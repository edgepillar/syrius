"""No native wallet, node, filesystem scratch, network or real input is used."""

import contextlib
import copy
import io
import json
import re
from pathlib import Path, PureWindowsPath
import stat
import sys
import types
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab
from tool.ci import windows_wallet_tour as tour
from tool.ci import run_wallet_tour_tests
from tool.ci import run_harness_tour_tests as harness


def receipt():
    return dict(schema=1, scope='wallet_page_tour', complete=True,
        requested=list(tour.PAGES), visited=[dict(page=page, nodes=20,
            error_widgets=0, severe_logs=0, captured=True) for page in tour.PAGES])


class AdmissionTests(unittest.TestCase):
    def test_full_controller_fixtures_refuse_local_execution_before_discovery(self):
        with mock.patch.object(sys, 'argv', ['policy-tests', '--all-controllers']), \
                mock.patch.dict(tour.os.environ, {}, clear=True), \
                mock.patch.object(unittest.TestLoader, 'discover') as discover, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = run_wallet_tour_tests.main()
        self.assertEqual(result, 1)
        discover.assert_not_called()
        self.assertEqual(json.loads(output.getvalue())['code'], 'ENVIRONMENT_REFUSED')

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


class AddressSelectionTests(unittest.TestCase):
    def test_preparation_receipt_accepts_only_finite_index_one_facts(self):
        for generated in (False, True):
            value = dict(index=1, members=2, generated=generated,
                         selected=True, persisted=True)
            self.assertEqual(tour.address_selection_receipt(value), value)
            for field in ('address', 'walletPath', 'members_raw', 'diagnostic'):
                with self.subTest(field=field), self.assertRaises(tour.Refused):
                    tour.address_selection_receipt(dict(value, **{field: 'private'}))

    def test_unconfirmed_or_malformed_selection_is_never_preparation_success(self):
        value = dict(index=1, members=2, generated=True, selected=True, persisted=True)
        for field, wrong in (('index', True), ('index', 0), ('members', True),
                             ('members', 1), ('members', 129), ('generated', 1),
                             ('selected', False), ('persisted', False)):
            with self.subTest(field=field, wrong=wrong), self.assertRaises(tour.Refused):
                tour.address_selection_receipt(dict(value, **{field: wrong}))
        for offered in (None, {}, dict(value, selected='true')):
            with self.assertRaises(tour.Refused):
                tour.address_selection_receipt(offered)

    def test_selection_failures_keep_fixed_labels_without_member_material(self):
        value = dict(stage='address_selection', code='wallet-recipe-command-refused',
            diagnostic=dict(action='tap', control='addresses_select',
                reason='wallet-recipe-original-address-context-changed'))
        self.assertEqual(tour.entry_failure(value), value)
        for field in ('address', 'members', 'saved', 'revision', 'private'):
            with self.subTest(field=field), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value,
                    diagnostic=dict(value['diagnostic'], **{field: 'private'})))


class LabSendDiagnosticTests(unittest.TestCase):
    def test_fixed_labels_are_accepted_only_in_the_original_send_stage(self):
        for phase in tour.lab_send_diagnostic.PHASES:
            value = dict(stage='lab_send', code=None, diagnostic=dict(
                phase=phase, reason='owned-isolated-profile-required'))
            self.assertIs(tour.entry_failure(value), value)
            with self.subTest(phase=phase), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value, stage='onboarding'))
        self.assertEqual(tour.entry_failure(dict(stage='lab_send', code=None)),
                         dict(stage='lab_send', code=None))

    def test_private_unknown_or_coerced_labels_are_refused(self):
        base = dict(phase='profile', reason='owned-isolated-profile-required')
        for change in (dict(phase='/fixture/private'), dict(reason='private'),
                       dict(phase=True), dict(reason=321), dict(hash='private'),
                       dict(address='private'), dict(confirmed=True), dict(retry=True)):
            value = dict(stage='lab_send', code=None, diagnostic=dict(base, **change))
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.entry_failure(value)

    def test_a_refusal_diagnostic_never_establishes_success_or_closure(self):
        value = dict(stage='lab_send', code=None,
            diagnostic=dict(phase='confirmation', reason='original-outcome-unknown'))
        self.assertIs(tour.entry_failure(value), value)
        report = CompletionTests().report()
        report['entry_exit'] = 1
        report['entry_failure'] = value
        report['lab_send'] = None
        self.assertFalse(tour.completed(report))
        for extra in (dict(hash='private'), dict(code='private-message')):
            with self.subTest(extra=extra), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value, **extra))

    def test_dart_and_controller_closed_vocabularies_are_equal(self):
        source = (Path(__file__).absolute().parents[2] /
                  'harness/lab_send_failure.dart').read_text(encoding='utf-8')
        for name, expected in (('Phases', tour.lab_send_diagnostic.PHASES),
                               ('Reasons', tour.lab_send_diagnostic.REASONS)):
            match = re.search(r'const Set<String> labSendFailure' + name +
                              r' = <String>\{(.*?)\};', source, re.S)
            self.assertIsNotNone(match)
            actual = re.findall(r"'([a-z0-9_-]+)'", match[1])
            self.assertEqual(set(actual), expected)
            self.assertEqual(len(actual), len(expected))


class StartupVocabularyTests(unittest.TestCase):
    def test_original_startup_vocabularies_match_the_dart_producer(self):
        source = Path('harness/wallet_recipe_failure.dart').read_text()
        for dart, expected in (
                ('walletRecipeFailureCodes', tour.RECIPE_FAILURE_CODES),
                ('walletRecipeEntryPhases', tour.RECIPE_ENTRY_PHASES),
                ('walletRecipeStartupHandoffs', tour.RECIPE_STARTUP_HANDOFFS),
                ('walletRecipeStartupFilmStates', tour.RECIPE_STARTUP_FILM_STATES)):
            match = re.search(r'const Set<String> ' + dart
                + r' = <String>\{(.*?)\};', source, re.S)
            self.assertIsNotNone(match)
            values = re.findall(r"'([a-z0-9_-]+)'", match[1])
            self.assertEqual(set(values), expected)
            self.assertEqual(len(values), len(expected))


class OriginalSendTests(unittest.TestCase):
    @staticmethod
    def receipt():
        return dict(schema=1, scope='original_lab_ui_send', chain=321,
            from_index=1, to_index=0, amount='100000000', token='ZNN',
            original_request=True, confirmed=True)

    def test_only_exact_fixed_original_send_facts_are_retained(self):
        value = self.receipt()
        self.assertIs(tour.lab_send_receipt(value), value)
        for field in ('hash', 'from', 'to', 'walletPath', 'diagnostic'):
            with self.subTest(field=field), self.assertRaises(tour.Refused):
                tour.lab_send_receipt(dict(value, **{field:'private'}))

    def test_unknown_or_unconfirmed_send_never_becomes_positive(self):
        for field, wrong in (('schema', True), ('chain', 321.0),
                ('from_index', True), ('to_index', False), ('amount', 100000000),
                ('token', 'QSR'), ('original_request', False), ('confirmed', False)):
            with self.subTest(field=field), self.assertRaises(tour.Refused):
                tour.lab_send_receipt(dict(self.receipt(), **{field:wrong}))

    def test_missing_or_extra_fields_are_not_original_send_evidence(self):
        for value in (None, {}, [], dict(self.receipt(), confirmed=1)):
            with self.assertRaises(tour.Refused):
                tour.lab_send_receipt(value)
        for field in self.receipt():
            value = self.receipt();del value[field]
            with self.subTest(field=field), self.assertRaises(tour.Refused):
                tour.lab_send_receipt(value)

    def test_present_send_scope_is_mandatory_without_changing_legacy_scope(self):
        report = CompletionTests().report()
        self.assertTrue(tour.completed(report))
        for value in (None, {}, dict(self.receipt(), confirmed=False)):
            self.assertFalse(tour.completed(dict(report, lab_send=value)))
        self.assertTrue(tour.completed(dict(report, lab_send=self.receipt())))
        report['entry_exit'] = 1
        self.assertFalse(tour.completed(dict(report, lab_send=self.receipt())))

    def test_send_stage_keeps_only_the_fixed_failure_label(self):
        value = dict(stage='lab_send', code=None)
        self.assertIs(tour.entry_failure(value), value)
        with self.assertRaises(tour.Refused):
            tour.entry_failure(dict(value, hash='private'))


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


class DiagnosticTests(unittest.TestCase):
    def test_control_change_labels_refuse_geometry_or_private_reply_fields(self):
        value = dict(stage='onboarding', code='wallet-recipe-command-refused',
            diagnostic=dict(action='tap', control='node_settings_chain_toggle',
                reason='wallet-recipe-original-control-changed'))
        for reason in ('wallet-recipe-original-control-changed',
                       'wallet-recipe-original-control-replaced',
                       'wallet-recipe-original-control-moved',
                       'wallet-recipe-original-control-moved-subpixel',
                       'wallet-recipe-original-control-resized'):
            offered = dict(value, diagnostic=dict(value['diagnostic'], reason=reason))
            self.assertEqual(tour.entry_failure(offered), offered)
            for field in ('rect', 'center', 'dx', 'dy', 'element', 'detail'):
                with self.subTest(reason=reason, field=field), self.assertRaises(tour.Refused):
                    tour.entry_failure(dict(offered,
                        diagnostic=dict(offered['diagnostic'], **{field: 'private'})))
        with self.assertRaises(tour.Refused):
            tour.entry_failure(dict(value,
                diagnostic=dict(value['diagnostic'], reason='private geometry')))

    def test_film_observation_accepts_only_fixed_labels_without_private_fields(self):
        value = dict(stage='onboarding', code='wallet-recipe-stage-unsettled',
            diagnostic=dict(action='observe', control='welcome_import',
                reason='wallet-recipe-control-absent', entry='startup-before-initialization',
                startup='key-confirmed'))
        for film in tour.RECIPE_STARTUP_FILM_STATES:
            offered = dict(value, diagnostic=dict(value['diagnostic'], film=film))
            self.assertEqual(tour.entry_failure(offered), offered)
        for change in (dict(film='synthetic private asset'), dict(film=1),
                       dict(film=True), dict(film=None), dict(asset='private'),
                       dict(frame=1), dict(path='private')):
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value, diagnostic=dict(value['diagnostic'], **change)))

    def test_startup_handoff_retains_only_fixed_original_decisions(self):
        value = dict(stage='onboarding', code='wallet-recipe-stage-unsettled',
            diagnostic=dict(action='observe', control='welcome_import',
                reason='wallet-recipe-control-absent', entry='startup-before-initialization'))
        for handoff in tour.RECIPE_STARTUP_HANDOFFS:
            traced = dict(value, diagnostic=dict(value['diagnostic'], startup=handoff))
            self.assertEqual(tour.entry_failure(traced), traced)
        for handoff in ('synthetic private input', 'space', True, None):
            with self.subTest(handoff=handoff), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value, diagnostic=dict(value['diagnostic'], startup=handoff)))

    def test_startup_key_labels_cannot_add_key_text_or_private_fields(self):
        value = dict(stage='onboarding', code='wallet-recipe-command-refused',
            diagnostic=dict(action='key', control='launch_skip_hint',
                reason='wallet-recipe-original-owner-changed'))
        self.assertEqual(tour.entry_failure(value), value)
        for change in (dict(control='space'), dict(key='space'), dict(value='private')):
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value,diagnostic=dict(value['diagnostic'],**change)))

    def test_fixed_onboarding_labels_preserve_the_original_failure(self):
        legacy = dict(stage='onboarding', code='wallet-recipe-command-refused')
        self.assertEqual(tour.entry_failure(legacy), legacy)
        value = dict(legacy, diagnostic=dict(action='type', control='import_seed_field',
            reason='wallet-recipe-original-owner-changed'))
        self.assertEqual(tour.entry_failure(value), value)
        waiting = dict(stage='onboarding', code='wallet-recipe-stage-unsettled',
            diagnostic=dict(action='observe',control='welcome_import',
                reason='wallet-recipe-control-absent'))
        self.assertEqual(tour.entry_failure(waiting),waiting)
        self.assertEqual(tour.entry_failure(dict(waiting,diagnostic=dict(
            waiting['diagnostic'],entry='startup-platform-error')))['diagnostic']['entry'],
            'startup-platform-error')
        self.assertEqual(tour.entry_failure(dict(stage='build',code=None)),dict(stage='build',code=None))

    def test_private_fields_dynamic_controls_and_unknown_labels_are_refused(self):
        value = dict(stage='onboarding', code='wallet-recipe-command-refused',
            diagnostic=dict(action='tap',control='node_settings_select',
                reason='wallet-recipe-selection-origin-refused'))
        changes = [dict(action='/private/action'), dict(control='node_settings_select_wss://private.invalid'),
                   dict(reason='wallet-recipe-private-value'), dict(detail='private payload'),
                   dict(entry='private payload'), dict(action=True)]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value,diagnostic=dict(value['diagnostic'],**change)))
        for change in (dict(stage='tour'),dict(code=None),dict(detail='private payload')):
            with self.subTest(change=change), self.assertRaises(tour.Refused):
                tour.entry_failure(dict(value,**change))


class StartupTests(unittest.TestCase):
    def check(self, *, remaining=0, marker=True):
        events = []
        process = mock.Mock()
        process.poll.return_value = 0
        process.wait.return_value = 0
        process.stdin = io.BytesIO()
        job = mock.Mock(active_at_close=remaining, forced=bool(remaining))
        job.assign.side_effect = lambda original: events.append(
            ('assigned', original is process, process.stdin.getvalue()))
        lines = mock.Mock(complete=True)
        offered = [b'CI_WALLET_STAGE:gate\n']
        if marker:
            offered.append(b'CI_WALLET_GATE_PASSED\n')
        lines.items.empty.side_effect = lambda: not offered
        lines.take.side_effect = lambda _: offered.pop(0)
        lines.finish.return_value = True
        lines.public.return_value = dict(bytes=50, sha256='a' * 64,
            output_complete=True, overflow=False)
        with mock.patch.object(harness, 'fresh_environment', return_value={}), \
                mock.patch.object(Path, 'exists', return_value=False), \
                mock.patch.object(Path, 'is_symlink', return_value=False), \
                mock.patch.object(harness.debug, 'WindowsJob', return_value=job), \
                mock.patch.object(harness.subprocess, 'Popen', return_value=process), \
                mock.patch.object(harness.debug, 'Lines', return_value=lines):
            value = harness.startup_check(Path('/fixture'), {}, Path('/sdk/dart'), 'gate')
        self.assertEqual(events, [('assigned', True, b'')])
        self.assertTrue(process.stdin.closed)
        process.kill.assert_not_called()
        return value

    def test_queued_markers_and_original_exit_pass_with_controller_input_open(self):
        value = self.check()
        self.assertTrue(value['passed'])
        self.assertTrue(value['stdin_open_at_exit'])
        self.assertEqual(value['actual_exit'], 0)

    def test_markers_or_zero_exit_cannot_heal_missing_proof_or_forced_members(self):
        for change in (dict(marker=False), dict(remaining=1)):
            with self.subTest(change=change):
                self.assertFalse(self.check(**change)['passed'])

    def test_local_wrapper_admission_refuses_before_sdk_or_profile_creation(self):
        with mock.patch.dict(harness.os.environ, {}, clear=True), \
                mock.patch.object(harness.debug, 'sdk') as sdk, \
                mock.patch.object(harness, 'fresh_environment') as profile, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            result = harness.main()
        sdk.assert_not_called()
        profile.assert_not_called()
        self.assertEqual(result, 1)
        self.assertEqual(json.loads(output.getvalue().splitlines()[0])['code'],
                         'ENVIRONMENT_REFUSED')


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


class StorageTests(unittest.TestCase):
    @staticmethod
    def plain_info(identifier, *, device=1, attributes=0):
        return types.SimpleNamespace(st_dev=device, st_ino=identifier, st_mode=stat.S_IFDIR,
            st_size=0, st_mtime_ns=1, st_file_attributes=attributes,
            st_reparse_tag=0xA0000003 if attributes else 0)

    def test_profile_target_requires_the_original_root_and_plain_same_volume_chain(self):
        root = PureWindowsPath('C:/synthetic-profile')
        target = root / 'AppData/Local/Microsoft'
        info = self.plain_info(10)
        expected = tour.directory_identity(info)
        observed = {root:info}
        for index in range(1, 4):
            observed[root.joinpath(*target.relative_to(root).parts[:index])] = self.plain_info(10+index)
        with mock.patch.object(tour.os, 'lstat', side_effect=lambda path: observed[path]):
            self.assertTrue(tour.plain_profile_target(root, str(target), expected))
            observed[root] = self.plain_info(99)
            self.assertFalse(tour.plain_profile_target(root, str(target), expected))

    def test_reparse_ancestor_or_cross_volume_target_is_not_followed(self):
        root = PureWindowsPath('C:/synthetic-profile')
        parent, target = root / 'AppData', root / 'AppData/Local'
        expected = tour.directory_identity(self.plain_info(10))
        for attributes, device in ((0x400, 1), (0, 2)):
            calls = []
            def info(path):
                calls.append(path)
                return self.plain_info(10) if path == root else self.plain_info(11, device=device, attributes=attributes)
            with self.subTest(attributes=attributes, device=device), \
                    mock.patch.object(tour.os, 'lstat', side_effect=info):
                self.assertFalse(tour.plain_profile_target(root, str(target), expected))
            self.assertEqual(calls, [root, parent])
        with mock.patch.object(tour.os,'lstat') as query:
            self.assertFalse(tour.plain_profile_target(root,str(root/'../external'),expected))
        query.assert_not_called()

    def test_changed_canonical_directory_identity_stays_unverified(self):
        root = PureWindowsPath('C:/synthetic-profile')
        target = root / 'AppData'
        root_info = self.plain_info(10)
        with mock.patch.object(tour.os, 'lstat', side_effect=[root_info,self.plain_info(11),self.plain_info(12)]):
            self.assertFalse(tour.plain_profile_target(root, str(target), tour.directory_identity(root_info)))

    def test_verified_internal_junction_counts_metadata_without_another_walk(self):
        root, alias, file = self.path(mode=stat.S_IFDIR), self.path(mode=stat.S_IFDIR, attributes=0x400), self.path(10)
        root.lstat.return_value = self.plain_info(10)
        root.iterdir.return_value = [file, alias]
        observed = dict(status='OBSERVED', tag=0xA0000003, target_profile_verified=True)
        sample = {}
        with mock.patch.object(tour, 'reparse_observation', return_value=observed):
            self.assertEqual(tour.sample_workspace((self.path(exists=False), self.path(exists=False),
                self.path(exists=False), root), receipt=sample, expected_profile=(1,10,stat.S_IFDIR,0,0)),10)
        self.assertEqual(sample['verified_aliases'],1)
        self.assertEqual(sample['status'],'COMPLETE')
        alias.iterdir.assert_not_called()
        self.assertEqual(sample['by_role']['tool_profile'],10)
        root.iterdir.reset_mock()
        with self.assertRaises(tour.Refused):
            tour.sample_workspace((self.path(exists=False),self.path(exists=False),
                self.path(exists=False),root), expected_profile=(1,99,stat.S_IFDIR,0,0))
        root.iterdir.assert_not_called()

    def test_reparse_proof_binds_the_canonical_chain_to_the_owned_profile(self):
        root = PureWindowsPath('C:/synthetic-private-profile')
        path = root / 'AppData/Local/Microsoft/Alias'
        target = root / 'AppData/Local/Microsoft/Canonical'
        info = self.reparse_info()
        entries = {path:info, root:self.plain_info(10)}
        parts = target.relative_to(root).parts
        for index in range(1,len(parts)+1):
            entries[root.joinpath(*parts[:index])] = self.plain_info(10+index)
        with mock.patch.object(tour.os,'readlink',return_value=str(target)), \
                mock.patch.object(tour.os,'lstat',side_effect=lambda value: entries[value]):
            observed = tour.reparse_observation(path,root,info,
                expected_profile=tour.directory_identity(entries[root]))
        self.assertTrue(observed['target_profile_verified'])
        self.assertTrue(observed['stable_metadata'])
        self.assertNotIn('synthetic-private-profile',json.dumps(observed))

    @staticmethod
    def reparse_info():
        return types.SimpleNamespace(st_dev=1, st_ino=2, st_mode=stat.S_IFDIR,
            st_size=0, st_mtime_ns=1, st_file_attributes=0x400, st_reparse_tag=0xA0000003)

    def test_reparse_observation_masks_paths_and_never_follows_the_target(self):
        root = PureWindowsPath('C:/synthetic-private-profile')
        path = root / 'AppData/Local/Application Data'
        info = self.reparse_info()
        with mock.patch.object(tour.os, 'readlink', return_value=str(root / 'AppData/Local')), \
                mock.patch.object(tour.os, 'lstat', return_value=info) as lstat:
            value = tour.reparse_observation(path, root, info)
        self.assertEqual(value['status'], 'OBSERVED')
        self.assertEqual(value['entry_parts'], ['appdata', 'local', 'application_data'])
        self.assertEqual(value['target_parts'], ['appdata', 'local'])
        self.assertTrue(value['target_lexically_inside_profile'])
        self.assertNotIn('synthetic-private-profile', json.dumps(value))
        self.assertEqual(lstat.call_args_list, [mock.call(path), mock.call(path)])

    def test_changed_or_external_reparse_targets_cannot_become_profile_ownership(self):
        root = PureWindowsPath('C:/synthetic-private-profile')
        path = root / 'AppData/Local/Application Data'
        for changed in (True, False):
            before, after = self.reparse_info(), self.reparse_info()
            if changed:after.st_ino += 1
            with self.subTest(changed=changed), \
                    mock.patch.object(tour.os, 'readlink', return_value='D:/synthetic-private-external'), \
                    mock.patch.object(tour.os, 'lstat', return_value=after):
                value = tour.reparse_observation(path, root, before)
            if changed:
                self.assertEqual(value['status'], 'CHANGED')
            else:
                self.assertFalse(value['target_lexically_inside_profile'])
                self.assertNotIn('target_parts', value)
            self.assertNotIn('synthetic-private', json.dumps(value))

    @staticmethod
    def path(size=0, mode=stat.S_IFREG, attributes=0, exists=True):
        path = mock.Mock(name='synthetic-private-output')
        path.exists.return_value = exists
        path.is_symlink.return_value = False
        path.lstat.return_value = types.SimpleNamespace(
            st_size=size, st_mode=mode, st_file_attributes=attributes)
        return path

    def paths(self, *offered):
        return (*offered, *(self.path(exists=False) for _ in range(4-len(offered))))

    def test_logical_bytes_are_attributed_to_only_the_owned_roles(self):
        sample = {}
        self.assertEqual(tour.sample_workspace(self.paths(self.path(10), self.path(20)),
                                               receipt=sample), 30)
        self.assertEqual(sample['by_role']['wallet_profile'], 10)
        self.assertEqual(sample['by_role']['application'], 20)
        self.assertEqual(sample['entries'], 2)
        self.assertEqual(sample['status'], 'COMPLETE')

    def test_cap_refusal_retains_the_actual_partial_total(self):
        sample = {}
        with mock.patch.object(tour, 'WORK_CAP', 10), self.assertRaises(tour.Refused):
            tour.sample_workspace(self.paths(self.path(8), self.path(8)), receipt=sample)
        self.assertEqual(sample['logical_bytes'], 16)
        self.assertEqual(sum(sample['by_role'].values()), 16)
        self.assertEqual(sample['reason'], 'workspace_cap')
        self.assertEqual(sample['status'], 'REFUSED')

    def test_links_reparse_entries_special_files_and_entry_limits_stay_refused(self):
        for mode, attributes, limit, reason in (
                (stat.S_IFLNK, 0, 100000, 'linked_entry'),
                (stat.S_IFREG, 0x400, 100000, 'reparse_entry'),
                (stat.S_IFIFO, 0, 100000, 'non_regular_entry'),
                (stat.S_IFREG, 0, 0, 'entry_limit')):
            path = self.path(mode=mode, attributes=attributes)
            sample = {}
            with self.subTest(reason=reason), mock.patch.object(tour, 'ENTRY_LIMIT', limit), \
                    self.assertRaises(tour.Refused):
                tour.sample_workspace(self.paths(path), receipt=sample)
            self.assertEqual(sample['reason'], reason)
            path.iterdir.assert_not_called()
            path.resolve.assert_not_called()
            self.assertNotIn('synthetic-private-output', json.dumps(sample))


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
        for change in ('error', 'forced', 'helper', 'capture', 'check', 'gate'):
            report = self.report()
            if change == 'error':report['errors'] = ['ENTRY_FAILED']
            elif change == 'forced':report['required_actor_forced_cleanup'] = True
            elif change == 'helper':report['auxiliary_cleanup']['status'] = 'FAILED'
            elif change == 'capture':report['captures'].pop()
            elif change == 'gate':report['checks']['entry_gate'] = False
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
