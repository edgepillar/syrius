"""Memory controls for the source-bound unavailable page controls."""

import unittest

from tool.ci import windows_wallet_inspection as inspect


class OriginalSurfaces:
    def __init__(self, fault=None, *, initial_tab='settings'):
        self.fault = fault
        self.tab, self.route, self.address = initial_tab, '/' + initial_tab, 'fixture-owner'
        self.token_open = False
        self.calls = []

    def send(self, command):
        self.calls.append(command.copy())
        kind = command['cmd']
        if kind == 'state':
            return dict(tab=self.tab, route=self.route, address=self.address,
                locale='unexpected' if self.fault == 'initial-state' else 'en',
                direction='ltr', node='ws://127.0.0.1:45998', chainId=321, signingChainId=321,
                savedSigningChainId=321, walletUnlocked=True, walletInitCompleted=True,
                embeddedNode=False, nodeTransitionPending=False)
        if kind == 'tap':
            if 'tab' in command:
                self.tab = command['tab']
                self.route = '/' + self.tab
            else:
                key = command['key']
                if key == 'token_zts1znnxxxxxxxxxxxxx9z4ulx_row':
                    self.token_open = not self.token_open
                    if self.token_open and self.fault == 'owner-before':
                        self.address = 'replacement-owner'
                    if self.token_open and self.fault == 'route-before':
                        self.route = '/replacement'
                elif key == 'nodes_tab_pillars':
                    self.route = '/pillars'
                elif key == 'pillars_sort':
                    self.route = '/pillars/menu'
                elif key == 'p2p_start_swap':
                    self.route = '/p2pSwap/draft'
                elif key == 'swap_action_close':
                    self.route = '/p2pSwap'
                else:
                    raise AssertionError('Unexpected action')
                return dict(ok=True, target=dict(key=key))
            return dict(ok=True)
        if kind == 'wait':
            key = command['key']
            if key in ('addresses_settings_page', 'home_hero', 'strip_update_button'):
                if self.fault == 'missing-' + key:
                    return dict(ok=True)
                if key == 'addresses_settings_page':
                    if self.fault == 'settings-owner':
                        self.address = 'replacement-owner'
                    if self.fault == 'settings-route':
                        self.route = '/replacement'
                if key == 'home_hero' and self.fault == 'home-initial-route':
                    self.route = '/replacement'
                if key == 'strip_update_button':
                    if self.fault == 'ready-owner':
                        self.address = 'replacement-owner'
                    if self.fault == 'ready-route':
                        self.route = '/replacement'
            if command.get('gone'):
                if key == 'token_explorer_control' and self.token_open:
                    raise AssertionError('Token disclosure remained open')
                return dict(ok=True)
            if key == 'token_explorer_control' and self.fault == 'missing-token-control':
                return dict(ok=True)
            return dict(ok=True, target=dict(key=key))
        if kind == 'readonly-seam-pointer':
            seam = command['seam']
            result = dict(ok=True, scope='readonly_native_seam_pointer_observation',
                seam=seam, pointerDispatched=True, absorptionObserved=True)
            if seam == 'tokenExplorer':
                if self.fault == 'owner-after':
                    self.address = 'replacement-owner'
                if self.fault == 'route-after':
                    self.route = '/replacement'
                if self.fault == 'wrong-seam':
                    result['seam'] = 'swapTerms'
                if self.fault == 'wrong-scope':
                    result['scope'] = 'foreign_observation'
                if self.fault == 'pointer-refused':
                    result['pointerDispatched'] = False
                if self.fault == 'absorption-refused':
                    result['absorptionObserved'] = False
            return result
        if kind == 'key' and command['key'] == 'escape' and self.route == '/pillars/menu':
            self.route = '/pillars'
            return dict(ok=True)
        if kind == 'logs':
            return dict(logs=[])
        raise AssertionError('Unexpected command')


class SurfaceSeamProbeTests(unittest.TestCase):
    def test_original_home_and_update_are_ready_before_the_first_pointer(self):
        original = OriginalSurfaces()
        inspect.observe_surface_seams(original.send, [])
        first = next(index for index, command in enumerate(original.calls)
                     if command['cmd'] == 'readonly-seam-pointer')
        self.assertEqual(original.calls[:first], [
            dict(cmd='state'),
            dict(cmd='wait', key='addresses_settings_page', exact=True, timeoutMs=5000),
            dict(cmd='state'),
            dict(cmd='tap', tab='dashboard'),
            dict(cmd='wait', key='home_hero', exact=True, timeoutMs=5000),
            dict(cmd='state'),
            dict(cmd='wait', key='strip_update_button', kind='button', exact=True, timeoutMs=5000),
            dict(cmd='state'),
        ])

    def test_unready_settings_home_or_update_stops_before_any_pointer(self):
        for key in ('addresses_settings_page', 'home_hero', 'strip_update_button'):
            original, observed = OriginalSurfaces('missing-' + key), []
            with self.subTest(key=key), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, [])
            self.assertFalse(any(command['cmd'] == 'readonly-seam-pointer'
                                 for command in original.calls))

    def test_already_bound_home_keeps_its_original_route(self):
        original, observed = OriginalSurfaces(initial_tab='dashboard'), []
        inspect.observe_surface_seams(original.send, observed)
        self.assertEqual(observed, list(inspect.SURFACE_SEAMS))
        first = next(index for index, command in enumerate(original.calls)
                     if command['cmd'] == 'readonly-seam-pointer')
        self.assertFalse(any(command['cmd'] == 'tap' for command in original.calls[:first]))
        original, observed = OriginalSurfaces('home-initial-route', initial_tab='dashboard'), []
        with self.assertRaises(inspect.Refused):
            inspect.observe_surface_seams(original.send, observed)
        self.assertEqual(observed, [])

    def test_changed_settings_owner_or_route_prevents_home_navigation(self):
        for fault in ('settings-owner', 'settings-route'):
            original, observed = OriginalSurfaces(fault), []
            with self.subTest(fault=fault), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, [])
            self.assertFalse(any(command['cmd'] == 'tap' for command in original.calls))

    def test_unexpected_initial_tab_is_refused_before_navigation(self):
        original, observed = OriginalSurfaces(initial_tab='tokens'), []
        with self.assertRaises(inspect.Refused):
            inspect.observe_surface_seams(original.send, observed)
        self.assertEqual(observed, [])
        self.assertEqual(original.calls, [dict(cmd='state')])

    def test_owner_or_route_replacement_during_readiness_is_refused(self):
        for fault in ('ready-owner', 'ready-route'):
            original, observed = OriginalSurfaces(fault), []
            with self.subTest(fault=fault), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, [])
            self.assertFalse(any(command['cmd'] == 'readonly-seam-pointer'
                                 for command in original.calls))

    def test_command_context_distinguishes_state_checks_from_exchange_failure(self):
        for exchange_failed in (False, True):
            original, observed, trace = OriginalSurfaces('initial-state'), [], inspect.SeamProbeTrace()

            def exchange(command):
                if exchange_failed:
                    raise RuntimeError('private response or exception detail')
                return original.send(command)

            expected_error = RuntimeError if exchange_failed else inspect.Refused
            with self.subTest(exchange_failed=exchange_failed), self.assertRaises(expected_error):
                inspect.observe_surface_seams(lambda command: trace.exchange(exchange, command), observed)
            self.assertEqual(observed, [])
            self.assertEqual(trace.receipt(), dict(schema=1, scope='readonly_seam_command_context',
                command_index=1, command='state', target='NONE',
                stage='REQUEST' if exchange_failed else 'REPLY'))

    def test_command_context_never_copies_free_text_or_reply_data(self):
        trace = inspect.SeamProbeTrace()
        private = 'private-path-address-token-password-and-error-detail'
        command = dict(cmd=private, key=private, tab=private, value=private)
        self.assertEqual(trace.exchange(lambda _: dict(private=private), command), dict(private=private))
        self.assertEqual(trace.receipt(), dict(schema=1, scope='readonly_seam_command_context',
            command_index=1, command='OTHER', target='OTHER', stage='REPLY'))
        self.assertNotIn(private, str(trace.receipt()))
        original, observed = OriginalSurfaces('pointer-refused'), []
        with self.assertRaises(inspect.Refused):
            inspect.observe_surface_seams(lambda value: trace.exchange(original.send, value), observed)
        self.assertEqual(observed, ['walletUpdateNotice'])
        self.assertEqual((trace.receipt()['command'], trace.receipt()['target'],
                          trace.receipt()['stage']), ('readonly-seam-pointer', 'token_explorer', 'REPLY'))

    def test_all_four_controls_are_observed_without_financial_or_form_input(self):
        original, observed = OriginalSurfaces(), []
        inspect.observe_surface_seams(original.send, observed)
        self.assertEqual(observed,
            ['walletUpdateNotice', 'tokenExplorer', 'pillarAprEstimate', 'swapTerms'])
        self.assertEqual((original.tab, original.route, original.address),
            ('dashboard', '/dashboard', 'fixture-owner'))
        self.assertFalse(original.token_open)
        attempted = [command for command in original.calls
                     if command['cmd'] == 'readonly-seam-pointer' and command['seam'] == 'tokenExplorer']
        self.assertEqual(attempted, [dict(cmd='readonly-seam-pointer',
            seam='tokenExplorer', key='token_explorer_control')])
        self.assertTrue(all(command['cmd'] in
            {'state', 'tap', 'wait', 'readonly-seam-pointer', 'key', 'logs'}
            for command in original.calls))

    def test_owner_and_route_replacement_preserve_only_the_confirmed_prefix(self):
        for fault in ('owner-before', 'route-before', 'owner-after', 'route-after'):
            original, observed = OriginalSurfaces(fault), []
            with self.subTest(fault=fault), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, ['walletUpdateNotice'])

    def test_wrong_or_refused_pointer_receipts_do_not_record_the_token_probe(self):
        for fault in ('wrong-seam', 'wrong-scope', 'pointer-refused', 'absorption-refused'):
            original, observed = OriginalSurfaces(fault), []
            with self.subTest(fault=fault), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, ['walletUpdateNotice'])

    def test_missing_token_control_cannot_complete_the_inspection(self):
        original, observed = OriginalSurfaces('missing-token-control'), []
        with self.assertRaises(inspect.Refused):
            inspect.observe_surface_seams(original.send, observed)
        self.assertEqual(observed, ['walletUpdateNotice'])
        self.assertFalse(any(command['cmd'] == 'readonly-seam-pointer'
            and command['seam'] == 'tokenExplorer' for command in original.calls))


class ActivityMessageSeamProbeTests(unittest.TestCase):
    @staticmethod
    def receipt(theme):
        return dict(schema=1,
            scope='readonly_native_activity_message_seam_observation',
            seam='zapReceive', theme=theme, pointerDispatched=True,
            absorptionObserved=True, originalHistoryRetained=True,
            previewOnly=True)

    def test_existing_history_preview_is_explicit_and_checked_in_both_themes(self):
        calls, observed = [], []
        theme = 'light'

        def send(command):
            nonlocal theme
            calls.append(command.copy())
            if command['cmd'] == 'theme':
                theme = command.get('mode', command.get('restore', {}).get('mode', theme))
                return dict(mode=theme)
            self.assertEqual(command, dict(cmd='readonly-activity-message-seam'))
            return dict(self.receipt(theme), private='private response detail')

        inspect.observe_activity_message_seams(send, observed, require_home=lambda: None)
        self.assertEqual(observed, [dict(panel='activity-preview', seam='zapReceive',
            theme=value, preview_only=True) for value in ('dark', 'light')])
        self.assertEqual(theme, 'light')
        self.assertEqual(sum(v['cmd'] == 'readonly-activity-message-seam' for v in calls), 2)
        self.assertTrue(all(v['cmd'] in ('theme', 'readonly-activity-message-seam') for v in calls))
        self.assertNotIn('private response detail', str(observed))

    def test_unknown_or_refused_preview_cannot_record_a_pointer_observation(self):
        for key, value in [('schema', True), ('schema', 2), ('scope', 'foreign'),
            ('seam', 'zapSend'), ('theme', 'light'), ('pointerDispatched', False),
            ('absorptionObserved', False), ('originalHistoryRetained', False),
            ('previewOnly', False)]:
            calls, observed = [], []

            def send(command):
                calls.append(command.copy())
                if command['cmd'] == 'theme':
                    return dict(mode='dark')
                result = self.receipt('dark')
                result[key] = value
                return result

            with self.subTest(key=key, value=value), self.assertRaises(inspect.Refused):
                inspect.observe_activity_message_seams(send, observed, require_home=lambda: None)
            self.assertEqual(observed, [])
            self.assertEqual(sum(v['cmd'] == 'readonly-activity-message-seam' for v in calls), 1)
            self.assertFalse(any('restore' in v for v in calls))

    def test_owner_loss_and_original_exchange_error_stop_without_retry(self):
        for exchange_error in (False, True):
            calls, observed = [], []
            current = True
            original = ValueError('private original failure')

            def require_home():
                inspect.need(current, 'ENTRY_REFUSED')

            def send(command):
                nonlocal current
                calls.append(command.copy())
                if command['cmd'] == 'theme':
                    return dict(mode='dark')
                if exchange_error:
                    raise original
                current = False
                return self.receipt('dark')

            kind = ValueError if exchange_error else inspect.Refused
            with self.subTest(exchange_error=exchange_error), self.assertRaises(kind) as caught:
                inspect.observe_activity_message_seams(send, observed, require_home=require_home)
            if exchange_error:
                self.assertIs(caught.exception, original)
            self.assertEqual(observed, [])
            self.assertEqual(sum(v['cmd'] == 'readonly-activity-message-seam' for v in calls), 1)
            self.assertFalse(any('restore' in v for v in calls))


class ReadonlyOwnerSurfaces:
    def __init__(self, fault=None, seam='walletUpdateNotice'):
        self.fault, self.seam = fault, seam
        self.tab, self.route, self.address = 'dashboard', '/dashboard', 'fixture-owner'
        self.mode, self.saved, self.brightness = 'system', None, 'light'
        self.warning_accepted = False
        self.calls = []
        self.original_error = ValueError('private original failure')

    def send(self, command):
        self.calls.append(command.copy())
        name = command['cmd']
        if name == 'state':
            return dict(tab=self.tab, route=self.route, address=self.address,
                locale='en', direction='ltr', node='ws://127.0.0.1:45998',
                chainId=321, signingChainId=321, savedSigningChainId=321,
                walletUnlocked=True, walletInitCompleted=True,
                embeddedNode=False, nodeTransitionPending=False)
        if name == 'theme':
            if 'mode' in command:
                self.mode = self.brightness = command['mode']
                self.saved = 'ThemeMode.' + self.mode
            if 'restore' in command:
                self.mode, self.saved = (command['restore'][key]
                    for key in ('mode', 'savedMode'))
                self.brightness = 'light'
            reply = dict(mode=self.mode, savedMode=self.saved, brightness=self.brightness)
            if self.fault == 'theme-original' and not set(command) & {'mode', 'restore'}:
                reply['mode'] = 'foreign'
            if self.fault == 'theme-selected' and 'mode' in command:
                reply['brightness'] = 'light' if self.mode == 'dark' else 'dark'
            if self.fault == 'theme-restored' and 'restore' in command:
                reply['mode'] = 'foreign'
            return reply
        if name == 'tap':
            if 'tab' in command:
                self.tab = command['tab']
                self.route = '/' + self.tab
                return {}
            key = command['key']
            if key == 'nodes_tab_pillars':
                self.route = '/pillars'
            elif key == 'pillars_sort':
                self.route = '/pillars/menu'
            elif key == 'p2p_start_swap':
                self.route = '/p2pSwap/' + ('draft' if self.warning_accepted else 'warning')
            elif key == 'p2p_warning_continue':
                self.warning_accepted = True
                self.route = '/p2pSwap/draft'
            elif key == 'swap_action_close':
                self.route = '/p2pSwap'
            else:
                raise AssertionError('Unexpected action')
            return dict(target=dict(key=key, kind='button'))
        if name == 'wait':
            return {} if command.get('gone') else dict(target=dict(
                key=command['key'], kind=command.get('kind', 'button')))
        if name == 'tree':
            if self.fault == 'tree-owner':
                self.address = 'replacement-owner'
            warning = self.route.endswith('/warning')
            return dict(nodes=[dict(key='p2p_warning_continue' if warning else
                'swap_counterparty_input', kind='button' if warning else 'field',
                enabled=True, text='private response detail')])
        if name == 'readonly-seam-pointer':
            seam = command['seam']
            reply = dict(scope='readonly_native_seam_pointer_observation',
                seam=seam, pointerDispatched=True, absorptionObserved=True)
            if seam == self.seam:
                if self.fault == 'owner-after':
                    self.address = 'replacement-owner'
                if self.fault == 'route-after':
                    self.route = '/replacement'
                if self.fault == 'wrong-scope':
                    reply['scope'] = 'foreign'
                if self.fault == 'wrong-seam':
                    reply['seam'] = 'foreign'
                if self.fault == 'pointer-refused':
                    reply['pointerDispatched'] = False
                if self.fault == 'original-error':
                    raise self.original_error
            return reply
        if name == 'key' and command['key'] == 'escape':
            self.route = '/pillars'
            return {}
        raise AssertionError('Unexpected command')


class ReadonlyOwnerSeamProbeTests(unittest.TestCase):
    def test_both_themes_use_the_original_warning_and_restore_home_and_preference(self):
        original, observed = ReadonlyOwnerSurfaces(), []
        inspect.observe_readonly_owner_seams(original.send, observed)
        self.assertEqual(observed, [dict(panel=panel, seam=seam, theme=theme)
            for theme in ('dark', 'light') for panel, seam in (
                ('home', 'walletUpdateNotice'), ('pillars', 'pillarAprEstimate'),
                ('swap', 'swapTerms'))])
        self.assertEqual((original.tab, original.route, original.address),
                         ('dashboard', '/dashboard', 'fixture-owner'))
        self.assertEqual((original.mode, original.saved), ('system', None))
        keys = [c.get('key') for c in original.calls if c['cmd'] == 'tap']
        self.assertEqual(keys.count('p2p_start_swap'), 2)
        self.assertEqual(keys.count('p2p_warning_continue'), 1)
        self.assertEqual(keys.count('swap_action_close'), 2)
        self.assertEqual(inspect.SEAM_PILOTS[inspect.HOME_SEAMS_FAMILY][2], 11)
        self.assertTrue(all(c['cmd'] in ('state', 'theme', 'tap', 'wait', 'tree',
            'readonly-seam-pointer', 'key') for c in original.calls))
        self.assertFalse(any(set(c) & {'value', 'amount', 'seed', 'force'} for c in original.calls))
        self.assertNotIn('private response detail', str(observed))

    def test_theme_read_selection_and_restore_require_actual_observations(self):
        for fault in ('theme-original', 'theme-selected', 'theme-restored'):
            original, observed = ReadonlyOwnerSurfaces(fault), []
            with self.subTest(fault=fault), self.assertRaises(inspect.Refused):
                inspect.observe_readonly_owner_seams(original.send, observed)
            self.assertEqual(len(observed), 6 if fault == 'theme-restored' else 0)
            self.assertEqual(sum(c.get('key') == 'p2p_start_swap' for c in original.calls),
                             2 if fault == 'theme-restored' else 0)

    def test_owner_or_route_loss_stops_before_the_next_original_control(self):
        for index, seam in enumerate(('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms')):
            for fault in ('owner-after', 'route-after'):
                original, observed = ReadonlyOwnerSurfaces(fault, seam), []
                with self.subTest(seam=seam, fault=fault), self.assertRaises(inspect.Refused):
                    inspect.observe_readonly_owner_seams(original.send, observed)
                self.assertEqual(len(observed), index)
                self.assertEqual(sum(c['cmd'] == 'readonly-seam-pointer'
                                     for c in original.calls), index + 1)
                self.assertFalse(any('restore' in c for c in original.calls))

    def test_refused_pointer_and_original_error_are_never_retried(self):
        for index, seam in enumerate(('walletUpdateNotice', 'pillarAprEstimate', 'swapTerms')):
            for fault in ('wrong-scope', 'wrong-seam', 'pointer-refused', 'original-error'):
                original, observed = ReadonlyOwnerSurfaces(fault, seam), []
                kind = ValueError if fault == 'original-error' else inspect.Refused
                with self.subTest(seam=seam, fault=fault), self.assertRaises(kind) as caught:
                    inspect.observe_readonly_owner_seams(original.send, observed)
                if fault == 'original-error':
                    self.assertIs(caught.exception, original.original_error)
                self.assertEqual(len(observed), index)
                self.assertEqual(sum(c['cmd'] == 'readonly-seam-pointer'
                                     for c in original.calls), index + 1)
                self.assertFalse(any('restore' in c for c in original.calls))

    def test_owner_loss_during_passive_opening_prevents_warning_acceptance(self):
        original, observed = ReadonlyOwnerSurfaces('tree-owner'), []
        with self.assertRaises(inspect.Refused):
            inspect.observe_readonly_owner_seams(original.send, observed)
        self.assertEqual(len(observed), 2)
        keys = [c.get('key') for c in original.calls if c['cmd'] == 'tap']
        self.assertEqual(keys.count('p2p_start_swap'), 1)
        self.assertNotIn('p2p_warning_continue', keys)
        self.assertFalse(any('restore' in c for c in original.calls))


class ReadonlySwapOpeningTests(unittest.TestCase):
    def test_one_current_snapshot_selects_warning_or_draft_after_original_transition(self):
        for phase in ('warning', 'draft', 'delayed'):
            route = '/root' if phase == 'delayed' else '/modal'
            calls = []

            def send(command):
                nonlocal route
                calls.append(command)
                route = '/modal'
                warning = phase != 'draft'
                return dict(nodes=[dict(key='p2p_warning_continue' if warning else
                    'swap_counterparty_input', kind='button' if warning else 'field',
                    enabled=True, text='private response detail')])

            observed = inspect.readonly_swap_opening(send, lambda: route, '/root',
                clock=lambda: 0, pause=lambda _: None)
            self.assertEqual(observed, ('draft' if phase == 'draft' else 'warning', '/modal'))
            self.assertEqual(len(calls), 2 if phase == 'delayed' else 1)
            self.assertTrue(all(c == dict(cmd='tree') for c in calls))
            self.assertNotIn('private response detail', str(observed))

    def test_ambiguous_malformed_disabled_and_absent_views_cannot_dispatch_input(self):
        warning = dict(key='p2p_warning_continue', kind='button', enabled=True)
        draft = dict(key='swap_counterparty_input', kind='field', enabled=True)
        replies = [None, {}, dict(nodes=True), dict(nodes=[None]),
            dict(nodes=[dict(kind='error')]), dict(nodes=[warning, warning]),
            dict(nodes=[dict(warning, enabled=False)]),
            dict(nodes=[dict(warning, kind='field')]), dict(nodes=[warning, draft]),
            dict(nodes=[{}] * 513), dict(nodes=[])]
        for reply in replies:
            calls = []

            def send(command):
                calls.append(command)
                return reply

            with self.subTest(reply=reply), self.assertRaises(inspect.Refused):
                inspect.readonly_swap_opening(send, lambda: '/modal', '/root',
                    clock=lambda: 0, pause=lambda _: None)
            self.assertEqual(len(calls), 34 if reply == dict(nodes=[]) else 1)
            self.assertTrue(all(c == dict(cmd='tree') for c in calls))

        calls = []
        expired = iter((0, 6))
        with self.assertRaises(inspect.Refused):
            inspect.readonly_swap_opening(lambda c: calls.append(c), lambda: '/modal',
                '/root', clock=lambda: next(expired), pause=lambda _: None)
        self.assertEqual(calls, [])
        original = ValueError('private owner failure')

        def lost():
            raise original

        with self.assertRaises(ValueError) as caught:
            inspect.readonly_swap_opening(lambda c: calls.append(c), lost, '/root',
                clock=lambda: 0, pause=lambda _: None)
        self.assertIs(caught.exception, original)
        self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
