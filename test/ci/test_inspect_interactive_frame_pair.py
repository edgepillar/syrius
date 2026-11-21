"""Memory and source controls for the paired interactive frame manifest."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
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
    def test_current_entry_bytes_match_preparation_source_pin(self):
        repo = Path(__file__).resolve().parents[2]
        entry = repo / pair.profile.ENTRY
        self.assertFalse(entry.is_symlink())
        data = entry.read_bytes()
        self.assertGreater(len(data), 0)
        self.assertLessEqual(len(data), 16384)
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         pair.profile.ENTRY_SHA256)

    def project(self, value, **options):
        raw, item, lab = package(value, **options)
        return inspect.project(raw, item, head=HEAD, tree=TREE, run_id=RUN, lab=lab,
                               expected_entry=pair.profile.ENTRY_SHA256)

    def test_shutdown_trace_has_closed_labels_bounded_lines_and_no_private_output(self):
        profile = pair.profile

        def row(phase, failed=False, *, elapsed_ms=None):
            event = dict(phase=phase, failed=failed)
            if elapsed_ms is not None:
                event['elapsed_ms'] = elapsed_ms
            return profile.SHUTDOWN_PREFIX + json.dumps(
                event, separators=(',', ':')).encode() + b'\n'

        def read(raw, complete=True, overflow=False, **options):
            result = profile.observe_shutdown_trace(raw, output_complete=complete,
                output_overflow=overflow, **options)
            self.assertTrue(profile.valid_shutdown_trace(result))
            self.assertNotIn('synthetic private', json.dumps(result))
            return result

        original = b'synthetic private child output\n' + row('idle') + row('serviceReset')
        self.assertEqual(read(original), dict(status='observed', phase='serviceReset',
            failed=False, event_count=2, output_complete=True))
        partial = original + profile.SHUTDOWN_PREFIX + b'{"phase":"synthetic private'
        self.assertEqual(read(partial, complete=False), dict(status='observed',
            phase='serviceReset', failed=False, event_count=2, output_complete=False))
        self.assertEqual(read(b'synthetic private child output\n'),
                         dict(status='absent', output_complete=True))
        self.assertEqual(read(row('exitRequested') + row('exitRequested', True))['failed'], True)
        timed = (row('idle', elapsed_ms=1) + row('serviceReset', elapsed_ms=500)
                 + row('exitRequested', elapsed_ms=10_123))
        self.assertEqual(read(timed), dict(status='observed', phase='exitRequested',
            failed=False, event_count=3, output_complete=True, elapsed_ms=10_123,
            max_gap_ms=9_623, max_gap_after='serviceReset'))
        single = read(row('idle', elapsed_ms=0))
        self.assertEqual((single['elapsed_ms'], single['max_gap_ms'],
                          single['max_gap_after']), (0, 0, None))
        invalid = (
            row('synthetic private phase'), row('idle', True), row('serviceReset', 1),
            profile.SHUTDOWN_PREFIX + b'{"phase":"idle","failed":false,"private":"synthetic private"}\n',
            profile.SHUTDOWN_PREFIX + b'{"phase":"synthetic private","phase":"idle","failed":false}\n',
            profile.SHUTDOWN_PREFIX + b'{"phase":"\xff","failed":false}\n',
            profile.SHUTDOWN_PREFIX + b' ' * 256 + b'\n', partial,
            row('idle') + row('idle'), row('serviceReset', True) + row('windowSizeRead'),
            row('exitRequested') + row('windowSizeRead'),
            row('idle') + row('serviceReset', elapsed_ms=1),
            row('idle', elapsed_ms=1) + row('serviceReset'),
            row('idle', elapsed_ms=4) + row('serviceReset', elapsed_ms=3),
            row('idle', elapsed_ms=1) + row('idle', elapsed_ms=2),
            row('idle', elapsed_ms=True), row('idle', elapsed_ms=-1),
            row('idle', elapsed_ms=profile.SHUTDOWN_ELAPSED_LIMIT_MS + 1),
            b''.join(row('serviceReset' if turn % 2 else 'windowSizeRead')
                     for turn in range(len(profile.SHUTDOWN_PHASES) + 2)),
        )
        for raw in invalid:
            with self.subTest(raw_size=len(raw)):
                self.assertEqual(read(raw)['error_code'], 'STATE_INVALID')
        self.assertEqual(read(original, overflow=True)['error_code'], 'OUTPUT_OVERFLOW')
        self.assertEqual(read(original, cap=1)['error_code'], 'OUTPUT_OVERFLOW')
        for cap in (False, 0, 131073):
            self.assertEqual(read(original, cap=cap)['error_code'], 'STATE_INVALID')
        for value in (
            None, dict(status='absent', output_complete=1),
            dict(status='observed', phase='synthetic private', failed=False,
                 event_count=1, output_complete=True),
            dict(status='observed', phase='idle', failed=True, event_count=1, output_complete=True),
            dict(status='observed', phase='idle', failed=False, event_count=True, output_complete=True),
            dict(status='observed', phase='idle', failed=False, event_count=0, output_complete=True),
            dict(status='unavailable', error_code='synthetic private', output_complete=True),
            dict(status='absent', output_complete=True, private='synthetic private'),
            dict(single, max_gap_after='idle'), dict(single, max_gap_ms=1),
            dict(read(timed), max_gap_after='synthetic private'),
            dict(read(timed), max_gap_ms=10_124),
        ):
            self.assertFalse(profile.valid_shutdown_trace(value))

    def test_shutdown_trace_runs_after_original_cleanup_and_cannot_qualify_failed_exit(self):
        profile = pair.profile
        row = profile.SHUTDOWN_PREFIX + b'{"phase":"exitRequested","failed":false}\n'
        for parent_error, parser_error in ((False, False), (True, False), (True, True)):
            actor = profile.InteractiveSession.__new__(profile.InteractiveSession)
            actor.report = SimpleNamespace(output_complete=True, output_overflow=False)
            actor.drain = SimpleNamespace(data=bytearray())
            actor.limits = SimpleNamespace(output_bytes=131072)
            actor.shutdown_trace = {}
            actor.process = mock.Mock()
            actor._rpc = mock.Mock()
            original = profile.launch.startup.Failure('EXIT_TIMEOUT')
            receipt = object()

            def finish(*args, **kwargs):
                actor.report.output_complete = False
                actor.drain.data.extend(row)
                if parent_error:
                    raise original
                return receipt

            parser = profile.observe_shutdown_trace
            with mock.patch.object(profile.launch.LaunchProcess, 'run_launch',
                    side_effect=finish) as run, mock.patch.object(profile, 'observe_shutdown_trace',
                    side_effect=RuntimeError('synthetic private parser') if parser_error else parser):
                if parent_error:
                    with self.assertRaises(profile.launch.startup.Failure) as raised:
                        actor.run_launch('dark', capture=False, settle=False)
                    self.assertIs(raised.exception, original)
                else:
                    self.assertIs(actor.run_launch('dark', capture=False, settle=False), receipt)
                run.assert_called_once_with('dark', capture=False, settle=False)
            actor.process.wait.assert_not_called()
            actor._rpc.assert_not_called()
            self.assertTrue(profile.valid_shutdown_trace(actor.shutdown_trace))
            self.assertFalse(actor.shutdown_trace['output_complete'])
            self.assertNotIn('synthetic private', json.dumps(actor.shutdown_trace))
            self.assertEqual(actor.shutdown_trace['status'],
                             'unavailable' if parser_error else 'observed')

        offered = fixture()
        current = offered['samples']['current']
        current['attempt'].update(exit_code=0, forced_kill=True, output_complete=False,
            error_codes=['EXIT_TIMEOUT', 'FORCED_TERMINATION', 'OUTPUT_INCOMPLETE'])
        current['attempt']['checks']['exit'] = False
        current['success'] = False
        trace = dict(status='observed', phase='exitRequested', failed=False,
                     event_count=2, output_complete=False)
        current['shutdown_trace'] = trace
        current['shutdown_observation'] = dict(status='unavailable', error_code='HTTP_FAILED')
        offered.update(phase='current_interactive', success=False, comparisons=None,
            samples=dict(current=current), same_fixture_address=False, commands=[],
            p06=dict(cold.P06_IDENTITY, overlay_verified=False), error_codes=['FRAME_REFUSED'])
        result = self.project(offered)
        self.assertEqual(result['shutdown_traces'], dict(current=trace))
        self.assertEqual(result['shutdown_observations'],
                         dict(current=current['shutdown_observation']))
        self.assertEqual(result['normal_wallet_exits'], 0)
        self.assertFalse(result['artifact_reported_success'])
        self.assertFalse(result['timing_criterion_passed'])
        timed = dict(trace, elapsed_ms=11_200, max_gap_ms=9000,
                     max_gap_after='serviceReset')
        current['shutdown_trace'] = timed
        result = self.project(offered)
        self.assertEqual(result['shutdown_traces'], dict(current=timed))
        self.assertEqual(result['normal_wallet_exits'], 0)
        self.assertFalse(result['timing_criterion_passed'])
        for update in (dict(output_complete=True), dict(phase='synthetic private'),
                       dict(event_count=0), dict(private='synthetic private')):
            current['shutdown_trace'] = dict(trace, **update)
            with self.assertRaises(archive.Refused):
                self.project(offered)

        for interactive in (False, True):
            process = mock.Mock(stdout=object())
            session = mock.Mock()
            receipt = object()
            session.run_launch.return_value = receipt
            factory = mock.Mock(return_value=session)
            context = mock.MagicMock()
            context.__enter__.return_value.getsockname.return_value = ('127.0.0.1', 12345)
            env = {}
            info = SimpleNamespace(st_dev=1, st_ino=2, st_size=3, st_mtime_ns=4)
            catalog = profile.launch
            with mock.patch.object(catalog.bounded, 'check_no_existing'), \
                    mock.patch.object(catalog.bounded, 'plain', return_value=info), \
                    mock.patch.object(catalog.entry, 'child_environment', return_value=env), \
                    mock.patch.object(catalog.socket, 'socket', return_value=context), \
                    mock.patch.object(catalog.subprocess, 'Popen', return_value=process) as spawn, \
                    mock.patch.object(catalog.bounded, 'OutputDrain') as drain:
                result = catalog.run_process(fixtures.Path('synthetic'),
                    dict(SYRIUS_PAIRED_INTERACTIVE_PROFILE='true'),
                    [(fixtures.Path('runner.exe'), None, (1, 2, 3, 4))],
                    fixtures.Path('profile'), 'dark', capture=False, settle=False,
                    process_type=factory, interactive=interactive)
            self.assertIs(result, receipt)
            spawn.assert_called_once()
            drain.assert_called_once_with(process.stdout, catalog.LIMITS.output_bytes,
                                          retain=interactive)
            limits = factory.call_args.kwargs['limits']
            self.assertEqual(limits.exit, 10)
            self.assertEqual(limits.cleanup, catalog.LIMITS.cleanup)
            self.assertEqual(limits.output_bytes, 131072)
            self.assertEqual(env.get('SYRIUS_HARNESS_FRAME_TIMING'),
                             'interactive' if interactive else None)
            process.wait.assert_not_called()

    def test_both_timings_require_the_same_owned_fixture_and_closed_actors(self):
        result = self.project(fixture())
        self.assertTrue(result['artifact_reported_success'])
        self.assertTrue(result['timing_criterion_passed'])
        self.assertEqual(result['normal_wallet_exits'], 2)
        self.assertEqual(result['normal_entry_exits'], 2)
        self.assertTrue(all(result['no_added_reported_slow_frames'].values()))

    def test_peak_total_reports_the_two_observed_waits(self):
        window = dict(schema=1, scope='harness_frame_window', windowUs=100000,
                      frames=[[0, 1000, 1000, 2000, 5000],
                              [1, 5000, 3000, 5000, 16000]])
        for wait in (0, 3000, 8000):
            timing = inspect._window_diagnostics(dict(window, peakBuildWaitUs=wait), None, None)
            self.assertEqual(timing['peak_total_parts_us'], dict(
                build=3000, raster=5000, outside_build_raster=8000,
                wait_for_build=wait, wait_for_raster=8000-wait))
        for refusal in (-1, 8001, True):
            with self.assertRaises(pair.shared.launch.startup.Failure):
                pair.shared.launch.frame_timing_rows(dict(window, peakBuildWaitUs=refusal))

    def test_retained_raster_starts_resolve_interaction_boundaries(self):
        window = dict(schema=1, scope='harness_frame_window', windowUs=100000,
                      frames=[[0, 1000, 1000, 2000, 5000],
                              [1, 5000, 3000, 5000, 16000]])
        observed = dict(window, rasterStartsUs=[2500, 14000])
        older = inspect._window_diagnostics(window, 9000, 4500)
        current = inspect._window_diagnostics(observed, 9000, 4500)
        self.assertEqual(older['raster_start_groups']['crossing']['samples'], 1)
        self.assertEqual(current['raster_start_groups']['crossing']['samples'], 0)
        self.assertEqual(current['raster_start_groups']['after']['samples'], 1)
        self.assertEqual(current['peak_raster_start_bounds_from_tap_us'],
                         dict(earliest=5000, latest=5000))
        for starts in ([2500], [1999, 14000], [2500, 16001], [True, 14000]):
            with self.assertRaises(pair.shared.launch.startup.Failure):
                pair.shared.launch.frame_timing_rows(dict(window, rasterStartsUs=starts))

    def test_retained_process_and_window_durations_are_bounded_observations(self):
        offered = fixture()
        observation = offered['samples']['current']['observation']
        observation['tap_release_us'] = {'page_change': 5000, 'disclosure': 6000}
        observation['pointer_phases_us'] = {
            'page_change': dict(move_started=1000, down=4000),
        }
        phases = dict(settled=250_000, list_laid_out=347_000)
        observation['disclosure_phases_us'] = phases
        result = self.project(offered)
        self.assertEqual(result['entry_process_seconds'], {'current': 10, 'p06': 10})
        self.assertEqual(result['observation_phases'], {'current': 'complete', 'p06': 'complete'})
        self.assertEqual(result['entry_process_results'], dict.fromkeys(('current', 'p06'), dict(
            success=True, exit_code=0, exit_observed=True, forced_kill=False,
            output_complete=True, output_overflow=False, error_codes=[], output_bytes=110)))
        self.assertEqual(result['wallet_process_results'], dict.fromkeys(('current', 'p06'), dict(
            exit_code=0, exit_observed=True, forced_kill=False, output_complete=True,
            output_overflow=False, error_codes=[], action_complete=True,
            checks=dict(identity=True, auth=True, close_ack=True, exit=True))))
        self.assertEqual(result['profile_stable'], dict(current=True, p06=True))
        self.assertEqual(result['frame_window_us'], {
            'current': dict.fromkeys(pair.WINDOWS, 1000000),
            'p06': dict.fromkeys(pair.WINDOWS, 1000000)})
        for label in ('current', 'p06'):
            for name in pair.WINDOWS:
                offered_window = offered['samples'][label]['observation']['windows'][name]
                rows = pair.shared.launch.frame_timing_rows(offered_window)
                actual = result['verified_window_diagnostics'][label][name]
                self.assertEqual(actual['samples'], len(rows))
                _, start, build, raster, total = max(rows, key=lambda row: row[4])
                self.assertEqual(actual['peak_build_starts_us'], dict(
                    raster=max(rows, key=lambda row: row[3])[1], total=start))
                self.assertEqual(actual['peak_total_parts_us'], dict(
                    build=build, raster=raster, outside_build_raster=total - build - raster))
        self.assertTrue(result['timing_criterion_passed'])
        page = result['verified_window_diagnostics']['current']['page_change']
        self.assertEqual(page['tap_release_us'], 5000)
        self.assertEqual(page['pointer_offsets_from_tap_us'],
                         dict(move_started=-4000, down=-1000))
        current_page = observation['windows']['page_change']
        _, start, build, raster, total = max(
            pair.shared.launch.frame_timing_rows(current_page), key=lambda row: row[3])
        self.assertEqual(page['peak_raster_start_bounds_from_tap_us'], dict(
            earliest=start + build - 5000, latest=start + total - raster - 5000))
        self.assertEqual(page['peak_raster_start_relation_to_pointer'],
                         dict(move_started='at_or_after', down='at_or_after'))
        for invalid in (dict(move_started=4001, down=4000),
                        dict(move_started=1000, down=5001),
                        dict(move_started=True, down=4000)):
            offered_invalid = fixture()
            invalid_observation = offered_invalid['samples']['current']['observation']
            invalid_observation['tap_release_us'] = {'page_change': 5000}
            invalid_observation['pointer_phases_us'] = {'page_change': invalid}
            with self.subTest(pointer_phases=invalid), self.assertRaises(archive.Refused):
                self.project(offered_invalid)
        disclosure = result['verified_window_diagnostics']['current']['disclosure']
        self.assertEqual(disclosure['observed_post_frame_offsets_from_tap_us'],
                         dict(settled=244_000, list_laid_out=341_000))
        measured_disclosure = fixture()
        disclosure_sample = measured_disclosure['samples']['current']['observation']
        disclosure_sample['tap_release_us'] = {'disclosure': 6000}
        disclosure_sample['disclosure_phases_us'] = phases
        disclosure_sample['windows']['disclosure'] = dict(
            disclosure_sample['windows']['disclosure'], frames=[
                [0, 239000, 100, 16000, 16100],
                [1, 249000, 100, 21000, 23000],
                [2, 249900, 100, 17000, 17100],
                [3, 346000, 100, 24000, 26000],
                [4, 346900, 100, 12000, 12100],
            ])
        measured_disclosure['comparisons']['disclosure'] = pair.shared.compare_windows(
            measured_disclosure['samples']['p06']['observation']['windows']['disclosure'],
            disclosure_sample['windows']['disclosure'])
        projected = self.project(measured_disclosure)
        self.assertEqual(projected['verified_raster_rank_overruns']['disclosure']['by_phase'],
                         dict(before_settlement=0, after_settlement=2, crossing=1))
        diagnosed = projected['verified_window_diagnostics']
        self.assertEqual(diagnosed['current']['disclosure']['raster_start_groups_by_observed_phase'], {
            'columns': ['samples', 'slow_raster', 'max_raster_us'],
            'phases': {
                'settled': dict(before=[1, 0, 16000], at_or_after=[3, 2, 24000],
                                crossing=[1, 1, 21000]),
                'list_laid_out': dict(before=[3, 2, 21000], at_or_after=[1, 0, 12000],
                                      crossing=[1, 1, 24000]),
            },
        })
        self.assertNotIn('raster_start_groups_by_observed_phase', diagnosed['p06']['disclosure'])
        for value in ({}, {'settled': 5999}, {'settled': True},
                      {'list_laid_out': 1_000_000}, {'other': 6500}):
            observation['disclosure_phases_us'] = value
            with self.subTest(phases=value), self.assertRaises(archive.Refused):
                self.project(offered)
        observation['disclosure_phases_us'] = phases
        self.assertNotIn('tap_release_us', result['verified_window_diagnostics']['p06']['page_change'])
        self.assertNotIn('peak_raster_start_bounds_from_tap_us',
                         result['verified_window_diagnostics']['p06']['page_change'])
        self.assertNotIn('raster_start_groups',
                         result['verified_window_diagnostics']['p06']['page_change'])
        grouped = fixture()
        measured = grouped['samples']['current']['observation']
        measured['tap_release_us'] = {'page_change': 5000}
        measured['windows']['page_change'] = dict(
            measured['windows']['page_change'], frames=[
                [0, 1000, 100, 16000, 16100],
                [1, 4000, 100, 21000, 23000],
                [2, 4900, 100, 17000, 17100],
                [3, 324000, 100, 24000, 26000],
                [4, 324900, 100, 12000, 12100],
            ])
        grouped['comparisons']['page_change'] = pair.shared.compare_windows(
            grouped['samples']['p06']['observation']['windows']['page_change'],
            measured['windows']['page_change'])
        projected = self.project(grouped)
        self.assertEqual(projected['verified_raster_rank_overruns'], {
            'page_change': dict(count=3, unpaired=2,
                by_phase=dict(before_release=0, during_nominal_motion=1,
                              after_nominal_motion=0, crossing=2),
                worst=dict(rank=1, baseline_us=17000, current_us=24000, excess_us=7000,
                           start_us=[324100, 326000], start_from_release_us=[319100, 321000])),
        })
        measured['page_settled_us'] = 300_000
        settled = self.project(grouped)
        self.assertEqual(settled['page_settled_us'], 300_000)
        self.assertEqual(settled['verified_raster_rank_overruns']['page_change']['by_phase'],
                         dict(before_release=0, before_settlement=1, after_settlement=1, crossing=1))
        page_settlement = settled['verified_window_diagnostics']['current']['page_change']
        self.assertEqual(page_settlement['observed_post_frame_offsets_from_tap_us'],
                         {'settled': 295_000})
        self.assertEqual(page_settlement['raster_start_groups_by_observed_phase'], dict(
            columns=['samples', 'slow_raster', 'max_raster_us'],
            phases={'settled': dict(before=[3, 2, 21_000],
                                   at_or_after=[2, 1, 24_000], crossing=[0, 0, 0])}))
        for invalid in (False, 4999, 1_000_000):
            measured['page_settled_us'] = invalid
            with self.subTest(page_settled_us=invalid), self.assertRaises(archive.Refused):
                self.project(grouped)
        page_groups = projected['verified_window_diagnostics']['current']['page_change']
        self.assertEqual(page_groups['nominal_motion_us'], 320_000)
        self.assertEqual(page_groups['raster_start_groups'], dict(
            before=dict(samples=1, slow_raster=0, max_raster_us=16000),
            within=dict(samples=1, slow_raster=1, max_raster_us=17000),
            after=dict(samples=1, slow_raster=0, max_raster_us=12000),
            crossing=dict(samples=2, slow_raster=2, max_raster_us=24000)))
        for offset in (-1, True, 1_000_000):
            observation['tap_release_us']['page_change'] = offset
            with self.subTest(offset=offset), self.assertRaises(archive.Refused):
                self.project(offered)
        observation['tap_release_us']['page_change'] = 5000
        previous_observation = offered['samples']['p06']['observation']
        previous_observation['tap_release_us'] = {'page_change': 5000}
        with self.assertRaises(archive.Refused):
            self.project(offered)
        del previous_observation['tap_release_us']
        offered['samples']['p06'].update(profile_stable=False, success=False)
        offered.update(phase='p06_interactive', success=False, comparisons=None,
                       error_codes=['PROFILE_REFUSED'])
        result = self.project(offered)
        self.assertEqual(result['entry_process_seconds'], {'current': 10, 'p06': 10})
        self.assertEqual(result['profile_stable'], dict(current=True, p06=False))
        self.assertFalse(result['artifact_reported_success'])
        self.assertFalse(result['timing_criterion_passed'])
        diagnostics = result['verified_window_diagnostics']
        self.assertEqual(set(diagnostics), {'current'})
        self.assertEqual(set(diagnostics['current']), set(pair.WINDOWS))
        self.assertEqual(diagnostics['current']['page_change']['tap_release_us'], 5000)
        self.assertIsNone(result['verified_comparisons'])
        interrupted = fixture()
        current = interrupted['samples']['current']
        current['attempt'].update(exit_code=1, forced_kill=True,
                                  error_codes=['CLEANUP_FAILED'])
        current['attempt']['checks'].update(close_ack=False, exit=False)
        current['success'] = False
        interrupted.update(phase='current_interactive', success=False, comparisons=None,
                           samples=dict(current=current), same_fixture_address=False,
                           commands=[], p06=dict(cold.P06_IDENTITY, overlay_verified=False),
                           error_codes=['FRAME_REFUSED'])
        projected = self.project(interrupted)
        self.assertEqual(projected['wallet_process_results'], dict(current=dict(
            exit_code=1, exit_observed=True, forced_kill=True, output_complete=True,
            output_overflow=False, error_codes=['CLEANUP_FAILED'], action_complete=True,
            checks=dict(identity=True, auth=True, close_ack=False, exit=False))))
        self.assertEqual(projected['profile_stable'], dict(current=True))
        self.assertEqual(projected['observation_phases'], dict(current='complete'))
        self.assertEqual(projected['normal_wallet_exits'], 0)
        self.assertFalse(projected['artifact_reported_success'])
        self.assertIsNone(projected['verified_window_diagnostics'])
        self.assertFalse(projected['timing_criterion_passed'])
        self.assertIsNone(projected['no_added_reported_slow_frames'])
        self.assertIsNone(projected['no_frame_number_gaps'])
        timed = deepcopy(interrupted)
        timed['samples']['current']['attempt'].update(
            error_codes=['EXIT_TIMEOUT', 'FORCED_TERMINATION', 'OUTPUT_INCOMPLETE'],
            output_complete=False)
        valid_close = (
            dict(status='observed', phase='wakeLockRead', failed=False),
            dict(status='observed', phase='serviceReset', failed=True),
            dict(status='unavailable', error_code='COMMAND_FAILED'),
        )
        for diagnostic in valid_close:
            timed['samples']['current']['shutdown_observation'] = diagnostic
            result = self.project(timed)
            self.assertEqual(result['shutdown_observations'], dict(current=diagnostic))
            self.assertFalse(result['artifact_reported_success'])
            self.assertFalse(result['timing_criterion_passed'])
            self.assertEqual(result['normal_wallet_exits'], 0)
        for diagnostic in (
            dict(status='observed', phase='synthetic private value', failed=False),
            dict(status='observed', phase='idle', failed=True),
            dict(status='observed', phase='wakeLockRead', failed=1),
            dict(status='observed', phase='wakeLockRead', failed=False, private='value'),
            dict(status='unavailable', error_code='synthetic private value'),
        ):
            timed['samples']['current']['shutdown_observation'] = diagnostic
            with self.subTest(shutdown=diagnostic), self.assertRaises(archive.Refused):
                self.project(timed)
        normal = fixture()
        normal['samples']['current']['shutdown_observation'] = valid_close[0]
        with self.assertRaises(archive.Refused):
            self.project(normal)
        for field, value in (
            ('stdout', 'synthetic private output'),
            ('error_codes', ['synthetic private output']),
            ('checks', dict(identity=True, auth=True, close_ack=True, exit=True,
                            private='synthetic private output')),
        ):
            private = fixture()
            private['samples']['current']['attempt'][field] = value
            with self.subTest(attempt_field=field), self.assertRaises(archive.Refused):
                self.project(private)
        preparation = fixture()
        baseline = preparation['samples']['p06']
        baseline['attempt'].update(action_complete=False,
                                  error_codes=['STARTUP_OBSERVATION_REFUSED'])
        baseline['observation'].update(phase='prepare_profile', lab_revalidations=1,
            entry=pair.shared.baseline.Outcome(exit_code=1, exit_observed=True,
                output_complete=True, output_bytes=97, seconds=34).public(),
            success=False, windows={})
        baseline['success'] = False
        preparation.update(phase='p06_interactive', success=False, comparisons=None,
                           same_fixture_address=False, error_codes=['FRAME_REFUSED'])
        partial = self.project(preparation)
        self.assertEqual(partial['observation_phases'],
                         {'current': 'complete', 'p06': 'prepare_profile'})
        self.assertEqual(partial['entry_process_results']['p06'], dict(
            success=False, exit_code=1, exit_observed=True, forced_kill=False,
            output_complete=True, output_overflow=False, error_codes=[], output_bytes=97))
        self.assertEqual(partial['normal_entry_exits'], 1)
        self.assertEqual(partial['frame_counts']['p06'], {})
        self.assertFalse(partial['artifact_reported_success'])
        self.assertFalse(partial['timing_criterion_passed'])
        self.assertEqual(partial['preparation_failures'], {})
        failure = dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
            action='tap', control='welcome_import', reason='wallet-recipe-control-absent',
            entry='startup-initialization-started'))
        traced = deepcopy(preparation)
        observation = traced['samples']['p06']['observation']
        observation['preparation_failure'] = failure
        observation['entry']['output_bytes'] = len(
            pair.profile.preparation_failure_marker(failure)) + 1
        projected = self.project(traced)
        self.assertEqual(projected['preparation_failures'], {'p06': failure})
        self.assertFalse(projected['artifact_reported_success'])
        self.assertFalse(projected['timing_criterion_passed'])
        navigation = deepcopy(traced)
        nav_failure = dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
            action='observe', control='nav_settings', entry='unknown',
            reason='wallet-recipe-control-absent'))
        nav_sample = navigation['samples']['p06']
        nav_sample['observation']['preparation_failure'] = nav_failure
        nav_sample['observation']['entry']['output_bytes'] = len(
            pair.profile.preparation_failure_marker(nav_failure)) + 1
        binding = dict(carrier='inkwell', hasExistingKey=False, expectedKey=False,
            sameRectangle=True, visibleInsideDecoration=True, enabled=True)
        valid_navigation = (
            dict(status='observed', settingsCount=0, bindings=[]),
            dict(status='observed', settingsCount=1, bindings=[binding]),
            dict(status='unavailable', error_code='HTTP_FAILED'),
        )
        for diagnostic in valid_navigation:
            nav_sample['navigation_observation'] = deepcopy(diagnostic)
            result = self.project(navigation)
            self.assertEqual(result['navigation_observations'], dict(p06=diagnostic))
            self.assertFalse(result['artifact_reported_success'])
            self.assertFalse(result['timing_criterion_passed'])
            self.assertEqual(result['normal_wallet_exits'], 2)
        for diagnostic in (
            dict(status='observed', settingsCount=True, bindings=[]),
            dict(status='observed', settingsCount=5, bindings=[]),
            dict(status='observed', settingsCount=0, bindings=[binding] * 5),
            dict(status='observed', settingsCount=1, bindings=[dict(binding, carrier='private')]),
            dict(status='observed', settingsCount=1, bindings=[dict(binding, enabled=1)]),
            dict(status='observed', settingsCount=1, bindings=[dict(binding, expectedKey=True)]),
            dict(status='observed', settingsCount=1,
                 bindings=[dict(binding, visibleInsideDecoration=False)]),
            dict(status='observed', settingsCount=1, bindings=[dict(binding, carrier='absent')]),
            dict(status='observed', settingsCount=0, bindings=[], private='value'),
            dict(status='unavailable', error_code='synthetic private value'),
        ):
            nav_sample['navigation_observation'] = diagnostic
            with self.subTest(navigation=diagnostic), self.assertRaises(archive.Refused):
                self.project(navigation)
        for wrong in (fixture(), traced):
            wrong = deepcopy(wrong)
            wrong['samples']['p06']['navigation_observation'] = valid_navigation[0]
            with self.assertRaises(archive.Refused):
                self.project(wrong)
        startup = deepcopy(traced)
        startup_sample = startup['samples']['p06']
        startup_sample['observation']['preparation_failure'] = dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='observe', control='welcome_import',
                entry='startup-before-initialization',
                reason='wallet-recipe-control-absent'))
        startup_sample['observation']['entry']['output_bytes'] = len(
            pair.profile.preparation_failure_marker(
                startup_sample['observation']['preparation_failure'])) + 1
        snapshot = dict(status='observed', entry='startup-before-initialization',
                        frames=240, shown=12, done=False)
        progress = dict(snapshot, schema=2, skip=True, pending=False, ticking=True)
        for diagnostic in (
            snapshot, dict(snapshot, frames=0, shown=-1), dict(snapshot, done=True),
            dict(snapshot, frames=5000, shown=4999),
            progress, dict(progress, pending=True, ticking=False),
            dict(status='absent', entry='welcome'),
            dict(status='unavailable', error_code='HTTP_FAILED'),
        ):
            startup_sample['startup_observation'] = deepcopy(diagnostic)
            result = self.project(startup)
            self.assertEqual(result['startup_observations'], dict(p06=diagnostic))
            self.assertFalse(result['artifact_reported_success'])
            self.assertFalse(result['timing_criterion_passed'])
            self.assertEqual(result['normal_wallet_exits'], 2)
        unconfirmed = deepcopy(startup)
        unconfirmed_sample = unconfirmed['samples']['p06']
        unconfirmed_sample['observation']['preparation_failure'] = dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='key', control='launch_skip_hint',
                reason='wallet-recipe-startup-key-unconfirmed', startup='key-sent'))
        unconfirmed_sample['observation']['entry']['output_bytes'] = len(
            pair.profile.preparation_failure_marker(
                unconfirmed_sample['observation']['preparation_failure'])) + 1
        unconfirmed_sample['startup_observation'] = deepcopy(progress)
        result = self.project(unconfirmed)
        self.assertEqual(result['startup_observations'], dict(p06=progress))
        self.assertFalse(result['artifact_reported_success'])
        self.assertFalse(result['timing_criterion_passed'])
        legacy = deepcopy(unconfirmed)
        legacy_failure = legacy['samples']['p06']['observation']['preparation_failure']
        del legacy_failure['recipe']['startup']
        legacy['samples']['p06']['observation']['entry']['output_bytes'] = len(
            pair.profile.preparation_failure_marker(legacy_failure)) + 1
        legacy_result = self.project(legacy)
        self.assertEqual(legacy_result['startup_observations'], dict(p06=progress))
        self.assertFalse(legacy_result['artifact_reported_success'])
        self.assertFalse(legacy_result['timing_criterion_passed'])
        for change in (
            {'reason': 'wallet-recipe-control-refused'},
            {'startup': 'key-confirmed'}, {'control': 'welcome_import'},
            {'entry': 'welcome'},
        ):
            wrong = deepcopy(unconfirmed)
            wrong['samples']['p06']['observation']['preparation_failure']['recipe'].update(change)
            with self.subTest(unconfirmed=change), self.assertRaises(archive.Refused):
                self.project(wrong)
        for diagnostic in (
            dict(snapshot, frames=True), dict(snapshot, frames=-1),
            dict(snapshot, frames=5001), dict(snapshot, shown=True),
            dict(snapshot, shown=-2), dict(snapshot, shown=240),
            dict(snapshot, done=1), dict(snapshot, entry='synthetic private phase'),
            dict(snapshot, private='synthetic private value'),
            dict(progress, schema=True), dict(progress, schema=1),
            dict(progress, schema=3), dict(progress, skip=1),
            dict(progress, pending=None), dict(progress, ticking='synthetic private'),
            {key: value for key, value in progress.items() if key != 'pending'},
            dict(progress, private='synthetic private value'),
            dict(status='observed', entry='welcome'),
            dict(status='unavailable', error_code='synthetic private error'),
        ):
            startup_sample['startup_observation'] = diagnostic
            with self.subTest(startup=diagnostic), self.assertRaises(archive.Refused):
                self.project(startup)
        for wrong in (fixture(), traced, navigation):
            wrong = deepcopy(wrong)
            wrong['samples']['p06']['startup_observation'] = snapshot
            with self.assertRaises(archive.Refused):
                self.project(wrong)
        mixed = deepcopy(startup)
        mixed['samples']['p06'].update(startup_observation=snapshot,
                                      navigation_observation=valid_navigation[0])
        with self.assertRaises(archive.Refused):
            self.project(mixed)
        for field, value in (
            ('exit_code', 0), ('forced_kill', True), ('output_complete', False),
            ('output_overflow', True), ('exit_observed', False),
            ('error_codes', ['CLEANUP_FAILED']), ('output_bytes', 4097),
            ('output_bytes', 1),
        ):
            private = deepcopy(traced)
            private['samples']['p06']['observation']['entry'][field] = value
            with self.subTest(preparation_field=field), self.assertRaises(archive.Refused):
                self.project(private)
        for invalid in (
            dict(failure, phase='synthetic private phase'),
            dict(failure, phase='ownerBefore'),
            dict(failure, recipe=dict(failure['recipe'], detail='synthetic private reply')),
            dict(failure, recipe=dict(failure['recipe'], control='synthetic private input')),
        ):
            private = deepcopy(traced)
            private['samples']['p06']['observation']['preparation_failure'] = invalid
            with self.subTest(preparation=invalid), self.assertRaises(archive.Refused):
                self.project(private)
        for phase in ('synthetic private phase', None, True):
            private = deepcopy(preparation)
            private['samples']['p06']['observation']['phase'] = phase
            with self.subTest(phase=phase), self.assertRaises(archive.Refused):
                self.project(private)
        for code in ('synthetic private output', True, 2**32):
            private = deepcopy(preparation)
            private['samples']['p06']['observation']['entry']['exit_code'] = code
            with self.subTest(exit_code=code), self.assertRaises(archive.Refused):
                self.project(private)
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
        window = dict(fixture()['samples']['current']['observation']['windows']['page_change'],
                      peakBuildWaitUs=0)
        window['rasterStartsUs'] = [row[1] + row[2] for row in window['frames']]
        for fault in (None, 'closed', 'content', 'address', 'scroll', 'tap_offset',
                      'phase_offset', 'pointer_order'):
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
                    reply = dict(ok=True, **window)
                    if opened:
                        reply['interactiveDisclosurePhasesUs'] = dict(
                            settled=59_000 if fault == 'phase_offset' else 304_000,
                            list_laid_out=450_000)
                    else:
                        reply['interactivePageSettledUs'] = 350_000
                    return reply
                if kind == 'tap':
                    if command.get('tab') == 'settings':
                        self.assertTrue(collecting)
                        tab = 'settings'
                        return dict(ok=True, target=dict(tab=tab), frameWindowTapReleaseUs=50_000,
                                    frameWindowPointerPhasesUs=dict(move_started=1000, down=2000))
                    key = command['key']
                    self.assertIn(key, ('settings_about', 'about_licences_toggle'))
                    if key == 'about_licences_toggle':
                        self.assertTrue(collecting)
                        self.assertFalse(opened)
                        opened = True
                        return dict(ok=True, target=dict(key=key),
                            frameWindowPointerPhasesUs=dict(
                                move_started=2000, down=1000 if fault == 'pointer_order' else 3000),
                            frameWindowTapReleaseUs=-1 if fault == 'tap_offset' else 60_000)
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

            windows, tap_releases, disclosure_phases, page_phases = {}, {}, {}, {}
            pointer_phases = {}

            def validate(value):
                pair.shared.launch.frame_timing_window(value)
                validated.append(value)

            with self.subTest(fault=fault):
                if fault in (None, 'phase_offset'):
                    result = pair.actions.observe_interactive(send, validate,
                        size=[1280, 780], windows=windows,
                        tap_releases=tap_releases,
                        disclosure_phases=disclosure_phases, page_phases=page_phases,
                        pointer_phases=pointer_phases,
                        sleep=pauses.append)
                    self.assertIs(result, windows)
                    self.assertEqual(set(windows), set(pair.WINDOWS))
                    self.assertEqual(len(calls), 16)
                    self.assertEqual(pauses, [0.6, 0.6])
                    self.assertEqual(len(validated), 2)
                    self.assertEqual(validated, [window, window])
                    self.assertEqual(tap_releases, {'page_change': 50_000, 'disclosure': 60_000})
                    self.assertEqual(page_phases, dict(settled=350_000))
                    self.assertEqual(pointer_phases, dict(
                        page_change=dict(move_started=1000, down=2000),
                        disclosure=dict(move_started=2000, down=3000)))
                    self.assertEqual(disclosure_phases,
                        {} if fault else dict(settled=304_000, list_laid_out=450_000))
                else:
                    with self.assertRaises(pair.actions.FrameActionRefused):
                        pair.actions.observe_interactive(send, validate,
                            size=[1280, 780], windows=windows,
                            tap_releases=tap_releases, pointer_phases=pointer_phases,
                            sleep=pauses.append)
                    self.assertEqual(set(windows), {'page_change'})
                    self.assertEqual(tap_releases, {'page_change': 50_000})
                    self.assertEqual(pointer_phases, {'page_change': dict(move_started=1000, down=2000)})
                self.assertFalse(collecting)
                self.assertFalse(any(call.get('key') in ('about_page', 'about_licences_list')
                                     for call in calls))

    def test_close_observation_preserves_the_original_exit_failure(self):
        profile = pair.profile
        base = profile.launch.LaunchProcess

        def session(reply=None, error=None):
            value = object.__new__(profile.InteractiveSession)
            value.shutdown_observation = {}
            value.deadline = 50.0
            value.clock = lambda: 10.0
            value._rpc = mock.Mock(return_value=reply, side_effect=error)
            return value

        for failure in (None, profile.launch.startup.Failure('CLOSE_FAILED')):
            actor = session()
            with mock.patch.object(base, '_quit', side_effect=failure):
                if failure is None:
                    actor._quit()
                else:
                    with self.assertRaises(profile.launch.startup.Failure) as raised:
                        actor._quit()
                    self.assertIs(raised.exception, failure)
            actor._rpc.assert_not_called()
            self.assertEqual(actor.shutdown_observation, {})

        cases = (
            (dict(ok=True, phase='wakeLockRead', failed=False), None,
             dict(status='observed', phase='wakeLockRead', failed=False)),
            (dict(ok=True, phase='serviceReset', failed=True), None,
             dict(status='observed', phase='serviceReset', failed=True)),
            (dict(ok=True, phase='idle', failed=True), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=1, phase='wakeLockRead', failed=False), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=True, phase='wakeLockRead', failed=1), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=True, phase='private', failed=False), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=True, phase='wakeLockRead', failed=False, private='value'), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (None, profile.launch.startup.Failure('HTTP_FAILED'),
             dict(status='unavailable', error_code='HTTP_FAILED')),
            (None, RuntimeError('synthetic private failure'),
             dict(status='unavailable', error_code='INTERNAL_ERROR')),
        )
        for reply, error, expected in cases:
            actor = session(reply, error)
            original = profile.launch.startup.Failure('EXIT_TIMEOUT')
            with mock.patch.object(base, '_quit', side_effect=original):
                with self.assertRaises(profile.launch.startup.Failure) as raised:
                    actor._quit()
            self.assertIs(raised.exception, original)
            actor._rpc.assert_called_once_with(
                {'cmd': 'shutdown-state'}, allow_exit=True, until=11.0)
            self.assertEqual(actor.shutdown_observation, expected)

        observation = dict(phase='prepare_profile', preparation_failure=dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='observe', control='nav_settings', entry='unknown',
                reason='wallet-recipe-control-absent')))
        binding = dict(carrier='inkwell', hasExistingKey=False, expectedKey=False,
            sameRectangle=True, visibleInsideDecoration=True, enabled=True)
        for value in ({}, dict(phase='complete'), None,
                      dict(observation, preparation_failure=dict(code='OWNER_REFUSED',
                                                                phase='ownerBefore'))):
            actor, diagnostic = session(), {}
            profile._observe_navigation_failure(actor, value, diagnostic)
            actor._rpc.assert_not_called()
            self.assertEqual(diagnostic, {})
        for reply, error, expected in (
            (dict(ok=True, settingsCount=1, bindings=[binding]), None,
             dict(status='observed', settingsCount=1, bindings=[binding])),
            (dict(ok=True, settingsCount=True, bindings=[]), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=True, settingsCount=0, bindings=[], private='value'), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(ok=True, settingsCount=1, bindings=[dict(binding, carrier='private')]), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (None, profile.launch.startup.Failure('HTTP_FAILED'),
             dict(status='unavailable', error_code='HTTP_FAILED')),
            (None, RuntimeError('synthetic private failure'),
             dict(status='unavailable', error_code='INTERNAL_ERROR')),
        ):
            for deadline in (50.0, 10.25, 9.0):
                actor, diagnostic = session(deepcopy(reply), error), {}
                actor.deadline = deadline
                profile._observe_navigation_failure(actor, observation, diagnostic)
                actor._rpc.assert_called_once_with(
                    {'cmd': 'navigation-state'}, until=min(deadline, 11.0))
                self.assertEqual(diagnostic, expected)
                profile._observe_navigation_failure(actor, observation, diagnostic)
                actor._rpc.assert_called_once()

        bounded = profile.launch.bounded
        for role in ('shutdown', 'navigation'):
            for variant, error, expected in (
                ('timeout', TimeoutError('synthetic private timeout'), 'HTTP_FAILED'),
                ('connection', ConnectionRefusedError('synthetic private connection'),
                 'HTTP_FAILED'),
                ('shared', bounded.SmokeFailure('OUTPUT_INCOMPLETE'),
                 'OUTPUT_INCOMPLETE'),
                ('invalid', None, 'RESPONSE_INVALID'),
                ('expired', None, 'TOTAL_DEADLINE'),
            ):
                actor = session()
                del actor._rpc  # Exercise the inherited request and exchange path.
                actor.token = 'a' * 43
                actor.process = mock.Mock()
                actor.process.poll.return_value = None
                actor.drain = mock.Mock(error=None)
                actor.drain.overflow.is_set.return_value = False
                actor.report = mock.Mock(original_errors=[])
                actor.limits = bounded.Limits()
                actor.transport = mock.Mock()
                actor.transport.exchange.side_effect = error
                actor.transport.exchange.return_value = bounded.Reply(
                    200, b'{"ok":1}', 'application/json')
                if variant == 'expired':
                    actor.deadline = 9.0
                if role == 'shutdown':
                    original = profile.launch.startup.Failure('EXIT_TIMEOUT')
                    with mock.patch.object(base, '_quit', side_effect=original):
                        with self.assertRaises(profile.launch.startup.Failure) as raised:
                            actor._quit()
                    self.assertIs(raised.exception, original)
                    diagnostic = actor.shutdown_observation
                else:
                    diagnostic = {}
                    profile._observe_navigation_failure(actor, observation, diagnostic)
                self.assertEqual(diagnostic,
                    dict(status='unavailable', error_code=expected))
                self.assertTrue(profile.valid_shutdown_observation(diagnostic))
                self.assertTrue(profile.valid_navigation_observation(diagnostic))
                self.assertNotIn('synthetic private', repr(diagnostic))
                if variant == 'expired':
                    actor.transport.exchange.assert_not_called()
                else:
                    actor.transport.exchange.assert_called_once_with(
                        {'cmd': role + '-state'}, actor.token, 1.0)
                actor.process.wait.assert_not_called()
                actor.process.kill.assert_not_called()

        startup = dict(phase='prepare_profile', preparation_failure=dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='observe', control='welcome_import',
                entry='startup-before-initialization',
                reason='wallet-recipe-control-absent')))
        body = dict(ok=True, booted=True, harnessMode='wallet', walletPresent=False,
                    transitionPending=False, hasError=False,
                    entryPhase='startup-before-initialization',
                    startupFilmFrame=dict(frames=240, shown=0, done=False),
                    controls=[dict(key='synthetic private control')],
                    private='synthetic private input')
        snapshot = dict(status='observed', entry='startup-before-initialization',
                        frames=240, shown=0, done=False)
        progress_frame = dict(body['startupFilmFrame'], schema=2,
                              skip=True, pending=False, ticking=True)
        progress = dict(snapshot, schema=2, skip=True, pending=False, ticking=True)
        unconfirmed = dict(phase='prepare_profile', preparation_failure=dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='key', control='launch_skip_hint',
                reason='wallet-recipe-startup-key-unconfirmed', startup='key-sent')))
        for bits in range(8):
            flags = dict(skip=bool(bits & 1), pending=bool(bits & 2), ticking=bool(bits & 4))
            actor, diagnostic = session(dict(body,
                startupFilmFrame=dict(progress_frame, **flags))), {}
            profile._observe_startup_failure(actor, unconfirmed, diagnostic)
            self.assertEqual(diagnostic, dict(progress, **flags))
            actor._rpc.assert_called_once()
            self.assertTrue(profile.valid_startup_observation(diagnostic))
            legacy = deepcopy(unconfirmed)
            del legacy['preparation_failure']['recipe']['startup']
            legacy_actor, legacy_diagnostic = session(dict(body,
                startupFilmFrame=dict(progress_frame, **flags))), {}
            profile._observe_startup_failure(legacy_actor, legacy, legacy_diagnostic)
            self.assertEqual(legacy_diagnostic, dict(progress, **flags))
            legacy_actor._rpc.assert_called_once()
        for wrong in ({}, observation, None, dict(phase='complete')):
            actor, diagnostic = session(body), {}
            profile._observe_startup_failure(actor, wrong, diagnostic)
            actor._rpc.assert_not_called()
            self.assertEqual(diagnostic, {})
        for reply, error, expected in (
            (body, None, snapshot),
            (dict(body, startupFilmFrame=progress_frame), None, progress),
            (dict(body, startupFilmFrame=dict(progress_frame, schema=True)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(progress_frame, schema=1)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(progress_frame, skip=1)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(progress_frame, pending=None)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(progress_frame, ticking=0)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame={key: value for key, value in
                progress_frame.items() if key != 'pending'}), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(progress_frame,
                 private='synthetic private frame')), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=None, entryPhase='welcome'), None,
             dict(status='absent', entry='welcome')),
            (dict(body, startupFilmFrame=dict(frames=0, shown=-1, done=False)), None,
             dict(snapshot, frames=0, shown=-1)),
            (dict(body, startupFilmFrame=dict(frames=True, shown=0, done=False)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(frames=240, shown=0, done=1)), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, startupFilmFrame=dict(frames=240, shown=0, done=False,
                                             private='synthetic private frame')), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, booted=1), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, walletPresent=True), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (dict(body, entryPhase='synthetic private phase'), None,
             dict(status='unavailable', error_code='STATE_INVALID')),
            (None, profile.launch.startup.Failure('HTTP_FAILED'),
             dict(status='unavailable', error_code='HTTP_FAILED')),
            (None, RuntimeError('synthetic private failure'),
             dict(status='unavailable', error_code='INTERNAL_ERROR')),
        ):
            for deadline in (50.0, 10.25, 9.0):
                offered = deepcopy(reply)
                actor, diagnostic = session(offered, error), {}
                actor.deadline = deadline
                profile._observe_startup_failure(actor, startup, diagnostic)
                actor._rpc.assert_called_once_with(
                    {'cmd': 'wallet-recipe', 'action': 'observe'},
                    until=min(deadline, 11.0))
                self.assertEqual(diagnostic, expected)
                self.assertTrue(profile.valid_startup_observation(diagnostic))
                self.assertNotIn('synthetic private', repr(diagnostic))
                if offered is not None and type(offered.get('startupFilmFrame')) is dict:
                    offered['startupFilmFrame']['frames'] = 'synthetic private replacement'
                    self.assertNotIn('synthetic private', repr(diagnostic))
                profile._observe_startup_failure(actor, startup, diagnostic)
                actor._rpc.assert_called_once()

        for variant, error, expected in (
            ('timeout', TimeoutError('synthetic private timeout'), 'HTTP_FAILED'),
            ('connection', ConnectionRefusedError('synthetic private connection'), 'HTTP_FAILED'),
            ('shared', bounded.SmokeFailure('OUTPUT_INCOMPLETE'), 'OUTPUT_INCOMPLETE'),
            ('invalid', None, 'RESPONSE_INVALID'), ('expired', None, 'TOTAL_DEADLINE'),
        ):
            actor = session()
            del actor._rpc
            actor.token = 'a' * 43
            actor.process = mock.Mock()
            actor.process.poll.return_value = None
            actor.drain = mock.Mock(error=None)
            actor.drain.overflow.is_set.return_value = False
            actor.report = mock.Mock(original_errors=[])
            actor.limits = bounded.Limits()
            actor.transport = mock.Mock()
            actor.transport.exchange.side_effect = error
            actor.transport.exchange.return_value = bounded.Reply(
                200, b'{"ok":1}', 'application/json')
            if variant == 'expired':
                actor.deadline = 9.0
            diagnostic = {}
            profile._observe_startup_failure(actor, startup, diagnostic)
            self.assertEqual(diagnostic, dict(status='unavailable', error_code=expected))
            if variant == 'expired':
                actor.transport.exchange.assert_not_called()
            else:
                actor.transport.exchange.assert_called_once_with(
                    {'cmd': 'wallet-recipe', 'action': 'observe'}, actor.token, 1.0)
            actor.process.wait.assert_not_called()
            actor.process.kill.assert_not_called()

        for failure, reply, field in (
            (startup, body, 'startup_observation'),
            (unconfirmed, dict(body, startupFilmFrame=progress_frame), 'startup_observation'),
            (observation, dict(ok=True, settingsCount=1, bindings=[binding]),
             'navigation_observation'),
        ):
            report, order = {}, []
            original = profile.InteractiveRefused('PROFILE_PREPARATION_REFUSED')
            actor = session(deepcopy(reply))
            actor.process = SimpleNamespace(pid=17)
            actor.transport = SimpleNamespace(port=15432)
            actor.token = 'a' * 43
            actor._rpc.side_effect = lambda *a, **k: (order.append('probe'), deepcopy(reply))[1]

            def owner(*args, **kwargs):
                kwargs['report'].update(deepcopy(failure))
                raise original

            def factory(*args, **kwargs):
                actor.observe = kwargs['observe']
                return actor

            def run(*args, **kwargs):
                instance = kwargs['process_type']()
                with self.assertRaises(profile.InteractiveRefused) as caught:
                    instance.observe(instance)
                self.assertIs(caught.exception, original)
                order.append('cleanup')
                attempt = fixture()['samples']['p06']['attempt']
                attempt.update(action_complete=False, error_codes=['STARTUP_OBSERVATION_REFUSED'])
                return attempt, {}

            with mock.patch.object(profile.launch.entry, 'require_ci',
                    return_value=({'SYRIUS_PAIRED_INTERACTIVE_PROFILE': 'true'}, None)), \
                    mock.patch.object(profile.launch.entry, 'new_profile',
                                      return_value=fixtures.Path('synthetic-profile')), \
                    mock.patch.object(profile.launch.bounded, 'plain',
                                      return_value=SimpleNamespace(st_dev=1, st_ino=2)), \
                    mock.patch.object(profile, 'owned_profile', side_effect=owner), \
                    mock.patch.object(profile, 'InteractiveSession', side_effect=factory), \
                    mock.patch.object(profile.launch, 'run_process', side_effect=run):
                with self.assertRaises(profile.InteractiveRefused) as caught:
                    profile.measure_process(fixtures.Path('synthetic'), fixtures.Path('build'),
                        {}, [], mock.Mock(), mock.Mock(), mock.Mock(), fixture_text='fixture',
                        genesis=GENESIS, first_height=10, report=report)
            self.assertEqual(str(caught.exception), 'FRAME_REFUSED')
            self.assertEqual(order, ['probe', 'cleanup'])
            actor._rpc.assert_called_once()
            self.assertTrue(profile.valid_startup_observation(report[field])
                            if field == 'startup_observation'
                            else profile.valid_navigation_observation(report[field]))
            self.assertFalse(report['success'])
            self.assertEqual(report['observation'], failure)
            self.assertNotIn('synthetic private', json.dumps(report))

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

            def measure(request, validate, *, size, windows, tap_releases,
                        disclosure_phases, page_phases, pointer_phases):
                request(dict(cmd='wait', key='about_page'))
                windows.update(dict.fromkeys(pair.WINDOWS, window))
                tap_releases.update(page_change=50_000, disclosure=60_000)
                disclosure_phases.update(settled=304_000)
                page_phases.update(settled=350_000)
                pointer_phases.update(page_change=dict(move_started=1000, down=2000))

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
            self.assertEqual(report.get('tap_release_us'),
                             None if failed else {'page_change': 50_000, 'disclosure': 60_000})
            self.assertEqual(report.get('page_settled_us'), None if failed else 350_000)
            self.assertEqual(report.get('pointer_phases_us'),
                             None if failed else {'page_change': dict(move_started=1000, down=2000)})
            encoded = cold.canonical(report)
            self.assertNotIn(b'synthetic private failure', encoded)
            self.assertNotIn(b'fixture words', encoded)

        failure = dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
            action='tap', control='welcome_import', reason='wallet-recipe-control-absent',
            entry='startup-initialization-started'))
        marker = (
            b'{"schema":1,"scope":"owned_chain321_frame_profile_preparation",'
            b'"success":false,"error_code":"PREPARATION_REFUSED",'
            b'"failure":{"phase":"importWallet","recipe":{"action":"tap",'
            b'"control":"welcome_import","reason":"wallet-recipe-control-absent",'
            b'"entry":"startup-initialization-started"}}}\n'
        )

        def outcome(raw=marker, **changes):
            value = profile.baseline.Outcome(exit_code=1, exit_observed=True,
                output_complete=True, output_bytes=len(raw), seconds=1, output=raw)
            for key, offered in changes.items():
                setattr(value, key, offered)
            return value

        self.assertEqual(profile.entry_preparation_failure(outcome()), failure)
        self.assertEqual(profile.entry_preparation_failure(outcome(marker[:-1] + b'\r\n')), failure)
        for invalid in (
            dict(exit_code=0), dict(exit_code=True), dict(exit_observed=False),
            dict(forced_kill=True), dict(output_complete=False), dict(output_overflow=True),
            dict(errors=('CLEANUP_FAILED',)), dict(output_bytes=1),
        ):
            with self.subTest(process=invalid):
                self.assertIsNone(profile.entry_preparation_failure(outcome(**invalid)))
        message = inspect.json.loads(marker)
        malformed = (
            dict(message, password='synthetic private input'),
            dict(message, schema=True), dict(message, success=True),
            dict(message, scope='synthetic private scope'),
            dict(message, error_code='synthetic private exception'),
            dict(message, failure=dict(phase='synthetic private phase')),
            dict(message, failure=dict(message['failure'],
                recipe=dict(failure['recipe'], detail='synthetic private reply'))),
        )
        for invalid in malformed:
            raw = inspect.json.dumps(invalid, separators=(',', ':')).encode('ascii') + b'\n'
            with self.subTest(marker=invalid):
                self.assertIsNone(profile.entry_preparation_failure(outcome(raw)))
        for raw in (
            b'synthetic private exception\n', b' ' * 4097, marker + b'private',
            marker.replace(b'"schema":1', b'"schema":1,"schema":1'),
            marker.replace(b'"action":"tap"', b'"action":"tap","action":"tap"'),
            marker.replace(b'"schema":1', b'"schema": 1'),
        ):
            with self.subTest(raw_size=len(raw)):
                self.assertIsNone(profile.entry_preparation_failure(outcome(raw)))
        self.assertIsNone(profile.entry_preparation_failure(outcome(profile.READY + b'\n')))

        commands = []

        def empty_send(command):
            commands.append(command.copy())
            if command['cmd'] == 'ping':
                return dict(ok=True, pid=17, booted=True, harnessMode='wallet')
            self.assertEqual(command, dict(cmd='state'))
            return dict(ok=True, walletUnlocked=False, walletInitCompleted=False, walletPath=None)

        report = {}
        measure = mock.Mock(side_effect=AssertionError('measurement must not start'))
        with mock.patch.object(profile.wallet_tour, 'public_fixture', return_value='fixture words'):
            with self.assertRaises(profile.InteractiveRefused) as caught:
                profile.owned_profile(empty_send, lambda _: outcome(),
                    lambda: dict(chain=321, genesis_hash=GENESIS, last_height=10,
                                 cross_transport_hash_equal=True),
                    measure, mock.Mock(), pid=17, port=15432, token='a' * 43,
                    fixture_text='fixture', genesis=GENESIS, first_height=10, report=report)
        self.assertEqual(str(caught.exception), 'PROFILE_PREPARATION_REFUSED')
        self.assertEqual(report['phase'], 'prepare_profile')
        self.assertEqual(report['preparation_failure'], failure)
        self.assertFalse(report['success'])
        self.assertEqual(report['windows'], {})
        self.assertEqual(commands, [dict(cmd='ping'), dict(cmd='state')])
        measure.assert_not_called()
        self.assertNotIn(b'fixture words', cold.canonical(report))

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
        self.assertIsNone(result['verified_comparisons'])
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
            sample['shutdown_trace'] = dict(status='observed', phase='exitRequested',
                failed=False, event_count=20, output_complete=True,
                elapsed_ms=120_000, max_gap_ms=110_000, max_gap_after='windowPositionRead')
        offered['samples']['current']['observation']['tap_release_us'] = dict.fromkeys(
            pair.WINDOWS, pair.actions.MAX_WINDOW_US - 1)
        offered['samples']['current']['observation']['pointer_phases_us'] = dict.fromkeys(
            pair.WINDOWS, dict(move_started=0, down=pair.actions.MAX_WINDOW_US - 2))
        offered['samples']['current']['observation']['disclosure_phases_us'] = dict(
            settled=pair.actions.MAX_WINDOW_US - 1,
            list_laid_out=pair.actions.MAX_WINDOW_US - 1)
        offered['samples']['current']['observation']['page_settled_us'] = (
            pair.actions.MAX_WINDOW_US - 1)
        offered['comparisons'] = {name: pair.shared.compare_windows(full, full)
                                 for name in pair.WINDOWS}
        self.assertLessEqual(len(cold.canonical(offered)) + 1, pair.MAX_MANIFEST)
        result = self.project(offered)
        self.assertTrue(result['artifact_reported_success'])
        self.assertEqual(result['frame_counts']['p06'], {'page_change': 512, 'disclosure': 512})
        self.assertEqual(result.pop('verified_comparisons'), offered['comparisons'])
        diagnostics = result.pop('verified_window_diagnostics')
        pointer = inspect.split_pointer_diagnostics(diagnostics)
        self.assertEqual(set(pointer), set(pair.WINDOWS))
        self.assertEqual(inspect.split_pointer_diagnostics(diagnostics), {})
        phases = inspect.split_phase_diagnostics(diagnostics)
        self.assertEqual(set(phases), set(pair.WINDOWS))
        self.assertEqual(inspect.split_phase_diagnostics(diagnostics), {})
        self.assertLessEqual(len(cold.canonical(result)), 3800)
        identity = {key: result[key] for key in (
            'schema', 'source_head', 'source_tree', 'source_run_id', 'source_attempt',
            'archive_sha256', 'manifest_sha256')}
        summary = dict(identity, scope='retained_paired_interactive_frame_diagnostics',
                       paired_timing_gate_passed=False, windows=diagnostics)
        self.assertLessEqual(len(cold.canonical(summary)), 3800)
        pointer_summary = dict(identity, scope='retained_interactive_pointer_timing',
                               paired_timing_gate_passed=False, windows=pointer)
        self.assertLessEqual(len(cold.canonical(pointer_summary)), 3800)
        phase_summary = dict(identity, scope='retained_interactive_observed_motion_phases',
                             paired_timing_gate_passed=False, windows=phases)
        self.assertLessEqual(len(cold.canonical(phase_summary)), 3800)
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
        self.assertEqual(result['verified_comparisons'], offered['comparisons'])
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
