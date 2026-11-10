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
ENTRY_SHA256 = 'c3a7e420ea32ff2098a378c056a66e979b4ebc40f9ba2fbf65032ba22404a289'


class InteractiveRefused(Exception):
    pass


def need(condition, code):
    if not condition:
        raise InteractiveRefused(code)


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
    measure(send, launch.frame_timing_window, size=list(launch.TIMING_SIZE),
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
