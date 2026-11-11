"""Memory-only boundaries for all four prepared native pointer gates."""

import copy
import unittest

from tool.ci import seeded_surface_seams as seams
from tool.ci.closed_lab_checkpoint import Refused


def observation(seam, theme):
    return dict(schema=1, scope=seams.SCOPE, seam=seam, theme=theme,
                pointerDispatched=True, absorptionObserved=True,
                originalReceiptCurrent=True, nativeFrameObserved=True)


class SeededSurfaceSeamTests(unittest.TestCase):
    def test_owner_pages_are_distinct_from_full_four_gate_acceptance(self):
        values = [observation(seam, theme) for seam, theme in seams.OWNER_EXPECTED]
        value = seams.owner_completed(values, 'a' * 64)
        self.assertEqual(seams.owner_reference(value, 'a' * 64), value)
        self.assertEqual(value['observations'], [
            dict(seam=seam, theme=theme) for theme in ('dark', 'light')
            for seam in ('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms')])
        self.assertEqual(len(value['observations']), 6)
        with self.assertRaises(Refused):
            seams.reference(value, 'a' * 64)
        with self.assertRaises(Refused):
            seams.completed(values, 'a' * 64)
        full = seams.completed(
            [observation(seam, theme) for seam, theme in seams.EXPECTED], 'a' * 64)
        with self.assertRaises(Refused):
            seams.owner_reference(full, 'a' * 64)

    def test_owner_pages_refuse_holder_link_and_missing_or_repeated_pairs(self):
        values = [observation(seam, theme) for seam, theme in seams.OWNER_EXPECTED]
        for offered in ([], values[:-1], list(reversed(values)), values + values[:1],
                        [values[0]] * 6,
                        [observation('tokenExplorer', 'dark')] + values[1:]):
            with self.subTest(offered=offered), self.assertRaises(Refused):
                seams.owner_completed(offered, 'a' * 64)

    def test_owner_pages_refuse_other_receipts_and_relabelled_full_scope(self):
        value = seams.owner_completed(
            [observation(seam, theme) for seam, theme in seams.OWNER_EXPECTED], 'a' * 64)
        for digest in ('b' * 64, '', None, True):
            with self.subTest(digest=digest), self.assertRaises(Refused):
                seams.owner_reference(value, digest)
        with self.assertRaises(Refused):
            seams.reference(dict(value, scope=seams.REFERENCE_SCOPE), 'a' * 64)
        with self.assertRaises(Refused):
            seams.owner_reference(dict(value, detail='private response'), 'a' * 64)

    def test_owner_pages_require_every_exact_pointer_fact(self):
        values = [observation(seam, theme) for seam, theme in seams.OWNER_EXPECTED]
        for field in seams.FACTS:
            for offered in (False, 1, 'true', None):
                changed = copy.deepcopy(values)
                changed[-1][field] = offered
                with self.subTest(field=field, offered=offered), self.assertRaises(Refused):
                    seams.owner_completed(changed, 'a' * 64)
                complete = seams.owner_completed(values, 'a' * 64)
                complete[field] = offered
                with self.assertRaises(Refused):
                    seams.owner_reference(complete, 'a' * 64)

    def test_all_four_gates_in_both_themes_bind_the_original_digest(self):
        values = [observation(seam, theme) for seam, theme in seams.EXPECTED]
        value = seams.completed(values, 'a' * 64)
        self.assertEqual(seams.reference(value, 'a' * 64), value)
        self.assertEqual(value['observations'],
                         [dict(seam=seam, theme=theme) for seam, theme in seams.EXPECTED])
        self.assertEqual(len(value['observations']), 8)
        self.assertNotIn('hash', str(value))
        self.assertNotIn('zts1', str(value))

    def test_missing_reordered_or_repeated_pairs_never_complete(self):
        original = [observation(seam, theme) for seam, theme in seams.EXPECTED]
        for values in ([], original[:1], list(reversed(original)),
                       [original[0]] * 8, original + original[:1], original[:-1]):
            with self.subTest(values=values), self.assertRaises(Refused):
                seams.completed(values, 'a' * 64)

    def test_false_or_mistyped_pointer_and_receipt_facts_are_refused(self):
        for field in ('pointerDispatched', 'absorptionObserved', 'originalReceiptCurrent',
                      'nativeFrameObserved'):
            for offered in (False, 1, 'true', None):
                value = observation('tokenExplorer', 'dark')
                value[field] = offered
                with self.subTest(field=field, offered=offered), self.assertRaises(Refused):
                    seams.receipt(value, 'tokenExplorer', 'dark')
                complete = seams.completed(
                    [observation(seam, theme) for seam, theme in seams.EXPECTED], 'a' * 64)
                complete[field] = offered
                with self.assertRaises(Refused):
                    seams.reference(complete, 'a' * 64)

    def test_extra_free_text_and_wrong_scope_are_never_projected(self):
        for change in (dict(detail='private response'), dict(scope='foreign'),
                       dict(seam='walletUpdateNotice'), dict(theme='private theme'),
                       dict(schema=True)):
            with self.subTest(change=change), self.assertRaises(Refused):
                seams.receipt(dict(observation('tokenExplorer', 'dark'), **change),
                              'tokenExplorer', 'dark')

    def test_another_preparation_digest_cannot_borrow_the_observations(self):
        value = seams.completed(
            [observation(seam, theme) for seam, theme in seams.EXPECTED], 'a' * 64)
        for expected in ('b' * 64, '', None, 1, 'private preparation'):
            with self.subTest(expected=expected), self.assertRaises(Refused):
                seams.reference(value, expected)
        tampered = copy.deepcopy(value)
        tampered['private'] = 'private preparation'
        with self.assertRaises(Refused):
            seams.reference(tampered, 'a' * 64)
