"""Read original Windows receipts in Actions memory without repeating runtime."""

import base64
import io
from itertools import groupby
import json
import math
import os
from pathlib import Path
import re
import stat
from statistics import median
import zipfile

from . import inspect_chain321 as archive
from . import inspect_windows_inventory as inventory
from . import dart_test_failure
from . import windows_baseline as baseline
from . import windows_entry_capture_smoke as entry
from . import inspect_startup_qualification as startup
from . import inspect_launch_timing_pair as paired_timing


MAX_LOG = 4 * 1024**2
MAX_ENTRY_ARCHIVE = 4 * entry.MAX_PNG + 1024**2
PRODUCERS = ('windows_baseline.py', 'windows_entry_capture_smoke.py',
             'windows_presentation_smoke.py', 'dart_test_failure.py')
# GitHub retains this exact unevaluated name when the job is skipped.
SKIPPED_BASELINE_JOB = (
    "inputs.windows_inventory_only && 'Hosted Windows inventory' "
    "|| 'Hosted Windows baseline'")
WINDOWS_READER_NAME = 'Inspect retained Windows qualification'
ENTRY_JOB_NAME = 'Ordinary Windows entry captures'
ENTRY_ARTIFACT_PREFIX = 'windows-entry-capture-'
QUIZ_ENTRY_REQUESTS = 14
READONLY_INSPECTOR_STEPS = {
    'Inspect retained chain-321 evidence': (
        'Test archive and credential boundaries in memory',
        'Inspect only the original finite manifests',
    ),
    WINDOWS_READER_NAME: (
        'Test retained Windows receipt controls in memory',
        'Inspect original baseline log and entry archive in memory',
    ),
}
PHASE = 'environment'
CHECK_STAGES = {
    'source': ('source_head', 'source_tree', 'source_clean_before'),
    'locked_restoration': ('restore_application', 'restore_vendored', 'source_clean_restored'),
    'windows_doctor': ('enable_windows', 'doctor'),
    'vendored_analysis': ('analyze_vendored',), 'root_analysis': ('analyze_root',),
    'unit_widget_tests': ('unit_widget_tests',),
    'generated_correspondence': ('generate_sources', 'format_integration',
                                 'generate_localizations', 'source_clean_generated'),
    'debug_build': ('generate_metadata', 'build_debug'), 'release_build': ('build_release',),
    'library_map_exports': ('map_source', 'map_debug', 'map_release'),
    'source_unchanged': ('source_clean_after',),
}


def digest(value):
    return type(value) is str and re.fullmatch('[a-f0-9]{64}', value) is not None


def checks(value, names):
    archive.need(type(value) is dict and set(value) == set(names)
                 and all(type(item) is bool for item in value.values()))
    return dict(value)


def numbers(value, names):
    archive.need(type(value) is dict and set(value) == set(names)
        and all(type(item) is int and 0 <= item <= 10**7 for item in value.values()))
    return dict(value)


def log_report(raw, scope):
    """Only one timestamped producer JSON frame is admitted; raw text stays private."""
    archive.need(type(raw) is bytes and 0 < len(raw) <= MAX_LOG)
    lines = raw.splitlines()
    archive.need(len(lines) <= 20000)
    found = []
    for line in lines:
        match = re.fullmatch(rb'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:'
                             rb'[0-9]{2}(?:\.[0-9]{1,9})?Z (\{.*\})', line)
        if match is None:
            continue
        archive.need(len(match[1]) <= archive.MAX_MANIFEST)
        try:
            value = json.loads(match[1])
        except (ValueError, UnicodeError):
            continue
        if type(value) is dict and value.get('scope') == scope:
            found.append(value)
    archive.need(len(found) == 1)
    return found[0]


def baseline_projection(report, head, tree, run_id):
    archive.need(type(report) is dict and report.get('schema') == 1
        and type(report['schema']) is int and report.get('scope') == 'github_hosted_windows_baseline'
        and report.get('source_sha') == head and report.get('source_tree') == tree
        and report.get('run') == dict(id=str(run_id), attempt='1'))
    original = checks(report.get('checks'), baseline.CHECKS)
    stages, errors = report.get('stages'), report.get('error_codes')
    archive.need(type(stages) is dict and set(stages) <= baseline.STAGES)
    outcomes = {name: inventory.outcome(value) for name, value in stages.items()}
    archive.need(type(errors) is list and len(errors) <= 16
                 and all(type(code) is str and code in baseline.CODES for code in errors))
    for check, names in CHECK_STAGES.items():
        if original[check]:
            for name in names:
                archive.need(name in outcomes)
                value = outcomes[name]
                if name == 'doctor':
                    archive.need(value['exit_observed'] and value['output_complete']
                        and not value['forced_kill'] and not value['output_overflow']
                        and not value['error_codes'])
                else:
                    archive.need(value['success'])
    doctor = report.get('doctor')
    archive.need(type(doctor) is dict and doctor.get('scope') == 'windows_desktop_only'
        and set(doctor) <= {'scope', 'windows_version', 'visual_studio'}
        and all(value in ('pass', 'warning', 'fail', 'unknown')
                for name, value in doctor.items() if name != 'scope'))
    if original['windows_doctor']:
        archive.need(doctor == dict(scope='windows_desktop_only',
                                   windows_version='pass', visual_studio='pass'))
    analysis = report.get('analysis')
    archive.need(type(analysis) is dict and set(analysis) <= {'analyze_root', 'analyze_vendored'})
    projected_analysis = {name: numbers(value, ('errors', 'warnings', 'infos'))
                          for name, value in analysis.items()}
    for check, stage in (('root_analysis', 'analyze_root'), ('vendored_analysis', 'analyze_vendored')):
        if original[check]:
            archive.need(stage in projected_analysis and projected_analysis[stage]['errors'] == 0
                         and projected_analysis[stage]['warnings'] == 0)
    tests = report.get('tests')
    if tests is not None:
        archive.need(type(tests) is dict and type(tests.get('terminal_success')) is bool)
        numbers({key: value for key, value in tests.items() if key != 'terminal_success'},
                ('passed', 'failed', 'skipped', 'hidden', 'terminal_events', 'error_events'))
        archive.need(tests['terminal_events'] > 0 and tests['hidden'] <= tests['terminal_events']
            and tests['passed'] + tests['failed'] + tests['skipped'] <= tests['terminal_events'])
    if original['unit_widget_tests']:
        archive.need(tests is not None and tests['terminal_success'] and tests['passed'] > 0
                     and tests['failed'] == tests['error_events'] == 0)
    localization = report.get('localization_correspondence')
    archive.need(type(localization) is dict and set(localization) <= {'before', 'after'})
    for value in localization.values():
        archive.need(type(value) is dict and set(value) == {'files', 'sha256'}
            and type(value['files']) is int and 0 < value['files'] <= 1000 and digest(value['sha256']))
    if original['generated_correspondence']:
        archive.need(set(localization) == {'before', 'after'}
                     and localization['before'] == localization['after'])
    libraries = report.get('libraries')
    archive.need(type(libraries) is dict and set(libraries) <= set(baseline.LIBRARIES))
    for value in libraries.values():
        archive.need(type(value) is dict and set(value) == {'sha256', 'map_exports'}
                     and digest(value['sha256']) and type(value['map_exports']) is bool)
    if original['library_hash_correspondence'] or original['library_map_exports']:
        archive.need(set(libraries) == set(baseline.LIBRARIES)
                     and len({value['sha256'] for value in libraries.values()}) == 1)
    if original['library_map_exports']:
        archive.need(all(value['map_exports'] for value in libraries.values()))
    archive.need(type(report.get('success')) is bool
                 and report['success'] is (all(original.values()) and not errors))
    failures = None
    if 'test_failures' in report:
        failures = dart_test_failure.locations_projection(report['test_failures'])
        archive.need(failures is not None and not original['unit_widget_tests']
            and report['success'] is False)
    return dict(scope='retained_windows_baseline_observation', inspection_only=True,
        runtime_started=False, wallet_qualified=False, source_head=head, source_tree=tree,
        source_run_id=run_id, source_attempt=1, artifact_reported_success=report['success'],
        original_checks=original, original_error_codes=errors, analysis=projected_analysis,
        tests=tests, doctor=doctor,
        **({'test_failures': failures} if failures is not None else {}),
        localization_unchanged=(set(localization) == {'before', 'after'}
            and localization['before'] == localization['after']), libraries=libraries,
        commands={name: outcomes[name] for name in ('enable_windows', 'doctor',
            'analyze_root', 'analyze_vendored',
            'unit_widget_tests', 'build_debug', 'build_release') if name in outcomes})


def entry_projection(report, head, tree, run_id):
    archive.need(type(report) is dict and type(report.get('schema')) is int and report['schema'] == 2
        and report.get('source_sha') == head and report.get('source_tree') == tree
        and report.get('run_id') == str(run_id) and report.get('run_attempt') == '1')
    original = checks(report.get('checks'), entry.CHECKS)
    caption = report.get('caption')
    archive.need(type(caption) is dict and set(caption) == {'schema', 'observations'}
                 and type(caption['schema']) is int and caption['schema'] == 1)
    captions = checks(caption['observations'], entry.CAPTION_CHECKS)
    for name in ('exit_observed', 'output_complete', 'output_overflow', 'forced_kill', 'complete', 'success'):
        archive.need(type(report.get(name)) is bool)
    code, count, captures = report.get('exit_code'), report.get('capture_count'), report.get('captures')
    archive.need(code is None or type(code) is int and -(2**31) <= code < 2**32)
    archive.need(type(count) is int and 0 <= count <= 4 and type(captures) is list and len(captures) == count)
    seen = set()
    for item in captures:
        archive.need(type(item) is dict and set(item) == {'file', 'sha256', 'bytes', 'width', 'height'}
            and item['file'] in entry.FILES and item['file'] not in seen and digest(item['sha256'])
            and type(item['bytes']) is int and 0 < item['bytes'] <= entry.MAX_PNG
            and type(item['width']) is int and type(item['height']) is int
            and (item['width'], item['height']) == (1280, 780))
        seen.add(item['file'])
    for screen, theme in entry.SCENES:
        if original[screen + '_' + theme]:
            archive.need(screen + '-' + theme + '.png' in seen)
    if original['exit']:
        archive.need(report['exit_observed'] and type(code) is int and code == 0)
    archive.need(type(report.get('output_bytes')) is int and 0 <= report['output_bytes'] < 2**63)
    archive.need(digest(report.get('runner_sha256')) and digest(report.get('dart_kernel_sha256')))
    errors, first, cleanup = report.get('error_codes'), report.get('first_command_failure'), report.get('cleanup_failures')
    archive.need(type(errors) is list and len(errors) <= 32
                 and all(type(code) is str and code in entry.CODES for code in errors))
    archive.need(first is None or entry.failure_projection(first) == first)
    archive.need(type(cleanup) is list and len(cleanup) <= 2
        and all(type(value) is dict and entry.failure_projection(value) == value
                and value['phase'] in entry.CLEANUP_PHASES
                for value in cleanup))
    capture_progress = transport_failure = effect_trace = None
    if 'capture_progress' in report:
        capture_progress = entry.capture_progress_projection(report['capture_progress'])
        archive.need(capture_progress is not None and capture_progress == report['capture_progress'])
    if 'transport_failure' in report:
        transport_failure = entry.transport_failure_projection(report['transport_failure'])
        archive.need(transport_failure is not None and transport_failure == report['transport_failure']
                     and 'HTTP_FAILED' in errors)
    if 'effect_trace' in report:
        effect_trace = entry.effect_trace_projection(report['effect_trace'])
        archive.need(effect_trace is not None and effect_trace == report['effect_trace'])
    complete = (all(original.values()) and all(captions.values()) and count == 4
        and report['exit_observed'] and type(code) is int and code == 0
        and report['output_complete'] and not report['output_overflow'] and not report['forced_kill']
        and not errors and first is None and not cleanup)
    archive.need(report['complete'] is complete and report['success'] is complete
                 and report.get('status') == ('SUCCESS' if complete else 'UNKNOWN'))
    return dict(scope='retained_windows_entry_observation', inspection_only=True,
        runtime_started=False, wallet_qualified=False, visual_matches=0, source_head=head,
        source_tree=tree, source_run_id=run_id, source_attempt=1, artifact_reported_success=complete,
        original_checks=original, caption_checks=captions, captures=captures, capture_count=count,
        exit_code=code, exit_observed=report['exit_observed'], forced_kill=report['forced_kill'],
        output_complete=report['output_complete'], output_overflow=report['output_overflow'],
        output_bytes=report['output_bytes'], original_error_codes=errors, first_command_failure=first,
        cleanup_failures=cleanup,
        **({'capture_progress': capture_progress} if capture_progress is not None else {}),
        **({'effect_trace': effect_trace} if effect_trace is not None else {}),
        **({'transport_failure': transport_failure} if transport_failure is not None else {}))


IMPORT_CONNECTOR_X = (482, 590)
IMPORT_CONNECTOR_Y = (278, 285)
IMPORT_CONNECTOR_REFERENCE_ROW = 280
IMPORT_CONNECTOR_CONTRAST = 5
IMPORT_DROP_X = (359, 921)
IMPORT_DROP_Y = (312, 444)
IMPORT_DROP_INTERVAL = 1366 / 273
IMPORT_DROP_QUARTER = 18.72809091419975
IMPORT_DROP_TOLERANCE_PPM = 25000


def _paeth(left, up, corner):
    target = left + up - corner
    a, b, c = abs(target - left), abs(target - up), abs(target - corner)
    if a <= b and a <= c:
        return left
    return up if b <= c else corner


def _png_crop(encoded, columns, lines):
    _, scanlines, stride = entry.decoded_png(encoded)
    channels = stride // 1280
    x0, x1 = columns
    y0, y1 = lines
    # PNG filters only depend on earlier columns and the previous scanline.
    prefix = x1 * channels
    previous = bytearray(prefix)
    rows = []
    for y in range(y1):
        start = y * (stride + 1)
        filter_type = scanlines[start]
        row = bytearray(scanlines[start + 1:start + 1 + prefix])
        if filter_type:
            for i in range(prefix):
                left = row[i - channels] if i >= channels else 0
                up = previous[i]
                corner = previous[i - channels] if i >= channels else 0
                if filter_type == 1:
                    offset = left
                elif filter_type == 2:
                    offset = up
                elif filter_type == 3:
                    offset = (left + up) // 2
                else:
                    offset = _paeth(left, up, corner)
                row[i] = (row[i] + offset) & 255
        if y >= y0:
            rows.append(row[x0 * channels:prefix])
        previous = row
    return rows, channels


def _opaque(rows, channels):
    return channels == 3 or all(alpha == 255 for row in rows for alpha in row[3::4])


BACK_MARK_COLUMNS = (367, 388)
BACK_MARK_ROWS = {'import': (225, 249), 'seed-quiz': (264, 288)}
BACK_MARK_CONTRAST = 35


def back_mark_bounds(encoded, screen):
    """Measure the Back chevron without the neighboring label."""
    left, right = BACK_MARK_COLUMNS
    top, bottom = BACK_MARK_ROWS[screen]
    rows, channels = _png_crop(encoded, (left, right), (top, bottom))
    if not _opaque(rows, channels):
        return None
    background = rows[0][:3]
    ink = [(left + offset // channels, y)
           for y, row in enumerate(rows, top)
           for offset in range(0, len(row), channels)
           if any(abs(value - base) >= BACK_MARK_CONTRAST
                  for value, base in zip(row[offset:offset + 3], background))]
    if not ink:
        return None
    xs, ys = zip(*ink)
    x0, y0, x1, y1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    if not (left < x0 < x1 < right and top < y0 < y1 < bottom):
        return None
    return dict(bounds=[x0, y0, x1, y1], ink_pixels=len(ink))


COMPLETED_STEP_CROPS = {
    'seed-quiz': ((337, 285, 397, 351),),
    'wallet-ready': ((382, 284, 449, 351), (492, 284, 574, 351),
                     (627, 284, 710, 351), (771, 284, 857, 351)),
}


def completed_step_bounds(encoded, screen):
    """Measure dark checkmark ink against the original green circle."""
    crops = COMPLETED_STEP_CROPS[screen]
    origin_x, origin_y, _, bottom = crops[0]
    rows, channels = _png_crop(encoded, (origin_x, crops[-1][2]), (origin_y, bottom))
    if not _opaque(rows, channels):
        return [None] * len(crops)

    def color(x, y):
        offset = (x - origin_x) * channels
        return rows[y - origin_y][offset:offset + 3]

    results = []
    for left, top, right, bottom in crops:
        green = []
        for y in range(top, bottom):
            for x in range(left, right):
                red, value, blue = color(x, y)
                if value >= 165 and value - max(red, blue) >= 65:
                    green.append((x, y))
        if len(green) < 285:
            results.append(None)
            continue
        xs, ys = zip(*green)
        x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
        if not (left < x0 < x1 < right and top < y0 < y1 < bottom
                and 20 <= x1 - x0 <= 23 and 20 <= y1 - y0 <= 23):
            results.append(None)
            continue
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        ink = [(x, y) for y in range(-6, 6) for x in range(-6, 6)
               if color(cx + x, cy + y)[1] <= 150]
        if not ink:
            results.append(None)
            continue
        xs, ys = zip(*ink)
        results.append(dict(circle=[x0, y0, x1, y1], ink_pixels=len(ink),
                            ink_from_center=[min(xs), min(ys), max(xs) + 1, max(ys) + 1]))
    return results


APPROVED_PRIMARY_PALETTE = ((0, 213, 87), (53, 183, 160), (0, 97, 235))
ORIGINAL_PRIMARY_PALETTE = ((79, 209, 102), (53, 183, 160), (0, 106, 255))
HANDOFF_UNLOCK_BOUNDS = (459, 511, 821, 557)
HANDOFF_OPACITY = .4


def primary_gradient_rgb(point, bounds, palette):
    x, y = point
    left, top, right, bottom = bounds
    angle = math.pi / 18
    span = (right - left) * math.cos(angle) + (bottom - top) * math.sin(angle)
    position = .5 + ((x + .5 - (left + right) / 2) * math.cos(angle)
                     + (y + .5 - (top + bottom) / 2) * math.sin(angle)) / span
    index = int(position >= .55)
    fraction = position / .55 if index == 0 else (position - .55) / .45
    return tuple(start + fraction * (end - start)
                 for start, end in zip(palette[index], palette[index + 1]))


def primary_gradient_error(encoded, bounds):
    """Compare a resting primary action's fill with the approved palette."""
    left, top, right, bottom = bounds
    y = (top + bottom) // 2
    width = right - left
    columns = [left + width * tenth // 10 for tenth in (1, 2, 8, 9)]
    rows, channels = _png_crop(encoded, (columns[0], columns[-1] + 1), (y, y + 1))
    if not _opaque(rows, channels):
        return None
    errors = []
    for x in columns:
        offset = (x - columns[0]) * channels
        expected = primary_gradient_rgb((x, y), bounds, APPROVED_PRIMARY_PALETTE)
        errors.extend(abs(value - target)
                      for value, target in zip(rows[0][offset:offset + 3], expected))
    return dict(max_channel_error_milli=round(max(errors) * 1000),
                mean_channel_error_milli=round(sum(errors) * 1000 / len(errors)))


def handoff_unlock_palette_delta(point):
    approved = primary_gradient_rgb(point, HANDOFF_UNLOCK_BOUNDS, APPROVED_PRIMARY_PALETTE)
    original = primary_gradient_rgb(point, HANDOFF_UNLOCK_BOUNDS, ORIGINAL_PRIMARY_PALETTE)
    return [round(1000 * HANDOFF_OPACITY * (a - b)) for a, b in zip(approved, original)]


def handoff_unlock_palette_band(data, reference):
    """Measure two strips of fill away from the label and rounded ends."""
    left, right = 482, 798
    top, bottom = 528, 540
    columns = tuple(range(left, 581)) + tuple(range(703, right))

    def decode(png):
        return _png_crop(base64.b64encode(png).decode('ascii'), (left, right), (top, bottom))

    actual, a_channels = decode(data)
    expected, e_channels = decode(reference)
    raw_differences = residual_differences = max_residual = 0
    for y, (a_row, e_row) in enumerate(zip(actual, expected), top):
        for x in columns:
            actual_offset = (x - left) * a_channels
            reference_offset = (x - left) * e_channels
            actual_rgb = a_row[actual_offset:actual_offset + 3]
            reference_rgb = e_row[reference_offset:reference_offset + 3]
            change = [1000 * (a_value - e_value)
                      for a_value, e_value in zip(actual_rgb, reference_rgb)]
            palette = handoff_unlock_palette_delta((x, y))
            residual = max(abs(value - delta) for value, delta in zip(change, palette))
            raw_differences += max(map(abs, change)) >= 16000
            residual_differences += residual >= 16000
            max_residual = max(max_residual, residual)
    return dict(sample_count=len(columns) * (bottom - top),
                raw_pixels_at_least_16=raw_differences,
                residual_pixels_at_least_16=residual_differences,
                max_residual_milli=max_residual)


def handoff_unlock_fill_rows(data):
    """Measure the vertical fill edges at two solid parts of the pill."""
    top, bottom = 501, 567
    encoded = base64.b64encode(data).decode('ascii')
    edges = {}
    for name, left, right, channel in (
        ('green', 502, 550, 1),
        ('blue', 742, 782, 2),
    ):
        rows, channels = _png_crop(encoded, (left, right), (top, bottom))
        filled = []
        if _opaque(rows, channels):
            for y, row in enumerate(rows, top):
                count = sum(row[offset + channel] - row[offset] >= 28
                            for offset in range(0, len(row), channels))
                if count * 10 >= (right - left) * 9:
                    filled.append(y)
        if (filled and top < filled[0] <= filled[-1] < bottom - 1
                and len(filled) == filled[-1] - filled[0] + 1):
            edges[name] = [filled[0], filled[-1] + 1]
        else:
            edges[name] = None
    return edges


def _connector_coverage(rows, channels):
    width = IMPORT_CONNECTOR_X[1] - IMPORT_CONNECTOR_X[0]
    y0, y1 = IMPORT_CONNECTOR_Y
    if not _opaque(rows, channels):
        return dict(status='nonopaque', counts=None, full_width_single_row=False, reference_row=False)
    background = rows[0]
    counts = [sum(any(abs(row[i + channel] - background[i + channel]) >= IMPORT_CONNECTOR_CONTRAST
                      for channel in range(3)) for i in range(0, len(row), channels))
              for row in rows]
    return dict(status='observed', counts=counts,
        full_width_single_row=counts.count(width) == 1 and counts.count(0) == len(rows) - 1,
        reference_row=counts == [width if y == IMPORT_CONNECTOR_REFERENCE_ROW else 0
                                 for y in range(y0, y1)])


def import_connector_coverage(encoded):
    """Measure a fixed part of the first Import step connector."""
    return _connector_coverage(*_png_crop(encoded, IMPORT_CONNECTOR_X, IMPORT_CONNECTOR_Y))


WELCOME_TEXT_X = (690, 1055)
WELCOME_TEXT_ROWS = {'title': (226, 265), 'subtitle': (275, 306)}
WELCOME_TEXT_CONTRAST = 40
WELCOME_ACTION_INK_CONTRAST = 40


def welcome_text_bounds(encoded):
    """Measure the first and last ink rows in each Welcome text band."""
    top = WELCOME_TEXT_ROWS['title'][0]
    bottom = WELCOME_TEXT_ROWS['subtitle'][1]
    rows, channels = _png_crop(encoded, WELCOME_TEXT_X, (top, bottom))
    if not _opaque(rows, channels):
        return None
    bounds = {}
    for name, (start, end) in WELCOME_TEXT_ROWS.items():
        lightness = [
            [(299 * row[i] + 587 * row[i + 1] + 114 * row[i + 2] + 500) // 1000
             for i in range(0, len(row), channels)]
            for row in rows[start - top:end - top]
        ]
        background = median(value for row in lightness for value in row)
        ink = [y for y, row in enumerate(lightness, start)
               if sum(abs(value - background) >= WELCOME_TEXT_CONTRAST for value in row) >= 2]
        if not ink or ink[0] == start or ink[-1] == end - 1:
            return None
        bounds[name] = [ink[0], ink[-1]]
    return bounds


def _drop_border_coverage(rows, channels, theme):
    if not _opaque(rows, channels):
        return dict(status='nonopaque', mean_error_ppm=None, model_within_tolerance=False)
    # The model follows the pinned reference's 562 by 132 rounded border,
    # beginning at the upper-left tangent and moving clockwise.
    left, right = IMPORT_DROP_X
    top, bottom = IMPORT_DROP_Y
    radius = 12
    across, down = right - left - 2 * radius, bottom - top - 2 * radius
    quarter = IMPORT_DROP_QUARTER
    columns, lines = range(386, 894), range(326, 422)
    edges = (
        ('top', True, top, 320, columns, columns.start - left - radius, 1),
        ('right', False, right - 1, 912, lines, across + quarter + lines.start - top - radius, 1),
        ('bottom', True, bottom - 1, 435, columns,
            across + down + 2 * quarter + right - radius - (columns.start + 1), -1),
        ('left', False, left, 368, lines,
            2 * across + down + 3 * quarter + bottom - radius - (lines.start + 1), -1),
    )
    peak = {'dark': 70, 'light': 122}[theme]

    def pixel(x, y):
        start = (x - IMPORT_DROP_X[0]) * channels
        return rows[y - IMPORT_CONNECTOR_Y[0]][start:start + 3]

    errors = {}
    for name, horizontal, border, fill, positions, start, direction in edges:
        loss = 0.0
        for index, position in enumerate(positions):
            edge, interior = ((pixel(position, border), pixel(position, fill))
                              if horizontal else (pixel(border, position), pixel(fill, position)))
            coverage = max(abs(a - b) for a, b in zip(edge, interior)) / peak
            phase = (start + index * direction) % IMPORT_DROP_INTERVAL
            expected = max(0, min(1, 3 - phase)) + max(0, phase + 1 - IMPORT_DROP_INTERVAL)
            loss += abs(coverage - expected)
        errors[name] = round(loss * 1000000 / len(positions))
    return dict(status='observed', mean_error_ppm=errors,
        model_within_tolerance=max(errors.values()) <= IMPORT_DROP_TOLERANCE_PPM)


def import_image_coverage(encoded, theme):
    """Read the two fixed observations from one decoded entry image."""
    x0, x1 = IMPORT_DROP_X
    y0 = IMPORT_CONNECTOR_Y[0]
    rows, channels = _png_crop(encoded, (x0, x1), (y0, IMPORT_DROP_Y[1]))
    start, stop = ((value - x0) * channels for value in IMPORT_CONNECTOR_X)
    connector = [row[start:stop] for row in rows[:IMPORT_CONNECTOR_Y[1] - y0]]
    return _connector_coverage(connector, channels), _drop_border_coverage(rows, channels, theme)


ENTRY_REFERENCE_FILES = {
    'welcome-dark.png': '44-welcome-dark.png',
    'welcome-light.png': '44-welcome-light.png',
    'import-dark.png': '45-import-dark.png',
    'import-light.png': '45-import-light.png',
}


ENTRY_REGIONS = {
    'welcome': {
        'caption': (0, 0, 1280, 30),
        'globe': (197, 185, 650, 637),
        'introduction': (684, 223, 1102, 307),
        'action_left_edge': (684, 308, 704, 560),
        'action_badges': (704, 308, 755, 560),
        'action_labels': (755, 308, 1056, 560),
        'action_chevrons': (1056, 308, 1082, 560),
        'action_right_edge': (1082, 308, 1102, 560),
        'footer': (684, 564, 1102, 594),
    },
    'import': {
        'caption': (0, 0, 1280, 30),
        'heading_and_steps': (324, 193, 955, 306),
        'drop_zone': (324, 306, 955, 451),
        'seed_field': (324, 451, 955, 542),
        'footer_controls': (324, 542, 955, 620),
    },
}


def _ink_shift(captured, reference):
    if not captured or not reference:
        return None
    candidates = [(len(reference ^ {(x + dx, y + dy) for x, y in captured}), dx, dy)
                  for dx in range(-2, 3) for dy in range(-2, 3)]
    error, dx, dy = min(candidates, key=lambda value: (value[0], abs(value[1]) + abs(value[2])))
    return dict(shift_to_reference=[dx, dy],
                original_difference=len(reference ^ captured), shifted_difference=error)


def caption_wordmark_alignment(actual, a_channels, expected, e_channels):
    """Compare wordmark ink with nearby caption fill and test small shifts."""
    def ink(rows, channels):
        result = set()
        for y in range(6, 24):
            row = rows[y]
            background = row[102 * channels:102 * channels + 3]
            for x in range(6, 100):
                offset = x * channels
                if max(abs(a - b) for a, b in zip(row[offset:offset + 3], background)) >= 16:
                    result.add((x, y))
        return result

    return _ink_shift(ink(actual, a_channels), ink(expected, e_channels))


def pillar_caption_alignment(actual, a_channels, expected, e_channels):
    """Compare the receipt caption with the plain fill at the left of its row."""
    def ink(rows, channels):
        points = set()
        for y in range(528, 560):
            row = rows[y]
            background = row[480 * channels:480 * channels + 3]
            for x in range(500, 1140):
                offset = x * channels
                if max(abs(a - b) for a, b in zip(row[offset:offset + 3], background)) >= 16:
                    points.add((x, y))
        return points

    captured = ink(actual, a_channels)
    reference = ink(expected, e_channels)
    result = _ink_shift(captured, reference)
    if result is not None:
        for name, points in (('actual_bounds', captured), ('reference_bounds', reference)):
            x, y = zip(*points)
            result[name] = [min(x), min(y), max(x) + 1, max(y) + 1]
    return result


def pillar_spawn_field_runs(rows, channels):
    """Measure solid input fills at a column clear of the reference address ink."""
    x = 820 * channels
    background = rows[105][x:x + 3]
    result = []
    for rgb, run in groupby(range(105, 390), key=lambda y: rows[y][x:x + 3]):
        if rgb != background:
            positions = list(run)
            if len(positions) >= 16:
                result.append(dict(rows=[positions[0], positions[-1] + 1], rgb=list(rgb)))
    return result


def welcome_action_alignment(actual, a_channels, expected, e_channels):
    """Measure small text offsets inside the three reference action rows."""
    def ink(rows, channels, top, bottom):
        return {(x, y) for y in range(top, bottom) for x in range(755, 1020)
                if abs(rows[y][x * channels] - rows[y][1020 * channels])
                >= WELCOME_ACTION_INK_CONTRAST}

    results = {}
    for index, name in enumerate(('create', 'import', 'hardware')):
        for part, (top, bottom) in (('label', (334, 352)), ('hint', (353, 370))):
            start, end = top + index * 82, bottom + index * 82
            captured = ink(actual, a_channels, start, end)
            reference = ink(expected, e_channels, start, end)
            shift = _ink_shift(captured, reference)
            if shift is not None:
                results[name + '_' + part] = shift
    return results


def settings_label_alignment(actual, a_channels, expected, e_channels):
    """Measure label masks and colour-channel spread in the Display menu."""
    def ink(rows, channels, top, bottom):
        mask = set()
        channel_spread = 0
        for y in range(top, bottom):
            row = rows[y]
            background = row[236 * channels:236 * channels + 3]
            for x in range(100, 200):
                pixel = row[x * channels:x * channels + 3]
                delta = [value - base for value, base in zip(pixel, background)]
                if max(map(abs, delta)) >= 16:
                    mask.add((x, y))
                    channel_spread += max(delta) - min(delta) >= 16
        return mask, channel_spread

    bounds = (44, 82, 121, 159, 197, 235, 274, 312)
    names = ('addresses', 'node', 'security', 'display', 'wallet', 'apps', 'about')
    results = {}
    for name, top, bottom in zip(names, bounds, bounds[1:]):
        captured, a_spread = ink(actual, a_channels, top, bottom)
        reference, e_spread = ink(expected, e_channels, top, bottom)
        results[name] = dict(actual_ink_pixels=len(captured), reference_ink_pixels=len(reference),
                             actual_channel_spread_pixels=a_spread,
                             reference_channel_spread_pixels=e_spread,
                             alignment=_ink_shift(captured, reference))
    return results


def settings_status_alignment(actual, a_channels, expected, e_channels):
    """Compare the Chain and Peers text after accounting for fixture widths."""
    def ink(rows, channels):
        result = set()
        for y in range(735, 753):
            row = rows[y]
            background = row[900 * channels:900 * channels + 3]
            for x in range(90, 850):
                offset = x * channels
                if max(abs(a - b) for a, b in zip(row[offset:offset + 3], background)) >= 25:
                    result.add((x, y))
        return result

    def word(mask, left, width):
        return {(x - left, y) for x, y in mask if left <= x < left + width}

    current = ink(actual, a_channels)
    reference = ink(expected, e_channels)
    columns = {x for x, _ in current}
    # Each connection fact follows a gap. Values can change the horizontal
    # start of the following label without changing its vertical placement.
    starts = sorted(x for x in columns if all(x - n not in columns for n in (1, 2, 3)))
    result = {}
    for name, left, width in (('chain', 408, 35), ('peers', 477, 34)):
        expected_word = word(reference, left, width)
        choices = []
        for x in starts:
            captured_word = word(current, x, width)
            alignment = _ink_shift(captured_word, expected_word)
            if alignment is not None and 2 * alignment['shifted_difference'] <= len(expected_word):
                choices.append((x, alignment))
        if choices:
            best = min(alignment['shifted_difference'] for _, alignment in choices)
            winners = [(x, alignment) for x, alignment in choices
                       if alignment['shifted_difference'] == best]
            if len(winners) == 1:
                x, alignment = winners[0]
                result[name] = dict(actual_left=x, reference_left=left, **alignment)
    return result


def import_backdrop_palette_model(actual, a_channels, reference, r_channels, theme):
    """Recolor the same modeled light contributions in an unobstructed crop."""
    base = {'dark': (27, 28, 27), 'light': (234, 234, 234)}[theme]
    original = ((79, 209, 102), (0, 106, 255), (249, 22, 144))
    approved = ((0, 213, 87), (0, 97, 235), original[2])
    offsets = [tuple(channel - bg for channel, bg in zip(color, base))
               for color in original]

    def dot(a, b):
        return sum(x * y for x, y in zip(a, b))

    def cross(a, b):
        return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
                a[0] * b[1] - a[1] * b[0])

    green, blue, pink = offsets
    cofactors = (cross(blue, pink), cross(pink, green), cross(green, blue))
    determinant = dot(green, cofactors[0])
    # Each observed pixel is the base plus three effective light contributions.
    # Keep those weights and replace just the authored green and blue values.
    shifts = [tuple(after - before for before, after in zip(old, new))
              for old, new in zip(original, approved)]
    channel_shifts = tuple(zip(*shifts))
    left, top, right, bottom = 220, 235, 250, 265
    raw_error = modeled_error = 0.0
    for y in range(top, bottom):
        for x in range(left, right):
            a, r = x * a_channels, x * r_channels
            observed = actual[y][a:a + 3]
            sample = reference[y][r:r + 3]
            centered = tuple(value - bg for value, bg in zip(sample, base))
            weights = [dot(centered, cofactor) / determinant for cofactor in cofactors]
            if any(weight < -0.03 for weight in weights) or sum(weights) > 0.38:
                return dict(status='unavailable', crop=[left, top, right, bottom])
            model = [value + dot(weights, channel)
                     for value, channel in zip(sample, channel_shifts)]
            raw_error += sum(abs(a - b) for a, b in zip(observed, sample))
            modeled_error += sum(abs(a - b) for a, b in zip(observed, model))
    count = 3 * (right - left) * (bottom - top)
    return dict(status='estimated', crop=[left, top, right, bottom],
                raw_mean_rgb_error_milli=round(1000 * raw_error / count),
                modeled_mean_rgb_error_milli=round(1000 * modeled_error / count))


def import_numeral_bottom_rows(rows, channels):
    """Read digit ink away from the top and bottom of each badge ring."""
    background = rows[294][400 * channels:400 * channels + 3]
    bottoms = []
    for x in (369, 621, 862):
        start = x * channels
        ink = [y for y in range(274, 289)
               if max(abs(a - b) for a, b in zip(rows[y][start:start + 3], background)) >= 16]
        bottoms.append(max(ink) if ink else None)
    return bottoms


def entry_pixel_comparison(data, reference, screen, *, theme=None):
    """Summarize original RGB differences without writing or grading an image."""
    return pixel_comparison(data, reference, ENTRY_REGIONS[screen],
                            align_welcome_actions=screen == 'welcome',
                            import_background_theme=theme if screen == 'import' else None,
                            align_caption=True)


def pixel_comparison(data, reference, regions, *, align_welcome_actions=False,
                     sample_points=None, import_background_theme=None,
                     align_settings_labels=False, align_caption=False,
                     align_pillar_caption=False, sample_spawn_fields=False):
    """Compare original opaque client images in the supplied fixed regions."""
    def decode(png):
        encoded = base64.b64encode(png).decode('ascii')
        return _png_crop(encoded, (0, 1280), (0, 780))

    actual, a_channels = decode(data)
    expected, e_channels = decode(reference)
    if not (_opaque(actual, a_channels) and _opaque(expected, e_channels)):
        return None
    by_region = dict.fromkeys(regions, 0)
    by_region['outside_crops'] = 0
    changed = high_contrast = total = 0
    for y, (actual_row, expected_row) in enumerate(zip(actual, expected)):
        active_regions = [(name, left, right)
                          for name, (left, top, right, bottom) in regions.items()
                          if top <= y < bottom]
        for x, (a, e) in enumerate(zip(range(0, len(actual_row), a_channels),
                                      range(0, len(expected_row), e_channels))):
            red = abs(actual_row[a] - expected_row[e])
            green = abs(actual_row[a + 1] - expected_row[e + 1])
            blue = abs(actual_row[a + 2] - expected_row[e + 2])
            difference = red + green + blue
            changed += difference != 0
            if red >= 16 or green >= 16 or blue >= 16:
                high_contrast += 1
                region = next((name for name, left, right in active_regions
                               if left <= x < right), 'outside_crops')
                by_region[region] += 1
            total += difference
    result = dict(reference_sha256=archive.sha(reference), actual_sha256=archive.sha(data),
                changed_pixels=changed, changed_pixels_at_least_16=high_contrast,
                pixels_at_least_16_by_region=by_region,
                mean_rgb_error_milli=round(1000 * total / (1280 * 780 * 3)))
    if align_welcome_actions:
        result['action_alignment'] = welcome_action_alignment(actual, a_channels, expected, e_channels)
    if align_caption:
        alignment = caption_wordmark_alignment(actual, a_channels, expected, e_channels)
        if alignment is not None:
            result['caption_wordmark_alignment'] = alignment
    if align_pillar_caption:
        alignment = pillar_caption_alignment(actual, a_channels, expected, e_channels)
        if alignment is not None:
            result['pillar_caption_alignment'] = alignment
    if sample_spawn_fields:
        result['spawn_field_fills'] = dict(
            column=820,
            actual=pillar_spawn_field_runs(actual, a_channels),
            reference=pillar_spawn_field_runs(expected, e_channels),
        )
    if align_settings_labels:
        result['settings_label_alignment'] = settings_label_alignment(
            actual, a_channels, expected, e_channels)
        result['settings_status_alignment'] = settings_status_alignment(
            actual, a_channels, expected, e_channels)
    if import_background_theme is not None:
        result['backdrop_palette_model'] = import_backdrop_palette_model(
            actual, a_channels, expected, e_channels, import_background_theme)
        result['step_numeral_bottom_rows'] = dict(
            actual=import_numeral_bottom_rows(actual, a_channels),
            reference=import_numeral_bottom_rows(expected, e_channels))
    if sample_points is not None:
        result['sample_rgb'] = {
            name: dict(point=[x, y],
                       actual=list(actual[y][x * a_channels:x * a_channels + 3]),
                       reference=list(expected[y][x * e_channels:x * e_channels + 3]))
            for name, (x, y) in sample_points.items()
        }
    return result


def startup_pixel_comparison(name, data):
    """Compare a verified startup capture against the tracked original shot."""
    references = Path(__file__).resolve().parents[2] / 'mockups/redesign/shots'
    with (references / name).open('rb') as stream:
        reference = stream.read(entry.MAX_PNG + 1)
    archive.need(0 < len(reference) <= entry.MAX_PNG)
    caption = dict(caption_wordmark=(0, 0, 100, 32),
                   caption_background=(100, 0, 1144, 32),
                   caption_controls=(1144, 0, 1280, 32))
    regions = dict(**caption, body=(0, 32, 1280, 780))
    points = None
    if name in startup.launch.SETTLE_FILES or name.startswith('41-lock-screen-'):
        # The same exterior points also sample the settled Lock backdrop.
        points = dict(startup.BACKDROP_SAMPLE_POINTS, caption_left=(300, 14),
                      caption_middle=(640, 14), caption_right=(960, 14),
                      caption_bottom=(640, 31))
    if name in startup.launch.SETTLE_FILES:
        # Fixed crops use the authored 0.4 checkpoint in the 1280 by 780 client.
        regions = dict(**caption, stage=(250, 149, 1030, 479),
                       above_unlock=(430, 479, 850, 510),
                       unlock_band=(430, 510, 850, 556),
                       below_unlock=(430, 556, 850, 668),
                       bottom=(0, 700, 1280, 780))
        points.update(film=(300, 240), form=(450, 520),
                      unlock_left=(510, 533), unlock_right=(730, 533),
                      above_unlock=(510, 500), below_unlock=(510, 565))
    result = pixel_comparison(data, reference, regions, sample_points=points,
                              align_caption=True)
    archive.need(result is not None)
    result['region_bounds'] = regions
    if name in startup.launch.SETTLE_FILES:
        # Estimate only the palette contribution at the two flat fill samples.
        # Geometry, text and the raw comparison stay in the original receipt.
        palette = {}
        for key in ('unlock_left', 'unlock_right'):
            sample = result['sample_rgb'][key]
            change = handoff_unlock_palette_delta(sample['point'])
            residual = [1000 * (a - b) - delta
                        for a, b, delta in zip(sample['actual'], sample['reference'], change)]
            palette[key] = dict(model_delta_milli=change, residual_delta_milli=residual)
        result['unlock_palette_samples'] = palette
        result['unlock_palette_band'] = handoff_unlock_palette_band(data, reference)
        result['unlock_fill_rows'] = dict(actual=handoff_unlock_fill_rows(data),
                                          reference=handoff_unlock_fill_rows(reference))
    return result


def emit_startup_comparison(title, summary, reference_head):
    comparisons = summary.pop('pixel_comparisons', {})
    emit(title, summary)
    for name, result in comparisons.items():
        emit('Retained startup pixel comparison', dict(
            scope='retained_startup_pixel_comparison', file=name,
            source_head=summary['source_head'], source_run_id=summary['source_run_id'],
            reference_head=reference_head, archive_sha256=summary['archive_sha256'],
            visual_matches=0, **result))


def entry_archive(raw, expected_sha, expected_size, head, tree, run_id, *, reference_dir=None):
    archive.need(type(raw) is bytes and type(expected_size) is int and digest(expected_sha)
                 and 0 < len(raw) == expected_size <= MAX_ENTRY_ARCHIVE
                 and archive.sha(raw) == expected_sha)
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        names = [value.filename for value in members]
        archive.need(1 <= len(names) <= 5 and len(set(names)) == len(names)
            and 'manifest.json' in names and set(names) <= {'manifest.json', *entry.FILES})
        for member in members:
            cap = archive.MAX_MANIFEST if member.filename == 'manifest.json' else entry.MAX_PNG
            archive.need(not member.is_dir() and not member.flag_bits & 1
                and 0 < member.file_size <= cap
                and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG))
        manifest = zipped.read('manifest.json')
        summary = entry_projection(json.loads(manifest), head, tree, run_id)
        archive.need(set(names) == {'manifest.json', *(value['file'] for value in summary['captures'])})
        connector, drop, welcome, comparisons, back = {}, {}, {}, {}, {}
        for value in summary['captures']:
            name = value['file']
            data = zipped.read(name)
            archive.need(len(data) == value['bytes'] and archive.sha(data) == value['sha256'])
            encoded = base64.b64encode(data).decode('ascii')
            if name in ('import-dark.png', 'import-light.png'):
                theme = name.removeprefix('import-').removesuffix('.png')
                connector[name], drop[name] = import_image_coverage(encoded, theme)
                back[name] = back_mark_bounds(encoded, 'import')
            else:
                welcome[name] = welcome_text_bounds(encoded)
            if reference_dir is not None:
                with (reference_dir / ENTRY_REFERENCE_FILES[name]).open('rb') as stream:
                    reference = stream.read(entry.MAX_PNG + 1)
                archive.need(0 < len(reference) <= entry.MAX_PNG)
                screen, theme = name.removesuffix('.png').split('-', 1)
                comparisons[name] = entry_pixel_comparison(data, reference, screen, theme=theme)
    summary.update(archive_sha256=archive.sha(raw), manifest_sha256=archive.sha(manifest),
                   import_connector_coverage=connector, import_drop_border_coverage=drop,
                   welcome_text_bounds=welcome, entry_pixel_comparisons=comparisons,
                   import_back_marks=back)
    return summary


def emit(title, summary):
    encoded = json.dumps(summary, sort_keys=True, separators=(',', ':'))
    archive.need(encoded.isascii() and len(encoded.encode()) <= 3800)
    print(encoded)
    print('::notice title=' + title + '::' + encoded)


def require_startup_job_set(jobs, producer, head, run_id):
    others = [job for job in jobs if job is not producer]
    archive.need(all(job['head_sha'] == head and job['run_id'] == run_id
        and job['status'] == 'completed' for job in others))
    executed = [job for job in others if job['conclusion'] != 'skipped']
    if not executed:
        return []
    # These explicitly selected readers can share a run with Windows captures.
    # Each artifact inspector still checks the exact set from the capture steps.
    batch = producer['name'] == startup.BATCH_JOB_NAME
    if batch:
        archive.need([job['name'] for job in executed] == [WINDOWS_READER_NAME])
    else:
        archive.need(producer['name'] == startup.JOB_NAME
            and any(step['name'] == paired_timing.pair.JOB_STEP
                    and step['status'] == 'completed'
                    and step['conclusion'] in ('success', 'failure') for step in producer['steps']))
    archive.need(len({job['name'] for job in executed}) == len(executed)
        and len({job['id'] for job in [producer, *executed]}) == len(executed) + 1)
    for job in executed:
        archive.need(job['name'] in READONLY_INSPECTOR_STEPS
            and job['labels'] == ['ubuntu-24.04']
            and (job['conclusion'] == 'success' or (batch and job['conclusion'] == 'failure')))
        controls, inspection = READONLY_INSPECTOR_STEPS[job['name']]
        expected = ['success', 'success', 'success', job['conclusion'], 'success', 'success']
        archive.need([step['name'] for step in job['steps']] == [
            'Set up job', 'Checkout the dispatched inspector source', controls, inspection,
            'Post Checkout the dispatched inspector source', 'Complete job']
            and [step['conclusion'] for step in job['steps']] == expected
            and all(step['status'] == 'completed' for step in job['steps']))
    return executed


def verify_entry_sources(client, head):
    global PHASE
    PHASE = 'source_metadata'
    for name in PRODUCERS:
        selected = client.json('/contents/tool/ci/' + name + '?ref=' + head)
        archive.need(selected['type'] == 'file' and selected['encoding'] == 'base64'
                     and selected['path'] == 'tool/ci/' + name)
        data = base64.b64decode(selected['content'].replace('\n', ''), validate=True)
        archive.need(len(data) == selected['size'] and data == Path(__file__).with_name(name).read_bytes())


def inspect_entry(client, text, head, tree, run_id, job, *, item=None):
    global PHASE
    PHASE = 'entry_artifact'
    name = ENTRY_ARTIFACT_PREFIX + head + '-' + text + '-1'
    if item is None:
        listing = client.json('/actions/runs/' + text + '/artifacts?per_page=20')
        archive.need(listing['total_count'] == len(listing['artifacts']) <= 20)
        selected = [candidate for candidate in listing['artifacts'] if candidate['name'] == name]
        archive.need(len(selected) == 1)
        item = selected[0]
    archive.need(item['name'] == name and item['expired'] is False
        and item['workflow_run']['id'] == run_id and item['workflow_run']['head_sha'] == head
        and type(item['id']) is int and item['id'] > 0
        and type(item['size_in_bytes']) is int and 0 < item['size_in_bytes'] <= MAX_ENTRY_ARCHIVE
        and re.fullmatch('sha256:[a-f0-9]{64}', item.get('digest', '')) is not None)
    location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
    raw = client.read(location, authenticated=False, cap=MAX_ENTRY_ARCHIVE)
    reference_head = os.environ.get('WINDOWS_REFERENCE_HEAD')
    reference_dir = None
    if reference_head is not None:
        archive.need(re.fullmatch('[a-f0-9]{40}', reference_head) is not None)
        reference_dir = Path(__file__).resolve().parents[2] / 'mockups/redesign/shots'
    summary = entry_archive(raw, item['digest'][7:], item['size_in_bytes'], head, tree,
                            run_id, reference_dir=reference_dir)
    archive.need(job['conclusion'] != 'success' or summary['artifact_reported_success'])
    summary.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'],
                   producer_sources_equal=True)
    connector = summary.pop('import_connector_coverage')
    drop = summary.pop('import_drop_border_coverage')
    welcome = summary.pop('welcome_text_bounds')
    comparisons = summary.pop('entry_pixel_comparisons')
    back = summary.pop('import_back_marks')
    emit('Hosted entry inspection', summary)
    binding = dict(source_head=head, source_tree=tree, source_run_id=run_id,
        source_attempt=1, original_job_id=job['id'], original_job_conclusion=job['conclusion'],
        archive_sha256=summary['archive_sha256'], manifest_sha256=summary['manifest_sha256'],
        visual_matches=0)
    if any(band['status'] == 'observed' for band in connector.values()):
        emit('Hosted Import connector coverage', dict(
            scope='retained_import_connector_coverage', **binding,
            x_range=list(IMPORT_CONNECTOR_X), y_range=list(IMPORT_CONNECTOR_Y),
            minimum_channel_contrast=IMPORT_CONNECTOR_CONTRAST, bands=connector))
    if any(edge['status'] == 'observed' for edge in drop.values()):
        emit('Hosted Import drop border coverage', dict(
            scope='retained_import_drop_border_coverage', **binding,
            reference_bounds=[IMPORT_DROP_X[0], IMPORT_DROP_Y[0], IMPORT_DROP_X[1], IMPORT_DROP_Y[1]],
            tolerance_ppm=IMPORT_DROP_TOLERANCE_PPM, edges=drop))
    if any(bounds is not None for bounds in welcome.values()):
        emit('Hosted Welcome text bands', dict(scope='retained_welcome_text_bounds',
            **binding, x_range=list(WELCOME_TEXT_X), crops=WELCOME_TEXT_ROWS,
            minimum_luminance_contrast=WELCOME_TEXT_CONTRAST, bounds=welcome))
    if any(value is not None for value in back.values()):
        emit('Hosted Import Back mark bounds', dict(scope='retained_import_back_mark_bounds',
            **binding, columns=BACK_MARK_COLUMNS, rows=BACK_MARK_ROWS['import'],
            minimum_channel_contrast=BACK_MARK_CONTRAST, marks=back))
    if any(value is not None for value in comparisons.values()):
        caption = {name: value.pop('caption_wordmark_alignment')
                   for name, value in comparisons.items()
                   if value is not None and 'caption_wordmark_alignment' in value}
        if caption:
            emit('Hosted caption wordmark alignment', dict(
                scope='retained_caption_wordmark_alignment', **binding,
                reference_head=reference_head, alignment=caption))
        alignment = {name: value.pop('action_alignment', {}) for name, value in comparisons.items()
                     if value is not None and name.startswith('welcome-')}
        if any(alignment.values()):
            emit('Hosted Welcome action alignment', dict(
                scope='retained_welcome_action_alignment', **binding,
                reference_head=reference_head, minimum_red_contrast=WELCOME_ACTION_INK_CONTRAST,
                alignment=alignment))
        palette = {name: value.pop('backdrop_palette_model') for name, value in comparisons.items()
                   if value is not None and 'backdrop_palette_model' in value}
        if palette:
            emit('Hosted Import backdrop palette model', dict(
                scope='retained_import_backdrop_palette_model', **binding,
                reference_head=reference_head, estimates=palette))
        numerals = {name: value.pop('step_numeral_bottom_rows')
                    for name, value in comparisons.items()
                    if value is not None and 'step_numeral_bottom_rows' in value}
        if numerals:
            emit('Hosted Import step numeral rows', dict(
                scope='retained_import_step_numeral_rows', **binding,
                reference_head=reference_head, rows=numerals))
        emit('Hosted entry pixel comparisons', dict(
            scope='retained_entry_pixel_comparisons', **binding,
            reference_head=reference_head, size=[1280, 780],
            region_bounds=ENTRY_REGIONS, comparisons=comparisons))


def inspect_quiz_entry_bundle(client, text, head, tree, run_id, quiz_job, entry_job):
    """Read the two archives from their original jobs without another build."""
    global PHASE
    for job, capture, retain in (
        (quiz_job, startup.quiz_catalog.JOB_STEP,
         'Retain the synthetic seed quiz manifest and PNGs'),
        (entry_job, 'Capture genuine ordinary entry and observe original process exit',
         'Retain entry evidence and finite manifest'),
    ):
        steps = {step['name']: step for step in job['steps']}
        archive.need(job['head_sha'] == head and job['run_id'] == run_id
            and job['status'] == 'completed' and job['conclusion'] in ('success', 'failure')
            and job['labels'] == ['windows-latest']
            and len(steps) == len(job['steps'])
            and steps[capture]['status'] == steps[retain]['status'] == 'completed'
            and steps[capture]['conclusion'] in ('success', 'failure')
            and steps[retain]['conclusion'] == 'success')
        # Both jobs must retain the original capture outcome.
        archive.need(job['conclusion'] == steps[capture]['conclusion'])

    PHASE = 'startup_artifacts'
    listing = client.json('/actions/runs/' + text + '/artifacts?per_page=20')
    expected = [prefix + head + '-' + text + '-1'
                for prefix in (startup.quiz_catalog.ARTIFACT_PREFIX, ENTRY_ARTIFACT_PREFIX)]
    entries = {item['name']: item for item in listing['artifacts']}
    archive.need(listing['total_count'] == len(listing['artifacts']) == len(entries) == 2
        and set(entries) == set(expected)
        and entries[expected[0]]['id'] != entries[expected[1]]['id'])
    quiz = startup.inspect_launch_run(
        client, head=head, tree=tree, run_id=run_id, job=quiz_job,
        quiz=True, item=entries[expected[0]])
    emit('Hosted original seed quiz catalog inspection', quiz)
    verify_entry_sources(client, head)
    inspect_entry(client, text, head, tree, run_id, entry_job, item=entries[expected[1]])


def main():
    global PHASE
    PHASE = 'environment'
    try:
        parent = os.environ
        archive.need(parent.get('GITHUB_ACTIONS') == 'true'
            and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
            and parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
            and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius')
        text, head = parent.get('WINDOWS_INSPECT_RUN', ''), parent.get('WINDOWS_INSPECT_HEAD', '')
        archive.need(re.fullmatch('[1-9][0-9]{0,19}', text) is not None
                     and re.fullmatch('[a-f0-9]{40}', head) is not None)
        run_id, client = int(text), archive.Client(parent.get('GH_TOKEN'))
        PHASE = 'source_metadata'
        run = client.json('/actions/runs/' + text)
        archive.need(run['id'] == run_id and run['head_sha'] == head and run['run_attempt'] == 1
            and run['workflow_id'] == 381413107 and run['event'] == 'workflow_dispatch'
            and run['status'] == 'completed' and run['repository']['full_name'] == 'edgepillar/syrius')
        commit = client.json('/git/commits/' + head)
        tree = commit['tree']['sha']
        archive.need(commit['sha'] == head and re.fullmatch('[a-f0-9]{40}', tree) is not None)
        PHASE = 'job_metadata'
        listing = client.json('/actions/runs/' + text + '/attempts/1/jobs?per_page=20')
        archive.need(listing['total_count'] == len(listing['jobs']) <= 20)
        startup_jobs = [job for job in listing['jobs']
                        if job['name'] in (startup.JOB_NAME, startup.BATCH_JOB_NAME)]
        archive.need(len(startup_jobs) <= 1)
        if startup_jobs and startup_jobs[0]['conclusion'] != 'skipped':
            job = startup_jobs[0]
            siblings = [candidate for candidate in listing['jobs']
                        if candidate is not job and candidate['conclusion'] != 'skipped']
            if (job['name'] == startup.JOB_NAME and len(siblings) == 1
                    and siblings[0]['name'] == ENTRY_JOB_NAME
                    and any(step['name'] == startup.quiz_catalog.JOB_STEP
                            and step['conclusion'] != 'skipped' for step in job['steps'])):
                entry_job = siblings[0]
                archive.need(job['id'] != entry_job['id'])
                require_startup_job_set([candidate for candidate in listing['jobs']
                                         if candidate is not entry_job], job, head, run_id)
                client = archive.Client(parent.get('GH_TOKEN'), max_calls=QUIZ_ENTRY_REQUESTS)
                inspect_quiz_entry_bundle(client, text, head, tree, run_id, job, entry_job)
                return 0
            readers = require_startup_job_set(listing['jobs'], job, head, run_id)
            PHASE = 'startup_artifacts'
            reference_head = parent.get('WINDOWS_REFERENCE_HEAD')
            archive.need(reference_head is None or
                         re.fullmatch('[a-f0-9]{40}', reference_head) is not None)
            if job['name'] == startup.BATCH_JOB_NAME:
                archive.need(run['head_branch'] == 'redesign')
                batch_client = archive.Client(parent.get('GH_TOKEN'), max_calls=startup.BATCH_REQUESTS)
                batch, results = startup.inspect_catalog_batch(
                    batch_client, head=head, tree=tree, run_id=run_id, job=job,
                    compare_png=startup_pixel_comparison if reference_head else None)
                if readers:
                    batch['parallel_windows_reader'] = {
                        key: readers[0][key] for key in ('id', 'conclusion')}
                for summary in results:
                    emit_startup_comparison('Hosted original startup catalog inspection',
                                            summary, reference_head)
                emit('Hosted shared Windows startup catalog inspection', batch)
                return 0
            launch_titles = {
                startup.launch.JOB_STEP: 'Hosted original cold launch inspection',
                startup.launch.SETTLE_JOB_STEP: 'Hosted original launch handoff inspection',
                startup.launch.MOTION_JOB_STEP: 'Hosted original launch motion inspection',
                startup.launch.TIMING_JOB_STEP: 'Hosted original cold lock timing inspection',
                paired_timing.pair.JOB_STEP: paired_timing.TITLE,
                startup.lock_catalog.JOB_STEP: 'Hosted original lock catalog inspection',
                startup.lock_catalog.SEAM_STEP: 'Hosted original lock seam inspection',
                startup.quiz_catalog.JOB_STEP: 'Hosted original seed quiz catalog inspection',
            }
            launch_steps = [step for step in job.get('steps', [])
                            if step['name'] in launch_titles
                            and step['conclusion'] != 'skipped']
            if launch_steps:
                combined = [step['name'] for step in launch_steps] == [
                    paired_timing.pair.JOB_STEP, startup.launch.SETTLE_JOB_STEP]
                archive.need((len(launch_steps) == 1 or combined)
                             and all(step['status'] == 'completed' for step in launch_steps))
                name = launch_steps[0]['name']
                if name == paired_timing.pair.JOB_STEP:
                    timing_item = None
                    if combined:
                        outcomes = [step['conclusion'] for step in launch_steps]
                        expected_job = 'success' if outcomes == ['success', 'success'] else 'failure'
                        archive.need(run['head_branch'] == 'redesign'
                                     and all(outcome in ('success', 'failure') for outcome in outcomes)
                                     and job['conclusion'] == expected_job)
                        client = archive.Client(parent.get('GH_TOKEN'), max_calls=startup.BATCH_REQUESTS)
                        listing = client.json('/actions/runs/' + text + '/artifacts?per_page=20')
                        suffix = head + '-' + text + '-1'
                        timing_name = paired_timing.pair.ARTIFACT_PREFIX + suffix
                        settle_name = 'windows-launch-settle-catalog-' + suffix
                        items = {item['name']: item for item in listing['artifacts']}
                        archive.need(listing['total_count'] == len(listing['artifacts']) == len(items) == 2
                            and set(items) == {timing_name, settle_name}
                            and items[timing_name]['id'] != items[settle_name]['id'])
                        timing_item = items[timing_name]
                    shared_binaries = {} if combined else None
                    summary = paired_timing.inspect_run(
                        client, head=head, tree=tree, run_id=run_id, job=job,
                        item=timing_item, current_binaries=shared_binaries)
                    if combined and launch_steps[0]['conclusion'] == 'failure':
                        archive.need(summary.get('closed_after_p06_deadline') is True)
                    gap_context = summary.pop('frame_gap_context', None)
                    common_interval = summary.pop('common_startup_interval', None)
                else:
                    gap_context = None
                    common_interval = None
                    motion = name == startup.launch.MOTION_JOB_STEP
                    if motion:
                        archive.need(run['head_branch'] == 'redesign')
                        if any(step['name'] == startup.launch.MOTION_LIGHT_JOB_STEP
                               for step in job['steps']):
                            batch_client = archive.Client(parent.get('GH_TOKEN'),
                                                          max_calls=startup.BATCH_REQUESTS)
                            batch, results = startup.inspect_motion_batch(
                                batch_client, head=head, tree=tree, run_id=run_id, job=job)
                            for result in results:
                                emit(launch_titles[name], result)
                            emit('Hosted shared Windows launch motion inspection', batch)
                            return 0
                    summary = startup.inspect_launch_run(
                        client, head=head, tree=tree, run_id=run_id, job=job,
                        settle=name == startup.launch.SETTLE_JOB_STEP,
                        lock=name == startup.lock_catalog.JOB_STEP,
                        quiz=name == startup.quiz_catalog.JOB_STEP,
                        timing=name == startup.launch.TIMING_JOB_STEP,
                        lock_seams=name == startup.lock_catalog.SEAM_STEP,
                        compare_png=(startup_pixel_comparison if reference_head and
                                     name == startup.launch.SETTLE_JOB_STEP else None),
                        **({'motion': True} if motion else {}))
                emit_startup_comparison(launch_titles[name], summary, reference_head)
                if gap_context is not None:
                    emit('Hosted cold lock frame key gaps', dict(
                        scope='reported_frames_only', source_head=head, source_tree=tree,
                        source_run_id=run_id, source_attempt=summary['source_attempt'],
                        archive_sha256=summary['archive_sha256'],
                        manifest_sha256=summary['manifest_sha256'], windows=gap_context))
                if common_interval is not None:
                    emit('Hosted cold lock common elapsed interval', dict(
                        scope='reported_build_starts_only', source_head=head, source_tree=tree,
                        source_run_id=run_id, source_attempt=summary['source_attempt'],
                        archive_sha256=summary['archive_sha256'],
                        manifest_sha256=summary['manifest_sha256'], **common_interval))
                if combined:
                    handoff = startup.inspect_launch_run(client, head=head, tree=tree,
                        run_id=run_id, job=job, settle=True, item=items[settle_name],
                        shared_binaries=shared_binaries,
                        compare_png=startup_pixel_comparison if reference_head else None)
                    emit_startup_comparison(launch_titles[startup.launch.SETTLE_JOB_STEP],
                                            handoff, reference_head)
                return 0
            for summary in startup.inspect_run(
                    client, head=head, tree=tree, run_id=run_id, job=job):
                title = ('Hosted natural startup inspection'
                         if summary['scope'] == 'retained_natural_release_startup_observation'
                         else 'Hosted original startup inspection')
                emit(title, summary)
            return 0
        # The startup reader checks its own four producers. Checking the
        # unselected baseline sources first exhausts the twelve-request bound
        # before either original startup archive can be read.
        verify_entry_sources(client, head)
        PHASE = 'job_metadata'
        jobs = {}
        for name in ('Hosted Windows baseline', ENTRY_JOB_NAME):
            selected = [job for job in listing['jobs']
                        if job['name'] == name or (
                            name == 'Hosted Windows baseline'
                            and job['name'] == SKIPPED_BASELINE_JOB
                            and job['conclusion'] == 'skipped')]
            outcomes = ('success', 'failure', 'skipped')
            archive.need(len(selected) == 1 and selected[0]['head_sha'] == head
                and selected[0]['run_id'] == run_id and selected[0]['status'] == 'completed'
                and selected[0]['conclusion'] in outcomes)
            if selected[0]['conclusion'] == 'skipped':
                archive.need(selected[0].get('steps') == [])
            jobs[name] = selected[0]
        archive.need(any(job['conclusion'] != 'skipped' for job in jobs.values()))
        job = jobs['Hosted Windows baseline']
        if job['conclusion'] == 'skipped':
            emit('Hosted baseline not selected', dict(scope='retained_windows_baseline_not_selected',
                inspection_only=True, runtime_started=False, wallet_qualified=False,
                source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
                original_job_id=job['id'], original_job_conclusion='skipped',
                baseline_qualified=False, baseline_logs_read=0))
        else:
            PHASE = 'baseline_log_location'
            location = client.read(archive.API + '/actions/jobs/' + str(job['id']) + '/logs', redirect=True)
            PHASE = 'baseline_log_download'
            raw = client.read(location, authenticated=False, cap=MAX_LOG)
            PHASE = 'baseline_log_frame'
            report = log_report(raw, 'github_hosted_windows_baseline')
            PHASE = 'baseline_projection'
            summary = baseline_projection(report, head, tree, run_id)
            PHASE = 'baseline_log'
            archive.need(job['conclusion'] != 'success' or summary['artifact_reported_success'])
            summary.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'],
                           log_sha256=archive.sha(raw), log_bytes=len(raw), producer_sources_equal=True)
            PHASE = 'baseline_notice'
            emit('Hosted baseline inspection', summary)
        entry_job = jobs[ENTRY_JOB_NAME]
        if entry_job['conclusion'] == 'skipped':
            emit('Hosted entry not selected', dict(scope='retained_windows_entry_not_selected',
                inspection_only=True, runtime_started=False, wallet_qualified=False,
                source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
                original_job_id=entry_job['id'], original_job_conclusion='skipped',
                entry_qualified=False, entry_artifacts_read=0))
            return 0
        inspect_entry(client, text, head, tree, run_id, entry_job)
        return 0
    except (Exception, KeyboardInterrupt):
        encoded = json.dumps(dict(scope='retained_windows_qualification_observation',
            inspection_success=False, code='INSPECTION_REFUSED', phase=PHASE,
            runtime_started=False, wallet_qualified=False), sort_keys=True)
        print(encoded)
        print('::notice title=Hosted Windows inspection refusal::' + encoded)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
