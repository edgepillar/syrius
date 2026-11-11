"""Closed metadata for four real prepared page gates in both native themes."""

import re

from .closed_lab_checkpoint import need


THEMES = ('dark', 'light')
SEAMS = ('walletUpdateNotice', 'tokenExplorer', 'pillarAprEstimate', 'swapTerms')
EXPECTED = (('tokenExplorer', 'dark'), ('tokenExplorer', 'light')) + tuple(
    (seam, theme) for theme in THEMES
    for seam in ('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms'))
SCOPE = 'owned_seeded_surface_seam_pointer_observation'
REFERENCE_SCOPE = 'owned_restored_surface_seams'
FACTS = dict(pointerDispatched=True, absorptionObserved=True,
             originalReceiptCurrent=True, nativeFrameObserved=True)


def receipt(value, seam, theme):
    expected = dict(schema=1, scope=SCOPE, seam=seam, theme=theme, **FACTS)
    need(seam in SEAMS and theme in THEMES
         and type(value) is dict and set(value) == set(expected)
         and all(type(value[key]) is type(item) and value[key] == item
                 for key, item in expected.items()))
    return dict(expected)


def reference(value, seed_receipts_sha256):
    facts = dict(schema=1, scope=REFERENCE_SCOPE,
                 seed_receipts_sha256=seed_receipts_sha256, **FACTS)
    need(type(seed_receipts_sha256) is str
         and re.fullmatch('[a-f0-9]{64}', seed_receipts_sha256) is not None
         and type(value) is dict
         and set(value) == set(facts) | {'observations'}
         and all(type(value[key]) is type(item) and value[key] == item
                 for key, item in facts.items())
         and type(value['observations']) is list
         and len(value['observations']) == len(EXPECTED))
    observations = []
    for item, (seam, theme) in zip(value['observations'], EXPECTED):
        need(type(item) is dict and set(item) == {'seam', 'theme'}
             and type(item['seam']) is str and item['seam'] == seam
             and type(item['theme']) is str and item['theme'] == theme)
        observations.append(dict(seam=seam, theme=theme))
    return dict(facts, observations=observations)


def completed(observations, seed_receipts_sha256):
    need(type(observations) is list and len(observations) == len(EXPECTED))
    for item, (seam, theme) in zip(observations, EXPECTED):
        receipt(item, seam, theme)
    return reference(dict(schema=1, scope=REFERENCE_SCOPE,
        seed_receipts_sha256=seed_receipts_sha256, **FACTS,
        observations=[dict(seam=seam, theme=theme) for seam, theme in EXPECTED]),
        seed_receipts_sha256)
