"""Memory controls for the source-bound unavailable page controls."""

import unittest

from tool.ci import windows_wallet_inspection as inspect


class OriginalSurfaces:
    def __init__(self, fault=None):
        self.fault = fault
        self.tab, self.route, self.address = 'dashboard', '/dashboard', 'fixture-owner'
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
            if key in ('home_hero', 'strip_update_button'):
                if self.fault == 'missing-' + key:
                    return dict(ok=True)
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
            dict(cmd='wait', key='home_hero', exact=True, timeoutMs=5000),
            dict(cmd='state'),
            dict(cmd='wait', key='strip_update_button', kind='button', exact=True, timeoutMs=5000),
            dict(cmd='state'),
        ])

    def test_unready_home_or_update_stops_before_any_pointer(self):
        for key in ('home_hero', 'strip_update_button'):
            original, observed = OriginalSurfaces('missing-' + key), []
            with self.subTest(key=key), self.assertRaises(inspect.Refused):
                inspect.observe_surface_seams(original.send, observed)
            self.assertEqual(observed, [])
            self.assertFalse(any(command['cmd'] == 'readonly-seam-pointer'
                                 for command in original.calls))

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


if __name__ == '__main__':
    unittest.main()
