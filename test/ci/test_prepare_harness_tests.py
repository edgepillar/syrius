"""Memory-only admission controls; no SDK, native process or scratch is created."""

import contextlib
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest import mock

from tool.ci import prepare_harness_tests as focused


def environment():
    return dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows',
        RUNNER_ENVIRONMENT='github-hosted', GITHUB_EVENT_NAME='workflow_dispatch',
        GITHUB_REPOSITORY='edgepillar/syrius', GITHUB_REF='refs/heads/redesign',
        GITHUB_SHA='a'*40, GITHUB_WORKSPACE='/fixture', SYSTEMROOT='/system',
        GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1',
        SYRIUS_HOSTED_RUNNER='github-hosted', SYRIUS_HARNESS_TESTS_ONLY='true')


class HarnessAdmissionTests(unittest.TestCase):
    def test_known_source_edits_reconstruct_exact_hashes(self):
        name = focused.OBSERVATION_FILES[0]
        before, after = b'class Labels {\n}\n', b'class Labels {\n  String get label;\n}\n'
        row = focused.source_change(name, before, after)
        self.assertEqual(row['edits_status'], 'OBSERVED')
        lines = before.decode().splitlines(keepends=True)
        for edit in reversed(row['edits']):
            start = edit['old_start']
            self.assertEqual(lines[start:start + len(edit['old_lines'])], edit['old_lines'])
            lines[start:start + len(edit['old_lines'])] = edit['new_lines']
        self.assertEqual(''.join(lines).encode(), after)
        self.assertEqual(row['after_sha256'], focused.hashlib.sha256(after).hexdigest())
        self.assertEqual(row['file'], name)

    def test_private_nonascii_and_large_edits_keep_only_hashes(self):
        name = focused.OBSERVATION_FILES[0]
        for after in (b'const path = "C:\\fixture\\private";\n',
                      b'Bearer private-value\n', 'private \u00e9\n'.encode()):
            row = focused.source_change(name, b'old\n', after)
            self.assertEqual(row['edits_status'], 'OMITTED_UNSAFE')
            self.assertEqual(row['edits'], [])
            self.assertNotIn('private', json.dumps(row))
        row = focused.source_change(name, b'old\n', b'x' * 2500)
        self.assertEqual(row['edits_status'], 'OMITTED_BUDGET')
        self.assertEqual(row['edits'], [])

    def test_unknown_names_types_and_source_size_refuse(self):
        for name in ('/fixture/private.dart', '../private.dart', 'lib/main.dart'):
            with self.assertRaisesRegex(ValueError, 'UNAPPROVED_SOURCE_FILE'):
                focused.source_change(name, b'old', b'new')
        for value in ('private', b'x' * (1024**2 + 1)):
            with self.assertRaisesRegex(ValueError, 'SOURCE_OBSERVATION_REFUSED'):
                focused.source_change(focused.OBSERVATION_FILES[0], b'old', value)

    def test_git_observation_preserves_dirty_state_and_hides_unknown_names(self):
        name = focused.OBSERVATION_FILES[0]
        def outcome(raw, code=0):
            return SimpleNamespace(output=raw, exit_code=code,
                transport_complete=True, public=lambda: dict(exit_code=code,
                    output_complete=True, forced_kill=False, output_overflow=False))
        outputs = [outcome(b'a'*40+b'\n'), outcome(b'b'*40+b'\r\n'),
                   outcome(b'', 1), outcome(b''),
                   outcome(name.encode()+b'\0C:/fixture/private\0')]
        parent = dict(environment(), GIT_CONFIG_COUNT='1')
        with mock.patch.object(focused.baseline, 'run_bounded', side_effect=outputs) as child, \
                mock.patch.object(focused, 'capture_observation_sources', return_value={name: b'new\n'}):
            value = focused.observe_source_refusal(Path('/fixture'), parent,
                'a'*40, 'b'*40, {name: b'old\n'})
        self.assertEqual(value['status'], 'OBSERVED')
        self.assertEqual(value['checks'], dict(head_matches=True, tree_matches=True,
            worktree_matches=False, index_matches=True))
        self.assertEqual(value['other_tracked_changes'], 1)
        self.assertEqual([row['file'] for row in value['files']], [name])
        self.assertNotIn('private', json.dumps(value))
        self.assertEqual(child.call_count, 5)
        self.assertEqual([c.kwargs['cap'] for c in child.call_args_list],
                         [128, 128, 4096, 4096, 16384])
        for call in child.call_args_list:
            self.assertEqual(call.kwargs['timeout'], 10)
            self.assertNotIn('GIT_CONFIG_COUNT', call.kwargs['env'])
            self.assertEqual(call.kwargs['env']['GIT_CONFIG_GLOBAL'], focused.os.devnull)

    def test_post_restore_refusal_keeps_failure_and_never_continues(self):
        parent = dict(environment(), FLUTTER_ROOT='/sdk')
        admitted = parent, 'a' * 40, Path('/fixture')
        def outcome(raw):
            return SimpleNamespace(output=raw, success=True,
                transport_complete=True, public=lambda: dict(exit_code=0,
                    exit_observed=True, output_complete=True, forced_kill=False,
                    output_overflow=False, output_bytes=len(raw), seconds=0.01,
                    success=True, error_codes=[]))
        observation = dict(status='OBSERVED', checks=dict(head_matches=False),
            commands=[], other_tracked_changes=0,
            files=[focused.source_change(name, b'old\n', b'new\n')
                   for name in focused.OBSERVATION_FILES])
        with mock.patch.object(focused, 'admit', return_value=admitted), \
                mock.patch.object(focused.debug.bounded, 'verify_source',
                    side_effect=[None, focused.debug.ProcessRefused('SOURCE_REFUSED')]), \
                mock.patch.object(focused.debug.entry, 'source_tree', return_value='b'*40) as tree, \
                mock.patch.object(focused, 'no_native_allocations', return_value=True), \
                mock.patch.object(focused, 'input_digest', return_value='fixed'), \
                mock.patch.object(focused, 'capture_observation_sources', return_value={}), \
                mock.patch.object(focused, 'observe_source_refusal', return_value=observation), \
                mock.patch.object(focused.shutil, 'disk_usage', return_value=SimpleNamespace(free=100*1024**3)), \
                mock.patch.object(focused.shutil, 'which', return_value='git'), \
                mock.patch.object(focused.debug, 'sdk', return_value=(Path('/sdk/dart'), Path('/sdk/snapshot'))), \
                mock.patch.object(focused.baseline, 'fresh_environment', return_value={}), \
                mock.patch.object(focused.baseline, 'run_bounded', side_effect=[
                    outcome((focused.SDK+'\n').encode()), outcome(b'app'), outcome(b'vendor')]) as child, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = focused.main([])
        value = json.loads(output.getvalue().splitlines()[0])
        self.assertEqual(result, 1)
        self.assertFalse(value['success'])
        self.assertEqual(value['code'], 'SOURCE_REFUSED')
        self.assertEqual(value['phase'], 'verify_head_after_restore')
        self.assertEqual(value['source_observation'], observation)
        self.assertTrue(value['locked_inputs_digest_unchanged'])
        self.assertEqual(child.call_count, 3)
        self.assertEqual(tree.call_count, 1)
        notices = [line.split('::', 2)[2] for line in output.getvalue().splitlines()
                   if line.startswith('::notice')]
        self.assertLessEqual(len(notices), 10)
        self.assertTrue(all(len(v.encode()) <= 3800 for v in notices))
        frames = [json.loads(v) for v in notices]
        header = next(v for v in frames if v['scope']=='focused_restore_source_observation')
        self.assertEqual(header['original_code'], 'SOURCE_REFUSED')
        self.assertFalse(header['original_success'])
        self.assertEqual(header['known_changed_files'], 14)
        self.assertEqual(header['files_without_notice'], 6)
        self.assertEqual(sum(v['scope']=='focused_restore_file_change' for v in frames), 8)

    def test_unowned_environment_refuses_before_any_profile_sdk_or_child(self):
        with mock.patch.dict(focused.os.environ, {}, clear=True), \
                mock.patch.object(focused.debug, 'sdk') as sdk, \
                mock.patch.object(focused.baseline, 'fresh_environment') as profile, \
                mock.patch.object(focused.baseline, 'run_bounded') as child, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = focused.main([])
        self.assertEqual(result, 1)
        sdk.assert_not_called()
        profile.assert_not_called()
        child.assert_not_called()
        self.assertEqual(json.loads(output.getvalue().splitlines()[0])['code'],
                         'ENVIRONMENT_REFUSED')

    def test_only_the_explicit_hosted_fork_branch_is_admitted(self):
        _, source, repo = focused.admit(environment(), platform='nt', cwd=Path('/fixture'))
        self.assertEqual(source, 'a'*40)
        self.assertEqual(repo, Path('/fixture'))
        for change in (dict(GITHUB_EVENT_NAME='push'), dict(SYRIUS_HARNESS_TESTS_ONLY='false'),
                       dict(SYRIUS_WINDOWS_WALLET_TOUR='true'), dict(GITHUB_REF='refs/heads/dev'),
                       dict(GITHUB_REPOSITORY='sol-znn/syrius'),
                       dict(SYRIUS_HOSTED_RUNNER='self-hosted')):
            with self.subTest(change=change):
                with self.assertRaises(Exception) as refused:
                    focused.admit(dict(environment(), **change), platform='nt', cwd=Path('/fixture'))
                self.assertEqual(getattr(refused.exception, 'code', None) or str(refused.exception),
                                 'ENVIRONMENT_REFUSED')

    def test_wrong_platform_or_workspace_refuses(self):
        for platform, cwd in (('posix', '/fixture'), ('nt', '/other')):
            with self.subTest(platform=platform, cwd=cwd):
                with self.assertRaises(Exception) as refused:
                    focused.admit(environment(), platform=platform, cwd=Path(cwd))
                self.assertEqual(getattr(refused.exception, 'code', None) or str(refused.exception),
                                 'ENVIRONMENT_REFUSED')

    def test_admission_only_checks_source_without_sdk_profile_or_dependency_commands(self):
        admitted = environment(), 'a'*40, Path('/fixture')
        with mock.patch.object(focused, 'admit', return_value=admitted), \
                mock.patch.object(focused.debug.bounded, 'verify_source') as source, \
                mock.patch.object(focused.debug.entry, 'source_tree', return_value='b'*40), \
                mock.patch.object(focused, 'no_native_allocations', return_value=True), \
                mock.patch.object(focused.debug, 'sdk') as sdk, \
                mock.patch.object(focused.baseline, 'fresh_environment') as profile, \
                mock.patch.object(focused.baseline, 'run_bounded') as child, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = focused.main(['--admission-only'])
        self.assertEqual(result, 0)
        source.assert_called_once()
        sdk.assert_not_called()
        profile.assert_not_called()
        child.assert_not_called()
        value = json.loads(output.getvalue().splitlines()[0])
        self.assertTrue(value['success'])
        self.assertEqual(value['source_sha'], 'a'*40)
        self.assertEqual(value['native_wallet_executions'], 0)
        self.assertEqual(value['commands'], [])

    def test_native_destination_presence_is_not_a_dependency_restore(self):
        with mock.patch.object(Path, 'exists', return_value=False), \
                mock.patch.object(Path, 'is_symlink', return_value=False):
            self.assertTrue(focused.no_native_allocations(Path('/fixture')))
        for method in ('exists', 'is_symlink'):
            with mock.patch.object(Path, 'exists', return_value=False), \
                    mock.patch.object(Path, 'is_symlink', return_value=False), \
                    mock.patch.object(Path, method, return_value=True):
                self.assertFalse(focused.no_native_allocations(Path('/fixture')))
