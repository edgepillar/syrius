"""Exercise the paired timing reader with finite in-memory receipts."""

import base64
from copy import deepcopy
import contextlib
import io
import json
from pathlib import Path
import struct
import unittest
from unittest import mock
import zipfile
import zlib

from tool.ci import inspect_launch_timing_pair as reader
from tool.ci import inspect_windows_qualification as windows


pair = reader.pair
HEAD, TREE, RUN = 'a' * 40, 'b' * 40, 9


def frame(*rows):
    return dict(schema=1, scope='harness_frame_window', windowUs=3000000,
                frames=[list(row) for row in rows])


def report(pins):
    before = frame((0, 1, 10000, 17000, 28000), (1, 30000, 600, 400, 2000))
    after = frame((0, 2, 9000, 17000, 28000), (1, 30000, 600, 400, 2000))
    actor = dict(theme=pair.launch.TIMING_THEME, action_complete=True,
        checks=dict.fromkeys(pair.launch.ATTEMPT_CHECKS, True), exit_code=0,
        exit_observed=True, forced_kill=False, output_complete=True,
        output_overflow=False, error_codes=[])
    commands = [dict(stage=stage, exit_code=0, exit_observed=True, forced_kill=False,
        output_complete=True, output_overflow=False, output_bytes=0, seconds=1.0,
        success=True, error_codes=[], output_sha256='c' * 64)
        for stage in reader.COMMAND_STAGES]
    free = pair.FLOOR + pair.RESERVATION
    return dict(schema=1, scope=pair.SCOPE, mode='release', theme=pair.launch.TIMING_THEME,
        client=list(pair.launch.TIMING_SIZE), phase='complete', success=True, **pins,
        p06=dict(reader.P06_IDENTITY, overlay_verified=True, runner_sha256='d' * 64,
                 payload_sha256='e' * 64),
        current=dict(runner_sha256='f' * 64, payload_sha256='9' * 64), commands=commands,
        samples=[dict(name=name, frame_window=observed, attempts=[dict(actor, role=role) for role in roles])
                 for (name, roles), observed in zip(reader.SAMPLE_ROLES, (after, before))],
        comparison=pair.compare_windows(before, after), error_codes=[], source_sha=HEAD,
        source_tree=TREE, run_id=str(RUN), run_attempt='1', sdk_revision=pair.prepare.SDK,
        equal_input_objects=reader.P06_INPUTS.copy(), storage=dict(initial_free_bytes=free,
            minimum_free_bytes=free, sampled_additional_bytes=0, floor_bytes=pair.FLOOR,
            reservation_bytes=pair.RESERVATION, samples=2 * len(reader.COMMAND_STAGES) + 4))


def package(value, *, name='manifest.json', extra=False):
    raw = io.BytesIO()
    with zipfile.ZipFile(raw, 'w') as zipped:
        zipped.writestr(name, value if isinstance(value, bytes) else reader.canonical(value))
        if extra:
            zipped.writestr('extra.png', b'forbidden')
    return raw.getvalue()


class Client:
    def __init__(self, *, alter_source=False, extra_job=False):
        patch, collector, profile = b'reviewed-p06-patch', b'frame-collector', b'profile-setup'
        self.sources = {
            'tool/ci/windows_launch_timing_pair.py': Path(pair.__file__).read_bytes(),
            'tool/ci/windows_launch_catalog.py': Path(pair.launch.__file__).read_bytes(),
            pair.PATCH.as_posix(): patch,
            pair.launch.TIMING_SOURCE.as_posix(): collector,
            pair.launch.SETTLE_PROFILE_SOURCE.as_posix(): profile,
        }
        if alter_source:
            self.sources['tool/ci/windows_launch_timing_pair.py'] += b'\n'
        self.pins = dict(baseline_patch_sha256=reader.archive.sha(patch),
                         collector_sha256=reader.archive.sha(collector),
                         profile_sha256=reader.archive.sha(profile))
        self.raw = package(report(self.pins))
        self.calls = []
        self.job = dict(id=4, name=reader.startup_reader.JOB_NAME, head_sha=HEAD,
            run_id=RUN, status='completed', conclusion='success', labels=['windows-latest'],
            steps=[dict(name=name, status='completed', conclusion='success')
                   for name in (pair.JOB_STEP, pair.RETAIN_STEP)])
        self.jobs = [self.job]
        if extra_job:
            self.jobs.append(dict(self.job, id=5, name='Unrelated job'))

    def json(self, path):
        self.calls.append(path)
        if path == '/actions/runs/' + str(RUN):
            return dict(id=RUN, head_sha=HEAD, run_attempt=1, workflow_id=381413107,
                        event='workflow_dispatch', status='completed',
                        repository=dict(full_name='edgepillar/syrius'))
        if path == '/git/commits/' + HEAD:
            return dict(sha=HEAD, tree=dict(sha=TREE))
        if path == '/actions/runs/' + str(RUN) + '/attempts/1/jobs?per_page=20':
            return dict(total_count=len(self.jobs), jobs=self.jobs)
        if path == '/git/commits/' + pair.P06_SOURCE:
            return dict(sha=pair.P06_SOURCE, tree=dict(sha=pair.P06_TREE))
        if path == '/actions/runs/' + str(RUN) + '/artifacts?per_page=20':
            return dict(total_count=1, artifacts=[dict(id=7, expired=False,
                name=f'{pair.ARTIFACT_PREFIX}{HEAD}-{RUN}-1', size_in_bytes=len(self.raw),
                digest='sha256:' + reader.archive.sha(self.raw),
                workflow_run=dict(id=RUN, head_sha=HEAD))])
        if path.startswith('/contents/'):
            name, ref = path.removeprefix('/contents/').split('?ref=')
            if ref != HEAD:
                raise AssertionError(path)
            raw = self.sources[name]
            return dict(type='file', encoding='base64', path=name, size=len(raw),
                        content=base64.b64encode(raw).decode('ascii'))
        raise AssertionError(path)

    def read(self, url, **options):
        self.calls.append(url)
        if (url, options) == (reader.archive.API + '/actions/artifacts/7/zip', {'redirect': True}):
            return 'memory-location'
        if (url, options) == ('memory-location', {'authenticated': False, 'cap': pair.MAX_ARCHIVE}):
            return self.raw
        raise AssertionError((url, options))


class PairInspectionTests(unittest.TestCase):
    def setUp(self):
        self.pins = dict.fromkeys(reader.PIN_FIELDS, '1' * 64)

    def project(self, value, **options):
        raw = package(value, **options)
        return reader.project(raw, reader.archive.sha(raw), len(raw),
                              head=HEAD, tree=TREE, run_id=RUN, pins=self.pins)

    def test_pair_checks_both_windows_and_all_original_closed_actors(self):
        result = self.project(report(self.pins))
        self.assertTrue(result['artifact_reported_success'])
        self.assertTrue(result['no_added_reported_slow_frames'])
        self.assertTrue(result['no_frame_number_gaps'])
        self.assertEqual(result['normal_actor_exits'], 5)
        self.assertEqual(result['frame_counts'], {'p06': 2, 'current': 2})
        self.assertEqual(result['slow_frame_counts'], {'p06': 1, 'current': 1})

    def test_p06_warmup_and_measurement_use_the_selected_baseline_binary(self):
        _, sample = report(self.pins)['samples']
        prepared, warmed, measured = sample['attempts']
        window = sample['frame_window']
        repo, profile, parent = Path('workspace'), Path('profile'), {}
        current, baseline = object(), object()
        retained = dict(samples=[], storage={})
        theme = pair.launch.TIMING_THEME
        with mock.patch.object(pair.launch.entry, 'new_profile', return_value=profile), \
             mock.patch.object(pair.launch.bounded, 'plain', return_value=mock.Mock(st_dev=1, st_ino=2)), \
             mock.patch.object(pair, 'check_space'), \
             mock.patch.object(pair.launch, 'run_process', side_effect=[
                 (prepared, None), (warmed, None), (measured, window)]) as run:
            self.assertEqual(pair.measure_sample(repo, parent, current, baseline, 'p06', retained), window)
        self.assertEqual(run.call_args_list, [
            mock.call(repo, parent, current, profile, theme, capture=False, settle=True),
            mock.call(repo, parent, baseline, profile, theme, capture=False, settle=False),
            mock.call(repo, parent, baseline, profile, theme, capture=True, settle=True,
                      timing=True, lock_diagnostic={}),
        ])
        self.assertEqual(retained['samples'], [sample])

    def test_failed_pair_retains_only_finite_original_lock_observations(self):
        value = report(self.pins)
        value.update(success=False, phase='p06_measure', comparison=None,
                     error_codes=['STARTUP_OBSERVATION_REFUSED'])
        sample = value['samples'][1]
        sample['frame_window'] = None
        diagnostic = dict(status='observed', tab='lock', entry_phase='startup-initialization-started',
            field='disabled', wallet_path_present=True, wallet_unlocked=False, client_at_target=True,
            native_window_ready=True, startup_ready=False, welcome_ready=False, entry_held=False)
        attempt = sample['attempts'][-1]
        attempt.update(action_complete=False, error_codes=['STARTUP_DEADLINE'], lock_diagnostic=diagnostic)
        result = self.project(value)
        self.assertFalse(result['artifact_reported_success'])
        self.assertEqual(result['normal_actor_exits'], 5)
        self.assertEqual(result['attempt_outcomes']['p06'][-1]['lock_diagnostic'], diagnostic)
        film = dict(frames=54, shown=31, done=False)
        attempt['lock_diagnostic'] = dict(diagnostic, film_frame=film)
        retained = self.project(value)['attempt_outcomes']['p06'][-1]['lock_diagnostic']
        self.assertEqual(retained['film_frame'], film)
        for invalid in (dict(diagnostic, path='synthetic private path'),
                        dict(diagnostic, wallet_path_present=1), dict(diagnostic, field='arbitrary'),
                        dict(diagnostic, entry_phase='synthetic source string'),
                        dict(diagnostic, film_frame=dict(film, frames=4097)),
                        dict(diagnostic, film_frame=dict(film, shown=54)),
                        dict(diagnostic, film_frame=dict(film, shown=True)),
                        dict(diagnostic, film_frame=dict(film, done=0)),
                        dict(diagnostic, film_frame=dict(film, raw='synthetic private text'))):
            attempt['lock_diagnostic'] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(reader.archive.Refused):
                self.project(value)

    def test_failed_pair_binds_the_command_receipt_to_its_original_error(self):
        value = report(self.pins)
        value.update(success=False, phase='p06_measure', comparison=None,
                     error_codes=['STARTUP_OBSERVATION_REFUSED'])
        sample = value['samples'][1]
        sample['frame_window'] = None
        attempt = sample['attempts'][-1]
        diagnostic = dict(status='command_refused', stage='frame_window', http_status=400,
                          frame_window_refused=True, frame_reason='frameLimit')
        attempt.update(action_complete=False, error_codes=['COMMAND_FAILED'], lock_diagnostic=diagnostic)
        result = self.project(value)
        self.assertEqual(result['normal_actor_exits'], 5)
        self.assertEqual(result['attempt_outcomes']['p06'][-1]['lock_diagnostic'], diagnostic)
        for invalid in (dict(diagnostic, http_status=True), dict(diagnostic, http_status=500),
                        dict(diagnostic, stage='lock_state'), dict(diagnostic, stage='other'),
                        dict(diagnostic, error='synthetic private text'),
                        dict(diagnostic, frame_reason='synthetic private text'),
                        dict(diagnostic, frame_window_refused=False)):
            attempt['lock_diagnostic'] = invalid
            with self.subTest(invalid=invalid), self.assertRaises(reader.archive.Refused):
                self.project(value)
        attempt.update(lock_diagnostic=diagnostic, error_codes=['STARTUP_DEADLINE'])
        with self.assertRaises(reader.archive.Refused):
            self.project(value)

    def test_pair_preserves_a_regression_and_frame_gaps(self):
        value = report(self.pins)
        value['samples'][0]['frame_window'] = frame((0, 2, 17000, 17000, 35000),
                                                    (2, 30000, 600, 400, 2000))
        value['comparison'] = pair.compare_windows(value['samples'][1]['frame_window'],
                                                   value['samples'][0]['frame_window'])
        result = self.project(value)
        self.assertTrue(result['artifact_reported_success'])
        self.assertFalse(result['no_added_reported_slow_frames'])
        self.assertFalse(result['no_frame_number_gaps'])

    def test_pair_retains_the_full_frame_limit_within_one_manifest(self):
        value = report(self.pins)
        full = dict(schema=1, scope='harness_frame_window', windowUs=60000000,
                    frames=[[0 if index == 0 else 2**32 - 512 + index,
                             59999999, 20000000, 20000000, 60000000]
                            for index in range(pair.launch.MAX_TIMING_FRAMES)])
        for sample in value['samples']:
            sample['frame_window'] = full
        value['comparison'] = pair.compare_windows(full, full)
        self.assertLessEqual(len(reader.canonical(value)) + 1, pair.MAX_MANIFEST)
        result = self.project(value)
        self.assertEqual(result['frame_counts'], {'p06': 512, 'current': 512})
        self.assertEqual(result['slow_frame_counts'], {'p06': 512, 'current': 512})

    def test_packed_pair_preserves_all_frames_and_rejects_corrupt_payloads(self):
        count = pair.launch.MAX_PAIRED_TIMING_FRAMES
        rows = [[0 if index == 0 else 2**32 - count + index,
                 index * 14000, 20000000, 20000000, 60000000]
                for index in range(count)]
        raw = b''.join(struct.pack('<5I', *row) for row in rows)
        packed = zlib.compress(raw)
        original = dict(schema=2, scope='harness_frame_window', windowUs=60000000,
                        frameCount=count, packedFrames=base64.b64encode(packed).decode('ascii'))
        self.assertEqual(pair.launch.frame_timing_rows(original, allow_packed=True), rows)
        with self.assertRaises(pair.launch.startup.Failure):
            pair.launch.frame_timing_window(original)
        value = report(self.pins)
        for sample in value['samples']:
            sample['frame_window'] = original
        value['comparison'] = pair.compare_windows(original, original)
        self.assertLessEqual(len(reader.canonical(value)) + 1, pair.MAX_MANIFEST)
        result = self.project(value)
        self.assertEqual(result['frame_counts'], {'p06': count, 'current': count})
        self.assertEqual(result['slow_frame_counts'], {'p06': count, 'current': count})
        self.assertFalse(result['no_frame_number_gaps'])
        self.assertEqual(result['frame_window_sha256']['p06'], reader.archive.sha(reader.canonical(original)))

        trailing = base64.b64encode(packed + b'\0').decode('ascii')
        truncated = base64.b64encode(packed[:-1]).decode('ascii')
        oversized = base64.b64encode(zlib.compress(raw + raw)).decode('ascii')
        for change in (dict(frameCount=count - 1), dict(frameCount=count + 1),
                       dict(frameCount=True), dict(packedFrames='!'), dict(packedFrames=trailing),
                       dict(packedFrames=truncated), dict(packedFrames=oversized)):
            with self.subTest(change=tuple(change)), self.assertRaises(pair.launch.startup.Failure):
                pair.launch.frame_timing_rows(dict(original, **change), allow_packed=True)

    def test_pair_keeps_partial_failure_with_a_forced_actor(self):
        value = report(self.pins)
        timing = value['samples'][1]
        timing['attempts'][-1].update(forced_kill=True, action_complete=False,
                                      exit_code=1, error_codes=['COMMAND_FAILED'])
        timing['frame_window'] = None
        value.update(success=False, comparison=None, phase='p06_measure',
                     error_codes=['STARTUP_OBSERVATION_REFUSED'])
        result = self.project(value)
        self.assertFalse(result['artifact_reported_success'])
        self.assertEqual(result['normal_actor_exits'], 4)
        self.assertEqual(result['frame_counts'], {'current': 2})

    def test_pair_preserves_current_failure_before_baseline_allocation(self):
        value = report(self.pins)
        value['samples'] = value['samples'][:1]
        timing = value['samples'][0]
        timing['attempts'][-1].update(action_complete=False, error_codes=['ENTRY_UNAVAILABLE'])
        timing['frame_window'] = None
        command = value['commands'][0]
        value.update(success=False, comparison=None, phase='current_measure', commands=[],
                     p06=dict(reader.P06_IDENTITY, overlay_verified=False),
                     error_codes=['STARTUP_OBSERVATION_REFUSED'])
        value.pop('sdk_revision')
        value.pop('equal_input_objects')
        result = self.project(value)
        self.assertFalse(result['artifact_reported_success'])
        self.assertEqual(result['normal_actor_exits'], 2)
        self.assertEqual(result['frame_counts'], {})
        self.assertEqual(result['attempt_outcomes']['current'][-1]['error_codes'],
                         ['ENTRY_UNAVAILABLE'])
        value['commands'].append(command)
        with self.assertRaises(reader.archive.Refused):
            self.project(value)

    def test_pair_refuses_changed_source_closed_actor_and_comparison_claims(self):
        cases = (
            lambda value: value['p06'].update(overlay_tree='f' * 40),
            lambda value: value['equal_input_objects'].update({'pubspec.lock': 'f' * 40}),
            lambda value: value['commands'].pop(reader.COMMAND_STAGES.index('build_p06_release')),
            lambda value: value['samples'][0]['attempts'][0].update(forced_kill=True),
            lambda value: value['samples'][0]['frame_window']['frames'][0].__setitem__(2, True),
            lambda value: value['comparison'].update(no_added_reported_slow_frames=1),
            lambda value: value['storage'].update(floor_bytes=float(pair.FLOOR)),
            lambda value: value['storage'].update(samples=1),
        )
        original = report(self.pins)
        for index, change in enumerate(cases):
            value = deepcopy(original)
            change(value)
            with self.subTest(change=index), self.assertRaises(reader.archive.Refused):
                self.project(value)

    def test_pair_refuses_extra_members_and_duplicate_manifest_keys(self):
        original = report(self.pins)
        for options in ({'extra': True}, {'name': 'nested/manifest.json'}):
            with self.subTest(options=options), self.assertRaises(reader.archive.Refused):
                self.project(original, **options)
        duplicated = reader.canonical(original).replace(b'"schema":1', b'"schema":1,"schema":1', 1)
        with self.assertRaises(reader.archive.Refused):
            self.project(duplicated)

    def test_pair_routes_only_the_exact_source_and_one_archive_in_twelve_calls(self):
        env = dict(GITHUB_ACTIONS='true', SYRIUS_HOSTED_RUNNER='github-hosted',
                   GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='edgepillar/syrius',
                   WINDOWS_INSPECT_RUN=str(RUN), WINDOWS_INSPECT_HEAD=HEAD, GH_TOKEN='unused')
        for offered, expected, calls in ((Client(), 0, 12), (Client(alter_source=True), 1, 4),
                                          (Client(extra_job=True), 1, 3)):
            output = io.StringIO()
            with self.subTest(expected=expected, calls=calls), \
                 mock.patch.dict(windows.os.environ, env, clear=True), \
                 mock.patch.object(windows.archive, 'Client', return_value=offered), \
                 mock.patch.object(pair, 'PATCH_SHA256', offered.pins['baseline_patch_sha256']), \
                 mock.patch.object(pair, 'COLLECTOR_SHA256', offered.pins['collector_sha256']), \
                 contextlib.redirect_stdout(output):
                self.assertEqual(windows.main(), expected)
                self.assertEqual(len(offered.calls), calls)
                if expected == 0:
                    first = json.loads(output.getvalue().splitlines()[0])
                    self.assertEqual(first['scope'], 'retained_' + pair.SCOPE)
                    self.assertEqual(first['original_job_id'], 4)
                else:
                    self.assertNotIn('memory-location', offered.calls)
