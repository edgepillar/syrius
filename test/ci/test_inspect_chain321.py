"""In-memory archive and credential-boundary cases; no network or disk scratch."""

import io
import copy
import json
import stat
import unittest
import zipfile

from tool.ci import inspect_chain321 as inspect
from tool.ci import producer_shutdown_patch as producer_patch
from tool.ci import read_first_client_fixture as client_fixture


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
    @staticmethod
    def wallet_stop_report():
        report = InspectionTests.corrected_manifest()
        report.update(run_id="40319698922", wallet_tour_requested=True, native_stack_diagnostic=True,
            native_stack_scope="all_originals", native_shutdown_order=list(inspect.ROLES),
            native_shutdown_mode="coordinated_requests_then_wait", runtime_phase="advancing_frontier",
            c_compiler=dict(target="x86_64-w64-mingw32", version="15.2.0", cgo_enabled=True),
            observations=dict(chain=321, genesis_hash="d"*64, first_height=1, last_height=2,
                first_timestamp=1739923200, last_timestamp=1792957080, samples=11,
                cross_transport_hash_equal=True), error_codes=["WALLET_TOUR_FAILED", "STOP_UNKNOWN"])
        report["checks"].update(assets=True, preflight=True, started=True, production=True)
        fixture = client_fixture.pending()
        fixture.update(phase="restored", all_seven_test_bodies_unchanged=True,
            original_restored=True, test_exit=0, test_output_complete=True, test_forced=False)
        report["upstream_client_fixture"] = fixture
        codes = ["NODE_DATA_LOCK_RELEASE_REQUESTED", "NODE_P2P_STOP_REQUESTED",
                 "NODE_SIGNAL_RECEIVED", "NODE_STOP_REQUESTED"]
        report["node_exits"] = [dict(exit_code=0, output_complete=True, forced=False,
            stack_role=role, node_diagnostics=list(codes), private_log_projection=dict(status="READ"))
            for role in inspect.ROLES]
        report["node_exits"][-1]["node_diagnostics"].append("NODE_HTTP_STOPPED")
        report["node_exits"][1].update(exit_code=1, forced=True, stop_code="WAIT_TIMEOUT",
            stack_probe=dict(status="CAPTURED", bytes=123456, sha256="b"*64,
                frames=["WAIT_GROUP", "PROTOCOL_STOP", "NODE_STOP"],
                protocol_workers=dict(status="CAPTURED", count=4,
                    items=[dict(kind="SYNCER", state="CHAN_RECEIVE", package="protocol/downloader",
                        source_path_sha256="c"*64, line=line) for line in range(100,104)])))
        return report

    def test_wallet_stop_notice_keeps_source_client_workers_and_all_original_exits(self):
        report = self.wallet_stop_report()
        value = inspect.project(report, "native", "a"*40, 40319698922,
            inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        value.update(archive_sha256="e"*64, manifest_sha256="f"*64)
        self.assertLessEqual(len(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()),3800)
        self.assertEqual(value["error_codes"], ["WALLET_TOUR_FAILED", "STOP_UNKNOWN"])
        self.assertFalse(value["artifact_reported_success"])
        self.assertEqual(len(value["node_exits"]),5)
        for original, selected in zip(report["node_exits"], value["node_exits"]):
            self.assertEqual([value["node_diagnostics_catalog"][index]
                              for index in selected["diagnostic_indices"]],original["node_diagnostics"])
            for key in ("exit_code", "output_complete", "forced", "stack_role"):
                self.assertEqual(selected[key],original[key])
        self.assertEqual(len(value["node_diagnostics_catalog"]),5)
        self.assertTrue(value["upstream_client_fixture"]["original_restored"])
        self.assertEqual(value["native_stack_probe"]["role"],"pillar2")
        self.assertEqual(value["native_stack_probe"]["protocol_workers"]["count"],4)
        self.assertEqual(len(value["native_stack_probe"]["protocol_workers"]["items"]),2)

    def test_shared_stop_milestones_still_reject_a_private_category_in_any_original(self):
        report = self.wallet_stop_report()
        report["node_exits"][-1]["node_diagnostics"].append("/fixture/private")
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a"*40, 40319698922,
                inspect.UPSTREAM_NODE_SHA, expected_patched=True)

    def test_wallet_client_fixture_must_restore_before_assets_can_be_admitted(self):
        report = self.corrected_manifest()
        report['wallet_tour_requested'] = True
        report['checks']['assets'] = True
        value = client_fixture.pending()
        value.update(phase='restored', all_seven_test_bodies_unchanged=True,
            original_restored=True, test_exit=0, test_output_complete=True, test_forced=False)
        report['upstream_client_fixture'] = value
        projected = inspect.project(report, 'native', 'a'*40, 123,
            inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        self.assertTrue(projected['upstream_client_fixture']['original_restored'])
        value.update(phase='held', original_restored=False)
        with self.assertRaises(inspect.Refused):
            inspect.project(report, 'native', 'a'*40, 123,
                inspect.UPSTREAM_NODE_SHA, expected_patched=True)

    def test_docker_stop_receipt_preserves_original_command_failure(self):
        report = manifest()
        report.update(backend="docker", compiler="go version go1.24.1 linux/amd64",
            docker_shutdown=dict(mode="single_verified_stop_command", roles=list(reversed(inspect.ROLES)),
                exit_code=1, output_complete=True, forced=False))
        value = inspect.project(report, "docker", "a" * 40, 123)
        self.assertEqual(value["docker_shutdown"]["exit_code"], 1)
        report["checks"]["stopped"] = True
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "docker", "a" * 40, 123)

    def test_docker_stop_receipt_rejects_unknown_roles_raw_fields_and_false_success(self):
        for change in (dict(roles=["private"]), dict(raw="private"), dict(exit_code=True),
                       dict(roles=["rpc", "rpc"]), dict(mode="private")):
            report = manifest()
            report.update(backend="docker", compiler="go version go1.24.1 linux/amd64",
                docker_shutdown=dict(mode="single_verified_stop_command", roles=list(reversed(inspect.ROLES)),
                    exit_code=0, output_complete=True, forced=False))
            report["docker_shutdown"].update(change)
            with self.subTest(change=change), self.assertRaises(inspect.Refused):
                inspect.project(report, "docker", "a" * 40, 123)

    @staticmethod
    def worker_probe_report():
        report = manifest()
        report.update(native_stack_diagnostic=True, native_stack_scope="all_originals",
            node_exits=[dict(exit_code=1, output_complete=True, forced=True, stop_code="WAIT_TIMEOUT",
                stack_role="pillar", stack_probe=dict(status="CAPTURED", bytes=100, sha256="b" * 64,
                    frames=["WAIT_GROUP", "PROTOCOL_STOP", "NODE_STOP"],
                    protocol_workers=dict(status="CAPTURED", count=4, items=[dict(kind="SYNCER", state="CHAN_RECEIVE",
                        package="protocol/downloader", source_path_sha256="c" * 64, line=line) for line in range(1, 5)])))])
        return report

    def test_all_worker_sites_are_validated_but_only_two_fit_the_finite_notice(self):
        report = self.worker_probe_report()
        value = inspect.project(report, "native", "a" * 40, 123)
        workers = value["native_stack_probe"]["protocol_workers"]
        self.assertEqual(workers["count"], 4)
        self.assertEqual(len(workers["items"]), 2)
        self.assertEqual(len(report["node_exits"][0]["stack_probe"]["protocol_workers"]["items"]), 4)
        self.assertTrue(value["node_exits"][0]["forced"])
        self.assertLessEqual(len(json.dumps(value, separators=(",", ":")).encode()), 3800)

    def test_worker_projection_rejects_raw_fields_unknown_codes_and_boolean_facts(self):
        for change in (dict(raw="private"), dict(kind="private"), dict(state="private"),
                       dict(package="private"), dict(source_path_sha256="private"), dict(line=True)):
            report = self.worker_probe_report()
            report["node_exits"][0]["stack_probe"]["protocol_workers"]["items"][-1].update(change)
            with self.subTest(change=change), self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)
        report = self.worker_probe_report()
        report["node_exits"][0]["stack_probe"]["protocol_workers"]["count"] = True
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_five_failed_probes_keep_every_original_exit_and_one_bounded_detail(self):
        report = self.corrected_manifest()
        report.update(native_stack_diagnostic=True, native_stack_scope="all_originals",
            node_exits=[dict(exit_code=1, output_complete=True, forced=True, stop_code="WAIT_TIMEOUT",
                stack_role=role, stack_probe=dict(status="CAPTURED", bytes=100, sha256="b" * 64,
                    frames=sorted(inspect.native_stack_probe.CODES))) for role in inspect.ROLES])
        value = inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        self.assertEqual(value["native_stack_probe_count"], 5)
        self.assertEqual(value["native_stack_probe"]["role"], "pillar")
        self.assertTrue(all(item["forced"] and item["stack_probe_status"] == "CAPTURED" for item in value["node_exits"]))
        self.assertLessEqual(len(json.dumps(value, separators=(",", ":")).encode()), 3800)

    def test_all_originals_probe_scope_keeps_the_original_role_and_failed_exit(self):
        report = manifest()
        report.update(native_stack_diagnostic=True, native_stack_scope="all_originals",
            node_exits=[dict(exit_code=1, output_complete=True, forced=True, stop_code="WAIT_TIMEOUT",
                stack_role="pillar", stack_probe=dict(status="CAPTURED", bytes=100, sha256="b" * 64,
                    frames=["PILLAR_WORKER_STOP", "NODE_STOP"]))])
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["native_stack_scope"], "all_originals")
        self.assertEqual(result["node_exits"][0]["stack_role"], "pillar")
        self.assertTrue(result["node_exits"][0]["forced"])
        report["node_exits"][0]["stack_role"] = "rpc"
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_probe_scope_cannot_adopt_an_unknown_role_or_disabled_diagnostic(self):
        for enabled, scope, role in ((False, "all_originals", "pillar"),
                                    (True, "private", "pillar"), (True, "all_originals", "private"),
                                    (True, None, "pillar")):
            report = manifest()
            report.update(native_stack_diagnostic=enabled, native_stack_scope=scope,
                node_exits=[dict(exit_code=1, output_complete=True, forced=True, stack_role=role)])
            with self.subTest(scope=scope, role=role), self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)

    def test_go_failure_observation_does_not_qualify_a_runtime_or_test_pass(self):
        report = manifest()
        report.update(node_sha=inspect.UPSTREAM_NODE_SHA, node_tree=producer_patch.BASE_TREE,
            upstream_stop_failure=dict(status="COMPLETE", exit_code=1, output_complete=True, forced=False,
                passed=[], failed=[inspect.SHUTDOWN_TESTS[0]], skipped=[], active=[], locations=[123],
                codes=["GO_TEST_ASSERTION"]))
        value = inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)
        self.assertEqual(value["upstream_stop_failure"]["exit_code"], 1)
        self.assertFalse(value["runtime_started"])
        self.assertIsNone(value["upstream_stop_regressions"])
        report["upstream_stop_failure"]["failed"] = ["private"]
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)

    def test_go_failure_projection_rejects_raw_fields_and_contradictory_success(self):
        report = manifest()
        report.update(node_sha=inspect.UPSTREAM_NODE_SHA, node_tree=producer_patch.BASE_TREE,
            upstream_stop_failure=dict(status="COMPLETE", exit_code=1, output_complete=True, forced=False,
                passed=[], failed=[], skipped=[], active=[], locations=[], codes=["GO_TEST_UNCLASSIFIED"]))
        for change in (dict(raw="private"), dict(exit_code=True), dict(locations=[True]),
                       dict(codes=["private"]), dict(output_complete=False)):
            changed = copy.deepcopy(report)
            changed["upstream_stop_failure"].update(change)
            with self.subTest(change=change), self.assertRaises(inspect.Refused):
                inspect.project(changed, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)
        report["checks"]["started"] = True
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)

    @staticmethod
    def corrected_manifest():
        report = manifest()
        report.update(node_source="lab-fix", node_sha=inspect.UPSTREAM_NODE_SHA,
            node_tree=producer_patch.BASE_TREE, compiled_node_tree=producer_patch.COMPILED_TREE,
            producer_task_patch=dict(producer_patch.pending(), phase="verified",
                compiled_tree=producer_patch.COMPILED_TREE, unpatched_exit=1, patched_exit=0,
                unpatched_expected_panic=True, patched_test_passed=True),
            upstream_stop_regressions=dict(passed=True, tests=list(inspect.SHUTDOWN_TESTS), skips=0))
        report["checks"].update(source=True, build=True)
        return report

    def test_corrected_node_requires_explicit_inspection_and_stays_separate(self):
        report = self.corrected_manifest()
        result = inspect.project(report, "native", "a" * 40, 123,
            inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        self.assertEqual(result["node_source"], "lab-fix")
        self.assertEqual(result["compiled_node_tree"], producer_patch.COMPILED_TREE)
        self.assertEqual(result["producer_task_patch"]["unpatched_exit"], 1)
        self.assertEqual(result["producer_task_patch"]["patched_exit"], 0)
        self.assertEqual(result["upstream_stop_regressions"], dict(passed=True, count=7, skips=0))
        self.assertFalse(result["runtime_started"])
        self.assertFalse(result["seed_admitted"])
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)

    def test_plain_upstream_cannot_be_relabelled_as_corrected(self):
        report = manifest()
        report.update(node_source="upstream", node_sha=inspect.UPSTREAM_NODE_SHA,
            node_tree=producer_patch.BASE_TREE)
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123,
                inspect.UPSTREAM_NODE_SHA, expected_patched=True)

    def test_corrected_build_cannot_hide_a_missing_or_changed_regression_proof(self):
        for change in (dict(producer_task_patch=None), dict(compiled_node_tree="a" * 40),
                       dict(node_source="upstream"), dict(producer_task_patch=producer_patch.pending())):
            report = dict(self.corrected_manifest(), **change)
            with self.subTest(change=change), self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123,
                    inspect.UPSTREAM_NODE_SHA, expected_patched=True)

    def test_early_correction_failure_is_observable_without_build_or_runtime_admission(self):
        report = self.corrected_manifest()
        report["checks"]["build"] = False
        report.update(producer_task_patch=producer_patch.pending(), compiled_node_tree=None,
                      upstream_stop_regressions=None, error_codes=["NODE_REGRESSIONS_REFUSED"])
        result = inspect.project(report, "native", "a" * 40, 123,
            inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        self.assertEqual(result["producer_task_patch"]["phase"], "fixture")
        self.assertIsNone(result["compiled_node_tree"])
        self.assertFalse(result["artifact_reported_success"])
        self.assertFalse(result["runtime_started"])

    def test_corrected_panic_notice_keeps_provenance_and_all_failures_in_its_cap(self):
        report = self.corrected_manifest()
        report["checks"]["production"] = True
        report.update(native_shutdown_mode="coordinated_requests_then_wait",
            native_shutdown_order=list(inspect.ROLES),
            observations=dict(chain=321, genesis_hash="b" * 64, first_height=1,
                last_height=2, first_timestamp=1, last_timestamp=30, samples=2,
                cross_transport_hash_equal=True),
            c_compiler=dict(target="x86_64-w64-mingw32", version="15.2.0", cgo_enabled=True))
        report["node_exits"] = [dict(exit_code=2, output_complete=True, forced=False,
            node_diagnostics=["NODE_SIGNAL_RECEIVED", "NODE_STOP_REQUESTED", "NODE_P2P_STOP_REQUESTED", "NODE_PANIC"],
            private_log_projection=dict(status="READ"), node_panic=dict(status="CAPTURED", kind="NIL_POINTER",
            bytes=10000, sha256="a" * 64, frames=[dict(package="pillar", source_path_sha256="b" * 64,
            line=120+i) for i in range(3)])) for _ in inspect.ROLES]
        result = inspect.project(report, "native", "a" * 40, 123,
            inspect.UPSTREAM_NODE_SHA, expected_patched=True)
        result.update(archive_sha256="a" * 64, manifest_sha256="b" * 64)
        self.assertEqual(result["node_panic_count"], 5)
        self.assertEqual(len(result["node_exits"]), 5)
        self.assertLess(len(json.dumps(result, separators=(",", ":")).encode()), 3800)

    def test_all_panic_facts_are_validated_but_only_the_first_detail_is_projected(self):
        report = manifest()
        panic = dict(status="CAPTURED", kind="NIL_POINTER", bytes=200, sha256="a" * 64,
            frames=[dict(package="wallet", source_path_sha256="b" * 64, line=257)])
        report["node_exits"] = [dict(exit_code=2, output_complete=True, forced=False,
            node_diagnostics=["NODE_PANIC"], node_panic=copy.deepcopy(panic)) for _ in inspect.ROLES]
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["node_panic_count"], 5)
        self.assertEqual(result["first_node_panic"], dict(role="pillar", **panic))
        self.assertFalse(result["artifact_reported_success"])
        self.assertFalse(result["runtime_started"])
        report["node_exits"][-1]["node_panic"]["frames"][0]["package"] = "private"
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

    def test_panic_details_reject_raw_text_paths_boolean_lines_and_unknown_fields(self):
        report = manifest()
        panic = dict(status="CAPTURED", kind="OTHER", bytes=200, sha256="a" * 64,
            frames=[dict(package="wallet", source_path_sha256="b" * 64, line=257)])
        invalid = [dict(kind="private"), dict(status="private"), dict(raw="private"),
            dict(sha256="private"), dict(frames=[dict(package="wallet", source_path_sha256="b" * 64, line=True)]),
            dict(frames=[dict(package="wallet", source_path_sha256="private/path", line=257)])]
        for change in invalid:
            report["node_exits"] = [dict(exit_code=2, node_panic=dict(panic, **change))]
            with self.subTest(change=change), self.assertRaises(inspect.Refused):
                inspect.project(report, "native", "a" * 40, 123)

    def test_five_panics_keep_a_single_complete_notice_with_three_location_hashes(self):
        report = manifest()
        report.update(node_sha=inspect.UPSTREAM_NODE_SHA, node_tree=inspect.NODE_SOURCES["upstream"][1],
            upstream_stop_regressions=dict(passed=True, tests=list(inspect.SHUTDOWN_TESTS), skips=0),
            native_shutdown_order=list(inspect.ROLES), native_shutdown_mode="coordinated_requests_then_wait")
        report["node_exits"] = [dict(exit_code=2, output_complete=True, forced=False,
            node_diagnostics=["NODE_SIGNAL_RECEIVED", "NODE_STOP_REQUESTED", "NODE_P2P_STOP_REQUESTED", "NODE_PANIC"],
            private_log_projection=dict(status="READ"),
            node_panic=dict(status="CAPTURED", kind="NIL_POINTER", bytes=100000, sha256="a" * 64,
            frames=[dict(package="wallet", source_path_sha256="b" * 64, line=257+i) for i in range(3)]))
            for _ in inspect.ROLES]
        result = inspect.project(report, "native", "a" * 40, 123, inspect.UPSTREAM_NODE_SHA)
        result.update(archive_sha256="a" * 64, manifest_sha256="b" * 64)
        self.assertLess(len(json.dumps(result, separators=(",", ":")).encode()), 3800)

    def test_coordinated_shutdown_mode_is_fixed_finite_observation(self):
        report = manifest()
        report["native_shutdown_mode"] = "coordinated_requests_then_wait"
        result = inspect.project(report, "native", "a" * 40, 123)
        self.assertEqual(result["native_shutdown_mode"], "coordinated_requests_then_wait")
        self.assertFalse(result["runtime_started"])
        report["native_shutdown_mode"] = "private-path"
        with self.assertRaises(inspect.Refused):
            inspect.project(report, "native", "a" * 40, 123)

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
