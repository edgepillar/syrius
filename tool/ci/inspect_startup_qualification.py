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
from . import windows_startup_probe as startup


MAX_ARCHIVE = 256 * 1024
PRODUCERS = ('windows_startup_probe.py', 'windows_presentation_smoke.py',
             'windows_entry_capture_smoke.py', 'windows_wallet_tour.py')
JOB_NAME = 'Observe original Windows Release startup'


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


def launch_archive(raw, expected_sha, expected_size, head, tree, run_id, pins):
    """Bind two genuine film frames to their closed preparation and capture actors."""
    archive.need(type(raw) is bytes and type(expected_size) is int
        and 0 < len(raw) == expected_size <= launch.MAX_ARCHIVE
        and archive.sha(raw) == expected_sha)

    def unique(pairs):
        value = {}
        for key, item in pairs:
            archive.need(key not in value)
            value[key] = item
        return value

    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        names = [member.filename for member in members]
        archive.need(1 <= len(names) <= 3 and len(set(names)) == len(names)
            and 'manifest.json' in names and set(names) <= {'manifest.json', *launch.FILES})
        for member in members:
            cap = launch.MAX_MANIFEST if member.filename == 'manifest.json' else launch.MAX_PNG
            archive.need(member.orig_filename == member.filename and not member.is_dir()
                and not member.flag_bits & 1 and 0 < member.file_size <= cap
                and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG))
        manifest = zipped.read('manifest.json')
        report = json.loads(manifest, object_pairs_hook=unique)
        required = {'schema', 'scope', 'success', 'attempts', 'captures', 'source_stable',
            'error_codes', 'source_sha', 'source_tree', 'run_id', 'run_attempt',
            'runner_sha256', 'payload_sha256', 'recipe_sha256', 'capture_source_sha256'}
        archive.need(type(report) is dict and set(report) == required
            and type(report['schema']) is int and report['schema'] == 1
            and report['scope'] == 'original_cold_launch_catalog'
            and report['source_sha'] == head and report['source_tree'] == tree
            and report['run_id'] == str(run_id) and report['run_attempt'] == '1'
            and type(report['success']) is bool and type(report['source_stable']) is bool
            and all(type(report[k]) is str and re.fullmatch('[a-f0-9]{64}', report[k])
                    for k in ('runner_sha256', 'payload_sha256', 'recipe_sha256', 'capture_source_sha256'))
            and all(report[key] == pins[key] for key in ('recipe_sha256', 'capture_source_sha256')))
        errors = report['error_codes']
        archive.need(type(errors) is list and len(errors) <= 2
            and all(type(code) is str and code in startup.CODES for code in errors))
        attempts, captures = report['attempts'], report['captures']
        roles = [(theme, role) for theme in launch.THEMES for role in ('prepare', 'capture')]
        archive.need(type(attempts) is list and len(attempts) <= len(roles)
                     and type(captures) is list and len(captures) <= len(launch.FILES))
        attempt_flags = ('action_complete', 'exit_observed', 'forced_kill',
                         'output_complete', 'output_overflow')
        for row, (theme, role) in zip(attempts, roles):
            archive.need(type(row) is dict and set(row) == {*attempt_flags, 'theme', 'role',
                'checks', 'exit_code', 'error_codes'} and row['theme'] == theme and row['role'] == role
                and all(type(row[k]) is bool for k in attempt_flags)
                and type(row['checks']) is dict and set(row['checks']) == set(launch.ATTEMPT_CHECKS)
                and all(type(check) is bool for check in row['checks'].values())
                and (row['exit_code'] is None or type(row['exit_code']) is int
                     and -(2**31) <= row['exit_code'] < 2**32)
                and type(row['error_codes']) is list and len(row['error_codes']) <= 16
                and all(type(code) is str and code in startup.CODES for code in row['error_codes']))
        archive.need(all(launch.attempt_passed(row) for row in attempts[:-1]))
        for index, (row, name) in enumerate(zip(captures, launch.FILES)):
            archive.need(type(row) is dict and set(row) == {'theme', 'file', 'bytes', 'sha256',
                'frame', 'frames', 'stage'} and row['theme'] == launch.THEMES[index] and row['file'] == name
                and type(row['frame']) is int and row['frame'] == 23
                and type(row['frames']) is int and row['frames'] == 56 and launch.stage_matches(row['stage'])
                and type(row['bytes']) is int and 0 < row['bytes'] <= launch.MAX_PNG
                and len(attempts) >= 2 * (index + 1)
                and launch.attempt_passed(attempts[2 * index + 1]))
            pixels = zipped.read(name)
            archive.need(len(pixels) == row['bytes'] and archive.sha(pixels) == row['sha256'])
            launch.entry.png_bytes(base64.b64encode(pixels).decode('ascii'))
        archive.need(set(names) == {'manifest.json', *(row['file'] for row in captures)})
        complete = (len(attempts) == len(roles) and len(captures) == len(launch.FILES)
                    and all(launch.attempt_passed(row) for row in attempts)
                    and report['source_stable'] and not errors)
        archive.need(report['success'] is complete)
    return dict(schema=1, scope='retained_original_cold_launch_catalog',
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        archive_sha256=archive.sha(raw), manifest_sha256=archive.sha(manifest),
        artifact_reported_success=complete, verified_png_count=len(captures),
        filenames=[row['file'] for row in captures], frame=23, frames=56,
        error_codes=errors, visual_matches=0, runtime_started=False,
        **pins)


def inspect_launch_run(client, *, head, tree, run_id, job):
    """Inspect the selected startup lane without an SDK or native process."""
    archive.need(job['name'] == JOB_NAME and job['head_sha'] == head
        and job['run_id'] == run_id and job['status'] == 'completed'
        and job['conclusion'] in ('success', 'failure'))
    pins = {}
    for name, key in (('tool/ci/windows_launch_catalog.py', None),
                      (str(launch.RECIPE), 'recipe_sha256'),
                      (str(launch.CAPTURE_SOURCE), 'capture_source_sha256')):
        selected = client.json('/contents/' + name + '?ref=' + head)
        archive.need(selected['type'] == 'file' and selected['encoding'] == 'base64'
            and selected['path'] == name and type(selected['size']) is int
            and 0 < selected['size'] <= 64 * 1024)
        body = base64.b64decode(selected['content'].replace('\n', ''), validate=True)
        archive.need(len(body) == selected['size'])
        if key is None:
            archive.need(body == Path(launch.__file__).read_bytes())
        else:
            pins[key] = archive.sha(body)
    listing = client.json('/actions/runs/' + str(run_id) + '/artifacts?per_page=20')
    archive.need(listing['total_count'] == len(listing['artifacts']) == 1)
    item = listing['artifacts'][0]
    archive.need(item['name'] == 'windows-launch-catalog-' + head + '-' + str(run_id) + '-1'
        and item['expired'] is False and item['workflow_run']['id'] == run_id
        and item['workflow_run']['head_sha'] == head and type(item['id']) is int and item['id'] > 0
        and re.fullmatch('sha256:[a-f0-9]{64}', item.get('digest', '')) is not None
        and type(item['size_in_bytes']) is int and 0 < item['size_in_bytes'] <= launch.MAX_ARCHIVE)
    location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
    raw = client.read(location, authenticated=False, cap=launch.MAX_ARCHIVE)
    summary = launch_archive(raw, item['digest'][7:], item['size_in_bytes'], head, tree, run_id, pins)
    archive.need((job['conclusion'] == 'success') is summary['artifact_reported_success'])
    summary.update(original_job_id=job['id'], original_job_conclusion=job['conclusion'])
    return summary
