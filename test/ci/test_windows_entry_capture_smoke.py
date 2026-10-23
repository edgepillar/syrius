"""Finite fake-process/parser cases. No Windows, HTTP or wallet is executed."""

import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path, PureWindowsPath
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import zlib

CONTROLLER = Path(__file__).resolve().parents[2] / "tool/ci/windows_entry_capture_smoke.py"
SPEC = importlib.util.spec_from_file_location("windows_entry_capture_smoke", CONTROLLER)
smoke = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = smoke
sys.path.insert(0, str(CONTROLLER.parent))
try:
    SPEC.loader.exec_module(smoke)
finally:
    sys.path.pop(0)

SOURCE, TREE = "1" * 40, "2" * 40
TOKEN = "private-original-entry-test-token"
LIMITS = smoke.bounded.Limits(total=10, ready=.3, request=.2, poll=.1,
                              exit=.2, cleanup=.2, drain=.1,
                              response_bytes=smoke.LIMITS.response_bytes)


def chunk(kind, payload):
    return (struct.pack(">I", len(payload)) + kind + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


HEADER = struct.pack(">IIBBBBB", 1280, 780, 8, 6, 0, 0, 0)
PIXELS = (b"\0" + bytes(1280 * 4)) * 780
PNG = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", HEADER)
       + chunk(b"IDAT", zlib.compress(PIXELS)) + chunk(b"IEND", b""))
ENCODED = base64.b64encode(PNG).decode("ascii")


def reply(body, status=200):
    return smoke.bounded.Reply(status, json.dumps(body).encode())


def capture_reply(screen="welcome", theme="dark"):
    return {"ok": True, "screen": screen, "theme": theme, "width": 1280,
            "height": 780, "scale": 1, "client": [1280, 780],
            "physical": [1920, 1170], "devicePixelRatio": 1.5, "png": ENCODED,
            "harnessMode": "wallet", "captureMode": "entry", "restorationVerified": True}


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def sleep(self, duration):
        self.now += duration


class OriginalProcess:
    def __init__(self):
        self.pid = 4141
        self.returncode = None
        self.close_requested = False
        self.can_close = True
        self.close_exit = 0
        self.kill_count = 0
        self.kill_error = None
        self.waits = []

    def poll(self):
        return self.returncode

    def wait(self, timeout):
        self.waits.append(timeout)
        if self.returncode is None:
            if self.close_requested and self.can_close:
                self.returncode = self.close_exit
            else:
                raise subprocess.TimeoutExpired("original-process", timeout)
        return self.returncode

    def kill(self):
        self.kill_count += 1
        if self.kill_error:
            raise self.kill_error
        self.returncode = 1


class Drain:
    def __init__(self):
        self.overflow = threading.Event()
        self.error = None
        self.count = 73
        self.complete = True
        self.overflow_on_finish = False

    def finish(self, timeout):
        if self.overflow_on_finish:
            self.overflow.set()
        return self.complete


class Artifacts:
    def __init__(self):
        self.records = []
        self.writes = {}

    def png(self, name, data):
        if name in self.writes:
            raise AssertionError("duplicate artifact")
        self.writes[name] = data
        self.records.append({"file": name, "bytes": len(data),
                             "sha256": hashlib.sha256(data).hexdigest()})


class Host:
    def __init__(self, process):
        self.process = process
        self.calls = []
        self.hook = None
        self.booted = self.entry_ready = True
        self.held = False
        self.pid = process.pid
        self.mode = "wallet"
        self.captures = 0
        self.window = [17, 23, 1240, 850]
        self.client = [1224, 811]
        self.original_window = self.snapshot()

    def snapshot(self):
        return {"window": list(self.window), "client": list(self.client),
                "physical": list(self.client), "devicePixelRatio": 1,
                "minimized": False, "maximized": False}

    def entry(self):
        return {"ok": True, "available": True, "nativeWindowReady": self.entry_ready,
                "startupReady": self.entry_ready, "welcomeReady": self.entry_ready,
                "held": self.held, "captures": self.captures}

    def exchange(self, command, token, timeout):
        self.calls.append((copy.deepcopy(command), token, timeout))
        if self.hook:
            override = self.hook(command, token)
            if override is not None:
                return override
        if token != TOKEN:
            return reply({"ok": False, "error": "bad token"}, 400)
        name = command["cmd"]
        if name == "ping":
            return reply({"ok": True, "pid": self.pid, "booted": self.booted,
                          "harnessMode": self.mode})
        if name == "entry-state":
            return reply(self.entry())
        if name == "window":
            extra = {}
            if "restoreState" in command:
                original = command["restoreState"]
                self.window, self.client = original["window"], original["client"]
                extra["restored"] = True
            elif command.get("do") == "show":
                self.window, self.client = [17, 23, 1296, 819], [1280, 780]
                extra["clientMatched"] = True
            return reply({"ok": True, **self.snapshot(), **extra})
        if name == "entry-capture":
            if set(command) != {"cmd", "screen", "theme"}:
                raise AssertionError("unexpected capture keys")
            self.captures += 1
            return reply(capture_reply(command["screen"], command["theme"]))
        if name == "entry-check":
            return reply({**self.entry(), "frameReady": True, "restorationVerified": True})
        if name == "quit":
            self.process.close_requested = True
            return reply({"ok": True})
        raise AssertionError("unexpected command")


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.clock, self.process = Clock(), OriginalProcess()
        self.host = Host(self.process)
        self.drain, self.artifacts, self.report = Drain(), Artifacts(), smoke.Report()
        self.report.source_sha, self.report.source_tree = SOURCE, TREE
        self.report.run_id, self.report.run_attempt = "4001", "2"
        self.report.runner_sha256, self.report.dart_kernel_sha256 = "3" * 64, "4" * 64
        for name in ("environment", "source", "profile", "preflight", "payload_stable"):
            self.report.checks[name] = True

    def run_smoke(self):
        return smoke.EntrySmoke(self.process, self.host, TOKEN, self.drain, self.report,
                                artifacts=self.artifacts, limits=LIMITS,
                                clock=self.clock, sleep=self.clock.sleep).run()

    def commands(self, name=None):
        return [command for command, _, _ in self.host.calls
                if name is None or command["cmd"] == name]

    def test_four_actual_byte_artifacts_outer_restore_then_original_zero_exit(self):
        result = self.run_smoke()
        self.assertTrue(result["success"])
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(tuple(self.artifacts.writes), smoke.FILES)
        self.assertEqual([command for command in self.commands("entry-capture")], [
            {"cmd": "entry-capture", "screen": screen, "theme": theme}
            for screen, theme in smoke.SCENES])
        self.assertEqual(self.commands()[-3:][0]["restoreState"], self.host.original_window)
        self.assertEqual([item["cmd"] for item in self.commands()[-3:]],
                         ["window", "entry-check", "quit"])
        self.assertEqual(result["capture_count"], 4)
        self.assertEqual(result["exit_code"], 0)
        self.assertTrue(result["output_complete"])
        self.assertEqual(self.process.kill_count, 0)
        self.assertTrue(all(0 < timeout <= LIMITS.request for _, _, timeout in self.host.calls))

    def test_original_identity_or_mode_failure_never_changes_a_window(self):
        for field, value, code in (("pid", 9191, "IDENTITY_REFUSED"),
                                   ("mode", "presentation", "MODE_REFUSED")):
            with self.subTest(field=field):
                self.setUp()
                setattr(self.host, field, value)
                result = self.run_smoke()
                self.assertIn(code, result["error_codes"])
                self.assertEqual(self.commands(), [{"cmd": "ping"}])
                self.assertEqual(self.process.kill_count, 1)

    def test_booted_is_not_positive_native_startup_evidence(self):
        self.host.entry_ready = False
        result = self.run_smoke()
        self.assertIn("READINESS_TIMEOUT", result["error_codes"])
        self.assertTrue(result["checks"]["identity"])
        self.assertFalse(result["checks"]["entry_ready"])
        self.assertFalse(self.commands("window"))
        self.assertLessEqual(len(self.commands("entry-state")), 4)
        self.assertEqual(len(self.commands("quit")), 1)

    def test_pending_ping_is_read_only_and_has_a_finite_deadline(self):
        self.host.booted = False
        result = self.run_smoke()
        self.assertIn("READINESS_TIMEOUT", result["error_codes"])
        self.assertLessEqual(len(self.commands()), 4)
        self.assertEqual({item["cmd"] for item in self.commands()}, {"ping"})

    def test_first_connection_refusal_only_polls_readiness(self):
        pending = [True]
        def first(command, token):
            if pending:
                pending.pop()
                raise ConnectionRefusedError()
        self.host.hook = first
        self.assertTrue(self.run_smoke()["success"])
        self.assertEqual(self.clock.now, LIMITS.poll)

    def test_held_or_unavailable_entry_does_not_retry_startup(self):
        for field, value, code in (("held", True, "ENTRY_HELD"),
                                   ("available", False, "ENTRY_UNAVAILABLE")):
            with self.subTest(field=field):
                self.setUp()
                self.host.hook = lambda command, token: reply({**self.host.entry(), field: value}) \
                    if command["cmd"] == "entry-state" else None
                result = self.run_smoke()
                self.assertIn(code, result["error_codes"])
                self.assertEqual(len(self.commands("entry-state")), 1)
                self.assertFalse(self.commands("entry-capture"))

    def test_forged_negative_auth_is_rejected_before_window_or_capture(self):
        self.host.hook = lambda command, token: reply({"ok": True}) if token != TOKEN else None
        result = self.run_smoke()
        self.assertIn("AUTH_REFUSAL_INVALID", result["error_codes"])
        self.assertFalse(self.commands("window"))
        self.assertFalse(self.commands("quit"))

    def test_invalid_json_or_duplicate_keys_are_not_readiness_retries(self):
        for body in (b"[]", b"not-json", b'{"ok":true,"ok":false}', b'{"ok":true,"n":NaN}'):
            with self.subTest(body=body):
                self.setUp()
                self.host.hook = lambda command, token: smoke.bounded.Reply(200, body)
                result = self.run_smoke()
                self.assertIn("RESPONSE_INVALID", result["error_codes"])
                self.assertEqual(self.commands(), [{"cmd": "ping"}])

    def test_client_match_claim_without_actual_client_dimensions_refuses(self):
        def outer_size_only(command, token):
            if command.get("do") == "show":
                return reply({"ok": True, **self.host.snapshot(), "clientMatched": True})
        self.host.hook = outer_size_only
        result = self.run_smoke()
        self.assertIn("WINDOW_INVALID", result["error_codes"])
        self.assertFalse(self.commands("entry-capture"))
        self.assertEqual(len([c for c in self.commands("window") if "restoreState" in c]), 1)

    def test_capture_refusal_preserves_prior_pngs_and_never_retries_capture(self):
        def refuse_second(command, token):
            if command["cmd"] == "entry-capture" and command["theme"] == "light":
                return reply({"ok": False, "error": TOKEN}, 400)
        self.host.hook = refuse_second
        result = self.run_smoke()
        self.assertFalse(result["success"])
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["capture_count"], 1)
        self.assertEqual(tuple(self.artifacts.writes), ("welcome-dark.png",))
        self.assertEqual(len(self.commands("entry-capture")), 2)
        self.assertEqual(len(self.commands("quit")), 1)

    def test_lost_capture_reply_is_unknown_even_if_original_exits_zero(self):
        def lost(command, token):
            if command["cmd"] == "entry-capture":
                raise TimeoutError(TOKEN)
        self.host.hook = lost
        result = self.run_smoke()
        self.assertIn("HTTP_FAILED", result["error_codes"])
        self.assertEqual(len(self.commands("entry-capture")), 1)
        self.assertEqual(result["exit_code"], 0)
        self.assertFalse(result["success"])

    def test_late_capture_cannot_extend_total_deadline_or_be_written(self):
        def late(command, token):
            if command["cmd"] == "entry-capture":
                self.clock.now += LIMITS.total
        self.host.hook = late
        result = self.run_smoke()
        self.assertIn("TOTAL_DEADLINE", result["error_codes"])
        self.assertEqual(result["capture_count"], 0)
        self.assertEqual(len(self.commands("entry-capture")), 1)
        self.assertEqual(self.process.kill_count, 1)

    def test_window_restore_requires_observed_original_geometry(self):
        def wrong_restore(command, token):
            if "restoreState" in command:
                return reply({"ok": True, **self.host.snapshot(), "restored": True})
        self.host.hook = wrong_restore
        result = self.run_smoke()
        self.assertIn("WINDOW_RESTORE_FAILED", result["error_codes"])
        self.assertFalse(result["checks"]["window_restored"])
        self.assertFalse(self.commands("entry-check"))
        self.assertEqual(len(self.commands("quit")), 1)

    def test_fresh_frame_restoration_count_and_no_hold_are_all_required(self):
        for field, value in (("frameReady", False), ("restorationVerified", False),
                             ("captures", 3), ("held", True), ("startupReady", False)):
            with self.subTest(field=field):
                self.setUp()
                self.host.hook = lambda command, token: reply({
                    **self.host.entry(), "frameReady": True, "restorationVerified": True,
                    field: value}) if command["cmd"] == "entry-check" else None
                result = self.run_smoke()
                self.assertFalse(result["checks"]["entry_restored"])
                self.assertFalse(result["success"])
                self.assertEqual(len(self.commands("entry-check")), 1)

    def test_quit_ack_without_original_exit_cannot_succeed(self):
        unrelated = OriginalProcess()
        self.process.can_close = False
        result = self.run_smoke()
        self.assertIn("EXIT_TIMEOUT", result["error_codes"])
        self.assertTrue(result["forced_kill"])
        self.assertEqual(self.process.kill_count, 1)
        self.assertEqual(unrelated.kill_count, 0)
        self.assertEqual(len(self.commands("quit")), 1)

    def test_lost_quit_ack_and_nonzero_exit_are_failures(self):
        def lost_close(command, token):
            if command["cmd"] == "quit":
                self.process.close_requested = True
                raise TimeoutError(TOKEN)
        self.host.hook = lost_close
        result = self.run_smoke()
        self.assertIn("CLOSE_UNCERTAIN", result["error_codes"])
        self.assertEqual(result["exit_code"], 0)
        self.assertFalse(result["success"])
        self.setUp()
        self.process.close_exit = 7
        result = self.run_smoke()
        self.assertIn("EXIT_FAILED", result["error_codes"])
        self.assertEqual(result["exit_code"], 7)

    def test_overflow_incomplete_drain_and_failed_owned_cleanup_remain_failures(self):
        for fault, code in (("overflow", "OUTPUT_OVERFLOW"),
                            ("incomplete", "OUTPUT_INCOMPLETE"), ("kill", "CLEANUP_FAILED")):
            with self.subTest(fault=fault):
                self.setUp()
                if fault == "overflow":
                    self.drain.overflow_on_finish = True
                elif fault == "incomplete":
                    self.drain.complete = False
                else:
                    self.host.mode = "presentation"
                    self.process.kill_error = OSError(TOKEN)
                result = self.run_smoke()
                self.assertIn(code, result["error_codes"])
                self.assertFalse(result["success"])

    def test_manifest_projection_cannot_publish_private_originals_or_unknown_codes(self):
        def private_failure(command, token):
            raise RuntimeError(TOKEN + " private-profile-path processInstance=opaque-owner")
        self.host.hook = private_failure
        self.report.fail("private-profile-path", TOKEN)
        self.report.captures.append({"file": "private-profile-path", "sha256": "5" * 64, "bytes": 1})
        result = self.run_smoke()
        encoded = json.dumps(result)
        for private in (TOKEN, "private-profile-path", "processInstance", "opaque-owner",
                        str(self.process.pid), "restoreState", "traceback"):
            self.assertNotIn(private, encoded)
        self.assertTrue(set(result["error_codes"]) <= smoke.CODES)
        self.assertEqual(set(result), {"schema", "source_sha", "source_tree", "run_id",
                         "run_attempt", "runner_sha256", "dart_kernel_sha256", "checks",
                         "captures", "capture_count", "exit_code", "exit_observed", "forced_kill",
                         "output_bytes", "output_complete", "output_overflow", "complete", "success",
                         "status", "error_codes"})


class ParserTests(unittest.TestCase):
    def test_real_structured_png_and_logical_dimensions_are_admitted(self):
        self.assertEqual(smoke.png_bytes(ENCODED), PNG)
        self.assertEqual(smoke.capture_bytes(capture_reply(), "welcome", "dark"), PNG)

    def test_base64_must_be_strict_canonical_and_bounded(self):
        for encoded in ("", ENCODED + "\n", "????", ENCODED[:-1], 42):
            with self.subTest(encoded_type=type(encoded)):
                with self.assertRaises(smoke.Failure) as caught:
                    smoke.png_bytes(encoded)
                self.assertEqual(caught.exception.code, "PNG_INVALID")
        with patch.object(smoke, "MAX_BASE64", len(ENCODED) - 1):
            with self.assertRaises(smoke.Failure):
                smoke.png_bytes(ENCODED)

    def test_png_crc_truncation_trailing_bytes_and_dimension_lies_refuse(self):
        wrong = struct.pack(">IIBBBBB", 1279, 780, 8, 6, 0, 0, 0)
        variants = (PNG[:-1], PNG + b"trailing", PNG[:40] + bytes([PNG[40] ^ 1]) + PNG[41:],
                    PNG[:8] + chunk(b"IHDR", wrong) + PNG[33:])
        for data in variants:
            with self.subTest(size=len(data)):
                with self.assertRaises(smoke.Failure):
                    smoke.png_bytes(base64.b64encode(data).decode())

    def test_text_metadata_invalid_zlib_and_compression_bomb_are_not_artifacts(self):
        variants = (
            PNG[:33] + chunk(b"tEXt", b"private-profile-path") + PNG[33:],
            PNG[:33] + chunk(b"IDAT", b"not-zlib") + chunk(b"IEND", b""),
            PNG[:33] + chunk(b"IDAT", zlib.compress(PIXELS + b"overflow")) + chunk(b"IEND", b""),
            PNG[:33] + chunk(b"IDAT", zlib.compress(PIXELS) + zlib.compress(b"second"))
            + chunk(b"IEND", b""),
        )
        for data in variants:
            with self.subTest(size=len(data)):
                with self.assertRaises(smoke.Failure):
                    smoke.png_bytes(base64.b64encode(data).decode())

    def test_png_requires_idat_order_iend_and_valid_scanline_filters(self):
        invalid_pixels = b"\5" + PIXELS[1:]
        variants = (PNG[:33] + chunk(b"IEND", b""),
                    PNG[:33] + chunk(b"IDAT", zlib.compress(invalid_pixels)) + chunk(b"IEND", b""),
                    PNG[:33] + chunk(b"IDAT", zlib.compress(PIXELS)) + chunk(b"sRGB", b"\0")
                    + chunk(b"IEND", b""))
        for data in variants:
            with self.subTest(size=len(data)):
                with self.assertRaises(smoke.Failure):
                    smoke.png_bytes(base64.b64encode(data).decode())

    def test_capture_claims_require_exact_screen_mode_restoration_and_metrics(self):
        variants = (("screen", "import"), ("theme", "light"), ("width", True),
                    ("height", 779), ("scale", 2), ("client", [1296, 819]),
                    ("physical", [1280, 780]), ("devicePixelRatio", float("inf")),
                    ("restorationVerified", False), ("harnessMode", "presentation"),
                    ("captureMode", "covering"), ("privatePath", TOKEN))
        for key, value in variants:
            with self.subTest(key=key):
                body = {**capture_reply(), key: value}
                with self.assertRaises(smoke.Failure) as caught:
                    smoke.capture_bytes(body, "welcome", "dark")
                self.assertEqual(caught.exception.code, "CAPTURE_INVALID")


class AdmissionArtifactTests(unittest.TestCase):
    def parent(self):
        return {"GITHUB_ACTIONS": "true", "GITHUB_SHA": SOURCE, "RUNNER_OS": "Windows",
                "RUNNER_ENVIRONMENT": "github-hosted", "GITHUB_WORKSPACE": "checkout",
                "SystemRoot": r"C:\Windows", "GITHUB_RUN_ID": "4001", "GITHUB_RUN_ATTEMPT": "2"}

    def test_only_hosted_windows_exact_sha_and_anonymous_run_attempt_are_admitted(self):
        parent, expected = smoke.require_ci(self.parent(), None, platform="nt")
        self.assertEqual(expected, SOURCE)
        self.assertEqual(parent["SYSTEMROOT"], r"C:\Windows")
        for change in ({"RUNNER_ENVIRONMENT": "self-hosted"}, {"GITHUB_SHA": "bad"},
                       {"GITHUB_RUN_ID": "private-name"}, {"GITHUB_RUN_ATTEMPT": "0"}):
            with self.subTest(change=change):
                with self.assertRaises(smoke.bounded.SmokeFailure):
                    smoke.require_ci({**self.parent(), **change}, None, platform="nt")
        with self.assertRaises(smoke.bounded.SmokeFailure):
            smoke.require_ci(self.parent(), None, platform="posix")
        with self.assertRaises(smoke.bounded.SmokeFailure):
            smoke.require_ci(self.parent(), "5" * 40, platform="nt")

    def test_ordinary_profile_replaces_all_locations_and_inherited_harness_flags(self):
        parent = {key.lower(): "inherited-private" for key in smoke.bounded.REPLACED}
        parent.update({"SYRIUS_HARNESS_PRESENTATION": "welcome", "SYRIUS_HARNESS_SEED": TOKEN,
                       "GITHUB_TOKEN": TOKEN, "HTTP_PROXY": TOKEN, "Path": "runtime-path"})
        original = dict(parent)
        profile = PureWindowsPath(r"D:\checkout\.harness\ci-entry-smoke-new")
        env = smoke.child_environment(parent, profile, 32123, TOKEN)
        self.assertEqual(parent, original)
        self.assertTrue(smoke.bounded.REPLACED <= env.keys())
        self.assertEqual(env["PATH"], "runtime-path")
        self.assertEqual(env["XDG_CACHE_HOME"], str(profile / "Cache"))
        self.assertEqual(env["HOMEDRIVE"], "D:")
        self.assertNotIn("inherited-private", env.values())
        for key in ("GITHUB_TOKEN", "HTTP_PROXY", "SYRIUS_HARNESS_PRESENTATION", "SYRIUS_HARNESS_SEED"):
            self.assertNotIn(key, env)

    def test_source_tree_is_exact_bounded_and_dirty_source_is_rejected(self):
        calls = []
        def fixed(arguments, **kwargs):
            calls.append((arguments, kwargs))
            return (0, (TREE + "\r\n").encode()) if "rev-parse" in arguments else (0, b"")
        self.assertEqual(smoke.source_tree(Path("checkout"), self.parent(), run=fixed), TREE)
        self.assertEqual(calls[0][1]["cap"], 128)
        self.assertIn("HEAD^{tree}", calls[0][0])
        for output in ((TREE + "\nprivate-path").encode(), b"not-a-tree\n"):
            with self.assertRaises(smoke.Failure):
                smoke.source_tree(Path("checkout"), {}, run=lambda *a, **kw: (0, output))
        with self.assertRaises(smoke.Failure):
            smoke.source_tree(Path("checkout"), {}, run=lambda args, **kw:
                              (0, (TREE + "\n").encode()) if "rev-parse" in args else (1, b""))

    def test_fresh_output_is_separate_from_profile_and_never_adopts_existing_output(self):
        with tempfile.TemporaryDirectory() as location:
            repo = Path(location)
            artifacts = smoke.Artifacts(repo)
            profile = smoke.new_profile(repo)
            self.assertNotEqual(profile, artifacts.root)
            self.assertNotIn(profile, artifacts.root.parents)
            artifacts.png("welcome-dark.png", PNG)
            with self.assertRaises(smoke.Failure) as caught:
                smoke.Artifacts(repo)
            self.assertEqual(caught.exception.code, "OUTPUT_REFUSED")
            report = smoke.Report()
            report.captures = artifacts.records
            artifacts.manifest(report.public())
            public = json.loads((artifacts.root / "manifest.json").read_bytes())
            self.assertFalse(public["success"])
            self.assertEqual(public["status"], "UNKNOWN")
            self.assertEqual(public["capture_count"], 1)
            self.assertEqual(set(path.name for path in artifacts.root.iterdir()),
                             {"welcome-dark.png", "manifest.json"})

    def test_exclusive_artifacts_keep_original_bytes_and_reject_unlisted_names(self):
        with tempfile.TemporaryDirectory() as location:
            artifacts = smoke.Artifacts(Path(location))
            artifacts.png("welcome-dark.png", PNG)
            for name in ("welcome-dark.png", "profile.zip", "../profile", "raw.log"):
                with self.subTest(name=name):
                    with self.assertRaises(smoke.Failure):
                        artifacts.png(name, b"private-data")
            self.assertEqual((artifacts.root / "welcome-dark.png").read_bytes(), PNG)
            artifacts.manifest(smoke.Report().public())
            with self.assertRaises(FileExistsError):
                artifacts.manifest(smoke.Report().public())

    def test_entry_lane_is_default_off_independent_and_uploads_five_explicit_files(self):
        workflow = (CONTROLLER.parents[2] / ".github/workflows/public-contribution-qualification.yml").read_text()
        self.assertIn("entry_capture_smoke:", workflow)
        option = workflow.split("      entry_capture_smoke:\n", 1)[1].split("\npermissions:", 1)[0]
        self.assertIn("default: false", option)
        lane = workflow.split("  windows-entry-capture:\n", 1)[1].split("\n  devnet-tests:", 1)[0]
        self.assertIn("if: inputs.entry_capture_smoke", lane)
        self.assertIn("runs-on: windows-latest", lane)
        self.assertNotIn("needs:", lane)
        self.assertIn("--target harness/app/main.dart", lane)
        self.assertIn("--enforce-lockfile", lane)
        self.assertIn("compression-level: 0", lane)
        self.assertIn("always()", lane)
        upload = lane.split("path: |\n", 1)[1]
        self.assertEqual([line.strip() for line in upload.splitlines() if line.strip()],
                         [f".harness/ci-entry-capture/{name}" for name in (*smoke.FILES, "manifest.json")])


if __name__ == "__main__":
    unittest.main()
