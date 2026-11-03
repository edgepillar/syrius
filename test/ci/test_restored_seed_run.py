"""Small memory-only cases; no signer, node, filesystem or network is used."""

import copy
import json
import unittest

from tool.ci import restored_seed_run as seeds
from tool.ci import restored_wallet_run as restored


def completed_reopen():
    # Test discovery need not import the repository's namespace as `test`.
    return dict(schema=1, scope=restored.SCOPE, complete=True, claim_once=True,
        originals_closed=True, chain_continuity=True, journal_unchanged=True,
        cipher_unchanged=True, wallet=dict(schema=1,
            scope='restored_lab_wallet_observation', chain=321, members=2,
            selected_index=1, membership_same=True, selection_saved=True,
            wallet_path_mapped=True, original_send_confirmed=True,
            journal_consistent=True, observation_stable=True),
        application_exit=0, entry_exit=0, output=dict(bytes=123, sha256='a'*64,
            output_complete=True, overflow=False), job_empty=True, forced=False,
        nodes=[dict(role=role, exit_code=0, output_complete=True, forced=False)
               for role in restored.checkpoint.ROLES[1:]],
        private_manifest_sha256='b'*64, seed_admitted=False)


def receipts():
    return dict(schema=1, scope='private_restored_seed_receipts', chain=321,
        members=3, selected_index=1, derived_once=True, owner_stable=True,
        receipts=[dict(recipe=recipe, hash=str(index+1)*64)
                  for index, recipe in enumerate(seeds.IDS)])


class SeedObservationTests(unittest.TestCase):
    def test_reopen_can_retain_six_effects_without_admitting_a_saved_report(self):
        value = dict(completed_reopen(), seed_workflow=seeds.completed(receipts()))
        self.assertEqual(restored.project(value), value)
        self.assertFalse(restored.project(value)['seed_admitted'])

    def test_incomplete_or_private_seed_facts_cannot_complete_reopen(self):
        for seed in (None, dict(schema=1, scope=seeds.SCOPE, complete=False),
                dict(seeds.completed(receipts()), wallet='private')):
            with self.subTest(seed=seed), self.assertRaises(restored.checkpoint.Refused):
                restored.project(dict(completed_reopen(), seed_workflow=seed))

    def test_six_unique_originals_project_without_addresses_or_hashes(self):
        value = receipts()
        result = seeds.completed(value)
        self.assertEqual(result['recipes'], list(seeds.IDS))
        self.assertEqual(result['confirmed'], 6)
        self.assertEqual(result['receipts_sha256'], seeds.digest(value))
        self.assertNotIn('receipts', result)
        self.assertEqual(seeds.private_receipts(value), value)

    def test_missing_reordered_duplicate_and_unknown_originals_refuse(self):
        for kind in ('missing', 'reordered', 'duplicate', 'unknown'):
            value = receipts()
            if kind == 'missing':value['receipts'].pop()
            if kind == 'reordered':value['receipts'].reverse()
            if kind == 'duplicate':value['receipts'][1]['hash'] = '1'*64
            if kind == 'unknown':value['receipts'][0]['hash'] = '0'*64
            with self.subTest(kind=kind), self.assertRaises(restored.checkpoint.Refused):
                seeds.private_receipts(value)

    def test_coerced_state_foreign_chain_and_private_fields_refuse(self):
        for change in (dict(chain=1), dict(chain=321.0), dict(members=True),
                dict(selected_index=True), dict(derived_once=1),
                dict(owner_stable=False), dict(wallet='private')):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                seeds.private_receipts(dict(receipts(), **change))

    def test_absent_and_partial_reports_cannot_claim_six_completed_effects(self):
        self.assertIsNone(seeds.project(None))
        partial = dict(schema=1, scope=seeds.SCOPE, complete=False)
        self.assertEqual(seeds.project(partial), partial)
        for change in (dict(confirmed=5), dict(owner_stable=False),
                dict(journals_consistent=False), dict(receipts_sha256='private')):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                seeds.project(dict(seeds.completed(receipts()), **change))
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.project(dict(partial, confirmed=6))

    def test_each_journal_record_must_retain_its_exact_original_hash(self):
        for state in ('attempt', 'accepted', 'confirmed'):
            value = dict(recipe='stake', state=state, chain=321)
            if state != 'attempt':value['hash'] = '1'*64
            seeds.journal_record('stake', state, json.dumps(value).encode(), '1'*64)
            value['hash'] = '2'*64
            with self.subTest(state=state), self.assertRaises(restored.checkpoint.Refused):
                seeds.journal_record('stake', state, json.dumps(value).encode(), '1'*64)

    def test_foreign_extra_and_oversized_journal_data_are_held(self):
        for value in (dict(recipe='fuse', state='attempt', chain=321),
                dict(recipe='stake', state='attempt', chain=True),
                dict(recipe='stake', state='attempt', chain=321, private='held')):
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                seeds.journal_record('stake', 'attempt', json.dumps(value).encode(), '1'*64)
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.journal_record('stake', 'attempt', b' '*2049, '1'*64)

    def test_counterparty_is_selected_only_from_the_pinned_lab_fixture(self):
        address = 'z1' + 'q'*38
        genesis = dict(ChainIdentifier=321, ExtraData='SYRIUS LAB', PillarConfig=dict(
            Pillars=[dict(Name='dev'+str(i), RewardWithdrawAddress=address,
                          StakeAddress=address) for i in range(1, 4)]))
        self.assertEqual(seeds.counterparty(genesis, ('first', 'second')), address)
        for changed in (dict(ChainIdentifier=69), dict(ExtraData='foreign')):
            with self.subTest(changed=changed), self.assertRaises(restored.checkpoint.Refused):
                seeds.counterparty(dict(genesis, **changed), ('first', 'second'))
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.counterparty(genesis, ('first', address))

    def test_ambiguous_or_changed_fixture_owner_is_not_a_counterparty(self):
        address = 'z1' + 'q'*38
        genesis = dict(ChainIdentifier=321, ExtraData='SYRIUS LAB', PillarConfig=dict(
            Pillars=[dict(Name='dev'+str(i), RewardWithdrawAddress=address,
                          StakeAddress=address) for i in range(1, 4)]))
        for kind in ('duplicate', 'different', 'invalid'):
            value = copy.deepcopy(genesis)
            if kind == 'duplicate':value['PillarConfig']['Pillars'][2]['Name'] = 'dev2'
            if kind == 'different':value['PillarConfig']['Pillars'][1]['StakeAddress'] = 'other'
            if kind == 'invalid':value['PillarConfig']['Pillars'][1]['RewardWithdrawAddress'] = 'private'
            with self.subTest(kind=kind), self.assertRaises(restored.checkpoint.Refused):
                seeds.counterparty(value, ('first', 'second'))


class SeedPrefixObservationTests(unittest.TestCase):
    def prefix(self, count):
        value = receipts()
        value['scope'] = 'private_restored_seed_prefix'
        value['receipts'] = value['receipts'][:count]
        return value

    def journal(self, recipe, state):
        value = dict(recipe=recipe, state=state, chain=321)
        if state != 'attempt':
            value['hash'] = str(seeds.IDS.index(recipe) + 1) * 64
        return json.dumps(value).encode()

    def test_ordered_prefixes_read_only_the_three_new_journals(self):
        previous = None
        for count in range(1, 7):
            calls = []
            def read(recipe, state):
                calls.append((recipe, state))
                return self.journal(recipe, state)
            value, public = seeds.retain_prefix(previous, self.prefix(count), read)
            self.assertEqual(calls, [(seeds.IDS[count-1], state)
                for state in ('attempt', 'accepted', 'confirmed')])
            self.assertEqual(public['confirmed'], count)
            self.assertEqual(public['recipes'], list(seeds.IDS[:count]))
            self.assertEqual(public['receipts_sha256'], seeds.digest(value))
            self.assertFalse(public['complete'])
            self.assertFalse(public['seed_admitted'])
            self.assertNotIn('receipts', public)
            self.assertNotIn('1'*64, json.dumps(public))
            previous = value

    def test_replay_skipping_and_replaced_prior_hash_refuse_before_io(self):
        previous = self.prefix(1)
        changed = self.prefix(2)
        changed['receipts'][0]['hash'] = 'a'*64
        for value in (self.prefix(1), self.prefix(3), changed):
            calls = []
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                seeds.retain_prefix(previous, value,
                    lambda *args: calls.append(args))
            self.assertEqual(calls, [])
        self.assertEqual(previous, self.prefix(1))

    def test_empty_reordered_duplicate_and_oversized_prefixes_are_not_receipts(self):
        empty = self.prefix(0)
        reordered = self.prefix(2)
        reordered['receipts'].reverse()
        duplicate = self.prefix(2)
        duplicate['receipts'][1]['hash'] = '1'*64
        oversized = self.prefix(6)
        oversized['receipts'].append(dict(recipe='extra', hash='a'*64))
        for value in (empty, reordered, duplicate, oversized):
            with self.subTest(value=value), self.assertRaises(restored.checkpoint.Refused):
                seeds.private_prefix(value)

    def test_foreign_scope_owner_state_or_extra_fields_cannot_form_a_prefix(self):
        for change in (dict(scope='private_restored_seed_receipts'),
                dict(owner_stable=False), dict(chain=True),
                dict(selected_index=True), dict(wallet='private')):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                seeds.private_prefix(dict(self.prefix(1), **change))

    def test_final_receipt_requires_the_identical_six_original_prefix(self):
        final = receipts()
        self.assertEqual(seeds.finish_prefix(self.prefix(6), final), final)
        changed = self.prefix(6)
        changed['receipts'][-1]['hash'] = 'a'*64
        for previous in (None, self.prefix(1), self.prefix(5), changed):
            with self.subTest(previous=previous), self.assertRaises(restored.checkpoint.Refused):
                seeds.finish_prefix(previous, final)

    def test_even_six_prefix_receipts_cannot_complete_or_admit_the_workflow(self):
        value = self.prefix(6)
        for validate in (seeds.private_receipts, seeds.completed, seeds.project):
            with self.subTest(validate=validate), self.assertRaises(restored.checkpoint.Refused):
                validate(value)
        _, public = seeds.retain_prefix(self.prefix(5), value, self.journal)
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.project(public)
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.prefix_projection(dict(public, complete=True, seed_admitted=True))

    def test_public_prefix_rejects_private_fields_coerced_counts_and_foreign_order(self):
        _, public = seeds.retain_prefix(None, self.prefix(1), self.journal)
        for change in (dict(receipts=self.prefix(1)['receipts']),
                dict(confirmed=True), dict(confirmed=0), dict(confirmed=7),
                dict(recipes=['fuse']), dict(recipes=('stake',)),
                dict(journals_consistent=False), dict(receipts_sha256='private')):
            with self.subTest(change=change), self.assertRaises(restored.checkpoint.Refused):
                seeds.prefix_projection(dict(public, **change))

    def test_retained_private_and_public_prefixes_do_not_alias_child_input(self):
        source = self.prefix(1)
        value, public = seeds.retain_prefix(None, source, self.journal)
        source['receipts'][0]['hash'] = 'a'*64
        self.assertEqual(value, self.prefix(1))
        projected = seeds.prefix_projection(public)
        projected['recipes'].clear()
        self.assertEqual(public['recipes'], ['stake'])

    def test_mismatched_new_journal_never_replaces_a_confirmed_predecessor(self):
        previous = self.prefix(1)
        calls = []
        def read(recipe, state):
            calls.append((recipe, state))
            if state == 'confirmed':
                return json.dumps(dict(recipe=recipe, state=state,
                    chain=321, hash='a'*64)).encode()
            return self.journal(recipe, state)
        with self.assertRaises(restored.checkpoint.Refused):
            seeds.retain_prefix(previous, self.prefix(2), read)
        self.assertEqual(len(calls), 3)
        self.assertEqual(previous, self.prefix(1))

    def test_a_failed_new_journal_read_stops_without_fabricating_progress(self):
        previous = self.prefix(1)
        calls = []
        def read(recipe, state):
            calls.append((recipe, state))
            raise OSError('Synthetic held journal')
        with self.assertRaises(OSError):
            seeds.retain_prefix(previous, self.prefix(2), read)
        self.assertEqual(calls, [('fuse', 'attempt')])
        self.assertEqual(previous, self.prefix(1))
