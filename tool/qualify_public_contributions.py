"""Bind public CI checks to exact sources and distinguish inherited drift."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


BASE = "069546c89924bbbf393f751af39e530edf0550fe"
LOCK_SHA256 = "97668c301ff6937b1edf9b89bd8ad632bc8d1b99696955a5a7f3186f392e62b7"


def git(repository, *arguments):
    return subprocess.check_output(["git", "-C", str(repository), *arguments])


def check(repository, command):
    subprocess.run(command, cwd=repository, check=True)


def note(message):
    print(message, flush=True)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as stream:
            stream.write(message + "\n\n")


def bind(repository, expected):
    if not re.fullmatch(r"[0-9a-f]{40}", expected):
        raise ValueError("Expected a complete source commit hash.")
    actual = git(repository, "rev-parse", "HEAD").decode().strip()
    if actual != expected:
        raise ValueError("The checked-out source does not match its pinned commit.")
    lock = hashlib.sha256((repository / "pubspec.lock").read_bytes()).hexdigest()
    if lock != LOCK_SHA256:
        raise ValueError("The dependency lock does not match the approved sources.")
    note(json.dumps({"sourceCommit": actual,
                     "sourceTree": git(repository, "rev-parse", "HEAD^{tree}").decode().strip(),
                     "dependencyLockSha256": lock}, sort_keys=True))


def regenerate(repository):
    check(repository, ["dart", "run", "build_runner", "build"])
    check(repository, ["dart", "format", "integration_test"])
    paths = git(repository, "diff", "--name-only", "-z", "HEAD").split(b"\0")
    changes = {}
    for raw_path in filter(None, paths):
        path = raw_path.decode()
        current = repository / path
        if not current.is_file() or current.is_symlink():
            raise ValueError("Regeneration removed a file or introduced a symlink.")
        before = git(repository, "show", "HEAD:" + path)
        changes[path] = {"before": hashlib.sha256(before).hexdigest(),
                         "after": hashlib.sha256(current.read_bytes()).hexdigest()}
    if git(repository, "ls-files", "--others", "--exclude-standard", "-z"):
        raise ValueError("Regeneration created an unexpected untracked file.")
    return changes


def generated(repository):
    check(repository, ["git", "diff", "--exit-code", "HEAD"])
    candidate = regenerate(repository)
    if not candidate:
        note("Generated-file check: the pinned source regenerates cleanly.")
        return
    check(repository, ["git", "fetch", "--no-tags", "--depth=1", "origin", BASE])
    with tempfile.TemporaryDirectory(prefix="public-ci-baseline-") as folder:
        baseline = Path(folder) / "source"
        check(repository, ["git", "worktree", "add", "--detach", str(baseline), BASE])
        try:
            bind(baseline, BASE)
            check(baseline, ["flutter", "pub", "get", "--enforce-lockfile"])
            inherited = regenerate(baseline)
            if candidate != inherited:
                raise ValueError("The candidate introduces generation drift beyond the pinned base.")
            note("Generated-file check: inherited drift matches the pinned base byte for byte. "
                 "This is a baseline comparison, not a strict clean-tree pass. "
                 "PR #17 supplies the separate clean-tree correction.")
            note(json.dumps({"inheritedGenerationDrift": candidate}, sort_keys=True))
        finally:
            check(repository, ["git", "worktree", "remove", "--force", str(baseline)])


def checksums(repository):
    text = (repository / ".github/workflows/syrius_builder.yml").read_text()
    marker = "      - name: Generate and verify checksums\n        run: |\n"
    if text.count(marker) != 1:
        raise ValueError("The exact checksum step is missing or ambiguous.")
    block = []
    for line in text.split(marker, 1)[1].splitlines():
        if not line.startswith("          "):
            break
        block.append(line[10:])
    if not block:
        raise ValueError("The checksum command block is empty.")
    names = ["syrius-alphanet-windows-amd64.zip",
             "syrius-alphanet-macos-universal.dmg",
             "syrius-alphanet-linux-amd64.zip"]
    with tempfile.TemporaryDirectory(prefix="public-ci-checksums-") as folder:
        root = Path(folder)
        releases = root / "releases"
        releases.mkdir()
        for index, name in enumerate(names):
            (releases / name).write_bytes(b"Synthetic public checksum fixture\n" + bytes([index]))
        (releases / "unrelated-fixture.txt").write_text("Excluded fixture\n")
        subprocess.run(["bash", "--noprofile", "--norc", "-euo", "pipefail", "-c",
                        "\n".join(block)], cwd=root, check=True)
        manifest = (releases / "SHA256CHECKSUMS.txt").read_text().splitlines()
        expected = [hashlib.sha256((releases / name).read_bytes()).hexdigest() + "  " + name
                    for name in names]
        if manifest != expected:
            raise ValueError("The manifest does not contain exactly the three expected artifacts.")
        (releases / names[0]).write_bytes(b"Altered synthetic artifact\n")
        damaged = subprocess.run(["sha256sum", "--check", "SHA256CHECKSUMS.txt"],
                                 cwd=releases, capture_output=True)
        if damaged.returncode == 0:
            raise ValueError("Checksum verification failed to reject an altered artifact.")
    note("Checksum fixture: the exact PR #15 step verifies three files, excludes unrelated "
         "files and rejects an altered artifact. No release was created.")


def linux_bundle(repository):
    bundle = repository / "build/linux/x64/release/bundle"
    plugins = sorted((bundle / "lib").glob("*_plugin.so"))
    if not plugins:
        raise ValueError("The Linux bundle has no Flutter plugin libraries.")
    for plugin in plugins:
        dynamic = subprocess.check_output(["readelf", "-d", str(plugin)], text=True)
        if not re.search(r"\(RUNPATH\).*\[\$ORIGIN\]", dynamic):
            raise ValueError("A plugin is missing its relocatable runtime path: " + plugin.name)
    import ctypes

    libraries = sorted((bundle / "lib").glob("*sqlite*.so"))
    if len(libraries) != 1:
        raise ValueError("The bundle must contain exactly one native SQLite library.")
    library = ctypes.CDLL(str(libraries[0]))
    library.sqlite3_libversion.restype = ctypes.c_char_p
    library.sqlite3_open_v2.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p),
                                      ctypes.c_int, ctypes.c_char_p]
    library.sqlite3_close_v2.argtypes = [ctypes.c_void_p]
    library.sqlite3_exec.argtypes = [ctypes.c_void_p, ctypes.c_char_p,
                                   ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
    database = ctypes.c_void_p()
    if library.sqlite3_open_v2(b":memory:", ctypes.byref(database), 6, None):
        raise ValueError("The packaged SQLite library cannot open an in-memory database.")
    try:
        if library.sqlite3_exec(database, b"SELECT 1;", None, None, None):
            raise ValueError("The packaged SQLite library cannot execute a query.")
    finally:
        if library.sqlite3_close_v2(database):
            raise ValueError("The packaged SQLite database failed to close.")
    note(json.dumps({"pluginRuntimePaths": "$ORIGIN", "pluginCount": len(plugins),
                     "packagedSqliteVersion": library.sqlite3_libversion().decode(),
                     "packagedSqliteQuery": "passed"}, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=["bind", "generated", "checksums", "linux-bundle"])
    parser.add_argument("repository", type=Path)
    parser.add_argument("expected_commit")
    args = parser.parse_args()
    repository = args.repository.resolve(strict=True)
    bind(repository, args.expected_commit)
    if args.check == "generated":
        generated(repository)
    elif args.check == "checksums":
        checksums(repository)
    elif args.check == "linux-bundle":
        linux_bundle(repository)


if __name__ == "__main__":
    main()
