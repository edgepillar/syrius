"""Bind interactive frame samples to an owned chain-321 test profile."""

import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import threading

from . import native_interactive_frame_actions as actions
from . import windows_baseline as baseline
from . import windows_debug_loop as debug
from . import windows_launch_catalog as launch
from . import windows_wallet_tour as wallet_tour


ENTRY_SCOPE = 'owned_chain321_frame_profile_preparation'
NODE = 'ws://127.0.0.1:45998'
READY = json.dumps(dict(schema=1, scope=ENTRY_SCOPE, success=True, error_code=None),
                   separators=(',', ':')).encode('ascii')
ENTRY = Path('harness/bin/ci_paired_interactive_entry.dart')
ENTRY_SHA256 = '9964efb8467c25596735b42c07719bb8fc0a71a1e83dcace3c82eca25bd26ad8'
MEASUREMENT_COMMANDS = frozenset(('theme', 'state', 'stalls', 'tap', 'wait', 'scroll'))
MAX_MEASUREMENT_COMMANDS = 32
SHUTDOWN_PREFIX = b'SYRIUS_SHUTDOWN '
SHUTDOWN_ELAPSED_LIMIT_MS = 120_000
SHUTDOWN_PHASES = frozenset((
    'idle', 'windowMaximizedRead', 'windowMaximizedSave', 'windowSizeRead',
    'windowWidthSave', 'windowHeightSave', 'windowPositionRead', 'windowXSave',
    'windowYSave', 'webSocketStop', 'embeddedNodeClose', 'wakeLockRead',
    'wakeLockDisable', 'embeddedStopRequest', 'embeddedStopWait',
    'embeddedCleanup', 'serviceReset', 'widgetDispose', 'exitRequested'))
NAVIGATION_FLAGS = frozenset(('hasExistingKey', 'expectedKey', 'sameRectangle',
                             'visibleInsideDecoration', 'enabled'))
NAVIGATION_CARRIERS = frozenset(('absent', 'inkwell', 'gesture', 'other'))
STARTUP_ENTRY_PHASES = frozenset(('startup-before-initialization',
                                'startup-initialization-started', 'welcome'))
STARTUP_FRAME_LIMIT = 5000
STARTUP_PROGRESS_FLAGS = frozenset(('skip', 'pending', 'ticking'))
PREPARATION_PHASES = frozenset(('environment', 'input', 'ownerBefore', 'emptyProfile',
                              'importWallet', 'ownerAfter', 'walletReady'))
PREPARATION_ERROR_PHASES = {
    'ENVIRONMENT_REFUSED': frozenset(('environment',)),
    'INPUT_REFUSED': frozenset(('input',)),
    'OWNER_REFUSED': frozenset(('ownerBefore', 'ownerAfter')),
    'PROFILE_REFUSED': frozenset(('emptyProfile',)),
    'WALLET_REFUSED': frozenset(('walletReady',)),
    'PREPARATION_REFUSED': PREPARATION_PHASES,
}


class InteractiveRefused(Exception):
    pass


def valid_shutdown_observation(value):
    """Accept fixed close labels, never private errors or successful-exit claims."""
    if type(value) is not dict:
        return False
    if set(value) == {'status', 'phase', 'failed'}:
        return (value['status'] == 'observed' and type(value['phase']) is str
            and value['phase'] in SHUTDOWN_PHASES and type(value['failed']) is bool
            and not (value['phase'] == 'idle' and value['failed']))
    return (set(value) == {'status', 'error_code'}
        and value['status'] == 'unavailable' and type(value['error_code']) is str
        and value['error_code'] in launch.startup.CODES)


def valid_shutdown_trace(value):
    """A last observed label cannot establish final state or normal exit."""
    if type(value) is not dict or type(value.get('output_complete')) is not bool:
        return False
    if set(value) == {'status', 'output_complete'}:
        return value['status'] == 'absent'
    if set(value) == {'status', 'error_code', 'output_complete'}:
        return (value['status'] == 'unavailable'
            and value['error_code'] in ('STATE_INVALID', 'OUTPUT_OVERFLOW', 'INTERNAL_ERROR'))
    base = {'status', 'phase', 'failed', 'event_count', 'output_complete'}
    timed = base | {'elapsed_ms', 'max_gap_ms', 'max_gap_after'}
    if not (set(value) in (base, timed)
        and value['status'] == 'observed' and type(value['phase']) is str
        and value['phase'] in SHUTDOWN_PHASES and type(value['failed']) is bool
        and not (value['phase'] == 'idle' and value['failed'])
        and type(value['event_count']) is int
        and 1 <= value['event_count'] <= len(SHUTDOWN_PHASES) + 1):
        return False
    if set(value) == base:
        return True
    if (not _shutdown_milliseconds(value['elapsed_ms'])
            or not _shutdown_milliseconds(value['max_gap_ms'])
            or value['max_gap_ms'] > value['elapsed_ms']):
        return False
    if value['event_count'] == 1:
        return value['max_gap_ms'] == 0 and value['max_gap_after'] is None
    return (type(value['max_gap_after']) is str
            and value['max_gap_after'] in SHUTDOWN_PHASES)


def _shutdown_milliseconds(value):
    return type(value) is int and 0 <= value <= SHUTDOWN_ELAPSED_LIMIT_MS


def observe_shutdown_trace(raw, *, output_complete, output_overflow, cap=131072):
    """Read only bounded complete protocol lines; never project child output."""
    def unavailable(code):
        return dict(status='unavailable', error_code=code,
                    output_complete=output_complete is True)

    if (type(raw) is not bytes or type(cap) is not int or not 0 < cap <= 131072
            or type(output_complete) is not bool or type(output_overflow) is not bool):
        return unavailable('STATE_INVALID')
    if output_overflow or len(raw) > cap:
        return unavailable('OUTPUT_OVERFLOW')

    def closed(pairs):
        value = dict(pairs)
        if len(pairs) != len(value):
            raise ValueError()
        return value

    events = []
    lines = raw.split(b'\n')
    for index, line in enumerate(lines):
        if not line.startswith(SHUTDOWN_PREFIX):
            continue
        if len(line) > 256:
            return unavailable('STATE_INVALID')
        if index == len(lines) - 1 and not output_complete:
            break
        try:
            value = json.loads(line[len(SHUTDOWN_PREFIX):], object_pairs_hook=closed)
        except (ValueError, UnicodeError):
            return unavailable('STATE_INVALID')
        if (index == len(lines) - 1 or type(value) is not dict
                or set(value) not in ({'phase', 'failed'}, {'phase', 'failed', 'elapsed_ms'})
                or 'elapsed_ms' in value and not _shutdown_milliseconds(value['elapsed_ms'])
                or type(value['phase']) is not str or value['phase'] not in SHUTDOWN_PHASES
                or type(value['failed']) is not bool
                or value['phase'] == 'idle' and value['failed']
                or len(events) >= len(SHUTDOWN_PHASES) + 1):
            return unavailable('STATE_INVALID')
        if events:
            previous = events[-1]
            if (set(previous) != set(value)
                    or value.get('elapsed_ms', 0) < previous.get('elapsed_ms', 0)
                    or previous['phase'] == value['phase'] and previous['failed'] == value['failed']
                    or previous['failed']
                    or previous['phase'] == 'exitRequested' and not (
                        value['phase'] == 'exitRequested' and value['failed'])):
                return unavailable('STATE_INVALID')
        events.append(value)
    if not events:
        return dict(status='absent', output_complete=output_complete)
    summary = dict(status='observed', **events[-1], event_count=len(events),
                   output_complete=output_complete)
    if 'elapsed_ms' in summary:
        maximum, after = max(
            ((later['elapsed_ms'] - earlier['elapsed_ms'], earlier['phase'])
             for earlier, later in zip(events, events[1:])),
            key=lambda pair: pair[0], default=(0, None))
        summary.update(max_gap_ms=maximum, max_gap_after=after)
    return summary


def valid_navigation_observation(value):
    """Accept only bounded selector flags, never labels or wallet data."""
    if type(value) is not dict:
        return False
    if set(value) == {'status', 'error_code'}:
        return (value['status'] == 'unavailable'
            and type(value['error_code']) is str
            and value['error_code'] in launch.startup.CODES)
    if (set(value) != {'status', 'settingsCount', 'bindings'}
            or value['status'] != 'observed'
            or type(value['settingsCount']) is not int
            or not 0 <= value['settingsCount'] <= 4
            or type(value['bindings']) is not list or len(value['bindings']) > 4):
        return False
    for row in value['bindings']:
        if (type(row) is not dict or set(row) != NAVIGATION_FLAGS | {'carrier'}
                or type(row['carrier']) is not str
                or row['carrier'] not in NAVIGATION_CARRIERS
                or any(type(row[key]) is not bool for key in NAVIGATION_FLAGS)
                or row['expectedKey'] and not row['hasExistingKey']
                or row['sameRectangle'] and not row['visibleInsideDecoration']
                or row['carrier'] == 'absent' and any(row[key] for key in NAVIGATION_FLAGS)):
            return False
    return True


def valid_startup_observation(value):
    """Keep legacy counters or versioned original-film flags without payloads."""
    if type(value) is not dict:
        return False
    if set(value) == {'status', 'error_code'}:
        return (value['status'] == 'unavailable'
            and type(value['error_code']) is str
            and value['error_code'] in launch.startup.CODES)
    if type(value.get('entry')) is not str or value['entry'] not in STARTUP_ENTRY_PHASES:
        return False
    if set(value) == {'status', 'entry'}:
        return value['status'] == 'absent'
    fields = {'status', 'entry', 'frames', 'shown', 'done'}
    if set(value) == fields | {'schema', *STARTUP_PROGRESS_FLAGS}:
        if (type(value['schema']) is not int or value['schema'] != 2
                or any(type(value[key]) is not bool for key in STARTUP_PROGRESS_FLAGS)):
            return False
    elif set(value) != fields:
        return False
    return (value['status'] == 'observed' and type(value['frames']) is int
        and 0 <= value['frames'] <= STARTUP_FRAME_LIMIT
        and type(value['shown']) is int and -1 <= value['shown'] < value['frames']
        and type(value['done']) is bool)


def need(condition, code):
    if not condition:
        raise InteractiveRefused(code)


def preparation_failure(value):
    """Validate fixed entry phases and the existing onboarding-label filter."""
    if (type(value) is not dict or set(value) not in (
            {'code', 'phase'}, {'code', 'phase', 'recipe'})
            or type(value['code']) is not str or type(value['phase']) is not str
            or value['phase'] not in PREPARATION_ERROR_PHASES.get(value['code'], ())):
        return None
    result = dict(code=value['code'], phase=value['phase'])
    if 'recipe' in value:
        if value['code'] != 'PREPARATION_REFUSED' or value['phase'] != 'importWallet':
            return None
        try:
            wallet_tour.entry_failure(dict(stage='onboarding',
                code='wallet-recipe-command-refused', diagnostic=value['recipe']))
        except wallet_tour.Refused:
            return None
        result['recipe'] = dict(value['recipe'])
    return result


def navigation_failure(value):
    """Select only the retained original missing-Settings preparation failure."""
    return (type(value) is dict and value.get('phase') == 'prepare_profile'
        and preparation_failure(value.get('preparation_failure')) == dict(
            code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='observe', control='nav_settings', entry='unknown',
                reason='wallet-recipe-control-absent')))


def startup_failure(value):
    """Select the original Welcome refusal or explicitly unconfirmed Skip."""
    return (type(value) is dict and value.get('phase') == 'prepare_profile'
        and preparation_failure(value.get('preparation_failure')) in (
            dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='observe', control='welcome_import',
                entry='startup-before-initialization',
                reason='wallet-recipe-control-absent')),
            dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='key', control='launch_skip_hint',
                reason='wallet-recipe-startup-key-unconfirmed')),
            dict(code='PREPARATION_REFUSED', phase='importWallet', recipe=dict(
                action='key', control='launch_skip_hint',
                reason='wallet-recipe-startup-key-unconfirmed', startup='key-sent'))))


def _observe_startup_failure(session, observation, diagnostic):
    if diagnostic or not startup_failure(observation):
        return
    try:
        body = session._rpc({'cmd': 'wallet-recipe', 'action': 'observe'},
                            until=min(session.deadline, session.clock() + 1))
        if (type(body) is not dict or body.get('ok') is not True
                or body.get('harnessMode') != 'wallet' or body.get('booted') is not True
                or body.get('walletPresent') is not False
                or body.get('transitionPending') is not False
                or body.get('hasError') is not False):
            raise launch.startup.Failure('STATE_INVALID')
        entry = body.get('entryPhase')
        frame = body.get('startupFilmFrame')
        if frame is None:
            value = dict(status='absent', entry=entry)
        else:
            fields = {'frames', 'shown', 'done'}
            if (type(frame) is not dict or set(frame) not in (
                    fields, fields | {'schema', *STARTUP_PROGRESS_FLAGS})):
                raise launch.startup.Failure('STATE_INVALID')
            value = dict(status='observed', entry=entry, **frame)
        if not valid_startup_observation(value):
            raise launch.startup.Failure('STATE_INVALID')
        diagnostic.update(value)
    except launch.bounded.SmokeFailure as error:
        code = error.code
        diagnostic.update(status='unavailable', error_code=code
            if type(code) is str and code in launch.startup.CODES else 'INTERNAL_ERROR')
    except ConnectionRefusedError:
        diagnostic.update(status='unavailable', error_code='HTTP_FAILED')
    except (Exception, KeyboardInterrupt):
        diagnostic.update(status='unavailable', error_code='INTERNAL_ERROR')


def _observe_navigation_failure(session, observation, diagnostic):
    if diagnostic or not navigation_failure(observation):
        return
    try:
        body = session._rpc({'cmd': 'navigation-state'},
                            until=min(session.deadline, session.clock() + 1))
        if (type(body) is not dict
                or set(body) != {'ok', 'settingsCount', 'bindings'}
                or body['ok'] is not True):
            raise launch.startup.Failure('STATE_INVALID')
        value = dict(status='observed', settingsCount=body['settingsCount'],
                     bindings=body['bindings'])
        if not valid_navigation_observation(value):
            raise launch.startup.Failure('STATE_INVALID')
        diagnostic.update(status='observed', settingsCount=value['settingsCount'],
                          bindings=[dict(row) for row in value['bindings']])
    except launch.bounded.SmokeFailure as error:
        code = error.code
        diagnostic.update(status='unavailable', error_code=code
            if type(code) is str and code in launch.startup.CODES else 'INTERNAL_ERROR')
    except ConnectionRefusedError:
        diagnostic.update(status='unavailable', error_code='HTTP_FAILED')
    except (Exception, KeyboardInterrupt):
        diagnostic.update(status='unavailable', error_code='INTERNAL_ERROR')


def preparation_failure_marker(value):
    """Rebuild the fixed marker for original-output and retained-size checks."""
    value = preparation_failure(value)
    if value is None:
        return None
    detail = dict(phase=value['phase'])
    if 'recipe' in value:
        detail['recipe'] = value['recipe']
    return json.dumps(dict(schema=1, scope=ENTRY_SCOPE, success=False,
        error_code=value['code'], failure=detail), separators=(',', ':')).encode('ascii')


def entry_preparation_failure(outcome):
    """Project a complete failed marker; raw stdout and errors remain private."""
    if (type(outcome) is not baseline.Outcome or type(outcome.exit_code) is not int
            or outcome.exit_code != 1 or outcome.exit_observed is not True
            or outcome.forced_kill is not False or outcome.output_complete is not True
            or outcome.output_overflow is not False or outcome.errors
            or type(outcome.output) is not bytes or not 0 < len(outcome.output) <= 4096
            or outcome.output_bytes != len(outcome.output)):
        return None

    def unique(items):
        result = dict(items)
        if len(result) != len(items):
            raise ValueError()
        return result

    try:
        value = json.loads(outcome.output.decode('ascii'), object_pairs_hook=unique)
    except (ValueError, UnicodeError, RecursionError):
        return None
    if (type(value) is not dict or set(value) != {
            'schema', 'scope', 'success', 'error_code', 'failure'}
            or type(value['schema']) is not int or value['schema'] != 1
            or value['scope'] != ENTRY_SCOPE or value['success'] is not False
            or type(value['failure']) is not dict or set(value['failure']) not in (
                {'phase'}, {'phase', 'recipe'})):
        return None
    failure = preparation_failure(dict(code=value['error_code'], **value['failure']))
    marker = preparation_failure_marker(failure)
    if marker is None or outcome.output not in (marker + b'\n', marker + b'\r\n'):
        return None
    return failure


def reply(send, command):
    value = send({'cmd': command})
    need(type(value) is dict and value.get('ok') is True, 'OWNER_REFUSED')
    return value


def run_entry_process(repo, parent, profile, payload):
    """Feed one private request to an original Dart process in an owned job."""
    parent, _ = launch.entry.require_ci(parent, None, platform=os.name)
    need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
         and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
         and parent.get('GITHUB_REF') == 'refs/heads/redesign'
         and parent.get('GITHUB_RUN_ATTEMPT') == '1'
         and parent.get('SYRIUS_PAIRED_INTERACTIVE_PROFILE') == 'true',
         'ENVIRONMENT_REFUSED')
    need(type(payload) is bytes and 0 < len(payload) <= 4096, 'INPUT_REFUSED')
    entry, packages = repo / ENTRY, repo / '.dart_tool/package_config.json'
    for path, cap in ((entry, 16384), (packages, 512 * 1024)):
        info = launch.bounded.plain(path)
        need(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= cap, 'SOURCE_REFUSED')
    need(launch.sha(entry.read_bytes()) == ENTRY_SHA256, 'SOURCE_REFUSED')
    need(stat.S_ISDIR(launch.bounded.plain(profile).st_mode), 'PROFILE_REFUSED')
    dart, _ = debug.sdk(parent)
    env = debug.profile_environment(parent, profile, 1, 'unused')
    env.pop('SYRIUS_HARNESS_PORT', None)
    env.pop('SYRIUS_HARNESS_TOKEN', None)
    for name in ('GITHUB_EVENT_NAME', 'GITHUB_REPOSITORY', 'GITHUB_REF',
                 'SYRIUS_PAIRED_INTERACTIVE_PROFILE'):
        env[name] = parent[name]
    job = debug.WindowsJob()
    process = writer = None
    complete = threading.Event()

    def spawn(arguments, **options):
        nonlocal process
        options['stdin'] = subprocess.PIPE
        process = subprocess.Popen(arguments, **options)
        return process

    def write():
        try:
            with process.stdin as stream:
                sent = stream.write(payload)
            if sent == len(payload):
                complete.set()
        except (OSError, ValueError):
            pass

    def drain(pipe, cap, *, retain):
        nonlocal writer
        job.assign(process)
        writer = threading.Thread(target=write, daemon=True)
        writer.start()
        return baseline.OutputDrain(pipe, cap, retain=retain)

    cleanup_failed = forced = False
    try:
        outcome = baseline.run_bounded(
            [str(dart), '--disable-dart-dev', '--packages=' + str(packages), str(entry)],
            cwd=repo, env=env, timeout=210, cap=4096, spawn=spawn, drain_factory=drain)
    finally:
        try:
            forced = job.close()
        except debug.ProcessRefused:
            cleanup_failed = True
        if writer is not None and writer.ident is not None:
            writer.join(1)
        elif process is not None:
            for stream in (process.stdin, process.stdout):
                try:
                    stream.close()
                except OSError:
                    cleanup_failed = True
    outcome.forced_kill = outcome.forced_kill or forced
    if cleanup_failed:
        outcome.errors += ('CLEANUP_FAILED',)
    if not complete.is_set() or writer is None or writer.is_alive():
        outcome.errors += ('COMMAND_REFUSED',)
    return outcome


def owned_profile(send, run_entry, revalidate, measure, confirm_address, *,
                  pid, port, token, fixture_text, genesis, first_height, report):
    """Prepare once and retain only numeric windows and fixed exit evidence."""
    need(type(pid) is int and pid > 0 and type(port) is int and 1024 <= port <= 65535
         and type(token) is str and re.fullmatch('[A-Za-z0-9_-]{43}', token),
         'OWNER_REFUSED')
    need(type(genesis) is str and re.fullmatch('[a-f0-9]{64}', genesis)
         and type(first_height) is int and first_height > 0, 'LAB_REFUSED')
    need(type(report) is dict and not report, 'PROFILE_REFUSED')
    report.update(phase='lab_before', lab_revalidations=0, entry=None, windows={},
                  success=False)
    last_height = first_height

    def lab():
        nonlocal last_height
        offered = revalidate()
        need(type(offered) is dict and type(offered.get('chain')) is int
             and offered['chain'] == 321 and offered.get('genesis_hash') == genesis
             and offered.get('cross_transport_hash_equal') is True
             and type(offered.get('last_height')) is int and offered['last_height'] >= last_height,
             'LAB_REFUSED')
        last_height = offered['last_height']
        report['lab_revalidations'] += 1

    def owner():
        offered = reply(send, 'ping')
        need(type(offered.get('pid')) is int and offered['pid'] == pid
             and offered.get('booted') is True and offered.get('harnessMode') == 'wallet',
             'OWNER_REFUSED')

    lab()
    report['phase'] = 'empty_profile'
    owner()
    state = reply(send, 'state')
    need(state.get('walletUnlocked') is False and state.get('walletInitCompleted') is False
         and 'walletPath' in state and state['walletPath'] is None, 'PROFILE_REFUSED')
    report['phase'] = 'prepare_profile'
    payload = json.dumps(dict(schema=1, pid=pid, port=port, token=token,
        mnemonic=wallet_tour.public_fixture(fixture_text),
        password=secrets.token_hex(16) + 'A!1'), separators=(',', ':')).encode('ascii')
    need(0 < len(payload) <= 4096, 'PROFILE_REFUSED')
    outcome = run_entry(payload)
    need(type(outcome) is baseline.Outcome, 'PROFILE_PREPARATION_REFUSED')
    report['entry'] = outcome.public()
    failure = entry_preparation_failure(outcome)
    if failure is not None:
        report['preparation_failure'] = failure
    need(outcome.success and outcome.output in (READY + b'\n', READY + b'\r\n'),
         'PROFILE_PREPARATION_REFUSED')

    report['phase'] = 'wallet_ready'
    owner()
    state = reply(send, 'state')
    address = state.get('address')
    need(state.get('walletUnlocked') is True and state.get('walletInitCompleted') is True
         and state.get('tab') == 'dashboard' and state.get('node') == NODE
         and all(type(state.get(key)) is int and state[key] == 321
                 for key in ('chainId', 'signingChainId', 'savedSigningChainId'))
         and state.get('embeddedNode') is False and state.get('nodeTransitionPending') is False
         and type(address) is str and address, 'WALLET_REFUSED')
    need(confirm_address(address) is True, 'WALLET_REFUSED')
    lab()
    report['phase'] = 'measure'
    progress = dict(index=0, command=None, returned=False)
    report['action_progress'] = progress

    def observed_send(command):
        need(type(command) is dict and command.get('cmd') in MEASUREMENT_COMMANDS
             and progress['index'] < MAX_MEASUREMENT_COMMANDS, 'FRAME_REFUSED')
        progress.update(index=progress['index'] + 1, command=command['cmd'], returned=False)
        value = send(command)
        progress['returned'] = True
        return value

    tap_releases = {}
    disclosure_phases = {}
    page_phases = {}
    pointer_phases = {}
    idle_sample = {}
    try:
        measure(observed_send, launch.frame_timing_window, size=list(launch.TIMING_SIZE),
                windows=report['windows'], tap_releases=tap_releases,
                disclosure_phases=disclosure_phases, page_phases=page_phases,
                pointer_phases=pointer_phases, idle_sample=idle_sample)
    finally:
        if tap_releases:
            report['tap_release_us'] = tap_releases
        if disclosure_phases:
            report['disclosure_phases_us'] = disclosure_phases
        if page_phases:
            report['page_settled_us'] = page_phases['settled']
        if pointer_phases:
            report['pointer_phases_us'] = pointer_phases
        if idle_sample:
            report['idle_after_disclosure'] = idle_sample
    need(set(report['windows']) == {'page_change', 'disclosure'}, 'FRAME_REFUSED')
    for window in report['windows'].values():
        launch.frame_timing_window(window)
    report['phase'] = 'verify_after'
    owner()
    lab()
    report.update(phase='complete', success=True)
    return report


class InteractiveSession(launch.LaunchProcess):
    def __init__(self, *args, observe, shutdown_observation=None, shutdown_trace=None,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self.observe = observe
        self.shutdown_observation = (
            {} if shutdown_observation is None else shutdown_observation)
        self.shutdown_trace = {} if shutdown_trace is None else shutdown_trace

    def run_launch(self, *args, **kwargs):
        try:
            return super().run_launch(*args, **kwargs)
        finally:
            complete = False
            try:
                complete = self.report.output_complete is True
                data = self.drain.data
                value = observe_shutdown_trace(
                    bytes(data) if type(data) in (bytes, bytearray) else None,
                    output_complete=complete,
                    output_overflow=self.report.output_overflow, cap=self.limits.output_bytes)
            except (Exception, KeyboardInterrupt):
                value = dict(status='unavailable', error_code='INTERNAL_ERROR',
                             output_complete=complete)
            target = getattr(self, 'shutdown_trace', None)
            if type(target) is dict:
                target.update(value)

    def _quit(self):
        try:
            super()._quit()
        except launch.startup.Failure as original:
            if original.code == 'EXIT_TIMEOUT' and not self.shutdown_observation:
                try:
                    body = self._rpc({'cmd': 'shutdown-state'}, allow_exit=True,
                                     until=min(self.deadline, self.clock() + 1))
                    if (type(body) is not dict or set(body) != {'ok', 'phase', 'failed'}
                            or body['ok'] is not True or type(body['phase']) is not str
                            or body['phase'] not in SHUTDOWN_PHASES
                            or type(body['failed']) is not bool
                            or body['phase'] == 'idle' and body['failed']):
                        raise launch.startup.Failure('STATE_INVALID')
                    self.shutdown_observation.update(status='observed',
                        phase=body['phase'], failed=body['failed'])
                except launch.bounded.SmokeFailure as diagnostic:
                    code = diagnostic.code
                    self.shutdown_observation.update(status='unavailable',
                        error_code=code if type(code) is str
                        and code in launch.startup.CODES else 'INTERNAL_ERROR')
                except ConnectionRefusedError:
                    self.shutdown_observation.update(status='unavailable',
                        error_code='HTTP_FAILED')
                except (Exception, KeyboardInterrupt):
                    self.shutdown_observation.update(status='unavailable',
                        error_code='INTERNAL_ERROR')
            raise

    def _prepare_theme(self, theme):
        super()._prepare_theme(theme)
        try:
            self.observe(self)
        except (InteractiveRefused, actions.FrameActionRefused):
            raise launch.startup.Failure('STARTUP_OBSERVATION_REFUSED') from None


def measure_process(repo, build_repo, parent, binaries, revalidate, measure,
                    confirm_address, *, fixture_text, genesis, first_height, report):
    """Observe one release actor and keep its original normal-exit receipt."""
    parent, _ = launch.entry.require_ci(parent, None, platform=os.name)
    need(parent.get('SYRIUS_PAIRED_INTERACTIVE_PROFILE') == 'true',
         'ENVIRONMENT_REFUSED')
    need(type(report) is dict and not report, 'PROFILE_REFUSED')
    profile = launch.entry.new_profile(repo)
    original = launch.bounded.plain(profile)
    report.update(attempt=None, observation={}, profile_stable=False, success=False)
    shutdown = {}
    trace = {}
    navigation = {}
    startup = {}

    def observe(session):
        try:
            owned_profile(session._rpc, lambda payload: run_entry_process(
                build_repo, parent, profile, payload), revalidate, measure,
                confirm_address, pid=session.process.pid, port=session.transport.port,
                token=session.token, fixture_text=fixture_text, genesis=genesis,
                first_height=first_height, report=report['observation'])
        except (InteractiveRefused, actions.FrameActionRefused):
            if navigation_failure(report['observation']):
                _observe_navigation_failure(session, report['observation'], navigation)
            else:
                _observe_startup_failure(session, report['observation'], startup)
            raise

    def session(*args, **kwargs):
        return InteractiveSession(*args, observe=observe,
                                  shutdown_observation=shutdown, shutdown_trace=trace, **kwargs)

    attempt, _ = launch.run_process(
        repo, parent, binaries, profile, launch.TIMING_THEME,
        capture=False, settle=False, process_type=session, interactive=True)
    report['attempt'] = dict(attempt, role='interactive')
    if shutdown:
        report['shutdown_observation'] = shutdown
    if trace:
        report['shutdown_trace'] = trace
    if navigation:
        report['navigation_observation'] = navigation
    if startup:
        report['startup_observation'] = startup
    current = launch.bounded.plain(profile)
    report['profile_stable'] = (current.st_dev, current.st_ino) == (original.st_dev, original.st_ino)
    need(report['profile_stable'], 'PROFILE_REFUSED')
    need(launch.attempt_passed(attempt) and report['observation'].get('success') is True,
         'FRAME_REFUSED')
    report['success'] = True
    return report
