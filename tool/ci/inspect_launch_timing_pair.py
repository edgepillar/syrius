"""Verify retained paired cold lock measurements without running Windows."""

import base64
import io
import json
from pathlib import Path
import re
import stat
import zipfile

from . import inspect_chain321 as archive
from . import inspect_startup_qualification as startup_reader
from . import windows_launch_timing_pair as pair


TITLE = 'Hosted paired cold lock timing inspection'
COMMAND_STAGES = (
    'sdk_revision', 'fetch_p06', 'checkout_p06', 'p06_identity',
    'p06_inputs', 'current_inputs', 'patch_p06_agent', 'stage_p06_collector',
    'overlay_tree_before_build', 'overlay_clean_before_build',
    'restore_p06_locked_packages', 'generate_p06_metadata', 'enable_p06_windows', 'build_p06_release',
    'overlay_tree_after_build', 'overlay_clean_after_build', 'sdk_revision_after',
)
SAMPLE_ROLES = (
    ('current', ('prepare', 'timing')),
    ('p06', ('prepare', 'prepare', 'timing')),
)
PHASES = frozenset((*COMMAND_STAGES, 'baseline_admission', 'environment',
    'p06_prepare_profile', 'p06_warm_ordinary_profile', 'p06_measure',
    'current_prepare_profile', 'current_measure', 'source_recheck', 'complete'))
P06_INPUTS = {
    'pubspec.yaml': '5f1e5bc20cd9472163efe922fee49d74a5ca9037',
    'pubspec.lock': '56f10c449aa1b4484d45a0169d2ac76ad8a9bdaf',
    'patched_packages/reown_core-1.3.8': '93dec79ff3650e61a0eee55bcc7ef446df14dbdc',
    'tool/generate_git_metadata.dart': 'ef2aa0a03cf1955db16bdafd78a4c691eb05fd48',
    'windows': '007fa2a8f13d099a590c9f8424e6e759e75bbb74',
    'lib/utils/wallet_file.dart': 'f28dbe0224a3b4cc92a1a51a39066bd6051a91c2',
    'lib/utils/constants.dart': '6560e4694227bbb5d5fcd8f321fc7618225a7b3f',
}
P06_IDENTITY = dict(original_sha=pair.P06_ORIGINAL, published_sha=pair.P06_SOURCE,
                    tree=pair.P06_TREE, overlay_tree=pair.P06_OVERLAY_TREE)
BINARY_HASHES = frozenset(('runner_sha256', 'payload_sha256'))
EXIT_FLAGS = ('exit_observed', 'forced_kill', 'output_complete', 'output_overflow')
PIN_FIELDS = frozenset(('baseline_patch_sha256', 'collector_sha256', 'profile_sha256'))


def digest(value):
    return type(value) is str and re.fullmatch('[a-f0-9]{64}', value) is not None


def codes(value, allowed, cap):
    archive.need(type(value) is list and len(value) <= cap
                 and all(type(code) is str and code in allowed for code in value))


def unique(items):
    result = dict(items)
    archive.need(len(result) == len(items))
    return result


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('ascii')


def normal_exit(receipt):
    archive.need(all(type(receipt[key]) is bool for key in EXIT_FLAGS))
    code = receipt['exit_code']
    archive.need(code is None or pair.launch.startup.integer(code, -(2**31), 2**32 - 1))
    return (code == 0 and receipt['exit_observed'] and receipt['output_complete']
            and not receipt['forced_kill'] and not receipt['output_overflow'])


def command_receipts(rows):
    fields = {*EXIT_FLAGS, 'stage', 'exit_code', 'output_bytes', 'seconds',
              'success', 'error_codes', 'output_sha256'}
    archive.need(type(rows) is list and len(rows) <= len(COMMAND_STAGES))
    for row, stage in zip(rows, COMMAND_STAGES):
        archive.need(type(row) is dict and set(row) == fields and row['stage'] == stage
            and digest(row['output_sha256'])
            and pair.launch.startup.integer(row['output_bytes'], 0, 64 * 1024**2)
            and type(row['seconds']) in (int, float) and 0 <= row['seconds'] <= 600)
        codes(row['error_codes'], pair.baseline.CODES, 16)
        archive.need(row['success'] is (normal_exit(row) and not row['error_codes']))
    archive.need(all(row['success'] for row in rows[:-1]))
    return len(rows) == len(COMMAND_STAGES) and rows[-1]['success']


def samples(rows):
    archive.need(type(rows) is list and len(rows) <= len(SAMPLE_ROLES))
    windows, closed = {}, 0
    fields = {*EXIT_FLAGS, 'theme', 'role', 'exit_code',
              'checks', 'action_complete', 'error_codes'}
    for row, (name, roles) in zip(rows, SAMPLE_ROLES):
        archive.need(type(row) is dict and set(row) == {'name', 'attempts', 'frame_window'}
            and row['name'] == name and type(row['attempts']) is list
            and len(row['attempts']) <= len(roles))
        for attempt, role in zip(row['attempts'], roles):
            archive.need(type(attempt) is dict and set(attempt) in (fields, fields | {'lock_diagnostic'})
                and attempt['theme'] == pair.launch.TIMING_THEME and attempt['role'] == role
                and type(attempt['action_complete']) is bool and type(attempt['checks']) is dict
                and set(attempt['checks']) == set(pair.launch.ATTEMPT_CHECKS)
                and all(type(value) is bool for value in attempt['checks'].values()))
            codes(attempt['error_codes'], pair.launch.startup.CODES, 16)
            if 'lock_diagnostic' in attempt:
                diagnostic = attempt['lock_diagnostic']
                archive.need(pair.launch.valid_lock_diagnostic(diagnostic))
                original_code = ('COMMAND_FAILED' if diagnostic['status'] == 'command_refused'
                                 else 'STARTUP_DEADLINE')
                archive.need(role == 'timing' and not attempt['action_complete']
                    and original_code in attempt['error_codes'])
            closed += normal_exit(attempt) and all(attempt['checks'].values())
        archive.need(all(pair.launch.attempt_passed(attempt) for attempt in row['attempts'][:-1]))
        if row['frame_window'] is not None:
            archive.need(len(row['attempts']) == len(roles)
                and all(pair.launch.attempt_passed(attempt) for attempt in row['attempts']))
            windows[name] = pair.launch.frame_timing_window(row['frame_window'], allow_packed=True)
    archive.need(len(rows) < 2 or 'current' in windows)
    return windows, closed


def storage_passed(value):
    bounds = ('initial_free_bytes', 'minimum_free_bytes', 'sampled_additional_bytes',
              'floor_bytes', 'reservation_bytes')
    archive.need(type(value) is dict and set(value) == {*bounds, 'samples'}
        and value['floor_bytes'] == pair.FLOOR and value['reservation_bytes'] == pair.RESERVATION
        and all(pair.launch.startup.integer(value[name], 0, 2**63 - 1) for name in bounds)
        and pair.launch.startup.integer(value['samples'], 1, 64)
        and value['sampled_additional_bytes'] == value['initial_free_bytes'] - value['minimum_free_bytes'])
    return (value['initial_free_bytes'] >= pair.FLOOR + pair.RESERVATION
        and value['minimum_free_bytes'] >= pair.FLOOR
        and value['sampled_additional_bytes'] <= pair.RESERVATION)


def project(raw, expected_sha, expected_size, *, head, tree, run_id, pins):
    archive.need(type(raw) is bytes and type(expected_size) is int
        and 0 < len(raw) == expected_size <= pair.MAX_ARCHIVE and archive.sha(raw) == expected_sha)
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        archive.need(len(members) == 1)
        member = members[0]
        archive.need(member.orig_filename == member.filename == 'manifest.json' and not member.is_dir()
            and not member.flag_bits & 1 and 0 < member.file_size <= pair.MAX_MANIFEST
            and member.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
            and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG))
        manifest = zipped.read(member)
        archive.need(len(manifest) == member.file_size)
    report = json.loads(manifest.decode('ascii'), object_pairs_hook=unique)
    required = {'schema', 'scope', 'mode', 'theme', 'client', 'phase', 'success', 'p06',
        'commands', 'samples', 'comparison', 'error_codes', 'source_sha', 'source_tree',
        'run_id', 'run_attempt', 'current', *PIN_FIELDS}
    optional = {'storage', 'sdk_revision', 'equal_input_objects'}
    archive.need(type(report) is dict and required <= set(report) <= required | optional
        and type(report['schema']) is int and report['schema'] == 1 and report['scope'] == pair.SCOPE
        and report['mode'] == 'release' and report['theme'] == pair.launch.TIMING_THEME
        and canonical(report['client']) == canonical(list(pair.launch.TIMING_SIZE))
        and type(report['phase']) is str and report['phase'] in PHASES
        and type(report['success']) is bool
        and report['source_sha'] == head and report['source_tree'] == tree
        and report['run_id'] == str(run_id) and report['run_attempt'] == '1'
        and set(pins) == PIN_FIELDS and all(digest(pins[key]) and report[key] == pins[key] for key in pins))
    codes(report['error_codes'], pair.launch.startup.CODES | {'SPACE_REFUSED', 'TOOL_REFUSED'}, 2)
    p06, current = report['p06'], report['current']
    archive.need(type(current) is dict and set(current) == BINARY_HASHES
        and all(digest(value) for value in current.values())
        and type(p06) is dict and type(p06.get('overlay_verified')) is bool
        and all(p06.get(key) == value for key, value in P06_IDENTITY.items()))
    verified = p06['overlay_verified']
    archive.need(set(p06) == (P06_IDENTITY.keys() | {'overlay_verified'}
        | (BINARY_HASHES if verified else set())))
    commands = command_receipts(report['commands'])
    space = 'storage' in report and storage_passed(report['storage'])
    sdk = report.get('sdk_revision')
    equal = report.get('equal_input_objects')
    archive.need(('sdk_revision' not in report or sdk == pair.prepare.SDK)
        and ('equal_input_objects' not in report or equal == P06_INPUTS)
        and (not verified or commands and sdk == pair.prepare.SDK and equal == P06_INPUTS
             and all(digest(p06[key]) for key in BINARY_HASHES)))
    comparison = report['comparison']
    try:
        windows, closed = samples(report['samples'])
        archive.need((verified or len(report['samples']) <= 1)
            and (not report['commands'] or 'current' in windows))
        if comparison is not None:
            archive.need(set(windows) == {'p06', 'current'}
                and canonical(comparison) == canonical(pair.compare_windows(windows['p06'], windows['current'])))
    except pair.launch.startup.Failure:
        raise archive.Refused('INSPECTION_REFUSED') from None
    complete = (verified and space and closed == 5 and comparison is not None
                and report['storage']['samples'] == 2 * len(COMMAND_STAGES) + 4
                and report['phase'] == 'complete' and not report['error_codes'])
    archive.need(report['success'] is complete and (complete or report['error_codes']))
    return dict(schema=1, scope='retained_' + pair.SCOPE, source_head=head, source_tree=tree,
        source_run_id=run_id, source_attempt=1, archive_sha256=expected_sha,
        manifest_sha256=archive.sha(manifest), artifact_reported_success=complete,
        original_phase=report['phase'], error_codes=report['error_codes'],
        p06_source=pair.P06_SOURCE, p06_overlay_tree=pair.P06_OVERLAY_TREE,
        normal_actor_exits=closed, runtime_started=False, verified_png_count=0,
        attempt_outcomes=pair.attempt_outcomes(report['samples']),
        frame_counts={name: pair.launch.frame_timing_count(window) for name, window in windows.items()},
        frame_window_sha256={name: archive.sha(canonical(window)) for name, window in windows.items()},
        slow_frame_counts=None if comparison is None else {
            name: comparison[key]['slow_frame_counts']['distinct']
            for name, key in (('p06', 'baseline'), ('current', 'current'))},
        no_added_reported_slow_frames=None if comparison is None else comparison['no_added_reported_slow_frames'],
        no_frame_number_gaps=None if comparison is None else comparison['no_frame_number_gaps'])


def source(client, name, head):
    selected = client.json('/contents/' + name + '?ref=' + head)
    archive.need(selected['type'] == 'file' and selected['encoding'] == 'base64'
        and selected['path'] == name and pair.launch.startup.integer(selected['size'], 1, 64 * 1024))
    raw = base64.b64decode(selected['content'].replace('\n', ''), validate=True)
    archive.need(len(raw) == selected['size'])
    return raw


def inspect_run(client, *, head, tree, run_id, job):
    archive.need(job['name'] == startup_reader.JOB_NAME and job['head_sha'] == head
        and job['run_id'] == run_id and job['status'] == 'completed'
        and job['conclusion'] in ('success', 'failure')
        and job['labels'] == ['windows-latest'])
    selected = [step for step in job['steps'] if step['name'] == pair.JOB_STEP]
    retained = [step for step in job['steps'] if step['name'] == pair.RETAIN_STEP]
    archive.need(len(selected) == len(retained) == 1
        and selected[0]['status'] == retained[0]['status'] == 'completed'
        and selected[0]['conclusion'] in ('success', 'failure') and retained[0]['conclusion'] == 'success')
    for name, module in (('windows_launch_timing_pair.py', pair),
                         ('windows_launch_catalog.py', pair.launch)):
        archive.need(source(client, 'tool/ci/' + name, head) == Path(module.__file__).read_bytes())
    pinned = client.json('/git/commits/' + pair.P06_SOURCE)
    archive.need(pinned['sha'] == pair.P06_SOURCE and pinned['tree']['sha'] == pair.P06_TREE)
    pins = {key: archive.sha(source(client, path.as_posix(), head)) for key, path in (
        ('baseline_patch_sha256', pair.PATCH), ('collector_sha256', pair.launch.TIMING_SOURCE),
        ('profile_sha256', pair.launch.SETTLE_PROFILE_SOURCE))}
    archive.need(pins['baseline_patch_sha256'] == pair.PATCH_SHA256
        and pins['collector_sha256'] == pair.COLLECTOR_SHA256)
    listing = client.json('/actions/runs/' + str(run_id) + '/artifacts?per_page=20')
    archive.need(listing['total_count'] == len(listing['artifacts']) == 1)
    item = listing['artifacts'][0]
    archive.need(item['name'] == pair.ARTIFACT_PREFIX + head + '-' + str(run_id) + '-1'
        and item['expired'] is False and item['workflow_run']['id'] == run_id
        and item['workflow_run']['head_sha'] == head
        and pair.launch.startup.integer(item['id'], 1, 2**63 - 1)
        and type(item.get('digest')) is str and item['digest'].startswith('sha256:')
        and digest(item['digest'][7:])
        and pair.launch.startup.integer(item['size_in_bytes'], 1, pair.MAX_ARCHIVE))
    location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
    raw = client.read(location, authenticated=False, cap=pair.MAX_ARCHIVE)
    result = project(raw, item['digest'][7:], item['size_in_bytes'],
        head=head, tree=tree, run_id=run_id, pins=pins)
    archive.need(result['artifact_reported_success'] is (selected[0]['conclusion'] == 'success'))
    result.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'])
    return result
