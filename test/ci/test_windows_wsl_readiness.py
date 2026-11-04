"""WSL privacy, uncertainty and dispatch admission without native execution."""

import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from tool.ci import windows_wsl_readiness as readiness


def outcome(output=b'', code=0, **changes):
    values = dict(output=output, exit_code=code, exit_observed=True,
        output_complete=True, output_bytes=len(output))
    values.update(changes)
    return readiness.bounded.Outcome(**values)


def commands(version=b'WSL version: 2.1.5.0\r\nKernel version: 6.6.87.2\r\n'):
    return dict(version=outcome(version), status=outcome())


class ProjectionTests(unittest.TestCase):
    def test_installed_version_never_qualifies_kernel_or_docker(self):
        value = readiness.project(commands())
        self.assertEqual(value['wsl_package_version'], '2.1.5.0')
        self.assertTrue(value['meets_docker_documented_wsl_minimum'])
        self.assertEqual(value['reported_kernel_version'], '6.6.87.2')
        self.assertFalse(value['kernel_start_qualified'])
        self.assertFalse(value['docker_linux_mode_qualified'])
        self.assertEqual(value['nested_virtualization'], 'NOT_ESTABLISHED')

    def test_utf16_redirected_version_with_or_without_bom(self):
        text = 'WSL version: 2.1.5.0\r\nKernel version: 6.6.87.2\r\n'
        for prefix in (b'', b'\xff\xfe'):
            with self.subTest(bom=bool(prefix)):
                value = readiness.project(commands(prefix + text.encode('utf-16-le')))
                self.assertEqual(value['wsl_package_version'], '2.1.5.0')

    def test_version_minimum_uses_numeric_components(self):
        for text, expected in [('2.1.4', False), ('2.1.5', True), ('2.10.0', True)]:
            with self.subTest(version=text):
                value = readiness.project(commands(('WSL version: ' + text + '\n').encode()))
                self.assertIs(value['meets_docker_documented_wsl_minimum'], expected)

    def test_unknown_locale_ambiguous_or_malformed_version_stays_unknown(self):
        for raw in (b'WSL: 2.1.5\n', b'WSL version: 2.1.5\nWSL version: 2.1.5\n',
                    b'WSL version: private\n', b'\xff', b'x' * (readiness.CAP + 1)):
            with self.subTest(size=len(raw)):
                value = readiness.project(commands(raw))
                self.assertIsNone(value['wsl_package_version'])
                self.assertIsNone(value['meets_docker_documented_wsl_minimum'])

    def test_nonzero_original_exit_cannot_supply_a_successful_version(self):
        selected = commands()
        selected['version'].exit_code = 50
        value = readiness.project(selected)
        self.assertIsNone(value['wsl_package_version'])
        self.assertEqual(value['commands']['version']['outcome']['exit_code'], 50)
        self.assertEqual(value['status'], 'OBSERVED')

    def test_incomplete_or_forced_command_remains_unknown(self):
        for changes in (dict(forced_kill=True), dict(output_complete=False),
                        dict(output_overflow=True), dict(exit_observed=False),
                        dict(errors=('COMMAND_TIMEOUT',))):
            with self.subTest(changes=changes):
                selected = commands()
                selected['version'] = outcome(selected['version'].output, **changes)
                value = readiness.project(selected)
                self.assertEqual(value['status'], 'UNKNOWN')
                self.assertIsNone(value['wsl_package_version'])

    def test_private_output_is_not_retained_or_printed(self):
        selected = commands(b'private-path private-person private-distribution\n'
            b'Wsl/Service/WSL_E_KERNEL_NOT_FOUND\nUNKNOWN_PRIVATE_CODE\n')
        selected['version'].exit_code = 1
        value = readiness.project(selected)
        public = json.dumps(value)
        for secret in ('private-path', 'private-person', 'private-distribution',
                       'UNKNOWN_PRIVATE_CODE', 'Wsl/Service/'):
            self.assertNotIn(secret, public)
        self.assertEqual(value['commands']['version']['reported_codes'],
                         ['WSL_E_KERNEL_NOT_FOUND'])

    def test_environment_drops_credentials_and_extra_commands(self):
        env = readiness.query_environment(dict(PATH='tools', SYSTEMROOT='system',
            GH_TOKEN='private', GITHUB_TOKEN='private', WSLENV='private',
            GIT_CONFIG_COUNT='1', PYTHONPATH='private'))
        self.assertEqual(env['PATH'], 'tools')
        self.assertFalse(set(env) & {'GH_TOKEN', 'GITHUB_TOKEN', 'WSLENV',
                                    'GIT_CONFIG_COUNT', 'PYTHONPATH'})


class AdmissionTests(unittest.TestCase):
    def parent(self):
        return dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
            SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
            GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_READINESS='true',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='123')

    def test_exact_fresh_hosted_dispatch_is_admitted(self):
        readiness.admit(self.parent(), 'win32')

    def test_missing_or_changed_gate_is_refused(self):
        for name in self.parent():
            with self.subTest(name=name):
                parent = self.parent()
                parent[name] = ''
                with self.assertRaises(readiness.Refused):
                    readiness.admit(parent, 'win32')
        with self.assertRaises(readiness.Refused):
            readiness.admit(self.parent(), 'darwin')

    def test_unapproved_context_never_launches_a_child(self):
        with patch.object(readiness.bounded.subprocess, 'Popen',
                side_effect=AssertionError('Child forbidden')) as child:
            with self.assertRaises(readiness.Refused):
                readiness.run({}, 'darwin')
            child.assert_not_called()

    def test_main_does_not_export_original_exception(self):
        output = io.StringIO()
        with (patch.object(readiness, 'run',
                side_effect=RuntimeError('private-details')),
                contextlib.redirect_stdout(output)):
            self.assertEqual(readiness.main([]), 1)
        self.assertEqual(output.getvalue(),
            '::error title=Windows WSL readiness::READINESS_REFUSED\n')

    def run_original_queries(self, *, changed=False):
        parent = dict(self.parent(), PATH='tools', SYSTEMROOT='system',
                      GH_TOKEN='private')
        replies = [outcome(('a' * 40).encode()), outcome(('b' * 40).encode()),
            outcome(), *commands().values(), outcome(('a' * 40).encode()),
            outcome((('c' if changed else 'b') * 40).encode()), outcome()]
        with (patch.object(readiness.shutil, 'which', return_value='git.exe'),
                patch.object(readiness.bounded, 'plain'),
                patch.object(Path, 'is_file', return_value=True),
                patch.object(readiness.bounded, 'run_bounded', side_effect=replies) as run,
                patch.object(readiness.bounded.subprocess, 'Popen',
                    side_effect=AssertionError('Child forbidden'))):
            if changed:
                with self.assertRaises(readiness.Refused):
                    readiness.run(parent, 'win32')
                value = None
            else:
                value = readiness.run(parent, 'win32')
        calls = run.call_args_list
        queries = [call for call in calls if call.args[0][0].endswith('wsl.exe')]
        self.assertEqual([call.args[0][1:] for call in queries],
                         [['--version'], ['--status']])
        self.assertEqual(len(calls), 8)
        for call in queries:
            self.assertEqual(call.kwargs['cap'], readiness.CAP)
            self.assertEqual(call.kwargs['timeout'], readiness.TIMEOUT)
            self.assertNotIn('GH_TOKEN', call.kwargs['env'])
        return value

    def test_real_controller_keeps_original_fixed_queries_and_source(self):
        value = self.run_original_queries()
        self.assertTrue(value['source_unchanged'])
        self.assertEqual(value['source_sha'], 'a' * 40)
        self.assertEqual(value['source_tree'], 'b' * 40)

    def test_changed_source_is_refused_without_replaying_queries(self):
        self.run_original_queries(changed=True)
