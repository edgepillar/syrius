"""Capture both synthetic quiz views in one ordinary Windows process."""

import json
import os
from pathlib import Path
import sys

from . import windows_launch_catalog as launch


entry, bounded, startup = launch.entry, launch.bounded, launch.startup
need, sha = launch.need, launch.sha
SCREEN = 'quiz-catalog'
SCOPE = 'original_seed_quiz_catalog'
JOB_STEP = 'Capture the synthetic seed quiz in both themes'
ARTIFACT_PREFIX = 'windows-quiz-catalog-'
OUTPUT = Path('.harness/ci-quiz-catalog')
PIN_SOURCES = {
    'capture_source_sha256': Path('harness/app/native_quiz_catalog.dart'),
    'fixture_source_sha256': Path('harness/app/fixtures/seed_quiz_fixture.dart'),
}
FILES = tuple(f'46-seed-quiz-{theme}.png' for theme in launch.THEMES)
MAX_ARCHIVE = len(FILES) * launch.MAX_PNG + launch.MAX_MANIFEST + 65536
STATE_FIELDS = {'correct', 'unlocked', 'questions', 'choices', 'complete',
                'artwork_seconds', 'native_before', 'native_after'}
PHASES = ('ready', 'welcome', 'open', 'route', 'selection', 'dark', 'light',
          'restore', 'complete')
REFUSALS = frozenset((
    'quiz-welcome-unavailable', 'quiz-profile-not-empty', 'quiz-owner-unavailable',
    'quiz-first-choice-unavailable', 'quiz-first-choice-changed',
    'quiz-frame-owner-changed', 'quiz-native-frame-refused', 'quiz-artwork-tree-limit',
    'quiz-artwork-owner-unavailable', 'quiz-artwork-frame-unavailable',
    'quiz-route-changed', 'quiz-fixture-unavailable', 'quiz-paint-unavailable',
    'quiz-restore-refused', 'quiz-artwork-restore-unproven',
    'quiz-welcome-restore-unproven', 'quiz-catalog-input-refused',
    'quiz-remote-refused', 'quiz-remote-error',
    'quiz-capture-tree-limit', 'quiz-capture-error-widget',
    'quiz-capture-target-unavailable', 'quiz-capture-source-unavailable',
    'quiz-capture-window-minimized', 'quiz-capture-source-changed',
    'original-renderer-unavailable', 'original-renderer-changed',
    'original-frame-unavailable', 'original-frame-color-space-unproven',
    'original-frame-encoding-unproven',
))


def quiz_state(value, correct):
    seconds = value['artwork_seconds']
    return (all(startup.integer(value[k], correct, correct)
                for k in ('correct', 'unlocked'))
            and startup.integer(value['questions'], 3, 3)
            and type(value['choices']) is list and len(value['choices']) == 3
            and all(startup.integer(count, 4, 4) for count in value['choices'])
            and value['complete'] is False
            and (startup.integer(seconds, 6, 6) if correct else seconds is None))


def frame_matches(value):
    return (quiz_state(value, 1)
            and startup.integer(value['native_before'], 2, 2**31 - 2)
            and startup.integer(value['native_after'], value['native_before'] + 1,
                                2**31 - 1))


class QuizProcess(launch.LaunchProcess):
    profile_screen = SCREEN

    def run_launch(self, theme, *, capture, settle):
        self.phase = 'ready'
        self.refusal = None
        receipt, result = super().run_launch(theme, capture=capture, settle=settle)
        return dict(receipt, phase=self.phase, refusal=self.refusal), result

    def _catalog(self, action, *, until=None):
        status, body = self._exchange(dict(cmd=SCREEN, action=action), until=until)
        if status == 200 and body['ok'] is True:
            return body
        error = body.get('error')
        if status == 400 and type(error) is str and error in REFUSALS:
            self.refusal = error
        else:
            self.refusal = 'quiz-remote-error' if status >= 500 else 'quiz-remote-refused'
        raise startup.Failure('COMMAND_FAILED')

    def _accept(self, action):
        need(self._catalog(action) == {'ok': True, 'status': 'accepted'}, 'ENTRY_INVALID')

    def _status(self, theme, correct, *, wait=False):
        fields = STATE_FIELDS - {'native_before', 'native_after'}
        until = min(self.deadline, self.clock() + 8)
        while self.clock() < until:
            body = self._catalog('status', until=until)
            if body == {'ok': True, 'status': 'pending'}:
                need(wait, 'ENTRY_INVALID')
            else:
                need(set(body) == fields | {'ok', 'status', 'theme', 'native_callback'}
                     and body['status'] == 'ready' and quiz_state(body, correct)
                     and startup.integer(body['native_callback'], 2, 2**31 - 1),
                     'ENTRY_INVALID')
                if body['theme'] == theme:
                    return body
                need(wait and body['theme'] is None, 'ENTRY_INVALID')
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        raise startup.Failure('STARTUP_DEADLINE')

    def _capture(self, theme):
        before = self._status(theme, 1, wait=True)
        body = self._catalog('capture-' + theme)
        need(set(body) == {'ok', 'status', 'theme', 'width', 'height', 'png'}
             and body['status'] == 'captured' and body['theme'] == theme
             and startup.integer(body['width'], 1280, 1280)
             and startup.integer(body['height'], 780, 780))
        after = self._status(theme, 1)
        state = {k: after[k] for k in STATE_FIELDS - {'native_before', 'native_after'}}
        state.update(native_before=before['native_callback'],
                     native_after=after['native_callback'])
        need(frame_matches(state), 'ENTRY_INVALID')
        pixels = entry.png_bytes(body.get('png'))
        need(0 < len(pixels) <= launch.MAX_PNG)
        return pixels, state

    def _observe_pixels(self, theme, *, settle):
        need(theme == 'dark' and settle)
        self.phase = 'welcome'
        until = min(self.deadline, self.clock() + startup.STARTUP_SECONDS)
        while not self._entry_ready(until):
            need(self.clock() < until, 'STARTUP_DEADLINE')
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        self._show()
        original = self._rpc(dict(cmd='theme'))
        theme_keys = {'mode', 'savedMode', 'brightness'}
        need(set(original) == theme_keys | {'ok'}, 'ENTRY_INVALID')
        original = {key: original[key] for key in theme_keys}
        self.phase = 'open'
        self._accept('open')
        self.phase = 'route'
        self._status('dark', 0, wait=True)
        self.phase = 'selection'
        self._accept('select-first')
        self.phase = 'dark'
        dark = self._capture('dark')
        self.phase = 'light'
        changed = self._rpc(dict(cmd='theme', mode='light'))
        need(changed == dict(ok=True, mode='light', brightness='light',
                             savedMode='ThemeMode.light'), 'ENTRY_INVALID')
        light = self._capture('light')
        need(light[1]['native_before'] > dark[1]['native_after']
             and dark[0] != light[0], 'ENTRY_INVALID')
        self.phase = 'restore'
        self._accept('close')
        need(self._rpc(dict(cmd='theme', restore=original)) == dict(ok=True, **original),
             'ENTRY_INVALID')
        self._restore()
        need(self._entry_ready(self.deadline), 'ENTRY_INVALID')
        self.phase = 'complete'
        return dark, light


def main():
    report = dict(schema=1, scope=SCOPE, success=False, attempts=[], captures=[],
                  source_stable=False, error_codes=[])
    output = None
    try:
        need(not sys.argv[1:], 'ARGUMENTS_REFUSED')
        parent, head = entry.require_ci(os.environ, None, platform=os.name)
        need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
             and parent.get('GITHUB_RUN_ATTEMPT') == '1'
             and parent.get('SYRIUS_WINDOWS_STARTUP_PROBE') == 'true'
             and parent.get('SYRIUS_WINDOWS_QUIZ_CATALOG') == 'true', 'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        bounded.plain(repo)
        need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        bounded.verify_source(repo, head, parent)
        tree = entry.source_tree(repo, parent)
        binaries = tuple(bounded.binary_hash(repo, path) for path in (startup.BINARY, startup.PAYLOAD))
        report.update(source_sha=head, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
            run_attempt='1', runner_sha256=binaries[0][1], payload_sha256=binaries[1][1],
            **{key: sha((repo / path).read_bytes()) for key, path in PIN_SOURCES.items()})
        profile = entry.new_profile(repo)
        target = repo / OUTPUT
        target.mkdir(mode=0o700)
        output = target
        identity = bounded.plain(profile)
        attempt, result = launch.run_process(repo, parent, binaries, profile, 'dark',
            capture=True, settle=True, process_type=QuizProcess)
        report['attempts'].append(attempt)
        need(result is not None and len(result) == len(FILES))
        current = bounded.plain(profile)
        need((current.st_dev, current.st_ino) == (identity.st_dev, identity.st_ino), 'PROFILE_REFUSED')
        for theme, name, (pixels, state) in zip(launch.THEMES, FILES, result):
            with (output / name).open('xb') as stream:
                stream.write(pixels)
            report['captures'].append(dict(theme=theme, file=name, bytes=len(pixels),
                                           sha256=sha(pixels), **state))
        bounded.verify_source(repo, head, parent)
        need(entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        need(tuple(bounded.binary_hash(repo, path) for path in (startup.BINARY, startup.PAYLOAD)) == binaries,
             'BINARY_REFUSED')
        report.update(source_stable=True, success=True)
    except bounded.SmokeFailure as error:
        report['error_codes'].append(error.code)
    except (Exception, KeyboardInterrupt):
        report['error_codes'].append('INTERNAL_ERROR')
    if output is not None:
        try:
            manifest = (json.dumps(report, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')
            need(len(manifest) <= launch.MAX_MANIFEST, 'ARTIFACT_FAILED')
            with (output / 'manifest.json').open('xb') as stream:
                stream.write(manifest)
        except (Exception, KeyboardInterrupt):
            report['success'] = False
            report['error_codes'].append('ARTIFACT_FAILED')
    print('::notice title=Original seed quiz catalog::' + json.dumps(report, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
