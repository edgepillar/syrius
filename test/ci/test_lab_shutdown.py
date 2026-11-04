"""Exercise the actual down script with a regular-file Docker command fixture."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).absolute().parents[2]
BASH = shutil.which('bash')
ENABLED = (sys.platform == 'linux' and BASH is not None
    and os.environ.get('SYRIUS_LAB_SHELL_FIXTURE') == 'true')
IDS = [character * 64 for character in 'abcde']
DOCKER = '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
if args[:1] == ['compose']:
    args = ['compose', *args[3:]]
with Path(os.environ['FIXTURE_TRACE']).open('a') as out:
    out.write(json.dumps(args) + '\\n')
if args == ['compose', 'ps', '-a', '-q']:
    if os.environ.get('FIXTURE_FAIL') == 'list':
        sys.exit(7)
    print(os.environ['FIXTURE_IDS'])
elif args[:1] == ['stop']:
    if os.environ.get('FIXTURE_FAIL') == 'stop':
        sys.exit(8)
elif args == ['compose', 'down']:
    if os.environ.get('FIXTURE_FAIL') == 'down':
        sys.exit(9)
else:
    sys.exit(99)
'''


@unittest.skipUnless(ENABLED, 'Explicit Linux shell fixture is not selected')
class LabShutdownTests(unittest.TestCase):
    def invoke(self, identifiers=IDS, failure=''):
        # No sockets, links, FIFOs, node, wallet or Docker daemon are involved.
        with tempfile.TemporaryDirectory(prefix='lab-stop-fixture-') as directory:
            root = Path(directory)
            script = root / 'lab.sh'
            script.write_bytes((REPO / 'tools/devnet/lab/lab.sh').read_bytes())
            (root / '.build').mkdir()
            (root / '.build/revision').write_text('590f43c\n')
            binary = root / 'docker'
            binary.write_text('#!' + sys.executable + '\n' + DOCKER)
            binary.chmod(0o700)
            trace = root / 'trace.jsonl'
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                FIXTURE_TRACE=str(trace), FIXTURE_IDS='\n'.join(identifiers),
                FIXTURE_FAIL=failure)
            result = subprocess.run([BASH, str(script), 'down'], env=env,
                capture_output=True, timeout=5, check=False)
            calls = [json.loads(line) for line in trace.read_text().splitlines()]
            return result, calls

    def test_all_originals_share_one_stop_before_project_removal(self):
        result, calls = self.invoke()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'],
            ['stop', '--timeout', '10', *IDS], ['compose', 'down']])

    def test_listing_failure_does_not_stop_or_remove(self):
        result, calls = self.invoke(failure='list')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q']])

    def test_bad_duplicate_or_excess_ids_refuse_before_mutation(self):
        for identifiers in (['--invalid'], ['a' * 63],
                [IDS[0], IDS[0]], [*IDS, 'f' * 64]):
            with self.subTest(identifiers=identifiers):
                result, calls = self.invoke(identifiers)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [['compose', 'ps', '-a', '-q']])

    def test_stop_failure_retains_project_and_does_not_retry(self):
        result, calls = self.invoke(failure='stop')
        self.assertEqual(result.returncode, 8)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'],
            ['stop', '--timeout', '10', *IDS]])

    def test_empty_project_has_no_stop_and_preserves_volumes(self):
        result, calls = self.invoke([])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'], ['compose', 'down']])

    def test_removal_failure_is_retained_without_second_stop(self):
        result, calls = self.invoke(failure='down')
        self.assertEqual(result.returncode, 9)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'],
            ['stop', '--timeout', '10', *IDS], ['compose', 'down']])


if __name__ == '__main__':
    unittest.main()
