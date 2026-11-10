"""Retain an original cold-launch reference state from two owned profiles."""

import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
from dataclasses import replace

from . import windows_entry_capture_smoke as entry
from . import windows_presentation_smoke as bounded
from . import windows_startup_probe as startup


OUTPUT = Path('.harness/ci-launch-catalog')
TIMING_OUTPUT = Path('.harness/ci-launch-timing')
TIMING_SCREEN = 'launch-timing'
TIMING_SCOPE = 'original_cold_lock_frame_timing'
TIMING_JOB_STEP = 'Measure the original cold lock frame window'
TIMING_ARTIFACT_PREFIX = 'windows-launch-timing-'
TIMING_MAX_ARCHIVE = 64 * 1024
TIMING_THEME = 'dark'
TIMING_SIZE = (1280, 780)
MAX_TIMING_FRAMES, MAX_TIMING_US = 512, 60000000
TIMING_FIELDS = ('schema', 'scope', 'windowUs', 'frames')
TIMING_SOURCE = Path('harness/app/frame_window.dart')
RECIPE = Path('harness/screens/launch.txt')
SETTLE_RECIPE = Path('harness/screens/launch-settle.txt')
CAPTURE_SOURCE = Path('harness/app/native_launch_capture.dart')
SETTLE_PROFILE_SOURCE = Path('harness/app/fixtures/launch_settle_profile.dart')
THEMES = ('dark', 'light')
FILES = tuple('39-launch-' + theme + '.png' for theme in THEMES)
SETTLE_SCREEN = 'launch-settle'
SETTLE_FILES = tuple('40-launch-settle-' + theme + '.png' for theme in THEMES)
FRAME_FIELDS = {'frame', 'frames', 'stage'}
SETTLE_FIELDS = FRAME_FIELDS | {'progress', 'well', 'lockHandoff'}
MAX_PNG = 4 * 1024**2
MAX_MANIFEST = 32 * 1024
MAX_ARCHIVE = 2 * MAX_PNG + MAX_MANIFEST + 65536
LIMITS = replace(startup.LIMITS, response_bytes=entry.MAX_BASE64 + 65536)
ATTEMPT_CHECKS = ('identity', 'auth', 'close_ack', 'exit')
JOB_STEP = 'Capture the original cold launch in both themes'
SETTLE_JOB_STEP = 'Capture the original launch handoff in both themes'
SCOPE = 'original_cold_launch_catalog'
SETTLE_SCOPE = 'original_launch_settle_catalog'


def need(value, code='STARTUP_OBSERVATION_REFUSED'):
    if not value:
        raise startup.Failure(code)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def stage_matches(value):
    # The original window body fills the client below its 32-pixel caption.
    return (type(value) is list and all(type(v) in (int, float) for v in value)
            and value in ([0, 0, 1280, 780], [0, 32, 1280, 748]))


def client_rect(value):
    if (type(value) is not list or len(value) != 4
            or not all(type(v) in (int, float) for v in value)):
        return False
    x, y, width, height = value
    return 0 <= x < 1280 and 0 <= y < 780 and 0 < width <= 1280 - x and 0 < height <= 780 - y


def frame_matches(value, *, settle=False):
    if (type(value['frames']) is not int or value['frames'] != 56
            or type(value['frame']) is not int):
        return False
    stage = value['stage']
    if not settle:
        return value['frame'] == 23 and stage_matches(stage)
    well, progress = value['well'], value['progress']
    return (value['frame'] == 55 and value['lockHandoff'] is True
            and type(progress) in (int, float) and .4 <= progress <= .72
            and client_rect(stage) and client_rect(well)
            and well[2] < stage[2] < 1280 and well[3] < stage[3] < 780)


def launch_pixels(reply, theme, *, settle=False):
    """Admit the painted film frame or the measured intermediate handoff."""
    fields = SETTLE_FIELDS if settle else FRAME_FIELDS
    need(theme in THEMES and type(reply) is dict and set(reply) ==
         {'ok', 'status', 'theme', 'png'} | fields)
    need(reply['ok'] is True and reply['status'] == 'captured'
         and reply['theme'] == theme and frame_matches(reply, settle=settle))
    pixels = entry.png_bytes(reply['png'])
    need(0 < len(pixels) <= MAX_PNG)
    return pixels, {name: reply[name] for name in sorted(fields)}


def frame_timing_window(value):
    """Validate a bounded frame interval without exporting other reply fields."""
    if (type(value) is not dict
            or set(value) != {'schema', 'scope', 'windowUs', 'frames'}
            or type(value['schema']) is not int or value['schema'] != 1
            or value['scope'] != 'harness_frame_window'):
        raise startup.Failure('STARTUP_OBSERVATION_REFUSED')
    duration, rows = value['windowUs'], value['frames']
    if (type(duration) is not int or not 0 < duration <= MAX_TIMING_US
            or type(rows) is not list or not 0 < len(rows) <= MAX_TIMING_FRAMES):
        raise startup.Failure('STARTUP_OBSERVATION_REFUSED')
    previous_id, previous_start = -1, -1
    for row in rows:
        if (type(row) is not list or len(row) != 5
                or any(type(value) is not int for value in row)):
            raise startup.Failure('STARTUP_OBSERVATION_REFUSED')
        number, start, build, raster, total = row
        if (not previous_id < number < 2**32
                or previous_id == -1 and number != 0
                or not previous_start <= start < duration or start < 0
                or build < 0 or raster < 0 or not build + raster <= total <= MAX_TIMING_US):
            raise startup.Failure('STARTUP_OBSERVATION_REFUSED')
        previous_id, previous_start = number, start
    return value


def attempt_passed(value):
    return (all(value['checks'].values()) and value['action_complete']
            and value['exit_observed'] and value['exit_code'] == 0
            and value['output_complete'] and not value['forced_kill']
            and not value['output_overflow'] and not value['error_codes'])


class LaunchProcess(startup.StartupProbe):
    profile_screen = SETTLE_SCREEN

    def _prepare_theme(self, theme):
        self._show()
        body = self._rpc({'cmd': 'theme', 'mode': theme})
        need(body.get('mode') == body.get('brightness') == theme
             and body.get('savedMode') == 'ThemeMode.' + theme)
        # Closing at this size saves the actual outer geometry in this profile.

    def _observe_pixels(self, theme, *, settle):
        screen = SETTLE_SCREEN if settle else 'launch'
        until = min(self.deadline, self.started + 60)
        while self.clock() < until:
            reply = self._rpc(dict(cmd='entry-capture', screen=screen, theme=theme),
                              until=until)
            if reply == {'ok': True, 'status': 'refused',
                         'reason': 'original-launch-window-refused'}:
                raise startup.Failure('WINDOW_INVALID')
            if reply == {'ok': True, 'status': 'refused',
                         'reason': 'original-launch-theme-refused'}:
                raise startup.Failure('ENTRY_INVALID')
            if reply != {'ok': True, 'status': 'pending'}:
                return launch_pixels(reply, theme, settle=settle)
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        raise startup.Failure('STARTUP_DEADLINE')

    def _observe_frame_timing(self):
        until = min(self.deadline - 5, self.started + 50, self.clock() + 20)
        window_pending = False
        while self.clock() < until:
            remaining_ms = int((until - self.clock()) * 1000)
            need(remaining_ms > 0, 'STARTUP_DEADLINE')
            reply = self._rpc(dict(cmd='wait', key='wallet_password_field',
                                   kind='field', exact=True, ready=True,
                                   timeoutMs=remaining_ms), until=until)
            target = reply.get('target')
            need(type(target) is dict and target.get('key') == 'wallet_password_field'
                 and target.get('kind') == 'field'
                 and type(target.get('enabled', True)) is bool, 'ENTRY_UNAVAILABLE')
            if target.get('enabled', True):
                state = self._rpc({'cmd': 'state'}, until=until)
                need(state.get('booted') is True and state.get('walletUnlocked') is False,
                     'ENTRY_INVALID')
                size = state.get('size')
                need(type(size) is list and len(size) == 2
                     and all(type(value) is int and value >= 0 for value in size),
                     'WINDOW_INVALID')
                # The original startup restores client geometry asynchronously.
                if size == list(TIMING_SIZE):
                    break
                window_pending = True
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        else:
            raise startup.Failure('WINDOW_INVALID' if window_pending else 'STARTUP_DEADLINE')
        raw = self._rpc(dict(cmd='stalls', frameWindow='end'),
                        until=min(self.deadline, self.started + 60))
        need(set(raw) == {'ok', *TIMING_FIELDS})
        return frame_timing_window({field: raw[field] for field in TIMING_FIELDS})

    def run_launch(self, theme, *, capture, settle, timing=False):
        result, complete = None, False
        try:
            self._ready()
            if timing:
                result = self._observe_frame_timing()
            elif capture:
                result = self._observe_pixels(theme, settle=settle)
            else:
                self._prepare_theme(theme)
            complete = True
        except bounded.SmokeFailure as error:
            self.report.fail(error.code, error)
        except (Exception, KeyboardInterrupt) as error:
            self.report.fail('INTERNAL_ERROR', error)
        finally:
            if self.authenticated and self.process.poll() is None:
                self._record(self._quit)
            grace = min(self.limits.exit, max(0, self.deadline - self.clock())) if self.quit_sent else 0
            bounded.finish_original(self.process, self.drain, self.report,
                                    self.limits, grace=grace)
        report = self.report
        receipt = dict(theme=theme, role='timing' if timing else 'capture' if capture else 'prepare',
            action_complete=complete, checks={name: report.checks[name] for name in ATTEMPT_CHECKS},
            exit_code=report.exit_code, exit_observed=report.exit_observed,
            forced_kill=report.forced_kill, output_complete=report.output_complete,
            output_overflow=report.output_overflow, error_codes=report.errors)
        return receipt, result if attempt_passed(receipt) else None


def run_process(repo, parent, binaries, profile, theme, *, capture, settle,
                process_type=LaunchProcess, timing=False):
    need(not timing or (capture and settle and process_type is LaunchProcess),
         'ENVIRONMENT_REFUSED')
    bounded.check_no_existing(repo, parent)
    binary = binaries[0][0]
    for selected, _, original in binaries:
        info = bounded.plain(selected)
        need((info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) == original,
             'BINARY_REFUSED')
    token = secrets.token_urlsafe(32)
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    env = entry.child_environment(parent, profile, port, token)
    limits = LIMITS
    if timing:
        env['SYRIUS_HARNESS_FRAME_TIMING'] = 'launch'
        limits = replace(LIMITS, response_bytes=65536)
    else:
        if settle:
            env.update(GITHUB_ACTIONS='true', SYRIUS_CI_LAUNCH_SCREEN=process_type.profile_screen)
        if capture:
            env.update(GITHUB_ACTIONS='true', SYRIUS_CI_LAUNCH_THEME=theme)
    report = startup.Report()
    process = subprocess.Popen([str(binary)], cwd=binary.parent, env=env,
        shell=False, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, bufsize=0)
    drain = None
    try:
        drain = bounded.OutputDrain(process.stdout, limits.output_bytes)
        session = process_type(process, bounded.LoopbackTransport(port, limits.response_bytes),
                                token, drain, report, limits=limits)
    except BaseException:
        bounded.finish_original(process, drain, report, limits)
        raise
    if timing:
        return session.run_launch(theme, capture=capture, settle=settle, timing=True)
    return session.run_launch(theme, capture=capture, settle=settle)


def main():
    requested = os.environ.get('SYRIUS_WINDOWS_LAUNCH_CATALOG')
    timing = requested == TIMING_SCREEN
    settle = requested in (SETTLE_SCREEN, TIMING_SCREEN)
    scope = TIMING_SCOPE if timing else SETTLE_SCOPE if settle else SCOPE
    report = dict(schema=1, scope=scope, success=False,
        attempts=[], source_stable=False, error_codes=[])
    if timing:
        report.update(mode='release', theme=TIMING_THEME, client=list(TIMING_SIZE),
                      frame_window=None)
    else:
        report['captures'] = []
    destination = None
    try:
        need(not sys.argv[1:], 'ARGUMENTS_REFUSED')
        parent, head = entry.require_ci(os.environ, None, platform=os.name)
        need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
             and parent.get('GITHUB_RUN_ATTEMPT') == '1'
             and parent.get('SYRIUS_WINDOWS_STARTUP_PROBE') == 'true'
             and requested in ('true', SETTLE_SCREEN, TIMING_SCREEN)
             and (not timing or parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'),
             'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        bounded.plain(repo)
        need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        bounded.verify_source(repo, head, parent)
        tree = entry.source_tree(repo, parent)
        binaries = tuple(bounded.binary_hash(repo, path) for path in (startup.BINARY, startup.PAYLOAD))
        recipe = SETTLE_RECIPE if settle else RECIPE
        report.update(source_sha=head, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
            run_attempt='1', runner_sha256=binaries[0][1], payload_sha256=binaries[1][1])
        if timing:
            report['collector_sha256'] = sha((repo / TIMING_SOURCE).read_bytes())
        else:
            report.update(recipe_sha256=sha((repo / recipe).read_bytes()),
                capture_source_sha256=sha((repo / CAPTURE_SOURCE).read_bytes()))
        if settle:
            report['profile_sha256'] = sha((repo / SETTLE_PROFILE_SOURCE).read_bytes())
        entry.private_root(repo)
        output_directory = repo / (TIMING_OUTPUT if timing else OUTPUT)
        output_directory.mkdir(mode=0o700)
        destination = output_directory
        samples = ((TIMING_THEME, None),) if timing else zip(
            THEMES, SETTLE_FILES if settle else FILES)
        for theme, filename in samples:
            profile = entry.new_profile(repo)
            original = bounded.plain(profile)
            prepared, _ = run_process(repo, parent, binaries, profile, theme,
                                      capture=False, settle=settle)
            report['attempts'].append(prepared)
            need(attempt_passed(prepared))
            current = bounded.plain(profile)
            need((current.st_dev, current.st_ino) == (original.st_dev, original.st_ino), 'PROFILE_REFUSED')
            captured, result = run_process(repo, parent, binaries, profile, theme,
                                           capture=True, settle=settle, timing=timing)
            report['attempts'].append(captured)
            need(result is not None)
            if timing:
                report['frame_window'] = frame_timing_window(result)
                continue
            pixels, state = result
            with (destination / filename).open('xb') as output:
                output.write(pixels)
            report['captures'].append(dict(theme=theme, file=filename,
                bytes=len(pixels), sha256=sha(pixels), **state))
        bounded.verify_source(repo, head, parent)
        need(entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        need(tuple(bounded.binary_hash(repo, path)
                   for path in (startup.BINARY, startup.PAYLOAD)) == binaries, 'BINARY_REFUSED')
        report.update(source_stable=True, success=True)
    except bounded.SmokeFailure as error:
        report['error_codes'].append(error.code)
    except (Exception, KeyboardInterrupt):
        report['error_codes'].append('INTERNAL_ERROR')
    if destination is not None:
        try:
            data = (json.dumps(report, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')
            need(len(data) <= MAX_MANIFEST, 'ARTIFACT_FAILED')
            with (destination / 'manifest.json').open('xb') as output:
                output.write(data)
        except (Exception, KeyboardInterrupt):
            report['success'] = False
            report['error_codes'].append('ARTIFACT_FAILED')
    if timing:
        title = 'Original cold lock frame timing'
        summary = {key: value for key, value in report.items() if key != 'frame_window'}
        window = report['frame_window']
        summary['frame_count'] = len(window['frames']) if window is not None else 0
    else:
        title = 'Original launch handoff catalog' if settle else 'Original cold launch catalog'
        summary = report
    print('::notice title=' + title + '::' + json.dumps(summary, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
