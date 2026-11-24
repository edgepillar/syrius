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
COMPARISON_TITLE = 'Retained paired interactive frame comparisons'
DIAGNOSTICS_TITLE = 'Retained paired interactive frame diagnostics'
CURRENT_DIAGNOSTICS_TITLE = 'Retained current interactive frame diagnostics'
POINTER_DIAGNOSTICS_TITLE = 'Retained interactive pointer timing'
OBSERVATION_PHASES = frozenset(('lab_before', 'empty_profile', 'prepare_profile',
    'wallet_ready', 'measure', 'verify_after', 'complete'))
PHASES = frozenset((*cold.COMMAND_STAGES, 'environment', 'storage_admission',
    'current_interactive', 'baseline_admission', 'bind_p06_entry',
    'p06_interactive', 'source_recheck', 'complete'))
EXIT_FIELDS = {*cold.EXIT_FLAGS, 'exit_code', 'error_codes'}
READOUT_FIELDS = {*EXIT_FIELDS, 'output_bytes', 'seconds', 'success'}
# The handoff's nominal intervals, measured from the recorded tap release.
MOTION_US = {'page_change': 320_000, 'disclosure': 240_000}


def split_pointer_diagnostics(windows):
    """Keep verified pointer details in their own bounded notice."""
    pointer = {}
    for name, timing in windows.get('current', {}).items():
        if 'pointer_offsets_from_tap_us' in timing:
            pointer[name] = {
                'pointer_offsets_from_tap_us': timing.pop('pointer_offsets_from_tap_us'),
                'peak_raster_start_relation_to_pointer': timing.pop(
                    'peak_raster_start_relation_to_pointer'),
            }
    return pointer


def split_phase_diagnostics(windows):
    """Keep observed motion boundaries in their own bounded notice."""
    phases = {}
    for name, timing in windows.get('current', {}).items():
        fields = {}
        if 'observed_post_frame_offsets_from_tap_us' in timing:
            fields.update({
                key: timing.pop(key) for key in (
                    'observed_post_frame_offsets_from_tap_us',
                    'raster_start_groups_by_observed_phase',
                    'post_boundary_raster_groups_by_build_start',
                )
            })
        if 'reported_raster_coverage_us' in timing:
            fields['reported_raster_coverage_us'] = timing.pop('reported_raster_coverage_us')
        if fields:
            phases[name] = fields
    return phases


def _idle_summary(sample):
    """Verify the optional static-view interval without changing the paired gate."""
    archive.need(type(sample) is dict)
    if sample == {'status': 'unavailable'}:
        return sample
    archive.need(set(sample) == {'status', 'window'} and sample['status'] == 'measured')
    window = sample['window']
    try:
        frames = pair.shared.launch.frame_timing_rows(window)
    except pair.shared.launch.startup.Failure:
        raise archive.Refused('INSPECTION_REFUSED') from None
    archive.need(pair.actions.IDLE_WINDOW_US <= window['windowUs'] <= pair.actions.MAX_WINDOW_US
        and len(frames) <= pair.actions.MAX_IDLE_FRAMES)
    result = dict(status='measured', window_us=window['windowUs'], frames=len(frames),
        frame_number_gaps=frames[-1][0] + 1 - len(frames),
        longest_raster_us=max(frame[3] for frame in frames),
        slow_rasters=sum(frame[3] > pair.shared.FRAME_BUDGET_US for frame in frames),
        **_retained_raster_details(window))
    field = pair.shared.launch.RETAINED_PICTURES_FIELD
    if field in window:
        result['retained_pictures'] = window[field]
    field = pair.shared.launch.RETAINED_STATUS_PICTURES_FIELD
    if field in window:
        result['retained_status_pictures'] = window[field]
    return result


def _retained_raster_details(window):
    fields = {
        pair.shared.launch.RASTER_CACHE_FIELD: 'raster_cache_at_peak',
        pair.shared.launch.GRAPHICS_ADAPTER_FIELD: 'graphics_adapter_kind',
    }
    return {name: window[field] for field, name in fields.items() if field in window}


def sample_receipts(value, *, allow_tap_release=False):
    if value == {}:
        return {}, False, False, False
    required = {'attempt', 'observation', 'profile_stable', 'success'}
    archive.need(type(value) is dict
        and required <= set(value) <= required | {
            'shutdown_observation', 'shutdown_trace', 'navigation_observation',
            'startup_observation'}
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
    if 'shutdown_observation' in value:
        archive.need(attempt is not None and 'EXIT_TIMEOUT' in attempt['error_codes']
            and pair.profile.valid_shutdown_observation(value['shutdown_observation']))
    if 'shutdown_trace' in value:
        trace = value['shutdown_trace']
        archive.need(attempt is not None and pair.profile.valid_shutdown_trace(trace)
            and trace['output_complete'] is attempt['output_complete'])
    observation = value['observation']
    if 'navigation_observation' in value:
        archive.need(attempt is not None
            and 'STARTUP_OBSERVATION_REFUSED' in attempt['error_codes']
            and pair.profile.navigation_failure(observation)
            and pair.profile.valid_navigation_observation(value['navigation_observation']))
    if 'startup_observation' in value:
        archive.need(attempt is not None and 'navigation_observation' not in value
            and 'STARTUP_OBSERVATION_REFUSED' in attempt['error_codes']
            and pair.profile.startup_failure(observation)
            and pair.profile.valid_startup_observation(value['startup_observation']))
    windows, entry_closed = {}, False
    observed = False
    if observation != {}:
        required = {'phase', 'lab_revalidations', 'entry', 'windows', 'success'}
        optional = {'action_progress', 'preparation_failure', 'idle_after_disclosure',
                    'idle_before_disclosure', 'idle_on_node_settings'}
        if allow_tap_release:
            optional.update(('tap_release_us', 'disclosure_phases_us', 'page_settled_us',
                             'pointer_phases_us'))
        archive.need(type(observation) is dict
            and required <= set(observation) <= required | optional
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
        if 'preparation_failure' in observation:
            failure = observation['preparation_failure']
            marker = pair.profile.preparation_failure_marker(failure)
            archive.need(type(failure) is dict
                and pair.profile.preparation_failure(failure) == failure
                and marker is not None
                and observation['phase'] == 'prepare_profile'
                and not observation['success'] and not offered and progress is None
                and entry is not None and entry['exit_code'] == 1
                and entry['exit_observed'] and not entry['forced_kill']
                and entry['output_complete'] and not entry['output_overflow']
                and not entry['error_codes'] and 0 < entry['output_bytes'] <= 4096
                and entry['output_bytes'] in (len(marker) + 1, len(marker) + 2))
        try:
            windows = {name: pair.shared.launch.frame_timing_window(window)
                       for name, window in offered.items()}
        except pair.shared.launch.startup.Failure:
            raise archive.Refused('INSPECTION_REFUSED') from None
        archive.need(not windows or entry_closed and observation['lab_revalidations'] >= 2)
        archive.need(all(pair.actions.MIN_WINDOW_US <= window['windowUs']
                         <= pair.actions.MAX_WINDOW_US for window in windows.values()))
        for field in ('idle_on_node_settings', 'idle_before_disclosure'):
            if field in observation:
                archive.need('page_change' in windows
                    and observation['phase'] in ('measure', 'verify_after', 'complete'))
                _idle_summary(observation[field])
        if 'idle_after_disclosure' in observation:
            archive.need('idle_on_node_settings' not in observation
                and set(windows) == set(pair.WINDOWS)
                and observation['phase'] in ('measure', 'verify_after', 'complete'))
            _idle_summary(observation['idle_after_disclosure'])
        if 'tap_release_us' in observation:
            releases = observation['tap_release_us']
            archive.need(type(releases) is dict and 0 < len(releases) <= len(windows)
                and set(releases) <= set(windows)
                and all(pair.shared.launch.startup.integer(offset, 0, windows[name]['windowUs'] - 1)
                        for name, offset in releases.items()))
        if 'pointer_phases_us' in observation:
            pointers = observation['pointer_phases_us']
            releases = observation.get('tap_release_us', {})
            archive.need(type(pointers) is dict and pointers and set(pointers) <= set(releases)
                and all(pair.actions.valid_pointer_phases(item, releases[name])
                        for name, item in pointers.items()))
        if 'disclosure_phases_us' in observation:
            archive.need('disclosure' in windows and pair.actions.valid_disclosure_phases(
                observation['disclosure_phases_us'],
                observation.get('tap_release_us', {}).get('disclosure'),
                windows['disclosure']['windowUs']))
        if 'page_settled_us' in observation:
            archive.need('page_change' in windows and pair.actions.valid_page_settlement(
                observation['page_settled_us'],
                observation.get('tap_release_us', {}).get('page_change'),
                windows['page_change']['windowUs']))
        observed = (observation['phase'] == 'complete' and observation['lab_revalidations'] == 3
                    and entry_closed and set(windows) == set(pair.WINDOWS))
        archive.need(observation['success'] is observed)
        archive.need(progress is None or not observed or progress['index'] > 0 and progress['returned'])
    success = completed and observed and value['profile_stable']
    archive.need(value['success'] is success)
    return windows, closed, entry_closed, success


def _raster_groups(*names):
    return {name: dict(samples=0, slow_raster=0, max_raster_us=0) for name in names}


def _record_raster(group, raster):
    group['samples'] += 1
    group['slow_raster'] += raster > pair.shared.FRAME_BUDGET_US
    group['max_raster_us'] = max(group['max_raster_us'], raster)


def _frame_gaps_by_previous_raster(window):
    """Group gaps by the previous reported raster's state at the next build."""
    rows = pair.shared.launch.frame_timing_rows(window, allow_packed=True)
    starts = cold.recorded_raster_starts(rows, window)
    groups = {state: dict(gaps=0, missing_frame_numbers=0) for state in (
        'finished', 'in_progress', 'pending', 'indeterminate')}
    for previous, following in zip(rows, rows[1:]):
        missing = following[0] - previous[0] - 1
        if not missing:
            continue
        earliest, latest = cold.raster_start_bounds(
            previous, observed_us=starts.get(previous[0]))
        following_build = following[1]
        raster_duration = previous[3]
        if following_build >= latest + raster_duration:
            state = 'finished'
        elif following_build < earliest:
            state = 'pending'
        elif latest <= following_build < earliest + raster_duration:
            state = 'in_progress'
        else:
            state = 'indeterminate'
        groups[state]['gaps'] += 1
        groups[state]['missing_frame_numbers'] += missing
    result = dict(raster_starts_observed=bool(starts), by_previous_raster=groups)
    largest = cold.largest_frame_gap(rows, starts)
    if largest is not None:
        result['largest_internal_gap'] = largest
    return result


def _reported_raster_coverage(rows, starts, end_us, tap_us, motion_us, settled_us):
    """Count the union of observed raster intervals within each time range."""
    intervals = []
    for start, end in sorted((starts[row[0]], starts[row[0]] + row[3]) for row in rows):
        if intervals and start <= intervals[-1][1]:
            intervals[-1] = (intervals[-1][0], max(end, intervals[-1][1]))
        else:
            intervals.append((start, end))

    def covered(begin, end):
        return sum(max(0, min(end, finish) - max(begin, start))
                   for start, finish in intervals)

    result = dict(window=covered(0, end_us),
                  nominal_motion=covered(tap_us, min(end_us, tap_us + motion_us)))
    if settled_us is not None:
        result['after_settlement'] = covered(settled_us, end_us)
    return result


def _window_diagnostics(window, tap_release_us, motion_us, observed_phases=None,
                        pointer_phases=None):
    result = cold.window_diagnostics(window, peak_starts=True)
    result.update(_retained_raster_details(window))
    if tap_release_us is not None:
        rows = pair.shared.launch.frame_timing_rows(window, allow_packed=True)
        raster_starts = cold.recorded_raster_starts(rows, window)
        if raster_starts:
            result['raster_start_timestamps_observed'] = True
            result['reported_raster_coverage_us'] = _reported_raster_coverage(
                rows, raster_starts, window['windowUs'], tap_release_us,
                motion_us, (observed_phases or {}).get('settled'))
        result['tap_release_us'] = tap_release_us
        result['peak_raster_start_bounds_from_tap_us'] = {
            name: offset - tap_release_us
            for name, offset in result.pop('peak_raster_start_bounds_us').items()}
        if pointer_phases:
            pointer_offsets = {name: offset - tap_release_us
                               for name, offset in pointer_phases.items()}
            peak = result['peak_raster_start_bounds_from_tap_us']
            result['pointer_offsets_from_tap_us'] = pointer_offsets
            result['peak_raster_start_relation_to_pointer'] = {
                name: ('before' if peak['latest'] < offset
                       else 'at_or_after' if peak['earliest'] >= offset
                       else 'crossing')
                for name, offset in pointer_offsets.items()}
        groups = _raster_groups('before', 'within', 'after', 'crossing')
        offsets = {name: offset - tap_release_us
                   for name, offset in (observed_phases or {}).items()}
        phase_groups = {name: _raster_groups('before', 'at_or_after', 'crossing')
                        for name in offsets}
        post_boundary_groups = {name: _raster_groups('before', 'at_or_after')
                                for name in offsets}
        for row in rows:
            earliest, latest = cold.raster_start_bounds(
                row, tap_release_us, observed_us=raster_starts.get(row[0]))
            if latest < 0:
                group = groups['before']
            elif earliest >= motion_us:
                group = groups['after']
            elif earliest >= 0 and latest < motion_us:
                group = groups['within']
            else:
                group = groups['crossing']
            raster = row[3]
            _record_raster(group, raster)
            # Each post-frame observation is an independent boundary.
            for name, offset in offsets.items():
                if latest < offset:
                    phase = 'before'
                elif earliest >= offset:
                    phase = 'at_or_after'
                    # Raster can begin after a boundary for a frame whose
                    # build started before it. Keep those samples separate.
                    build_start = row[1] - tap_release_us
                    build_phase = 'before' if build_start < offset else 'at_or_after'
                    _record_raster(post_boundary_groups[name][build_phase], raster)
                else:
                    phase = 'crossing'
                _record_raster(phase_groups[name][phase], raster)
        result.update(nominal_motion_us=motion_us, raster_start_groups=groups)
        if offsets:
            result['observed_post_frame_offsets_from_tap_us'] = offsets
            columns = ['samples', 'slow_raster', 'max_raster_us']
            result['raster_start_groups_by_observed_phase'] = dict(
                columns=columns,
                phases={name: {relation: [group[column] for column in columns]
                               for relation, group in relations.items()}
                        for name, relations in phase_groups.items()})
            result['post_boundary_raster_groups_by_build_start'] = dict(
                columns=columns,
                phases={name: {relation: [group[column] for column in columns]
                               for relation, group in relations.items()}
                        for name, relations in post_boundary_groups.items()})
    return result


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
    windows, current_closed, current_entry, current_passed = sample_receipts(
        samples.get('current', {}), allow_tap_release=True)
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
    diagnostic_windows = {}
    observed_phases = {}
    if current_passed:
        diagnostic_windows['current'] = windows
        observation = samples['current']['observation']
        observed_phases['disclosure'] = observation.get('disclosure_phases_us')
        if 'page_settled_us' in observation:
            observed_phases['page_change'] = {'settled': observation['page_settled_us']}
    if complete:
        diagnostic_windows['p06'] = old
    raster_overruns = {}
    if complete:
        observation = samples['current']['observation']
        releases = observation.get('tap_release_us', {})
        settlement = observation.get('disclosure_phases_us', {}).get('settled')
        page_settlement = observation.get('page_settled_us')
        for name in pair.WINDOWS:
            if 'raster' not in comparisons[name]['exceeded']:
                continue
            boundaries = None
            if name == 'disclosure' and settlement is not None:
                boundaries = ([settlement], ('before_settlement', 'after_settlement', 'crossing'))
            elif name == 'page_change' and page_settlement is not None:
                boundaries = ([releases[name], page_settlement],
                              ('before_release', 'before_settlement', 'after_settlement', 'crossing'))
            elif name == 'page_change' and name in releases:
                release = releases[name]
                boundaries = ([release, release + MOTION_US[name]],
                              ('before_release', 'during_nominal_motion', 'after_nominal_motion', 'crossing'))
            overrun = cold.raster_rank_overruns(old[name], windows[name], phase_boundaries=boundaries)
            if overrun['by_phase'] is None:
                del overrun['by_phase']
            if name in releases:
                bounds = overrun['worst']['start_us']
                overrun['worst']['start_from_release_us'] = [
                    value - releases[name] for value in bounds]
            raster_overruns[name] = overrun
    return dict(schema=1, scope='retained_' + pair.SCOPE,
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        archive_sha256=expected_sha, manifest_sha256=manifest_sha,
        artifact_reported_success=complete, timing_criterion_passed=timing_criterion_passed,
        original_phase=report['phase'],
        error_codes=report['error_codes'], runtime_started=False, verified_png_count=0,
        same_fixture_address=report['same_fixture_address'],
        action_progress={label: sample['observation'].get('action_progress')
                         for label, sample in samples.items() if sample.get('observation')},
        observation_phases={label: sample['observation']['phase']
                            for label, sample in samples.items() if sample.get('observation')},
        preparation_failures={label: sample['observation']['preparation_failure']
                              for label, sample in samples.items() if sample.get('observation')
                              and 'preparation_failure' in sample['observation']},
        shutdown_observations={label: sample['shutdown_observation']
                               for label, sample in samples.items()
                               if 'shutdown_observation' in sample},
        shutdown_traces={label: sample['shutdown_trace'] for label, sample in samples.items()
                         if 'shutdown_trace' in sample},
        navigation_observations={label: sample['navigation_observation']
                                 for label, sample in samples.items()
                                 if 'navigation_observation' in sample},
        startup_observations={label: sample['startup_observation']
                              for label, sample in samples.items()
                              if 'startup_observation' in sample},
        normal_wallet_exits=current_closed + p06_closed,
        normal_entry_exits=current_entry + p06_entry,
        entry_process_results={label: {key: sample['observation']['entry'][key] for key in (
            'success', 'exit_code', 'exit_observed', 'forced_kill', 'output_complete',
            'output_overflow', 'error_codes', 'output_bytes')}
            for label, sample in samples.items() if sample.get('observation')
            and sample['observation']['entry'] is not None},
        entry_process_seconds={label: sample['observation']['entry']['seconds']
            for label, sample in samples.items() if sample.get('observation')
            and sample['observation']['entry'] is not None},
        wallet_process_results={label: {key: sample['attempt'][key] for key in (
            'exit_code', *cold.EXIT_FLAGS, 'error_codes', 'action_complete', 'checks')}
            for label, sample in samples.items() if sample.get('attempt') is not None},
        profile_stable={label: sample['profile_stable']
            for label, sample in samples.items() if sample},
        frame_window_us={label:{name:value['windowUs'] for name,value in window.items()}
                         for label,window in (('current',windows), ('p06',old))},
        frame_counts={label:{name:len(value['frames']) for name,value in window.items()}
                      for label,window in (('current',windows), ('p06',old))},
        no_added_reported_slow_frames=None if comparisons is None else {
            name: value['no_added_reported_slow_frames'] for name,value in comparisons.items()},
        no_frame_number_gaps=None if comparisons is None else {
            name: value['no_frame_number_gaps'] for name,value in comparisons.items()},
        verified_comparisons=comparisons,
        verified_idle_on_node_settings={
            label: _idle_summary(samples[label]['observation']['idle_on_node_settings'])
            for label in diagnostic_windows
            if 'idle_on_node_settings' in samples[label]['observation']
        },
        verified_idle_before_disclosure={
            label: _idle_summary(samples[label]['observation']['idle_before_disclosure'])
            for label in diagnostic_windows
            if 'idle_before_disclosure' in samples[label]['observation']
        },
        verified_idle_after_disclosure={
            label: _idle_summary(samples[label]['observation']['idle_after_disclosure'])
            for label in diagnostic_windows
            if 'idle_after_disclosure' in samples[label]['observation']
        },
        verified_raster_rank_overruns=raster_overruns,
        verified_gap_raster_states={
            label: {name: _frame_gaps_by_previous_raster(window)
                    for name, window in frame_windows.items()}
            for label, frame_windows in diagnostic_windows.items()
        },
        **({'page_settled_us': samples['current']['observation']['page_settled_us']}
           if current_passed and 'page_settled_us' in samples['current']['observation'] else {}),
        verified_window_diagnostics={
            label: {name: _window_diagnostics(
                        window, samples[label]['observation'].get('tap_release_us', {}).get(name),
                        MOTION_US[name], observed_phases.get(name) if label == 'current' else None,
                        pointer_phases=samples[label]['observation'].get('pointer_phases_us', {}).get(name))
                    for name, window in frame_windows.items()}
            for label, frame_windows in diagnostic_windows.items()
        } or None)


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
    archive.need(entry in (
        pair.profile.ENTRY_SHA256,
        # Historical Welcome and original Skip preparation sources.
        'bbd2c42a646c19fb48908cd132cb01b0640a421011b833a7e3402d9f3140f1a0',
        '9964efb8467c25596735b42c07719bb8fc0a71a1e83dcace3c82eca25bd26ad8',
    ))
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
