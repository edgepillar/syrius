"""Three passive reads of an already owned, failed native lab; no runtime API."""

from __future__ import annotations

import json
import secrets
import time

from tools.devnet.lab import owned_lab as policy
from tools.devnet.lab.socket_transport import make_transports


READS = (
    ('network', 'stats.networkInfo'),
    ('sync', 'stats.syncInfo'),
    ('frontier', 'ledger.getFrontierMomentum'),
)
SCOPE = 'owned_lab_failure_probe'
PHASE = 'after_wallet_failure_before_node_shutdown'
MAXIMUM = 9007199254740991
CODES = frozenset(('READ_REFUSED', 'OWNER_REFUSED', 'CLOSE_UNKNOWN',
    'DEADLINE', 'WIRE_REFUSED', 'WIRE_EOF', 'WIRE_OVERFLOW', 'HTTP_REFUSED',
    'RPC_REFUSED', 'FRONTIER_REFUSED', 'FRONTIER_REGRESSED'))


class Refused(ValueError):
    pass


def need(value):
    if not value:
        raise Refused('PROBE_REFUSED')


def integer(value, maximum=MAXIMUM):
    return type(value) is int and 0 <= value <= maximum


class _StatusReads(policy.HttpRpc):
    """A separate fixed sequence; the original ledger client is unchanged."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.close_unknown = False

    def _close(self, wire):
        try:
            return super()._close(wire)
        except BaseException:
            self.close_unknown = True
            raise

    def _payload(self, method, params):
        policy._require(self.next_id < len(READS)
            and type(method) is str
            and method == READS[self.next_id][1]
            and type(params) is list and not params, 'RPC_REFUSED')
        self.next_id += 1
        return json.dumps(dict(jsonrpc='2.0', id=self.next_id, method=method,
                               params=[]), separators=(',', ':')).encode()


def network(value):
    need(type(value) is dict and integer(value.get('numPeers'), 128)
         and type(value.get('peers')) is list and len(value['peers']) <= 128
         and all(type(peer) is dict for peer in value['peers']))
    # The node computes these separately; their equality is not assumed.
    return dict(reported_peers=value['numPeers'], listed_peers=len(value['peers']))


def sync(value):
    need(type(value) is dict and type(value.get('state')) is int
         and value['state'] in (1, 2, 3)
         and all(integer(value.get(key)) for key in ('currentHeight', 'targetHeight')))
    return dict(state=value['state'], current_height=value['currentHeight'],
                target_height=value['targetHeight'])


def frontier(value):
    original = policy.Momentum.parse(value)
    need(integer(original.height) and integer(original.timestamp))
    return dict(height=original.height, timestamp=original.timestamp)


def unavailable():
    """An unexpected collection failure supplies no invented read/close counts."""
    return dict(schema=1, scope=SCOPE, phase=PHASE, status='UNAVAILABLE')


def project(value):
    """Exact data only; no peer, wallet, runtime or retry capability is returned."""
    if value is None:
        return None
    fixed = {'schema', 'scope', 'phase', 'status'}
    need(type(value) is dict and type(value.get('schema')) is int
         and value['schema'] == 1 and value.get('scope') == SCOPE
         and value.get('phase') == PHASE)
    if value.get('status') == 'UNAVAILABLE':
        need(set(value) == fixed)
        return unavailable()
    need(value.get('status') == 'SAMPLED'
         and set(value) == fixed | {'attempted', 'opened_wires', 'wires_closed',
             'ownership_current', 'network', 'sync', 'frontier'}
         and integer(value['attempted'], 3)
         and integer(value['opened_wires'], value['attempted'])
         and type(value['wires_closed']) is bool
         and type(value['ownership_current']) is bool)
    result = {key: value[key] for key in fixed | {'attempted', 'opened_wires',
                                                 'wires_closed', 'ownership_current'}}
    fields = dict(network={'reported_peers', 'listed_peers'},
                  sync={'state', 'current_height', 'target_height'},
                  frontier={'height', 'timestamp'})
    observed = 0
    ended = False
    owner_refused = False
    for name, _ in READS:
        item = value[name]
        need(type(item) is dict and type(item.get('status')) is str)
        status = item['status']
        if status == 'NOT_READ':
            need(set(item) == {'status'})
            ended = True
        else:
            need(not ended)
            observed += 1
            if status == 'REFUSED':
                need(set(item) == {'status', 'code'}
                     and type(item['code']) is str and item['code'] in CODES)
                owner_refused = owner_refused or item['code'] == 'OWNER_REFUSED'
            else:
                need(status == 'OBSERVED' and set(item) == fields[name] | {'status'})
                if name == 'network':
                    need(all(integer(item[key], 128) for key in fields[name]))
                elif name == 'sync':
                    need(type(item['state']) is int and item['state'] in (1, 2, 3)
                         and all(integer(item[key]) for key in ('current_height', 'target_height')))
                else:
                    need(all(integer(item[key]) and item[key] > 0 for key in fields[name]))
        result[name] = dict(item)
    need(observed == value['attempted']
         and (not value['ownership_current'] or observed == 3)
         and (not owner_refused or not value['ownership_current']))
    return result


def collect(require_owned, *, transports=make_transports, clock=time.monotonic):
    """One attempt per fixed read, under the original node ownership check."""
    http_wire, _ = transports()
    limits = policy.Limits(total=8, request=2, close=1, header_bytes=4096,
                           response_bytes=65536, frame_bytes=65536, reads=1024)
    limits.validate()
    client = _StatusReads(http_wire, limits,
        policy._Deadline(clock, clock() + limits.total), secrets.token_bytes)
    result = dict(schema=1, scope=SCOPE, phase=PHASE, status='SAMPLED',
        attempted=0, opened_wires=0, wires_closed=True, ownership_current=True,
        **{name: dict(status='NOT_READ') for name, _ in READS})
    reducers = dict(network=network, sync=sync, frontier=frontier)
    try:
        for name, method in READS:
            try:
                require_owned()
            except Exception:
                result['ownership_current'] = False
                break
            result['attempted'] += 1
            try:
                raw = client.call(method, [])
                result[name] = dict(status='OBSERVED', **reducers[name](raw))
            except Exception as error:
                code = error.code if isinstance(error, policy.Refused) else 'READ_REFUSED'
                code = code if code in CODES else 'READ_REFUSED'
                result[name] = dict(status='REFUSED', code=code)
                if code == 'CLOSE_UNKNOWN':
                    result['wires_closed'] = False
            try:
                require_owned()
            except Exception:
                result['ownership_current'] = False
                if result[name]['status'] == 'OBSERVED':
                    result[name] = dict(status='REFUSED', code='OWNER_REFUSED')
                break
    finally:
        result['opened_wires'] = len(client.seen_wires)
        try:
            client.close()
        except Exception:
            result['wires_closed'] = False
        result['wires_closed'] = result['wires_closed'] and not client.close_unknown
    return project(result)
