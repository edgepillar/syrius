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
        for name in ('wallet_recipe_startup_test.dart', 'rail_navigation_test.dart',
                     'wallet_address_recipe_test.dart', 'addresses_selection_test.dart',
                     'lab_transfer_witness_test.dart', 'lab_transfer_witness.dart',
                     'lab_send_policy_test.dart', 'lab_send_journal_test.dart',
                     'lab_send_ui_binding.dart', 'lab_send_ui_binding_test.dart',
                     'lab_send_failure.dart', 'lab_send_failure_test.dart',
                     'lab_sender_menu_test.dart',
                     'send_populated.dart',
                     'lab_send_policy.dart', 'seed_policy_test.dart', 'seed_policy.dart',
                     'lab_seed_binding.dart',
                     'selection_context_revision_test.dart', 'default_address_notifier.dart',
                     'recipe_control_admission_test.dart', 'recipe_control_admission.dart'):
            row = event();row['stackTrace'] = '/fixture/private/' + name + ':129:5\nprivate'
            value = failure.project(encode([row]))
            with self.subTest(name=name):
                self.assertEqual(value, dict(status='OBSERVED', total=1, items=[dict(
                    file=name, line=129, kind='ASSERTION', expectation='TRUE',
                    category='ASSERTION', location_source='STACK')]))
                self.assertNotIn('private', json.dumps(value))

    def test_unknown_locations_and_unhandled_payloads_stay_unattributed(self):
        row = event();row.update(stackTrace='/fixture/private.dart:123',
            error='private input', isFailure=False)
        value = failure.project(encode([row]))
        self.assertEqual(value['items'], [dict(file=None, line=None,
            kind='UNHANDLED', expectation='OTHER', category='OTHER', location_source='NONE')])
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

    def test_generic_framework_error_uses_only_its_own_preceding_print_context(self):
        rows = [dict(type='print', testID=7, messageType='print',
            message='Expected: true\nActual: false\n/fixture/private/wallet_recipe_startup_test.dart:101:5'),
            dict(type='error', testID=7, isFailure=False,
                error='Test failed. See exception logs above.', stackTrace='')]
        value = failure.project(encode(rows))
        self.assertEqual(value['items'], [dict(file='wallet_recipe_startup_test.dart', line=101,
            kind='UNHANDLED', expectation='TRUE', category='ASSERTION', location_source='PRINT')])
        self.assertNotIn('private', json.dumps(value))
        self.assertNotIn('Actual', json.dumps(value))

    def test_foreign_prints_cannot_supply_a_location_and_loading_errors_use_known_text(self):
        rows = [dict(type='print', testID=99, message='MissingPluginException private agent.dart:444:1'),
            dict(type='error', testID=7, isFailure=False, stackTrace='',
                error='Failed to load /fixture/private/wallet_recipe_startup_test.dart:81:5')]
        value = failure.project(encode(rows))['items'][0]
        self.assertEqual((value['category'], value['location_source'], value['line']),
            ('LOAD_ERROR', 'ERROR', 81))
        rows[-1]['error'] = 'Test failed. See exception logs above.'
        value = failure.project(encode(rows))['items'][0]
        self.assertEqual((value['file'], value['category'], value['location_source']),
            (None, 'OTHER', 'NONE'))
