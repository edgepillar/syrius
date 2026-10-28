"""Original-process protocol controls; no files, SDK, network or native app."""

import json
import threading
import unittest

from tool.ci import windows_startup_probe as probe


def progress():
    return dict(frames=56, shown=0, decoding=12, stage='frame', skip=True,
                pending=False, ticking=True, done=False)


def sample(**changes):
    result = dict(at_ms=1000, phase='startup-before-initialization',
                  film='skip-middle-frame-pending', progress=progress())
    result.update(changes)
    return result


def positive_report():
    report = probe.Report()
    report.source_sha, report.source_tree = 'a' * 40, 'b' * 40
    report.run_id, report.run_attempt = '9', '1'
    report.runner_sha256, report.payload_sha256 = 'c' * 64, 'd' * 64
    report.checks = dict.fromkeys(probe.CHECKS, True)
    report.handoff, report.key_attempts = 'key-confirmed', 1
    report.exit_observed, report.exit_code = True, 0
    report.output_complete = True
    report.samples = [sample()]
    return report


class Clock:
    def __init__(self):
        self.now = 0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class Process:
    pid = 17

    def __init__(self):
        self.code = None
        self.kills = 0

    def poll(self):
        return self.code

    def wait(self, timeout):
        if self.code is None:
            raise probe.subprocess.TimeoutExpired('owned-fixture', timeout)
        return self.code

    def kill(self):
        self.kills += 1
        self.code = 9


class Drain:
    error = None
    overflow = threading.Event()

    def finish(self, timeout):
        return True


class Session(probe.StartupProbe):
    def __init__(self, *, ready_after=2, refuse_key=False, natural=False):
        self.timer, self.commands = Clock(), []
        self.reads, self.ready_after = 0, ready_after
        self.refuse_key, self.natural = refuse_key, natural
        report = positive_report()
        report.samples, report.handoff, report.key_attempts = [], None, 0
        report.checks['startup_ready'] = False
        super().__init__(Process(), None, 'private-token', Drain(), report,
                         limits=probe.LIMITS, clock=self.timer, sleep=self.timer.sleep)

    def _rpc(self, command, *, until=None, allow_exit=False):
        self.commands.append(dict(command))
        if command['cmd'] == 'entry-state':
            ready = self.reads >= self.ready_after
            return dict(ok=True, available=True, held=False, captures=0,
                        nativeWindowReady=True, startupReady=ready, welcomeReady=ready)
        if command.get('action') == 'observe':
            self.reads += 1
            return dict(ok=True, harnessMode='wallet', booted=True,
                        walletPresent=False, hasError=False,
                        entryPhase='welcome' if self.natural else 'startup-before-initialization',
                        owner=3, revision=4, startupFilmState='skip-middle-frame-pending',
                        startupFilmProgress={**progress(), 'decoding': min(54, self.reads),
                                             'skip': self.report.key_attempts == 1},
                        controls=[dict(key='launch_skip_hint', enabled=True)])
        if command.get('action') == 'key':
            if self.refuse_key:
                raise probe.Failure('COMMAND_FAILED')
            return dict(ok=True, acted=True)
        raise AssertionError('Unexpected command')


class ProjectionTests(unittest.TestCase):
    def test_original_frame_integers_and_closed_fields_only(self):
        value = progress()
        self.assertEqual(probe.progress_projection(value), value)
        for key, bad in (('frames', True), ('frames', 4097), ('shown', 56),
                         ('decoding', -1), ('decoding', 56), ('decoding', '12'),
                         ('stage', 'private error'), ('stage', []), ('skip', 1)):
            with self.subTest(key=key, bad=bad):
                self.assertIsNone(probe.progress_projection({**value, key: bad}))
        self.assertIsNone(probe.progress_projection({**value, 'private': 'payload'}))
        self.assertIsNone(probe.progress_projection({**value, 'frames': 0}))

    def test_opening_and_finished_facts_do_not_synthesize_a_frame(self):
        opening = dict(frames=0, shown=-1, decoding=None, stage='asset',
                       skip=False, pending=False, ticking=True, done=False)
        self.assertEqual(probe.progress_projection(opening), opening)
        ended = {**progress(), 'shown': 55, 'decoding': 55, 'stage': 'complete',
                 'done': True, 'ticking': False}
        self.assertEqual(probe.progress_projection(ended), ended)
        self.assertIsNone(probe.progress_projection({**opening, 'shown': 0}))

    def test_sample_rejects_payloads_unknown_labels_and_unbounded_time(self):
        value = sample()
        self.assertEqual(probe.sample_projection(value), value)
        for key, bad in (('at_ms', -1), ('at_ms', 90001), ('at_ms', True),
                         ('phase', 'private path'), ('phase', []), ('film', []),
                         ('film', 'private output'), ('progress', {})):
            with self.subTest(key=key):
                self.assertIsNone(probe.sample_projection({**value, key: bad}))
        self.assertIsNone(probe.sample_projection({**value, 'reply': 'private'}))


class ReportTests(unittest.TestCase):
    def test_complete_original_observation_is_not_chain_or_wallet_acceptance(self):
        report = positive_report()
        public = report.public()
        self.assertTrue(public['success'])
        self.assertTrue(public['original_skip_qualified'])
        self.assertFalse(public['wallet_qualified'])
        self.assertFalse(public['chain_qualified'])
        self.assertEqual(public['visual_matches'], 0)
        report.samples = [sample(at_ms=at * 250) for at in range(96)]
        full = report.public()
        self.assertGreater(len(json.dumps(full)), 4096)
        summary = report.summary()
        self.assertLessEqual(len(json.dumps(summary).encode('ascii')), 3800)
        self.assertEqual(summary['scope'], 'original_release_startup_summary')
        self.assertEqual(summary['sample_count'], 96)
        self.assertEqual(summary['first_sample'], full['samples'][0])
        self.assertEqual(summary['last_sample'], full['samples'][-1])
        self.assertEqual(len(summary['report_sha256']), 64)
        self.assertNotIn('samples', summary)
        self.assertEqual(report.public(), full)
        report.samples[48] = sample(at_ms=48 * 250,
                                    progress={**progress(), 'decoding': 13})
        changed = report.summary()
        self.assertEqual(changed['first_sample'], summary['first_sample'])
        self.assertEqual(changed['last_sample'], summary['last_sample'])
        self.assertNotEqual(changed['report_sha256'], summary['report_sha256'])
        for code in probe.CODES:
            report.fail(code)
        summary = report.summary()
        self.assertTrue(summary['errors_truncated'])
        self.assertEqual(summary['error_count'], len(probe.CODES))
        self.assertLessEqual(len(json.dumps(summary).encode('ascii')), 3800)

    def test_original_deadline_failure_cannot_be_healed_by_late_exit(self):
        report = positive_report()
        report.startup_deadline_expired = True
        self.assertFalse(report.public()['success'])
        report.startup_deadline_expired = False
        report.fail('STARTUP_DEADLINE', ValueError('private text'))
        public = report.public()
        self.assertFalse(public['success'])
        self.assertNotIn('private text', json.dumps(public))
        self.assertIn('STARTUP_DEADLINE', public['error_codes'])

    def test_natural_startup_never_becomes_skip_qualification(self):
        report = positive_report()
        report.handoff, report.key_attempts = 'natural', 0
        self.assertTrue(report.public()['success'])
        self.assertFalse(report.public()['original_skip_qualified'])
        report.key_attempts = 1
        self.assertFalse(report.public()['success'])

    def test_incomplete_force_overflow_unpinned_and_malformed_data_deny_success(self):
        for name, value in (('forced_kill', True), ('output_complete', False),
                            ('output_overflow', True), ('exit_observed', False),
                            ('exit_code', 9), ('key_attempts', True),
                            ('runner_sha256', None), ('source_tree', None),
                            ('run_id', None), ('run_attempt', '0')):
            with self.subTest(name=name):
                report = positive_report()
                setattr(report, name, value)
                self.assertFalse(report.public()['success'])
        for values in ([sample(progress={})], [sample()] * 97,
                       [sample(at_ms=2), sample(at_ms=1)]):
            report = positive_report()
            report.samples = values
            self.assertFalse(report.public()['success'])


class ProtocolTests(unittest.TestCase):
    def test_one_original_key_uses_current_owner_revision_and_reads_progress(self):
        session = Session()
        session._startup()
        keys = [row for row in session.commands if row.get('action') == 'key']
        self.assertEqual(keys, [dict(cmd='wallet-recipe', action='key',
            key='launch_skip_hint', owner=3, revision=4)])
        self.assertEqual([row['progress']['decoding'] for row in session.report.samples], [1, 2])
        self.assertEqual(session.report.handoff, 'key-confirmed')
        self.assertTrue(session.report.checks['startup_ready'])

    def test_refused_original_key_is_never_retried(self):
        session = Session(refuse_key=True)
        with self.assertRaises(probe.Failure):
            session._startup()
        self.assertEqual(session.report.key_attempts, 1)
        self.assertEqual(len([row for row in session.commands
                              if row.get('action') == 'key']), 1)
        self.assertIsNone(session.report.handoff)

    def test_natural_handoff_issues_no_input(self):
        session = Session(ready_after=1, natural=True)
        session._startup()
        self.assertEqual(session.report.handoff, 'natural')
        self.assertEqual(session.report.key_attempts, 0)
        self.assertFalse(any(row.get('action') == 'key' for row in session.commands))

    def test_original_deadline_is_twenty_seconds_and_samples_stay_bounded(self):
        session = Session(ready_after=1000)
        with self.assertRaises(probe.Failure) as caught:
            session._startup()
        self.assertEqual(caught.exception.code, 'STARTUP_DEADLINE')
        self.assertEqual(session.timer.now, 20)
        self.assertTrue(session.report.startup_deadline_expired)
        self.assertEqual(session.report.key_attempts, 1)
        self.assertLessEqual(len(session.report.samples), probe.MAX_SAMPLES)
        late = Session(ready_after=1000)

        def failed_exchange(command, **kwargs):
            late.timer.now = 20
            raise probe.Failure('HTTP_FAILED')

        late._rpc = failed_exchange
        with self.assertRaises(probe.Failure) as caught:
            late._startup()
        self.assertEqual(caught.exception.code, 'STARTUP_DEADLINE')
        self.assertIn('HTTP_FAILED', late.report.errors)
        self.assertTrue(late.report.startup_deadline_expired)

    def test_unknown_owners_and_nonempty_wallets_refuse_before_input(self):
        for key, bad in (('walletPresent', True), ('hasError', True),
                         ('owner', True), ('revision', -1)):
            with self.subTest(key=key):
                session = Session()
                original = session._rpc

                def corrupt(command, **kwargs):
                    body = original(command, **kwargs)
                    if command.get('action') == 'observe':
                        body[key] = bad
                    return body

                session._rpc = corrupt
                with self.assertRaises(probe.Failure) as caught:
                    session._startup()
                self.assertEqual(caught.exception.code, 'STARTUP_OBSERVATION_REFUSED')
                self.assertEqual(session.report.key_attempts, 0)


if __name__ == '__main__':
    unittest.main()
