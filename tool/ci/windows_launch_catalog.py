"""Retain an original cold-launch reference state from two owned profiles."""

import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import struct
import subprocess
import sys
import zlib
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
LOCK_DIAGNOSTIC_FLAGS = ('wallet_path_present', 'wallet_unlocked', 'client_at_target',
    'native_window_ready', 'startup_ready', 'welcome_ready', 'entry_held')
TIMING_COMMAND_STAGES = ('password_readiness', 'lock_state', 'frame_window')
FRAME_REFUSALS = ('notCollecting', 'launchNotBooted', 'lockFieldCount', 'lockFieldDisabled',
    'lockFieldUnreachable', 'deliveryTimeout', 'frameOrder', 'frameLimit', 'frameTiming',
    'windowBounds', 'noFrames')
MAX_TIMING_FRAMES, MAX_TIMING_US = 512, 60000000
MAX_PAIRED_TIMING_FRAMES = 4096
PAIRED_TIMING_REPLY_CAP = 128 * 1024
TIMING_FIELDS = ('schema', 'scope', 'windowUs', 'frames')
PACKED_TIMING_FIELDS = ('schema', 'scope', 'windowUs', 'frameCount', 'packedFrames')
FRAME_ROW = struct.Struct('<5I')
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


def _packed_frame_rows(value):
    count, encoded = value['frameCount'], value['packedFrames']
    need(startup.integer(count, 1, MAX_PAIRED_TIMING_FRAMES))
    size = count * FRAME_ROW.size
    # This covers the zlib bound even at the largest admitted count.
    cap = size + 64
    need(type(encoded) is str and encoded.isascii() and 0 < len(encoded) <= 4 * ((cap + 2) // 3))
    try:
        packed = base64.b64decode(encoded, validate=True)
        need(len(packed) <= cap and base64.b64encode(packed).decode('ascii') == encoded)
        decoder = zlib.decompressobj()
        raw = decoder.decompress(packed, size + 1)
    except (ValueError, zlib.error):
        raise startup.Failure('STARTUP_OBSERVATION_REFUSED') from None
    need(len(raw) == size and decoder.eof and not decoder.unconsumed_tail and not decoder.unused_data)
    return [list(row) for row in FRAME_ROW.iter_unpack(raw)]


def frame_timing_rows(value, *, allow_packed=False):
    """Validate and read every row in the admitted timing representation."""
    need(type(value) is dict and type(value.get('schema')) is int
        and value.get('scope') == 'harness_frame_window'
        and startup.integer(value.get('windowUs'), 1, MAX_TIMING_US))
    duration = value['windowUs']
    if value['schema'] == 1 and set(value) == set(TIMING_FIELDS):
        rows = value['frames']
        need(type(rows) is list and 0 < len(rows) <= MAX_TIMING_FRAMES)
    elif allow_packed and value['schema'] == 2 and set(value) == set(PACKED_TIMING_FIELDS):
        rows = _packed_frame_rows(value)
    else:
        raise startup.Failure('STARTUP_OBSERVATION_REFUSED')
    previous_id, previous_start = -1, -1
    for row in rows:
        need(type(row) is list and len(row) == 5 and all(type(item) is int for item in row))
        number, start, build, raster, total = row
        need(previous_id < number < 2**32 and (previous_id != -1 or number == 0)
            and previous_start <= start < duration and start >= 0
            and build >= 0 and raster >= 0 and build + raster <= total <= MAX_TIMING_US)
        previous_id, previous_start = number, start
    return rows


def frame_timing_window(value, *, allow_packed=False):
    """Keep the original representation for the bounded manifest."""
    frame_timing_rows(value, allow_packed=allow_packed)
    return value


def frame_timing_count(value):
    """Count a previously validated original frame window."""
    return value['frameCount'] if value['schema'] == 2 else len(value['frames'])

class TimingCommandRefused(startup.Failure):
    def __init__(self, stage, http_status, reply):
        super().__init__('COMMAND_FAILED')
        self.diagnostic = dict(status='command_refused', stage=stage, http_status=http_status,
            frame_window_refused=(stage == 'frame_window' and http_status == 400
                                  and reply.get('error') == 'frame-window-unqualified'))
        detail = reply.get('detail')
        if (self.diagnostic['frame_window_refused'] and type(detail) is dict
                and set(detail) == {'reason'} and detail['reason'] in FRAME_REFUSALS):
            self.diagnostic['frame_reason'] = detail['reason']


def timing_reply(stage, status, reply):
    if status != 200 or reply['ok'] is not True:
        raise TimingCommandRefused(stage, status, reply)
    return reply


def valid_lock_film_frame(value):
    return (type(value) is dict and set(value) == {'frames', 'shown', 'done'}
        and startup.integer(value['frames'], 0, 4096)
        and startup.integer(value['shown'], -1, max(-1, value['frames'] - 1))
        and type(value['done']) is bool)


def valid_lock_diagnostic(value):
    if type(value) is not dict:
        return False
    if value.get('status') == 'command_refused':
        fields = {'status', 'stage', 'http_status', 'frame_window_refused'}
        return (set(value) in (fields, fields | {'frame_reason'})
            and value['stage'] in TIMING_COMMAND_STAGES
            and startup.integer(value['http_status'], 100, 599)
            and type(value['frame_window_refused']) is bool
            and (not value['frame_window_refused']
                 or value['stage'] == 'frame_window' and value['http_status'] == 400)
            and ('frame_reason' not in value
                 or value['frame_window_refused'] and value['frame_reason'] in FRAME_REFUSALS))
    if set(value) == {'status', 'error_code'} and value['status'] == 'unavailable':
        code = value['error_code']
        return type(code) is str and code in startup.CODES
    fields = {'status', 'tab', 'entry_phase', 'field', *LOCK_DIAGNOSTIC_FLAGS}
    return (set(value) in (fields, fields | {'film_frame'})
        and ('film_frame' not in value or valid_lock_film_frame(value['film_frame']))
        and value['status'] == 'observed' and value['tab'] in ('lock', 'none', 'other')
        and type(value['entry_phase']) is str and value['entry_phase'] in startup.RECIPE_ENTRY_PHASES
        and value['field'] in ('missing', 'disabled', 'visible')
        and all(type(value[key]) is bool for key in LOCK_DIAGNOSTIC_FLAGS))


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

    def _observe_frame_timing(self, *, paired=False):
        until = min(self.deadline - 5, self.started + 50)
        if not paired:
            until = min(until, self.clock() + 20)
        window_pending = False
        # A zero-wait original predicate leaves time for its HTTP reply.
        # P06 and the current agent use different fixed pending messages.
        while self.clock() + self.limits.poll < until:
            status, reply = self._exchange(dict(cmd='wait', key='wallet_password_field',
                kind='field', exact=True, ready=True, timeoutMs=0), until=until)
            pending = (status == 400 and reply['ok'] is False
                and reply.get('error') in ('not there after 0 ms', 'not ready after 0 ms'))
            target = None
            if not pending:
                target = timing_reply('password_readiness', status, reply).get('target')
                need(type(target) is dict and target.get('key') == 'wallet_password_field'
                     and target.get('kind') == 'field'
                     and type(target.get('enabled', True)) is bool, 'ENTRY_UNAVAILABLE')
            if target is not None and target.get('enabled', True):
                state = timing_reply('lock_state', *self._exchange({'cmd': 'state'}, until=until))
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
        raw = timing_reply('frame_window', *self._exchange(dict(cmd='stalls', frameWindow='end'),
                           until=min(self.deadline, self.started + 60)))
        fields = PACKED_TIMING_FIELDS if paired else TIMING_FIELDS
        need(set(raw) == {'ok', *fields})
        return frame_timing_window({field: raw[field] for field in fields}, allow_packed=paired)

    def _lock_diagnostic(self):
        # This sample occurs after the failed comparison window. Keep only
        # finite facts from the still-owned original process.
        until = min(self.deadline - 5, self.clock() + 5)
        try:
            state = self._rpc({'cmd': 'state'}, until=until)
            native = self._rpc({'cmd': 'entry-state'}, until=until)
            recipe = self._rpc({'cmd': 'wallet-recipe', 'action': 'observe'}, until=until)
            status, field = self._exchange(dict(cmd='wait', key='wallet_password_field',
                kind='field', exact=True, timeoutMs=0), until=until)
            if status == 400 and field['ok'] is False and field.get('error') == 'not there after 0 ms':
                field_state = 'missing'
            else:
                target = field.get('target')
                need(status == 200 and field['ok'] is True and type(target) is dict
                     and target.get('key') == 'wallet_password_field' and target.get('kind') == 'field'
                     and type(target.get('enabled', True)) is bool, 'ENTRY_UNAVAILABLE')
                field_state = 'visible' if target.get('enabled', True) else 'disabled'
            wallet_path, size = state.get('walletPath'), state.get('size')
            need('walletPath' in state and (wallet_path is None or type(wallet_path) is str and wallet_path)
                 and state.get('booted') is True and native.get('available') is True
                 and type(size) is list and len(size) == 2
                 and all(type(value) is int and value >= 0 for value in size), 'ENTRY_INVALID')
            tab = state.get('tab')
            value = dict(status='observed', tab='lock' if tab == 'lock' else 'none' if tab is None else 'other',
                entry_phase=recipe.get('entryPhase'), field=field_state,
                wallet_path_present=wallet_path is not None, wallet_unlocked=state.get('walletUnlocked'),
                client_at_target=size == list(TIMING_SIZE), native_window_ready=native.get('nativeWindowReady'),
                startup_ready=native.get('startupReady'), welcome_ready=native.get('welcomeReady'),
                entry_held=native.get('held'))
            film = recipe.get('startupFilmFrame')
            if 'startupFilmProgress' in recipe:
                progress = startup.progress_projection(recipe['startupFilmProgress'])
                film = ({name: progress[name] for name in ('frames', 'shown', 'done')}
                        if progress is not None else None)
            if valid_lock_film_frame(film):
                value['film_frame'] = film
            need(valid_lock_diagnostic(value), 'ENTRY_INVALID')
            return value
        except bounded.SmokeFailure as error:
            return dict(status='unavailable', error_code=error.code)
        except Exception:
            return dict(status='unavailable', error_code='INTERNAL_ERROR')

    def run_launch(self, theme, *, capture, settle, timing=False, lock_diagnostic=None):
        result, complete = None, False
        try:
            self._ready()
            if timing:
                result = self._observe_frame_timing(paired=lock_diagnostic is not None)
            elif capture:
                result = self._observe_pixels(theme, settle=settle)
            else:
                self._prepare_theme(theme)
            complete = True
        except bounded.SmokeFailure as error:
            self.report.fail(error.code, error)
            if timing and lock_diagnostic is not None:
                if isinstance(error, TimingCommandRefused) and valid_lock_diagnostic(error.diagnostic):
                    lock_diagnostic.update(error.diagnostic)
                elif error.code == 'STARTUP_DEADLINE':
                    lock_diagnostic.update(self._lock_diagnostic())
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
                process_type=LaunchProcess, timing=False, lock_diagnostic=None):
    need(lock_diagnostic is None or timing and type(lock_diagnostic) is dict and not lock_diagnostic,
         'ENVIRONMENT_REFUSED')
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
        paired = lock_diagnostic is not None
        env['SYRIUS_HARNESS_FRAME_TIMING'] = 'paired-launch' if paired else 'launch'
        limits = replace(LIMITS, response_bytes=PAIRED_TIMING_REPLY_CAP if paired else 65536)
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
        return session.run_launch(theme, capture=capture, settle=settle, timing=True,
                                  lock_diagnostic=lock_diagnostic)
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
