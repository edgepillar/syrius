"""Finite CI test facts without tracebacks, private paths or exception text."""

import io
import json
from pathlib import Path
import re
import unittest


def load_suite():
    # CPython can include a regular stdlib `test` package.
    # Discover these files directly instead of importing a colliding namespace.
    directory = str(Path(__file__).absolute().parents[2] / 'test' / 'ci')
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()
    for pattern in ('test_flutter_debug_protocol.py', 'test_windows_debug_loop.py'):
        suite.addTests(loader.discover(directory, pattern=pattern))
    return suite


def execute_suite(suite, *, scope='debug_controller_inmemory_cases',
                  title='Windows debug controller tests'):
    result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
    names = []
    for case, _ in result.failures + result.errors:
        identifier = case.id()
        names.append(identifier if re.fullmatch(r'[A-Za-z0-9_.]{1,180}', identifier)
                     else 'UNCLASSIFIED_CASE')
    value = dict(scope=scope, tests=result.testsRun,
                 failures=len(result.failures), errors=len(result.errors),
                 skips=len(result.skipped), failed_cases=names[:8],
                 success=result.wasSuccessful(), native_executions=0)
    public = json.dumps(value, sort_keys=True, separators=(',', ':'))
    print(public)
    if len(public.encode()) <= 3800:
        print('::notice title=' + title + '::' + public)
    return 0 if value['success'] else 1


def main():
    return execute_suite(load_suite())


if __name__ == '__main__':
    raise SystemExit(main())
