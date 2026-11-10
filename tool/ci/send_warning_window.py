"""Own the two finite markers of one isolated Send warning observation."""

from contextlib import ExitStack
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


def window_receipt(value, *, complete=False):
    _require(type(value) is dict and set(value) == {'started', 'released', 'samples'}
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
    _require(not complete or (value['started'] and value['released']
                              and len(samples) == len(THEMES)))
    return value


class _SyncRequest:
    def _payload(self, method, params):
        _require(method == 'stats.syncInfo' and type(params) is list
                 and not params and self.next_id == 0)
        self.next_id = 1
        return b'{"jsonrpc":"2.0","id":1,"method":"stats.syncInfo","params":[]}'


class _SyncHttp(_SyncRequest, policy.HttpRpc):
    pass


class _SyncWs(_SyncRequest, policy.WsRpc):
    pass


class SendWarningWindow:
    def __init__(self, path, require_original):
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

    def receipt(self):
        return window_receipt(dict(started=self._began is not None,
            released=self._released, samples=list(self._samples)))

    def release_if_owned(self):
        if self._began is not None and not self._release_attempted:
            self.release()

    def sample(self, theme):
        index = len(self._samples)
        _require(index < len(THEMES) and theme == THEMES[index]
                 and self._deadline is not None and time.monotonic() < self._deadline)
        self._current()
        http_wire, ws_wire = make_transports()
        limits = policy.Limits(total=8, request=2, close=1)
        limits.validate()
        deadline = policy._Deadline(time.monotonic, time.monotonic() + limits.total)
        http = _SyncHttp(http_wire, limits, deadline, secrets.token_bytes)
        ws = _SyncWs(ws_wire, limits, deadline, secrets.token_bytes)
        with ExitStack() as wires:
            wires.callback(http.close)
            wires.callback(ws.close)
            ws.connect()
            first = http.call('stats.syncInfo', [])
            second = ws.call('stats.syncInfo', [])
        _require(time.monotonic() < self._deadline)
        observation = dict(theme=theme, **self.observed_lag(first, second))
        window_receipt(dict(started=True, released=False,
                            samples=[*self._samples, observation]))
        self._samples.append(observation)

    def _current(self):
        self._original()
        _require(_identity(self.path) == self._owner)

    def begin(self):
        _require(not self._start_attempted)
        self._current()
        _require(_identity(self._begin) is None and _identity(self._release) is None)
        self._start_attempted = True
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

    def observed_lag(self, http, ws):
        _require(self._began is not None and not self._release_attempted)
        self._current()
        _require(_identity(self._begin) == self._began and _identity(self._release) is None)
        first, second = lab_failure_probe.sync(http), lab_failure_probe.sync(ws)
        height = first['current_height']
        target = min(first['target_height'], second['target_height'])
        _require(first['state'] == second['state'] == 1 and height > 0
                 and height == second['current_height'] and target - height >= 3)
        return dict(state=1, current_height=height, minimum_target_height=target,
                    minimum_lag=target - height)
