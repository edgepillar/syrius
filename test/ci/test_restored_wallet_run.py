"""Memory policies and separate tiny hosted filesystem fixtures, without signing."""

import ast
import json
import hashlib
import io
from pathlib import Path, PureWindowsPath
import re
import tempfile
import time
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab
from tool.ci import restored_wallet_run as restored
from tool.ci import wallet_restore_origin as origin
from tool.ci import windows_wallet_tour as tour


def wallet_observation():
    return dict(schema=1, scope='restored_lab_wallet_observation', chain=321,
        members=2, selected_index=1, membership_same=True, selection_saved=True,
        wallet_path_mapped=True, original_send_confirmed=True,
        journal_consistent=True, observation_stable=True)


def completed():
    return dict(schema=1, scope=restored.SCOPE, complete=True, claim_once=True,
        originals_closed=True, chain_continuity=True, journal_unchanged=True,
        cipher_unchanged=True, wallet=wallet_observation(), application_exit=0,
        entry_exit=0, output=dict(bytes=123, sha256='a'*64,
            output_complete=True, overflow=False), job_empty=True, forced=False,
        nodes=[dict(role=role, exit_code=0, output_complete=True, forced=False)
               for role in restored.checkpoint.ROLES[1:]],
        private_manifest_sha256='b'*64, seed_admitted=False)


def lock_view_observation():
    return dict(schema=1, status='observed', owner_same=True,
        view=dict({key: False for key in restored.LOCK_VIEW_BOOLEANS},
            password_failures=0, lifecycle='inactive'))


def original_wait(namespace):
    source = ast.parse(Path('tool/ci/restored_wallet_run.py').read_text())
    run = next(node for node in source.body
        if isinstance(node, ast.FunctionDef) and node.name == 'run')
    waits = [node for node in ast.walk(run)
        if isinstance(node, ast.FunctionDef) and node.name == 'wait']
    assert len(waits) == 1
    wrapper = ast.parse('def bind_original_wait():\n'
        '    holder_selection_observation = None\n'
        '    def wait(marker): pass\n'
        '    return wait\n')
    wrapper.body[0].body[1] = waits[0]
    exec(compile(ast.fix_missing_locations(wrapper),
        '<original-restored-wait>', 'exec'), namespace)
    return namespace['bind_original_wait']()


class PolicyTests(unittest.TestCase):
    def test_holder_scope_keeps_original_catalog_digest_and_required_actor_closure(self):
        from tool.ci import seeded_surface_seams
        receipts = dict(schema=1, scope='private_restored_seed_catalog_receipts',
            chain=321, members=3, selected_index=1, derived_once=True,
            owner_stable=True, receipts=[dict(recipe=name, hash=f'{i:064x}')
                for i, name in enumerate(('stake', 'token'), 1)])
        seeds = restored.seeds.completed(receipts, catalog_capture=True)
        reference = dict(schema=4, scope='restored_native_seeded_catalog_reference',
            screens=['staking', 'token-mine'], captured=4, manifest_sha256='d' * 64,
            seed_receipts_sha256=seeds['receipts_sha256'])
        seams = seeded_surface_seams.holder_completed([
            dict(schema=1, scope=seeded_surface_seams.SCOPE, seam=seam,
                 theme=theme, **seeded_surface_seams.FACTS)
            for seam, theme in seeded_surface_seams.EXPECTED],
            seeded_surface_seams.HOLDER_SELECTION, seeds['receipts_sha256'])
        value = dict(completed(), catalog_prerequisites=seeds,
                     seeded_catalog=reference, seeded_surface_seams=seams)
        self.assertEqual(restored.project(value), value)
        self.assertEqual(value['wallet']['selected_index'], 1)
        self.assertEqual(value['seeded_surface_seams']['holder_selection']['selectedIndex'], 2)
        for change in (dict(application_exit=1), dict(entry_exit=1), dict(forced=True),
                       dict(seeded_catalog=None), dict(originals_closed=False),
                       dict(seeded_surface_seams=dict(seams, seed_receipts_sha256='e' * 64)),
                       dict(seeded_surface_seams=dict(seams, holder_selection=None)),
                       dict(seeded_owner_page_seams=seams)):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(value, **change))
        changed = json.loads(json.dumps(value))
        changed['nodes'][-1]['forced'] = True
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(changed)
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), seeded_surface_seams=seams))

    def test_owner_page_seams_need_the_original_closed_catalog_and_cannot_borrow_full_scope(self):
        from tool.ci import seeded_surface_seams
        receipts = dict(schema=1, scope='private_restored_seed_catalog_receipts',
            chain=321, members=3, selected_index=1, derived_once=True,
            owner_stable=True, receipts=[dict(recipe=name, hash=f'{i:064x}')
                for i, name in enumerate(('stake', 'token'), 1)])
        seeds = restored.seeds.completed(receipts, catalog_capture=True)
        reference = dict(schema=4, scope='restored_native_seeded_catalog_reference',
            screens=['staking', 'token-mine'], captured=4, manifest_sha256='d' * 64,
            seed_receipts_sha256=seeds['receipts_sha256'])
        observations = [dict(schema=1, scope=seeded_surface_seams.SCOPE, seam=seam,
            theme=theme, **seeded_surface_seams.FACTS)
            for seam, theme in seeded_surface_seams.OWNER_EXPECTED]
        seams = seeded_surface_seams.owner_completed(observations, seeds['receipts_sha256'])
        value = dict(completed(), catalog_prerequisites=seeds,
                     seeded_catalog=reference, seeded_owner_page_seams=seams)
        self.assertEqual(restored.project(value), value)
        for change in (dict(application_exit=1), dict(forced=True),
                       dict(seeded_catalog=None),
                       dict(seeded_owner_page_seams=dict(seams, seed_receipts_sha256='e' * 64)),
                       dict(seeded_surface_seams=seams)):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(value, **change))
        renamed = dict(value)
        renamed['seeded_surface_seams'] = renamed.pop('seeded_owner_page_seams')
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(renamed)
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), seeded_owner_page_seams=seams))

    def test_surface_seams_require_the_same_catalog_receipts_and_complete_closure(self):
        from tool.ci import seeded_surface_seams
        receipts = dict(schema=1, scope='private_restored_seed_catalog_receipts',
            chain=321, members=3, selected_index=1, derived_once=True,
            owner_stable=True, receipts=[dict(recipe=name, hash=f'{i:064x}')
                for i, name in enumerate(('stake', 'token'), 1)])
        seeds = restored.seeds.completed(receipts, catalog_capture=True)
        reference = dict(schema=4, scope='restored_native_seeded_catalog_reference',
            screens=['staking', 'token-mine'], captured=4, manifest_sha256='d' * 64,
            seed_receipts_sha256=seeds['receipts_sha256'])
        observations = [dict(schema=1, scope=seeded_surface_seams.SCOPE, seam=seam,
            theme=theme, pointerDispatched=True, absorptionObserved=True,
            originalReceiptCurrent=True, nativeFrameObserved=True)
            for seam, theme in seeded_surface_seams.EXPECTED]
        seams = seeded_surface_seams.completed(observations, seeds['receipts_sha256'])
        value = dict(completed(), catalog_prerequisites=seeds,
                     seeded_catalog=reference, seeded_surface_seams=seams)
        self.assertEqual(restored.project(value), value)
        for change in (dict(application_exit=1),
                       dict(seeded_surface_seams=dict(seams, seed_receipts_sha256='e' * 64)),
                       dict(seeded_surface_seams=dict(seams, observations=observations[:1]))):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(value, **change))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), seeded_surface_seams=seams))

    def test_only_complete_finite_reopen_facts_are_projected(self):
        value = completed()
        self.assertEqual(restored.project(value), value)
        self.assertFalse(restored.project(value)['seed_admitted'])

    def test_seeded_catalog_requires_matching_completed_seed_workflow(self):
        seed_receipts = dict(schema=1, scope='private_restored_seed_receipts',
            chain=321, members=3, selected_index=1, derived_once=True,
            owner_stable=True, receipts=[dict(recipe=recipe, hash=f'{i:064x}')
                for i, recipe in enumerate(restored.seeds.IDS, 1)])
        seeds = restored.seeds.completed(seed_receipts)
        reference = dict(schema=4, scope='restored_native_seeded_catalog_reference',
            screens=['staking', 'token-mine'], captured=4,
            manifest_sha256='d'*64, seed_receipts_sha256=seeds['receipts_sha256'])
        value = dict(completed(), seeded_catalog=reference, seed_workflow=seeds)
        self.assertEqual(restored.project(value), value)
        for change in (dict(seed_workflow=None),
                       dict(seeded_catalog=dict(reference, seed_receipts_sha256='e'*64)),
                       dict(application_exit=1)):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(value, **change))
        prerequisites = restored.seeds.completed(dict(seed_receipts,
            scope='private_restored_seed_catalog_receipts',
            receipts=[row for row in seed_receipts['receipts']
                      if row['recipe'] in ('stake', 'token')]), catalog_capture=True)
        catalog_reference = dict(reference,
            seed_receipts_sha256=prerequisites['receipts_sha256'])
        focused = dict(completed(), catalog_prerequisites=prerequisites,
            seeded_catalog=catalog_reference)
        self.assertEqual(restored.project(focused), focused)
        self.assertEqual(prerequisites['scope'], 'owned_restored_seed_catalog_prerequisites')
        self.assertEqual(prerequisites['recipes'], ['stake', 'token'])
        self.assertEqual(prerequisites['confirmed'], 2)
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), catalog_prerequisites=prerequisites))
        for change in (dict(catalog_prerequisites=seeds), dict(seeded_catalog=reference),
                       dict(seed_workflow=seeds)):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(focused, **change))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), seeded_catalog=catalog_reference,
                seed_workflow=prerequisites))
        stake_only = restored.seeds.completed(dict(seed_receipts,
            scope='private_restored_seed_catalog_receipts',
            receipts=seed_receipts['receipts'][:1]), catalog_capture='stake-draft')
        stake_draft_reference = dict(reference, schema=6, screens=['staking-new'],
            captured=2, seed_receipts_sha256=stake_only['receipts_sha256'])
        draft = dict(completed(), catalog_prerequisites=stake_only,
                     seeded_catalog=stake_draft_reference)
        self.assertEqual(restored.project(draft), draft)
        for different in (
            dict(draft, catalog_prerequisites=prerequisites),
            dict(draft, seeded_catalog=dict(catalog_reference,
                 seed_receipts_sha256=stake_only['receipts_sha256'])),
            dict(completed(), seed_workflow=seeds, seeded_catalog=stake_draft_reference),
            dict(draft, seeded_catalog=dict(stake_draft_reference,
                 seed_receipts_sha256=prerequisites['receipts_sha256'])),
        ):
            with self.subTest(different=different), self.assertRaises(restored.checkpoint.Refused):
                restored.project(different)
        project_only = restored.seeds.completed(dict(seed_receipts,
            scope='private_restored_project_catalog_receipts',
            receipts=[row for row in seed_receipts['receipts']
                      if row['recipe'] == 'project']), catalog_capture='project-detail')
        project_reference = dict(reference, schema=7, screens=['az-project'],
            captured=2, seed_receipts_sha256=project_only['receipts_sha256'])
        detail = dict(completed(), catalog_prerequisites=project_only,
                      seeded_catalog=project_reference)
        self.assertEqual(restored.project(detail), detail)
        self.assertEqual(project_only['scope'], 'owned_restored_project_catalog_prerequisites')
        for different in (
            dict(detail, catalog_prerequisites=stake_only),
            dict(detail, seeded_catalog=dict(stake_draft_reference,
                 seed_receipts_sha256=project_only['receipts_sha256'])),
            dict(completed(), seed_workflow=seeds, seeded_catalog=project_reference),
        ):
            with self.subTest(different=different), self.assertRaises(restored.checkpoint.Refused):
                restored.project(different)

    def test_absence_and_incomplete_reopen_never_supply_a_wallet(self):
        self.assertIsNone(restored.project(None))
        value = dict(schema=1, scope=restored.SCOPE, complete=False)
        self.assertEqual(restored.project(value), value)
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(value, wallet=wallet_observation()))

    def test_private_or_missing_observation_fields_are_refused(self):
        for candidate in (dict(wallet_observation(), walletPath='private'),
                {key: value for key, value in wallet_observation().items() if key != 'chain'}):
            with self.subTest(fields=len(candidate)), self.assertRaises(restored.checkpoint.Refused):
                restored.wallet_observation(candidate)

    def test_every_wallet_observation_must_be_positive_and_well_typed(self):
        for field, value in (('schema', True), ('chain', 1), ('chain', 321.0),
                ('members', True), ('members', 129), ('members', 1),
                ('selected_index', 0), ('selected_index', True),
                ('membership_same', False), ('selection_saved', 1),
                ('wallet_path_mapped', False), ('original_send_confirmed', False),
                ('journal_consistent', False), ('observation_stable', False)):
            with self.subTest(field=field), self.assertRaises(restored.checkpoint.Refused):
                restored.wallet_observation(dict(wallet_observation(), **{field: value}))

    def test_failed_forced_or_unclosed_actors_cannot_be_healed(self):
        for change in (dict(application_exit=None), dict(application_exit=False),
                dict(entry_exit=1), dict(forced=True), dict(job_empty=False),
                dict(originals_closed=False), dict(chain_continuity=False),
                dict(journal_unchanged=False), dict(cipher_unchanged=False),
                dict(claim_once=False), dict(seed_admitted=True)):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(completed(), **change))

    def test_each_new_original_node_requires_its_own_normal_complete_exit(self):
        for change in (dict(exit_code=1), dict(exit_code=False),
                       dict(forced=True), dict(output_complete=False), dict(role='foreign')):
            value = completed()
            value['nodes'][2].update(change)
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(value)
        value = completed()
        value['nodes'].pop()
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(value)

    def test_incomplete_overflowed_or_private_output_cannot_be_published(self):
        for change in (dict(bytes=True), dict(bytes=0), dict(output_complete=False),
                       dict(overflow=True), dict(sha256='private'), dict(raw='private')):
            value = completed()
            value['output'].update(change)
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.project(value)

    def test_unowned_local_entry_refuses_before_files_or_processes(self):
        with mock.patch.object(restored.subprocess, 'Popen') as launch, \
                mock.patch.object(restored.checkpoint, 'ancestors') as discover:
            with self.assertRaises(Exception):
                restored.run(Path('/fixture'), {}, mock.Mock(), mock.Mock(),
                    {}, {}, Path('/checkpoint'), lambda: True, lambda: 0)
        launch.assert_not_called()
        discover.assert_not_called()


class ReopenDiagnosticTests(unittest.TestCase):
    def test_prepared_operation_requires_completed_issuer_capture_context(self):
        operation = dict(schema=1, scope='prepared_owner_surface_operation',
            action='wait', target='home_hero', theme='dark', boundary='request')
        child = dict(schema=1, scope='owned_reopen_child_failure', phase='seeded_capture',
            kind='HARNESS_REFUSED', code=None, recipe=None,
            capture=dict(schema=2, kind='restored_seeded_capture_failure',
                         last_entered_step='complete', reply='unknown'),
            prepared_surface_operation=operation)
        projected = restored.child_failure_projection(child)
        self.assertEqual(projected, child)
        for change in (dict(phase='seed_token'), dict(capture=None),
                       dict(capture=dict(child['capture'], last_entered_step='scriptLine')),
                       dict(capture=dict(child['capture'], screen='staking', theme='dark', line=1)),
                       dict(capture=dict(child['capture'], kind='restored_stake_draft_capture_failure')),
                       dict(prepared_surface_operation=dict(operation, raw='private'))):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(dict(child, **change))
        operation['target'] = 'private'
        self.assertEqual(projected['prepared_surface_operation']['target'], 'home_hero')

    def test_prepared_operation_frames_keep_the_original_failure_unqualified(self):
        operation = dict(schema=1, scope='prepared_owner_surface_operation',
            action='seam', target='pillarAprEstimate', theme='light', boundary='request')
        child = dict(schema=1, scope='owned_reopen_child_failure', phase='seeded_capture',
            kind='HARNESS_REFUSED', code=None, recipe=None,
            capture=dict(schema=2, kind='restored_seeded_capture_failure',
                         last_entered_step='complete', reply='unknown'),
            prepared_surface_operation=operation)
        trace = restored.ReopenDiagnostic()
        trace.at('seeded_capture')
        trace.observe_line(b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\n')
        trace.failure(restored.checkpoint.Refused())
        value = restored.project(dict(schema=1, scope=restored.SCOPE, complete=False,
                                      diagnostic=trace.snapshot()))
        self.assertFalse(value['complete'])
        self.assertEqual(value['diagnostic']['error'], 'CHECKPOINT_REFUSED')
        self.assertEqual(value['diagnostic']['child_failure'], child)
        frames = restored.notice_frames(dict(scope='synthetic_observation',
            source_sha='a' * 40, run_id=123, codes=['SYNTHETIC_FINITE'] * 175,
            wallet_reopen=value))
        self.assertTrue(all(len(json.dumps(item, separators=(',', ':')).encode()) <= 3800
                            for _, item in frames))
        self.assertIn(operation, [item.get('facts', {}).get('diagnostic', {})
            .get('child_failure', {}).get('prepared_surface_operation') for _, item in frames]
            + [item.get('wallet_reopen', {}).get('diagnostic', {})
               .get('child_failure', {}).get('prepared_surface_operation') for _, item in frames])

    def test_actual_wait_retains_two_journal_prefixes_before_the_child_fails(self):
        receipts = [dict(recipe=recipe, hash=str(index+1)*64)
                    for index, recipe in enumerate(restored.seeds.IDS)]
        prefixes = [dict(schema=1, scope='private_restored_seed_prefix', chain=321,
            members=3, selected_index=1, derived_once=True, owner_stable=True,
            receipts=receipts[:count]) for count in (1, 2)]
        rows = [b'CI_SEED_PROGRESS:' + json.dumps(value).encode() + b'\n'
                for value in prefixes] + [b'CI_REOPEN_ERROR:seed_token\n']
        journals = {}
        for row in receipts[:2]:
            for state in ('attempt', 'accepted', 'confirmed'):
                value = dict(recipe=row['recipe'], state=state, chain=321)
                if state != 'attempt':
                    value['hash'] = row['hash']
                journals['seed-' + row['recipe'] + '-' + state + '.json'] = json.dumps(value).encode()
        class Journal(str):
            def lstat(self):
                return None
        class Home:
            def __truediv__(self, name):
                return Journal(name)
        trace = restored.ReopenDiagnostic()
        trace.at('seed_workflow')
        record, snapshot = {}, {}
        unchanged = mock.Mock()
        def read(path, cap):
            self.assertEqual(cap, 2048)
            return journals[path]
        namespace = dict(deadline=1, time=mock.Mock(monotonic=lambda: 0),
            checkpoint=restored.checkpoint, runtime=mock.Mock(), sample=mock.Mock(),
            guard=lambda: True, lines=mock.Mock(take=mock.Mock(side_effect=rows)),
            original=mock.Mock(poll=lambda: None), trace=trace, json=json,
            wallet_observation=restored.wallet_observation, seeds=restored.seeds,
            unchanged=unchanged, copied_home=Home(), snapshot=snapshot,
            record=record, bounded_read=read, hashlib=hashlib, catalog_capture=False)
        wait = original_wait(namespace)
        with mock.patch.object(restored.checkpoint, 'file_identity',
                return_value=(1, 2, 100)), self.assertRaises(restored.checkpoint.Refused):
            wait(b'CI_SEED_DONE')
        trace.failure(ValueError('Synthetic later recipe failure'))
        self.assertEqual(record['seed_private_prefix'], prefixes[-1])
        self.assertEqual(len(snapshot), 6)
        self.assertEqual(unchanged.call_count, 4)
        self.assertEqual(trace.snapshot()['seed_prefix']['confirmed'], 2)
        self.assertEqual(trace.snapshot()['child_phase'], 'seed_token')
        self.assertFalse(trace.snapshot()['seed_prefix']['complete'])

    def test_actual_wait_requires_one_selection_before_all_eight_original_pointers(self):
        seams = restored.seeded_surface_seams
        catalog = restored.catalog
        capture = dict(schema=4, scope='restored_native_seeded_catalog_capture',
            screens=['staking', 'token-mine'], themes=['dark', 'light'],
            files=['13-staking-dark.png', '13-staking-light.png',
                   '24-token-mine-dark.png', '24-token-mine-light.png'],
            width=1280, height=780, scale=1, capture_returned=True)
        def line(marker, value):
            return marker + b':' + json.dumps(value).encode() + b'\n'
        selection = line(b'CI_PREPARED_HOLDER_SELECTION', seams.HOLDER_SELECTION)
        pointers = [line(b'CI_PREPARED_SURFACE_SEAM', dict(schema=1,
            scope=seams.SCOPE, seam=seam, theme=theme, **seams.FACTS))
            for seam, theme in seams.EXPECTED]
        done = line(b'CI_SEEDED_CAPTURE_DONE', capture)
        complete = [selection, *pointers, done]
        for offered in (complete, pointers + [done],
                        [selection, selection, *pointers, done],
                        [selection, *reversed(pointers), done],
                        [selection, *pointers[:-1], done],
                        [pointers[0], selection, *pointers[1:], done]):
            record = dict(phase='seeded_capture', catalog_prerequisites=dict(
                complete=True, receipts_sha256='a' * 64))
            trace = restored.ReopenDiagnostic()
            trace.at('seeded_capture')
            namespace = dict(deadline=1, time=mock.Mock(monotonic=lambda: 0),
                checkpoint=restored.checkpoint, runtime=mock.Mock(), sample=mock.Mock(),
                guard=lambda: True, lines=mock.Mock(take=mock.Mock(side_effect=offered)),
                original=mock.Mock(poll=lambda: None), trace=trace, json=json,
                capture_schema=4, catalog=catalog, record=record,
                seed_key='catalog_prerequisites', seeded_surface_seams=seams,
                surface_seam_observations=[])
            wait = original_wait(namespace)
            if offered is complete:
                self.assertEqual(wait(b'CI_SEEDED_CAPTURE_DONE'), capture)
                retained = record['seeded_surface_seams']
                self.assertEqual(retained['schema'], 2)
                self.assertEqual(retained['holder_selection'], seams.HOLDER_SELECTION)
                self.assertEqual(len(retained['observations']), 8)
                self.assertNotIn('seeded_owner_page_seams', record)
            else:
                with self.assertRaises(restored.checkpoint.Refused):
                    wait(b'CI_SEEDED_CAPTURE_DONE')
                self.assertNotIn('seeded_surface_seams', record)

    def seed_prefix(self, count):
        return dict(schema=1, scope='observed_restored_seed_prefix', complete=False,
            confirmed=count, recipes=list(restored.seeds.IDS[:count]),
            journals_consistent=True, receipts_sha256='a'*64, seed_admitted=False)

    def test_confirmed_prefix_survives_a_later_failure_without_completing_reopen(self):
        trace = restored.ReopenDiagnostic()
        trace.at('seed_workflow')
        trace.confirmed_prefix(self.seed_prefix(1))
        trace.confirmed_prefix(self.seed_prefix(2))
        trace.observe_line(b'CI_REOPEN_ERROR:seed_token\n')
        trace.failure(ValueError('Synthetic later recipe failure'))
        value = trace.snapshot()
        self.assertEqual(value['seed_prefix'], self.seed_prefix(2))
        self.assertEqual(value['child_phase'], 'seed_token')
        partial = restored.project(dict(schema=1, scope=restored.SCOPE,
            complete=False, diagnostic=value))
        self.assertFalse(partial['complete'])
        self.assertFalse(partial['diagnostic']['seed_prefix']['seed_admitted'])

    def test_prefix_phase_order_and_failure_guards_do_not_grant_new_work(self):
        trace = restored.ReopenDiagnostic()
        with self.assertRaises(restored.checkpoint.Refused):
            trace.confirmed_prefix(self.seed_prefix(1))
        trace.at('seed_workflow')
        trace.confirmed_prefix(self.seed_prefix(1))
        for count in (1, 3):
            with self.subTest(count=count), self.assertRaises(restored.checkpoint.Refused):
                trace.confirmed_prefix(self.seed_prefix(count))
        for change in (dict(phase='pre_input'),
                dict(seed_prefix=dict(self.seed_prefix(1), wallet='private'))):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.diagnostic_projection(dict(trace.snapshot(), **change))
        trace.snapshot()['seed_prefix']['recipes'].clear()
        self.assertEqual(trace.snapshot()['seed_prefix']['recipes'], ['stake'])
        trace.failure(ValueError('Synthetic held observation'))
        with self.assertRaises(restored.checkpoint.Refused):
            trace.confirmed_prefix(self.seed_prefix(2))
        self.assertEqual(trace.snapshot()['seed_prefix']['confirmed'], 1)

    def trace(self, raw=b'CI_REOPEN_ERROR:unlock\r\n'):
        trace = restored.ReopenDiagnostic()
        trace.at('unlock_and_observe')
        trace.observe_line(raw)
        return trace

    def test_child_phases_match_the_actual_entry_and_ordered_seed_recipes(self):
        source = Path('harness/bin/ci_wallet_reopen.dart').read_text()
        phases = set(re.findall(r"phase = '([a-z_-]+)'", source))
        phases.update('seed_' + name for name in restored.seeds.IDS)
        self.assertEqual(set(restored.CHILD_PHASES), phases)
        for phase in phases:
            raw = ('CI_REOPEN_ERROR:' + phase + '\r\n').encode()
            value = self.trace(raw).snapshot()
            self.assertEqual(value['child_phase'], phase)
            self.assertEqual(value['output'], dict(code='REOPEN_CHILD_REFUSED',
                bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()))
        capture = dict(schema=2, kind='restored_seeded_capture_failure',
            last_entered_step='scriptLine', screen='staking', theme='dark',
            line=5, reply='targetMissing')
        child = dict(schema=1, scope='owned_reopen_child_failure',
            phase='seeded_capture', kind='HARNESS_REFUSED', code=None,
            recipe=None, capture=capture)
        self.assertEqual(restored.child_failure_projection(child), child)
        with self.assertRaises(restored.checkpoint.Refused):
            restored.child_failure_projection(dict(child, phase='seed_token'))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.child_failure_projection(dict(child,
                capture=dict(capture, command='private')))
        draft = dict(capture, kind='restored_stake_draft_capture_failure',
                     screen='staking-new')
        detail = dict(capture, kind='restored_project_detail_capture_failure',
                      screen='az-project')
        for scoped in (draft, detail):
            self.assertEqual(restored.child_failure_projection(dict(child,
                capture=scoped))['capture'], scoped)
        for wrong in (dict(capture, screen='staking-new'),
                      dict(draft, screen='az-project'), dict(detail, screen='staking')):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(dict(child, capture=wrong))

    def test_ordinary_output_is_ignored_and_error_text_is_only_classified_and_hashed(self):
        trace = restored.ReopenDiagnostic()
        trace.observe_line(b'started an isolated fixture\n')
        self.assertIsNone(trace.snapshot()['output'])
        raw = b'Unhandled exception: synthetic private password and path\n'
        trace.observe_line(raw)
        value = trace.snapshot()
        self.assertEqual(value['output']['code'], 'UNHANDLED_EXCEPTION')
        self.assertEqual(value['output']['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertIsNone(value['child_phase'])
        self.assertNotIn('private', json.dumps(value))
        self.assertNotIn('password', json.dumps(value))

    def test_foreign_markers_fields_coercions_and_unknown_vocabulary_are_refused(self):
        for raw in (b'CI_REOPEN_ERROR:private\n',
                    b'CI_REOPEN_ERROR:unlock:private\n'):
            value = self.trace(raw).snapshot()
            self.assertIsNone(value['child_phase'])
            self.assertEqual(value['output']['code'], 'UNCLASSIFIED_OUTPUT')
        original = self.trace().snapshot()
        changes = [dict(original, private='fixture'), dict(original, schema=True),
            dict(original, phase='private'), dict(original, child_phase='private'),
            dict(original, error='private'), dict(original, code='private'),
            dict(original, output=dict(original['output'], bytes=True)),
            dict(original, output=dict(original['output'], sha256='private')),
            dict(original, output=dict(original['output'], raw='private'))]
        for value in changes:
            with self.subTest(fields=len(value)), self.assertRaises(restored.checkpoint.Refused):
                restored.diagnostic_projection(value)

    def test_error_categories_never_format_the_original_exception(self):
        class Unformattable(Exception):
            def __str__(self):
                raise AssertionError('private error must not be formatted')
        for error, expected in (
                (restored.checkpoint.Refused(), 'CHECKPOINT_REFUSED'),
                (TypeError('private'), 'TYPE_ERROR'),
                (KeyError('private'), 'KEY_ERROR'),
                (OSError('private'), 'OS_ERROR'),
                (ValueError('private'), 'VALUE_ERROR'),
                (KeyboardInterrupt('private'), 'INTERRUPTED'),
                (Unformattable('private'), 'OTHER_ERROR')):
            trace = restored.ReopenDiagnostic()
            trace.failure(error)
            self.assertEqual(trace.snapshot()['error'], expected)
            self.assertIsNone(trace.snapshot()['code'])
            self.assertNotIn('private', json.dumps(trace.snapshot()))

    def test_domain_codes_require_the_exact_known_exception_and_allowlist(self):
        for error, category, code in (
                (lab.Failure('PORT_CONFLICT'), 'LAB_REFUSED', 'PORT_CONFLICT'),
                (restored.debug.ProcessRefused('CLOSE_UNCONFIRMED'),
                 'PROCESS_REFUSED', 'CLOSE_UNCONFIRMED')):
            trace = restored.ReopenDiagnostic()
            trace.failure(error)
            self.assertEqual(trace.snapshot()['error'], category)
            self.assertEqual(trace.snapshot()['code'], code)
        error = lab.Failure('PORT_CONFLICT')
        error.code = 'private'
        for error in (error, restored.debug.ProcessRefused('private')):
            trace = restored.ReopenDiagnostic()
            trace.failure(error)
            self.assertIsNone(trace.snapshot()['code'])
            self.assertNotIn('private', json.dumps(trace.snapshot()))
        value = self.trace().snapshot()
        with self.assertRaises(restored.checkpoint.Refused):
            restored.diagnostic_projection(dict(value, error='OS_ERROR',
                code='CLOSE_UNCONFIRMED'))

    def test_first_output_error_and_snapshots_keep_their_original_values(self):
        trace = self.trace()
        first = trace.snapshot()
        edited = trace.snapshot()
        edited['output']['bytes'] = 1
        trace.observe_line(b'CI_REOPEN_ERROR:finish\n')
        self.assertEqual(trace.snapshot(), first)
        trace.failure(TypeError('private'))
        trace.failure(KeyError('private'))
        self.assertEqual(trace.snapshot()['error'], 'TYPE_ERROR')
        with self.assertRaises(restored.checkpoint.Refused):
            trace.at('start')
        self.assertEqual(trace.snapshot()['phase'], first['phase'])

    def test_original_wire_refusals_keep_only_allowlisted_codes(self):
        error = lab.wire_policy.Refused('RPC_REFUSED')
        trace = restored.ReopenDiagnostic()
        trace.failure(error)
        self.assertEqual(trace.snapshot()['error'], 'WIRE_REFUSED')
        self.assertEqual(trace.snapshot()['code'], 'RPC_REFUSED')
        error.code = 'private'
        trace = restored.ReopenDiagnostic()
        trace.failure(error)
        self.assertIsNone(trace.snapshot()['code'])
        self.assertNotIn('private', json.dumps(trace.snapshot()))
        class Foreign(lab.wire_policy.Refused):
            pass
        trace = restored.ReopenDiagnostic()
        trace.failure(Foreign('RPC_REFUSED'))
        self.assertEqual(trace.snapshot()['error'], 'OTHER_ERROR')
        self.assertIsNone(trace.snapshot()['code'])
        with self.assertRaises(restored.checkpoint.Refused):
            restored.diagnostic_projection(dict(trace.snapshot(),
                error='WIRE_REFUSED', code='private'))

    def test_an_incomplete_diagnostic_cannot_supply_reopen_or_seed_authority(self):
        value = dict(schema=1, scope=restored.SCOPE, complete=False,
                     diagnostic=self.trace().snapshot())
        self.assertFalse(restored.project(value)['complete'])
        self.assertNotIn('seed_admitted', restored.project(value))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(value, wallet=wallet_observation()))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), diagnostic=value['diagnostic']))

    def test_output_bounds_and_invalid_phase_never_enter_a_snapshot(self):
        for raw in (None, '', b'', bytearray(b'fixture'),
                    b'a' * (restored.debug.protocol.MAX_LINE + 2)):
            trace = restored.ReopenDiagnostic()
            with self.subTest(kind=type(raw).__name__), self.assertRaises(restored.checkpoint.Refused):
                trace.observe_line(raw)
            self.assertIsNone(trace.snapshot()['output'])
        trace = restored.ReopenDiagnostic()
        with self.assertRaises(restored.checkpoint.Refused):
            trace.at('private')
        self.assertEqual(trace.snapshot()['phase'], 'admission')

    def test_closed_child_failure_vocabulary_matches_the_dart_formatter(self):
        source = Path('harness/bin/ci_wallet_reopen.dart').read_text()
        for name, expected in (
                ('restoredChildPhases', set(restored.CHILD_PHASES)),
                ('restoredChildKinds', restored.CHILD_FAILURE_KINDS),
                ('restoredWindowFailureCodes', restored.WINDOW_FAILURE_CODES),
                ('restoredUnlockFailureCodes', restored.UNLOCK_FAILURE_CODES),
                ('restoredRecipeExtraCodes', restored.CHILD_RECIPE_EXTRA_CODES)):
            match = re.search(r'const Set<String> ' + name
                + r' = <String>\{(.*?)\};', source, re.S)
            self.assertIsNotNone(match)
            values = re.findall(r"'([A-Za-z0-9_-]+)'", match[1])
            self.assertEqual(set(values), expected)
            self.assertEqual(len(values), len(expected))

    def test_original_child_failure_is_bound_and_cannot_be_replaced(self):
        child = dict(schema=1, scope='owned_reopen_child_failure', phase='startup',
            kind='RECIPE_REFUSED', code='wallet-recipe-restored-lock-required',
            recipe=dict(action='observe', control='none', reason='wallet-recipe-refused',
                entry='startup-before-initialization', startup='key-confirmed',
                film='skip-middle-frame-pending'))
        raw = b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\r\n'
        trace = self.trace(raw)
        first = trace.snapshot()
        self.assertEqual(first['child_failure'], child)
        self.assertEqual(first['child_phase'], 'startup')
        self.assertEqual(first['output'], dict(code='REOPEN_CHILD_REFUSED',
            bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()))
        changed = trace.snapshot()
        changed['child_failure']['recipe']['film'] = 'ended'
        trace.observe_line(b'CI_REOPEN_ERROR:unlock\n')
        self.assertEqual(trace.snapshot(), first)
        trace.failure(restored.checkpoint.Refused())
        value = dict(schema=1, scope=restored.SCOPE, complete=False,
            diagnostic=trace.snapshot())
        self.assertFalse(restored.project(value)['complete'])
        self.assertNotIn('seed_admitted', restored.project(value))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.project(dict(completed(), diagnostic=trace.snapshot()))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.diagnostic_projection(dict(first, child_phase='unlock'))
        self.assertNotIn('child_failure', self.trace().snapshot())
        for code in restored.UNLOCK_FAILURE_CODES:
            unlock = dict(schema=1, scope='owned_reopen_child_failure',
                phase='unlock', kind='HARNESS_REFUSED', code=code, recipe=None)
            self.assertEqual(restored.child_failure_projection(unlock), unlock)
            raw = b'CI_REOPEN_FAILURE:' + json.dumps(unlock).encode() + b'\n'
            trace = self.trace(raw)
            self.assertEqual(trace.snapshot()['child_failure'], unlock)
            for change in (dict(phase='startup'), dict(kind='FORMAT_ERROR'),
                    dict(code='private'), dict(recipe=dict(private='private'))):
                with self.subTest(code=code, change=change), \
                        self.assertRaises(restored.checkpoint.Refused):
                    restored.child_failure_projection(dict(unlock, **change))

    def test_lock_view_vocabulary_and_original_failure_are_preserved(self):
        source = Path('harness/lock_view_observation.dart').read_text()
        for name, expected in (
                ('lockViewBooleanFields', restored.LOCK_VIEW_BOOLEANS),
                ('lockViewLifecycles', restored.LOCK_VIEW_LIFECYCLES),
                ('lockViewStatuses', restored.LOCK_VIEW_STATUSES),
                ('lockViewUnlockPhases', restored.LOCK_VIEW_UNLOCK_PHASES)):
            match = re.search(r'const Set<String> ' + name
                + r' = <String>\{(.*?)\};', source, re.S)
            self.assertIsNotNone(match)
            self.assertEqual(set(re.findall(r"'([a-z_]+)'", match[1])), expected)
        child = dict(schema=1, scope='owned_reopen_child_failure', phase='unlock',
            kind='HARNESS_REFUSED', code='UNLOCK_WAIT_REFUSED', recipe=None,
            lock_view=lock_view_observation())
        raw = b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\n'
        trace = self.trace(raw)
        self.assertEqual(trace.snapshot()['child_failure'], child)
        result = dict(schema=1, scope=restored.SCOPE, complete=False,
            diagnostic=trace.snapshot())
        self.assertFalse(restored.project(result)['complete'])
        self.assertNotIn('wallet', restored.project(result))
        for status in restored.LOCK_VIEW_STATUSES - {'observed'}:
            observation = dict(schema=1, status=status, owner_same=False, view=None)
            self.assertEqual(restored.lock_view_projection(observation), observation)

    def test_private_or_invalid_lock_observations_are_only_hashed(self):
        child = dict(schema=1, scope='owned_reopen_child_failure', phase='unlock',
            kind='HARNESS_REFUSED', code='UNLOCK_WAIT_REFUSED', recipe=None,
            lock_view=lock_view_observation())
        values = [dict(child, phase='startup'), dict(child, kind='FORMAT_ERROR'),
            dict(child, lock_view=dict(lock_view_observation(), private='private')),
            dict(child, lock_view=dict(lock_view_observation(), schema=True)),
            dict(child, lock_view=dict(lock_view_observation(), status='private')),
            dict(child, lock_view=dict(lock_view_observation(), owner_same=False)),
            dict(child, lock_view=dict(lock_view_observation(), view=None))]
        for change in (dict(private='private'), dict(busy=1),
                dict(password_failures=True), dict(password_failures=-1),
                dict(password_failures=256), dict(lifecycle='private')):
            observation = lock_view_observation()
            observation['view'].update(change)
            values.append(dict(child, lock_view=observation))
        for value in values:
            with self.subTest(fields=len(value)), \
                    self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(value)
            raw = b'CI_REOPEN_FAILURE:' + json.dumps(value).encode() + b'\n'
            result = self.trace(raw).snapshot()
            self.assertNotIn('child_failure', result)
            self.assertEqual(result['output']['code'], 'UNCLASSIFIED_OUTPUT')
            self.assertEqual(result['output']['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertNotIn('private', json.dumps(result))

    def test_paired_unlock_progress_never_completes_original_authentication(self):
        for phase in restored.LOCK_VIEW_UNLOCK_PHASES:
            for count in (0, 1, 255):
                observation = lock_view_observation()
                observation['view'].update(unlock_phase=phase, unlock_requests=count)
                child = dict(schema=1, scope='owned_reopen_child_failure', phase='unlock',
                    kind='HARNESS_REFUSED', code='UNLOCK_WAIT_REFUSED', recipe=None,
                    lock_view=observation)
                raw = b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\n'
                with self.subTest(phase=phase, count=count):
                    trace = self.trace(raw).snapshot()
                    self.assertEqual(trace['child_failure'], child)
                    result = restored.project(dict(schema=1, scope=restored.SCOPE,
                        complete=False, diagnostic=trace))
                    self.assertFalse(result['complete'])
                    self.assertNotIn('wallet', result)
                    self.assertNotIn('seed_admitted', result)

    def test_unknown_partial_or_private_unlock_progress_is_only_hashed(self):
        changes = [dict(unlock_phase='idle'), dict(unlock_requests=1),
            dict(unlock_phase='private', unlock_requests=1),
            dict(unlock_phase='entered', unlock_requests=True),
            dict(unlock_phase='entered', unlock_requests=-1),
            dict(unlock_phase='entered', unlock_requests=256),
            dict(unlock_phase='entered', unlock_requests='private'),
            dict(unlock_phase='entered', unlock_requests=1, password='private')]
        for change in changes:
            observation = lock_view_observation()
            observation['view'].update(change)
            child = dict(schema=1, scope='owned_reopen_child_failure', phase='unlock',
                kind='HARNESS_REFUSED', code='UNLOCK_WAIT_REFUSED', recipe=None,
                lock_view=observation)
            with self.subTest(fields=set(change)), self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(child)
            raw = b'CI_REOPEN_FAILURE:' + json.dumps(child).encode() + b'\n'
            result = self.trace(raw).snapshot()
            self.assertNotIn('child_failure', result)
            self.assertEqual(result['output']['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertNotIn('private', json.dumps(result))

    def test_private_or_unlisted_child_failure_fields_are_only_hashed(self):
        child = dict(schema=1, scope='owned_reopen_child_failure',
            phase='startup_window', kind='WINDOW_REFUSED',
            code='WINDOW_CLIENT_REFUSED', recipe=None)
        values = [dict(child, private='private'), dict(child, schema=True),
            dict(child, phase='private'), dict(child, phase='startup'),
            dict(child, kind='private'), dict(child, code='private'),
            dict(child, code=None), dict(child, recipe=dict(private='private')),
            dict(child, kind='FORMAT_ERROR', code='WINDOW_CLIENT_REFUSED'),
            dict(child, kind='RECIPE_REFUSED', code='private'),
            dict(child, kind='RECIPE_REFUSED', code=None,
                recipe=dict(action='observe', control='none',
                    reason='wallet-recipe-refused', private='private'))]
        for value in values:
            with self.subTest(kind=value['kind']), self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(value)
            raw = b'CI_REOPEN_FAILURE:' + json.dumps(value).encode() + b'\n'
            result = self.trace(raw).snapshot()
            self.assertIsNone(result['child_phase'])
            self.assertNotIn('child_failure', result)
            self.assertEqual(result['output']['code'], 'UNCLASSIFIED_OUTPUT')
            self.assertEqual(result['output']['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertNotIn('private', json.dumps(result))


class NoticeTests(unittest.TestCase):
    def test_small_legacy_notices_keep_their_exact_facts(self):
        value = dict(scope='synthetic_observation', source_sha='a'*40,
                     success=False, wallet_reopen=None)
        self.assertEqual(restored.notice_frames(value), [('', value)])

    def test_large_notices_keep_every_component_in_parent_bound_finite_frames(self):
        value = dict(scope='synthetic_observation', source_sha='a'*40, run_id=123,
                     codes=['SYNTHETIC_FINITE']*175, wallet_reopen=completed())
        self.assertGreater(len(json.dumps(value, separators=(',', ':')).encode()), 3800)
        frames = restored.notice_frames(value)
        self.assertEqual(len(frames), 2)
        primary = frames[0][1]
        child = frames[1][1]
        digest = hashlib.sha256(json.dumps(primary, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(child['parent_notice_sha256'], digest)
        self.assertEqual(child['components'], ['wallet_reopen'])
        self.assertEqual(dict(primary, wallet_reopen=child['facts']), value)
        self.assertTrue(all(len(json.dumps(frame, sort_keys=True, separators=(',', ':')).encode()) <= 3800
                            for _, frame in frames))

    def test_private_component_fields_refuse_even_in_a_short_notice(self):
        value = dict(scope='synthetic_observation', wallet_reopen=dict(completed(), path='private'))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.notice_frames(value)

    def test_an_oversized_primary_refuses_without_truncating_its_facts(self):
        value = dict(scope='synthetic_observation', codes=['SYNTHETIC_FINITE']*300,
                     wallet_reopen=completed())
        with self.assertRaises(restored.checkpoint.Refused):
            restored.notice_frames(value)


class OutputTests(unittest.TestCase):
    def test_one_original_pipe_is_preserved_exactly_without_public_text(self):
        raw = b'synthetic private path\nfinite marker\n'
        target = io.BytesIO()
        capture = restored._CapturedOutput(io.BytesIO(raw), target.write)
        result = bytearray()
        while True:
            part = capture.readline(7)
            if not part:
                break
            result.extend(part)
        self.assertEqual(bytes(result), raw)
        self.assertEqual(target.getvalue(), raw)
        self.assertEqual(capture.digest.hexdigest(), hashlib.sha256(raw).hexdigest())
        self.assertFalse(capture.overflow)

    def test_overflow_retains_the_exact_bounded_prefix_and_drains_the_original(self):
        raw = b'synthetic full original\n'
        target = io.BytesIO()
        capture = restored._CapturedOutput(io.BytesIO(raw), target.write, cap=8)
        observed = bytearray()
        while True:
            part = capture.readline(5)
            if not part:
                break
            observed.extend(part)
        self.assertEqual(bytes(observed), raw)
        self.assertEqual(target.getvalue(), raw[:8])
        self.assertEqual(capture.bytes, 8)
        self.assertTrue(capture.overflow)

    def test_failed_capture_write_refuses_without_a_second_reader_or_retry(self):
        source = io.BytesIO(b'original\n')
        write = mock.Mock(return_value=0)
        capture = restored._CapturedOutput(source, write)
        with self.assertRaises(restored.checkpoint.Refused):
            capture.readline(20)
        write.assert_called_once_with(b'original\n')
        self.assertEqual(capture.bytes, 0)


def momentum(height, stamp, digit):
    return dict(chainIdentifier=321, height=height, timestamp=stamp, hash=digit*64)


class ChainPolicyTests(unittest.TestCase):
    def test_advancing_reopened_observation_uses_the_aggregate_sampler(self):
        http, ws = mock.Mock(), mock.Mock()
        genesis, first, last = momentum(1, 10, '1'), momentum(10, 100, '2'), momentum(11, 110, '3')
        http.call.side_effect = [dict(list=[genesis]), first, last]
        ws.call.side_effect = [genesis, last]
        measure = mock.Mock()
        with mock.patch.object(lab.socket, 'create_connection', return_value=mock.MagicMock()), \
                mock.patch.object(lab, 'make_transports', return_value=(object(), object())), \
                mock.patch.object(lab.wire_policy, 'HttpRpc', return_value=http), \
                mock.patch.object(lab.wire_policy, 'WsRpc', return_value=ws), \
                mock.patch.object(lab, 'sample_storage', side_effect=AssertionError('partial sample')):
            result = lab.observe(mock.Mock(), Path('/fixture'), measure=measure)
        self.assertEqual(measure.call_count, 2)
        self.assertEqual(result['last_height'], 11)

    def test_a_refused_aggregate_sample_stops_before_new_rpc_allocation(self):
        with mock.patch.object(lab, 'make_transports') as allocate:
            with self.assertRaises(lab.Failure):
                lab.observe(mock.Mock(), Path('/fixture'),
                    measure=mock.Mock(side_effect=lab.Failure('STORAGE_REFUSED')))
        allocate.assert_not_called()

    def run_read(self, *, expected=True, changed=None, ws_wrong=False,
                 close_error=False, original_error=False):
        original_runtime = lab.Native(mock.Mock(), Path('/fixture/node'), {})
        runtime = lab.Native(mock.Mock(), Path('/fixture/node'), {})
        genesis, anchor, frontier = momentum(1, 10, '1'), momentum(10, 100, '2'), momentum(11, 110, '3')
        witness = restored._ChainAnchor(original_runtime,
            lab.wire_policy.Momentum.parse(genesis), lab.wire_policy.Momentum.parse(anchor))
        values = dict(genesis=genesis, anchor=anchor, frontier=frontier)
        if changed:
            for key, value in changed.items():
                values[key] = dict(values[key], **value)
        http, ws = mock.Mock(), mock.Mock()
        def http_call(method, params):
            if method == 'ledger.getFrontierMomentum':
                return values['frontier']
            self.assertEqual(method, 'ledger.getMomentumsByHeight')
            return dict(list=[values['genesis'] if params[0] == 1 else values['anchor']])
        def ws_call(method, params):
            self.assertEqual(method, 'ledger.getMomentumByHash')
            value = next((item for item in values.values() if item['hash'] == params[0]), None)
            return dict(value, timestamp=999) if ws_wrong and value is not None else value
        Http, Ws = lab.wire_policy.HttpRpc, lab.wire_policy.WsRpc
        def admitted_factory(cls, target, respond):
            def create(*args, **kwargs):
                admission = cls(*args, **kwargs)
                target.admission = admission
                def call(method, params):
                    admission._payload(method, params)
                    return respond(method, params)
                target.call.side_effect = call
                return target
            return create
        first_error = lab.wire_policy.Refused('WS_REFUSED')
        if original_error:
            ws.connect.side_effect = first_error
        if close_error:
            ws.close.side_effect = lab.wire_policy.Refused('CLOSE_UNKNOWN')
        with mock.patch.object(runtime, 'healthy'), \
                mock.patch.object(lab, 'make_transports', return_value=(object(), object())), \
                mock.patch.object(lab.wire_policy, 'HttpRpc',
                    side_effect=admitted_factory(Http, http, http_call)), \
                mock.patch.object(lab.wire_policy, 'WsRpc',
                    side_effect=admitted_factory(Ws, ws, ws_call)):
            try:
                result = restored.chain_read(runtime, witness if expected else None)
            except Exception as error:
                result = error
        ws.close.assert_called_once_with()
        http.close.assert_called_once_with()
        return result, runtime, first_error, http, ws

    def test_the_exact_old_momentum_and_genesis_survive_in_a_new_advancing_chain(self):
        value, runtime, _, http, ws = self.run_read()
        self.assertIsInstance(value, restored._ChainAnchor)
        self.assertIs(value.owner, runtime)
        self.assertEqual(value.frontier.height, 11)
        self.assertTrue(all(call.args[0].startswith('ledger.get')
                            for call in http.call.call_args_list + ws.call.call_args_list))

    def test_retained_continuity_uses_the_actual_admission_and_original_height(self):
        value, runtime, _, http, ws = self.run_read()
        self.assertIsInstance(value, restored._ChainAnchor)
        self.assertIs(value.owner, runtime)
        heights = [call.args[1] for call in http.call.call_args_list
                   if call.args[0] == 'ledger.getMomentumsByHeight']
        self.assertEqual(heights, [[1, 1], [10, 1]])
        ws.call.assert_any_call('ledger.getMomentumByHash', ['2' * 64])

    def test_retained_http_scope_does_not_admit_other_heights_counts_or_ws_scope(self):
        value, _, _, http, ws = self.run_read()
        self.assertIsInstance(value, restored._ChainAnchor)
        for params in ([11, 1], [9, 1], [10, 2], [True, 1]):
            with self.subTest(params=params), self.assertRaises(lab.wire_policy.Refused):
                http.admission._payload('ledger.getMomentumsByHeight', params)
        with self.assertRaises(lab.wire_policy.Refused):
            ws.admission._payload('ledger.getMomentumsByHeight', [10, 1])

    def test_initial_anchor_is_captured_without_a_prior_report(self):
        value, runtime, _, _, _ = self.run_read(expected=False)
        self.assertIs(value.owner, runtime)

    def test_matching_heights_or_new_frontiers_cannot_replace_the_original_hash(self):
        for changes in (dict(anchor=dict(hash='4'*64)), dict(genesis=dict(hash='5'*64)),
                        dict(frontier=dict(height=9, timestamp=90)),
                        dict(frontier=dict(height=10, timestamp=100, hash='2'*64)),
                        dict(frontier=dict(timestamp=99))):
            with self.subTest(changes=changes):
                value, *_ = self.run_read(changed=changes)
                self.assertIsInstance(value, Exception)

    def test_cross_transport_disagreement_is_not_continuity(self):
        value, *_ = self.run_read(ws_wrong=True)
        self.assertIsInstance(value, Exception)

    def test_a_failed_transport_close_refuses_after_good_rpc_replies(self):
        value, *_ = self.run_read(close_error=True)
        self.assertIsInstance(value, restored.checkpoint.Refused)

    def test_cleanup_keeps_the_first_original_rpc_failure(self):
        value, _, original_error, _, _ = self.run_read(close_error=True, original_error=True)
        self.assertIs(value, original_error)

    def test_saved_data_refuses_before_new_rpc_transport_creation(self):
        runtime = lab.Native(mock.Mock(), Path('/fixture/node'), {})
        with mock.patch.object(runtime, 'healthy'), \
                mock.patch.object(lab, 'make_transports') as create:
            with self.assertRaises(restored.checkpoint.Refused):
                restored.chain_read(runtime, dict(hash='2'*64, height=10))
        create.assert_not_called()


class HandoffTests(unittest.TestCase):
    def wallet(self):
        home = PureWindowsPath(r'C:\fixture\.harness') / ('ci-wallet-'+'1'*24)
        value = dict(schema=1, scope='private_owned_wallet_origin',
            profile=home.name, home=str(home), wallet=str(home / 'wallet/one.json'),
            cache=str(home / 'cache'), members=['synthetic-zero', 'synthetic-one'],
            selected='synthetic-one', saved='synthetic-one', send_hash='a'*64,
            send_token='zts1znnxxxxxxxxxxxxx9z4ulx', send_amount='100000000',
            node='ws://127.0.0.1:45998', chain=321)
        parsed = origin.parse(value, str(home))
        entry = mock.Mock(poll=mock.Mock(return_value=None))
        quiet = dict(schema=1, scope='owned_lab_quiescence', chain=321, complete=True,
            admission_closed=True, original_send_confirmed=True, originals_positive=True,
            file_operations=1, sdk_publications=1, receive_reads=0, receive_publications=0)
        handoff = tour._QuiescenceHandoff(entry, quiet, parsed)
        entry.poll.return_value = 0
        return tour._ClosedWallet(home, entry, (1, 2), 'synthetic-private-input',
                                 (), (3, 4), handoff)

    def test_only_one_reopen_claim_follows_the_original_checkpoint_claim(self):
        wallet = self.wallet()
        with mock.patch.object(wallet, 'closed', return_value=True):
            with self.assertRaises(tour.Refused):
                wallet.claim_reopen()
            wallet.claim_checkpoint()
            wallet.claim_reopen()
            with self.assertRaises(tour.Refused):
                wallet.claim_reopen()

    def test_private_input_is_one_attempt_and_retains_the_exact_original_hash(self):
        wallet = self.wallet()
        home = wallet.home.parent / ('ci-wallet-'+'2'*24)
        with mock.patch.object(wallet, 'closed', return_value=True):
            wallet.claim_checkpoint()
            wallet.claim_reopen()
            value = wallet.reopen_input(home)
            self.assertEqual(set(value), {'password', 'originalProfile', 'wallet', 'members', 'hash'})
            self.assertEqual(value['hash'], 'a'*64)
            self.assertEqual(value['originalProfile'], wallet.home.name)
            with self.assertRaises(tour.Refused):
                wallet.reopen_input(home)
        self.assertNotIn('synthetic', repr(wallet))

    def test_invalid_or_lost_owned_input_is_held_without_a_second_attempt(self):
        wallet = self.wallet()
        with mock.patch.object(wallet, 'closed', return_value=True):
            wallet.claim_checkpoint()
            wallet.claim_reopen()
            with self.assertRaises(origin.Refused):
                wallet.reopen_input(wallet.home)
            with self.assertRaises(tour.Refused):
                wallet.reopen_input(wallet.home.parent / ('ci-wallet-'+'2'*24))

    def test_legacy_observations_cannot_claim_reopened_ownership(self):
        wallet = self.wallet()
        wallet._quiescence._origin = None
        wallet._checkpoint_claimed = True
        with mock.patch.object(wallet, 'closed', return_value=True):
            with self.assertRaises(tour.Refused):
                wallet.claim_reopen()
        self.assertFalse(wallet._reopen_claimed)


class FilesystemTests(unittest.TestCase):
    def fixture(self, root):
        source, copied, retained = (Path(root) / name for name in ('original.json', 'copy.json', 'retained.json'))
        raw = json.dumps(dict(mode='release', harnessMode='wallet', token='a'*32,
                              pid=123, port=12345)).encode()
        source.write_bytes(raw)
        copied.write_bytes(raw)
        return source, copied, retained, raw

    def test_retirement_preserves_original_and_exact_copied_metadata_identity(self):
        with tempfile.TemporaryDirectory(prefix='syrius-reopen-metadata-') as root:
            source, copied, retained, raw = self.fixture(root)
            old = restored.checkpoint.file_identity(copied.lstat())
            value, original_pin, copied_pin = restored.retire_metadata(
                source, copied, retained, lambda: True, time.monotonic()+10)
            self.assertEqual(value['token'], 'a'*32)
            self.assertEqual(source.read_bytes(), raw)
            self.assertEqual(retained.read_bytes(), raw)
            self.assertEqual(copied_pin[0], old)
            self.assertEqual(original_pin[1], copied_pin[1])
            self.assertFalse(copied.exists())

    def test_existing_retained_or_changed_metadata_refuses_without_overwrite(self):
        with tempfile.TemporaryDirectory(prefix='syrius-reopen-metadata-') as root:
            source, copied, retained, raw = self.fixture(root)
            retained.write_bytes(b'synthetic held metadata')
            with self.assertRaises(restored.checkpoint.Refused):
                restored.retire_metadata(source, copied, retained, lambda: True, time.monotonic()+10)
            self.assertEqual(copied.read_bytes(), raw)
            self.assertEqual(retained.read_bytes(), b'synthetic held metadata')
            retained.unlink()
            copied.write_bytes(raw+b' ')
            with self.assertRaises(restored.checkpoint.Refused):
                restored.retire_metadata(source, copied, retained, lambda: True, time.monotonic()+10)

    def test_lost_closure_refuses_before_the_metadata_is_moved(self):
        with tempfile.TemporaryDirectory(prefix='syrius-reopen-metadata-') as root:
            source, copied, retained, raw = self.fixture(root)
            with self.assertRaises(restored.checkpoint.Refused):
                restored.retire_metadata(source, copied, retained, lambda: False, time.monotonic()+10)
            self.assertEqual(source.read_bytes(), raw)
            self.assertEqual(copied.read_bytes(), raw)
            self.assertFalse(retained.exists())


class SeedFailureProjectionTests(unittest.TestCase):
    @staticmethod
    def home(**changes):
        value = dict(stage='railTogglePresence', target='home', state=dict(
            at='railReadiness', booted='yes', unlocked='yes',
            initialized='yes', tab='home'))
        value.update(changes)
        return value

    def test_original_home_stages_are_finite_copied_observations(self):
        source = Path('harness/home_preparation_observation.dart').read_text()
        match = re.search(r'enum HomePreparationStep\s*\{([^}]+)\}', source)
        self.assertIsNotNone(match)
        self.assertEqual(tuple(re.findall(r'\b[A-Za-z][A-Za-z0-9]*\b', match[1])),
                         restored.HOME_PREPARATION_STAGES)
        match = re.search(r'enum HomeTapReply\s*\{([^}]+)\}', source)
        self.assertIsNotNone(match)
        self.assertEqual(set(re.findall(r'\b[A-Za-z][A-Za-z0-9]*\b', match[1])),
                         restored.HOME_TAP_REPLIES)
        for code in restored.HOME_TAP_REPLIES:
            offered = self.home(stage='gotoTap', reply=code,
                state=self.home()['state'] | dict(at='gotoTarget'))
            self.assertEqual(restored.home_preparation_projection(offered), offered)
        for stage in restored.HOME_PREPARATION_STAGES:
            offered = dict(stage=stage)
            if stage != 'initialState':
                offered['state'] = self.home()['state'] | dict(at='initialReadiness')
            if restored.HOME_PREPARATION_STAGES.index(stage) >= 2:
                offered['target'] = 'dashboard'
            seed = self.seed(recipe='deposit', action='home', step='navigation',
                             home=offered)
            result = restored.seed_failure_projection(seed, 'seed_deposit')
            self.assertEqual(result, seed)
            self.assertIsNot(result['home'], offered)
            if 'state' in offered:
                self.assertIsNot(result['home']['state'], offered['state'])
                offered['state']['tab'] = 'private'
                self.assertEqual(result['home']['state']['tab'], 'home')
            self.assertEqual(restored.child_failure_projection(
                self.child(result))['seed'], result)
        legacy = self.seed(action='home', step='navigation')
        self.assertEqual(restored.seed_failure_projection(legacy, 'seed_stake'), legacy)
        self.assertEqual(len(legacy), 9)
        self.assertNotIn('home', legacy)

    def test_home_projection_refuses_unknown_coerced_private_or_future_state(self):
        values = [None, True, [], 'private', {},
            self.home(stage='private'), self.home(stage=True),
            self.home(target='private'), self.home(target=True),
            self.home(stage='initialState'), self.home(path='private'),
            self.home(state=True), self.home(state={'at': 'railReadiness'})]
        for change in (dict(at='finalReadiness'), dict(at='railWait'),
                dict(booted=True), dict(unlocked=1), dict(initialized=None),
                dict(tab='private'), dict(tab=True), dict(path='private')):
            values.append(self.home(state=self.home()['state'] | change))
        for key in self.home()['state']:
            values.append(self.home(state={name: value for name, value
                in self.home()['state'].items() if name != key}))
        for value in values:
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                restored.home_preparation_projection(value)
        tap = self.home(stage='gotoTap', reply='targetCovered',
            state=self.home()['state'] | dict(at='gotoTarget'))
        for change in (dict(reply='private'), dict(reply=True), dict(reply=None),
                dict(stage='gotoWait'), dict(state=self.home()['state'])):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.home_preparation_projection(tap | change)
        for missing in ('target', 'state'):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.home_preparation_projection({key: value
                    for key, value in tap.items() if key != missing})
        for flag in ('yes', 'no', 'unknown'):
            for tab in ('home', 'dashboard', 'lock', 'other', 'unknown'):
                value = self.home(state=self.home()['state'] | dict(
                    booted=flag, unlocked=flag, initialized=flag, tab=tab))
                self.assertEqual(restored.home_preparation_projection(value), value)

    def test_home_observations_cannot_relabel_a_later_operation_or_add_authority(self):
        for recipe in restored.SEED_FAILURE_RECIPES:
            value = self.seed(recipe=recipe, action='home', step='navigation',
                              home=self.home())
            self.assertEqual(restored.seed_failure_projection(value,
                'seed_' + recipe), value)
            value['home'] = self.home(stage='gotoTap', reply='targetCovered',
                state=self.home()['state'] | dict(at='gotoTarget'))
            self.assertEqual(restored.seed_failure_projection(value,
                'seed_' + recipe), value)
        for change in (dict(action='source', step='read'),
                dict(action='begin', step='reply'),
                dict(action='prepare', step='owner', command_index=1),
                dict(action='publish', step='reply', command_index=7,
                     publication_call_entered=True), dict(command_index=1),
                dict(publication_call_entered=True), dict(confirmation=self.counts()),
                dict(confirmed=True), dict(retry=True), dict(success=True)):
            value = self.seed(action='home', step='navigation', home=self.home())
            value.update(change)
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(value, 'seed_stake')
        value = self.seed(action='home', step='navigation', home=self.home())
        for phase in ('seed_fuse', 'unlock', 'seed_admission'):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(value, phase)

    @staticmethod
    def counts(**changes):
        value = dict(polls=18, absent=6, unconfirmed=6,
                     effect_pending=6, last='effect_pending')
        value.update(changes)
        return value

    def exhausted(self, **changes):
        return self.seed(recipe='fuse', action='publish', step='reply',
            command_index=7, publication_call_entered=True, kind='refused',
            reason='exact-confirmation-or-effect-pending',
            confirmation=self.counts(), **changes)

    def test_exhausted_original_seed_rounds_remain_copied_observations(self):
        for last in ('absent', 'unconfirmed', 'effect_pending'):
            offered = self.exhausted()
            offered['confirmation']['last'] = last
            result = restored.seed_failure_projection(offered, 'seed_fuse')
            self.assertEqual(result, offered)
            self.assertIsNot(result['confirmation'], offered['confirmation'])
            offered['confirmation']['absent'] = 0
            self.assertEqual(result['confirmation']['absent'], 6)
            child = self.child(result)
            self.assertEqual(restored.child_failure_projection(child)['seed'], result)
        legacy = self.seed()
        self.assertNotIn('confirmation', restored.seed_failure_projection(legacy, 'seed_stake'))
        for key in ('confirmed', 'complete', 'hash', 'retry', 'success', 'address'):
            self.assertNotIn(key, result['confirmation'])

    def test_seed_counts_refuse_unknown_coerced_missing_and_impossible_values(self):
        changes = (dict(polls=True), dict(polls=17), dict(absent=-1),
            dict(absent=19), dict(unconfirmed=6.0), dict(effect_pending=None),
            dict(effect_pending=5), dict(last='private'), dict(hash='private'),
            dict(path='private'), dict(absent=18, unconfirmed=0, effect_pending=0))
        for change in changes:
            offered = self.exhausted()
            offered['confirmation'] = self.counts(**change)
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(offered, 'seed_fuse')
        for key in self.counts():
            offered = self.exhausted()
            del offered['confirmation'][key]
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(offered, 'seed_fuse')
        for value in (None, True, [], 'private'):
            offered = self.exhausted()
            offered['confirmation'] = value
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(offered, 'seed_fuse')

    def test_funding_observation_requires_the_exact_negative_fund_reply(self):
        offered = self.exhausted()
        offered.update(recipe='fund-address', command_index=11)
        funding = dict(ledger='balance_pending', wallet_receive='pending',
                       paired_receive=False)
        offered['confirmation']['funding'] = funding
        result = restored.seed_failure_projection(offered, 'seed_fund-address')
        self.assertEqual(result, offered)
        self.assertIsNot(result['confirmation']['funding'], funding)
        self.assertEqual(restored.child_failure_projection(self.child(result))['seed'], result)
        for change in (dict(wallet_receive='private'), dict(ledger='confirmed'),
                dict(paired_receive=0), dict(hash='private'),
                dict(ledger='receive_pending', paired_receive=True)):
            invalid = dict(offered, confirmation=dict(offered['confirmation'],
                funding=dict(funding, **change)))
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(invalid, 'seed_fund-address')
        wrong_round = dict(offered, confirmation=dict(offered['confirmation'], last='absent'))
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(wrong_round, 'seed_fund-address')
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(dict(offered, recipe='fuse'), 'seed_fuse')

    def test_seed_counts_cannot_relabel_another_original_boundary(self):
        for change in (dict(action='check', step='owner'),
                dict(action='publish', step='request'), dict(reason='unknown'),
                dict(kind='timeout'), dict(publication_call_entered=False)):
            offered = self.exhausted()
            offered.update(change)
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(offered, 'seed_fuse')
        offered = self.exhausted()
        for phase in ('seed_stake', 'unlock', 'seed_admission'):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(offered, phase)

    @staticmethod
    def seed(**changes):
        value = dict(schema=1, scope='original_seed_operation_failure',
            recipe='stake', action='begin', step='reply', command_index=0,
            publication_call_entered=False, kind='refused', reason='unknown')
        value.update(changes)
        return value

    @staticmethod
    def child(seed, **changes):
        value = dict(schema=1, scope='owned_reopen_child_failure',
            phase='seed_' + seed['recipe'], kind='HARNESS_REFUSED',
            code=None, recipe=None, seed=seed)
        value.update(changes)
        return value

    @staticmethod
    def frontier(ws=True, http=False, **changes):
        value = dict(polls=6)
        for endpoint, advanced in (('ws', ws), ('http', http)):
            value.update({endpoint + '_first_height': 11 if advanced else 10,
                endpoint + '_last_height': 17 if advanced else 10,
                endpoint + '_first_timestamp': 101 if advanced else 100,
                endpoint + '_last_timestamp': 107 if advanced else 100,
                endpoint + '_hash_changed': advanced})
        value.update(changes)
        return value

    def test_original_frontier_samples_survive_child_projection_without_authority(self):
        for ws, http in ((True, False), (False, True), (False, False)):
            offered = self.seed(action='publish', step='reply', command_index=8,
                publication_call_entered=True, reason='advancing-momentum-required',
                frontier=self.frontier(ws, http))
            result = restored.seed_failure_projection(offered, 'seed_stake')
            self.assertEqual(result, offered)
            self.assertIsNot(result['frontier'], offered['frontier'])
            offered['frontier']['ws_first_height'] = 0
            self.assertGreater(result['frontier']['ws_first_height'], 0)
            self.assertEqual(restored.child_failure_projection(
                self.child(result))['seed'], result)
            for field in ('hash', 'address', 'path', 'confirmed', 'retry', 'success'):
                self.assertNotIn(field, result)
                self.assertNotIn(field, result['frontier'])
        for flags in range(1, 8):
            offered = self.seed(recipe='deposit', action='publish', step='reply',
                command_index=12, publication_call_entered=True,
                reason='earlier-original-unresolved', originals=dict(
                    pending=bool(flags & 1), failed=bool(flags & 2),
                    release_failed=bool(flags & 4)))
            result = restored.seed_failure_projection(offered, 'seed_deposit')
            self.assertEqual(result, offered)
            self.assertIsNot(result['originals'], offered['originals'])
            offered['originals'].clear()
            self.assertTrue(any(result['originals'].values()))
            child = self.child(result, phase='seed_deposit')
            self.assertEqual(restored.child_failure_projection(child)['seed'],
                             result)

    def test_frontier_samples_refuse_private_coerced_inconsistent_or_misplaced_data(self):
        original = self.seed(action='publish', step='reply', command_index=8,
            publication_call_entered=True, reason='advancing-momentum-required',
            frontier=self.frontier())
        changes = (dict(polls=True), dict(polls=5), dict(ws_first_height=0),
            dict(ws_last_height=9), dict(http_last_height=9007199254740992),
            dict(ws_last_timestamp=107.0), dict(http_first_timestamp=None),
            dict(ws_hash_changed=1), dict(http_hash_changed=True),
            dict(hash='Synthetic private value'), dict(path='Synthetic'),
            dict(address='Synthetic'), dict(confirmed=True), dict(retry=True))
        values = [original['frontier'] | change for change in changes]
        values += [{key: value for key, value in original['frontier'].items()
                    if key != missing} for missing in original['frontier']]
        values += [None, True, [], 'Synthetic', self.frontier(True, True)]
        for value in values:
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(original | dict(frontier=value),
                                                  'seed_stake')
        for change in (dict(action='begin', command_index=0,
                            publication_call_entered=False),
                dict(action='command', step='execute'), dict(step='request'),
                dict(publication_call_entered=False), dict(kind='timeout'),
                dict(reason='unknown'), dict(reason='exact-confirmation-or-effect-pending'),
                dict(confirmation=self.counts()), dict(home=self.home())):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(original | change, 'seed_stake')
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(original, 'seed_fuse')
        flags = dict(pending=True, failed=False, release_failed=False)
        original = self.seed(recipe='deposit', action='publish', step='reply',
            command_index=12, publication_call_entered=True,
            reason='earlier-original-unresolved', originals=flags)
        values = [None, True, [], 'Synthetic', dict.fromkeys(flags, False)]
        values += [flags | {key: value} for key in flags
                   for value in (1, 0, None, 'Synthetic')]
        values += [{key: value for key, value in flags.items() if key != missing}
                   for missing in flags]
        values += [flags | {key: 'Synthetic'} for key in
                   ('path', 'hash', 'address', 'retry', 'confirmed')]
        for value in values:
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(original | dict(originals=value),
                                                  'seed_deposit')
        for change in (dict(action='begin', command_index=0,
                            publication_call_entered=False),
                dict(action='command', step='execute'), dict(step='request'),
                dict(publication_call_entered=False), dict(kind='timeout'),
                dict(reason='unknown'), dict(reason='advancing-momentum-required'),
                dict(confirmation=self.counts()), dict(home=self.home()),
                dict(frontier=self.frontier())):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(original | change, 'seed_deposit')
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(original, 'seed_stake')

    def test_finite_original_boundaries_remain_observation_data(self):
        for recipe in restored.SEED_FAILURE_RECIPES:
            for action in restored.SEED_FAILURE_ACTIONS:
                steps = ({'read', 'parse', 'resolve'} if action == 'source' else
                         {'navigation'} if action == 'home' else
                         {'owner', 'execute'} if action == 'command' else
                         {'owner', 'request', 'reply'})
                for step in steps:
                    entered = action == 'finish' or action == 'publish' and step != 'owner'
                    index = 0 if action in ('source', 'begin', 'home', 'finish') else 5
                    offered = self.seed(recipe=recipe, action=action, step=step,
                        command_index=index, publication_call_entered=entered)
                    self.assertEqual(restored.seed_failure_projection(offered,
                        'seed_' + recipe), offered)
                    self.assertEqual(restored.child_failure_projection(
                        self.child(offered))['seed'], offered)
        for action in ('check', 'command'):
            offered = self.seed(action=action, step='owner', command_index=5,
                                publication_call_entered=True)
            self.assertEqual(restored.seed_failure_projection(offered,
                             'seed_stake'), offered)

        boundaries = [
            (index, 'command', step, False)
            for index in range(1, 7) for step in ('owner', 'execute')
        ] + [
            (7, 'command', 'execute', False),
            (7, 'publish', 'owner', False),
            (7, 'publish', 'request', True),
            (7, 'publish', 'reply', True),
            (8, 'command', 'owner', True),
        ]
        for index, action, step, entered in boundaries:
            offered = self.seed(recipe='pillar-qsr', action=action, step=step,
                command_index=index, publication_call_entered=entered)
            with self.subTest(boundary=(index, action, step, entered)):
                self.assertEqual(restored.child_failure_projection(
                    self.child(offered))['seed'], offered)
                with self.assertRaises(restored.checkpoint.Refused):
                    restored.seed_failure_projection(offered, 'seed_deposit')
                with self.assertRaises(restored.checkpoint.Refused):
                    restored.seed_failure_projection(
                        offered | {'publication_call_entered': not entered},
                        'seed_pillar-qsr')
        for action, step, index in (('command', 'owner', 7),
                                    ('command', 'execute', 8),
                                    ('publish', 'reply', 6),
                                    ('prepare', 'reply', 3),
                                    ('home', 'navigation', 0)):
            with self.subTest(action=action, step=step, index=index):
                with self.assertRaises(restored.checkpoint.Refused):
                    restored.seed_failure_projection(self.seed(
                        recipe='pillar-qsr', action=action, step=step,
                        command_index=index,
                        publication_call_entered=action == 'publish'),
                        'seed_pillar-qsr')

    def test_private_unknown_coerced_or_unbounded_metadata_is_refused(self):
        for change in (dict(schema=True), dict(schema=2), dict(scope='private'),
                dict(recipe='private'), dict(recipe=True), dict(action='private'),
                dict(step='private'), dict(command_index=True), dict(command_index=-1),
                dict(command_index=97), dict(publication_call_entered=1),
                dict(kind='private'), dict(kind=True), dict(reason='private'),
                dict(path='private'), dict(message='private'), dict(stack='private'),
                dict(args=['private']), dict(address='private')):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(self.seed(**change), 'seed_stake')
        original = self.seed()
        for key in original:
            with self.subTest(missing=key), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection({name: value for name, value
                    in original.items() if name != key}, 'seed_stake')
        for value in (None, True, [], 'private'):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(value, 'seed_stake')

    def test_recipe_phase_and_original_call_boundaries_cannot_be_relabelled(self):
        for phase in ('unlock', 'seed_admission', 'seed_fuse', True, None):
            with self.subTest(phase=phase), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(self.seed(), phase)
        changes = (
            dict(action='source', step='read', publication_call_entered=True),
            dict(action='home', step='navigation', publication_call_entered=True),
            dict(action='prepare', step='owner', command_index=5,
                 publication_call_entered=True),
            dict(action='publish', step='owner', command_index=5,
                 publication_call_entered=True),
            dict(action='publish', step='request', command_index=5),
            dict(action='finish', step='request'),
            dict(action='command', step='execute', command_index=0),
            dict(action='source', step='read', command_index=1),
            dict(action='begin', step='execute'),
        )
        for change in changes:
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(self.seed(**change), 'seed_stake')

    def test_only_canonical_source_codes_are_public_and_do_not_imply_success(self):
        for code in (*restored.SEED_REPLY_CODES, 'unknown'):
            prepared = dict(action='prepare', command_index=3) if code in (
                restored.SEED_PREPARATION_REPLY_CODES) else {}
            value = self.seed(reason=code, **prepared)
            self.assertEqual(restored.seed_failure_projection(value,
                             'seed_stake')['reason'], code)
        code = sorted(restored.SEED_REPLY_CODES)[0]
        for value in (code + ' ', code + '-private', 'Seed refused: ' + code):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(self.seed(reason=value), 'seed_stake')
        control_code = 'original-ui-control-changed'
        control = self.seed(recipe='deposit', action='publish', command_index=12,
                            publication_call_entered=True, reason=control_code)
        self.assertEqual(restored.seed_failure_projection(control,
                         'seed_deposit'), control)
        for changes in (dict(action='begin'), dict(command_index=0),
                        dict(publication_call_entered=False), dict(step='owner')):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(control | changes,
                                                  'seed_deposit')
        for value in (control_code + ' ', control_code + '-private',
                      'Seed refused: ' + control_code):
            with self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(control | dict(reason=value),
                                                  'seed_deposit')
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(self.seed(reason=code, kind='type'),
                                             'seed_stake')
        for key in ('confirmed', 'complete', 'hash', 'retry', 'seed_admitted',
                    'success', 'pointer_dispatched', 'sdk_entered', 'accepted'):
            with self.subTest(key=key), self.assertRaises(restored.checkpoint.Refused):
                restored.seed_failure_projection(self.seed(**{key: True}), 'seed_stake')

    def test_preparation_labels_preserve_only_original_negative_reply_scope(self):
        for code in restored.SEED_PREPARATION_REPLY_CODES:
            value = self.seed(action='prepare', command_index=3, reason=code)
            self.assertEqual(restored.seed_failure_projection(value, 'seed_stake'), value)
            child = restored.child_failure_projection(self.child(value))
            self.assertEqual(child['seed'], value)
            self.assertFalse(value['publication_call_entered'])
        helper = Path('harness/seed_preparation_failure.dart').read_text()
        match = re.search(r'seedPreparationUiFailureCodes = <String>\{([^}]+)\}', helper)
        self.assertIsNotNone(match)
        self.assertEqual(set(re.findall(r"'([a-z0-9-]+)'", match[1])),
                         set(restored.SEED_PREPARATION_REPLY_CODES))

    def test_preparation_labels_refuse_other_actions_input_or_private_fields(self):
        for code in restored.SEED_PREPARATION_REPLY_CODES:
            changes = (dict(action='begin', command_index=0),
                dict(action='check'), dict(action='publish', publication_call_entered=True),
                dict(action='finish', command_index=0, publication_call_entered=True),
                dict(step='request'), dict(publication_call_entered=True),
                dict(confirmed=True), dict(hash='private'), dict(message='private'))
            for change in changes:
                value = self.seed(action='prepare', command_index=3, reason=code)
                value.update(change)
                with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                    restored.seed_failure_projection(value, 'seed_stake')

    @staticmethod
    def stake_effect(**changes):
        value = dict(schema=1, scope='original_seed_stake_effect',
            reported_rows=0, returned_rows=0, scan='COMPLETE',
            id_matches=0, owner_matches=0, amount_matches=0, duration_matches=0)
        value.update(changes)
        return value

    def stake_failure(self, effect):
        return self.seed(recipe='stake', action='publish', step='reply',
            command_index=8, publication_call_entered=True, kind='refused',
            reason='exact-confirmation-or-effect-pending',
            confirmation=self.counts(absent=13, unconfirmed=0, effect_pending=5),
            stake_effect=effect)

    def test_stake_effect_counts_are_copied_negative_data_without_authority(self):
        unscanned = dict(schema=1, scope='original_seed_stake_effect',
            reported_rows=65, returned_rows=64, scan='NOT_RUN')
        values = [self.stake_effect(), unscanned,
            self.stake_effect(reported_rows=4, returned_rows=4, id_matches=3,
                owner_matches=2, amount_matches=1),
            self.stake_effect(reported_rows=2, returned_rows=2, id_matches=2,
                owner_matches=2, amount_matches=2, duration_matches=2)]
        for effect in values:
            offered = self.stake_failure(effect)
            projected = restored.seed_failure_projection(offered, 'seed_stake')
            self.assertEqual(projected, offered)
            self.assertIsNot(projected['stake_effect'], effect)
            self.assertEqual(restored.child_failure_projection(
                self.child(projected))['seed'], projected)
            effect['reported_rows'] = 100
            self.assertNotEqual(projected['stake_effect']['reported_rows'], 100)
            for key in ('hash', 'address', 'path', 'receipt', 'retry', 'confirmed'):
                self.assertNotIn(key, projected['stake_effect'])
        self.assertNotIn('stake_effect', restored.seed_failure_projection(
            self.exhausted(), 'seed_fuse'))

    def test_stake_effect_counts_refuse_unknown_coerced_or_positive_values(self):
        original = self.stake_effect()
        values = [None, True, [], 'Synthetic']
        values += [original | change for change in (
            dict(schema=True), dict(reported_rows=-1), dict(reported_rows=2**53),
            dict(returned_rows=65), dict(reported_rows=1), dict(scan='NOT_RUN'),
            dict(id_matches=True), dict(owner_matches=1), dict(id_matches=0.0),
            dict(reported_rows=1, returned_rows=1, id_matches=1, owner_matches=1,
                 amount_matches=1, duration_matches=1))]
        values += [original | {key: 'Synthetic private value'} for key in
                   ('hash', 'address', 'path', 'receipt', 'retry', 'exception')]
        values += [{key: item for key, item in original.items() if key != missing}
                   for missing in original]
        for effect in values:
            with self.subTest(effect=effect), self.assertRaises(
                    restored.checkpoint.Refused):
                restored.seed_failure_projection(self.stake_failure(effect),
                                                  'seed_stake')

    def test_stake_effect_snapshot_requires_its_same_last_reply_context(self):
        original = self.stake_failure(self.stake_effect())
        changes = (dict(recipe='fuse'), dict(step='request'),
            dict(publication_call_entered=False), dict(kind='timeout'),
            dict(reason='unknown'), dict(confirmation=self.counts(last='absent')),
            dict(confirmation=None), dict(frontier=self.frontier(True, False)))
        for change in changes:
            value = original | change
            phase = 'seed_' + value['recipe']
            with self.subTest(change=change), self.assertRaises(
                    restored.checkpoint.Refused):
                restored.seed_failure_projection(value, phase)
        del original['confirmation']
        with self.assertRaises(restored.checkpoint.Refused):
            restored.seed_failure_projection(original, 'seed_stake')

    def test_public_enum_and_reply_catalogs_match_the_actual_dart_source(self):
        source = Path('harness/bin/harness.dart').read_text()
        for name, expected in (
                ('SeedOperationAction', restored.SEED_FAILURE_ACTIONS),
                ('SeedOperationStep', restored.SEED_FAILURE_STEPS),
                ('SeedOperationFailureKind', restored.SEED_FAILURE_KINDS)):
            match = re.search(r'enum ' + name + r'\s*\{([^}]+)\}', source)
            self.assertIsNotNone(match)
            labels = set(re.findall(r'\b[A-Za-z][A-Za-z0-9]*\b', match[1]))
            self.assertEqual(labels, set(expected))
        match = re.search(r'seedOperationReplyCodes = <String>\{([^}]+)\}', source)
        self.assertIsNotNone(match)
        self.assertEqual(set(re.findall(r"'([a-z0-9-]+)'", match[1])),
                         set(restored.SEED_REPLY_CODES))
        self.assertIn('length > 96', Path('harness/seed/seed_recipe.dart').read_text())

    def test_child_projection_preserves_legacy_refusals_and_copies_failure_data(self):
        value = self.child(self.seed())
        projected = restored.child_failure_projection(value)
        value['seed']['reason'] = 'private'
        self.assertEqual(projected['seed']['reason'], 'unknown')
        for changes in (dict(phase='unlock'), dict(kind='TYPE_ERROR'),
                dict(code='UNLOCK_TAP_REFUSED'), dict(recipe=dict(private='private')),
                dict(lock_view=lock_view_observation()), dict(complete=True)):
            with self.subTest(change=changes), self.assertRaises(restored.checkpoint.Refused):
                restored.child_failure_projection(self.child(self.seed(), **changes))
        legacy = self.child(self.seed())
        del legacy['seed']
        self.assertEqual(restored.child_failure_projection(legacy), legacy)


if __name__ == '__main__':
    unittest.main()
