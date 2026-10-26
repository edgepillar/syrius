"""Project known test locations and fixed assertion labels without raw errors."""

import json
import re

FILES = ('wallet_tour_test.dart', 'build_output_test.dart',
    'wallet_recipe_failure_test.dart', 'wallet_recipe_startup_test.dart',
    'wallet_recipe_test.dart')


def project(raw):
    refused = dict(status='REFUSED', total=0, items=[])
    if type(raw) is not bytes or len(raw) > 4 * 1024**2:
        return refused
    lines = raw.splitlines()
    if len(lines) > 20000:
        return refused
    total, items = 0, []
    try:
        for line in lines:
            if not line.strip():
                continue
            event = json.loads(line)
            if type(event) is not dict:
                return refused
            if event.get('type') != 'error':
                continue
            error, stack = event.get('error'), event.get('stackTrace')
            failure = event.get('isFailure')
            if type(error) is not str or type(stack) is not str or type(failure) is not bool:
                return refused
            total += 1
            if len(items) == 3:
                continue
            locations = []
            for name in FILES:
                match = re.search(r'(?<![A-Za-z0-9_.-])' + re.escape(name)
                    + r'(?::|\s+)([1-9][0-9]{0,5})(?::[0-9]+)?', stack)
                if match:
                    locations.append((match.start(), name, int(match[1])))
            location = min(locations) if locations else None
            expectation = 'OTHER'
            for pattern, label in ((r'Expected:\s*true\b', 'TRUE'),
                                   (r'Expected:\s*false\b', 'FALSE'),
                                   (r'Expected:\s*<1>(?:\s|$)', 'ONE')):
                if re.search(pattern, error):
                    expectation = label
                    break
            items.append(dict(file=location[1] if location else None,
                line=location[2] if location else None,
                kind='ASSERTION' if failure else 'UNHANDLED', expectation=expectation))
    except (ValueError, UnicodeError, TypeError):
        return refused
    return dict(status='OBSERVED' if total else 'NO_ERROR_EVENTS', total=total, items=items)
