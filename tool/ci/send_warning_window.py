"""Own the two finite markers of one isolated Send warning observation."""

from contextlib import ExitStack, closing
import http.client
import secrets
import time

from . import lab_failure_probe
from tools.devnet.lab import owned_lab as policy
from tools.devnet.lab.socket_transport import make_transports


FAMILY = 'send-warn'
ENVIRONMENT = 'SYRIUS_LAB_SEND_WARN_DIR'
COMPILED_TREE = 'ce05297713a87313e07759f7c1299fc36878b39f'
PATCH = 'tool/ci/node_fixtures/send_warning_handler.patch'
SOURCE_PINS = {
    'tool/ci/node_fixtures/send_warning_handler.patch':
        '92511b78c7da1b0c5051100c42892c95efb51087be12849c14b611a83c73de86',
    'tool/ci/node_fixtures/syrius_send_warning_fixture.go':
        '0b49f11bdc5f4f9f5a82d51d2e0796136869a0014929ad4ad2a99ddd7f05f152',
    'tool/ci/node_fixtures/syrius_send_warning_fixture_test.go':
        'f0f527032695cb6df9498b63450d9e47e532fd256821c3d01d3731ef94bed3b2',
}
TESTS = (
    'TestSyriusSendWarningFixturePreservesOriginalInsert',
    'TestSyriusSendWarningFixtureRefusesInvalidMarkers',
    'TestSyriusSendWarningFixtureBoundsWaitAndHonorsShutdown',
)
PACKAGE = 'github.com/zenon-network/go-zenon/protocol'
THEMES = ('dark', 'light')
SECONDS = 90
READINESS_INTERVAL = 5
READINESS_ATTEMPTS = 9
CAPTURE_RESERVE = 45
PRODUCER_PORTS = {'pillar': 46011, 'pillar2': 46012, 'pillar3': 46013}
PRODUCER_READ_BYTES = 2048
PRODUCER_READ_SECONDS = 3
_SYNC_BODY = b'{"jsonrpc":"2.0","id":1,"method":"stats.syncInfo","params":[]}'


class SendWarningWindowRefused(Exception):
    code = 'SEND_WARNING_WINDOW_REFUSED'

    def __init__(self):
        super().__init__(self.code)


def _require(value):
    if not value:
        raise SendWarningWindowRefused()


def _identity(path):
    from .windows_wallet_tour import directory_identity

    try:
        result = directory_identity(path.lstat())
    except FileNotFoundError:
        return None
    _require(result is not None)
    return result


def test_receipt(value):
    return (type(value) is dict and set(value) == {'passed', 'tests', 'skips'}
            and value['passed'] is True and value['tests'] == list(TESTS)
            and type(value['skips']) is int and value['skips'] == 0)


def _positive_lag(http, ws):
    height = http['current_height']
    target = min(http['target_height'], ws['target_height'])
    if (http['state'] == ws['state'] == 1 and height > 0
            and height == ws['current_height'] and target - height >= 3):
        return dict(state=1, current_height=height,
                    minimum_target_height=target, minimum_lag=target - height)
    return None


def _readiness_lag(value):
    _require(type(value) is dict and set(value) == {
        'attempts', 'read_refused', 'first', 'last'}
        and type(value['attempts']) is int
        and 0 <= value['attempts'] <= READINESS_ATTEMPTS
        and type(value['read_refused']) is bool)
    count = value['attempts'] - int(value['read_refused'])
    _require(count >= 0)
    first, last = value['first'], value['last']
    if count == 0:
        _require(first is last is None)
        return None
    for pair in (first, last):
        _require(type(pair) is dict and set(pair) == {'http', 'ws'})
        for row in pair.values():
            _require(type(row) is dict and set(row) == {
                'state', 'current_height', 'target_height'}
                and type(row['state']) is int and row['state'] in (1, 2, 3)
                and all(lab_failure_probe.integer(row[key]) for key in (
                    'current_height', 'target_height')))
    _require(first == last if count == 1 else _positive_lag(**first) is None)
    lag = _positive_lag(**last)
    _require(not value['read_refused'] or lag is None)
    return lag


def window_receipt(value, *, complete=False):
    # Older reports may have neither the readiness nor producer observations.
    required = {'started', 'released', 'samples'}
    _require(type(value) is dict and required <= set(value) <= required | {
        'readiness', 'producer_progress'}
             and type(value['started']) is type(value['released']) is bool
             and type(value['samples']) is list and len(value['samples']) <= len(THEMES)
             and (value['started'] or not value['released'] and not value['samples']))
    samples = value['samples']
    for sample, theme in zip(samples, THEMES):
        _require(type(sample) is dict and set(sample) == {
            'theme', 'state', 'current_height', 'minimum_target_height', 'minimum_lag'}
            and sample['theme'] == theme and type(sample['state']) is int
            and sample['state'] == 1
            and all(lab_failure_probe.integer(sample[key]) for key in (
                'current_height', 'minimum_target_height', 'minimum_lag'))
            and sample['current_height'] == samples[0]['current_height'] > 0
            and sample['minimum_target_height'] - sample['current_height'] ==
                sample['minimum_lag'] >= 3)
    if 'readiness' in value:
        readiness = value['readiness']
        lag = _readiness_lag(readiness)
        _require(value['started'] or readiness['attempts'] == 0)
        _require(not samples or (lag is not None
                                  and samples[0]['current_height'] == lag['current_height']))
    if 'producer_progress' in value:
        progress = value['producer_progress']
        _require(type(progress) is dict and set(progress) == {'before', 'after_refusal'})
        for heights in progress.values():
            _require(heights is None or (type(heights) is dict
                and heights.keys() == PRODUCER_PORTS.keys()
                and all(height is None or (lab_failure_probe.integer(height) and height > 0)
                        for height in heights.values())))
        _require(not value['started'] or progress['before'] is not None)
        _require(progress['after_refusal'] is None or (value['started'] and not samples
                 and 'readiness' in value and lag is None))
    _require(not complete or (value['started'] and value['released']
                              and len(samples) == len(THEMES)))
    return value


class _SyncRequest:
    def _payload(self, method, params):
        _require(method == 'stats.syncInfo' and type(params) is list
                 and not params and self.next_id == 0)
        self.next_id = 1
        return _SYNC_BODY


class _SyncHttp(_SyncRequest, policy.HttpRpc):
    pass


class _SyncWs(_SyncRequest, policy.WsRpc):
    pass


def _producer_height(port, require_original, deadline):
    try:
        require_original()
        timeout = min(1, deadline - time.monotonic())
        if timeout <= 0:
            return None
        with closing(http.client.HTTPConnection('127.0.0.1', port, timeout=timeout)) as wire:
            wire.request('POST', '/', body=_SYNC_BODY, headers={'Content-Type': 'application/json',
                'Accept-Encoding': 'identity', 'Connection': 'close'})
            with wire.getresponse() as reply:
                if (reply.status != 200 or reply.getheader('Content-Encoding', 'identity') != 'identity'
                        or reply.getheader('Content-Type', '').split(';', 1)[0].strip().lower() != 'application/json'):
                    return None
                raw = bytearray()
                while time.monotonic() < deadline:
                    chunk = reply.read1(PRODUCER_READ_BYTES + 1 - len(raw))
                    if not chunk:
                        break
                    raw.extend(chunk)
                    if len(raw) > PRODUCER_READ_BYTES:
                        return None
                else:
                    return None
                if not reply.isclosed() or reply.length not in (0, None):
                    return None
        require_original()
        if time.monotonic() >= deadline:
            return None
        limits = policy.Limits(response_bytes=PRODUCER_READ_BYTES)
        value = lab_failure_probe.sync(policy._json(bytes(raw), 1, limits))
        return value['current_height'] or None
    except Exception:
        # A diagnostic read cannot change the admission or its original error.
        return None


def _producer_heights(require_original, limit):
    deadline = min(limit, time.monotonic() + PRODUCER_READ_SECONDS)
    return {role: _producer_height(port, require_original, deadline)
            for role, port in PRODUCER_PORTS.items()}


class SendWarningWindow:
    def __init__(self, path, require_original, *, probe_producers=False):
        _require(path.is_absolute())
        self.path = path
        self._original = require_original
        self._owner = _identity(path)
        _require(self._owner is not None)
        self._begin = path / 'begin'
        self._release = path / 'release'
        self._began = None
        self._start_attempted = False
        self._release_attempted = False
        self._released = False
        self._deadline = None
        self._samples = []
        self._readiness = dict(attempts=0, read_refused=False, first=None, last=None)
        self._producer_progress = dict(before=None, after_refusal=None) if probe_producers else None

    def receipt(self):
        value = dict(started=self._began is not None,
            released=self._released, samples=list(self._samples),
            readiness=dict(self._readiness))
        if self._producer_progress is not None:
            value['producer_progress'] = dict(self._producer_progress)
        return window_receipt(value)

    def release_if_owned(self):
        if self._began is not None and not self._release_attempted:
            self.release()

    def wait_until_ready(self, limit):
        """Observe actual RPC lag before admitting the wallet's wait."""
        _require(self._deadline is not None and self._readiness['attempts'] == 0)
        cutoff = min(limit, self._deadline) - CAPTURE_RESERVE
        while (self._readiness['attempts'] < READINESS_ATTEMPTS
               and time.monotonic() < cutoff):
            self._readiness['attempts'] += 1
            self._readiness['read_refused'] = True
            pair = self._read_pair(cutoff)
            self._readiness['read_refused'] = False
            if self._readiness['first'] is None:
                self._readiness['first'] = pair
            self._readiness['last'] = pair
            if _positive_lag(**pair) is not None:
                return
            remaining = cutoff - time.monotonic()
            if remaining > 0 and self._readiness['attempts'] < READINESS_ATTEMPTS:
                time.sleep(min(READINESS_INTERVAL, remaining))
        if self._producer_progress is not None:
            self._producer_progress['after_refusal'] = _producer_heights(
                self._active, min(limit, self._deadline))
        raise SendWarningWindowRefused()

    def sample(self, theme):
        index = len(self._samples)
        _require(index < len(THEMES) and theme == THEMES[index]
                 and self._deadline is not None
                 and _readiness_lag(self._readiness) is not None)
        pair = self._read_pair(self._deadline)
        lag = _positive_lag(**pair)
        _require(lag is not None)
        observation = dict(theme=theme, **lag)
        window_receipt(dict(started=True, released=False,
            samples=[*self._samples, observation], readiness=self._readiness))
        self._samples.append(observation)

    def _read_pair(self, limit):
        self._active()
        now = time.monotonic()
        _require(now < limit)
        http_wire, ws_wire = make_transports()
        limits = policy.Limits(total=8, request=2, close=1)
        limits.validate()
        deadline = policy._Deadline(time.monotonic, min(limit, now + limits.total))
        http = _SyncHttp(http_wire, limits, deadline, secrets.token_bytes)
        ws = _SyncWs(ws_wire, limits, deadline, secrets.token_bytes)
        try:
            with ExitStack() as wires:
                wires.callback(http.close)
                wires.callback(ws.close)
                ws.connect()
                first = http.call('stats.syncInfo', [])
                second = ws.call('stats.syncInfo', [])
            pair = dict(http=lab_failure_probe.sync(first),
                        ws=lab_failure_probe.sync(second))
        except lab_failure_probe.Refused:
            raise SendWarningWindowRefused() from None
        _require(time.monotonic() < limit)
        self._active()
        return pair

    def _current(self):
        self._original()
        _require(_identity(self.path) == self._owner)

    def begin(self, *, limit=None):
        _require(not self._start_attempted)
        self._current()
        _require(_identity(self._begin) is None and _identity(self._release) is None)
        self._start_attempted = True
        if self._producer_progress is not None:
            _require(limit is not None)
            self._producer_progress['before'] = _producer_heights(self._current, limit)
            self._current()
            _require(time.monotonic() < limit
                     and _identity(self._begin) is None and _identity(self._release) is None)
        self._deadline = time.monotonic() + SECONDS
        self._begin.mkdir(mode=0o700)
        self._current()
        self._began = _identity(self._begin)
        _require(self._began is not None and _identity(self._release) is None)

    def release(self, *, within_window=False):
        _require(not within_window or (self._deadline is not None
                                       and time.monotonic() < self._deadline))
        _require(self._began is not None and not self._release_attempted)
        self._current()
        _require(_identity(self._begin) == self._began and _identity(self._release) is None)
        self._release_attempted = True
        self._release.mkdir(mode=0o700)
        self._current()
        _require(_identity(self._begin) == self._began and _identity(self._release) is not None)
        self._released = True

    def _active(self):
        _require(self._began is not None and not self._release_attempted)
        self._current()
        _require(_identity(self._begin) == self._began and _identity(self._release) is None)
