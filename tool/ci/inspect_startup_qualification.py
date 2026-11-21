"""Validate two retained startup reports without starting another process."""

import base64
import io
import json
from pathlib import Path
import re
import stat
import zipfile

from . import inspect_chain321 as archive
from . import windows_launch_catalog as launch
from . import windows_lock_catalog as lock_catalog
from . import windows_quiz_catalog as quiz_catalog
from . import windows_startup_probe as startup


MAX_ARCHIVE = 256 * 1024
PRODUCERS = ('windows_startup_probe.py', 'windows_presentation_smoke.py',
             'windows_entry_capture_smoke.py', 'windows_wallet_tour.py')
JOB_NAME = 'Observe original Windows Release startup'
BATCH_JOB_NAME = 'Capture original Windows startup catalog'
BACKDROP_SAMPLE_POINTS = dict(upper_left=(80, 90), upper_right=(1200, 90),
    left_of_stage=(190, 400), right_of_stage=(1090, 400),
    bottom_left=(60, 744), bottom_right=(1220, 744))
# One listing, fifteen source reads and two requests per archive.
BATCH_REQUESTS = 24
PRE_FIRST_PROGRESS_LAUNCH_PRODUCER_SHA = 'e494d6a5fffc539a9a0c63ccf13c813c3e58a50af507432976c1af109352166c'
PRE_P06_FILM_FLAGS_LAUNCH_PRODUCER_SHA = '2953d8dc15680d8e2fc5d0eb49fb719be23b32f5c91027f1d0a314b3c72806f5'
PRE_P06_WARMUP_LAUNCH_PRODUCER_SHA = 'a75408a79109738ba997eef4b09692db7ff3f1354833a1bd022a7160c04b5fc5'
PRE_LOCK_SETTLE_LAUNCH_PRODUCER_SHA = 'd83f34f0be461f80f350917c97b8dd2cff71e0b8d146a02f67adeda05e6340a4'
PRE_BATCH_LAUNCH_PRODUCER_SHA = '166cd2d6a070c53fef5e41d3e7d65fb7bf7e65cab53148da576f5338fe2d1f74'
PRE_PHASE_LAUNCH_PRODUCER_SHA = '83e89caefc7b68ad03450013544f98d234d5f01bbd9fa30c77e5c19765a80170'
PRE_MOTION_LAUNCH_PRODUCER_SHA = '34e0f9e31655e61d9299a0c3002f99f921ca2e2ad7fe3c7c7cc728ca072f3ae4'
PRE_LIGHT_MOTION_LAUNCH_PRODUCER_SHA = '090cfbe23429e293c5e7b9c7eef93c2ee903ad29b06ecfa08423dcf557925ecb'
PRE_AUTH_PHASE_LAUNCH_PRODUCER_SHA = '7dfdc17484942d61429e0bca2f48085ef9964d70414f3fb75511a942b0c560bc'
PRE_STAGE_LAYOUT_LAUNCH_PRODUCER_SHA = 'dc0c379a8abaa7b0e2ab39f1ff445a7325a5c29e804add276e646c5a6b7e1982'
PRE_RASTER_STARTS_LAUNCH_PRODUCER_SHA = '0c726ce6e6b7bfc5de9ce77702782366d489b7215815d1cd6b8833a03996a2df'
# The timing lane preserves earlier launch, lock and quiz producers.
PRE_TIMING_LAUNCH_PRODUCER_SHA = 'e579d76e178e69189069f5269a0ba8981f3e435a10e0f80f69bb2d559b4761a2'
FIRST_TIMING_LAUNCH_PRODUCER_SHA = '6880559d501bc59bff26865155af96efe56322a61a587a04edccc37b41a487a5'
PRIOR_TIMING_LAUNCH_PRODUCER_SHAS = (
    FIRST_TIMING_LAUNCH_PRODUCER_SHA,
    '0691ffb8a027616aac19115fe0cf3a8c8a9b407a4d0d72217be1be5475bab891',
)
# Retained launch archives created before the handoff option use this producer.
ORIGINAL_LAUNCH_PRODUCER_SHA = 'dbf165b477df62dae61258224a96220e8b5d4575b4673010d9491006c486bce9'
HANDOFF_LAUNCH_PRODUCER_SHA = 'ffb11b8748080d0973eb08f168f1c926bdf13622e9f9717fe084f2b09571d9fc'
PRIOR_QUIZ_PRODUCER_SHAS = (
    '059f36ee7a97d0242355763211af2241aa8ff3bf38916ac634791a4ca8ff120c',
    'd7d5770ca1332345e908ec6fe47f0d0f60fbf617760e48daece268e67828c48d',
    'dfbfce588d8d83ae7c7eab7b330571a2632b22d12281d9700855e956e416143b',
)


def startup_archive(raw, expected_sha, expected_size, head, tree, run_id, *,
                    natural_only=False, prior_manifest_sha256=None,
                    runner_sha256=None, payload_sha256=None):
    """Consume one bounded manifest and keep its original positive or negative."""
    archive.need(type(raw) is bytes and type(expected_size) is int
        and 0 < len(raw) == expected_size <= MAX_ARCHIVE
        and type(expected_sha) is str
        and re.fullmatch('[a-f0-9]{64}', expected_sha) is not None
        and archive.sha(raw) == expected_sha)
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        archive.need(len(members) == 1)
        member = members[0]
        archive.need(member.filename == 'manifest.json' and not member.is_dir()
            and not member.flag_bits & 1
            and member.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
            and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG)
            and 0 < member.file_size <= startup.MAX_MANIFEST)
        with zipped.open(member) as stream:
            manifest = stream.read(startup.MAX_MANIFEST + 1)
        archive.need(len(manifest) == member.file_size)
    report = json.loads(manifest)
    archive.need(type(report) is dict)
    if not natural_only:
        runner_sha256 = report.get('runner_sha256')
        payload_sha256 = report.get('payload_sha256')
    projected = startup.observation_projection(
        report, head=head, tree=tree, run_id=str(run_id), run_attempt='1',
        runner_sha256=runner_sha256, payload_sha256=payload_sha256,
        natural_only=natural_only, prior_manifest_sha256=prior_manifest_sha256,
    )
    archive.need(projected is not None)
    samples = projected['samples']
    summary = dict(
        schema=1,
        scope=('retained_natural_release_startup_observation' if natural_only
               else 'retained_release_startup_observation'),
        inspection_only=True, runtime_started=False, wallet_qualified=False,
        chain_qualified=False, source_head=head, source_tree=tree,
        source_run_id=run_id, source_attempt=1,
        archive_sha256=archive.sha(raw), archive_bytes=len(raw),
        manifest_sha256=archive.sha(manifest), manifest_bytes=len(manifest),
        artifact_reported_success=projected['success'],
        checks=projected['checks'], sample_count=len(samples),
        samples_valid=projected['samples_valid'],
        first_sample=samples[0] if samples else None,
        last_sample=samples[-1] if samples else None,
        handoff=projected['handoff'], key_attempts=projected['key_attempts'],
        startup_deadline_seconds=projected['startup_deadline_seconds'],
        startup_deadline_expired=projected['startup_deadline_expired'],
        exit_code=projected['exit_code'], exit_observed=projected['exit_observed'],
        forced_kill=projected['forced_kill'], output_complete=projected['output_complete'],
        output_overflow=projected['output_overflow'],
        original_error_codes=projected['error_codes'],
        runner_sha256=projected['runner_sha256'],
        payload_sha256=projected['payload_sha256'],
        original_skip_qualified=projected['original_skip_qualified'],
        original_natural_qualified=projected.get('original_natural_qualified', False),
        visual_matches=0, financial_actions_requested=0, node_cluster_started=False,
    )
    if natural_only:
        summary['prior_manifest_sha256'] = projected['prior_manifest_sha256']
    return summary


def inspect_run(client, *, head, tree, run_id, job):
    """Read the exact producer sources, job and two original finite archives."""
    archive.need(job['name'] == JOB_NAME and job['head_sha'] == head
        and job['run_id'] == run_id and job['status'] == 'completed'
        and job['conclusion'] in ('success', 'failure'))
    for name in PRODUCERS:
        selected = client.json('/contents/tool/ci/' + name + '?ref=' + head)
        archive.need(selected['type'] == 'file' and selected['encoding'] == 'base64'
            and selected['path'] == 'tool/ci/' + name)
        data = base64.b64decode(selected['content'].replace('\n', ''), validate=True)
        archive.need(len(data) == selected['size']
            and data == Path(__file__).with_name(name).read_bytes())
    listing = client.json('/actions/runs/' + str(run_id) + '/artifacts?per_page=20')
    archive.need(listing['total_count'] == len(listing['artifacts']) <= 20)
    summaries = []
    for natural, prefix in ((False, 'windows-startup-probe-'),
                            (True, 'windows-natural-startup-probe-')):
        name = prefix + head + '-' + str(run_id) + '-1'
        selected = [item for item in listing['artifacts'] if item['name'] == name]
        archive.need(len(selected) == 1)
        item = selected[0]
        archive.need(item['expired'] is False and item['workflow_run']['id'] == run_id
            and item['workflow_run']['head_sha'] == head
            and type(item['id']) is int and item['id'] > 0
            and type(item['size_in_bytes']) is int
            and 0 < item['size_in_bytes'] <= MAX_ARCHIVE
            and re.fullmatch('sha256:[a-f0-9]{64}', item.get('digest', '')) is not None)
        location = client.read(archive.API + '/actions/artifacts/' + str(item['id'])
                               + '/zip', redirect=True)
        raw = client.read(location, authenticated=False, cap=MAX_ARCHIVE)
        prior = summaries[0] if summaries else {}
        if natural:
            archive.need(prior['artifact_reported_success'])
        summary = startup_archive(
            raw, item['digest'][7:], item['size_in_bytes'], head, tree, run_id,
            natural_only=natural, prior_manifest_sha256=prior.get('manifest_sha256'),
            runner_sha256=prior.get('runner_sha256'),
            payload_sha256=prior.get('payload_sha256'),
        )
        archive.need(job['conclusion'] != 'success'
                     or summary['artifact_reported_success'])
        summary.update(original_job_id=job['id'],
            original_job_conclusion=job['conclusion'], producer_sources_equal=True)
        summaries.append(summary)
    return summaries


def lock_film_bounds(encoded):
    """Measure inclusive black film edges in the original 1280 x 780 capture."""
    from .inspect_windows_qualification import _opaque, _png_crop

    left, right = 407, 873
    top, bottom = 76, 394
    rows, channels = _png_crop(encoded, (left, right), (top, bottom))
    if not _opaque(rows, channels):
        return None
    # The interior stripe is clear of the wordmark and rounded corners.
    first, last = (448 - left) * channels, (465 - left) * channels
    black_rows = [y for y, row in enumerate(rows)
                  if all(max(row[i:i + 3]) <= 5 for i in range(first, last, channels))]
    if (len(black_rows) < 15 or black_rows[0] == 0 or black_rows[-1] == len(rows) - 1
            or len(black_rows) != black_rows[-1] - black_rows[0] + 1):
        return None
    row = rows[black_rows[0] + 14]
    black_columns = [left + i // channels for i in range(0, len(row), channels)
                     if max(row[i:i + 3]) <= 5]
    if black_columns[0] == left or black_columns[-1] == right - 1:
        return None
    return dict(left=black_columns[0], top=top + black_rows[0],
                right=black_columns[-1], bottom=top + black_rows[-1])


def settle_stage_bounds(encoded):
    """Measure the black stage on two scan lines away from the wordmark."""
    from .inspect_windows_qualification import _opaque, _png_crop

    left, right, top, bottom = 225, 1055, 110, 540
    rows, channels = _png_crop(encoded, (left, right), (top, bottom))
    if not _opaque(rows, channels):
        return None
    across = rows[390 - top]
    column = (300 - left) * channels
    xs = [x for x in range(right - left)
          if max(across[x * channels:x * channels + 3]) <= 5]
    ys = [y for y, row in enumerate(rows) if max(row[column:column + 3]) <= 5]
    for indices, limit in ((xs, right - left), (ys, bottom - top)):
        if (not indices or indices[0] == 0 or indices[-1] == limit - 1
                or len(indices) != indices[-1] - indices[0] + 1):
            return None
    return dict(left=left + xs[0], top=top + ys[0],
                right=left + xs[-1], bottom=top + ys[-1])


def lock_picker_divider_row(encoded, theme):
    """Read the one menu line between the wallet rows and the add action."""
    from .inspect_windows_qualification import _opaque, _png_crop

    top, bottom = 476, 508
    rows, channels = _png_crop(encoded, (622, 655), (top, bottom))
    ink = {'dark': bytes((56, 58, 56)), 'light': bytes((213, 216, 213))}[theme]
    if not _opaque(rows, channels):
        return None
    matches = [y for y, row in enumerate(rows, top)
               if all(row[i:i + 3] == ink for i in range(0, len(row), channels))]
    return matches[0] if len(matches) == 1 else None


def launch_archive(raw, expected_sha, expected_size, head, tree, run_id, pins, *,
                   settle=False, lock=False, quiz=False, timing=False, lock_seams=False,
                   motion=False, motion_theme=launch.TIMING_THEME, shared_binaries=None,
                   compare_png=None):
    """Bind startup evidence to its exact original closed actors."""
    archive.need(not timing or not (settle or lock or quiz))
    archive.need(not lock_seams or not (settle or lock or quiz or timing))
    archive.need(not motion or not (settle or lock or quiz or timing or lock_seams))
    archive.need(motion_theme in launch.THEMES and (motion or motion_theme == launch.TIMING_THEME))
    cap = launch.TIMING_MAX_ARCHIVE if timing else lock_catalog.MAX_ARCHIVE if lock else launch.MAX_ARCHIVE
    if quiz:
        cap = quiz_catalog.MAX_ARCHIVE
    elif lock_seams:
        cap = lock_catalog.SEAM_MAX_ARCHIVE
    elif motion:
        cap = launch.MOTION_MAX_ARCHIVE
    archive.need(type(raw) is bytes and type(expected_size) is int
        and 0 < len(raw) == expected_size <= cap
        and archive.sha(raw) == expected_sha)
    if timing:
        files, frame_fields, scope = (), set(), launch.TIMING_SCOPE
        pin_fields = {'collector_sha256', 'profile_sha256'}
    elif quiz:
        files, frame_fields, scope = quiz_catalog.FILES, quiz_catalog.STATE_FIELDS, quiz_catalog.SCOPE
        pin_fields = set(quiz_catalog.PIN_SOURCES)
    elif lock_seams:
        files, frame_fields, scope = (), set(), lock_catalog.SEAM_SCOPE
        pin_fields = {'capture_source_sha256', 'profile_sha256'} | set(lock_catalog.SEAM_PIN_SOURCES)
    elif lock:
        files, frame_fields, scope = lock_catalog.FILES, lock_catalog.STATE_FIELDS, lock_catalog.SCOPE
        pin_fields = {'capture_source_sha256', 'profile_sha256'}
    elif motion:
        files, scope = launch.MOTION_FILES, launch.MOTION_SCOPE
        frame_fields = {'slot', 'offsetUs', 'stage', 'well', 'progress'}
        pin_fields = {'recipe_sha256', 'capture_source_sha256', 'profile_sha256'}
    else:
        files = launch.SETTLE_FILES if settle else launch.FILES
        frame_fields = launch.SETTLE_FIELDS if settle else launch.FRAME_FIELDS
        scope = launch.SETTLE_SCOPE if settle else launch.SCOPE
        pin_fields = {'recipe_sha256', 'capture_source_sha256'}
    if settle:
        pin_fields.add('profile_sha256')
    per_theme = len(files) // len(launch.THEMES)
    archive.need(set(pins) == pin_fields)

    def unique(pairs):
        value = {}
        for key, item in pairs:
            archive.need(key not in value)
            value[key] = item
        return value

    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        names = [member.filename for member in members]
        archive.need(1 <= len(names) <= len(files) + 1 and len(set(names)) == len(names)
            and 'manifest.json' in names and set(names) <= {'manifest.json', *files})
        for member in members:
            manifest_cap = lock_catalog.SEAM_CAP if lock_seams else launch.MAX_MANIFEST
            png_cap = launch.MOTION_PNG_CAP if motion else launch.MAX_PNG
            cap = manifest_cap if member.filename == 'manifest.json' else png_cap
            archive.need(member.orig_filename == member.filename and not member.is_dir()
                and not member.flag_bits & 1 and 0 < member.file_size <= cap
                and member.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG))
        manifest = zipped.read('manifest.json')
        report = json.loads(manifest, object_pairs_hook=unique)
        required = {'schema', 'scope', 'success', 'attempts', 'captures', 'source_stable',
            'error_codes', 'source_sha', 'source_tree', 'run_id', 'run_attempt',
            'runner_sha256', 'payload_sha256'} | pin_fields
        if timing:
            required = required - {'captures'} | {'mode', 'theme', 'client', 'frame_window'}
        if lock_seams:
            required.add('seam_refusals')
        if motion:
            required.add('attempted_slots')
            if type(report) is dict and 'first_observed_progress' in report:
                required.add('first_observed_progress')
        archive.need(type(report) is dict and set(report) == required
            and type(report['schema']) is int and report['schema'] == 1
            and report['scope'] == scope
            and report['source_sha'] == head and report['source_tree'] == tree
            and report['run_id'] == str(run_id) and report['run_attempt'] == '1'
            and type(report['success']) is bool and type(report['source_stable']) is bool
            and all(type(report[k]) is str and re.fullmatch('[a-f0-9]{64}', report[k])
                    for k in {'runner_sha256', 'payload_sha256'} | pin_fields)
            and all(report[key] == pins[key] for key in pin_fields))
        errors = report['error_codes']
        archive.need(type(errors) is list and len(errors) <= 2
            and all(type(code) is str and code in startup.CODES for code in errors))
        attempts = report['attempts']
        captures = [] if timing else report['captures']
        if timing or lock_seams or motion:
            action = 'capture' if motion else 'observe' if lock_seams else 'timing'
            roles = [(motion_theme, role) for role in ('prepare', action)]
        else:
            roles = ([('dark', 'capture')] if quiz else
                     [(theme, role) for theme in launch.THEMES for role in ('prepare', 'capture')])
        archive.need(type(attempts) is list and len(attempts) <= len(roles)
                     and type(captures) is list and len(captures) <= len(files))
        attempt_flags = ('action_complete', 'exit_observed', 'forced_kill',
                         'output_complete', 'output_overflow')
        attempt_keys = {*attempt_flags, 'theme', 'role', 'checks', 'exit_code', 'error_codes'}
        if lock or quiz or lock_seams:
            attempt_keys.add('phase')
        for row, (theme, role) in zip(attempts, roles):
            archive.need(type(row) is dict)
            fields = attempt_keys | {'refusal'} if quiz and 'refusal' in row else attempt_keys
            archive.need(set(row) == fields
                and row['theme'] == theme and row['role'] == role
                and all(type(row[k]) is bool for k in attempt_flags)
                and type(row['checks']) is dict and set(row['checks']) == set(launch.ATTEMPT_CHECKS)
                and all(type(check) is bool for check in row['checks'].values())
                and (row['exit_code'] is None or type(row['exit_code']) is int
                     and -(2**31) <= row['exit_code'] < 2**32)
                and type(row['error_codes']) is list and len(row['error_codes']) <= 16
                and all(type(code) is str and code in startup.CODES for code in row['error_codes']))
            if lock or lock_seams:
                phases = lock_catalog.SEAM_PHASES if lock_seams else lock_catalog.PHASES
                archive.need(row['phase'] in phases
                    and ((role == 'prepare') is (row['phase'] == 'prepare'))
                    and (not row['action_complete'] or row['phase'] in ('prepare', 'complete')))
            if quiz:
                refusal = row.get('refusal')
                archive.need(row['phase'] in quiz_catalog.PHASES
                    and row['action_complete'] is (row['phase'] == 'complete')
                    and (refusal is None or (type(refusal) is str
                         and refusal in quiz_catalog.REFUSALS
                         and 'COMMAND_FAILED' in row['error_codes']
                         and not row['action_complete'])))
        archive.need(all(launch.attempt_passed(row) for row in attempts[:-1]))
        if lock_seams:
            observed = report['seam_refusals']
            expected = tuple(seam for _, seam in lock_catalog.SEAM_ACTIONS)
            archive.need(type(observed) is list and tuple(observed) == expected[:len(observed)]
                and (not observed or len(attempts) == 2
                     and attempts[1]['phase'] in ('seam_probes', 'complete')))
        frame_window = None
        motion_backdrop = {}
        if timing:
            archive.need(report['mode'] == 'release' and report['theme'] == launch.TIMING_THEME
                and type(report['client']) is list
                and all(type(value) is int for value in report['client'])
                and report['client'] == list(launch.TIMING_SIZE))
            frame_window = report['frame_window']
            if frame_window is not None:
                archive.need(len(attempts) == len(roles) and launch.attempt_passed(attempts[-1]))
                try:
                    launch.standalone_frame_timing_window(frame_window)
                except startup.Failure:
                    raise archive.Refused('INSPECTION_REFUSED') from None
        if motion:
            from .inspect_windows_qualification import _png_crop

            attempted = report['attempted_slots']
            archive.need(type(attempted) is list and (not captures or attempted))
            progress = {}
            if 'first_observed_progress' in report:
                archive.need(bool(attempted))
                progress['firstObservedProgress'] = report['first_observed_progress']
            live_rows = []
            for row in captures:
                archive.need(type(row) is dict and set(row) == {
                    'theme', 'file', 'bytes', 'sha256'} | frame_fields
                    and type(row['slot']) is int and 0 <= row['slot'] < len(files)
                    and row['theme'] == motion_theme and row['file'] == files[row['slot']]
                    and row['file'] in names and type(row['bytes']) is int)
                pixels = zipped.read(row['file'])
                archive.need(len(pixels) == row['bytes'] and archive.sha(pixels) == row['sha256'])
                live_rows.append(dict(png=base64.b64encode(pixels).decode('ascii'),
                    **{key: row[key] for key in frame_fields}))
            if attempted:
                archive.need(len(attempts) == 2 and all(launch.attempt_passed(row) for row in attempts))
                try:
                    launch.motion_pixels(dict(ok=True, status='captured', theme=motion_theme,
                        lockHandoff=True, frame=55, frames=56,
                        attemptedSlots=attempted, samples=live_rows, **progress), motion_theme)
                except startup.Failure:
                    raise archive.Refused('INSPECTION_REFUSED') from None
            for row, live in zip(captures, live_rows):
                left, top, width, height = row['stage']
                scan, channels = _png_crop(live['png'], (60, 1221), (90, 745))
                colors = {}
                for name, (x, y) in BACKDROP_SAMPLE_POINTS.items():
                    if left <= x < left + width and top <= y < top + height:
                        continue
                    start = (x - 60) * channels
                    pixel = scan[y - 90][start:start + channels]
                    if channels == 3 or pixel[3] == 255:
                        colors[name] = list(pixel[:3])
                motion_backdrop[row['file']] = colors
        film_bounds, stage_bounds, picker_divider_rows, wrong_action_gradient = [], {}, {}, {}
        quiz_step_bounds, quiz_back_bounds = {}, {}
        for index, (row, name) in enumerate(zip(captures, () if motion else files)):
            theme, phase = divmod(index, per_theme)
            actor = 0 if quiz else 2 * theme + 1
            archive.need(type(row) is dict
                and set(row) == {'theme', 'file', 'bytes', 'sha256'} | frame_fields
                and row['theme'] == launch.THEMES[theme] and row['file'] == name
                and type(row['bytes']) is int and 0 < row['bytes'] <= launch.MAX_PNG
                and len(attempts) > actor and launch.attempt_passed(attempts[actor]))
            if quiz:
                archive.need(quiz_catalog.frame_matches(row) and (index == 0
                    or row['native_before'] > captures[index - 1]['native_after']))
            elif lock:
                archive.need(lock_catalog.frame_matches(row, lock_catalog.SCREENS[phase]))
            else:
                archive.need(launch.frame_matches(row, settle=settle))
            pixels = zipped.read(name)
            archive.need(len(pixels) == row['bytes'] and archive.sha(pixels) == row['sha256'])
            encoded = base64.b64encode(pixels).decode('ascii')
            if lock:
                film_bounds.append(lock_film_bounds(encoded))
                if row['screen'] == 'lock-pick':
                    picker_divider_rows[row['theme']] = lock_picker_divider_row(encoded, row['theme'])
                if row['screen'] == 'lock-wrong':
                    from .inspect_windows_qualification import primary_gradient_error

                    wrong_action_gradient[row['theme']] = primary_gradient_error(
                        encoded, (459, 525, 821, 571))
            elif quiz:
                from .inspect_windows_qualification import back_mark_bounds, completed_step_bounds

                quiz_step_bounds[row['theme']] = completed_step_bounds(encoded, 'seed-quiz')
                quiz_back_bounds[row['theme']] = back_mark_bounds(encoded, 'seed-quiz')
            elif settle:
                stage_bounds[row['theme']] = settle_stage_bounds(encoded)
            else:
                launch.entry.png_bytes(encoded)
        archive.need(set(names) == {'manifest.json', *(row['file'] for row in captures)})
        if lock or quiz:
            archive.need(len({row['sha256'] for row in captures}) == len(captures))
        complete = (len(attempts) == len(roles) and len(captures) == len(files)
                    and all(launch.attempt_passed(row) for row in attempts)
                    and report['source_stable'] and not errors
                    and (not timing or frame_window is not None)
                    and (not lock_seams or tuple(observed) == expected))
        archive.need(report['success'] is complete)
        comparisons = {}
        if complete and compare_png is not None:
            for row in captures:
                name = row['file']
                comparisons[name] = compare_png(name, zipped.read(name))
    summary = dict(schema=1, scope='retained_' + report['scope'],
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        archive_sha256=archive.sha(raw), manifest_sha256=archive.sha(manifest),
        artifact_reported_success=complete, verified_png_count=len(captures),
        filenames=[row['file'] for row in captures],
        error_codes=errors, visual_matches=0, runtime_started=False,
        **pins)
    if comparisons:
        summary['pixel_comparisons'] = comparisons
    if timing:
        summary.update(frame_count=0, window_us=None, frame_window_sha256=None)
        if frame_window is not None:
            raw_window = json.dumps(frame_window, sort_keys=True,
                separators=(',', ':')).encode('ascii')
            summary.update(frame_count=launch.frame_timing_count(frame_window),
                window_us=frame_window['windowUs'], frame_window_sha256=archive.sha(raw_window))
            if frame_window['schema'] == 2:
                from .inspect_launch_timing_pair import window_diagnostics

                summary['frame_diagnostics'] = window_diagnostics(frame_window)
        summary.update(mode=report['mode'], theme=report['theme'], client=report['client'],
            original_attempts=attempts, baseline_compared=False)
    elif lock_seams:
        summary['seam_refusals'] = observed
        summary['normal_actor_exits'] = sum(
            row['exit_observed'] and row['exit_code'] == 0
            and row['output_complete'] and not row['output_overflow'] and not row['forced_kill']
            and all(row['checks'].values()) for row in attempts)
    elif motion:
        summary['theme'] = motion_theme
        summary['backdrop_sample_points'] = BACKDROP_SAMPLE_POINTS
        summary['exterior_rgb_by_sample'] = motion_backdrop
        summary['attempted_slots'] = attempted
        if 'first_observed_progress' in report:
            summary['first_observed_progress'] = report['first_observed_progress']
        summary['samples'] = [{key: row[key] for key in sorted(frame_fields)} for row in captures]
        summary['normal_actor_exits'] = sum(launch.attempt_passed(row) for row in attempts)
    elif quiz:
        summary['single_process'] = len(attempts) == 1 and launch.attempt_passed(attempts[0])
        summary['completed_step_bounds'] = quiz_step_bounds
        summary['back_mark_bounds'] = quiz_back_bounds
        summary['states'] = [{key: row[key] for key in sorted(frame_fields)} for row in captures]
        if attempts and attempts[0].get('refusal') is not None:
            summary['refusal'] = attempts[0]['refusal']
    elif lock:
        summary['frames'] = 56
        summary['states'] = [{key: row[key] for key in sorted(frame_fields)} for row in captures]
        summary['film_pixel_bounds'] = film_bounds
        summary['picker_divider_rows'] = picker_divider_rows
        summary['wrong_action_gradient'] = wrong_action_gradient
    else:
        summary['frames'] = 56
        summary['frame'] = 55 if settle else 23
    if settle:
        summary['handoff_progress'] = [row['progress'] for row in captures]
        summary['stage_pixel_bounds'] = stage_bounds
    if shared_binaries is not None:
        for key in ('runner_sha256', 'payload_sha256'):
            archive.need(shared_binaries.setdefault(key, report[key]) == report[key])
    return summary


def inspect_launch_run(client, *, head, tree, run_id, job, settle=False, lock=False,
                       quiz=False, timing=False, lock_seams=False, motion=False,
                       item=None, compare_png=None, shared_binaries=None):
    """Inspect the selected startup lane without an SDK or native process."""
    archive.need(job['name'] == JOB_NAME and job['head_sha'] == head
        and job['run_id'] == run_id and job['status'] == 'completed'
        and job['conclusion'] in ('success', 'failure'))
    if lock_seams:
        observed = [step for step in job['steps'] if step['name'] == lock_catalog.SEAM_STEP]
        retained = [step for step in job['steps'] if step['name'] == lock_catalog.SEAM_RETAIN_STEP]
        archive.need(job['labels'] == ['windows-latest'] and len(observed) == len(retained) == 1
            and observed[0]['status'] == retained[0]['status'] == 'completed'
            and observed[0]['conclusion'] in ('success', 'failure')
            and retained[0]['conclusion'] == 'success')
    if motion:
        steps = {step['name']: step for step in job['steps']}
        archive.need(len(steps) == len(job['steps']) and job['labels'] == ['windows-latest']
            and steps['Build the ordinary Release harness target']['conclusion'] == 'success'
            and steps[launch.MOTION_JOB_STEP]['conclusion'] == job['conclusion']
            and steps[launch.MOTION_RETAIN_STEP]['conclusion'] == 'success')
    if settle:
        steps = {step['name']: step for step in job['steps']}
        archive.need(len(steps) == len(job['steps']) and job['labels'] == ['windows-latest'])
        for name, conclusion in (
            ('Build the ordinary Release harness target', 'success'),
            (launch.SETTLE_JOB_STEP, job['conclusion']),
            ('Retain the original launch handoff manifest and PNGs', 'success'),
        ):
            step = steps.get(name, {})
            archive.need(step.get('status') == 'completed'
                         and step.get('conclusion') == conclusion)
    summary = _inspect_launch_artifact(client, head, tree, run_id,
        settle=settle, lock=lock, quiz=quiz, timing=timing, lock_seams=lock_seams,
        motion=motion, item=item, compare_png=compare_png, shared_binaries=shared_binaries)
    archive.need((job['conclusion'] == 'success') is summary['artifact_reported_success'])
    summary.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'])
    return summary


def _inspect_launch_artifact(client, head, tree, run_id, *, settle=False, lock=False,
                             quiz=False, timing=False, lock_seams=False, motion=False, item=None,
                             motion_theme=launch.TIMING_THEME, shared_binaries=None,
                             compare_png=None):
    pins = {}
    sources = [('tool/ci/windows_launch_catalog.py', None)]
    if timing:
        sources.extend(((launch.TIMING_SOURCE.as_posix(), 'collector_sha256'),
                        (launch.SETTLE_PROFILE_SOURCE.as_posix(), 'profile_sha256')))
        sources.extend(('tool/ci/' + name, None) for name in PRODUCERS[:3])
    elif quiz:
        sources.append(('tool/ci/windows_quiz_catalog.py', None))
        sources.extend((path.as_posix(), key) for key, path in quiz_catalog.PIN_SOURCES.items())
    elif lock or lock_seams:
        sources.extend((('tool/ci/windows_lock_catalog.py', None),
                        (lock_catalog.CAPTURE_SOURCE.as_posix(), 'capture_source_sha256')))
    else:
        recipe = launch.SETTLE_RECIPE if settle or motion else launch.RECIPE
        sources.extend(((recipe.as_posix(), 'recipe_sha256'),
                        (launch.CAPTURE_SOURCE.as_posix(), 'capture_source_sha256')))
    if settle or lock or lock_seams or motion:
        sources.append((launch.SETTLE_PROFILE_SOURCE.as_posix(), 'profile_sha256'))
    if lock_seams:
        sources.extend((path.as_posix(), key) for key, path in lock_catalog.SEAM_PIN_SOURCES.items())
    for name, key in sources:
        selected = client.json('/contents/' + name + '?ref=' + head)
        archive.need(selected['type'] == 'file' and selected['encoding'] == 'base64'
            and selected['path'] == name and type(selected['size']) is int
            and 0 < selected['size'] <= 64 * 1024)
        body = base64.b64decode(selected['content'].replace('\n', ''), validate=True)
        archive.need(len(body) == selected['size'])
        if key is None:
            current = Path(__file__).with_name(Path(name).name).read_bytes()
            prior = () if lock or quiz or lock_seams else ((HANDOFF_LAUNCH_PRODUCER_SHA,) if settle else
                                      (ORIGINAL_LAUNCH_PRODUCER_SHA, HANDOFF_LAUNCH_PRODUCER_SHA))
            if timing:
                prior = (PRIOR_TIMING_LAUNCH_PRODUCER_SHAS
                         if name == 'tool/ci/windows_launch_catalog.py' else ())
            elif name == 'tool/ci/windows_launch_catalog.py' and not lock_seams:
                prior = (*prior, PRE_TIMING_LAUNCH_PRODUCER_SHA, *PRIOR_TIMING_LAUNCH_PRODUCER_SHAS)
            if quiz and name == 'tool/ci/windows_quiz_catalog.py':
                prior = PRIOR_QUIZ_PRODUCER_SHAS
            if name == 'tool/ci/windows_launch_catalog.py':
                prior = (*prior, PRE_BATCH_LAUNCH_PRODUCER_SHA, PRE_RASTER_STARTS_LAUNCH_PRODUCER_SHA)
            before_phase_capture = (name == 'tool/ci/windows_launch_catalog.py'
                                    and archive.sha(body) in (PRE_PHASE_LAUNCH_PRODUCER_SHA,
                                                             PRE_MOTION_LAUNCH_PRODUCER_SHA))
            before_lock_settle = (name == 'tool/ci/windows_launch_catalog.py'
                                  and archive.sha(body) == PRE_LOCK_SETTLE_LAUNCH_PRODUCER_SHA)
            before_p06_diagnostics = (name == 'tool/ci/windows_launch_catalog.py'
                                      and archive.sha(body) in (PRE_P06_WARMUP_LAUNCH_PRODUCER_SHA,
                                                               PRE_P06_FILM_FLAGS_LAUNCH_PRODUCER_SHA))
            before_first_progress = (name == 'tool/ci/windows_launch_catalog.py'
                                     and archive.sha(body) == PRE_FIRST_PROGRESS_LAUNCH_PRODUCER_SHA)
            before_light_motion = (name == 'tool/ci/windows_launch_catalog.py'
                                   and archive.sha(body) == PRE_LIGHT_MOTION_LAUNCH_PRODUCER_SHA)
            before_auth_phase = (name == 'tool/ci/windows_launch_catalog.py'
                                 and archive.sha(body) in (PRE_AUTH_PHASE_LAUNCH_PRODUCER_SHA,
                                                          PRE_STAGE_LAYOUT_LAUNCH_PRODUCER_SHA))
            legacy = (before_lock_settle or before_p06_diagnostics or before_first_progress
                      or before_light_motion or not motion and (before_phase_capture
                          or shared_binaries is None and archive.sha(body) in prior))
            archive.need(body == current or before_auth_phase
                         or motion_theme == launch.TIMING_THEME and legacy)
        else:
            pins[key] = archive.sha(body)
    if item is None:
        listing = client.json('/actions/runs/' + str(run_id) + '/artifacts?per_page=20')
        archive.need(listing['total_count'] == len(listing['artifacts']) == 1)
        item = listing['artifacts'][0]
    screen = launch.SETTLE_SCREEN if settle else 'launch'
    prefix = lock_catalog.ARTIFACT_PREFIX if lock else 'windows-' + screen + '-catalog-'
    cap = lock_catalog.MAX_ARCHIVE if lock else launch.MAX_ARCHIVE
    if timing:
        prefix, cap = launch.TIMING_ARTIFACT_PREFIX, launch.TIMING_MAX_ARCHIVE
    elif quiz:
        prefix, cap = quiz_catalog.ARTIFACT_PREFIX, quiz_catalog.MAX_ARCHIVE
    elif lock_seams:
        prefix, cap = lock_catalog.SEAM_ARTIFACT_PREFIX, lock_catalog.SEAM_MAX_ARCHIVE
    elif motion:
        prefix = (launch.MOTION_LIGHT_ARTIFACT_PREFIX if motion_theme == 'light'
                  else launch.MOTION_ARTIFACT_PREFIX)
        cap = launch.MOTION_MAX_ARCHIVE
    archive.need(item['name'] == prefix + head + '-' + str(run_id) + '-1'
        and item['expired'] is False and item['workflow_run']['id'] == run_id
        and item['workflow_run']['head_sha'] == head and type(item['id']) is int and item['id'] > 0
        and re.fullmatch('sha256:[a-f0-9]{64}', item.get('digest', '')) is not None
        and type(item['size_in_bytes']) is int and 0 < item['size_in_bytes'] <= cap)
    location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
    raw = client.read(location, authenticated=False, cap=cap)
    return launch_archive(raw, item['digest'][7:], item['size_in_bytes'],
        head, tree, run_id, pins, settle=settle, lock=lock, quiz=quiz, timing=timing,
        lock_seams=lock_seams, motion=motion, motion_theme=motion_theme,
        shared_binaries=shared_binaries, compare_png=compare_png)


def inspect_catalog_batch(client, *, head, tree, run_id, job, compare_png=None):
    """Bind each archive to its original step and compare the shared binaries."""
    lanes = (
        (launch.JOB_STEP, 'Retain the original cold launch manifest and PNGs',
         'windows-launch-catalog-', {}),
        (launch.SETTLE_JOB_STEP, 'Retain the original launch handoff manifest and PNGs',
         'windows-launch-settle-catalog-', {'settle': True}),
        (lock_catalog.JOB_STEP, 'Retain the original lock catalog manifest and PNGs',
         lock_catalog.ARTIFACT_PREFIX, {'lock': True}),
        (quiz_catalog.JOB_STEP, 'Retain the synthetic seed quiz manifest and PNGs',
         quiz_catalog.ARTIFACT_PREFIX, {'quiz': True}),
    )
    return _inspect_catalog_lanes(client, head, tree, run_id, job, lanes,
                                  BATCH_JOB_NAME, 'retained_windows_startup_catalog_batch',
                                  compare_png=compare_png)


def inspect_motion_batch(client, *, head, tree, run_id, job):
    """Verify each theme against its original step and the same Release binaries."""
    lanes = (
        (launch.MOTION_JOB_STEP, launch.MOTION_RETAIN_STEP,
         launch.MOTION_ARTIFACT_PREFIX, {'motion': True}),
        (launch.MOTION_LIGHT_JOB_STEP, launch.MOTION_LIGHT_RETAIN_STEP,
         launch.MOTION_LIGHT_ARTIFACT_PREFIX, {'motion': True, 'motion_theme': 'light'}),
    )
    return _inspect_catalog_lanes(client, head, tree, run_id, job, lanes,
                                  JOB_NAME, 'retained_windows_launch_motion_batch')


def _inspect_catalog_lanes(client, head, tree, run_id, job, lanes, job_name, scope,
                           *, compare_png=None):
    archive.need(job['name'] == job_name and job['labels'] == ['windows-latest']
        and job['head_sha'] == head and job['run_id'] == run_id
        and job['status'] == 'completed' and job['conclusion'] in ('success', 'failure'))
    steps = {}
    for step in job['steps']:
        name = step['name']
        archive.need(name not in steps and step['status'] == 'completed')
        steps[name] = step['conclusion']
    archive.need(steps['Build the ordinary Release harness target'] == 'success')
    expected = {}
    ran_all = True
    for capture, retain, prefix, options in lanes:
        outcome, upload = steps[capture], steps[retain]
        archive.need(outcome in ('success', 'failure', 'skipped')
            and upload in ('success', 'failure', 'skipped')
            and (upload != 'success' or outcome != 'skipped'))
        ran_all = ran_all and outcome == upload == 'success'
        if upload == 'success':
            expected[prefix + head + '-' + str(run_id) + '-1'] = (outcome, options)
    archive.need(job['conclusion'] != 'success' or ran_all)
    listing = client.json('/actions/runs/' + str(run_id) + '/artifacts?per_page=20')
    items = {item['name']: item for item in listing['artifacts']}
    archive.need(listing['total_count'] == len(listing['artifacts']) == len(items)
        and set(items) == set(expected)
        and len({item['id'] for item in items.values()}) == len(items))
    shared_binaries, results = {}, []
    for name, (outcome, options) in expected.items():
        summary = _inspect_launch_artifact(client, head, tree, run_id,
            item=items[name], shared_binaries=shared_binaries,
            compare_png=compare_png, **options)
        archive.need((outcome == 'success') is summary['artifact_reported_success'])
        summary.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'],
                       original_capture_conclusion=outcome)
        results.append(summary)
    batch = dict(schema=1, scope=scope,
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        original_job_id=job['id'], original_job_conclusion=job['conclusion'],
        complete=ran_all and job['conclusion'] == 'success', verified_catalogs=len(results),
        verified_png_count=sum(item['verified_png_count'] for item in results),
        visual_matches=0, **shared_binaries)
    return batch, results
