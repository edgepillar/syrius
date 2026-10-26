"""A gated ordinary wallet tour while the original owned chain-321 lab runs.

Only a finite manifest leaves this controller. The public lab mnemonic, generated
password, private instance receipt, profile, captures and raw output stay private.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
import subprocess
import time

from . import windows_debug_loop as debug


PAGES = ('dashboard', 'transfer', 'pillars', 'sentinels', 'staking', 'plasma',
         'tokens', 'p2pSwap', 'accelerator', 'notifications', 'settings', 'walletConnect')
CHECKS = ('environment', 'source', 'unused_destinations', 'job_owned', 'entry_ready',
          'application_owned', 'lab_revalidated', 'input_released', 'tour_complete',
          'captures', 'close_ack', 'application_exit', 'entry_exit', 'output_complete',
          'source_unchanged', 'auxiliary_cleanup')
CODES = frozenset(('ENVIRONMENT_REFUSED', 'SOURCE_REFUSED', 'PROFILE_REFUSED',
    'STORAGE_REFUSED', 'JOB_REFUSED', 'PROCESS_REFUSED', 'ENTRY_REFUSED',
    'ENTRY_FAILED', 'TOUR_REFUSED', 'CAPTURE_REFUSED', 'FIXTURE_REFUSED',
    'LAB_REFUSED', 'INPUT_REFUSED', 'CLOSE_UNCONFIRMED', 'OUTPUT_REFUSED',
    'EXISTING_PROCESS', 'PREFLIGHT_FAILED', 'PREFLIGHT_TIMEOUT', 'PREFLIGHT_OUTPUT_REFUSED',
    'APPLICATION_EXIT_UNCONFIRMED', 'PNG_INVALID', 'TOOL_REFUSED',
    'TOTAL_DEADLINE', 'HELPER_IMAGE_REFUSED', 'HELPER_IDENTITY_REFUSED',
    'HELPER_CLOSE_UNCONFIRMED', 'INTERNAL_ERROR'))
WORK_CAP = 4 * 1024**3
FIXTURE_FLOOR = 2 * 1024**3


class Refused(Exception):
    def __init__(self, code):
        self.code = code if code in CODES else 'INTERNAL_ERROR'
        super().__init__(self.code)


def need(value, code):
    if not value:
        raise Refused(code)


def public_fixture(text):
    """Read only the explicitly committed public devnet example, never a profile."""
    need(type(text) is str and 0 < len(text.encode()) <= 65536, 'FIXTURE_REFUSED')
    offered = re.findall(r'^```\r?\n([a-z]+(?: [a-z]+){11}|[a-z]+(?: [a-z]+){23})\r?\n```$', text, re.M)
    need(len(offered) == 1 and len(offered[0]) <= 512, 'FIXTURE_REFUSED')
    return offered[0]


def tour_receipt(value):
    need(type(value) is dict and set(value) == {'schema', 'scope', 'complete', 'requested', 'visited'}
         and type(value['schema']) is int and value['schema'] == 1
         and value['scope'] == 'wallet_page_tour' and type(value['complete']) is bool
         and value['requested'] == list(PAGES) and type(value['visited']) is list
         and len(value['visited']) <= len(PAGES), 'TOUR_REFUSED')
    for index, page in enumerate(value['visited']):
        need(type(page) is dict and set(page) == {'page', 'nodes', 'error_widgets', 'severe_logs', 'captured'}
             and page['page'] == PAGES[index] and type(page['captured']) is bool
             and all(type(page[key]) is int and 0 <= page[key] <= 100000
                     for key in ('nodes', 'error_widgets', 'severe_logs')), 'TOUR_REFUSED')
    return value


def tour_complete(value):
    return (value['complete'] is True and len(value['visited']) == len(PAGES)
            and all(page['captured'] and page['error_widgets'] == page['severe_logs'] == 0
                    for page in value['visited']))


def completed(report):
    """A good page receipt cannot heal uncertain original exits or cleanup."""
    try:
        checks = report['checks']
        if (type(checks) is not dict or set(checks) != set(CHECKS)
                or not all(value is True for value in checks.values())
                or report['errors'] != [] or report['required_actor_forced_cleanup'] is not False
                or any(type(report.get(key)) is not int or report[key] != 0
                       for key in ('application_exit', 'entry_exit', 'owned_job_active_at_close'))
                or report['entry_output']['output_complete'] is not True
                or report['entry_output']['overflow'] is not False
                or not debug.helper_cleanup_complete(report['auxiliary_cleanup'])
                or report['forced_cleanup'] is not report['auxiliary_cleanup']['forced']
                or not tour_complete(tour_receipt(report['tour']))):
            return False
        captures = report['captures']
        if type(captures) is not list or len(captures) != len(PAGES):
            return False
        return all(type(item) is dict and set(item) == {'page', 'bytes', 'sha256', 'width', 'height'}
            and item['page'] == page and type(item['bytes']) is int
            and 0 < item['bytes'] <= debug.entry.MAX_PNG
            and debug.bounded.safe_digest(item['sha256'])
            and type(item['width']) is type(item['height']) is int
            and item['width'] == 1280 and item['height'] == 780
            for item, page in zip(captures, PAGES))
    except (KeyError, TypeError, Refused):
        return False


def sample_workspace(paths):
    """Sample only this attempt's explicit new output paths on its fresh runner."""
    total, count = 0, 0
    pending = [path for path in paths if path.exists() or path.is_symlink()]
    while pending:
        path = pending.pop()
        try:
            info = path.lstat()
        except FileNotFoundError:
            continue
        count += 1
        need(count <= 100000 and not stat.S_ISLNK(info.st_mode)
             and not getattr(info, 'st_file_attributes', 0) & 0x400, 'STORAGE_REFUSED')
        if stat.S_ISDIR(info.st_mode):
            try:
                pending.extend(path.iterdir())
            except FileNotFoundError:
                continue
        else:
            need(stat.S_ISREG(info.st_mode), 'STORAGE_REFUSED')
            total += info.st_size
            need(total <= WORK_CAP, 'STORAGE_REFUSED')
    return total


def run(repo, parent, runtime, lab_root, observation, revalidate):
    report = dict(schema=1, scope='owned_chain321_wallet_tour', success=False,
        wallet_qualified=False, seed_admitted=False, visual_matches=0,
        checks=dict.fromkeys(CHECKS, False), errors=[], captures=[], tour=None,
        forced_cleanup=False, required_actor_forced_cleanup=False,
        auxiliary_cleanup=None, phase='admission', min_free_bytes=FIXTURE_FLOOR,
        workspace_cap_bytes=WORK_CAP,
        storage_scope='isolated_hosted_regression_fixture_cooperative_samples',
        cleanup='runner_lifecycle_not_qualified')
    original = lines = job = output = transport = None
    token = None
    close_attempted = False
    try:
        parent, source = debug.entry.require_ci(parent, None, platform=os.name)
        need(parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
             and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
             and parent.get('SYRIUS_LAB_NODE_SOURCE') == 'lab-fix'
             and parent.get('SYRIUS_NATIVE_STACK_DIAGNOSTIC') == 'true', 'ENVIRONMENT_REFUSED')
        report['checks']['environment'] = True
        debug.bounded.verify_source(repo, source, parent)
        tree = debug.entry.source_tree(repo, parent)
        report.update(source_sha=source, source_tree=tree,
            run_id=parent['GITHUB_RUN_ID'], run_attempt=parent['GITHUB_RUN_ATTEMPT'])
        report['checks']['source'] = True
        root = debug.entry.private_root(repo)
        output = root / 'ci-wallet-tour'
        output.mkdir(mode=0o700)
        need(shutil.disk_usage(repo).free >= FIXTURE_FLOOR + WORK_CAP, 'STORAGE_REFUSED')
        debug.bounded.check_no_existing(repo, parent)
        name = 'ci-wallet-' + secrets.token_hex(12)
        home, app = root / name, root / 'app'
        native_build = repo / 'build/windows/x64'
        need(not any(path.exists() or path.is_symlink() for path in (home, app, native_build)),
             'PROFILE_REFUSED')
        report['checks']['unused_destinations'] = True
        tool_profile = debug.entry.new_profile(repo)
        env = debug.profile_environment(parent, tool_profile, 1, secrets.token_hex(16))
        env.update(SYRIUS_CI_WALLET_TOUR='true', SYRIUS_CI_WALLET_INSTANCE=name)
        dart, _ = debug.sdk(parent)
        job = debug.WindowsJob()
        original = subprocess.Popen([str(dart), '--disable-dart-dev',
            '--packages=' + str(repo / '.dart_tool/package_config.json'),
            'harness/bin/ci_wallet_tour.dart'], cwd=repo, env=env, shell=False,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
        job.assign(original)
        report['checks']['job_owned'] = True
        lines = debug.Lines(original.stdout)
        deadline, next_sample = time.monotonic() + 900, 0.0
        used = set()

        def write(data):
            need(original.poll() is None and len(data) <= 4096, 'INPUT_REFUSED')
            original.stdin.write(data)
            original.stdin.flush()

        def wait(marker):
            nonlocal next_sample
            while True:
                runtime.healthy()
                now = time.monotonic()
                need(now < deadline, 'TOTAL_DEADLINE')
                if now >= next_sample:
                    sample_workspace((home, app, native_build, tool_profile))
                    need(shutil.disk_usage(repo).free >= FIXTURE_FLOOR, 'STORAGE_REFUSED')
                    next_sample = now + 5
                raw = lines.take(.1)
                if raw is None:
                    need(original.poll() is None or not lines.complete, 'ENTRY_FAILED')
                    continue
                line = raw.rstrip(b'\r\n')
                if line.startswith(b'SYRIUS_WALLET_TOUR:'):
                    need('tour' not in used and marker == b'CI_WALLET_DONE', 'TOUR_REFUSED')
                    used.add('tour')
                    report['tour'] = tour_receipt(json.loads(line.partition(b':')[2]))
                elif line.startswith(b'CI_WALLET_ERROR:'):
                    failure = json.loads(line.partition(b':')[2])
                    need(type(failure) is dict and set(failure) == {'stage', 'code'}
                         and failure['stage'] in ('unused_destinations', 'build', 'start',
                             'input', 'onboarding', 'signing_policy', 'onboarding_logs',
                             'window', 'tour', 'finish')
                         and (failure['code'] is None or type(failure['code']) is str
                              and re.fullmatch('wallet-recipe-[a-z-]{1,80}', failure['code'])),
                         'ENTRY_REFUSED')
                    report['entry_failure'] = failure
                    raise Refused('ENTRY_FAILED')
                elif line in (b'CI_WALLET_READY', b'CI_WALLET_DONE', b'CI_WALLET_ERROR'):
                    need(line == marker and line not in used, 'ENTRY_FAILED')
                    used.add(line)
                    return

        report['phase'] = 'build_and_start'
        write(b'START\n')
        wait(b'CI_WALLET_READY')
        report['checks']['entry_ready'] = True
        instance = home / 'instance.json'
        debug.bounded.plain(home)
        info = debug.bounded.plain(instance)
        need(0 < info.st_size <= 4096, 'PROFILE_REFUSED')
        private = json.loads(instance.read_bytes())
        pid, port, token = private.get('pid'), private.get('port'), private.get('token')
        need(type(pid) is int and 0 < pid < 2**32 and type(port) is int and 1024 <= port <= 65535
             and type(token) is str and re.fullmatch('[0-9a-f]{32}', token)
             and private.get('mode') == 'release' and private.get('harnessMode') == 'wallet'
             and private.get('presentationScreen') is None, 'ENTRY_REFUSED')
        job.bind_application(pid, app / 'release/syrius.exe')
        transport = debug.bounded.LoopbackTransport(port, 32768)
        ping = transport.exchange(dict(cmd='ping'), token, 5)
        body = json.loads(ping.body)
        need(ping.status == 200 and body.get('ok') is True and body.get('booted') is True
             and type(body.get('pid')) is int and body['pid'] == pid
             and body.get('harnessMode') == 'wallet', 'ENTRY_REFUSED')
        report['checks']['application_owned'] = True
        report['phase'] = 'lab_revalidation'
        runtime.healthy()
        current = revalidate()
        need(current['chain'] == observation['chain'] == 321
             and current['genesis_hash'] == observation['genesis_hash']
             and current['last_height'] >= observation['last_height']
             and current['cross_transport_hash_equal'] is observation['cross_transport_hash_equal'] is True,
             'LAB_REFUSED')
        report['checks']['lab_revalidated'] = True
        fixture = public_fixture((repo / 'tools/devnet/lab/README.md').read_text(encoding='utf-8'))
        report['phase'] = 'onboarding_and_tour'
        # Reserve before the single private-input write; no retry is admitted.
        report['input_attempted'] = True
        write((json.dumps(dict(chain='321', node='ws://127.0.0.1:45998',
            mnemonic=fixture, password=secrets.token_hex(16) + 'A!1')) + '\n').encode())
        report['checks']['input_released'] = True
        wait(b'CI_WALLET_DONE')
        need(report['tour'] is not None and tour_complete(report['tour']), 'TOUR_REFUSED')
        report['checks']['tour_complete'] = True
        for page in PAGES:
            path = home / 'tour' / (page + '.png')
            info = debug.bounded.plain(path)
            need(0 < info.st_size <= debug.entry.MAX_PNG, 'CAPTURE_REFUSED')
            raw = path.read_bytes()
            debug.entry.png_bytes(base64.b64encode(raw).decode('ascii'))
            report['captures'].append(dict(page=page, bytes=len(raw),
                sha256=hashlib.sha256(raw).hexdigest(), width=1280, height=780))
        report['checks']['captures'] = True
        report['phase'] = 'ordinary_close'
        close_attempted = True
        debug.request_close(transport, token)
        report['checks']['close_ack'] = True
        report['application_exit'] = job.application_exit()
        need(report['application_exit'] == 0, 'CLOSE_UNCONFIRMED')
        report['checks']['application_exit'] = True
        write(b'FINISH\n')
        need(original.wait(timeout=15) == 0, 'ENTRY_FAILED')
        report['checks']['entry_exit'] = True
        need(lines.finish(), 'OUTPUT_REFUSED')
        report['checks']['output_complete'] = True
        debug.bounded.verify_source(repo, source, parent)
        need(debug.entry.source_tree(repo, parent) == tree, 'SOURCE_REFUSED')
        report['checks']['source_unchanged'] = True
        report['phase'] = 'auxiliary_cleanup'
        report['auxiliary_cleanup'] = job.finish_known_helpers(
            dart, lambda: debug.compiler_telemetry_image(repo))
        report['forced_cleanup'] = report['auxiliary_cleanup']['forced']
        need(debug.helper_cleanup_complete(report['auxiliary_cleanup']),
             report['auxiliary_cleanup']['code'] or 'HELPER_CLOSE_UNCONFIRMED')
        report['checks']['auxiliary_cleanup'] = True
        report['phase'] = 'complete'
    except (Exception, KeyboardInterrupt) as error:
        code = getattr(error, 'code', None) or str(error)
        report['errors'].append(code if code in CODES else 'INTERNAL_ERROR')
    finally:
        if job is not None:
            if job.application is not None and not close_attempted:
                close_attempted = True
                try:
                    debug.request_close(transport, token)
                    report['cleanup_application_exit'] = job.application_exit()
                except Exception:
                    report['errors'].append('CLOSE_UNCONFIRMED')
            job.close()
            report['owned_job_active_at_close'] = job.active_at_close
            report['forced_cleanup'] |= job.forced
            report['required_actor_forced_cleanup'] |= job.forced
        if original is not None:
            if original.poll() is None:
                report['required_actor_forced_cleanup'] = report['forced_cleanup'] = True
                original.kill()
            try:
                report['entry_exit'] = original.wait(timeout=10)
            except Exception:
                report['entry_exit'] = None
                report['errors'].append('CLOSE_UNCONFIRMED')
        if lines is not None:
            lines.finish()
            report['entry_output'] = lines.public()
        report['success'] = completed(report)
        if output is not None:
            with (output / 'manifest.json').open('x', encoding='ascii') as stream:
                json.dump(report, stream, sort_keys=True, separators=(',', ':'))
                stream.write('\n')
        # Capture digests are in the explicit manifest; keep annotations compact.
        public = {key: value for key, value in report.items() if key not in ('captures', 'tour')}
        public['captured_pages'] = len(report['captures'])
        public['visited_pages'] = 0 if report['tour'] is None else len(report['tour']['visited'])
        text = json.dumps(public, sort_keys=True, separators=(',', ':'))
        print(text)
        if len(text.encode()) <= 3800:
            print('::notice title=Windows wallet tour outcome::' + text)
    return report
