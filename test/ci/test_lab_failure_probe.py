"""Memory-only fixed-wire failure diagnostics; no sockets, files or processes."""

import copy
import ast
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab
from tool.ci import inspect_chain321 as inspector
from tool.ci import lab_failure_probe as probe
from tool.ci import restored_wallet_run as copied


def replies():
    return {
        'stats.networkInfo': dict(numPeers=3,
            peers=[dict(ip='Synthetic private IP', publicKey='Synthetic private key')],
            self=dict(name='Synthetic private identity')),
        'stats.syncInfo': dict(state=3, currentHeight=14, targetHeight=0),
        'ledger.getFrontierMomentum': dict(chainIdentifier=321, height=14,
            timestamp=1793912240, hash='a' * 64),
    }


class Wire:
    def __init__(self, owner):
        self.owner = owner
        self.pending = bytearray()
        self.close_count = 0

    def write(self, raw, deadline):
        request = json.loads(raw.split(b'\r\n\r\n', 1)[1])
        self.owner.requests.append(request)
        if self.owner.write_hook:
            self.owner.write_hook(request)
        value = self.owner.responses[request['method']]
        if isinstance(value, Exception):
            raise value
        body = json.dumps(dict(jsonrpc='2.0', id=request['id'], result=value)).encode()
        self.pending.extend(b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
            + ('Content-Length: %d\r\n\r\n' % len(body)).encode() + body)

    def read(self, maximum, deadline):
        value = bytes(self.pending[:maximum])
        del self.pending[:maximum]
        return value

    def close(self, deadline):
        self.close_count += 1
        if self.owner.close_error and self is self.owner.wires[0]:
            raise self.owner.close_error
        return probe.policy.Closed(self, True)


class Transport:
    def __init__(self):
        self.responses = replies()
        self.requests = []
        self.wires = []
        self.origins = []
        self.deadlines = []
        self.write_hook = None
        self.open_hook = None
        self.close_error = None

    def open(self, origin, deadline):
        self.origins.append(origin)
        self.deadlines.append(deadline)
        wire = Wire(self)
        self.wires.append(wire)
        if self.open_hook:
            self.open_hook()
        return wire


class FailureProbeTests(unittest.TestCase):
    def collect(self, transport=None, owner=None, clock=None):
        transport = transport or Transport()
        return probe.collect(owner or (lambda: None),
            transports=lambda: (transport, object()), clock=clock or (lambda: 0.0))

    def test_three_original_reads_have_fixed_endpoint_order_bounds_and_no_identity(self):
        transport = Transport()
        result = self.collect(transport)
        self.assertEqual([v['method'] for v in transport.requests],
                         [method for _, method in probe.READS])
        self.assertEqual([v['id'] for v in transport.requests], [1, 2, 3])
        self.assertTrue(all(v['params'] == [] for v in transport.requests))
        self.assertEqual(transport.origins, [probe.policy.HTTP_ORIGIN] * 3)
        self.assertEqual(transport.deadlines, [2.0] * 3)
        self.assertEqual([v.close_count for v in transport.wires], [1, 1, 1])
        self.assertEqual(result['attempted'], 3)
        self.assertEqual(result['opened_wires'], 3)
        self.assertTrue(result['wires_closed'])
        self.assertTrue(result['ownership_current'])
        self.assertEqual(result['network'], dict(status='OBSERVED',
            reported_peers=3, listed_peers=1))
        self.assertEqual(result['sync'], dict(status='OBSERVED', state=3,
            current_height=14, target_height=0))
        self.assertEqual(result['frontier'], dict(status='OBSERVED',
            height=14, timestamp=1793912240))
        for value in ('Synthetic', 'publicKey', 'self', 'hash', 'confirmed', 'retry'):
            self.assertNotIn(value, json.dumps(result))

    def test_status_client_cannot_expand_or_reorder_the_original_ledger_client(self):
        transport = Transport()
        deadline = probe.policy._Deadline(lambda: 0, 8)
        client = probe._StatusReads(transport, probe.policy.Limits(), deadline, lambda n: b'x' * n)
        for method, params in (('stats.syncInfo', []), ('ledger.publishRawTransaction', []),
                ('stats.networkInfo', ['private']), ('stats.networkInfo', {})):
            with self.assertRaises(probe.policy.Refused):
                client.call(method, params)
        self.assertEqual(client.next_id, 0)
        self.assertEqual(transport.wires, [])
        for _, method in probe.READS:
            client.call(method, [])
        with self.assertRaises(probe.policy.Refused):
            client.call('stats.networkInfo', [])
        self.assertEqual(len(transport.wires), 3)
        original = probe.policy.HttpRpc(transport, probe.policy.Limits(), deadline, lambda n: b'x' * n)
        for method in ('stats.networkInfo', 'stats.syncInfo'):
            with self.assertRaises(probe.policy.Refused):
                original.call(method, [])
        self.assertEqual(original.next_id, 0)

    def test_projection_refuses_private_coerced_unbounded_or_inconsistent_data(self):
        original = self.collect()
        changes = [dict(schema=True), dict(schema=2), dict(scope='private'),
            dict(phase='after_stop'), dict(status='success'), dict(attempted=True),
            dict(attempted=4), dict(opened_wires=4), dict(opened_wires=True),
            dict(wires_closed=1), dict(ownership_current=1), dict(address='private'),
            dict(confirmed=True), dict(retry=True), dict(path='private')]
        for name in ('network', 'sync', 'frontier'):
            changes += [{name: original[name] | dict(path='private')},
                        {name: dict(status='REFUSED', code='private')},
                        {name: dict(status='private')}, {name: None}]
            for key in original[name]:
                changes.append({name: {k: v for k, v in original[name].items() if k != key}})
        changes += [dict(network=original['network'] | dict(reported_peers=True)),
            dict(network=original['network'] | dict(listed_peers=129)),
            dict(sync=original['sync'] | dict(state=True)),
            dict(sync=original['sync'] | dict(state=0)),
            dict(sync=original['sync'] | dict(current_height=1.0)),
            dict(sync=original['sync'] | dict(target_height=probe.MAXIMUM + 1)),
            dict(frontier=original['frontier'] | dict(height=0)),
            dict(frontier=original['frontier'] | dict(timestamp=-1)),
            dict(network=dict(status='NOT_READ')), dict(attempted=2),
            dict(network=dict(status='REFUSED', code='OWNER_REFUSED'))]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(probe.Refused):
                probe.project(original | change)
        for key in original:
            with self.assertRaises(probe.Refused):
                probe.project({k: v for k, v in original.items() if k != key})

    def test_copies_and_unavailable_data_never_invent_a_receipt_or_count(self):
        original = self.collect()
        result = probe.project(original)
        original['network']['reported_peers'] = 128
        self.assertEqual(result['network']['reported_peers'], 3)
        self.assertIsNone(probe.project(None))
        self.assertEqual(probe.project(probe.unavailable()), probe.unavailable())
        for key in ('attempted', 'opened_wires', 'wires_closed', 'confirmed', 'retry'):
            with self.assertRaises(probe.Refused):
                probe.project(probe.unavailable() | {key: 0})

    def test_original_ownership_refusal_stops_reads_and_closes_each_opened_wire_once(self):
        for refuse_at, attempts in ((1, 0), (2, 1), (3, 1)):
            transport = Transport()
            calls = []
            def owner():
                calls.append(None)
                if len(calls) == refuse_at:
                    raise RuntimeError('Synthetic private ownership failure')
            result = self.collect(transport, owner)
            self.assertFalse(result['ownership_current'])
            self.assertEqual(result['attempted'], attempts)
            self.assertEqual(len(transport.requests), attempts)
            self.assertTrue(all(w.close_count == 1 for w in transport.wires))
            self.assertTrue(result['wires_closed'])
            if refuse_at == 2:
                self.assertEqual(result['network'], dict(status='REFUSED', code='OWNER_REFUSED'))
            self.assertEqual(result['frontier'], dict(status='NOT_READ'))

    def test_each_original_read_failure_is_retained_without_a_retry_or_raw_reply(self):
        for changes in ({'stats.networkInfo': dict(numPeers=True, peers=[])},
                {'stats.syncInfo': dict(state=2, currentHeight=True, targetHeight=14)},
                {'ledger.getFrontierMomentum': replies()['ledger.getFrontierMomentum'] | dict(chainIdentifier=1)},
                {'stats.networkInfo': probe.policy.Refused('RPC_REFUSED')}):
            transport = Transport()
            transport.responses.update(changes)
            result = self.collect(transport)
            self.assertEqual(len(transport.requests), 3)
            self.assertEqual([v['method'] for v in transport.requests],
                             [method for _, method in probe.READS])
            for name, method in probe.READS:
                if method in changes:
                    self.assertEqual(result[name]['status'], 'REFUSED')
            self.assertTrue(all(w.close_count == 1 for w in transport.wires))
            self.assertNotIn('Synthetic', json.dumps(result))

    def test_failed_original_close_is_not_reissued_or_relabelled_by_later_closes(self):
        for error in (RuntimeError('Synthetic private release failure'),
                      probe.policy.Refused('CLOSE_UNKNOWN')):
            transport = Transport()
            transport.close_error = error
            result = self.collect(transport)
            self.assertFalse(result['wires_closed'])
            self.assertEqual(result['network']['status'], 'REFUSED')
            self.assertEqual(result['sync']['status'], 'OBSERVED')
            self.assertEqual([w.close_count for w in transport.wires], [1, 1, 1])
            self.assertNotIn('Synthetic', json.dumps(result))

    def test_existing_transport_limits_bound_late_or_oversized_original_responses(self):
        transport = Transport()
        now = [0.0]
        transport.write_hook = lambda request: now.__setitem__(0, 9.0)
        result = self.collect(transport, clock=lambda: now[0])
        self.assertEqual(result['attempted'], 3)
        self.assertEqual(result['opened_wires'], 1)
        self.assertEqual(len(transport.requests), 1)
        self.assertTrue(all(result[name] == dict(status='REFUSED', code='DEADLINE')
                            for name, _ in probe.READS))
        self.assertEqual(transport.wires[0].close_count, 1)
        transport = Transport()
        now = [0.0]
        transport.open_hook = lambda: now.__setitem__(0, now[0] + 2.5)
        result = self.collect(transport, clock=lambda: now[0])
        self.assertEqual(result['attempted'], 3)
        self.assertEqual(result['opened_wires'], 3)
        self.assertEqual(transport.requests, [])
        self.assertEqual([wire.close_count for wire in transport.wires], [1, 1, 1])
        self.assertTrue(result['wires_closed'])
        transport = Transport()
        transport.responses['stats.networkInfo']['self'] = dict(private='x' * 65536)
        result = self.collect(transport)
        self.assertEqual(result['network']['status'], 'REFUSED')
        self.assertEqual(result['opened_wires'], 3)
        self.assertTrue(result['wires_closed'])

    def test_parent_collection_is_explicit_once_only_and_preserves_the_original_failure(self):
        runtime = mock.Mock(spec=lab.Native)
        checks = dict.fromkeys(('source', 'build', 'started', 'production'), True)
        report = dict(runtime_phase='wallet_tour', error_codes=['WALLET_TOUR_FAILED'], checks=checks)
        with mock.patch.object(probe, 'collect', return_value=self.collect()) as collect:
            lab.record_wallet_failure_probe(report, runtime, wallet_tour=True, stack_debug=True)
            lab.record_wallet_failure_probe(report, runtime, wallet_tour=True, stack_debug=True)
        collect.assert_called_once_with(runtime.healthy)
        runtime.stop.assert_not_called()
        self.assertEqual(report['error_codes'], ['WALLET_TOUR_FAILED'])
        for error in (RuntimeError('Synthetic private error'), None, dict(path='private')):
            original = dict(runtime_phase='wallet_tour', error_codes=['WALLET_TOUR_FAILED'], checks=checks)
            kwargs = dict(side_effect=error) if isinstance(error, Exception) else dict(return_value=error)
            with mock.patch.object(probe, 'collect', **kwargs):
                lab.record_wallet_failure_probe(original, runtime, wallet_tour=True, stack_debug=True)
            self.assertEqual(original['wallet_failure_probe'], probe.unavailable())
            self.assertEqual(original['error_codes'], ['WALLET_TOUR_FAILED'])
        for wallet, debug, actor, phase, errors in (
                (False, True, runtime, 'wallet_tour', ['WALLET_TOUR_FAILED']),
                (True, False, runtime, 'wallet_tour', ['WALLET_TOUR_FAILED']),
                (True, True, object(), 'wallet_tour', ['WALLET_TOUR_FAILED']),
                (True, True, runtime, 'other', ['WALLET_TOUR_FAILED']),
                (True, True, runtime, 'wallet_tour', ['CHECKPOINT_REFUSED'])):
            value = dict(runtime_phase=phase, error_codes=errors, checks=checks)
            with mock.patch.object(probe, 'collect') as collect:
                lab.record_wallet_failure_probe(value, actor, wallet_tour=wallet, stack_debug=debug)
            collect.assert_not_called()
            self.assertNotIn('wallet_failure_probe', value)
        for key in checks:
            value = dict(runtime_phase='wallet_tour', error_codes=['WALLET_TOUR_FAILED'],
                checks=checks | {key: False})
            with mock.patch.object(probe, 'collect') as collect:
                lab.record_wallet_failure_probe(value, runtime, wallet_tour=True, stack_debug=True)
            collect.assert_not_called()

    def test_independent_reader_binds_passive_data_to_the_original_failed_native_context(self):
        report = dict(wallet_failure_probe=self.collect(), wallet_tour_requested=True,
            native_stack_diagnostic=True, success=False, error_codes=['WALLET_TOUR_FAILED'],
            checks=dict.fromkeys(('source', 'build', 'started', 'production'), True),
            runtime_phase='wallet_tour')
        result = inspector.project_wallet_failure_probe(report, 'native')
        self.assertEqual(result, report['wallet_failure_probe'])
        self.assertIsNot(result['network'], report['wallet_failure_probe']['network'])
        self.assertIsNone(inspector.project_wallet_failure_probe({}, 'docker'))
        for change in (dict(wallet_tour_requested=False), dict(native_stack_diagnostic=False),
                dict(success=True), dict(success=0), dict(error_codes=[]),
                dict(checks=dict(started=False)), dict(runtime_phase='other'),
                dict(wallet_failure_probe=report['wallet_failure_probe'] | dict(hash='private'))):
            with self.subTest(change=change), self.assertRaises(inspector.Refused):
                inspector.project_wallet_failure_probe(report | change, 'native')
        with self.assertRaises(inspector.Refused):
            inspector.project_wallet_failure_probe(report, 'docker')
        for key in report['checks']:
            with self.assertRaises(inspector.Refused):
                inspector.project_wallet_failure_probe(report | dict(
                    checks=report['checks'] | {key: False}), 'native')
        self.assertFalse(report['success'])
        self.assertEqual(report['error_codes'], ['WALLET_TOUR_FAILED'])

    def test_complete_notice_preserves_every_old_negative_fact_and_binds_a_small_probe_frame(self):
        if __package__:
            from .test_inspect_chain321 import InspectionTests
        else:
            from test_inspect_chain321 import InspectionTests

        report = InspectionTests.wallet_stop_report()
        report['wallet_failure_probe'] = self.collect()
        original = copy.deepcopy(report)
        summary = inspector.project(report, 'native', 'a' * 40, 40319698922,
            inspector.UPSTREAM_NODE_SHA, expected_patched=True)
        summary.update(archive_sha256='e' * 64, manifest_sha256='f' * 64)
        frames = inspector.observation_frames(summary)
        self.assertEqual(report, original)
        self.assertEqual([name for name, _ in frames], ['', 'wallet_failure_probe'])
        parent, frame = frames[0][1], frames[1][1]
        encoded = lambda value: json.dumps(value, sort_keys=True,
            separators=(',', ':')).encode('ascii')
        self.assertTrue(all(len(encoded(value)) <= 3800 for _, value in frames))
        self.assertFalse(parent['artifact_reported_success'])
        self.assertEqual(parent['error_codes'], ['WALLET_TOUR_FAILED', 'STOP_UNKNOWN'])
        self.assertEqual(len(parent['node_exits']), 5)
        self.assertTrue(parent['node_exits'][1]['forced'])
        self.assertEqual(parent['native_stack_probe']['protocol_workers']['count'], 4)
        self.assertNotIn('wallet_failure_probe', parent)
        self.assertEqual(frame['scope'], 'owned_lab_failure_probe_component')
        self.assertEqual(frame['parent_notice_sha256'], hashlib.sha256(encoded(parent)).hexdigest())
        self.assertEqual(frame['facts'], summary['wallet_failure_probe'])
        for key in ('source_head', 'source_run_id', 'source_attempt', 'backend',
                    'archive_sha256', 'manifest_sha256'):
            self.assertEqual(frame[key], parent[key])


def copied_stall():
    trace = copied.ReopenDiagnostic()
    trace.at('seed_workflow')
    frontier = dict(polls=6, ws_first_height=23, ws_last_height=23,
        ws_first_timestamp=100, ws_last_timestamp=100, ws_hash_changed=False,
        http_first_height=23, http_last_height=23,
        http_first_timestamp=100, http_last_timestamp=100, http_hash_changed=False)
    seed = dict(schema=1, scope='original_seed_operation_failure', recipe='stake',
        action='publish', step='reply', command_index=8, publication_call_entered=True,
        kind='refused', reason='advancing-momentum-required', frontier=frontier)
    child = dict(schema=1, scope='owned_reopen_child_failure', phase='seed_stake',
        kind='HARNESS_REFUSED', code=None, recipe=None, seed=seed)
    trace.observe_line(b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\n')
    return trace


class CopiedFailureProbeTests(unittest.TestCase):
    def record(self, trace, transport, guard=lambda: True):
        runtime = mock.Mock(spec=lab.Native)
        original = probe.collect
        with mock.patch.object(probe, 'collect', side_effect=lambda owned:
                original(owned, transports=lambda: (transport, object()), clock=lambda: 0)):
            copied._record_copied_failure_probe(trace, runtime, guard,
                copied.checkpoint.Refused(), stack_debug=True)
        return runtime

    def test_owned_copied_stall_gets_only_three_passive_reads_without_healing(self):
        trace, transport = copied_stall(), Transport()
        runtime = self.record(trace, transport)
        self.assertEqual([row['method'] for row in transport.requests],
                         [method for _, method in probe.READS])
        self.assertTrue(all(row['params'] == [] for row in transport.requests))
        self.assertTrue(all(wire.close_count == 1 for wire in transport.wires))
        self.assertIsNone(trace.error)
        self.assertEqual(trace.phase, 'seed_workflow')
        self.assertTrue(trace.copied_lab_failure_probe['ownership_current'])
        runtime.start.assert_not_called()
        runtime.stop.assert_not_called()
        original = copied.checkpoint.Refused()
        trace.failure(original)
        value = trace.snapshot()
        self.assertEqual(value['error'], 'CHECKPOINT_REFUSED')
        self.assertEqual(value['child_failure']['seed']['reason'], 'advancing-momentum-required')
        self.assertFalse(copied.project(dict(schema=1, scope=copied.SCOPE,
            complete=False, diagnostic=value))['complete'])
        self.assertNotIn('Synthetic', json.dumps(value))
        self.assertNotIn('publicKey', json.dumps(value))

    def test_other_phases_errors_owners_and_disabled_flags_cannot_open_a_wire(self):
        for change in ('phase', 'child', 'reason', 'error', 'runtime', 'disabled', 'coerced', 'guard'):
            trace = copied_stall()
            runtime, error, flag, guard = mock.Mock(spec=lab.Native), copied.checkpoint.Refused(), True, lambda: True
            if change == 'phase': trace.phase = 'seeded_capture'
            if change == 'child': trace.child_failure = None
            if change == 'reason': trace.child_failure['seed']['reason'] = 'unknown'
            if change == 'error': error = OSError('Synthetic private error')
            if change == 'runtime': runtime = object()
            if change == 'disabled': flag = False
            if change == 'coerced': flag = 1
            if change == 'guard': guard = None
            with self.subTest(change=change), mock.patch.object(probe, 'collect') as collect:
                copied._record_copied_failure_probe(trace, runtime, guard, error, stack_debug=flag)
            collect.assert_not_called()
            self.assertIsNone(trace.copied_lab_failure_probe)

    def test_lost_owner_before_the_sample_stays_unavailable_for_future_reentry(self):
        trace, transport = copied_stall(), Transport()
        self.record(trace, transport, guard=lambda: False)
        value = trace.copied_lab_failure_probe
        self.assertEqual((value['attempted'], value['opened_wires']), (0, 0))
        self.assertFalse(value['ownership_current'])
        with mock.patch.object(probe, 'collect') as collect:
            copied._record_copied_failure_probe(trace, mock.Mock(spec=lab.Native),
                lambda: True, copied.checkpoint.Refused(), stack_debug=True)
        collect.assert_not_called()
        self.assertEqual(transport.requests, [])

    def test_owner_loss_after_an_original_wire_closes_it_and_prevents_more_reads(self):
        trace, transport = copied_stall(), Transport()
        owned = [True]
        transport.write_hook = lambda request: owned.__setitem__(0, False)
        self.record(trace, transport, guard=lambda: owned[0])
        value = trace.copied_lab_failure_probe
        self.assertEqual(value['attempted'], 1)
        self.assertEqual(value['network'], dict(status='REFUSED', code='OWNER_REFUSED'))
        self.assertEqual(value['sync'], dict(status='NOT_READ'))
        self.assertEqual(value['frontier'], dict(status='NOT_READ'))
        self.assertFalse(value['ownership_current'])
        self.assertEqual([wire.close_count for wire in transport.wires], [1])

    def test_actual_exception_handler_samples_before_cleanup_and_reraises_the_original(self):
        tree = ast.parse(Path('tool/ci/restored_wallet_run.py').read_text())
        run = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'run')
        block = copy.deepcopy(next(node for node in run.body
            if isinstance(node, ast.Try) and node.finalbody))
        block.body = ast.parse('raise original_error').body
        block.finalbody = ast.parse("events.append('close')").body
        runtime, trace, events = mock.Mock(spec=lab.Native), copied_stall(), []
        original_error = copied.checkpoint.Refused()
        def collect(owned):
            events.append('sample')
            raise RuntimeError('Synthetic private collection error')
        scope = dict(_record_copied_failure_probe=copied._record_copied_failure_probe,
            trace=trace, runtime=runtime, guard=lambda: True, original_error=original_error,
            original_runtime=SimpleNamespace(stack_debug=True), events=events)
        program = ast.fix_missing_locations(ast.Module(body=[block], type_ignores=[]))
        with mock.patch.object(probe, 'collect', side_effect=collect):
            with self.assertRaises(copied.checkpoint.Refused) as raised:
                exec(compile(program, 'original_reopen_handler', 'exec'), scope)
        self.assertIs(raised.exception, original_error)
        self.assertEqual(events, ['sample', 'close'])
        self.assertEqual(trace.copied_lab_failure_probe, probe.unavailable())
        self.assertNotIn('Synthetic', json.dumps(trace.copied_lab_failure_probe))
        events.clear()
        scope['_record_copied_failure_probe'] = mock.Mock(
            side_effect=RuntimeError('Synthetic observer admission failure'))
        with self.assertRaises(copied.checkpoint.Refused) as raised:
            exec(compile(program, 'original_reopen_handler', 'exec'), scope)
        self.assertIs(raised.exception, original_error)
        self.assertEqual(events, ['close'])

    def test_projection_binds_closed_sample_to_the_original_failed_copy_and_notice(self):
        trace = copied_stall()
        self.record(trace, Transport())
        trace.failure(copied.checkpoint.Refused())
        value = trace.snapshot()
        for change in (dict(error=None), dict(error='OS_ERROR'), dict(phase='ordinary_close'),
                       dict(child_failure=None), dict(copied_lab_failure_probe=None),
                       dict(copied_lab_failure_probe=value['copied_lab_failure_probe'] | dict(path='private'))):
            with self.subTest(change=change), self.assertRaises(copied.checkpoint.Refused):
                copied.diagnostic_projection(value | change)
        projected = copied.diagnostic_projection(value)
        value['copied_lab_failure_probe']['network']['reported_peers'] = 128
        self.assertEqual(projected['copied_lab_failure_probe']['network']['reported_peers'], 3)
        summary = dict(scope='retained_chain321_observation', source_head='a' * 40,
            source_run_id=123, backend='native', archive_sha256='b' * 64,
            manifest_sha256='c' * 64, wallet_reopen=dict(schema=1,
                scope=copied.SCOPE, complete=False, diagnostic=projected))
        frames = copied.notice_frames(summary)
        self.assertTrue(all(len(json.dumps(frame, separators=(',', ':')).encode()) <= 3800
                            for _, frame in frames))
        self.assertEqual(len(frames), 1)
        facts = frames[0][1]['wallet_reopen']
        self.assertFalse(facts['complete'])
        self.assertEqual(facts['diagnostic']['error'], 'CHECKPOINT_REFUSED')
        self.assertEqual(facts['diagnostic']['copied_lab_failure_probe'],
                         projected['copied_lab_failure_probe'])


if __name__ == '__main__':
    unittest.main()
