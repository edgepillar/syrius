"""Observe the same original actions in the current and P06 harness builds."""

import time

from . import windows_startup_probe as startup
from .windows_launch_catalog import PEAK_BUILD_WAIT_FIELD, RASTER_STARTS_FIELD, TIMING_FIELDS


MIN_WINDOW_US = 600_000
MAX_WINDOW_US = 2_500_000
IDLE_WINDOW_US = 1_100_000
MAX_IDLE_FRAMES = 96


class FrameActionRefused(RuntimeError):
    """The original replies did not establish the measured action."""


def _require(condition):
    if not condition:
        raise FrameActionRefused('native frame action refused')


def _original(send, **command):
    reply = send(command)
    _require(type(reply) is dict and reply.get('ok') is True)
    return reply


def _target(reply, **fields):
    target = reply.get('target')
    _require(type(target) is dict
             and all(target.get(key) == value for key, value in fields.items()))
    return target


def _wallet(send, tab, size, address=None):
    state = _original(send, cmd='state')
    selected = state.get('address')
    _require(state.get('booted') is True and state.get('tab') == tab
             and state.get('size') == size
             and state.get('walletUnlocked') is True
             and state.get('walletInitCompleted') is True
             and state.get('node') == 'ws://127.0.0.1:45998'
             and state.get('chainId') == state.get('signingChainId') == 321
             and state.get('nodeTransitionPending') is False
             and type(selected) is str and bool(selected)
             and (address is None or selected == address))
    return selected


def _wait(send, key):
    return _target(_original(send, cmd='wait', key=key, timeoutMs=5000), key=key)


def _licences(send, *, gone=False):
    reply = _original(send, cmd='wait', type='Licences', timeoutMs=5000,
                      **({'gone': True} if gone else {}))
    if gone:
        _require('target' not in reply)
    else:
        path = _target(reply).get('path')
        _require(type(path) is list and 'Licences' in path)


def _end(send, validate_window, phase_field):
    reply = _original(send, cmd='stalls', frameWindow='end')
    _require(all(field in reply for field in TIMING_FIELDS))
    window = {field: reply[field] for field in TIMING_FIELDS}
    for field in (PEAK_BUILD_WAIT_FIELD, RASTER_STARTS_FIELD):
        if field in reply:
            window[field] = reply[field]
    validate_window(window)
    return window, reply.get(phase_field)


def valid_disclosure_phases(value, release, window_us):
    return (type(value) is dict and bool(value)
            and set(value) <= {'settled', 'list_laid_out'}
            and type(release) is int and type(window_us) is int
            and all(type(offset) is int and release <= offset < window_us
                    for offset in value.values()))


def valid_page_settlement(value, release, window_us):
    return type(release) is int and type(value) is int and release <= value < window_us


def valid_pointer_phases(value, release):
    return (type(value) is dict and set(value) == {'move_started', 'down'}
            and type(release) is int
            and all(type(offset) is int for offset in value.values())
            and 0 <= value['move_started'] <= value['down'] <= release)


def _measure(send, validate_window, sleep, selector, phase_field):
    reply = _original(send, cmd='stalls', frameWindow='begin')
    _require(reply.get('frameWindow') == 'collecting')
    tap = _original(send, cmd='tap', settleMs=0, **selector)
    _target(tap, **selector)
    sleep(0.6)
    window, phases = _end(send, validate_window, phase_field)
    _require(MIN_WINDOW_US <= window['windowUs'] <= MAX_WINDOW_US)
    field = 'frameWindowTapReleaseUs'
    release = tap.get(field)
    if field in tap:
        _require(type(release) is int and 0 <= release < window['windowUs'])
    pointer_field = 'frameWindowPointerPhasesUs'
    pointers = tap.get(pointer_field)
    if pointer_field in tap:
        _require(valid_pointer_phases(pointers, release))
    return window, release, phases, pointers


def _observe_idle(send, validate_window, sleep):
    """Read a separate quiet window from the same open Licences view."""
    sleep(1.0)
    try:
        reply = _original(send, cmd='stalls', frameWindow='begin')
        _require(reply.get('frameWindow') == 'collecting')
        sleep(IDLE_WINDOW_US / 1_000_000)
        window, _ = _end(send, validate_window, None)
        _require(IDLE_WINDOW_US <= window['windowUs'] <= MAX_WINDOW_US
                 and len(window['frames']) <= MAX_IDLE_FRAMES)
        return dict(status='measured', window=window)
    except startup.Failure as error:
        if error.code != 'COMMAND_FAILED':
            raise
    except FrameActionRefused:
        pass
    return dict(status='unavailable')


def observe_interactive(send, validate_window, *, size, windows=None,
                        tap_releases=None, disclosure_phases=None,
                        page_phases=None, pointer_phases=None, idle_sample=None,
                        sleep=time.sleep):
    """Observe Home to Settings and the closed About licences disclosure.

    The caller binds the owned release process and profile. A confirmed page
    window stays available if the disclosure later refuses. Only numeric frame
    data is retained.
    """
    windows = {} if windows is None else windows
    _require(type(windows) is dict and not windows)
    theme = _original(send, cmd='theme')
    _require(theme.get('mode') == theme.get('brightness') == 'dark'
             and theme.get('savedMode') == 'ThemeMode.dark')
    address = _wallet(send, 'dashboard', size)
    page, page_release, page_settlement, page_pointer = _measure(
        send, validate_window, sleep, {'tab': 'settings'}, 'interactivePageSettledUs')
    _wait(send, 'settings_node')
    _wallet(send, 'settings', size, address)
    windows['page_change'] = page
    if tap_releases is not None and page_release is not None:
        tap_releases['page_change'] = page_release
    if pointer_phases is not None and page_pointer is not None:
        pointer_phases['page_change'] = page_pointer
    if page_phases is not None and valid_page_settlement(page_settlement, page_release, page['windowUs']):
        page_phases['settled'] = page_settlement

    _target(_original(send, cmd='tap', key='settings_about'), key='settings_about')
    _wait(send, 'about_licences_toggle')
    _licences(send, gone=True)
    disclosure, disclosure_release, phases, disclosure_pointer = _measure(
        send, validate_window, sleep, {'key': 'about_licences_toggle'},
        'interactiveDisclosurePhasesUs')
    # The redesigned list can start below the visible scroll area. Reveal it
    # after closing the timing window so the scroll is outside the sample.
    shown = _original(send, cmd='scroll', key='about_licences_toggle', dy=300)
    at = shown.get('at')
    _require(type(at) is list and len(at) == len(size) == 2
             and all(type(value) is int and 0 <= value < limit
                     for value, limit in zip(at, size)))
    _licences(send)
    _wallet(send, 'settings', size, address)
    windows['disclosure'] = disclosure
    if tap_releases is not None and disclosure_release is not None:
        tap_releases['disclosure'] = disclosure_release
    if pointer_phases is not None and disclosure_pointer is not None:
        pointer_phases['disclosure'] = disclosure_pointer
    if (disclosure_phases is not None and valid_disclosure_phases(
            phases, disclosure_release, disclosure['windowUs'])):
        disclosure_phases.update(phases)
    if idle_sample is not None:
        _require(type(idle_sample) is dict and not idle_sample)
        idle_sample.update(_observe_idle(send, validate_window, sleep))
        _wallet(send, 'settings', size, address)
        _licences(send)
    return windows
