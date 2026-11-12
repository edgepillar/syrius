"""Inspect one fresh native wallet while its original five-node lab is owned.

Financial and copied-wallet flows are separate. Only closed-schema observations
and explicitly admitted English page captures can leave the isolated runner.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
import subprocess
import sys
import time

from . import windows_debug_loop as debug
from . import windows_wallet_tour as shared
from . import readonly_viewport_capture as viewport
from . import readonly_settings_capture as settings
from . import readonly_navigation_capture as navigation
from . import readonly_details_capture as details
from . import send_warning_window
from .windows_debug_process import IMAGE_NAMES
from .hosted_chain321 import (EARN_INSPECTION_SCHEMA, HOME_BELL_INSPECTION_SCHEMA,
    HOME_SEAMS_FAMILY, HOME_ZAP_PREVIEW_INSPECTION_SCHEMA,
    READONLY_CATALOG_SCHEMAS, SEND_CONFIRM_INSPECTION_SCHEMA, SENTINEL_INSPECTION_SCHEMA,
    SEND_WARNING_INSPECTION_SCHEMA, SETTINGS_SEAMS_FAMILY, SWAP_START_INSPECTION_SCHEMA,
    SURFACE_SEAMS_FAMILY, SURFACE_SEAMS_SCHEMA, WALLET_READY_INSPECTION_SCHEMA,
    readonly_catalog_family)


PAGES = shared.PAGES
THEMES = ('dark', 'light')
OUTPUT = Path('.harness/ci-wallet-inspection')
MAX_CAPTURE_TOTAL = 32 * 1024**2
MAX_MANIFEST = 128 * 1024
HOME_OUTPUT = Path('.harness/ci-home-catalog')
HOME_FILES = ('01-home-rest-dark.png', '01-home-rest-light.png')
MAX_HOME_CAPTURE_TOTAL = 4 * 1024**2
MAX_HOME_MANIFEST = 64 * 1024
HOME_SCRIPT = Path('harness/screens/home-rest.txt')
HOME_HIDDEN_SCRIPT = Path('harness/screens/home-hidden.txt')
HOME_STATE_FILES = HOME_FILES + ('03-home-hidden-dark.png', '03-home-hidden-light.png')
HOME_STATE_SCREENS = ('home-rest', 'home-hidden')
HOME_OPEN_SCRIPT = Path('harness/screens/home-open.txt')
HOME_OPEN_FILES = HOME_FILES + ('02-home-open-dark.png', '02-home-open-light.png') + HOME_STATE_FILES[2:]
HOME_OPEN_SCREENS = ('home-rest', 'home-open', 'home-hidden')
HOME_GOTO_SCRIPT = Path('harness/screens/home-goto.txt')
HOME_GOTO_FILES = HOME_OPEN_FILES + ('05-home-goto-dark.png', '05-home-goto-light.png')
HOME_GOTO_SCREENS = HOME_OPEN_SCREENS + ('home-goto',)
HOME_BELL_SCRIPT = Path('harness/screens/home-bell.txt')
HOME_BELL_FILES = ('04-home-bell-dark.png', '04-home-bell-light.png')
HOME_BELL_CAPTURE_SCHEMA = 5
HOME_CAPTURE_SCHEMAS = {'home': 4, 'home-bell': HOME_BELL_CAPTURE_SCHEMA}
HOME_INSPECTION_SCHEMAS = (1, HOME_BELL_INSPECTION_SCHEMA)
CHECKS = ('environment', 'source', 'unused_destinations', 'job_owned',
    'entry_gate', 'entry_ready', 'application_owned', 'lab_revalidated',
    'input_released', 'wallet_bound', 'tours_complete', 'locale_verified',
    'captures', 'close_ack', 'application_exit', 'entry_exit',
    'output_complete', 'source_unchanged', 'auxiliary_cleanup')
TOUR_CHECKS = ('tours_complete', 'locale_verified')
CATALOG_ONLY_FAMILIES = {
    HOME_BELL_INSPECTION_SCHEMA: 'home-bell',
    SEND_CONFIRM_INSPECTION_SCHEMA: 'send-confirm',
    SWAP_START_INSPECTION_SCHEMA: 'swap-start',
    WALLET_READY_INSPECTION_SCHEMA: 'wallet-ready',
    SEND_WARNING_INSPECTION_SCHEMA: send_warning_window.FAMILY,
    HOME_ZAP_PREVIEW_INSPECTION_SCHEMA: 'home-zap-preview',
    EARN_INSPECTION_SCHEMA: 'earn',
    SENTINEL_INSPECTION_SCHEMA: 'sentinel-fixture',
    SURFACE_SEAMS_SCHEMA: SURFACE_SEAMS_FAMILY,
}
CODES = shared.CODES | shared.LAB_REVALIDATION_CODES | frozenset((
    'BINDING_REFUSED', 'INSPECTION_REFUSED', 'SEND_WARNING_WINDOW_REFUSED'))
STAGES = frozenset(('unused_destinations', 'build', 'start', 'input', 'window',
    'onboarding', 'signing_policy', 'onboarding_logs', 'address_selection',
    'wallet_binding', 'tour_dark', 'tour_light', 'home_catalog', 'settings_catalog',
    'navigation_catalog', *details.CATALOG_STAGES, 'viewport', 'finish'))


class Refused(Exception):
    def __init__(self, code):
        self.code = code if type(code) is str and code in CODES else 'INTERNAL_ERROR'
        super().__init__(self.code)


def need(value, code='INSPECTION_REFUSED'):
    if not value:
        raise Refused(code)


def inspection_failure_code(error, phase):
    return shared.project_failure_code(error, phase, CODES)


def read_original(path, cap):
    """Bound one original plain file and keep its identity across the read."""
    for parent in reversed(path.parents):
        need(stat.S_ISDIR(debug.bounded.plain(parent).st_mode), 'OUTPUT_REFUSED')
    before = debug.bounded.plain(path)

    def identity(info):
        need(stat.S_ISREG(info.st_mode) and info.st_nlink == 1
             and 0 < info.st_size <= cap, 'OUTPUT_REFUSED')
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns)

    expected = identity(before)
    with path.open('rb') as original:
        need(identity(os.fstat(original.fileno())) == expected, 'OUTPUT_REFUSED')
        raw = original.read(cap + 1)
        need(identity(os.fstat(original.fileno())) == expected, 'OUTPUT_REFUSED')
    need(identity(debug.bounded.plain(path)) == expected
         and len(raw) == before.st_size, 'OUTPUT_REFUSED')
    return raw


def home_catalog_files(schema):
    """Each version admits a finite literal family, never a generic alias."""
    need(type(schema) is int and schema in (1, 2, 3, 4, HOME_BELL_CAPTURE_SCHEMA),
         'CAPTURE_REFUSED')
    if schema == HOME_BELL_CAPTURE_SCHEMA:
        return HOME_BELL_FILES
    if schema == 1:
        return HOME_FILES
    if schema == 2:
        return HOME_STATE_FILES
    return HOME_OPEN_FILES if schema == 3 else HOME_GOTO_FILES


def home_catalog_screens(schema):
    home_catalog_files(schema)
    if schema == HOME_BELL_CAPTURE_SCHEMA:
        return ('home-bell',)
    if schema == 1:
        return ('home-rest',)
    if schema == 2:
        return HOME_STATE_SCREENS
    return HOME_OPEN_SCREENS if schema == 3 else HOME_GOTO_SCREENS


def home_capture_receipt(value):
    """Admit fixed metadata only after the original capture runner returns."""
    need(type(value) is dict, 'CAPTURE_REFUSED')
    schema = value.get('schema')
    files = home_catalog_files(schema)
    expected = dict(schema=schema, scope='readonly_native_home_catalog_capture',
        themes=list(THEMES), files=list(files),
        width=1280, height=780, scale=1, capture_returned=True)
    expected.update(dict(screen='home-rest', number=1) if schema == 1
                    else dict(screens=list(home_catalog_screens(schema))))
    need(set(value) == set(expected)
         and all(type(value[k]) is type(v) and value[k] == v
                 for k, v in expected.items()), 'CAPTURE_REFUSED')
    return value


def home_capture_records(value, *, schema=1):
    """The fixed filenames bind each state and theme in their original order."""
    files = home_catalog_files(schema)
    need(type(value) is list and len(value) == len(files), 'CAPTURE_REFUSED')
    for index, (row, name) in enumerate(zip(value, files)):
        theme = THEMES[index % len(THEMES)]
        need(type(row) is dict and set(row) ==
             {'theme', 'file', 'bytes', 'sha256', 'width', 'height', 'scale'}
             and row['theme'] == theme and row['file'] == name
             and type(row['bytes']) is int and 0 < row['bytes'] <= MAX_HOME_CAPTURE_TOTAL
             and type(row['sha256']) is str and re.fullmatch('[a-f0-9]{64}', row['sha256'])
             and all(type(row[k]) is int for k in ('width', 'height', 'scale'))
             and (row['width'], row['height'], row['scale']) == (1280, 780, 1),
             'CAPTURE_REFUSED')
    need(sum(row['bytes'] for row in value) <= MAX_HOME_CAPTURE_TOTAL, 'CAPTURE_REFUSED')
    if schema == HOME_BELL_CAPTURE_SCHEMA:
        need(len({row['sha256'] for row in value}) == len(files), 'CAPTURE_REFUSED')
    return value


def home_catalog_reference(value):
    need(type(value) is dict, 'CAPTURE_REFUSED')
    schema = value.get('schema')
    files = home_catalog_files(schema)
    expected = dict(schema=schema, scope='readonly_native_home_catalog_reference',
        captured=len(files))
    expected.update(dict(screen='home-rest') if schema == 1
                    else dict(screens=list(home_catalog_screens(schema))))
    need(set(value) == set(expected) | {'manifest_sha256'}
         and all(type(value[k]) is type(v) and value[k] == v
                 for k, v in expected.items())
         and type(value['manifest_sha256']) is str
         and re.fullmatch('[a-f0-9]{64}', value['manifest_sha256']), 'CAPTURE_REFUSED')
    return value


def _home_script_field(schema):
    home_catalog_files(schema)
    return 'script_sha256' if schema == 1 else 'script_sha256_by_screen'


def _home_script_pins(repo, schema):
    if schema == HOME_BELL_CAPTURE_SCHEMA:
        return {'home-bell': hashlib.sha256(
            read_original(repo / HOME_BELL_SCRIPT, 65536)).hexdigest()}
    first = hashlib.sha256(read_original(repo / HOME_SCRIPT, 65536)).hexdigest()
    if schema == 1:
        return first
    hidden = hashlib.sha256(read_original(repo / HOME_HIDDEN_SCRIPT, 65536)).hexdigest()
    if schema == 2:
        return dict(zip(HOME_STATE_SCREENS, (first, hidden)))
    pins = dict(zip(HOME_OPEN_SCREENS, (first,
        hashlib.sha256(read_original(repo / HOME_OPEN_SCRIPT, 65536)).hexdigest(), hidden)))
    if schema == 4:
        pins['home-goto'] = hashlib.sha256(read_original(repo / HOME_GOTO_SCRIPT, 65536)).hexdigest()
    return pins


def public_home_catalog(value):
    """This bundle cannot qualify its later parent closure or a match."""
    need(type(value) is dict, 'OUTPUT_REFUSED')
    schema = value.get('schema')
    home_catalog_files(schema)
    flags = {'inspection_only', 'parent_closure_qualified', 'atomic_frame_qualified',
             'wallet_qualified', 'seed_admitted', 'financial_send_qualified'}
    required = flags | {'schema', 'scope', 'source_sha', 'source_tree', 'run_id',
        'run_attempt', _home_script_field(schema), 'capture', 'captures', 'visual_matches'}
    need(set(value) == required
         and value['scope'] == 'readonly_native_home_catalog_capture_bundle'
         and all(type(value[k]) is bool for k in flags)
         and value['inspection_only'] is True
         and all(value[k] is False for k in flags - {'inspection_only'})
         and type(value['visual_matches']) is int and value['visual_matches'] == 0,
         'OUTPUT_REFUSED')
    for key in ('source_sha', 'source_tree'):
        need(type(value[key]) is str and re.fullmatch('[a-f0-9]{40}', value[key]), 'OUTPUT_REFUSED')
    need(type(value['run_id']) is str and re.fullmatch('[1-9][0-9]{0,19}', value['run_id'])
         and type(value['run_attempt']) is str and value['run_attempt'] == '1', 'OUTPUT_REFUSED')
    pins = value[_home_script_field(schema)]
    if schema == 1:
        pins = {'home-rest': pins}
    need(type(pins) is dict and set(pins) == set(
        home_catalog_screens(schema))
        and all(type(pin) is str and re.fullmatch('[a-f0-9]{64}', pin)
                for pin in pins.values()), 'OUTPUT_REFUSED')
    home_capture_receipt(value['capture'])
    need(value['capture']['schema'] == schema, 'OUTPUT_REFUSED')
    home_capture_records(value['captures'], schema=schema)
    return value


def home_output_bytes(output, *, schema=2):
    """Account this finite family, including incomplete original writes."""
    files = home_catalog_files(schema)
    if not output.exists() and not output.is_symlink():
        return 0
    root = debug.bounded.plain(output)
    need(stat.S_ISDIR(root.st_mode), 'STORAGE_REFUSED')
    allowed = {'manifest.json', *files}
    total = count = 0
    for path in output.iterdir():
        count += 1
        need(count <= len(allowed) and path.name in allowed, 'STORAGE_REFUSED')
        info = debug.bounded.plain(path)
        cap = MAX_HOME_MANIFEST if path.name == 'manifest.json' else MAX_HOME_CAPTURE_TOTAL
        need(stat.S_ISREG(info.st_mode) and info.st_nlink == 1
             and 0 <= info.st_size <= cap, 'STORAGE_REFUSED')
        total += info.st_size
    need(total <= MAX_HOME_CAPTURE_TOTAL + MAX_HOME_MANIFEST, 'STORAGE_REFUSED')
    return total


def collect_home_catalog(repo, receipt, source, tree, parent):
    """Retain original PNG references without another archive copy."""
    home_capture_receipt(receipt)
    schema = receipt['schema']
    output = repo / HOME_OUTPUT
    home_output_bytes(output, schema=schema)
    records = []
    for index, name in enumerate(home_catalog_files(schema)):
        raw = read_original(output / name, MAX_HOME_CAPTURE_TOTAL)
        debug.entry.png_bytes(base64.b64encode(raw).decode('ascii'))
        records.append(dict(theme=THEMES[index % len(THEMES)], file=name, bytes=len(raw),
            sha256=hashlib.sha256(raw).hexdigest(), width=1280, height=780, scale=1))
    home_capture_records(records, schema=schema)
    value = dict(schema=schema, scope='readonly_native_home_catalog_capture_bundle',
        source_sha=source, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
        run_attempt=parent['GITHUB_RUN_ATTEMPT'], capture=receipt, captures=records,
        inspection_only=True, parent_closure_qualified=False, atomic_frame_qualified=False,
        wallet_qualified=False, seed_admitted=False, financial_send_qualified=False,
        visual_matches=0)
    value[_home_script_field(schema)] = _home_script_pins(repo, schema)
    public_home_catalog(value)
    data = (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')
    need(len(data) <= MAX_HOME_MANIFEST, 'OUTPUT_REFUSED')
    with (output / 'manifest.json').open('xb') as stream:
        stream.write(data)
    home_output_bytes(output, schema=schema)
    reference = dict(schema=schema, scope='readonly_native_home_catalog_reference',
        captured=len(records), manifest_sha256=hashlib.sha256(data).hexdigest())
    reference.update(dict(screen='home-rest') if schema == 1
                     else dict(screens=list(home_catalog_screens(schema))))
    return home_catalog_reference(reference)


def home_artifact_paths(repo, report):
    """Only a completed generic parent can export every catalog original."""
    if report.get('success') is not True:
        return []
    need(completed(report), 'CAPTURE_REFUSED')
    reference = home_catalog_reference(report['home_catalog'])
    schema = reference['schema']
    output = repo / HOME_OUTPUT
    home_output_bytes(output, schema=schema)
    raw = read_original(output / 'manifest.json', MAX_HOME_MANIFEST)
    need(hashlib.sha256(raw).hexdigest() == reference['manifest_sha256'], 'CAPTURE_REFUSED')
    def unique(pairs):
        value = {}
        for key, item in pairs:
            need(key not in value, 'OUTPUT_REFUSED')
            value[key] = item
        return value

    value = public_home_catalog(json.loads(raw, object_pairs_hook=unique))
    need(value['schema'] == schema
         and all(value[k] == report[k] for k in
                 ('source_sha', 'source_tree', 'run_id', 'run_attempt'))
         and value[_home_script_field(schema)] == _home_script_pins(repo, schema),
         'SOURCE_REFUSED')
    paths = [str(HOME_OUTPUT / 'manifest.json').replace('\\', '/')]
    for row in home_capture_records(value['captures'], schema=schema):
        image = read_original(output / row['file'], MAX_HOME_CAPTURE_TOTAL)
        need(len(image) == row['bytes'] and hashlib.sha256(image).hexdigest() == row['sha256'],
             'CAPTURE_REFUSED')
        debug.entry.png_bytes(base64.b64encode(image).decode('ascii'))
        paths.append(str(HOME_OUTPUT / row['file']).replace('\\', '/'))
    return paths


def sdk_receipt(value):
    expected = dict(schema=1, scope='readonly_native_sdk_admission', status='CURRENT',
        publicationAdmissionPaused=True, automaticReceiveDisabled=True)
    need(type(value) is dict and set(value) == set(expected)
         and all(type(value[k]) is type(v) and value[k] == v for k, v in expected.items()))
    return value


def wallet_receipt(value):
    expected = dict(schema=1, scope='readonly_native_wallet_admission', status='CURRENT',
        chain=321, selectedIndex=1, nativeFrameObserved=True)
    need(type(value) is dict and set(value) == set(expected)
         and all(type(value[k]) is type(v) and value[k] == v for k, v in expected.items()),
         'BINDING_REFUSED')
    return value


def readonly_reply(value, pid, *, wallet=False):
    need(type(value) is dict and value.get('ok') is True
         and value.get('booted') is True and value.get('readOnly') is True
         and value.get('harnessMode') == 'readonly-native'
         and type(value.get('pid')) is int and value['pid'] == pid)
    sdk_receipt(value.get('readonlyAdmission'))
    if wallet:
        wallet_receipt(value.get('readonlyWallet'))
    return value


def ready_receipt(value):
    need(type(value) is dict and set(value) == {'schema', 'scope', 'pid', 'port'}
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'readonly_native_inspection_ready'
         and type(value['pid']) is int and 0 < value['pid'] < 2**32
         and type(value['port']) is int and 1024 <= value['port'] <= 65535,
         'ENTRY_REFUSED')
    return value


LAYOUT_KEYS = ('window-caption', 'window-body', 'home_hero', 'home_send', 'nodes_tab_pillars', 'nodes_tab_sentinels', 'staking_stake_button', 'plasma_open_fuse', 'tokens_filter_held', 'p2p_start_swap', 'node_settings_add', 'apps_settings_web_switch', 'transfer_card', 'accelerator_strip', 'bell_panel')
LAYOUT_STATUS = frozenset(('OBSERVED', 'MISSING', 'DUPLICATE', 'UNAVAILABLE', 'LIMIT'))


def layout_observation(value):
    """Only fixed keys and bounded numeric facts at two readback boundaries."""
    need(type(value) is dict and set(value) ==
         {'schema', 'scope', 'boundaries', 'before', 'after', 'unchanged'}
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'readonly_shot_layout_observation'
         and value['boundaries'] == ['before_raster', 'after_encoding']
         and type(value['unchanged']) is bool, 'CAPTURE_REFUSED')
    for boundary in ('before', 'after'):
        rows = value[boundary]
        need(type(rows) is list and len(rows) == len(LAYOUT_KEYS), 'CAPTURE_REFUSED')
        for row, key in zip(rows, LAYOUT_KEYS):
            need(type(row) is dict and row.get('key') == key
                 and type(row.get('status')) is str
                 and row['status'] in LAYOUT_STATUS, 'CAPTURE_REFUSED')
            need(set(row) == ({'key', 'status', 'rect'} if row['status'] == 'OBSERVED'
                              else {'key', 'status'}), 'CAPTURE_REFUSED')
            if row['status'] == 'OBSERVED':
                rect = row['rect']
                need(type(rect) is list and len(rect) == 4
                     and all(type(x) is int and abs(x) <= 32768 for x in rect)
                     and rect[2] >= rect[0] and rect[3] >= rect[1], 'CAPTURE_REFUSED')
        if any(row['status'] == 'LIMIT' for row in rows):
            need(all(row['status'] == 'LIMIT' for row in rows), 'CAPTURE_REFUSED')
    need(value['unchanged'] is (value['before'] == value['after']), 'CAPTURE_REFUSED')
    return value


def tour_receipt(value):
    need(type(value) is dict and set(value) == {'theme', 'tour'}
         and value['theme'] in THEMES, 'TOUR_REFUSED')
    tour = value['tour']
    need(type(tour) is dict and set(tour) ==
         {'schema', 'scope', 'complete', 'requested', 'visited'}
         and type(tour['schema']) is int and tour['schema'] == 1
         and tour['scope'] == 'readonly_native_page_tour'
         and type(tour['complete']) is bool and tour['requested'] == list(PAGES)
         and type(tour['visited']) is list and len(tour['visited']) <= len(PAGES),
         'TOUR_REFUSED')
    for index, page in enumerate(tour['visited']):
        need(type(page) is dict and set(page) ==
             {'page', 'nodes', 'error_widgets', 'severe_logs', 'captured', 'layout'}
             and page['page'] == PAGES[index] and type(page['captured']) is bool
             and all(type(page[k]) is int and 0 <= page[k] <= 100000
                     for k in ('nodes', 'error_widgets', 'severe_logs')), 'TOUR_REFUSED')
        if page['captured']:
            layout_observation(page['layout'])
        else:
            need(page['layout'] is None, 'TOUR_REFUSED')
    return value


def tour_complete(value):
    tour_receipt(value)
    tour = value['tour']
    return (tour['complete'] and len(tour['visited']) == len(PAGES)
        and all(p['captured'] and p['error_widgets'] == p['severe_logs'] == 0
                for p in tour['visited']))


def locale_receipt(value):
    need(type(value) is dict and set(value) ==
         {'schema', 'scope', 'theme', 'language', 'direction', 'stable'}
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'readonly_native_locale_observation'
         and value['theme'] in THEMES and value['language'] == 'en'
         and value['direction'] == 'ltr' and value['stable'] is True)
    return value


def stalls_receipt(value):
    need(type(value) is dict and set(value) ==
         {'schema', 'scope', 'theme', 'events', 'longest_ms'}
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'readonly_native_stalls_observation'
         and value['theme'] in THEMES
         and type(value['events']) is int and 0 <= value['events'] <= 100000
         and type(value['longest_ms']) is int and 0 <= value['longest_ms'] <= 900000)
    return value


def capture_frame_state(value):
    """Retain only the original refusal's closed scheduler facts."""
    need(type(value) is dict and type(value.get('schema')) is int
         and value['schema'] in (1, 2), 'ENTRY_REFUSED')
    fields = {
        'schema', 'scheduler_phase', 'lifecycle_state', 'frames_enabled',
        'has_scheduled_frame', 'binding_current'}
    if value['schema'] == 2:
        fields |= {'begin_frame_callback_registered',
                   'draw_frame_callback_registered', 'persistent_callbacks_observed'}
    need(set(value) == fields, 'ENTRY_REFUSED')
    need(type(value['scheduler_phase']) is str and value['scheduler_phase'] in (
             'idle', 'transientCallbacks', 'midFrameMicrotasks',
             'persistentCallbacks', 'postFrameCallbacks')
         and type(value['lifecycle_state']) is str and value['lifecycle_state'] in (
             'none', 'detached', 'resumed', 'inactive', 'hidden', 'paused')
         and all(type(value[key]) is bool for key in (
             'frames_enabled', 'has_scheduled_frame', 'binding_current')),
         'ENTRY_REFUSED')
    if value['schema'] == 2:
        callbacks = value['persistent_callbacks_observed']
        need(type(value['begin_frame_callback_registered']) is bool
             and type(value['draw_frame_callback_registered']) is bool
             and (type(callbacks) is int and 0 <= callbacks <= 65535
                  or type(callbacks) is str and callbacks == 'unknown'),
             'ENTRY_REFUSED')
    return value


def home_failure_diagnostic(value):
    """Keep only finite context from the failed original Home capture."""
    required = {'schema', 'kind', 'last_entered_step'}
    optional = {'screen', 'theme', 'line'}
    need(type(value) is dict and type(value.get('schema')) is int,
         'ENTRY_REFUSED')
    if value['schema'] in (2, 3):
        required = required | {'reply'}
        need(type(value.get('reply')) is str
             and value['reply'] in settings.FAILURE_REPLIES, 'ENTRY_REFUSED')
    else:
        need(value['schema'] == 1, 'ENTRY_REFUSED')
    if value['schema'] == 3:
        required = required | {'frame_state'}
        need(value['reply'] in ('frameBusy', 'frameDeadlineExceeded',
             'frameOriginalFailed', 'frameAdmissionFailed'), 'ENTRY_REFUSED')
        capture_frame_state(value.get('frame_state'))
    need(required <= set(value) <= required | optional, 'ENTRY_REFUSED')
    need(value['kind'] == 'readonly_home_capture_failure'
         and type(value['last_entered_step']) is str
         and value['last_entered_step'] in settings.FAILURE_STEPS,
         'ENTRY_REFUSED')
    need(('screen' in value) == ('theme' in value), 'ENTRY_REFUSED')
    if 'screen' in value:
        need(type(value['screen']) is str
             and value['screen'] in (*HOME_GOTO_SCREENS, 'home-bell')
             and type(value['theme']) is str and value['theme'] in THEMES,
             'ENTRY_REFUSED')
    script = value['last_entered_step'] in ('scriptLine', 'afterCaptureLine')
    need(not script or {'screen', 'theme', 'line'} <= set(value), 'ENTRY_REFUSED')
    if 'line' in value:
        need(script and type(value['line']) is int and 1 <= value['line'] <= 65535,
             'ENTRY_REFUSED')
    return value


def entry_failure(value):
    need(type(value) is dict and set(value) in
         ({'stage', 'code'}, {'stage', 'code', 'diagnostic'})
         and value['stage'] in STAGES and (value['code'] is None
             or type(value['code']) is str and (
                 re.fullmatch('wallet-recipe-[a-z-]{1,80}', value['code'])
                 or value['code'] in {'inspection-' + reason for reason in
                     ('process', 'retired', 'command', 'reply', 'binding')})), 'ENTRY_REFUSED')
    if 'diagnostic' in value:
        if value['stage'] in ('onboarding', 'address_selection'):
            shared.entry_failure(value)
        elif value['stage'] == 'home_catalog':
            need(value['code'] is None or value['code'] in {
                'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}, 'ENTRY_REFUSED')
            home_failure_diagnostic(value['diagnostic'])
        elif value['stage'] == 'settings_catalog':
            need(value['code'] is None or value['code'] in {
                'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}, 'ENTRY_REFUSED')
            try:
                settings.failure_diagnostic(value['diagnostic'])
            except settings.Refused:
                need(False, 'ENTRY_REFUSED')
        elif value['stage'] == 'navigation_catalog':
            need(value['code'] is None or value['code'] in {
                'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}, 'ENTRY_REFUSED')
            try:
                navigation.failure_diagnostic(value['diagnostic'])
            except navigation.Refused:
                need(False, 'ENTRY_REFUSED')
        elif value['stage'] in details.CATALOG_STAGES:
            need(value['code'] is None or value['code'] in {
                'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}, 'ENTRY_REFUSED')
            try:
                details.failure_diagnostic(value['diagnostic'],
                    catalog_schema=details.CATALOG_STAGES[value['stage']])
            except details.Refused:
                need(False, 'ENTRY_REFUSED')
        elif value['stage'] == 'viewport':
            need(value['code'] is None or value['code'] in {
                'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}, 'ENTRY_REFUSED')
            try:
                viewport.failure_diagnostic(value['diagnostic'])
            except viewport.Refused:
                need(False, 'ENTRY_REFUSED')
        else:
            need(value['stage'] in ('tour_dark', 'tour_light')
                 and value['code'] is None, 'ENTRY_REFUSED')
            shared.tour_failure_diagnostic(value['diagnostic'])
    return value


def refused_entry_marker(value):
    """Project only fixed labels when an entry failure marker is refused."""
    marker = value if type(value) is dict else {}
    diagnostic = marker.get('diagnostic')
    fields = diagnostic if type(diagnostic) is dict else {}

    def label(candidate, allowed):
        return candidate if type(candidate) is str and candidate in allowed else None

    kind = ('absent' if diagnostic is None else
        'recipe' if {'action', 'control', 'reason'} <= set(fields) else
        'capture' if fields.get('kind') == 'readonly_details_capture_failure' else
        'other')
    return dict(schema=1, scope='readonly_entry_marker_refusal',
        stage=label(marker.get('stage'), STAGES),
        code=label(marker.get('code'), {
            'wallet-recipe-command-refused', 'wallet-recipe-stage-unsettled',
            'wallet-recipe-control-ambiguous',
            *{'inspection-' + reason for reason in
                ('process', 'retired', 'command', 'reply', 'binding')}}),
        diagnostic=kind,
        action=label(fields.get('action'), shared.RECIPE_ACTIONS),
        control=label(fields.get('control'), shared.RECIPE_CONTROLS),
        reason=label(fields.get('reason'), shared.RECIPE_FAILURE_CODES))


def entry_marker_kind(line):
    """Name a fixed marker family without retaining its payload or suffix."""
    if type(line) is not bytes:
        return 'unrecognized'
    for prefix, kind in (
        (b'CI_INSPECT_STAGE:', 'stage'), (b'CI_INSPECT_READY', 'ready'),
        (b'CI_INSPECT_DONE', 'done'), (b'CI_INSPECT_ERROR:', 'error'),
        (b'SYRIUS_INSPECTION_ADDRESS:', 'address'),
        (b'SYRIUS_INSPECTION_WALLET:', 'wallet'),
        (b'SYRIUS_INSPECTION_CATALOG:', 'catalog'),
        (b'SYRIUS_INSPECTION_VIEWPORT:', 'viewport'),
        (b'SYRIUS_INSPECTION_TOUR:', 'tour'),
        (b'SYRIUS_INSPECTION_LOCALE:', 'locale'),
        (b'SYRIUS_INSPECTION_STALLS:', 'stalls'),
        (b'CI_INSPECT_SEND_WARN_', 'send-warning'),
        (b'CI_INSPECT_', 'inspection-other'),
        (b'SYRIUS_INSPECTION_', 'inspection-other'),
        (b'CI_WALLET_', 'wallet-other'),
        (b'SYRIUS_WALLET_TOUR:', 'wallet-tour'),
        (b'SYRIUS_LAB_SEND:', 'lab-send'),
    ):
        if line.startswith(prefix):
            return kind
    return 'other'


def capture_records(value, *, complete=True):
    need(type(value) is list and len(value) <= len(THEMES) * len(PAGES)
         and (not complete or len(value) == len(THEMES) * len(PAGES)), 'CAPTURE_REFUSED')
    for row, (theme, page) in zip(value, ((t, p) for t in THEMES for p in PAGES)):
        need(type(row) is dict and set(row) ==
             {'theme', 'page', 'bytes', 'sha256', 'width', 'height'}
             and row['theme'] == theme and row['page'] == page
             and type(row['bytes']) is int and 0 < row['bytes'] <= debug.entry.MAX_PNG
             and type(row['sha256']) is str and re.fullmatch('[a-f0-9]{64}', row['sha256'])
             and type(row['width']) is type(row['height']) is int
             and row['width'] == 1280 and row['height'] == 780, 'CAPTURE_REFUSED')
    need(not complete or sum(row['bytes'] for row in value) <= MAX_CAPTURE_TOTAL, 'CAPTURE_REFUSED')
    return value


def inspection_catalog_reference(report):
    schema = report.get('schema')
    need(type(schema) is int and schema in READONLY_CATALOG_SCHEMAS.values(),
         'CAPTURE_REFUSED')
    if schema in HOME_INSPECTION_SCHEMAS:
        reference = home_catalog_reference(report['home_catalog'])
        need((reference['schema'] == HOME_BELL_CAPTURE_SCHEMA) is
             (schema == HOME_BELL_INSPECTION_SCHEMA), 'CAPTURE_REFUSED')
        return reference
    need(report['home_catalog'] is None, 'CAPTURE_REFUSED')
    if schema == 2:
        return settings.catalog_reference(report['settings_catalog'])
    need(report['settings_catalog'] is None, 'CAPTURE_REFUSED')
    if schema == 3:
        return navigation.catalog_reference(report['navigation_catalog'])
    need(report['navigation_catalog'] is None, 'CAPTURE_REFUSED')
    reference = details.catalog_reference(report['details_catalog'])
    need(reference['schema'] not in details.RESTORED_SCHEMAS, 'CAPTURE_REFUSED')
    family = catalog_only_family(report)
    if family is not None:
        need(reference['schema'] == details.FAMILY_SCHEMAS[family], 'CAPTURE_REFUSED')
    else:
        need(reference['schema'] in (1, 2, 3), 'CAPTURE_REFUSED')
    return reference


def catalog_only_family(report):
    return CATALOG_ONLY_FAMILIES.get(report['schema'])


def complete_checks(report):
    checks = report['checks']
    skipped = TOUR_CHECKS if catalog_only_family(report) else ()
    if report['schema'] == SURFACE_SEAMS_SCHEMA:
        skipped += ('captures',)
    return set(checks) == set(CHECKS) and all(
        checks[key] is (key not in skipped) for key in CHECKS)


def require_catalog_only_samples(report):
    failure = report.get('entry_failure')
    need(report['captures'] == [] and report['viewport'] is None
         and all(report[key] == {} for key in ('tours', 'locales', 'stalls'))
         and all(report['checks'][key] is False for key in TOUR_CHECKS)
         and (failure is None or type(failure) is dict and failure.get('stage')
              not in ('tour_dark', 'tour_light', 'viewport')), 'OUTPUT_REFUSED')


def require_surface_seam_samples(report, *, complete):
    observed = report['seam_refusals']
    need(type(observed) is list and tuple(observed) == SURFACE_SEAMS[:len(observed)]
         and (not observed or report['checks']['wallet_bound'] is True)
         and (not complete or tuple(observed) == SURFACE_SEAMS)
         and report['checks']['captures'] is False
         and all(report[field] is None for field in
                 ('home_catalog', 'settings_catalog', 'navigation_catalog', 'details_catalog')),
         'OUTPUT_REFUSED')


def completed(report):
    try:
        if report['schema'] == SURFACE_SEAMS_SCHEMA:
            require_surface_seam_samples(report, complete=True)
        else:
            inspection_catalog_reference(report)
        if catalog_only_family(report):
            require_catalog_only_samples(report)
            if report['schema'] == SEND_WARNING_INSPECTION_SCHEMA:
                require_warning_window(report, complete=True)
        else:
            capture_records(report['captures'])
            viewport.reference(report['viewport'])
            need(set(report['tours']) == set(report['locales']) ==
                 set(report['stalls']) == set(THEMES)
                 and all(tour_complete(report['tours'][t])
                         and locale_receipt(report['locales'][t])
                         and stalls_receipt(report['stalls'][t]) for t in THEMES),
                 'TOUR_REFUSED')
        sdk_receipt(report['sdk_admission'])
        wallet_receipt(report['wallet_admission'])
        return (report['phase'] == 'complete' and not report['errors']
            and complete_checks(report)
            and type(report['lab_revalidations']) is int and report['lab_revalidations'] == 2
            and type(report.get('application_exit')) is int and report['application_exit'] == 0
            and type(report.get('entry_exit')) is int and report['entry_exit'] == 0
            and type(report.get('owned_job_active_at_close')) is int
            and report['owned_job_active_at_close'] == 0
            and report['owned_job_images_before_close']['status'] == 'OBSERVED'
            and report['owned_job_images_before_close']['listed'] ==
                report['owned_job_images_before_close']['observed'] == 0
            and not report['required_actor_forced_cleanup']
            and report['entry_output']['output_complete'] and not report['entry_output']['overflow']
            and debug.helper_cleanup_complete(report['auxiliary_cleanup'])
            and report['forced_cleanup'] is report['auxiliary_cleanup']['forced'])
    except (Refused, viewport.Refused, settings.Refused, navigation.Refused,
            details.Refused, KeyError, TypeError):
        return False


def output_bytes(output, *, catalog_only=False):
    """Only the manifest and finite capture paths belong to this output root."""
    total = entries = 0
    allowed = {output / 'manifest.json'} | {
        output / 'captures' / theme / (page + '.png') for theme in THEMES for page in PAGES}
    capture_roots = (output / 'captures', *(output / 'captures' / t for t in THEMES))
    if catalog_only:
        allowed = {output / 'manifest.json'}
        capture_roots = ()
    for path in (output, *capture_roots):
        if path.exists() or path.is_symlink():
            debug.bounded.plain(path)
            for child in path.iterdir():
                if child in capture_roots:
                    debug.bounded.plain(child)
                else:
                    need(child in allowed, 'STORAGE_REFUSED')
                    info = debug.bounded.plain(child)
                    total += info.st_size
                    entries += 1
    need(entries <= len(allowed) and total <= MAX_CAPTURE_TOTAL + MAX_MANIFEST, 'STORAGE_REFUSED')
    return total


def sample_capture_outputs(repo, *, family, catalog_only):
    """Account in-progress writes using the selected finite filename sets."""
    if family == SURFACE_SEAMS_FAMILY:
        capture_roots = (HOME_OUTPUT, settings.OUTPUT, navigation.OUTPUT,
                         details.OUTPUT, viewport.OUTPUT)
        need(catalog_only and not any((repo / path).exists() or (repo / path).is_symlink()
                                     for path in capture_roots), 'CAPTURE_REFUSED')
        return output_bytes(repo / OUTPUT, catalog_only=True)
    return (output_bytes(repo / OUTPUT, catalog_only=catalog_only)
        + home_output_bytes(repo / HOME_OUTPUT, schema=HOME_CAPTURE_SCHEMAS.get(family, 4))
        + settings.output_bytes(repo / settings.OUTPUT)
        + navigation.output_bytes(repo / navigation.OUTPUT)
        + details.output_bytes(repo / details.OUTPUT, schema=details.FAMILY_SCHEMAS.get(family, 1))
        + viewport.output_bytes(repo / viewport.OUTPUT))


def require_warning_window(report, *, complete):
    try:
        return send_warning_window.window_receipt(report['send_warning_window'],
                                                  complete=complete)
    except send_warning_window.SendWarningWindowRefused:
        raise Refused('OUTPUT_REFUSED') from None


def public_manifest(value):
    """Refuse unexpected fields and strings before any artifact or annotation."""
    flags = {'success', 'inspection_qualified', 'wallet_qualified', 'seed_admitted',
        'forced_cleanup', 'required_actor_forced_cleanup', 'financial_send_qualified',
        'motion_baseline_compared', 'arabic_or_minimum_window_qualified'}
    required = flags | {'schema', 'scope', 'visual_matches', 'checks', 'errors', 'phase',
        'captures', 'tours', 'locales', 'stalls', 'home_catalog', 'viewport', 'sdk_admission', 'wallet_admission',
        'address_selection', 'lab_revalidations', 'auxiliary_cleanup', 'min_free_bytes',
        'workspace_cap_bytes', 'storage_scope', 'storage', 'cleanup'}
    optional = {'source_sha', 'source_tree', 'run_id', 'run_attempt', 'input_attempted',
        'entry_failure', 'application_exit', 'cleanup_application_exit', 'entry_exit',
        'owned_job_images_before_close', 'owned_job_active_at_close', 'entry_output',
        'home_seam_observations', 'settings_seam_observations'}
    need(type(value) is dict and type(value.get('schema')) is int
         and value['schema'] in READONLY_CATALOG_SCHEMAS.values(), 'OUTPUT_REFUSED')
    schema = value['schema']
    if schema >= 2:
        required.add('settings_catalog')
    if schema >= 3:
        required.add('navigation_catalog')
    if schema >= 4:
        required.add('details_catalog')
    if schema == SEND_WARNING_INSPECTION_SCHEMA:
        required.add('send_warning_window')
    if schema == SURFACE_SEAMS_SCHEMA:
        required.add('seam_refusals')
    need(required <= set(value) <= required | optional, 'OUTPUT_REFUSED')
    need(value['scope'] == 'owned_chain321_wallet_inspection'
         and all(type(value[k]) is bool for k in flags)
         and all(value[k] is False for k in ('wallet_qualified', 'seed_admitted',
             'financial_send_qualified', 'motion_baseline_compared', 'arabic_or_minimum_window_qualified'))
         and type(value['visual_matches']) is int and value['visual_matches'] == 0
         and value['success'] is value['inspection_qualified'], 'OUTPUT_REFUSED')
    need(type(value['checks']) is dict and set(value['checks']) == set(CHECKS)
         and all(type(v) is bool for v in value['checks'].values())
         and type(value['errors']) is list and len(value['errors']) <= 32
         and all(type(e) is str and e in CODES for e in value['errors'])
         and value['phase'] in ('admission', 'build_and_start', 'lab_revalidation',
             'onboarding_and_inspection', 'ordinary_close', 'complete')
         and type(value['lab_revalidations']) is int and 0 <= value['lab_revalidations'] <= 2,
         'OUTPUT_REFUSED')
    need(value['min_free_bytes'] == shared.FIXTURE_FLOOR
         and value['workspace_cap_bytes'] == shared.WORK_CAP
         and value['storage_scope'] == 'isolated_hosted_regression_fixture_cooperative_samples'
         and value['cleanup'] == 'runner_lifecycle_not_qualified', 'OUTPUT_REFUSED')
    for name in ('source_sha', 'source_tree'):
        if name in value:
            need(type(value[name]) is str and re.fullmatch('[a-f0-9]{40}', value[name]), 'OUTPUT_REFUSED')
    for name in ('run_id', 'run_attempt'):
        if name in value:
            need(type(value[name]) is str and re.fullmatch('[1-9][0-9]{0,19}', value[name]), 'OUTPUT_REFUSED')
    for name in ('application_exit', 'cleanup_application_exit', 'entry_exit', 'owned_job_active_at_close'):
        if name in value:
            need(value[name] is None or type(value[name]) is int
                 and -2**31 <= value[name] < 2**32, 'OUTPUT_REFUSED')
    if 'input_attempted' in value:
        need(type(value['input_attempted']) is bool, 'OUTPUT_REFUSED')
    if 'entry_failure' in value:
        entry_failure(value['entry_failure'])
    for field, family, validate in (
            ('home_seam_observations', 'home', home_seam_observations),
            ('settings_seam_observations', 'settings', settings_seam_observations)):
        if field in value:
            need(schema == READONLY_CATALOG_SCHEMAS[family], 'OUTPUT_REFUSED')
            observations = validate(value[field])
            need(not value['success'] or observations['complete'], 'OUTPUT_REFUSED')
            need(observations['probe_failure'] is None
                 or observations['probe_failure'] in value['errors'], 'OUTPUT_REFUSED')
    if schema == SURFACE_SEAMS_SCHEMA:
        require_surface_seam_samples(value, complete=value['success'])
    elif schema in HOME_INSPECTION_SCHEMAS:
        if value['home_catalog'] is not None or value['success']:
            inspection_catalog_reference(value)
        if schema == HOME_BELL_INSPECTION_SCHEMA:
            need(all(value[key] is None for key in
                     ('settings_catalog', 'navigation_catalog', 'details_catalog')),
                 'OUTPUT_REFUSED')
    else:
        need(value['home_catalog'] is None, 'OUTPUT_REFUSED')
        if value['schema'] == 2:
            if value['settings_catalog'] is not None:
                settings.catalog_reference(value['settings_catalog'])
            need(not value['success'] or value['settings_catalog'] is not None,
                 'OUTPUT_REFUSED')
        else:
            need(value['settings_catalog'] is None, 'OUTPUT_REFUSED')
            if value['schema'] == 3:
                if value['navigation_catalog'] is not None:
                    navigation.catalog_reference(value['navigation_catalog'])
                need(not value['success'] or value['navigation_catalog'] is not None,
                     'OUTPUT_REFUSED')
            else:
                need(value['navigation_catalog'] is None, 'OUTPUT_REFUSED')
                if value['details_catalog'] is not None:
                    inspection_catalog_reference(value)
                need(not value['success'] or value['details_catalog'] is not None,
                     'OUTPUT_REFUSED')
    if catalog_only_family(value):
        require_catalog_only_samples(value)
        if schema == SEND_WARNING_INSPECTION_SCHEMA:
            require_warning_window(value, complete=value['success'])
    else:
        if value['viewport'] is not None:
            viewport.reference(value['viewport'])
        need(not value['success'] or value['viewport'] is not None, 'OUTPUT_REFUSED')
        capture_records(value['captures'], complete=value['success'])
    if value['sdk_admission'] is not None:
        sdk_receipt(value['sdk_admission'])
    if value['wallet_admission'] is not None:
        wallet_receipt(value['wallet_admission'])
    if value['address_selection'] is not None:
        shared.address_selection_receipt(value['address_selection'])
    for key, validate in (('tours', tour_receipt), ('locales', locale_receipt), ('stalls', stalls_receipt)):
        need(type(value[key]) is dict and set(value[key]) <= set(THEMES), 'OUTPUT_REFUSED')
        for theme, observed in value[key].items():
            validate(observed)
            need(observed['theme'] == theme, 'OUTPUT_REFUSED')
    storage = value['storage']
    need(type(storage) is dict and set(storage) ==
         {'samples', 'peak_logical_bytes', 'minimum_free_bytes', 'refusal'}
         and all(type(storage[k]) is int and 0 <= storage[k] < 2**63
                 for k in ('samples', 'peak_logical_bytes'))
         and (storage['minimum_free_bytes'] is None or
              type(storage['minimum_free_bytes']) is int and 0 <= storage['minimum_free_bytes'] < 2**63)
         and storage['refusal'] in (None, 'STORAGE_REFUSED'), 'OUTPUT_REFUSED')
    labels = set(IMAGE_NAMES.values()) | {'OTHER'}
    if 'owned_job_images_before_close' in value:
        images = value['owned_job_images_before_close']
        need(type(images) is dict and set(images) == {'status', 'listed', 'observed', 'counts'}
             and images['status'] in ('OBSERVED', 'UNKNOWN')
             and all(type(images[k]) is int and 0 <= images[k] <= 64 for k in ('listed', 'observed'))
             and type(images['counts']) is dict and set(images['counts']) <= labels
             and all(type(n) is int and 0 <= n <= 64 for n in images['counts'].values()), 'OUTPUT_REFUSED')
    if 'entry_output' in value:
        observed = value['entry_output']
        need(type(observed) is dict and set(observed) == {'bytes', 'sha256', 'output_complete', 'overflow'}
             and type(observed['bytes']) is int and 0 <= observed['bytes'] < 2**63
             and type(observed['sha256']) is str and re.fullmatch('[a-f0-9]{64}', observed['sha256'])
             and type(observed['output_complete']) is type(observed['overflow']) is bool, 'OUTPUT_REFUSED')
    aux = value['auxiliary_cleanup']
    if aux is not None:
        need(type(aux) is dict and set(aux) ==
             {'scope', 'status', 'code', 'forced', 'remaining', 'receipts', 'observation'}
             and aux['scope'] == debug.HELPER_SCOPE and aux['status'] in ('PASSED', 'FAILED')
             and (aux['code'] is None or type(aux['code']) is str and aux['code'] in CODES)
             and type(aux['forced']) is bool
             and (aux['remaining'] is None or type(aux['remaining']) is int and 0 <= aux['remaining'] <= 64)
             and type(aux['receipts']) is list and len(aux['receipts']) <= 2, 'OUTPUT_REFUSED')
        for receipt in aux['receipts']:
            need(type(receipt) is dict and set(receipt) == {'role', 'image_sha256', 'forced',
                 'termination_requested', 'termination_succeeded', 'actual_exit', 'exit_observed', 'stdio_captured'}
                 and receipt['role'] in ('sdk_dart', 'msvc_telemetry')
                 and type(receipt['image_sha256']) is str
                 and re.fullmatch('[a-f0-9]{64}', receipt['image_sha256'])
                 and all(type(receipt[k]) is bool for k in ('forced', 'termination_requested',
                     'termination_succeeded', 'exit_observed', 'stdio_captured'))
                 and (receipt['actual_exit'] is None or type(receipt['actual_exit']) is int
                      and -2**31 <= receipt['actual_exit'] < 2**32), 'OUTPUT_REFUSED')
        observation = aux['observation']
        need(type(observation) is dict and set(observation) ==
             {'stage', 'image_class', 'image_bytes', 'path_match'}
             and observation['stage'] in ('members', 'member', 'sdk_image', 'compiler_metadata',
                 'compiler_image', 'image_pin', 'membership_recheck', 'image_recheck',
                 'termination', 'exit_observation', 'empty_job', 'complete')
             and observation['image_class'] in labels | {None}
             and (observation['image_bytes'] is None or type(observation['image_bytes']) is int
                  and 0 <= observation['image_bytes'] <= 64 * 1024**2)
             and (observation['path_match'] is None or type(observation['path_match']) is bool), 'OUTPUT_REFUSED')
    return value


SETTINGS_SEAM_PANELS = (
    ('node', 'node_settings_page', (
        ('sporks', 'node_settings_sporks_gate'),
    )),
    ('security', 'security_settings_page', (
        ('autoLockOnClose', 'security_lock_close'),
        ('biometricUnlock', 'security_settings_biometric_gate'),
        ('wrongPasswordLimitOff', 'security_limit_off'),
        ('passwordChangeMigration', 'security_settings_password_gate'),
    )),
    ('wallet', 'wallet_settings_page', (
        ('operatorModes', 'wallet_settings_modes_gate'),
        ('walletPicker', 'wallet_settings_wallets_gate'),
    )),
    ('about', 'about_page', (
        ('walletUpdateNotice', 'about_update_gate'),
    )),
)


def expected_settings_seam_observations():
    return [dict(panel=panel, seam=seam)
            for panel, _, targets in SETTINGS_SEAM_PANELS for seam, _ in targets]


def settings_seam_observations(value):
    return _seam_observation_prefix(value, expected_settings_seam_observations())


def seam_wallet_observation(state, tab):
    need(type(state) is dict, 'ENTRY_REFUSED')
    address = state.get('address')
    need(state.get('tab') == tab and state.get('locale') == 'en'
         and state.get('direction') == 'ltr'
         and state.get('node') == 'ws://127.0.0.1:45998'
         and state.get('chainId') == state.get('signingChainId') == 321
         and state.get('savedSigningChainId') == 321
         and state.get('walletUnlocked') is True
         and state.get('walletInitCompleted') is True
         and state.get('embeddedNode') is False
         and state.get('nodeTransitionPending') is False
         and type(address) is str and bool(address), 'ENTRY_REFUSED')
    return state


def seam_wallet_state(send, tab):
    return seam_wallet_observation(send(dict(cmd='state')), tab)


def require_seam_absorption(send, seam, key):
    result = send(dict(cmd='readonly-seam-pointer', seam=seam, key=key))
    need(result.get('scope') == 'readonly_native_seam_pointer_observation'
         and result.get('seam') == seam
         and result.get('pointerDispatched') is True
         and result.get('absorptionObserved') is True, 'ENTRY_REFUSED')


def require_seam_clean_logs(send):
    logs = send(dict(cmd='logs', since=0, limit=500,
                     levels=['SEVERE', 'SHOUT', 'FLUTTER']))
    need(logs.get('logs') == [], 'ENTRY_REFUSED')


def observe_settings_seam_pointers(send, observed):
    """Use the bound original wallet after its settings captures are complete."""

    original_address = seam_wallet_state(send, 'dashboard')['address']
    send(dict(cmd='tap', tab='settings'))
    send(dict(cmd='wait', key='settings_node', timeoutMs=5000))
    need(seam_wallet_state(send, 'settings')['address'] == original_address, 'ENTRY_REFUSED')
    for panel, marker, targets in SETTINGS_SEAM_PANELS:
        send(dict(cmd='tap', key='settings_' + panel))
        send(dict(cmd='wait', key=marker, timeoutMs=30000))
        if panel == 'node':
            send(dict(cmd='scroll', dy=-1000000))
            send(dict(cmd='scroll', key='node_settings_peers_toggle', dy=300))
        for seam, key in targets:
            require_seam_absorption(send, seam, key)
            need(seam_wallet_state(send, 'settings')['address'] == original_address, 'ENTRY_REFUSED')
            observed.append(dict(panel=panel, seam=seam))
    send(dict(cmd='tap', tab='dashboard'))
    send(dict(cmd='wait', key='home_hero', timeoutMs=5000))
    need(seam_wallet_state(send, 'dashboard')['address'] == original_address, 'ENTRY_REFUSED')
    require_seam_clean_logs(send)


HOME_SEAM_CONTROLS = (
    ('home', 'zapSend', 'home_zap'),
    ('activity', 'activityAddressScope', 'activity_scope_filter'),
)
HOME_GO_TO_GATE = 'go_to_gate_action:zap'


def observe_home_seam_pointers(send, observed):
    """Verify direct and palette refusal in the original bound Home."""
    original = seam_wallet_state(send, 'dashboard')
    home_route = original.get('route')
    need(type(home_route) is str and bool(home_route), 'ENTRY_REFUSED')

    def current():
        state = seam_wallet_state(send, 'dashboard')
        need(state['address'] == original['address'], 'ENTRY_REFUSED')
        return state.get('route')

    for panel, seam, key in HOME_SEAM_CONTROLS:
        require_seam_absorption(send, seam, key)
        need(current() == home_route, 'ENTRY_REFUSED')
        observed.append(dict(panel=panel, seam=seam))

    send(dict(cmd='key', key='ctrl+k'))
    send(dict(cmd='wait', key='go_to_field', ready=True, timeoutMs=5000))
    palette_route = current()
    need(type(palette_route) is str and bool(palette_route)
         and palette_route != home_route, 'ENTRY_REFUSED')
    typed = send(dict(cmd='type', key='go_to_field', value='Zap'))
    need(typed.get('value') == 'Zap' and current() == palette_route,
         'ENTRY_REFUSED')
    require_seam_absorption(send, 'zapSend', HOME_GO_TO_GATE)
    need(current() == palette_route, 'ENTRY_REFUSED')
    send(dict(cmd='key', key='down', paletteGate=HOME_GO_TO_GATE))
    send(dict(cmd='key', key='enter', paletteGate=HOME_GO_TO_GATE))
    send(dict(cmd='wait', key='go_to_field', ready=True, timeoutMs=5000))
    need(current() == palette_route, 'ENTRY_REFUSED')
    observed.append(dict(panel='go-to', seam='zapSend', keyboard_refused=True))
    send(dict(cmd='key', key='escape'))
    send(dict(cmd='wait', key='go_to_field', gone=True, timeoutMs=5000))
    send(dict(cmd='wait', key='home_hero', timeoutMs=5000))
    need(current() == home_route, 'ENTRY_REFUSED')
    observe_activity_message_seams(send, observed,
        require_home=lambda: need(current() == home_route, 'ENTRY_REFUSED'))
    observe_readonly_owner_seams(send, observed)
    require_seam_clean_logs(send)


def observe_activity_message_seams(send, observed, *, require_home):
    """Use explicit previews of existing history, never a synthetic Zap receipt."""
    require_home()
    original_theme = send(dict(cmd='theme'))
    require_home()
    for theme in ('dark', 'light'):
        send(dict(cmd='theme', mode=theme))
        require_home()
        result = send(dict(cmd='readonly-activity-message-seam'))
        need(type(result) is dict and type(result.get('schema')) is int
             and result['schema'] == 1
             and result.get('scope') == 'readonly_native_activity_message_seam_observation'
             and result.get('seam') == 'zapReceive' and result.get('theme') == theme
             and all(result.get(key) is True for key in ('pointerDispatched',
                 'absorptionObserved', 'originalHistoryRetained', 'previewOnly')),
             'ENTRY_REFUSED')
        require_home()
        observed.append(dict(panel='activity-preview', seam='zapReceive',
                             theme=theme, preview_only=True))
    send(dict(cmd='theme', restore=original_theme))
    require_home()


READONLY_OWNER_SEAMS = ('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms')


def expected_home_seam_observations():
    return [
        dict(panel='home', seam='zapSend'),
        dict(panel='activity', seam='activityAddressScope'),
        dict(panel='go-to', seam='zapSend', keyboard_refused=True),
        dict(panel='activity-preview', seam='zapReceive', theme='dark', preview_only=True),
        dict(panel='activity-preview', seam='zapReceive', theme='light', preview_only=True),
        dict(panel='home', seam='walletUpdateNotice', theme='dark'),
        dict(panel='pillars', seam='pillarAprEstimate', theme='dark'),
        dict(panel='swap', seam='swapTerms', theme='dark'),
        dict(panel='home', seam='walletUpdateNotice', theme='light'),
        dict(panel='pillars', seam='pillarAprEstimate', theme='light'),
        dict(panel='swap', seam='swapTerms', theme='light'),
    ]


def home_seam_observations(value):
    return _seam_observation_prefix(value, expected_home_seam_observations())


def _seam_observation_prefix(value, expected):
    """Retain the original closed prefix, including after a later failure."""
    need(type(value) is dict and set(value) == {
        'schema', 'requested', 'observed', 'probe_failure', 'complete'}, 'OUTPUT_REFUSED')
    need(type(value['schema']) is int and value['schema'] == 1
         and type(value['requested']) is int and value['requested'] == len(expected)
         and type(value['complete']) is bool and type(value['observed']) is list
         and len(value['observed']) <= len(expected)
         and (value['probe_failure'] is None
              or type(value['probe_failure']) is str and value['probe_failure'] in CODES),
         'OUTPUT_REFUSED')
    for original, required in zip(value['observed'], expected):
        need(type(original) is dict and set(original) == set(required)
             and all(type(original[key]) is type(fact) and original[key] == fact
                     for key, fact in required.items()), 'OUTPUT_REFUSED')
    need(value['complete'] is (len(value['observed']) == len(expected)
         and value['probe_failure'] is None), 'OUTPUT_REFUSED')
    return value


def readonly_swap_opening(send, read_route, root_route, *, clock=None, pause=None):
    """Observe the original first-use warning or draft without repeating Start."""
    clock, pause = clock or time.monotonic, pause or time.sleep
    deadline = clock() + 5
    original_route = None

    def current_route():
        nonlocal original_route
        current = read_route()
        if original_route is None and current != root_route:
            original_route = current
        need(original_route is None or current == original_route, 'ENTRY_REFUSED')
        return current

    for _ in range(34):
        if clock() >= deadline:
            break
        before = current_route()
        reply = send(dict(cmd='tree'))
        after = current_route()
        nodes = reply.get('nodes') if type(reply) is dict else None
        need(type(nodes) is list and len(nodes) <= 512
             and all(type(row) is dict and row.get('kind') != 'error'
                     for row in nodes), 'ENTRY_REFUSED')
        visible = []
        ready = True
        for label, key, kind in (('warning', 'p2p_warning_continue', 'button'),
                                 ('draft', 'swap_counterparty_input', 'field')):
            matches = [row for row in nodes if row.get('key') == key]
            need(len(matches) <= 1 and all(row.get('kind') == kind
                 and type(row.get('enabled', True)) is bool for row in matches),
                 'ENTRY_REFUSED')
            if matches:
                visible.append(label)
                enabled = matches[0].get('enabled', True)
                if label == 'warning':
                    need(enabled, 'ENTRY_REFUSED')
                ready = ready and enabled
        need(len(visible) <= 1, 'ENTRY_REFUSED')
        if visible and ready and before == after and after != root_route:
            return visible[0], after
        pause(0.15)
    raise Refused('ENTRY_REFUSED')


def observe_readonly_owner_seams(send, observed):
    """Try the existing owner controls without a send, seed or form input."""
    original = seam_wallet_state(send, 'dashboard')
    home = original.get('route')
    need(type(home) is str and bool(home), 'ENTRY_REFUSED')

    def route(tab):
        state = seam_wallet_state(send, tab)
        value = state.get('route')
        need(state['address'] == original['address']
             and type(value) is str and bool(value), 'ENTRY_REFUSED')
        return value

    def same(tab, expected):
        need(route(tab) == expected, 'ENTRY_REFUSED')

    def stable(command, tab, expected):
        same(tab, expected)
        reply = send(command)
        same(tab, expected)
        need(type(reply) is dict, 'ENTRY_REFUSED')
        return reply

    def wait(key, tab, *, expected=None, kind=None, gone=False):
        current = route(tab)
        if expected is not None:
            need(current == expected, 'ENTRY_REFUSED')
        command = dict(cmd='wait', key=key, exact=True, timeoutMs=5000)
        if kind is not None:
            command['kind'] = kind
        if gone:
            command['gone'] = True
        reply = send(command)
        current = route(tab)
        if expected is not None:
            need(current == expected, 'ENTRY_REFUSED')
        need(type(reply) is dict, 'ENTRY_REFUSED')
        target = reply.get('target')
        need(('target' not in reply if gone else type(target) is dict
             and target.get('key') == key
             and (kind is None or target.get('kind') == kind)), 'ENTRY_REFUSED')
        return current

    def tap(key, tab, expected):
        same(tab, expected)
        reply = send(dict(cmd='tap', key=key, kind='button', exact=True))
        current = route(tab)
        need(type(reply) is dict, 'ENTRY_REFUSED')
        target = reply.get('target')
        need(type(target) is dict and target.get('key') == key
             and target.get('kind') == 'button', 'ENTRY_REFUSED')
        return current

    def navigate(tab, previous, expected):
        same(previous, expected)
        send(dict(cmd='tap', tab=tab))
        return route(tab)

    def probe(seam, key, tab, expected):
        same(tab, expected)
        require_seam_absorption(send, seam, key)
        same(tab, expected)

    original_theme = stable(dict(cmd='theme'), 'dashboard', home)
    need(type(original_theme) is dict and 'mode' in original_theme
         and original_theme['mode'] in (None, 'dark', 'light', 'system')
         and original_theme.get('brightness') in THEMES
         and 'savedMode' in original_theme
         and (original_theme['savedMode'] is None
              or type(original_theme['savedMode']) is str), 'ENTRY_REFUSED')
    for theme in THEMES:
        selected = stable(dict(cmd='theme', mode=theme), 'dashboard', home)
        need(selected.get('mode') == selected.get('brightness') == theme
             and selected.get('savedMode') == 'ThemeMode.' + theme, 'ENTRY_REFUSED')
        wait('strip_update_button', 'dashboard', expected=home, kind='button')
        probe('walletUpdateNotice', 'strip_update_button', 'dashboard', home)
        observed.append(dict(panel='home', seam='walletUpdateNotice', theme=theme))

        pillars = navigate('pillars', 'dashboard', home)
        wait('nodes_tab_pillars', 'pillars', expected=pillars)
        need(tap('nodes_tab_pillars', 'pillars', pillars) == pillars, 'ENTRY_REFUSED')
        wait('nodes_pillars_strip', 'pillars', expected=pillars)
        menu = tap('pillars_sort', 'pillars', pillars)
        need(menu != pillars, 'ENTRY_REFUSED')
        probe('pillarAprEstimate', 'pillars_sort_apr_gate', 'pillars', menu)
        same('pillars', menu)
        send(dict(cmd='key', key='escape'))
        same('pillars', pillars)
        observed.append(dict(panel='pillars', seam='pillarAprEstimate', theme=theme))

        swaps = navigate('p2pSwap', 'pillars', pillars)
        wait('p2p_swaps_strip', 'p2pSwap', expected=swaps)
        tap('p2p_start_swap', 'p2pSwap', swaps)
        opening, current = readonly_swap_opening(
            send, lambda: route('p2pSwap'), swaps)
        if opening == 'warning':
            tap('p2p_warning_continue', 'p2pSwap', current)
            draft = wait('swap_counterparty_input', 'p2pSwap', kind='field')
        else:
            draft = wait('swap_counterparty_input', 'p2pSwap',
                         expected=current, kind='field')
        need(draft != swaps, 'ENTRY_REFUSED')
        wait('swap_start_terms_gate', 'p2pSwap', expected=draft, kind='button')
        probe('swapTerms', 'swap_start_terms_gate', 'p2pSwap', draft)
        wait('swap_counterparty_input', 'p2pSwap', expected=draft, kind='field')
        tap('swap_action_close', 'p2pSwap', draft)
        need(wait('swap_counterparty_input', 'p2pSwap', gone=True) == swaps,
             'ENTRY_REFUSED')
        observed.append(dict(panel='swap', seam='swapTerms', theme=theme))
        need(navigate('dashboard', 'p2pSwap', swaps) == home, 'ENTRY_REFUSED')
        wait('home_hero', 'dashboard', expected=home)

    restored = stable(dict(cmd='theme', restore=original_theme), 'dashboard', home)
    need(restored.get('mode') == original_theme['mode']
         and restored.get('savedMode') == original_theme['savedMode'], 'ENTRY_REFUSED')


SURFACE_SEAMS = ('walletUpdateNotice', 'tokenExplorer', 'pillarAprEstimate', 'swapTerms')
SURFACE_TOKEN_ROW = 'token_zts1znnxxxxxxxxxxxxx9z4ulx_row'


class SeamProbeTrace:
    """Retain fixed command labels without response bodies or exception text."""

    COMMANDS = frozenset(('state', 'wait', 'tap', 'readonly-seam-pointer', 'key',
                         'logs', 'tree', 'theme'))
    TARGETS = {
        'addresses_settings_page': 'addresses',
        'home_hero': 'home', 'strip_update_button': 'update',
        SURFACE_TOKEN_ROW: 'token_row', 'token_explorer_control': 'token_explorer',
        'nodes_tab_pillars': 'pillars_tab', 'nodes_pillars_strip': 'pillars_strip',
        'pillars_sort': 'pillars_sort', 'pillars_sort_apr_gate': 'pillar_apr',
        'p2p_swaps_strip': 'swaps_strip', 'p2p_start_swap': 'swap_start',
        'p2p_warning_continue': 'swap_warning',
        'swap_counterparty_input': 'swap_draft', 'swap_start_terms_gate': 'swap_terms',
        'swap_action_close': 'swap_close', 'escape': 'escape',
    }
    TABS = frozenset(('dashboard', 'tokens', 'pillars', 'p2pSwap'))

    def __init__(self, *, maximum=128):
        need(type(maximum) is int and maximum in (128, 1024), 'ENTRY_REFUSED')
        self._maximum = maximum
        self._index = 0
        self._command, self._target, self._stage = 'NONE', 'NONE', 'NOT_STARTED'

    def exchange(self, send, command):
        need(self._index < self._maximum, 'ENTRY_REFUSED')
        self._index += 1
        name = command.get('cmd') if type(command) is dict else None
        self._command = name if type(name) is str and name in self.COMMANDS else 'OTHER'
        key = command.get('key') if type(command) is dict else None
        tab = command.get('tab') if type(command) is dict else None
        self._target = (self.TARGETS.get(key, 'OTHER') if type(key) is str else
                        tab if type(tab) is str and tab in self.TABS else 'NONE')
        self._stage = 'REQUEST'
        result = send(command)
        self._stage = 'REPLY'
        return result

    def receipt(self):
        return dict(schema=1, scope='readonly_seam_command_context',
            command_index=self._index, command=self._command,
            target=self._target, stage=self._stage)


def observe_surface_seams(send, observed):
    """Try four existing unavailable controls without captures or form input."""
    initial = send(dict(cmd='state'))
    need(type(initial) is dict and initial.get('tab') in ('settings', 'dashboard'),
         'ENTRY_REFUSED')
    initial = seam_wallet_observation(initial, initial['tab'])
    address, home = initial['address'], initial.get('route')
    need(type(home) is str and bool(home), 'ENTRY_REFUSED')

    def route(tab):
        state = seam_wallet_state(send, tab)
        route_name = state.get('route')
        need(state['address'] == address and type(route_name) is str and bool(route_name),
             'ENTRY_REFUSED')
        return route_name

    def wait(key, *, kind=None, gone=False):
        command = dict(cmd='wait', key=key, exact=True, timeoutMs=5000)
        if kind is not None:
            command['kind'] = kind
        if gone:
            command['gone'] = True
        response = send(command)
        target = response.get('target')
        need(('target' not in response if gone else
              type(target) is dict and target.get('key') == key), 'ENTRY_REFUSED')

    def tap(key):
        result = send(dict(cmd='tap', key=key, kind='button', exact=True))
        target = result.get('target')
        need(type(target) is dict and target.get('key') == key, 'ENTRY_REFUSED')

    from_settings = initial['tab'] == 'settings'
    if from_settings:
        wait('addresses_settings_page')
        need(route('settings') == home, 'ENTRY_REFUSED')
        send(dict(cmd='tap', tab='dashboard'))
    wait('home_hero')
    current_home = route('dashboard')
    need(from_settings or current_home == home, 'ENTRY_REFUSED')
    home = current_home
    wait('strip_update_button', kind='button')
    need(route('dashboard') == home, 'ENTRY_REFUSED')
    require_seam_absorption(send, 'walletUpdateNotice', 'strip_update_button')
    need(route('dashboard') == home, 'ENTRY_REFUSED')
    observed.append('walletUpdateNotice')

    send(dict(cmd='tap', tab='tokens'))
    wait(SURFACE_TOKEN_ROW, kind='button')
    tokens = route('tokens')
    tap(SURFACE_TOKEN_ROW)
    wait('token_explorer_control', kind='button')
    need(route('tokens') == tokens, 'ENTRY_REFUSED')
    require_seam_absorption(send, 'tokenExplorer', 'token_explorer_control')
    need(route('tokens') == tokens, 'ENTRY_REFUSED')
    tap(SURFACE_TOKEN_ROW)
    wait('token_explorer_control', kind='button', gone=True)
    need(route('tokens') == tokens, 'ENTRY_REFUSED')
    observed.append('tokenExplorer')

    send(dict(cmd='tap', tab='pillars'))
    wait('nodes_tab_pillars')
    tap('nodes_tab_pillars')
    wait('nodes_pillars_strip')
    pillars = route('pillars')
    tap('pillars_sort')
    menu = route('pillars')
    need(menu != pillars, 'ENTRY_REFUSED')
    require_seam_absorption(send, 'pillarAprEstimate', 'pillars_sort_apr_gate')
    need(route('pillars') == menu, 'ENTRY_REFUSED')
    send(dict(cmd='key', key='escape'))
    need(route('pillars') == pillars, 'ENTRY_REFUSED')
    observed.append('pillarAprEstimate')

    send(dict(cmd='tap', tab='p2pSwap'))
    wait('p2p_swaps_strip')
    swap = route('p2pSwap')
    tap('p2p_start_swap')
    wait('swap_counterparty_input', kind='field')
    draft = route('p2pSwap')
    require_seam_absorption(send, 'swapTerms', 'swap_start_terms_gate')
    need(route('p2pSwap') == draft, 'ENTRY_REFUSED')
    wait('swap_counterparty_input', kind='field')
    tap('swap_action_close')
    wait('swap_counterparty_input', kind='field', gone=True)
    need(route('p2pSwap') == swap, 'ENTRY_REFUSED')
    observed.append('swapTerms')

    send(dict(cmd='tap', tab='dashboard'))
    wait('home_hero')
    need(route('dashboard') == home, 'ENTRY_REFUSED')
    require_seam_clean_logs(send)


SEAM_PILOTS = {
    SURFACE_SEAMS_FAMILY: (SURFACE_SEAMS_FAMILY, observe_surface_seams, len(SURFACE_SEAMS)),
    SETTINGS_SEAMS_FAMILY: ('settings', observe_settings_seam_pointers,
        sum(len(targets) for _, _, targets in SETTINGS_SEAM_PANELS)),
    HOME_SEAMS_FAMILY: ('home', observe_home_seam_pointers,
        len(HOME_SEAM_CONTROLS) + 3 + len(THEMES) * len(READONLY_OWNER_SEAMS)),
}


def run(repo, parent, runtime, lab_root, observation, revalidate, *, warning_window=None):
    report = dict(schema=4, scope='owned_chain321_wallet_inspection', success=False,
        inspection_qualified=False, wallet_qualified=False, seed_admitted=False, visual_matches=0,
        checks=dict.fromkeys(CHECKS, False), errors=[], phase='admission', captures=[],
        tours={}, locales={}, stalls={}, home_catalog=None, settings_catalog=None, navigation_catalog=None, details_catalog=None, viewport=None,
        sdk_admission=None, wallet_admission=None,
        address_selection=None, lab_revalidations=0, forced_cleanup=False,
        required_actor_forced_cleanup=False, auxiliary_cleanup=None,
        min_free_bytes=shared.FIXTURE_FLOOR, workspace_cap_bytes=shared.WORK_CAP,
        storage_scope='isolated_hosted_regression_fixture_cooperative_samples',
        storage=dict(samples=0, peak_logical_bytes=0, minimum_free_bytes=None, refusal=None),
        cleanup='runner_lifecycle_not_qualified', financial_send_qualified=False,
        motion_baseline_compared=False, arabic_or_minimum_window_qualified=False)
    original = lines = job = output = transport = token = None
    close_attempted = False
    warning_close_grace = False
    catalog_receipt = viewport_receipt = None
    seam_pointers = seam_failure = seam_pilot = seam_trace = None
    family = catalog_slot = 'details'
    details_schema = 1
    catalog_only = seams_only = False
    entry_marker = expected_entry_marker = 'none'
    entry_candidate = None
    try:
        parent, source = debug.entry.require_ci(parent, None, platform=os.name)
        need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
             and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
             and parent.get('SYRIUS_WINDOWS_WALLET_INSPECTION') == 'true'
             and parent.get('SYRIUS_WINDOWS_WALLET_TOUR', 'false') == 'false'
             and parent.get('SYRIUS_LAB_NODE_SOURCE') == 'lab-fix'
             and parent.get('SYRIUS_NATIVE_STACK_DIAGNOSTIC') == 'true', 'ENVIRONMENT_REFUSED')
        family = readonly_catalog_family(parent)
        details_schema = details.FAMILY_SCHEMAS.get(family, 1)
        if family in HOME_CAPTURE_SCHEMAS:
            catalog_slot = 'home'
        else:
            catalog_slot = 'details' if family in details.FAMILY_SCHEMAS else family
        report['schema'] = READONLY_CATALOG_SCHEMAS[family]
        for pilot, field in (
                (HOME_SEAMS_FAMILY, 'home_seam_observations'),
                (SETTINGS_SEAMS_FAMILY, 'settings_seam_observations')):
            if parent.get('SYRIUS_READONLY_CATALOG_FAMILY') == pilot:
                report[field] = dict(schema=1, requested=SEAM_PILOTS[pilot][2],
                    observed=[], probe_failure=None, complete=False)
        seams_only = family == SURFACE_SEAMS_FAMILY
        if seams_only:
            report['seam_refusals'] = []
            need(parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
                 and parent.get('GITHUB_REF') == 'refs/heads/redesign'
                 and parent.get('GITHUB_RUN_ATTEMPT') == '1', 'ENVIRONMENT_REFUSED')
        if family == send_warning_window.FAMILY:
            report['send_warning_window'] = dict(started=False, released=False, samples=[])
        need((family == send_warning_window.FAMILY) == (warning_window is not None),
             'ENVIRONMENT_REFUSED')
        catalog_only = catalog_only_family(report) is not None
        for field, since in (('details_catalog', 4), ('navigation_catalog', 3),
                             ('settings_catalog', 2)):
            if report['schema'] < since:
                report.pop(field)
        report['checks']['environment'] = True
        debug.bounded.verify_source(repo, source, parent)
        tree = debug.entry.source_tree(repo, parent)
        report.update(source_sha=source, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
            run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        report['checks']['source'] = True
        root = debug.entry.private_root(repo)
        output = repo / OUTPUT
        output.mkdir(mode=0o700)
        free = shutil.disk_usage(repo).free
        report['storage']['minimum_free_bytes'] = free
        need(free >= shared.FIXTURE_FLOOR + shared.WORK_CAP, 'STORAGE_REFUSED')
        debug.bounded.check_no_existing(repo, parent)
        name = 'ci-inspect-' + secrets.token_hex(12)
        home, app, build = root / name, root / 'app', repo / 'build/windows/x64'
        need(not any(p.exists() or p.is_symlink() for p in (home, app, build, repo / HOME_OUTPUT, repo / settings.OUTPUT, repo / navigation.OUTPUT, repo / details.OUTPUT, repo / viewport.OUTPUT)), 'PROFILE_REFUSED')
        report['checks']['unused_destinations'] = True
        profile = debug.entry.new_profile(repo)
        profile_identity = shared.directory_identity(profile.lstat())
        need(profile_identity is not None, 'PROFILE_REFUSED')
        env = debug.profile_environment(parent, profile, 1, secrets.token_hex(16))
        env.update(SYRIUS_CI_WALLET_INSPECTION='true', SYRIUS_CI_INSPECTION_INSTANCE=name,
                   SYRIUS_READONLY_CATALOG_FAMILY=family)
        dart, _ = debug.sdk(parent)
        job = debug.WindowsJob()
        original = subprocess.Popen([str(dart), '--disable-dart-dev',
            '--packages=' + str(repo / '.dart_tool/package_config.json'),
            'harness/bin/ci_wallet_inspection.dart'], cwd=repo, env=env, shell=False,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
        job.assign(original)
        report['checks']['job_owned'] = True
        lines = debug.Lines(original.stdout)
        deadline, next_sample = time.monotonic() + 900, 0.0
        used = set()
        stages = []
        ready = None

        def write(data):
            need(original.poll() is None and len(data) <= 4096, 'INPUT_REFUSED')
            original.stdin.write(data)
            original.stdin.flush()

        def lab_current():
            report['phase'] = 'lab_revalidation'
            runtime.healthy()
            now = revalidate()
            need(now['chain'] == observation['chain'] == 321
                 and now['genesis_hash'] == observation['genesis_hash']
                 and now['last_height'] >= observation['last_height']
                 and now['cross_transport_hash_equal'] is observation['cross_transport_hash_equal'] is True,
                 'LAB_REFUSED')
            report['lab_revalidations'] += 1

        def sample(now):
            nonlocal next_sample
            if now >= next_sample:
                logical = shared.sample_workspace((home, app, build, profile),
                    expected_profile=profile_identity)
                logical += sample_capture_outputs(
                    repo, family=family, catalog_only=catalog_only)
                need(logical <= shared.WORK_CAP, 'STORAGE_REFUSED')
                free = shutil.disk_usage(repo).free
                storage = report['storage']
                storage['samples'] += 1
                storage['peak_logical_bytes'] = max(storage['peak_logical_bytes'], logical)
                storage['minimum_free_bytes'] = min(storage['minimum_free_bytes'], free)
                need(free >= shared.FIXTURE_FLOOR, 'STORAGE_REFUSED')
                next_sample = now + 5

        def wait(marker, *, seconds=None):
            nonlocal ready, catalog_receipt, viewport_receipt
            nonlocal warning_close_grace
            nonlocal entry_marker, expected_entry_marker, entry_candidate
            expected_entry_marker = entry_marker_kind(marker)
            limit = deadline if seconds is None else min(deadline, time.monotonic() + seconds)
            while True:
                runtime.healthy()
                now = time.monotonic()
                need(now < limit, 'TOTAL_DEADLINE')
                sample(now)
                raw = lines.take(.1)
                if raw is None:
                    need(original.poll() is None or not lines.complete, 'ENTRY_FAILED')
                    continue
                line = raw.rstrip(b'\r\n')
                entry_marker = entry_marker_kind(line)
                entry_candidate = None
                if line.startswith(b'CI_INSPECT_STAGE:'):
                    ordered = (b'CI_INSPECT_STAGE:gate', b'CI_INSPECT_STAGE:build',
                               b'CI_INSPECT_STAGE:start')
                    need(len(stages) < len(ordered) and line == ordered[len(stages)], 'ENTRY_REFUSED')
                    stages.append(line)
                    used.add(line)
                    if line == marker:
                        return
                elif line.startswith(b'CI_INSPECT_READY:'):
                    need(marker == b'CI_INSPECT_READY' and ready is None
                         and len(stages) == 3, 'ENTRY_REFUSED')
                    ready = ready_receipt(json.loads(line.partition(b':')[2]))
                    return
                elif line.startswith(b'SYRIUS_INSPECTION_ADDRESS:'):
                    need(marker == b'CI_INSPECT_DONE' and 'address' not in used, 'ENTRY_REFUSED')
                    used.add('address')
                    report['address_selection'] = shared.address_selection_receipt(
                        json.loads(line.partition(b':')[2]))
                elif line.startswith(b'SYRIUS_INSPECTION_WALLET:'):
                    need('address' in used and 'wallet' not in used, 'ENTRY_REFUSED')
                    used.add('wallet')
                    report['wallet_admission'] = wallet_receipt(json.loads(line.partition(b':')[2]))
                elif line.startswith(b'SYRIUS_INSPECTION_TOUR:'):
                    need(not catalog_only, 'ENTRY_REFUSED')
                    value = tour_receipt(json.loads(line.partition(b':')[2]))
                    theme = value['theme']
                    need('wallet' in used and theme not in report['tours']
                         and len(report['tours']) == len(report['locales']) ==
                             len(report['stalls']) == THEMES.index(theme), 'ENTRY_REFUSED')
                    report['tours'][theme] = value
                elif line.startswith(b'SYRIUS_INSPECTION_LOCALE:'):
                    need(not catalog_only, 'ENTRY_REFUSED')
                    value = locale_receipt(json.loads(line.partition(b':')[2]))
                    theme = value['theme']
                    need(theme in report['tours'] and theme not in report['locales']
                         and len(report['tours']) == len(report['locales']) + 1
                         and len(report['stalls']) == THEMES.index(theme), 'ENTRY_REFUSED')
                    report['locales'][theme] = value
                elif line.startswith(b'SYRIUS_INSPECTION_STALLS:'):
                    need(not catalog_only, 'ENTRY_REFUSED')
                    value = stalls_receipt(json.loads(line.partition(b':')[2]))
                    theme = value['theme']
                    need(theme in report['locales'] and theme not in report['stalls']
                         and len(report['locales']) == len(report['stalls']) + 1
                         and len(report['stalls']) == THEMES.index(theme), 'ENTRY_REFUSED')
                    report['stalls'][theme] = value
                elif line in (b'CI_INSPECT_SEND_WARN_BEGIN', b'CI_INSPECT_SEND_WARN_DARK',
                              b'CI_INSPECT_SEND_WARN_LIGHT'):
                    need(warning_window is not None and marker == b'CI_INSPECT_DONE'
                         and report['phase'] == 'onboarding_and_inspection'
                         and report['checks']['application_owned']
                         and report['checks']['input_released'] and 'wallet' in used
                         and line not in used and catalog_receipt is None, 'ENTRY_REFUSED')
                    used.add(line)
                    try:
                        if line == b'CI_INSPECT_SEND_WARN_BEGIN':
                            warning_window.begin(limit=limit)
                            warning_window.wait_until_ready(limit)
                            write(b'LAG_WINDOW\n')
                        else:
                            need(b'CI_INSPECT_SEND_WARN_SYNC' in used, 'ENTRY_REFUSED')
                            theme = 'dark' if line.endswith(b'DARK') else 'light'
                            warning_window.sample(theme)
                            write(b'LAG_SAMPLE\n')
                    except send_warning_window.SendWarningWindowRefused:
                        warning_close_grace = True
                        raise
                    report['send_warning_window'] = warning_window.receipt()
                elif line.startswith(b'CI_INSPECT_SEND_WARN_SYNC:'):
                    sync_marker = b'CI_INSPECT_SEND_WARN_SYNC'
                    need(warning_window is not None and marker == b'CI_INSPECT_DONE'
                         and b'CI_INSPECT_SEND_WARN_BEGIN' in used
                         and sync_marker not in used and len(line) <= 768
                         and catalog_receipt is None, 'ENTRY_REFUSED')
                    try:
                        warning_window.observe_wallet_sync(json.loads(line.partition(b':')[2]))
                        used.add(sync_marker)
                        report['send_warning_window'] = warning_window.receipt()
                        write(b'LAG_SYNC_RECORDED\n')
                    except send_warning_window.SendWarningWindowRefused:
                        warning_close_grace = True
                        raise
                elif line.startswith(b'SYRIUS_INSPECTION_CATALOG:'):
                    expected_themes = set() if catalog_only else set(THEMES)
                    need(not seams_only and marker == b'CI_INSPECT_DONE' and catalog_receipt is None
                         and 'wallet' in used and set(report['stalls']) == expected_themes,
                         'ENTRY_REFUSED')
                    if warning_window is not None:
                        need(len(warning_window.receipt()['samples']) == len(THEMES),
                             'ENTRY_REFUSED')
                    receipt = json.loads(line.partition(b':')[2])
                    validators = dict(home=home_capture_receipt,
                        settings=settings.capture_receipt,
                        navigation=navigation.capture_receipt,
                        details=details.capture_receipt)
                    catalog_receipt = validators[catalog_slot](receipt)
                    need(catalog_receipt['schema'] == HOME_CAPTURE_SCHEMAS.get(family, details_schema),
                         'ENTRY_REFUSED')
                elif line.startswith(b'SYRIUS_INSPECTION_VIEWPORT:'):
                    need(not catalog_only and marker == b'CI_INSPECT_DONE' and viewport_receipt is None
                         and catalog_receipt is not None, 'ENTRY_REFUSED')
                    viewport_receipt = viewport.receipt(json.loads(line.partition(b':')[2]))
                elif line.startswith(b'CI_INSPECT_ERROR:'):
                    try:
                        entry_candidate = json.loads(line.partition(b':')[2])
                        report['entry_failure'] = entry_failure(entry_candidate)
                    except (ValueError, TypeError, KeyError, Refused, shared.Refused):
                        raise Refused('ENTRY_REFUSED') from None
                    if warning_window is not None:
                        warning_close_grace = True
                    raise Refused('ENTRY_FAILED')
                elif line == b'CI_INSPECT_DONE':
                    need(marker == line and 'wallet' in used
                         and (catalog_receipt is not None) is (not seams_only)
                         and (viewport_receipt is not None) is (not catalog_only),
                         'ENTRY_REFUSED')
                    return
                elif line.startswith((b'CI_INSPECT_', b'SYRIUS_INSPECTION_',
                        b'CI_WALLET_', b'SYRIUS_LAB_SEND:', b'SYRIUS_WALLET_TOUR:')):
                    raise Refused('ENTRY_REFUSED')

        report['phase'] = 'build_and_start'
        write(b'START\n')
        wait(b'CI_INSPECT_STAGE:gate', seconds=30)
        report['checks']['entry_gate'] = True
        wait(b'CI_INSPECT_READY')
        report['checks']['entry_ready'] = True
        info = debug.bounded.plain(home / 'instance.json')
        debug.bounded.plain(home)
        need(0 < info.st_size <= 4096, 'PROFILE_REFUSED')
        private = json.loads((home / 'instance.json').read_bytes())
        pid, port, token = private.get('pid'), private.get('port'), private.get('token')
        need(type(pid) is int and pid == ready['pid'] and port == ready['port']
             and type(token) is str and re.fullmatch('[a-f0-9]{32}', token)
             and private.get('mode') == 'release' and private.get('harnessMode') == 'readonly-native'
             and private.get('presentationScreen') is None, 'ENTRY_REFUSED')
        job.bind_application(pid, app / 'release/syrius.exe')
        transport = debug.bounded.LoopbackTransport(port, 32768)
        ping = transport.exchange(dict(cmd='ping'), token, 5)
        need(ping.status == 200)
        response = readonly_reply(json.loads(ping.body), pid)
        report['sdk_admission'] = response['readonlyAdmission']
        report['checks']['application_owned'] = True
        report['phase'] = 'lab_revalidation'
        lab_current()
        report['checks']['lab_revalidated'] = True
        private_input = dict(chain='321', node='ws://127.0.0.1:45998',
            password=secrets.token_hex(16) + 'A!1')
        if family != 'wallet-ready':
            private_input['mnemonic'] = shared.public_fixture(
                (repo / 'tools/devnet/lab/README.md').read_text(encoding='utf-8'))
        report['phase'] = 'onboarding_and_inspection'
        report['input_attempted'] = True
        write((json.dumps(private_input) + '\n').encode())
        report['checks']['input_released'] = True
        wait(b'CI_INSPECT_DONE')
        if warning_window is not None:
            warning_window.release(within_window=True)
            report['send_warning_window'] = warning_window.receipt()
        shared.address_selection_receipt(report['address_selection'])
        wallet_receipt(report['wallet_admission'])
        confirm = transport.exchange(dict(cmd='ping'), token, 5)
        need(confirm.status == 200)
        readonly_reply(json.loads(confirm.body), pid, wallet=True)
        report['checks']['wallet_bound'] = True
        if not catalog_only:
            need(all(tour_complete(report['tours'][theme]) for theme in THEMES), 'TOUR_REFUSED')
            report['checks']['tours_complete'] = True
            need(set(report['locales']) == set(THEMES))
            report['checks']['locale_verified'] = True
            for theme in THEMES:
                for page in PAGES:
                    path = output / 'captures' / theme / (page + '.png')
                    raw = read_original(path, debug.entry.MAX_PNG)
                    debug.entry.png_bytes(base64.b64encode(raw).decode('ascii'))
                    report['captures'].append(dict(theme=theme, page=page, bytes=len(raw),
                        sha256=hashlib.sha256(raw).hexdigest(), width=1280, height=780))
            capture_records(report['captures'])
        if seams_only:
            sample_capture_outputs(repo, family=family, catalog_only=True)
        else:
            output_bytes(output, catalog_only=catalog_only)
            if not catalog_only:
                report['checks']['captures'] = True
            if catalog_slot == 'home':
                report['home_catalog'] = collect_home_catalog(
                    repo, catalog_receipt, source, tree, parent)
            else:
                collector = dict(settings=settings, navigation=navigation, details=details)[catalog_slot]
                report[catalog_slot + '_catalog'] = collector.collect(
                    repo, catalog_receipt, source, tree, parent, read_original=read_original)
            if catalog_only:
                report['checks']['captures'] = True
            else:
                report['viewport'] = viewport.collect(repo, viewport_receipt, source, tree, parent,
                    read_original=read_original)
        seam_pilot = SEAM_PILOTS.get(parent.get('SYRIUS_READONLY_CATALOG_FAMILY'))
        if seam_pilot is not None:
            expected_family, observe_seams, _ = seam_pilot
            need(family == expected_family, 'ENTRY_REFUSED')
            seam_pointers = report['seam_refusals'] if seams_only else []
            seam_limit = min(deadline, time.monotonic() + 90)
            seam_deadline_reached = False

            def exchange_seam(command):
                runtime.healthy()
                need(original.poll() is None, 'ENTRY_FAILED')
                sample(time.monotonic())
                timeout = min(35, seam_limit - time.monotonic())
                need(timeout > 0, 'ENTRY_REFUSED')
                response = transport.exchange(command, token, timeout)
                need(response.status == 200, 'ENTRY_REFUSED')
                return readonly_reply(json.loads(response.body), pid, wallet=True)

            try:
                seam_trace = SeamProbeTrace(maximum=1024 if family == 'home' else 128)
                send_seam = lambda command: seam_trace.exchange(exchange_seam, command)
                observe_seams(send_seam, seam_pointers)
                need(len(seam_pointers) == seam_pilot[2], 'ENTRY_REFUSED')
                if seams_only:
                    sample_capture_outputs(repo, family=family, catalog_only=True)
            except Exception as error:
                seam_failure = inspection_failure_code(error, report['phase'])
                seam_deadline_reached = time.monotonic() >= seam_limit
                report['errors'].append(seam_failure)
            finally:
                for field in ('home_seam_observations', 'settings_seam_observations'):
                    if field in report:
                        report[field] = dict(schema=1,
                            requested=seam_pilot[2], observed=[dict(row) for row in seam_pointers],
                            probe_failure=seam_failure, complete=seam_failure is None
                                and len(seam_pointers) == seam_pilot[2])
        lab_current()
        report['phase'] = 'ordinary_close'
        close_attempted = True
        closed = transport.exchange(dict(cmd='quit'), token, 5)
        need(closed.status == 200, 'CLOSE_UNCONFIRMED')
        value = json.loads(closed.body)
        need(set(value) == {'ok', 'pid', 'booted', 'harnessMode', 'readOnly',
             'readonlyAdmission', 'readonlyWallet'}, 'CLOSE_UNCONFIRMED')
        readonly_reply(value, pid, wallet=True)
        report['checks']['close_ack'] = True
        report['application_exit'] = job.application_exit()
        need(report['application_exit'] == 0, 'CLOSE_UNCONFIRMED')
        report['checks']['application_exit'] = True
        write(b'FINISH\n')
        need(original.wait(timeout=15) == 0, 'ENTRY_FAILED')
        report['checks']['entry_exit'] = True
        need(lines.finish(), 'OUTPUT_REFUSED')
        report['checks']['output_complete'] = True
        debug.bounded.verify_source(repo, source, parent)
        need(debug.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        report['checks']['source_unchanged'] = True
        report['auxiliary_cleanup'] = job.finish_known_helpers(
            dart, lambda: debug.compiler_telemetry_image(repo))
        report['forced_cleanup'] = report['auxiliary_cleanup']['forced']
        need(debug.helper_cleanup_complete(report['auxiliary_cleanup']), 'HELPER_CLOSE_UNCONFIRMED')
        report['checks']['auxiliary_cleanup'] = True
        report['phase'] = 'complete'
        if seam_failure is not None and seam_failure not in report['errors']:
            report['errors'].append(seam_failure)
    except (Exception, KeyboardInterrupt) as error:
        code = inspection_failure_code(error, report['phase'])
        report['errors'].append(code)
        if code == 'ENTRY_REFUSED' and report['phase'] == 'onboarding_and_inspection':
            notice = refused_entry_marker(entry_candidate)
            notice.update(marker=entry_marker, expected=expected_entry_marker,
                address_seen='address' in used, wallet_seen='wallet' in used,
                stage_count=len(stages), source_sha=source, source_tree=tree,
                run_id=parent['GITHUB_RUN_ID'],
                run_attempt=parent['GITHUB_RUN_ATTEMPT'])
            print('::notice title=Refused entry marker::' +
                json.dumps(notice, sort_keys=True, separators=(',', ':')),
                flush=True)
    finally:
        if warning_window is not None and 'send_warning_window' in report:
            try:
                warning_window.release_if_owned()
                report['send_warning_window'] = warning_window.receipt()
            except Exception:
                report['errors'].append('SEND_WARNING_WINDOW_REFUSED')
        if warning_close_grace and original is not None:
            try:
                original.stdin.close()
            except OSError:
                report['errors'].append('CLOSE_UNCONFIRMED')
        if job is not None:
            if job.application is not None and not close_attempted:
                close_attempted = True
                try:
                    reply = transport.exchange(dict(cmd='quit'), token, 5)
                    need(reply.status == 200, 'CLOSE_UNCONFIRMED')
                    readonly_reply(json.loads(reply.body), pid,
                        wallet=report['wallet_admission'] is not None)
                    report['cleanup_application_exit'] = job.application_exit()
                except Exception:
                    report['errors'].append('CLOSE_UNCONFIRMED')
            if warning_close_grace and original.poll() is None:
                try:
                    original.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass  # The original forced-cleanup accounting still applies.
                except OSError:
                    report['errors'].append('CLOSE_UNCONFIRMED')
            try:
                report['owned_job_images_before_close'] = job.remaining_images()
            except Exception:
                report['errors'].append('CLOSE_UNCONFIRMED')
            try:
                job.close()
            except Exception:
                report['errors'].append('CLOSE_UNCONFIRMED')
            report['owned_job_active_at_close'] = job.active_at_close
            report['forced_cleanup'] |= job.forced
            report['required_actor_forced_cleanup'] |= job.forced
        if original is not None:
            if original.poll() is None:
                report['required_actor_forced_cleanup'] = report['forced_cleanup'] = True
                original.kill()
            try:
                report['entry_exit'] = original.wait(timeout=10)
            except Exception:
                report['entry_exit'] = None
                report['errors'].append('CLOSE_UNCONFIRMED')
            if not warning_close_grace:
                try:
                    original.stdin.close()
                except OSError:
                    report['errors'].append('CLOSE_UNCONFIRMED')
        if lines is not None:
            lines.finish()
            report['entry_output'] = lines.public()
        report['success'] = report['inspection_qualified'] = completed(report)
        try:
            public_manifest(report)
        except Exception:
            report['success'] = report['inspection_qualified'] = False
            report['errors'].append('OUTPUT_REFUSED')
            if output is not None:
                with (output / 'manifest.private.json').open('x', encoding='ascii') as stream:
                    json.dump(report, stream, sort_keys=True, separators=(',', ':'))
            print(json.dumps(dict(schema=1, scope='readonly_native_output_refusal', code='OUTPUT_REFUSED')))
            return report
        if output is not None:
            text = json.dumps(report, sort_keys=True, separators=(',', ':')) + '\n'
            need(len(text.encode('ascii')) <= MAX_MANIFEST, 'OUTPUT_REFUSED')
            with (output / 'manifest.json').open('x', encoding='ascii') as stream:
                stream.write(text)
        summary = {key: value for key, value in report.items()
                   if key not in ('captures', 'tours', 'locales', 'stalls', 'home_catalog',
                       'settings_catalog', 'navigation_catalog', 'details_catalog', 'viewport')}
        summary.update(viewport_captured=4 if report['viewport'] is not None else 0,
            catalog_captured=(report[catalog_slot + '_catalog']['captured']
                if report.get(catalog_slot + '_catalog') is not None else 0),
            details_catalog_manifest_sha256=(report['details_catalog']['manifest_sha256']
                if report.get('details_catalog') is not None else None),
            navigation_catalog_manifest_sha256=(report['navigation_catalog']['manifest_sha256']
                if report.get('navigation_catalog') is not None else None),
            settings_catalog_manifest_sha256=(report['settings_catalog']['manifest_sha256']
                if report.get('settings_catalog') is not None else None),
            home_catalog_manifest_sha256=(report['home_catalog']['manifest_sha256']
                if report['home_catalog'] is not None else None),
            captured_pages=len(report['captures']),
            visited_pages=sum(len(t['tour']['visited']) for t in report['tours'].values()))
        public = json.dumps(summary, sort_keys=True, separators=(',', ':'))
        print(public)
        if len(public.encode()) <= 3800:
            print('::notice title=Windows readonly inspection outcome::' + public)
        if seam_pointers is not None:
            seam_summary = json.dumps(dict(schema=1,
                scope=f'readonly_native_{family}_seam_pointers',
                source_sha=source, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
                run_attempt=parent['GITHUB_RUN_ATTEMPT'],
                requested=seam_pilot[2],
                observed=seam_pointers,
                probe_failure=seam_failure,
                probe_deadline_reached=seam_deadline_reached,
                command_context=seam_trace.receipt() if seam_trace is not None else None,
                inspection_completed=report['success'],
                application_exit=report.get('application_exit'),
                entry_exit=report.get('entry_exit')),
                sort_keys=True, separators=(',', ':'))
            need(len(seam_summary.encode('ascii')) <= 3800, 'OUTPUT_REFUSED')
            print(f'::notice title=Windows {family} seam pointers::' + seam_summary)
    return report


def artifact_paths(parent):
    """Select only verified manifest references, never a recursive profile tree."""
    parent, source = debug.entry.require_ci(parent, None, platform=os.name)
    repo = Path(parent['GITHUB_WORKSPACE'])
    debug.bounded.verify_source(repo, source, parent)
    path = repo / OUTPUT / 'manifest.json'
    value = json.loads(read_original(path, MAX_MANIFEST))
    public_manifest(value)
    need(value.get('scope') == 'owned_chain321_wallet_inspection'
         and value.get('source_sha') == source
         and value.get('source_tree') == debug.entry.source_tree(repo, parent)
         and value.get('run_id') == parent['GITHUB_RUN_ID']
         and value.get('run_attempt') == parent['GITHUB_RUN_ATTEMPT'], 'SOURCE_REFUSED')
    paths = [str(OUTPUT / 'manifest.json').replace('\\', '/')]
    catalog_only = catalog_only_family(value) is not None
    if value.get('success') is True:
        need(completed(value), 'CAPTURE_REFUSED')
        output_bytes(repo / OUTPUT, catalog_only=catalog_only)
        for row in value['captures']:
            relative = OUTPUT / 'captures' / row['theme'] / (row['page'] + '.png')
            capture = repo / relative
            raw = read_original(capture, debug.entry.MAX_PNG)
            need(len(raw) == row['bytes']
                 and hashlib.sha256(raw).hexdigest() == row['sha256'], 'CAPTURE_REFUSED')
            debug.entry.png_bytes(base64.b64encode(raw).decode('ascii'))
            paths.append(str(relative).replace('\\', '/'))
    catalog_family = {1: 'home-catalog', 2: 'settings-catalog',
        3: 'navigation-catalog', 4: 'details-catalog',
        HOME_BELL_INSPECTION_SCHEMA: 'home-catalog',
        SEND_CONFIRM_INSPECTION_SCHEMA: 'details-catalog',
        SWAP_START_INSPECTION_SCHEMA: 'details-catalog',
        WALLET_READY_INSPECTION_SCHEMA: 'details-catalog',
        SEND_WARNING_INSPECTION_SCHEMA: 'details-catalog',
        HOME_ZAP_PREVIEW_INSPECTION_SCHEMA: 'details-catalog',
        EARN_INSPECTION_SCHEMA: 'details-catalog',
        SENTINEL_INSPECTION_SCHEMA: 'details-catalog',
        SURFACE_SEAMS_SCHEMA: ''}[value['schema']]
    if value['schema'] == SURFACE_SEAMS_SCHEMA:
        sample_capture_outputs(repo, family=SURFACE_SEAMS_FAMILY, catalog_only=True)
        home_paths = []
    elif value['schema'] in HOME_INSPECTION_SCHEMAS:
        home_paths = home_artifact_paths(repo, value)
    elif value['schema'] == 2:
        home_paths = settings.artifact_paths(repo, value, read_original=read_original,
            parent_completed=completed(value))
    elif value['schema'] == 3:
        home_paths = navigation.artifact_paths(repo, value, read_original=read_original,
            parent_completed=completed(value))
    else:
        home_paths = details.artifact_paths(repo, value, read_original=read_original,
            parent_completed=completed(value))
    viewport_paths = [] if catalog_only else viewport.artifact_paths(
        repo, value, parent_completed=completed, read_original=read_original)
    output = Path(parent['GITHUB_OUTPUT'])
    debug.bounded.plain(output)
    with output.open('a', encoding='utf-8') as stream:
        stream.write('paths<<INSPECTION_PATHS_V1\n' + '\n'.join(paths) + '\nINSPECTION_PATHS_V1\n')
        stream.write('catalog_family=' + catalog_family + '\n')
        stream.write('catalog_paths<<HOME_CATALOG_PATHS_V1\n'
            + '\n'.join(home_paths) + '\nHOME_CATALOG_PATHS_V1\n')
        stream.write('viewport_paths<<VIEWPORT_PATHS_V1\n'
            + '\n'.join(viewport_paths) + '\nVIEWPORT_PATHS_V1\n')
    return paths


if __name__ == '__main__':
    if sys.argv[1:] != ['--artifact-paths']:
        raise SystemExit(1)
    try:
        artifact_paths(os.environ)
    except Exception:
        print('WALLET_INSPECTION_ARTIFACT_REFUSED')
        raise SystemExit(1) from None
