"""Project known test locations and fixed assertion labels without raw errors."""

import json
import re

FILES = ('wallet_tour_test.dart', 'build_output_test.dart',
    'copied_wallet_pointer.dart', 'copied_wallet_pointer_test.dart',
    'ci_copied_wallet_pointer.dart', 'copied_pointer_input_test.dart',
    'lab_quiescence.dart', 'lab_quiescence_test.dart',
    'wallet_address_recipe_test.dart', 'addresses_selection_test.dart',
    'lab_transfer_witness_test.dart', 'lab_transfer_witness.dart',
    'lab_send_policy_test.dart', 'lab_send_journal_test.dart',
    'lab_send_ui_binding.dart', 'lab_send_ui_binding_test.dart',
    'lab_send_failure.dart', 'lab_send_failure_test.dart',
    'lab_sender_menu_test.dart', 'transfer_sender_header_test.dart',
    'startup_key_confirm_test.dart', 'startup_key_refusal_test.dart',
    'startup_key_support.dart', 'launch_film_test.dart',
    'send_populated.dart',
    'lab_send_policy.dart', 'seed_policy_test.dart', 'seed_policy.dart',
    'lab_seed_binding.dart',
    'selection_context_revision_test.dart', 'default_address_notifier.dart',
    'recipe_control_admission_test.dart', 'recipe_control_admission.dart',
    'wallet_recipe_failure_test.dart', 'wallet_recipe_startup_test.dart',
    'wallet_recipe_test.dart', 'key_dispatch_test.dart', 'rail_navigation_test.dart', 'agent.dart',
    'launch_film.dart', 'startup_stage.dart')
CATEGORIES = (
    (r'Failed to load', 'LOAD_ERROR'),
    (r'MissingPluginException', 'MISSING_PLUGIN'),
    (r'Null check operator used on a null value', 'NULL_CHECK'),
    (r'TypeError|is not a subtype', 'TYPE_ERROR'),
    (r'TimeoutException|[Tt]est timed out', 'TIMEOUT'),
    (r'A RenderFlex overflowed|RenderBox was not laid out|BoxConstraints forces', 'LAYOUT'),
    (r'[Tt]imer is still pending|Pending timers:', 'PENDING_TIMER'),
    (r'used after being disposed', 'DISPOSED'),
    (r'TestFailure|Expected:|assertion was thrown|Assertion failed:', 'ASSERTION'),
    (r'EXCEPTION CAUGHT', 'FRAMEWORK'),
)

FRAMEWORK_ASSERTIONS = {
    'package:flutter/src/widgets/framework.dart': 'flutter_framework',
    'package:flutter/src/rendering/object.dart': 'flutter_render_object',
    'package:flutter/src/rendering/box.dart': 'flutter_box',
    'package:flutter/src/material/dropdown.dart': 'flutter_dropdown',
    'package:flutter/src/material/dropdown_menu.dart': 'flutter_dropdown_menu',
    'package:flutter/src/foundation/change_notifier.dart': 'flutter_notifier',
    'package:flutter/src/widgets/scroll_controller.dart': 'flutter_scroll',
    'package:flutter/src/widgets/binding.dart': 'flutter_widgets_binding',
    'package:flutter/src/scheduler/binding.dart': 'flutter_scheduler_binding',
    'package:provider/src/provider.dart': 'provider_core',
    'package:provider/src/inherited_provider.dart': 'provider_inherited',
    'package:flutter_bloc/src/bloc_builder.dart': 'flutter_bloc_builder',
    'package:flutter_bloc/src/bloc_provider.dart': 'flutter_bloc_provider',
    'package:bloc/src/emitter.dart': 'bloc_emitter',
    'package:get_it/get_it_impl.dart': 'get_it_registry',
    'package:flutter_test/src/binding.dart': 'flutter_test_binding',
    'package:flutter_test/src/widget_tester.dart': 'flutter_widget_tester',
    'package:flutter_test/src/test_async_utils.dart': 'flutter_test_async',
    'package:flutter_test/src/async_matchers.dart': 'flutter_test_matchers',
}
FRAMEWORK_FAILURE_KINDS = ('FLUTTER_ERROR', 'ASSERTION_ERROR', 'STATE_ERROR',
    'TYPE_ERROR', 'NO_SUCH_METHOD', 'FORMAT_ERROR', 'OTHER')


def framework_assertion(text, stack=''):
    """Keep only an allowlisted package label and bounded numeric position."""
    found = []
    for path, label in FRAMEWORK_ASSERTIONS.items():
        match = re.search(r'''['"]''' + re.escape(path)
            + r'''['"]:\s*Failed assertion:\s*line\s+([1-9][0-9]{0,5})'''
            + r'\s+pos\s+([1-9][0-9]{0,5})(?![0-9])', text)
        if match:
            found.append((match.start(), label, int(match[1]), int(match[2])))
    if found:
        _, source, line, column = min(found)
        return dict(source=source, line=line, column=column)
    # FlutterError.fromParts may have no native assertion header. An owned
    # package frame is context, not proof of the exact assertion origin.
    context = stack + '\n' + text
    for path, label in FRAMEWORK_ASSERTIONS.items():
        match = re.search(r'\(' + re.escape(path)
            + r':([1-9][0-9]{0,5}):([1-9][0-9]{0,5})\)', context)
        if match:
            found.append((match.start(), label, int(match[1]), int(match[2])))
    if found:
        _, source, line, column = min(found)
        return dict(source=source, line=line, column=column, kind='STACK_FRAME')
    return None


def location(text, *, tests_only=False):
    found = []
    for name in FILES:
        if tests_only and not name.endswith('_test.dart'):
            continue
        match = re.search(r'(?<![A-Za-z0-9_.-])' + re.escape(name)
            + r'(?::|\s+)([1-9][0-9]{0,5})(?![0-9])(?::[0-9]+)?', text)
        if match:
            found.append((match.start(), name, int(match[1])))
    return min(found) if found else None


def project(raw):
    refused = dict(status='REFUSED', total=0, items=[])
    if type(raw) is not bytes or len(raw) > 4 * 1024**2:
        return refused
    lines = raw.splitlines()
    if len(lines) > 20000:
        return refused
    total, items, prints = 0, [], {}
    try:
        for line in lines:
            if not line.strip():
                continue
            event = json.loads(line)
            if type(event) is not dict:
                return refused
            if event.get('type') == 'print':
                identity, message = event.get('testID'), event.get('message')
                if type(identity) is int and identity >= 0 and event.get('messageType', 'print') == 'print':
                    if type(message) is not str:
                        return refused
                    if identity not in prints and len(prints) >= 256:
                        return refused
                    prints[identity] = (prints.get(identity, '') + '\n' + message)[-16384:]
                continue
            if event.get('type') != 'error':
                continue
            error, stack = event.get('error'), event.get('stackTrace')
            failure = event.get('isFailure')
            if type(error) is not str or type(stack) is not str or type(failure) is not bool:
                return refused
            total += 1
            if len(items) == 3:
                continue
            identity = event.get('testID')
            context = prints.get(identity, '') if type(identity) is int else ''
            details = error + '\n' + context
            source, selected = 'NONE', None
            for label, text in (('STACK', stack), ('ERROR', error), ('PRINT', context)):
                selected = location(text)
                if selected:
                    source = label
                    break
            expectation = 'OTHER'
            for pattern, label in ((r'Expected:\s*true\b', 'TRUE'),
                                   (r'Expected:\s*false\b', 'FALSE'),
                                   (r'Expected:\s*<1>(?:\s|$)', 'ONE')):
                if re.search(pattern, details):
                    expectation = label
                    break
            category = next((label for pattern, label in CATEGORIES
                if re.search(pattern, details)), 'OTHER')
            item = dict(file=selected[1] if selected else None,
                line=selected[2] if selected else None, location_source=source,
                kind='ASSERTION' if failure else 'UNHANDLED',
                expectation=expectation, category=category)
            for label, text in (('STACK', stack), ('ERROR', error), ('PRINT', context)):
                caller = location(text, tests_only=True)
                if caller is not None:
                    if selected is not None and caller[1:] != selected[1:]:
                        item['test_context'] = dict(file=caller[1], line=caller[2],
                            location_source=label)
                    break
            assertion = framework_assertion(details, stack)
            if assertion is not None:
                item['framework_assertion'] = assertion
            marker = re.search(r'(?m)^CI_FRAMEWORK_FAILURE_KIND:('
                + '|'.join(FRAMEWORK_FAILURE_KINDS) + r')\r?$', context)
            if marker:
                item['framework_failure_kind'] = marker[1]
            items.append(item)
    except (ValueError, UnicodeError, TypeError):
        return refused
    return dict(status='OBSERVED' if total else 'NO_ERROR_EVENTS', total=total, items=items)
