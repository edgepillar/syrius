"""Isolated inspection controls. No SDK, node, process or native wallet runs."""

import base64
import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import stat
import struct
from types import SimpleNamespace
import unittest
from unittest import mock
import zlib

from tool.ci import hosted_chain321 as lab
from tool.ci import windows_wallet_inspection as inspection
import test_readonly_viewport_capture as viewport_fixtures
import test_readonly_settings_capture as settings_fixtures
import test_readonly_navigation_capture as navigation_fixtures
import test_readonly_details_capture as details_fixtures


def settings_manifest(pixels, script):
    value, _ = settings_fixtures.fixture()
    value.update(source_sha='a' * 40, source_tree='b' * 40,
        run_id='1', script_sha256_by_screen={
            name: hashlib.sha256(script).hexdigest()
            for name in inspection.settings.SCREENS})
    for row in value['captures']:
        row.update(bytes=len(pixels), sha256=hashlib.sha256(pixels).hexdigest())
    return value


def settings_reference(digest):
    return dict(schema=1, scope='readonly_native_settings_catalog_reference',
        screens=list(inspection.settings.SCREENS), captured=14, manifest_sha256=digest)


def navigation_manifest(pixels, script):
    value, _ = navigation_fixtures.fixture()
    value.update(source_sha='a' * 40, source_tree='b' * 40,
        run_id='1', script_sha256_by_screen={
            name: hashlib.sha256(script).hexdigest()
            for name in inspection.navigation.SCREENS})
    for row in value['captures']:
        row.update(bytes=len(pixels), sha256=hashlib.sha256(pixels).hexdigest())
    return value


def navigation_reference(digest):
    return dict(schema=1, scope='readonly_native_navigation_catalog_reference',
        screens=list(inspection.navigation.SCREENS), captured=14, manifest_sha256=digest)


def details_manifest(pixels, script, *, schema=1):
    value, _ = details_fixtures.fixture()
    screens = inspection.details.catalog_screens(schema)
    files = inspection.details.catalog_files(schema)
    value.update(schema=schema, source_sha='a' * 40, source_tree='b' * 40,
        run_id='1', script_sha256_by_screen={
            name: hashlib.sha256(script).hexdigest()
            for name in screens})
    value['capture'].update(schema=schema, screens=list(screens), files=list(files))
    value['captures'] = [dict(row, file=name, bytes=len(pixels),
        sha256=hashlib.sha256(pixels).hexdigest())
        for row, name in zip(value['captures'], files)]
    if schema in (inspection.details.FAMILY_SCHEMAS['swap-start'],
                  inspection.details.FAMILY_SCHEMAS['wallet-ready'],
                  inspection.details.FAMILY_SCHEMAS['send-warn'],
                  inspection.details.FAMILY_SCHEMAS['home-zap-preview']):
        light = png(255)
        value['captures'][1].update(bytes=len(light), sha256=hashlib.sha256(light).hexdigest())
    return value


def details_reference(digest, *, schema=1):
    return dict(schema=schema, scope='readonly_native_details_catalog_reference',
        screens=list(inspection.details.catalog_screens(schema)),
        captured=len(inspection.details.catalog_files(schema)), manifest_sha256=digest)


def catalog_only_report(value, digest, family):
    bell = family == 'home-bell'
    report = dict(value, schema=lab.READONLY_CATALOG_SCHEMAS[family],
        captures=[], tours={}, locales={}, stalls={},
        home_catalog=home_reference(digest, schema=inspection.HOME_BELL_CAPTURE_SCHEMA) if bell else None,
        settings_catalog=None, navigation_catalog=None, viewport=None,
        details_catalog=None if bell else details_reference(
            digest, schema=inspection.details.FAMILY_SCHEMAS[family]),
        checks=dict(value['checks'], tours_complete=False, locale_verified=False))
    if family == 'send-warn':
        report['send_warning_window'] = dict(started=True, released=True, samples=[
            dict(theme=theme, state=1, current_height=9, minimum_target_height=12 + index,
                 minimum_lag=3 + index)
            for index, theme in enumerate(('dark', 'light'))])
    return report


def sdk():
    return dict(schema=1, scope='readonly_native_sdk_admission', status='CURRENT',
        publicationAdmissionPaused=True, automaticReceiveDisabled=True)


def wallet():
    return dict(schema=1, scope='readonly_native_wallet_admission', status='CURRENT',
        chain=321, selectedIndex=1, nativeFrameObserved=True)


def layout():
    rows = [dict(key=key, status='MISSING') for key in ('window-caption', 'window-body', 'home_hero', 'home_send', 'nodes_tab_pillars', 'nodes_tab_sentinels', 'staking_stake_button', 'plasma_open_fuse', 'tokens_filter_held', 'p2p_start_swap', 'node_settings_add', 'apps_settings_web_switch', 'transfer_card', 'accelerator_strip', 'bell_panel')]
    return dict(schema=1, scope='readonly_shot_layout_observation',
        boundaries=['before_raster', 'after_encoding'], before=rows,
        after=copy.deepcopy(rows), unchanged=True)


def tour(theme):
    return dict(theme=theme, tour=dict(schema=1, scope='readonly_native_page_tour',
        complete=True, requested=list(inspection.PAGES), visited=[dict(page=p,
            nodes=1, error_widgets=0, severe_logs=0, captured=True,
            layout=layout()) for p in inspection.PAGES]))


def home_receipt(*, schema=1):
    value = dict(schema=schema, scope='readonly_native_home_catalog_capture',
        themes=['dark', 'light'], files=list(inspection.home_catalog_files(schema)),
        width=1280, height=780, scale=1, capture_returned=True)
    value.update(dict(screen='home-rest', number=1) if schema == 1
                 else dict(screens=list(inspection.home_catalog_screens(schema))))
    return value


def home_reference(digest='e' * 64, *, schema=1):
    value = dict(schema=schema, scope='readonly_native_home_catalog_reference',
        captured=len(inspection.home_catalog_files(schema)), manifest_sha256=digest)
    value.update(dict(screen='home-rest') if schema == 1
                 else dict(screens=list(inspection.home_catalog_screens(schema))))
    return value


def home_manifest(pixels, script=b'synthetic public script', *, schema=1,
                  hidden_script=None, open_script=None, goto_script=None):
    value = dict(schema=schema, scope='readonly_native_home_catalog_capture_bundle',
        source_sha='a' * 40, source_tree='b' * 40, run_id='1', run_attempt='1',
        capture=home_receipt(schema=schema),
        captures=[dict(theme=inspection.THEMES[index % 2], file=name,
            bytes=len(pixels), sha256=hashlib.sha256(pixels).hexdigest(),
            width=1280, height=780, scale=1)
            for index, name in enumerate(inspection.home_catalog_files(schema))],
        inspection_only=True, parent_closure_qualified=False,
        atomic_frame_qualified=False, wallet_qualified=False, seed_admitted=False,
        financial_send_qualified=False, visual_matches=0)
    first = hashlib.sha256(script).hexdigest()
    if schema == 1:
        value['script_sha256'] = first
    elif schema == inspection.HOME_BELL_CAPTURE_SCHEMA:
        value['script_sha256_by_screen'] = {'home-bell': first}
        light = png(255)
        value['captures'][1].update(bytes=len(light), sha256=hashlib.sha256(light).hexdigest())
    else:
        hidden = hashlib.sha256(script if hidden_script is None else hidden_script).hexdigest()
        if schema == 2:
            value['script_sha256_by_screen'] = dict(zip(inspection.HOME_STATE_SCREENS, (first, hidden)))
        else:
            value['script_sha256_by_screen'] = dict(zip(inspection.HOME_OPEN_SCREENS,
                (first, hashlib.sha256(script if open_script is None else open_script).hexdigest(), hidden)))
            if schema == 4:
                value['script_sha256_by_screen']['home-goto'] = hashlib.sha256(
                    script if goto_script is None else goto_script).hexdigest()
    return value


def report():
    return dict(schema=1, scope='owned_chain321_wallet_inspection', success=True,
        inspection_qualified=True, wallet_qualified=False, seed_admitted=False, visual_matches=0,
        checks=dict.fromkeys(inspection.CHECKS, True), errors=[], phase='complete',
        captures=[dict(theme=t, page=p, bytes=100, sha256='c' * 64, width=1280, height=780)
                  for t in inspection.THEMES for p in inspection.PAGES],
        tours={t: tour(t) for t in inspection.THEMES},
        locales={t: dict(schema=1, scope='readonly_native_locale_observation', theme=t,
            language='en', direction='ltr', stable=True) for t in inspection.THEMES},
        stalls={t: dict(schema=1, scope='readonly_native_stalls_observation', theme=t,
            events=0, longest_ms=0) for t in inspection.THEMES},
        sdk_admission=sdk(), wallet_admission=wallet(), home_catalog=home_reference(),
        viewport=dict(schema=1, scope='readonly_native_viewport_reference',
                      captured=4, manifest_sha256='e' * 64),
        address_selection=dict(index=1, members=2, generated=False, selected=True, persisted=True),
        lab_revalidations=2, forced_cleanup=False, required_actor_forced_cleanup=False,
        auxiliary_cleanup=dict(scope=inspection.debug.HELPER_SCOPE, status='PASSED',
            code=None, forced=False, remaining=0, receipts=[], observation=dict(
                stage='complete', image_class=None, image_bytes=None, path_match=None)),
        min_free_bytes=inspection.shared.FIXTURE_FLOOR,
        workspace_cap_bytes=inspection.shared.WORK_CAP,
        storage_scope='isolated_hosted_regression_fixture_cooperative_samples',
        storage=dict(samples=1, peak_logical_bytes=2400, minimum_free_bytes=8 * 1024**3, refusal=None),
        cleanup='runner_lifecycle_not_qualified', financial_send_qualified=False,
        motion_baseline_compared=False, arabic_or_minimum_window_qualified=False,
        source_sha='a' * 40, source_tree='b' * 40, run_id='1', run_attempt='1',
        input_attempted=True, application_exit=0, entry_exit=0,
        owned_job_images_before_close=dict(status='OBSERVED', listed=0, observed=0, counts={}),
        owned_job_active_at_close=0, entry_output=dict(bytes=1, sha256='d' * 64,
            output_complete=True, overflow=False))


def png(sample=0):
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack(
            '>I', zlib.crc32(kind + body) & 0xffffffff)
    row = b'\0' + bytes((sample, sample, sample, 255)) * 1280
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',
        1280, 780, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(row * 780)) + chunk(b'IEND', b''))


class _Output(io.StringIO):
    def close(self):
        pass


class InspectionTests(unittest.TestCase):
    def test_catalog_choice_is_admitted_before_any_runtime_allocation(self):
        parent = dict(SYRIUS_WINDOWS_WALLET_INSPECTION='true',
            SYRIUS_WINDOWS_WALLET_TOUR='false', SYRIUS_LAB_NODE_SOURCE='lab-fix',
            SYRIUS_NATIVE_STACK_DIAGNOSTIC='true')
        self.assertEqual(lab.readonly_catalog_family(parent), 'details')
        for family, schema in (('home', 1), ('home-seams', 1), ('surface-seams', 13), ('home-bell', 8), ('settings', 2),
                               ('settings-seams', 2),
                               ('navigation', 3), ('details', 4),
                               ('token-draft', 4), ('send-confirm', 5),
                               ('earn', 6), ('sentinel-fixture', 7),
                               ('swap-start', 9), ('wallet-ready', 10), ('send-warn', 11),
                               ('home-zap-preview', 12)):
            selected = dict(parent, SYRIUS_READONLY_CATALOG_FAMILY=family)
            self.assertTrue(lab.wallet_inspection_requested('native', selected))
            self.assertEqual(lab.READONLY_CATALOG_SCHEMAS[
                lab.readonly_catalog_family(selected)], schema)
        for value in (None, True, 1, '', 'Home', 'all', 'home,navigation',
                      '../home', 'launch', 'launch-settle', 'launch-timing', 'launch-timing-pair', 'interactive-timing-pair',
                      'lock-catalog', 'lock-seams', 'quiz-catalog', 'seeded-states',
                      'stake-draft', 'project-detail', 'pillar-spawn',
                      'pillar-done', 'swap-seeded'):
            with self.subTest(value=value), self.assertRaises(lab.Failure):
                lab.wallet_inspection_requested('native',
                    dict(parent, SYRIUS_READONLY_CATALOG_FAMILY=value))
        workflow = Path('.github/workflows/public-contribution-qualification.yml').read_text()
        choice = workflow.split('      readonly_catalog_family:', 1)[1].split('      chain321_lab:', 1)[0]
        self.assertIn('type: choice', choice)
        self.assertIn('default: details', choice)
        self.assertEqual([line.strip()[2:] for line in choice.splitlines()
            if line.strip().startswith('- ')],
            ['home', 'home-seams', 'surface-seams', 'home-bell', 'home-zap-preview', 'settings', 'settings-seams',
             'navigation', 'details', 'token-draft',
             'send-confirm', 'send-warn', 'swap-start', 'wallet-ready', 'earn',
             'sentinel-fixture', 'launch', 'launch-settle', 'launch-timing', 'launch-timing-pair', 'interactive-timing-pair',
             'lock-catalog', 'lock-seams', 'quiz-catalog', 'seeded-states',
             'swap-seeded', 'stake-draft', 'project-detail', 'pillar-spawn',
             'pillar-done'])
        self.assertIn('SYRIUS_READONLY_CATALOG_FAMILY: ${{ inputs.readonly_catalog_family }}', workflow)
        for family in ('send-warn', 'settings-seams', 'home-seams', 'surface-seams'):
            scoped = dict(parent, SYRIUS_READONLY_CATALOG_FAMILY=family,
                SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_ACTIONS='true',
                GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='edgepillar/syrius',
                GITHUB_SHA='a' * 40, GITHUB_RUN_ATTEMPT='1', GITHUB_REF='refs/heads/redesign')
            with mock.patch.object(lab.sys, 'platform', 'win32'):
                self.assertFalse(lab.require_environment('native', scoped))
                if family == 'surface-seams':
                    with self.assertRaises(lab.Failure):
                        lab.require_environment('native', dict(scoped, GITHUB_REF='refs/heads/dev'))
                for change in (dict(GITHUB_REPOSITORY='sol-znn/syrius'),
                        dict(GITHUB_RUN_ATTEMPT='2'), dict(SYRIUS_WINDOWS_WALLET_INSPECTION='false')):
                    with self.assertRaises(lab.Failure):
                        lab.require_environment('native', dict(scoped, **change))
        for family, title, stem in (
            ('stake-draft', 'New stake draft', '14-staking-new'),
            ('project-detail', 'Project detail', '29-az-project'),
            ('pillar-spawn', 'Pillar Spawn', '19-spawn'),
            ('pillar-done', 'Pillar Done', '20-pillar-done'),
            ('swap-seeded', 'seeded Swap list', '26-swap-list'),
        ):
            marker = f'      - name: Retain the two verified {title} captures\n'
            upload = workflow.split(marker, 1)[1].split('\n      - name:', 1)[0]
            self.assertIn("success() && inputs.windows_wallet_tour && "
                          f"inputs.readonly_catalog_family == '{family}'", upload)
            self.assertEqual([line.strip() for line in upload.splitlines()
                              if line.strip().startswith('.harness/')], [
                '.harness/ci-seeded-catalog/manifest.json',
                f'.harness/ci-seeded-catalog/{stem}-dark.png',
                f'.harness/ci-seeded-catalog/{stem}-light.png',
            ])

    def test_settings_seam_pointers_stop_on_scope_or_address_change(self):
        targets = [
            ('sporks', 'node_settings_sporks_gate'),
            ('autoLockOnClose', 'security_lock_close'),
            ('biometricUnlock', 'security_settings_biometric_gate'),
            ('wrongPasswordLimitOff', 'security_limit_off'),
            ('passwordChangeMigration', 'security_settings_password_gate'),
            ('operatorModes', 'wallet_settings_modes_gate'),
            ('walletPicker', 'wallet_settings_wallets_gate'),
            ('walletUpdateNotice', 'about_update_gate'),
        ]
        for fault in (None, 'scope', 'address'):
            with self.subTest(fault=fault):
                tab = 'dashboard'
                address = 'original'
                inputs = []
                observed = []

                def send(command):
                    nonlocal tab, address
                    inputs.append(command)
                    name = command['cmd']
                    if name == 'tap' and 'tab' in command:
                        tab = command['tab']
                    if name == 'state':
                        return dict(tab=tab, address=address, locale='en',
                            direction='ltr', node='ws://127.0.0.1:45998',
                            chainId=321, signingChainId=321, savedSigningChainId=321,
                            walletUnlocked=True, walletInitCompleted=True,
                            embeddedNode=False, nodeTransitionPending=False)
                    if name == 'readonly-seam-pointer':
                        if fault == 'address':
                            address = 'replacement'
                        return dict(scope='unrelated' if fault == 'scope'
                            else 'readonly_native_seam_pointer_observation',
                            seam=command['seam'], pointerDispatched=True,
                            absorptionObserved=True)
                    if name == 'logs':
                        return dict(logs=[])
                    return {}

                if fault is None:
                    inspection.observe_settings_seam_pointers(send, observed)
                    self.assertEqual(tab, 'dashboard')
                    self.assertEqual([row['seam'] for row in observed],
                                     [seam for seam, _ in targets])
                    self.assertEqual(inputs[-1]['cmd'], 'logs')
                else:
                    with self.assertRaises(inspection.Refused):
                        inspection.observe_settings_seam_pointers(send, observed)
                    self.assertEqual(observed, [])
                self.assertEqual([(row['seam'], row['key']) for row in inputs
                    if row['cmd'] == 'readonly-seam-pointer'],
                    targets if fault is None else targets[:1])

    def test_home_seams_require_original_palette_after_keyboard(self):
        for changed_route in (False, True):
            with self.subTest(changed_route=changed_route):
                route = 'original-home'
                theme = 'dark'
                inputs, observed = [], []

                def send(command):
                    nonlocal route, theme
                    inputs.append(command)
                    name = command['cmd']
                    if name == 'state':
                        return dict(tab='dashboard', route=route, address='original',
                            locale='en', direction='ltr', node='ws://127.0.0.1:45998',
                            chainId=321, signingChainId=321, savedSigningChainId=321,
                            walletUnlocked=True, walletInitCompleted=True,
                            embeddedNode=False, nodeTransitionPending=False)
                    if name == 'key':
                        chord = command['key']
                        if chord in ('down', 'enter'):
                            self.assertEqual(command['paletteGate'],
                                             'go_to_gate_action:zap')
                        if chord == 'ctrl+k':
                            route = 'original-palette'
                        elif chord == 'enter' and changed_route:
                            route = 'replacement'
                        elif chord == 'escape':
                            route = 'original-home'
                    if name == 'type':
                        return dict(value=command['value'])
                    if name == 'theme':
                        theme = command.get('mode', command.get('restore', {}).get('mode', theme))
                        return dict(mode=theme)
                    if name == 'readonly-activity-message-seam':
                        return dict(schema=1,
                            scope='readonly_native_activity_message_seam_observation',
                            seam='zapReceive', theme=theme, pointerDispatched=True,
                            absorptionObserved=True, originalHistoryRetained=True,
                            previewOnly=True)
                    if name == 'readonly-seam-pointer':
                        return dict(scope='readonly_native_seam_pointer_observation',
                            seam=command['seam'], pointerDispatched=True,
                            absorptionObserved=True)
                    if name == 'logs':
                        return dict(logs=[])
                    return {}

                with mock.patch.object(inspection, 'observe_readonly_owner_seams') as owner:
                    if changed_route:
                        with self.assertRaises(inspection.Refused):
                            inspection.observe_home_seam_pointers(send, observed)
                        owner.assert_not_called()
                    else:
                        inspection.observe_home_seam_pointers(send, observed)
                        owner.assert_called_once_with(send, observed)
                        self.assertEqual(route, 'original-home')
                        self.assertEqual(inputs[-1]['cmd'], 'logs')
                expected = [dict(panel='home', seam='zapSend'),
                    dict(panel='activity', seam='activityAddressScope')]
                if not changed_route:
                    expected.append(dict(panel='go-to', seam='zapSend',
                                         keyboard_refused=True))
                    expected.extend(dict(panel='activity-preview', seam='zapReceive',
                        theme=value, preview_only=True) for value in ('dark', 'light'))
                self.assertEqual(observed, expected)
                chords = [v['key'] for v in inputs if v['cmd'] == 'key']
                self.assertEqual(chords, ['ctrl+k', 'down', 'enter']
                    + ([] if changed_route else ['escape']))
                self.assertEqual([v['key'] for v in inputs
                    if v['cmd'] == 'readonly-seam-pointer'],
                    ['home_zap', 'activity_scope_filter', 'go_to_gate_action:zap'])

    def test_lab_failure_projection_retains_only_fixed_codes_and_refuses_success(self):
        labels = []
        for code in lab.CODES:
            error = RuntimeError('Synthetic private exception text')
            error.code = code
            self.assertEqual(inspection.inspection_failure_code(error,
                'lab_revalidation'), code)
            labels.append(code)
        for error, label in ((TimeoutError('private'), 'LAB_REVALIDATION_TIMEOUT_ERROR'),
            (ConnectionError('private'), 'LAB_REVALIDATION_CONNECTION_ERROR'),
            (KeyError('private'), 'LAB_REVALIDATION_KEY_ERROR'),
            (TypeError('private'), 'LAB_REVALIDATION_TYPE_ERROR'),
            (ValueError('private'), 'LAB_REVALIDATION_VALUE_ERROR'),
            (OSError('private'), 'LAB_REVALIDATION_OS_ERROR')):
            observed = inspection.inspection_failure_code(error, 'lab_revalidation')
            self.assertEqual(observed, label)
            self.assertEqual(inspection.inspection_failure_code(error,
                'onboarding_and_inspection'), 'INTERNAL_ERROR')
            self.assertFalse(inspection.completed({**report(), 'errors': [observed]}))
            labels.append(observed)
        class PrivateCode(ValueError):
            @property
            def code(self):
                raise RuntimeError('Synthetic private code lookup')
        self.assertEqual(inspection.inspection_failure_code(PrivateCode('private'),
            'lab_revalidation'), 'LAB_REVALIDATION_VALUE_ERROR')
        self.assertEqual(inspection.inspection_failure_code(
            inspection.debug.ProcessRefused('TOOL_REFUSED'), 'admission'), 'TOOL_REFUSED')
        for error in (RuntimeError('private'), KeyboardInterrupt('private')):
            self.assertEqual(inspection.inspection_failure_code(error,
                'lab_revalidation'), 'INTERNAL_ERROR')
        self.assertNotIn('private', json.dumps(labels))

    def test_home_bell_requires_its_own_pair_and_inspection_schema(self):
        schema = inspection.HOME_BELL_CAPTURE_SCHEMA
        manifest = home_manifest(png(), schema=schema)
        inspection.public_home_catalog(manifest)
        duplicate = copy.deepcopy(manifest)
        duplicate['captures'][1]['sha256'] = duplicate['captures'][0]['sha256']
        with self.assertRaises(inspection.Refused):
            inspection.public_home_catalog(duplicate)
        selected = catalog_only_report(report(), 'e' * 64, 'home-bell')
        inspection.public_manifest(selected)
        for wrong in (dict(selected, home_catalog=home_reference(schema=4)),
                      dict(report(), home_catalog=home_reference(schema=schema))):
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(wrong)

        repo = Path('/fixture')
        output = repo / inspection.HOME_OUTPUT
        first = output / inspection.HOME_BELL_FILES[0]
        children = [first]
        with mock.patch.object(Path, 'exists', lambda path: path == output), \
                mock.patch.object(Path, 'is_symlink', return_value=False), \
                mock.patch.object(Path, 'iterdir', lambda _: iter(children)), \
                mock.patch.object(inspection.debug.bounded, 'plain', side_effect=lambda path:
                    SimpleNamespace(st_mode=stat.S_IFDIR) if path == output else
                    SimpleNamespace(st_mode=stat.S_IFREG, st_nlink=1, st_size=24)):
            self.assertEqual(inspection.sample_capture_outputs(
                repo, family='home-bell', catalog_only=True), 24)
            with self.assertRaisesRegex(inspection.Refused, 'STORAGE_REFUSED'):
                inspection.sample_capture_outputs(repo, family='home', catalog_only=False)
            children.append(output / 'unregistered.png')
            with self.assertRaisesRegex(inspection.Refused, 'STORAGE_REFUSED'):
                inspection.sample_capture_outputs(repo, family='home-bell', catalog_only=True)

    def test_home_catalog_privacy_geometry_and_fixed_files_are_independent(self):
        pixels = png()
        original = home_manifest(pixels)
        self.assertIs(inspection.home_capture_receipt(original['capture']), original['capture'])
        self.assertIs(inspection.public_home_catalog(original), original)
        self.assertFalse(original['parent_closure_qualified'])
        self.assertFalse(original['atomic_frame_qualified'])
        self.assertEqual(original['visual_matches'], 0)
        missing = report()
        missing['home_catalog'] = None
        self.assertFalse(inspection.completed(missing))
        with self.assertRaises(inspection.Refused):
            inspection.public_manifest(missing)
        for change in ({'schema': True}, {'scope': 'ordinary'},
                       {'source_sha': 'Synthetic private origin'},
                       {'parent_closure_qualified': True}, {'atomic_frame_qualified': True},
                       {'wallet_qualified': True}, {'visual_matches': 1},
                       {'private_profile': 'Synthetic private path'}):
            with self.subTest(change=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(dict(copy.deepcopy(original), **change))
        for change in ({'files': ['dashboard.png', '01-home-rest-light.png']},
                       {'themes': ['dark', 'dark']}, {'number': True},
                       {'capture_returned': False}, {'width': 1279}, {'scale': True}):
            value = copy.deepcopy(original)
            value['capture'].update(change)
            with self.subTest(capture=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(value)
        for change in ({'file': '../private.png'}, {'theme': 'light'}, {'bytes': True},
                       {'bytes': inspection.MAX_HOME_CAPTURE_TOTAL + 1},
                       {'sha256': 'Synthetic private value'}, {'width': 1279},
                       {'path': 'Synthetic private path'}):
            value = copy.deepcopy(original)
            value['captures'][0].update(change)
            with self.subTest(image=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(value)
        # The duplicated field is refused before script or pixel consumption.
        duplicate = b'{"schema":1,' + json.dumps(original).encode('ascii')[1:]
        owner = report()
        owner['home_catalog'] = home_reference(hashlib.sha256(duplicate).hexdigest())
        with mock.patch.object(inspection, 'home_output_bytes', return_value=len(duplicate)), \
                mock.patch.object(inspection, 'read_original', return_value=duplicate) as read:
            with self.assertRaises(inspection.Refused):
                inspection.home_artifact_paths(Path('/fixture'), owner)
            self.assertEqual(read.call_count, 1)
        output = Path('/fixture/home')
        with mock.patch.object(Path, 'exists', return_value=True), \
                mock.patch.object(Path, 'iterdir', return_value=iter([output / 'unregistered.bin'])), \
                mock.patch.object(inspection.debug.bounded, 'plain',
                    return_value=SimpleNamespace(st_mode=stat.S_IFDIR)):
            with self.assertRaises(inspection.Refused):
                inspection.home_output_bytes(output)

        states = home_manifest(pixels, schema=2)
        self.assertIs(inspection.public_home_catalog(states), states)
        self.assertEqual(states['capture']['screens'], ['home-rest', 'home-hidden'])
        self.assertEqual(len(states['captures']), 4)
        for change in (
            lambda value: value['capture'].update(screens=['home-rest', 'home-rest']),
            lambda value: value['capture'].update(schema=1),
            lambda value: value['captures'].pop(),
            lambda value: value['captures'][2].update(file='01-home-rest-dark.png'),
            lambda value: value['captures'][2].update(theme='light'),
            lambda value: value['script_sha256_by_screen'].pop('home-hidden'),
            lambda value: value['script_sha256_by_screen'].update(private='synthetic'),
            lambda value: value.update(script_sha256='e' * 64),
        ):
            bad = copy.deepcopy(states)
            change(bad)
            with self.subTest(schema=2, change=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(bad)
        for schema in (1, 2):
            for count in (True, 3, 6):
                reference = home_reference(schema=schema)
                reference['captured'] = count
                with self.subTest(schema=schema, captured=count), self.assertRaises(inspection.Refused):
                    inspection.home_catalog_reference(reference)

        expanded = home_manifest(pixels, schema=3)
        self.assertIs(inspection.public_home_catalog(expanded), expanded)
        self.assertEqual(expanded['capture']['screens'], ['home-rest', 'home-open', 'home-hidden'])
        self.assertEqual(len(expanded['captures']), 6)
        for change in (
            lambda value: value['capture'].update(screens=['home-rest', 'home-hidden', 'home-open']),
            lambda value: value['capture'].update(schema=2),
            lambda value: value['captures'].pop(),
            lambda value: value['captures'][2].update(file='03-home-hidden-dark.png'),
            lambda value: value['captures'][3].update(theme='dark'),
            lambda value: value['script_sha256_by_screen'].pop('home-open'),
            lambda value: value['script_sha256_by_screen'].update(private='synthetic'),
            lambda value: value.update(script_sha256='e' * 64),
        ):
            bad = copy.deepcopy(expanded)
            change(bad)
            with self.subTest(schema=3, change=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(bad)
        for count in (True, 2, 3, 4, 8):
            bad = home_reference(schema=3)
            bad['captured'] = count
            with self.subTest(schema=3, count=count), self.assertRaises(inspection.Refused):
                inspection.home_catalog_reference(bad)

        expanded = home_manifest(pixels, schema=4)
        self.assertIs(inspection.public_home_catalog(expanded), expanded)
        self.assertEqual(expanded['capture']['screens'], ['home-rest', 'home-open', 'home-hidden', 'home-goto'])
        self.assertEqual(len(expanded['captures']), 8)
        for change in (
            lambda value: value['capture'].update(screens=['home-rest', 'home-open', 'home-goto', 'home-hidden']),
            lambda value: value['capture'].update(schema=2),
            lambda value: value['captures'].pop(),
            lambda value: value['captures'][6].update(file='03-home-hidden-dark.png'),
            lambda value: value['captures'][7].update(theme='dark'),
            lambda value: value['script_sha256_by_screen'].pop('home-goto'),
            lambda value: value['script_sha256_by_screen'].update(private='synthetic'),
            lambda value: value.update(script_sha256='e' * 64),
        ):
            bad = copy.deepcopy(expanded)
            change(bad)
            with self.subTest(schema=4, change=change), self.assertRaises(inspection.Refused):
                inspection.public_home_catalog(bad)
        for count in (True, 1, 2, 3, 4, 6, 10):
            bad = home_reference(schema=4)
            bad['captured'] = count
            with self.subTest(schema=4, count=count), self.assertRaises(inspection.Refused):
                inspection.home_catalog_reference(bad)

        class RetainedBytes(io.BytesIO):
            def close(self):
                pass

        for schema in (1, 2, 3, 4):
            written = RetainedBytes()
            scripts = {'home-rest.txt': b'first original public script',
                'home-hidden.txt': b'distinct original hidden script',
                'home-open.txt': b'distinct original open script',
                'home-goto.txt': b'distinct original goto script'}

            def read(path, cap):
                if path.suffix == '.png':
                    self.assertEqual(cap, inspection.MAX_HOME_CAPTURE_TOTAL)
                    return pixels
                self.assertEqual(cap, 65536)
                return scripts[path.name]

            with mock.patch.object(inspection, 'home_output_bytes', return_value=0), \
                    mock.patch.object(inspection, 'read_original', side_effect=read) as reads, \
                    mock.patch.object(Path, 'open', return_value=written) as opened:
                reference = inspection.collect_home_catalog(Path('/fixture'),
                    home_receipt(schema=schema), 'a' * 40, 'b' * 40,
                    dict(GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1'))
            manifest = json.loads(written.getvalue())
            self.assertEqual(reference['manifest_sha256'],
                hashlib.sha256(written.getvalue()).hexdigest())
            self.assertEqual(reference['captured'], {1: 2, 2: 4, 3: 6, 4: 8}[schema])
            self.assertEqual([row['file'] for row in manifest['captures']],
                list(inspection.home_catalog_files(schema)))
            self.assertEqual(reads.call_count, {1: 3, 2: 6, 3: 9, 4: 12}[schema])
            self.assertTrue(written.getvalue().endswith(b'\n'))
            opened.assert_called_once_with('xb')
            if schema == 2:
                self.assertEqual(manifest['script_sha256_by_screen'],
                    {'home-rest': hashlib.sha256(scripts['home-rest.txt']).hexdigest(),
                     'home-hidden': hashlib.sha256(scripts['home-hidden.txt']).hexdigest()})
                self.assertFalse(manifest['parent_closure_qualified'])
                self.assertEqual(manifest['visual_matches'], 0)
            if schema == 3:
                self.assertEqual(manifest['script_sha256_by_screen'],
                    {name: hashlib.sha256(scripts[name + '.txt']).hexdigest()
                     for name in inspection.HOME_OPEN_SCREENS})
                self.assertFalse(manifest['parent_closure_qualified'])
                self.assertEqual(manifest['visual_matches'], 0)
            if schema == 4:
                self.assertEqual(manifest['script_sha256_by_screen'],
                    {name: hashlib.sha256(scripts[name + '.txt']).hexdigest()
                     for name in inspection.HOME_GOTO_SCREENS})
                self.assertFalse(manifest['parent_closure_qualified'])
                self.assertEqual(manifest['visual_matches'], 0)
        written = RetainedBytes()
        scripts = {name + '.txt': ('original ' + name).encode('ascii')
            for name in inspection.settings.SCREENS}
        def read_settings(path, cap):
            if path.suffix == '.png':
                self.assertEqual(cap, inspection.settings.MAX_CAPTURE_TOTAL)
                return pixels
            self.assertEqual(cap, 65536)
            return scripts[path.name]
        reads = mock.Mock(side_effect=read_settings)
        with mock.patch.object(inspection.settings, 'output_bytes', return_value=0), \
                mock.patch.object(Path, 'open', return_value=written) as opened:
            reference = inspection.settings.collect(Path('/fixture'),
                settings_fixtures.receipt(), 'a' * 40, 'b' * 40,
                dict(GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1'), read_original=reads)
        manifest = json.loads(written.getvalue())
        self.assertEqual(reference['manifest_sha256'], hashlib.sha256(written.getvalue()).hexdigest())
        self.assertEqual(reference['captured'], 14)
        self.assertEqual(reads.call_count, 21)
        self.assertEqual(manifest['script_sha256_by_screen'],
            {name: hashlib.sha256(scripts[name + '.txt']).hexdigest()
             for name in inspection.settings.SCREENS})
        self.assertEqual([row['file'] for row in manifest['captures']], list(inspection.settings.FILES))
        self.assertFalse(manifest['parent_closure_qualified'])
        self.assertEqual(manifest['visual_matches'], 0)
        opened.assert_called_once_with('xb')
        written = RetainedBytes()
        scripts = {name + '.txt': ('original ' + name).encode('ascii')
            for name in inspection.navigation.SCREENS}
        def read_navigation(path, cap):
            if path.suffix == '.png':
                self.assertEqual(cap, inspection.navigation.MAX_CAPTURE_TOTAL)
                return pixels
            self.assertEqual(cap, 65536)
            return scripts[path.name]
        reads = mock.Mock(side_effect=read_navigation)
        with mock.patch.object(inspection.navigation, 'output_bytes', return_value=0), \
                mock.patch.object(Path, 'open', return_value=written) as opened:
            reference = inspection.navigation.collect(Path('/fixture'),
                navigation_fixtures.receipt(), 'a' * 40, 'b' * 40,
                dict(GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1'), read_original=reads)
        manifest = json.loads(written.getvalue())
        self.assertEqual(reference['manifest_sha256'], hashlib.sha256(written.getvalue()).hexdigest())
        self.assertEqual(reference['captured'], 14)
        self.assertEqual(reads.call_count, 21)
        self.assertEqual(manifest['script_sha256_by_screen'],
            {name: hashlib.sha256(scripts[name + '.txt']).hexdigest()
             for name in inspection.navigation.SCREENS})
        self.assertEqual([row['file'] for row in manifest['captures']], list(inspection.navigation.FILES))
        self.assertFalse(manifest['parent_closure_qualified'])
        self.assertEqual(manifest['visual_matches'], 0)
        opened.assert_called_once_with('xb')
        written = RetainedBytes()
        scripts = {name + '.txt': ('original ' + name).encode('ascii')
            for name in inspection.details.SCREENS}
        def read_details(path, cap):
            if path.suffix == '.png':
                self.assertEqual(cap, inspection.details.MAX_CAPTURE_TOTAL)
                return pixels
            self.assertEqual(cap, 65536)
            return scripts[path.name]
        reads = mock.Mock(side_effect=read_details)
        with mock.patch.object(inspection.details, 'output_bytes', return_value=0), \
                mock.patch.object(Path, 'open', return_value=written) as opened:
            reference = inspection.details.collect(Path('/fixture'),
                details_fixtures.receipt(), 'a' * 40, 'b' * 40,
                dict(GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1'), read_original=reads)
        manifest = json.loads(written.getvalue())
        self.assertEqual(reference['manifest_sha256'], hashlib.sha256(written.getvalue()).hexdigest())
        self.assertEqual(reference['captured'], 10)
        self.assertEqual(reads.call_count, 15)
        self.assertEqual(manifest['script_sha256_by_screen'],
            {name: hashlib.sha256(scripts[name + '.txt']).hexdigest()
             for name in inspection.details.SCREENS})
        self.assertEqual([row['file'] for row in manifest['captures']], list(inspection.details.FILES))
        self.assertFalse(manifest['parent_closure_qualified'])
        self.assertEqual(manifest['visual_matches'], 0)
        opened.assert_called_once_with('xb')
        with mock.patch.object(inspection, 'home_output_bytes', return_value=0), \
                mock.patch.object(inspection, 'read_original', return_value=b'bad pixels'), \
                mock.patch.object(Path, 'open') as opened:
            with self.assertRaises(inspection.debug.entry.Failure) as failure:
                inspection.collect_home_catalog(Path('/fixture'),
                    home_receipt(schema=2), 'a' * 40, 'b' * 40,
                    dict(GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1'))
            self.assertEqual(failure.exception.code, 'PNG_INVALID')
            opened.assert_not_called()

    def test_complete_finite_controls_do_not_grant_financial_or_catalog_acceptance(self):
        for schema, field, reference in (
            (2, 'settings_catalog', settings_reference('e' * 64)),
            (3, 'navigation_catalog', navigation_reference('e' * 64)),
            (4, 'details_catalog', details_reference('e' * 64)),
        ):
            selected = dict(report(), schema=schema, home_catalog=None,
                settings_catalog=reference if schema == 2 else None)
            if schema in (3, 4):
                selected['navigation_catalog'] = reference if schema == 3 else None
            if schema == 4:
                selected['details_catalog'] = reference
            self.assertTrue(inspection.completed(selected))
            self.assertIs(inspection.public_manifest(selected), selected)
            missing = dict(selected, **{field: None})
            self.assertFalse(inspection.completed(missing))
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(missing)
            wrong = dict(selected, home_catalog=home_reference())
            self.assertFalse(inspection.completed(wrong))
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(wrong)
            if schema in (3, 4):
                mixed = dict(selected, settings_catalog=settings_reference('e' * 64))
                self.assertFalse(inspection.completed(mixed))
                with self.assertRaises(inspection.Refused):
                    inspection.public_manifest(mixed)
            if schema == 4:
                mixed = dict(selected, navigation_catalog=navigation_reference('e' * 64))
                self.assertFalse(inspection.completed(mixed))
                with self.assertRaises(inspection.Refused):
                    inspection.public_manifest(mixed)
        value = report()
        self.assertTrue(inspection.completed(value))
        self.assertIs(inspection.public_manifest(value), value)
        for key in ('wallet_qualified', 'financial_send_qualified', 'seed_admitted',
                    'motion_baseline_compared', 'arabic_or_minimum_window_qualified'):
            self.assertIs(value[key], False)
        self.assertEqual(value['visual_matches'], 0)
        focused = catalog_only_report(value, 'f' * 64, 'send-confirm')
        for family in ('earn', 'sentinel-fixture', 'swap-start', 'wallet-ready', 'send-warn',
                       'home-zap-preview'):
            catalog = catalog_only_report(value, 'f' * 64, family)
            self.assertTrue(inspection.completed(catalog))
            self.assertIs(inspection.public_manifest(catalog), catalog)
            for schema in (4, 5, 6, 7, 9, 10, 11, 12):
                if schema != catalog['schema']:
                    with self.subTest(family=family, schema=schema), self.assertRaises(inspection.Refused):
                        inspection.public_manifest(dict(catalog, schema=schema))
        warning = catalog_only_report(value, 'f' * 64, 'send-warn')
        for change in (
            dict(released=False),
            dict(samples=warning['send_warning_window']['samples'][:1]),
            dict(samples=list(reversed(warning['send_warning_window']['samples']))),
            dict(samples=[dict(warning['send_warning_window']['samples'][0], minimum_lag=2)]),
        ):
            malformed = dict(warning,
                send_warning_window=dict(warning['send_warning_window'], **change))
            self.assertFalse(inspection.completed(malformed))
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(malformed)
        self.assertIs(inspection.public_manifest(focused), focused)
        self.assertTrue(inspection.completed(focused))
        for change in (
            dict(captures=value['captures']), dict(tours=value['tours']),
            dict(locales=value['locales']), dict(stalls=value['stalls']),
            dict(viewport=value['viewport']), dict(checks=value['checks']),
            dict(details_catalog=details_reference('f' * 64, schema=2)),
            dict(entry_failure=dict(stage='viewport', code=None)),
        ):
            with self.subTest(change=tuple(change)), self.assertRaises(inspection.Refused):
                mutated = dict(focused, **change)
                self.assertFalse(inspection.completed(mutated))
                inspection.public_manifest(mutated)
        self.assertFalse(inspection.completed(dict(focused, entry_exit=1)))
        self.assertFalse(inspection.completed(dict(focused, required_actor_forced_cleanup=True)))
        self.assertEqual(tuple(inspection.LAYOUT_KEYS), ('window-caption', 'window-body', 'home_hero', 'home_send', 'nodes_tab_pillars', 'nodes_tab_sentinels', 'staking_stake_button', 'plasma_open_fuse', 'tokens_filter_held', 'p2p_start_swap', 'node_settings_add', 'apps_settings_web_switch', 'transfer_card', 'accelerator_strip', 'bell_panel'))
        observed = layout()
        for boundary in ('before', 'after'):
            observed[boundary][1] = dict(key='window-body', status='OBSERVED',
                                        rect=[0, 32, 1280, 780])
        self.assertIs(inspection.layout_observation(observed), observed)
        changed = copy.deepcopy(observed)
        changed['after'][1]['rect'][1] = 0
        changed['unchanged'] = False
        self.assertIs(inspection.layout_observation(changed), changed)
        malformed = []
        for change in ({'schema': True}, {'extra': 'Synthetic private data'},
                       {'unchanged': False}, {'boundaries': ['tree', 'after_encoding']}):
            malformed.append(dict(copy.deepcopy(observed), **change))
        for change in ({'key': 'Synthetic private key'}, {'status': 'OTHER'},
                       {'extra': 'Synthetic private value'}, {'status': 'LIMIT'},
                       {'rect': [False, 32, 1280, 780]},
                       {'rect': [0, 32, 32769, 780]}, {'rect': [2, 32, 1, 780]}):
            bad = copy.deepcopy(observed)
            bad['before'][1].update(change)
            malformed.append(bad)
        for bad in malformed:
            with self.subTest(layout=bad), self.assertRaises(inspection.Refused):
                inspection.layout_observation(bad)
        partial = tour('dark')
        partial['tour']['complete'] = False
        page = partial['tour']['visited'][0]
        page.update(captured=False, layout=None)
        inspection.tour_receipt(partial)
        page['captured'] = True
        with self.assertRaises(inspection.Refused):
            inspection.tour_receipt(partial)


    def test_send_warning_requires_owned_rpc_lag_before_sampling_themes(self):
        warning = inspection.send_warning_window
        directory = Path.cwd() / 'send-warning-test-markers'
        synced = dict(state=2, current_height=9, target_height=9)
        behind = dict(state=1, current_height=9, target_height=13)
        short = dict(behind, target_height=11)
        admitted = dict(http=behind, ws=dict(behind, target_height=12))
        unready = dict(http=short, ws=behind)
        caught_up = dict(http=synced, ws=synced)
        for scenario in ('ready', 'stationary', 'read_refused', 'parent_deadline', 'close_unknown'):
            with self.subTest(scenario=scenario):
                owners = {directory: object()}
                clock = SimpleNamespace(now=0)

                def sleep(seconds):
                    clock.now += seconds

                def mkdir(path, mode):
                    self.assertEqual(path.parent, directory)
                    self.assertEqual(mode, 0o700)
                    self.assertNotIn(path, owners)
                    owners[path] = object()

                probe = scenario == 'stationary'
                before = dict(pillar=9, pillar2=9, pillar3=None)
                after = dict(pillar=13, pillar2=12, pillar3=13)
                with (mock.patch.object(Path, 'mkdir', new=mkdir),
                      mock.patch.object(warning, '_identity', owners.get),
                      mock.patch.object(warning, '_producer_heights',
                                        side_effect=[before, after]) as producers,
                      mock.patch.object(warning, 'time', SimpleNamespace(
                          monotonic=lambda: clock.now, sleep=sleep))):
                    window = warning.SendWarningWindow(directory, lambda: None,
                                                       probe_producers=probe)
                    window.begin(limit=900)
                    with self.assertRaises(warning.SendWarningWindowRefused):
                        window.sample('dark')
                    with self.assertRaises(warning.SendWarningWindowRefused):
                        window.observe_wallet_sync(dict(outcome='formMissing',
                            before=None, after=None))
                    if scenario == 'ready':
                        reads = [caught_up, unready, admitted, admitted, admitted]
                        with mock.patch.object(window, '_read_pair', side_effect=reads) as rpc:
                            window.wait_until_ready(900)
                            self.assertEqual(clock.now, 10)
                            state = dict(status='success', timer_active=True, sync=behind)
                            observed = dict(outcome='refreshReturned',
                                before=dict(state, sync=synced), after=state)
                            for invalid in (dict(observed, source='private'),
                                    dict(observed, outcome='alreadyReady'),
                                    dict(observed, before=state),
                                    dict(observed, after=dict(state, timer_active=1))):
                                with self.assertRaises(warning.SendWarningWindowRefused):
                                    window.observe_wallet_sync(invalid)
                            window.observe_wallet_sync(observed)
                            with self.assertRaises(warning.SendWarningWindowRefused):
                                window.observe_wallet_sync(observed)
                            self.assertEqual(window.receipt()['wallet_sync'], observed)
                            window.sample('dark')
                            window.sample('light')
                            self.assertEqual(rpc.call_args_list,
                                [mock.call(45)] * 3 + [mock.call(90)] * 2)
                        window.release(within_window=True)
                        value = warning.window_receipt(window.receipt(), complete=True)
                        self.assertEqual(value['readiness'],
                            dict(attempts=3, read_refused=False,
                                 first=caught_up, last=admitted))
                        self.assertEqual([row['minimum_lag'] for row in value['samples']], [3, 3])
                        for change in (
                            dict(attempts=True), dict(first=admitted),
                            dict(last=unready), dict(read_refused=True),
                            dict(last=dict(admitted, raw='private reply')),
                            dict(last=dict(admitted, ws=dict(behind, current_height=True))),
                        ):
                            with self.assertRaises(warning.SendWarningWindowRefused):
                                warning.window_receipt(dict(value, readiness=dict(
                                    value['readiness'], **change)), complete=True)
                    elif scenario == 'close_unknown':
                        fault = warning.policy.Refused('CLOSE_UNKNOWN')
                        wire_value = dict(state=1, currentHeight=9, targetHeight=13)
                        with (mock.patch.object(warning, 'make_transports', return_value=(None, None)),
                              mock.patch.object(warning._SyncWs, 'connect'),
                              mock.patch.object(warning._SyncHttp, 'call', return_value=wire_value),
                              mock.patch.object(warning._SyncWs, 'call', return_value=wire_value),
                              mock.patch.object(warning._SyncWs, 'close', side_effect=fault)):
                            with self.assertRaises(warning.policy.Refused) as caught:
                                window.wait_until_ready(900)
                        self.assertIs(caught.exception, fault)
                        window.release_if_owned()
                        self.assertEqual(window.receipt()['readiness'],
                            dict(attempts=1, read_refused=True, first=None, last=None))
                    else:
                        error = warning.SendWarningWindowRefused() if scenario == 'read_refused' else None
                        limit = 49 if scenario == 'parent_deadline' else 900
                        with mock.patch.object(window, '_read_pair',
                                return_value=unready, side_effect=error) as rpc:
                            with self.assertRaises(warning.SendWarningWindowRefused):
                                window.wait_until_ready(limit)
                        self.assertEqual(rpc.call_count, 9 if scenario == 'stationary' else 1)
                        self.assertEqual(clock.now, dict(stationary=40, read_refused=0,
                            parent_deadline=4)[scenario])
                        window.release_if_owned()
                        value = window.receipt()
                        self.assertTrue(value['released'])
                        self.assertEqual(value['samples'], [])
                        self.assertEqual(value['readiness']['read_refused'], error is not None)
                        self.assertEqual(value['readiness']['last'], None if error else unready)
                        if probe:
                            self.assertEqual([call.args[1] for call in producers.call_args_list], [900, 90])
                            self.assertEqual(value['producer_progress'], dict(before=before,
                                                                           after_refusal=after))
                            for height in (False, 0, '13'):
                                bad = dict(value, producer_progress=dict(before=before,
                                    after_refusal=dict(after, pillar=height)))
                                with self.assertRaises(warning.SendWarningWindowRefused):
                                    warning.window_receipt(bad)
                        with self.assertRaises(warning.SendWarningWindowRefused):
                            warning.window_receipt(value, complete=True)

    def test_send_warning_producer_probe_keeps_only_a_complete_owned_height(self):
        warning = inspection.send_warning_window
        raw = b'{"jsonrpc":"2.0","id":1,"result":{"state":2,"currentHeight":24,"targetHeight":24}}'
        for label in ('complete', 'truncated', 'overflow', 'lost_owner'):
            with self.subTest(label=label):
                original = mock.Mock(side_effect=[None, RuntimeError('held')]
                                     if label == 'lost_owner' else None)
                wire = mock.Mock()
                reply = mock.MagicMock(status=200, length=1 if label == 'truncated' else 0)
                reply.__enter__.return_value = reply
                reply.isclosed.return_value = True
                reply.getheader.side_effect = {'Content-Encoding': 'identity',
                                               'Content-Type': 'application/json'}.get
                reply.read1.side_effect = [b' '*2049 if label == 'overflow' else raw, b'']
                wire.getresponse.return_value = reply
                with (mock.patch.object(warning.time, 'monotonic', return_value=0),
                      mock.patch.object(warning.http.client, 'HTTPConnection', return_value=wire) as connect):
                    result = warning._producer_height(warning.PRODUCER_PORTS['pillar'], original, 1)
                self.assertEqual(result, 24 if label == 'complete' else None)
                connect.assert_called_once_with('127.0.0.1', warning.PRODUCER_PORTS['pillar'], timeout=1)
                self.assertEqual(wire.request.call_args.args, ('POST', '/'))
                self.assertEqual(json.loads(wire.request.call_args.kwargs['body']),
                                 dict(jsonrpc='2.0', id=1, method='stats.syncInfo', params=[]))
                wire.close.assert_called_once_with()

    def test_sdk_and_wallet_receipts_refuse_expansion_coercion_and_old_scopes(self):
        for original, validate, changes in (
            (sdk(), inspection.sdk_receipt, ({'schema': True}, {'status': 'PENDING'},
                {'automaticReceiveDisabled': False}, {'extra': 'synthetic private data'})),
            (wallet(), inspection.wallet_receipt, ({'chain': 321.0}, {'selectedIndex': True},
                {'nativeFrameObserved': False}, {'scope': 'original_lab_ui_send'}))):
            self.assertIs(validate(original), original)
            for change in changes:
                with self.subTest(change=change), self.assertRaises(inspection.Refused):
                    validate(dict(original, **change))

    def test_ready_scope_requires_actual_integer_process_and_port(self):
        value = dict(schema=1, scope='readonly_native_inspection_ready', pid=44, port=45000)
        self.assertIs(inspection.ready_receipt(value), value)
        for change in ({'pid': True}, {'port': '45000'}, {'pid': 0}, {'port': 65536},
                       {'scope': 'wallet'}, {'token': 'synthetic private token'}):
            with self.subTest(change=change), self.assertRaises(inspection.Refused):
                inspection.ready_receipt(dict(value, **change))

    def test_replies_cannot_borrow_ordinary_or_foreign_process_admission(self):
        value = dict(ok=True, pid=44, booted=True, readOnly=True, harnessMode='readonly-native',
                     readonlyAdmission=sdk(), readonlyWallet=wallet())
        self.assertIs(inspection.readonly_reply(value, 44, wallet=True), value)
        for change in ({'pid': 45}, {'harnessMode': 'wallet'}, {'readonlyAdmission': None},
                       {'readonlyWallet': None}, {'readOnly': 1}):
            with self.subTest(change=change), self.assertRaises(inspection.Refused):
                inspection.readonly_reply(dict(value, **change), 44, wallet=True)

    def test_tours_keep_all_original_pages_and_their_separate_inspection_scope(self):
        value = tour('dark')
        self.assertTrue(inspection.tour_complete(value))
        ordinary = copy.deepcopy(value)
        ordinary['tour']['scope'] = 'wallet_page_tour'
        with self.assertRaises(inspection.Refused):
            inspection.tour_receipt(ordinary)
        for fault in ('missing', 'reordered', 'uncaptured', 'widget', 'log'):
            bad = copy.deepcopy(value)
            if fault == 'missing':
                bad['tour']['visited'].pop()
            elif fault == 'reordered':
                bad['tour']['visited'].reverse()
            else:
                bad['tour']['visited'][0][{'uncaptured': 'captured',
                    'widget': 'error_widgets', 'log': 'severe_logs'}[fault]] = False if fault == 'uncaptured' else 1
            try:
                result = inspection.tour_complete(bad)
            except inspection.Refused:
                result = False
            self.assertFalse(result, fault)

    def test_locale_and_stalls_are_finite_observations_not_baseline_acceptance(self):
        value = report()
        for theme in inspection.THEMES:
            inspection.locale_receipt(value['locales'][theme])
            inspection.stalls_receipt(value['stalls'][theme])
        for key, change, validate in (
            ('locales', {'language': 'ar'}, inspection.locale_receipt),
            ('locales', {'stable': False}, inspection.locale_receipt),
            ('stalls', {'events': True}, inspection.stalls_receipt),
            ('stalls', {'longest_ms': -1}, inspection.stalls_receipt)):
            with self.subTest(change=change), self.assertRaises(inspection.Refused):
                validate(dict(value[key]['dark'], **change))

    def test_missing_originals_unknown_output_and_forced_actors_never_complete(self):
        changes = [lambda v: v['checks'].pop('wallet_bound'),
            lambda v: v['checks'].update(close_ack=False),
            lambda v: v.update(application_exit=True), lambda v: v.update(entry_exit=None),
            lambda v: v.update(wallet_admission=None), lambda v: v.update(lab_revalidations=1),
            lambda v: v.update(required_actor_forced_cleanup=True),
            lambda v: v.update(owned_job_active_at_close=1),
            lambda v: v['owned_job_images_before_close'].update(status='UNKNOWN'),
            lambda v: v['entry_output'].update(output_complete=False),
            lambda v: v['entry_output'].update(overflow=True)]
        for change in changes:
            value = report()
            change(value)
            self.assertFalse(inspection.completed(value))

    def test_exact_auxiliary_termination_remains_separate_from_required_actors(self):
        value = report()
        value['forced_cleanup'] = value['auxiliary_cleanup']['forced'] = True
        value['auxiliary_cleanup']['receipts'] = [dict(role='sdk_dart', image_sha256='e' * 64,
            forced=True, termination_requested=True, termination_succeeded=True,
            actual_exit=inspection.debug.HELPER_EXIT_MARKER, exit_observed=True, stdio_captured=False)]
        self.assertTrue(inspection.completed(value))
        inspection.public_manifest(value)
        value['required_actor_forced_cleanup'] = True
        self.assertFalse(inspection.completed(value))

    def test_private_or_unknown_fields_cannot_enter_public_manifests(self):
        changes = [lambda v: v.update(credentials='synthetic private value'),
            lambda v: v['sdk_admission'].update(path='synthetic private path'),
            lambda v: v['wallet_admission'].update(members=['synthetic private member']),
            lambda v: v['captures'][0].update(filename='synthetic private path'),
            lambda v: v['entry_output'].update(text='synthetic private output'),
            lambda v: v['auxiliary_cleanup']['observation'].update(path='synthetic private path'),
            lambda v: v['errors'].append('synthetic private failure'),
            lambda v: v['storage'].update(path='synthetic private path'),
            lambda v: v['owned_job_images_before_close']['counts'].update(private_image=1),
            lambda v: v.update(run_id='synthetic private identifier'),
            lambda v: v.update(motion_baseline_compared=True)]
        for change in changes:
            value = report()
            change(value)
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(value)

    def test_negative_manifest_keeps_partial_and_unknown_original_outcomes(self):
        value = report()
        value.update(success=False, inspection_qualified=False, phase='onboarding_and_inspection',
            errors=['ENTRY_FAILED'], application_exit=None, entry_exit=1,
            captures=value['captures'][:1], tours={}, locales={}, stalls={},
            wallet_admission=None, auxiliary_cleanup=None)
        value['owned_job_images_before_close']['status'] = 'UNKNOWN'
        self.assertIs(inspection.public_manifest(value), value)
        self.assertFalse(inspection.completed(value))
        self.assertIsNone(value['application_exit'])

    def test_inspection_default_off_and_explicit_native_lab_requirements(self):
        workflow = Path('.github/workflows/public-contribution-qualification.yml').read_text(encoding='utf-8')
        self.assertIn('- name: Retain the admitted literal catalog captures', workflow)
        self.assertIn("steps.inspection_paths.outputs.catalog_paths != ''", workflow)
        self.assertIn('path: ${{ steps.inspection_paths.outputs.catalog_paths }}', workflow)
        self.assertNotIn('path: .harness/ci-home-catalog/**', workflow)
        self.assertNotIn('path: .harness/ci-settings-catalog/**', workflow)
        self.assertIn('name: ${{ steps.inspection_paths.outputs.catalog_family }}-', workflow)
        self.assertFalse(lab.wallet_inspection_requested('native', {}))
        parent = dict(SYRIUS_WINDOWS_WALLET_INSPECTION='true',
            SYRIUS_WINDOWS_WALLET_TOUR='false', SYRIUS_LAB_NODE_SOURCE='lab-fix',
            SYRIUS_NATIVE_STACK_DIAGNOSTIC='true')
        self.assertTrue(lab.wallet_inspection_requested('native', parent))
        for change in ({'SYRIUS_WINDOWS_WALLET_TOUR': 'true'},
                       {'SYRIUS_LAB_NODE_SOURCE': 'original'},
                       {'SYRIUS_NATIVE_STACK_DIAGNOSTIC': 'false'},
                       {'SYRIUS_WINDOWS_WALLET_INSPECTION': True}):
            with self.assertRaises(lab.Failure):
                lab.wallet_inspection_requested('native', dict(parent, **change))
        with self.assertRaises(lab.Failure):
            lab.wallet_inspection_requested('docker', parent)

    def test_entry_failures_keep_only_original_finite_diagnostics(self):
        value = dict(stage='onboarding', code='wallet-recipe-command-refused', diagnostic=dict(
            action='type', control='import_seed_field', reason='wallet-recipe-control-disabled', entry='import'))
        self.assertIs(inspection.entry_failure(value), value)
        code = 'wallet-recipe-control-ambiguous'
        ambiguous = dict(stage='onboarding', code=code, diagnostic=dict(
            action='observe', control='new_wallet_password', reason=code))
        self.assertIs(inspection.entry_failure(ambiguous), ambiguous)
        for changed in (dict(action='type'), dict(reason='wallet-recipe-control-absent'),
                        dict(value='synthetic private password'), dict(control='private key')):
            with self.assertRaises(inspection.shared.Refused):
                inspection.entry_failure(dict(ambiguous,
                    diagnostic=dict(ambiguous['diagnostic'], **changed)))
        for change in ({'stage': 'lab_send'}, {'code': 'synthetic private diagnostic'},
                       {'stack': 'synthetic private path'}):
            with self.assertRaises(inspection.Refused):
                inspection.entry_failure(dict(value, **change))

    def test_settings_seam_manifest_retains_only_its_original_typed_prefix(self):
        expected = [dict(panel=panel, seam=seam) for panel, seam in (
            ('node', 'sporks'), ('security', 'autoLockOnClose'),
            ('security', 'biometricUnlock'), ('security', 'wrongPasswordLimitOff'),
            ('security', 'passwordChangeMigration'), ('wallet', 'operatorModes'),
            ('wallet', 'walletPicker'), ('about', 'walletUpdateNotice'))]
        self.assertEqual(inspection.expected_settings_seam_observations(), expected)
        complete = dict(schema=1, requested=8, observed=expected,
            probe_failure=None, complete=True)
        settings_report = dict(report(), schema=2, home_catalog=None,
            settings_catalog=settings_reference('e' * 64))
        self.assertIs(inspection.settings_seam_observations(complete), complete)
        self.assertEqual(inspection.public_manifest(dict(settings_report,
            settings_seam_observations=complete))['settings_seam_observations'], complete)
        for count in range(9):
            partial = dict(complete, observed=expected[:count],
                complete=False, probe_failure='ENTRY_REFUSED')
            offered = dict(settings_report, success=False, inspection_qualified=False,
                errors=['ENTRY_REFUSED'], settings_seam_observations=partial)
            self.assertEqual(inspection.public_manifest(offered)['settings_seam_observations'],
                partial)
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(dict(offered, success=True,
                    inspection_qualified=True))
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(dict(offered, errors=[]))
        for delta in (dict(schema=True), dict(requested=True), dict(complete=1),
                      dict(observed=expected[:-1]), dict(observed=expected[::-1]),
                      dict(observed=expected + expected[:1]),
                      dict(observed=[dict(expected[0], panel=1)] + expected[1:]),
                      dict(probe_failure='Synthetic private reply'),
                      dict(raw='Synthetic private path')):
            with self.subTest(delta=delta), self.assertRaises(inspection.Refused):
                inspection.settings_seam_observations(dict(complete, **delta))
        with self.assertRaises(inspection.Refused):
            inspection.public_manifest(dict(report(), settings_seam_observations=complete))
        self.assertNotIn('settings_seam_observations',
            inspection.public_manifest(settings_report))

    def test_home_seam_manifest_retains_only_the_original_typed_prefix(self):
        expected = inspection.expected_home_seam_observations()
        complete = dict(schema=1, requested=11, observed=expected,
            probe_failure=None, complete=True)
        self.assertEqual(len(expected), 11)
        self.assertIs(inspection.home_seam_observations(complete), complete)
        self.assertEqual(inspection.public_manifest(dict(report(),
            home_seam_observations=complete))['home_seam_observations'], complete)
        for count in range(11):
            partial = dict(complete, observed=expected[:count],
                complete=False, probe_failure='ENTRY_REFUSED')
            offered = dict(report(), success=False, inspection_qualified=False,
                errors=['ENTRY_REFUSED'], home_seam_observations=partial)
            self.assertEqual(inspection.public_manifest(offered)['home_seam_observations'],
                partial)
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(dict(offered, success=True,
                    inspection_qualified=True))
            with self.assertRaises(inspection.Refused):
                inspection.public_manifest(dict(offered, errors=[]))
        wrong_boolean = copy.deepcopy(complete)
        wrong_boolean['observed'][2]['keyboard_refused'] = 1
        for delta in (dict(schema=True), dict(requested=True), dict(complete=1),
                      dict(observed=expected[:-1]), dict(observed=expected[::-1]),
                      dict(observed=expected + expected[:1]),
                      dict(probe_failure='Synthetic private reply'),
                      dict(raw='Synthetic private path')):
            with self.subTest(delta=delta), self.assertRaises(inspection.Refused):
                inspection.home_seam_observations(dict(complete, **delta))
        with self.assertRaises(inspection.Refused):
            inspection.home_seam_observations(wrong_boolean)
        self.assertNotIn('home_seam_observations', inspection.public_manifest(report()))

    def test_home_failure_diagnostic_keeps_only_closed_original_context(self):
        base = dict(schema=1, kind='readonly_home_capture_failure',
            last_entered_step='preflight')
        self.assertIs(inspection.home_failure_diagnostic(base), base)
        # Earlier failures remain valid without retroactively invented detail.
        earlier = dict(stage='home_catalog', code=None)
        self.assertIs(inspection.entry_failure(earlier), earlier)
        valid = dict(base, last_entered_step='scriptLine',
            screen='home-rest', theme='dark', line=5)
        shot_replies = (
            'frameUnavailable',
            'frameBusy',
            'frameDeadlineExceeded',
            'frameOriginalFailed',
            'frameAdmissionFailed',
            'captureClientMismatch',
            'captureWindowMinimized',
            'captureThemeMismatch',
            'captureLayerUnavailable',
            'captureColorSpaceMismatch',
            'captureReadbackUnavailable',
            'captureDimensionsMismatch',
            'captureStateChanged',
        )
        for reply in shot_replies:
            with self.subTest(shot_reply=reply):
                self.assertIn(reply, inspection.settings.FAILURE_REPLIES)
                shot = dict(schema=2, kind='readonly_home_capture_failure',
                    last_entered_step='shotRequest', screen='home-goto',
                    theme='light', reply=reply)
                self.assertIs(inspection.entry_failure(dict(stage='home_catalog',
                    code=None, diagnostic=shot))['diagnostic'], shot)
                for changed in (reply + ' ', 'Synthetic ' + reply, reply.upper()):
                    with self.assertRaises(inspection.Refused):
                        inspection.home_failure_diagnostic(dict(shot, reply=changed))
                for field in ('raw', 'stack', 'command'):
                    with self.assertRaises(inspection.Refused):
                        inspection.home_failure_diagnostic(dict(shot,
                            **{field: 'Synthetic private diagnostic'}))
        frame_state = dict(schema=1, scheduler_phase='idle', lifecycle_state='paused',
            frames_enabled=False, has_scheduled_frame=True, binding_current=True)
        contextual = dict(schema=3, kind='readonly_home_capture_failure',
            last_entered_step='shotRequest', screen='home-goto', theme='light',
            reply='frameDeadlineExceeded', frame_state=frame_state)
        self.assertIs(inspection.home_failure_diagnostic(contextual), contextual)
        progress = dict(frame_state, schema=2, begin_frame_callback_registered=True,
            draw_frame_callback_registered=True, persistent_callbacks_observed=0)
        for callbacks in (0, 1, 65535, 'unknown'):
            for begin in (False, True):
                for draw in (False, True):
                    observed = dict(contextual, frame_state=dict(progress,
                        begin_frame_callback_registered=begin,
                        draw_frame_callback_registered=draw,
                        persistent_callbacks_observed=callbacks))
                    self.assertIs(inspection.home_failure_diagnostic(observed), observed)
        for callbacks in (True, False, -1, 65536, 0.0, None, 'Synthetic private frame'):
            with self.subTest(callbacks=callbacks), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual,
                    frame_state=dict(progress, persistent_callbacks_observed=callbacks)))
        for delta in (dict(schema=1), dict(schema=3),
                      dict(begin_frame_callback_registered=1),
                      dict(draw_frame_callback_registered=None),
                      dict(private_path='Synthetic private callback')):
            with self.subTest(progress=delta), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual,
                    frame_state=dict(progress, **delta)))
        for key in progress:
            missing = dict(progress)
            missing.pop(key)
            with self.subTest(missing=key), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual, frame_state=missing))
        for phase in ('idle', 'transientCallbacks', 'midFrameMicrotasks',
                      'persistentCallbacks', 'postFrameCallbacks'):
            for lifecycle in ('none', 'detached', 'resumed', 'inactive', 'hidden', 'paused'):
                observed = dict(contextual, frame_state=dict(frame_state,
                    scheduler_phase=phase, lifecycle_state=lifecycle))
                self.assertIs(inspection.home_failure_diagnostic(observed), observed)
        for delta in (dict(schema=True), dict(frames_enabled=1),
                      dict(has_scheduled_frame=None), dict(binding_current=0),
                      dict(scheduler_phase='Synthetic private phase'),
                      dict(lifecycle_state='Synthetic private lifecycle'),
                      dict(raw='Synthetic private reply')):
            with self.subTest(frame_state=delta), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual,
                    frame_state=dict(frame_state, **delta)))
        for reply in ('unknown', 'frameUnavailable', 'captureThemeMismatch'):
            with self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual, reply=reply))
        for missing in frame_state:
            broken = dict(frame_state)
            broken.pop(missing)
            with self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual, frame_state=broken))
        for schema in (1, 2):
            with self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(contextual, schema=schema))
        for screen in inspection.HOME_GOTO_SCREENS:
            for theme in inspection.THEMES:
                for reply in inspection.settings.FAILURE_REPLIES:
                    observed = dict(valid, schema=2, screen=screen,
                        theme=theme, reply=reply)
                    self.assertIs(inspection.home_failure_diagnostic(observed), observed)
                    self.assertIs(inspection.entry_failure(dict(stage='home_catalog',
                        code=None, diagnostic=observed))['diagnostic'], observed)
        for delta in (
            dict(schema=True), dict(schema=3), dict(kind='other'),
            dict(last_entered_step='Synthetic private step'),
            dict(screen='Synthetic private path'), dict(theme='ar'),
            dict(line=True), dict(line=0), dict(line=65536),
            dict(last_entered_step='preflight'),
            dict(command='Synthetic private command'),
            dict(raw='Synthetic private reply'),
            dict(schema=1, reply='unknown'), dict(schema=2),
            dict(schema=2, reply=True), dict(schema=2, reply='Synthetic input'),
        ):
            with self.subTest(delta=delta), self.assertRaises(inspection.Refused):
                inspection.entry_failure(dict(stage='home_catalog', code=None,
                    diagnostic=dict(valid, **delta)))
        for missing in ('screen', 'theme', 'line'):
            broken = dict(valid)
            broken.pop(missing)
            with self.subTest(missing=missing), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(broken)
        for delta in (dict(screen='home-rest'), dict(theme='dark'), dict(line=1)):
            with self.subTest(delta=delta), self.assertRaises(inspection.Refused):
                inspection.home_failure_diagnostic(dict(base, **delta))
        with self.assertRaises(inspection.Refused):
            inspection.entry_failure(dict(stage='home_catalog',
                code='wallet-recipe-other', diagnostic=valid))

    def test_non_ci_admission_refuses_before_profile_sdk_or_process_allocation(self):
        with mock.patch.object(inspection.subprocess, 'Popen', side_effect=AssertionError('No process')) as process, \
                mock.patch.object(Path, 'mkdir', side_effect=AssertionError('No scratch')) as mkdir, \
                mock.patch.object(inspection.debug, 'sdk', side_effect=AssertionError('No SDK')) as sdk_call, \
                contextlib.redirect_stdout(io.StringIO()):
            value = inspection.run(Path('/fixture'), {}, None, None, {}, lambda: None)
        self.assertFalse(value['success'])
        self.assertEqual(value['errors'], ['ENVIRONMENT_REFUSED'])
        process.assert_not_called()
        mkdir.assert_not_called()
        sdk_call.assert_not_called()

    def test_original_artifact_reads_refuse_aliases_growth_and_changed_identity(self):
        class Original(io.BytesIO):
            def fileno(self):
                return 59

        path = Path('/fixture/capture.png')
        raw = b'observed'
        info = SimpleNamespace(st_mode=stat.S_IFREG, st_nlink=1,
            st_size=len(raw), st_dev=1, st_ino=2, st_mtime_ns=3)
        for fault in (None, 'alias', 'growth', 'replaced', 'short'):
            before = copy.copy(info)
            after = copy.copy(info)
            pixels = raw
            if fault == 'alias':
                before.st_nlink = 2
            elif fault == 'growth':
                pixels *= 4
            elif fault == 'replaced':
                after.st_ino = 4
            elif fault == 'short':
                pixels = raw[:-1]
            with self.subTest(fault=fault), \
                    mock.patch.object(inspection.debug.bounded, 'plain',
                        side_effect=lambda p: before if p == path else
                            SimpleNamespace(st_mode=stat.S_IFDIR)), \
                    mock.patch.object(inspection.os, 'fstat', side_effect=[before, after]), \
                    mock.patch.object(Path, 'open', return_value=Original(pixels)):
                if fault is None:
                    self.assertEqual(inspection.read_original(path, 16), raw)
                else:
                    with self.assertRaises(inspection.Refused):
                        inspection.read_original(path, 16)

    def artifact_case(self, value, *, pixels=None, home_schema=1,
                      settings_catalog=False, navigation_catalog=False,
                      details_catalog=False, catalog_only=None):
        parent = dict(GITHUB_WORKSPACE='/fixture', GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1',
                      GITHUB_OUTPUT='/fixture-output')
        value = copy.deepcopy(value)
        script = Path('harness/screens/home-rest.txt').read_bytes()
        home = home_manifest(pixels or b'x', script, schema=home_schema)
        home_raw = json.dumps(home).encode('ascii')
        settings_value = settings_manifest(pixels or b'x', script)
        settings_raw = json.dumps(settings_value).encode('ascii')
        navigation_value = navigation_manifest(pixels or b'x', script)
        navigation_raw = json.dumps(navigation_value).encode('ascii')
        details_schema = inspection.details.FAMILY_SCHEMAS.get(catalog_only, 1)
        details_value = details_manifest(pixels or b'x', script, schema=details_schema)
        details_raw = json.dumps(details_value).encode('ascii')
        self.assertLessEqual(sum((settings_catalog, navigation_catalog,
            details_catalog, catalog_only is not None)), 1)
        viewport_manifest, viewport_images = viewport_fixtures.fixture()
        viewport_manifest['probe_sha256'] = hashlib.sha256(script).hexdigest()
        viewport_raw = json.dumps(viewport_manifest).encode('ascii')
        if value['success']:
            if catalog_only:
                value = catalog_only_report(
                    value, hashlib.sha256(details_raw).hexdigest(), catalog_only)
            elif details_catalog:
                value.update(schema=4, home_catalog=None, settings_catalog=None,
                    navigation_catalog=None,
                    details_catalog=details_reference(hashlib.sha256(details_raw).hexdigest()))
            elif navigation_catalog:
                value.update(schema=3, home_catalog=None, settings_catalog=None,
                    navigation_catalog=navigation_reference(hashlib.sha256(navigation_raw).hexdigest()))
            elif settings_catalog:
                value.update(schema=2, home_catalog=None,
                    settings_catalog=settings_reference(hashlib.sha256(settings_raw).hexdigest()))
            else:
                value['home_catalog'] = home_reference(hashlib.sha256(home_raw).hexdigest(), schema=home_schema)
            if value['viewport'] is not None:
                value['viewport']['manifest_sha256'] = hashlib.sha256(viewport_raw).hexdigest()
        manifest = json.dumps(value).encode()
        output = _Output()
        reads = []

        def read(path, cap):
            reads.append(path)
            if path in (Path('/fixture') / inspection.HOME_SCRIPT,
                        Path('/fixture') / inspection.HOME_HIDDEN_SCRIPT,
                        Path('/fixture') / inspection.HOME_OPEN_SCRIPT,
                        Path('/fixture') / inspection.HOME_GOTO_SCRIPT,
                        Path('/fixture') / inspection.viewport.PROBE):
                self.assertEqual(cap, 65536)
                return script
            if (path.parent == Path('/fixture/harness/screens')
                    and path.stem in inspection.details.catalog_screens(details_schema)):
                self.assertEqual(cap, 65536)
                return script
            if path.parent == Path('/fixture') / inspection.details.OUTPUT:
                self.assertIn(path.name, ('manifest.json',
                    *inspection.details.catalog_files(details_schema)))
                self.assertEqual(cap, inspection.details.MAX_MANIFEST
                    if path.name == 'manifest.json' else inspection.details.MAX_CAPTURE_TOTAL)
                return details_raw if path.name == 'manifest.json' else pixels
            if (path.parent == Path('/fixture/harness/screens')
                    and path.stem in inspection.navigation.SCREENS):
                self.assertEqual(cap, 65536)
                return script
            if path.parent == Path('/fixture') / inspection.navigation.OUTPUT:
                self.assertIn(path.name, ('manifest.json', *inspection.navigation.FILES))
                self.assertEqual(cap, inspection.navigation.MAX_MANIFEST
                    if path.name == 'manifest.json' else inspection.navigation.MAX_CAPTURE_TOTAL)
                return navigation_raw if path.name == 'manifest.json' else pixels
            if (path.parent == Path('/fixture/harness/screens')
                    and path.stem in inspection.settings.SCREENS):
                self.assertEqual(cap, 65536)
                return script
            if path.parent == Path('/fixture') / inspection.settings.OUTPUT:
                self.assertIn(path.name, ('manifest.json', *inspection.settings.FILES))
                self.assertEqual(cap, inspection.settings.MAX_MANIFEST
                    if path.name == 'manifest.json' else inspection.settings.MAX_CAPTURE_TOTAL)
                return settings_raw if path.name == 'manifest.json' else pixels
            if path.parent == Path('/fixture') / inspection.viewport.OUTPUT:
                return viewport_raw if path.name == 'manifest.json' else viewport_images[path.name]
            if path.parent == Path('/fixture') / inspection.HOME_OUTPUT:
                if path.name == 'manifest.json':
                    self.assertEqual(cap, inspection.MAX_HOME_MANIFEST)
                    return home_raw
                self.assertEqual(cap, inspection.MAX_HOME_CAPTURE_TOTAL)
                self.assertIn(path.name, inspection.home_catalog_files(home_schema))
                return pixels
            if path.name == 'manifest.json':
                self.assertEqual(cap, inspection.MAX_MANIFEST)
                return manifest
            self.assertIsNotNone(pixels)
            self.assertEqual(cap, inspection.debug.entry.MAX_PNG)
            self.assertIn(path.name, {p + '.png' for p in inspection.PAGES})
            return pixels

        with mock.patch.object(inspection.debug.entry, 'require_ci', return_value=(parent, 'a' * 40)), \
                mock.patch.object(inspection.debug.bounded, 'verify_source'), \
                mock.patch.object(inspection.debug.entry, 'source_tree', return_value='b' * 40), \
                mock.patch.object(inspection.debug.bounded, 'plain', side_effect=lambda path:
                    SimpleNamespace(st_size=len(manifest) if path.name == 'manifest.json' else len(pixels or b''))), \
                mock.patch.object(inspection, 'read_original', side_effect=read), \
                mock.patch.object(Path, 'open', return_value=output), \
                mock.patch.object(inspection, 'output_bytes', return_value=len(pixels or b'') * 24), \
                mock.patch.object(inspection, 'home_output_bytes', return_value=len(home_raw) + len(pixels or b'') * 2), \
                mock.patch.object(inspection.settings, 'output_bytes', return_value=0), \
                mock.patch.object(inspection.viewport, 'output_bytes', return_value=0):
            paths = inspection.artifact_paths(parent)
        return paths, reads, output.getvalue()

    def test_failed_inspection_exports_only_its_finite_manifest(self):
        value = report()
        value.update(success=False, inspection_qualified=False, errors=['ENTRY_FAILED'])
        paths, reads, output = self.artifact_case(value)
        self.assertEqual(paths, ['.harness/ci-wallet-inspection/manifest.json'])
        for flavor in (PurePosixPath, PureWindowsPath):
            expected = flavor(inspection.OUTPUT.as_posix()) / 'manifest.json'
            self.assertEqual(str(expected).replace('\\', '/'), paths[0])
        self.assertEqual(len(reads), 1)
        self.assertNotIn('.png', output)

    def test_successful_artifact_selection_verifies_every_original_png_reference(self):
        pixels = png()
        value = report()
        for row in value['captures']:
            row.update(bytes=len(pixels), sha256=hashlib.sha256(pixels).hexdigest())
        paths, reads, output = self.artifact_case(value, pixels=pixels)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(set(paths)), 25)
        self.assertEqual(len(reads), 35)
        self.assertIn('captures/dark/dashboard.png', output)
        self.assertIn('captures/light/walletConnect.png', output)
        self.assertIn('catalog_paths<<HOME_CATALOG_PATHS_V1', output)
        self.assertIn('ci-home-catalog/01-home-rest-dark.png', output)
        self.assertIn('ci-home-catalog/01-home-rest-light.png', output)
        self.assertIn('viewport_paths<<VIEWPORT_PATHS_V1', output)
        for filename in inspection.viewport.FILES:
            self.assertIn('ci-viewport-observations/' + filename, output)

        paths, reads, output = self.artifact_case(value, pixels=pixels, home_schema=2)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(set(paths)), 25)
        self.assertEqual(len(reads), 38)
        for filename in inspection.HOME_STATE_FILES:
            self.assertIn('ci-home-catalog/' + filename, output)
        self.assertNotIn('private', output)

        paths, reads, output = self.artifact_case(value, pixels=pixels, home_schema=3)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(set(paths)), 25)
        self.assertEqual(len(reads), 41)
        for filename in inspection.HOME_OPEN_FILES:
            self.assertIn('ci-home-catalog/' + filename, output)
        self.assertNotIn('private', output)

        paths, reads, output = self.artifact_case(value, pixels=pixels, home_schema=4)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(set(paths)), 25)
        self.assertEqual(len(reads), 44)
        for filename in inspection.HOME_GOTO_FILES:
            self.assertIn('ci-home-catalog/' + filename, output)
        self.assertNotIn('private', output)

        paths, reads, output = self.artifact_case(value, pixels=pixels, settings_catalog=True)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(reads), 53)
        self.assertIn('catalog_family=settings-catalog', output)
        self.assertNotIn('ci-home-catalog/', output)
        for filename in inspection.settings.FILES:
            self.assertIn('ci-settings-catalog/' + filename, output)
        self.assertNotIn('private', output)
        paths, reads, output = self.artifact_case(value, pixels=pixels, navigation_catalog=True)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(reads), 53)
        self.assertIn('catalog_family=navigation-catalog', output)
        self.assertNotIn('ci-home-catalog/', output)
        for filename in inspection.navigation.FILES:
            self.assertIn('ci-navigation-catalog/' + filename, output)
        self.assertNotIn('private', output)
        paths, reads, output = self.artifact_case(value, pixels=pixels, details_catalog=True)
        self.assertEqual(len(paths), 25)
        self.assertEqual(len(reads), 47)
        self.assertIn('catalog_family=details-catalog', output)
        self.assertNotIn('ci-home-catalog/', output)
        for filename in inspection.details.FILES:
            self.assertIn('ci-details-catalog/' + filename, output)
        self.assertNotIn('ci-navigation-catalog/', output)
        self.assertNotIn('private', output)
        paths, reads, output = self.artifact_case(
            value, pixels=pixels, catalog_only='send-confirm')
        self.assertEqual(paths, ['.harness/ci-wallet-inspection/manifest.json'])
        self.assertEqual(len(reads), 5)
        self.assertIn('catalog_family=details-catalog', output)
        self.assertIn('ci-details-catalog/12-send-confirm-dark.png', output)
        self.assertIn('ci-details-catalog/12-send-confirm-light.png', output)
        self.assertNotIn('/captures/', output)
        self.assertNotIn('ci-viewport-observations/', output)
        paths, reads, output = self.artifact_case(
            value, pixels=pixels, catalog_only='earn')
        self.assertEqual(paths, ['.harness/ci-wallet-inspection/manifest.json'])
        self.assertEqual(len(reads), 8)
        for filename in inspection.details.EARN_FILES:
            self.assertIn('ci-details-catalog/' + filename, output)
        self.assertNotIn('12-send-confirm-', output)
        self.assertNotIn('/captures/', output)
        self.assertNotIn('ci-viewport-observations/', output)
        paths, reads, output = self.artifact_case(
            value, pixels=pixels, catalog_only='sentinel-fixture')
        self.assertEqual(paths, ['.harness/ci-wallet-inspection/manifest.json'])
        self.assertEqual(len(reads), 5)
        self.assertIn('catalog_family=details-catalog', output)
        self.assertIn('ci-details-catalog/18-sentinels-dark.png', output)
        self.assertIn('ci-details-catalog/18-sentinels-light.png', output)
        self.assertNotIn('12-send-confirm-', output)
        self.assertNotIn('/captures/', output)
        self.assertNotIn('ci-viewport-observations/', output)

    def test_artifacts_cannot_borrow_another_source_run_or_private_manifest(self):
        for change in ({'source_sha': 'c' * 40}, {'run_attempt': '2'},
                       {'private': 'synthetic private data'}):
            value = report()
            value.update(success=False, inspection_qualified=False, errors=['ENTRY_FAILED'], **change)
            with self.assertRaises(inspection.Refused):
                self.artifact_case(value)


if __name__ == '__main__':
    unittest.main()
