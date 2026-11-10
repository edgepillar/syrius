"""Compare ordinary cold lock frame windows on one hosted Windows runner."""

import json
import os
from pathlib import Path
import shutil
import stat
import sys

from . import windows_baseline as baseline
from . import windows_debug_loop as debug
from . import windows_launch_catalog as launch
from . import prepare_harness_tests as prepare


SCOPE = 'paired_original_cold_lock_frame_timing'
SCREEN = 'launch-timing-pair'
OUTPUT = Path('.harness/ci-launch-timing-pair')
JOB_STEP = 'Measure paired cold lock frame windows'
RETAIN_STEP = 'Retain the paired cold lock timing manifest'
ARTIFACT_PREFIX = 'windows-launch-timing-pair-'
MAX_MANIFEST = 256 * 1024
MAX_ARCHIVE = MAX_MANIFEST + 65536
FLOOR = prepare.FREE_FLOOR
RESERVATION = 4 * 1024**3
FRAME_BUDGET_US = 16000
P06_ORIGINAL = 'f024e78bf777d9b16d9e4a81c295ef092c9bf79d'
P06_SOURCE = 'e06330fd5c630fee82f59efd42140f7190260ff9'
P06_TREE = '197785948b180221aa3521b35fcc4def52620ba9'
P06_OVERLAY_TREE = 'd795458e1410dc9757ff004cd0472ba8292a2c31'
PATCH = Path('tool/ci/fixtures/p06-frame-window.patch')
PATCH_SHA256 = '06db35e49cf480b5ae43d0caac4b22280b9619fa08d687e33179ad5fbc4c294e'
COLLECTOR_SHA256 = '51c47391b0bb3c6a3c8a3cae26ed1a3f72dd56a7a8d32a175bd214a5182f4db9'
SAME_INPUTS = ('pubspec.yaml', 'pubspec.lock', 'patched_packages/reown_core-1.3.8',
               'tool/generate_git_metadata.dart', 'windows', 'lib/utils/wallet_file.dart',
               'lib/utils/constants.dart')
ORIGIN = 'https://github.com/edgepillar/syrius.git'


class PairRefused(Exception):
    def __init__(self, code):
        self.code = code if code in ('SPACE_REFUSED', 'TOOL_REFUSED') else 'INTERNAL_ERROR'
        super().__init__(self.code)


def check_space(repo, storage):
    free = shutil.disk_usage(repo).free
    storage['samples'] += 1
    storage['minimum_free_bytes'] = min(storage['minimum_free_bytes'], free)
    storage['sampled_additional_bytes'] = (
        storage['initial_free_bytes'] - storage['minimum_free_bytes'])
    if free < FLOOR or storage['sampled_additional_bytes'] > RESERVATION:
        raise PairRefused('SPACE_REFUSED')


def reserve_storage(repo, report):
    free = shutil.disk_usage(repo).free
    storage = dict(floor_bytes=FLOOR, reservation_bytes=RESERVATION,
                   initial_free_bytes=free, minimum_free_bytes=free,
                   sampled_additional_bytes=0, samples=1)
    report['storage'] = storage
    if free < FLOOR + RESERVATION:
        raise PairRefused('SPACE_REFUSED')


def build_baseline(repo, parent, report):
    """Build the reviewed P06 source and collector overlay with the current SDK."""
    report['phase'] = 'baseline_admission'
    temp = Path(parent.get('RUNNER_TEMP', ''))
    cache = Path(parent.get('PUB_CACHE', ''))
    launch.need(temp.is_absolute() and cache.is_absolute()
                and temp.drive.casefold() == repo.drive.casefold()
                and stat.S_ISDIR(launch.bounded.plain(temp).st_mode)
                and stat.S_ISDIR(launch.bounded.plain(cache).st_mode),
                'ENVIRONMENT_REFUSED')
    storage = report['storage']
    check_space(repo, storage)
    patch = repo / PATCH
    collector = repo / launch.TIMING_SOURCE
    for source in (patch, collector):
        info = launch.bounded.plain(source)
        launch.need(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= 16 * 1024,
                    'SOURCE_REFUSED')
    collector_bytes = collector.read_bytes()
    launch.need(launch.sha(patch.read_bytes()) == PATCH_SHA256
                and launch.sha(collector_bytes) == COLLECTOR_SHA256, 'SOURCE_REFUSED')
    stage = temp / 'syrius-p06-frame'
    stage.mkdir(mode=0o700)
    target = stage / 'source'
    env = baseline.fresh_environment(repo, parent)
    env.update(GITHUB_WORKSPACE=str(target), GITHUB_SHA=P06_SOURCE,
               GITHUB_SERVER_URL='https://github.com', GITHUB_REPOSITORY='edgepillar/syrius')
    git = shutil.which('git', path=env.get('PATH'))
    if git is None:
        raise PairRefused('TOOL_REFUSED')
    git = [git, '-c', 'core.autocrlf=false', '-c', 'gc.auto=0',
           '-c', 'maintenance.auto=false', '--no-pager']
    try:
        dart, snapshot = debug.sdk(parent)
    except debug.ProcessRefused:
        raise PairRefused('TOOL_REFUSED') from None
    packages = (Path(parent['FLUTTER_ROOT'])
                / 'packages/flutter_tools/.dart_tool/package_config.json')
    if not stat.S_ISREG(launch.bounded.plain(packages).st_mode):
        raise PairRefused('TOOL_REFUSED')
    flutter = [str(dart), '--packages=' + str(packages), str(snapshot)]

    def command(name, cwd, arguments, *, timeout=30, cap=65536):
        report['phase'] = name
        check_space(repo, storage)
        outcome = baseline.run_bounded(arguments, cwd=cwd, env=env, timeout=timeout, cap=cap)
        report['commands'].append(dict(stage=name, **outcome.public(),
                                       output_sha256=launch.sha(outcome.output)))
        check_space(repo, storage)
        launch.need(outcome.success, 'COMMAND_FAILED')
        return outcome.output

    def git_ids(name, cwd, *references):
        raw = command(name, cwd, git + ['rev-parse', *references], cap=1024)
        rows = raw.decode('ascii').splitlines()
        launch.need(len(rows) == len(references) and all(map(launch.bounded.valid_sha, rows)),
                    'SOURCE_REFUSED')
        return rows

    def check_overlay(suffix):
        value = command('overlay_tree_' + suffix, target, git + ['write-tree'], cap=128)
        launch.need(value.decode('ascii').splitlines() == [P06_OVERLAY_TREE], 'SOURCE_REFUSED')
        command('overlay_clean_' + suffix, target, git + ['diff', '--quiet', '--no-ext-diff', '--'])

    sdk_root = Path(parent['FLUTTER_ROOT'])
    if git_ids('sdk_revision', sdk_root, 'HEAD') != [prepare.SDK]:
        raise PairRefused('TOOL_REFUSED')
    report['sdk_revision'] = prepare.SDK
    command('fetch_p06', repo, git + ['fetch', '--no-tags', '--no-recurse-submodules',
            '--no-write-fetch-head', '--depth=1', ORIGIN, P06_SOURCE], timeout=120)
    command('checkout_p06', repo, git + ['worktree', 'add', '--detach', str(target), P06_SOURCE],
            timeout=120)
    launch.need(git_ids('p06_identity', target, 'HEAD', 'HEAD^{tree}')
                == [P06_SOURCE, P06_TREE], 'SOURCE_REFUSED')
    old_inputs = git_ids('p06_inputs', target, *('HEAD:' + path for path in SAME_INPUTS))
    new_inputs = git_ids('current_inputs', repo, *('HEAD:' + path for path in SAME_INPUTS))
    launch.need(old_inputs == new_inputs, 'SOURCE_REFUSED')
    report['equal_input_objects'] = dict(zip(SAME_INPUTS, old_inputs))
    command('patch_p06_agent', target, git + ['apply', '--index', '--whitespace=error-all',
            '--', str(patch)])
    with (target / launch.TIMING_SOURCE).open('xb') as output:
        output.write(collector_bytes)
    command('stage_p06_collector', target, git + ['add', '--', launch.TIMING_SOURCE.as_posix()])
    check_overlay('before_build')

    command('restore_p06_locked_packages', target,
            flutter + ['pub', 'get', '--offline', '--enforce-lockfile'],
            timeout=300, cap=4 * 1024**2)
    command('generate_p06_metadata', target, [str(dart), 'run', 'tool/generate_git_metadata.dart'],
            timeout=60, cap=65536)
    command('enable_p06_windows', target, flutter + ['config', '--enable-windows-desktop'])
    command('build_p06_release', target,
            flutter + ['build', 'windows', '--release', '--no-pub',
                       '--target', 'harness/app/main.dart',
                       '--dart-define-from-file=.dart_tool/git_metadata.json'],
            timeout=540, cap=4 * 1024**2)
    check_overlay('after_build')
    if git_ids('sdk_revision_after', sdk_root, 'HEAD') != [prepare.SDK]:
        raise PairRefused('TOOL_REFUSED')
    binaries = tuple(launch.bounded.binary_hash(target, path)
                     for path in (launch.startup.BINARY, launch.startup.PAYLOAD))
    report['p06'].update(overlay_verified=True, runner_sha256=binaries[0][1],
                         payload_sha256=binaries[1][1])
    return binaries


def compare_windows(baseline_window, current_window):
    def summarize(window):
        rows = launch.frame_timing_rows(window, allow_packed=True)
        by_stage = {
            'build': [row[2] for row in rows],
            'raster': [row[3] for row in rows],
            'distinct': [max(row[2], row[3]) for row in rows],
        }
        slow = {key: sorted((value for value in values if value > FRAME_BUDGET_US), reverse=True)
                for key, values in by_stage.items()}
        summary = dict(frames=len(rows), frame_number_gaps=rows[-1][0] + 1 - len(rows),
                       longest_total_us=max(row[4] for row in rows),
                       slow_frame_counts={key: len(values) for key, values in slow.items()})
        return summary, slow

    before, baseline_slow = summarize(baseline_window)
    after, current_slow = summarize(current_window)
    exceeded = []
    for key, old in baseline_slow.items():
        new = current_slow[key]
        if len(new) > len(old) or any(now > then for then, now in zip(old, new)):
            exceeded.append(key)
    return dict(budget_us=FRAME_BUDGET_US, baseline=before, current=after, exceeded=exceeded,
                no_added_reported_slow_frames=not exceeded,
                no_frame_number_gaps=before['frame_number_gaps'] == after['frame_number_gaps'] == 0)


def check_profile(profile, original):
    current = launch.bounded.plain(profile)
    launch.need((current.st_dev, current.st_ino) == original, 'PROFILE_REFUSED')


def attempt_outcomes(samples):
    fields = ('role', 'action_complete', 'exit_code', 'forced_kill', 'error_codes', 'lock_diagnostic')
    return {sample['name']: [{key: attempt[key] for key in fields if key in attempt}
                            for attempt in sample['attempts']] for sample in samples}


def measure_sample(repo, parent, current, binaries, name, report):
    theme = launch.TIMING_THEME
    report['phase'] = name + '_prepare_profile'
    profile = launch.entry.new_profile(repo)
    original = launch.bounded.plain(profile)
    identity = original.st_dev, original.st_ino
    sample = dict(name=name, attempts=[], frame_window=None)
    report['samples'].append(sample)
    prepared, _ = launch.run_process(repo, parent, current, profile, theme,
                                     capture=False, settle=True)
    sample['attempts'].append(prepared)
    launch.need(launch.attempt_passed(prepared))
    check_profile(profile, identity)
    if name == 'p06':
        report['phase'] = 'p06_warm_ordinary_profile'
        warmed, _ = launch.run_process(repo, parent, binaries, profile, theme,
                                       capture=False, settle=False)
        sample['attempts'].append(warmed)
        launch.need(launch.attempt_passed(warmed))
        check_profile(profile, identity)
    report['phase'] = name + '_measure'
    diagnostic = {}
    measured, window = launch.run_process(repo, parent, binaries, profile, theme,
        capture=True, settle=True, timing=True, lock_diagnostic=diagnostic)
    if diagnostic:
        measured['lock_diagnostic'] = diagnostic
    sample['attempts'].append(measured)
    launch.need(window is not None and launch.attempt_passed(measured))
    check_profile(profile, identity)
    sample['frame_window'] = launch.frame_timing_window(window, allow_packed=True)
    check_space(repo, report['storage'])
    return sample['frame_window']


def main():
    report = dict(schema=1, scope=SCOPE, mode='release', theme=launch.TIMING_THEME,
                  client=list(launch.TIMING_SIZE), phase='environment', success=False,
                  p06=dict(original_sha=P06_ORIGINAL, published_sha=P06_SOURCE,
                           tree=P06_TREE, overlay_tree=P06_OVERLAY_TREE, overlay_verified=False),
                  commands=[], samples=[], comparison=None, error_codes=[])
    destination = None
    try:
        launch.need(not sys.argv[1:], 'ARGUMENTS_REFUSED')
        parent, head = launch.entry.require_ci(os.environ, None, platform=os.name)
        launch.need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
                    and parent.get('GITHUB_RUN_ATTEMPT') == '1'
                    and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
                    and parent.get('GITHUB_REF') == 'refs/heads/redesign'
                    and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
                    and parent.get('SYRIUS_WINDOWS_STARTUP_PROBE') == 'true'
                    and parent.get('SYRIUS_WINDOWS_LAUNCH_CATALOG') == SCREEN,
                    'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        launch.need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        launch.bounded.verify_source(repo, head, parent)
        tree = launch.entry.source_tree(repo, parent)
        report.update(source_sha=head, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
                      run_attempt='1', baseline_patch_sha256=PATCH_SHA256,
                      collector_sha256=COLLECTOR_SHA256,
                      profile_sha256=launch.sha((repo / launch.SETTLE_PROFILE_SOURCE).read_bytes()))
        current = tuple(launch.bounded.binary_hash(repo, path)
                        for path in (launch.startup.BINARY, launch.startup.PAYLOAD))
        report['current'] = dict(runner_sha256=current[0][1], payload_sha256=current[1][1])
        report['phase'] = 'baseline_admission'
        reserve_storage(repo, report)
        launch.entry.private_root(repo)
        target = repo / OUTPUT
        target.mkdir(mode=0o700)
        destination = target
        current_window = measure_sample(repo, parent, current, current, 'current', report)
        p06 = build_baseline(repo, parent, report)
        p06_window = measure_sample(repo, parent, current, p06, 'p06', report)
        report['comparison'] = compare_windows(p06_window, current_window)
        report['phase'] = 'source_recheck'
        launch.bounded.verify_source(repo, head, parent)
        launch.need(launch.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        launch.need(tuple(launch.bounded.binary_hash(repo, path)
                          for path in (launch.startup.BINARY, launch.startup.PAYLOAD)) == current,
                    'BINARY_REFUSED')
        report.update(phase='complete', success=True)
    except (launch.bounded.SmokeFailure, PairRefused) as error:
        report['error_codes'].append(error.code)
    except (Exception, KeyboardInterrupt):
        report['error_codes'].append('INTERNAL_ERROR')
    if destination is not None:
        try:
            data = (json.dumps(report, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')
            launch.need(len(data) <= MAX_MANIFEST, 'ARTIFACT_FAILED')
            with (destination / 'manifest.json').open('xb') as output:
                output.write(data)
        except (Exception, KeyboardInterrupt):
            report['success'] = False
            report['error_codes'].append('ARTIFACT_FAILED')
    summary = {key: value for key, value in report.items()
               if key not in ('samples', 'comparison', 'commands')}
    summary['command_count'] = len(report['commands'])
    if report['commands']:
        summary['last_command'] = report['commands'][-1]
    summary['frame_counts'] = {
        sample['name']: launch.frame_timing_count(sample['frame_window']) if sample['frame_window'] else 0
        for sample in report['samples']}
    summary['attempt_outcomes'] = attempt_outcomes(report['samples'])
    if report['comparison'] is not None:
        for key in ('no_added_reported_slow_frames', 'no_frame_number_gaps'):
            summary[key] = report['comparison'][key]
    print('::notice title=Paired original cold lock frame timing::'
          + json.dumps(summary, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
