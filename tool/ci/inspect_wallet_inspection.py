"""Inspect retained readonly wallet archives without another native execution."""

from __future__ import annotations

import base64
from collections import Counter
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import zipfile
from functools import cache

from . import inspect_chain321 as archive
from . import inspect_windows_qualification as windows
from . import windows_wallet_inspection as producer


MAX_ARCHIVE = producer.MAX_CAPTURE_TOTAL + producer.MAX_MANIFEST + 65536
MAX_HOME_ARCHIVE = producer.MAX_HOME_CAPTURE_TOTAL + producer.MAX_HOME_MANIFEST + 65536
MAX_TREE = 2 * 1024**2
MAX_NOTICE_BYTES = 3800
WORKFLOW_SOURCE = '.github/workflows/public-contribution-qualification.yml'
MAX_WORKFLOW_SOURCE = 128 * 1024
MAX_WORKFLOW_RESPONSE = 2 * MAX_WORKFLOW_SOURCE
CAPTURE_AGENT_SOURCE = 'harness/app/agent.dart'
HOME_FIELD_SOURCE = 'lib/rearchitecture/utils/widgets/hero_field.dart'
HOME_GOTO_CONTACT_FIXTURE = 'harness/app/fixtures/home_goto_contact.dart'
MAX_CAPTURE_AGENT_SOURCE = 256 * 1024
MAX_VERSIONED_BLOB_RESPONSE = 2 * MAX_CAPTURE_AGENT_SOURCE
VERSIONED_INPUTS = frozenset((
    'pubspec.yaml', 'pubspec.lock',
    'harness/screens/home-open.txt',
    'harness/screens/pillars.txt', 'harness/screens/plasma-fuse.txt',
    'harness/screens/set-licences.txt', 'harness/screens/set-wallet.txt',
    'harness/screens/token-new.txt',
    'tool/ci/hosted_chain321.py',
    'tool/ci/readonly_details_capture.py',
    'tool/ci/run_harness_tour_tests.py',
    'tool/ci/windows_wallet_inspection.py',
    'harness/bin/ci_wallet_inspection.dart',
    'harness/bin/ci_wallet_reopen.dart',
    'harness/bin/readonly_catalog_contact.dart',
    'harness/bin/readonly_details_catalog.dart',
    'harness/bin/readonly_home_catalog.dart',
    'harness/bin/readonly_inspection_session.dart',
    'harness/bin/readonly_navigation_catalog.dart',
    'harness/bin/readonly_settings_catalog.dart',
    'harness/bin/screen_capture.dart',
    'harness/bin/wallet_recipe.dart',
    'harness/app/ready_reference_artwork.dart',
    'harness/app/readonly_native_commands.dart',
    'lib/rearchitecture/utils/widgets/entry_field.dart',
    'lib/rearchitecture/utils/widgets/segment.dart',
    'lib/utils/reference_artwork_source.dart',
    'lib/widgets/modular_widgets/help_widgets/about_card.dart',
    'lib/widgets/modular_widgets/help_widgets/originals_card.dart',
    'lib/widgets/modular_widgets/help_widgets/originals_tiles.dart',
    'lib/widgets/modular_widgets/settings_widgets/node_settings_view.dart',
    'lib/widgets/shell/rail.dart',
    'lib/widgets/shell/strip/status_dot.dart',
    'lib/widgets/modular_widgets/settings_widgets/wallet_settings_view.dart',
    'lib/widgets/reusable_widgets/launch_film.dart',
    CAPTURE_AGENT_SOURCE, HOME_FIELD_SOURCE, HOME_GOTO_CONTACT_FIXTURE,
))
JOB = 'Windows readonly inspection with owned chain-321'
PREFLIGHT = ('Test all isolated controllers before SDK allocation',
    'Analyze the gated wallet entry and tour',
    'Test page coverage and refusal before wallet build')
RUNTIME = 'Build, observe and stop the original isolated lab'
SOURCE_FILES = (
    'tool/ci/windows_wallet_inspection.py', 'tool/ci/hosted_chain321.py',
    'tool/ci/readonly_viewport_capture.py', 'harness/bin/readonly_viewport_probe.dart',
    'tool/ci/run_harness_tour_tests.py', 'tool/ci/windows_debug_loop.py',
    'tool/ci/windows_debug_process.py', 'tool/ci/windows_entry_capture_smoke.py',
    'tool/ci/windows_presentation_smoke.py', 'tool/ci/windows_wallet_tour.py',
    'harness/bin/ci_wallet_inspection.dart',
    'harness/bin/readonly_inspection_session.dart', 'harness/bin/harness.dart',
    'harness/bin/wallet_recipe.dart', 'harness/app/agent.dart',
    'harness/app/capture_frame.dart',
    'harness/app/readonly_native_mode.dart',
    'harness/app/readonly_native_commands.dart',
    'harness/app/activity_message_seam_binding.dart',
    'harness/app/fixtures/activity_message_preview.dart',
    'lib/rearchitecture/features/latest_transactions/model/activity_entry.dart',
    'lib/rearchitecture/features/latest_transactions/view/activity_row.dart',
    'lib/rearchitecture/features/latest_transactions/view/latest_transactions_card.dart',
    'lib/rearchitecture/features/latest_transactions/bloc/latest_transactions_bloc.dart',
    'lib/rearchitecture/utils/blocs/infinite_list/infinite_list_bloc.dart',
    'lib/seams/SEAMS.md', 'lib/seams/seam.dart',
    'lib/widgets/shell/rail.dart',
    'lib/widgets/shell/strip/update_slot.dart',
    'lib/rearchitecture/features/pillars/view/pillars_card.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/modals/start_native_swap_modal.dart',
    'lib/widgets/modular_widgets/settings_widgets/node_settings_view.dart',
    'lib/widgets/modular_widgets/settings_widgets/security_settings_view.dart',
    'lib/widgets/modular_widgets/settings_widgets/wallet_settings_view.dart',
    'lib/widgets/modular_widgets/help_widgets/about_card.dart',
    'lib/rearchitecture/utils/widgets/segment.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/modals/swap_action_boundary.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/modals/swap_action_surface.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/modals/swap_modal_state.dart',
    'harness/app/readonly_sdk_admission.dart', 'harness/app/readonly_sdk_binding.dart',
    'harness/app/readonly_wallet_admission.dart',
    'harness/app/readonly_wallet_binding.dart', 'harness/app/native_window_owner.dart',
    'harness/app/logical_capture.dart', 'harness/app/readonly_shot_layout.dart',
    'harness/bin/readonly_home_catalog.dart', 'harness/bin/screen_capture.dart',
    'harness/screens/home-rest.txt', 'harness/screens/home-hidden.txt',
    'harness/screens/home-open.txt', 'harness/screens/home-goto.txt',
    '.github/workflows/public-contribution-qualification.yml',
    'pubspec.yaml', 'pubspec.lock',
    'tool/ci/readonly_settings_capture.py',
    'harness/bin/readonly_settings_catalog.dart',
    'harness/screens/set-node.txt',
    'harness/screens/set-security.txt',
    'harness/screens/set-display.txt',
    'harness/screens/set-wallet.txt',
    'harness/screens/set-apps.txt',
    'harness/screens/set-addresses.txt',
    'harness/screens/set-about.txt',
    'tool/ci/readonly_navigation_capture.py',
    'harness/bin/readonly_navigation_catalog.dart',
    'harness/screens/send-rest.txt',
    'harness/screens/receive.txt',
    'harness/screens/pillars.txt',
    'harness/screens/plasma.txt',
    'harness/screens/tokens.txt',
    'harness/screens/swap-list.txt',
    'harness/screens/az.txt',
    'tool/ci/readonly_details_capture.py',
    'harness/bin/readonly_details_catalog.dart',
    'harness/screens/receive-qr.txt',
    'harness/screens/zap-form.txt',
    'harness/screens/plasma-fuse.txt',
    'harness/screens/set-licences.txt',
    'harness/screens/set-originals.txt',
    'harness/screens/token-new.txt',
    'harness/screens/send-confirm.txt',
)
SURFACE_SEAM_SOURCES = (
    'lib/seams/SEAMS.md', 'lib/seams/seam.dart',
    'lib/widgets/shell/strip/update_slot.dart',
    'lib/rearchitecture/features/tokens/view/tokens_card.dart',
    'lib/rearchitecture/features/tokens/widgets/token_card.dart',
    'lib/rearchitecture/features/tokens/widgets/token_inline_actions.dart',
    'lib/rearchitecture/utils/widgets/row_detail.dart',
    'lib/rearchitecture/features/pillars/view/pillars_card.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/modals/start_native_swap_modal.dart',
)
SENTINEL_FIXTURE_SOURCES = ('harness/app/main.dart',
    'harness/app/fixtures/sentinel_fixture.dart')
AGED_FUSE_SOURCES = (
    'harness/bin/ci_wallet_reopen.dart',
    'harness/app/fixtures/seed_commands.dart',
    'harness/app/fixtures/seed_policy.dart',
    'harness/app/fixtures/lab_seed_binding.dart',
    'harness/app/fixtures/presentation_fixtures.dart',
    'harness/app/fixtures/fixture_cleanup.dart',
    'tool/ci/restored_wallet_run.py',
)
HOME_ZAP_PREVIEW_SOURCES = ('harness/app/fixtures/home_zap_preview.dart',)
PHASE = 'environment'


def need(value):
    archive.need(value)


def digest(value, length=64):
    return type(value) is str and re.fullmatch('[a-f0-9]{' + str(length) + '}', value) is not None


def decode(raw):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            need(key not in value)
            value[key] = item
        return value
    return json.loads(raw, object_pairs_hook=unique)


def owned_lab(report, head, tree, run_id):
    """The explicit reader scope cannot adopt a financial or restored lab."""
    need(type(report) is dict and report.get('application_tree') == tree)
    summary = archive.project(report, 'native', head, run_id,
        archive.UPSTREAM_NODE_SHA, expected_patched=True, expected_inspection=True)
    exits = summary['node_exits']
    positive = (all(summary['checks'].values()) and not summary['error_codes']
        and len(exits) == 5 and summary['native_shutdown_order'] == list(archive.ROLES)
        and summary['native_shutdown_mode'] == 'coordinated_requests_then_wait'
        and all(type(row['exit_code']) is int and row['exit_code'] == 0
                and row['output_complete'] is True and row['forced'] is False
                and row['stop_code'] is None for row in exits))
    need(not report['success'] or positive)
    summary['original_lab_closure_qualified'] = bool(report['success'] and positive)
    return summary


def projection(report, lab, lab_summary, head, tree, run_id, manifest_sha):
    """Check independent success requirements after the closed privacy schema."""
    producer.public_manifest(report)
    need(report.get('source_sha') == head and report.get('source_tree') == tree
         and report.get('run_id') == str(run_id) and report.get('run_attempt') == '1'
         and digest(manifest_sha) and lab.get('application_sha') == head
         and lab.get('application_tree') == tree and lab.get('run_id') == str(run_id)
         and lab.get('attempt') == '1' and lab_summary.get('source_head') == head
         and lab_summary.get('source_run_id') == run_id)
    original = lab.get('wallet_inspection')
    need(type(original) is dict and set(original) == {'success', 'phase', 'checks',
         'errors', 'captured_pages', 'visited_pages', 'manifest_sha256'}
         and original['manifest_sha256'] == manifest_sha
         and original['success'] is report['success'] and original['phase'] == report['phase']
         and original['checks'] == report['checks'] and original['errors'] == report['errors']
         and type(original['captured_pages']) is type(original['visited_pages']) is int
         and original['captured_pages'] == len(report['captures'])
         and original['visited_pages'] == sum(len(v['tour']['visited']) for v in report['tours'].values()))
    catalog_family = producer.catalog_only_family(report)
    send_warning = catalog_family == producer.send_warning_window.FAMILY
    need(send_warning is ('send_warning_node_fixture' in lab))
    if send_warning and report['success']:
        need(producer.send_warning_window.test_receipt(lab.get('send_warning_node_fixture')))
    samples_complete = catalog_family is not None or (
        set(report['tours']) == set(report['locales']) ==
            set(report['stalls']) == set(producer.THEMES)
        and len(report['captures']) == len(producer.THEMES) * len(producer.PAGES)
        and all(v['tour']['complete'] is True
                and len(v['tour']['visited']) == len(producer.PAGES)
                and all(p['captured'] is True and p['nodes'] > 0
                        and p['error_widgets'] == p['severe_logs'] == 0
                        for p in v['tour']['visited']) for v in report['tours'].values()))
    if catalog_family == producer.SURFACE_SEAMS_FAMILY:
        samples_complete = tuple(report['seam_refusals']) == producer.SURFACE_SEAMS
    for field in ('home_seam_observations', 'settings_seam_observations'):
        if field in report:
            samples_complete = samples_complete and report[field]['complete']
    positive = (report['phase'] == 'complete' and not report['errors']
        and producer.complete_checks(report) and samples_complete
        and report['input_attempted'] is True and report['lab_revalidations'] == 2
        and report['address_selection'] is not None
        and report['sdk_admission'] is not None and report['wallet_admission'] is not None
        and type(report.get('application_exit')) is int and report['application_exit'] == 0
        and type(report.get('entry_exit')) is int and report['entry_exit'] == 0
        and report['required_actor_forced_cleanup'] is False
        and report.get('owned_job_active_at_close') == 0
        and report['owned_job_images_before_close'] ==
            dict(status='OBSERVED', listed=0, observed=0, counts={})
        and report['entry_output']['output_complete'] is True
        and report['entry_output']['overflow'] is False
        and report['auxiliary_cleanup'] is not None
        and producer.debug.helper_cleanup_complete(report['auxiliary_cleanup'])
        and report['forced_cleanup'] is report['auxiliary_cleanup']['forced'])
    need(report['success'] is bool(positive))
    if positive:
        if catalog_family is None:
            producer.capture_records(report['captures'])
        producer.sdk_receipt(report['sdk_admission'])
        producer.wallet_receipt(report['wallet_admission'])
    captures = json.dumps(report['captures'], sort_keys=True, separators=(',', ':')).encode('ascii')
    result = dict(schema=1, scope='retained_readonly_wallet_inspection',
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        artifact_reported_success=report['success'],
        original_lab_closure_qualified=lab_summary['original_lab_closure_qualified'],
        native_inspection_qualified=False, original_checks=dict(report['checks']),
        original_errors=list(report['errors']),
        entry_failure=report.get('entry_failure'), application_exit=report.get('application_exit'),
        entry_exit=report.get('entry_exit'),
        entry_output=report.get('entry_output'), forced_cleanup=report['forced_cleanup'],
        auxiliary_cleanup=report['auxiliary_cleanup'],
        required_actor_forced_cleanup=report['required_actor_forced_cleanup'],
        sdk_admission=report['sdk_admission'], wallet_admission=report['wallet_admission'],
        address_selection=report['address_selection'], lab_revalidations=report['lab_revalidations'],
        reported_capture_count=len(report['captures']), verified_png_count=0,
        capture_catalog_sha256=archive.sha(captures),
        visited_pages={t: len(v['tour']['visited']) for t, v in report['tours'].items()},
        locale_verified=sorted(report['locales']), stalls=report['stalls'],
        inspection_only=True, runtime_started=False, wallet_qualified=False,
        seed_admitted=False, financial_send_qualified=False,
        motion_baseline_compared=False, arabic_or_minimum_window_qualified=False,
        visual_matches=0)
    if catalog_family is not None:
        result['sampling_scope'] = catalog_family + '-only'
    if catalog_family == producer.SURFACE_SEAMS_FAMILY:
        result['seam_refusals'] = list(report['seam_refusals'])
    if 'aged_fuse_fixture' in report:
        witness = report['aged_fuse_fixture']
        result['aged_fuse_fixture'] = (
            producer.aged_fuse_receipt(witness) if witness is not None else None)
    if 'build_before_lab' in report:
        result['build_before_lab'] = producer.build_before_lab_receipt(
            report['build_before_lab'])
    for field in ('home_seam_observations', 'settings_seam_observations'):
        if field in report:
            observations = report[field]
            result[field] = dict(observations,
                observed=[dict(row) for row in observations['observed']])
    if send_warning:
        result['send_warning_window'] = producer.require_warning_window(
            report, complete=report['success'])
    return result


LAYOUT_STATUS_ORDER = ('MISSING', 'OBSERVED', 'DUPLICATE', 'UNAVAILABLE', 'LIMIT')
LAYOUT_TARGETS = ('home_hero', 'transfer_card', 'nodes_tab_pillars',
    'nodes_tab_sentinels', 'staking_stake_button', 'plasma_open_fuse',
    'tokens_filter_held', 'p2p_start_swap', 'accelerator_strip', 'bell_panel',
    'node_settings_add', 'apps_settings_web_switch')
LAYOUT_COLUMNS = tuple(boundary + '_' + name
    for boundary in ('before', 'after')
    for name in ('body_status', 'body_top', 'caption_status', 'caption_bottom',
                 'target_status', 'target_top')) + ('unchanged',)


def layout_projection(report, head, tree, run_id):
    """Finite coordinates from the retained archive, never original widget text."""
    producer.public_manifest(report)
    need(report['success'] and report['source_sha'] == head
         and report['source_tree'] == tree and report['run_id'] == str(run_id)
         and report['run_attempt'] == '1' and len(LAYOUT_TARGETS) == len(producer.PAGES))
    rows = {}
    for theme in producer.THEMES:
        tour = report['tours'][theme]
        need(producer.tour_complete(tour))
        frames = []
        for page, target in zip(tour['tour']['visited'], LAYOUT_TARGETS):
            original = producer.layout_observation(page['layout'])
            frame = []
            for boundary in ('before', 'after'):
                entries = {row['key']: row for row in original[boundary]}
                for key, coordinate in (('window-body', 1), ('window-caption', 3),
                                         (target, 1)):
                    row = entries[key]
                    frame.extend((LAYOUT_STATUS_ORDER.index(row['status']),
                        row['rect'][coordinate] if row['status'] == 'OBSERVED' else None))
            frame.append(original['unchanged'])
            frames.append(frame)
        rows[theme] = frames
    return dict(schema=1, scope='retained_readonly_shot_layout_observation',
        source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
        pages=list(producer.PAGES), targets=list(LAYOUT_TARGETS),
        statuses=list(LAYOUT_STATUS_ORDER), columns=list(LAYOUT_COLUMNS), rows=rows,
        sample_count=24, boundaries=['before_raster', 'after_encoding'],
        inspection_only=True, runtime_started=False, atomic_frame_qualified=False,
        visual_matches=0, original_layout_or_raster_cause='NOT_ESTABLISHED')


def unpack(raw, expected_sha, expected_size, head, tree, run_id, lab, lab_summary):
    need(type(raw) is bytes and type(expected_size) is int and digest(expected_sha)
         and 0 < len(raw) == expected_size <= MAX_ARCHIVE and archive.sha(raw) == expected_sha)
    allowed = {'manifest.json'} | {'captures/' + t + '/' + p + '.png'
        for t in producer.THEMES for p in producer.PAGES}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        names = [m.filename for m in members]
        need(1 <= len(members) <= 25 and len(set(names)) == len(names)
             and 'manifest.json' in names and set(names) <= allowed)
        total = 0
        for member in members:
            cap = producer.MAX_MANIFEST if member.filename == 'manifest.json' else producer.debug.entry.MAX_PNG
            need(not member.is_dir() and not member.flag_bits & 1
                 and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG)
                 and 0 < member.file_size <= cap)
            total += member.file_size
        need(total <= producer.MAX_CAPTURE_TOTAL + producer.MAX_MANIFEST)

        def member(name, cap):
            with zipped.open(name) as stream:
                value = stream.read(cap + 1)
                need(not stream.read(1))
            need(0 < len(value) == zipped.getinfo(name).file_size <= cap)
            return value

        manifest = member('manifest.json', producer.MAX_MANIFEST)
        report = decode(manifest)
        summary = projection(report, lab, lab_summary, head, tree, run_id, archive.sha(manifest))
        if report['success']:
            catalog_only = producer.catalog_only_family(report) is not None
            need(set(names) == ({'manifest.json'} if catalog_only else allowed))
            for row in report['captures']:
                name = 'captures/' + row['theme'] + '/' + row['page'] + '.png'
                image = member(name, producer.debug.entry.MAX_PNG)
                need(len(image) == row['bytes'] and archive.sha(image) == row['sha256'])
                producer.debug.entry.png_bytes(base64.b64encode(image).decode('ascii'))
            summary['verified_png_count'] = len(report['captures'])
            if not catalog_only:
                summary['_layout_observation'] = layout_projection(
                    report, head, tree, run_id)
            summary['_home_catalog_reference'] = report['home_catalog']
            if report['schema'] in producer.SETTINGS_INSPECTION_SCHEMAS:
                summary['_settings_catalog_reference'] = report['settings_catalog']
            elif report['schema'] == 3:
                summary['_navigation_catalog_reference'] = report['navigation_catalog']
            elif report['schema'] >= 4:
                summary['_details_catalog_reference'] = report['details_catalog']
            summary['_viewport_reference'] = report['viewport']
        else:
            need(names == ['manifest.json'])
    summary.update(archive_sha256=archive.sha(raw), manifest_sha256=archive.sha(manifest))
    return summary


def home_script_source_pins(source_digests, schema):
    producer.home_catalog_files(schema)
    if schema == producer.HOME_BELL_CAPTURE_SCHEMA:
        return {'home-bell': source_digests[producer.HOME_BELL_SCRIPT.as_posix()]}
    first = source_digests['harness/screens/home-rest.txt']
    if schema == 1:
        return first
    if schema == 2:
        return {'home-rest': first,
            'home-hidden': source_digests['harness/screens/home-hidden.txt']}
    pins = {'home-rest': first,
        'home-open': source_digests['harness/screens/home-open.txt'],
        'home-hidden': source_digests['harness/screens/home-hidden.txt']}
    if schema == 4:
        pins['home-goto'] = source_digests['harness/screens/home-goto.txt']
    return pins


def catalog_image_pins(raw, catalog):
    """Project the literal PNG digests from an already verified catalog."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        manifest = zipped.read('manifest.json')
    need(archive.sha(manifest) == catalog['manifest_sha256'])
    rows = decode(manifest)['captures']
    pins = {row['file']: row['sha256'] for row in rows}
    need(len(pins) == len(rows) and set(pins) == set(catalog['filenames'])
         and all(digest(value) for value in pins.values()))
    return pins


def unpack_home_catalog(raw, expected_sha, expected_size, head, tree, run_id,
                        reference, script_sha):
    """Verify each literal state; only the caller can bind parent closure."""
    producer.home_catalog_reference(reference)
    schema = reference['schema']
    files = producer.home_catalog_files(schema)
    script_field = producer._home_script_field(schema)
    pins = {'home-rest': script_sha} if schema == 1 else script_sha
    need(type(pins) is dict and set(pins) == set(
        producer.home_catalog_screens(schema))
        and all(digest(pin) for pin in pins.values()))
    need(type(raw) is bytes and type(expected_size) is int and digest(expected_sha)
         and 0 < len(raw) == expected_size <= MAX_HOME_ARCHIVE and archive.sha(raw) == expected_sha)
    allowed = {'manifest.json', *files}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        members = zipped.infolist()
        names = [m.filename for m in members]
        need(len(members) == len(set(names)) == len(allowed) and set(names) == allowed)
        total = 0
        for member in members:
            cap = producer.MAX_HOME_MANIFEST if member.filename == 'manifest.json' else producer.MAX_HOME_CAPTURE_TOTAL
            need(member.orig_filename == member.filename and not member.is_dir()
                 and not member.flag_bits & 1
                 and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG)
                 and 0 < member.file_size <= cap)
            total += member.file_size
        need(total <= producer.MAX_HOME_CAPTURE_TOTAL + producer.MAX_HOME_MANIFEST)

        def member(name, cap):
            with zipped.open(name) as stream:
                value = stream.read(cap + 1)
                need(not stream.read(1))
            need(0 < len(value) == zipped.getinfo(name).file_size <= cap)
            return value

        manifest = member('manifest.json', producer.MAX_HOME_MANIFEST)
        need(archive.sha(manifest) == reference['manifest_sha256'])
        value = producer.public_home_catalog(decode(manifest))
        need(value['schema'] == schema and value['source_sha'] == head
             and value['source_tree'] == tree and value['run_id'] == str(run_id)
             and value['run_attempt'] == '1' and value[script_field] == script_sha)
        for row in producer.home_capture_records(value['captures'], schema=schema):
            pixels = member(row['file'], producer.MAX_HOME_CAPTURE_TOTAL)
            need(len(pixels) == row['bytes'] and archive.sha(pixels) == row['sha256'])
            producer.debug.entry.png_bytes(base64.b64encode(pixels).decode('ascii'))
    result = dict(schema=schema, scope='retained_readonly_home_catalog', source_head=head,
        source_tree=tree, source_run_id=run_id, source_attempt=1,
        themes=list(producer.THEMES), filenames=list(files),
        width=1280, height=780, scale=1, verified_png_count=len(files),
        archive_sha256=archive.sha(raw), manifest_sha256=archive.sha(manifest),
        catalog_capture_qualified=False, parent_closure_qualified=False,
        atomic_frame_qualified=False, inspection_only=True, runtime_started=False,
        wallet_qualified=False, seed_admitted=False, financial_send_qualified=False,
        visual_matches=0)
    result.update(dict(screen='home-rest', number=1) if schema == 1
                  else dict(screens=list(producer.home_catalog_screens(schema))))
    result[script_field] = script_sha
    if 'rail_motion' in value['capture']:
        samples = producer.rail_motion_receipt(value['capture']['rail_motion'])
        result['rail_motion'] = dict(
            scope='original_toggle_widths_after_tap_reply', samples=samples,
            intermediate_observed={direction: any(40 < row[1] < 184 for row in rows)
                                   for direction, rows in samples.items()},
        )
        if len(samples['opening'][0]) == 4:
            result['rail_motion'].update(
                chevron_intermediate_observed={
                    direction: any(0 < row[2] < 3142 for row in rows)
                    for direction, rows in samples.items()},
                opening_label_fade_observed=any(
                    0 < row[3] < 1000 for row in samples['opening']),
            )
    if 'sync_pulse' in value['capture']:
        samples = producer.sync_pulse_receipt(value['capture']['sync_pulse'])
        resumes = [(left[0], right[1]) for left, right in zip(samples, samples[1:])
                   if left[2] == 1000 and right[2] < 1000]
        result['sync_pulse'] = dict(
            sample_count=len(samples),
            observed_intermediate=any(0 < phase < 1000 for _, _, phase in samples),
            transparent_samples=sum(phase == 1000 for _, _, phase in samples),
            resume_intervals_us=resumes,
            resume_separation_bounds_us=[
                [next_start - end, next_end - start]
                for (start, end), (next_start, next_end) in zip(resumes, resumes[1:])
            ],
        )
    if 'segment_motion' in value['capture']:
        samples = producer.segment_motion_receipt(value['capture']['segment_motion'])
        result['segment_motion'] = {
            name: dict(
                sample_count=len(motion['samples']),
                before_millipixels=motion['before'],
                after_millipixels=motion['samples'][-1][1:3],
                first_settled_after_reply_us=motion['samples'][-1][0],
                intermediate_observed=any(
                    row[1:3] != motion['before'] and row[1:3] != row[3:]
                    for row in motion['samples']),
            )
            for name, motion in samples.items()
        }
    return result


READY_ARTWORK_SOURCES = (
    'harness/app/ready_reference_artwork.dart',
    'lib/utils/reference_artwork_source.dart',
    'lib/widgets/reusable_widgets/app_lottie.dart',
    'lib/screens/onboarding/wallet_ready_surface.dart',
    'lib/utils/wallet_ready_binding.dart',
    'lib/rearchitecture/utils/widgets/entry_field.dart')
CATALOG_CONTACT_SOURCE = 'harness/bin/readonly_catalog_contact.dart'
HOME_GOTO_CONTACT_SOURCES = (
    CATALOG_CONTACT_SOURCE,
    HOME_GOTO_CONTACT_FIXTURE,
    'harness/app/fixtures/send_warning_draft.dart',
    'lib/rearchitecture/utils/widgets/go_to_palette.dart')


def ready_artwork_sources(repo, value, tree, *, read_versioned_blob=None):
    """Bind new Ready renderers while retaining earlier producer requirements."""
    need(type(value) is dict and value.get('sha') == tree
         and value.get('truncated') is False
         and type(value.get('tree')) is list and len(value['tree']) <= 10000
         and all(type(item) is dict for item in value['tree']))
    if not any(item.get('path') == READY_ARTWORK_SOURCES[0] for item in value['tree']):
        return {}
    originals = (
        'lib/widgets/modular_widgets/help_widgets/originals_card.dart',
        'lib/widgets/modular_widgets/help_widgets/originals_tiles.dart',
        'lib/widgets/reusable_widgets/launch_film.dart',
    )
    return source_files(repo, value, tree,
        read_versioned_blob=read_versioned_blob,
        files=READY_ARTWORK_SOURCES + tuple(path for path in originals
            if any(item.get('path') == path for item in value['tree'])))


def git_blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode('ascii') + b'\0' + raw).hexdigest()


def exact_source_blob(read_blob, sha, *, max_size=MAX_WORKFLOW_SOURCE):
    need(callable(read_blob))
    value = read_blob(sha)
    content_cap = (MAX_WORKFLOW_RESPONSE if max_size == MAX_WORKFLOW_SOURCE
                   else MAX_VERSIONED_BLOB_RESPONSE)
    need(type(value) is dict and value.get('sha') == sha
         and value.get('encoding') == 'base64'
         and type(value.get('size')) is int
         and 0 < value['size'] <= max_size
         and type(value.get('content')) is str
         and 0 < len(value['content']) <= content_cap
         and re.fullmatch(r'[A-Za-z0-9+/=\n]+', value['content']) is not None)
    encoded = value['content'].replace('\n', '')
    raw = base64.b64decode(encoded, validate=True)
    need(len(raw) == value['size'] and base64.b64encode(raw).decode('ascii') == encoded)
    return raw


def source_files(repo, value, tree, *, read_workflow_blob=None,
                 read_versioned_blob=None, files=SOURCE_FILES):
    need(type(value) is dict and value.get('sha') == tree and value.get('truncated') is False
         and type(value.get('tree')) is list and len(value['tree']) <= 10000)
    entries = {}
    for item in value['tree']:
        if item.get('path') in files:
            need(item['path'] not in entries and item.get('mode') == '100644'
                 and item.get('type') == 'blob' and digest(item.get('sha'), 40))
            entries[item['path']] = item
    need(set(entries) == set(files))
    digests = {}
    for name in files:
        sha = entries[name]['sha']
        if name == WORKFLOW_SOURCE and read_workflow_blob is not None:
            # Read the exact producer blob even when the reader checks out a
            # different workflow revision for its own source-discovery controls.
            raw = exact_source_blob(read_workflow_blob, sha)
        else:
            raw = producer.read_original(repo / name, MAX_TREE)
            if (name in VERSIONED_INPUTS and read_versioned_blob is not None
                    and git_blob(raw) != sha):
                raw = exact_source_blob(read_versioned_blob, sha, max_size=(
                    MAX_CAPTURE_AGENT_SOURCE if name == CAPTURE_AGENT_SOURCE
                    else MAX_WORKFLOW_SOURCE))
        need(git_blob(raw) == sha)
        digests[name] = archive.sha(raw)
    return digests


def selected_job(value, head, run_id):
    need(type(value) is dict and type(value.get('jobs')) is list
         and type(value.get('total_count')) is int
         and value['total_count'] == len(value['jobs']) <= 50)
    jobs = [j for j in value['jobs'] if j.get('name') == JOB]
    need(len(jobs) == 1)
    job = jobs[0]
    need(type(job.get('id')) is int and 0 < job['id'] < 2**63
         and job.get('head_sha') == head and type(job.get('run_id')) is int
         and job['run_id'] == run_id and type(job.get('run_attempt')) is int
         and job['run_attempt'] == 1 and job.get('status') == 'completed'
         and job.get('conclusion') in ('success', 'failure', 'cancelled', 'timed_out'))
    need(all(j.get('status') == 'completed' and j.get('conclusion') == 'skipped'
             for j in value['jobs'] if j is not job))
    steps = job.get('steps')
    need(type(steps) is list and len(steps) <= 60)
    selected = []
    for name in (*PREFLIGHT, RUNTIME):
        found = [s for s in steps if s.get('name') == name]
        need(len(found) == 1 and found[0].get('status') == 'completed'
             and type(found[0].get('number')) is int)
        selected.append(found[0])
    need([s['number'] for s in selected] == sorted({s['number'] for s in selected})
         and all(s.get('conclusion') == 'success' for s in selected[:-1])
         and (job['conclusion'] != 'success' or selected[-1].get('conclusion') == 'success'))
    return job


def _vertical_bands(zipped, name, column, top, bottom):
    return _image_vertical_bands(zipped.read(name), column, top, bottom)


def _image_vertical_bands(data, column, top, bottom):
    encoded = base64.b64encode(data).decode('ascii')
    rows, channels = windows._png_crop(encoded, (column, column + 1), (top, bottom))
    if not windows._opaque(rows, channels):
        return []
    bands = [(top, rows[0])]
    for y, row in enumerate(rows[1:], top + 1):
        if row != bands[-1][1]:
            bands.append((y, row))
    return bands


def node_update_notice_geometry(raw, reference_dir):
    """Measure the notice fill at the original column and clear of reference text."""
    column, clear_column, top, bottom = 700, 980, 327, 620
    panel_top = 230
    fills = {'dark': (46, 48, 46), 'light': (255, 255, 255)}
    backgrounds = {'dark': (27, 28, 27), 'light': (234, 234, 234)}

    def ranges(bands):
        ends = [start for start, _ in bands[1:]] + [bottom]
        return [(start, end, tuple(color[:3]))
                for (start, color), end in zip(bands, ends)]

    def span(bands, fill):
        matches = [(start, end) for start, end, color in bands
                   if color == fill and top < start and end < bottom]
        if not matches:
            return None
        start, end = max(matches, key=lambda rows: rows[1] - rows[0])
        return [start, end - 1]

    def enclosing_panel(bands, notice, background):
        if notice is None:
            return None
        gaps = [(start, end) for start, end, color in bands
                if color == background and end - start >= 8]
        before = [end for _, end in gaps if end <= notice[0]]
        after = [start for start, _ in gaps if start > notice[1]]
        return [max(before), min(after) - 1] if before and after else None

    themes = {}
    clear_themes = {}
    panels = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme, fill in fills.items():
            name = f'30-set-node-{theme}.png'
            actual = zipped.read(name)
            reference = producer.read_original(reference_dir / name, producer.debug.entry.MAX_PNG)
            themes[theme] = dict(
                actual=span(ranges(_image_vertical_bands(actual, column, top, bottom)), fill),
                reference=span(ranges(_image_vertical_bands(reference, column, top, bottom)), fill))
            clear_bands = {label: ranges(_image_vertical_bands(data, clear_column, panel_top, bottom))
                           for label, data in (('actual', actual), ('reference', reference))}
            clear_themes[theme] = {label: span(bands, fill)
                                   for label, bands in clear_bands.items()}
            panels[theme] = {label: enclosing_panel(
                bands, clear_themes[theme][label], backgrounds[theme])
                for label, bands in clear_bands.items()}
    return dict(column=column, scan_rows=[top, bottom], themes=themes,
                clear_column=dict(column=clear_column, themes=clear_themes),
                enclosing_panel=dict(column=clear_column, scan_rows=[panel_top, bottom],
                                     themes=panels))


def addresses_card_comparison(raw, reference_dir):
    """Measure the edges of the three Addresses cards on the same column."""
    column, top, bottom = 700, 33, 700
    cards = ('members', 'contacts', 'account_chain')

    def spans(data):
        bands = _image_vertical_bands(data, column, top, bottom)
        if not bands or bands[0][1] != bands[-1][1]:
            return None
        background = bands[0][1]
        # Card dividers and text can interrupt the fill. A page gap is
        # at least eight rows of the surrounding page color.
        gaps = [(start, end) for (start, color), (end, _) in zip(bands, bands[1:])
                if color == background and (start == top or end - start >= 8)]
        if len(gaps) != len(cards):
            return None
        ends = [start for start, _ in gaps[1:]] + [bands[-1][0]]
        return {name: [gap_end, card_end]
                for name, (_, gap_end), card_end in zip(cards, gaps, ends)}

    themes = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme in producer.settings.THEMES:
            name = f'35-set-addresses-{theme}.png'
            reference = producer.read_original(reference_dir / name, producer.debug.entry.MAX_PNG)
            themes[theme] = dict(actual=spans(zipped.read(name)),
                                 reference=spans(reference))
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def home_goto_geometry(raw):
    """Measure the panel edge, visible caret and window edge of Go To."""
    column, top, bottom = 450, 440, 476
    themes = {}
    caption_bands = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme in producer.THEMES:
            name = f'05-home-goto-{theme}.png'
            caption_bands[theme] = [
                [row, list(color[:3])]
                for row, color in _vertical_bands(zipped, name, 600, 20, 36)
            ]
            bands = _vertical_bands(zipped, name, column, top, bottom)
            themes[theme] = None
            if not bands:
                continue
            footer = bands[0][1][:3]
            # A one-level blend change can occur within the light footer.
            for edge, edge_color in bands[1:]:
                if max(abs(a - b) for a, b in zip(footer, edge_color[:3])) < 4:
                    continue
                if top + 6 <= edge <= bottom - 3:
                    themes[theme] = dict(edge_row=edge, footer_rgb=list(footer),
                                         edge_rgb=list(edge_color[:3]))
                break
        caret = _ink_bounds(zipped, '05-home-goto', (428, 435), (132, 158),
                            lambda *difference: max(difference) >= 35,
                            relative_to_background=True)
    return dict(goto_footer=dict(column=column, scan_rows=[top, bottom], themes=themes),
                goto_caret=caret,
                goto_caption=dict(column=600, scan_rows=[20, 36], bands=caption_bands))


def home_notifications_geometry(raw):
    """Observe the settled tooltip fill along a column clear of label ink."""
    column, top, bottom = 65, 630, 700
    fills = {'dark': (54, 56, 54), 'light': (238, 240, 238)}
    themes = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme, fill in fills.items():
            bands = _vertical_bands(zipped, f'01-home-rest-{theme}.png',
                                    column, top, bottom)
            ends = [y for y, _ in bands[1:]] + [bottom]
            matching = [[start, end - 1] for (start, color), end in zip(bands, ends)
                        if tuple(color[:3]) == fill and end - start == 28
                        and top < start and end < bottom]
            themes[theme] = dict(status='unavailable')
            if len(matching) == 1:
                themes[theme] = dict(status='observed', fill_rows=matching[0])
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def home_expanded_tokens_header(raw):
    """Read the fill in the open Tokens header away from text and icons."""
    column, top, bottom = 1000, 285, 297
    themes = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme in producer.THEMES:
            bands = _vertical_bands(zipped, f'02-home-open-{theme}.png',
                                    column, top, bottom)
            themes[theme] = list(bands[0][1][:3]) if len(bands) == 1 else None
    return dict(column=column, scan_rows=[top, bottom], fill_rgb=themes)


def home_send_bounds(raw):
    """Locate the bright Send fill inside the Home rest action row."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        return _ink_bounds(
            zipped, '01-home-rest', (912, 1032), (82, 142),
            lambda *color: max(color) > 110 and max(color) - min(color) > 70,
        )


ORIGINALS_MAP_CROP = (616, 319, 758, 423)


def _map_gray_deviation(png):
    """Measure interior dot coverage and intensity against the tile background."""
    left, top, right, bottom = ORIGINALS_MAP_CROP
    encoded = base64.b64encode(png).decode('ascii')
    rows, channels = windows._png_crop(encoded, (left, right), (top, bottom))
    if not windows._opaque(rows, channels):
        return None
    # Sum RGB before dividing by three, to retain sub-level precision.
    levels = Counter(sum(row[i:i + 3]) for row in rows
                     for i in range(0, len(row), channels))
    background, _ = levels.most_common(1)[0]
    weighted_error = sum(abs(value - background) * count
                         for value, count in levels.items())
    return round(1000 * weighted_error / (3 * sum(levels.values())))


def _catalog_pixel_pair(zipped, reference_dir, screen, regions, *, sample_points=None):
    pairs = {}
    map_gray = {}
    for theme in producer.THEMES:
        name = f'{screen}-{theme}.png'
        actual = zipped.read(name)
        reference = producer.read_original(reference_dir / name, producer.debug.entry.MAX_PNG)
        pairs[theme] = windows.pixel_comparison(actual, reference, regions,
                                                sample_points=sample_points)
        if screen == '38-set-originals':
            map_gray[theme] = dict(actual=_map_gray_deviation(actual),
                                  reference=_map_gray_deviation(reference))
    result = dict(screen=screen, region_bounds=regions, pairs=pairs)
    if map_gray:
        result['map_gray_deviation_milli'] = dict(bounds=ORIGINALS_MAP_CROP,
                                                 themes=map_gray)
    return result


def _catalog_pair_names(files):
    return (name.removesuffix('-dark.png') for name in files
            if name.endswith('-dark.png'))


def home_pixel_comparisons(raw, reference_dir):
    """Compare the verified originals without changing visual verdicts."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for screen in ('01-home-rest', '02-home-open', '03-home-hidden', '05-home-goto'):
            rail_end = 204 if screen == '02-home-open' else 60
            regions = dict(caption=(0, 0, 1280, 32), rail=(0, 32, rail_end, 780),
                hero=(rail_end, 38, 1264, 190), body=(rail_end, 200, 1264, 724),
                status=(rail_end, 724, 1264, 780))
            yield _catalog_pixel_pair(zipped, reference_dir, screen, regions)


def details_pixel_comparisons(raw, reference_dir):
    """Compare each original Details pair against its numbered reference."""
    regions = dict(caption=(0, 0, 1280, 32), rail=(0, 32, 60, 780),
                   content=(60, 32, 1280, 724), status=(60, 724, 1280, 780))
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for screen in _catalog_pair_names(producer.details.FILES):
            crop = _originals_pixel_regions(regions) if screen == '38-set-originals' else regions
            yield _catalog_pixel_pair(zipped, reference_dir, screen, crop)


def settings_pixel_comparisons(raw, reference_dir, *, files=None):
    """Compare the seven Settings sections with separate menu and body counts."""
    regions = dict(caption=(0, 0, 1280, 32), rail=(0, 32, 60, 780),
                   settings_menu=(60, 32, 260, 724), content=(260, 32, 1280, 724),
                   status=(60, 724, 1280, 780))
    # Split at the tracked reference card boundaries. These crops measure
    # different fixture states as well as visual differences.
    section_crops = {
        '30-set-node': dict(nodes=(260, 32, 1280, 267),
                            update=(260, 267, 1280, 522),
                            chain_title=(260, 522, 1020, 566),
                            chain_summary=(1020, 522, 1236, 566),
                            chain_chevron=(1236, 522, 1280, 566),
                            other_disclosures=(260, 566, 1280, 678),
                            below_cards=(260, 678, 1280, 724)),
        '35-set-addresses': dict(members=(260, 32, 1280, 326),
                                 contacts=(260, 326, 1280, 489),
                                 chain_title=(260, 489, 1080, 533),
                                 chain_summary=(1080, 489, 1236, 533),
                                 chain_chevron=(1236, 489, 1280, 533),
                                 below_cards=(260, 533, 1280, 724)),
    }
    sample_points = {
        '30-set-node': dict(node_table=(700, 220), update_card=(700, 298),
                            update_notice=(700, 450), first_disclosure=(700, 546),
                            last_disclosure=(700, 658)),
        '35-set-addresses': dict(last_member=(700, 280), member_gap=(700, 319),
                                 last_contact=(700, 449), contact_gap=(700, 482),
                                 chain_card=(700, 510), after_chain=(700, 545)),
    }
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for screen in _catalog_pair_names(producer.settings.FILES if files is None else files):
            crop = regions
            if screen in section_crops:
                crop = {name: bounds for name, bounds in regions.items() if name != 'content'}
                crop.update(section_crops[screen])
            yield _catalog_pixel_pair(zipped, reference_dir, screen, crop,
                                      sample_points=sample_points.get(screen))


def _originals_pixel_regions(regions):
    # Partition the same content area at the reference gallery's row breaks.
    chrome = {name: bounds for name, bounds in regions.items() if name != 'content'}
    return dict(**chrome, settings_menu=(60, 32, 260, 724),
                licences=(260, 32, 1280, 248), gallery_header=(260, 248, 1280, 315),
                launch_tile=(260, 315, 444, 427), globe_tile=(444, 315, 606, 427),
                map_tile=(606, 315, 768, 427), pillar_tile=(768, 315, 930, 427),
                sentinel_tile=(930, 315, 1092, 427), token_tile=(1092, 315, 1280, 427),
                gallery_labels=(260, 427, 1280, 512), gallery_footer=(260, 512, 1280, 563),
                below_gallery=(260, 563, 1280, 724))


def staking_empty_bands(raw):
    """Observe the strip and both cards in the verified Earn archive."""
    column, top, bottom = 1000, 35, 711
    themes = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for theme in producer.details.THEMES:
            name = '15-staking-empty-' + theme + '.png'
            bands = _vertical_bands(zipped, name, column, top, bottom)
            themes[theme] = dict(status='unavailable')
            if len(bands) != 9:
                continue
            positions, colors = zip(*bands)
            base, card, divider = colors[0], colors[1], colors[4]
            if (base == card or divider in (base, card) or
                    colors != (base, card, base, card, divider, card, base, card, base)):
                continue
            themes[theme] = dict(status='observed', summary=list(positions[1:3]),
                stakes=[positions[3], positions[6]], divider=list(positions[4:6]),
                rewards=list(positions[7:9]))
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def _ink_bounds(zipped, screen, columns, lines, matches, *, minimum_fill=0,
                relative_to_background=False):
    left, right = columns
    top, bottom = lines
    themes = {}
    for theme in producer.settings.THEMES:
        name = f'{screen}-{theme}.png'
        encoded = base64.b64encode(zipped.read(name)).decode('ascii')
        rows, channels = windows._png_crop(encoded, columns, lines)
        points = []
        if windows._opaque(rows, channels):
            background = rows[0][:3] if relative_to_background else None
            for y, row in enumerate(rows, top):
                for index in range(0, len(row), channels):
                    color = tuple(row[index:index + 3])
                    channels_to_match = color if background is None else tuple(
                        abs(channel - base) for channel, base in zip(color, background))
                    if matches(*channels_to_match):
                        points.append((color, left + index // channels, y))
        themes[theme] = None
        if points and minimum_fill:
            # Isolate the solid tint from pink text and anti-aliased edges.
            color, count = Counter(color for color, _, _ in points).most_common(1)[0]
            points = [point for point in points if point[0] == color] if count >= minimum_fill else []
        if points:
            _, xs, ys = zip(*points)
            x1, x2, y1, y2 = min(xs), max(xs), min(ys), max(ys)
            if left < x1 <= x2 < right - 1 and top < y1 <= y2 < bottom - 1:
                themes[theme] = dict(left=x1, top=y1, right=x2, bottom=y2)
    return themes


def _selection_ink(red, green, blue):
    return green - red >= 45 and green - blue >= 31


def _update_badge_ink(red, green, blue):
    return red - green >= 20 and blue - green >= 10


def _node_table_rows(zipped):
    column, top, bottom = 700, 35, 330
    themes = {}
    for theme in producer.settings.THEMES:
        bands = _vertical_bands(zipped, f'30-set-node-{theme}.png', column, top, bottom)[:9]
        themes[theme] = None
        if len(bands) != 9:
            continue
        positions, colors = zip(*bands)
        base, card, divider = colors[:3]
        if (base != card and divider not in (base, card)
                and colors == (base, card, divider, card, divider, card, divider, card, base)):
            themes[theme] = list(positions[2:9:2])
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def _about_card_bands(zipped):
    column, top, bottom = 700, 35, 279
    themes = {}
    for theme in producer.settings.THEMES:
        bands = _vertical_bands(zipped, f'36-set-about-{theme}.png', column, top, bottom)
        themes[theme] = None
        if len(bands) != 9:
            continue
        positions, colors = zip(*bands)
        base, card = colors[:2]
        if base != card and colors == (base, card) * 4 + (base,):
            themes[theme] = dict(version=list(positions[1:3]), links=list(positions[3:5]),
                computer=list(positions[5:7]), licences=list(positions[7:9]))
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def _wallet_panel_fills(zipped):
    column, wallets_row, maintenance_row = 650, 325, 392
    themes = {}
    for theme in producer.settings.THEMES:
        bands = _vertical_bands(zipped, f'33-set-wallet-{theme}.png',
                                column, wallets_row, maintenance_row + 1)
        themes[theme] = (dict(wallets=list(bands[0][1][:3]),
                              maintenance=list(bands[-1][1][:3])) if bands else None)
    return dict(column=column, rows=[wallets_row, maintenance_row], themes=themes)


def settings_catalog_geometry(raw):
    """Measure the Settings rows, selectors and panels after verification."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        return dict(
            address_selector_bounds=_ink_bounds(
                zipped, '35-set-addresses', (288, 321), (90, 315), _selection_ink),
            node_selector_bounds=_ink_bounds(
                zipped, '30-set-node', (284, 319), (88, 256), _selection_ink),
            node_table_rows=_node_table_rows(zipped),
            wallet_panel_fills=_wallet_panel_fills(zipped),
            about_card_bands=_about_card_bands(zipped),
            about_update_badge_bounds=_ink_bounds(
                zipped, '36-set-about', (740, 1248), (47, 95), _update_badge_ink,
                minimum_fill=300),
        )


def plasma_bolt_bounds(raw, screen):
    """Measure solid white bolt ink in the verified Plasma well."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        return _ink_bounds(zipped, screen, (190, 270), (76, 160),
                           lambda red, green, blue: min(red, green, blue) >= 252)


def _nodes_table_edges(zipped, screen):
    column, top, bottom = 900, 100, 181
    themes = {}
    for theme in producer.navigation.THEMES:
        bands = _vertical_bands(zipped, f'{screen}-{theme}.png', column, top, bottom)
        themes[theme] = None
        if len(bands) != 5:
            continue
        rows, colors = zip(*bands)
        card, base, line = colors[0], colors[1], colors[3]
        if line not in (card, base) and colors == (card, base, card, line, card):
            themes[theme] = dict(strip_end=rows[1], list_start=rows[2],
                                 tab_divider=rows[3], column_headings_start=rows[4])
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def navigation_component_geometry(raw):
    """Measure strip boundaries, the Pillars table and its expanded row."""
    column, top, bottom = 900, 100, 125
    detail_column, detail_top, detail_bottom = 1100, 186, 398
    strips = {}
    pillar_rows = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for screen in ('23-tokens', '28-az'):
            themes = {}
            for theme in producer.navigation.THEMES:
                name = f'{screen}-{theme}.png'
                bands = _vertical_bands(zipped, name, column, top, bottom)
                themes[theme] = None
                if len(bands) == 3 and bands[0][1] == bands[2][1]:
                    themes[theme] = dict(strip_end=bands[1][0], list_start=bands[2][0])
            strips[screen] = themes
        pillars = _nodes_table_edges(zipped, '16-pillars')
        badge = _ink_bounds(zipped, '16-pillars', (130, 221), (201, 239),
                            lambda red, green, blue: green - red > 10 and green - blue > 7)
        detail_ink = {
            name: _ink_bounds(zipped, '16-pillars', area, (243, 263),
                              lambda *difference: max(difference) >= 40,
                              relative_to_background=True)
            for name, area in (('momentums_label', (660, 750)),
                               ('momentums_value', (750, 967)))
        }
        for theme in producer.navigation.THEMES:
            bands = _vertical_bands(zipped, f'16-pillars-{theme}.png',
                                    detail_column, detail_top, detail_bottom)
            pillar_rows[theme] = ([[start, *color[:3]] for start, color in bands]
                                  if 2 <= len(bands) <= 10 else None)
    return dict(strip_boundaries=dict(column=column, scan_rows=[top, bottom], screens=strips),
                pillar_table_edges=pillars, pillar_owned_badge_bounds=badge,
                pillar_detail_ink=detail_ink,
                pillar_row_bands=dict(column=detail_column,
                    scan_rows=[detail_top, detail_bottom], themes=pillar_rows))


def details_licence_header_chevrons(raw):
    """Measure the three header icons on the verified Licences screen."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        return {
            heading: _ink_bounds(
                zipped, '37-set-licences', (1232, 1253), (center - 9, center + 9),
                lambda red, green, blue: max(red, green, blue) >= 8,
                relative_to_background=True)
            for heading, center in (('links', 58), ('computer', 114), ('licences', 170))
        }


def _details_licence_dividers(zipped, screen='37-set-licences', scan_rows=(188, 645)):
    column = 700
    top, bottom = scan_rows
    themes = {}
    for theme in producer.details.THEMES:
        name = f'{screen}-{theme}.png'
        encoded = base64.b64encode(zipped.read(name)).decode('ascii')
        rows, channels = windows._png_crop(encoded, (column, column + 1), (top, bottom))
        themes[theme] = None
        if windows._opaque(rows, channels):
            background = Counter(bytes(row[:3]) for row in rows).most_common(1)[0][0]
            spans = []
            for y, row in enumerate(rows, top):
                if max(abs(value - base) for value, base in zip(row, background)) < 2:
                    continue
                # A one-pixel divider at a fractional position can cover two rows.
                if spans and spans[-1][1] + 1 == y:
                    spans[-1][1] = y
                else:
                    spans.append([y, y])
            if len(spans) <= 16 and all(end - start <= 2 for start, end in spans):
                themes[theme] = spans
    return themes


def _details_plasma_footer_clear(zipped):
    left, right = 71, 260
    themes = {}
    for theme in producer.details.THEMES:
        encoded = base64.b64encode(zipped.read(f'22-plasma-fuse-{theme}.png')).decode('ascii')
        rows, channels = windows._png_crop(encoded, (left, right), (271, 295))
        themes[theme] = None
        if windows._opaque(rows, channels):
            background = rows[0][:channels] * (right - left)
            themes[theme] = all(row == background for row in rows)
    return themes


def _details_originals_footer_rows(zipped):
    column, top, bottom = 1000, 500, 570
    themes = {}
    for theme in producer.details.THEMES:
        bands = _vertical_bands(zipped, f'38-set-originals-{theme}.png', column, top, bottom)
        themes[theme] = None
        if len(bands) != 4:
            continue
        rows, colors = zip(*bands)
        card, rule, footer, base = colors
        if footer == card and card != base and rule not in (card, base):
            themes[theme] = dict(divider=list(rows[1:3]), card_end=rows[3])
    return dict(column=column, scan_rows=[top, bottom], themes=themes)


def _details_plasma_fuse_geometry(zipped):
    distances = (22, 38, 54, 66)
    center = 230
    halo_left, halo_right = center - distances[-1], center + distances[-1] + 1
    action_left, action_right = 1141, 1262
    action_bands = ((264, 290), (343, 369), (388, 414), (433, 459))
    themes = {}
    for theme in producer.details.THEMES:
        encoded = base64.b64encode(zipped.read(f'22-plasma-fuse-{theme}.png')).decode('ascii')
        halo, channels = windows._png_crop(encoded, (halo_left, halo_right), (114, 122))
        samples = None
        if windows._opaque(halo, channels):
            samples = [
                [round(sum(row[(x - halo_left) * channels + channel] for row in halo
                           for x in (center - distance, center + distance)) / (2 * len(halo)))
                 for channel in range(3)]
                for distance in distances
            ]
        start, end = action_bands[0][0], action_bands[-1][1]
        actions, channels = windows._png_crop(encoded, (action_left, action_right), (start, end))
        bounds = []
        for index, (top, bottom) in enumerate(action_bands):
            band = actions[top - start:bottom - start]
            left = action_left if index == 0 else 1165
            painted = []
            if windows._opaque(band, channels):
                for row in band:
                    background = row[-channels:][:3]
                    for x in range(left, action_right - 1):
                        offset = (x - action_left) * channels
                        if any(abs(value - base) >= 5
                               for value, base in zip(row[offset:offset + 3], background)):
                            painted.append(x)
            bounds.append([min(painted), max(painted) + 1] if painted else None)
        themes[theme] = dict(halo_rgb=samples, cancel_columns=bounds)
    return dict(halo_distances=list(distances), themes=themes)


def details_component_geometry(raw):
    """Measure the changed components together from the original Details archive."""
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        return dict(
            licence_divider_spans=_details_licence_dividers(zipped),
            originals_licence_divider_spans=_details_licence_dividers(
                zipped, '38-set-originals', (67, 173)),
            originals_footer_rows=_details_originals_footer_rows(zipped),
            receive_qsr_mark=_ink_bounds(zipped, '10-receive-qr', (814, 849), (235, 274),
                lambda red, green, blue: blue - red > 90 and blue - green > 25),
            receive_qsr_label=_ink_bounds(zipped, '10-receive-qr', (850, 906), (241, 265),
                lambda red, green, blue: min(red, green, blue) >= 80, relative_to_background=True),
            plasma_footer_clear=_details_plasma_footer_clear(zipped),
            plasma_fuse=_details_plasma_fuse_geometry(zipped),
        )


def details_transfer_chip_rows(raw):
    """Read the address chip's painted rows in the verified QR and Zap views."""
    left, right, top, bottom = 860, 974, 44, 84
    result = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        for name in ('10-receive-qr', '11-zap-form'):
            themes = {}
            for theme in producer.details.THEMES:
                encoded = base64.b64encode(zipped.read(f'{name}-{theme}.png')).decode('ascii')
                rows, channels = windows._png_crop(encoded, (left, right), (top, bottom))
                themes[theme] = None
                if not windows._opaque(rows, channels):
                    continue
                background = rows[0][:channels] * (right - left)
                if (rows[0] != background or rows[-1] != background
                        or any(row[:channels] != background[:channels]
                               or row[-channels:] != background[-channels:] for row in rows)):
                    continue
                painted = [y for y, row in enumerate(rows, top) if row != background]
                if painted and len(painted) == painted[-1] - painted[0] + 1:
                    themes[theme] = [painted[0], painted[-1] + 1]
            result[name] = themes
    return result


def artifact(listing, name, head, run_id):
    need(type(listing) is dict and type(listing.get('artifacts')) is list
         and type(listing.get('total_count')) is int
         and listing.get('total_count') == len(listing['artifacts']) <= 20)
    selected = [a for a in listing['artifacts'] if a.get('name') == name]
    need(len(selected) == 1)
    value = selected[0]
    need(value.get('expired') is False and type(value.get('id')) is int and value['id'] > 0
         and type(value.get('workflow_run', {}).get('id')) is int
         and value['workflow_run']['id'] == run_id
         and value['workflow_run'].get('head_sha') == head
         and type(value.get('digest')) is str and re.fullmatch('sha256:[a-f0-9]{64}', value['digest'])
         and type(value.get('size_in_bytes')) is int and value['size_in_bytes'] > 0)
    return value


def encode_notice(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def wallet_inspection_frames(summary):
    title = 'Retained readonly wallet inspection'
    if len(encode_notice(summary)) <= MAX_NOTICE_BYTES:
        return [(title, summary)]

    overview, frames = dict(summary), []
    pins = {key: summary[key] for key in ('source_head', 'source_tree',
        'source_run_id', 'source_attempt', 'archive_sha256', 'manifest_sha256',
        'producer_job_id')}
    for family in ('home', 'settings'):
        field = family + '_seam_observations'
        if field in overview:
            frames.append((f'Retained readonly {family} seam observations',
                dict(schema=1, scope='retained_readonly_' + field,
                     **pins, **{field: overview.pop(field)})))
    return [(title, overview), *frames]


def emit(title, value):
    raw = encode_notice(value)
    need(len(raw) <= MAX_NOTICE_BYTES)
    print('::notice title=' + title + '::' + raw.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'), flush=True)


def main(parent=None):
    global PHASE
    parent = os.environ if parent is None else parent
    need(parent.get('GITHUB_ACTIONS') == 'true' and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
         and parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
         and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius')
    text, head = parent.get('WALLET_INSPECT_RUN', ''), parent.get('WALLET_INSPECT_HEAD', '')
    need(type(text) is str and re.fullmatch('[1-9][0-9]{0,19}', text) and digest(head, 40))
    run_id = int(text)
    # Allow 15 metadata and artifact requests plus 25 exact producer blobs,
    # including the workflow. The metadata reads after transport still apply.
    client = archive.Client(parent.get('GH_TOKEN'), max_calls=40)
    PHASE = 'producer_metadata'
    run = client.json('/actions/runs/' + text)
    need(type(run.get('id')) is int and run['id'] == run_id and run.get('head_sha') == head
         and type(run.get('run_attempt')) is int and run['run_attempt'] == 1
         and run.get('workflow_id') == 381413107 and run.get('event') == 'workflow_dispatch'
         and run.get('status') == 'completed' and run.get('repository', {}).get('full_name') == 'edgepillar/syrius')
    commit = client.json('/git/commits/' + head)
    need(commit.get('sha') == head and digest(commit.get('tree', {}).get('sha'), 40))
    tree = commit['tree']['sha']
    PHASE = 'producer_source'
    repo = Path(parent['GITHUB_WORKSPACE'])
    producer_tree = decode(client.read(
        archive.API + '/git/trees/' + tree + '?recursive=1', cap=MAX_TREE))
    @cache
    def read_blob(blob):
        return decode(client.read(
            archive.API + '/git/blobs/' + blob, cap=MAX_VERSIONED_BLOB_RESPONSE))

    source_digests = source_files(repo, producer_tree, tree,
        read_workflow_blob=read_blob, read_versioned_blob=read_blob)
    source_digests.update(ready_artwork_sources(repo, producer_tree, tree,
        read_versioned_blob=read_blob))
    has_catalog_contact = any(item.get('path') == CATALOG_CONTACT_SOURCE
                              for item in producer_tree['tree'])
    jobs = client.json('/actions/runs/' + text + '/attempts/1/jobs?per_page=50')
    job = selected_job(jobs, head, run_id)
    need((run.get('conclusion') == 'success') is (job['conclusion'] == 'success'))
    PHASE = 'lab_artifact_metadata'
    listing = client.json('/actions/runs/' + text + '/artifacts?per_page=20')

    def download(item, cap):
        need(item['size_in_bytes'] <= cap)
        location = client.read(archive.API + '/actions/artifacts/' + str(item['id']) + '/zip', redirect=True)
        return client.read(location, authenticated=False, cap=cap)

    root_item = artifact(listing, 'chain321-native-' + head + '-' + text + '-1', head, run_id)
    PHASE = 'lab_artifact_transport'
    lab_bytes = download(root_item, archive.MAX_ARCHIVE)
    PHASE = 'lab_artifact_contents'
    lab, lab_sha = archive.unpack(lab_bytes,
        root_item['digest'][7:], root_item['size_in_bytes'])
    PHASE = 'lab_artifact_closure'
    lab_summary = owned_lab(lab, head, tree, run_id)
    lab_summary.update(archive_sha256=root_item['digest'][7:], manifest_sha256=lab_sha)
    if 'send_warning_node_fixture' in lab:
        fixture = producer.send_warning_window
        fixture_sources = ('tool/ci/send_warning_window.py',
                           'harness/app/fixtures/send_warning_draft.dart', *fixture.SOURCE_PINS)
        if has_catalog_contact:
            fixture_sources += (CATALOG_CONTACT_SOURCE,)
        source_digests.update(source_files(repo, producer_tree, tree,
            read_versioned_blob=read_blob, files=fixture_sources))
        need(all(source_digests[name] == pin for name, pin in fixture.SOURCE_PINS.items()))
    PHASE = 'wallet_artifact'
    name = 'wallet-inspection-' + head + '-' + text + '-1'
    child = [v for v in listing['artifacts'] if v.get('name') == name]
    if not child:
        need(lab['success'] is False and job['conclusion'] != 'success')
        receipt = lab.get('wallet_inspection')
        need(receipt is None or type(receipt) is dict and receipt.get('manifest_sha256') is None)
        summary = dict(schema=1, scope='retained_readonly_wallet_inspection',
            source_head=head, source_tree=tree, source_run_id=run_id, source_attempt=1,
            artifact_reported_success=False, native_inspection_qualified=False,
            wallet_artifact_status='UNAVAILABLE', verified_png_count=0,
            inspection_only=True, runtime_started=False, wallet_qualified=False,
            seed_admitted=False, financial_send_qualified=False, visual_matches=0)
    else:
        item = artifact(listing, name, head, run_id)
        original = lab.get('wallet_inspection')
        need(type(original) is dict and type(original.get('captured_pages')) is int)
        zero_captures = original['captured_pages'] == 0
        cap = producer.MAX_MANIFEST + 65536 if zero_captures else MAX_ARCHIVE
        summary = unpack(download(item, cap), item['digest'][7:], item['size_in_bytes'],
            head, tree, run_id, lab, lab_summary)
        expected_pages = 0 if 'sampling_scope' in summary else 24
        summary['native_inspection_qualified'] = bool(summary['artifact_reported_success']
            and summary['original_lab_closure_qualified']
            and summary['verified_png_count'] == expected_pages
            and job['conclusion'] == 'success')
    need(job['conclusion'] != 'success' or summary['native_inspection_qualified'])
    catalog = catalog_index = viewport_observation = None
    catalog_comparisons = []
    reference_head = parent.get('WALLET_REFERENCE_HEAD')
    reference = summary.pop('_home_catalog_reference', None)
    settings_reference = summary.pop('_settings_catalog_reference', None)
    navigation_reference = summary.pop('_navigation_catalog_reference', None)
    details_reference = summary.pop('_details_catalog_reference', None)
    viewport_reference = summary.pop('_viewport_reference', None)
    seams_only = summary.get('sampling_scope') == producer.SURFACE_SEAMS_FAMILY + '-only'
    if seams_only:
        need(all(value is None for value in
                 (reference, settings_reference, navigation_reference, details_reference, viewport_reference))
             and listing['total_count'] == 2
             and {item['name'] for item in listing['artifacts']} == {name, root_item['name']})
        PHASE = 'surface_source_metadata'
        source_digests.update(source_files(repo, producer_tree, tree, files=SURFACE_SEAM_SOURCES))
    if 'aged_fuse_fixture' in summary:
        PHASE = 'aged_fuse_source_metadata'
        source_digests.update(source_files(repo, producer_tree, tree,
            read_versioned_blob=read_blob, files=AGED_FUSE_SOURCES))
    if summary['native_inspection_qualified'] and not seams_only:
        need(sum(value is not None for value in
            (reference, settings_reference, navigation_reference, details_reference)) == 1)
        if details_reference is not None:
            PHASE = 'details_catalog_artifact'
            schema = details_reference['schema']
            scripts = producer.details.catalog_screens(schema)
            script_paths = {name: 'harness/screens/' + producer.details.catalog_script_name(schema, name)
                            for name in scripts}
            if schema in (producer.details.FAMILY_SCHEMAS['earn'],
                          producer.details.FAMILY_SCHEMAS['sentinel-fixture'],
                          producer.details.FAMILY_SCHEMAS['swap-start'],
                          producer.details.FAMILY_SCHEMAS['wallet-ready'],
                          producer.details.FAMILY_SCHEMAS['send-warn'],
                          producer.details.FAMILY_SCHEMAS['home-zap-preview'],
                          producer.details.NODE_VERIFIED_SCHEMA,
                          producer.details.SETTINGS_REVIEW_SCHEMA,
                          producer.details.SEND_CATALOG_SCHEMA):
                fixture_sources = {
                    producer.details.FAMILY_SCHEMAS['sentinel-fixture']: SENTINEL_FIXTURE_SOURCES,
                    producer.details.FAMILY_SCHEMAS['home-zap-preview']: HOME_ZAP_PREVIEW_SOURCES,
                    producer.details.SETTINGS_REVIEW_SCHEMA: (
                        CATALOG_CONTACT_SOURCE, 'harness/app/fixtures/send_warning_draft.dart'),
                }.get(schema, ())
                source_digests.update(source_files(repo, producer_tree, tree,
                    read_versioned_blob=read_blob, files=fixture_sources + tuple(script_paths.values())))
            item = artifact(listing, 'details-catalog-' + head + '-' + text + '-1', head, run_id)
            pins = {name: source_digests[path] for name, path in script_paths.items()}
            catalog_archive = download(item, producer.details.MAX_ARCHIVE)
            catalog = producer.details.unpack(catalog_archive,
                item['digest'][7:], item['size_in_bytes'], head, tree, run_id,
                details_reference, pins)
            if '10-receive-qr-dark.png' in catalog['filenames']:
                catalog['transfer_address_chip_rows'] = details_transfer_chip_rows(catalog_archive)
            if '22-plasma-fuse-dark.png' in catalog['filenames']:
                catalog['plasma_bolt_bounds'] = plasma_bolt_bounds(catalog_archive, '22-plasma-fuse')
            if '37-set-licences-dark.png' in catalog['filenames']:
                catalog['licence_header_chevrons'] = details_licence_header_chevrons(catalog_archive)
            if (producer.details.family_matches('node-verified', schema)
                    and reference_head is not None):
                need(digest(reference_head, 40))
                reference_dir = repo / 'mockups/redesign/shots'
                catalog_comparisons = list(settings_pixel_comparisons(
                    catalog_archive, reference_dir, files=catalog['filenames']))
                catalog['node_update_notice_geometry'] = node_update_notice_geometry(
                    catalog_archive, reference_dir)
                if '35-set-addresses-dark.png' in catalog['filenames']:
                    catalog['addresses_card_bands'] = addresses_card_comparison(
                        catalog_archive, reference_dir)
            if {'10-receive-qr-dark.png', '22-plasma-fuse-dark.png',
                    '37-set-licences-dark.png'} <= set(catalog['filenames']):
                catalog['component_geometry'] = details_component_geometry(catalog_archive)
            if schema == producer.details.FAMILY_SCHEMAS['details'] and reference_head is not None:
                need(digest(reference_head, 40))
                catalog_comparisons = list(details_pixel_comparisons(
                    catalog_archive, repo / 'mockups/redesign/shots'))
            if schema == producer.details.FAMILY_SCHEMAS['earn']:
                catalog['staking_empty_bands'] = staking_empty_bands(catalog_archive)
            if schema == producer.details.FAMILY_SCHEMAS['sentinel-fixture']:
                with zipfile.ZipFile(io.BytesIO(catalog_archive)) as zipped:
                    catalog['sentinel_table_edges'] = _nodes_table_edges(zipped, '18-sentinels')
            if schema == producer.details.FAMILY_SCHEMAS['wallet-ready']:
                with zipfile.ZipFile(io.BytesIO(catalog_archive)) as zipped:
                    captures = {theme: base64.b64encode(
                        zipped.read(f'47-wallet-ready-{theme}.png')).decode('ascii')
                        for theme in producer.THEMES}
                    catalog['primary_gradient'] = {theme: windows.primary_gradient_error(
                        encoded, (403, 464, 877, 510)) for theme, encoded in captures.items()}
                    catalog['completed_step_bounds'] = {
                        theme: windows.completed_step_bounds(encoded, 'wallet-ready')
                        for theme, encoded in captures.items()}
        elif navigation_reference is not None:
            PHASE = 'navigation_catalog_artifact'
            item = artifact(listing, 'navigation-catalog-' + head + '-' + text + '-1', head, run_id)
            pins = {name: source_digests['harness/screens/' + name + '.txt']
                for name in producer.navigation.SCREENS}
            catalog_archive = download(item, producer.navigation.MAX_ARCHIVE)
            catalog = producer.navigation.unpack(catalog_archive,
                item['digest'][7:], item['size_in_bytes'], head, tree, run_id,
                navigation_reference, pins)
            catalog['plasma_bolt_bounds'] = plasma_bolt_bounds(catalog_archive, '21-plasma')
            catalog['component_geometry'] = navigation_component_geometry(catalog_archive)
        elif settings_reference is not None:
            PHASE = 'settings_catalog_artifact'
            if has_catalog_contact:
                source_digests.update(source_files(repo, producer_tree, tree,
                    read_versioned_blob=read_blob, files=(CATALOG_CONTACT_SOURCE,
                        'harness/app/fixtures/send_warning_draft.dart')))
            item = artifact(listing, 'settings-catalog-' + head + '-' + text + '-1', head, run_id)
            pins = {name: source_digests['harness/screens/' + name + '.txt']
                for name in producer.settings.SCREENS}
            catalog_archive = download(item, producer.settings.MAX_ARCHIVE)
            catalog = producer.settings.unpack(catalog_archive,
                item['digest'][7:], item['size_in_bytes'], head, tree, run_id,
                settings_reference, pins)
            catalog.update(settings_catalog_geometry(catalog_archive))
            if reference_head is not None:
                need(digest(reference_head, 40))
                catalog_comparisons = list(settings_pixel_comparisons(
                    catalog_archive, repo / 'mockups/redesign/shots'))
        else:
            PHASE = 'home_catalog_artifact'
            need(reference is not None)
            if (has_catalog_contact
                    and reference['schema'] == producer.HOME_CAPTURE_SCHEMAS['home']):
                source_digests.update(source_files(
                    repo, producer_tree, tree, read_versioned_blob=read_blob,
                    files=HOME_GOTO_CONTACT_SOURCES))
            if reference['schema'] == producer.HOME_BELL_CAPTURE_SCHEMA:
                source_digests.update(source_files(repo, producer_tree, tree,
                    files=(producer.HOME_BELL_SCRIPT.as_posix(),)))
            item = artifact(listing, 'home-catalog-' + head + '-' + text + '-1', head, run_id)
            catalog_archive = download(item, MAX_HOME_ARCHIVE)
            catalog = unpack_home_catalog(catalog_archive, item['digest'][7:],
                item['size_in_bytes'], head, tree, run_id, reference,
                home_script_source_pins(source_digests, reference['schema']))
            if 'sync_pulse' in catalog:
                source_digests.update(source_files(repo, producer_tree, tree,
                    read_versioned_blob=read_blob,
                    files=('lib/widgets/shell/strip/status_dot.dart',)))
            if 'segment_motion' in catalog:
                source_digests.update(source_files(repo, producer_tree, tree,
                    read_versioned_blob=read_blob,
                    files=('lib/rearchitecture/utils/widgets/segment.dart',)))
            if reference['schema'] == producer.HOME_CAPTURE_SCHEMAS['home']:
                source_digests.update(source_files(repo, producer_tree, tree,
                    read_versioned_blob=read_blob, files=(HOME_FIELD_SOURCE,)))
                catalog.update(home_goto_geometry(catalog_archive))
                catalog['notifications_tooltip'] = home_notifications_geometry(catalog_archive)
                catalog['expanded_tokens_header'] = home_expanded_tokens_header(catalog_archive)
                catalog['home_send_bounds'] = home_send_bounds(catalog_archive)
                if reference_head is not None:
                    need(digest(reference_head, 40))
                    catalog_comparisons = list(home_pixel_comparisons(
                        catalog_archive, repo / 'mockups/redesign/shots'))
        catalog_index = dict(artifact_id=item['id'], archive_bytes=item['size_in_bytes'],
            images=catalog_image_pins(catalog_archive, catalog))
        del catalog_archive
        viewport_name = 'viewport-observation-' + head + '-' + text + '-1'
        PHASE = 'viewport_artifact'
        sampling_scope = summary.get('sampling_scope')
        if sampling_scope is not None:
            need(viewport_reference is None
                 and not any(v.get('name') == viewport_name for v in listing['artifacts']))
            family = sampling_scope.removesuffix('-only')
            if family in producer.HOME_CAPTURE_SCHEMAS:
                need(reference is not None
                     and reference['schema'] == producer.HOME_CAPTURE_SCHEMAS[family])
            elif family == 'settings-catalog':
                need(settings_reference is not None)
            else:
                need(details_reference is not None and producer.details.family_matches(
                     family, details_reference['schema']))
        else:
            need(viewport_reference is not None)
            item = artifact(listing, viewport_name, head, run_id)
            viewport_observation = producer.viewport.unpack(download(item, producer.viewport.MAX_ARCHIVE),
                item['digest'][7:], item['size_in_bytes'], head, tree, run_id, viewport_reference,
                source_digests['harness/bin/readonly_viewport_probe.dart'])
    PHASE = 'metadata_after'
    after = client.json('/actions/runs/' + text)
    need(all(after.get(k) == run.get(k) for k in ('id', 'head_sha', 'run_attempt', 'workflow_id', 'status', 'conclusion')))
    after_job = selected_job(client.json('/actions/runs/' + text + '/attempts/1/jobs?per_page=50'), head, run_id)
    need(all(after_job.get(k) == job.get(k) for k in ('id', 'head_sha', 'run_id', 'run_attempt', 'status', 'conclusion')))
    PHASE = 'emit'
    layout = summary.pop('_layout_observation', None)
    verified_sources = len(source_digests)
    for component, frame in archive.observation_frames(lab_summary):
        emit('Readonly inspection parent' + (' ' + component if component else ''), frame)
    summary.update(verified_viewport_png_count=4 if viewport_observation is not None else 0,
        verified_catalog_png_count=catalog['verified_png_count'] if catalog is not None else 0,
        producer_job_id=job['id'], producer_conclusion=job['conclusion'],
        producer_source_files_verified=verified_sources, metadata_revalidated=True)
    if 'aged_fuse_fixture' in summary:
        summary['aged_fuse_fixture_qualified'] = bool(
            summary['native_inspection_qualified']
            and summary['aged_fuse_fixture'] is not None)
    for title, frame in wallet_inspection_frames(summary):
        emit(title, frame)
    if layout is not None and summary['native_inspection_qualified']:
        layout.update(archive_sha256=summary['archive_sha256'],
            manifest_sha256=summary['manifest_sha256'],
            producer_job_id=job['id'], metadata_revalidated=True,
            producer_source_files_verified=verified_sources,
            all_original_png_digests_verified=True)
        emit('Retained readonly shot layout', layout)
    if catalog is not None:
        catalog.update(catalog_capture_qualified=True, parent_closure_qualified=True,
            producer_job_id=job['id'], metadata_revalidated=True,
            producer_source_files_verified=verified_sources,
            all_original_png_digests_verified=True)
        family = {'retained_readonly_home_catalog': 'Home',
                  'retained_readonly_settings_catalog': 'Settings',
                  'retained_readonly_navigation_catalog': 'Navigation',
                  'retained_readonly_details_catalog': 'Details'}[catalog['scope']]
        rail_motion = catalog.pop('rail_motion', None)
        sync_pulse = catalog.pop('sync_pulse', None)
        segment_motion = catalog.pop('segment_motion', None)
        emit(f'Retained readonly {family} catalog', catalog)
        sampling_scope = summary.get('sampling_scope')
        capture_family = (sampling_scope.removesuffix('-only')
                          if family == 'Details' and sampling_scope else family.lower())
        emit('Retained readonly catalog image index', dict(
            scope='retained_readonly_catalog_image_index', source_head=head,
            source_run_id=run_id, producer_job_id=job['id'],
            archive_sha256=catalog['archive_sha256'],
            manifest_sha256=catalog['manifest_sha256'],
            catalog_family=capture_family, sampling_scope=sampling_scope,
            **catalog_index))
        if rail_motion is not None:
            emit('Retained readonly rail motion', dict(source_head=head,
                source_run_id=run_id, archive_sha256=catalog['archive_sha256'],
                manifest_sha256=catalog['manifest_sha256'], **rail_motion))
        if sync_pulse is not None:
            emit('Retained readonly status halo', dict(source_head=head,
                source_run_id=run_id, archive_sha256=catalog['archive_sha256'],
                manifest_sha256=catalog['manifest_sha256'], **sync_pulse))
        if segment_motion is not None:
            emit('Retained readonly segment motion', dict(source_head=head,
                source_run_id=run_id, archive_sha256=catalog['archive_sha256'],
                manifest_sha256=catalog['manifest_sha256'], pages=segment_motion))
        for comparison in catalog_comparisons:
            emit(f'Retained {family} pixel comparison', dict(
                scope=f'retained_{family.lower()}_pixel_comparison', source_head=head,
                source_run_id=run_id, archive_sha256=catalog['archive_sha256'],
                reference_head=reference_head, visual_matches=0, **comparison))
    if viewport_observation is not None:
        viewport_observation.update(viewport_observation_qualified=True, parent_closure_qualified=True,
            producer_job_id=job['id'], metadata_revalidated=True,
            producer_source_files_verified=verified_sources, all_original_png_digests_verified=True)
        emit('Retained readonly viewport observation', viewport_observation)
    return summary


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('::error title=Readonly wallet inspection::INSPECTION_REFUSED phase=' + PHASE, flush=True)
        raise SystemExit(1) from None
