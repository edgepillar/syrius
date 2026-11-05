"""Restore locked harness inputs on a fresh hosted runner without a native build."""

import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys

from . import windows_baseline as baseline
from . import windows_debug_loop as debug
from .analysis_delta import INPUTS, SDK


FREE_FLOOR = 10 * 1024**3
RESERVATION = 3 * 1024**3
CODES = frozenset(('ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'TOOL_REFUSED',
    'SPACE_REFUSED', 'PROFILE_REFUSED', 'COMMAND_FAILED', 'INPUTS_CHANGED',
    'INTERNAL_ERROR'))
OBSERVATION_FILES = ('lib/l10n/app_localizations.dart',) + tuple(
    'lib/l10n/app_localizations_' + locale + '.dart'
    for locale in ('ar', 'en', 'es', 'hi', 'zh')) + (
    'lib/l10n/untranslated.json',
    'windows/flutter/generated_plugin_registrant.cc',
    'windows/flutter/generated_plugin_registrant.h',
    'windows/flutter/generated_plugins.cmake',
    'linux/flutter/generated_plugin_registrant.cc',
    'linux/flutter/generated_plugin_registrant.h',
    'linux/flutter/generated_plugins.cmake',
    'macos/Flutter/GeneratedPluginRegistrant.swift')


def source_change(name, before, after):
    """Describe only a fixed public source name; never export private paths."""
    if name not in OBSERVATION_FILES:
        raise ValueError('UNAPPROVED_SOURCE_FILE')
    if any(v is not None and (type(v) is not bytes or len(v) > 1024**2)
           for v in (before, after)):
        raise ValueError('SOURCE_OBSERVATION_REFUSED')
    row = dict(file=name, edits=[], edits_status='OMITTED_UNSAFE')
    for role, raw in (('before', before), ('after', after)):
        row[role + '_bytes'] = None if raw is None else len(raw)
        row[role + '_sha256'] = None if raw is None else hashlib.sha256(raw).hexdigest()
    try:
        old = (before or b'').decode('utf-8').splitlines(keepends=True)
        new = (after or b'').decode('utf-8').splitlines(keepends=True)
    except UnicodeError:
        return row
    edits = []
    for tag, first, end, start, stop in difflib.SequenceMatcher(
            a=old, b=new, autojunk=False).get_opcodes():
        if tag != 'equal':
            text = ''.join(old[first:end] + new[start:stop])
            if not text.isascii() or re.search(
                    r'(?i)(?:[a-z]:[\\/]|/(?:Users|home|Volumes|tmp)/|'
                    r'\bBearer\s|\bgh[opusr]_)', text):
                return row
            edits.append(dict(old_start=first, old_lines=old[first:end],
                              new_lines=new[start:stop]))
    if len(edits) > 8 or len(json.dumps(edits).encode()) > 2400:
        row['edits_status'] = 'OMITTED_BUDGET'
        return row
    row.update(edits=edits, edits_status='OBSERVED')
    return row


def capture_observation_sources(repo):
    files = {}
    total = 0
    for name in OBSERVATION_FILES:
        path = repo / name
        if path.exists() or path.is_symlink():
            debug.bounded.plain(path)
            debug.need(path.stat().st_size <= 1024**2, 'SOURCE_REFUSED')
            files[name] = path.read_bytes()
            total += len(files[name])
        else:
            files[name] = None
    debug.need(total <= 2 * 1024**2, 'SOURCE_REFUSED')
    return files


def observe_source_refusal(repo, parent, source, tree, before):
    """Observe the original check's Git environment without changing its result."""
    result = dict(status='REFUSED', checks={}, commands=[], files=[],
                  other_tracked_changes=None)
    try:
        env = {k: v for k, v in parent.items() if not k.upper().startswith('GIT_')}
        env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)

        def command(stage, arguments, cap):
            value = baseline.run_bounded(['git', '-C', str(repo), *arguments],
                cwd=repo, env=env, timeout=10, cap=cap)
            result['commands'].append(dict(stage=stage, **value.public(),
                output_sha256=hashlib.sha256(value.output).hexdigest()))
            return value

        def matches(value, expected):
            if not value.transport_complete or value.exit_code != 0:
                return None
            return value.output in ((expected + '\n').encode(), (expected + '\r\n').encode())

        def clean(value):
            return (value.exit_code == 0 if value.transport_complete
                    and value.exit_code in (0, 1) else None)

        result['checks']['head_matches'] = matches(
            command('head', ['rev-parse', 'HEAD'], 128), source)
        result['checks']['tree_matches'] = matches(
            command('tree', ['rev-parse', 'HEAD^{tree}'], 128), tree)
        result['checks']['worktree_matches'] = clean(
            command('worktree', ['diff', '--quiet', 'HEAD', '--'], 4096))
        result['checks']['index_matches'] = clean(
            command('index', ['diff', '--cached', '--quiet', 'HEAD', '--'], 4096))
        names = command('changed_names', ['diff', '--name-only', '-z', 'HEAD', '--'], 16384)
        if not names.transport_complete or names.exit_code != 0:
            return result
        debug.need(not names.output or names.output.endswith(b'\0'), 'SOURCE_REFUSED')
        offered = names.output.rstrip(b'\0').split(b'\0') if names.output else []
        debug.need(len(offered) <= 512 and len(set(offered)) == len(offered), 'SOURCE_REFUSED')
        known = {n.encode(): n for n in OBSERVATION_FILES}
        after = capture_observation_sources(repo)
        result['files'] = [source_change(known[n], before[known[n]], after[known[n]])
                           for n in offered if n in known]
        result.update(status='OBSERVED',
            other_tracked_changes=sum(n not in known for n in offered))
    except (Exception, KeyboardInterrupt):
        # Diagnosis cannot replace or turn the original refusal into success.
        result['status'] = 'REFUSED'
    return result


def admit(environment, *, platform, cwd):
    """Refuse an unowned or non-opted-in environment before allocating a profile."""
    parent, source = debug.entry.require_ci(environment, None, platform=platform)
    debug.need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
        and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
        and parent.get('GITHUB_REF') == 'refs/heads/redesign'
        and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
        and parent.get('SYRIUS_HARNESS_TESTS_ONLY') == 'true'
        and parent.get('SYRIUS_WINDOWS_WALLET_TOUR') != 'true', 'ENVIRONMENT_REFUSED')
    repo = Path(parent['GITHUB_WORKSPACE'])
    debug.need(repo.resolve() == cwd.resolve(), 'ENVIRONMENT_REFUSED')
    return parent, source, repo


def input_digest(repo):
    offered = {}
    for name in INPUTS:
        path = repo / name
        debug.bounded.plain(path)
        offered[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashlib.sha256(json.dumps(offered, sort_keys=True,
        separators=(',', ':')).encode()).hexdigest()


def no_native_allocations(repo):
    return not any(path.exists() or path.is_symlink() for path in (
        repo / '.harness/app', repo / '.harness/ci-node-source',
        repo / '.harness/ci-chain321'))


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    report = dict(schema=1, scope='focused_harness_dependencies', success=False,
        admission_only=arguments == ['--admission-only'], phase='environment',
        native_wallet_executions=0, native_node_executions=0, native_builds=0,
        commands=[], inputs_unchanged=False, code=None)
    observation_before = observation_context = None
    try:
        debug.need(arguments in ([], ['--admission-only']), 'ENVIRONMENT_REFUSED')
        parent, source, repo = admit(os.environ, platform=os.name, cwd=Path.cwd())
        debug.bounded.verify_source(repo, source, parent)
        tree = debug.entry.source_tree(repo, parent)
        report.update(source_sha=source, source_tree=tree,
            run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        debug.need(no_native_allocations(repo), 'PROFILE_REFUSED')
        if arguments == ['--admission-only']:
            report.update(phase='admitted', success=True)
        else:
            debug.need(shutil.disk_usage(repo).free >= FREE_FLOOR + RESERVATION,
                       'SPACE_REFUSED')
            before = input_digest(repo)
            dart, snapshot = debug.sdk(parent)
            env = baseline.fresh_environment(repo, parent)
            git = shutil.which('git', path=env.get('PATH'))
            debug.need(git is not None, 'TOOL_REFUSED')

            def command(stage, arguments, cwd, *, timeout=600, cap=4 * 1024**2):
                debug.need(shutil.disk_usage(repo).free >= FREE_FLOOR, 'SPACE_REFUSED')
                outcome = baseline.run_bounded(arguments, cwd=cwd, env=env,
                                               timeout=timeout, cap=cap)
                report['commands'].append(dict(stage=stage, **outcome.public(),
                    output_sha256=hashlib.sha256(outcome.output).hexdigest()))
                debug.need(outcome.success and outcome.transport_complete, 'COMMAND_FAILED')
                return outcome.output

            report['phase'] = 'sdk'
            revision = command('sdk_revision', [git, '-C', parent['FLUTTER_ROOT'],
                'rev-parse', 'HEAD'], repo, timeout=30, cap=128).decode('ascii').strip()
            debug.need(revision == SDK, 'TOOL_REFUSED')
            report['sdk_revision'] = revision
            packages = Path(parent['FLUTTER_ROOT']) / 'packages/flutter_tools/.dart_tool/package_config.json'
            flutter = [str(dart), '--packages=' + str(packages), str(snapshot)]
            report['phase'] = 'restore'
            observation_before = capture_observation_sources(repo)
            observation_context = repo, parent, source, tree
            command('application_restore', flutter + ['pub', 'get', '--enforce-lockfile'], repo)
            command('vendored_restore', flutter + ['pub', 'get', '--enforce-lockfile'],
                    repo / 'patched_packages/reown_core-1.3.8')
            debug.need(input_digest(repo) == before, 'INPUTS_CHANGED')
            report['locked_inputs_digest_unchanged'] = True
            report['phase'] = 'verify_head_after_restore'
            debug.bounded.verify_source(repo, source, parent)
            report['phase'] = 'verify_tree_after_restore'
            debug.need(debug.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
            debug.need(no_native_allocations(repo), 'PROFILE_REFUSED')
            report.update(phase='source_unchanged', success=True, inputs_unchanged=True,
                          inputs_sha256=before)
    except (Exception, KeyboardInterrupt) as error:
        code = getattr(error, 'code', None) or str(error)
        report['code'] = code if code in CODES else 'INTERNAL_ERROR'
        if (report['code'] == 'SOURCE_REFUSED' and observation_before is not None
                and observation_context is not None):
            report['source_observation'] = observe_source_refusal(
                *observation_context, observation_before)
    public = json.dumps(report, sort_keys=True, separators=(',', ':'))
    print(public)
    if len(public.encode()) <= 3800:
        print('::notice title=Focused harness dependencies::' + public)
    observation = report.get('source_observation')
    if observation is not None:
        binding = {k: report[k] for k in ('source_sha', 'source_tree', 'run_id', 'run_attempt')}
        header = dict(schema=1, scope='focused_restore_source_observation',
            original_code=report['code'], original_success=report['success'],
            original_commands=report['commands'], sdk_revision=report.get('sdk_revision'),
            locked_inputs_digest_unchanged=report.get('locked_inputs_digest_unchanged', False),
            native_wallet_executions=0, native_node_executions=0, native_builds=0,
            phase=report['phase'], **binding,
            **{k: observation[k] for k in ('status', 'checks', 'commands', 'other_tracked_changes')},
            known_changed_files=len(observation['files']),
            files_without_notice=max(0, len(observation['files']) - 8))
        frames = [header] + [dict(schema=1, scope='focused_restore_file_change',
            **binding, **row) for row in observation['files'][:8]]
        for frame in frames:
            encoded = json.dumps(frame, sort_keys=True, separators=(',', ':'))
            if len(encoded.encode()) <= 3800:
                print('::notice title=Focused restore source observation::' + encoded.replace('%', '%25'))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
