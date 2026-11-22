import copy
import io
import json
from pathlib import Path
import stat
import struct
import unittest
import zipfile
import zlib

from tool.ci import readonly_details_capture as details
from tool.ci import windows_wallet_inspection as legacy
from tool.ci import readonly_settings_capture as original_settings
from tool.ci import readonly_navigation_capture as original_navigation


SCREENS = ('receive-qr', 'zap-form', 'plasma-fuse', 'set-licences', 'set-originals')
FILES = ('10-receive-qr-dark.png', '10-receive-qr-light.png', '11-zap-form-dark.png', '11-zap-form-light.png', '22-plasma-fuse-dark.png', '22-plasma-fuse-light.png', '37-set-licences-dark.png', '37-set-licences-light.png', '38-set-originals-dark.png', '38-set-originals-light.png')
HEAD, TREE, RUN = '1' * 40, '2' * 40, 7
PINS = {name: format(i, '064x') for i, name in enumerate(SCREENS, 1)}


def receipt():
    return dict(schema=1, scope='readonly_native_details_catalog_capture',
        screens=list(SCREENS), themes=['dark', 'light'], files=list(FILES),
        width=1280, height=780, scale=1, capture_returned=True)


def png(sample=0):
    def chunk(kind, value):
        body = kind + value
        return struct.pack('>I', len(value)) + body + struct.pack('>I',
            zlib.crc32(body) & 0xffffffff)
    return (bytes((137, 80, 78, 71, 13, 10, 26, 10))
        + chunk(b'IHDR', struct.pack('>IIBBBBB', 1280, 780, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress((b'\0' + bytes((sample,)) * (1280 * 3)) * 780))
        + chunk(b'IEND', b''))


def fixture():
    pixels = png()
    captures = [dict(theme=('dark', 'light')[i % 2], file=name,
        bytes=len(pixels), sha256=details.sha(pixels), width=1280,
        height=780, scale=1) for i, name in enumerate(FILES)]
    value = dict(schema=1, scope='readonly_native_details_catalog_capture_bundle',
        source_sha=HEAD, source_tree=TREE, run_id=str(RUN), run_attempt='1',
        script_sha256_by_screen=PINS, capture=receipt(), captures=captures,
        inspection_only=True, parent_closure_qualified=False,
        atomic_frame_qualified=False, wallet_qualified=False,
        seed_admitted=False, financial_send_qualified=False, visual_matches=0)
    return value, {name: pixels for name in FILES}


def bundle(value, images, *, link=None):
    raw = io.BytesIO()
    manifest = (json.dumps(value, sort_keys=True, separators=(',', ':'))
        + '\n').encode('ascii')
    with zipfile.ZipFile(raw, 'w', zipfile.ZIP_DEFLATED) as target:
        target.writestr('manifest.json', manifest)
        for name, pixels in images.items():
            info = zipfile.ZipInfo(name)
            info.external_attr = ((stat.S_IFLNK if name == link else stat.S_IFREG)
                | 0o600) << 16
            target.writestr(info, pixels)
    reference = dict(schema=value['schema'],
        scope='readonly_native_details_catalog_reference',
        screens=value['capture']['screens'], captured=len(value['captures']),
        manifest_sha256=details.sha(manifest))
    if value['schema'] in details.RESTORED_SCHEMAS:
        reference.update(scope='restored_native_seeded_catalog_reference',
            seed_receipts_sha256=value['seed_receipts_sha256'])
    return raw.getvalue(), reference


class DetailsCatalogTests(unittest.TestCase):
    def test_holder_receipt_requires_positive_non_owner_state(self):
        schema = details.RESTORED_FAMILIES['token-holder']
        value = dict(receipt(), schema=schema,
            scope='restored_native_seeded_catalog_capture', screens=['tokens'],
            files=['23-tokens-dark.png', '23-tokens-light.png'])
        with self.assertRaises(details.Refused):
            details.capture_receipt(value)
        with self.assertRaises(details.Refused):
            details.capture_receipt(dict(value, positive_non_owner_holding=1))
        value['positive_non_owner_holding'] = True
        self.assertEqual(details.capture_receipt(value), value)
        self.assertEqual(details.catalog_script_name(schema, 'tokens'),
            'prepared/token-holder.txt')

    def test_single_state_only_admits_its_two_original_files_and_script(self):
        original, original_images = fixture()
        for schema, screen, number, stage in (
            (2, 'token-new', 25, 'token_draft_catalog'),
            (3, 'send-confirm', 12, 'send_confirm_catalog'),
            (9, 'swap-start', 27, 'swap_start_catalog'),
            (10, 'wallet-ready', 47, 'wallet_ready_catalog'),
            (11, 'send-warn', 8, 'send_warn_catalog'),
            (12, 'home-zap', 6, 'home_zap_preview_catalog'),
            (19, 'set-node', 30, 'node_verified_catalog'),
        ):
            with self.subTest(screen=screen):
                files = [f'{number:02d}-{screen}-{theme}.png'
                    for theme in ('dark', 'light')]
                pins = {screen: '7' * 64}
                capture = dict(receipt(), schema=schema, screens=[screen],
                    files=files)
                captures = [dict(row, file=name)
                    for row, name in zip(original['captures'][:2], files)]
                images = dict(zip(files, original_images.values()))
                if schema in (9, 10, 11, 12, 19):
                    with self.assertRaises(details.Refused):
                        details.capture_records(captures, schema=schema)
                    light = images[files[1]] = png(255)
                    captures[1].update(bytes=len(light), sha256=details.sha(light))
                report = dict(original, schema=schema, capture=capture,
                    captures=captures, script_sha256_by_screen=pins)
                raw, reference = bundle(report, images)
                result = details.unpack(raw, details.sha(raw), len(raw),
                    HEAD, TREE, RUN, reference, pins)
                self.assertEqual(result['filenames'], files)
                self.assertEqual(result['verified_png_count'], 2)
                self.assertEqual(result['script_sha256_by_screen'], pins)
                self.assertEqual(result['visual_matches'], 0)
                self.assertEqual(result.get('presentation_fixture'),
                    'sample_zap_message' if schema == 12 else None)
                if schema == 19:
                    self.assertEqual(details.catalog_script_name(schema, screen),
                                     'prepared/set-node.txt')
                    script = Path('harness/screens/prepared/set-node.txt').read_text()
                    commands = [line for line in script.splitlines()
                                if 'tap --key node_update_' in line]
                    self.assertEqual(commands, [
                        'tap --key node_update_check', 'tap --key node_update_download',
                        '# after-capture: tap --key node_update_discard_download --exact',
                    ])
                with self.assertRaises(details.Refused):
                    details.unpack(raw, details.sha(raw), len(raw),
                        HEAD, TREE, RUN, reference, PINS)
                with self.assertRaises(details.Refused):
                    details.catalog_reference(dict(reference, schema=3 if schema == 2 else 2))
                failure = dict(schema=1, kind='readonly_details_capture_failure',
                    last_entered_step='scriptLine', screen=screen, theme='dark',
                    line=5)
                self.assertEqual(legacy.entry_failure(dict(stage=stage,
                    code=None, diagnostic=failure))['diagnostic'], failure)
                with self.assertRaises(legacy.Refused):
                    legacy.entry_failure(dict(stage='details_catalog',
                        code=None, diagnostic=failure))

        schema = details.SETTINGS_REVIEW_SCHEMA
        screens = ['set-node', 'set-addresses']
        files = [f'{number}-{screen}-{theme}.png'
                 for number, screen in zip((30, 35), screens) for theme in details.THEMES]
        pins = {'set-node': '7' * 64, 'set-addresses': '8' * 64}
        capture = dict(receipt(), schema=schema, screens=screens, files=files)
        images = {name: png(index + 1) for index, name in enumerate(files)}
        captures = [dict(file=name, theme=details.THEMES[index % 2],
            width=1280, height=780, scale=1, bytes=len(data), sha256=details.sha(data))
            for index, (name, data) in enumerate(images.items())]
        report = dict(original, schema=schema, capture=capture,
                      captures=captures, script_sha256_by_screen=pins)
        raw, reference = bundle(report, images)
        result = details.unpack(raw, details.sha(raw), len(raw), HEAD, TREE, RUN, reference, pins)
        self.assertEqual(result['filenames'], files)
        self.assertEqual(result['verified_png_count'], 4)
        self.assertTrue(details.family_matches('node-verified', 19))
        self.assertTrue(details.family_matches('node-verified', schema))
        self.assertFalse(details.family_matches('details', schema))
        self.assertEqual(details.catalog_script_name(schema, 'set-node'), 'prepared/set-node.txt')
        self.assertEqual(details.catalog_script_name(schema, 'set-addresses'), 'set-addresses.txt')
        with self.assertRaises(details.Refused):
            details.capture_receipt(dict(capture, files=files[:2]))

    def test_closed_details_namespace_cannot_adopt_home_or_private_fields(self):
        value = receipt()
        self.assertEqual(details.capture_receipt(value), value)
        self.assertEqual(details.catalog_files(1), FILES)
        self.assertEqual(details.catalog_screens(1), SCREENS)
        with self.assertRaises(legacy.Refused):
            legacy.home_capture_receipt(value)
        with self.assertRaises(original_settings.Refused):
            original_settings.capture_receipt(value)
        with self.assertRaises(original_navigation.Refused):
            original_navigation.capture_receipt(value)
        mutations = [
            dict(schema=True), dict(schema=2), dict(schema='1'),
            dict(scope='readonly_native_home_catalog_capture'),
            dict(scope='readonly_native_settings_catalog_capture'),
            dict(scope='readonly_native_navigation_catalog_capture'),
            dict(screens=list(original_navigation.SCREENS)),
            dict(screens=list(original_settings.SCREENS)),
            dict(files=list(legacy.HOME_GOTO_FILES)), dict(capture_returned=1),
            dict(screens=list(reversed(SCREENS))), dict(scale=True),
            dict(width=1200), dict(unexpected='unapproved'),
        ]
        for delta in mutations:
            with self.subTest(delta=delta), self.assertRaises(details.Refused):
                details.capture_receipt(dict(value, **delta))
        report, _ = fixture()
        self.assertEqual(details.public_catalog(report), report)
        for key, bad in (
            ('inspection_only', False), ('parent_closure_qualified', True),
            ('atomic_frame_qualified', True), ('wallet_qualified', True),
            ('seed_admitted', True), ('financial_send_qualified', True),
            ('visual_matches', 1), ('unexpected', 'unapproved'),
        ):
            with self.subTest(key=key), self.assertRaises(details.Refused):
                details.public_catalog(dict(report, **{key: bad}))

    def test_failure_diagnostic_is_closed_and_cannot_disclose_commands_or_paths(self):
        base = dict(schema=1, kind='readonly_details_capture_failure',
            last_entered_step='preflight')
        self.assertIs(details.failure_diagnostic(base), base)
        valid = dict(base, last_entered_step='scriptLine',
            screen='receive-qr', theme='dark', line=5)
        self.assertIs(details.failure_diagnostic(valid), valid)
        for reply in details.FAILURE_REPLIES:
            observed = dict(valid, schema=2, reply=reply)
            self.assertIs(details.failure_diagnostic(observed), observed)
            self.assertIs(legacy.entry_failure(dict(stage='details_catalog',
                code=None, diagnostic=observed))['diagnostic'], observed)
        for reply in details.ORIGINALS_ARTWORK_REPLIES:
            observed = dict(base, schema=2, last_entered_step='shotRequest',
                screen='set-originals', theme='dark', reply=reply)
            self.assertIs(details.failure_diagnostic(observed), observed)
            self.assertIs(legacy.entry_failure(dict(stage='details_catalog',
                code=None, diagnostic=observed))['diagnostic'], observed)
            with self.subTest(reply=reply), self.assertRaises(details.Refused):
                details.failure_diagnostic(dict(observed, screen='receive-qr'))
            with self.subTest(reply=reply), self.assertRaises(details.Refused):
                details.failure_diagnostic(dict(valid, schema=2, reply=reply))
        for reply in details.PILLAR_ARTWORK_REPLIES:
            schema = details.PILLAR_DONE_SCHEMA
            observed = dict(schema=2, kind=details.RESTORED_FAILURE_KINDS[schema],
                last_entered_step='shotRequest', screen='pillar-done',
                theme='dark', reply=reply)
            self.assertIs(details.failure_diagnostic(observed,
                catalog_schema=schema), observed)
            for invalid in (
                dict(observed, screen='set-originals'),
                dict(observed, last_entered_step='scriptLine', line=1),
                dict(observed, path='Synthetic private path'),
            ):
                with self.subTest(invalid=invalid), self.assertRaises(details.Refused):
                    details.failure_diagnostic(invalid, catalog_schema=schema)
            with self.assertRaises(details.Refused):
                details.failure_diagnostic(observed)
        schema = details.PILLAR_SPAWN_SCHEMA
        spawn = dict(schema=2, kind=details.RESTORED_FAILURE_KINDS[schema],
            last_entered_step='shotRequest', screen='spawn', theme='dark',
            reply='pillarDraftOverlay')
        self.assertIs(details.failure_diagnostic(spawn,
            catalog_schema=schema), spawn)
        for invalid in (
            dict(spawn, screen='pillar-done'),
            dict(spawn, last_entered_step='scriptLine', line=1),
            dict(spawn, detail='Synthetic private path'),
        ):
            with self.subTest(invalid=invalid), self.assertRaises(details.Refused):
                details.failure_diagnostic(invalid, catalog_schema=schema)
        with self.assertRaises(details.Refused):
            details.failure_diagnostic(spawn, catalog_schema=details.PILLAR_DONE_SCHEMA)
        # These are existing original Dart refusals, including Ready frames.
        for reply in ('targetUnavailable', 'frameBusy',
                      'frameDeadlineExceeded', 'frameOriginalFailed',
                      'frameAdmissionFailed'):
            observed = dict(base, schema=2, last_entered_step='shotRequest',
                screen='wallet-ready', theme='dark', reply=reply)
            self.assertIs(details.failure_diagnostic(observed,
                catalog_schema=10), observed)
            self.assertIs(legacy.entry_failure(dict(stage='wallet_ready_catalog',
                code=None, diagnostic=observed))['diagnostic'], observed)
        state = dict(schema=1, scheduler_phase='idle', lifecycle_state='resumed',
            frames_enabled=True, has_scheduled_frame=True, binding_current=True)
        callback_state = dict(state, schema=2, begin_frame_callback_registered=True,
            draw_frame_callback_registered=True, persistent_callbacks_observed=0)
        for frame_state in (state, callback_state):
            for reply in ('frameBusy', 'frameDeadlineExceeded',
                          'frameOriginalFailed', 'frameAdmissionFailed'):
                observed = dict(base, schema=3, last_entered_step='shotRequest',
                    screen='wallet-ready', theme='dark', reply=reply,
                    frame_state=frame_state)
                self.assertIs(details.failure_diagnostic(observed,
                    catalog_schema=10), observed)
                self.assertIs(legacy.entry_failure(dict(stage='wallet_ready_catalog',
                    code=None, diagnostic=observed))['diagnostic'], observed)
                self.assertIs(legacy.capture_frame_state(frame_state), frame_state)
        frame_diagnostic = dict(base, schema=3, last_entered_step='shotRequest',
            screen='wallet-ready', theme='dark', reply='frameDeadlineExceeded',
            frame_state=callback_state)
        for broken in (
            dict(callback_state, schema=True),
            dict(callback_state, persistent_callbacks_observed=True),
            dict(callback_state, persistent_callbacks_observed=-1),
            dict(callback_state, persistent_callbacks_observed=65536),
            dict(callback_state, persistent_callbacks_observed='Synthetic private frame'),
            dict(callback_state, begin_frame_callback_registered=1),
            dict(callback_state, draw_frame_callback_registered='Synthetic callback'),
            dict(callback_state, private_path='Synthetic private path'),
            {key: value for key, value in callback_state.items()
             if key != 'frames_enabled'},
        ):
            with self.subTest(frame=broken), self.assertRaises(details.Refused):
                details.failure_diagnostic(dict(frame_diagnostic,
                    frame_state=broken), catalog_schema=10)
            with self.subTest(frame=broken), self.assertRaises(legacy.Refused):
                legacy.entry_failure(dict(stage='wallet_ready_catalog', code=None,
                    diagnostic=dict(frame_diagnostic, frame_state=broken)))
        for reply in details.FAILURE_REPLIES:
            if reply not in ('frameBusy', 'frameDeadlineExceeded',
                             'frameOriginalFailed', 'frameAdmissionFailed'):
                with self.subTest(reply=reply), self.assertRaises(details.Refused):
                    details.failure_diagnostic(dict(frame_diagnostic, reply=reply),
                        catalog_schema=10)
        for delta in (
            dict(schema=1, reply='unknown'), dict(schema=2),
            dict(schema=2, reply=True), dict(schema=2, reply=23),
            dict(schema=2, reply='Synthetic private path'),
            dict(schema=2, reply='scroll --dy 250'),
            dict(schema=2, reply='targetCovered',
                raw='Synthetic private input'),
            dict(schema=3, reply='unknown'),
        ):
            with self.subTest(delta=delta), self.assertRaises(details.Refused):
                details.failure_diagnostic(dict(valid, **delta))
        self.assertIs(legacy.entry_failure(dict(stage='details_catalog',
            code=None, diagnostic=valid))['diagnostic'], valid)
        for delta in (
            dict(schema=True), dict(kind='other'),
            dict(last_entered_step='Synthetic private step'),
            dict(screen='Synthetic private path'), dict(theme='dark'),
            dict(line=True), dict(line=1),
            dict(command='Synthetic private input'), dict(extra='unapproved'),
        ):
            with self.subTest(delta=delta), self.assertRaises(details.Refused):
                details.failure_diagnostic(dict(base, **delta))
        for delta in (
            dict(screen='home-rest'), dict(theme='ar'), dict(line=True),
            dict(line=0), dict(line=65536), dict(last_entered_step='preflight'),
            dict(extra='Synthetic private path'),
        ):
            with self.subTest(delta=delta), self.assertRaises(legacy.Refused):
                legacy.entry_failure(dict(stage='details_catalog', code=None,
                    diagnostic=dict(valid, **delta)))
        for missing in ('screen', 'theme', 'line'):
            broken = dict(valid)
            broken.pop(missing)
            with self.subTest(missing=missing), self.assertRaises(details.Refused):
                details.failure_diagnostic(broken)
        with self.assertRaises(legacy.Refused):
            legacy.entry_failure(dict(stage='details_catalog',
                code='wallet-recipe-other', diagnostic=valid))

    def test_exact_archive_pins_pixels_and_namespace_are_bound_independently(self):
        report, images = fixture()
        raw, reference = bundle(report, images)
        def inspect(data, ref=reference, pins=PINS):
            return details.unpack(data, details.sha(data), len(data),
                HEAD, TREE, RUN, ref, pins)
        result = inspect(raw)
        self.assertEqual(result['filenames'], list(FILES))
        self.assertEqual(result['verified_png_count'], 10)
        self.assertEqual(result['scope'], 'retained_readonly_details_catalog')
        self.assertIs(result['catalog_capture_qualified'], False)
        self.assertIs(result['parent_closure_qualified'], False)
        self.assertIs(result['runtime_started'], False)
        self.assertEqual(result['visual_matches'], 0)
        for delta in (
            dict(schema=True), dict(captured=9), dict(captured=True),
            dict(scope='readonly_native_home_catalog_reference'),
            dict(screens=list(reversed(SCREENS))),
            dict(manifest_sha256='3' * 64), dict(unexpected='unapproved'),
        ):
            with self.subTest(reference=delta), self.assertRaises(details.Refused):
                inspect(raw, dict(reference, **delta))
        swapped = dict(PINS, **{SCREENS[0]: 'f' * 64})
        with self.assertRaises(details.Refused):
            inspect(raw, pins=swapped)
        altered = []
        for key, value in (
            ('source_sha', '3' * 40), ('source_tree', '3' * 40),
            ('run_id', '8'), ('run_attempt', '2'),
            ('script_sha256_by_screen', swapped),
            ('unexpected', 'unapproved'),
        ):
            altered.append((dict(report, **{key: value}), images, None))
        reverse = copy.deepcopy(report)
        reverse['captures'].reverse()
        altered.append((reverse, images, None))
        aliases = dict(images)
        aliases['01-home-rest-dark.png'] = aliases.pop(FILES[0])
        altered.append((report, aliases, None))
        changed = dict(images, **{FILES[0]: images[FILES[0]] + b'extra'})
        altered.append((report, changed, None))
        altered.append((report, images, FILES[0]))
        for index, (value, payload, link) in enumerate(altered):
            data, ref = bundle(value, payload, link=link)
            with self.subTest(archive=index), self.assertRaises(details.Refused):
                inspect(data, ref)

    def test_restored_catalog_requires_exact_files_and_seed_receipts(self):
        original, original_images = fixture()
        families = (
            (4, ['staking', 'token-mine'],
                ['13-staking-dark.png', '13-staking-light.png',
                 '24-token-mine-dark.png', '24-token-mine-light.png']),
            (6, ['staking-new'], ['14-staking-new-dark.png', '14-staking-new-light.png']),
            (7, ['az-project'], ['29-az-project-dark.png', '29-az-project-light.png']),
            (13, ['spawn'], ['19-spawn-dark.png', '19-spawn-light.png']),
            (14, ['pillar-done'],
                ['20-pillar-done-dark.png', '20-pillar-done-light.png']),
            (15, ['swap-list'],
                ['26-swap-list-dark.png', '26-swap-list-light.png']),
            (16, ['az', 'az-project'],
                ['28-az-dark.png', '28-az-light.png',
                 '29-az-project-dark.png', '29-az-project-light.png']),
            (18, ['staking', 'tokens', 'token-mine'],
                ['13-staking-dark.png', '13-staking-light.png',
                 '23-tokens-dark.png', '23-tokens-light.png',
                 '24-token-mine-dark.png', '24-token-mine-light.png']),
        )
        self.assertEqual(details.catalog_script_name(16, 'az'), 'prepared/az.txt')
        self.assertEqual(details.catalog_script_name(16, 'az-project'), 'az-project.txt')
        self.assertEqual(details.catalog_script_name(7, 'az-project'), 'az-project.txt')
        self.assertEqual(details.catalog_script_name(18, 'tokens'), 'prepared/tokens.txt')
        self.assertEqual(details.catalog_script_name(4, 'token-mine'), 'token-mine.txt')
        self.assertEqual(details.catalog_script_name(18, 'token-mine'), 'token-mine.txt')
        for schema, screens, files in families:
            with self.subTest(schema=schema):
                pins = {screen: str(index)*64
                        for index, screen in enumerate(screens, 7)}
                capture = dict(receipt(), schema=schema,
                    scope='restored_native_seeded_catalog_capture',
                    screens=screens, files=files)
                report = dict(original, schema=schema,
                    scope='restored_native_seeded_catalog_capture_bundle',
                    capture=capture, script_sha256_by_screen=pins,
                    seed_receipts_sha256='9'*64,
                    captures=[dict(row, file=name)
                              for row, name in zip(original['captures'], files)])
                images = dict(zip(files, original_images.values()))
                raw, reference = bundle(report, images)
                result = details.unpack(raw, details.sha(raw), len(raw),
                    HEAD, TREE, RUN, reference, pins, include_image_pins=True)
                self.assertEqual(result['scope'], 'retained_restored_seeded_catalog')
                self.assertEqual(result['filenames'], files)
                self.assertEqual(result['images'],
                    {name: details.sha(image) for name, image in images.items()})
                self.assertEqual(result['seed_receipts_sha256'], '9'*64)
                self.assertFalse(result['catalog_capture_qualified'])
                self.assertFalse(result['parent_closure_qualified'])
                with self.assertRaises(details.Refused):
                    details.unpack(raw, details.sha(raw), len(raw), HEAD, TREE, RUN,
                        dict(reference, seed_receipts_sha256='a'*64), pins)
                extra, _ = bundle(report, dict(images, **{'unexpected.png': png()}))
                with self.assertRaises(details.Refused):
                    details.unpack(extra, details.sha(extra), len(extra),
                        HEAD, TREE, RUN, reference, pins)
                missing, _ = bundle(report, {name: image for name, image in images.items()
                                            if name != files[-1]})
                with self.assertRaises(details.Refused):
                    details.unpack(missing, details.sha(missing), len(missing),
                        HEAD, TREE, RUN, reference, pins)
                with self.assertRaises(legacy.Refused):
                    legacy.inspection_catalog_reference(dict(schema=4,
                        home_catalog=None, settings_catalog=None,
                        navigation_catalog=None, details_catalog=reference))


if __name__ == '__main__':
    unittest.main()
