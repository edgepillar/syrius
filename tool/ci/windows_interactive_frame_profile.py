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
ENTRY_SHA256 = '6572908b7d68590547fe79e428a837d4e002ec7d6fe0058568670ff848d0b031'
MEASUREMENT_COMMANDS = frozenset(('theme', 'state', 'stalls', 'tap', 'wait', 'scroll'))
MAX_MEASUREMENT_COMMANDS = 32
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

    measure(observed_send, launch.frame_timing_window, size=list(launch.TIMING_SIZE),
            windows=report['windows'])
    need(set(report['windows']) == {'page_change', 'disclosure'}, 'FRAME_REFUSED')
    for window in report['windows'].values():
        launch.frame_timing_window(window)
    report['phase'] = 'verify_after'
    owner()
    lab()
    report.update(phase='complete', success=True)
    return report


class InteractiveSession(launch.LaunchProcess):
    def __init__(self, *args, observe, **kwargs):
        super().__init__(*args, **kwargs)
        self.observe = observe

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

    def observe(session):
        owned_profile(session._rpc, lambda payload: run_entry_process(
            build_repo, parent, profile, payload), revalidate, measure,
            confirm_address, pid=session.process.pid, port=session.transport.port,
            token=session.token, fixture_text=fixture_text, genesis=genesis,
            first_height=first_height, report=report['observation'])

    def session(*args, **kwargs):
        return InteractiveSession(*args, observe=observe, **kwargs)

    attempt, _ = launch.run_process(
        repo, parent, binaries, profile, launch.TIMING_THEME,
        capture=False, settle=False, process_type=session, interactive=True)
    report['attempt'] = dict(attempt, role='interactive')
    current = launch.bounded.plain(profile)
    report['profile_stable'] = (current.st_dev, current.st_ino) == (original.st_dev, original.st_ino)
    need(report['profile_stable'], 'PROFILE_REFUSED')
    need(launch.attempt_passed(attempt) and report['observation'].get('success') is True,
         'FRAME_REFUSED')
    report['success'] = True
    return report
