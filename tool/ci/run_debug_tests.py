"""Finite CI test facts without tracebacks, private paths or exception text."""

import io
import json
import re
import unittest


def main():
    suite = unittest.defaultTestLoader.loadTestsFromNames([
        'test.ci.test_flutter_debug_protocol', 'test.ci.test_windows_debug_loop'])
    result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
    names = []
    for case, _ in result.failures + result.errors:
        identifier = case.id()
        names.append(identifier if re.fullmatch(r'[A-Za-z0-9_.]{1,180}', identifier)
                     else 'UNCLASSIFIED_CASE')
    value = dict(scope='debug_controller_inmemory_cases', tests=result.testsRun,
                 failures=len(result.failures), errors=len(result.errors),
                 skips=len(result.skipped), failed_cases=names[:8],
                 success=result.wasSuccessful(), native_executions=0)
    public = json.dumps(value, sort_keys=True, separators=(',', ':'))
    print(public)
    if len(public.encode()) <= 3800:
        print('::notice title=Windows debug controller tests::' + public)
    return 0 if value['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
