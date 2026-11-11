"""Verify paired interactive Windows frame records and their original lab."""

import io
import json
from pathlib import Path
import stat
import zipfile

from . import inspect_chain321 as archive
from . import inspect_launch_timing_pair as cold
from . import windows_interactive_frame_pair as pair


JOB_NAME = 'Windows paired interactive timing with owned chain-321'
ARTIFACT_PREFIX = 'interactive-timing-pair-'
TITLE = 'Retained paired interactive frame measurements'
OBSERVATION_PHASES = frozenset(('lab_before', 'empty_profile', 'prepare_profile',
    'wallet_ready', 'measure', 'verify_after', 'complete'))
PHASES = frozenset((*cold.COMMAND_STAGES, 'environment', 'storage_admission',
    'current_interactive', 'baseline_admission', 'bind_p06_entry',
    'p06_interactive', 'source_recheck', 'complete'))
EXIT_FIELDS = {*cold.EXIT_FLAGS, 'exit_code', 'error_codes'}
READOUT_FIELDS = {*EXIT_FIELDS, 'output_bytes', 'seconds', 'success'}


def sample_receipts(value):
    if value == {}:
        return {}, False, False, False
    archive.need(type(value) is dict
        and set(value) == {'attempt', 'observation', 'profile_stable', 'success'}
        and type(value['success']) is type(value['profile_stable']) is bool)
    attempt = value['attempt']
    closed = completed = False
    if attempt is not None:
        archive.need(type(attempt) is dict
            and set(attempt) == {*EXIT_FIELDS, 'theme', 'role', 'action_complete', 'checks'}
            and attempt['theme'] == pair.shared.launch.TIMING_THEME and attempt['role'] == 'interactive'
            and type(attempt['action_complete']) is bool and type(attempt['checks']) is dict
            and set(attempt['checks']) == set(pair.shared.launch.ATTEMPT_CHECKS)
            and all(type(check) is bool for check in attempt['checks'].values()))
        cold.codes(attempt['error_codes'], pair.shared.launch.startup.CODES, 16)
        closed = cold.normal_exit(attempt) and all(attempt['checks'].values())
        completed = closed and attempt['action_complete'] and not attempt['error_codes']
    observation = value['observation']
    windows, entry_closed = {}, False
    observed = False
    if observation != {}:
        required = {'phase', 'lab_revalidations', 'entry', 'windows', 'success'}
        archive.need(type(observation) is dict
            and required <= set(observation) <= required | {'action_progress'}
            and type(observation['phase']) is str and observation['phase'] in OBSERVATION_PHASES
            and type(observation['success']) is bool
            and pair.shared.launch.startup.integer(observation['lab_revalidations'], 0, 3))
        progress = observation.get('action_progress')
        if 'action_progress' in observation:
            archive.need(type(progress) is dict and set(progress) == {'index', 'command', 'returned'}
                and pair.shared.launch.startup.integer(progress['index'], 0, pair.profile.MAX_MEASUREMENT_COMMANDS)
                and type(progress['returned']) is bool
                and observation['phase'] in ('measure', 'verify_after', 'complete'))
            archive.need((progress['index'] == 0 and progress['command'] is None and not progress['returned'])
                or (progress['index'] > 0 and type(progress['command']) is str
                    and progress['command'] in pair.profile.MEASUREMENT_COMMANDS))
        entry = observation['entry']
        if entry is not None:
            archive.need(type(entry) is dict and set(entry) == READOUT_FIELDS
                and pair.shared.launch.startup.integer(entry['output_bytes'], 0, 64 * 1024**2)
                and type(entry['seconds']) in (int, float) and 0 <= entry['seconds'] <= 220)
            cold.codes(entry['error_codes'], pair.shared.baseline.CODES, 16)
            entry_closed = cold.normal_exit(entry) and not entry['error_codes']
            archive.need(entry['success'] is entry_closed)
        offered = observation['windows']
        archive.need(type(offered) is dict and set(offered) <= set(pair.WINDOWS)
            and ('disclosure' not in offered or 'page_change' in offered))
        try:
            windows = {name: pair.shared.launch.frame_timing_window(window)
                       for name, window in offered.items()}
        except pair.shared.launch.startup.Failure:
            raise archive.Refused('INSPECTION_REFUSED') from None
        archive.need(not windows or entry_closed and observation['lab_revalidations'] >= 2)
        archive.need(all(pair.actions.MIN_WINDOW_US <= window['windowUs']
                         <= pair.actions.MAX_WINDOW_US for window in windows.values()))
        observed = (observation['phase'] == 'complete' and observation['lab_revalidations'] == 3
                    and entry_closed and set(windows) == set(pair.WINDOWS))
        archive.need(observation['success'] is observed)
        archive.need(progress is None or not observed or progress['index'] > 0 and progress['returned'])
    success = completed and observed and value['profile_stable']
    archive.need(value['success'] is success)
    return windows, closed, entry_closed, success


def project(raw, item, *, head, tree, run_id, lab, expected_entry):
    expected_sha, size = item['digest'][7:], item['size_in_bytes']
    archive.need(type(raw) is bytes and type(size) is int
        and 0 < len(raw) == size <= pair.MAX_ARCHIVE and archive.sha(raw) == expected_sha)
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
    manifest_sha = archive.sha(manifest)
    report = json.loads(manifest.decode('ascii'), object_pairs_hook=cold.unique)
    required = {'schema', 'scope', 'mode', 'theme', 'client', 'phase', 'success',
        'p06', 'commands', 'samples', 'comparisons', 'same_fixture_address', 'error_codes',
        'source_sha', 'source_tree', 'run_id', 'run_attempt', 'baseline_patch_sha256',
        'collector_sha256', 'entry_sha256', 'lab_anchor', 'storage', 'current'}
    optional = {'sdk_revision', 'equal_input_objects'}
    reference = lab['interactive_frame_pair']
    archive.need(type(report) is dict and required <= set(report) <= required | optional
        and type(report['schema']) is int and report['schema'] == 1 and report['scope'] == pair.SCOPE
        and report['mode'] == 'release' and report['theme'] == pair.shared.launch.TIMING_THEME
        and cold.canonical(report['client']) == cold.canonical(list(pair.shared.launch.TIMING_SIZE))
        and type(report['phase']) is str and report['phase'] in PHASES
        and type(report['success']) is type(report['same_fixture_address']) is bool
        and report['source_sha'] == head and report['source_tree'] == tree
        and report['run_id'] == str(run_id) and report['run_attempt'] == '1'
        and report['baseline_patch_sha256'] == pair.shared.PATCH_SHA256
        and report['collector_sha256'] == pair.shared.COLLECTOR_SHA256
        and report['entry_sha256'] == expected_entry
        and reference == dict(success=report['success'], phase=report['phase'], manifest_sha256=manifest_sha))
    origin = lab['observations']
    archive.need(cold.canonical(report['lab_anchor']) == cold.canonical(dict(
        chain=321, genesis_hash=origin['genesis_hash'], first_height=origin['last_height'])))
    cold.codes(report['error_codes'], pair.shared.launch.startup.CODES | {
        'SPACE_REFUSED', 'TOOL_REFUSED', 'LAB_REFUSED', 'WALLET_REFUSED', 'FRAME_REFUSED',
        'PROFILE_PREPARATION_REFUSED', 'OWNER_REFUSED'}, 2)
    current, p06 = report['current'], report['p06']
    archive.need(type(current) is dict and set(current) == cold.BINARY_HASHES
        and all(cold.digest(value) for value in current.values())
        and type(p06) is dict and type(p06.get('overlay_verified')) is bool
        and all(p06.get(key) == value for key, value in cold.P06_IDENTITY.items()))
    verified = p06['overlay_verified']
    archive.need(set(p06) == (cold.P06_IDENTITY.keys() | {'overlay_verified'}
        | (cold.BINARY_HASHES if verified else set())))
    commands = cold.command_receipts(report['commands'])
    storage = cold.storage_passed(report['storage'])
    sdk, inputs = report.get('sdk_revision'), report.get('equal_input_objects')
    archive.need(('sdk_revision' not in report or sdk == pair.shared.prepare.SDK)
        and ('equal_input_objects' not in report or inputs == cold.P06_INPUTS)
        and (not verified or commands and sdk == pair.shared.prepare.SDK
             and inputs == cold.P06_INPUTS and all(cold.digest(p06[key]) for key in cold.BINARY_HASHES)))
    samples = report['samples']
    archive.need(type(samples) is dict and set(samples) <= {'current', 'p06'})
    windows, current_closed, current_entry, current_passed = sample_receipts(samples.get('current', {}))
    old, p06_closed, p06_entry, p06_passed = sample_receipts(samples.get('p06', {}))
    archive.need((not report['commands'] or current_passed)
        and ('p06' not in samples or current_passed and verified)
        and (not p06_passed or report['same_fixture_address'])
        and (not report['same_fixture_address'] or 'p06' in samples))
    comparisons = report['comparisons']
    if comparisons is not None:
        archive.need(current_passed and p06_passed and report['same_fixture_address']
            and cold.canonical(comparisons) == cold.canonical({
                name: pair.shared.compare_windows(old[name], windows[name]) for name in pair.WINDOWS}))
    complete = (verified and storage and comparisons is not None
        and report['storage']['samples'] == 2 * len(cold.COMMAND_STAGES) + 5
        and report['phase'] == 'complete' and not report['error_codes'])
    archive.need(report['success'] is complete and (complete or report['error_codes']))
    timing_criterion_passed = bool(complete and all(
        value['no_added_reported_slow_frames'] and value['no_frame_number_gaps']
        for value in comparisons.values()))
    return dict(schema=1, scope='retained_' + pair.SCOPE,
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        archive_sha256=expected_sha, manifest_sha256=manifest_sha,
        artifact_reported_success=complete, timing_criterion_passed=timing_criterion_passed,
        original_phase=report['phase'],
        error_codes=report['error_codes'], runtime_started=False, verified_png_count=0,
        same_fixture_address=report['same_fixture_address'],
        action_progress={label: sample['observation'].get('action_progress')
                         for label, sample in samples.items() if sample.get('observation')},
        normal_wallet_exits=current_closed + p06_closed,
        normal_entry_exits=current_entry + p06_entry,
        entry_process_seconds={label: sample['observation']['entry']['seconds']
            for label, sample in samples.items() if sample.get('observation')
            and sample['observation']['entry'] is not None},
        frame_window_us={label:{name:value['windowUs'] for name,value in window.items()}
                         for label,window in (('current',windows), ('p06',old))},
        frame_counts={label:{name:len(value['frames']) for name,value in window.items()}
                      for label,window in (('current',windows), ('p06',old))},
        no_added_reported_slow_frames=None if comparisons is None else {
            name: value['no_added_reported_slow_frames'] for name,value in comparisons.items()},
        no_frame_number_gaps=None if comparisons is None else {
            name: value['no_frame_number_gaps'] for name,value in comparisons.items()})


def inspect_run(client, *, head, run_id, lab, lab_summary, listing, run):
    archive.need(lab['backend'] == 'native' and lab['application_sha'] == head
        and lab['run_id'] == str(run_id) and lab['attempt'] == '1')
    jobs = client.json('/actions/runs/' + str(run_id) + '/attempts/1/jobs?per_page=20')
    archive.need(jobs['total_count'] == len(jobs['jobs']) <= 20)
    selected = [job for job in jobs['jobs'] if job['name'] == JOB_NAME]
    archive.need(len(selected) == 1)
    job = selected[0]
    archive.need(job['head_sha'] == head and job['run_id'] == run_id
        and job['status'] == 'completed' and job['conclusion'] in ('success', 'failure')
        and job['labels'] == ['windows-latest']
        and all(other['head_sha'] == head and other['run_id'] == run_id
            and other['status'] == 'completed' and other['conclusion'] == 'skipped'
            for other in jobs['jobs'] if other is not job))
    items = [item for item in listing['artifacts'] if item['name'].startswith(ARTIFACT_PREFIX)]
    reference = lab['interactive_frame_pair']
    if reference is None or reference.get('manifest_sha256') is None:
        archive.need(not items and lab['success'] is False
            and (reference is None or reference.get('success') is False))
        return dict(schema=1, scope='retained_' + pair.SCOPE, source_head=head,
            source_run_id=run_id, original_job_id=job['id'],
            original_job_conclusion=job['conclusion'], retained_pair=False,
            native_measurement_qualified=False, paired_timing_gate_passed=False,
            runtime_started=False)

    archive.need(type(reference) is dict and set(reference) == {'success', 'phase', 'manifest_sha256'}
        and type(reference['success']) is bool and cold.digest(reference['manifest_sha256'])
        and listing['total_count'] == 2 and len(items) == 1)
    item = items[0]
    archive.need(item['name'] == ARTIFACT_PREFIX + head + '-' + str(run_id) + '-1'
        and item['expired'] is False and item['workflow_run']['id'] == run_id
        and item['workflow_run']['head_sha'] == head
        and pair.shared.launch.startup.integer(item['id'], 1, 2**63 - 1)
        and type(item.get('digest')) is str and item['digest'].startswith('sha256:')
        and cold.digest(item['digest'][7:])
        and pair.shared.launch.startup.integer(item['size_in_bytes'], 1, pair.MAX_ARCHIVE))
    commit = client.json('/git/commits/' + head)
    tree = commit['tree']['sha']
    archive.need(commit['sha'] == head and tree == lab['application_tree'])
    archive.need(cold.source(client, 'tool/ci/windows_interactive_frame_pair.py', head)
        == Path(pair.__file__).read_bytes())
    entry = archive.sha(cold.source(client, pair.profile.ENTRY.as_posix(), head))
    archive.need(entry == pair.profile.ENTRY_SHA256)
    old = client.json('/git/commits/' + pair.shared.P06_SOURCE)
    archive.need(old['sha'] == pair.shared.P06_SOURCE and old['tree']['sha'] == pair.shared.P06_TREE)
    location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
    raw = client.read(location, authenticated=False, cap=pair.MAX_ARCHIVE)
    result = project(raw, item, head=head, tree=tree, run_id=run_id, lab=lab, expected_entry=entry)
    node_exits = lab_summary['node_exits']
    normal_nodes = sum(node['exit_code'] == 0 and node['output_complete'] is True
                       and node['forced'] is False for node in node_exits)
    measured = bool(result['artifact_reported_success'] and lab['success']
        and normal_nodes == len(archive.ROLES) and run['conclusion'] == job['conclusion'] == 'success')
    result.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'],
        retained_pair=True, normal_node_exits=normal_nodes, native_measurement_qualified=measured,
        paired_timing_gate_passed=measured and result['timing_criterion_passed'])
    return result
