"""Memory-only admission and finite disclosure checks for the original asset gate."""

import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest import mock

from tool.ci import run_asset_tests as asset


def reply():
    return dict(schema=1, scope='lab_asset_helper_inmemory_cases', success=True,
        cases=4, asset_bytes_equal=True, filesystem_scratch=0, native_wallet_executions=0)


def encoded(value=None):
    return asset.PREFIX + json.dumps(reply() if value is None else value).encode() + b'\n'


class AssetCommandTests(unittest.TestCase):
    def test_unowned_environment_refuses_before_discovery_or_child(self):
        with mock.patch.dict(asset.os.environ, {}, clear=True), \
                mock.patch.object(asset.shutil, 'which') as discover, \
                mock.patch.object(asset.baseline, 'run_bounded') as child, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = asset.main()
        self.assertEqual(result, 1)
        discover.assert_not_called()
        child.assert_not_called()
        value = json.loads(output.getvalue().splitlines()[0])
        self.assertEqual(value['code'], 'ENVIRONMENT_REFUSED')
        self.assertEqual(value['commands'], [])

    def test_only_the_hosted_fork_dispatch_and_workspace_are_admitted(self):
        parent = dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='workflow_dispatch',
            RUNNER_ENVIRONMENT='github-hosted', SYRIUS_HOSTED_RUNNER='github-hosted',
            GITHUB_REPOSITORY='edgepillar/syrius', GITHUB_REF='refs/heads/redesign',
            GITHUB_SHA='a'*40, GITHUB_WORKSPACE='/fixture',
            GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1')
        self.assertEqual(asset.admit(parent, Path('/fixture'))[1], Path('/fixture'))
        for change in (dict(GITHUB_EVENT_NAME='push'), dict(RUNNER_ENVIRONMENT='self-hosted'),
                       dict(GITHUB_REPOSITORY='sol-znn/syrius'), dict(GITHUB_SHA='private'),
                       dict(GITHUB_WORKSPACE='/other'), dict(github_sha='b'*40),
                       dict(GITHUB_RUN_ID='private'), dict(GITHUB_RUN_ATTEMPT='private')):
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, '^ENVIRONMENT_REFUSED$'):
                asset.admit(dict(parent, **change), Path('/fixture'))

    def test_original_finite_result_is_reencoded_without_private_output(self):
        raw = b'synthetic private warning\n' + encoded()
        self.assertEqual(asset.control_reply(raw), reply())
        self.assertNotIn('private', json.dumps(asset.control_reply(raw)))

    def test_extra_duplicate_and_false_result_fields_cannot_pass(self):
        for raw in (encoded() * 2, encoded(dict(reply(), detail='private')),
                    encoded(dict(reply(), success=False)), encoded(dict(reply(), schema=True)),
                    asset.PREFIX + b'{"schema":1,"schema":1}\n', b'private', b'x'*65537):
            with self.subTest(size=len(raw)), self.assertRaisesRegex(ValueError, '^CONTROL_REPLY_REFUSED$'):
                asset.control_reply(raw)

    def test_failure_labels_never_copy_paths_values_or_unknown_error_text(self):
        raw = b'TypeError: synthetic private payload\n at C:/private/lab_asset_progress_test.js:57:4\n'
        self.assertEqual(asset.failure_labels(raw), dict(category='TYPE', source='asset_test', line=57))
        self.assertEqual(asset.failure_labels(b'private unsupported text'),
                         dict(category='UNKNOWN', source=None, line=None))
        self.assertEqual(asset.failure_labels(b'ERR_SCRIPT_EXECUTION_TIMEOUT private'),
                         dict(category='VM_TIMEOUT', source=None, line=None))

    def test_failed_original_command_cannot_be_replaced_by_a_success_notice(self):
        parent = dict(GITHUB_SHA='a'*40, GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1')
        for exit_code, complete, expected in ((1, True, 'CONTROL_FAILED'),
                                               (0, False, 'OUTPUT_REFUSED')):
            version = asset.baseline.Outcome(output=b'v26.5.0\n', exit_code=0,
                exit_observed=True, output_complete=True, output_bytes=8)
            outcome = asset.baseline.Outcome(output=encoded(), exit_code=exit_code,
                exit_observed=True, output_complete=complete, output_bytes=len(encoded()))
            with self.subTest(exit_code=exit_code, complete=complete), \
                    mock.patch.object(asset, 'admit', return_value=(parent, Path('/fixture'))), \
                    mock.patch.object(asset.source.bounded, 'verify_source'), \
                    mock.patch.object(asset.source, 'source_tree', return_value='b'*40), \
                    mock.patch.object(asset.shutil, 'which', return_value='/node'), \
                    mock.patch.object(asset.baseline, 'run_bounded', side_effect=[version, outcome]), \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                result = asset.main()
            self.assertEqual(result, 1)
            value = json.loads(output.getvalue().splitlines()[0])
            self.assertFalse(value['success'])
            self.assertEqual(value['code'], expected)
            self.assertEqual(value['commands'][-1]['exit_code'], exit_code)
            self.assertNotIn(asset.PREFIX.decode(), output.getvalue())

    def test_one_cold_version_observation_stays_bounded_and_never_retries(self):
        parent = dict(GITHUB_SHA='a'*40, GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1')
        for timed_out in (False, True):
            calls = []

            def child(arguments, *, cwd, env, timeout, cap):
                calls.append((arguments, timeout, cap))
                if arguments == ['/node', '--version']:
                    complete = not timed_out and timeout >= 6
                    return asset.baseline.Outcome(
                        output=b'v26.5.0\n' if complete else b'',
                        exit_code=0 if complete else 1, exit_observed=True,
                        forced_kill=not complete, output_complete=True,
                        output_bytes=8 if complete else 0,
                        seconds=6 if complete else timeout,
                        errors=() if complete else ('COMMAND_TIMEOUT',))
                self.assertEqual(arguments, ['/node', 'test/ci/lab_asset_progress_test.js'])
                return asset.baseline.Outcome(output=encoded(), exit_code=0,
                    exit_observed=True, output_complete=True, output_bytes=len(encoded()))

            with self.subTest(timed_out=timed_out), \
                    mock.patch.object(asset, 'admit', return_value=(parent, Path('/fixture'))), \
                    mock.patch.object(asset.source.bounded, 'verify_source'), \
                    mock.patch.object(asset.source, 'source_tree', return_value='b'*40), \
                    mock.patch.object(asset.shutil, 'which', return_value='/node'), \
                    mock.patch.object(asset.baseline, 'run_bounded', side_effect=child), \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                result = asset.main()
            self.assertEqual(result, 1 if timed_out else 0)
            self.assertEqual(calls[0][1:], (15, 256))
            self.assertEqual(sum(arguments == ['/node', '--version']
                for arguments, _, _ in calls), 1)
            value = json.loads(output.getvalue().splitlines()[0])
            if timed_out:
                self.assertEqual(len(calls), 1)
                self.assertEqual(value['code'], 'OUTPUT_REFUSED')
                self.assertFalse(value['success'])
                self.assertTrue(value['commands'][0]['forced_kill'])
                self.assertNotIn(asset.PREFIX.decode(), output.getvalue())
            else:
                self.assertEqual(len(calls), 2)
                self.assertEqual(calls[1][1:], (15, 65536))
                self.assertTrue(value['success'])
                self.assertFalse(value['commands'][0]['forced_kill'])
