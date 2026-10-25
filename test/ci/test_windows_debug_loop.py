"""In-memory controller boundaries; native ownership is qualified on Windows."""

import io
import json
from pathlib import Path
import unittest
from unittest import mock

from tool.ci import windows_debug_loop as debug
from test.ci.test_flutter_debug_protocol import event, frame, VM


class Process:
    def __init__(self):
        self.stdin = io.BytesIO()
        self.code = None

    def poll(self):
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
    def test_profile_environment_has_no_inherited_credentials_or_presentation_mode(self):
        parent = dict(PATH='runtime', SYSTEMROOT='system', GITHUB_ACTIONS='true',
            GITHUB_TOKEN='private-token', GH_TOKEN='private-token', HTTPS_PROXY='private-proxy',
            SYRIUS_HARNESS_PRESENTATION='import', FLUTTER_ROOT='sdk', PUB_CACHE='packages')
        env = debug.profile_environment(parent, Path('/fixture/profile'), 45000, 'private-agent-token')
        self.assertFalse(set(env) & {'GITHUB_TOKEN', 'GH_TOKEN', 'HTTPS_PROXY', 'SYRIUS_HARNESS_PRESENTATION'})
        self.assertEqual(env['USERPROFILE'], '/fixture/profile')
        self.assertEqual(env['APPDATA'], '/fixture/profile/AppData/Roaming')
        self.assertEqual(env['SYRIUS_WINDOWS_DEBUG_PROFILE'], '/fixture/profile')
        self.assertEqual(env['FLUTTER_ROOT'], 'sdk')

    def test_job_refuses_native_execution_on_other_platforms(self):
        with mock.patch.object(debug.os, 'name', 'posix'), self.assertRaises(debug.ProcessRefused):
            debug.WindowsJob()


if __name__ == '__main__':
    unittest.main()
