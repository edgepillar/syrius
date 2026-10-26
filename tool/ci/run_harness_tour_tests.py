"""Run the six isolated tour regressions with finite, source-bound output."""

import hashlib
import json
import os
from pathlib import Path

import windows_debug_loop as debug
from windows_baseline import fresh_environment, run_bounded, test_counts


def main():
    report = dict(schema=1, scope='wallet_tour_controller_tests', success=False,
                  wallet_qualified=False, native_wallet_executions=0, counts=None,
                  command=None, code=None)
    try:
        parent, source = debug.entry.require_ci(os.environ, None, platform=os.name)
        repo = Path(parent['GITHUB_WORKSPACE'])
        debug.need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        debug.bounded.verify_source(repo, source, parent)
        tree = debug.entry.source_tree(repo, parent)
        report.update(source_sha=source, source_tree=tree,
                      run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        dart, snapshot = debug.sdk(parent)
        packages = Path(parent['FLUTTER_ROOT']) / 'packages/flutter_tools/.dart_tool/package_config.json'
        outcome = run_bounded([str(dart), '--packages=' + str(packages), str(snapshot),
            'test', '--no-pub', '--reporter', 'json', '--concurrency=1',
            'test/harness/wallet_tour_test.dart'], cwd=repo,
            env=fresh_environment(repo, parent), timeout=240, cap=4 * 1024**2)
        report['command'] = dict(**outcome.public(),
            output_sha256=hashlib.sha256(outcome.output).hexdigest())
        debug.need(outcome.transport_complete, 'OUTPUT_REFUSED')
        counts = test_counts(outcome.output)
        report['counts'] = counts
        debug.need(outcome.success and counts['terminal_success'] is True
            and counts['passed'] == 6 and counts['skipped'] == counts['failed'] == counts['error_events'] == 0,
            'TESTS_FAILED')
        debug.bounded.verify_source(repo, source, parent)
        debug.need(debug.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        report['success'] = True
    except (Exception, KeyboardInterrupt) as error:
        known = {'ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'PROFILE_REFUSED',
                 'TOOL_REFUSED', 'OUTPUT_REFUSED', 'TESTS_FAILED', 'TEST_EVENTS_INVALID'}
        code = getattr(error, 'code', None) or str(error)
        report['code'] = code if code in known else 'INTERNAL_ERROR'
    public = json.dumps(report, sort_keys=True, separators=(',', ':'))
    print(public)
    if len(public.encode()) <= 3800:
        print('::notice title=Wallet tour controller tests::' + public)
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
