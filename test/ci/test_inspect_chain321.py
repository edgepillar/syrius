"""In-memory archive and credential-boundary cases; no network or disk scratch."""

import io
import json
import stat
import unittest
import zipfile

from tool.ci import inspect_chain321 as inspect


def packed(value, name="manifest.json", mode=stat.S_IFREG):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as archive:
        info = zipfile.ZipInfo(name)
        info.external_attr = (mode | 0o600) << 16
        archive.writestr(info, json.dumps(value))
    return stream.getvalue()


def manifest():
    return dict(scope="hosted_chain321_lab", application_sha="a" * 40,
        node_sha=inspect.NODE_SHA, run_id="123", attempt="1", backend="native",
        node_tree=inspect.NODE_SOURCES["original"][1],
        success=False, checks=dict.fromkeys(inspect.CHECKS, False),
        error_codes=["COMMAND_FAILED"], commands=[dict(compiler_diagnostics=[dict(code="LOCKED_MODULE_CHANGED")])],
        compiler="go version go1.24.1 windows/amd64", private_profile="/fixture/private/profile")


class InspectionTests(unittest.TestCase):
    def test_upstream_pin_is_explicit_and_cannot_relabel_an_original_run(self):
        report = manifest()
        report["node_sha"] = inspect.UPSTREAM_NODE_SHA
        report["node_tree"] = inspect.NODE_SOURCES["upstream"][1]
        report["upstream_stop_regressions"] = dict(passed=True, tests=list(inspect.SHUTDOWN_TESTS), skips=0)
        result = inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)
        self.assertEqual(result["node_sha"], inspect.UPSTREAM_NODE_SHA)
        self.assertFalse(result["runtime_started"])
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)
        report["node_tree"] = inspect.NODE_SOURCES["original"][1]
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)

    def test_upstream_success_cannot_hide_missing_or_skipped_stop_regressions(self):
        report = manifest()
        report.update(node_sha=inspect.UPSTREAM_NODE_SHA, node_tree=inspect.NODE_SOURCES["upstream"][1], success=True)
        for regressions in (None, dict(passed=True, tests=list(inspect.SHUTDOWN_TESTS), skips=1)):
            report["upstream_stop_regressions"] = regressions
            with self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)

    def test_native_shutdown_order_is_finite_and_cannot_adopt_another_scope(self):
        report = manifest()
        report["native_shutdown_order"] = list(inspect.ROLES)
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["native_shutdown_order"], list(inspect.ROLES))
        self.assertFalse(result["runtime_started"])
        for value in (["rpc"], list(inspect.ROLES) * 2, ["private-path"]):
            report["native_shutdown_order"] = value
            with self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)

    def test_stack_probe_requires_explicit_diagnostic_scope_and_finite_frames(self):
        report = manifest()
        report["native_stack_diagnostic"] = True
        report["node_exits"] = [dict(exit_code=1, forced=True, output_complete=True,
            stack_probe=dict(status="CAPTURED", bytes=100, sha256="b" * 64,
                             frames=["HTTP_SERVER_SHUTDOWN", "NODE_STOP"]))]
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["node_exits"][0]["stack_probe"]["frames"], ["HTTP_SERVER_SHUTDOWN", "NODE_STOP"])
        self.assertFalse(result["runtime_started"])
        report["native_stack_diagnostic"] = False
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)
        report["native_stack_diagnostic"] = True
        report["node_exits"][0]["stack_probe"]["frames"] = ["private-frame"]
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_native_log_projection_keeps_status_and_finite_stages_only(self):
        report = manifest()
        report["node_exits"] = [dict(exit_code=1, output_complete=True, forced=True,
            node_diagnostics=["NODE_P2P_STOP_REQUESTED"],
            private_log_projection=dict(status="READ", files=[dict(private="fixture")], raw="private"))]
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["node_exits"][0]["node_log_status"], "READ")
        self.assertNotIn("private", json.dumps(result))
        report["node_exits"][0]["private_log_projection"]["status"] = "/fixture/private/path"
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_backend_selection_is_explicit_and_cannot_name_another_target(self):
        self.assertEqual(inspect.selected_backends("both"), ("docker", "native"))
        self.assertEqual(inspect.selected_backends("native"), ("native",))
        self.assertEqual(inspect.selected_backends("docker"), ("docker",))
        with self.assertRaises(inspect.Refused):
            inspect.selected_backends("https://example.invalid")

    def test_positive_momentum_observations_require_real_progress_fields(self):
        report = manifest()
        report["checks"]["production"] = True
        report["observations"] = dict(chain=321, genesis_hash="b" * 64, first_height=1,
            last_height=3, first_timestamp=1, last_timestamp=30, samples=2, cross_transport_hash_equal=True)
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["observations"]["last_height"], 3)
        self.assertFalse(result["runtime_started"])
        report["observations"]["last_height"] = 1
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_artifact_request_never_receives_the_api_token(self):
        api = inspect.request_for(inspect.API + "/actions/runs/123", "fixture-token")
        blob = inspect.request_for("https://fixture.blob.core.windows.net/data?sig=fixture")
        self.assertEqual(api.get_header("Authorization"), "Bearer fixture-token")
        self.assertIsNone(blob.get_header("Authorization"))

    def test_redirect_rejects_plaintext_userinfo_and_lookalike_hosts(self):
        for url in ("http://fixture.blob.core.windows.net/data",
                    "https://user@fixture.blob.core.windows.net/data",
                    "https://fixture.blob.core.windows.net.example.invalid/data",
                    "https://fixture.blob.core.windows.net/data#fragment"):
            with self.subTest(url=url), self.assertRaises(inspect.Refused):
                inspect.artifact_location(url)

    def test_api_credential_cannot_be_sent_to_another_repository(self):
        with self.assertRaises(inspect.Refused):
            inspect.request_for("https://api.github.com/repos/other/project/actions/runs/123", "fixture-token")

    def test_manifest_hash_size_and_crc_are_checked_in_memory(self):
        data = packed(manifest())
        value, digest = inspect.unpack(data, inspect.sha(data), len(data))
        self.assertEqual(value, manifest())
        self.assertEqual(len(digest), 64)
        with self.assertRaises(inspect.Refused):
            inspect.unpack(data, "b" * 64, len(data))
        with self.assertRaises(inspect.Refused):
            inspect.unpack(data, inspect.sha(data), len(data) + 1)
        changed = bytearray(data)
        offset = changed.index(b'{"scope":')
        changed[offset + 2] ^= 1
        changed = bytes(changed)
        with self.assertRaises(zipfile.BadZipFile):
            inspect.unpack(changed, inspect.sha(changed), len(changed))

    def test_traversal_and_symbolic_links_are_refused(self):
        for name, mode in (("../manifest.json", stat.S_IFREG),
                           ("manifest.json", stat.S_IFLNK)):
            data = packed(manifest(), name, mode)
            with self.assertRaises(inspect.Refused):
                inspect.unpack(data, inspect.sha(data), len(data))

    def test_extra_members_and_oversized_manifest_are_refused(self):
        stream = io.BytesIO(packed(manifest()))
        with zipfile.ZipFile(stream, "a") as archive:
            archive.writestr("extra.json", "{}")
        data = stream.getvalue()
        with self.assertRaises(inspect.Refused):
            inspect.unpack(data, inspect.sha(data), len(data))
        data = packed(dict(value="x" * inspect.MAX_MANIFEST))
        with self.assertRaises(inspect.Refused):
            inspect.unpack(data, inspect.sha(data), len(data))

    def test_projection_omits_private_fields_and_cannot_admit_runtime(self):
        summary = inspect.project(manifest(), "native", "a" * 40, 123)
        self.assertNotIn("private", json.dumps(summary))
        self.assertIs(summary["inspection_only"], True)
        self.assertIs(summary["runtime_started"], False)
        self.assertIs(summary["seed_admitted"], False)
        self.assertEqual(summary["compiler_diagnostics"], [dict(code="LOCKED_MODULE_CHANGED")])

    def test_wrong_source_backend_or_node_is_refused(self):
        for field, value in (("application_sha", "b" * 40),
                             ("backend", "docker"), ("node_sha", "c" * 40)):
            report = manifest()
            report[field] = value
            with self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)

    def test_runtime_projection_keeps_terminal_facts_without_original_streams(self):
        report = manifest()
        report.update(runtime_phase="http_genesis", error_codes=["HTTP_REFUSED"],
            node_exits=[dict(exit_code=1, forced=False, output_complete=True,
                stop_code="SIGNAL_OS_ERROR", stop_os_error=6, node_diagnostics=["NODE_PANIC"],
                private_profile="/fixture/private/profile", streams=dict(private="fixture"))])
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["runtime_phase"], "http_genesis")
        self.assertEqual(result["node_exits"][0]["stop_os_error"], 6)
        self.assertNotIn("private", json.dumps(result))
        self.assertFalse(result["runtime_started"])

    def test_arbitrary_runtime_strings_and_boolean_exit_codes_are_refused(self):
        for change in (dict(runtime_phase="/fixture/private/profile"),
                       dict(node_diagnostics=["/fixture/private/value"]),
                       dict(created_count=True),
                       dict(node_exits=[dict(exit_code=True)])):
            report = manifest()
            report.update(change)
            with self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)

    def test_repeated_health_events_fit_one_notice_and_keep_original_failure(self):
        report = manifest()
        report["backend"] = "docker"
        report["compiler"] = "go version go1.24.1 linux/amd64"
        states = [dict(phase="health", role=role, running=True, exit_code=0, oom_killed=False)
                  for _ in range(36) for role in inspect.ROLES]
        failed = dict(phase="health", role="pillar", running=False, exit_code=1, oom_killed=False)
        states.insert(5, failed)
        states.extend(dict(phase="after_stop", role=role, running=False, exit_code=0, oom_killed=False)
                      for role in inspect.ROLES)
        report["docker_states"] = states
        result = inspect.project(report, "docker", "a" * 40, 123)
        self.assertEqual(len(result["docker_states"]), 5)
        self.assertEqual(result["docker_state_counts"], dict(health=181, after_stop=5))
        self.assertEqual(result["first_unhealthy_docker_state"], failed)
        result.update(archive_sha256="a" * 64, manifest_sha256="b" * 64)
        self.assertLess(len(json.dumps(result, separators=(",", ":")).encode()), 3800)

    def test_relay_projection_is_finite_data_and_never_an_owner(self):
        report = manifest()
        report.update(backend="docker", compiler="go version go1.24.1 linux/amd64",
            direct_rpc_ready=True, loopback_relay=dict(started=True, closed=True,
            listeners=2, accepted=3, completed=3, bytes=12, active=0, workers_alive=0))
        result = inspect.project(report, "docker", "a" * 40, 123)
        self.assertTrue(result["loopback_relay"]["closed"])
        self.assertFalse(result["runtime_started"])
        report["loopback_relay"]["private_profile"] = "/fixture/private/profile"
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "docker", "a" * 40, 123)


if __name__ == "__main__":
    unittest.main()
