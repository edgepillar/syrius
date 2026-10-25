"""In-memory controller boundaries; native ownership is qualified on Windows."""

import io
import json
from pathlib import Path, PureWindowsPath
import sys
import types
import unittest
from unittest import mock

from tool.ci import windows_debug_loop as debug
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
            outputBytes=0, outputSha256='0' * 64)
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


if __name__ == '__main__':
    unittest.main()
