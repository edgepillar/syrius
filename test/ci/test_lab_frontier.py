"""Run the actual frontier script with an inert HTTP adapter and fake clock in CI."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest


REPO = Path(__file__).absolute().parents[2]
ENABLED = (sys.platform == 'linux'
    and os.environ.get('SYRIUS_LAB_SHELL_FIXTURE') == 'true')
NODE = shutil.which('node')
FIXTURE = r'''
const fs = require('node:fs');
const vm = require('node:vm');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
let now = 0, requests = 0;
const exits = [], stdout = [], stderr = [];
class Exit extends Error {}
const http = {request(url, options, callback) {
  if (url !== 'http://127.0.0.1:45997' || options.method !== 'POST' || options.timeout !== 5000) {
    throw new Error('unexpected fixture request');
  }
  const handlers = {};
  return {
    on(name, handler) {handlers[name] = handler; return this;},
    destroy(error) {handlers.error(error);},
    end(body) {
      if (JSON.parse(body).method !== 'ledger.getFrontierMomentum' || ++requests > 200) {
        throw new Error('unexpected fixture method or count');
      }
      if (requests <= (input.failures || 0)) {
        handlers.error(new Error('fixture unavailable'));
        return;
      }
      const heights = input.heights || [2];
      const value = heights[Math.min(requests - 1 - (input.failures || 0), heights.length - 1)];
      const reply = JSON.stringify({result: {height: value,
        chainIdentifier: input.chain === undefined ? 321 : input.chain}});
      callback({on(name, handler) {
        if (name === 'data') handler(reply);
        if (name === 'end') handler();
      }});
    }
  };
}};
const context = {
  require(name) {if (name !== 'node:http') throw new Error('unexpected module'); return http;},
  process: {argv: ['node', 'frontier.js', ...input.args], env: {},
    exit(code) {exits.push(code); if (code === 2) throw new Exit();}},
  console: {log(value) {stdout.push(String(value));}, error(value) {stderr.push(String(value));}},
  Date: {now() {return now;}},
  setTimeout(callback, delay) {now += delay; queueMicrotask(callback);}
};
(async () => {
  try {await vm.runInNewContext(input.source, context, {timeout: 1000});}
  catch (error) {if (!(error instanceof Exit)) throw error;}
  process.stdout.write(JSON.stringify({exits, stdout, stderr, requests, seconds: now / 1000}));
})().catch(() => {process.stderr.write('frontier fixture failed'); process.exitCode = 1;});
'''


@unittest.skipUnless(ENABLED, 'Explicit Linux script fixture is not selected')
class LabFrontierTests(unittest.TestCase):
    def invoke(self, args, **settings):
        self.assertIsNotNone(NODE, 'The hosted script fixture requires Node')
        value = dict(source=(REPO / 'tools/devnet/lab/frontier.js').read_text(),
            args=args, **settings)
        result = subprocess.run([NODE, '-e', FIXTURE], input=json.dumps(value),
            text=True, capture_output=True, timeout=5, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertLess(len(result.stdout), 8192)
        return json.loads(result.stdout)

    def test_startup_waits_for_two_advances_without_extending_either_window(self):
        value = self.invoke(['180', '--wait', '90', '--advances', '2'],
            heights=[1, 1, 2, 2, 3])
        self.assertEqual(value, dict(exits=[0], stdout=[
            'chain 321: 1 then 3 after 20 s', 'producing'], stderr=[], requests=5, seconds=20))
        value = self.invoke(['15', '--advances', '2'], heights=[1, 2])
        self.assertEqual(value['exits'], [1])
        self.assertEqual(value['stdout'], ['chain 321: 1 then 2 after 15 s', 'NOT producing'])
        self.assertEqual(value['seconds'], 15)
        value = self.invoke(['30'], heights=[2, 2, 3])
        self.assertEqual(value['exits'], [0]);self.assertEqual(value['seconds'], 10)
        value = self.invoke(['30'], heights=[2])
        self.assertEqual(value['exits'], [1]);self.assertEqual(value['seconds'], 30)
        value = self.invoke(['180', '--wait', '9', '--advances', '2'],
            heights=[1, 2, 3], failures=2)
        self.assertEqual(value['exits'], [0]);self.assertEqual(value['seconds'], 16)

    def test_bad_options_and_invalid_or_regressing_frontiers_do_not_pass(self):
        for args in (['30', '--advances', '0'], ['30', '--advances', 'NaN'],
                ['30', '--advances', '1.5'], ['30', '--advances'],
                ['30', '--advances', '2', '--advances', '3'],
                ['30', '--wait', '-1'], ['--unknown']):
            with self.subTest(args=args):
                value = self.invoke(args)
                self.assertEqual(value['exits'], [2]);self.assertEqual(value['requests'], 0)
        for settings in (dict(chain=69), dict(heights=['2']), dict(heights=[-1]),
                dict(heights=[2.5]), dict(heights=[2**53])):
            with self.subTest(settings=settings):
                value = self.invoke(['30'], **settings)
                self.assertEqual(value['exits'], [1]);self.assertEqual(value['requests'], 1)
        value = self.invoke(['30'], heights=[2, 1])
        self.assertEqual(value['exits'], [1]);self.assertEqual(value['seconds'], 5)


if __name__ == '__main__':
    unittest.main()
