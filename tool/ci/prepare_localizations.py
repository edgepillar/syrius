"""Generate a finite localization delta without building or opening a wallet."""

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
from .analysis_delta import SDK


LABELS = dict(zapReceivedBack='Zap back', zapReceivedNice='Nice',
             zapSenderAttribution='Written by the sender, not by Syrius.')
DART_FILES = ('lib/l10n/app_localizations.dart',) + tuple(
    'lib/l10n/app_localizations_' + locale + '.dart'
    for locale in ('ar', 'en', 'es', 'hi', 'zh'))
REPORT = 'lib/l10n/untranslated.json'
OUTPUTS = (*DART_FILES, REPORT)
INPUTS = ('l10n.yaml', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') + tuple(
    'lib/l10n/app_' + locale + '.arb' for locale in ('ar', 'en', 'es', 'hi', 'zh'))
FREE_FLOOR = 10 * 1024**3
CODES = frozenset(('ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'TOOL_REFUSED',
    'SPACE_REFUSED', 'COMMAND_FAILED', 'DELTA_REFUSED', 'INTERNAL_ERROR'))


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def delta(before, after):
    """Export only generated insertions and the fixed missing-key report."""
    debug.need(set(before) == set(after) == set(OUTPUTS), 'DELTA_REFUSED')
    files = {}
    for name in OUTPUTS:
        a, b = before[name], after[name]
        debug.need(type(a) is bytes and type(b) is bytes
            and len(a) <= 1024**2 and len(b) <= 1024**2 and a != b,
            'DELTA_REFUSED')
        old, new = a.decode('utf-8').splitlines(keepends=True), b.decode('utf-8').splitlines(keepends=True)
        edits = []
        for tag, first, end, start, stop in difflib.SequenceMatcher(a=old, b=new, autojunk=False).get_opcodes():
            if tag == 'equal':
                continue
            debug.need(name == REPORT or tag == 'insert', 'DELTA_REFUSED')
            offered = ''.join(old[first:end] + new[start:stop])
            debug.need(offered.isascii(), 'DELTA_REFUSED')
            edits.append(dict(old_start=first, old_lines=old[first:end],
                              new_lines=new[start:stop]))
        if name in DART_FILES:
            for key in LABELS:
                debug.need(('get ' + key) not in a.decode()
                    and b.decode().count('get ' + key) == 1, 'DELTA_REFUSED')
            introduced = ''.join(line for edit in edits for line in edit['new_lines'])
            code = '\n'.join(line for line in introduced.splitlines()
                if line.strip() and not line.lstrip().startswith('//')
                and line.strip() != '@override')
            for key, value in LABELS.items():
                pattern = r'\bString\s+get\s+' + key + r'\s*(?:;|=>\s*' + re.escape("'" + value + "'") + r';)'
                code, count = re.subn(pattern, '', code)
                debug.need(count == 1, 'DELTA_REFUSED')
            debug.need(not code.strip(), 'DELTA_REFUSED')
        else:
            x, y = json.loads(a), json.loads(b)
            debug.need(type(x) is dict and type(y) is dict and set(x) == set(y), 'DELTA_REFUSED')
            for locale in x:
                debug.need(locale in ('ar', 'en', 'es', 'hi', 'zh')
                    and type(x[locale]) is list and type(y[locale]) is list
                    and all(type(v) is str for v in x[locale] + y[locale])
                    and len(set(x[locale])) == len(x[locale])
                    and len(set(y[locale])) == len(y[locale])
                    and set(y[locale]) == set(x[locale]) | (set() if locale == 'en' else set(LABELS)),
                    'DELTA_REFUSED')
        files[name] = dict(before_bytes=len(a), before_sha256=sha(a),
            after_bytes=len(b), after_sha256=sha(b), edits=edits)
    debug.need(len(json.dumps(files).encode()) <= 48 * 1024, 'DELTA_REFUSED')
    return files


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    report = dict(schema=1, scope='english_localization_preparation',
        success=False, code=None, commands=[], files={},
        native_wallet_executions=0, native_node_executions=0, application_builds=0)
    try:
        debug.need(arguments in ([], ['--admission-only']), 'ENVIRONMENT_REFUSED')
        parent, source = debug.entry.require_ci(os.environ, None, platform=os.name)
        debug.need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
            and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
            and parent.get('GITHUB_REF') == 'refs/heads/redesign'
            and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
            and parent.get('SYRIUS_LOCALIZATION_PREPARATION') == 'true',
            'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        debug.need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        debug.bounded.verify_source(repo, source, parent)
        tree = debug.entry.source_tree(repo, parent)
        debug.need(shutil.disk_usage(repo).free >= FREE_FLOOR + 3 * 1024**3, 'SPACE_REFUSED')
        report.update(source_sha=source, source_tree=tree,
            run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        if arguments:
            report.update(success=True, phase='admitted_without_sdk')
        else:
            env = baseline.fresh_environment(repo, parent)
            git = shutil.which('git', path=env.get('PATH'))
            debug.need(git is not None, 'TOOL_REFUSED')

            def command(stage, argv, cap=65536, timeout=30):
                debug.need(shutil.disk_usage(repo).free >= FREE_FLOOR, 'SPACE_REFUSED')
                result = baseline.run_bounded(argv, cwd=repo, env=env,
                    timeout=timeout, cap=cap)
                report['commands'].append(dict(stage=stage,
                    **result.public(), output_sha256=sha(result.output)))
                debug.need(result.success and result.transport_complete, 'COMMAND_FAILED')
                return result.output

            def read(name):
                path = repo / name
                debug.bounded.plain(path)
                debug.need(path.stat().st_size <= 1024**2, 'SOURCE_REFUSED')
                return path.read_bytes()

            before_inputs = {name: sha(read(name)) for name in INPUTS}
            template = json.loads(read('lib/l10n/app_en.arb'))
            debug.need(all(template.get(k) == v for k, v in LABELS.items()), 'SOURCE_REFUSED')
            before = {name: read(name) for name in OUTPUTS}
            revision = command('sdk_revision', [git, '-C', parent['FLUTTER_ROOT'],
                'rev-parse', 'HEAD'], cap=128).decode('ascii').strip()
            debug.need(revision == SDK, 'TOOL_REFUSED')
            dart, snapshot = debug.sdk(parent)
            packages = Path(parent['FLUTTER_ROOT']) / 'packages/flutter_tools/.dart_tool/package_config.json'
            debug.bounded.plain(packages)
            command('gen_l10n', [str(dart), '--packages=' + str(packages),
                str(snapshot), 'gen-l10n'], timeout=120)
            debug.need({name: sha(read(name)) for name in INPUTS} == before_inputs, 'SOURCE_REFUSED')
            changed = command('changed_files', [git, 'diff', '--name-only', '-z'], cap=8192)
            debug.need(set(changed.decode().strip('\0').split('\0')) == set(OUTPUTS), 'SOURCE_REFUSED')
            debug.need(not command('index_unchanged', [git, 'diff', '--cached', '--name-only'], cap=8192), 'SOURCE_REFUSED')
            debug.need(command('head_unchanged', [git, 'rev-parse', 'HEAD'], cap=128).decode().strip() == source, 'SOURCE_REFUSED')
            report.update(files=delta(before, {name: read(name) for name in OUTPUTS}),
                sdk_revision=revision, inputs_sha256=before_inputs,
                generated_outputs_only=True, source_head_and_index_unchanged=True,
                phase='generated_delta_prepared', success=True)
    except (Exception, KeyboardInterrupt) as error:
        code = getattr(error, 'code', None) or str(error)
        report['code'] = code if code in CODES else 'INTERNAL_ERROR'
    public = json.dumps(report, sort_keys=True, separators=(',', ':'))
    if len(public.encode()) > 60 * 1024:
        report.update(success=False, code='DELTA_REFUSED', files={})
        public = json.dumps(report, sort_keys=True, separators=(',', ':'))
    print(public)
    print('::notice title=English localization preparation::' + public.replace('%', '%25'))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
