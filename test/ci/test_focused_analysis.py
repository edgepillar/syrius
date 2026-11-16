"""Memory-only privacy, bounds and original-exit controls for strict notices."""

import io
import json
import subprocess
import unittest
from unittest.mock import patch

from tool.ci import focused_analysis as focused


def finding(path='lib/view.dart', code='unnecessary_import', *, message='private'):
    return ('info - ' + path + ':10:3 - ' + message + ' - ' + code +
            '\n1 issue found.\n').encode()


class _Process:
    def __init__(self, raw, code):
        self.stdout = io.BytesIO(raw)
        self.code = code

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def wait(self):
        return self.code


class FocusedAnalysisTests(unittest.TestCase):
    def project(self, raw, *, repo='/fixture', code=1):
        return focused.failure_notice(
            raw, code, repo=repo, sources=('lib/view.dart',))

    def test_selected_linux_and_windows_paths_drop_roots_and_messages(self):
        for repo, path in (
                ('/fixture', '/fixture/lib/view.dart'),
                ('C:/fixture', 'C:\\fixture\\lib\\view.dart')):
            for code in ('unnecessary_import', 'cascade_invocations',
                         'use_null_aware_elements'):
                value = self.project(
                    finding(path, code=code, message='private credential'),
                    repo=repo)
                self.assertEqual(value['diagnostics'][0]['file'], 'lib/view.dart')
                self.assertEqual(value['diagnostics'][0]['code'], code)
                self.assertTrue(value['locations_complete'])
                rendered = json.dumps(value)
                self.assertNotIn('fixture', rendered)
                self.assertNotIn('private', rendered)
                self.assertNotIn('credential', rendered)
                self.assertFalse(value['qualification'])

    def test_foreign_unselected_parent_and_uri_paths_never_escape(self):
        for path in ('/outside/private.dart', '../lib/view.dart',
                     'lib/unselected.dart', 'https://private.invalid/view.dart',
                     '//private/share/view.dart'):
            value = self.project(finding(path))
            self.assertEqual(value['status'], 'REFUSED')
            self.assertEqual(value['diagnostics'], [])
            self.assertNotIn('private', json.dumps(value))

    def test_unknown_codes_and_unframed_messages_are_not_disclosed(self):
        value = self.project(finding(code='private_credential'))
        self.assertEqual(value['diagnostics'][0]['code'], 'other')
        self.assertTrue(value['diagnostics'][0]['unknown_code'])
        self.assertNotIn('private', json.dumps(value))
        value = self.project(b'private raw exception\n')
        self.assertFalse(value['locations_complete'])
        self.assertEqual(value['diagnostics'], [])
        self.assertNotIn('private', json.dumps(value))
        self.assertEqual(self.project(None)['status'], 'REFUSED')

    def test_notice_cap_keeps_total_counts_without_raw_text(self):
        raw = finding().split(b'\n')[0] + b'\n'
        value = self.project(raw * 100 + b'100 issues found.\n')
        self.assertEqual(value['total_diagnostics'], 100)
        self.assertEqual(value['counts']['info'], 100)
        self.assertTrue(value['truncated'])
        self.assertTrue(value['locations_complete'])
        self.assertLessEqual(len(json.dumps(value, separators=(',', ':')).encode()), 3800)
        self.assertNotIn('private', json.dumps(value))

    def run_child(self, raw, code, *, cap=focused.MAX_NOTICE_INPUT):
        data = io.BytesIO()
        output = io.TextIOWrapper(data, encoding='utf-8', write_through=True)
        try:
            with patch.object(focused.subprocess, 'Popen',
                              return_value=_Process(raw, code)) as child, \
                    patch.object(focused, 'MAX_NOTICE_INPUT', cap), \
                    patch.object(focused.sys, 'stdout', output):
                result = focused.main()
            rendered = data.getvalue()
        finally:
            output.detach()
        self.assertEqual(child.call_count, 1)
        self.assertEqual(child.call_args.args[0],
                         ['dart', 'analyze', '--fatal-infos',
                          *focused.SELECTED_DART_SOURCES])
        self.assertEqual(child.call_args.args[0].count(
            'harness/bin/ci_paired_interactive_entry.dart'), 1)
        self.assertEqual(child.call_args.args[0].count(
            'test/settings_about_redesign/support.dart'), 1)
        self.assertEqual(child.call_args.args[0].count(
            'lib/utils/shutdown_observation.dart'), 1)
        self.assertEqual(child.call_args.kwargs['stdin'], subprocess.DEVNULL)
        return result, rendered

    def test_original_success_failure_and_signal_exit_are_unchanged(self):
        for code in (0, 3, -15):
            raw = b'original child output\n'
            result, rendered = self.run_child(raw, code)
            self.assertEqual(result, code)
            self.assertTrue(rendered.startswith(raw))
            if code:
                value = json.loads(rendered.split(b'::', 2)[2])
                self.assertEqual(value['actual_exit'], code)
                self.assertFalse(value['qualification'])
            else:
                self.assertEqual(rendered, raw)

    def test_overflow_drains_original_stream_without_promoting_failure(self):
        raw = b'private raw data\n' * 1024
        result, rendered = self.run_child(raw, 4, cap=256)
        self.assertEqual(result, 4)
        self.assertTrue(rendered.startswith(raw))
        notice = rendered[len(raw):].split(b'::', 2)[2]
        value = json.loads(notice)
        self.assertEqual(value['status'], 'REFUSED')
        self.assertFalse(value['qualification'])
        self.assertNotIn(b'private', notice)


if __name__ == '__main__':
    unittest.main()
