"""No native wallet, node, filesystem scratch, network or real input is used."""

import contextlib
import copy
import io
import json
from pathlib import Path
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab
from tool.ci import windows_wallet_tour as tour


def receipt():
    return dict(schema=1, scope='wallet_page_tour', complete=True,
        requested=list(tour.PAGES), visited=[dict(page=page, nodes=20,
            error_widgets=0, severe_logs=0, captured=True) for page in tour.PAGES])


class AdmissionTests(unittest.TestCase):
    def test_hosted_native_admission_is_checked_before_storage_allocation(self):
        parent = dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='workflow_dispatch',
            SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_SHA='a'*40, SYRIUS_WINDOWS_WALLET_TOUR='true',
            SYRIUS_LAB_NODE_SOURCE='lab-fix', SYRIUS_NATIVE_STACK_DIAGNOSTIC='true')
        with mock.patch.object(lab.sys, 'platform', 'win32'):
            self.assertTrue(lab.require_environment('native', parent))
            for field, value in (('SYRIUS_HOSTED_RUNNER', 'self-hosted'),
                                 ('GITHUB_EVENT_NAME', 'push')):
                with self.subTest(field=field), self.assertRaises(lab.Failure):
                    lab.require_environment('native', dict(parent, **{field: value}))

    def test_node_only_default_does_not_admit_a_wallet(self):
        self.assertFalse(lab.wallet_tour_requested('native', {}))
        self.assertFalse(lab.wallet_tour_requested('docker', {}))

    def test_wallet_requires_explicit_corrected_native_lab_and_original_role_diagnostics(self):
        parent = dict(SYRIUS_WINDOWS_WALLET_TOUR='true', SYRIUS_LAB_NODE_SOURCE='lab-fix',
                      SYRIUS_NATIVE_STACK_DIAGNOSTIC='true')
        self.assertTrue(lab.wallet_tour_requested('native', parent))
        for backend, change in (('docker', {}), ('native', dict(SYRIUS_LAB_NODE_SOURCE='original')),
                               ('native', dict(SYRIUS_NATIVE_STACK_DIAGNOSTIC='false')),
                               ('native', dict(SYRIUS_WINDOWS_WALLET_TOUR='TRUE'))):
            with self.subTest(backend=backend, change=change), self.assertRaises(lab.Failure):
                lab.wallet_tour_requested(backend, dict(parent, **change))

    def test_an_unowned_local_environment_refuses_before_a_process_or_profile(self):
        with mock.patch.object(tour.subprocess, 'Popen') as launch, \
                mock.patch.object(tour.debug.entry, 'private_root') as profile, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            value = tour.run(Path('/fixture'), {}, mock.Mock(), Path('/fixture/lab'), {}, mock.Mock())
        launch.assert_not_called()
        profile.assert_not_called()
        self.assertFalse(value['success'])
        self.assertEqual(value['errors'], ['ENVIRONMENT_REFUSED'])
        self.assertNotIn('/fixture', output.getvalue())


class FixtureTests(unittest.TestCase):
    def test_only_one_explicit_fenced_public_fixture_is_selected(self):
        for count in (12, 24):
            words = ' '.join(['synthetic'] * count)
            self.assertEqual(tour.public_fixture('public example\n```\n' + words + '\n```\n'), words)

    def test_missing_unfenced_ambiguous_or_oversized_input_is_refused(self):
        words = ' '.join(['synthetic'] * 12)
        fence = '```\n' + words + '\n```\n'
        for text in ('', words, fence * 2, fence.upper(), 'x' * 65537):
            with self.subTest(length=len(text)), self.assertRaises(tour.Refused):
                tour.public_fixture(text)


class CoverageTests(unittest.TestCase):
    def test_complete_original_order_is_required(self):
        value = receipt()
        self.assertTrue(tour.tour_complete(tour.tour_receipt(value)))
        for change in ('missing', 'duplicate', 'unknown', 'extra'):
            value = receipt()
            if change == 'missing':value['requested'].pop()
            elif change == 'duplicate':value['visited'][1] = value['visited'][0]
            elif change == 'unknown':value['visited'][0]['page'] = 'private-page'
            else:value['visited'][0]['private'] = 'private-context'
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.tour_receipt(value)

    def test_partial_coverage_retains_finite_failure_counts_without_completing(self):
        value = receipt();value['complete'] = False;value['visited'] = value['visited'][:2]
        value['visited'][1].update(severe_logs=1, captured=False)
        self.assertIs(tour.tour_receipt(value), value)
        self.assertFalse(tour.tour_complete(value))

    def test_boolean_counts_or_capture_claims_cannot_substitute_for_observations(self):
        for key, offered in (('nodes', True), ('severe_logs', -1), ('captured', 1)):
            value = receipt();value['visited'][0][key] = offered
            with self.subTest(key=key), self.assertRaises(tour.Refused):
                tour.tour_receipt(value)

    def test_widget_log_or_capture_failure_cannot_be_overridden_by_complete(self):
        for key, offered in (('error_widgets', 1), ('severe_logs', 1), ('captured', False)):
            value = receipt();value['visited'][0][key] = offered
            with self.subTest(key=key):
                self.assertFalse(tour.tour_complete(tour.tour_receipt(value)))


class CompletionTests(unittest.TestCase):
    def report(self):
        return dict(checks=dict.fromkeys(tour.CHECKS, True), errors=[],
            application_exit=0, entry_exit=0, owned_job_active_at_close=0,
            entry_output=dict(output_complete=True, overflow=False),
            required_actor_forced_cleanup=False, forced_cleanup=False,
            auxiliary_cleanup=dict(scope=tour.debug.HELPER_SCOPE, status='PASSED', code=None,
                forced=False, remaining=0, receipts=[]), tour=receipt(),
            captures=[dict(page=page, bytes=1024, sha256='a'*64, width=1280, height=780)
                for page in tour.PAGES])

    def test_all_original_exits_and_complete_output_are_required(self):
        self.assertTrue(tour.completed(self.report()))
        for key in ('application_exit', 'entry_exit', 'owned_job_active_at_close'):
            for value in (None, False, 1):
                report = self.report();report[key] = value
                with self.subTest(key=key, value=value):self.assertFalse(tour.completed(report))
        report = self.report();report['entry_output']['output_complete'] = False
        self.assertFalse(tour.completed(report))

    def test_helper_receipts_cannot_heal_an_error_or_forced_required_actor(self):
        for change in ('error', 'forced', 'helper', 'capture', 'check'):
            report = self.report()
            if change == 'error':report['errors'] = ['ENTRY_FAILED']
            elif change == 'forced':report['required_actor_forced_cleanup'] = True
            elif change == 'helper':report['auxiliary_cleanup']['status'] = 'FAILED'
            elif change == 'capture':report['captures'].pop()
            else:report['checks']['lab_revalidated'] = False
            with self.subTest(change=change):self.assertFalse(tour.completed(report))

    def test_duplicate_or_changed_capture_records_prevent_completion(self):
        for change in ('duplicate', 'digest', 'dimensions', 'bytes'):
            report = self.report()
            if change == 'duplicate':report['captures'][1] = copy.deepcopy(report['captures'][0])
            elif change == 'digest':report['captures'][0]['sha256'] = 'private-detail'
            elif change == 'dimensions':report['captures'][0]['width'] = 1200
            else:report['captures'][0]['bytes'] = True
            with self.subTest(change=change):self.assertFalse(tour.completed(report))


if __name__ == '__main__':
    unittest.main()
