"""Read retained lab manifests in memory; never start a runtime or admit seed."""

from __future__ import annotations

import hashlib
import io
import json
import os
import re
import stat
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

from tool.ci.hosted_chain321 import CODES, NODE_SHA


API = "https://api.github.com/repos/edgepillar/syrius"
MAX_ARCHIVE = 1024**2
MAX_MANIFEST = 512 * 1024
DIAGNOSTICS = frozenset((
    "GO_VERSION_REQUIRED", "BUILD_TAGS_REQUIRED", "LOCKED_MODULE_CHANGED",
    "VCS_STATUS_REFUSED", "DEPENDENCY_TLS_REFUSED", "DEPENDENCY_NETWORK_FAILED",
    "DEPENDENCY_MISSING", "C_TOOLCHAIN_FAILED", "GO_LINKNAME_REFUSED",
    "COMPILER_UNDEFINED_SYMBOL", "UNCLASSIFIED_BUILD_FAILURE",
))
CHECKS = frozenset(("source", "build", "assets", "preflight", "started",
                    "production", "stopped", "inputs_unchanged"))
PHASE = "environment"


class Refused(Exception):
    pass


def need(value):
    if not value:
        raise Refused("INSPECTION_REFUSED")


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def artifact_location(value):
    need(type(value) is str and len(value) <= 8192
         and all(32 < ord(char) < 127 for char in value))
    parsed = urllib.parse.urlsplit(value)
    need(parsed.scheme == "https" and parsed.hostname is not None
         and parsed.hostname.endswith((".blob.core.windows.net", ".actions.githubusercontent.com"))
         and parsed.port in (None, 443) and parsed.username is None
         and parsed.password is None and not parsed.fragment)
    return value


def request_for(url, token=None):
    if token is None:
        artifact_location(url)
        return urllib.request.Request(url, headers={"User-Agent": "syrius-chain321-inspection"})
    parsed = urllib.parse.urlsplit(url)
    need(parsed.scheme == "https" and parsed.hostname == "api.github.com"
         and parsed.port in (None, 443) and parsed.username is None
         and parsed.password is None and parsed.path.startswith("/repos/edgepillar/syrius/"))
    need(type(token) is str and 0 < len(token) <= 4096)
    return urllib.request.Request(url, headers={"Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "syrius-chain321-inspection"})


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Client:
    def __init__(self, token):
        self.token, self.end, self.calls = token, time.monotonic() + 120, 0
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def read(self, url, *, authenticated=True, redirect=False, cap=256 * 1024):
        self.calls += 1
        need(self.calls <= 12 and time.monotonic() < self.end)
        req = request_for(url, self.token if authenticated else None)
        try:
            response = self.opener.open(req, timeout=15)
        except urllib.error.HTTPError as error:
            try:
                need(redirect and authenticated and error.code == 302)
                return artifact_location(error.headers["Location"])
            finally:
                error.close()
        with response:
            need(not redirect and response.status == 200
                 and response.headers.get("Content-Encoding", "identity") == "identity")
            data = bytearray()
            while True:
                need(time.monotonic() < self.end)
                chunk = response.read1(min(65536, cap + 1 - len(data)))
                if not chunk:
                    break
                data.extend(chunk)
                need(len(data) <= cap)
            return bytes(data)

    def json(self, path):
        return json.loads(self.read(API + path))


def unpack(raw, expected_sha, expected_size):
    need(type(raw) is bytes and 0 < len(raw) == expected_size <= MAX_ARCHIVE
         and sha(raw) == expected_sha)
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        members = archive.infolist()
        need(len(members) == 1)
        member = members[0]
        need(member.filename == "manifest.json" and not member.is_dir()
             and not member.flag_bits & 1 and 0 < member.file_size <= MAX_MANIFEST
             and stat.S_IFMT(member.external_attr >> 16) in (0, stat.S_IFREG))
        with archive.open(member) as stream:
            data = stream.read(MAX_MANIFEST + 1)
            need(not stream.read(1))
        need(len(data) == member.file_size <= MAX_MANIFEST)
    value = json.loads(data)
    need(type(value) is dict)
    return value, sha(data)


def project(report, backend, head, run_id):
    need(backend in ("docker", "native") and report.get("scope") == "hosted_chain321_lab"
         and report.get("application_sha") == head and report.get("node_sha") == NODE_SHA
         and report.get("run_id") == str(run_id) and report.get("attempt") == "1"
         and report.get("backend") == backend and type(report.get("success")) is bool)
    checks, errors, commands = report.get("checks"), report.get("error_codes"), report.get("commands")
    need(type(checks) is dict and set(checks) == CHECKS and all(type(v) is bool for v in checks.values()))
    need(type(errors) is list and len(errors) <= 16 and all(code in CODES for code in errors))
    need(type(commands) is list and len(commands) <= 1024)
    diagnostics = []
    for command in commands:
        if command is None:
            continue
        need(type(command) is dict)
        found = command.get("compiler_diagnostics", [])
        need(type(found) is list and len(found) <= 12)
        for item in found:
            need(type(item) is dict and set(item) <= {"code", "symbol"}
                 and item.get("code") in DIAGNOSTICS)
            value = dict(code=item["code"])
            if "symbol" in item:
                need(type(item["symbol"]) is str
                     and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_./]{0,95}", item["symbol"]) is not None)
                value["symbol"] = item["symbol"]
            diagnostics.append(value)
    need(len(diagnostics) <= 24)
    compiler = report.get("compiler")
    need(compiler is None or (type(compiler) is str and
         re.fullmatch(r"go version go[0-9]+\.[0-9]+\.[0-9]+ (?:windows|linux)/amd64", compiler)))
    return dict(scope="retained_chain321_observation", backend=backend,
        source_head=head, source_run_id=run_id, source_attempt=1,
        artifact_reported_success=report["success"], checks=checks, error_codes=errors,
        compiler=compiler, compiler_diagnostics=diagnostics,
        inspection_only=True, runtime_started=False, seed_admitted=False)


def main():
    global PHASE
    parent = os.environ
    need(parent.get("GITHUB_ACTIONS") == "true" and parent.get("SYRIUS_HOSTED_RUNNER") == "github-hosted"
         and parent.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
         and parent.get("GITHUB_REPOSITORY") == "edgepillar/syrius")
    run_text, head = parent.get("LAB_INSPECT_RUN", ""), parent.get("LAB_INSPECT_HEAD", "")
    need(re.fullmatch(r"[1-9][0-9]{0,19}", run_text) is not None
         and re.fullmatch(r"[a-f0-9]{40}", head) is not None)
    run_id = int(run_text)
    client = Client(parent.get("GH_TOKEN"))
    PHASE = "source_metadata"
    run = client.json("/actions/runs/" + run_text)
    need(run["id"] == run_id and run["head_sha"] == head and run["run_attempt"] == 1
         and run["workflow_id"] == 381413107 and run["event"] == "workflow_dispatch"
         and run["status"] == "completed" and run["repository"]["full_name"] == "edgepillar/syrius")
    PHASE = "artifact_metadata"
    listing = client.json("/actions/runs/" + run_text + "/artifacts?per_page=20")
    need(listing["total_count"] == len(listing["artifacts"]) <= 20)
    for backend in ("docker", "native"):
        name = "chain321-" + backend + "-" + head + "-" + run_text + "-1"
        selected = [item for item in listing["artifacts"] if item["name"] == name]
        need(len(selected) == 1)
        item = selected[0]
        need(item["expired"] is False and item["workflow_run"]["id"] == run_id
             and item["workflow_run"]["head_sha"] == head
             and re.fullmatch(r"sha256:[a-f0-9]{64}", item.get("digest", "")) is not None)
        PHASE = "download_" + backend
        location = client.read(API + "/actions/artifacts/" + str(item["id"]) + "/zip", redirect=True)
        raw = client.read(location, authenticated=False, cap=MAX_ARCHIVE)
        PHASE = "parse_" + backend
        report, manifest_sha = unpack(raw, item["digest"][7:], item["size_in_bytes"])
        summary = project(report, backend, head, run_id)
        summary.update(archive_sha256=sha(raw), manifest_sha256=manifest_sha)
        encoded = json.dumps(summary, sort_keys=True, separators=(",", ":"))
        escaped = encoded.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print("::notice title=Retained chain-321 observation::" + escaped, flush=True)
    PHASE = "source_metadata_after"
    after = client.json("/actions/runs/" + run_text)
    need(all(after[key] == run[key] for key in ("id", "head_sha", "run_attempt", "workflow_id", "status", "conclusion")))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("::error title=Retained chain-321 inspection::INSPECTION_REFUSED phase=" + PHASE, flush=True)
        raise SystemExit(1)
