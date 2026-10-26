"""Manual hosted-Windows Flutter debug loop; no wallet or chain admission.

Only finite receipts leave this controller. Flutter machine messages, VM service
authentication addresses, profile paths and process IDs remain private. DevTools
availability is recorded separately from a real frontend attachment.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import queue
import re
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time

try:
    from . import flutter_debug_protocol as protocol
    from . import windows_entry_capture_smoke as entry
    from .windows_debug_process import WindowsJob, ProcessRefused
except ImportError:
    import flutter_debug_protocol as protocol
    import windows_entry_capture_smoke as entry
    from windows_debug_process import WindowsJob, ProcessRefused


bounded = entry.bounded
OUTPUT = Path('.harness/ci-windows-debug')
EXIT_PREFIX = b'SYRIUS_DEBUG_TOOL_EXIT:'
CHECKS = ('environment', 'source', 'profile', 'preflight', 'job_owned',
          'tool_started', 'application_owned', 'ordinary_entry', 'service_bound',
          'breakpoint_hit', 'hot_reload', 'reload_state_preserved', 'hot_restart',
          'restart_state_reset', 'devtools_available', 'probe_closed',
          'frontend_job_owned', 'frontend_attached', 'frontend_exit',
          'close_ack', 'application_exit', 'tool_exit', 'output_complete', 'source_unchanged')
CODES = protocol.CODES | frozenset(('ENVIRONMENT_REFUSED', 'PROFILE_REFUSED',
    'SOURCE_REFUSED', 'TOOL_REFUSED', 'JOB_REFUSED', 'PROCESS_REFUSED',
    'APPLICATION_EXIT_UNCONFIRMED', 'TOOL_EXIT_UNCONFIRMED', 'PROBE_REFUSED',
    'PROBE_EXIT_UNCONFIRMED', 'ENTRY_REFUSED', 'READINESS_TIMEOUT', 'TOTAL_DEADLINE',
    'APPLICATION_EXIT_FAILED', 'INTERNAL_ERROR', 'FORCED_CLEANUP', 'ANALYSIS_FAILED',
    'CLOSE_UNCONFIRMED'))
DART_CODES = frozenset(('PID_REFUSED', 'ISOLATE_REFUSED', 'MARKER_REFUSED',
    'BREAKPOINT_REFUSED', 'SERVICE_OUTPUT_REFUSED', 'SERVICE_IO_REFUSED',
    'INPUT_REFUSED', 'CLOSE_UNCONFIRMED'))
CODES |= DART_CODES
FRONTEND_CODES = frozenset(('SOCKET_REPLACED', 'REQUEST_REFUSED', 'VM_REFUSED',
    'CDP_OUTPUT_REFUSED', 'CDP_RESPONSE_REFUSED', 'CDP_IO_REFUSED', 'CDP_COMMAND_UNCERTAIN',
    'BROWSER_REFUSED', 'BROWSER_TIMEOUT', 'FRONTEND_REFUSED', 'FRONTEND_UNCONFIRMED',
    'BROWSER_EXIT_UNCONFIRMED', 'FRONTEND_EXIT_UNCONFIRMED'))
CODES |= FRONTEND_CODES
FRONTEND_PHASES = frozenset(('new', 'admitted', 'browser_started', 'browser_socket_bound',
    'page_navigated', 'vm_matched', 'ui_ready', 'close_requested', 'browser_exited'))
FRONTEND_FLAGS = ('pageLoaded', 'documentReady', 'devtoolsTitle', 'webglIssue', 'wasmIssue',
    'frontendGetVmMatched', 'frontendSocketClosed', 'held', 'serviceSocketSeen')
FRONTEND_COUNTS = ('runtimeExceptions', 'networkFailures', 'workerTargets',
    'getVmRequests', 'getVmReplies', 'otherSockets')


def need(value, code):
    if not value:
        raise ProcessRefused(code)


class Lines:
    """One original output stream, capped in memory and drained to real EOF."""
    def __init__(self, stream):
        self.stream, self.items = stream, queue.Queue(128)
        self.count, self.digest = 0, hashlib.sha256()
        self.complete = self.overflow = self.failed = False
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()

    def _read(self):
        try:
            while True:
                raw = self.stream.readline(protocol.MAX_LINE + 1)
                if not raw:
                    self.complete = True
                    return
                self.count += len(raw)
                self.digest.update(raw)
                if (len(raw) > protocol.MAX_LINE or self.count > protocol.MAX_TOTAL
                        or self.overflow):
                    self.overflow = True
                    continue
                try:
                    self.items.put_nowait(raw)
                except queue.Full:
                    self.overflow = True
        except Exception:
            self.failed = True

    def take(self, seconds=.1):
        need(not self.overflow and not self.failed, 'OUTPUT_REFUSED')
        try:
            return self.items.get(timeout=max(0, seconds))
        except queue.Empty:
            return None

    def finish(self):
        self.thread.join(5)
        return self.complete and not self.thread.is_alive() and not self.failed and not self.overflow

    def public(self):
        return dict(bytes=self.count, sha256=self.digest.hexdigest(),
                    output_complete=self.complete and not self.failed,
                    overflow=self.overflow)


def sdk(parent):
    root = Path(parent.get('FLUTTER_ROOT', ''))
    need(root.is_absolute(), 'TOOL_REFUSED')
    paths = (root / 'bin/cache/dart-sdk/bin/dart.exe', root / 'bin/cache/flutter_tools.snapshot')
    for path in paths:
        need(path.is_file(), 'TOOL_REFUSED')
        bounded.plain(path)
    return paths


def profile_environment(parent, profile, port, token):
    env = entry.child_environment(parent, profile, port, token)
    for name in ('FLUTTER_ROOT', 'PUB_CACHE', 'PROGRAMFILES', 'PROGRAMFILES(X86)',
                 'PROGRAMW6432', 'GITHUB_ACTIONS', 'RUNNER_OS', 'RUNNER_ENVIRONMENT',
                 'GITHUB_SHA', 'GITHUB_WORKSPACE', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'):
        if name in parent:
            env[name] = parent[name]
    env.update(SYRIUS_WINDOWS_DEBUG_PROFILE=str(profile), FLUTTER_SUPPRESS_ANALYTICS='true',
               DART_SUPPRESS_ANALYTICS='true', CI='true')
    return env


def sdk_child():
    """The job owner must release this gate before any SDK process can exist."""
    parent, _ = entry.require_ci(os.environ, None, platform=os.name)
    profile = Path(parent.get('SYRIUS_WINDOWS_DEBUG_PROFILE', ''))
    need(profile.is_absolute() and parent.get('APPDATA') == str(profile / 'AppData/Roaming')
         and parent.get('HOME') == str(profile), 'PROFILE_REFUSED')
    need(os.read(0, 6) == b'START\n', 'JOB_REFUSED')
    dart, snapshot = sdk(parent)
    packages = Path(parent['FLUTTER_ROOT']) / 'packages/flutter_tools/.dart_tool/package_config.json'
    need(packages.is_file(), 'TOOL_REFUSED')
    bounded.plain(packages)
    # Match Flutter 3.47.7's Windows launcher while keeping the original SDK
    # process supervised directly, without a command-shell intermediary.
    original = subprocess.Popen([str(dart), '--packages=' + str(packages), str(snapshot),
        'run', '--machine', '--no-pub',
        '-d', 'windows', '--target', 'harness/app/main.dart',
        '--dart-define-from-file=.dart_tool/git_metadata.json'],
        shell=False, stdin=sys.stdin.buffer, stdout=sys.stdout.buffer, stderr=sys.stdout.buffer,
        env=parent, cwd=Path(parent['GITHUB_WORKSPACE']))
    code = original.wait()
    sys.stdout.buffer.write(EXIT_PREFIX + json.dumps(dict(exit=code)).encode() + b'\n')
    sys.stdout.buffer.flush()
    return code


class Tool:
    def __init__(self, original, lines):
        self.original, self.lines = original, lines
        self.protocol, self.exit = protocol.DaemonTranscript(), None

    def observe(self, seconds=.1):
        raw = self.lines.take(seconds)
        if raw is None:
            return
        if raw.startswith(EXIT_PREFIX):
            need(self.exit is None, 'TOOL_EXIT_UNCONFIRMED')
            value = json.loads(raw[len(EXIT_PREFIX):])
            need(type(value) is dict and set(value) == {'exit'} and type(value['exit']) is int,
                 'TOOL_EXIT_UNCONFIRMED')
            self.exit = value['exit']
        else:
            self.protocol.feed(raw)

    def until(self, predicate, seconds):
        deadline = time.monotonic() + seconds
        while not predicate():
            need(time.monotonic() < deadline, 'TOTAL_DEADLINE')
            self.observe(min(.1, max(0, deadline - time.monotonic())))
            need(not (self.original.poll() is not None and self.lines.complete
                      and self.lines.items.empty() and not predicate()), 'TOOL_EXIT_UNCONFIRMED')

    def command(self, method, *, full_restart=None, seconds=60):
        message = self.protocol.reserve(method, full_restart=full_restart)
        try:
            self.original.stdin.write(json.dumps([message], separators=(',', ':')).encode() + b'\n')
            self.original.stdin.flush()
            self.until(lambda: not self.protocol._pending, seconds)
        except Exception:
            if message['id'] in self.protocol._pending:
                self.protocol.uncertain(message['id'])
            raise


class Probe:
    def __init__(self, dart, repo, env):
        packages = repo / '.dart_tool/package_config.json'
        need(packages.is_file(), 'TOOL_REFUSED')
        bounded.plain(packages)
        self.original = subprocess.Popen([str(dart), '--disable-dart-dev',
            '--packages=' + str(packages),
            'tool/ci/windows_debug_service_probe.dart'], cwd=repo, env=env, shell=False,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
        self.lines = Lines(self.original.stdout)
        self.reserved = set()
        self.failure = None

    def command(self, action, tool, **values):
        need(action in ('bind', 'breakpoint', 'reload', 'restart', 'close')
             and action not in self.reserved, 'PROBE_REFUSED')
        self.reserved.add(action)
        self.original.stdin.write(json.dumps(dict(action=action, **values)).encode() + b'\n')
        self.original.stdin.flush()
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            tool.observe(0)
            raw = self.lines.take(.1)
            if raw is None:
                need(self.original.poll() is None or not self.lines.complete, 'PROBE_EXIT_UNCONFIRMED')
                continue
            try:
                value = json.loads(raw)
            except (ValueError, UnicodeError):
                self.failure = probe_line_observation(raw)
                raise ProcessRefused('PROBE_REFUSED') from None
            phase = 'bound' if action == 'bind' else 'closed' if action == 'close' else action
            if type(value) is dict and value.get('ok') is False and value.get('code') in CODES:
                raise ProcessRefused(value['code'])
            need(type(value) is dict and value.get('ok') is True and value.get('phase') == phase,
                 'PROBE_REFUSED')
            if action == 'bind':
                need(value == dict(ok=True, phase='bound', pidMatched=True, rootMatched=True,
                                   debugLoopQualified=False), 'PROBE_REFUSED')
            elif action == 'close':
                need(value == dict(ok=True, phase='closed'), 'PROBE_REFUSED')
            else:
                need(value == dict(ok=True, phase=phase, debugLoopQualified=False), 'PROBE_REFUSED')
            return
        raise ProcessRefused('PROBE_REFUSED')


def probe_line_observation(raw):
    """Classify only fixed startup shapes; preserve no line or private detail."""
    code = 'UNCLASSIFIED_OUTPUT'
    if raw.startswith((b'Resolving dependencies', b'Downloading packages')):
        code = 'PUB_RESOLUTION'
    elif raw.startswith(b'Building package executable'):
        code = 'PUB_EXECUTABLE_BUILD'
    elif raw.startswith(b'Unhandled exception:'):
        code = 'UNHANDLED_EXCEPTION'
    elif re.search(rb'\bError:', raw):
        code = 'COMPILE_OR_USAGE_ERROR'
    elif raw.startswith(b'The Dart VM service is listening'):
        code = 'VM_SERVICE_LISTENER'
    return dict(code=code, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())


def request_close(transport, token):
    """One ordinary close request; a lost acknowledgement is never retried."""
    try:
        reply = transport.exchange(dict(cmd='quit'), token, 5)
        value = json.loads(reply.body)
        need(reply.status == 200 and type(value) is dict and set(value) == {'ok'}
             and value['ok'] is True, 'CLOSE_UNCONFIRMED')
    except Exception:
        raise ProcessRefused('CLOSE_UNCONFIRMED') from None


class Frontend:
    def __init__(self, repo, env):
        node = shutil.which('node', path=env.get('PATH'))
        need(node is not None, 'BROWSER_REFUSED')
        bounded.plain(Path(node))
        self.original = subprocess.Popen([node, 'tool/ci/windows_devtools_frontend.mjs'],
            cwd=repo, env=env, shell=False, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, bufsize=0)
        self.lines = Lines(self.original.stdout)
        self.result = None

    def attach(self, tool, pid):
        data = json.dumps(dict(devtools=tool.protocol._devtools,
                               service=tool.protocol._service, pid=pid)).encode()
        need(len(data) <= 16378, 'ENDPOINT_REFUSED')
        self.original.stdin.write(b'START\n' + data + b'\n')
        self.original.stdin.flush()
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            tool.observe(0)
            raw = self.lines.take(.1)
            if raw is None:
                need(self.original.poll() is None or not self.lines.complete, 'FRONTEND_EXIT_UNCONFIRMED')
                continue
            value = json.loads(raw)
            fields = {'schema', 'ok', 'scope', 'attached', 'headless', 'browserExit',
                      'outputComplete', 'forced', 'code', 'outputBytes', 'outputSha256',
                      'phase', 'observations'}
            need(type(value) is dict and set(value) == fields and type(value['schema']) is int and value['schema'] == 1
                 and value['scope'] == 'owned_devtools_frontend'
                 and all(type(value[name]) is bool for name in
                         ('ok', 'attached', 'headless', 'outputComplete', 'forced'))
                 and type(value['outputBytes']) is int and 0 <= value['outputBytes'] <= 1024**2
                 and bounded.safe_digest(value['outputSha256'])
                 and (value['browserExit'] is None or type(value['browserExit']) is int)
                 and (value['code'] is None or value['code'] in CODES)
                 and value['phase'] in FRONTEND_PHASES, 'FRONTEND_REFUSED')
            observations = value['observations']
            need(type(observations) is dict and set(observations) == set(FRONTEND_FLAGS + FRONTEND_COUNTS)
                 and all(type(observations[key]) is bool for key in FRONTEND_FLAGS)
                 and all(type(observations[key]) is int and 0 <= observations[key] <= 1000
                         for key in FRONTEND_COUNTS), 'FRONTEND_REFUSED')
            self.result = value
            if value['code'] is not None:
                raise ProcessRefused(value['code'])
            need(value['ok'] and value['attached'] and value['headless']
                 and value['outputComplete'] and value['browserExit'] == 0 and not value['forced'],
                 'FRONTEND_UNCONFIRMED')
            need(value['phase'] == 'browser_exited' and not observations['held']
                 and all(observations[key] for key in ('documentReady', 'devtoolsTitle',
                         'frontendGetVmMatched', 'serviceSocketSeen'))
                 and observations['getVmRequests'] >= observations['getVmReplies'] >= 1,
                 'FRONTEND_UNCONFIRMED')
            need(self.original.wait(timeout=15) == 0 and self.lines.finish(), 'FRONTEND_EXIT_UNCONFIRMED')
            return
        raise ProcessRefused('FRONTEND_UNCONFIRMED')


def ready(tool, transport, token, seconds=45):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        tool.observe(0)
        try:
            reply = transport.exchange(dict(cmd='ping'), token, 1)
        except (OSError, TimeoutError):
            time.sleep(.1)
            continue
        need(reply.status == 200, 'ENTRY_REFUSED')
        value = json.loads(reply.body)
        need(type(value) is dict and value.get('ok') is True and value.get('harnessMode') == 'wallet'
             and type(value.get('pid')) is int and value['pid'] > 0, 'ENTRY_REFUSED')
        if value.get('booted') is True:
            return value['pid']
        time.sleep(.1)
    raise ProcessRefused('READINESS_TIMEOUT')


def analyze(parent, repo):
    dart, _ = sdk(parent)
    original = subprocess.Popen([str(dart), 'analyze', '--format', 'machine',
        'tool/ci/windows_debug_service_probe.dart', 'harness/app/main.dart'],
        cwd=repo, env=parent, shell=False, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
    lines = Lines(original.stdout)
    counts = dict(error=0, warning=0, info=0)
    locations = []
    failed = False
    deadline = time.monotonic() + 180
    try:
        while not (original.poll() is not None and lines.complete and lines.items.empty()):
            need(time.monotonic() < deadline, 'TOTAL_DEADLINE')
            raw = lines.take()
            if raw is not None:
                severity = raw.partition(b'|')[0].decode('ascii', errors='ignore').lower()
                if severity in counts:
                    counts[severity] += 1
                    fields = raw.decode('utf-8', errors='replace').rstrip('\r\n').split('|')
                    if len(fields) >= 7 and len(locations) < 16:
                        code, line, column = fields[2], fields[4], fields[5]
                        if (re.fullmatch(r'[A-Z][A-Z0-9_]{0,95}', code)
                                and line.isascii() and line.isdigit()
                                and column.isascii() and column.isdigit()):
                            relative = re.sub('/+', '/', fields[3].replace('\\', '/')).casefold()
                            selected = ('service_probe' if relative.endswith('/tool/ci/windows_debug_service_probe.dart')
                                        else 'harness_entry' if relative.endswith('/harness/app/main.dart') else 'other')
                            locations.append(dict(source=selected, code=code,
                                                  line=int(line), column=int(column)))
        code = original.wait(timeout=5)
        need(lines.finish() and code in (0, 1) and counts['error'] == counts['warning'] == 0,
             'ANALYSIS_FAILED')
    except Exception:
        failed = True
        if original.poll() is None:
            original.kill()
            original.wait(timeout=10)
        lines.finish()
        raise
    finally:
        value = dict(scope='debug_probe_analysis', actual_exit=original.returncode,
                     diagnostics=counts, locations=locations, failed=failed, **lines.public())
        public = json.dumps(value, sort_keys=True, separators=(',', ':'))
        print(public)
        if len(public.encode()) <= 3800:
            print('::notice title=Windows debug analysis::' + public)
    return 0


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments == ['--sdk-child']:
        return sdk_child()
    checks = dict.fromkeys(CHECKS, False)
    report = dict(schema=1, scope='ordinary_entry_debug_loop', checks=checks, errors=[],
                  success=False, debug_loop_qualified=False, wallet_qualified=False,
                  devtools_attached=False, seed_admitted=False, forced_cleanup=False)
    job = original = tool = probe = frontend = None
    output = None
    try:
        need(arguments in ([], ['--analyze']), 'ENVIRONMENT_REFUSED')
        parent, expected = entry.require_ci(os.environ, None, platform=os.name)
        repo = Path(parent['GITHUB_WORKSPACE'])
        need(repo.resolve() == Path.cwd().resolve(), 'ENVIRONMENT_REFUSED')
        checks['environment'] = True
        bounded.verify_source(repo, expected, parent)
        tree = entry.source_tree(repo, parent)
        report.update(source_sha=expected, source_tree=tree,
            run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        checks['source'] = True
        if arguments == ['--analyze']:
            return analyze(parent, repo)
        output = entry.private_root(repo) / OUTPUT.name
        output.mkdir(mode=0o700)
        bounded.check_no_existing(repo, parent)
        checks['preflight'] = True
        profile = entry.private_root(repo) / ('ci-windows-debug-' + secrets.token_hex(12))
        profile.mkdir(mode=0o700)
        for name in ('AppData/Roaming', 'AppData/Local', 'Temp', 'Config', 'Data', 'Cache'):
            (profile / name).mkdir(parents=True, mode=0o700)
        checks['profile'] = True
        token = secrets.token_urlsafe(32)
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as reservation:
            reservation.bind(('127.0.0.1', 0))
            port = reservation.getsockname()[1]
        env = profile_environment(parent, profile, port, token)
        dart, _ = sdk(parent)
        job = WindowsJob()
        original = subprocess.Popen([sys.executable, '-B', str(Path(__file__).absolute()), '--sdk-child'],
            cwd=repo, env=env, shell=False, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, bufsize=0)
        job.assign(original)
        checks['job_owned'] = True
        tool = Tool(original, Lines(original.stdout))
        original.stdin.write(b'START\n')
        original.stdin.flush()
        tool.until(lambda: tool.protocol._started, 900)
        checks['tool_started'] = True
        transport = bounded.LoopbackTransport(port, 32768)
        pid = ready(tool, transport, token)
        binary = repo / bounded.BINARY
        job.bind_application(pid, binary)
        checks['application_owned'] = checks['ordinary_entry'] = True
        probe = Probe(dart, repo, env)
        probe.command('bind', tool, pid=pid, wsUri=tool.protocol._service)
        checks['service_bound'] = True
        probe.command('breakpoint', tool)
        checks['breakpoint_hit'] = True
        tool.command('app.restart', full_restart=False)
        checks['hot_reload'] = True
        probe.command('reload', tool)
        checks['reload_state_preserved'] = True
        tool.command('app.restart', full_restart=True)
        checks['hot_restart'] = True
        need(ready(tool, transport, token) == pid, 'PROCESS_REFUSED')
        probe.command('restart', tool)
        checks['restart_state_reset'] = True
        tool.until(lambda: tool.protocol._devtools is not None, 45)
        checks['devtools_available'] = True
        probe.command('close', tool)
        need(probe.original.wait(timeout=15) == 0 and probe.lines.finish(), 'PROBE_EXIT_UNCONFIRMED')
        checks['probe_closed'] = True
        frontend = Frontend(repo, env)
        job.assign(frontend.original)
        checks['frontend_job_owned'] = True
        frontend.attach(tool, pid)
        checks['frontend_attached'] = checks['frontend_exit'] = True
        report['devtools_attached'] = True
        report['close_attempted'] = True
        request_close(transport, token)
        checks['close_ack'] = True
        need(job.application_exit() == 0, 'APPLICATION_EXIT_FAILED')
        checks['application_exit'] = True
        tool.until(lambda: tool.exit is not None and tool.protocol._stopped, 20)
        need(original.wait(timeout=10) == 0 and tool.exit == 0, 'TOOL_EXIT_UNCONFIRMED')
        checks['tool_exit'] = True
        checks['output_complete'] = tool.lines.finish()
        bounded.verify_source(repo, expected, parent)
        need(entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        checks['source_unchanged'] = True
        report['success'] = all(checks.values())
    except (protocol.Refused, ProcessRefused, bounded.SmokeFailure) as error:
        report['errors'].append(error.code if getattr(error, 'code', None) in CODES
                                else str(error) if str(error) in CODES else 'INTERNAL_ERROR')
    except (Exception, KeyboardInterrupt):
        report['errors'].append('INTERNAL_ERROR')
    finally:
        if frontend is not None:
            if frontend.original.poll() is None:
                report['forced_cleanup'] = True
                frontend.original.kill()
                frontend.original.wait(timeout=10)
            frontend.lines.finish()
            report['frontend_output'] = frontend.lines.public()
            report['frontend_exit'] = frontend.original.returncode
            report['frontend'] = frontend.result
        if probe is not None and probe.original.poll() is None:
            report['forced_cleanup'] = True
            probe.original.kill()
            probe.original.wait(timeout=10)
        if probe is not None:
            probe.lines.finish()
            report['probe_output'] = probe.lines.public()
            report['probe_exit'] = probe.original.returncode
            report['probe_failure'] = probe.failure
        if job is not None:
            job.close()
            report['forced_cleanup'] |= job.forced
        if original is not None:
            if original.poll() is None:
                report['forced_cleanup'] = True
                original.kill()
            original.wait(timeout=10)
            report['bootstrap_exit'] = original.returncode
        if tool is not None:
            tool.lines.finish()
            report['tool_output'] = tool.lines.public()
            report['tool_exit'] = tool.exit
            report['protocol'] = tool.protocol.public()
        report['success'] &= not report['errors'] and not report['forced_cleanup']
        report['debug_loop_qualified'] = report['success'] and report['devtools_attached']
        if output is not None:
            target = output / 'manifest.json'
            with target.open('x', encoding='utf-8') as stream:
                json.dump(report, stream, sort_keys=True, separators=(',', ':'))
                stream.write('\n')
    if arguments != ['--analyze']:
        public = json.dumps(report, sort_keys=True, separators=(',', ':'))
        print(public)
        if len(public.encode()) <= 3800:
            print('::notice title=Windows debug outcome::' + public)
    return 0 if report['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
