"""Injected diagnostic cases; no process, socket, thread or disk scratch."""

from pathlib import Path
import subprocess
import unittest
from unittest import mock

from tool.ci import hosted_chain321 as lab
from tool.ci import native_stack_probe as probe


def stack():
    return (b"goroutine 10 [select]:\nnet/http.(*Server).Shutdown(0xprivate)\n"
            b"private-path.go:1\ngithub.com/zenon-network/go-zenon/node.(*httpServer).doStop(0xprivate)\n"
            + probe.OWNER + b"0xprivate)\nprivate-path.go:2\n\n"
            b"goroutine 11 [select]:\nprivate-owner()\nprivate-path.go:3\n")


class StackProbeTests(unittest.TestCase):
    def test_only_actual_shutdown_block_has_allowlisted_frames(self):
        result = probe.project(stack())
        self.assertEqual(result["status"], "CAPTURED")
        self.assertEqual(result["frames"], ["HTTP_SERVER_SHUTDOWN", "NODE_HTTP_DO_STOP", "NODE_STOP"])
        self.assertNotIn("private", str(result))

    def test_unrelated_or_ambiguous_goroutines_cannot_become_original_shutdown(self):
        self.assertEqual(probe.project(b"goroutine 1 [select]:\nprivate()\n")["status"], "NO_SHUTDOWN_STACK")
        self.assertEqual(probe.project(stack() + b"\n" + stack())["status"], "AMBIGUOUS")
        self.assertEqual(probe.project(b"bad header\n" + probe.OWNER + b"0)")["status"], "REFUSED")

    def test_oversized_bytes_are_refused_before_parsing(self):
        self.assertEqual(probe.project(b"x" * (probe.MAX_BYTES + 1))["status"], "REFUSED")

    def test_disabled_or_exited_original_never_opens_a_connection(self):
        with mock.patch.object(probe.http.client, "HTTPConnection") as connection:
            for enabled, code in ((False, None), (True, 0)):
                owner = mock.Mock(stack_debug=enabled, process=mock.Mock(poll=mock.Mock(return_value=code)))
                self.assertEqual(probe.capture(owner)["status"], "UNAVAILABLE")
            connection.assert_not_called()

    def test_one_fixed_loopback_request_and_original_connection_close(self):
        response = mock.Mock(status=200)
        response.getheader.return_value = "identity"
        response.read1.side_effect = [stack(), b""]
        connection = mock.Mock()
        connection.getresponse.return_value = response
        owner = mock.Mock(stack_debug=True, process=mock.Mock(poll=mock.Mock(return_value=None)))
        with mock.patch.object(probe.http.client, "HTTPConnection", return_value=connection) as factory:
            result = probe.capture(owner)
        factory.assert_called_once_with("127.0.0.1", 45999, timeout=1)
        connection.request.assert_called_once_with("GET", "/debug/pprof/goroutine?debug=2",
            headers={"Connection": "close", "Accept-Encoding": "identity"})
        connection.close.assert_called_once_with()
        self.assertEqual(result["status"], "CAPTURED")

    def test_redirect_is_not_followed_and_original_exit_during_read_is_unavailable(self):
        for status, polls in ((302, [None]), (200, [None, 0])):
            response = mock.Mock(status=status)
            response.getheader.return_value = "identity"
            response.read1.side_effect = [stack(), b""]
            connection = mock.Mock()
            connection.getresponse.return_value = response
            owner = mock.Mock(stack_debug=True, process=mock.Mock(poll=mock.Mock(side_effect=polls)))
            with mock.patch.object(probe.http.client, "HTTPConnection", return_value=connection):
                result = probe.capture(owner)
            self.assertNotEqual(result["status"], "CAPTURED")
            connection.close.assert_called_once_with()
            connection.request.assert_called_once()

    def test_close_failure_cannot_leave_a_positive_probe(self):
        response = mock.Mock(status=200)
        response.getheader.return_value = "identity"
        response.read1.side_effect = [stack(), b""]
        connection = mock.Mock()
        connection.getresponse.return_value = response
        connection.close.side_effect = OSError("private")
        owner = mock.Mock(stack_debug=True, process=mock.Mock(poll=mock.Mock(return_value=None)))
        with mock.patch.object(probe.http.client, "HTTPConnection", return_value=connection):
            result = probe.capture(owner)
        self.assertEqual(result["status"], "REFUSED")
        self.assertEqual(result["frames"], [])

    def test_diagnostic_flags_are_default_off_and_only_enabled_for_rpc(self):
        for enabled in (False, True):
            runtime = lab.Native(mock.Mock(env={}), Path("fixture/znnd"),
                {role: Path("fixture") / role for role in lab.ROLES}, stack_debug=enabled)
            with mock.patch.object(lab, "Original") as factory:
                runtime.start()
            calls = factory.call_args_list
            self.assertEqual(len(calls), 5)
            self.assertTrue(all("--pprof" not in call.args[0] for call in calls[:4]))
            self.assertEqual("--pprof" in calls[4].args[0], enabled)

    def test_probe_error_cannot_prevent_forced_original_cleanup_or_create_success(self):
        owner = object.__new__(lab.Original)
        owner.process = mock.Mock()
        owner.process.poll.side_effect = [None, None]
        owner.process.wait.side_effect = [subprocess.TimeoutExpired("fixture", 30), None]
        owner.receipt, owner.forced, owner.stack_debug = None, False, True
        owner.finish = mock.Mock()
        with mock.patch.object(probe, "capture", side_effect=ValueError("private")):
            owner.stop()
        owner.process.kill.assert_called_once_with()
        self.assertTrue(owner.forced)
        self.assertEqual(owner.stop_code, "WAIT_TIMEOUT")
        self.assertEqual(owner.stack_probe["status"], "UNAVAILABLE")
