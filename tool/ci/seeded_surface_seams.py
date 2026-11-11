"""Separate closed metadata for prepared owner pages and the full four gates."""

import re

from .closed_lab_checkpoint import need


THEMES = ('dark', 'light')
SEAMS = ('walletUpdateNotice', 'tokenExplorer', 'pillarAprEstimate', 'swapTerms')
EXPECTED = (('tokenExplorer', 'dark'), ('tokenExplorer', 'light')) + tuple(
    (seam, theme) for theme in THEMES
    for seam in ('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms'))
SCOPE = 'owned_seeded_surface_seam_pointer_observation'
REFERENCE_SCOPE = 'owned_restored_surface_seams'
OWNER_SEAMS = ('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms')
OWNER_EXPECTED = tuple((seam, theme) for theme in THEMES for seam in OWNER_SEAMS)
OWNER_REFERENCE_SCOPE = 'owned_restored_owner_page_seams'
FACTS = dict(pointerDispatched=True, absorptionObserved=True,
             originalReceiptCurrent=True, nativeFrameObserved=True)
HOLDER_SELECTION = dict(schema=1, scope='owned_seeded_token_holder_selection',
    members=3, originalIndex=1, selectedIndex=2, singleTransition=True,
    persisted=True, originalResourcesCurrent=True, publicationRetired=True)
OPERATION_TARGETS = {
    'themeRead': (None,), 'themeSelect': ('dark', 'light'), 'themeRestore': (None,),
    'windowRead': (None,), 'windowShow': (None,), 'windowRestore': (None,),
    'navigate': ('dashboard', 'pillars', 'p2pSwap', 'tokens'),
    'wait': ('home_hero', 'strip_update_button', 'nodes_tab_pillars',
             'nodes_pillars_strip', 'p2p_swaps_strip', 'swap_counterparty_input',
             'swap_start_terms_gate', 'p2p_warning_continue', 'tokens_filter_all',
             'issuedTokenRow', 'token_send', 'token_explorer_control'),
    'waitGone': ('swap_counterparty_input', 'token_explorer_control'),
    'tap': ('nodes_tab_pillars', 'pillars_sort', 'p2p_start_swap', 'swap_action_close',
            'p2p_warning_continue', 'tokens_filter_all', 'issuedTokenRow'),
    'state': (None,), 'escape': (None,), 'seam': SEAMS,
}
OPERATION_BOUNDARIES = ('ownerBefore', 'request', 'ownerAfter', 'reply')


def operation(value):
    """A last-entered label is diagnostic data, never a pointer receipt."""
    fields = {'schema', 'scope', 'action', 'target', 'theme', 'boundary'}
    need(type(value) is dict and set(value) == fields
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'prepared_owner_surface_operation'
         and type(value['action']) is str and value['action'] in OPERATION_TARGETS
         and (value['target'] is None or type(value['target']) is str)
         and value['target'] in OPERATION_TARGETS[value['action']]
         and (value['theme'] is None or type(value['theme']) is str
              and value['theme'] in THEMES)
         and (value['action'] != 'themeSelect' or value['target'] == value['theme'])
         and type(value['boundary']) is str and value['boundary'] in OPERATION_BOUNDARIES)
    return dict(value)


def receipt(value, seam, theme):
    expected = dict(schema=1, scope=SCOPE, seam=seam, theme=theme, **FACTS)
    need(seam in SEAMS and theme in THEMES
         and type(value) is dict and set(value) == set(expected)
         and all(type(value[key]) is type(item) and value[key] == item
                 for key, item in expected.items()))
    return dict(expected)


def reference(value, seed_receipts_sha256):
    if type(value) is dict and type(value.get('schema')) is int and value['schema'] == 2:
        selected = holder_selection(value.get('holder_selection'))
        original = {key: item for key, item in value.items() if key != 'holder_selection'}
        original['schema'] = 1
        base = _reference(original, seed_receipts_sha256, EXPECTED, REFERENCE_SCOPE)
        return dict(base, schema=2, holder_selection=selected)
    return _reference(value, seed_receipts_sha256, EXPECTED, REFERENCE_SCOPE)


def holder_selection(value):
    """Exact committed selection facts; neither names nor addresses leave the actor."""
    need(type(value) is dict and set(value) == set(HOLDER_SELECTION)
         and all(type(value[key]) is type(item) and value[key] == item
                 for key, item in HOLDER_SELECTION.items()))
    return dict(HOLDER_SELECTION)


def holder_completed(observations, selection, seed_receipts_sha256):
    """A holder proof supplements every original pointer and receipt binding."""
    base = completed(observations, seed_receipts_sha256)
    return reference(dict(base, schema=2, holder_selection=holder_selection(selection)),
                     seed_receipts_sha256)


def owner_reference(value, seed_receipts_sha256):
    """The issuer's Mint catalog cannot prove the separate holder token link."""
    return _reference(value, seed_receipts_sha256, OWNER_EXPECTED, OWNER_REFERENCE_SCOPE)


def _reference(value, seed_receipts_sha256, pairs, scope):
    facts = dict(schema=1, scope=scope,
                 seed_receipts_sha256=seed_receipts_sha256, **FACTS)
    need(type(seed_receipts_sha256) is str
         and re.fullmatch('[a-f0-9]{64}', seed_receipts_sha256) is not None
         and type(value) is dict
         and set(value) == set(facts) | {'observations'}
         and all(type(value[key]) is type(item) and value[key] == item
                 for key, item in facts.items())
         and type(value['observations']) is list
         and len(value['observations']) == len(pairs))
    observations = []
    for item, (seam, theme) in zip(value['observations'], pairs):
        need(type(item) is dict and set(item) == {'seam', 'theme'}
             and type(item['seam']) is str and item['seam'] == seam
             and type(item['theme']) is str and item['theme'] == theme)
        observations.append(dict(seam=seam, theme=theme))
    return dict(facts, observations=observations)


def completed(observations, seed_receipts_sha256):
    return _completed(observations, seed_receipts_sha256, EXPECTED, REFERENCE_SCOPE)


def owner_completed(observations, seed_receipts_sha256):
    return _completed(observations, seed_receipts_sha256, OWNER_EXPECTED,
                      OWNER_REFERENCE_SCOPE)


def _completed(observations, seed_receipts_sha256, pairs, scope):
    need(type(observations) is list and len(observations) == len(pairs))
    for item, (seam, theme) in zip(observations, pairs):
        receipt(item, seam, theme)
    return _reference(dict(schema=1, scope=scope,
        seed_receipts_sha256=seed_receipts_sha256, **FACTS,
        observations=[dict(seam=seam, theme=theme) for seam, theme in pairs]),
        seed_receipts_sha256, pairs, scope)
