"""Retain three original lock states from each owned Windows profile."""

import json
import os
from pathlib import Path
import sys

from . import windows_launch_catalog as launch


entry, bounded, startup = launch.entry, launch.bounded, launch.startup
need, sha = launch.need, launch.sha
SCREEN = 'lock-catalog'
SCOPE = 'original_lock_catalog'
JOB_STEP = 'Capture the original lock states in both themes'
ARTIFACT_PREFIX = 'windows-lock-catalog-'
OUTPUT = Path('.harness/ci-lock-catalog')
CAPTURE_SOURCE = Path('harness/app/native_lock_catalog.dart')
SCREENS = ('lock-screen', 'lock-wrong', 'lock-pick')
FILES = tuple(f'{index:02}-{screen}-{theme}.png' for theme in launch.THEMES
              for index, screen in enumerate(SCREENS, 41))
STATE_FIELDS = {'screen', 'frame', 'frames', 'failures', 'remaining', 'picker_gates', 'masked_chars'}
MAX_ARCHIVE = len(FILES) * launch.MAX_PNG + launch.MAX_MANIFEST + 65536
SAMPLE = 'screen-state'
REFUSED_SAMPLE = 'redesign-qualification-wrong-password'
PHASES = ('prepare', 'ready', 'bind', 'input', 'normal', 'picker', 'refusal', 'complete')


def frame_matches(value, screen):
    expected = {
        'lock-screen': (55, 0, 3, 0, len(SAMPLE)),
        'lock-wrong': (23, 1, 2, 0, 0),
        'lock-pick': (55, 0, 3, 4, 0),
    }
    fields = ('frame', 'failures', 'remaining', 'picker_gates', 'masked_chars')
    return (screen in expected and value['screen'] == screen
            and type(value['frames']) is int and value['frames'] == 56
            and all(type(value[field]) is int for field in fields)
            and tuple(value[field] for field in fields) == expected[screen])


class LockProcess(launch.LaunchProcess):
    profile_screen = SCREEN

    def run_launch(self, theme, *, capture, settle):
        self.phase = 'ready' if capture else 'prepare'
        receipt, result = super().run_launch(theme, capture=capture, settle=settle)
        return dict(receipt, phase=self.phase), result

    def _catalog(self, action, *, until=None):
        return self._rpc(dict(cmd='lock-catalog', action=action), until=until)

    def _wait_catalog(self, action, seconds):
        until = min(self.deadline, self.clock() + seconds)
        while self.clock() < until:
            body = self._catalog(action, until=until)
            if body != {'ok': True, 'status': 'pending'}:
                return body
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        raise startup.Failure('STARTUP_DEADLINE')

    def _lock_owner(self, action):
        body = self._rpc(dict(cmd='lock-view', action=action))
        need(body.get('status') == 'observed' and body.get('owner_same') is True
             and type(body.get('view')) is dict)
        return body['view']

    @staticmethod
    def _input_ready(view, failures):
        true = ('mounted', 'current', 'window_active', 'visible', 'route_current',
                'focus_allows_input', 'startup_interactive')
        false = ('busy', 'opening', 'attempt_storage_failed', 'has_error_message')
        return (all(view.get(key) is True for key in true)
             and all(view.get(key) is False for key in false)
             and view.get('lifecycle') in ('resumed', 'unknown')
             and view.get('incorrect_password') is (failures == 1)
             and startup.integer(view.get('password_failures'), failures, failures)
             and startup.integer(view.get('unlock_requests'), failures, failures)
             and view.get('unlock_phase') == ('password_exception' if failures else 'idle'))

    def _bind_input(self):
        self.phase = 'bind'
        view = self._lock_owner('bind')
        self.phase = 'input'
        if view.get('window_active') is not True or view.get('lifecycle') != 'resumed':
            window = entry.EntrySmoke._window(self, self._rpc(dict(cmd='window', do='show')))
            need(not window['minimized'] and not window['maximized']
                 and all(abs(a - b) < .01 for a, b in zip(window['client'], (1280, 780))),
                 'WINDOW_INVALID')
        until = min(self.deadline, self.clock() + 12)
        while self.clock() < until:
            if self._input_ready(self._lock_owner('observe'), 0):
                return
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        raise startup.Failure('ENTRY_INVALID')

    def _lock_view(self, failures):
        need(self._input_ready(self._lock_owner('observe'), failures), 'ENTRY_INVALID')

    def _type_sample(self, value):
        body = self._rpc(dict(cmd='type', key='wallet_password_field', value=value, settleMs=0))
        need(body.get('value') == '\u2022' * len(value))

    def _status(self, theme, picker, *, wait=False):
        until = min(self.deadline, self.clock() + 40)
        expected = dict(ok=True, status='ready', theme=theme, frame=55, frames=56,
                        failures=0, remaining=3, picker=picker, gates=4 if picker else 0)
        while self.clock() < until:
            value = self._catalog('status', until=until)
            if value == expected:
                return value
            need(wait and (value == {'ok': True, 'status': 'pending'} or
                (set(value) == set(expected) and
                 all(value[k] == expected[k] for k in expected if k not in ('frame', 'gates')) and
                 startup.integer(value['frame'], 0, 55) and
                 startup.integer(value['gates'], 0, expected['gates']))), 'ENTRY_INVALID')
            self.sleep(min(self.limits.poll, max(0, until - self.clock())))
        raise startup.Failure('STARTUP_DEADLINE')

    def _still(self, theme, screen, *, masked, picker):
        self._status(theme, picker, wait=True)
        self._lock_view(0)
        body = self._rpc(dict(cmd='shot', width=1280, height=780, theme=theme,
                              expect=dict(key='wallet_unlock_button')))
        need(body.get('asserted') is True and body.get('theme') == theme
             and body.get('width') == 1280 and body.get('height') == 780)
        status = self._status(theme, picker)
        self._lock_view(0)
        state = dict(screen=screen, frame=status['frame'], frames=status['frames'],
            failures=status['failures'], remaining=status['remaining'],
            picker_gates=status['gates'], masked_chars=masked)
        return self._pixels(body, state)

    def _pixels(self, body, state):
        need(frame_matches(state, state['screen']))
        png = entry.png_bytes(body.get('png'))
        need(0 < len(png) <= launch.MAX_PNG)
        return png, state

    def _accept(self, action):
        need(self._catalog(action) == {'ok': True, 'status': 'accepted'})

    def _observe_pixels(self, theme, *, settle):
        need(settle)
        self._status(theme, False, wait=True)
        self._bind_input()
        self.phase = 'normal'
        self._type_sample(SAMPLE)
        normal = self._still(theme, 'lock-screen', masked=len(SAMPLE), picker=False)
        self.phase = 'picker'
        self._type_sample('')
        self._accept('open-picker')
        picker = self._still(theme, 'lock-pick', masked=0, picker=True)
        self._accept('close-picker')
        self._status(theme, False, wait=True)
        self.phase = 'refusal'
        self._type_sample(REFUSED_SAMPLE)
        self._accept('arm-wrong')
        # One actual refusal in this owned profile. An uncertain reply ends the attempt.
        self._rpc(dict(cmd='tap', key='wallet_unlock_button', settleMs=0))
        body = self._wait_catalog('wrong-frame', 27)
        need(set(body) == {'ok', 'status', 'theme', 'frame', 'frames', 'failures', 'remaining', 'png'}
             and body['status'] == 'captured' and body['theme'] == theme)
        self._lock_view(1)
        state = dict(screen='lock-wrong', frame=body['frame'], frames=body['frames'],
            failures=body['failures'], remaining=body['remaining'], picker_gates=0, masked_chars=0)
        wrong = self._pixels(body, state)
        self.phase = 'complete'
        return normal, wrong, picker


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
             and parent.get('SYRIUS_WINDOWS_LOCK_CATALOG') == 'true', 'ENVIRONMENT_REFUSED')
        repo = Path(parent['GITHUB_WORKSPACE'])
        bounded.plain(repo)
        need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        bounded.verify_source(repo, head, parent)
        tree = entry.source_tree(repo, parent)
        binaries = tuple(bounded.binary_hash(repo, path) for path in (startup.BINARY, startup.PAYLOAD))
        report.update(source_sha=head, source_tree=tree, run_id=parent['GITHUB_RUN_ID'], run_attempt='1',
            runner_sha256=binaries[0][1], payload_sha256=binaries[1][1],
            capture_source_sha256=sha((repo / CAPTURE_SOURCE).read_bytes()),
            profile_sha256=sha((repo / launch.SETTLE_PROFILE_SOURCE).read_bytes()))
        entry.private_root(repo)
        target = repo / OUTPUT
        target.mkdir(mode=0o700)
        output = target
        for index, theme in enumerate(launch.THEMES):
            profile = entry.new_profile(repo)
            identity = bounded.plain(profile)
            prepared, _ = launch.run_process(repo, parent, binaries, profile, theme,
                capture=False, settle=True, process_type=LockProcess)
            report['attempts'].append(prepared)
            need(launch.attempt_passed(prepared))
            current = bounded.plain(profile)
            need((current.st_dev, current.st_ino) == (identity.st_dev, identity.st_ino), 'PROFILE_REFUSED')
            captured, result = launch.run_process(repo, parent, binaries, profile, theme,
                capture=True, settle=True, process_type=LockProcess)
            report['attempts'].append(captured)
            need(result is not None and len(result) == len(SCREENS))
            for offset, (png, state) in enumerate(result):
                name = FILES[index * len(SCREENS) + offset]
                with (output / name).open('xb') as stream:
                    stream.write(png)
                report['captures'].append(dict(theme=theme, file=name, bytes=len(png), sha256=sha(png), **state))
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
    print('::notice title=Original lock catalog::' + json.dumps(report, separators=(',', ':')))
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
