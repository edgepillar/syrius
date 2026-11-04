"""One pinned WSL MSI installation in a fresh, opted-in hosted Arm VM.

No distro, Linux kernel, container, wallet or chain node is started. Installer
and post-install component observations retain their separate original exits.
Local execution, existing WSL installations and known pending reboots refuse.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import ssl
import stat
import sys
import tempfile
import time
import unittest
import urllib.parse
import urllib.request

from . import hosted_chain321 as owned
from . import windows_wsl_readiness as readiness
from .run_debug_tests import execute_suite


VERSION = '3.0.3.0'
ASSET_ID = 620248058
PACKAGE_BYTES = 341086208
PACKAGE_SHA256 = '2937c7ce840bb35ec6e97f052189bdfff27f8c3463bfdd231df9a958212787a3'
PACKAGE_URL = 'https://github.com/microsoft/WSL/releases/download/3.0.3/wsl.3.0.3.0.arm64.msi'
DOWNLOAD_SECONDS = 180
INSTALL_SECONDS = 180
CAP = 16384
CI_KEYS = ('GITHUB_ACTIONS', 'RUNNER_OS', 'RUNNER_ARCH', 'SYRIUS_HOSTED_RUNNER',
    'GITHUB_REPOSITORY', 'GITHUB_EVENT_NAME', 'GITHUB_REF', 'GITHUB_RUN_ATTEMPT',
    'GITHUB_SHA', 'GITHUB_RUN_ID', 'SYRIUS_WINDOWS_WSL_INSTALLATION')
FALSE_SCOPE = dict(kernel_start_qualified=False, docker_linux_mode_qualified=False,
    chain321_qualified=False, x64_wallet_qualified=False, distro_install_requested=False,
    kernel_or_container_start_requested=False, wallet_or_node_start_requested=False,
    feature_change_requested=False, reboot_requested=False, cleanup_performed=False)


class Refused(Exception):
    pass


IDENTITY_FIELDS = ('st_dev', 'st_ino', 'st_size', 'st_mtime_ns', 'st_ctime_ns', 'st_nlink')
PACKAGE_CODES = frozenset((
    'PACKAGE_TYPE_REFUSED', 'PACKAGE_SIZE_REFUSED', 'PACKAGE_LINKS_REFUSED',
    'PACKAGE_OPEN_IDENTITY_REFUSED', 'PACKAGE_STREAM_SIZE_REFUSED',
    'PACKAGE_CLOSE_IDENTITY_REFUSED', 'PACKAGE_PATH_IDENTITY_REFUSED',
    'PACKAGE_LENGTH_REFUSED', 'PACKAGE_DIGEST_REFUSED',
))


class PackageRefused(Refused):
    def __init__(self, code, comparisons=None):
        self.code = code if type(code) is str and code in PACKAGE_CODES else None
        self.comparisons = {} if comparisons is None else dict(comparisons)
        super().__init__('PACKAGE_VERIFICATION_REFUSED')


def verification_failure(error):
    unknown = dict(status='UNKNOWN', code='PACKAGE_VERIFICATION_UNCERTAIN',
                   comparisons={}, os_code=None)
    if type(error) is PackageRefused:
        code, comparisons = error.code, error.comparisons
        if (type(code) is str and code in PACKAGE_CODES and type(comparisons) is dict
                and (not comparisons or set(comparisons) == set(IDENTITY_FIELDS))
                and all(type(value) is bool for value in comparisons.values())):
            return dict(status='REFUSED', code=code,
                        comparisons=dict(comparisons), os_code=None)
    elif type(error) in (OSError, FileNotFoundError, PermissionError,
                         IsADirectoryError, NotADirectoryError):
        code = getattr(error, 'winerror', None)
        code = getattr(error, 'errno', None) if code is None else code
        if type(code) is int and code in (2, 3, 5, 13, 21, 32, 33, 87, 1117, 1392):
            unknown['os_code'] = code
    return unknown


def verify_for_installation(path, report):
    try:
        result = verify_package(path)
    except (Exception, KeyboardInterrupt) as error:
        report['file_verification'] = verification_failure(error)
        raise
    report['file_verification'] = dict(status='VERIFIED', code=None,
                                      comparisons={}, os_code=None)
    return result


def admit(parent, platform_name):
    expected = dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
        SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
        GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
        GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_INSTALLATION='true')
    if (platform_name != 'win32'
            or any(parent.get(key) != value for key, value in expected.items())
            or re.fullmatch('[a-f0-9]{40}', parent.get('GITHUB_SHA', '')) is None
            or re.fullmatch('[1-9][0-9]{0,19}', parent.get('GITHUB_RUN_ID', '')) is None):
        raise Refused()


def preflight(value):
    yes = {'administrator', 'desktop_windows', 'native_arm64',
           'virtual_machine_platform_enabled', 'wsl_feature_enabled'}
    no = {'existing_msi_binary', 'store_package_present', 'known_windows_reboot_pending'}
    finite_facts(value, 'wsl_install_preflight', yes | no)
    if (any(value[name] is not True for name in yes)
            or any(value[name] is not False for name in no)):
        raise Refused()
    return value


def signature(value):
    finite_facts(value, 'wsl_install_signature', {'valid', 'microsoft_publisher'})
    if value['valid'] is not True or value['microsoft_publisher'] is not True:
        raise Refused()
    return value


def finite_facts(value, scope, fields):
    if (type(value) is not dict or set(value) != fields | {'schema', 'scope'}
            or type(value['schema']) is not int or value['schema'] != 1
            or value['scope'] != scope or any(type(value[name]) is not bool for name in fields)):
        raise Refused()
    return value


def command_error(error):
    code = error.code if isinstance(error, owned.Failure) else None
    return (code if code in ('COMMAND_FAILED', 'COMMAND_TIMEOUT',
        'OUTPUT_REFUSED', 'STORAGE_REFUSED') else 'INSTALL_COMMAND_UNCERTAIN')


def allowed_url(url):
    value = urllib.parse.urlsplit(url)
    if (value.scheme != 'https' or value.username is not None or value.password is not None
            or value.port not in (None, 443) or value.fragment
            or value.hostname not in ('github.com', 'release-assets.githubusercontent.com',
                                      'objects.githubusercontent.com')):
        raise Refused()


class Redirect(urllib.request.HTTPRedirectHandler):
    def __init__(self):
        super().__init__()
        self.count = 0

    def redirect_request(self, request, response, code, message, headers, target):
        self.count += 1
        allowed_url(target)
        if self.count > 3:
            raise Refused()
        return super().redirect_request(request, response, code, message, headers, target)


def copy_verified(response, stream, size, digest, *, sample, received=None,
                  clock=time.monotonic):
    deadline, total, next_sample = clock() + DOWNLOAD_SECONDS, 0, 0.0
    hashed = hashlib.sha256()
    while True:
        now = clock()
        if now >= deadline:
            raise Refused()
        if now >= next_sample:
            sample()
            next_sample = now + 2
        block = response.read(min(65536, size - total + 1))
        if not block:
            break
        total += len(block)
        if received is not None:
            received(total)
        if total > size:
            raise Refused()
        hashed.update(block)
        stream.write(block)
    if total != size or hashed.hexdigest() != digest:
        raise Refused()
    return total


def download(root, report):
    allowed_url(PACKAGE_URL)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), Redirect(),
        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    request = urllib.request.Request(PACKAGE_URL,
        headers={'User-Agent': 'syrius-wsl-installation', 'Accept-Encoding': 'identity'})
    destination = root / 'wsl.arm64.msi'
    descriptor = os.open(destination, os.O_CREAT | os.O_EXCL | os.O_WRONLY
        | getattr(os, 'O_BINARY', 0) | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        with opener.open(request, timeout=15) as response:
            allowed_url(response.geturl())
            report['download_http_status'] = response.status
            length = response.headers.get('Content-Length')
            if (response.status != 200
                    or response.headers.get('Content-Encoding', 'identity') != 'identity'
                    or length is not None and length != str(PACKAGE_BYTES)):
                raise Refused()
            copy_verified(response, stream, PACKAGE_BYTES, PACKAGE_SHA256,
                sample=lambda: owned.sample_storage(root),
                received=lambda count: report.update(download_bytes_received=count))
        stream.flush()
        os.fsync(stream.fileno())
    destination.chmod(0o400)
    return destination


def installer_result(receipt, command_error=None):
    if receipt is None:
        return dict(exit_code=None, output_complete=None, forced=None,
                    output_bytes=None, overflow=None, reported_success=False,
                    command_error=command_error,
                    reboot_required=None, ready_without_reboot=False)
    streams = receipt['streams']
    complete = receipt['output_complete'] and not receipt['forced']
    overflow = any(value['overflow'] for value in streams.values())
    code = receipt['exit_code']
    closed = complete and not overflow and (command_error is None
        or command_error == 'COMMAND_FAILED' and code == 3010)
    return dict(exit_code=code, output_complete=receipt['output_complete'],
        forced=receipt['forced'], output_bytes=sum(v['bytes'] for v in streams.values()),
        overflow=overflow, reported_success=closed and code in (0, 3010),
        command_error=command_error,
        reboot_required=(code == 3010 if closed else None),
        ready_without_reboot=closed and code == 0)


def verify_package(path):
    def identity(info):
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns,
                info.st_ctime_ns, info.st_nlink)
    before = readiness.bounded.plain(path)
    if not stat.S_ISREG(before.st_mode):
        raise PackageRefused('PACKAGE_TYPE_REFUSED')
    if before.st_size != PACKAGE_BYTES:
        raise PackageRefused('PACKAGE_SIZE_REFUSED')
    if before.st_nlink != 1:
        raise PackageRefused('PACKAGE_LINKS_REFUSED')
    def require_identity(current, code):
        actual, expected = identity(current), identity(before)
        if actual != expected:
            raise PackageRefused(code, dict(zip(IDENTITY_FIELDS,
                (a == b for a, b in zip(actual, expected)))))
    digest, count = hashlib.sha256(), 0
    with path.open('rb') as stream:
        require_identity(os.fstat(stream.fileno()), 'PACKAGE_OPEN_IDENTITY_REFUSED')
        while block := stream.read(65536):
            count += len(block)
            if count > PACKAGE_BYTES:
                raise PackageRefused('PACKAGE_STREAM_SIZE_REFUSED')
            digest.update(block)
        require_identity(os.fstat(stream.fileno()), 'PACKAGE_CLOSE_IDENTITY_REFUSED')
    require_identity(readiness.bounded.plain(path), 'PACKAGE_PATH_IDENTITY_REFUSED')
    if count != PACKAGE_BYTES:
        raise PackageRefused('PACKAGE_LENGTH_REFUSED')
    if digest.hexdigest() != PACKAGE_SHA256:
        raise PackageRefused('PACKAGE_DIGEST_REFUSED')


def observe(parent, report):
    admit(parent, sys.platform)
    repo = Path(__file__).absolute().parents[2]
    env = readiness.query_environment(parent)
    env.update({key: parent[key] for key in CI_KEYS})
    for name in ('PROGRAMFILES', 'PROGRAMDATA', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE'):
        if name in parent:
            env[name] = parent[name]
    git = shutil.which('git.exe', path=env.get('PATH', ''))
    system = Path(parent['SYSTEMROOT']) / 'System32'
    powershell = system / 'WindowsPowerShell/v1.0/powershell.exe'
    msiexec = system / 'msiexec.exe'
    for file in (powershell, msiexec):
        readiness.bounded.plain(file)
        if not file.is_file():
            raise Refused()
    if not git:
        raise Refused()

    def source():
        values = []
        for arguments in (['rev-parse', 'HEAD'], ['rev-parse', 'HEAD^{tree}'],
                          ['status', '--porcelain=v1', '--untracked-files=all']):
            original = readiness.bounded.run_bounded([git, '--no-pager', '--no-lazy-fetch',
                '-c', 'core.fsmonitor=false', '-c', 'gc.auto=0', *arguments],
                cwd=repo, env=env, cap=CAP, timeout=15)
            if not original.success:
                raise Refused()
            values.append(original.output.decode('ascii').strip())
        if (values[0] != parent['GITHUB_SHA'] or values[2]
                or re.fullmatch('[a-f0-9]{40}', values[1]) is None):
            raise Refused()
        return tuple(values[:2])

    head, tree = source()
    report.update(source_sha=head, source_tree=tree)
    temp = Path(parent['RUNNER_TEMP'])
    readiness.bounded.plain(temp)
    if shutil.disk_usage(temp).free < owned.FIXTURE_MIN_FREE + owned.MAX_WORK:
        raise Refused()
    root = Path(tempfile.mkdtemp(prefix='syrius-wsl-install-', dir=temp))
    report.update(storage_scope='isolated_hosted_regression_fixture_cooperative_samples',
        min_free_bytes=owned.FIXTURE_MIN_FREE, work_cap_bytes=owned.MAX_WORK)
    env.update(TEMP=str(root), TMP=str(root))
    commands = owned.Commands(root, env)

    def facts(stage):
        env['SYRIUS_WSL_INSTALL_STAGE'] = stage
        original_count, failure = len(commands.originals), None
        try:
            raw = commands.run([str(powershell), '-NoLogo', '-NoProfile', '-NonInteractive',
                '-File', str(repo / 'tool/ci/windows_wsl_installation.ps1')],
                cwd=repo, timeout=45, cap=CAP)
            value = json.loads(raw.decode('utf-8-sig'))
            fields = ({'administrator', 'desktop_windows', 'native_arm64',
                'virtual_machine_platform_enabled', 'wsl_feature_enabled',
                'existing_msi_binary', 'store_package_present', 'known_windows_reboot_pending'}
                if stage == 'preflight' else {'valid', 'microsoft_publisher'})
            return finite_facts(value, 'wsl_install_' + stage, fields)
        except (Exception, KeyboardInterrupt) as error:
            failure = command_error(error)
            raise
        finally:
            receipt = (commands.originals[-1].receipt
                if len(commands.originals) == original_count + 1 else None)
            original = installer_result(receipt, failure)
            report[stage + '_command'] = {name: original[name] for name in (
                'exit_code', 'output_complete', 'forced', 'output_bytes',
                'overflow', 'command_error')}

    report['stage'] = 'preflight'
    report['preflight'] = facts('preflight')
    preflight(report['preflight'])
    report['stage'] = 'download'
    report['download_requested'] = True
    package = download(root, report)
    report['download_verified'] = True
    report['download_complete'] = True
    report['stage'] = 'signature'
    env['SYRIUS_WSL_MSI_FILE'] = str(package)
    report['signature'] = facts('signature')
    signature(report['signature'])
    verify_for_installation(package, report)
    report['stage'] = 'installer'
    report['installation_requested'] = True
    original_count = len(commands.originals)
    failure = None
    try:
        commands.run([str(msiexec), '/i', str(package), '/qn', '/norestart',
            'REBOOT=ReallySuppress'], cwd=repo, timeout=INSTALL_SECONDS, cap=CAP)
    except (Exception, KeyboardInterrupt) as error:
        # A failed or uncertain original invocation is never launched again.
        failure = command_error(error)
    receipt = (commands.originals[-1].receipt
               if len(commands.originals) == original_count + 1 else None)
    report['installer'] = installer_result(receipt, failure)
    owned.sample_storage(root)
    if report['installer']['reboot_required'] is True:
        report['status'] = 'REBOOT_REQUIRED'
    elif not report['installer']['ready_without_reboot']:
        report['status'] = 'INSTALLATION_FAILED_OR_UNKNOWN'
    else:
        report['stage'] = 'installed_component_queries'
        installed = Path(parent['PROGRAMFILES']) / 'WSL/wsl.exe'
        readiness.bounded.plain(installed)
        if not installed.is_file():
            raise Refused()
        observations = {name: readiness.bounded.run_bounded([str(installed), '--' + name],
            cwd=repo, env=env, cap=CAP, timeout=15) for name in ('version', 'status')}
        component_facts = readiness.project(observations)
        report['components'] = {name: component_facts[name] for name in (
            'status', 'commands', 'wsl_package_version', 'reported_kernel_version',
            'meets_docker_documented_wsl_minimum')}
        report['component_version_qualified'] = (
            report['components']['wsl_package_version'] == VERSION
            and all(value.success for value in observations.values()))
        report['status'] = ('COMPONENT_VERSION_QUALIFIED'
            if report['component_version_qualified'] else 'COMPONENT_READINESS_UNQUALIFIED')
    report['stage'] = 'source_after'
    if source() != (head, tree):
        raise Refused()
    report['source_unchanged'] = True
    report['stage'] = 'complete'


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments == ['--self-test']:
        directory = str(Path(__file__).absolute().parents[2] / 'test/ci')
        suite = unittest.TestLoader().discover(directory,
            pattern='test_windows_wsl_installation.py')
        if suite.countTestCases() != 28:
            print('::error title=WSL installation controls::TEST_SELECTION_REFUSED')
            return 1
        return execute_suite(suite, scope='wsl_installation_controls',
                             title='WSL installation controls')
    run_id = os.environ.get('GITHUB_RUN_ID', '')
    if re.fullmatch('[1-9][0-9]{0,19}', run_id) is None:
        run_id = None
    report = dict(schema=1, scope='github_hosted_windows_wsl_package_installation',
        status='REFUSED_OR_UNKNOWN', stage='environment', source_sha=None,
        source_tree=None, source_unchanged=False, run_id=run_id,
        run_attempt=1, package_version=VERSION, package_asset_id=ASSET_ID,
        package_bytes=PACKAGE_BYTES, package_sha256=PACKAGE_SHA256,
        download_requested=False, download_http_status=None, download_bytes_received=0,
        download_complete=False, download_verified=False, installation_requested=False,
        component_version_qualified=False, **FALSE_SCOPE)
    try:
        if arguments:
            raise Refused()
        observe(os.environ, report)
    except (Exception, KeyboardInterrupt):
        report['status'] = 'REFUSED_OR_UNKNOWN'
        report['component_version_qualified'] = False
    encoded = json.dumps(report, sort_keys=True, separators=(',', ':'))
    if not encoded.isascii() or len(encoded.encode()) > 3800:
        print('::error title=Windows WSL installation::REPORT_REFUSED')
        return 1
    print('::notice title=Windows WSL installation::' + encoded)
    return 0 if report['component_version_qualified'] and report['source_unchanged'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
