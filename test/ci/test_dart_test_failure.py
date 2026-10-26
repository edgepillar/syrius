"""Memory-only failure-location privacy and completeness cases."""

import json
import unittest

from tool.ci import dart_test_failure as failure


def event():
    return dict(type='error', isFailure=True, error='Expected: true\nActual: false',
        stackTrace='/fixture/private/wallet_recipe_startup_test.dart:129:5\nprivate')


def encode(rows):
    return b'\n'.join(json.dumps(row).encode() for row in rows)


class DartFailureTests(unittest.TestCase):
    def test_known_source_location_never_exports_error_stack_or_host_path(self):
        value = failure.project(encode([event()]))
        self.assertEqual(value, dict(status='OBSERVED', total=1, items=[dict(
            file='wallet_recipe_startup_test.dart', line=129, kind='ASSERTION', expectation='TRUE')]))
        self.assertNotIn('private', json.dumps(value))

    def test_unknown_locations_and_unhandled_payloads_stay_unattributed(self):
        row = event();row.update(stackTrace='/fixture/private.dart:123',
            error='private input', isFailure=False)
        value = failure.project(encode([row]))
        self.assertEqual(value['items'], [dict(file=None, line=None,
            kind='UNHANDLED', expectation='OTHER')])
        self.assertNotIn('private', json.dumps(value))

    def test_invalid_or_incomplete_event_shapes_cannot_invent_a_location(self):
        invalid = event();invalid['isFailure'] = 1
        for raw in (None, b'x' * (4 * 1024**2 + 1), b'private raw text',
                    b'[]', encode([invalid])):
            self.assertEqual(failure.project(raw), dict(status='REFUSED', total=0, items=[]))

    def test_error_count_is_complete_but_public_details_are_bounded(self):
        row = event();row.update(error='Expected: <1>\nActual: <0>',
            stackTrace='test/harness/wallet_recipe_test.dart 88:5\nprivate')
        value = failure.project(encode([row] * 5))
        self.assertEqual(value['total'], 5)
        self.assertEqual(len(value['items']), 3)
        self.assertEqual(value['items'][0]['expectation'], 'ONE')
        self.assertEqual(value['items'][0]['line'], 88)
        self.assertEqual(failure.project(b'')['status'], 'NO_ERROR_EVENTS')
