"""Finite protocol policies; actual Hive and owned-process execution are separate."""

from pathlib import Path
import unittest
from unittest import mock

from tool.ci import closed_wallet_pointer as pointer


def completed():
    return dict(schema=1, scope=pointer.SCOPE, complete=True, claim_once=True,
        originals_unchanged=True, cipher_unchanged=True, pointer_bound=True,
        child_exit=0, output_bytes=52, output_sha256='a' * 64, output_complete=True,
        forced=False, job_empty=True, private_manifest_sha256='b' * 64,
        native_reopen_qualified=False, seed_admitted=False)


class PointerPolicyTests(unittest.TestCase):
    def test_complete_binding_observations_do_not_qualify_native_reopen_or_seed(self):
        value = pointer.project(completed())
        self.assertTrue(value['complete'])
        self.assertFalse(value['native_reopen_qualified'])
        self.assertFalse(value['seed_admitted'])

    def test_absence_or_incomplete_binding_stays_unqualified(self):
        self.assertIsNone(pointer.project(None))
        value = dict(schema=1, scope=pointer.SCOPE, complete=False)
        self.assertEqual(pointer.project(value), value)
        with self.assertRaises(pointer.checkpoint.Refused):
            pointer.project(dict(value, pointer_bound=True))

    def test_private_or_missing_projection_fields_are_refused(self):
        value = completed()
        for candidate in (dict(value, wallet='private'),
                          {key: item for key, item in value.items() if key != 'child_exit'}):
            with self.subTest(fields=len(candidate)), self.assertRaises(pointer.checkpoint.Refused):
                pointer.project(candidate)

    def test_failed_forced_or_unclosed_child_cannot_supply_positive_binding(self):
        for change in (dict(child_exit=1), dict(child_exit=None), dict(child_exit=False),
                dict(forced=True), dict(job_empty=False), dict(output_complete=False),
                dict(claim_once=False), dict(cipher_unchanged=False),
                dict(originals_unchanged=False), dict(pointer_bound=False)):
            with self.subTest(change=change), self.assertRaises(pointer.checkpoint.Refused):
                pointer.project(dict(completed(), **change))

    def test_coerced_or_malformed_public_observations_are_refused(self):
        for change in (dict(schema=True), dict(output_bytes=True), dict(output_bytes=0),
                dict(output_bytes=2 * 1024**2 + 1), dict(output_sha256='private'),
                dict(private_manifest_sha256='A' * 64), dict(complete=1)):
            with self.subTest(change=change), self.assertRaises(pointer.checkpoint.Refused):
                pointer.project(dict(completed(), **change))

    def test_binding_data_cannot_be_promoted_to_reopened_wallet_or_seed_authority(self):
        for change in (dict(native_reopen_qualified=True), dict(seed_admitted=True)):
            with self.subTest(change=change), self.assertRaises(pointer.checkpoint.Refused):
                pointer.project(dict(completed(), **change))

    def test_unowned_local_execution_refuses_before_process_or_path_discovery(self):
        with mock.patch.object(pointer.subprocess, 'Popen') as launch, \
                mock.patch.object(pointer.checkpoint, 'ancestors') as discover:
            with self.assertRaises(Exception):
                pointer.run(Path('/fixture'), {}, mock.Mock(), Path('/copy'),
                            Path('/checkpoint'), lambda: True, lambda: 0)
        launch.assert_not_called()
        discover.assert_not_called()


if __name__ == '__main__':
    unittest.main()
