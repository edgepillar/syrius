"""Pure fixture and mocked lifecycle controls; no Docker, SDK or filesystem scratch."""

import contextlib
import copy
import io
import json
from pathlib import Path
import unittest
from unittest import mock

from tool.ci import literal_lab_commands as lab


class LiteralLabTests(unittest.TestCase):
    def parent(self):
        return dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='workflow_dispatch',
            SYRIUS_HOSTED_RUNNER='github-hosted', SYRIUS_LITERAL_LAB='true',
            GITHUB_REPOSITORY='edgepillar/syrius', GITHUB_REF='refs/heads/redesign',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1')

    def rows(self):
        rows = []
        for index, role in enumerate(lab.ROLES, 1):
            ports = {} if role != 'rpc' else {
                '35997/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45997'}],
                '35998/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45998'}],
            }
            rows.append(dict(Id=str(index) * 64, Image='sha256:' + 'f' * 64,
                Name='/syrius-lab-' + role, RestartCount=0,
                Config=dict(Labels={'com.docker.compose.project': lab.PROJECT,
                    'com.docker.compose.service': role, 'private': 'not exported'}),
                State=dict(Running=True, Paused=False, Dead=False, OOMKilled=False,
                    Status='running', Pid=index,
                    StartedAt='2026-11-04T00:00:00.123456789Z'),
                NetworkSettings=dict(Ports=ports, Networks={lab.PROJECT:
                    dict(IPAddress='172.37.0.' + str(lab.hosted.OCTETS[role]))}),
                Mounts=[dict(Destination='/devnet', Type='bind', RW=False,
                    Source='/fixture/assets'), dict(Destination='/root/.znn',
                    Type='volume', RW=True, Name=lab.PROJECT + '_' + role + '-data')]))
        return rows

    def parse(self, rows):
        return lab.containers(json.dumps(rows).encode(), 'sha256:' + 'f' * 64,
            Path('/fixture/assets'))

    def events(self, owned):
        return [dict(Type='container', Action='die', Actor=dict(ID=value[0],
            Attributes={'exitCode': '0', 'name': 'syrius-lab-' + role,
                'com.docker.compose.project': lab.PROJECT,
                'com.docker.compose.service': role})) for role, value in owned.items()]

    def encoded(self, rows):
        return b'\n'.join(json.dumps(row).encode() for row in rows)

    def test_admits_only_first_manual_fork_linux_hosted_trial(self):
        lab.admit(self.parent(), 'linux')
        for field, value in [('GITHUB_EVENT_NAME', 'push'),
                ('SYRIUS_HOSTED_RUNNER', 'self-hosted'), ('SYRIUS_LITERAL_LAB', 'false'),
                ('GITHUB_REPOSITORY', 'private/other'), ('GITHUB_REF', 'refs/heads/dev'),
                ('GITHUB_SHA', 'private'), ('GITHUB_RUN_ID', 'private'),
                ('GITHUB_RUN_ATTEMPT', '2')]:
            with self.subTest(field=field), self.assertRaises(lab.Refused):
                lab.admit(dict(self.parent(), **{field: value}), 'linux')
        with self.assertRaises(lab.Refused):
            lab.admit(self.parent(), 'win32')

    def test_node_choices_are_fixed_pins_and_unknown_revisions_refuse(self):
        self.assertEqual(lab.selected_node({}), ('original', lab.NODE, lab.NODE_TREE))
        self.assertEqual(lab.admit(dict(self.parent(),
            SYRIUS_LITERAL_NODE_SOURCE='dev-0e80915'), 'linux'),
            ('dev-0e80915', '0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b',
                '244d362062b03c07e205ef9a2ad7ba1071fe779a'))
        for value in ('dev', 'a' * 40, '/private/input', '', None, True, []):
            with self.subTest(value=value), self.assertRaises(lab.Refused):
                lab.admit(dict(self.parent(), SYRIUS_LITERAL_NODE_SOURCE=value), 'linux')

    def test_unadmitted_main_starts_no_original_process(self):
        with mock.patch.dict(lab.os.environ, {}, clear=True), \
                mock.patch.object(lab.hosted, 'Original', side_effect=AssertionError('forbidden')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(lab.main(), 1)
        value = json.loads(output.getvalue().split('::', 2)[2])
        self.assertEqual(value['code'], 'ENVIRONMENT_REFUSED')
        self.assertEqual(value['schema'], 2)
        self.assertEqual(value['command_count'], 0)
        self.assertEqual(value['command_chunk_count'], 0)
        self.assertNotIn('commands', value)
        self.assertEqual(value['flutter_sdk_executions'], 0)
        self.assertNotIn('sdk_executions', value)

    def test_frontier_requires_chain321_and_actual_height_progress(self):
        self.assertEqual(lab.frontier(b'compose table\nchain 321: 5 then 6 after 5 s\nproducing\n'),
            dict(chain_id=321, first_height=5, last_height=6, seconds=5))
        for line in (b'chain 69: 5 then 6 after 5 s', b'chain 321: 5 then 5 after 5 s',
                b'chain 321: 6 then 5 after 5 s', b'chain 321: 5 then 6 after 271 s',
                b'chain 321: 5 then 9007199254740992 after 5 s'):
            with self.subTest(line=line), self.assertRaises(lab.Refused):
                lab.frontier(line + b'\nproducing\n')

    def test_frontier_never_borrows_an_earlier_valid_record(self):
        good = b'chain 321: 5 then 6 after 5 s\nproducing\n'
        for raw in (good + b'private', good + good,
                good.replace(b'producing', b'NOT producing'), b'x' * (2 * lab.MIB + 1)):
            with self.assertRaises(lab.Refused):
                lab.frontier(raw)

    def test_container_binding_keeps_original_id_start_and_pid_only(self):
        result = self.parse(self.rows())
        self.assertEqual(set(result), set(lab.ROLES))
        self.assertEqual(result['pillar'], ('1' * 64, '2026-11-04T00:00:00.123456789Z', 1))
        self.assertNotIn('private', json.dumps(result))

    def test_missing_extra_repeated_and_replaced_resources_refuse(self):
        original = self.rows()
        samples = [original[:-1], original + [original[0]],
            [original[0], original[0], *original[2:]]]
        for field, value in [('Id', 'private'), ('Image', 'sha256:' + 'e' * 64),
                ('Name', '/other'), ('RestartCount', 1)]:
            changed = copy.deepcopy(original);changed[0][field] = value;samples.append(changed)
        for rows in samples:
            with self.assertRaises(lab.Refused):
                self.parse(rows)

    def test_process_replacement_changes_the_bound_original(self):
        rows = self.rows();before = self.parse(rows)
        rows[0]['State']['Pid'] += 10
        self.assertNotEqual(before, self.parse(rows))
        rows = self.rows();rows[0]['State']['StartedAt'] = '2026-11-04T01:00:00Z'
        self.assertNotEqual(before, self.parse(rows))

    def test_unowned_or_unhealthy_container_state_refuses(self):
        for field, value in [('Running', False), ('Paused', True), ('Dead', True),
                ('OOMKilled', True), ('Status', 'exited'), ('Pid', True),
                ('StartedAt', 'private')]:
            rows = self.rows();rows[0]['State'][field] = value
            with self.subTest(field=field), self.assertRaises(lab.Refused):
                self.parse(rows)
        rows = self.rows();rows[0]['Config']['Labels']['com.docker.compose.project'] = 'other'
        with self.assertRaises(lab.Refused):self.parse(rows)

    def test_public_or_extra_rpc_and_p2p_bindings_refuse(self):
        for role, key, binding in [('rpc', '35997/tcp', [{'HostIp': '0.0.0.0', 'HostPort': '45997'}]),
                ('pillar', '35995/tcp', [{'HostIp': '127.0.0.1', 'HostPort': '45995'}]),
                ('rpc', '35995/tcp', [{'HostIp': '127.0.0.1', 'HostPort': '45995'}])]:
            rows = self.rows();next(r for r in rows if r['Name'].endswith('-' + role))['NetworkSettings']['Ports'][key] = binding
            with self.assertRaises(lab.Refused):self.parse(rows)

    def test_changed_asset_volume_and_peer_bindings_refuse(self):
        for mount, field, value in [(0, 'RW', True), (0, 'Source', '/private'),
                (1, 'Name', 'unowned-volume')]:
            rows = self.rows();rows[0]['Mounts'][mount][field] = value
            with self.assertRaises(lab.Refused):self.parse(rows)
        rows = self.rows();rows[0]['NetworkSettings']['Networks'][lab.PROJECT]['IPAddress'] = '127.0.0.1'
        with self.assertRaises(lab.Refused):self.parse(rows)

    def test_original_exit_events_require_every_owned_zero_exit(self):
        owned = self.parse(self.rows())
        self.assertEqual(lab.exits(self.encoded(self.events(owned)), owned), dict.fromkeys(lab.ROLES, 0))

    def test_missing_duplicate_nonzero_and_oom_events_refuse(self):
        owned = self.parse(self.rows());original = self.events(owned)
        samples = [original[:-1], original + [original[0]]]
        changed = copy.deepcopy(original);changed[0]['Actor']['Attributes']['exitCode'] = '137';samples.append(changed)
        samples.append(original + [dict(Type='container', Action='oom', Actor=dict(ID='1' * 64))])
        for rows in samples:
            with self.assertRaises(lab.Refused):lab.exits(self.encoded(rows), owned)

    def test_foreign_events_and_labels_are_never_exported(self):
        owned = self.parse(self.rows());rows = self.events(owned)
        rows.append(dict(Type='container', Action='die', Actor=dict(ID='private', Attributes=dict(private='secret'))))
        value = lab.exits(self.encoded(rows), owned)
        self.assertNotIn('secret', json.dumps(value));self.assertNotIn('private', json.dumps(value))

    def test_duplicate_json_keys_and_unknown_errors_do_not_export_input(self):
        with self.assertRaises(lab.Refused):lab.json_value(b'{"a": 1, "a": 2}')
        self.assertEqual(lab.code(ValueError('/private/input secret')), 'INTERNAL_ERROR')

    def test_failed_frontier_keeps_only_exact_stalled_fixture_numbers(self):
        self.assertEqual(lab.failed_frontier(b'table\nchain 321: 5 then 5 after 30 s\nNOT producing\n'),
            dict(status='STALLED', chain_id=321, first_height=5, last_height=5, seconds=30))
        for raw in (b'http://private: secret',
                b'chain 69: 5 then 5 after 30 s\nNOT producing\n',
                b'chain 321: 5 then 6 after 30 s\nNOT producing\n',
                b'chain 321: 5 then 5 after 30 s\nNOT producing\nprivate',
                b'chain 321: 5 then ' + b'9' * 10000 + b' after 30 s\nNOT producing\n'):
            value = lab.failed_frontier(raw)
            self.assertEqual(value, dict(status='UNAVAILABLE'))
            self.assertNotIn('private', json.dumps(value))

    def test_exit_facts_never_turn_nonzero_missing_or_oom_into_success(self):
        owned = self.parse(self.rows());rows = self.events(owned)[:-1]
        rows[0]['Actor']['Attributes']['exitCode'] = '137'
        rows.append(dict(Type='container', Action='oom', Actor=dict(ID=owned['pillar2'][0])))
        rows.append(dict(Type='container', Action='die', Actor=dict(ID='private', Attributes=dict(secret='private'))))
        raw = self.encoded(rows);facts = lab.exit_facts(raw, owned)
        self.assertEqual(facts['status'], 'OBSERVED')
        self.assertEqual(facts['roles']['pillar']['exit_codes'], [137])
        self.assertEqual(facts['roles']['rpc']['die_count'], 0)
        self.assertTrue(facts['roles']['pillar2']['oom'])
        self.assertNotIn('private', json.dumps(facts))
        with self.assertRaises(lab.Refused):lab.exits(raw, owned)
        self.assertEqual(lab.exit_facts(b'private', owned), dict(status='REFUSED', roles={}))

    def test_failure_log_refusal_is_bounded_and_does_not_raise(self):
        commands = mock.Mock();commands.run.side_effect = lab.Refused('OUTPUT_REFUSED')
        owned = self.parse(self.rows());value = lab.failure_logs(commands, owned)
        self.assertEqual(value, {role: dict(status='UNAVAILABLE', code='OUTPUT_REFUSED') for role in lab.ROLES})
        self.assertEqual(commands.run.call_count, 5)
        for call in commands.run.call_args_list:
            self.assertEqual(call.args[0], 'node_failure_logs')
            self.assertEqual(call.args[1][:4], ['docker', 'logs', '--tail', '64'])

    def test_node_file_logs_use_only_the_bound_ids_and_pinned_regular_paths(self):
        self.assertEqual(lab.NODE_LOG_SOURCES, (
            ('main', '/root/.znn/log/zenon.log'),
            ('error', '/root/.znn/log/error/zenon.error.log')))
        commands = mock.Mock()
        commands.run.side_effect = lambda stage, argv: (
            b'panic: fixture' if argv[-1].endswith('/log/zenon.log')
            else b'permission denied: fixture')
        owned = self.parse(self.rows())
        value = lab.failure_file_logs(commands, owned)
        self.assertEqual(value, {role: dict(sources=dict(main='READ', error='READ'),
            codes=['NODE_STORAGE_REFUSED', 'NODE_PANIC']) for role in lab.ROLES})
        self.assertEqual(commands.run.call_count, 10)
        for index, call in enumerate(commands.run.call_args_list):
            role = lab.ROLES[index // 2]
            self.assertEqual(call.args, ('node_failure_file_logs', ['docker',
                'exec', owned[role][0], 'sh', '-c', lab.NODE_LOG_READ,
                'lab-log', lab.NODE_LOG_SOURCES[index % 2][1]]))
        self.assertIn('[ ! -L "$1" ]', lab.NODE_LOG_READ)
        self.assertIn('[ -f "$1" ]', lab.NODE_LOG_READ)
        self.assertIn('exec tail -n 64 "$1"', lab.NODE_LOG_READ)

    def test_node_file_log_refusal_preserves_closed_codes_without_raw_errors(self):
        commands = mock.Mock()
        commands.run.side_effect = lab.Refused('OUTPUT_REFUSED')
        value = lab.failure_file_logs(commands, self.parse(self.rows()))
        self.assertEqual(value, {role: dict(sources=dict(main='OUTPUT_REFUSED',
            error='OUTPUT_REFUSED'), codes=[]) for role in lab.ROLES})
        self.assertEqual(commands.run.call_count, 10)
        commands = mock.Mock()
        commands.run.return_value = 'private input'
        value = lab.failure_file_logs(commands, self.parse(self.rows()))
        self.assertEqual(value, {role: dict(sources=dict(main='OUTPUT_REFUSED',
            error='OUTPUT_REFUSED'), codes=[]) for role in lab.ROLES})
        commands = mock.Mock()
        commands.run.return_value = b'fixture'
        with mock.patch.object(lab.hosted, 'node_diagnostics',
                side_effect=ValueError('private input')):
            value = lab.failure_file_logs(commands, self.parse(self.rows()))
        self.assertEqual(value, {role: dict(sources=dict(main='INTERNAL_ERROR',
            error='INTERNAL_ERROR'), codes=[]) for role in lab.ROLES})
        self.assertNotIn('private', json.dumps(value))

    def test_notice_chunks_preserve_all_bound_receipts_within_message_limit(self):
        command = dict(stage='source', seconds=0.1, receipt=dict(exit_code=0,
            output_complete=True, forced=False, stop_code=None, stop_os_error=None,
            streams={name: dict(bytes=40, retained_bytes=40, sha256='a' * 64,
                overflow=False) for name in ('stdout', 'stderr')}),
            retained_objects={name: dict(bytes=40, sha256='a' * 64) for name in ('stdout', 'stderr')})
        rows = [copy.deepcopy(command) for _ in range(80)]
        rows[7]['stage'] = 'up'
        rows[7]['up_output_tags'] = [dict(code='GO_LINKNAME_REFUSED', symbol='a' * 95) for _ in range(12)]
        with mock.patch.dict(lab.os.environ, {}, clear=True), \
                mock.patch.object(lab.hosted, 'Original', side_effect=AssertionError('forbidden')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(lab.main(), 1)
        report = json.loads(output.getvalue().split('::', 2)[2])
        report.update(source_sha='a' * 40, source_tree='b' * 40,
            run_id='1' * 20, run_attempt='1', commands=rows)
        del report['command_count'], report['command_chunk_count']
        codes = ['NODE_DATA_LOCK_RELEASE_REQUESTED', 'NODE_KEYSTORE_REFUSED',
            'NODE_P2P_STOP_REQUESTED', 'NODE_SIGNAL_RECEIVED']
        report['node_failure_facts'] = {role: dict(status='READ', codes=codes)
            for role in lab.ROLES}
        report['node_file_failure_facts'] = {role: dict(sources=dict(
            main='OUTPUT_REFUSED', error='COMMAND_TIMEOUT'), codes=codes)
            for role in lab.ROLES}
        report['exit_observations'] = dict(status='OBSERVED', roles={role: dict(
            die_count=2000, exit_codes=[137, 138, 139, 255], exit_code_count=256,
            oom=True) for role in lab.ROLES})
        report.update(image_sha256='c' * 64, genesis_sha256='d' * 64,
            observation_code='COMMAND_TIMEOUT', close_code='RESOURCE_CHANGED',
            up=dict(chain_id=321, first_height=2**53 - 2,
                last_height=2**53 - 1, seconds=270),
            status=dict(chain_id=321, first_height=2**53 - 2,
                last_height=2**53 - 1, seconds=270))
        frames = lab.notice_frames(report)
        self.assertEqual(frames[0]['command_count'], 80)
        self.assertEqual(frames[0]['command_chunk_count'], len(frames) - 1)
        self.assertEqual(report['commands'], rows)
        self.assertLessEqual(len(frames), 50)
        items = []
        for index, frame in enumerate(frames[1:], 1):
            self.assertEqual(frame['chunk_index'], index)
            self.assertEqual(frame['chunk_count'], len(frames) - 1)
            self.assertEqual(frame['source_sha'], report['source_sha'])
            self.assertEqual(frame['run_id'], '1' * 20)
            items.extend(frame['items'])
        self.assertEqual([item['index'] for item in items], list(range(1, 81)))
        self.assertEqual([item['command'] for item in items], rows)
        self.assertTrue(all(len(json.dumps(frame, sort_keys=True,
            separators=(',', ':')).encode()) <= 3800 for frame in frames))

    def test_complete_original_command_path_closes_once_then_revalidates_source(self):
        for choice, (node, tree) in lab.NODE_SOURCES.items():
            with self.subTest(choice=choice):
                commands = mock.Mock();commands.git.side_effect = [node, tree]
                rows = self.rows();owned = self.parse(rows)
                commands.docker.side_effect = [json.dumps('sha256:' + 'f' * 64).encode(),
                    json.dumps(rows).encode(), json.dumps(rows).encode(), b'', b'']
                outputs = dict(up=b'chain 321: 5 then 6 after 5 s\nproducing\n',
                    status=b'chain 321: 6 then 7 after 5 s\nproducing\n', down=b'',
                    exit_events=self.encoded(self.events(owned)))
                commands.run.side_effect = lambda stage, *_args: outputs[stage]
                report = dict(source_sha='a' * 40, node_source=choice,
                    node_sha=node, node_tree=tree, checks=dict.fromkeys(
                    ('fresh', 'originals', 'production', 'stopped', 'source_after'), False))
                genesis = b'{"ChainIdentifier":321}'
                with mock.patch.object(lab, 'source', return_value='b' * 40) as source, \
                        mock.patch.object(lab, 'empty_project'), \
                        mock.patch.object(lab.hosted, 'regular',
                            side_effect=[node[:7].encode(), genesis, genesis]):
                    lab.observe(commands, Path('/repo'), Path('/fixture'), report)
                self.assertTrue(all(report['checks'].values()))
                self.assertEqual(source.call_count, 2)
                self.assertEqual(report['exit_codes'], dict.fromkeys(lab.ROLES, 0))
                self.assertEqual([c.args[0] for c in commands.run.call_args_list],
                    ['up', 'status', 'down', 'exit_events'])
                argv = commands.run.call_args_list[-1].args[1]
                for value in owned.values():self.assertEqual(argv.count('container=' + value[0]), 1)

    def test_candidate_header_cannot_borrow_an_original_node_build(self):
        commands = mock.Mock();commands.git.return_value = lab.NODE
        commands.run.return_value = b'chain 321: 5 then 6 after 5 s\nproducing\n'
        node, tree = lab.NODE_SOURCES['dev-0e80915']
        report = dict(source_sha='a' * 40, node_source='dev-0e80915',
            node_sha=node, node_tree=tree, checks=dict(fresh=False))
        with mock.patch.object(lab, 'source', return_value='b' * 40), \
                mock.patch.object(lab, 'empty_project'):
            with self.assertRaises(lab.Refused) as raised:
                lab.observe(commands, Path('/repo'), Path('/fixture'), report)
        self.assertEqual(raised.exception.code, 'SOURCE_REFUSED')
        self.assertEqual(report['observation_code'], 'SOURCE_REFUSED')
        self.assertTrue(report['unadopted_start_held'])
        self.assertEqual([call.args[0] for call in commands.run.call_args_list], ['up'])

    def test_primary_observation_failure_survives_a_close_refusal(self):
        commands = mock.Mock();commands.git.side_effect = [lab.NODE, lab.NODE_TREE]
        commands.docker.return_value = json.dumps('sha256:' + 'f' * 64).encode()
        def run(stage, *args):
            if stage == 'up':return b'chain 321: 5 then 6 after 5 s\nproducing\n'
            raise lab.Refused('CHAIN_REFUSED')
        commands.run.side_effect = run
        report = dict(source_sha='a' * 40, checks=dict(fresh=False, originals=False, production=False))
        owned = self.parse(self.rows());changed = dict(owned, pillar=('e' * 64, owned['pillar'][1], 99))
        with mock.patch.object(lab, 'source', return_value='b' * 40), \
                mock.patch.object(lab, 'empty_project'), \
                mock.patch.object(lab.hosted, 'regular', side_effect=[b'590f43c', b'{"ChainIdentifier":321}']), \
                mock.patch.object(lab, 'containers', side_effect=[owned, changed]):
            with self.assertRaises(lab.Refused) as raised:
                lab.observe(commands, Path('/fixture'), Path('/fixture/lab'), report)
        self.assertEqual(raised.exception.code, 'CHAIN_REFUSED')
        self.assertEqual(report['observation_code'], 'CHAIN_REFUSED')
        self.assertEqual(report['close_code'], 'RESOURCE_CHANGED')
        self.assertEqual([c.args[0] for c in commands.run.call_args_list], ['up', 'status'])


if __name__ == '__main__':
    unittest.main()
