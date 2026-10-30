"""Paired original-report controls using memory and bounded fake transport."""

import base64
import contextlib
import io
import json
from pathlib import Path
import unittest
from unittest import mock
import zipfile

from tool.ci import inspect_startup_qualification as inspect
from tool.ci import inspect_windows_qualification as windows
from test.ci.test_windows_startup_probe import positive_report


HEAD, TREE, RUN = 'a' * 40, 'b' * 40, 9


def package(report, *, extra=False):
    manifest = (json.dumps(report, sort_keys=True) + '\n').encode('ascii')
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_STORED) as zipped:
        zipped.writestr('manifest.json', manifest)
        if extra:
            zipped.writestr('private.txt', b'private-state')
    return stream.getvalue(), manifest


def pair(*, negative=False):
    ordinary, manifest = package(positive_report().public())
    natural = positive_report(natural_only=True)
    natural.prior_manifest_sha256 = inspect.archive.sha(manifest)
    if negative:
        natural.startup_deadline_expired = True
        natural.fail('STARTUP_DEADLINE')
    return ordinary, package(natural.public())[0]


class Client:
    def __init__(self, *, negative=False, source_changed=False, missing=False,
                 mixed=False, duplicate=False):
        self.calls = []
        self.bodies = dict(zip((7, 8), pair(negative=negative)))
        self.source_changed, self.missing = source_changed, missing
        self.mixed, self.duplicate = mixed, duplicate
        self.job = dict(id=17, name=inspect.JOB_NAME, head_sha=HEAD, run_id=RUN,
                        status='completed', conclusion='failure' if negative else 'success')

    def json(self, path):
        self.calls.append(path)
        if path == '/actions/runs/9':
            return dict(id=RUN, head_sha=HEAD, run_attempt=1, workflow_id=381413107,
                        event='workflow_dispatch', status='completed',
                        repository=dict(full_name='edgepillar/syrius'))
        if path == '/git/commits/' + HEAD:
            return dict(sha=HEAD, tree=dict(sha=TREE))
        if path.startswith('/contents/tool/ci/'):
            name = path.split('/')[-1].partition('?')[0]
            body = Path(inspect.__file__).with_name(name).read_bytes()
            if self.source_changed and name == 'windows_startup_probe.py':
                body += b'\n# changed producer\n'
            return dict(type='file', path='tool/ci/' + name, encoding='base64',
                        size=len(body), content=base64.b64encode(body).decode())
        if path == '/actions/runs/9/attempts/1/jobs?per_page=20':
            other = dict(id=18, name='Hosted Windows baseline', head_sha=HEAD,
                         run_id=RUN, status='completed', steps=[],
                         conclusion='success' if self.mixed else 'skipped')
            rows = [self.job, other]
            if self.duplicate:
                rows.append(dict(self.job))
            return dict(total_count=len(rows), jobs=rows)
        if path == '/actions/runs/9/artifacts?per_page=20':
            names = ('windows-startup-probe-', 'windows-natural-startup-probe-')
            rows = [dict(id=number, expired=False,
                         name=prefix + HEAD + '-9-1', size_in_bytes=len(self.bodies[number]),
                         digest='sha256:' + inspect.archive.sha(self.bodies[number]),
                         workflow_run=dict(id=RUN, head_sha=HEAD))
                    for number, prefix in zip((7, 8), names)]
            if self.missing:
                rows.pop()
            return dict(total_count=len(rows), artifacts=rows)
        raise AssertionError('Unexpected metadata query')

    def read(self, url, *, redirect=False, authenticated=True, cap=262144):
        self.calls.append(url)
        if redirect:
            if not authenticated or url.rsplit('/', 1)[-1] != 'zip':
                raise AssertionError('Unexpected redirect')
            number = int(url.split('/')[-2])
            return 'https://synthetic.blob.core.windows.net/' + str(number)
        if authenticated or cap != inspect.MAX_ARCHIVE:
            raise AssertionError('Credentials or unbounded artifact read')
        data = self.bodies[int(url.rsplit('/', 1)[-1])]
        if len(data) > cap:
            raise AssertionError('Oversized artifact')
        return data


class StartupInspectionTests(unittest.TestCase):
    def test_original_pair_keeps_exact_manifest_binary_and_prior_binding(self):
        client = Client()
        values = inspect.inspect_run(client, head=HEAD, tree=TREE, run_id=RUN,
                                     job=client.job)
        self.assertEqual(len(values), 2)
        ordinary, natural = values
        self.assertTrue(ordinary['original_skip_qualified'])
        self.assertTrue(natural['original_natural_qualified'])
        self.assertFalse(natural['original_skip_qualified'])
        self.assertEqual(natural['prior_manifest_sha256'], ordinary['manifest_sha256'])
        self.assertEqual(natural['runner_sha256'], ordinary['runner_sha256'])
        self.assertEqual(natural['payload_sha256'], ordinary['payload_sha256'])
        self.assertEqual(natural['key_attempts'], 0)
        for value in values:
            self.assertTrue(value['inspection_only'])
            self.assertFalse(value['runtime_started'])
            self.assertFalse(value['wallet_qualified'])
            self.assertEqual(value['financial_actions_requested'], 0)
            with contextlib.redirect_stdout(io.StringIO()):
                windows.emit('Hosted startup inspection', value)

    def test_archive_refuses_wrong_digest_size_source_tree_or_run(self):
        raw = pair()[0]
        arguments = (inspect.archive.sha(raw), len(raw), HEAD, TREE, RUN)
        variants = [('f' * 64, *arguments[1:]),
                    (arguments[0], len(raw) + 1, *arguments[2:]),
                    (*arguments[:2], 'f' * 40, TREE, RUN),
                    (*arguments[:3], 'f' * 40, RUN),
                    (*arguments[:4], RUN + 1)]
        for selected in variants:
            with self.subTest(selected=selected), self.assertRaises(inspect.archive.Refused):
                inspect.startup_archive(raw, *selected)

    def test_natural_archive_refuses_foreign_prior_payload_and_claimed_skip_success(self):
        ordinary, natural = pair()
        prior = inspect.startup_archive(ordinary, inspect.archive.sha(ordinary),
                                        len(ordinary), HEAD, TREE, RUN)
        arguments = dict(natural_only=True,
                         prior_manifest_sha256=prior['manifest_sha256'],
                         runner_sha256=prior['runner_sha256'],
                         payload_sha256=prior['payload_sha256'])
        for fields in ({'prior_manifest_sha256': 'f' * 64},
                       {'runner_sha256': 'f' * 64},
                       {'payload_sha256': 'f' * 64}):
            with self.subTest(fields=fields), self.assertRaises(inspect.archive.Refused):
                inspect.startup_archive(natural, inspect.archive.sha(natural),
                    len(natural), HEAD, TREE, RUN, **{**arguments, **fields})
        report = positive_report(natural_only=True).public()
        report.update(prior_manifest_sha256=prior['manifest_sha256'],
                      key_attempts=1, handoff='key-confirmed')
        raw = package(report)[0]
        with self.assertRaises(inspect.archive.Refused):
            inspect.startup_archive(raw, inspect.archive.sha(raw), len(raw),
                                    HEAD, TREE, RUN, **arguments)

    def test_archive_refuses_extra_members_before_export(self):
        raw = package(positive_report().public(), extra=True)[0]
        with self.assertRaises(inspect.archive.Refused):
            inspect.startup_archive(raw, inspect.archive.sha(raw), len(raw),
                                    HEAD, TREE, RUN)

    def test_reader_preserves_negative_natural_deadline_and_original_positive(self):
        client = Client(negative=True)
        ordinary, natural = inspect.inspect_run(
            client, head=HEAD, tree=TREE, run_id=RUN, job=client.job)
        self.assertTrue(ordinary['artifact_reported_success'])
        self.assertFalse(natural['artifact_reported_success'])
        self.assertFalse(natural['original_natural_qualified'])
        self.assertTrue(natural['startup_deadline_expired'])
        self.assertEqual(natural['original_error_codes'], ['STARTUP_DEADLINE'])
        self.assertEqual(natural['original_job_conclusion'], 'failure')

    def read_windows(self, client):
        environment = dict(GITHUB_ACTIONS='true', SYRIUS_HOSTED_RUNNER='github-hosted',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='edgepillar/syrius',
            WINDOWS_INSPECT_RUN=str(RUN), WINDOWS_INSPECT_HEAD=HEAD, GH_TOKEN='synthetic')
        with mock.patch.dict(windows.os.environ, environment, clear=True), \
                mock.patch.object(windows.archive, 'Client', return_value=client), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = windows.main()
        return status, output.getvalue()

    def test_generic_reader_routes_only_the_selected_original_startup_job(self):
        client = Client()
        status, output = self.read_windows(client)
        self.assertEqual(status, 0)
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        self.assertIn('Hosted original startup inspection', notices[0])
        self.assertIn('Hosted natural startup inspection', notices[1])
        self.assertFalse(any('/logs' in value for value in client.calls))
        self.assertNotIn('private-state', output)

    def test_changed_producer_or_missing_pair_is_not_qualified(self):
        for fields in (dict(source_changed=True), dict(missing=True)):
            client = Client(**fields)
            with self.subTest(fields=fields):
                status, output = self.read_windows(client)
                self.assertEqual(status, 1)
                self.assertIn('INSPECTION_REFUSED', output)
                self.assertNotIn('original_natural_qualified', output)
        client = Client(source_changed=True)
        self.read_windows(client)
        self.assertFalse(any('/artifacts/' in value for value in client.calls))

    def test_mixed_or_duplicate_jobs_are_refused_before_archive_transport(self):
        for fields in (dict(mixed=True), dict(duplicate=True)):
            client = Client(**fields)
            with self.subTest(fields=fields):
                status, output = self.read_windows(client)
                self.assertEqual(status, 1)
                self.assertIn('INSPECTION_REFUSED', output)
                self.assertFalse(any('/artifacts' in value for value in client.calls))


if __name__ == '__main__':
    unittest.main()
