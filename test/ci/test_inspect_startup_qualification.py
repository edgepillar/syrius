"""Paired original-report controls using memory and bounded fake transport."""

import base64
import builtins
import contextlib
import io
import json
from pathlib import Path
import struct
import types
import unittest
from unittest import mock
import zipfile
import zlib

from tool.ci import inspect_startup_qualification as inspect
from tool.ci import inspect_windows_qualification as windows


HEAD, TREE, RUN = 'a' * 40, 'b' * 40, 9


def positive_report(*, natural_only=False):
    """Keep fixture construction independent of any external test package."""
    report = inspect.startup.Report(natural_only=natural_only)
    report.source_sha, report.source_tree = HEAD, TREE
    report.run_id, report.run_attempt = str(RUN), '1'
    report.runner_sha256, report.payload_sha256 = 'c' * 64, 'd' * 64
    report.checks = dict.fromkeys(inspect.startup.CHECKS, True)
    report.handoff = 'natural' if natural_only else 'key-confirmed'
    report.key_attempts = 0 if natural_only else 1
    report.exit_observed, report.exit_code, report.output_complete = True, 0, True
    report.samples = [dict(at_ms=1000, phase='startup-before-initialization',
        progress=dict(frames=56, shown=0, decoding=12, stage='frame',
                      skip=not natural_only, pending=False, ticking=True, done=False))]
    if natural_only:
        report.prior_manifest_sha256 = 'e' * 64
    return report


def package(report, *, extra=False):
    manifest = (json.dumps(report, sort_keys=True) + '\n').encode('ascii')
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_STORED) as zipped:
        zipped.writestr('manifest.json', manifest)
        if extra:
            zipped.writestr('private.txt', b'private-state')
    return stream.getvalue(), manifest


def pair(*, negative=False):
    ordinary, manifest = package(positive_report().public())
    natural = positive_report(natural_only=True)
    natural.prior_manifest_sha256 = inspect.archive.sha(manifest)
    if negative:
        natural.startup_deadline_expired = True
        natural.fail('STARTUP_DEADLINE')
    return ordinary, package(natural.public())[0]


class Client:
    def __init__(self, *, negative=False, source_changed=False, missing=False,
                 mixed=False, duplicate=False):
        self.calls = []
        self.bodies = dict(zip((7, 8), pair(negative=negative)))
        self.source_changed, self.missing = source_changed, missing
        self.mixed, self.duplicate = mixed, duplicate
        self.job = dict(id=17, name=inspect.JOB_NAME, head_sha=HEAD, run_id=RUN,
                        status='completed', conclusion='failure' if negative else 'success')

    def json(self, path):
        self.calls.append(path)
        if path == '/actions/runs/9':
            return dict(id=RUN, head_sha=HEAD, run_attempt=1, workflow_id=381413107,
                        event='workflow_dispatch', status='completed',
                        repository=dict(full_name='edgepillar/syrius'))
        if path == '/git/commits/' + HEAD:
            return dict(sha=HEAD, tree=dict(sha=TREE))
        if path.startswith('/contents/tool/ci/'):
            name = path.split('/')[-1].partition('?')[0]
            body = Path(inspect.__file__).with_name(name).read_bytes()
            if self.source_changed and name == 'windows_startup_probe.py':
                body += b'\n# changed producer\n'
            return dict(type='file', path='tool/ci/' + name, encoding='base64',
                        size=len(body), content=base64.b64encode(body).decode())
        if path == '/actions/runs/9/attempts/1/jobs?per_page=20':
            other = dict(id=18, name='Hosted Windows baseline', head_sha=HEAD,
                         run_id=RUN, status='completed', steps=[],
                         conclusion='success' if self.mixed else 'skipped')
            rows = [self.job, other]
            if self.duplicate:
                rows.append(dict(self.job))
            return dict(total_count=len(rows), jobs=rows)
        if path == '/actions/runs/9/artifacts?per_page=20':
            names = ('windows-startup-probe-', 'windows-natural-startup-probe-')
            rows = [dict(id=number, expired=False,
                         name=prefix + HEAD + '-9-1', size_in_bytes=len(self.bodies[number]),
                         digest='sha256:' + inspect.archive.sha(self.bodies[number]),
                         workflow_run=dict(id=RUN, head_sha=HEAD))
                    for number, prefix in zip((7, 8), names)]
            if self.missing:
                rows.pop()
            return dict(total_count=len(rows), artifacts=rows)
        raise AssertionError('Unexpected metadata query')

    def read(self, url, *, redirect=False, authenticated=True, cap=262144):
        self.calls.append(url)
        if redirect:
            if not authenticated or url.rsplit('/', 1)[-1] != 'zip':
                raise AssertionError('Unexpected redirect')
            number = int(url.split('/')[-2])
            return 'https://synthetic.blob.core.windows.net/' + str(number)
        if authenticated or cap != inspect.MAX_ARCHIVE:
            raise AssertionError('Credentials or unbounded artifact read')
        data = self.bodies[int(url.rsplit('/', 1)[-1])]
        if len(data) > cap:
            raise AssertionError('Oversized artifact')
        return data


def _png(sample=0):
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data)))

    row = bytes((0, sample)) + bytes(1280 * 3 - 1)
    return (b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', 1280, 780, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(row * 780))
        + chunk(b'IEND', b''))


class StartupInspectionTests(unittest.TestCase):
    def test_cold_launch_requires_exact_frame_geometry_and_normal_actor_exits(self):
        self._check_launch_catalog(settle=False)

    def test_launch_timing_waits_for_the_original_enabled_lock_field(self):
        launch = inspect.launch
        process = object.__new__(launch.LaunchProcess)
        process.deadline, process.started = 65, 0
        process.clock, process.sleep = lambda: 0, mock.Mock()
        process.limits = launch.LIMITS
        lock = dict(kind='field', key='wallet_password_field')
        report = dict(schema=1, scope='harness_frame_window', windowUs=3000000,
                      frames=[[0, 10, 200, 300, 500]])
        process._exchange = mock.Mock(side_effect=[
            (400, dict(ok=False, error='not there after 0 ms')),
            (400, dict(ok=False, error='not ready after 0 ms')),
            (200, dict(ok=True, target=dict(lock, enabled=False))),
            (200, dict(ok=True, target=lock)),
            (200, dict(ok=True, booted=True, walletUnlocked=False, size=[1200, 600])),
            (200, dict(ok=True, target=lock)),
            (200, dict(ok=True, booted=True, walletUnlocked=False, size=[1280, 780])),
            (200, dict(ok=True, **report)),
        ])
        self.assertEqual(process._observe_frame_timing(), report)
        wait = dict(cmd='wait', key='wallet_password_field', kind='field',
                    exact=True, ready=True, timeoutMs=0)
        self.assertEqual(process._exchange.call_args_list, [
            *[mock.call(wait, until=20)] * 4,
            mock.call(dict(cmd='state'), until=20),
            mock.call(wait, until=20),
            mock.call(dict(cmd='state'), until=20),
            mock.call(dict(cmd='stalls', frameWindow='end'), until=60),
        ])
        self.assertEqual(process.sleep.call_args_list, [mock.call(launch.LIMITS.poll)] * 4)

        count = launch.MAX_TIMING_FRAMES + 1
        packed = zlib.compress(b''.join(struct.pack('<5I', i, i, 10, 5, 20) for i in range(count)))
        receipt = dict(schema=2, scope='harness_frame_window', windowUs=1000000,
                       frameCount=count, packedFrames=base64.b64encode(packed).decode('ascii'))
        process._exchange = mock.Mock(side_effect=[
            (200, dict(ok=True, target=lock)),
            (200, dict(ok=True, booted=True, walletUnlocked=False, size=[1280, 780])),
            (200, dict(ok=True, **receipt)),
        ])
        self.assertEqual(process._observe_frame_timing(paired=True), receipt)
        self.assertEqual(process._exchange.call_count, 3)

    def test_launch_timing_keeps_pending_distinct_from_an_actual_command_failure(self):
        launch = inspect.launch
        cases = (
            ((400, dict(ok=False, error='not there after 0 ms')), 'STARTUP_DEADLINE'),
            ((400, dict(ok=False, error='not ready after 0 ms')), 'STARTUP_DEADLINE'),
            ((400, dict(ok=False, error='bad token')), 'COMMAND_FAILED'),
            ((500, dict(ok=False, error='not ready after 0 ms')), 'COMMAND_FAILED'),
        )
        for reply, code in cases:
            with self.subTest(reply=reply):
                process = object.__new__(launch.LaunchProcess)
                process.deadline, process.started, process.limits = 65, 0, launch.LIMITS
                process.clock = mock.Mock(side_effect=(0, 0, 0, 20))
                process.sleep = mock.Mock()
                process._exchange = mock.Mock(return_value=reply)
                with self.assertRaisesRegex(inspect.startup.Failure, '^' + code + '$'):
                    process._observe_frame_timing()
                self.assertEqual(process._exchange.call_count, 1)

    def test_paired_lock_retains_the_original_refused_request(self):
        launch = inspect.launch
        field = (200, dict(ok=True, target=dict(kind='field', key='wallet_password_field')))
        state = (200, dict(ok=True, booted=True, walletUnlocked=False, size=[1280, 780]))
        cases = (
            ('password_readiness', [(400, dict(ok=False, error='synthetic private text'))], False),
            ('lock_state', [field, (500, dict(ok=False, error='synthetic private text'))], False),
            ('frame_window', [field, state, (400, dict(ok=False, error='frame-window-unqualified',
                detail=dict(reason='frameLimit')))], True),
            ('frame_window', [field, state, (400, dict(ok=False, error='frame-window-unqualified',
                detail=dict(reason='synthetic private text')))], True),
        )
        for stage, responses, frame_refusal in cases:
            with self.subTest(stage=stage):
                process = object.__new__(launch.LaunchProcess)
                process.deadline, process.started, process.limits = 65, 0, launch.LIMITS
                process.clock = lambda: 1
                process.report = inspect.startup.Report()
                process.process = process.drain = None
                process.authenticated = process.quit_sent = False
                process._ready = mock.Mock()
                process._exchange = mock.Mock(side_effect=responses)
                process._lock_diagnostic = mock.Mock()
                diagnostic = {}
                with mock.patch.object(launch.bounded, 'finish_original'):
                    attempt, frames = process.run_launch('dark', capture=True, settle=True,
                        timing=True, lock_diagnostic=diagnostic)
                self.assertIsNone(frames)
                self.assertEqual(attempt['error_codes'], ['COMMAND_FAILED'])
                self.assertEqual(process._exchange.call_count, len(responses))
                expected = dict(status='command_refused', stage=stage,
                    http_status=responses[-1][0], frame_window_refused=frame_refusal)
                if responses[-1][1].get('detail') == {'reason': 'frameLimit'}:
                    expected['frame_reason'] = 'frameLimit'
                self.assertEqual(diagnostic, expected)
                process._lock_diagnostic.assert_not_called()

    def test_paired_lock_readiness_budget_and_passive_failure_readout(self):
        launch = inspect.launch
        process = object.__new__(launch.LaunchProcess)
        process.deadline, process.started, process.limits = 65, 0, launch.LIMITS
        process.clock, process.sleep = mock.Mock(side_effect=(1, 2, 50)), mock.Mock()
        process._exchange = mock.Mock(return_value=(400, dict(ok=False, error='not ready after 0 ms')))
        with self.assertRaisesRegex(inspect.startup.Failure, '^STARTUP_DEADLINE$'):
            process._observe_frame_timing(paired=True)
        self.assertEqual(process._exchange.call_args.kwargs['until'], 50)

        process.clock = lambda: 50
        process._rpc = mock.Mock(side_effect=[
            dict(ok=True, booted=True, walletPath='synthetic private path',
                 size=[1280, 780], tab='lock', walletUnlocked=False),
            dict(ok=True, available=True, nativeWindowReady=True, startupReady=False,
                 welcomeReady=False, held=False),
            dict(ok=True, entryPhase='startup-initialization-started'),
        ])
        process._exchange = mock.Mock(return_value=(200, dict(ok=True,
            target=dict(key='wallet_password_field', kind='field', enabled=False))))
        observed = process._lock_diagnostic()
        self.assertEqual(observed['status'], 'observed')
        self.assertEqual(observed['field'], 'disabled')
        self.assertTrue(observed['wallet_path_present'])
        self.assertNotIn('synthetic private path', json.dumps(observed))
        self.assertEqual([call.args[0]['cmd'] for call in process._rpc.call_args_list],
                         ['state', 'entry-state', 'wallet-recipe'])
        legacy = dict(frames=54, shown=31, done=False)
        current = dict(legacy, decoding=32, stage='frame', skip=False,
                       pending=True, ticking=True)
        for fields, expected in (
            (dict(startupFilmFrame=legacy), legacy),
            (dict(startupFilmProgress=current), legacy),
            (dict(startupFilmFrame=dict(legacy, shown=54)), None),
            (dict(startupFilmFrame=dict(legacy, done=0)), None),
            (dict(startupFilmFrame=dict(legacy, path='synthetic private path')), None),
            (dict(startupFilmProgress=dict(current, stage='synthetic private stage')), None),
        ):
            with self.subTest(fields=fields):
                process._rpc = mock.Mock(side_effect=[
                    dict(ok=True, booted=True, walletPath=None, size=[1280, 780],
                         tab=None, walletUnlocked=False),
                    dict(ok=True, available=True, nativeWindowReady=True,
                         startupReady=False, welcomeReady=False, held=False),
                    dict(ok=True, entryPhase='startup-before-initialization', **fields),
                ])
                observed = process._lock_diagnostic()
                self.assertEqual(observed['status'], 'observed')
                self.assertEqual(observed.get('film_frame'), expected)
                self.assertEqual(process._rpc.call_count, 3)
                self.assertNotIn('synthetic private', json.dumps(observed))
        process._rpc = mock.Mock(side_effect=inspect.startup.Failure('HTTP_FAILED'))
        self.assertEqual(process._lock_diagnostic(), dict(status='unavailable', error_code='HTTP_FAILED'))

    def test_launch_timing_refuses_unrestored_geometry_at_its_deadline(self):
        launch = inspect.launch
        process = object.__new__(launch.LaunchProcess)
        process.deadline, process.started = 65, 0
        process.clock = mock.Mock(side_effect=(0, 0, 0, 20))
        process.sleep = mock.Mock()
        process.limits = launch.LIMITS
        process._exchange = mock.Mock(side_effect=[
            (200, dict(ok=True, target=dict(kind='field', key='wallet_password_field'))),
            (200, dict(ok=True, booted=True, walletUnlocked=False, size=[1200, 600])),
        ])
        with self.assertRaisesRegex(inspect.startup.Failure, '^WINDOW_INVALID$'):
            process._observe_frame_timing()
        self.assertEqual(process._exchange.call_args_list[-1], mock.call(dict(cmd='state'), until=20))
        self.assertEqual(process._exchange.call_count, 2)

    def test_launch_timing_main_retains_one_manifest_without_a_capture(self):
        launch = inspect.launch
        repo = Path.cwd()
        profile = repo / 'fixture-profile'
        binaries = tuple((repo / path, 'c' * 64, (1, 2, 3, 4))
                         for path in (inspect.startup.BINARY, inspect.startup.PAYLOAD))
        facts = dict(theme='dark', action_complete=True, exit_observed=True,
            exit_code=0, forced_kill=False, output_complete=True, output_overflow=False,
            checks=dict.fromkeys(launch.ATTEMPT_CHECKS, True), error_codes=[])
        frames = dict(schema=1, scope='harness_frame_window', windowUs=2000000,
                      frames=[[0, 10, 200, 400, 610]])
        environment = dict(SYRIUS_WINDOWS_LAUNCH_CATALOG=launch.TIMING_SCREEN)
        parent = dict(GITHUB_REPOSITORY='edgepillar/syrius',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_RUN_ATTEMPT='1',
            GITHUB_RUN_ID=str(RUN), GITHUB_WORKSPACE=str(repo),
            SYRIUS_WINDOWS_STARTUP_PROBE='true')
        identity = types.SimpleNamespace(st_dev=1, st_ino=2)
        output = io.StringIO()
        open_output = mock.mock_open()
        with contextlib.ExitStack() as stack:
            for patch in (
                mock.patch.dict(launch.os.environ, environment, clear=True),
                mock.patch.object(launch.sys, 'argv', ['windows_launch_catalog']),
                mock.patch.object(launch.entry, 'require_ci', return_value=(parent, HEAD)),
                mock.patch.object(launch.entry, 'source_tree', return_value=TREE),
                mock.patch.object(launch.entry, 'private_root'),
                mock.patch.object(launch.entry, 'new_profile', return_value=profile),
                mock.patch.object(launch.bounded, 'plain', return_value=identity),
                mock.patch.object(launch.bounded, 'verify_source'),
                mock.patch.object(launch.bounded, 'binary_hash', side_effect=[*binaries, *binaries]),
                mock.patch.object(Path, 'mkdir'), mock.patch.object(Path, 'read_bytes', return_value=b'fixture'),
                mock.patch.object(Path, 'open', open_output),
                contextlib.redirect_stdout(output),
            ):
                stack.enter_context(patch)
            original = stack.enter_context(mock.patch.object(launch, 'run_process', side_effect=[
                (dict(facts, role='prepare'), None), (dict(facts, role='timing'), frames),
            ]))
            self.assertEqual(launch.main(), 0)
        self.assertEqual(original.call_args_list, [
            mock.call(repo, parent, binaries, profile, 'dark', capture=False, settle=True),
            mock.call(repo, parent, binaries, profile, 'dark', capture=True, settle=True, timing=True),
        ])
        open_output.assert_called_once_with('xb')
        manifest = json.loads(open_output().write.call_args.args[0])
        self.assertEqual(manifest['frame_window'], frames)
        self.assertEqual(manifest['source_tree'], TREE)
        self.assertNotIn('captures', manifest)
        notice = json.loads(output.getvalue().split('::', 2)[-1])
        self.assertEqual(notice['frame_count'], 1)
        self.assertNotIn('frame_window', notice)

    def test_launch_timing_archive_requires_exact_closed_numeric_observation(self):
        launch = inspect.launch
        pins = dict(profile_sha256='c' * 64, collector_sha256='d' * 64)
        frame = dict(schema=1, scope='harness_frame_window', windowUs=1200000,
                     frames=[[0, 0, 3000, 4100, 7200]])
        facts = dict(theme='dark', action_complete=True, exit_observed=True,
            exit_code=0, forced_kill=False, output_complete=True, output_overflow=False,
            checks=dict.fromkeys(launch.ATTEMPT_CHECKS, True), error_codes=[])
        report = dict(schema=1, scope=launch.TIMING_SCOPE, success=True, mode='release',
            theme='dark', client=[1280, 780], frame_window=frame, source_stable=True,
            source_sha=HEAD, source_tree=TREE, run_id=str(RUN), run_attempt='1',
            runner_sha256='e' * 64, payload_sha256='f' * 64, error_codes=[],
            attempts=[dict(facts, role='prepare'), dict(facts, role='timing')], **pins)

        def read(value, *, extra=False):
            raw, _ = package(value, extra=extra)
            return inspect.launch_archive(raw, inspect.archive.sha(raw), len(raw),
                HEAD, TREE, RUN, pins, timing=True)

        summary = read(report)
        self.assertEqual(summary['frame_count'], 1)
        self.assertEqual(summary['window_us'], 1200000)
        self.assertEqual(summary['verified_png_count'], 0)
        self.assertFalse(summary['baseline_compared'])
        self.assertTrue(summary['artifact_reported_success'])
        for change in (dict(frame_window=None), dict(collector_sha256='1' * 64),
                       dict(mode='debug'), dict(client=[1280, 781]),
                       dict(attempts=[report['attempts'][0],
                            dict(report['attempts'][1], forced_kill=True)])):
            with self.subTest(change=change), self.assertRaises(inspect.archive.Refused):
                read(dict(report, **change))
        with self.assertRaises(inspect.archive.Refused):
            read(report, extra=True)
        partial = dict(report, success=False, source_stable=False, frame_window=None,
                       attempts=report['attempts'][:1], error_codes=['ENTRY_INVALID'])
        self.assertFalse(read(partial)['artifact_reported_success'])

    def test_launch_timing_routes_without_requesting_any_legacy_startup_archive(self):
        client = Client()
        client.job['steps'] = [dict(name=inspect.launch.TIMING_JOB_STEP,
                                    status='completed', conclusion='success')]
        summary = dict(scope='retained_original_cold_lock_frame_timing',
                       frame_count=1, artifact_reported_success=True)
        with mock.patch.object(inspect, 'inspect_launch_run', return_value=summary) as reader:
            status, output = self.read_windows(client)
        self.assertEqual(status, 0)
        self.assertIn('retained_original_cold_lock_frame_timing', output)
        self.assertTrue(reader.call_args.kwargs['timing'])
        self.assertFalse(any('/artifacts' in path for path in client.calls))

    def test_launch_timing_refuses_unlocked_or_non_numeric_samples(self):
        launch = inspect.launch
        process = object.__new__(launch.LaunchProcess)
        process.deadline, process.started = 65, 0
        process.clock, process.limits = lambda: 0, launch.LIMITS
        process._exchange = mock.Mock(side_effect=[
            (200, dict(ok=True, target=dict(kind='field', key='wallet_password_field'))),
            (200, dict(ok=True, booted=True, walletUnlocked=True, size=[1280, 780])),
        ])
        with self.assertRaisesRegex(inspect.startup.Failure, '^ENTRY_INVALID$'):
            process._observe_frame_timing()
        self.assertEqual(process._exchange.call_args_list[-1], mock.call(dict(cmd='state'), until=20))
        self.assertEqual(process._exchange.call_count, 2)
        good = dict(schema=1, scope='harness_frame_window', windowUs=1000,
                    frames=[[0, 0, 30, 40, 70]])
        for bad in (dict(schema=True), dict(frames=[]), dict(private='private'),
                    dict(frames=[[0, 1, 60, 40, 99]]),
                    dict(frames=[[0, 0, 30, 40, 70], [0, 1, 30, 40, 70]])):
            with self.subTest(bad=bad), self.assertRaises(inspect.startup.Failure):
                launch.frame_timing_window(dict(good, **bad))

    def test_launch_settle_requires_original_handoff_and_intermediate_geometry(self):
        self._check_launch_catalog(settle=True)

    def _check_launch_catalog(self, *, settle):
        pixels = _png()
        pins = dict(recipe_sha256='c' * 64, capture_source_sha256='d' * 64)
        if settle:
            pins['profile_sha256'] = 'a' * 64
        attempts = [dict(theme=theme, role=role, action_complete=True,
            checks=dict.fromkeys(inspect.launch.ATTEMPT_CHECKS, True), exit_code=0,
            exit_observed=True, forced_kill=False, output_complete=True,
            output_overflow=False, error_codes=[])
            for theme in inspect.launch.THEMES for role in ('prepare', 'capture')]
        captures = []
        files = inspect.launch.SETTLE_FILES if settle else inspect.launch.FILES
        for theme, name in zip(inspect.launch.THEMES, files):
            state = (dict(frame=55, frames=56, stage=[220, 88, 840, 410],
                          well=[430, 194, 420, 118], lockHandoff=True, progress=.52)
                     if settle else dict(frame=23, frames=56, stage=[0, 32, 1280, 748]))
            reply = dict(ok=True, status='captured', theme=theme,
                         png=base64.b64encode(pixels).decode(), **state)
            original, state = inspect.launch.launch_pixels(reply, theme, settle=settle)
            self.assertEqual(original, pixels)
            captures.append(dict(theme=theme, file=name, bytes=len(pixels),
                sha256=inspect.archive.sha(pixels), **state))
            refusals = [dict(frame=24), dict(stage=[0, 32, 10, 10]), dict(frames=True)]
            if settle:
                refusals += [dict(progress=.39), dict(progress=.73),
                             dict(lockHandoff=False), dict(well=[0, 0, 960, 480])]
            for wrong in refusals:
                with self.assertRaises(inspect.startup.Failure):
                    inspect.launch.launch_pixels(dict(reply, **wrong), theme, settle=settle)
        scope = inspect.launch.SETTLE_SCOPE if settle else inspect.launch.SCOPE
        report = dict(schema=1, scope=scope, success=True,
            attempts=attempts, captures=captures, source_stable=True, error_codes=[],
            source_sha=HEAD, source_tree=TREE, run_id=str(RUN), run_attempt='1',
            runner_sha256='e' * 64, payload_sha256='f' * 64, **pins)

        def read(value):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, 'w') as zipped:
                zipped.writestr('manifest.json', json.dumps(value))
                for row in value['captures']:
                    zipped.writestr(row['file'], pixels)
            raw = buffer.getvalue()
            return inspect.launch_archive(raw, inspect.archive.sha(raw), len(raw),
                HEAD, TREE, RUN, pins, settle=settle)

        actual = read(report)
        self.assertTrue(actual['artifact_reported_success'])
        self.assertEqual(actual['verified_png_count'], 2)
        self.assertEqual(actual['filenames'], list(files))
        if settle:
            self.assertEqual(actual['handoff_progress'], [.52, .52])
            with self.assertRaises(inspect.archive.Refused):
                read(dict(report, captures=[dict(captures[0], lockHandoff=False), captures[1]]))
        failed = dict(attempts[2], action_complete=False, forced_kill=True)
        with self.assertRaises(inspect.archive.Refused):
            read(dict(report, attempts=attempts[:2] + [failed, attempts[3]]))
        partial = read(dict(report, attempts=attempts[:2] + [failed], captures=captures[:1],
            source_stable=False, success=False, error_codes=['STARTUP_OBSERVATION_REFUSED']))
        self.assertFalse(partial['artifact_reported_success'])
        self.assertEqual(partial['verified_png_count'], 1)

    def test_lock_seams_require_exact_absorbed_controls_and_closed_actors(self):
        catalog = inspect.lock_catalog
        pins = dict.fromkeys(('capture_source_sha256', 'profile_sha256',
                              *catalog.SEAM_PIN_SOURCES), 'e' * 64)
        attempts = [dict(theme='dark', role=role, phase=phase, action_complete=True,
            checks=dict.fromkeys(inspect.launch.ATTEMPT_CHECKS, True), exit_code=0,
            exit_observed=True, forced_kill=False, output_complete=True,
            output_overflow=False, error_codes=[])
            for role, phase in (('prepare', 'prepare'), ('observe', 'complete'))]
        expected = [seam for _, seam in catalog.SEAM_ACTIONS]
        report = dict(schema=1, scope=catalog.SEAM_SCOPE, success=True, attempts=attempts,
            captures=[], seam_refusals=expected, source_stable=True, error_codes=[],
            source_sha=HEAD, source_tree=TREE, run_id=str(RUN), run_attempt='1',
            runner_sha256='c' * 64, payload_sha256='d' * 64, **pins)

        def read(value, *, extra=False):
            raw, _ = package(value, extra=extra)
            return inspect.launch_archive(raw, inspect.archive.sha(raw), len(raw), HEAD, TREE,
                                          RUN, pins, lock_seams=True)

        result = read(report)
        self.assertTrue(result['artifact_reported_success'])
        self.assertEqual(result['verified_png_count'], 0)
        self.assertEqual(result['seam_refusals'], expected)
        self.assertEqual(result['normal_actor_exits'], 2)
        for change in (dict(seam_refusals=expected[::-1]), dict(seam_refusals=expected[:1]),
                       dict(captures=[{}]), dict(attempts=attempts[:1]),
                       dict(attempts=[attempts[0], dict(attempts[1], forced_kill=True)])):
            with self.subTest(change=change), self.assertRaises(inspect.archive.Refused):
                read(dict(report, **change))
        with self.assertRaises(inspect.archive.Refused):
            read(report, extra=True)
        partial = read(dict(report, success=False, source_stable=False,
            seam_refusals=expected[:1], error_codes=['STARTUP_OBSERVATION_REFUSED'],
            attempts=[attempts[0], dict(attempts[1], phase='seam_probes',
                action_complete=False, error_codes=['COMMAND_FAILED'])]))
        self.assertFalse(partial['artifact_reported_success'])
        self.assertEqual(partial['seam_refusals'], expected[:1])
        self.assertEqual(partial['normal_actor_exits'], 2)

        sources = {
            'tool/ci/windows_launch_catalog.py': Path(inspect.launch.__file__).read_bytes(),
            'tool/ci/windows_lock_catalog.py': Path(catalog.__file__).read_bytes(),
            catalog.CAPTURE_SOURCE.as_posix(): b'native fixture',
            inspect.launch.SETTLE_PROFILE_SOURCE.as_posix(): b'isolated profile',
        }
        source_paths = {'capture_source_sha256': catalog.CAPTURE_SOURCE,
                        'profile_sha256': inspect.launch.SETTLE_PROFILE_SOURCE,
                        **catalog.SEAM_PIN_SOURCES}
        for path in catalog.SEAM_PIN_SOURCES.values():
            sources[path.as_posix()] = b'synthetic selected source'
        sealed = dict(report, **{key: inspect.archive.sha(sources[path.as_posix()])
                                for key, path in source_paths.items()})
        raw, _ = package(sealed)

        class SeamClient(Client):
            def __init__(self):
                super().__init__()
                self.job.update(labels=['windows-latest'],
                    steps=[dict(name=name, status='completed', conclusion='success')
                           for name in (catalog.SEAM_STEP, catalog.SEAM_RETAIN_STEP)])

            def json(self, path):
                if path.startswith('/contents/'):
                    self.calls.append(path)
                    name, selected = path.removeprefix('/contents/').split('?ref=')
                    assert selected == HEAD
                    body = sources[name]
                    return dict(type='file', encoding='base64', path=name, size=len(body),
                                content=base64.b64encode(body).decode())
                if path == '/actions/runs/9/artifacts?per_page=20':
                    self.calls.append(path)
                    return dict(total_count=1, artifacts=[dict(id=7, expired=False,
                        name=catalog.SEAM_ARTIFACT_PREFIX + HEAD + '-9-1',
                        size_in_bytes=len(raw), digest='sha256:' + inspect.archive.sha(raw),
                        workflow_run=dict(id=RUN, head_sha=HEAD))])
                return super().json(path)

            def read(self, url, *, redirect=False, authenticated=True, cap=262144):
                self.calls.append(url)
                if redirect:
                    assert authenticated and url.endswith('/artifacts/7/zip')
                    return 'https://synthetic.blob.core.windows.net/7'
                assert not authenticated and cap == catalog.SEAM_MAX_ARCHIVE
                assert url == 'https://synthetic.blob.core.windows.net/7'
                return raw

        client = SeamClient()
        status, output = self.read_windows(client)
        self.assertEqual(status, 0)
        self.assertEqual(len(client.calls), 12)
        self.assertIn('Hosted original lock seam inspection', output)
        self.assertIn('retained_original_lock_seam_refusals', output)
        client = SeamClient()
        client.job['steps'].append(dict(client.job['steps'][0]))
        status, _ = self.read_windows(client)
        self.assertEqual(status, 1)
        self.assertFalse(any('/artifacts' in path for path in client.calls))

    def test_lock_catalog_requires_each_state_and_its_closed_original(self):
        catalog = inspect.lock_catalog
        states = (
            dict(frame=55, frames=56, failures=0, remaining=3, picker_gates=0, masked_chars=12),
            dict(frame=23, frames=56, failures=1, remaining=2, picker_gates=0, masked_chars=0),
            dict(frame=55, frames=56, failures=0, remaining=3, picker_gates=4, masked_chars=0),
        )
        bodies = {name: _png(index) for index, name in enumerate(catalog.FILES)}
        captures = [dict(file=name, theme=inspect.launch.THEMES[index // 3],
            screen=catalog.SCREENS[index % 3], bytes=len(bodies[name]),
            sha256=inspect.archive.sha(bodies[name]), **states[index % 3])
            for index, name in enumerate(catalog.FILES)]
        attempts = [dict(theme=theme, role=role, phase=phase, action_complete=True,
            checks=dict.fromkeys(inspect.launch.ATTEMPT_CHECKS, True), exit_code=0,
            exit_observed=True, forced_kill=False, output_complete=True,
            output_overflow=False, error_codes=[])
            for theme in inspect.launch.THEMES for role, phase in
            (('prepare', 'prepare'), ('capture', 'complete'))]
        pins = dict(capture_source_sha256='d' * 64, profile_sha256='a' * 64)
        report = dict(schema=1, scope=catalog.SCOPE, success=True, attempts=attempts,
            captures=captures, source_stable=True, error_codes=[], source_sha=HEAD,
            source_tree=TREE, run_id=str(RUN), run_attempt='1', runner_sha256='e' * 64,
            payload_sha256='f' * 64, **pins)

        def read(value):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, 'w') as zipped:
                zipped.writestr('manifest.json', json.dumps(value))
                for row in value['captures']:
                    zipped.writestr(row['file'], bodies[row['file']])
            raw = buffer.getvalue()
            return inspect.launch_archive(raw, inspect.archive.sha(raw), len(raw),
                HEAD, TREE, RUN, pins, lock=True)

        summary = read(report)
        self.assertTrue(summary['artifact_reported_success'])
        self.assertEqual(summary['verified_png_count'], 6)
        self.assertEqual(summary['states'][1]['remaining'], 2)
        for index, change in ((1, dict(failures=0)), (2, dict(picker_gates=3)),
                              (4, dict(frame=55)), (5, dict(theme='dark'))):
            changed = list(captures)
            changed[index] = dict(changed[index], **change)
            with self.assertRaises(inspect.archive.Refused):
                read(dict(report, captures=changed))
        with self.assertRaises(inspect.archive.Refused):
            read(dict(report, attempts=attempts[:-1]))

    def test_quiz_catalog_requires_one_closed_actor_and_ordered_native_frames(self):
        catalog = inspect.quiz_catalog
        bodies = {name: _png(index) for index, name in enumerate(catalog.FILES)}
        pins = dict(capture_source_sha256='d' * 64, fixture_source_sha256='c' * 64)
        attempt = dict(theme='dark', role='capture', phase='complete', action_complete=True,
            checks=dict.fromkeys(inspect.launch.ATTEMPT_CHECKS, True), exit_code=0,
            exit_observed=True, forced_kill=False, output_complete=True,
            output_overflow=False, error_codes=[])
        captures = [dict(file=name, theme=theme, bytes=len(bodies[name]),
            sha256=inspect.archive.sha(bodies[name]), correct=1, unlocked=1,
            questions=3, choices=[4, 4, 4], complete=False, artwork_seconds=6,
            native_before=4 + 2 * index, native_after=5 + 2 * index)
            for index, (theme, name) in enumerate(zip(inspect.launch.THEMES, catalog.FILES))]
        report = dict(schema=1, scope=catalog.SCOPE, success=True, attempts=[attempt],
            captures=captures, source_stable=True, error_codes=[], source_sha=HEAD,
            source_tree=TREE, run_id=str(RUN), run_attempt='1', runner_sha256='e' * 64,
            payload_sha256='f' * 64, **pins)

        def read(value, images=bodies):
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, 'w') as zipped:
                zipped.writestr('manifest.json', json.dumps(value))
                for row in value['captures']:
                    zipped.writestr(row['file'], images[row['file']])
            raw = buffer.getvalue()
            return inspect.launch_archive(raw, inspect.archive.sha(raw), len(raw),
                HEAD, TREE, RUN, pins, quiz=True)

        summary = read(report)
        self.assertTrue(summary['artifact_reported_success'])
        self.assertTrue(summary['single_process'])
        self.assertEqual(summary['filenames'], list(catalog.FILES))
        self.assertEqual(summary['visual_matches'], 0)
        for change in (dict(correct=True), dict(unlocked=2), dict(complete=True),
                       dict(artwork_seconds=7), dict(native_before=5),
                       dict(native_after=6)):
            with self.subTest(change=change), self.assertRaises(inspect.archive.Refused):
                read(dict(report, captures=[captures[0], dict(captures[1], **change)]))
        failed = dict(attempt, phase='restore', action_complete=False, forced_kill=True)
        with self.assertRaises(inspect.archive.Refused):
            read(dict(report, attempts=[failed]))
        with self.assertRaises(inspect.archive.Refused):
            read(dict(report, attempts=[attempt, attempt]))
        dark, light = catalog.FILES
        duplicate = dict(captures[1], bytes=len(bodies[dark]),
                         sha256=inspect.archive.sha(bodies[dark]))
        with self.assertRaises(inspect.archive.Refused):
            read(dict(report, captures=[captures[0], duplicate]),
                 dict(bodies, **{light: bodies[dark]}))
        partial = read(dict(report, attempts=[failed], captures=[], source_stable=False,
            success=False, error_codes=['WINDOW_RESTORE_FAILED']))
        self.assertFalse(partial['artifact_reported_success'])
        self.assertFalse(partial['single_process'])
        self.assertEqual(partial['verified_png_count'], 0)
        refused = dict(failed, phase='route', forced_kill=False,
                       refusal='quiz-fixture-unavailable', error_codes=['COMMAND_FAILED'])
        failure = dict(report, attempts=[refused], captures=[], source_stable=False,
                       success=False, error_codes=['STARTUP_OBSERVATION_REFUSED'])
        self.assertEqual(read(failure)['refusal'], 'quiz-fixture-unavailable')
        for attempt in (dict(refused, refusal='unfiltered payload'),
                        dict(refused, error_codes=[])):
            with self.assertRaises(inspect.archive.Refused):
                read(dict(failure, attempts=[attempt]))

    def test_quiz_catalog_retains_only_fixed_remote_refusals(self):
        catalog = inspect.quiz_catalog
        probe = object.__new__(catalog.QuizProcess)
        for code, body, projected in (
            (400, dict(ok=False, error='quiz-owner-unavailable'), 'quiz-owner-unavailable'),
            (400, dict(ok=False, error='quiz-capture-renderer-timeout'),
             'quiz-capture-renderer-timeout'),
            (400, dict(ok=False, error='unfiltered payload'), 'quiz-remote-refused'),
            (500, dict(ok=False, error='quiz-owner-unavailable'), 'quiz-remote-error'),
        ):
            with self.subTest(code=code, projected=projected), mock.patch.object(
                    probe, '_exchange', return_value=(code, body)) as exchange:
                with self.assertRaises(inspect.startup.Failure) as outcome:
                    probe._catalog('open', until=12)
                self.assertEqual(outcome.exception.code, 'COMMAND_FAILED')
                self.assertEqual(probe.refusal, projected)
                exchange.assert_called_once_with(dict(cmd=catalog.SCREEN, action='open'), until=12)

    def test_quiz_uses_the_original_capture_between_native_observations(self):
        catalog = inspect.quiz_catalog
        probe = object.__new__(catalog.QuizProcess)
        original = _png()
        calls = mock.Mock()
        calls.status.side_effect = [
            dict(native_callback=4),
            dict(native_callback=6, correct=1, unlocked=1, questions=3,
                 choices=[4, 4, 4], complete=False, artwork_seconds=6),
        ]
        calls.capture.return_value = dict(
            ok=True, status='captured', theme='dark', width=1280, height=780,
            png=base64.b64encode(original).decode('ascii'),
        )
        with mock.patch.object(probe, '_status', calls.status), mock.patch.object(
                probe, '_catalog', calls.capture):
            png, state = probe._capture('dark')
        self.assertEqual(png, original)
        self.assertEqual((state['native_before'], state['native_after']), (4, 6))
        self.assertEqual(calls.mock_calls, [
            mock.call.status('dark', 1, wait=True),
            mock.call.capture('capture-dark'),
            mock.call.status('dark', 1),
        ])

    def test_lock_catalog_waits_for_rest_and_refuses_a_changed_profile(self):
        catalog = inspect.lock_catalog
        settled = dict(ok=True, status='ready', theme='dark', frame=55, frames=56,
                       failures=0, remaining=3, picker=False, gates=0)

        class Probe(catalog.LockProcess):
            def __init__(self, samples):
                self.samples = iter(samples)
                self.deadline = 60
                self.elapsed = 0
                self.limits = inspect.launch.LIMITS

            def clock(self):
                return self.elapsed

            def sleep(self, seconds):
                self.elapsed += seconds

            def _catalog(self, action, *, until=None):
                if action != 'status' or until != 40:
                    raise AssertionError('Expected the bounded original state query')
                return next(self.samples)

        probe = Probe([dict(ok=True, status='pending'), dict(settled, frame=17), settled])
        self.assertEqual(probe._status('dark', False, wait=True), settled)
        self.assertEqual(probe.elapsed, 2 * inspect.launch.LIMITS.poll)
        for changed in (dict(settled, failures=1), dict(settled, theme='light')):
            with self.assertRaises(inspect.startup.Failure):
                Probe([changed, settled])._status('dark', False, wait=True)

    def test_startup_pair_keeps_the_original_twelve_request_transport_bound(self):
        class Response(io.BytesIO):
            status = 200
            headers = {'Content-Encoding': 'identity'}

        for negative in (False, True):
            with self.subTest(negative=negative):
                fixture = Client(negative=negative)

                class Opener:
                    def open(inner, request, *, timeout):
                        self.assertEqual(timeout, 15)
                        url = request.full_url
                        if url.startswith(inspect.archive.API + '/'):
                            self.assertEqual(request.get_header('Authorization'),
                                             'Bearer synthetic')
                            path = url[len(inspect.archive.API):]
                            if path.endswith('/zip'):
                                number = path.split('/')[-2]
                                raise inspect.archive.urllib.error.HTTPError(
                                    url, 302, 'Found', {'Location':
                                        'https://synthetic.blob.core.windows.net/' + number},
                                    io.BytesIO(),
                                )
                            return Response(json.dumps(fixture.json(path)).encode())
                        self.assertIsNone(request.get_header('Authorization'))
                        return Response(fixture.read(url, authenticated=False,
                                                     cap=inspect.MAX_ARCHIVE))

                reader = inspect.archive.Client('synthetic')
                with mock.patch.object(reader, 'opener', Opener()):
                    status, output = self.read_windows(reader)
                self.assertEqual(status, 0)
                self.assertEqual(reader.calls, 12)
                sources = [value.split('/')[-1].partition('?')[0]
                           for value in fixture.calls
                           if value.startswith('/contents/tool/ci/')]
                self.assertEqual(sources, list(inspect.PRODUCERS))
                self.assertNotIn('windows_baseline.py', sources)
                self.assertNotIn('dart_test_failure.py', sources)
                self.assertEqual(output.count('::notice'), 2)
                self.assertNotIn('INSPECTION_REFUSED', output)
                self.assertNotIn('Bearer synthetic', output)

    def test_fixture_import_does_not_require_an_external_test_package(self):
        original_import = builtins.__import__
        refused = []

        def independent_import(name, *args, **kwargs):
            if name == 'test' or name.startswith('test.'):
                refused.append(name)
                raise ModuleNotFoundError('External test package is unavailable')
            return original_import(name, *args, **kwargs)

        source = Path(__file__)
        namespace = dict(__name__='isolated_startup_inspection_fixture',
                         __file__=str(source))
        with mock.patch.object(builtins, '__import__', side_effect=independent_import):
            exec(compile(source.read_bytes(), str(source), 'exec'), namespace)
        self.assertEqual(refused, [])
        self.assertTrue(namespace['positive_report']().public()['success'])

    def test_original_pair_keeps_exact_manifest_binary_and_prior_binding(self):
        client = Client()
        values = inspect.inspect_run(client, head=HEAD, tree=TREE, run_id=RUN,
                                     job=client.job)
        self.assertEqual(len(values), 2)
        ordinary, natural = values
        self.assertTrue(ordinary['original_skip_qualified'])
        self.assertTrue(natural['original_natural_qualified'])
        self.assertFalse(natural['original_skip_qualified'])
        self.assertEqual(natural['prior_manifest_sha256'], ordinary['manifest_sha256'])
        self.assertEqual(natural['runner_sha256'], ordinary['runner_sha256'])
        self.assertEqual(natural['payload_sha256'], ordinary['payload_sha256'])
        self.assertEqual(natural['key_attempts'], 0)
        for value in values:
            self.assertTrue(value['inspection_only'])
            self.assertFalse(value['runtime_started'])
            self.assertFalse(value['wallet_qualified'])
            self.assertEqual(value['financial_actions_requested'], 0)
            with contextlib.redirect_stdout(io.StringIO()):
                windows.emit('Hosted startup inspection', value)

    def test_archive_refuses_wrong_digest_size_source_tree_or_run(self):
        raw = pair()[0]
        arguments = (inspect.archive.sha(raw), len(raw), HEAD, TREE, RUN)
        variants = [('f' * 64, *arguments[1:]),
                    (arguments[0], len(raw) + 1, *arguments[2:]),
                    (*arguments[:2], 'f' * 40, TREE, RUN),
                    (*arguments[:3], 'f' * 40, RUN),
                    (*arguments[:4], RUN + 1)]
        for selected in variants:
            with self.subTest(selected=selected), self.assertRaises(inspect.archive.Refused):
                inspect.startup_archive(raw, *selected)

    def test_natural_archive_refuses_foreign_prior_payload_and_claimed_skip_success(self):
        ordinary, natural = pair()
        prior = inspect.startup_archive(ordinary, inspect.archive.sha(ordinary),
                                        len(ordinary), HEAD, TREE, RUN)
        arguments = dict(natural_only=True,
                         prior_manifest_sha256=prior['manifest_sha256'],
                         runner_sha256=prior['runner_sha256'],
                         payload_sha256=prior['payload_sha256'])
        for fields in ({'prior_manifest_sha256': 'f' * 64},
                       {'runner_sha256': 'f' * 64},
                       {'payload_sha256': 'f' * 64}):
            with self.subTest(fields=fields), self.assertRaises(inspect.archive.Refused):
                inspect.startup_archive(natural, inspect.archive.sha(natural),
                    len(natural), HEAD, TREE, RUN, **{**arguments, **fields})
        report = positive_report(natural_only=True).public()
        report.update(prior_manifest_sha256=prior['manifest_sha256'],
                      key_attempts=1, handoff='key-confirmed')
        raw = package(report)[0]
        with self.assertRaises(inspect.archive.Refused):
            inspect.startup_archive(raw, inspect.archive.sha(raw), len(raw),
                                    HEAD, TREE, RUN, **arguments)

    def test_archive_refuses_extra_members_before_export(self):
        raw = package(positive_report().public(), extra=True)[0]
        with self.assertRaises(inspect.archive.Refused):
            inspect.startup_archive(raw, inspect.archive.sha(raw), len(raw),
                                    HEAD, TREE, RUN)

    def test_reader_preserves_negative_natural_deadline_and_original_positive(self):
        client = Client(negative=True)
        ordinary, natural = inspect.inspect_run(
            client, head=HEAD, tree=TREE, run_id=RUN, job=client.job)
        self.assertTrue(ordinary['artifact_reported_success'])
        self.assertFalse(natural['artifact_reported_success'])
        self.assertFalse(natural['original_natural_qualified'])
        self.assertTrue(natural['startup_deadline_expired'])
        self.assertEqual(natural['original_error_codes'], ['STARTUP_DEADLINE'])
        self.assertEqual(natural['original_job_conclusion'], 'failure')

    def read_windows(self, client):
        environment = dict(GITHUB_ACTIONS='true', SYRIUS_HOSTED_RUNNER='github-hosted',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='edgepillar/syrius',
            WINDOWS_INSPECT_RUN=str(RUN), WINDOWS_INSPECT_HEAD=HEAD, GH_TOKEN='synthetic')
        with mock.patch.dict(windows.os.environ, environment, clear=True), \
                mock.patch.object(windows.archive, 'Client', return_value=client), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = windows.main()
        return status, output.getvalue()

    def test_generic_reader_routes_only_the_selected_original_startup_job(self):
        client = Client()
        status, output = self.read_windows(client)
        self.assertEqual(status, 0)
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        self.assertIn('Hosted original startup inspection', notices[0])
        self.assertIn('Hosted natural startup inspection', notices[1])
        self.assertFalse(any('/logs' in value for value in client.calls))
        self.assertNotIn('private-state', output)

    def test_changed_producer_or_missing_pair_is_not_qualified(self):
        for fields in (dict(source_changed=True), dict(missing=True)):
            client = Client(**fields)
            with self.subTest(fields=fields):
                status, output = self.read_windows(client)
                self.assertEqual(status, 1)
                self.assertIn('INSPECTION_REFUSED', output)
                self.assertNotIn('original_natural_qualified', output)
        client = Client(source_changed=True)
        self.read_windows(client)
        self.assertFalse(any('/artifacts/' in value for value in client.calls))

    def test_mixed_or_duplicate_jobs_are_refused_before_archive_transport(self):
        for fields in (dict(mixed=True), dict(duplicate=True)):
            client = Client(**fields)
            with self.subTest(fields=fields):
                status, output = self.read_windows(client)
                self.assertEqual(status, 1)
                self.assertIn('INSPECTION_REFUSED', output)
                self.assertFalse(any('/artifacts' in value for value in client.calls))


if __name__ == '__main__':
    unittest.main()
