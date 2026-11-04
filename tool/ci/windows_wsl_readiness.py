"""Query installed WSL components without installation or Linux startup.

Only finite versions, original command outcomes and fixed diagnostic codes
leave memory. A command on PATH, a version or a successful status query does
not establish a running kernel, nested virtualization or Docker Linux mode.
"""

import json
import os
from pathlib import Path
import re
import shutil
import sys
import unittest

from . import windows_baseline as bounded
from .run_debug_tests import execute_suite


CAP = 16384
TIMEOUT = 15
DIAGNOSTICS = (
    'WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED', 'WSL_E_KERNEL_NOT_FOUND',
    'WSL_E_DEFAULT_DISTRO_NOT_FOUND', 'HCS_E_HYPERV_NOT_INSTALLED',
    'ERROR_NOT_SUPPORTED', 'REGDB_E_CLASSNOTREG',
)
RUNTIME_KEYS = bounded.RUNTIME_ENV | frozenset(('TEMP', 'TMP'))


class Refused(Exception):
    pass


def admit(parent, platform_name):
    required = dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows',
        RUNNER_ARCH='ARM64', SYRIUS_HOSTED_RUNNER='github-hosted',
        GITHUB_REPOSITORY='edgepillar/syrius',
        GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
        GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_READINESS='true')
    if (platform_name != 'win32'
            or any(parent.get(key) != value for key, value in required.items())
            or re.fullmatch('[a-f0-9]{40}', parent.get('GITHUB_SHA', '')) is None
            or re.fullmatch('[1-9][0-9]{0,19}', parent.get('GITHUB_RUN_ID', '')) is None):
        raise Refused()


def decode(raw):
    if type(raw) is not bytes or len(raw) > CAP:
        return None
    try:
        if raw.startswith(b'\xff\xfe'):
            return raw[2:].decode('utf-16-le')
        if b'\0' in raw:
            return raw.decode('utf-16-le')
        return raw.decode('utf-8-sig')
    except UnicodeError:
        return None


def version(text, label):
    if text is None:
        return None
    # Unknown locales and duplicate/ambiguous records stay unknown.
    rows = re.findall(r'^' + re.escape(label)
        + r': ([0-9]{1,5}(?:\.[0-9]{1,5}){1,3})\r?$', text, re.MULTILINE)
    return rows[0] if len(rows) == 1 else None


def project(commands):
    if set(commands) != {'version', 'status'}:
        raise Refused()
    facts = {}
    for name, outcome in commands.items():
        text = decode(outcome.output)
        facts[name] = dict(outcome=outcome.public(), reported_codes=[code
            for code in DIAGNOSTICS if text is not None and re.search(
                r'(?<![A-Z0-9_])' + code + r'(?![A-Z0-9_])', text)])
    package = (version(decode(commands['version'].output), 'WSL version')
               if commands['version'].success else None)
    kernel = (version(decode(commands['version'].output), 'Kernel version')
              if commands['version'].success else None)
    minimum = None
    if package is not None:
        parts = tuple(int(item) for item in package.split('.'))
        minimum = parts + (0,) * (4 - len(parts)) >= (2, 1, 5, 0)
    return dict(status=('OBSERVED' if all(value.transport_complete
        for value in commands.values()) else 'UNKNOWN'), commands=facts,
        wsl_package_version=package, reported_kernel_version=kernel,
        meets_docker_documented_wsl_minimum=minimum,
        nested_virtualization='NOT_ESTABLISHED', kernel_start_qualified=False,
        docker_linux_mode_qualified=False, x64_wallet_qualified=False,
        chain321_qualified=False, installation_performed=False,
        features_changed=False, downloads_requested=False,
        kernel_or_container_start_requested=False,
        wallet_or_node_start_requested=False)


def query_environment(parent):
    env = {key: value for key, value in parent.items() if key in RUNTIME_KEYS}
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
               GIT_TERMINAL_PROMPT='0')
    return env


def run(parent, platform_name):
    admit(parent, platform_name)
    repo = Path(__file__).absolute().parents[2]
    env = query_environment(parent)
    git = shutil.which('git.exe', path=env.get('PATH', ''))
    root = parent.get('SYSTEMROOT', '')
    if not git or not root:
        raise Refused()
    wsl = Path(root) / 'System32' / 'wsl.exe'
    bounded.plain(wsl)
    if not wsl.is_file():
        raise Refused()

    def source(arguments):
        result = bounded.run_bounded([git, '--no-pager', '--no-lazy-fetch',
            '-c', 'core.fsmonitor=false', '-c', 'gc.auto=0', *arguments],
            cwd=repo, env=env, timeout=TIMEOUT, cap=CAP)
        if not result.success:
            raise Refused()
        return result.output.decode('ascii').strip()

    def identity():
        head = source(['rev-parse', 'HEAD'])
        tree = source(['rev-parse', 'HEAD^{tree}'])
        if (head != parent['GITHUB_SHA']
                or re.fullmatch('[a-f0-9]{40}', tree) is None
                or source(['status', '--porcelain=v1', '--untracked-files=all'])):
            raise Refused()
        return head, tree

    head, tree = identity()
    commands = {name: bounded.run_bounded([str(wsl), '--' + name],
        cwd=repo, env=env, timeout=TIMEOUT, cap=CAP)
        for name in ('version', 'status')}
    if identity() != (head, tree):
        raise Refused()
    value = project(commands)
    value.update(schema=1, scope='github_hosted_windows_wsl_readiness',
        source_sha=head, source_tree=tree, source_unchanged=True,
        run_id=parent['GITHUB_RUN_ID'], run_attempt=1)
    return value


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments == ['--self-test']:
        directory = str(Path(__file__).absolute().parents[2] / 'test/ci')
        suite = unittest.TestLoader().discover(directory,
            pattern='test_windows_wsl_readiness.py')
        if suite.countTestCases() != 14:
            print('::error title=WSL readiness controls::TEST_SELECTION_REFUSED')
            return 1
        return execute_suite(suite, scope='wsl_readiness_controls',
                             title='WSL readiness controls')
    try:
        if arguments:
            raise Refused()
        value = run(os.environ, sys.platform)
        encoded = json.dumps(value, sort_keys=True, separators=(',', ':'))
        if not encoded.isascii() or len(encoded.encode()) > 3800:
            raise Refused()
        print('::notice title=Windows WSL readiness::' + encoded)
        return 0 if value['status'] == 'OBSERVED' else 1
    except (Exception, KeyboardInterrupt):
        print('::error title=Windows WSL readiness::READINESS_REFUSED')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
