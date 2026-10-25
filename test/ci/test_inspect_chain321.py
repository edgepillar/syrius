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
        success=False, checks=dict.fromkeys(inspect.CHECKS, False),
        error_codes=["COMMAND_FAILED"], commands=[dict(compiler_diagnostics=[dict(code="LOCKED_MODULE_CHANGED")])],
        compiler="go version go1.24.1 windows/amd64", private_profile="/fixture/private/profile")


class InspectionTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
