"""Finite regression cases; no node, Docker, wallet or network is started."""

import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab


def node_config():
    return dict(DataPath="/root/.znn", GenesisFile="/root/.znn/genesis.json",
        WalletPath="/root/.znn/wallet", Producer=dict(Address="fixture", Index=0),
        Net=dict(BootstrapPeers=["/ip4/172.30.0.12/tcp/35995/p2p/" + "a" * 40],
                 Seeders=["enode://" + "b" * 128 + "@172.30.0.13:35995"],
                 ListenHost="0.0.0.0", ListenPort=35995, MinConnectedPeers=3, MinPeers=0),
        RPC=dict(EnableHTTP=True, EnableWS=True, HTTPHost="0.0.0.0",
                 WSHost="0.0.0.0", HTTPPort=35997, WSPort=35998))


class ConfigurationTests(unittest.TestCase):
    def test_native_bootstrap_and_seeder_remain_on_loopback(self):
        result = lab.configuration(node_config(), "pillar", Path("fixture"), "native")
        self.assertIn("/ip4/127.0.0.1/tcp/45992/p2p/", result["Net"]["BootstrapPeers"][0])
        self.assertTrue(result["Net"]["Seeders"][0].endswith("@127.0.0.1:45993"))
        self.assertNotIn("172.30.0.", json.dumps(result))
        self.assertEqual(result["Net"]["MinConnectedPeers"], 3)
        self.assertEqual(result["Producer"], node_config()["Producer"])

    def test_each_native_role_has_a_distinct_loopback_port(self):
        ports = {lab.configuration(node_config(), role, Path("fixture"), "native")["Net"]["ListenPort"]
                 for role in lab.ROLES}
        self.assertEqual(len(ports), 5)
        for role in lab.ROLES:
            cfg = lab.configuration(node_config(), role, Path("fixture"), "native")
            self.assertEqual(cfg["Net"]["ListenHost"], "127.0.0.1")
            self.assertEqual(cfg["RPC"]["HTTPHost"], "127.0.0.1")
            self.assertEqual(cfg["RPC"]["WSHost"], "127.0.0.1")

    def test_only_rpc_role_exposes_http_and_websocket(self):
        for backend in ("native", "docker"):
            for role in lab.ROLES:
                cfg = lab.configuration(node_config(), role, Path("fixture"), backend)
                self.assertIs(cfg["RPC"]["EnableHTTP"], role == "rpc")
                self.assertIs(cfg["RPC"]["EnableWS"], role == "rpc")

    def test_docker_keeps_its_internal_ports_and_moves_the_subnet(self):
        cfg = lab.configuration(node_config(), "rpc", Path("fixture"), "docker")
        self.assertIn("172.37.0.12/tcp/35995", cfg["Net"]["BootstrapPeers"][0])
        self.assertEqual((cfg["RPC"]["HTTPPort"], cfg["RPC"]["WSPort"]), (35997, 35998))
        self.assertEqual(cfg["GenesisFile"], "/data/genesis.json")

    def test_input_configuration_is_not_mutated(self):
        source = node_config()
        before = copy.deepcopy(source)
        lab.configuration(source, "rpc", Path("fixture"), "native")
        self.assertEqual(source, before)

    def test_public_dns_alias_or_additional_path_is_refused(self):
        candidates = ["https://example.invalid/172.30.0.12/tcp/35995/p2p/" + "a" * 40,
                      "/dns4/example.invalid/tcp/35995/p2p/" + "a" * 40,
                      "/ip4/172.30.0.12/tcp/35995/p2p/" + "a" * 40 + "/extra"]
        for peer in candidates:
            source = node_config()
            source["Net"]["BootstrapPeers"] = [peer]
            for backend in ("native", "docker"):
                with self.subTest(peer=peer, backend=backend), self.assertRaises(lab.Failure):
                    lab.configuration(source, "rpc", Path("fixture"), backend)

    def test_foreign_subnet_or_wrong_port_is_refused(self):
        for old, new in (("172.30.0.12", "172.31.0.12"), ("35995", "35996")):
            source = node_config()
            source["Net"]["BootstrapPeers"][0] = source["Net"]["BootstrapPeers"][0].replace(old, new)
            with self.assertRaises(lab.Failure):
                lab.configuration(source, "rpc", Path("fixture"), "native")

    def test_non_original_seeder_is_refused(self):
        source = node_config()
        source["Net"]["Seeders"] = ["enode://" + "b" * 128 + "@example.invalid:35995"]
        with self.assertRaises(lab.Failure):
            lab.configuration(source, "rpc", Path("fixture"), "native")


class OriginalHandleTests(unittest.TestCase):
    def original(self, process, drains):
        value = object.__new__(lab.Original)
        value.process, value.drains = process, drains
        value.forced, value.receipt = False, None
        return value

    def drain(self, data=b"", finish=True):
        value = mock.Mock(data=bytearray(data), count=len(data), error=None)
        value.overflow.is_set.return_value = False
        value.finish.return_value = finish
        return value

    def test_both_drains_are_finished_after_one_reports_incomplete(self):
        drains = [self.drain(finish=False), self.drain()]
        original = self.original(mock.Mock(poll=mock.Mock(return_value=0)), drains)
        with self.assertRaises(lab.Failure):
            original.finish()
        for drain in drains:
            drain.finish.assert_called_once_with(3)
        self.assertFalse(original.receipt["output_complete"])

    def test_forced_exit_cannot_be_successful_even_with_zero_exit(self):
        original = self.original(mock.Mock(poll=mock.Mock(return_value=0)), [self.drain(), self.drain()])
        original.forced = True
        with self.assertRaises(lab.Failure):
            original.finish()

    def test_terminal_failure_is_not_replaced_by_a_second_stop(self):
        original = self.original(mock.Mock(poll=mock.Mock(return_value=7)), [self.drain(), self.drain()])
        with self.assertRaises(lab.Failure):
            original.finish()
        original.stop()
        original.process.send_signal.assert_not_called()
        self.assertEqual(original.receipt["exit_code"], 7)

    def test_overflow_refuses_native_process_admission(self):
        drain = self.drain()
        drain.overflow.is_set.return_value = True
        original = self.original(mock.Mock(), [drain, self.drain()])
        with self.assertRaises(lab.Failure):
            original.healthy()

    def test_native_stop_attempts_every_original_after_one_failure(self):
        runtime = lab.Native(mock.Mock(), Path("fixture"), {})
        runtime.originals = [mock.Mock() for _ in lab.ROLES]
        runtime.originals[2].stop.side_effect = lab.Failure("STOP_UNKNOWN")
        with self.assertRaises(lab.Failure):
            runtime.stop()
        for original in runtime.originals:
            original.stop.assert_called_once_with()

    def test_running_native_process_cannot_replace_a_missing_fifth_owner(self):
        runtime = lab.Native(mock.Mock(), Path("fixture"), {})
        runtime.originals = [mock.Mock() for _ in range(4)]
        with self.assertRaises(lab.Failure):
            runtime.healthy()

    def test_prior_terminal_failure_cannot_become_success_on_a_second_stop(self):
        runtime = lab.Native(mock.Mock(), Path("fixture"), {})
        runtime.originals = [mock.Mock(receipt=dict(exit_code=0, output_complete=True, forced=False))
                             for _ in lab.ROLES]
        runtime.originals[0].receipt["exit_code"] = 7
        with self.assertRaises(lab.Failure):
            runtime.stop()


class IsolationTests(unittest.TestCase):
    def test_child_environment_excludes_tokens_and_original_profiles(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            result = lab.child_environment(root, dict(PATH="tools", GITHUB_TOKEN="private",
                ACTIONS_ID_TOKEN_REQUEST_TOKEN="private", HOME="original", USERPROFILE="original"))
            self.assertNotIn("GITHUB_TOKEN", result)
            self.assertNotIn("ACTIONS_ID_TOKEN_REQUEST_TOKEN", result)
            self.assertNotIn("original", result.values())
            for field in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "TMP", "TEMP"):
                self.assertTrue(Path(result[field]).is_relative_to(root))

    def test_regular_input_refuses_a_hard_link(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / "first").write_bytes(b"fixture")
            try:
                os.link(root / "first", root / "second")
            except (OSError, NotImplementedError):
                self.skipTest("Hard links unavailable")
            with self.assertRaises(lab.Failure):
                lab.regular(root / "first")

    def test_real_wallet_or_non_actions_run_is_refused_before_any_launch(self):
        with mock.patch.dict(lab.os.environ, {}, clear=True), mock.patch.object(lab, "Original") as launch:
            with self.assertRaises(lab.Failure):
                lab.run("native")
            launch.assert_not_called()

    def test_self_hosted_runner_cannot_use_the_lower_fixture_floor(self):
        parent = dict(GITHUB_ACTIONS="true", GITHUB_EVENT_NAME="workflow_dispatch",
            GITHUB_REPOSITORY="edgepillar/syrius", GITHUB_SHA="a" * 40,
            SYRIUS_HOSTED_RUNNER="self-hosted")
        with mock.patch.dict(lab.os.environ, parent, clear=True), mock.patch.object(lab, "Original") as launch:
            with self.assertRaises(lab.Failure) as result:
                lab.run("native")
            self.assertEqual(result.exception.code, "ENVIRONMENT_REFUSED")
            launch.assert_not_called()

    def test_port_preflight_closes_all_originals_after_a_conflict(self):
        sockets = [mock.Mock(), mock.Mock()]
        sockets[1].bind.side_effect = OSError("fixture")
        with mock.patch.object(lab.socket, "socket", side_effect=sockets), self.assertRaises(lab.Failure):
            lab.preflight_ports("native")
        for original in sockets:
            original.close.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
