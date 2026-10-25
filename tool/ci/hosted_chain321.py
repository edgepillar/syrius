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
import subprocess
import sys
import time

from tool.ci.windows_presentation_smoke import OutputDrain
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
CODES = frozenset((
    "ENVIRONMENT_REFUSED", "SOURCE_REFUSED", "STORAGE_REFUSED",
    "COMMAND_FAILED", "COMMAND_TIMEOUT", "OUTPUT_REFUSED", "STOP_UNKNOWN",
    "CONFIG_REFUSED", "PORT_CONFLICT", "NODE_EXITED", "RPC_UNAVAILABLE",
    "RPC_REFUSED", "GENESIS_MISMATCH", "PRODUCTION_UNPROVEN",
    "DOCKER_REFUSED", "RESOURCE_CHANGED", "INTERNAL_ERROR",
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
               GOTOOLCHAIN="local", CGO_ENABLED="0", USER="ci",
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
            forced=self.forced, streams={key: dict(bytes=d.count,
                retained_bytes=len(d.data), sha256=digest(bytes(d.data)),
                overflow=d.overflow.is_set()) for key, d in zip(
                    ("stdout", "stderr"), self.drains)})
        need(complete and all(not d.overflow.is_set() and d.error is None
                              for d in self.drains), "OUTPUT_REFUSED")
        if success:
            need(code == 0 and not self.forced, "COMMAND_FAILED")
        return bytes(self.drains[0].data)

    def stop(self):
        if self.receipt is not None:
            return
        if self.process.poll() is None:
            try:
                self.process.send_signal(signal.CTRL_BREAK_EVENT if sys.platform == "win32"
                                         else signal.SIGINT)
                self.process.wait(timeout=30)
            except (OSError, subprocess.TimeoutExpired):
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
    rpc.update(EnableHTTP=role == "rpc", EnableWS=role == "rpc",
        HTTPHost="0.0.0.0" if backend == "docker" else "127.0.0.1",
        WSHost="0.0.0.0" if backend == "docker" else "127.0.0.1",
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
        for original in reversed(self.originals):
            try:
                original.stop()
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
        shutil.copyfile(self.binary, context / "znnd")
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
            if role == "rpc":
                args += ["-p", "127.0.0.1:45997:35997", "-p", "127.0.0.1:45998:35998"]
            args += [self.image, "--data", "/data", "--config", "/data/config.json",
                     "--genesis", "/data/genesis.json", "--wallet", "/data/wallet"]
            identifier = self.call(*args).decode().strip()
            need(re.fullmatch("[a-f0-9]{64}", identifier), "DOCKER_REFUSED")
            self.created.append(identifier)
            self.call("start", identifier)
            self.started.append(identifier)
        self.healthy()

    def healthy(self):
        need(len(self.created) == len(self.started) == 5, "RESOURCE_CHANGED")
        network = self.inspect("network", self.network)
        need(network["Id"] == self.network and network["Internal"] is True
             and set(network["Containers"]) == set(self.created), "RESOURCE_CHANGED")
        for identifier in self.started:
            item = self.inspect("container", identifier)
            need(item["Id"] == identifier and item["Image"] == self.image
                 and item["Config"]["Labels"].get("org.zenon.ci321.owner") == self.owner
                 and item["State"]["Running"] is True and item["RestartCount"] == 0,
                 "RESOURCE_CHANGED")

    def stop(self):
        failed = False
        for identifier in reversed(self.created):
            try:
                item = self.inspect("container", identifier)
                need(item["Id"] == identifier and item["Image"] == self.image
                     and item["Config"]["Labels"].get("org.zenon.ci321.owner") == self.owner,
                     "RESOURCE_CHANGED")
                self.call("stop", "--time", "20", identifier, timeout=30)
                state = self.inspect("container", identifier)["State"]
                need(state["Running"] is False and state["ExitCode"] == 0
                     and state.get("OOMKilled") is False, "STOP_UNKNOWN")
            except Exception:
                failed = True
        need(not failed and len(self.started) == len(self.created) == 5, "STOP_UNKNOWN")


def observe(runtime, root):
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
    try:
        ws.connect()
        genesis = http.call("ledger.getMomentumsByHeight", [1, 1])
        need(type(genesis) is dict and type(genesis.get("list")) is list
             and len(genesis["list"]) == 1, "GENESIS_MISMATCH")
        first_genesis = wire_policy.Momentum.parse(genesis["list"][0])
        need(first_genesis.height == 1, "GENESIS_MISMATCH")
        need(wire_policy.Momentum.parse(ws.call("ledger.getMomentumByHash", [first_genesis.hash]))
             == first_genesis, "GENESIS_MISMATCH")
        first = previous = wire_policy.Momentum.parse(http.call("ledger.getFrontierMomentum", []))
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
    finally:
        failed = False
        for original in (ws, http):
            try:
                original.close()
            except Exception:
                failed = True
        need(not failed, "RPC_REFUSED")


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
        binary = root / ("znnd.exe" if backend == "native" else "znnd")
        commands.run(["go", "build", "-trimpath", "-mod=readonly", "-o", str(binary), "./cmd/znnd"],
                     cwd=source, timeout=1200)
        report["binary_sha256"] = digest(regular(binary, 128 * MIB))
        report["checks"]["build"] = True
        assets = root / "assets"
        commands.run(["node", str(repo / "tools/devnet/lab/make-assets.js"),
                      str(source / "docker/devnet"), str(assets)], cwd=repo)
        genesis = regular(assets / "genesis.json")
        need(json.loads(genesis)["ChainIdentifier"] == 321, "CONFIG_REFUSED")
        report["genesis_sha256"] = digest(genesis)
        configs, pins = {}, {}
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
                        (data / name / item.name).write_bytes(regular(item))
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
        report["observations"] = observe(runtime, root)
        report["checks"]["production"] = True
        need(all(digest(regular(configs[role] / "config.json")) == pins[role]
                 and regular(configs[role] / "genesis.json") == genesis for role in ROLES)
             and digest(regular(binary, 128 * MIB)) == report["binary_sha256"]
             and not commands.git(repo, "status", "--porcelain=v1", "--untracked-files=all")
             and not commands.git(source, "status", "--porcelain=v1", "--untracked-files=all"), "SOURCE_REFUSED")
        report["checks"]["inputs_unchanged"] = True
    except (Exception, KeyboardInterrupt) as error:
        report["error_codes"].append(error.code if isinstance(error, (Failure, wire_policy.Refused))
                                      and error.code in CODES else "INTERNAL_ERROR")
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
