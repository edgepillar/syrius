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
    def test_entry_locations_keep_only_exact_names_and_original_numeric_lines(self):
        names = ('entry_capture_source_test.dart', 'entry_capture_opt_in_test.dart',
                 'entry_prepared_draft_test.dart', 'entry_capture_source.dart',
                 'import_wallet_seed_choice_screen.dart', 'native_entry_capture.dart')
        for name in names:
            row = dict(type='error', testID=7, isFailure=False,
                error='Null check operator used on a null value: private text',
                stackTrace='#0 private (/fixture/private/' + name + ':101:9)')
            value = failure.project(encode([row]))['items'][0]
            with self.subTest(name=name):
                self.assertEqual((value['file'], value['line']), (name, 101))
                self.assertEqual(value['category'], 'NULL_CHECK')
                self.assertEqual(value['location_source'], 'STACK')
                self.assertNotIn('private', json.dumps(value))
                self.assertNotIn('/fixture', json.dumps(value))
                self.assertNotIn('text', json.dumps(value))
                row['stackTrace'] = '/fixture/private/private_' + name + ':101:9'
                foreign = failure.project(encode([row]))['items'][0]
                self.assertIsNone(foreign['file'])
                self.assertIsNone(foreign['line'])

    def test_original_test_caller_is_separate_from_the_first_helper_location(self):
        frame = ('#0 private (/fixture/private/agent.dart:976:7)\n'
            '#1 private (/fixture/private/lab_send_ui_binding_test.dart:371:5)')
        for use_print in (False, True):
            row = dict(type='error', testID=7, isFailure=False,
                error='private error', stackTrace='' if use_print else frame)
            rows = [row]
            if use_print:
                rows.insert(0, dict(type='print', testID=7, message=frame))
            value = failure.project(encode(rows))['items'][0]
            with self.subTest(use_print=use_print):
                self.assertEqual((value['file'], value['line']), ('agent.dart', 976))
                self.assertEqual(value['test_context'], dict(
                    file='lab_send_ui_binding_test.dart', line=371,
                    location_source='PRINT' if use_print else 'STACK'))
                self.assertNotIn('private', json.dumps(value))
                self.assertNotIn('/fixture', json.dumps(value))

    def test_foreign_or_unknown_test_frames_cannot_supply_caller_context(self):
        for caller in ('unknown_test.dart:371:5',
                       'private_lab_send_ui_binding_test.dart:371:5',
                       'lab_send_ui_binding_test.dart:0:5',
                       'lab_send_ui_binding_test.dart:1234567:5'):
            row = dict(type='error', testID=7, isFailure=False,
                error='private error', stackTrace='agent.dart:976:7\n' + caller)
            value = failure.project(encode([row]))['items'][0]
            self.assertNotIn('test_context', value)
        rows = [dict(type='print', testID=99,
            message='lab_send_ui_binding_test.dart:371:5'),
            dict(type='error', testID=7, isFailure=False,
                error='private error', stackTrace='agent.dart:976:7')]
        self.assertNotIn('test_context', failure.project(encode(rows))['items'][0])

    def test_known_source_location_never_exports_error_stack_or_host_path(self):
        for name in ('wallet_recipe_startup_test.dart', 'rail_navigation_test.dart',
                     'wallet_address_recipe_test.dart', 'addresses_selection_test.dart',
                     'lab_transfer_witness_test.dart', 'lab_transfer_witness.dart',
                     'lab_send_policy_test.dart', 'lab_send_journal_test.dart',
                     'lab_send_ui_binding.dart', 'lab_send_ui_binding_test.dart',
                     'lab_send_failure.dart', 'lab_send_failure_test.dart',
                     'lab_sender_menu_test.dart', 'transfer_sender_header_test.dart',
                     'startup_key_confirm_test.dart', 'startup_key_refusal_test.dart',
                     'startup_key_support.dart',
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

    def test_framework_assertions_keep_only_known_labels_and_numeric_positions(self):
        for path, label in (
                ('package:flutter/src/widgets/framework.dart', 'flutter_framework'),
                ('package:provider/src/provider.dart', 'provider_core'),
                ('package:bloc/src/emitter.dart', 'bloc_emitter'),
                ('package:get_it/get_it_impl.dart', 'get_it_registry')):
            rows = [dict(type='print', testID=7, messageType='print',
                message="'" + path + "': Failed assertion: line 123 pos 9: "
                    "'private expression': private details\n"
                    '/fixture/private/transfer_sender_header_test.dart:386:5'),
                dict(type='error', testID=7, isFailure=False, stackTrace='',
                    error='Test failed. See exception logs above.')]
            with self.subTest(source=label):
                value = failure.project(encode(rows))['items'][0]
                self.assertEqual(value['framework_assertion'],
                    dict(source=label, line=123, column=9))
                self.assertEqual((value['file'], value['line']),
                    ('transfer_sender_header_test.dart', 386))
                public = json.dumps(value)
                self.assertNotIn(path, public)
                self.assertNotIn('private', public)
                self.assertNotIn('expression', public)

    def test_unknown_assertion_paths_and_foreign_context_cannot_add_framework_data(self):
        for path, position in (
                ('/fixture/private/framework.dart', 'line 123 pos 9'),
                ('package:private/framework.dart', 'line 123 pos 9'),
                ('package:flutter/src/widgets/framework.dart', 'line 0 pos 9'),
                ('package:flutter/src/widgets/framework.dart', 'line 123 pos 0'),
                ('package:flutter/src/widgets/framework.dart', 'line 1234567 pos 9'),
                ('package:flutter/src/widgets/framework.dart', 'line 123 pos 1234567')):
            row = event()
            row['error'] = "'" + path + "': Failed assertion: " + position
            with self.subTest(path=path, position=position):
                value = failure.project(encode([row]))['items'][0]
                self.assertNotIn('framework_assertion', value)
                self.assertNotIn('private', json.dumps(value))
        rows = [dict(type='print', testID=99, messageType='print',
            message="'package:flutter/src/widgets/framework.dart': "
                'Failed assertion: line 123 pos 9: private'),
            dict(type='error', testID=7, isFailure=False, stackTrace='',
                error='Test failed. See exception logs above.')]
        self.assertNotIn('framework_assertion', failure.project(encode(rows))['items'][0])

    def test_owned_package_frame_is_context_and_cannot_claim_an_assertion_origin(self):
        for use_print in (False, True):
            frame = ('#0 private (package:flutter/src/widgets/framework.dart:123:9)\n'
                '#1 private (package:provider/src/provider.dart:456:7)\n'
                '/fixture/private/transfer_sender_header_test.dart:386:5')
            rows = [dict(type='error', testID=7, isFailure=False,
                error='Test failed. See exception logs above.',
                stackTrace='' if use_print else frame)]
            if use_print:
                rows.insert(0, dict(type='print', testID=7, messageType='print',
                    message=frame))
            with self.subTest(use_print=use_print):
                value = failure.project(encode(rows))['items'][0]
                self.assertEqual(value['framework_assertion'], dict(
                    source='flutter_framework', line=123, column=9,
                    kind='STACK_FRAME'))
                self.assertNotIn('private', json.dumps(value))
                self.assertNotIn('package:', json.dumps(value))
        for position in ('0:9', '123:0', '1234567:9', '123:1234567'):
            row = event()
            row['stackTrace'] = '(package:flutter/src/widgets/framework.dart:' + position + ')'
            self.assertNotIn('framework_assertion',
                failure.project(encode([row]))['items'][0])
        rows = [dict(type='print', testID=99, messageType='print', message=frame),
            dict(type='error', testID=7, isFailure=False, stackTrace='',
                error='Test failed. See exception logs above.')]
        self.assertNotIn('framework_assertion', failure.project(encode(rows))['items'][0])

    def test_failure_kind_requires_a_closed_marker_from_the_same_test(self):
        for kind in ('FLUTTER_ERROR', 'ASSERTION_ERROR', 'STATE_ERROR',
                     'TYPE_ERROR', 'NO_SUCH_METHOD', 'FORMAT_ERROR', 'OTHER'):
            rows = [dict(type='print', testID=7, messageType='print',
                message='CI_FRAMEWORK_FAILURE_KIND:' + kind),
                dict(type='error', testID=7, isFailure=False,
                    error='private error', stackTrace='private stack')]
            with self.subTest(kind=kind):
                value = failure.project(encode(rows))['items'][0]
                self.assertEqual(value['framework_failure_kind'], kind)
                self.assertNotIn('private', json.dumps(value))
        for marker in ('CI_FRAMEWORK_FAILURE_KIND:private',
                       'CI_FRAMEWORK_FAILURE_KIND:STATE_ERROR private'):
            rows[0]['message'] = marker
            self.assertNotIn('framework_failure_kind',
                failure.project(encode(rows))['items'][0])
        rows[0].update(testID=99, message='CI_FRAMEWORK_FAILURE_KIND:STATE_ERROR')
        self.assertNotIn('framework_failure_kind',
            failure.project(encode(rows))['items'][0])
