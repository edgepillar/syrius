"""Finite regression cases; no node, Docker, wallet or network is started."""

import copy
import json
import os
from pathlib import Path
import struct
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


class CompilerDiagnosticTests(unittest.TestCase):
    def test_version_requirement_and_locked_modules_have_distinct_codes(self):
        self.assertEqual(lab.compiler_diagnostics(b"dependency requires go >= 1.24.0"),
                         [dict(code="GO_VERSION_REQUIRED")])
        self.assertEqual(lab.compiler_diagnostics(b"go: updates to go.mod needed"),
                         [dict(code="LOCKED_MODULE_CHANGED")])

    def test_linker_reference_retains_only_the_public_symbol(self):
        for symbol in ("runtime.stopTheWorld", "crypto/tls.cipherSuiteTLS13"):
            value = lab.compiler_diagnostics(("/fixture/private/compiler/link: invalid reference to " + symbol + "\n").encode())
            self.assertEqual(value, [dict(code="GO_LINKNAME_REFUSED", symbol=symbol)])
            self.assertNotIn("/fixture/", json.dumps(value))

    def test_unclassified_private_text_is_never_echoed(self):
        value = lab.compiler_diagnostics(b"/fixture/private/value: an unrecognized diagnostic\n")
        self.assertEqual(value, [dict(code="UNCLASSIFIED_BUILD_FAILURE")])
        self.assertNotIn("private", json.dumps(value))


class NodeSourceTests(unittest.TestCase):
    def test_only_two_exact_source_pins_are_admitted(self):
        self.assertEqual(lab.selected_node_source("original")[0], lab.NODE_SHA)
        self.assertEqual(lab.selected_node_source("upstream")[0], lab.UPSTREAM_NODE_SHA)
        for offered in ("dev", "master", "https://example.invalid", "a" * 40, None):
            with self.subTest(offered=offered), self.assertRaises(lab.Failure):
                lab.selected_node_source(offered)

    @staticmethod
    def events():
        package = "github.com/zenon-network/go-zenon/p2p/legacy"
        return [dict(Action="pass", Package=package, Test=name) for name in lab.SHUTDOWN_TESTS] + [dict(Action="pass", Package=package)]

    def test_all_seven_original_go_tests_and_package_pass_are_required(self):
        raw = b"\n".join(json.dumps(event).encode() for event in self.events())
        result = lab.shutdown_test_result(raw)
        self.assertEqual(result, dict(passed=True, tests=list(lab.SHUTDOWN_TESTS), skips=0))

    def test_empty_missing_duplicate_skipped_or_failed_go_results_are_refused(self):
        events = self.events()
        invalid = [[], events[1:], events[:-1], events + [events[0]],
            events + [dict(Action="skip")], events + [dict(Action="fail")]]
        for offered in invalid:
            raw = b"\n".join(json.dumps(event).encode() for event in offered)
            with self.subTest(events=len(offered)), self.assertRaises(lab.Failure):
                lab.shutdown_test_result(raw)
        with self.assertRaises(lab.Failure):
            lab.shutdown_test_result(b"private-path: not a Go JSON event")

    def test_raw_test_output_is_ignored_in_the_finite_projection(self):
        events = [dict(Action="output", Output="private-path and private-input")] + self.events()
        result = lab.shutdown_test_result(b"\n".join(json.dumps(event).encode() for event in events))
        self.assertNotIn("private", json.dumps(result))


class RuntimeDiagnosticTests(unittest.TestCase):
    def test_shutdown_projection_keeps_only_finite_stage_codes(self):
        raw = (b'private-path msg="Stopping znnd ..."\n'
               b'msg="stopping p2p server ..."\nmsg="HTTP server stopped" endpoint=private\n'
               b'msg="releasing dataDir lock ..."\nmsg="Failed to stop node" reason=private')
        result = lab.node_diagnostics(raw)
        self.assertEqual(set(result), {"NODE_STOP_REQUESTED", "NODE_P2P_STOP_REQUESTED",
            "NODE_HTTP_STOPPED", "NODE_DATA_LOCK_RELEASE_REQUESTED", "NODE_STOP_FAILED"})
        self.assertNotIn("private", json.dumps(result))

    def test_owned_log_files_are_bounded_and_never_returned_as_text(self):
        calls = []
        def read(path):
            calls.append(path)
            return b'private-path msg="stopping p2p server ..."'
        with mock.patch.object(lab, "directories"), mock.patch.object(lab, "regular", side_effect=read):
            result = lab.native_log_projection(Path("fixture"))
        self.assertEqual(calls, [Path("fixture/log/zenon.log"), Path("fixture/log/error/zenon.error.log")])
        self.assertEqual(result["status"], "READ")
        self.assertEqual(result["codes"], ["NODE_P2P_STOP_REQUESTED"])
        self.assertNotIn("private", json.dumps(result))
        self.assertTrue(all(set(item) == {"kind", "bytes", "sha256"} for item in result["files"]))

    def test_missing_and_refused_logs_keep_honest_distinct_status(self):
        for error, status in ((FileNotFoundError(), "MISSING"), (lab.Failure("STORAGE_REFUSED"), "REFUSED")):
            with mock.patch.object(lab, "directories"), mock.patch.object(lab, "regular", side_effect=error):
                result = lab.native_log_projection(Path("fixture"))
            self.assertEqual(result["status"], status)
            self.assertEqual(result["codes"], [])

    def test_original_wire_codes_are_preserved_without_exception_text(self):
        for code in ("HTTP_REFUSED", "WS_REFUSED", "FRONTIER_REFUSED", "CLOSE_UNKNOWN"):
            self.assertEqual(lab.failure_code(lab.wire_policy.Refused(code)), code)
        self.assertEqual(lab.failure_code(ValueError("/fixture/private/value")), "INTERNAL_ERROR")

    def test_node_log_projection_keeps_categories_and_omits_private_text(self):
        result = lab.node_diagnostics(b"/fixture/private/value: permission denied\npanic: fixture")
        self.assertEqual(set(result), {"NODE_STORAGE_REFUSED", "NODE_PANIC"})
        self.assertNotIn("private", json.dumps(result))
        self.assertEqual(lab.node_diagnostics(b"using key file /fixture/private/value"), [])

    def test_docker_state_requires_an_original_created_resource(self):
        runtime = lab.Docker(mock.Mock(), Path("fixture"), {}, "fixture")
        runtime.created = ["fixture-original"]
        item = dict(Id="fixture-original", State=dict(Running=False, ExitCode=1, OOMKilled=False))
        runtime.record_state(item, "before_stop")
        self.assertEqual(runtime.states, [dict(phase="before_stop", role="pillar", running=False,
                                               exit_code=1, oom_killed=False)])
        item["Id"] = "unowned"
        with self.assertRaises(lab.Failure):
            runtime.record_state(item, "before_stop")

    def test_wire_cleanup_cannot_replace_the_first_observed_failure(self):
        http, ws = mock.Mock(), mock.Mock()
        ws.connect.side_effect = lab.wire_policy.Refused("WS_REFUSED")
        ws.close.side_effect = lab.wire_policy.Refused("CLOSE_UNKNOWN")
        report = dict(error_codes=[])
        with mock.patch.object(lab.socket, "create_connection", return_value=mock.MagicMock()), \
                mock.patch.object(lab, "make_transports", return_value=(object(), object())), \
                mock.patch.object(lab.wire_policy, "HttpRpc", return_value=http), \
                mock.patch.object(lab.wire_policy, "WsRpc", return_value=ws), \
                self.assertRaises(lab.wire_policy.Refused) as result:
            lab.observe(mock.Mock(), Path("fixture"), report)
        self.assertEqual(result.exception.code, "WS_REFUSED")
        self.assertEqual(report["error_codes"], ["CLOSE_UNKNOWN"])
        http.close.assert_called_once_with()
        ws.close.assert_called_once_with()


class StaticBinaryTests(unittest.TestCase):
    @staticmethod
    def elf(kinds=(1, 7)):
        raw = bytearray(64 + 56 * len(kinds))
        raw[:7] = b"\x7fELF\x02\x01\x01"
        struct.pack_into("<HHI", raw, 16, 2, 62, 1)
        struct.pack_into("<Q", raw, 32, 64)
        struct.pack_into("<HH", raw, 54, 56, len(kinds))
        for index, kind in enumerate(kinds):
            struct.pack_into("<I", raw, 64 + 56 * index, kind)
        return bytes(raw)

    def test_static_amd64_executable_is_accepted_without_execution(self):
        self.assertTrue(lab.static_linux_binary(self.elf()))

    def test_interpreter_or_dynamic_section_cannot_enter_scratch_image(self):
        for kind in (2, 3):
            with self.subTest(kind=kind), self.assertRaises(lab.Failure):
                lab.static_linux_binary(self.elf((1, kind)))

    def test_wrong_architecture_or_shared_object_is_refused(self):
        for offset, value in ((16, 3), (18, 183)):
            raw = bytearray(self.elf())
            struct.pack_into("<H", raw, offset, value)
            with self.assertRaises(lab.Failure):
                lab.static_linux_binary(bytes(raw))

    def test_truncated_or_unbounded_program_headers_are_refused(self):
        raw = bytearray(self.elf())
        struct.pack_into("<H", raw, 56, 65535)
        for value in (bytes(raw), self.elf()[:-1], b"MZ" + b"\0" * 70):
            with self.assertRaises(lab.Failure):
                lab.static_linux_binary(value)


class KeyfileDeploymentTests(unittest.TestCase):
    @staticmethod
    def source():
        name = "z1" + "a" * 38
        value = dict(Path="/root/.znn/wallet/" + name, baseAddress=name, version=1, timestamp=1,
            crypto=dict(cipherName="aes-256-gcm", kdf="argon2.IDKey", cipherData="0xabcdef",
                        nonce="0x123456", argon2Params=dict(salt="0x789abc")))
        return name, value

    def test_only_embedded_path_moves_and_crypto_bytes_remain_equal(self):
        name, value = self.source()
        raw = json.dumps(value).encode()
        for parent in ("/data/wallet/", "C:\\fixture\\pillar\\wallet\\"):
            result = json.loads(lab.relocated_keyfile(raw, name, parent + name))
            self.assertEqual(result["Path"], parent + name)
            self.assertEqual({k: v for k, v in result.items() if k != "Path"},
                             {k: v for k, v in value.items() if k != "Path"})
            self.assertEqual(json.dumps(value).encode(), raw)

    def test_another_profile_address_or_unknown_field_cannot_be_adopted(self):
        name, value = self.source()
        for field, changed in (("Path", "/fixture/private/wallet/" + name),
                               ("baseAddress", "/fixture/private/value"), ("extra", "fixture")):
            source = dict(value)
            source[field] = changed
            with self.assertRaises(lab.Failure):
                lab.relocated_keyfile(json.dumps(source).encode(), name, "/data/wallet/" + name)

    def test_committed_filename_can_differ_from_the_preserved_base_address(self):
        name, value = self.source()
        value["baseAddress"] = "z1" + "b" * 38
        result = json.loads(lab.relocated_keyfile(json.dumps(value).encode(), name, "/data/wallet/" + name))
        self.assertEqual(result["baseAddress"], value["baseAddress"])
        self.assertEqual(result["crypto"], value["crypto"])
        self.assertEqual(result["Path"], "/data/wallet/" + name)

    def test_malformed_fixture_or_changed_version_is_refused(self):
        name, value = self.source()
        value["version"] = 2
        for raw in (b"not-json", json.dumps(value).encode()):
            with self.assertRaises(lab.Failure):
                lab.relocated_keyfile(raw, name, "/data/wallet/" + name)


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
            self.assertEqual(cfg["RPC"]["HTTPHost"], "127.0.0.1" if role == "rpc" else "")
            self.assertEqual(cfg["RPC"]["WSHost"], "127.0.0.1" if role == "rpc" else "")

    def test_only_rpc_role_exposes_http_and_websocket(self):
        for backend in ("native", "docker"):
            for role in lab.ROLES:
                cfg = lab.configuration(node_config(), role, Path("fixture"), backend)
                self.assertIs(cfg["RPC"]["EnableHTTP"], role == "rpc")
                self.assertIs(cfg["RPC"]["EnableWS"], role == "rpc")
                self.assertEqual(bool(cfg["RPC"]["HTTPHost"]), role == "rpc")
                self.assertEqual(bool(cfg["RPC"]["WSHost"]), role == "rpc")

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
    def test_failed_original_signal_is_retained_and_never_reissued(self):
        process = mock.Mock()
        process.poll.side_effect = [None, 0]
        process.send_signal.side_effect = OSError(5, "fixture signal refusal")
        original = self.original(process, [self.drain(), self.drain()])
        with self.assertRaises(OSError):
            original.request_stop()
        with self.assertRaises(lab.Failure):
            original.stop()
        process.send_signal.assert_called_once()
        process.kill.assert_called_once_with()
        self.assertEqual(original.receipt["stop_code"], "SIGNAL_OS_ERROR")
        self.assertTrue(original.receipt["forced"])

    def test_native_keeps_rpc_running_until_producers_and_observer_have_finished(self):
        events = []
        originals = []
        for index in range(5):
            item = mock.Mock(receipt=dict(exit_code=0, output_complete=True, forced=False), drains=[])
            def finish(index=index):
                self.assertEqual(index, len(events))
                events.append(index)
            item.stop.side_effect = finish
            originals.append(item)
        runtime = lab.Native(mock.Mock(), Path("fixture"), {})
        runtime.originals = originals
        runtime.stop()
        self.assertEqual(events, list(range(5)))
        self.assertEqual(runtime.stop_order, list(lab.ROLES))
        for item in originals:
            item.request_stop.assert_not_called()

    def test_native_stop_is_one_attempt_even_after_all_originals_exit_zero(self):
        runtime = lab.Native(mock.Mock(), Path("fixture"), {})
        runtime.originals = [mock.Mock(receipt=dict(exit_code=0, output_complete=True, forced=False), drains=[])
                             for _ in lab.ROLES]
        runtime.stop()
        with self.assertRaises(lab.Failure):
            runtime.stop()
        for item in runtime.originals:
            item.stop.assert_called_once_with()

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
            self.assertEqual(result["CGO_ENABLED"], "1")
            self.assertEqual(result["CC"], "gcc")
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
