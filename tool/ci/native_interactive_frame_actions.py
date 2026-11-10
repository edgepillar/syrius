"""Observe the same original actions in the current and P06 harness builds."""

import time


MIN_WINDOW_US = 600_000
MAX_WINDOW_US = 2_500_000


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


def _end(send, validate_window):
    reply = _original(send, cmd='stalls', frameWindow='end')
    fields = ('schema', 'scope', 'windowUs', 'frames')
    _require(all(field in reply for field in fields))
    window = {field: reply[field] for field in fields}
    validate_window(window)
    return window


def _measure(send, validate_window, sleep, selector):
    reply = _original(send, cmd='stalls', frameWindow='begin')
    _require(reply.get('frameWindow') == 'collecting')
    _target(_original(send, cmd='tap', settleMs=0, **selector), **selector)
    sleep(0.6)
    window = _end(send, validate_window)
    _require(MIN_WINDOW_US <= window['windowUs'] <= MAX_WINDOW_US)
    return window


def observe_interactive(send, validate_window, *, size, windows=None, sleep=time.sleep):
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
    page = _measure(send, validate_window, sleep, {'tab': 'settings'})
    _wait(send, 'settings_node')
    _wallet(send, 'settings', size, address)
    windows['page_change'] = page

    _target(_original(send, cmd='tap', key='settings_about'), key='settings_about')
    _wait(send, 'about_licences_toggle')
    _licences(send, gone=True)
    disclosure = _measure(send, validate_window, sleep,
                          {'key': 'about_licences_toggle'})
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
    return windows
