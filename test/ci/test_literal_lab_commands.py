"""Pure fixture and mocked lifecycle controls; no Docker, SDK or filesystem scratch."""

import contextlib
import copy
import io
import json
from pathlib import Path
import unittest
from unittest import mock

from tool.ci import literal_lab_commands as lab


class LiteralLabTests(unittest.TestCase):
    def parent(self):
        return dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME='workflow_dispatch',
            SYRIUS_HOSTED_RUNNER='github-hosted', SYRIUS_LITERAL_LAB='true',
            GITHUB_REPOSITORY='edgepillar/syrius', GITHUB_REF='refs/heads/redesign',
            GITHUB_SHA='a' * 40, GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1')

    def rows(self):
        rows = []
        for index, role in enumerate(lab.ROLES, 1):
            ports = {} if role != 'rpc' else {
                '35997/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45997'}],
                '35998/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45998'}],
            }
            rows.append(dict(Id=str(index) * 64, Image='sha256:' + 'f' * 64,
                Name='/syrius-lab-' + role, RestartCount=0,
                Config=dict(Labels={'com.docker.compose.project': lab.PROJECT,
                    'com.docker.compose.service': role, 'private': 'not exported'}),
                State=dict(Running=True, Paused=False, Dead=False, OOMKilled=False,
                    Status='running', Pid=index,
                    StartedAt='2026-11-04T00:00:00.123456789Z'),
                NetworkSettings=dict(Ports=ports, Networks={lab.PROJECT:
                    dict(IPAddress='172.37.0.' + str(lab.hosted.OCTETS[role]))}),
                Mounts=[dict(Destination='/devnet', Type='bind', RW=False,
                    Source='/fixture/assets'), dict(Destination='/root/.znn',
                    Type='volume', RW=True, Name=lab.PROJECT + '_' + role + '-data')]))
        return rows

    def parse(self, rows):
        return lab.containers(json.dumps(rows).encode(), 'sha256:' + 'f' * 64,
            Path('/fixture/assets'))

    def events(self, owned):
        return [dict(Type='container', Action='die', Actor=dict(ID=value[0],
            Attributes={'exitCode': '0', 'name': 'syrius-lab-' + role,
                'com.docker.compose.project': lab.PROJECT,
                'com.docker.compose.service': role})) for role, value in owned.items()]

    def encoded(self, rows):
        return b'\n'.join(json.dumps(row).encode() for row in rows)

    def test_admits_only_first_manual_fork_linux_hosted_trial(self):
        lab.admit(self.parent(), 'linux')
        for field, value in [('GITHUB_EVENT_NAME', 'push'),
                ('SYRIUS_HOSTED_RUNNER', 'self-hosted'), ('SYRIUS_LITERAL_LAB', 'false'),
                ('GITHUB_REPOSITORY', 'private/other'), ('GITHUB_REF', 'refs/heads/dev'),
                ('GITHUB_SHA', 'private'), ('GITHUB_RUN_ID', 'private'),
                ('GITHUB_RUN_ATTEMPT', '2')]:
            with self.subTest(field=field), self.assertRaises(lab.Refused):
                lab.admit(dict(self.parent(), **{field: value}), 'linux')
        with self.assertRaises(lab.Refused):
            lab.admit(self.parent(), 'win32')

    def test_unadmitted_main_starts_no_original_process(self):
        with mock.patch.dict(lab.os.environ, {}, clear=True), \
                mock.patch.object(lab.hosted, 'Original', side_effect=AssertionError('forbidden')), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(lab.main(), 1)
        value = json.loads(output.getvalue().split('::', 2)[2])
        self.assertEqual(value['code'], 'ENVIRONMENT_REFUSED')
        self.assertEqual(value['commands'], [])

    def test_frontier_requires_chain321_and_actual_height_progress(self):
        self.assertEqual(lab.frontier(b'compose table\nchain 321: 5 then 6 after 5 s\nproducing\n'),
            dict(chain_id=321, first_height=5, last_height=6, seconds=5))
        for line in (b'chain 69: 5 then 6 after 5 s', b'chain 321: 5 then 5 after 5 s',
                b'chain 321: 6 then 5 after 5 s', b'chain 321: 5 then 6 after 271 s',
                b'chain 321: 5 then 9007199254740992 after 5 s'):
            with self.subTest(line=line), self.assertRaises(lab.Refused):
                lab.frontier(line + b'\nproducing\n')

    def test_frontier_never_borrows_an_earlier_valid_record(self):
        good = b'chain 321: 5 then 6 after 5 s\nproducing\n'
        for raw in (good + b'private', good + good,
                good.replace(b'producing', b'NOT producing'), b'x' * (2 * lab.MIB + 1)):
            with self.assertRaises(lab.Refused):
                lab.frontier(raw)

    def test_container_binding_keeps_original_id_start_and_pid_only(self):
        result = self.parse(self.rows())
        self.assertEqual(set(result), set(lab.ROLES))
        self.assertEqual(result['pillar'], ('1' * 64, '2026-11-04T00:00:00.123456789Z', 1))
        self.assertNotIn('private', json.dumps(result))

    def test_missing_extra_repeated_and_replaced_resources_refuse(self):
        original = self.rows()
        samples = [original[:-1], original + [original[0]],
            [original[0], original[0], *original[2:]]]
        for field, value in [('Id', 'private'), ('Image', 'sha256:' + 'e' * 64),
                ('Name', '/other'), ('RestartCount', 1)]:
            changed = copy.deepcopy(original);changed[0][field] = value;samples.append(changed)
        for rows in samples:
            with self.assertRaises(lab.Refused):
                self.parse(rows)

    def test_process_replacement_changes_the_bound_original(self):
        rows = self.rows();before = self.parse(rows)
        rows[0]['State']['Pid'] += 10
        self.assertNotEqual(before, self.parse(rows))
        rows = self.rows();rows[0]['State']['StartedAt'] = '2026-11-04T01:00:00Z'
        self.assertNotEqual(before, self.parse(rows))

    def test_unowned_or_unhealthy_container_state_refuses(self):
        for field, value in [('Running', False), ('Paused', True), ('Dead', True),
                ('OOMKilled', True), ('Status', 'exited'), ('Pid', True),
                ('StartedAt', 'private')]:
            rows = self.rows();rows[0]['State'][field] = value
            with self.subTest(field=field), self.assertRaises(lab.Refused):
                self.parse(rows)
        rows = self.rows();rows[0]['Config']['Labels']['com.docker.compose.project'] = 'other'
        with self.assertRaises(lab.Refused):self.parse(rows)

    def test_public_or_extra_rpc_and_p2p_bindings_refuse(self):
        for role, key, binding in [('rpc', '35997/tcp', [{'HostIp': '0.0.0.0', 'HostPort': '45997'}]),
                ('pillar', '35995/tcp', [{'HostIp': '127.0.0.1', 'HostPort': '45995'}]),
                ('rpc', '35995/tcp', [{'HostIp': '127.0.0.1', 'HostPort': '45995'}])]:
            rows = self.rows();next(r for r in rows if r['Name'].endswith('-' + role))['NetworkSettings']['Ports'][key] = binding
            with self.assertRaises(lab.Refused):self.parse(rows)

    def test_changed_asset_volume_and_peer_bindings_refuse(self):
        for mount, field, value in [(0, 'RW', True), (0, 'Source', '/private'),
                (1, 'Name', 'unowned-volume')]:
            rows = self.rows();rows[0]['Mounts'][mount][field] = value
            with self.assertRaises(lab.Refused):self.parse(rows)
        rows = self.rows();rows[0]['NetworkSettings']['Networks'][lab.PROJECT]['IPAddress'] = '127.0.0.1'
        with self.assertRaises(lab.Refused):self.parse(rows)

    def test_original_exit_events_require_every_owned_zero_exit(self):
        owned = self.parse(self.rows())
        self.assertEqual(lab.exits(self.encoded(self.events(owned)), owned), dict.fromkeys(lab.ROLES, 0))

    def test_missing_duplicate_nonzero_and_oom_events_refuse(self):
        owned = self.parse(self.rows());original = self.events(owned)
        samples = [original[:-1], original + [original[0]]]
        changed = copy.deepcopy(original);changed[0]['Actor']['Attributes']['exitCode'] = '137';samples.append(changed)
        samples.append(original + [dict(Type='container', Action='oom', Actor=dict(ID='1' * 64))])
        for rows in samples:
            with self.assertRaises(lab.Refused):lab.exits(self.encoded(rows), owned)

    def test_foreign_events_and_labels_are_never_exported(self):
        owned = self.parse(self.rows());rows = self.events(owned)
        rows.append(dict(Type='container', Action='die', Actor=dict(ID='private', Attributes=dict(private='secret'))))
        value = lab.exits(self.encoded(rows), owned)
        self.assertNotIn('secret', json.dumps(value));self.assertNotIn('private', json.dumps(value))

    def test_duplicate_json_keys_and_unknown_errors_do_not_export_input(self):
        with self.assertRaises(lab.Refused):lab.json_value(b'{"a": 1, "a": 2}')
        self.assertEqual(lab.code(ValueError('/private/input secret')), 'INTERNAL_ERROR')

    def test_complete_original_command_path_closes_once_then_revalidates_source(self):
        commands = mock.Mock();commands.git.side_effect = [lab.NODE, lab.NODE_TREE]
        rows = self.rows();owned = self.parse(rows)
        commands.docker.side_effect = [json.dumps('sha256:' + 'f' * 64).encode(),
            json.dumps(rows).encode(), json.dumps(rows).encode(), b'', b'']
        outputs = dict(up=b'chain 321: 5 then 6 after 5 s\nproducing\n',
            status=b'chain 321: 6 then 7 after 5 s\nproducing\n', down=b'',
            exit_events=self.encoded(self.events(owned)))
        commands.run.side_effect = lambda stage, *_args: outputs[stage]
        report = dict(source_sha='a' * 40, checks=dict.fromkeys(
            ('fresh', 'originals', 'production', 'stopped', 'source_after'), False))
        genesis = b'{"ChainIdentifier":321}'
        with mock.patch.object(lab, 'source', return_value='b' * 40) as source, \
                mock.patch.object(lab, 'empty_project'), \
                mock.patch.object(lab.hosted, 'regular', side_effect=[b'590f43c', genesis, genesis]):
            lab.observe(commands, Path('/repo'), Path('/fixture'), report)
        self.assertTrue(all(report['checks'].values()))
        self.assertEqual(source.call_count, 2)
        self.assertEqual(report['exit_codes'], dict.fromkeys(lab.ROLES, 0))
        self.assertEqual([c.args[0] for c in commands.run.call_args_list],
            ['up', 'status', 'down', 'exit_events'])
        argv = commands.run.call_args_list[-1].args[1]
        for value in owned.values():self.assertEqual(argv.count('container=' + value[0]), 1)

    def test_primary_observation_failure_survives_a_close_refusal(self):
        commands = mock.Mock();commands.git.side_effect = [lab.NODE, lab.NODE_TREE]
        commands.docker.return_value = json.dumps('sha256:' + 'f' * 64).encode()
        def run(stage, *args):
            if stage == 'up':return b'chain 321: 5 then 6 after 5 s\nproducing\n'
            raise lab.Refused('CHAIN_REFUSED')
        commands.run.side_effect = run
        report = dict(source_sha='a' * 40, checks=dict(fresh=False, originals=False, production=False))
        owned = self.parse(self.rows());changed = dict(owned, pillar=('e' * 64, owned['pillar'][1], 99))
        with mock.patch.object(lab, 'source', return_value='b' * 40), \
                mock.patch.object(lab, 'empty_project'), \
                mock.patch.object(lab.hosted, 'regular', side_effect=[b'590f43c', b'{"ChainIdentifier":321}']), \
                mock.patch.object(lab, 'containers', side_effect=[owned, changed]):
            with self.assertRaises(lab.Refused) as raised:
                lab.observe(commands, Path('/fixture'), Path('/fixture/lab'), report)
        self.assertEqual(raised.exception.code, 'CHAIN_REFUSED')
        self.assertEqual(report['observation_code'], 'CHAIN_REFUSED')
        self.assertEqual(report['close_code'], 'RESOURCE_CHANGED')
        self.assertEqual([c.args[0] for c in commands.run.call_args_list], ['up', 'status'])


if __name__ == '__main__':
    unittest.main()
