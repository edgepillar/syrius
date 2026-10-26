"""Attribute analyzer changes on fixed sources without builds or wallet execution.

Only tracked relative Dart paths, lint codes and numeric locations are public.
Original analyzer/dependency output remains in bounded runner memory. The two
historical worktrees and profiles belong to this fresh hosted job and are preserved.
"""

from collections import Counter
import hashlib
import json
import os
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import secrets
import shutil

from . import windows_baseline as baseline
from . import windows_debug_loop as debug


HISTORY = (
    ('before', '1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0',
     '9a8eec6320aa5cf1be0cad89f4bf9b4e8e979d18'),
    ('reported', 'f024e78bf777d9b16d9e4a81c295ef092c9bf79d',
     '197785948b180221aa3521b35fcc4def52620ba9'),
)
SDK = 'abaf9c523780a608bd46686fd5e53740a07077f8'
INPUTS = ('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml',
          'patched_packages/reown_core-1.3.8/pubspec.yaml',
          'patched_packages/reown_core-1.3.8/pubspec.lock')
CODES = frozenset(('ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'TOOL_REFUSED',
    'SPACE_REFUSED', 'COMMAND_FAILED', 'ANALYSIS_INVALID', 'ANALYSIS_FAILED',
    'INPUTS_CHANGED', 'INTERNAL_ERROR'))
DIAGNOSTIC = re.compile(
    r'^\s*(error|warning|info)\s+[\u2022-]\s+.+\s+[\u2022-]\s+'
    r'(.+):(\d+):(\d+)\s+[\u2022-]\s+([a-z][a-z0-9_]{0,99})\s*$')
PATH = re.compile(r'[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\.dart')
MAX_OUTPUT = 8 * 1024**2
FREE_FLOOR = 10 * 1024**3
RESERVATION = 4 * 1024**3


class Refused(Exception):
    pass


def need(value, code):
    if not value:
        raise Refused(code)


def relative_dart(offered, root, tracked):
    """Reject private or untracked paths rather than trimming them for output."""
    offered = offered.replace('\\', '/')
    root = str(root).replace('\\', '/')
    windows = bool(re.match(r'^[A-Za-z]:/', root))
    cls = PureWindowsPath if windows else PurePosixPath
    path = cls(offered)
    need('..' not in path.parts and not offered.startswith('//'), 'ANALYSIS_INVALID')
    if path.is_absolute():
        try:
            path = path.relative_to(cls(root))
        except ValueError:
            raise Refused('ANALYSIS_INVALID') from None
    value = path.as_posix()
    need(PATH.fullmatch(value) is not None and value in tracked, 'ANALYSIS_INVALID')
    return value


def diagnostics(raw, root, tracked):
    need(type(raw) is bytes and len(raw) <= MAX_OUTPUT, 'ANALYSIS_INVALID')
    try:
        raw.decode('utf-8', 'strict')
        counts = baseline.analysis_counts(raw)
    except (UnicodeError, baseline.BaselineFailure):
        raise Refused('ANALYSIS_INVALID') from None
    rows = []
    for line in baseline.clean_text(raw).splitlines():
        if not re.match(r'^\s*(error|warning|info)\s+[\u2022-]\s+', line):
            continue
        match = DIAGNOSTIC.fullmatch(line)
        need(match is not None, 'ANALYSIS_INVALID')
        level, offered, row, column, code = match.groups()
        row, column = int(row), int(column)
        need(0 < row <= 10**7 and 0 < column <= 10**7, 'ANALYSIS_INVALID')
        rows.append((level, relative_dart(offered, root, tracked), code, row, column))
    levels = Counter(row[0] for row in rows)
    need(counts == dict(errors=levels['error'], warnings=levels['warning'],
                        infos=levels['info']) and len(rows) <= 20000, 'ANALYSIS_INVALID')
    return counts, rows


def changes(before, after):
    """Compare multiplicities per file/code; shifted line numbers are not new lints."""
    old = Counter(row[:3] for row in before)
    new = Counter(row[:3] for row in after)
    groups = []
    for key in sorted(old.keys() | new.keys()):
        if old[key] == new[key]:
            continue
        level, path, code = key
        locations = sorted({row[3:] for row in after if row[:3] == key})
        groups.append(dict(level=level, file=path, code=code, before=old[key],
            after=new[key], delta=new[key] - old[key],
            locations=[dict(line=row, column=column) for row, column in locations[:3]],
            locations_truncated=len(locations) > 3))
    return groups


def notice_projection(value, groups, *, cap=3800):
    result = dict(value, groups=[], total_groups=len(groups), truncated=False)
    for group in groups:
        candidate = dict(result, groups=result['groups'] + [group])
        if len(json.dumps(candidate, separators=(',', ':'), sort_keys=True).encode()) > cap:
            result['truncated'] = True
            break
        result = candidate
    return result


def main():
    report = dict(schema=1, scope='source_bound_analysis_delta', success=False,
        wallet_qualified=False, native_wallet_executions=0, builds=0, tests=0,
        phase='environment', code=None, sources=[], commands=[])
    comparisons = []
    try:
        parent, head = debug.entry.require_ci(os.environ, None, platform=os.name)
        need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
            and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
            and parent.get('GITHUB_REF') == 'refs/heads/redesign', 'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        debug.bounded.verify_source(repo, head, parent)
        tree = debug.entry.source_tree(repo, parent)
        report.update(source_sha=head, source_tree=tree,
            run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        dart, snapshot = debug.sdk(parent)
        packages = Path(parent['FLUTTER_ROOT']) / 'packages/flutter_tools/.dart_tool/package_config.json'
        flutter = [str(dart), '--packages=' + str(packages), str(snapshot)]
        env = baseline.fresh_environment(repo, parent)
        git = shutil.which('git', path=env.get('PATH'))
        need(git is not None, 'TOOL_REFUSED')
        temporary = Path(parent.get('RUNNER_TEMP', ''))
        need(temporary.is_absolute() and temporary.is_dir(), 'ENVIRONMENT_REFUSED')
        debug.bounded.plain(temporary)
        need(shutil.disk_usage(temporary).free >= FREE_FLOOR + RESERVATION, 'SPACE_REFUSED')
        root = temporary / ('syrius-analysis-' + secrets.token_hex(12))
        root.mkdir(mode=0o700)

        def command(label, arguments, cwd, *, timeout=120, cap=262144, required=True,
                    child_env=None):
            need(shutil.disk_usage(root).free >= FREE_FLOOR, 'SPACE_REFUSED')
            outcome = baseline.run_bounded(arguments, cwd=cwd, env=env if child_env is None else child_env,
                                           timeout=timeout, cap=cap)
            report['commands'].append(dict(stage=label, **outcome.public(),
                output_sha256=hashlib.sha256(outcome.output).hexdigest()))
            need(outcome.transport_complete and (not required or outcome.success), 'COMMAND_FAILED')
            return outcome.output

        report['phase'] = 'sdk'
        actual_sdk = command('sdk_source', [git, '-C', parent['FLUTTER_ROOT'],
            'rev-parse', 'HEAD'], repo, cap=128).decode('ascii').strip()
        need(actual_sdk == SDK, 'TOOL_REFUSED')
        report['sdk_revision'] = actual_sdk
        report['phase'] = 'source'
        origin = command('origin', [git, 'remote', 'get-url', 'origin'], repo,
                         cap=256).decode('ascii').strip()
        need(origin in ('https://github.com/edgepillar/syrius',
                        'https://github.com/edgepillar/syrius.git'), 'SOURCE_REFUSED')
        command('fetch_fixed_history', [git, '-c', 'credential.helper=', '-c',
            'http.followRedirects=false', 'fetch', '--quiet', '--no-tags', '--depth=1',
            'origin', HISTORY[0][1], HISTORY[1][1]], repo, timeout=180)
        declarations = []
        for label, source, expected_tree in (*HISTORY, ('current', head, tree)):
            report['phase'] = label
            target = repo if label == 'current' else root / label
            if label != 'current':
                command(label + '_worktree', [git, 'worktree', 'add', '--quiet',
                    '--detach', str(target), source], repo, timeout=180)
            actual = command(label + '_tree', [git, 'rev-parse', 'HEAD^{tree}'],
                             target, cap=128).decode('ascii').strip()
            need(actual == expected_tree, 'SOURCE_REFUSED')
            inputs = {name: hashlib.sha256((target / name).read_bytes()).hexdigest()
                      for name in INPUTS}
            need(not declarations or inputs == declarations[0], 'INPUTS_CHANGED')
            declarations.append(inputs)
            tracked_raw = command(label + '_tracked', [git, 'ls-files', '-z', '--', '*.dart'],
                                  target, cap=1024**2)
            tracked = set(tracked_raw.decode('utf-8').rstrip('\0').split('\0'))
            need(tracked and all(PATH.fullmatch(name) for name in tracked), 'SOURCE_REFUSED')
            child_env = baseline.fresh_environment(target, parent)
            command(label + '_restore', flutter + ['pub', 'get', '--enforce-lockfile'],
                    target, child_env=child_env, timeout=600, cap=4 * 1024**2)
            command(label + '_restore_vendored', flutter + ['pub', 'get', '--enforce-lockfile'],
                    target / 'patched_packages/reown_core-1.3.8', child_env=child_env,
                    timeout=600, cap=4 * 1024**2)
            raw = command(label + '_analysis', flutter + ['analyze', '--no-pub', '--no-fatal-infos'],
                          target, child_env=child_env, timeout=300, cap=MAX_OUTPUT, required=False)
            counts, rows = diagnostics(raw, target, tracked)
            report['sources'].append(dict(label=label, head=source, tree=actual,
                counts=counts, tracked_dart_files=len(tracked),
                inputs_sha256=hashlib.sha256(json.dumps(inputs, sort_keys=True,
                    separators=(',', ':')).encode()).hexdigest()))
            need(not counts['errors'] and not counts['warnings']
                and report['commands'][-1]['success'], 'ANALYSIS_FAILED')
            debug.bounded.verify_source(target, source, parent)
            need(debug.entry.source_tree(target, parent) == expected_tree, 'SOURCE_REFUSED')
            comparisons.append(rows)
        report['phase'] = 'source_unchanged'
        debug.bounded.verify_source(repo, head, parent)
        need(debug.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        report['dependency_inputs_equal'] = True
        report['success'] = True
    except (Exception, KeyboardInterrupt) as error:
        code = str(error)
        report['code'] = code if code in CODES else 'INTERNAL_ERROR'
    print(json.dumps(report, sort_keys=True, separators=(',', ':')))
    summary = {key: value for key, value in report.items() if key != 'commands'}
    summary['analysis_commands'] = [row for row in report['commands']
        if row['stage'] in ('before_analysis', 'reported_analysis', 'current_analysis')]
    print('::notice title=Hosted analysis delta::' + json.dumps(summary, sort_keys=True, separators=(',', ':')))
    for title, start, end in (('Historical analysis locations', 0, 1),
                              ('Current analysis locations', 1, 2)):
        if len(comparisons) > end:
            projection = notice_projection(dict(schema=1, scope='source_bound_analysis_locations',
                source_sha=report['source_sha'], run_id=report['run_id'],
                before=report['sources'][start]['head'], after=report['sources'][end]['head']),
                changes(comparisons[start], comparisons[end]))
            print('::notice title=' + title + '::' + json.dumps(projection, sort_keys=True, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
