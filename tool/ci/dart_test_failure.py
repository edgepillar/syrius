"""Project known test locations and fixed assertion labels without raw errors."""

import json
import re

FILES = ('wallet_tour_test.dart', 'build_output_test.dart',
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


def location(text):
    found = []
    for name in FILES:
        match = re.search(r'(?<![A-Za-z0-9_.-])' + re.escape(name)
            + r'(?::|\s+)([1-9][0-9]{0,5})(?::[0-9]+)?', text)
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
            items.append(dict(file=selected[1] if selected else None,
                line=selected[2] if selected else None, location_source=source,
                kind='ASSERTION' if failure else 'UNHANDLED',
                expectation=expectation, category=category))
    except (ValueError, UnicodeError, TypeError):
        return refused
    return dict(status='OBSERVED' if total else 'NO_ERROR_EVENTS', total=total, items=items)
