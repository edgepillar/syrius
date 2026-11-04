"""Exercise the actual down script with a regular-file Docker command fixture."""
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
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
elif args[:1] == ['build']:
    if os.environ.get('FIXTURE_FAIL') == 'build':
        sys.exit(17)
elif args[:2] == ['image', 'inspect'] or args in (['compose', 'up', '-d'], ['compose', 'ps', '-a']):
    pass
else:
    sys.exit(99)
'''


@unittest.skipUnless(ENABLED, 'Explicit Linux shell fixture is not selected')
class LabShutdownTests(unittest.TestCase):
    def invoke(self, identifiers=IDS, failure='', recipe='upstream', revision='590f43c'):
        # No sockets, links, FIFOs, node, wallet or Docker daemon are involved.
        with tempfile.TemporaryDirectory(prefix='lab-stop-fixture-') as directory:
            root = Path(directory)
            script = root / 'lab.sh'
            script.write_bytes((REPO / 'tools/devnet/lab/lab.sh').read_bytes())
            (root / '.build').mkdir()
            (root / '.build/revision').write_text(revision + '\n')
            binary = root / 'docker'
            binary.write_text('#!' + sys.executable + '\n' + DOCKER)
            binary.chmod(0o700)
            trace = root / 'trace.jsonl'
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                FIXTURE_TRACE=str(trace), FIXTURE_IDS='\n'.join(identifiers),
                FIXTURE_FAIL=failure, LAB_BUILD_RECIPE=recipe)
            if recipe is None:
                env.pop('LAB_BUILD_RECIPE')
            result = subprocess.run([BASH, str(script), 'down'], env=env,
                capture_output=True, timeout=5, check=False)
            calls = [json.loads(line) for line in trace.read_text().splitlines()] if trace.exists() else []
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

    def test_reference_uses_one_twenty_second_stop_before_removal(self):
        result, calls = self.invoke(recipe='reference', revision='0e80915-reference')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'],
            ['stop', '--timeout', '20', *IDS], ['compose', 'down']])

    def test_unknown_recipe_or_mismatched_tag_starts_no_docker_command(self):
        for recipe, revision in (('other', '590f43c'),
                ('reference', '0e80915'), ('upstream', '0e80915-reference'),
                ('upstream', '--invalid')):
            with self.subTest(recipe=recipe, revision=revision):
                result, calls = self.invoke(recipe=recipe, revision=revision)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    def build(self, recipe, failure=''):
        with tempfile.TemporaryDirectory(prefix='lab-build-fixture-') as directory:
            root = Path(directory)
            script = root / 'lab.sh'
            script.write_bytes((REPO / 'tools/devnet/lab/lab.sh').read_bytes())
            (root / 'Dockerfile.reference').write_bytes(
                (REPO / 'tools/devnet/lab/Dockerfile.reference').read_bytes())
            (root / '.build/go-zenon').mkdir(parents=True)
            archive = root / 'source.tar'
            with tarfile.open(archive, 'w') as stream:
                entry = tarfile.TarInfo('fixture.txt');entry.size = 7
                stream.addfile(entry, io.BytesIO(b'fixture'))
            git = root / 'git'
            git.write_text('#!' + sys.executable + '\n' + '''import os, sys
import json
from pathlib import Path
args = sys.argv[1:]
with Path(os.environ['FIXTURE_GIT_TRACE']).open('a') as out:
    out.write(json.dumps(args) + '\\n')
if 'cat-file' in args:
    sys.exit(7 if os.environ.get('FIXTURE_NEED_FETCH') == 'true' else 0)
if 'init' in args:
    Path(args[-1]).mkdir(parents=True, exist_ok=True)
elif 'fetch' in args:
    sys.exit(0)
elif 'rev-parse' in args:
    print('0e80915')
elif 'archive' in args:
    sys.stdout.buffer.write(Path(os.environ['FIXTURE_ARCHIVE']).read_bytes())
else:
    sys.exit(99)
''')
            git.chmod(0o700)
            docker = root / 'docker'
            docker.write_text('#!' + sys.executable + '\n' + DOCKER)
            docker.chmod(0o700)
            trace = root / 'trace.jsonl'
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                LAB_BUILD_RECIPE=recipe, FIXTURE_TRACE=str(trace),
                FIXTURE_FAIL=failure, FIXTURE_ARCHIVE=str(archive),
                FIXTURE_GIT_TRACE=str(root / 'git-trace.jsonl'),
                FIXTURE_NEED_FETCH='true' if recipe is None else 'false')
            if recipe is None:
                for name in ('LAB_BUILD_RECIPE', 'GO_ZENON_URL', 'GO_ZENON_REV'):
                    env.pop(name, None)
            result = subprocess.run([BASH, str(script), 'build'], env=env,
                capture_output=True, timeout=5, check=False)
            calls = [json.loads(line) for line in trace.read_text().splitlines()]
            stamp = root / '.build/revision'
            revision = stamp.read_text() if stamp.exists() else None
            self.assertEqual((root / '.build/src/fixture.txt').read_bytes(), b'fixture')
            if recipe is None:
                git_calls = [json.loads(line) for line in
                    (root / 'git-trace.jsonl').read_text().splitlines()]
                fetch = [args for args in git_calls if 'fetch' in args]
                self.assertEqual(len(fetch), 1)
                self.assertEqual(fetch[0][-2:], ['https://github.com/zenon-network/go-zenon.git',
                    '0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b'])
            return result, calls, revision, root

    def test_actual_build_selects_recipe_and_distinct_image_tag(self):
        for recipe in ('upstream', 'reference'):
            with self.subTest(recipe=recipe):
                result, calls, revision, root = self.build(recipe)
                suffix = '-reference' if recipe == 'reference' else ''
                self.assertEqual(result.returncode, 0)
                self.assertEqual(revision, '0e80915' + suffix + '\n')
                flags = ['-f', str(root / 'Dockerfile.reference')] if suffix else []
                self.assertEqual(calls, [['build', *flags, '-t',
                    'syrius-lab-znnd:0e80915' + suffix, str(root / '.build/src')]])

    def test_failed_build_does_not_publish_revision_or_retry(self):
        result, calls, revision, _ = self.build('reference', failure='build')
        self.assertEqual(result.returncode, 17)
        self.assertIsNone(revision)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0], 'build')

    def test_default_build_fetches_fixed_source_and_selects_reference_recipe(self):
        result, calls, revision, root = self.build(None)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(revision, '0e80915-reference\n')
        self.assertEqual(calls, [['build', '-f', str(root / 'Dockerfile.reference'),
            '-t', 'syrius-lab-znnd:0e80915-reference', str(root / '.build/src')]])

    def test_default_down_uses_the_reference_stop_grace(self):
        result, calls = self.invoke(recipe=None, revision='0e80915-reference')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(calls, [['compose', 'ps', '-a', '-q'],
            ['stop', '--timeout', '20', *IDS], ['compose', 'down']])

    def test_up_requests_two_advances_and_status_retains_thirty_seconds(self):
        with tempfile.TemporaryDirectory(prefix='lab-readiness-fixture-') as directory:
            root = Path(directory);script = root / 'lab.sh'
            script.write_bytes((REPO / 'tools/devnet/lab/lab.sh').read_bytes())
            (root / '.build').mkdir();(root / '.build/revision').write_text('590f43c\n')
            (root / 'assets').mkdir();(root / 'assets/genesis.json').write_text('{}')
            trace = root / 'trace.jsonl'
            docker = root / 'docker';docker.write_text('#!' + sys.executable + '\n' + DOCKER);docker.chmod(0o700)
            node = root / 'node'
            node.write_text('#!' + sys.executable + '\n' + '''import json, os, sys
from pathlib import Path
with Path(os.environ['FIXTURE_TRACE']).open('a') as out:
    out.write(json.dumps(['node', *sys.argv[1:]]) + '\\n')
''');node.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                FIXTURE_TRACE=str(trace), LAB_BUILD_RECIPE='upstream')
            for action in ('up', 'status'):
                result = subprocess.run([BASH, str(script), action], env=env,
                    capture_output=True, timeout=5, check=False)
                self.assertEqual(result.returncode, 0)
            calls = [json.loads(line) for line in trace.read_text().splitlines()]
            self.assertEqual(calls, [['image', 'inspect', 'syrius-lab-znnd:590f43c'],
                ['compose', 'up', '-d'], ['node', str(root / 'frontier.js'),
                    '180', '--wait', '90', '--advances', '2'],
                ['compose', 'ps', '-a'], ['node', str(root / 'frontier.js'), '30']])


if __name__ == '__main__':
    unittest.main()
