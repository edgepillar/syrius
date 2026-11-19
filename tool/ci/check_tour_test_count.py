"""Check the Windows tour case count against the regular Linux test run."""

import argparse
import json
import posixpath
from pathlib import Path

from .dart_test_progress import _path
from .run_harness_tour_tests import EXPECTED_DART_CASES, TOUR_TEST_PATHS

MAX_LINE_BYTES = 1024**2
MAX_REPORT_BYTES = 16 * 1024**2


def selected_passes(stream, *, repo, paths):
    """Count completed ordinary tests for the selected source suites."""
    root = repo.resolve().as_posix()
    expected = {_path(posixpath.join(root, path)) for path in paths}
    if None in expected:
        raise ValueError('Invalid tour suite path')
    suites = {}
    tests = {}
    outcomes = {}
    complete = False
    size = 0
    for line in iter(lambda: stream.readline(MAX_LINE_BYTES + 1), b''):
        size += len(line)
        if len(line) > MAX_LINE_BYTES or size > MAX_REPORT_BYTES:
            raise ValueError('Dart report exceeded its byte limit')
        if not line.strip():
            continue
        event = json.loads(line)
        if complete or type(event) is not dict:
            raise ValueError('Invalid Dart report event')
        kind = event.get('type')
        if kind == 'suite':
            suite = event['suite']
            suite_id, path = suite['id'], suite.get('path')
            if type(suite_id) is not int or suite_id in suites:
                raise ValueError('Invalid or duplicate suite')
            absolute = _path(path)
            if absolute is None and type(path) is str:
                relative = path.replace('\\', '/')
                absolute = _path(posixpath.normpath(posixpath.join(root, relative)))
            suites[suite_id] = absolute
        elif kind == 'testStart':
            test = event['test']
            test_id, suite_id = test['id'], test['suiteID']
            if type(test_id) is not int or type(suite_id) is not int or test_id in tests:
                raise ValueError('Invalid or duplicate test')
            tests[test_id] = suite_id
        elif kind == 'testDone':
            test_id = event['testID']
            hidden, skipped = event.get('hidden', False), event.get('skipped', False)
            if (type(test_id) is not int or test_id not in tests or test_id in outcomes
                    or type(hidden) is not bool or type(skipped) is not bool):
                raise ValueError('Invalid or duplicate test result')
            outcomes[test_id] = event['result'] == 'success' and not hidden and not skipped
        elif kind == 'done':
            if event.get('success') is not True:
                raise ValueError('Dart did not report successful completion')
            complete = True

    selected = [path for path in suites.values() if path in expected]
    if not complete or len(selected) != len(expected) or set(selected) != expected:
        raise ValueError('Missing or repeated tour suites in the Dart report')
    if tests.keys() != outcomes.keys() or any(suite_id not in suites for suite_id in tests.values()):
        raise ValueError('Dart report contains unfinished or unbound tests')
    return sum(outcomes[test_id] for test_id, suite_id in tests.items()
               if suites[suite_id] in expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    try:
        with args.report.open('rb') as stream:
            passed = selected_passes(stream, repo=Path.cwd(), paths=TOUR_TEST_PATHS)
    except (KeyError, OSError, RecursionError, TypeError, ValueError):
        print('The Linux Dart report could not verify the Windows tour case count.')
        return 1
    print(f'Windows tour suites passed {passed} cases on Linux '
          f'across {len(TOUR_TEST_PATHS)} files. Expected {EXPECTED_DART_CASES}.')
    return int(passed != EXPECTED_DART_CASES)


if __name__ == '__main__':
    raise SystemExit(main())
