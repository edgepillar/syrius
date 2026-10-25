"""Source-bound chain-321 labs in fresh hosted runners, without public RPC.

Linux uses five owned Docker containers. Windows uses five original native
process handles and the same genesis. This is lab execution evidence; importing
this module starts nothing and no wallet, signer or seed recipe is admitted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import socket
import stat
import struct
import subprocess
import sys
import time

from tool.ci.windows_presentation_smoke import OutputDrain
from tool.ci.loopback_relay import PAIRS as RELAY_PAIRS, TARGET as RELAY_TARGET, Relay
from tools.devnet.lab import owned_lab as wire_policy
from tools.devnet.lab.socket_transport import make_transports


NODE_SHA = "590f43ca7a24dccd8e883bc8903a0cb02e54528a"
ROLES = ("pillar", "pillar2", "pillar3", "observer", "rpc")
OCTETS = dict(zip(ROLES, (10, 12, 13, 14, 11)))
NATIVE_PORTS = dict(zip(ROLES, (45991, 45992, 45993, 45994, 45995)))
MIB, GIB = 1024**2, 1024**3
MAX_WORK = 4 * GIB
# Only fresh, non-secret hosted regression VMs use this floor. Local and
# production storage retain their separate 10 GiB policy.
FIXTURE_MIN_FREE = 2 * GIB
GO_VERSION = "1.24.1"
CODES = frozenset((
    "ENVIRONMENT_REFUSED", "SOURCE_REFUSED", "STORAGE_REFUSED",
    "COMMAND_FAILED", "COMMAND_TIMEOUT", "OUTPUT_REFUSED", "STOP_UNKNOWN",
    "CONFIG_REFUSED", "PORT_CONFLICT", "NODE_EXITED", "RPC_UNAVAILABLE",
    "RPC_REFUSED", "GENESIS_MISMATCH", "PRODUCTION_UNPROVEN",
    "DOCKER_REFUSED", "RESOURCE_CHANGED", "INTERNAL_ERROR",
)) | wire_policy.CODES
NODE_DIAGNOSTICS = frozenset((
    "NODE_CLI_REFUSED", "NODE_STORAGE_REFUSED", "NODE_PANIC",
    "NODE_KEYSTORE_REFUSED", "NODE_GENESIS_REFUSED", "NODE_PORT_CONFLICT",
    "NODE_STARTUP_FAILED", "NODE_SIGNAL_RECEIVED",
))


class Failure(Exception):
    def __init__(self, code):
        self.code = code if code in CODES else "INTERNAL_ERROR"
        super().__init__(self.code)


def need(value, code):
    if not value:
        raise Failure(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def failure_code(error):
    return (error.code if isinstance(error, (Failure, wire_policy.Refused))
            and error.code in CODES else "INTERNAL_ERROR")


def node_diagnostics(raw):
    """Finite node failure categories; never include log text or paths."""
    text = raw.decode("utf-8", "replace")
    patterns = (
        ("NODE_CLI_REFUSED", r"flag provided but not defined|Incorrect Usage"),
        ("NODE_STORAGE_REFUSED", r"permission denied|access is denied|operation not permitted"),
        ("NODE_PANIC", r"panic:|fatal error:"),
        ("NODE_KEYSTORE_REFUSED", r"failed to start wallet|could not decrypt|invalid password|(?:failed|cannot|unable).*key file|key file.*not found"),
        ("NODE_GENESIS_REFUSED", r"genesis.*(?:invalid|error)|failed to.*genesis"),
        ("NODE_PORT_CONFLICT", r"address already in use|Only one usage of each socket"),
        ("NODE_STARTUP_FAILED", r"failed to.*(?:node|zenon)|Fatal:"),
        ("NODE_SIGNAL_RECEIVED", r"Got interrupt|Got signal|Shutting down"),
    )
    return [code for code, pattern in patterns if re.search(pattern, text, re.IGNORECASE)]


def static_linux_binary(raw):
    """Refuse ELF interpreters or dynamic sections before using FROM scratch."""
    need(type(raw) is bytes and len(raw) >= 64
         and raw[:7] == b"\x7fELF\x02\x01\x01", "SOURCE_REFUSED")
    need(struct.unpack_from("<HHI", raw, 16) == (2, 62, 1), "SOURCE_REFUSED")
    offset = struct.unpack_from("<Q", raw, 32)[0]
    size, count = struct.unpack_from("<HH", raw, 54)
    need(offset >= 64 and size == 56 and 1 <= count <= 128
         and offset + size * count <= len(raw), "SOURCE_REFUSED")
    kinds = {struct.unpack_from("<I", raw, offset + size * i)[0]
             for i in range(count)}
    need(1 in kinds and not kinds.intersection((2, 3)), "SOURCE_REFUSED")
    return True


def compiler_diagnostics(raw):
    """Project known compiler failures to codes, never paths or raw output."""
    text = raw.decode("utf-8", "replace")
    patterns = (
        ("GO_VERSION_REQUIRED", r"requires go >=|requires Go [0-9]"),
        ("BUILD_TAGS_REQUIRED", r"build constraints exclude all Go files"),
        ("LOCKED_MODULE_CHANGED", r"updates to go\.mod needed"),
        ("VCS_STATUS_REFUSED", r"error obtaining VCS status|detected dubious ownership"),
        ("DEPENDENCY_TLS_REFUSED", r"x509:|TLS handshake timeout"),
        ("DEPENDENCY_NETWORK_FAILED", r"dial tcp|network is unreachable|no such host"),
        ("DEPENDENCY_MISSING", r"no required module provides package|cannot find module"),
        ("C_TOOLCHAIN_FAILED", r"C compiler .* not found|gcc: error:|exec: .gcc."),
    )
    found = [dict(code=code) for code, pattern in patterns if re.search(pattern, text)]
    for symbol in re.findall(r"invalid reference to ([A-Za-z_][A-Za-z0-9_./]{0,95})(?:\s|$)", text)[:4]:
        found.append(dict(code="GO_LINKNAME_REFUSED", symbol=symbol))
    for symbol in re.findall(r"undefined: ([A-Za-z_][A-Za-z0-9_.]{0,95})(?:\s|$)", text)[:4]:
        found.append(dict(code="COMPILER_UNDEFINED_SYMBOL", symbol=symbol))
    return found[:12] or [dict(code="UNCLASSIFIED_BUILD_FAILURE")]


def relocated_keyfile(raw, filename, node_path):
    """Move only the public fixture's embedded deployment path."""
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeError):
        raise Failure("CONFIG_REFUSED") from None
    need(type(filename) is str and re.fullmatch(r"z1[a-z0-9]{30,64}", filename)
         and type(node_path) is str and 0 < len(node_path) <= 4096
         and "\0" not in node_path and node_path.endswith(("/" + filename, "\\" + filename)),
         "CONFIG_REFUSED")
    need(type(value) is dict and set(value) == {"Path", "baseAddress", "crypto", "version", "timestamp"}
         and value["Path"] == "/root/.znn/wallet/" + filename
         and type(value["baseAddress"]) is str
         and re.fullmatch(r"z1[a-z0-9]{30,64}", value["baseAddress"])
         and type(value["version"]) is int
         and value["version"] == 1 and type(value["timestamp"]) is int
         and type(value["crypto"]) is dict, "CONFIG_REFUSED")
    crypto = value["crypto"]
    need(crypto.get("cipherName") == "aes-256-gcm" and crypto.get("kdf") == "argon2.IDKey"
         and all(type(crypto.get(key)) is str for key in ("cipherData", "nonce"))
         and type(crypto.get("argon2Params")) is dict, "CONFIG_REFUSED")
    moved = dict(value, Path=node_path)
    return (json.dumps(moved, sort_keys=True, separators=(",", ":")) + "\n").encode("ascii")


def regular(path, cap=MIB):
    info = path.lstat()
    need(stat.S_ISREG(info.st_mode) and info.st_nlink == 1
         and info.st_size <= cap, "STORAGE_REFUSED")
    raw = path.read_bytes()
    after = path.lstat()
    need((info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns)
         == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns)
         and len(raw) == info.st_size, "STORAGE_REFUSED")
    return raw


def directories(path):
    for parent in reversed((path, *path.parents)):
        info = parent.lstat()
        need(stat.S_ISDIR(info.st_mode) and not parent.is_symlink()
             and not (getattr(info, "st_file_attributes", 0) & 0x400),
             "STORAGE_REFUSED")


def child_environment(root, parent):
    # Build tools and nodes receive no Actions token or user profile.
    allowed = {"PATH", "SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC",
               "PATHEXT", "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE",
               "LANG", "LC_ALL", "GOROOT", "SSL_CERT_FILE", "SSL_CERT_DIR"}
    env = {key: value for key, value in parent.items() if key in allowed}
    for name in ("home", "tmp", "go", "gocache", "gomodcache", "gotmp"):
        (root / name).mkdir(mode=0o700)
    env.update({key: str(root / "home") for key in
                ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA")})
    env.update({key: str(root / "tmp") for key in ("TMP", "TEMP", "TMPDIR")})
    env.update(GOPATH=str(root / "go"), GOCACHE=str(root / "gocache"),
               GOMODCACHE=str(root / "gomodcache"), GOTMPDIR=str(root / "gotmp"),
               GOTOOLCHAIN="local", CGO_ENABLED="1", CC="gcc", USER="ci",
               GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    return env


def sample_storage(root):
    """A finite cooperative sample, not an OS-enforced disk quota."""
    total, count = 0, 0
    pending = [root]
    while pending:
        current = pending.pop()
        try:
            entries = os.scandir(current)
        except FileNotFoundError:
            need(current != root, "STORAGE_REFUSED")
            continue
        with entries:
            for entry in entries:
                count += 1
                need(count <= 100000, "STORAGE_REFUSED")
                try:
                    info = entry.stat(follow_symlinks=False)
                except FileNotFoundError:
                    # Go replaces its own temporary cache entries during a build.
                    continue
                need(not entry.is_symlink()
                     and not (getattr(info, "st_file_attributes", 0) & 0x400),
                     "STORAGE_REFUSED")
                if stat.S_ISDIR(info.st_mode):
                    pending.append(Path(entry.path))
                else:
                    need(stat.S_ISREG(info.st_mode), "STORAGE_REFUSED")
                    total += info.st_size
                    need(total <= MAX_WORK, "STORAGE_REFUSED")
    need(shutil.disk_usage(root).free >= FIXTURE_MIN_FREE, "STORAGE_REFUSED")
    return total


class Original:
    """Retain the original handle and bounded drains through terminal exit."""

    def __init__(self, argv, *, cwd, env, cap=MIB):
        options = (dict(creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
                   if sys.platform == "win32" else dict(start_new_session=True))
        self.process = subprocess.Popen(argv, cwd=cwd, env=env, shell=False,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            **options)
        self.drains = [OutputDrain(pipe, cap, retain=True) for pipe in
                       (self.process.stdout, self.process.stderr)]
        self.forced = False
        self.receipt = None

    def healthy(self):
        need(not any(d.overflow.is_set() or d.error is not None
                     for d in self.drains), "OUTPUT_REFUSED")

    def finish(self, *, success=True):
        need(self.receipt is None, "STOP_UNKNOWN")
        code = self.process.poll()
        need(type(code) is int, "STOP_UNKNOWN")
        complete = all([d.finish(3) for d in self.drains])
        self.receipt = dict(exit_code=code, output_complete=complete,
            forced=self.forced, stop_code=getattr(self, "stop_code", None),
            stop_os_error=getattr(self, "stop_os_error", None),
            streams={key: dict(bytes=d.count,
                retained_bytes=len(d.data), sha256=digest(bytes(d.data)),
                overflow=d.overflow.is_set()) for key, d in zip(
                    ("stdout", "stderr"), self.drains)})
        need(complete and all(not d.overflow.is_set() and d.error is None
                              for d in self.drains), "OUTPUT_REFUSED")
        if success:
            need(code == 0 and not self.forced, "COMMAND_FAILED")
        return bytes(self.drains[0].data)

    def request_stop(self):
        if self.receipt is not None:
            return
        if getattr(self, "stop_requested", False):
            if getattr(self, "signal_error", None) is not None:
                raise self.signal_error
            return
        self.stop_requested = True
        if self.process.poll() is None:
            try:
                self.process.send_signal(signal.CTRL_BREAK_EVENT if sys.platform == "win32"
                                         else signal.SIGINT)
            except OSError as error:
                self.signal_error = error
                self.stop_code = "SIGNAL_OS_ERROR"
                self.stop_os_error = getattr(error, "winerror", getattr(error, "errno", None))
                raise

    def stop(self):
        if self.receipt is not None:
            return
        try:
            self.request_stop()
            if self.process.poll() is None:
                self.process.wait(timeout=30)
        except (OSError, subprocess.TimeoutExpired) as error:
            if getattr(self, "stop_code", None) is None:
                self.stop_code = "SIGNAL_OS_ERROR" if isinstance(error, OSError) else "WAIT_TIMEOUT"
                number = getattr(error, "winerror", getattr(error, "errno", None))
                self.stop_os_error = number if type(number) is int else None
            self.forced = True
            self.process.kill()
            self.process.wait(timeout=10)
        self.finish()


class Commands:
    def __init__(self, root, env):
        self.root, self.env, self.originals = root, env, []

    def run(self, argv, *, cwd, timeout=20, cap=MIB):
        need(len(self.originals) < 1024, "COMMAND_FAILED")
        original = Original(argv, cwd=cwd, env=self.env, cap=cap)
        self.originals.append(original)
        end, next_sample = time.monotonic() + timeout, 0.0
        try:
            while original.process.poll() is None:
                original.healthy()
                now = time.monotonic()
                need(now < end, "COMMAND_TIMEOUT")
                if now >= next_sample:
                    sample_storage(self.root)
                    next_sample = now + 2
                time.sleep(0.2)
            return original.finish()
        except BaseException:
            if original.process.poll() is None:
                original.forced = True
                original.process.kill()
                original.process.wait(timeout=10)
            if original.receipt is None:
                original.finish(success=False)
            if argv[:2] == ["go", "build"]:
                original.receipt["compiler_diagnostics"] = compiler_diagnostics(
                    bytes(original.drains[1].data))
            raise

    def git(self, path, *args):
        return self.run(["git", "--no-pager", "-c", "core.fsmonitor=false",
            "-c", "core.hooksPath=" + os.devnull, "-c", "core.pager=cat",
            "-C", str(path), *args], cwd=path).decode("ascii").strip()


def configuration(value, role, data, backend):
    """Move only deployment paths, listen addresses and bootstrap ports."""
    need(role in ROLES and backend in ("docker", "native"), "CONFIG_REFUSED")
    result = json.loads(json.dumps(value))
    need(type(result.get("Net")) is dict and type(result.get("RPC")) is dict,
         "CONFIG_REFUSED")
    net, rpc = result["Net"], result["RPC"]
    for field in ("BootstrapPeers", "Seeders"):
        peers = net.get(field)
        need(type(peers) is list and peers, "CONFIG_REFUSED")
        moved = []
        for peer in peers:
            need(type(peer) is str, "CONFIG_REFUSED")
            pattern = (r"/ip4/172\.30\.0\.(10|11|12|13|14)/tcp/35995/p2p/[A-Za-z0-9]{32,128}"
                       if field == "BootstrapPeers" else
                       r"enode://[a-f0-9]{128}@172\.30\.0\.(10|11|12|13|14):35995")
            need(re.fullmatch(pattern, peer) is not None, "CONFIG_REFUSED")
            expected = [other for other in ROLES if
                        ("172.30.0." + str(OCTETS[other])) in peer]
            need(len(expected) == 1 and peer.count("172.30.0.") == 1,
                 "CONFIG_REFUSED")
            other = expected[0]
            old = "172.30.0." + str(OCTETS[other])
            if backend == "docker":
                peer = peer.replace(old, "172.37.0." + str(OCTETS[other]))
            else:
                peer = peer.replace(old + "/tcp/35995", "127.0.0.1/tcp/" + str(NATIVE_PORTS[other]))
                peer = peer.replace(old + ":35995", "127.0.0.1:" + str(NATIVE_PORTS[other]))
                need("172.30.0." not in peer and "127.0.0.1" in peer,
                     "CONFIG_REFUSED")
            moved.append(peer)
        net[field] = moved
    net["ListenHost"] = "0.0.0.0" if backend == "docker" else "127.0.0.1"
    net["ListenPort"] = 35995 if backend == "docker" else NATIVE_PORTS[role]
    base = "/data" if backend == "docker" else str(data)
    result.update(DataPath=base, GenesisFile=base + "/genesis.json",
                  WalletPath=base + "/wallet")
    rpc_host = ("0.0.0.0" if backend == "docker" else "127.0.0.1") if role == "rpc" else ""
    rpc.update(EnableHTTP=role == "rpc", EnableWS=role == "rpc",
        HTTPHost=rpc_host, WSHost=rpc_host,
        HTTPPort=35997 if backend == "docker" else 45997,
        WSPort=35998 if backend == "docker" else 45998)
    return result


def preflight_ports(backend):
    ports = [45997, 45998] + (list(NATIVE_PORTS.values()) if backend == "native" else [])
    sockets = []
    try:
        for port in ports:
            original = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sockets.append(original)
            if sys.platform == "win32":
                original.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            original.bind(("127.0.0.1", port))
    except OSError:
        raise Failure("PORT_CONFLICT") from None
    finally:
        for original in sockets:
            original.close()


class Native:
    def __init__(self, commands, binary, configs):
        self.commands, self.binary, self.configs = commands, binary, configs
        self.originals = []

    def start(self):
        for role in ROLES:
            data = self.configs[role]
            original = Original([str(self.binary), "--data", str(data),
                "--config", str(data / "config.json"), "--genesis", str(data / "genesis.json"),
                "--wallet", str(data / "wallet")], cwd=data, env=self.commands.env)
            self.originals.append(original)

    def healthy(self):
        need(len(self.originals) == 5, "NODE_EXITED")
        for original in self.originals:
            original.healthy()
            need(original.process.poll() is None, "NODE_EXITED")

    def stop(self):
        failed = False
        # Signal the whole original peer set before waiting for any member.
        # Peer shutdown can wait for remote read loops to finish.
        for original in reversed(self.originals):
            try:
                original.request_stop()
            except Exception:
                failed = True
        for original in reversed(self.originals):
            try:
                original.stop()
            except Exception:
                failed = True
            finally:
                try:
                    if type(original.receipt) is dict:
                        original.receipt["node_diagnostics"] = node_diagnostics(
                            b"\n".join(bytes(d.data) for d in original.drains))
                except Exception:
                    failed = True
        need(not failed and len(self.originals) == 5
             and all(item.receipt is not None and item.receipt["exit_code"] == 0
                     and item.receipt["output_complete"] is True
                     and item.receipt["forced"] is False for item in self.originals),
             "STOP_UNKNOWN")


class Docker:
    def __init__(self, commands, binary, configs, nonce):
        self.commands, self.binary, self.configs = commands, binary, configs
        self.name, self.owner = "syrius-ci321-" + nonce, nonce
        self.image = self.network = None
        self.created, self.started = [], []
        self.states, self.diagnostics = [], []
        self.relay = None
        self.direct_rpc_ready = False

    def record_state(self, item, phase):
        state = item.get("State", {})
        need(item.get("Id") in self.created
             and type(state.get("Running")) is bool and type(state.get("ExitCode")) is int
             and type(state.get("OOMKilled")) is bool and len(self.states) < 512,
             "RESOURCE_CHANGED")
        self.states.append(dict(phase=phase, role=ROLES[self.created.index(item["Id"])],
            running=state["Running"],
            exit_code=state["ExitCode"], oom_killed=state["OOMKilled"]))

    def call(self, *args, timeout=20):
        return self.commands.run(["docker", *args], cwd=self.binary.parent,
                                 timeout=timeout)

    def inspect(self, kind, identifier):
        value = json.loads(self.call(kind, "inspect", identifier))
        need(type(value) is list and len(value) == 1, "DOCKER_REFUSED")
        return value[0]

    def start(self):
        info = json.loads(self.call("info", "--format", "{{json .}}"))
        need(info.get("OSType") == "linux" and info.get("Architecture") in
             ("x86_64", "amd64"), "DOCKER_REFUSED")
        context = self.binary.parent / "image"
        context.mkdir(mode=0o700)
        image_binary = context / "znnd"
        shutil.copyfile(self.binary, image_binary)
        image_binary.chmod(0o555)
        need(digest(regular(image_binary, 128 * MIB)) == digest(regular(self.binary, 128 * MIB))
             and stat.S_IMODE(image_binary.stat().st_mode) == 0o555, "SOURCE_REFUSED")
        (context / "Dockerfile").write_text('FROM scratch\nCOPY znnd /znnd\nENTRYPOINT ["/znnd"]\n')
        tag = self.name + ":source"
        self.call("build", "--network=none", "--pull=false", "--label",
                  "org.zenon.ci321.owner=" + self.owner, "-t", tag, str(context), timeout=120)
        image = self.inspect("image", tag)
        need(re.fullmatch("sha256:[a-f0-9]{64}", image.get("Id", ""))
             and image["Config"]["Labels"].get("org.zenon.ci321.owner") == self.owner,
             "DOCKER_REFUSED")
        self.image = image["Id"]
        self.network = self.call("network", "create", "--internal", "--subnet", "172.37.0.0/24",
            "--gateway", "172.37.0.1",
            "--label", "org.zenon.ci321.owner=" + self.owner, self.name).decode().strip()
        need(re.fullmatch("[a-f0-9]{64}", self.network), "DOCKER_REFUSED")
        for role in ROLES:
            args = ["create", "--name", self.name + "-" + role, "--label",
                "org.zenon.ci321.owner=" + self.owner, "--network", self.network,
                "--ip", "172.37.0." + str(OCTETS[role]), "--restart=no", "--read-only",
                "--cap-drop=ALL", "--security-opt=no-new-privileges", "--pids-limit=128",
                "--log-opt=max-size=1m", "--log-opt=max-file=2", "--tmpfs", "/tmp:size=32m",
                "--user", str(os.getuid()) + ":" + str(os.getgid()), "--env", "HOME=/data",
                "--env", "USER=ci", "--mount", "type=bind,src=" + str(self.configs[role]) + ",dst=/data"]
            args += [self.image, "--data", "/data", "--config", "/data/config.json",
                     "--genesis", "/data/genesis.json", "--wallet", "/data/wallet"]
            identifier = self.call(*args).decode().strip()
            need(re.fullmatch("[a-f0-9]{64}", identifier), "DOCKER_REFUSED")
            self.created.append(identifier)
            self.call("start", identifier)
            self.started.append(identifier)
        self.healthy()
        # Internal bridges remain isolated. Reach only the exact RPC member
        # from the host, then expose two original loopback byte relays.
        end = time.monotonic() + 90
        while True:
            try:
                for _, port in RELAY_PAIRS:
                    with socket.create_connection((RELAY_TARGET, port), timeout=1):
                        pass
                break
            except OSError:
                need(time.monotonic() < end, "RPC_UNAVAILABLE")
                time.sleep(2)
        self.direct_rpc_ready = True
        self.healthy()
        self.relay = Relay()
        self.relay.start()

    def healthy(self):
        need(len(self.created) == len(self.started) == 5, "RESOURCE_CHANGED")
        network = self.inspect("network", self.network)
        need(network["Id"] == self.network and network["Internal"] is True
             and set(network["Containers"]) == set(self.created), "RESOURCE_CHANGED")
        for identifier in self.started:
            item = self.inspect("container", identifier)
            need(item["Id"] == identifier and item["Image"] == self.image
                 and item["Config"]["Labels"].get("org.zenon.ci321.owner") == self.owner,
                 "RESOURCE_CHANGED")
            self.record_state(item, "health")
            need(item["State"]["Running"] is True and item["RestartCount"] == 0,
                 "RESOURCE_CHANGED")

    def stop(self):
        failed = False
        if self.relay is not None:
            try:
                self.relay.stop()
            except Exception:
                failed = True
        for identifier in reversed(self.created):
            try:
                item = self.inspect("container", identifier)
                need(item["Id"] == identifier and item["Image"] == self.image
                     and item["Config"]["Labels"].get("org.zenon.ci321.owner") == self.owner,
                     "RESOURCE_CHANGED")
                self.record_state(item, "before_stop")
                # The exact created resource was just verified; logs remain
                # private and only finite failure codes enter the manifest.
                try:
                    output = self.call("logs", "--tail", "80", identifier)
                    stderr = bytes(self.commands.originals[-1].drains[1].data)
                    self.diagnostics.extend(node_diagnostics(output + b"\n" + stderr))
                except Exception:
                    pass
                self.call("stop", "--time", "20", identifier, timeout=30)
                item = self.inspect("container", identifier)
                self.record_state(item, "after_stop")
                state = item["State"]
                need(state["Running"] is False and state["ExitCode"] == 0
                     and state.get("OOMKilled") is False, "STOP_UNKNOWN")
            except Exception:
                failed = True
        need(not failed and len(self.started) == len(self.created) == 5, "STOP_UNKNOWN")


def observe(runtime, root, report=None):
    def phase(name):
        if report is not None:
            report["runtime_phase"] = name

    phase("rpc_readiness")
    end = time.monotonic() + 90
    while True:
        runtime.healthy()
        try:
            with socket.create_connection(("127.0.0.1", 45997), timeout=1):
                break
        except OSError:
            need(time.monotonic() < end, "RPC_UNAVAILABLE")
            time.sleep(2)
    http_wire, ws_wire = make_transports()
    limits = wire_policy.Limits()
    deadline = wire_policy._Deadline(time.monotonic, time.monotonic() + 230)
    http = wire_policy.HttpRpc(http_wire, limits, deadline, secrets.token_bytes)
    ws = wire_policy.WsRpc(ws_wire, limits, deadline, secrets.token_bytes)
    original_failed = False
    try:
        phase("ws_handshake")
        ws.connect()
        phase("http_genesis")
        genesis = http.call("ledger.getMomentumsByHeight", [1, 1])
        need(type(genesis) is dict and type(genesis.get("list")) is list
             and len(genesis["list"]) == 1, "GENESIS_MISMATCH")
        first_genesis = wire_policy.Momentum.parse(genesis["list"][0])
        need(first_genesis.height == 1, "GENESIS_MISMATCH")
        phase("ws_genesis")
        need(wire_policy.Momentum.parse(ws.call("ledger.getMomentumByHash", [first_genesis.hash]))
             == first_genesis, "GENESIS_MISMATCH")
        phase("first_frontier")
        first = previous = wire_policy.Momentum.parse(http.call("ledger.getFrontierMomentum", []))
        phase("advancing_frontier")
        samples = 0
        for _ in range(36):
            runtime.healthy()
            sample_storage(root)
            current = wire_policy.Momentum.parse(http.call("ledger.getFrontierMomentum", []))
            current.follows(previous)
            peer = wire_policy.Momentum.parse(ws.call("ledger.getMomentumByHash", [current.hash]))
            need(peer == current, "RPC_REFUSED")
            samples += 1
            if current.height > first.height and current.timestamp > first.timestamp:
                return dict(chain=321, genesis_hash=first_genesis.hash,
                    first_height=first.height, last_height=current.height,
                    first_timestamp=first.timestamp, last_timestamp=current.timestamp,
                    samples=samples, cross_transport_hash_equal=True)
            previous = current
            time.sleep(5)
        raise Failure("PRODUCTION_UNPROVEN")
    except BaseException:
        original_failed = True
        raise
    finally:
        failed = False
        for original in (ws, http):
            try:
                original.close()
            except Exception:
                failed = True
        if failed:
            if report is not None:
                report["error_codes"].append("CLOSE_UNKNOWN")
            if not original_failed:
                raise Failure("CLOSE_UNKNOWN")


def run(backend):
    repo = Path(__file__).absolute().parents[2]
    parent = os.environ
    need(parent.get("GITHUB_ACTIONS") == "true" and parent.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
         and parent.get("SYRIUS_HOSTED_RUNNER") == "github-hosted"
         and parent.get("GITHUB_REPOSITORY") in ("edgepillar/syrius", "sol-znn/syrius")
         and re.fullmatch("[a-f0-9]{40}", parent.get("GITHUB_SHA", "")), "ENVIRONMENT_REFUSED")
    need((backend == "docker" and sys.platform == "linux")
         or (backend == "native" and sys.platform == "win32"), "ENVIRONMENT_REFUSED")
    directories(repo)
    temp = Path(parent["RUNNER_TEMP"])
    directories(temp)
    need(shutil.disk_usage(temp).free >= FIXTURE_MIN_FREE + MAX_WORK, "STORAGE_REFUSED")
    nonce = secrets.token_hex(12)
    root = temp / ("syrius-chain321-" + nonce)
    root.mkdir(mode=0o700)
    env = child_environment(root, parent)
    commands = Commands(root, env)
    report = dict(schema=1, scope="hosted_chain321_lab", backend=backend,
        application_sha=parent["GITHUB_SHA"], node_sha=NODE_SHA,
        run_id=parent.get("GITHUB_RUN_ID"), attempt=parent.get("GITHUB_RUN_ATTEMPT"),
        success=False, error_codes=[], checks=dict.fromkeys(
            ("source", "build", "assets", "preflight", "started", "production", "stopped", "inputs_unchanged"), False),
        wallet_qualified=False, seed_admitted=False, visual_matches=0,
        min_free_bytes=FIXTURE_MIN_FREE, work_cap_bytes=MAX_WORK,
        storage_limit_scope="isolated_hosted_regression_fixture_cooperative_samples",
        cleanup="runner_lifecycle_not_qualified")
    runtime = None
    try:
        source = repo / ".harness/ci-node-source"
        directories(source)
        need(commands.git(repo, "rev-parse", "HEAD") == parent["GITHUB_SHA"]
             and not commands.git(repo, "status", "--porcelain=v1", "--untracked-files=all")
             and commands.git(source, "rev-parse", "HEAD") == NODE_SHA
             and not commands.git(source, "status", "--porcelain=v1", "--untracked-files=all"), "SOURCE_REFUSED")
        report["application_tree"] = commands.git(repo, "rev-parse", "HEAD^{tree}")
        report["node_tree"] = commands.git(source, "rev-parse", "HEAD^{tree}")
        report["checks"]["source"] = True
        version = commands.run(["go", "version"], cwd=source).decode("ascii").strip()
        need(version == "go version go" + GO_VERSION + (" windows/amd64" if backend == "native" else " linux/amd64"),
             "SOURCE_REFUSED")
        report["compiler"] = version
        target = commands.run(["gcc", "-dumpmachine"], cwd=source).decode("ascii").strip()
        c_version = commands.run(["gcc", "-dumpfullversion"], cwd=source).decode("ascii").strip()
        need(target == ("x86_64-w64-mingw32" if backend == "native" else "x86_64-linux-gnu")
             and re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", c_version), "SOURCE_REFUSED")
        report["c_compiler"] = dict(target=target, version=c_version, cgo_enabled=True)
        binary = root / ("znnd.exe" if backend == "native" else "znnd")
        commands.run(["go", "build", "-trimpath", "-buildvcs=false", "-mod=readonly",
                      "-tags=netgo,osusergo", "-ldflags=-linkmode=external -extldflags=-static",
                      "-o", str(binary), "./cmd/znnd"],
                     cwd=source, timeout=1200)
        binary_bytes = regular(binary, 128 * MIB)
        if backend == "docker":
            report["static_linux_binary_verified"] = static_linux_binary(binary_bytes)
        report["binary_sha256"] = digest(binary_bytes)
        report["checks"]["build"] = True
        assets = root / "assets"
        commands.run(["node", str(repo / "tools/devnet/lab/make-assets.js"),
                      str(source / "docker/devnet"), str(assets)], cwd=repo)
        genesis = regular(assets / "genesis.json")
        need(json.loads(genesis)["ChainIdentifier"] == 321, "CONFIG_REFUSED")
        report["genesis_sha256"] = digest(genesis)
        configs, pins, keyfile_pins = {}, {}, {}
        report["keyfile_relocations"] = []
        for role in ROLES:
            data = root / role
            data.mkdir(mode=0o700)
            configs[role] = data
            value = configuration(json.loads(regular(source / "docker/devnet" / role / "config.json")), role, data, backend)
            (data / "config.json").write_text(json.dumps(value, indent=2) + "\n")
            (data / "genesis.json").write_bytes(genesis)
            for name in ("network-private-key", "wallet"):
                offered = assets / role / name
                if offered.is_dir():
                    (data / name).mkdir(mode=0o700)
                    for item in offered.iterdir():
                        original_keyfile = regular(item)
                        node_path = ("/data/wallet/" + item.name if backend == "docker"
                                     else str(data / name / item.name))
                        moved_keyfile = relocated_keyfile(original_keyfile, item.name, node_path)
                        destination = data / name / item.name
                        destination.write_bytes(moved_keyfile)
                        keyfile_pins[destination] = digest(moved_keyfile)
                        original_fields = json.loads(original_keyfile)
                        moved_fields = json.loads(moved_keyfile)
                        need({key: value for key, value in original_fields.items() if key != "Path"}
                             == {key: value for key, value in moved_fields.items() if key != "Path"},
                             "CONFIG_REFUSED")
                        report["keyfile_relocations"].append(dict(role=role,
                            source_sha256=digest(original_keyfile), deployed_sha256=digest(moved_keyfile),
                            non_path_fields_unchanged=True))
                elif offered.exists():
                    (data / name).write_bytes(regular(offered))
            pins[role] = digest(regular(data / "config.json"))
        report["config_sha256"] = pins
        report["checks"]["assets"] = True
        preflight_ports(backend)
        report["checks"]["preflight"] = True
        runtime = (Docker(commands, binary, configs, nonce) if backend == "docker"
                   else Native(commands, binary, configs))
        runtime.start()
        report["checks"]["started"] = True
        report["observations"] = observe(runtime, root, report)
        report["checks"]["production"] = True
        need(all(digest(regular(configs[role] / "config.json")) == pins[role]
                 and regular(configs[role] / "genesis.json") == genesis for role in ROLES)
             and all(digest(regular(path)) == expected for path, expected in keyfile_pins.items())
             and digest(regular(binary, 128 * MIB)) == report["binary_sha256"]
             and not commands.git(repo, "status", "--porcelain=v1", "--untracked-files=all")
             and not commands.git(source, "status", "--porcelain=v1", "--untracked-files=all"), "SOURCE_REFUSED")
        report["checks"]["inputs_unchanged"] = True
    except (Exception, KeyboardInterrupt) as error:
        report["error_codes"].append(failure_code(error))
    finally:
        if runtime is not None:
            try:
                runtime.stop()
                report["checks"]["stopped"] = True
            except Exception:
                report["error_codes"].append("STOP_UNKNOWN")
        report["commands"] = [item.receipt for item in commands.originals]
        if isinstance(runtime, Native):
            report["node_exits"] = [item.receipt for item in runtime.originals]
        elif isinstance(runtime, Docker):
            report["docker_image_id"] = runtime.image
            report["created_count"] = len(runtime.created)
            report["started_count"] = len(runtime.started)
            report["docker_states"] = runtime.states
            report["node_diagnostics"] = sorted(set(runtime.diagnostics))
            report["direct_rpc_ready"] = runtime.direct_rpc_ready
            report["loopback_relay"] = None if runtime.relay is None else runtime.relay.summary()
        report["success"] = all(report["checks"].values()) and not report["error_codes"]
        output = repo / ".harness/ci-chain321"
        output.mkdir(mode=0o700)
        with (output / "manifest.json").open("x", encoding="ascii") as stream:
            json.dump(report, stream, sort_keys=True, separators=(",", ":"))
            stream.write("\n")
        print(json.dumps(report, sort_keys=True))
    return 0 if report["success"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Isolated hosted chain-321 lab")
    parser.add_argument("--backend", required=True, choices=("docker", "native"))
    options = parser.parse_args()
    try:
        sys.exit(run(options.backend))
    except (Exception, KeyboardInterrupt) as error:
        print(json.dumps(dict(schema=1, success=False,
            error_codes=[error.code if isinstance(error, Failure) else "INTERNAL_ERROR"])))
        sys.exit(1)
