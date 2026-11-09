"""Finite observations for one owned lab seed session."""

import hashlib
import json
import re

from .closed_lab_checkpoint import need
from .readonly_details_capture import STAKE_DRAFT_FAMILY


IDS = ('stake', 'fuse', 'token', 'deposit', 'project', 'fund-address')
CATALOG_IDS = ('stake', 'token')
SCOPE = 'owned_restored_seed_workflow'
CATALOG_SCOPE = 'owned_restored_seed_catalog_prerequisites'
PREFIX_SCOPE = 'observed_restored_seed_prefix'
CATALOG_PREFIX_SCOPE = 'observed_restored_seed_catalog_prefix'


def _recipe_ids(catalog_capture):
    if catalog_capture == STAKE_DRAFT_FAMILY:
        return ('stake',)
    need(type(catalog_capture) is bool)
    return CATALOG_IDS if catalog_capture else IDS


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True,
        separators=(',', ':')).encode('ascii')).hexdigest()


def counterparty(genesis, members):
    """Choose dev2's public fixture owner from the already pinned lab genesis."""
    need(type(genesis) is dict and genesis.get('ChainIdentifier') == 321
        and type(genesis.get('ChainIdentifier')) is int
        and genesis.get('ExtraData') == 'SYRIUS LAB'
        and type(members) in (list, tuple) and len(members) == 2)
    config = genesis.get('PillarConfig')
    need(type(config) is dict and type(config.get('Pillars')) is list)
    rows = config['Pillars']
    need(len(rows) == 3 and all(type(row) is dict for row in rows)
        and {row.get('Name') for row in rows} == {'dev1', 'dev2', 'dev3'})
    row = next(row for row in rows if row['Name'] == 'dev2')
    value = row.get('RewardWithdrawAddress')
    need(type(value) is str and re.fullmatch(r'z1[023456789acdefghjklmnpqrstuvwxyz]{38}', value)
        and row.get('StakeAddress') == value and value not in members)
    return value


def _private_receipts(value, *, prefix=False, catalog_capture=False):
    ids = _recipe_ids(catalog_capture)
    scope = 'private_restored_seed_catalog' if catalog_capture else 'private_restored_seed'
    scope += '_prefix' if prefix else '_receipts'
    fields = {'schema', 'scope', 'chain', 'members', 'selected_index',
        'derived_once', 'owner_stable', 'receipts'}
    need(type(value) is dict and set(value) == fields
        and type(value['schema']) is int and value['schema'] == 1
        and value['scope'] == scope
        and type(value['chain']) is int and value['chain'] == 321
        and type(value['members']) is int and value['members'] == 3
        and type(value['selected_index']) is int and value['selected_index'] == 1
        and value['derived_once'] is value['owner_stable'] is True
        and type(value['receipts']) is list
        and (1 <= len(value['receipts']) <= len(ids) if prefix
             else len(value['receipts']) == len(ids)))
    hashes = set()
    for recipe, row in zip(ids, value['receipts']):
        need(type(row) is dict and set(row) == {'recipe', 'hash'}
            and row['recipe'] == recipe and type(row['hash']) is str
            and re.fullmatch('[a-f0-9]{64}', row['hash'])
            and row['hash'] != '0'*64 and row['hash'] not in hashes)
        hashes.add(row['hash'])
    return json.loads(json.dumps(value))


def private_receipts(value, *, catalog_capture=False):
    return _private_receipts(value, catalog_capture=catalog_capture)


def private_prefix(value, *, catalog_capture=False):
    """An ordered original receipt prefix; never a completed workflow."""
    return _private_receipts(value, prefix=True, catalog_capture=catalog_capture)


def next_prefix(previous, value, *, catalog_capture=False):
    value = private_prefix(value, catalog_capture=catalog_capture)
    earlier = ([] if previous is None
               else private_prefix(previous, catalog_capture=catalog_capture)['receipts'])
    need(len(value['receipts']) == len(earlier) + 1
        and value['receipts'][:-1] == earlier)
    return value


def prefix_projection(value):
    fields = {'schema', 'scope', 'complete', 'confirmed', 'recipes',
        'journals_consistent', 'receipts_sha256', 'seed_admitted'}
    need(type(value) is dict and set(value) == fields
        and type(value['schema']) is int and value['schema'] == 1
        and value['scope'] in (PREFIX_SCOPE, CATALOG_PREFIX_SCOPE))
    ids = CATALOG_IDS if value['scope'] == CATALOG_PREFIX_SCOPE else IDS
    need(value['complete'] is value['seed_admitted'] is False
        and type(value['confirmed']) is int and 1 <= value['confirmed'] <= len(ids)
        and type(value['recipes']) is list
        and value['recipes'] == list(ids[:value['confirmed']])
        and value['journals_consistent'] is True
        and type(value['receipts_sha256']) is str
        and re.fullmatch('[a-f0-9]{64}', value['receipts_sha256']))
    return dict(value, recipes=list(value['recipes']))


def retain_prefix(previous, value, read_journal, *, catalog_capture=False):
    """Validate only the new original's journals before retaining its prefix."""
    value = next_prefix(previous, value, catalog_capture=catalog_capture)
    need(callable(read_journal))
    latest = value['receipts'][-1]
    for state in ('attempt', 'accepted', 'confirmed'):
        journal_record(latest['recipe'], state,
            read_journal(latest['recipe'], state), latest['hash'])
    scope = CATALOG_PREFIX_SCOPE if catalog_capture else PREFIX_SCOPE
    public = prefix_projection(dict(schema=1, scope=scope,
        complete=False, confirmed=len(value['receipts']),
        recipes=[row['recipe'] for row in value['receipts']],
        journals_consistent=True, receipts_sha256=digest(value), seed_admitted=False))
    return value, public


def finish_prefix(previous, value, *, catalog_capture=False):
    """Bind the final receipt to every required journaled original."""
    value = private_receipts(value, catalog_capture=catalog_capture)
    need(private_prefix(previous, catalog_capture=catalog_capture)['receipts']
        == value['receipts'])
    return value


def journal_record(recipe, state, raw, original_hash):
    need(recipe in IDS and state in ('attempt', 'accepted', 'confirmed')
        and type(raw) is bytes and 0 < len(raw) <= 2048)
    value = json.loads(raw)
    need(type(value) is dict and set(value) ==
        {'recipe', 'chain', 'state'} | ({'hash'} if state != 'attempt' else set())
        and value['recipe'] == recipe and type(value['chain']) is int
        and value['chain'] == 321 and value['state'] == state
        and (state == 'attempt' or value['hash'] == original_hash))


def completed(value, *, catalog_capture=False):
    value = private_receipts(value, catalog_capture=catalog_capture)
    ids = _recipe_ids(catalog_capture)
    scope = CATALOG_SCOPE if catalog_capture else SCOPE
    return project(dict(schema=1, scope=scope, complete=True, chain=321,
        recipes=list(ids), confirmed=len(ids), members=3, selected_index=1,
        derived_once=True, owner_stable=True, journals_consistent=True,
        original_outcomes_preserved=True, receipts_sha256=digest(value)),
        catalog_capture=catalog_capture)


def project(value, *, catalog_capture=False):
    if value is None:
        return None
    ids = _recipe_ids(catalog_capture)
    scope = CATALOG_SCOPE if catalog_capture else SCOPE
    common = {'schema', 'scope', 'complete'}
    need(type(value) is dict and common <= set(value)
        and type(value['schema']) is int and value['schema'] == 1
        and value['scope'] == scope and type(value['complete']) is bool)
    if not value['complete']:
        need(set(value) == common)
        return dict(value)
    need(set(value) == common | {'chain', 'recipes', 'confirmed', 'members',
        'selected_index', 'derived_once', 'owner_stable', 'journals_consistent',
        'original_outcomes_preserved', 'receipts_sha256'}
        and type(value['chain']) is int and value['chain'] == 321
        and value['recipes'] == list(ids)
        and type(value['confirmed']) is int and value['confirmed'] == len(ids)
        and type(value['members']) is int and value['members'] == 3
        and type(value['selected_index']) is int and value['selected_index'] == 1
        and all(value[key] is True for key in ('derived_once', 'owner_stable',
            'journals_consistent', 'original_outcomes_preserved'))
        and type(value['receipts_sha256']) is str
        and re.fullmatch('[a-f0-9]{64}', value['receipts_sha256']))
    return dict(value)
