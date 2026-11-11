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
            return dict(tab=self.tab, route=self.route, address=self.address, locale='en',
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
