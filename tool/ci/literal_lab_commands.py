"""Observe the original lab.sh commands in a fresh, non-secret hosted fixture."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import sys
import time

from tool.ci import hosted_chain321 as hosted

MIB, GIB = 1024**2, 1024**3
NODE = '590f43ca7a24dccd8e883bc8903a0cb02e54528a'
NODE_TREE = '3bedc2fde71035c983997451c2d7e76b66d2d210'
PROJECT = 'syrius-lab'
ROLES = ('pillar', 'pillar2', 'pillar3', 'observer', 'rpc')
PINS = {
    'lab.sh': 'efb63da127bee3a9d5dc0b8f9abc0fb8beebe91afda38d066e215ae9da1dae8a',
    'docker-compose.yml': '0100e958abd79d03bd125ce7fd042b9f3bb78cda8b69a17502beadb99ed4cef9',
    'make-assets.js': 'bf2a2f20f780b384b2cd0d0e04cb8eff217b671373b0025435bded07b56fbebb',
    'frontier.js': 'd43aad19cf583b72f6615b96069c4e39e617587a5afaedc9ea07f6b2c2f1a76d',
}
CODES = frozenset(('ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'STORAGE_REFUSED',
    'RESOURCE_CHANGED', 'CHAIN_REFUSED', 'COMMAND_FAILED', 'COMMAND_TIMEOUT',
    'OUTPUT_REFUSED', 'STOP_UNKNOWN', 'INTERNAL_ERROR'))


class Refused(Exception):
    def __init__(self, code):
        self.code = code if code in CODES else 'INTERNAL_ERROR'
        super().__init__(self.code)


def need(value, code):
    if not value:
        raise Refused(code)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def admit(parent, platform):
    need(platform == 'linux' and parent.get('GITHUB_ACTIONS') == 'true'
        and parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
        and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
        and parent.get('SYRIUS_LITERAL_LAB') == 'true'
        and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
        and parent.get('GITHUB_REF') == 'refs/heads/redesign'
        and re.fullmatch('[a-f0-9]{40}', parent.get('GITHUB_SHA', ''))
        and re.fullmatch('[1-9][0-9]{0,19}', parent.get('GITHUB_RUN_ID', ''))
        and parent.get('GITHUB_RUN_ATTEMPT') == '1', 'ENVIRONMENT_REFUSED')


def frontier(raw):
    need(type(raw) is bytes and len(raw) <= 2 * MIB, 'OUTPUT_REFUSED')
    rows = raw.decode('utf-8', 'strict').splitlines()
    markers = [row for row in rows if row.startswith('chain ')]
    need(len(markers) == 1 and len(rows) >= 2
        and rows[-2:] == [markers[0], 'producing'], 'CHAIN_REFUSED')
    match = re.fullmatch(r'chain 321: ([0-9]{1,16}) then ([0-9]{1,16}) after ([0-9]{1,3}) s', markers[0])
    need(match is not None, 'CHAIN_REFUSED')
    first, last, seconds = map(int, match.groups())
    need(0 <= first < last <= 2**53 - 1 and 0 <= seconds <= 270, 'CHAIN_REFUSED')
    return dict(chain_id=321, first_height=first, last_height=last, seconds=seconds)


def failed_frontier(raw):
    """Retain only an exact stopped-progress line, never an RPC error string."""
    value = dict(status='UNAVAILABLE')
    if type(raw) is not bytes or len(raw) > 2 * MIB:
        return value
    rows = raw.decode('utf-8', 'replace').splitlines()
    markers = [row for row in rows if row.startswith('chain ')]
    if len(markers) != 1 or rows[-2:] != [markers[0], 'NOT producing']:
        return value
    match = re.fullmatch(r'chain 321: ([0-9]{1,16}) then ([0-9]{1,16}) after ([0-9]{1,3}) s', markers[0])
    if match is None:
        return value
    first, last, seconds = map(int, match.groups())
    if not (0 <= first == last <= 2**53 - 1 and 0 <= seconds <= 270):
        return value
    return dict(status='STALLED', chain_id=321, first_height=first,
        last_height=last, seconds=seconds)


def json_value(raw):
    need(type(raw) is bytes and len(raw) <= 2 * MIB, 'OUTPUT_REFUSED')
    def pairs(items):
        value = {}
        for key, item in items:
            need(key not in value, 'RESOURCE_CHANGED')
            value[key] = item
        return value
    return json.loads(raw, object_pairs_hook=pairs)


def containers(raw, image, assets):
    rows = json_value(raw)
    need(type(rows) is list and len(rows) == 5, 'RESOURCE_CHANGED')
    result = {}
    for row in rows:
        labels, state = row['Config']['Labels'], row['State']
        role = labels.get('com.docker.compose.service')
        identity = row['Id']
        started, pid = state['StartedAt'], state['Pid']
        need(role in ROLES and role not in result and type(identity) is str
            and re.fullmatch('[a-f0-9]{64}', identity)
            and labels.get('com.docker.compose.project') == PROJECT
            and row['Name'] == '/syrius-lab-' + role and row['Image'] == image
            and state['Running'] is True and state['Paused'] is False
            and state['Dead'] is False and state['OOMKilled'] is False
            and state['Status'] == 'running' and type(row['RestartCount']) is int
            and row['RestartCount'] == 0 and type(pid) is int and pid > 0
            and type(started) is str and re.fullmatch(
                r'20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,9})?Z', started),
            'RESOURCE_CHANGED')
        ports = row['NetworkSettings']['Ports'] or {}
        published = {key: value for key, value in ports.items() if value}
        expected = {} if role != 'rpc' else {
            '35997/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45997'}],
            '35998/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '45998'}],
        }
        need(published == expected, 'RESOURCE_CHANGED')
        networks = row['NetworkSettings']['Networks']
        need(set(networks) == {PROJECT} and networks[PROJECT]['IPAddress']
            == '172.37.0.' + str(hosted.OCTETS[role]), 'RESOURCE_CHANGED')
        mounts = row['Mounts']
        asset = [m for m in mounts if m['Destination'] == '/devnet']
        data = [m for m in mounts if m['Destination'] == '/root/.znn']
        need(len(mounts) == 2 and len(asset) == len(data) == 1
            and asset[0]['Type'] == 'bind' and asset[0]['RW'] is False
            and asset[0]['Source'] == str(assets)
            and data[0]['Type'] == 'volume' and data[0]['RW'] is True
            and data[0]['Name'] == PROJECT + '_' + role + '-data', 'RESOURCE_CHANGED')
        result[role] = (identity, started, pid)
    need(len({value[0] for value in result.values()}) == 5, 'RESOURCE_CHANGED')
    return result


def exits(raw, owned):
    need(type(raw) is bytes and len(raw) <= 2 * MIB, 'OUTPUT_REFUSED')
    rows = raw.splitlines()
    need(len(rows) <= 2000, 'OUTPUT_REFUSED')
    roles = {value[0]: role for role, value in owned.items()}
    result = {}
    for line in rows:
        row = json_value(line)
        identity = row.get('Actor', {}).get('ID')
        if identity not in roles:
            continue
        need(row.get('Type') == 'container' and row.get('Action') != 'oom', 'STOP_UNKNOWN')
        if row.get('Action') != 'die':
            continue
        role = roles[identity]
        labels = row['Actor']['Attributes']
        need(role not in result and labels.get('exitCode') == '0'
            and labels.get('name') == 'syrius-lab-' + role
            and labels.get('com.docker.compose.project') == PROJECT
            and labels.get('com.docker.compose.service') == role, 'STOP_UNKNOWN')
        result[role] = 0
    need(set(result) == set(ROLES), 'STOP_UNKNOWN')
    return result


def exit_facts(raw, owned):
    """Diagnostic facts do not replace the unchanged strict exit admission."""
    result = {role: dict(die_count=0, exit_codes=[], exit_code_count=0, oom=False)
        for role in ROLES}
    roles = {value[0]: role for role, value in owned.items()}
    codes = {role: set() for role in ROLES}
    try:
        need(type(raw) is bytes and len(raw) <= 2 * MIB
            and len(raw.splitlines()) <= 2000, 'OUTPUT_REFUSED')
        for line in raw.splitlines():
            row = json_value(line)
            identity = row.get('Actor', {}).get('ID')
            if type(identity) is not str or identity not in roles:
                continue
            role = roles[identity]
            need(row.get('Type') == 'container', 'STOP_UNKNOWN')
            if row.get('Action') == 'oom':
                result[role]['oom'] = True
            if row.get('Action') != 'die':
                continue
            labels = row['Actor']['Attributes']
            need(labels.get('com.docker.compose.project') == PROJECT
                and labels.get('com.docker.compose.service') == role
                and labels.get('name') == 'syrius-lab-' + role, 'STOP_UNKNOWN')
            value = labels.get('exitCode')
            need(type(value) is str and re.fullmatch('[0-9]{1,3}', value)
                and 0 <= int(value) <= 255, 'STOP_UNKNOWN')
            result[role]['die_count'] += 1
            codes[role].add(int(value))
        for role in ROLES:
            result[role].update(exit_codes=sorted(codes[role])[:4],
                exit_code_count=len(codes[role]))
        return dict(status='OBSERVED', roles=result)
    except Exception:
        return dict(status='REFUSED', roles={})


def failure_logs(commands, owned):
    """Read bounded original-container logs without exporting raw messages."""
    result = {}
    for role in ROLES:
        try:
            commands.run('node_failure_logs', ['docker', 'logs', '--tail', '64', owned[role][0]])
            output = b'\n'.join(bytes(drain.data) for drain in commands.originals[-1].drains)
            result[role] = dict(status='READ', codes=hosted.node_diagnostics(output)[:4])
        except Exception as error:
            result[role] = dict(status='UNAVAILABLE', code=code(error))
    return result


class Commands:
    """Bound original process groups; keep raw output private and receipts finite."""
    def __init__(self, repo, root, lab, env, report):
        self.repo, self.root, self.lab, self.env, self.report = repo, root, lab, env, report
        self.initial_free = shutil.disk_usage(root).free
        self.originals = []
        self.objects = root / 'objects'
        self.objects.mkdir(mode=0o700)
        info = self.objects.lstat()
        self.object_identity = (info.st_dev, info.st_ino)
        self.identities = {}
        for path in (root, lab):
            hosted.directories(path)
            info = path.lstat()
            self.identities[path] = (info.st_dev, info.st_ino)

    def sample(self):
        # Only this fresh hosted regression fixture uses the declared 2 GiB floor.
        # Sampling is conservative and cooperative, not an OS-enforced disk quota.
        hosted.directories(self.lab)
        info = self.lab.lstat()
        need((info.st_dev, info.st_ino) == self.identities[self.lab], 'STORAGE_REFUSED')
        free = shutil.disk_usage(self.root).free
        need(free >= 2 * GIB and self.initial_free - free <= 4 * GIB, 'STORAGE_REFUSED')
        total, count = 0, 0
        for root in (self.root, self.lab / '.build', self.lab / 'assets'):
            if not os.path.lexists(root):
                need(root not in self.identities, 'STORAGE_REFUSED')
                continue
            hosted.directories(root)
            info = root.lstat()
            identity = (info.st_dev, info.st_ino)
            need(self.identities.setdefault(root, identity) == identity, 'STORAGE_REFUSED')
            for directory, dirs, names in os.walk(root, followlinks=False):
                for name in [*dirs, *names]:
                    path = Path(directory) / name
                    try:
                        info = path.lstat()
                    except FileNotFoundError:
                        continue
                    count += 1
                    need(count <= 100000 and not stat.S_ISLNK(info.st_mode)
                        and (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)),
                        'STORAGE_REFUSED')
                    if stat.S_ISREG(info.st_mode):
                        total += info.st_size
                        need(total <= 4 * GIB, 'STORAGE_REFUSED')

    def retain(self, original):
        hosted.directories(self.objects)
        info = self.objects.lstat()
        need((info.st_dev, info.st_ino) == self.object_identity, 'STORAGE_REFUSED')
        result = {}
        for name, drain in zip(('stdout', 'stderr'), original.drains):
            raw = bytes(drain.data)
            pin = digest(raw)
            path = self.objects / pin
            if not os.path.lexists(path):
                fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o400)
                with os.fdopen(fd, 'wb') as stream:
                    stream.write(raw)
            need(hosted.regular(path, 2 * MIB) == raw, 'STORAGE_REFUSED')
            result[name] = dict(sha256=pin, bytes=len(raw))
        return result

    def run(self, stage, argv, timeout=20):
        need(len(self.report['commands']) < 80, 'COMMAND_FAILED')
        row = dict(stage=stage, seconds=None, receipt=None, retained_objects={})
        self.report['commands'].append(row)
        original = hosted.Original(argv, cwd=self.repo, env=self.env, cap=2 * MIB)
        self.originals.append(original)
        start = time.monotonic()
        next_sample = start
        error = None
        try:
            while original.process.poll() is None:
                original.healthy()
                now = time.monotonic()
                need(now - start < timeout, 'COMMAND_TIMEOUT')
                if now >= next_sample:
                    self.sample()
                    next_sample = now + 2
                time.sleep(0.2)
        except BaseException as caught:
            error = caught
            if original.process.poll() is None:
                original.forced = True
                try:
                    os.killpg(original.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                original.process.wait(timeout=10)
        try:
            raw = original.finish(success=False)
        except BaseException as caught:
            if error is None:
                error = caught
            raw = b''
        finally:
            row.update(seconds=round(time.monotonic() - start, 3), receipt=original.receipt)
            if error is None and (original.receipt is None
                    or original.receipt['exit_code'] != 0 or original.receipt['forced']):
                error = Refused('COMMAND_FAILED')
            if stage == 'up' and error is not None:
                output = b'\n'.join(bytes(drain.data) for drain in original.drains)
                row['up_output_tags'] = [item for item in hosted.compiler_diagnostics(output)
                    if item['code'] != 'UNCLASSIFIED_BUILD_FAILURE']
            if stage == 'status' and error is not None:
                row['frontier_observation'] = failed_frontier(bytes(original.drains[0].data))
            try:
                row['retained_objects'] = self.retain(original)
            except Exception as caught:
                row['retention_code'] = code(caught)
                if error is None:
                    error = caught
        if error is not None:
            raise error
        need(original.receipt['exit_code'] == 0 and not original.receipt['forced'], 'COMMAND_FAILED')
        self.sample()
        return raw

    def git(self, path, *args):
        return self.run('source', ['git', '--no-pager', '-c', 'core.fsmonitor=false',
            '-c', 'core.hooksPath=' + os.devnull, '-C', str(path), *args]).decode('ascii').strip()

    def docker(self, *args):
        return self.run('docker_metadata', ['docker', *args])


def source(commands, repo, lab, head, tree=None):
    need(commands.git(repo, 'rev-parse', 'HEAD') == head
        and not commands.git(repo, 'status', '--porcelain=v1', '--untracked-files=all'),
        'SOURCE_REFUSED')
    actual = commands.git(repo, 'rev-parse', 'HEAD^{tree}')
    need(tree is None or actual == tree, 'SOURCE_REFUSED')
    for name, pin in PINS.items():
        need(digest(hosted.regular(lab / name)) == pin, 'SOURCE_REFUSED')
    return actual


def empty_project(commands):
    queries = [
        ('ps', '-a', '--filter', 'name=^/syrius-lab-', '--format', '{{.ID}}'),
        ('network', 'ls', '--filter', 'name=^syrius-lab$', '--format', '{{.ID}}'),
        ('volume', 'ls', '--filter', 'name=^syrius-lab_', '--format', '{{.Name}}'),
        ('image', 'ls', '--filter', 'reference=syrius-lab-znnd:*', '--format', '{{.ID}}'),
    ]
    for query in queries:
        need(not commands.docker(*query).strip(), 'RESOURCE_CHANGED')


def observe(commands, repo, lab, report):
    script = ['bash', str(lab / 'lab.sh')]
    owned, image = None, None
    report['source_tree'] = source(commands, repo, lab, report['source_sha'])
    empty_project(commands)
    report['checks']['fresh'] = True
    observation_failed = False
    try:
        report['up'] = frontier(commands.run('up', [*script, 'up'], 900))
        node = lab / '.build/go-zenon'
        need(commands.git(node, 'rev-parse', NODE + '^{commit}') == NODE
            and commands.git(node, 'rev-parse', NODE + '^{tree}') == NODE_TREE,
            'SOURCE_REFUSED')
        tag = hosted.regular(lab / '.build/revision', 80).decode('ascii').strip()
        need(re.fullmatch('[a-f0-9]{7,40}', tag) and NODE.startswith(tag), 'SOURCE_REFUSED')
        image = json_value(commands.docker('image', 'inspect', 'syrius-lab-znnd:' + tag,
            '--format', '{{json .Id}}'))
        need(type(image) is str and re.fullmatch('sha256:[a-f0-9]{64}', image), 'SOURCE_REFUSED')
        report['image_sha256'] = image.removeprefix('sha256:')
        genesis = hosted.regular(lab / 'assets/genesis.json')
        chain = json_value(genesis).get('ChainIdentifier')
        need(type(chain) is int and chain == 321, 'CHAIN_REFUSED')
        report['genesis_sha256'] = digest(genesis)
        names = ['syrius-lab-' + role for role in ROLES]
        owned = containers(commands.docker('inspect', *names), image, lab / 'assets')
        report['checks']['originals'] = True
        report['status'] = frontier(commands.run('status', [*script, 'status'], 45))
        need(report['status']['first_height'] >= report['up']['last_height'], 'CHAIN_REFUSED')
        report['checks']['production'] = True
    except Exception as error:
        observation_failed = True
        report['observation_code'] = code(error)
        raise
    finally:
        # A partial start is never adopted after an unknown or failed launch.
        # Preserve it for VM disposal; do not run a name-based cleanup on guesses.
        if owned is not None:
            try:
                names = ['syrius-lab-' + role for role in ROLES]
                current = containers(commands.docker('inspect', *names), image, lab / 'assets')
                need(current == owned, 'RESOURCE_CHANGED')
                if observation_failed:
                    report['node_failure_facts'] = failure_logs(commands, owned)
                    current = containers(commands.docker('inspect', *names), image, lab / 'assets')
                    need(current == owned, 'RESOURCE_CHANGED')
                since = str(max(0, int(time.time()) - 1))
                commands.run('down', [*script, 'down'], 45)
                until = str(int(time.time()) + 1)
                filters = [arg for value in owned.values()
                    for arg in ('--filter', 'container=' + value[0])]
                raw = commands.run('exit_events', ['docker', 'events', '--since', since,
                    '--until', until, '--filter', 'type=container', *filters,
                    '--format', '{{json .}}'], 20)
                report['exit_observations'] = exit_facts(raw, owned)
                report['exit_codes'] = exits(raw, owned)
                need(not commands.docker('ps', '-a', '--filter',
                    'name=^/syrius-lab-', '--format', '{{.ID}}').strip(), 'STOP_UNKNOWN')
                need(not commands.docker('network', 'ls', '--filter',
                    'name=^syrius-lab$', '--format', '{{.ID}}').strip(), 'STOP_UNKNOWN')
                report['checks']['stopped'] = True
            except Exception as error:
                report['close_code'] = code(error)
                if not observation_failed:
                    raise
        else:
            report['unadopted_start_held'] = True
    need(digest(hosted.regular(lab / 'assets/genesis.json')) == report['genesis_sha256'],
        'SOURCE_REFUSED')
    source(commands, repo, lab, report['source_sha'], report['source_tree'])
    report['checks']['source_after'] = True


def code(error):
    return error.code if isinstance(error, (Refused, hosted.Failure)) and error.code in CODES else 'INTERNAL_ERROR'


def notice_frames(report):
    """Keep every independently bound notice below the observed 4 KiB limit."""
    summary = dict(report)
    rows = summary.pop('commands')
    need(type(rows) is list and len(rows) <= 80, 'OUTPUT_REFUSED')
    binding = {key: report[key] for key in ('source_sha', 'source_tree', 'run_id', 'run_attempt')}
    def packet(items, index, count):
        return dict(schema=1, scope='literal_lab_command_receipts', **binding,
            command_count=len(rows), chunk_index=index, chunk_count=count, items=items)
    def encoded(value):
        return json.dumps(value, sort_keys=True, separators=(',', ':')).encode('ascii')
    chunks, current = [], []
    for index, row in enumerate(rows, 1):
        item = dict(index=index, command=row)
        if current and len(encoded(packet([*current, item], 80, 80))) > 3500:
            chunks.append(current)
            current = []
        current.append(item)
        need(len(encoded(packet(current, 80, 80))) <= 3500, 'OUTPUT_REFUSED')
    if current:
        chunks.append(current)
    summary.update(schema=2, command_count=len(rows), command_chunk_count=len(chunks))
    frames = [summary, *[packet(items, index, len(chunks))
        for index, items in enumerate(chunks, 1)]]
    need(len(frames) <= 50 and all(len(encoded(frame)) <= 3800 for frame in frames), 'OUTPUT_REFUSED')
    return frames


def main():
    report = dict(schema=1, scope='literal_lab_commands', success=False, code=None,
        source_sha=None, source_tree=None, run_id=None, run_attempt=None,
        observation_code=None, close_code=None, unadopted_start_held=False,
        node_failure_facts={}, exit_observations=None,
        node_sha=NODE, node_tree=NODE_TREE, commands=[], up=None, status=None,
        image_sha256=None, genesis_sha256=None, exit_codes={},
        checks=dict(fresh=False, originals=False, production=False, stopped=False, source_after=False),
        work_limit_bytes=4 * GIB, fixture_floor_bytes=2 * GIB, per_stream_bytes=2 * MIB,
        storage_scope='fresh_hosted_regression_cooperative_samples',
        volumes_preserved=True, vm_disposal_qualified=False, wallet_executions=0,
        flutter_sdk_executions=0, windows_docker_desktop_qualified=False,
        wallet_import_or_send_qualified=False)
    try:
        parent = dict(os.environ)
        admit(parent, sys.platform)
        report.update(source_sha=parent['GITHUB_SHA'], run_id=parent['GITHUB_RUN_ID'], run_attempt='1')
        repo = Path(parent['GITHUB_WORKSPACE'])
        lab = repo / 'tools/devnet/lab'
        hosted.directories(lab)
        need(not os.path.lexists(lab / '.build') and not os.path.lexists(lab / 'assets'), 'STORAGE_REFUSED')
        need(shutil.disk_usage(repo).free >= 6 * GIB, 'STORAGE_REFUSED')
        hosted.preflight_ports('docker')
        hidden = repo / '.harness'
        if not os.path.lexists(hidden):
            hidden.mkdir(mode=0o700)
        hosted.directories(hidden)
        root = hidden / 'ci-literal-lab'
        need(not os.path.lexists(root), 'STORAGE_REFUSED')
        root.mkdir(mode=0o700)
        env = hosted.child_environment(root, parent)
        env.update(GO_ZENON_URL='https://github.com/zenon-network/go-zenon.git',
            GO_ZENON_REV=NODE, LAB_RPC='http://127.0.0.1:45997')
        commands = Commands(repo, root, lab, env, report)
        observe(commands, repo, lab, report)
        report['success'] = all(report['checks'].values())
    except Exception as error:
        report['code'] = code(error)
    for frame in notice_frames(report):
        raw = json.dumps(frame, sort_keys=True, separators=(',', ':'))
        print('::notice title=Original lab commands::' + raw)
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
