"""Memory-only original-receipt controls; no network, native process or scratch."""

import base64
import contextlib
import copy
import io
import json
from pathlib import Path
import struct
import unittest
from unittest import mock
import zipfile
import zlib

from tool.ci import inspect_windows_qualification as inspect


HEAD, TREE, RUN = 'a' * 40, 'b' * 40, 123


def receipt():
    return dict(required=True, exit_code=0, exit_observed=True, forced_kill=False,
        output_complete=True, output_overflow=False, output_bytes=50, seconds=1.25,
        success=True, error_codes=[])


def baseline():
    return dict(schema=1, scope='github_hosted_windows_baseline', source_sha=HEAD,
        source_tree=TREE, run=dict(id=str(RUN), attempt='1'), success=True, error_codes=[],
        checks=dict.fromkeys(inspect.baseline.CHECKS, True),
        stages={name: receipt() for names in inspect.CHECK_STAGES.values() for name in names},
        doctor=dict(scope='windows_desktop_only', windows_version='pass', visual_studio='pass'),
        analysis={name: dict(errors=0, warnings=0, infos=3 if name == 'analyze_root' else 0)
                  for name in ('analyze_root', 'analyze_vendored')},
        tests=dict(passed=50, failed=0, skipped=2, hidden=3, terminal_events=55,
                   error_events=0, terminal_success=True),
        localization_correspondence={name: dict(files=3, sha256='d' * 64)
                                     for name in ('before', 'after')},
        libraries={name: dict(sha256='c' * 64, map_exports=True)
                   for name in inspect.baseline.LIBRARIES}, private_context='synthetic-private-context')


def log(report):
    return b'2026-10-26T12:00:00.000Z private tool text\n' + (
        '2026-10-26T12:00:01.0000000Z ' + json.dumps(report) + '\n').encode()


def pixels(*connector_rows, opaque=False, welcome_rows=(), welcome_x=710):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    alpha = 255 if opaque else 0
    fill = bytes((20, 20, 20, alpha))
    ink = bytes((60, 60, 60, alpha))
    blank = b'\x00' + fill * 1280
    connector = b'\x00' + fill * 482 + ink * 108 + fill * (1280 - 590)
    text = b'\x00' + fill * welcome_x + ink * 8 + fill * (1280 - welcome_x - 8)
    scanlines = b''.join(
        connector if y in connector_rows else text if y in welcome_rows else blank
        for y in range(780))
    return (b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', 1280, 780, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(scanlines))
        + chunk(b'IEND', b''))


def entry_report(data):
    value = inspect.entry.Report()
    value.source_sha, value.source_tree = HEAD, TREE
    value.run_id, value.run_attempt = str(RUN), '1'
    value.runner_sha256 = value.dart_kernel_sha256 = 'c' * 64
    value.checks = dict.fromkeys(inspect.entry.CHECKS, True)
    value.caption_checks = dict.fromkeys(inspect.entry.CAPTION_CHECKS, True)
    value.captures = [dict(file=name, sha256=inspect.archive.sha(data), bytes=len(data))
                      for name in inspect.entry.FILES]
    value.exit_code, value.exit_observed, value.output_complete = 0, True, True
    value.output_bytes = 100
    return value.public()


def package(report, data, *, extra=None, omitted=None, duplicate=False):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_STORED) as zipped:
        zipped.writestr('manifest.json', json.dumps(report))
        for item in report['captures']:
            if item['file'] != omitted:
                zipped.writestr(item['file'], data)
        if extra is not None:
            zipped.writestr(extra, b'synthetic')
        if duplicate:
            zipped.writestr('manifest.json', json.dumps(report))
    return stream.getvalue()


class WindowsQualificationTests(unittest.TestCase):
    def test_welcome_text_bands_are_bound_to_the_original_pngs(self):
        data = pixels(opaque=True, welcome_rows=(234, 254, 282, 294))
        status, _, output = self._read_original(baseline_conclusion='skipped', entry_data=data)
        self.assertEqual(status, 0)
        notices = [json.loads(line.split('::', 2)[2]) for line in output.splitlines()
                   if line.startswith('::notice')]
        capture = next(value for value in notices if value['scope'] == 'retained_windows_entry_observation')
        measured = next(value for value in notices if value['scope'] == 'retained_welcome_text_bounds')
        self.assertEqual(measured['archive_sha256'], capture['archive_sha256'])
        expected = {'title': [234, 254], 'subtitle': [282, 294]}
        self.assertEqual(measured['bounds'], dict.fromkeys(
            ('welcome-dark.png', 'welcome-light.png'), expected))
        self.assertEqual(measured['visual_matches'], 0)

    def test_entry_back_mark_crops_exclude_surrounding_content(self):
        rows = [bytes([30] * 63)] * 24
        middle = bytearray(rows[8])
        middle[24:36] = bytes([90] * 12)
        rows[8] = bytes(middle)
        with mock.patch.object(inspect, '_png_crop', return_value=(rows, 3)) as crop:
            self.assertEqual(inspect.back_mark_bounds('capture', 'import'),
                dict(bounds=[375, 233, 379, 234], ink_pixels=4))
        crop.assert_called_once_with('capture', (367, 388), (225, 249))

        rows[8] = bytes([90] * 63)
        with mock.patch.object(inspect, '_png_crop', return_value=(rows, 3)):
            self.assertIsNone(inspect.back_mark_bounds('capture', 'import'))

    def test_completed_step_bounds_bind_dark_ink_to_the_green_circle(self):
        left, top, right, bottom = inspect.COMPLETED_STEP_CROPS['seed-quiz'][0]
        green = b'\x00\xd5\x57'
        ink = b'\x04\x14\x0a'
        background = b'\xf1\xf4\xf1'
        rows = [
            b''.join(
                ink if (x, y) in ((369, 322), (370, 321))
                else green if (x + .5 - 370)**2 + (y + .5 - 322)**2 <= 121
                else background
                for x in range(left, right)
            )
            for y in range(top, bottom)
        ]
        with mock.patch.object(inspect, '_png_crop', return_value=(rows, 3)) as crop:
            self.assertEqual(inspect.completed_step_bounds('original', 'seed-quiz'), [
                dict(circle=[359, 311, 381, 333], ink_pixels=2,
                     ink_from_center=[-1, -1, 1, 1]),
            ])
        crop.assert_called_once_with('original', (left, right), (top, bottom))
        uniform = [green * (right - left)] * (bottom - top)
        with mock.patch.object(inspect, '_png_crop', return_value=(uniform, 3)):
            self.assertEqual(inspect.completed_step_bounds('original', 'seed-quiz'), [None])

    def test_original_baseline_receipts_preserve_counts_infos_and_scope(self):
        report = baseline()
        value = inspect.baseline_projection(report, HEAD, TREE, RUN)
        self.assertTrue(value['artifact_reported_success'])
        self.assertEqual(value['tests']['passed'], 50)
        self.assertEqual(value['tests']['skipped'], 2)
        self.assertEqual(value['analysis']['analyze_root']['infos'], 3)
        self.assertFalse(value['runtime_started'])
        self.assertFalse(value['wallet_qualified'])
        self.assertNotIn('synthetic-private-context', json.dumps(value))
        with contextlib.redirect_stdout(io.StringIO()):
            inspect.emit('Hosted baseline inspection', value)

    def test_original_failed_test_and_forced_exit_stay_negative(self):
        report = baseline()
        report['checks'] = dict.fromkeys(inspect.baseline.CHECKS, False)
        report['success'], report['error_codes'] = False, ['TESTS_FAILED']
        report['stages']['unit_widget_tests'].update(exit_code=1, forced_kill=True,
            success=False, error_codes=['COMMAND_TIMEOUT'])
        report['tests'].update(passed=49, failed=1, terminal_success=False)
        value = inspect.baseline_projection(report, HEAD, TREE, RUN)
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['original_error_codes'], ['TESTS_FAILED'])
        self.assertEqual(value['commands']['unit_widget_tests']['exit_code'], 1)
        self.assertTrue(value['commands']['unit_widget_tests']['forced_kill'])
        self.assertEqual(value['tests']['failed'], 1)

        doctor = baseline()
        doctor['checks'] = dict.fromkeys(inspect.baseline.CHECKS, False)
        doctor['checks']['source'] = True
        doctor['success'], doctor['error_codes'] = False, ['DOCTOR_UNPROVEN']
        doctor['doctor'].update(windows_version='unknown', visual_studio='unknown')
        doctor['stages'] = {name: receipt() for name in (
            'source_head', 'source_tree', 'source_clean_before',
            'enable_windows', 'doctor')}
        doctor['analysis'], doctor['tests'] = {}, None
        value = inspect.baseline_projection(doctor, HEAD, TREE, RUN)
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['original_error_codes'], ['DOCTOR_UNPROVEN'])
        self.assertEqual(value['commands']['enable_windows']['exit_code'], 0)
        self.assertEqual(value['commands']['doctor']['exit_code'], 0)
        self.assertIsNone(value['tests'])
        self.assertEqual(value['analysis'], {})
        self.assertFalse(value['original_checks']['windows_doctor'])
        doctor['stages']['doctor'].update(exit_code=1, forced_kill=True,
            output_complete=False, success=False, error_codes=['COMMAND_TIMEOUT'])
        value = inspect.baseline_projection(doctor, HEAD, TREE, RUN)
        self.assertFalse(value['artifact_reported_success'])
        self.assertTrue(value['commands']['doctor']['forced_kill'])
        self.assertFalse(value['commands']['doctor']['output_complete'])
        self.assertFalse(value['runtime_started'])
        self.assertFalse(value['wallet_qualified'])
        self.assertNotIn('synthetic-private-context', json.dumps(value))

    def test_failed_root_locations_keep_the_failure_and_refuse_private_fields(self):
        report = baseline()
        report['checks'] = dict.fromkeys(inspect.baseline.CHECKS, False)
        report['success'], report['error_codes'] = False, ['TESTS_FAILED']
        report['tests'].update(passed=49, failed=1, error_events=1,
            terminal_success=False)
        locations = dict(status='OBSERVED', total=1,
            items=[dict(file='welcome_surface_test.dart', line=554,
                kind='ASSERTION', category='ASSERTION')])
        report['test_failures'] = locations
        value = inspect.baseline_projection(report, HEAD, TREE, RUN)
        self.assertEqual(value['test_failures'], locations)
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['tests']['failed'], 1)
        invalid = [dict(locations, private='private'), dict(locations, total=True),
            dict(locations, status='private'), dict(locations, total=0)]
        for change in (dict(file='private'), dict(line=True), dict(line=0),
                dict(line=1000000), dict(kind='private'), dict(category='private'),
                dict(error='private'), dict(file=None)):
            invalid.append(dict(locations, items=[dict(locations['items'][0], **change)]))
        for item in invalid:
            with self.subTest(fields=len(item)), self.assertRaises(inspect.archive.Refused):
                inspect.baseline_projection(dict(report, test_failures=item), HEAD, TREE, RUN)
        positive = baseline()
        positive['test_failures'] = locations
        with self.assertRaises(inspect.archive.Refused):
            inspect.baseline_projection(positive, HEAD, TREE, RUN)

    def test_baseline_cannot_substitute_identity_exit_stage_or_correspondence(self):
        for change in ('source', 'attempt', 'exit', 'stage', 'analysis', 'library', 'localization'):
            report = baseline()
            if change == 'source':report['source_sha'] = 'e' * 40
            elif change == 'attempt':report['run']['attempt'] = '2'
            elif change == 'exit':report['stages']['build_debug']['exit_code'] = False
            elif change == 'stage':del report['stages']['build_release']
            elif change == 'analysis':report['analysis']['analyze_root']['warnings'] = 1
            elif change == 'library':report['libraries']['source']['sha256'] = 'e' * 64
            else:report['localization_correspondence']['after']['sha256'] = 'e' * 64
            with self.subTest(change=change), self.assertRaises(inspect.archive.Refused):
                inspect.baseline_projection(report, HEAD, TREE, RUN)

    def test_job_log_requires_one_timestamped_original_frame(self):
        raw = log(baseline())
        self.assertEqual(inspect.log_report(raw, 'github_hosted_windows_baseline'), baseline())
        for invalid in (b'', raw + raw, json.dumps(baseline()).encode(),
                        b'2026-10-26T12:00:00Z {}\n', b'x' * (inspect.MAX_LOG + 1)):
            with self.subTest(size=len(invalid)), self.assertRaises(inspect.archive.Refused):
                inspect.log_report(invalid, 'github_hosted_windows_baseline')

    def test_four_entry_pngs_are_checked_without_visual_match_claims(self):
        data = pixels()
        report = entry_report(data)
        raw = package(report, data)
        value = inspect.entry_archive(raw, inspect.archive.sha(raw), len(raw), HEAD, TREE, RUN)
        self.assertTrue(value['artifact_reported_success'])
        self.assertEqual(value['capture_count'], 4)
        self.assertEqual(value['visual_matches'], 0)
        self.assertFalse(value['runtime_started'])
        with contextlib.redirect_stdout(io.StringIO()):
            inspect.emit('Hosted entry inspection', value)

    def test_entry_rgb_comparison_binds_both_originals(self):
        actual = pixels(280, opaque=True, welcome_rows=(234, 340))
        reference = pixels(280, opaque=True, welcome_rows=(235,))
        comparison = inspect.entry_pixel_comparison(actual, reference, 'welcome')
        self.assertEqual(comparison, dict(actual_sha256=inspect.archive.sha(actual),
            reference_sha256=inspect.archive.sha(reference), changed_pixels=24,
            changed_pixels_at_least_16=24, mean_rgb_error_milli=1, action_alignment={},
            pixels_at_least_16_by_region=dict(caption=0, globe=0, introduction=16,
                action_left_edge=0, action_badges=8, action_labels=0,
                action_chevrons=0, action_right_edge=0, footer=0, outside_crops=0)))
        self.assertIsNone(inspect.entry_pixel_comparison(actual, pixels(), 'welcome'))

        for theme, observed, original in (
            ('dark', (24, 47, 33), (32, 46, 34)),
            ('light', (211, 232, 219), (219, 232, 221)),
        ):
            with self.subTest(backdrop=theme):
                a_rows = [bytes(observed) * 250] * 265
                r_rows = [bytes(original) * 250] * 265
                estimate = inspect.import_backdrop_palette_model(a_rows, 3, r_rows, 3, theme)
                self.assertEqual(estimate['status'], 'estimated')
                self.assertEqual(estimate['crop'], [220, 235, 250, 265])
                self.assertEqual(estimate['raw_mean_rgb_error_milli'], 3333)
                self.assertLess(estimate['modeled_mean_rgb_error_milli'], 700)

        numeral_rows = [bytes(1280 * 3)] * 295
        ink = bytearray(numeral_rows[284])
        for x in (369, 862):
            ink[x * 3] = 16
        numeral_rows[284] = bytes(ink)
        numeral_rows[291] = bytes(ink)
        self.assertEqual(inspect.import_numeral_bottom_rows(numeral_rows, 3),
                         [284, None, 284])

        handoff = pixels(520, 744, opaque=True, welcome_rows=(14, 240), welcome_x=300)
        with mock.patch.object(Path, 'open', return_value=io.BytesIO(pixels(opaque=True))):
            comparison = inspect.startup_pixel_comparison('40-launch-settle-dark.png', handoff)
        self.assertEqual(comparison['pixels_at_least_16_by_region'], dict(
            caption_wordmark=0, caption_background=8, caption_controls=0,
            stage=8, above_unlock=0, unlock_band=108, below_unlock=0,
            bottom=108, outside_crops=0))
        self.assertEqual(comparison['sample_rgb']['caption_left'], dict(
            point=[300, 14], actual=[60, 60, 60], reference=[20, 20, 20]))
        self.assertEqual(comparison['sample_rgb']['film'], dict(
            point=[300, 240], actual=[60, 60, 60], reference=[20, 20, 20]))
        self.assertEqual(comparison['unlock_palette_samples'], dict(
            unlock_left=dict(model_delta_milli=[-22989, 1164, -4365],
                             residual_delta_milli=[22989, -1164, 4365]),
            unlock_right=dict(model_delta_milli=[0, -1554, -3454],
                              residual_delta_milli=[0, 1554, 3454])))
        self.assertEqual(comparison['unlock_palette_band'], dict(sample_count=2328,
            raw_pixels_at_least_16=0, residual_pixels_at_least_16=881,
            max_residual_milli=27473))
        with mock.patch.object(Path, 'open', return_value=io.BytesIO(pixels(opaque=True))):
            settled = inspect.startup_pixel_comparison('41-lock-screen-dark.png', handoff)
        self.assertEqual(settled['sample_rgb']['left_of_stage'],
                         comparison['sample_rgb']['left_of_stage'])
        self.assertNotIn('film', settled['sample_rgb'])

    def test_handoff_fill_edges_match_the_two_reference_images(self):
        references = Path(inspect.__file__).resolve().parents[2] / 'mockups/redesign/shots'
        for theme in ('dark', 'light'):
            with self.subTest(theme=theme):
                data = (references / f'40-launch-settle-{theme}.png').read_bytes()
                self.assertEqual(inspect.handoff_unlock_fill_rows(data),
                                 dict(green=[511, 557], blue=[511, 557]))
        self.assertEqual(inspect.handoff_unlock_fill_rows(pixels(opaque=True)),
                         dict(green=None, blue=None))

    def test_welcome_action_alignment_finds_the_shift_to_the_reference(self):
        actual = pixels(opaque=True, welcome_rows=(340, 341), welcome_x=763)
        reference = pixels(opaque=True, welcome_rows=(338, 339), welcome_x=764)
        comparison = inspect.entry_pixel_comparison(actual, reference, 'welcome')
        self.assertEqual(comparison['action_alignment'], dict(create_label=dict(
            shift_to_reference=[1, -2], original_difference=32, shifted_difference=0)))
        actual = pixels(opaque=True, welcome_rows=(10, 11), welcome_x=15)
        reference = pixels(opaque=True, welcome_rows=(11, 12), welcome_x=15)
        comparison = inspect.entry_pixel_comparison(actual, reference, 'welcome')
        self.assertEqual(comparison['caption_wordmark_alignment'], dict(
            shift_to_reference=[0, 1], original_difference=16, shifted_difference=0))
        actual = pixels(opaque=True, welcome_rows=(503, 504, 538, 539, 576), welcome_x=702)
        reference = pixels(opaque=True, welcome_rows=(505, 506, 537, 538, 572, 576), welcome_x=701)
        comparison = inspect.pixel_comparison(
            actual, reference, {}, align_pillar_receipt=True)
        self.assertEqual(comparison['pillar_caption_alignment'], dict(
            shift_to_reference=[-1, -1], original_difference=18,
            shifted_difference=0, actual_bounds=[702, 538, 710, 540],
            reference_bounds=[701, 537, 709, 539]))
        self.assertEqual(comparison['pillar_heading_alignment'], dict(
            shift_to_reference=[-1, 2], original_difference=32,
            shifted_difference=0, actual_bounds=[702, 503, 710, 505],
            reference_bounds=[701, 505, 709, 507]))
        self.assertEqual(comparison['pillar_view_action_alignment'], dict(
            shift_to_reference=[-1, 0], original_difference=10,
            shifted_difference=8, actual_bounds=[702, 576, 710, 577],
            reference_bounds=[701, 572, 709, 577]))
        self.assertNotIn('pillar_done_action_alignment', comparison)
        actual = pixels(opaque=True, welcome_rows=range(134, 174), welcome_x=817)
        reference = pixels(opaque=True, welcome_rows=range(132, 172), welcome_x=817)
        comparison = inspect.pixel_comparison(
            actual, reference, {}, sample_spawn_fields=True)
        self.assertEqual(comparison['spawn_field_fills'], dict(
            column=820,
            actual=[dict(rows=[134, 174], rgb=[60, 60, 60],
                         probe_row=142, columns=[817, 825])],
            reference=[dict(rows=[132, 172], rgb=[60, 60, 60],
                            probe_row=140, columns=[817, 825])]))
        self.assertEqual(comparison['spawn_continue_bounds'],
                         dict(actual=None, reference=None))
        background = bytes((40, 40, 40))
        primary = bytes((0, 213, 87))
        rows = [background * 1280] * 475
        rows[400:438] = [background * 463 + primary * 94 + background * 723] * 38
        self.assertEqual(inspect.pillar_spawn_continue_bounds(rows, 3),
                         [463, 400, 557, 438])

    def test_entry_digest_missing_extra_and_invalid_pixels_are_refused(self):
        data = pixels()
        report = entry_report(data)
        for kind in ('digest', 'missing', 'extra', 'pixels'):
            selected = copy.deepcopy(report)
            body = data
            if kind == 'pixels':
                body = b'not screenshot pixels'
                for item in selected['captures']:
                    item.update(sha256=inspect.archive.sha(body), bytes=len(body))
            raw = package(selected, body,
                omitted=inspect.entry.FILES[0] if kind == 'missing' else None,
                extra='unexpected.txt' if kind == 'extra' else None)
            digest = 'e' * 64 if kind == 'digest' else inspect.archive.sha(raw)
            with self.subTest(kind=kind), self.assertRaises((inspect.archive.Refused, inspect.entry.Failure)):
                inspect.entry_archive(raw, digest, len(raw), HEAD, TREE, RUN)

    def test_entry_cannot_replace_original_process_or_caption_facts(self):
        for change in ('source', 'exit', 'forced', 'caption', 'identity'):
            report = entry_report(pixels())
            if change == 'source':report['source_sha'] = 'e' * 40
            elif change == 'exit':report['exit_code'] = False
            elif change == 'forced':report['forced_kill'] = True
            elif change == 'caption':report['caption']['observations']['native_restored'] = False
            else:report['runner_sha256'] = None
            with self.subTest(change=change), self.assertRaises(inspect.archive.Refused):
                inspect.entry_projection(report, HEAD, TREE, RUN)

    def test_import_connector_coverage_uses_only_the_original_png_band(self):
        for rows, opaque, expected, single, aligned in (
                ((280,), True, [0, 0, 108, 0, 0, 0, 0], True, True),
                ((281,), True, [0, 0, 0, 108, 0, 0, 0], True, False),
                ((280, 281), True, [0, 0, 108, 108, 0, 0, 0], False, False),
                ((280,), False, None, False, False)):
            with self.subTest(rows=rows, opaque=opaque):
                data = pixels(*rows, opaque=opaque)
                raw = package(entry_report(data), data)
                summary = inspect.entry_archive(raw, inspect.archive.sha(raw), len(raw), HEAD, TREE, RUN)
                self.assertTrue(summary['artifact_reported_success'])
                self.assertEqual(summary['visual_matches'], 0)
                self.assertEqual(set(summary['import_connector_coverage']),
                                 {'import-dark.png', 'import-light.png'})
                for band in summary['import_connector_coverage'].values():
                    self.assertEqual(band, dict(status='observed' if opaque else 'nonopaque',
                        counts=expected, full_width_single_row=single, reference_row=aligned))
                for border in summary['import_drop_border_coverage'].values():
                    self.assertEqual(border['status'], 'observed' if opaque else 'nonopaque')
                    self.assertFalse(border['model_within_tolerance'])

        status, calls, output = self._read_original(
            baseline_conclusion='skipped', entry_data=pixels(280, opaque=True))
        self.assertEqual(status, 0)
        self.assertEqual(len(calls), 6 + len(inspect.PRODUCERS))
        notices = [json.loads(line.split('::', 2)[2]) for line in output.splitlines()
                   if line.startswith('::notice')]
        self.assertEqual([value['scope'] for value in notices], [
            'retained_windows_baseline_not_selected', 'retained_windows_entry_observation',
            'retained_import_connector_coverage', 'retained_import_drop_border_coverage'])
        capture, band, drop = notices[1:]
        for field in ('archive_sha256', 'manifest_sha256', 'source_head', 'source_tree',
                      'source_run_id', 'original_job_id'):
            self.assertEqual(band[field], capture[field])
            self.assertEqual(drop[field], capture[field])
        self.assertEqual(band['visual_matches'], 0)
        self.assertEqual(drop['visual_matches'], 0)
        self.assertTrue(all(not edge['model_within_tolerance'] for edge in drop['edges'].values()))
        self.assertTrue(all(result['reference_row'] for result in band['bands'].values()))

    def test_partial_entry_and_nonzero_exit_are_not_completed_by_inspection(self):
        report = entry_report(pixels())
        report.update(captures=[], capture_count=0, exit_code=1, forced_kill=True,
            complete=False, success=False, status='UNKNOWN', error_codes=['ENTRY_UNAVAILABLE'])
        report['checks'] = dict.fromkeys(inspect.entry.CHECKS, False)
        raw = package(report, b'')
        value = inspect.entry_archive(raw, inspect.archive.sha(raw), len(raw), HEAD, TREE, RUN)
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['capture_count'], 0)
        self.assertEqual(value['exit_code'], 1)
        self.assertTrue(value['forced_kill'])

    def test_local_admission_refuses_before_network(self):
        with mock.patch.dict(inspect.os.environ, {}, clear=True), \
                mock.patch.object(inspect.archive, 'Client') as client, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(inspect.main(), 1)
        client.assert_not_called()
        lines = output.getvalue().splitlines()
        self.assertEqual(json.loads(lines[0])['phase'], 'environment')
        self.assertEqual(lines[1], '::notice title=Hosted Windows inspection refusal::' + lines[0])

    def _read_original(self, *, entry_change=None, entry_count=1, failed_root=False,
                       baseline_conclusion='success', baseline_change=None, baseline_count=1,
                       log_failure=None, entry_data=None, quiz_job=None, extra_artifact=False,
                       reference_head=None):
        data = pixels() if entry_data is None else entry_data
        raw = package(entry_report(data), data)
        original_report = baseline()
        if failed_root:
            original_report['success'] = False
            original_report['error_codes'] = ['TESTS_FAILED']
            original_report['checks']['unit_widget_tests'] = False
            original_report['checks']['debug_build'] = False
            original_report['checks']['release_build'] = False
            original_report['tests'].update(passed=49, failed=1, error_events=1,
                                            terminal_success=False)
            original_report['stages']['unit_widget_tests'].update(exit_code=1,
                success=False, error_codes=[])
        original_log = log(original_report)
        calls = []

        class Client(inspect.archive.Client):
            def json(self, path):
                calls.append(path)
                if path == '/actions/runs/123':
                    return dict(id=RUN, head_sha=HEAD, run_attempt=1, workflow_id=381413107,
                        event='workflow_dispatch', status='completed', repository=dict(full_name='edgepillar/syrius'))
                if path == '/git/commits/' + HEAD:
                    return dict(sha=HEAD, tree=dict(sha=TREE))
                if path.startswith('/contents/tool/ci/'):
                    name = path.split('/')[-1].partition('?')[0]
                    body = Path(inspect.__file__).with_name(name).read_bytes()
                    return dict(type='file', path='tool/ci/' + name, encoding='base64', size=len(body),
                                content=base64.b64encode(body).decode('ascii'))
                if path == '/actions/runs/123/attempts/1/jobs?per_page=20':
                    original_baseline = dict(id=5, name='Hosted Windows baseline', run_id=RUN,
                        head_sha=HEAD, status='completed', conclusion=baseline_conclusion, steps=[])
                    if baseline_change is not None:
                        original_baseline.update(baseline_change)
                    original_entry = dict(id=6, name='Ordinary Windows entry captures', run_id=RUN,
                        head_sha=HEAD, status='completed', conclusion='success', steps=[])
                    if entry_change is not None:
                        original_entry.update(entry_change)
                    jobs = ([dict(original_baseline) for _ in range(baseline_count)]
                            + [dict(original_entry) for _ in range(entry_count)])
                    if quiz_job is not None:
                        jobs.append(quiz_job)
                    return dict(total_count=len(jobs), jobs=jobs)
                if path == '/actions/runs/123/artifacts?per_page=20':
                    artifacts = [dict(id=7, expired=False,
                        name='windows-entry-capture-' + HEAD + '-123-1',
                        workflow_run=dict(id=RUN, head_sha=HEAD), size_in_bytes=len(raw),
                        digest='sha256:' + inspect.archive.sha(raw))]
                    if quiz_job is not None:
                        artifacts.append(dict(id=8, name='windows-quiz-catalog-' + HEAD + '-123-1'))
                    if extra_artifact:
                        artifacts.append(dict(id=9, name='unrelated'))
                    return dict(total_count=len(artifacts), artifacts=artifacts)
                raise AssertionError('unexpected metadata query')

            def read(self, url, *, redirect=False, authenticated=True, cap=262144):
                calls.append(url)
                if ((redirect and url.endswith('/jobs/5/logs') and log_failure == 'location')
                        or (not redirect and url.endswith('/log') and log_failure == 'download')):
                    raise inspect.archive.Refused('synthetic-private-context')
                if redirect:
                    self_url = ('log' if url.endswith('/jobs/5/logs') else
                                'entry' if url.endswith('/artifacts/7/zip') else None)
                    if self_url is None or not authenticated:
                        raise AssertionError('unexpected redirect')
                    return 'https://synthetic.blob.core.windows.net/' + self_url
                if authenticated:
                    raise AssertionError('credentials forwarded to artifact host')
                body = original_log if url.endswith('/log') else raw
                if len(body) > cap:
                    raise AssertionError('unbounded read')
                return body

        environment = dict(GITHUB_ACTIONS='true', SYRIUS_HOSTED_RUNNER='github-hosted',
            GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='edgepillar/syrius',
            WINDOWS_INSPECT_RUN='123', WINDOWS_INSPECT_HEAD=HEAD, GH_TOKEN='synthetic')
        if reference_head is not None:
            environment['WINDOWS_REFERENCE_HEAD'] = reference_head
        with mock.patch.dict(inspect.os.environ, environment, clear=True), \
                mock.patch.object(inspect.archive, 'Client', Client), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            status = inspect.main()
        return status, calls, output.getvalue()

    def test_standalone_handoff_routes_verified_pixels_to_the_reference_reader(self):
        job = dict(id=8, name=inspect.startup.JOB_NAME, run_id=RUN, head_sha=HEAD,
            status='completed', conclusion='success', labels=['windows-latest'],
            steps=[dict(name=inspect.startup.launch.SETTLE_JOB_STEP,
                        status='completed', conclusion='success')])
        file = '40-launch-settle-dark.png'
        reference_head = 'c' * 40

        def read(client, **options):
            self.assertTrue(options['settle'])
            self.assertIs(options['compare_png'], inspect.startup_pixel_comparison)
            return dict(source_head=HEAD, source_run_id=RUN, archive_sha256='d' * 64,
                        pixel_comparisons={file: dict(changed_pixels=17)})

        with mock.patch.object(inspect.startup, 'inspect_launch_run', side_effect=read):
            status, _, output = self._read_original(quiz_job=job,
                baseline_conclusion='skipped', entry_change=dict(conclusion='skipped'),
                reference_head=reference_head)
        self.assertEqual(status, 0, output)
        rows = [json.loads(line) for line in output.splitlines() if line.startswith('{')]
        self.assertEqual(rows[1], dict(scope='retained_startup_pixel_comparison', file=file,
            source_head=HEAD, source_run_id=RUN, reference_head=reference_head,
            archive_sha256='d' * 64, visual_matches=0, changed_pixels=17))

    def test_quiz_and_entry_share_one_artifact_listing_and_keep_both_receipts(self):
        def step(name):
            return dict(name=name, status='completed', conclusion='success')

        quiz = dict(id=8, name=inspect.startup.JOB_NAME, run_id=RUN, head_sha=HEAD,
            status='completed', conclusion='success', labels=['windows-latest'],
            steps=[step(inspect.startup.quiz_catalog.JOB_STEP),
                   step('Retain the synthetic seed quiz manifest and PNGs')])
        entry = dict(labels=['windows-latest'],
            steps=[step('Capture genuine ordinary entry and observe original process exit'),
                   step('Retain entry evidence and finite manifest')])
        with mock.patch.object(inspect.startup, 'inspect_launch_run',
                return_value=dict(scope='retained_seed_quiz', verified_png_count=2)) as inspect_quiz:
            status, calls, output = self._read_original(
                quiz_job=quiz, baseline_conclusion='skipped', entry_change=entry)
            self.assertEqual(status, 0, output)
            self.assertEqual(calls.count('/actions/runs/123/artifacts?per_page=20'), 1)
            self.assertFalse(any('/logs' in call for call in calls))
            self.assertEqual(inspect_quiz.call_args.kwargs['item']['id'], 8)
            self.assertTrue(inspect_quiz.call_args.kwargs['quiz'])
            self.assertIn('Hosted original seed quiz catalog inspection', output)
            self.assertIn('Hosted entry inspection', output)

            inspect_quiz.reset_mock()
            status, calls, _ = self._read_original(quiz_job=quiz,
                baseline_conclusion='skipped', entry_change=entry, extra_artifact=True)
            self.assertEqual(status, 1)
            inspect_quiz.assert_not_called()
            self.assertFalse(any('/zip' in call for call in calls))

    def test_complete_reader_uses_only_original_metadata_and_bounded_memory_reads(self):
        status, calls, output = self._read_original()
        self.assertEqual(status, 0)
        self.assertEqual(len(calls), 8 + len(inspect.PRODUCERS))
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        self.assertTrue(all(len(line.partition('::')[2].encode()) < 3900 for line in notices))
        self.assertNotIn('synthetic-private-context', output)
        for failure, phase in (('location', 'baseline_log_location'),
                               ('download', 'baseline_log_download')):
            with self.subTest(failure=failure):
                status, calls, output = self._read_original(
                    entry_change=dict(conclusion='skipped'), log_failure=failure)
            self.assertEqual(status, 1)
            self.assertEqual(json.loads(output.splitlines()[0])['phase'], phase)
            self.assertFalse(any('/artifacts' in call for call in calls))
            self.assertNotIn('synthetic-private-context', output)
        for function, phase in (('log_report', 'baseline_log_frame'),
                                ('baseline_projection', 'baseline_projection'),
                                ('emit', 'baseline_notice')):
            with self.subTest(function=function), mock.patch.object(inspect, function,
                    side_effect=inspect.archive.Refused('synthetic-private-context')):
                status, calls, output = self._read_original(
                    entry_change=dict(conclusion='skipped'))
            self.assertEqual(status, 1)
            self.assertEqual(json.loads(output.splitlines()[0])['phase'], phase)
            self.assertFalse(any('/artifacts' in call for call in calls))
            self.assertNotIn('synthetic-private-context', output)

    def test_baseline_only_reader_keeps_original_result_without_entry_transport(self):
        status, calls, output = self._read_original(entry_change=dict(conclusion='skipped'))
        self.assertEqual(status, 0)
        self.assertEqual(len(calls), 5 + len(inspect.PRODUCERS))
        self.assertFalse(any('/artifacts' in call for call in calls))
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        self.assertTrue(notices[0].startswith('::notice title=Hosted baseline inspection::'))
        self.assertTrue(notices[1].startswith('::notice title=Hosted entry not selected::'))
        skipped = json.loads(notices[1].split('::', 2)[2])
        self.assertEqual(skipped, dict(scope='retained_windows_entry_not_selected',
            inspection_only=True, runtime_started=False, wallet_qualified=False,
            source_head=HEAD, source_tree=TREE, source_run_id=RUN, source_attempt=1,
            original_job_id=6, original_job_conclusion='skipped',
            entry_qualified=False, entry_artifacts_read=0))
        self.assertNotIn('synthetic-private-context', output)

    def test_skipped_entry_requires_one_original_completed_source_bound_job(self):
        for options in (dict(entry_count=0), dict(entry_count=2),
                dict(entry_change=dict(conclusion='skipped', head_sha='c' * 40)),
                dict(entry_change=dict(conclusion='skipped', run_id=RUN + 1)),
                dict(entry_change=dict(conclusion='skipped', status='in_progress')),
                dict(entry_change=dict(conclusion='skipped', steps=[dict(name='Started')]))):
            with self.subTest(options=options):
                status, calls, output = self._read_original(**options)
            self.assertEqual(status, 1)
            self.assertFalse(any(call.endswith('/logs') for call in calls))
            self.assertEqual(json.loads(output.splitlines()[0])['phase'], 'job_metadata')
            self.assertNotIn('::notice title=Hosted baseline inspection::', output)

    def test_entry_only_reader_keeps_skipped_baseline_unqualified_and_reads_no_log(self):
        status, calls, output = self._read_original(baseline_conclusion='skipped')
        self.assertEqual(status, 0)
        self.assertEqual(len(calls), 6 + len(inspect.PRODUCERS))
        self.assertFalse(any('/logs' in call for call in calls))
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        self.assertTrue(notices[0].startswith('::notice title=Hosted baseline not selected::'))
        self.assertTrue(notices[1].startswith('::notice title=Hosted entry inspection::'))
        skipped = json.loads(notices[0].split('::', 2)[2])
        self.assertEqual(skipped, dict(scope='retained_windows_baseline_not_selected',
            inspection_only=True, runtime_started=False, wallet_qualified=False,
            source_head=HEAD, source_tree=TREE, source_run_id=RUN, source_attempt=1,
            original_job_id=5, original_job_conclusion='skipped',
            baseline_qualified=False, baseline_logs_read=0))
        entry = json.loads(notices[1].split('::', 2)[2])
        self.assertTrue(entry['artifact_reported_success'])
        self.assertEqual(entry['capture_count'], 4)
        self.assertEqual(entry['visual_matches'], 0)
        self.assertFalse(entry['runtime_started'])
        self.assertFalse(entry['wallet_qualified'])
        self.assertNotIn('synthetic-private-context', output)

    def test_skipped_baseline_requires_bound_empty_job_and_one_selected_producer(self):
        for options in (dict(baseline_count=0), dict(baseline_count=2),
                dict(baseline_change=dict(head_sha='c' * 40)),
                dict(baseline_change=dict(run_id=RUN + 1)),
                dict(baseline_change=dict(status='in_progress')),
                dict(baseline_change=dict(steps=[dict(name='Started')])),
                dict(entry_change=dict(conclusion='skipped'))):
            with self.subTest(options=options):
                status, calls, output = self._read_original(
                    baseline_conclusion='skipped', **options)
            self.assertEqual(status, 1)
            self.assertFalse(any('/artifacts' in call or '/logs' in call for call in calls))
            self.assertEqual(json.loads(output.splitlines()[0])['phase'], 'job_metadata')
            self.assertNotIn('::notice title=Hosted baseline not selected::', output)
            self.assertNotIn('::notice title=Hosted entry inspection::', output)

    def test_original_skipped_expression_name_keeps_entry_only_scope(self):
        status, calls, output = self._read_original(baseline_conclusion='skipped',
            baseline_change=dict(name=inspect.SKIPPED_BASELINE_JOB))
        self.assertEqual(status, 0)
        self.assertFalse(any('/logs' in call for call in calls))
        notices = [line for line in output.splitlines() if line.startswith('::notice')]
        self.assertEqual(len(notices), 2)
        skipped = json.loads(notices[0].split('::', 2)[2])
        self.assertFalse(skipped['baseline_qualified'])
        self.assertEqual(skipped['baseline_logs_read'], 0)
        self.assertEqual(skipped['original_job_conclusion'], 'skipped')
        self.assertEqual(json.loads(notices[1].split('::', 2)[2])['capture_count'], 4)

    def test_skipped_expression_cannot_alias_an_executed_or_ambiguous_job(self):
        options = [dict(baseline_conclusion=value,
            baseline_change=dict(name=inspect.SKIPPED_BASELINE_JOB))
            for value in ('success', 'failure')]
        options += [dict(baseline_conclusion='skipped', baseline_count=2,
            baseline_change=dict(name=inspect.SKIPPED_BASELINE_JOB)),
            dict(baseline_conclusion='skipped',
                baseline_change=dict(name=inspect.SKIPPED_BASELINE_JOB + ' ')),
            dict(baseline_conclusion='skipped',
                baseline_change=dict(name=inspect.SKIPPED_BASELINE_JOB, steps=[{}]))]
        for change in options:
            with self.subTest(change=change):
                status, calls, output = self._read_original(**change)
            self.assertEqual(status, 1)
            self.assertFalse(any('/artifacts' in call or '/logs' in call for call in calls))
            self.assertEqual(json.loads(output.splitlines()[0])['phase'], 'job_metadata')
            self.assertNotIn('::notice title=Hosted baseline not selected::', output)

    def test_baseline_only_reader_preserves_the_original_failed_suite(self):
        status, calls, output = self._read_original(entry_change=dict(conclusion='skipped'),
            failed_root=True, baseline_conclusion='failure')
        self.assertEqual(status, 0)
        self.assertFalse(any('/artifacts' in call for call in calls))
        original = json.loads(output.splitlines()[0])
        self.assertFalse(original['artifact_reported_success'])
        self.assertEqual(original['original_job_conclusion'], 'failure')
        self.assertEqual(original['original_error_codes'], ['TESTS_FAILED'])
        self.assertEqual(original['tests']['failed'], 1)
        self.assertEqual(original['tests']['error_events'], 1)
        self.assertFalse(original['tests']['terminal_success'])
        self.assertFalse(original['original_checks']['unit_widget_tests'])

    def test_baseline_only_reader_cannot_accept_a_false_success_job(self):
        status, calls, output = self._read_original(entry_change=dict(conclusion='skipped'),
            failed_root=True, baseline_conclusion='success')
        self.assertEqual(status, 1)
        self.assertFalse(any('/artifacts' in call for call in calls))
        self.assertEqual(json.loads(output.splitlines()[0])['phase'], 'baseline_log')
        self.assertNotIn('::notice title=Hosted baseline inspection::', output)
        self.assertNotIn('::notice title=Hosted entry not selected::', output)



def failed_entry_progress_report():
    report = entry_report(pixels())
    report['checks'].update(welcome_dark=False, welcome_light=False,
                           import_dark=False, import_light=False, entry_restored=False)
    report['caption']['observations'] = dict.fromkeys(inspect.entry.CAPTION_CHECKS, False)
    report.update(captures=[], capture_count=0, complete=False, success=False, status='UNKNOWN',
        error_codes=['HTTP_FAILED', 'ENTRY_INVALID'],
        first_command_failure=dict(category='EXCHANGE_FAILED', code='HTTP_FAILED',
            http_status=None, phase='capture_welcome_dark', resize=None),
        cleanup_failures=[dict(category='GUARD_FAILED', code='ENTRY_INVALID',
            http_status=200, phase='entry_verify', resize=None)])
    effect = dict(phase='original-native-frame', future='succeeded',
                  failed=False, milliseconds=21001)
    report['capture_progress'] = dict(schema=1, screen='welcome', theme='dark', scopes=1,
        completedCaptures=1, effects=1, last=effect, slowest=dict(effect),
        artworkCount=2, imageCreated=True, restoring=True, restored=True, held=False)
    report['transport_failure'] = dict(phase='capture_welcome_dark', kind='TIMEOUT')
    return report


class EntryProgressInspectionTests(unittest.TestCase):
    def test_fixed_pipe_trace_cannot_heal_the_original_failed_entry(self):
        report = failed_entry_progress_report()
        event = dict(schema=1, screen='welcome', theme='dark', scopes=1, effects=1,
            phase='original-renderer-image', boundary='begin',
            future='not_returned', failed=False, milliseconds=0)
        report['effect_trace'] = dict(schema=1, status='OBSERVED', events=1,
                                     last=event, last_ended=None)
        value = inspect.entry_projection(report, HEAD, TREE, RUN)
        self.assertEqual(value['effect_trace'], report['effect_trace'])
        self.assertEqual(value['capture_count'], 0)
        self.assertEqual(value['original_error_codes'], report['error_codes'])
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['visual_matches'], 0)

    def test_private_or_contradictory_pipe_summaries_are_refused(self):
        report = failed_entry_progress_report()
        event = dict(schema=1, screen='welcome', theme='dark', scopes=1, effects=1,
            phase='original-renderer-image', boundary='begin',
            future='not_returned', failed=False, milliseconds=0)
        trace = dict(schema=1, status='OBSERVED', events=1, last=event, last_ended=None)
        invalid = [dict(trace, private='private'), dict(trace, events=True),
            dict(trace, events=2),
            dict(trace, events=0), dict(trace, status='private'),
            dict(trace, last=dict(event, error='private')),
            dict(trace, last=dict(event, phase='private')),
            dict(trace, last_ended=event)]
        for value in invalid:
            with self.subTest(fields=len(value)), self.assertRaises(inspect.archive.Refused):
                inspect.entry_projection(dict(report, effect_trace=value), HEAD, TREE, RUN)

    def test_diagnostics_cannot_replace_received_images_or_heal_original_failure(self):
        report = failed_entry_progress_report()
        value = inspect.entry_projection(report, HEAD, TREE, RUN)
        self.assertEqual(value['capture_count'], 0)
        self.assertEqual(value['capture_progress']['completedCaptures'], 1)
        self.assertEqual(value['transport_failure']['kind'], 'TIMEOUT')
        self.assertEqual(value['first_command_failure'], report['first_command_failure'])
        self.assertEqual(value['original_error_codes'], ['HTTP_FAILED', 'ENTRY_INVALID'])
        self.assertFalse(value['artifact_reported_success'])
        self.assertEqual(value['visual_matches'], 0)
        with contextlib.redirect_stdout(io.StringIO()):
            inspect.emit('Hosted entry inspection', value)

    def test_private_or_coerced_progress_and_unbound_transport_kinds_are_refused(self):
        report = failed_entry_progress_report()
        for field, change in (
                ('capture_progress', dict(owner='private-context')),
                ('capture_progress', dict(scopes=True)),
                ('capture_progress', dict(completedCaptures=2)),
                ('transport_failure', dict(kind='private-context')),
                ('transport_failure', dict(kind=True)),
                ('transport_failure', dict(phase='private-context')),
                ('transport_failure', dict(error='private-context'))):
            invalid = dict(report, **{field: dict(report[field], **change)})
            with self.subTest(field=field), self.assertRaises(inspect.archive.Refused):
                inspect.entry_projection(invalid, HEAD, TREE, RUN)
        invalid = dict(report, error_codes=['ENTRY_INVALID'])
        with self.assertRaises(inspect.archive.Refused):
            inspect.entry_projection(invalid, HEAD, TREE, RUN)


if __name__ == '__main__':
    unittest.main()
