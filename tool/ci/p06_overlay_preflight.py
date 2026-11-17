"""Check the original P06 patch with real Git before allocating an SDK."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile

from . import windows_baseline as baseline
from . import windows_launch_timing_pair as timing


SCOPE = 'original_p06_strict_git_overlay'
FLOOR = 10 * 1024**3
RESERVATION = 256 * 1024**2
OUTPUT = Path('.harness/ci-p06-overlay/manifest.json')
BROKEN_SOURCE = '4de1f6c47bca2511ad808f3abec6fe1ba7ef7a34'
BROKEN_PATCH_SHA256 = '44d8efc152083c690552ba7880bbc09cda15626c3717c53aa0a9d1705fdb01dd'
FILES = (
    'harness/app/agent.dart',
    'harness/bin/harness.dart',
    'harness/bin/wallet_recipe.dart',
    'harness/wallet_recipe_failure.dart',
    'lib/widgets/reusable_widgets/launch_film.dart',
)
COLLECTOR = 'harness/app/frame_window.dart'


class Refused(Exception):
    """Carry a fixed public code, never an external error or private path."""


def need(value, code):
    if not value:
        raise Refused(code)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path, cap):
    before = baseline.plain(path)
    need(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= cap, 'SOURCE_REFUSED')
    data = path.read_bytes()
    after = baseline.plain(path)
    identity = lambda value: (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns)
    need(identity(before) == identity(after) and len(data) == before.st_size, 'SOURCE_REFUSED')
    return data


def ids(data, count):
    rows = data.decode('ascii').splitlines()
    need(len(rows) == count and all(re.fullmatch('[0-9a-f]{40}', row) for row in rows),
         'SOURCE_REFUSED')
    return rows


def qualify(repo, parent, report):
    need(parent.get('GITHUB_ACTIONS') == 'true'
         and parent.get('RUNNER_OS') == 'Linux'
         and parent.get('RUNNER_ENVIRONMENT') == 'github-hosted'
         and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
         and parent.get('GITHUB_REF') == 'refs/heads/redesign'
         and parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
         and parent.get('GITHUB_RUN_ATTEMPT') == '1'
         and re.fullmatch('[1-9][0-9]{0,19}', parent.get('GITHUB_RUN_ID', ''))
         and re.fullmatch('[0-9a-f]{40}', parent.get('GITHUB_SHA', '')),
         'ENVIRONMENT_REFUSED')
    temp = Path(parent.get('RUNNER_TEMP', ''))
    need(temp.is_absolute() and stat.S_ISDIR(baseline.plain(temp).st_mode)
         and stat.S_ISDIR(baseline.plain(repo / '.git').st_mode),
         'ENVIRONMENT_REFUSED')
    workspace = Path(parent.get('GITHUB_WORKSPACE', ''))
    need(workspace.is_absolute() and repo == workspace,
         'ENVIRONMENT_REFUSED')
    report.update(admitted=True, source_run_id=int(parent['GITHUB_RUN_ID']),
                  source_attempt=1)
    initial_free = shutil.disk_usage(repo).free
    need(initial_free >= FLOOR + RESERVATION
         and shutil.disk_usage(temp).free >= FLOOR + RESERVATION, 'SPACE_REFUSED')
    report['storage'] = dict(floor_bytes=FLOOR, reservation_bytes=RESERVATION,
                             initial_free_bytes=initial_free,
                             minimum_free_bytes=initial_free)
    env = {key: parent[key] for key in ('PATH', 'SSL_CERT_FILE', 'SSL_CERT_DIR')
           if key in parent}
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
               GIT_TERMINAL_PROMPT='0', GIT_ALLOW_PROTOCOL='https',
               GIT_LFS_SKIP_SMUDGE='1', LC_ALL='C')
    binary = shutil.which('git', path=env.get('PATH'))
    need(binary is not None, 'REQUIRED_TOOL_MISSING')
    git = [binary, '--no-pager', '-c', 'core.autocrlf=false',
           '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null',
           '-c', 'credential.helper=', '-c', 'http.https://github.com/.extraheader=',
           '-c', 'gc.auto=0', '-c', 'maintenance.auto=false',
           '-c', 'submodule.recurse=false']

    def space():
        free = shutil.disk_usage(repo).free
        report['storage']['minimum_free_bytes'] = min(
            report['storage']['minimum_free_bytes'], free)
        need(free >= FLOOR and initial_free - free <= RESERVATION
             and shutil.disk_usage(temp).free >= FLOOR, 'SPACE_REFUSED')

    def command(name, arguments, *, cwd=repo, environment=env, timeout=30,
                cap=65536, expected_failure=False):
        report['phase'] = name
        space()
        result = baseline.run_bounded(
            git + arguments, cwd=cwd, env=environment, timeout=timeout, cap=cap)
        row = dict(stage=name, **result.public(), output_sha256=sha(result.output))
        report['commands'].append(row)
        space()
        if expected_failure:
            need(result.transport_complete and result.exit_code == 1
                 and b'patch does not apply' in result.output,
                 'REGRESSION_REFUSAL_UNQUALIFIED')
            row['expected_failure'] = True
        else:
            need(result.success, 'COMMAND_FAILED')
        return result.output

    report['source_head'], report['source_tree'] = ids(command(
        'current_identity_before', ['rev-parse', 'HEAD', 'HEAD^{tree}'], cap=1024), 2)
    need(report['source_head'] == parent['GITHUB_SHA'], 'SOURCE_REFUSED')
    command('current_index_before', ['diff', '--cached', '--quiet', '--no-ext-diff', 'HEAD', '--'])
    command('current_worktree_before', ['diff', '--quiet', '--no-ext-diff', 'HEAD', '--'])
    version = command('git_version', ['--version'], cap=256).decode('ascii').strip()
    need(re.fullmatch(r'git version [0-9A-Za-z .()+_-]{1,80}', version),
         'SOURCE_REFUSED')
    report['git_version'] = version
    patch = read_file(repo / timing.PATCH, 16384)
    collector = read_file(repo / COLLECTOR, 16384)
    need(sha(patch) == timing.PATCH_SHA256
         and sha(collector) == timing.COLLECTOR_SHA256, 'SOURCE_REFUSED')
    old_paths = re.findall(br'(?m)^--- a/([^\n]+)', patch)
    new_paths = re.findall(br'(?m)^\+\+\+ b/([^\n]+)', patch)
    need(len(old_paths) == len(new_paths) == len(FILES)
         and set(old_paths) == set(new_paths) == {value.encode() for value in FILES},
         'SOURCE_REFUSED')
    report.update(patch_bytes=len(patch), patch_sha256=sha(patch),
                  collector_sha256=sha(collector))
    for name, source in (('fetch_p06', timing.P06_SOURCE),
                         ('fetch_regression_source', BROKEN_SOURCE)):
        command(name, ['fetch', '--no-tags', '--no-recurse-submodules',
                       '--no-write-fetch-head', '--depth=1', timing.ORIGIN, source],
                timeout=90)
    need(ids(command('p06_identity', ['rev-parse', timing.P06_SOURCE + '^{tree}'],
                     cap=128), 1) == [timing.P06_TREE], 'SOURCE_REFUSED')
    broken = command('read_regression_patch', [
        'show', BROKEN_SOURCE + ':' + timing.PATCH.as_posix()], cap=16384)
    need(sha(broken) == BROKEN_PATCH_SHA256, 'SOURCE_REFUSED')
    scratch = Path(tempfile.mkdtemp(prefix='syrius-p06-overlay-', dir=temp))
    source = scratch / 'source'
    source.mkdir(mode=0o700)
    private = dict(env, GIT_DIR=str(repo / '.git'), GIT_WORK_TREE=str(source),
                   GIT_INDEX_FILE=str(scratch / 'original.index'))
    command('read_original_index', ['read-tree', timing.P06_SOURCE],
            environment=private, cwd=source)
    entries = command('original_regular_files', [
        'ls-tree', timing.P06_SOURCE, '--', *FILES], cap=4096).decode().splitlines()
    need(len(entries) == len(FILES) and all(
        re.fullmatch(r'100644 blob [0-9a-f]{40}\t' + re.escape(name), row)
        for name, row in zip(sorted(FILES), entries)), 'SOURCE_REFUSED')
    command('materialize_original_files', [
        'checkout-index', '--prefix=' + str(source) + '/', '--', *FILES],
        environment=private, cwd=source)
    original = {name: sha(read_file(source / name, 256 * 1024)) for name in FILES}
    report['original_files_sha256'] = original
    previous = scratch / 'regression.patch'
    with previous.open('xb') as output:
        output.write(broken)
    command('reject_previous_patch', [
        'apply', '--index', '--whitespace=error-all', '--', str(previous)],
        environment=private, cwd=source, expected_failure=True)
    need(ids(command('regression_index_unchanged', ['write-tree'],
                     environment=private, cwd=source, cap=128), 1)
         == [timing.P06_TREE], 'SOURCE_REFUSED')
    need(all(sha(read_file(source / name, 256 * 1024)) == pin
             for name, pin in original.items()), 'SOURCE_REFUSED')
    report['previous_patch_refused_without_input_change'] = True
    command('apply_current_patch', [
        'apply', '--index', '--whitespace=error-all', '--', str(repo / timing.PATCH)],
        environment=private, cwd=source)
    report['patch_applied'] = True
    need(not command('collector_absent_before_copy', ['ls-files', '--', COLLECTOR],
                     environment=private, cwd=source, cap=128), 'SOURCE_REFUSED')
    with (source / COLLECTOR).open('xb') as output:
        output.write(collector)
    command('stage_unchanged_collector', ['add', '--', COLLECTOR],
            environment=private, cwd=source)
    observed = ids(command('verify_overlay_tree', ['write-tree'],
                           environment=private, cwd=source, cap=128), 1)[0]
    report['observed_overlay_tree'] = observed
    need(observed == timing.P06_OVERLAY_TREE, 'OVERLAY_TREE_REFUSED')
    report['applied_files_sha256'] = {
        name: sha(read_file(source / name, 256 * 1024))
        for name in (*FILES, COLLECTOR)}
    command('materialized_files_match_index', [
        'diff', '--quiet', '--no-ext-diff', '--', *FILES, COLLECTOR],
        environment=private, cwd=source)
    need(ids(command('current_identity_after', [
        'rev-parse', 'HEAD', 'HEAD^{tree}'], cap=1024), 2)
         == [report['source_head'], report['source_tree']], 'INPUT_CHANGED')
    command('current_index_after', ['diff', '--cached', '--quiet', '--no-ext-diff', 'HEAD', '--'])
    command('current_worktree_after', ['diff', '--quiet', '--no-ext-diff', 'HEAD', '--'])
    need(read_file(repo / timing.PATCH, 16384) == patch
         and read_file(repo / COLLECTOR, 16384) == collector, 'INPUT_CHANGED')
    report.update(phase='complete', workspace_inputs_unchanged=True,
                  isolated_index=True, success=True)


def main():
    report = dict(schema=1, scope=SCOPE, success=False, phase='environment',
                  source_head=None, source_tree=None, source_run_id=None,
                  source_attempt=None, admitted=False,
                  baseline_source=timing.P06_SOURCE, baseline_tree=timing.P06_TREE,
                  expected_overlay_tree=timing.P06_OVERLAY_TREE,
                  observed_overlay_tree=None, commands=[], error_code=None,
                  previous_patch_refused_without_input_change=False,
                  patch_applied=False, workspace_inputs_unchanged=False,
                  isolated_index=False, sdk_started=False, wallet_started=False,
                  node_started=False, scratch_retained_for_job_inspection=True)
    repo = Path.cwd().absolute()
    try:
        need(len(sys.argv) == 1, 'ENVIRONMENT_REFUSED')
        qualify(repo, os.environ, report)
    except Refused as error:
        report['error_code'] = str(error)
    except (Exception, KeyboardInterrupt):
        report['error_code'] = 'INTERNAL_ERROR'
    if report['admitted']:
        try:
            root = repo / OUTPUT.parent
            root.parent.mkdir(mode=0o700, exist_ok=True)
            need(stat.S_ISDIR(baseline.plain(root.parent).st_mode), 'SOURCE_REFUSED')
            root.mkdir(mode=0o700)
            data = json.dumps(report, sort_keys=True, separators=(',', ':')).encode('ascii')
            need(len(data) <= 32768, 'OUTPUT_REFUSED')
            with (repo / OUTPUT).open('xb') as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            (repo / OUTPUT).chmod(0o400)
        except (Exception, KeyboardInterrupt):
            report.update(success=False, error_code='OUTPUT_REFUSED')
    print('::notice title=P06 strict Git overlay::' + json.dumps(
        report, sort_keys=True, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
