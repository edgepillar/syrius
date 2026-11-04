"""Pinned-stream, installation uncertainty and privacy controls; no native work."""

import contextlib
import hashlib
import io
import json
from pathlib import Path
import stat
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tool.ci import windows_wsl_installation as installation


class InstallationControls(unittest.TestCase):
    def facts(self):
        return dict(schema=1, scope='wsl_install_preflight', administrator=True,
            desktop_windows=True, native_arm64=True, virtual_machine_platform_enabled=True,
            wsl_feature_enabled=True, existing_msi_binary=False, store_package_present=False,
            known_windows_reboot_pending=False)

    def receipt(self, code=0, **changes):
        value = dict(exit_code=code, output_complete=True, forced=False,
            streams={name: dict(bytes=0, overflow=False) for name in ('stdout', 'stderr')})
        value.update(changes)
        return value

    def test_preflight_requires_positive_fresh_desktop_and_enabled_features(self):
        self.assertEqual(installation.preflight(self.facts()), self.facts())
        for name, current in self.facts().items():
            if type(current) is bool:
                with self.subTest(name=name):
                    value = self.facts()
                    value[name] = not current
                    with self.assertRaises(installation.Refused):
                        installation.preflight(value)

    def test_unknown_or_extra_preflight_data_is_not_permission_to_install(self):
        for change in (dict(administrator=1), dict(native_arm64=None), dict(extra='private')):
            with self.subTest(fields=list(change)):
                with self.assertRaises(installation.Refused):
                    installation.preflight(dict(self.facts(), **change))

    def test_both_valid_signature_and_microsoft_publisher_are_required(self):
        value = dict(schema=1, scope='wsl_install_signature', valid=True, microsoft_publisher=True)
        self.assertEqual(installation.signature(value), value)
        for name in ('valid', 'microsoft_publisher'):
            for flag in (False, None, 1):
                with self.subTest(name=name, flag=flag):
                    with self.assertRaises(installation.Refused):
                        installation.signature(dict(value, **{name: flag}))

    def test_download_accepts_only_exact_complete_bytes_and_digest(self):
        raw = b'fixed-public-fixture'
        sink = io.BytesIO()
        count = installation.copy_verified(io.BytesIO(raw), sink, len(raw),
            hashlib.sha256(raw).hexdigest(), sample=lambda: None)
        self.assertEqual(count, len(raw))
        self.assertEqual(sink.getvalue(), raw)

    def test_truncated_excess_or_hash_mismatched_download_is_refused(self):
        for raw, size, digest in ((b'abc', 4, hashlib.sha256(b'abc').hexdigest()),
                (b'abcde', 4, hashlib.sha256(b'abcd').hexdigest()),
                (b'abcd', 4, '0' * 64)):
            with self.subTest(size=size, actual=len(raw)):
                with self.assertRaises(installation.Refused):
                    installation.copy_verified(io.BytesIO(raw), io.BytesIO(), size,
                        digest, sample=lambda: None)

    def test_overflow_preserves_actual_received_count_without_writing_excess(self):
        received, sink = [], io.BytesIO()
        with self.assertRaises(installation.Refused):
            installation.copy_verified(io.BytesIO(b'four'), sink, 3, '0' * 64,
                sample=lambda: None, received=received.append)
        self.assertEqual(received, [4])
        self.assertEqual(sink.getvalue(), b'')

    def test_stream_deadline_and_storage_refusal_stop_consumption(self):
        response = io.BytesIO(b'abc')
        with self.assertRaises(installation.Refused):
            installation.copy_verified(response, io.BytesIO(), 3, '0' * 64,
                sample=lambda: None, clock=iter((0, installation.DOWNLOAD_SECONDS)).__next__)
        self.assertEqual(response.tell(), 0)
        def refused():
            raise installation.Refused()
        with self.assertRaises(installation.Refused):
            installation.copy_verified(response, io.BytesIO(), 3, '0' * 64, sample=refused)
        self.assertEqual(response.tell(), 0)

    def verify_memory_package(self, *, replaced=False):
        raw = b'fixed-public-fixture'
        before = SimpleNamespace(st_dev=1, st_ino=2, st_size=len(raw), st_mtime_ns=3,
            st_ctime_ns=4, st_nlink=1, st_mode=stat.S_IFREG)
        after = SimpleNamespace(**dict(vars(before), st_ino=5)) if replaced else before
        class Package(io.BytesIO):
            def fileno(self):
                return 123
        with (patch.object(installation, 'PACKAGE_BYTES', len(raw)),
                patch.object(installation, 'PACKAGE_SHA256', hashlib.sha256(raw).hexdigest()),
                patch.object(installation.readiness.bounded, 'plain', side_effect=[before, after]),
                patch.object(Path, 'open', return_value=Package(raw)),
                patch.object(installation.os, 'fstat', return_value=before)):
            installation.verify_package(Path('fixture.msi'))

    def test_package_is_rehashed_with_stable_file_identity_before_installation(self):
        self.verify_memory_package()

    def test_replaced_verified_package_is_refused_without_installation(self):
        with self.assertRaises(installation.Refused):
            self.verify_memory_package(replaced=True)

    def test_redirects_refuse_credentials_http_other_hosts_ports_and_fragments(self):
        for url in ('http://github.com/file', 'https://example.com/file',
                'https://token@github.com/file', 'https://github.com:444/file',
                'https://github.com/file#fragment', 'https://github.com.evil.invalid/file'):
            with self.subTest(url=url):
                with self.assertRaises(installation.Refused):
                    installation.allowed_url(url)
        installation.allowed_url(installation.PACKAGE_URL)
        installation.allowed_url('https://release-assets.githubusercontent.com/file?signature=fixture')

    def test_normal_success_and_reboot_required_remain_separate(self):
        success = installation.installer_result(self.receipt())
        reboot = installation.installer_result(self.receipt(3010))
        self.assertTrue(success['ready_without_reboot'])
        self.assertTrue(reboot['reported_success'])
        self.assertTrue(reboot['reboot_required'])
        self.assertFalse(reboot['ready_without_reboot'])

    def test_original_command_refusal_prevents_accepting_a_late_zero_exit(self):
        for code in ('COMMAND_TIMEOUT', 'OUTPUT_REFUSED', 'STORAGE_REFUSED',
                     'INSTALL_COMMAND_UNCERTAIN'):
            with self.subTest(code=code):
                value = installation.installer_result(self.receipt(), code)
                self.assertFalse(value['reported_success'])
                self.assertFalse(value['ready_without_reboot'])
        reboot = installation.installer_result(self.receipt(3010), 'COMMAND_FAILED')
        self.assertTrue(reboot['reported_success'])
        self.assertTrue(reboot['reboot_required'])
        self.assertFalse(reboot['ready_without_reboot'])

    def test_forced_incomplete_or_missing_receipt_cannot_qualify_installation(self):
        for receipt in (None, self.receipt(forced=True), self.receipt(output_complete=False)):
            with self.subTest(receipt=receipt):
                value = installation.installer_result(receipt)
                self.assertFalse(value['reported_success'])
                self.assertFalse(value['ready_without_reboot'])
                self.assertIsNone(value['reboot_required'])

    def test_installer_failure_is_not_hidden_by_its_complete_exit(self):
        value = installation.installer_result(self.receipt(1603))
        self.assertEqual(value['exit_code'], 1603)
        self.assertTrue(value['output_complete'])
        self.assertFalse(value['reported_success'])
        self.assertFalse(value['ready_without_reboot'])

    def run_controller(self, *, reboot=False, blocked=False):
        parent = dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
            SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
            GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_INSTALLATION='true',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='123', SYSTEMROOT='system',
            PROGRAMFILES='programs', RUNNER_TEMP='scratch')
        calls, reads, originals = [], [], []
        def command(argv, **kwargs):
            calls.append(argv)
            originals.append(SimpleNamespace(receipt=self.receipt(
                3010 if reboot and argv[0].endswith('msiexec.exe') else 0)))
            if argv[0].endswith('msiexec.exe'):
                if reboot:
                    raise installation.owned.Failure('COMMAND_FAILED')
                return b''
            if env['SYRIUS_WSL_INSTALL_STAGE'] == 'preflight':
                return json.dumps(dict(self.facts(), store_package_present=blocked)).encode()
            return json.dumps(dict(schema=1, scope='wsl_install_signature',
                valid=True, microsoft_publisher=True)).encode()
        def query(argv, **kwargs):
            reads.append(argv)
            output = b''
            if argv[-1] == 'HEAD':
                output = b'a' * 40
            elif argv[-1] == 'HEAD^{tree}':
                output = b'b' * 40
            elif argv[-1] == '--version':
                output = ('WSL version: ' + installation.VERSION + '\n').encode()
            return installation.readiness.bounded.Outcome(output=output,
                exit_code=0, exit_observed=True, output_complete=True, output_bytes=len(output))
        env = {}
        def commands(root, selected):
            env.update(selected)
            # Keep the actual shared child environment as stages change.
            nonlocal_env[0] = selected
            return SimpleNamespace(originals=originals,
                run=lambda argv, **kwargs: command_with_environment(argv, **kwargs))
        nonlocal_env = [env]
        def command_with_environment(argv, **kwargs):
            env.update(nonlocal_env[0])
            return command(argv, **kwargs)
        report = dict(component_version_qualified=False, installation_requested=False,
                      **installation.FALSE_SCOPE)
        with (patch.object(installation.sys, 'platform', 'win32'),
                patch.object(installation.shutil, 'which', return_value='git.exe'),
                patch.object(installation.shutil, 'disk_usage',
                    return_value=SimpleNamespace(free=10 * 1024**3)),
                patch.object(installation.readiness.bounded, 'plain'),
                patch.object(Path, 'is_file', return_value=True),
                patch.object(installation.tempfile, 'mkdtemp', return_value='owned-fixture'),
                patch.object(installation.owned, 'sample_storage', return_value=0),
                patch.object(installation.owned, 'Commands', side_effect=commands),
                patch.object(installation, 'download', return_value=Path('fixture.msi')),
                patch.object(installation, 'verify_package'),
                patch.object(installation.readiness.bounded, 'run_bounded', side_effect=query),
                patch.object(installation.readiness.bounded.subprocess, 'Popen',
                    side_effect=AssertionError('No process'))):
            if blocked:
                with self.assertRaises(installation.Refused):
                    installation.observe(parent, report)
            else:
                installation.observe(parent, report)
        installs = [argv for argv in calls if argv[0].endswith('msiexec.exe')]
        self.assertEqual(len(installs), 0 if blocked else 1)
        if not blocked:
            self.assertEqual(installs[0][1:],
                ['/i', 'fixture.msi', '/qn', '/norestart', 'REBOOT=ReallySuppress'])
        return report, [argv[-1] for argv in reads if argv[0] != 'git.exe']

    def test_real_controller_uses_one_installer_and_fixed_component_queries(self):
        value, queries = self.run_controller()
        self.assertEqual(queries, ['--version', '--status'])
        self.assertEqual(value['status'], 'COMPONENT_VERSION_QUALIFIED')
        self.assertTrue(value['component_version_qualified'])
        self.assertTrue(value['source_unchanged'])
        self.assertFalse(value['kernel_or_container_start_requested'])

    def test_real_controller_does_not_retry_or_query_after_reboot_required(self):
        value, queries = self.run_controller(reboot=True)
        self.assertEqual(queries, [])
        self.assertEqual(value['status'], 'REBOOT_REQUIRED')
        self.assertFalse(value['component_version_qualified'])
        self.assertTrue(value['source_unchanged'])

    def test_finite_negative_preflight_and_original_command_survive_refusal(self):
        value, queries = self.run_controller(blocked=True)
        self.assertEqual(queries, [])
        self.assertTrue(value['preflight']['store_package_present'])
        self.assertFalse(value['installation_requested'])
        self.assertFalse(value['component_version_qualified'])
        self.assertEqual(value['preflight_command']['exit_code'], 0)
        self.assertTrue(value['preflight_command']['output_complete'])
        self.assertFalse(value['preflight_command']['forced'])

    def test_nonhosted_context_refuses_before_files_network_or_processes(self):
        with (patch.object(installation, 'download', side_effect=AssertionError('No download')) as download,
                patch.object(installation.readiness.bounded.subprocess, 'Popen',
                    side_effect=AssertionError('No process')) as process):
            with self.assertRaises(installation.Refused):
                installation.observe({}, {})
            download.assert_not_called()
            process.assert_not_called()

    def test_positive_admission_refuses_replay_other_repo_and_nonwindows(self):
        parent = dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
            SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
            GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_INSTALLATION='true',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='123')
        installation.admit(parent, 'win32')
        for change in (dict(GITHUB_RUN_ATTEMPT='2'), dict(GITHUB_REPOSITORY='other/repo'),
                       dict(SYRIUS_HOSTED_RUNNER='self-hosted'), dict(GITHUB_EVENT_NAME='push')):
            with self.subTest(change=change):
                with self.assertRaises(installation.Refused):
                    installation.admit(dict(parent, **change), 'win32')
        with self.assertRaises(installation.Refused):
            installation.admit(parent, 'darwin')

    def test_package_installation_never_claims_kernel_docker_wallet_or_chain(self):
        self.assertTrue(all(value is False for value in installation.FALSE_SCOPE.values()))
        self.assertFalse(installation.FALSE_SCOPE['kernel_start_qualified'])
        self.assertFalse(installation.FALSE_SCOPE['docker_linux_mode_qualified'])

    def test_private_failure_is_exported_only_as_closed_finite_report(self):
        out = io.StringIO()
        with (patch.object(installation, 'observe', side_effect=RuntimeError('private-path private-person')),
                contextlib.redirect_stdout(out)):
            self.assertEqual(installation.main([]), 1)
        text = out.getvalue()
        self.assertNotIn('private-path', text)
        self.assertNotIn('private-person', text)
        value = json.loads(text.split('::', 2)[2])
        self.assertEqual(value['status'], 'REFUSED_OR_UNKNOWN')
        self.assertFalse(value['component_version_qualified'])

    def test_invalid_environment_run_id_is_not_copied_to_public_output(self):
        out = io.StringIO()
        with (patch.dict(installation.os.environ, {'GITHUB_RUN_ID': 'private-identifier'}),
                patch.object(installation, 'observe', side_effect=installation.Refused()),
                contextlib.redirect_stdout(out)):
            self.assertEqual(installation.main([]), 1)
        self.assertNotIn('private-identifier', out.getvalue())
        value = json.loads(out.getvalue().split('::', 2)[2])
        self.assertIsNone(value['run_id'])
