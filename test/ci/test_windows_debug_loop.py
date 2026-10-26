"""In-memory controller boundaries; native ownership is qualified on Windows."""

import io
import json
import copy
from pathlib import Path, PureWindowsPath
import sys
import types
import unittest
from unittest import mock

from tool.ci import windows_debug_loop as debug
from tool.ci import windows_debug_process as owned
from tool.ci import run_debug_tests


VM = 'ws://127.0.0.1:43432/fixture-token=/ws'


def frame(value):
    return json.dumps([value]).encode()


def event(name, **params):
    return frame(dict(event=name, params=params))


class Process:
    def __init__(self):
        self.stdin = io.BytesIO()
        self.code = None

    def poll(self):
        return self.code

    def wait(self, timeout=None):
        self.code = 0
        return self.code


class StreamTests(unittest.TestCase):
    def test_original_stream_hash_and_eof_are_distinct_from_runtime_success(self):
        raw = b'private-source-path\nprivate-auth-address\n'
        lines = debug.Lines(io.BytesIO(raw))
        self.assertTrue(lines.finish())
        self.assertEqual(lines.take(), b'private-source-path\n')
        self.assertEqual(lines.take(), b'private-auth-address\n')
        self.assertEqual(lines.public()['bytes'], len(raw))
        self.assertTrue(lines.public()['output_complete'])
        self.assertNotIn('private', json.dumps(lines.public()))

    def test_line_overflow_is_held_and_never_exposed_as_complete_qualification(self):
        with mock.patch.object(debug.protocol, 'MAX_LINE', 8):
            lines = debug.Lines(io.BytesIO(b'private-value-too-long\n'))
            self.assertFalse(lines.finish())
            with self.assertRaises(debug.ProcessRefused):
                lines.take()

    def test_total_overflow_does_not_hide_actual_consumed_bytes(self):
        with mock.patch.object(debug.protocol, 'MAX_TOTAL', 4):
            lines = debug.Lines(io.BytesIO(b'123\n456\n'))
            self.assertFalse(lines.finish())
            self.assertEqual(lines.count, 8)


class ToolTests(unittest.TestCase):
    def tool(self, raw):
        process = Process()
        lines = debug.Lines(io.BytesIO(raw))
        lines.thread.join(1)
        return debug.Tool(process, lines)

    def startup(self, extra=b''):
        return (event('app.start', appId='original', deviceId='windows', supportsRestart=True) + b'\n'
            + event('app.debugPort', appId='original', port=43432, wsUri=VM) + b'\n'
            + event('app.started', appId='original') + b'\n' + extra)

    def test_sdk_exit_is_actual_separate_fact_without_protocol_admission(self):
        tool = self.tool(debug.EXIT_PREFIX + b'{"exit":1}\n')
        tool.observe()
        self.assertEqual(tool.exit, 1)
        self.assertFalse(tool.protocol.public()['runtime_qualified'])

    def test_duplicate_or_boolean_exit_receipt_is_refused(self):
        for raw in (b'{"exit":true}', b'{"exit":0,"path":"private"}'):
            tool = self.tool(debug.EXIT_PREFIX + raw + b'\n')
            with self.subTest(raw=raw), self.assertRaises(debug.ProcessRefused):
                tool.observe()
        tool = self.tool((debug.EXIT_PREFIX + b'{"exit":0}\n') * 2)
        tool.observe()
        with self.assertRaises(debug.ProcessRefused):
            tool.observe()

    def test_successful_reload_keeps_original_request_and_private_output(self):
        tool = self.tool(self.startup(frame(dict(id=1, result=dict(code=0))) + b'\n'))
        for _ in range(3):
            tool.observe()
        tool.command('app.restart', full_restart=False)
        sent = json.loads(tool.original.stdin.getvalue())
        self.assertEqual(sent[0]['params']['appId'], 'original')
        self.assertIs(sent[0]['params']['fullRestart'], False)
        self.assertEqual(tool.protocol.public()['completed_commands'], 1)

    def test_failed_reload_cannot_be_retried_after_late_success(self):
        tool = self.tool(self.startup(frame(dict(id=1, error='private-error')) + b'\n'
            + frame(dict(id=1, result=dict(code=0))) + b'\n'))
        for _ in range(3):
            tool.observe()
        with self.assertRaises(debug.protocol.Refused):
            tool.command('app.restart', full_restart=False)
        self.assertTrue(tool.protocol.public()['held'])
        with self.assertRaises(debug.protocol.Refused):
            tool.observe()
        self.assertEqual(len(tool.original.stdin.getvalue().splitlines()), 1)

    def test_ended_original_cannot_supply_an_unobserved_reply(self):
        tool = self.tool(b'')
        tool.original.code = 0
        with self.assertRaises(debug.ProcessRefused):
            tool.until(lambda: False, .2)


class EnvironmentTests(unittest.TestCase):
    def test_discovery_does_not_import_the_stdlib_test_namespace(self):
        standard = types.ModuleType('test')
        standard.__path__ = ['/fixture/stdlib-test']
        with mock.patch.dict(sys.modules, {'test': standard}):
            suite = run_debug_tests.load_suite()
            self.assertGreaterEqual(suite.countTestCases(), 29)
            cases = []

            def collect(value):
                for item in value:
                    if isinstance(item, unittest.TestSuite):
                        collect(item)
                    else:
                        cases.append(item.id())

            collect(suite)
            self.assertFalse(any('_FailedTest' in case for case in cases))
            self.assertTrue(all(case.startswith(('test_flutter_debug_protocol.',
                                                 'test_windows_debug_loop.')) for case in cases))

    def test_profile_environment_has_no_inherited_credentials_or_presentation_mode(self):
        parent = dict(PATH='runtime', SYSTEMROOT='system', GITHUB_ACTIONS='true',
            GITHUB_TOKEN='private-token', GH_TOKEN='private-token', HTTPS_PROXY='private-proxy',
            SYRIUS_HARNESS_PRESENTATION='import', FLUTTER_ROOT='sdk', PUB_CACHE='packages')
        for profile in (Path('/fixture/profile'), PureWindowsPath('Q:/fixture/profile')):
            with self.subTest(path_type=type(profile).__name__):
                env = debug.profile_environment(parent, profile, 45000, 'private-agent-token')
                self.assertFalse(set(env) & {'GITHUB_TOKEN', 'GH_TOKEN', 'HTTPS_PROXY', 'SYRIUS_HARNESS_PRESENTATION'})
                self.assertEqual(env['USERPROFILE'], str(profile))
                self.assertEqual(env['APPDATA'], str(profile / 'AppData/Roaming'))
                self.assertEqual(env['SYRIUS_WINDOWS_DEBUG_PROFILE'], str(profile))
                self.assertEqual(env['FLUTTER_ROOT'], 'sdk')

    def test_job_refuses_native_execution_on_other_platforms(self):
        with mock.patch.object(debug.os, 'name', 'posix'), self.assertRaises(debug.ProcessRefused):
            debug.WindowsJob()


class FrontendTests(unittest.TestCase):
    def worker(self, value):
        worker = debug.Frontend.__new__(debug.Frontend)
        worker.original, worker.result = Process(), None
        worker.lines = debug.Lines(io.BytesIO(json.dumps(value).encode() + b'\n'))
        worker.lines.thread.join(1)
        tool = mock.Mock()
        tool.protocol._service = VM
        tool.protocol._devtools = 'private-linked-frontend'
        return worker, tool

    def receipt(self, **changes):
        value = dict(schema=1, ok=True, scope='owned_devtools_frontend', attached=True,
            headless=True, browserExit=0, outputComplete=True, forced=False, code=None,
            outputBytes=0, outputSha256='0' * 64, phase='browser_exited',
            observations=dict.fromkeys(debug.FRONTEND_FLAGS, False))
        value['observations'].update(dict.fromkeys(debug.FRONTEND_COUNTS, 0))
        value['observations'].update(documentReady=True, devtoolsTitle=True,
            frontendSourceMatched=True, frontendGetVmMatched=True, serviceSocketSeen=True,
            getVmRequests=1, getVmReplies=1)
        value.update(changes)
        return value

    def test_finite_frontend_receipt_keeps_private_command_out_of_its_result(self):
        worker, tool = self.worker(self.receipt())
        worker.attach(tool, 1234)
        self.assertTrue(worker.result['attached'])
        self.assertNotIn('private', json.dumps(worker.result))
        command = worker.original.stdin.getvalue()
        self.assertTrue(command.startswith(b'START\n'))
        self.assertEqual(json.loads(command.splitlines()[1])['pid'], 1234)

    def test_zero_exit_does_not_replace_required_attachment_or_complete_unforced_output(self):
        for changes in (dict(attached=False), dict(outputComplete=False), dict(forced=True),
                        dict(browserExit=False), dict(schema=True), dict(extra='private-field')):
            worker, tool = self.worker(self.receipt(**changes))
            with self.subTest(changes=changes), self.assertRaises(debug.ProcessRefused):
                worker.attach(tool, 1234)

    def test_known_frontend_failure_is_preserved_without_retry_or_raw_details(self):
        worker, tool = self.worker(self.receipt(ok=False, attached=False, code='BROWSER_REFUSED'))
        with self.assertRaises(debug.ProcessRefused) as raised:
            worker.attach(tool, 1234)
        self.assertEqual(str(raised.exception), 'BROWSER_REFUSED')
        self.assertEqual(worker.result['code'], 'BROWSER_REFUSED')
        self.assertEqual(len(worker.original.stdin.getvalue().splitlines()), 2)

    def test_frontend_positive_bit_cannot_override_missing_or_malformed_observations(self):
        changes = [dict(phase='page_navigated'), dict(phase='private-phase')]
        for key, value in (('getVmReplies', 0), ('getVmRequests', True),
                           ('documentReady', False), ('held', True), ('otherSockets', 'private')):
            observations = self.receipt()['observations']
            observations[key] = value
            changes.append(dict(observations=observations))
        for change in changes:
            worker, tool = self.worker(self.receipt(**change))
            with self.subTest(change=change), self.assertRaises(debug.ProcessRefused):
                worker.attach(tool, 1234)

    def test_title_change_preserves_source_identity_and_wrong_origin_still_refuses(self):
        observations = self.receipt()['observations']
        observations['devtoolsTitle'] = False
        worker, tool = self.worker(self.receipt(observations=observations))
        worker.attach(tool, 1234)
        observations = self.receipt()['observations']
        observations['frontendSourceMatched'] = False
        worker, tool = self.worker(self.receipt(observations=observations))
        with self.assertRaises(debug.ProcessRefused):
            worker.attach(tool, 1234)


class ProbeStartupTests(unittest.TestCase):
    def test_known_startup_shape_projects_only_finite_code_size_and_hash(self):
        value = debug.probe_line_observation(b'Resolving dependencies... private-context\n')
        self.assertEqual(value['code'], 'PUB_RESOLUTION')
        self.assertEqual(set(value), {'code', 'bytes', 'sha256'})
        self.assertNotIn('private', json.dumps(value))

    def test_unknown_startup_text_is_hashed_without_exposing_it(self):
        value = debug.probe_line_observation(b'private-auth-address and private-source-path\n')
        self.assertEqual(value['code'], 'UNCLASSIFIED_OUTPUT')
        self.assertNotIn('private', json.dumps(value))

    def test_failed_original_bind_is_reserved_and_cannot_be_reissued(self):
        probe = debug.Probe.__new__(debug.Probe)
        probe.original, probe.reserved, probe.failure = Process(), set(), None
        probe.lines = debug.Lines(io.BytesIO(b'Resolving dependencies...\n'))
        probe.lines.thread.join(1)
        tool = mock.Mock()
        for _ in range(2):
            with self.assertRaises(debug.ProcessRefused):
                probe.command('bind', tool, pid=1234, wsUri=VM)
        self.assertEqual(probe.failure['code'], 'PUB_RESOLUTION')
        self.assertEqual(len(probe.original.stdin.getvalue().splitlines()), 1)


class OrdinaryCloseTests(unittest.TestCase):
    def test_close_ack_is_separate_from_original_process_exit(self):
        transport = mock.Mock()
        transport.exchange.return_value = types.SimpleNamespace(status=200, body=b'{"ok":true}')
        self.assertIsNone(debug.request_close(transport, 'fixture-token'))
        transport.exchange.assert_called_once_with(dict(cmd='quit'), 'fixture-token', 5)

    def test_invalid_or_extra_close_reply_does_not_trigger_another_request(self):
        for status, body in ((400, b'{"ok":true}'), (200, b'{"ok":1}'),
                             (200, b'{"ok":false}'), (200, b'{"ok":true,"extra":"private"}'),
                             (200, b'private-invalid-json')):
            transport = mock.Mock()
            transport.exchange.return_value = types.SimpleNamespace(status=status, body=body)
            with self.subTest(status=status, body=body), self.assertRaises(debug.ProcessRefused):
                debug.request_close(transport, 'fixture-token')
            self.assertEqual(transport.exchange.call_count, 1)

    def test_lost_ack_stays_uncertain_without_replay_or_exception_text(self):
        transport = mock.Mock()
        transport.exchange.side_effect = TimeoutError('private socket context')
        with self.assertRaises(debug.ProcessRefused) as raised:
            debug.request_close(transport, 'fixture-token')
        self.assertEqual(str(raised.exception), 'CLOSE_UNCONFIRMED')
        self.assertEqual(transport.exchange.call_count, 1)


class CompilerHelperTests(unittest.TestCase):
    def test_cmake_vendor_versions_are_admitted_without_accepting_paths(self):
        for value in ('4.4.4', '3.11.18033000-MSVC_2', '4.1.0-msvc1', '4.2.0-rc1'):
            with self.subTest(value=value):
                self.assertTrue(debug.compiler_metadata_version(value))
        for value in ('../4.4.4', '4.4.4/other', 'Q:/4.4.4', 'vendor', '4.4.4-' + 'a'*65):
            with self.subTest(value=value):
                self.assertFalse(debug.compiler_metadata_version(value))

    def test_helper_is_the_sibling_of_the_recorded_absolute_msvc_compiler(self):
        text = 'set(CMAKE_CXX_COMPILER "Q:/fixture/MSVC/14.50/bin/Hostx64/x64/cl.exe")\n'
        self.assertEqual(debug.compiler_helper_path(text),
            PureWindowsPath('Q:/fixture/MSVC/14.50/bin/Hostx64/x64/vctip.exe'))

    def test_ambiguous_relative_remote_or_other_compiler_is_refused(self):
        values = ['cl.exe', 'Q:/fixture/../cl.exe', '//fixture.invalid/share/cl.exe',
                  'Q:/fixture/clang-cl.exe', 'Q:/fixture/\x00cl.exe']
        for value in values:
            with self.subTest(value=value), self.assertRaises(debug.ProcessRefused):
                debug.compiler_helper_path('set(CMAKE_CXX_COMPILER "' + value + '")\n')
        with self.assertRaises(debug.ProcessRefused):
            debug.compiler_helper_path('set(CMAKE_CXX_COMPILER "Q:/fixture/cl.exe")\n' * 2)


class HelperAdmissionTests(unittest.TestCase):
    def report(self):
        receipt = dict(role='sdk_dart', image_sha256='a' * 64, forced=True,
            termination_requested=True, termination_succeeded=True,
            actual_exit=debug.HELPER_EXIT_MARKER, exit_observed=True, stdio_captured=False)
        report = dict(checks=dict.fromkeys(debug.CHECKS, True), errors=[],
            required_actor_forced_cleanup=False, devtools_attached=True,
            frontend=dict(ok=True, browserExit=0, forced=False, outputComplete=True),
            protocol=dict(held=False, app_stopped=True, pending_commands=0),
            auxiliary_cleanup=dict(scope=debug.HELPER_SCOPE, status='PASSED', code=None,
                forced=True, remaining=0, receipts=[receipt]),
            owned_job_active_at_close=0, forced_cleanup=True)
        for key in ('application_exit','bootstrap_exit','tool_exit','probe_exit','frontend_exit'):
            report[key] = 0
        for key in ('tool_output','probe_output','frontend_output'):
            report[key] = dict(output_complete=True, overflow=False)
        return report

    def test_helper_teardown_keeps_its_forced_marker_separate_from_normal_actor_exits(self):
        report = self.report()
        self.assertTrue(debug.required_actors_complete(report))
        self.assertTrue(debug.debug_complete(report))
        self.assertTrue(report['forced_cleanup'])
        self.assertEqual(report['auxiliary_cleanup']['receipts'][0]['actual_exit'], debug.HELPER_EXIT_MARKER)
        self.assertEqual(report['application_exit'], 0)

    def test_any_nonzero_unobserved_or_boolean_original_exit_refuses_helper_admission(self):
        for key in ('application_exit','bootstrap_exit','tool_exit','probe_exit','frontend_exit'):
            for value in (1, None, False):
                report = self.report();report[key] = value
                with self.subTest(key=key, value=value):
                    self.assertFalse(debug.required_actors_complete(report))
                    self.assertFalse(debug.debug_complete(report))

    def test_held_failed_source_or_incomplete_output_cannot_be_healed_by_helper_cleanup(self):
        for change in ('error','held','source','output','forced'):
            report = self.report()
            if change == 'error':report['errors'] = ['COMMAND_UNCERTAIN']
            elif change == 'held':report['protocol']['held'] = True
            elif change == 'source':report['checks']['source_unchanged'] = False
            elif change == 'output':report['tool_output']['output_complete'] = False
            else:report['required_actor_forced_cleanup'] = True
            with self.subTest(change=change):
                self.assertFalse(debug.required_actors_complete(report))
                self.assertFalse(debug.debug_complete(report))

    def test_unknown_duplicate_or_unobserved_helper_receipts_refuse_qualification(self):
        for change in ('role','duplicate','exit','signal','digest','remaining','status'):
            report = self.report();cleanup=report['auxiliary_cleanup'];receipt=cleanup['receipts'][0]
            if change == 'role':receipt['role'] = 'other'
            elif change == 'duplicate':cleanup['receipts'].append(copy.deepcopy(receipt))
            elif change == 'exit':receipt['exit_observed'] = False
            elif change == 'signal':receipt['termination_succeeded'] = False
            elif change == 'digest':receipt['image_sha256'] = 'private-invalid'
            elif change == 'remaining':report['owned_job_active_at_close'] = 1
            else:cleanup['status'] = 'FAILED'
            with self.subTest(change=change):self.assertFalse(debug.debug_complete(report))

    def test_natural_helper_exit_zero_and_empty_job_need_no_forced_marker(self):
        report=self.report();cleanup=report['auxiliary_cleanup'];receipt=cleanup['receipts'][0]
        cleanup['forced']=report['forced_cleanup']=False
        receipt.update(forced=False,termination_requested=False,termination_succeeded=False,actual_exit=0)
        self.assertTrue(debug.debug_complete(report))
        cleanup['receipts']=[]
        self.assertTrue(debug.debug_complete(report))

    def test_wrong_helper_exit_or_hidden_force_is_not_accepted(self):
        report=self.report();report['auxiliary_cleanup']['receipts'][0]['actual_exit']=0
        self.assertFalse(debug.debug_complete(report))
        report=self.report();report['forced_cleanup']=False
        self.assertFalse(debug.debug_complete(report))


class OwnedHelperTests(unittest.TestCase):
    class Kernel:
        def __init__(self, names, timeout=False):
            self.names = dict(enumerate(names, 1))
            self.exits, self.signals, self.closed, self.opened = {}, [], [], []
            self.timeout = timeout

        def QueryInformationJobObject(self, job, kind, pointer, size, returned):
            active = [pid for pid in self.names if pid not in self.exits]
            value = pointer._obj
            if kind == 3:
                value.assigned = value.listed = len(active)
                for index, pid in enumerate(active):
                    value.identifiers[index] = pid
            else:
                value.active = len(active)
            return True

        def OpenProcess(self, rights, inherit, pid):
            self.opened.append(pid)
            return pid

        def IsProcessInJob(self, handle, job, pointer):
            pointer._obj.value = handle in self.names
            return True

        def QueryFullProcessImageNameW(self, handle, flags, image, size):
            image.value = str(Path('/fixture') / self.names[handle])
            return True

        def WaitForSingleObject(self, handle, milliseconds):
            return 0 if handle in self.exits and not self.timeout else 0x102

        def TerminateProcess(self, handle, marker):
            self.signals.append((handle, marker, tuple(self.opened)))
            self.exits[handle] = marker
            return True

        def GetExitCodeProcess(self, handle, pointer):
            pointer._obj.value = self.exits[handle]
            return True

        def CloseHandle(self, handle):
            self.closed.append(handle)
            return True

    def finish(self, names, timeout=False):
        job = owned.WindowsJob.__new__(owned.WindowsJob)
        job.handle, job.kernel = 99, self.Kernel(names, timeout)
        with mock.patch.object(owned, 'image_pin', return_value=('a' * 64, (1, 2, 3, 4))), \
                mock.patch.object(owned.Path, 'lstat', return_value=types.SimpleNamespace(st_size=1024)):
            result = job.finish_known_helpers(Path('/fixture/sdk/dart.exe'),
                lambda: Path('/fixture/compiler/vctip.exe'))
        return result, job.kernel

    def test_all_original_handles_are_bound_before_signalling_known_helpers(self):
        result, kernel = self.finish(['sdk/dart.exe', 'compiler/vctip.exe'])
        self.assertTrue(debug.helper_cleanup_complete(result))
        self.assertEqual(result['remaining'], 0)
        self.assertEqual(result['observation']['stage'], 'complete')
        self.assertEqual(kernel.signals, [(1, owned.HELPER_EXIT_MARKER, (1, 2)),
                                          (2, owned.HELPER_EXIT_MARKER, (1, 2))])
        self.assertEqual(kernel.closed, [1, 2])

    def test_unknown_or_duplicate_member_prevents_any_signal(self):
        for names in (['sdk/dart.exe', 'other/tool.exe'], ['sdk/dart.exe'] * 2):
            result, kernel = self.finish(names)
            with self.subTest(names=names):
                self.assertEqual(result['status'], 'FAILED')
                self.assertFalse(result['forced'])
                self.assertEqual(kernel.signals, [])
                self.assertEqual(kernel.closed, [1, 2])

    def test_unobserved_termination_is_failed_without_a_second_signal(self):
        result, kernel = self.finish(['sdk/dart.exe'], timeout=True)
        self.assertEqual(result['status'], 'FAILED')
        self.assertEqual(result['code'], 'HELPER_CLOSE_UNCONFIRMED')
        self.assertEqual(result['observation']['stage'], 'termination')
        self.assertTrue(result['forced'])
        self.assertFalse(result['receipts'][0]['exit_observed'])
        self.assertEqual(kernel.signals, [(1, owned.HELPER_EXIT_MARKER, (1,))])
        self.assertEqual(kernel.closed, [1])


if __name__ == '__main__':
    unittest.main()
