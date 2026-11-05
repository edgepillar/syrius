"""Kernel-query admission, original outcomes and privacy without native execution."""
import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from tool.ci import windows_wsl_kernel as kernel


RELEASE = b'6.6.114.1-microsoft-standard-WSL2\r\n'


def outcome(raw=b'', code=0, **changes):
    values = dict(output=raw, exit_code=code, exit_observed=True,
        output_complete=True, output_bytes=len(raw))
    values.update(changes)
    return kernel.readiness.bounded.Outcome(**values)


class KernelTests(unittest.TestCase):
    def parent(self):
        return dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
            SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
            GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_KERNEL_START='true',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='7', PROGRAMFILES='fixture-programs',
            PATH='fixture-path')

    def invoke(self, version=b'WSL version: 3.0.3.0\r\n', status=None,
            kernel_result=None, source_drift=False):
        calls = []
        source_calls = 0

        def run(argv, **options):
            nonlocal source_calls
            calls.append((argv, options))
            if argv[0] == 'git.exe':
                source_calls += 1
                if argv[-1] == 'HEAD':
                    return outcome((('c' if source_drift and source_calls > 3 else 'a') * 40 + '\n').encode())
                if argv[-1] == 'HEAD^{tree}':return outcome(('b' * 40 + '\n').encode())
                return outcome()
            if argv[-1] == '--version':return outcome(version)
            if argv[-1] == '--status':return outcome() if status is None else status
            self.assertEqual(argv, [str(Path('fixture-programs') / 'WSL/wsl.exe'),
                '--system', '--exec', '/bin/uname', '-r'])
            self.assertEqual((options['timeout'], options['cap']), (30, 16384))
            return outcome(RELEASE) if kernel_result is None else kernel_result

        with (patch.dict(kernel.os.environ, self.parent(), clear=True),
                patch.object(kernel.sys, 'platform', 'win32'),
                patch.object(kernel.shutil, 'which', return_value='git.exe'),
                patch.object(kernel.readiness.bounded, 'plain'),
                patch.object(Path, 'is_file', return_value=True),
                patch.object(kernel.readiness.bounded, 'run_bounded', side_effect=run),
                contextlib.redirect_stdout(io.StringIO()) as output):
            code = kernel.main([])
        text = output.getvalue()
        self.assertLessEqual(len(text.split('::', 2)[2].strip().encode()), 3800)
        return code, json.loads(text.split('::', 2)[2]), calls

    def test_only_first_manual_opted_in_hosted_arm_fork_admits(self):
        kernel.admit(self.parent(), 'win32')
        for name, value in (('GITHUB_EVENT_NAME', 'push'), ('RUNNER_ARCH', 'X64'),
                ('SYRIUS_HOSTED_RUNNER', 'self-hosted'), ('GITHUB_REPOSITORY', 'other/repo'),
                ('GITHUB_REF', 'refs/heads/dev'), ('GITHUB_RUN_ATTEMPT', '2'),
                ('SYRIUS_WINDOWS_WSL_KERNEL_START', 'false'), ('GITHUB_SHA', 'private'),
                ('GITHUB_RUN_ID', 'private')):
            with self.subTest(name=name), self.assertRaises(kernel.Refused):
                kernel.admit(dict(self.parent(), **{name: value}), 'win32')
        with self.assertRaises(kernel.Refused):kernel.admit(self.parent(), 'darwin')

    def test_valid_release_requires_an_original_complete_zero_exit(self):
        value = kernel.kernel_projection(outcome(RELEASE))
        self.assertEqual(value['status'], 'VALID_RELEASE_OBSERVED')
        self.assertEqual(value['release'], RELEASE.decode().strip())
        self.assertTrue(value['command']['success'])

    def test_utf16_release_is_decoded_without_exporting_raw_output(self):
        value = kernel.kernel_projection(outcome(b'\xff\xfe' + RELEASE.decode().encode('utf-16-le')))
        self.assertEqual(value['status'], 'VALID_RELEASE_OBSERVED')
        self.assertEqual(value['release'], RELEASE.decode().strip())
        self.assertNotIn('output', value)
        self.assertEqual(len(value['captured_output_sha256']), 64)

    def test_metadata_foreign_private_and_multiple_lines_never_qualify(self):
        for raw in (b'Kernel version: 6.6.114.1\n', b'6.6.114.1-custom-private\n',
                RELEASE + RELEASE, RELEASE + b'private\n', b'private person/path',
                b' 6.6.114.1-microsoft-standard-WSL2\n', b'\xff'):
            with self.subTest(raw=raw):
                value = kernel.kernel_projection(outcome(raw))
                self.assertEqual(value['status'], 'OUTPUT_REFUSED')
                self.assertIsNone(value['release'])
                self.assertNotIn('private', json.dumps(value))

    def test_nonzero_exit_cannot_borrow_a_valid_release(self):
        value = kernel.kernel_projection(outcome(RELEASE, code=1))
        self.assertEqual(value['status'], 'COMMAND_FAILED')
        self.assertIsNone(value['release'])
        self.assertFalse(value['command']['success'])
        for code in (False, None):
            value = kernel.kernel_projection(outcome(RELEASE, code=code))
            self.assertEqual(value['status'], 'UNKNOWN')
            self.assertIsNone(value['release'])
            self.assertFalse(value['command']['success'])

    def test_forced_incomplete_overflow_or_unknown_exit_remains_unknown(self):
        for change in (dict(forced_kill=True), dict(output_complete=False),
                dict(output_overflow=True), dict(exit_observed=False),
                dict(errors=('COMMAND_TIMEOUT',))):
            with self.subTest(change=change):
                value = kernel.kernel_projection(outcome(RELEASE, **change))
                self.assertEqual(value['status'], 'UNKNOWN')
                self.assertIsNone(value['release'])

    def test_only_closed_diagnostic_codes_leave_the_projection(self):
        value = kernel.kernel_projection(outcome(
            b'private path Wsl/Service/HCS_E_HYPERV_NOT_INSTALLED UNKNOWN_PRIVATE_CODE\n', code=1))
        self.assertEqual(value['reported_codes'], ['HCS_E_HYPERV_NOT_INSTALLED'])
        self.assertNotIn('private', json.dumps(value).lower())

    def test_full_path_queries_one_fixed_kernel_command_then_revalidates_source(self):
        code, value, calls = self.invoke()
        self.assertEqual(code, 0)
        self.assertTrue(value['kernel_start_qualified'])
        self.assertTrue(value['source_unchanged'])
        self.assertTrue(value['kernel_or_container_start_requested'])
        self.assertEqual(value['source_sha'], 'a' * 40)
        self.assertEqual(value['source_tree'], 'b' * 40)
        self.assertEqual(len(calls), 9)
        self.assertEqual(sum(argv[-1] == '-r' for argv, _ in calls), 1)
        self.assertTrue(all(argv[0] == 'git.exe' for argv, _ in calls[-3:]))
        for name in ('docker_linux_mode_qualified', 'chain321_qualified',
                'x64_wallet_qualified', 'distro_install_requested', 'downloads_requested',
                'features_changed', 'reboot_requested', 'wallet_or_node_start_requested',
                'cleanup_performed', 'vm_disposal_qualified'):
            self.assertIs(value[name], False)

    def test_wrong_component_or_failed_status_never_starts_kernel(self):
        for settings in (dict(version=b'WSL version: 2.1.5.0\n'),
                dict(version=b'private metadata'), dict(status=outcome(code=1))):
            with self.subTest(settings=settings):
                code, value, calls = self.invoke(**settings)
                self.assertEqual(code, 1)
                self.assertEqual(value['status'], 'COMPONENT_PREREQUISITE_REFUSED')
                self.assertFalse(value['kernel_query_attempted'])
                self.assertFalse(value['kernel_or_container_start_requested'])
                self.assertTrue(value['source_unchanged'])
                self.assertFalse(any(argv[-1] == '-r' for argv, _ in calls))

    def test_kernel_failure_keeps_original_outcome_without_retry(self):
        code, value, calls = self.invoke(kernel_result=outcome(
            b'HCS_E_HYPERV_NOT_INSTALLED\n', code=1))
        self.assertEqual(code, 1)
        self.assertEqual(value['status'], 'KERNEL_START_UNQUALIFIED')
        self.assertTrue(value['component_prerequisites_observed'])
        self.assertTrue(value['source_unchanged'])
        self.assertEqual(value['kernel']['command']['exit_code'], 1)
        self.assertEqual(sum(argv[-1] == '-r' for argv, _ in calls), 1)

    def test_source_drift_does_not_qualify_an_otherwise_valid_kernel_reply(self):
        code, value, _ = self.invoke(source_drift=True)
        self.assertEqual(code, 1)
        self.assertEqual(value['status'], 'REFUSED_OR_UNKNOWN')
        self.assertEqual(value['stage'], 'source_after')
        self.assertFalse(value['source_unchanged'])
        self.assertFalse(value['kernel_start_qualified'])
        self.assertEqual(value['kernel']['status'], 'VALID_RELEASE_OBSERVED')

    def test_unadmitted_or_private_failure_starts_nothing_and_exports_no_error(self):
        for arguments, private in (([], False), ([], True), (['--other'], False)):
            with self.subTest(arguments=arguments, private=private):
                with (patch.dict(kernel.os.environ, {}, clear=True),
                        patch.object(kernel, 'observe', side_effect=RuntimeError(
                            'private-person private-path')) if private else contextlib.nullcontext(),
                        patch.object(kernel.readiness.bounded, 'run_bounded',
                            side_effect=AssertionError('native forbidden')) as native,
                        contextlib.redirect_stdout(io.StringIO()) as output):
                    self.assertEqual(kernel.main(arguments), 1)
                value = json.loads(output.getvalue().split('::', 2)[2])
                self.assertFalse(value['kernel_start_qualified'])
                self.assertFalse(native.called)
                self.assertNotIn('private', output.getvalue())


if __name__ == '__main__':
    unittest.main()
