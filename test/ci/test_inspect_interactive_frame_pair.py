"""Memory controls for the paired interactive frame manifest."""

from copy import deepcopy
import unittest
from unittest import mock

import test_inspect_chain321 as lab_fixtures
import test_inspect_launch_timing_pair as fixtures

from tool.ci import inspect_interactive_frame_pair as inspect


pair, cold, archive = inspect.pair, inspect.cold, inspect.archive
HEAD, TREE, RUN = fixtures.HEAD, fixtures.TREE, fixtures.RUN
GENESIS = '3' * 64


def fixture():
    earlier = fixtures.report(dict.fromkeys(cold.PIN_FIELDS, '1' * 64))
    now, before = earlier['samples']
    entry = pair.shared.baseline.Outcome(exit_code=0, exit_observed=True,
        output_complete=True, output_bytes=110, seconds=10).public()

    def sample(value):
        window = dict(value['frame_window'], windowUs=1_000_000)
        return dict(attempt=dict(value['attempts'][-1], role='interactive'),
            observation=dict(phase='complete', lab_revalidations=3, entry=entry.copy(),
                success=True, windows=dict.fromkeys(pair.WINDOWS, window)),
            profile_stable=True, success=True)

    return dict(schema=1, scope=pair.SCOPE, mode='release', theme='dark', client=[1280, 780],
        phase='complete', success=True, p06=earlier['p06'], commands=earlier['commands'],
        samples=dict(current=sample(now), p06=sample(before)),
        comparisons={key: pair.shared.compare_windows(before['frame_window'], now['frame_window'])
                     for key in pair.WINDOWS},
        same_fixture_address=True, error_codes=[], source_sha=HEAD, source_tree=TREE,
        run_id=str(RUN), run_attempt='1', baseline_patch_sha256=pair.shared.PATCH_SHA256,
        collector_sha256=pair.shared.COLLECTOR_SHA256, entry_sha256=pair.profile.ENTRY_SHA256,
        lab_anchor=dict(chain=321, genesis_hash=GENESIS, first_height=10),
        storage=dict(earlier['storage'], samples=2 * len(cold.COMMAND_STAGES) + 5),
        current=earlier['current'], sdk_revision=earlier['sdk_revision'],
        equal_input_objects=earlier['equal_input_objects'])


def package(value, **options):
    encoded = cold.canonical(value)
    raw = fixtures.package(encoded, **options)
    item = dict(digest='sha256:' + archive.sha(raw), size_in_bytes=len(raw))
    lab = dict(observations=dict(genesis_hash=GENESIS, last_height=10),
        interactive_frame_pair=dict(success=value['success'], phase=value['phase'],
                                    manifest_sha256=archive.sha(encoded)))
    return raw, item, lab


class InteractiveFramePairTests(unittest.TestCase):
    def project(self, value, **options):
        raw, item, lab = package(value, **options)
        return inspect.project(raw, item, head=HEAD, tree=TREE, run_id=RUN, lab=lab,
                               expected_entry=pair.profile.ENTRY_SHA256)

    def test_both_timings_require_the_same_owned_fixture_and_closed_actors(self):
        result = self.project(fixture())
        self.assertTrue(result['artifact_reported_success'])
        self.assertTrue(result['timing_criterion_passed'])
        self.assertEqual(result['normal_wallet_exits'], 2)
        self.assertEqual(result['normal_entry_exits'], 2)
        self.assertTrue(all(result['no_added_reported_slow_frames'].values()))

    def test_retained_process_and_window_durations_are_bounded_observations(self):
        offered = fixture()
        result = self.project(offered)
        self.assertEqual(result['entry_process_seconds'], {'current': 10, 'p06': 10})
        self.assertEqual(result['frame_window_us'], {
            'current': dict.fromkeys(pair.WINDOWS, 1000000),
            'p06': dict.fromkeys(pair.WINDOWS, 1000000)})
        self.assertTrue(result['timing_criterion_passed'])
        offered['samples']['p06'].update(profile_stable=False, success=False)
        offered.update(phase='p06_interactive', success=False, comparisons=None,
                       error_codes=['PROFILE_REFUSED'])
        result = self.project(offered)
        self.assertEqual(result['entry_process_seconds'], {'current': 10, 'p06': 10})
        self.assertFalse(result['artifact_reported_success'])
        self.assertFalse(result['timing_criterion_passed'])
        for bad in (-1, 221, True, 'private'):
            sample = fixture()
            sample['samples']['current']['observation']['entry']['seconds'] = bad
            with self.subTest(seconds=bad), self.assertRaises(archive.Refused):
                self.project(sample)
        for bad in (float('nan'), float('inf')):
            sample = fixture()['samples']['current']
            sample['observation']['entry']['seconds'] = bad
            with self.subTest(nonfinite=type(bad).__name__), self.assertRaises(archive.Refused):
                inspect.sample_receipts(sample)

    def test_normal_about_content_uses_visible_licences_and_keeps_scroll_outside_timing(self):
        window = fixture()['samples']['current']['observation']['windows']['page_change']
        for fault in (None, 'closed', 'content', 'address', 'scroll'):
            calls, validated, pauses = [], [], []
            tab, opened, collecting = 'dashboard', False, False

            def send(command):
                nonlocal tab, opened, collecting
                calls.append(command.copy())
                kind = command['cmd']
                if kind == 'theme':
                    return dict(ok=True, mode='dark', brightness='dark', savedMode='ThemeMode.dark')
                if kind == 'state':
                    return dict(ok=True, booted=True, tab=tab, size=[1280, 780],
                        walletUnlocked=True, walletInitCompleted=True,
                        node='ws://127.0.0.1:45998', chainId=321, signingChainId=321,
                        nodeTransitionPending=False,
                        address='changed-address' if fault == 'address' and opened else 'fixture-address')
                if kind == 'stalls':
                    if command['frameWindow'] == 'begin':
                        self.assertFalse(collecting)
                        collecting = True
                        return dict(ok=True, frameWindow='collecting')
                    self.assertTrue(collecting)
                    collecting = False
                    return dict(ok=True, **window)
                if kind == 'tap':
                    if command.get('tab') == 'settings':
                        self.assertTrue(collecting)
                        tab = 'settings'
                        return dict(ok=True, target=dict(tab=tab))
                    key = command['key']
                    self.assertIn(key, ('settings_about', 'about_licences_toggle'))
                    if key == 'about_licences_toggle':
                        self.assertTrue(collecting)
                        self.assertFalse(opened)
                        opened = True
                    else:
                        self.assertFalse(collecting)
                    return dict(ok=True, target=dict(key=key))
                if kind == 'scroll':
                    self.assertTrue(opened)
                    self.assertFalse(collecting)
                    self.assertEqual(command, dict(cmd='scroll', key='about_licences_toggle', dy=300))
                    return dict(ok=True, at=[1280 if fault == 'scroll' else 900, 500])
                self.assertEqual(kind, 'wait')
                self.assertFalse(collecting)
                if 'key' in command:
                    self.assertIn(command['key'], ('settings_node', 'about_licences_toggle'))
                    return dict(ok=True, target=dict(key=command['key']))
                self.assertEqual(command['type'], 'Licences')
                self.assertEqual(command['timeoutMs'], 5000)
                if not opened:
                    self.assertIs(command['gone'], True)
                    return dict(ok=True, **({'target': {}} if fault == 'closed' else {}))
                self.assertNotIn('gone', command)
                return dict(ok=True, target=dict(path=['Other'] if fault == 'content'
                                                       else ['AboutCard', 'Licences', 'Text']))

            windows = {}

            def validate(value):
                pair.shared.launch.frame_timing_window(value)
                validated.append(value)

            with self.subTest(fault=fault):
                if fault is None:
                    result = pair.actions.observe_interactive(send, validate,
                        size=[1280, 780], windows=windows, sleep=pauses.append)
                    self.assertIs(result, windows)
                    self.assertEqual(set(windows), set(pair.WINDOWS))
                    self.assertEqual(len(calls), 16)
                    self.assertEqual(pauses, [0.6, 0.6])
                    self.assertEqual(len(validated), 2)
                else:
                    with self.assertRaises(pair.actions.FrameActionRefused):
                        pair.actions.observe_interactive(send, validate,
                            size=[1280, 780], windows=windows, sleep=pauses.append)
                    self.assertEqual(set(windows), {'page_change'})
                self.assertFalse(collecting)
                self.assertFalse(any(call.get('key') in ('about_page', 'about_licences_list')
                                     for call in calls))

    def test_profile_progress_preserves_the_original_send_failure(self):
        profile = pair.profile
        original_failure = RuntimeError('synthetic private failure')
        window = fixture()['samples']['current']['observation']['windows']['page_change']
        for failed in (False, True):
            report = {}
            unlocked = False

            def send(command):
                if command['cmd'] == 'ping':
                    return dict(ok=True, pid=17, booted=True, harnessMode='wallet')
                if command['cmd'] == 'state':
                    return dict(ok=True, walletUnlocked=unlocked, walletInitCompleted=unlocked,
                        walletPath=None, tab='dashboard', node=profile.NODE,
                        chainId=321, signingChainId=321, savedSigningChainId=321,
                        embeddedNode=False, nodeTransitionPending=False, address='fixture-address')
                self.assertEqual(command['cmd'], 'wait')
                if failed:
                    raise original_failure
                return dict(ok=True)

            def run_entry(payload):
                nonlocal unlocked
                self.assertIsInstance(payload, bytes)
                unlocked = True
                output = profile.READY + b'\n'
                return profile.baseline.Outcome(exit_code=0, exit_observed=True,
                    output_complete=True, output_bytes=len(output), seconds=1, output=output)

            def measure(request, validate, *, size, windows):
                request(dict(cmd='wait', key='about_page'))
                windows.update(dict.fromkeys(pair.WINDOWS, window))

            with mock.patch.object(profile.wallet_tour, 'public_fixture', return_value='fixture words'):
                arguments = (send, run_entry,
                    lambda: dict(chain=321, genesis_hash=GENESIS, last_height=10,
                                 cross_transport_hash_equal=True),
                    measure, lambda address: address == 'fixture-address')
                options = dict(pid=17, port=15432, token='a' * 43, fixture_text='fixture',
                    genesis=GENESIS, first_height=10, report=report)
                if failed:
                    with self.assertRaises(RuntimeError) as caught:
                        profile.owned_profile(*arguments, **options)
                    self.assertIs(caught.exception, original_failure)
                    self.assertEqual(report['phase'], 'measure')
                    self.assertFalse(report['success'])
                else:
                    profile.owned_profile(*arguments, **options)
                    self.assertTrue(report['success'])
            self.assertEqual(report['action_progress'], dict(index=1, command='wait', returned=not failed))
            encoded = cold.canonical(report)
            self.assertNotIn(b'synthetic private failure', encoded)
            self.assertNotIn(b'fixture words', encoded)

    def test_reader_refuses_private_or_inconsistent_action_progress(self):
        value = fixture()
        progress = dict(index=1, command='wait', returned=True)
        value['samples']['current']['observation']['action_progress'] = progress
        result = self.project(value)
        self.assertEqual(result['action_progress']['current'], progress)
        self.assertIsNone(result['action_progress']['p06'])
        invalid = (
            dict(progress, index=True), dict(progress, index=33), dict(progress, command=None),
            dict(progress, command='synthetic private command'), dict(progress, returned=1),
            dict(progress, private='synthetic private value'), dict(progress, index=0),
            dict(index=0, command=None, returned=False), dict(progress, returned=False),
        )
        for offered in invalid:
            value['samples']['current']['observation']['action_progress'] = offered
            with self.subTest(progress=offered), self.assertRaises(archive.Refused):
                self.project(value)

    def test_replaced_profile_preserves_observed_windows_without_accepting_pair(self):
        offered = fixture()
        offered['samples']['p06'].update(profile_stable=False, success=False)
        offered.update(phase='p06_interactive', success=False, comparisons=None,
                       error_codes=['PROFILE_REFUSED'])
        result = self.project(offered)
        self.assertFalse(result['artifact_reported_success'])
        self.assertEqual(result['frame_counts']['p06'], {'page_change': 2, 'disclosure': 2})

    def test_pair_refuses_unbound_lab_receipts_and_incomplete_commands(self):
        edits = (
            lambda value: value['lab_anchor'].update(first_height=11),
            lambda value: value['samples']['current']['observation'].update(lab_revalidations=2),
            lambda value: value['samples']['p06']['attempt'].update(forced_kill=True),
            lambda value: value['comparisons']['page_change'].update(no_frame_number_gaps=1),
            lambda value: value['samples']['current']['observation']['windows']['page_change'].update(
                windowUs=pair.actions.MAX_WINDOW_US + 1),
            lambda value: value['samples'].pop('current'),
            lambda value: value['storage'].update(samples=1),
        )
        original = fixture()
        for index, edit in enumerate(edits):
            offered = deepcopy(original)
            edit(offered)
            with self.subTest(case=index), self.assertRaises(archive.Refused):
                self.project(offered)
        with self.assertRaises(archive.Refused):
            self.project(original, extra=True)

    def test_four_maximum_windows_fit_the_numeric_manifest_limit(self):
        offered = fixture()
        full = dict(schema=1, scope='harness_frame_window', windowUs=pair.actions.MAX_WINDOW_US,
            frames=[[0 if i == 0 else 2**32 - 512 + i,
                     pair.actions.MAX_WINDOW_US - 1, 20000000, 20000000, 60000000]
                    for i in range(pair.shared.launch.MAX_TIMING_FRAMES)])
        for sample in offered['samples'].values():
            sample['observation']['windows'] = dict.fromkeys(pair.WINDOWS, full)
        offered['comparisons'] = {name: pair.shared.compare_windows(full, full)
                                 for name in pair.WINDOWS}
        self.assertLessEqual(len(cold.canonical(offered)) + 1, pair.MAX_MANIFEST)
        result = self.project(offered)
        self.assertTrue(result['artifact_reported_success'])
        self.assertEqual(result['frame_counts']['p06'], {'page_change': 512, 'disclosure': 512})
        self.assertFalse(any(result['no_frame_number_gaps'].values()))
        self.assertFalse(result['timing_criterion_passed'])

    def test_new_slow_frame_keeps_the_measurement_and_refuses_timing(self):
        offered = fixture()
        now = offered['samples']['current']['observation']['windows']
        before = offered['samples']['p06']['observation']['windows']
        page = deepcopy(now['page_change'])
        page['frames'][1][2:] = [17000, 400, 18000]
        now['page_change'] = page
        offered['comparisons']['page_change'] = pair.shared.compare_windows(
            before['page_change'], page)
        result = self.project(offered)
        self.assertTrue(result['artifact_reported_success'])
        self.assertFalse(result['timing_criterion_passed'])
        self.assertEqual(result['no_added_reported_slow_frames'],
                         {'page_change': False, 'disclosure': True})
        self.assertTrue(all(result['no_frame_number_gaps'].values()))

    def test_interactive_lab_requires_the_restored_client_test_fixture(self):
        lab = lab_fixtures.InspectionTests.wallet_stop_report()
        lab.update(application_sha=HEAD, run_id=str(RUN), runtime_phase='interactive_frame_pair',
            wallet_tour_requested=False, wallet_tour=None, wallet_qualified=False,
            seed_admitted=False, interactive_frame_pair=None,
            error_codes=['INTERACTIVE_FRAME_PAIR_FAILED', 'STOP_UNKNOWN'])

        def project(value, *, interactive=True):
            return archive.project(value, 'native', HEAD, RUN, archive.UPSTREAM_NODE_SHA,
                                   expected_patched=True, expected_interactive=interactive)

        result = project(lab)
        self.assertFalse(result['artifact_reported_success'])
        self.assertEqual(result['runtime_phase'], 'interactive_frame_pair')
        self.assertTrue(result['upstream_client_fixture']['original_restored'])
        self.assertTrue(result['node_exits'][1]['forced'])
        with self.assertRaises(archive.Refused):
            project(lab, interactive=False)
        with self.assertRaises(archive.Refused):
            project(dict(lab, upstream_client_fixture=None))
        with self.assertRaises(archive.Refused):
            project(dict(lab, upstream_client_fixture=dict(lab['upstream_client_fixture'],
                                                           original_restored=False)))
