"""Finite observations for one owned lab seed session."""

import hashlib
import json
import re
from typing import NamedTuple

from .closed_lab_checkpoint import need
from . import readonly_details_capture as catalog


IDS = ('stake', 'fuse', 'token', 'deposit', 'project', 'fund-address')
CATALOG_IDS = ('stake', 'token')
SCOPE = 'owned_restored_seed_workflow'
CATALOG_SCOPE = 'owned_restored_seed_catalog_prerequisites'
PROJECT_SCOPE = 'owned_restored_project_catalog_prerequisites'
PILLAR_SPAWN_SCOPE = 'owned_restored_pillar_spawn_prerequisites'
PILLAR_DONE_SCOPE = 'owned_restored_pillar_done_prerequisites'
PREFIX_SCOPE = 'observed_restored_seed_prefix'
CATALOG_PREFIX_SCOPE = 'observed_restored_seed_catalog_prefix'
PROJECT_PREFIX_SCOPE = 'observed_restored_project_catalog_prefix'
PILLAR_SPAWN_PREFIX_SCOPE = 'observed_restored_pillar_spawn_prefix'
PILLAR_DONE_PREFIX_SCOPE = 'observed_restored_pillar_done_prefix'
PILLAR_SPAWN_IDS = ('fuse', 'pillar-qsr')
PILLAR_DONE_IDS = (*PILLAR_SPAWN_IDS, 'pillar-register')

# docker/devnet/README.md at go-zenon 2d1b929cc3fa5269cf133757d4a6963821137984.
_PILLAR_FIXTURE_DOC_SHA256 = '1fb72ad5908eaab0df5f98711d88c9b222e179399b96acf7808e17f42fa6d4b8'

CATALOG_SELECTIONS = {
    catalog.SEEDED_SCHEMA: True,
    catalog.STAKE_DRAFT_SCHEMA: catalog.STAKE_DRAFT_FAMILY,
    catalog.PROJECT_DETAIL_SCHEMA: catalog.PROJECT_DETAIL_FAMILY,
    catalog.PILLAR_SPAWN_SCHEMA: catalog.PILLAR_SPAWN_FAMILY,
    catalog.PILLAR_DONE_SCHEMA: catalog.PILLAR_DONE_FAMILY,
    catalog.SWAP_SEEDED_SCHEMA: catalog.SWAP_SEEDED_FAMILY,
}


class _SeedPlan(NamedTuple):
    recipes: tuple[str, ...]
    private_scope: str
    completed_scope: str
    prefix_scope: str
    members: int = 3
    selected_index: int = 1
    derivations: int = 1

    @property
    def membership(self):
        derived = ({'derived_once': True} if self.derivations == 1
                   else {'derived_count': self.derivations})
        return dict(members=self.members, selected_index=self.selected_index, **derived)


_PLANS = {
    False: _SeedPlan(IDS, 'private_restored_seed', SCOPE, PREFIX_SCOPE),
    catalog.SWAP_SEEDED_FAMILY: _SeedPlan(
        IDS, 'private_restored_seed', SCOPE, PREFIX_SCOPE),
    True: _SeedPlan(CATALOG_IDS, 'private_restored_seed_catalog',
                    CATALOG_SCOPE, CATALOG_PREFIX_SCOPE),
    catalog.STAKE_DRAFT_FAMILY: _SeedPlan(
        ('stake',), 'private_restored_seed_catalog',
        CATALOG_SCOPE, CATALOG_PREFIX_SCOPE),
    catalog.PROJECT_DETAIL_FAMILY: _SeedPlan(
        ('project',), 'private_restored_project_catalog',
        PROJECT_SCOPE, PROJECT_PREFIX_SCOPE),
    catalog.PILLAR_SPAWN_FAMILY: _SeedPlan(
        PILLAR_SPAWN_IDS, 'private_restored_pillar_spawn',
        PILLAR_SPAWN_SCOPE, PILLAR_SPAWN_PREFIX_SCOPE, 4, 3, 2),
    catalog.PILLAR_DONE_FAMILY: _SeedPlan(
        PILLAR_DONE_IDS, 'private_restored_pillar_done',
        PILLAR_DONE_SCOPE, PILLAR_DONE_PREFIX_SCOPE, 4, 3, 2),
}
_PREFIX_RECIPES = {
    PREFIX_SCOPE: IDS,
    CATALOG_PREFIX_SCOPE: CATALOG_IDS,
    PROJECT_PREFIX_SCOPE: _PLANS[catalog.PROJECT_DETAIL_FAMILY].recipes,
    PILLAR_SPAWN_PREFIX_SCOPE: PILLAR_SPAWN_IDS,
    PILLAR_DONE_PREFIX_SCOPE: PILLAR_DONE_IDS,
}


def _plan(catalog_capture):
    need(type(catalog_capture) in (bool, str) and catalog_capture in _PLANS)
    return _PLANS[catalog_capture]


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


class PillarFixture(NamedTuple):
    actor: str
    producer: str
    reward: str


def pillar_fixture(genesis, members, upstream_readme):
    """Bind the copied wallet and the three Pillar roles to pinned lab inputs."""
    need(type(upstream_readme) is bytes and 0 < len(upstream_readme) <= 32768
        and hashlib.sha256(upstream_readme).hexdigest() == _PILLAR_FIXTURE_DOC_SHA256)
    pairs = re.findall(rb'(?m)^\|[ \t]*([0-9])[ \t]*\|[ \t]*'
        rb'`(z1[023456789acdefghjklmnpqrstuvwxyz]{38})`[ \t]*\|', upstream_readme)
    addresses = {int(index): value.decode('ascii') for index, value in pairs}
    need(len(pairs) == len(addresses) == len(set(addresses.values())) == 10
        and set(addresses) == set(range(10)))
    legacy_owner = counterparty(genesis, members)
    need(tuple(members) == (addresses[0], addresses[1]) and legacy_owner == addresses[5])
    fixture = PillarFixture(addresses[3], addresses[8], addresses[9])
    pillars = genesis['PillarConfig']['Pillars']
    for row in pillars:
        need(type(row.get('PillarType')) is int and row['PillarType'] == 1
            and all(type(row.get(key)) is str and row[key] in addresses.values()
                    and row[key] not in fixture for key in (
                        'StakeAddress', 'BlockProducingAddress', 'RewardWithdrawAddress')))
    need(all(type(genesis.get(key)) is dict
             for key in ('PlasmaConfig', 'TokenConfig', 'GenesisBlocks')))
    fusions = genesis['PlasmaConfig'].get('Fusions')
    need(type(fusions) is list and len(fusions) == 3 and all(
        type(row) is dict and row.get('owner') == addresses[1]
        and row.get('beneficiaryAddress') in (addresses[0], addresses[1])
        and type(row.get('amount')) is int and row['amount'] == 1000000000000
        for row in fusions))
    need(sum(row['beneficiaryAddress'] == addresses[1] for row in fusions) == 2)

    tokens = genesis['TokenConfig'].get('Tokens')
    need(type(tokens) is list and len(tokens) == 2 and all(type(row) is dict
        and type(row.get('tokenSymbol')) is str and type(row.get('tokenStandard')) is str
        and type(row.get('decimals')) is int and row['decimals'] == 8 for row in tokens))
    standards = {row['tokenSymbol']: row['tokenStandard'] for row in tokens}
    need(set(standards) == {'ZNN', 'QSR'} and len(set(standards.values())) == 2)
    blocks = genesis['GenesisBlocks'].get('Blocks')
    need(type(blocks) is list and len(blocks) == 7 and all(type(row) is dict
        and type(row.get('Address')) is str and type(row.get('BalanceList')) is dict
        for row in blocks))
    balances = {row['Address']: row['BalanceList'] for row in blocks}
    need(len(balances) == len(blocks))
    for address in fixture:
        balance = balances.get(address, {})
        for symbol, units in (('ZNN', 5000000000000), ('QSR', 50000000000000)):
            value = balance.get(standards[symbol])
            need(type(value) is int and value == units)
    return fixture


def _private_receipts(value, *, prefix=False, catalog_capture=False):
    plan = _plan(catalog_capture)
    ids = plan.recipes
    scope = plan.private_scope + ('_prefix' if prefix else '_receipts')
    membership = plan.membership
    fields = {'schema', 'scope', 'chain', 'owner_stable', 'receipts'} | membership.keys()
    need(type(value) is dict and set(value) == fields
        and type(value['schema']) is int and value['schema'] == 1
        and value['scope'] == scope
        and type(value['chain']) is int and value['chain'] == 321
        and all(type(value[key]) is type(expected) and value[key] == expected
                for key, expected in membership.items())
        and value['owner_stable'] is True
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
        and type(value['scope']) is str and value['scope'] in _PREFIX_RECIPES)
    ids = _PREFIX_RECIPES[value['scope']]
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
    scope = _plan(catalog_capture).prefix_scope
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
    need(recipe in (*IDS, *PILLAR_DONE_IDS[1:])
        and state in ('attempt', 'accepted', 'confirmed')
        and type(raw) is bytes and 0 < len(raw) <= 2048)
    value = json.loads(raw)
    need(type(value) is dict and set(value) ==
        {'recipe', 'chain', 'state'} | ({'hash'} if state != 'attempt' else set())
        and value['recipe'] == recipe and type(value['chain']) is int
        and value['chain'] == 321 and value['state'] == state
        and (state == 'attempt' or value['hash'] == original_hash))


def completed(value, *, catalog_capture=False):
    value = private_receipts(value, catalog_capture=catalog_capture)
    plan = _plan(catalog_capture)
    ids, scope = plan.recipes, plan.completed_scope
    return project(dict(schema=1, scope=scope, complete=True, chain=321,
        recipes=list(ids), confirmed=len(ids), owner_stable=True, journals_consistent=True,
        original_outcomes_preserved=True, receipts_sha256=digest(value), **plan.membership),
        catalog_capture=catalog_capture)


def project(value, *, catalog_capture=False):
    if value is None:
        return None
    plan = _plan(catalog_capture)
    ids, scope = plan.recipes, plan.completed_scope
    common = {'schema', 'scope', 'complete'}
    need(type(value) is dict and common <= set(value)
        and type(value['schema']) is int and value['schema'] == 1
        and value['scope'] == scope and type(value['complete']) is bool)
    if not value['complete']:
        need(set(value) == common)
        return dict(value)
    membership = plan.membership
    need(set(value) == common | membership.keys() | {'chain', 'recipes', 'confirmed',
        'owner_stable', 'journals_consistent', 'original_outcomes_preserved', 'receipts_sha256'}
        and type(value['chain']) is int and value['chain'] == 321
        and value['recipes'] == list(ids)
        and type(value['confirmed']) is int and value['confirmed'] == len(ids)
        and all(type(value[key]) is type(expected) and value[key] == expected
                for key, expected in membership.items())
        and all(value[key] is True for key in ('owner_stable', 'journals_consistent',
            'original_outcomes_preserved'))
        and type(value['receipts_sha256']) is str
        and re.fullmatch('[a-f0-9]{64}', value['receipts_sha256']))
    return dict(value)
