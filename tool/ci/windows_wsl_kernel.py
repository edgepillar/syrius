"""One opt-in system-distro kernel query after the separate pinned WSL install.

The command does not install a user distribution or start Docker/a wallet.
Only a finite WSL2 release, original command outcomes and fixed codes are public.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import unittest

from . import windows_wsl_readiness as readiness
from .run_debug_tests import execute_suite


VERSION = '3.0.3.0'
CAP = 16384
TIMEOUT = 30
KERNEL_ARGUMENTS = ('--system', '--exec', '/bin/uname', '-r')


class Refused(Exception):
    pass


def admit(parent, platform_name):
    required = dict(GITHUB_ACTIONS='true', RUNNER_OS='Windows', RUNNER_ARCH='ARM64',
        SYRIUS_HOSTED_RUNNER='github-hosted', GITHUB_REPOSITORY='edgepillar/syrius',
        GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/redesign',
        GITHUB_RUN_ATTEMPT='1', SYRIUS_WINDOWS_WSL_KERNEL_START='true')
    if (platform_name != 'win32'
            or any(parent.get(k) != v for k, v in required.items())
            or re.fullmatch('[a-f0-9]{40}', parent.get('GITHUB_SHA', '')) is None
            or re.fullmatch('[1-9][0-9]{0,19}', parent.get('GITHUB_RUN_ID', '')) is None):
        raise Refused()


def kernel_projection(outcome):
    text = readiness.decode(outcome.output)
    release = None
    if text is not None:
        rows = text.splitlines()
        if len(rows) == 1 and re.fullmatch(
                r'[0-9]{1,3}(?:\.[0-9]{1,5}){1,3}-microsoft-standard-WSL2\+?', rows[0]):
            release = rows[0]
    if not outcome.transport_complete or type(outcome.exit_code) is not int:
        status = 'UNKNOWN'
    elif not outcome.success:
        status = 'COMMAND_FAILED'
    elif release is None:
        status = 'OUTPUT_REFUSED'
    else:
        status = 'VALID_RELEASE_OBSERVED'
    command = outcome.public()
    command['success'] = outcome.success and type(outcome.exit_code) is int
    return dict(status=status, release=release if status == 'VALID_RELEASE_OBSERVED' else None,
        command=command, captured_output_sha256=hashlib.sha256(outcome.output).hexdigest(),
        reported_codes=[code for code in readiness.DIAGNOSTICS if text is not None
            and re.search(r'(?<![A-Z0-9_])' + code + r'(?![A-Z0-9_])', text)])


def observe(parent, report):
    admit(parent, sys.platform)
    repo = Path(__file__).absolute().parents[2]
    env = readiness.query_environment(parent)
    git = shutil.which('git.exe', path=env.get('PATH', ''))
    if not git or not parent.get('PROGRAMFILES'):
        raise Refused()
    installed = Path(parent['PROGRAMFILES']) / 'WSL/wsl.exe'
    readiness.bounded.plain(installed)
    if not installed.is_file():
        raise Refused()

    def source():
        values = []
        for args in (['rev-parse', 'HEAD'], ['rev-parse', 'HEAD^{tree}'],
                ['status', '--porcelain=v1', '--untracked-files=all']):
            outcome = readiness.bounded.run_bounded([git, '--no-pager', '--no-lazy-fetch',
                '-c', 'core.fsmonitor=false', '-c', 'gc.auto=0', *args],
                cwd=repo, env=env, cap=CAP, timeout=15)
            if not outcome.success:
                raise Refused()
            values.append(outcome.output.decode('ascii').strip())
        if (values[0] != parent['GITHUB_SHA'] or values[2]
                or re.fullmatch('[a-f0-9]{40}', values[1]) is None):
            raise Refused()
        return tuple(values[:2])

    report['stage'] = 'source_before'
    head, tree = source()
    report.update(source_sha=head, source_tree=tree)
    report['stage'] = 'component_queries'
    commands = {name: readiness.bounded.run_bounded([str(installed), '--' + name],
        cwd=repo, env=env, cap=CAP, timeout=15) for name in ('version', 'status')}
    facts = readiness.project(commands)
    report['components'] = {name: facts[name] for name in (
        'commands', 'wsl_package_version', 'meets_docker_documented_wsl_minimum')}
    eligible = (facts['wsl_package_version'] == VERSION
        and facts['meets_docker_documented_wsl_minimum'] is True
        and all(value.success for value in commands.values()))
    report['component_prerequisites_observed'] = eligible
    if eligible:
        report.update(stage='kernel_query', kernel_query_attempted=True,
            kernel_or_container_start_requested=True)
        outcome = readiness.bounded.run_bounded([str(installed), *KERNEL_ARGUMENTS],
            cwd=repo, env=env, cap=CAP, timeout=TIMEOUT)
        report['kernel'] = kernel_projection(outcome)
    report['stage'] = 'source_after'
    if source() != (head, tree):
        raise Refused()
    report['source_unchanged'] = True
    report['kernel_start_qualified'] = (eligible and report['kernel'] is not None
        and report['kernel']['status'] == 'VALID_RELEASE_OBSERVED')
    report['status'] = ('KERNEL_START_QUALIFIED' if report['kernel_start_qualified']
        else 'KERNEL_START_UNQUALIFIED' if eligible else 'COMPONENT_PREREQUISITE_REFUSED')
    report['stage'] = 'complete'


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if arguments == ['--self-test']:
        directory = str(Path(__file__).absolute().parents[2] / 'test/ci')
        suite = unittest.TestLoader().discover(directory, pattern='test_windows_wsl_kernel.py')
        if suite.countTestCases() != 12:
            print('::error title=WSL kernel controls::TEST_SELECTION_REFUSED')
            return 1
        return execute_suite(suite, scope='wsl_kernel_controls', title='WSL kernel controls')
    run_id = os.environ.get('GITHUB_RUN_ID', '')
    if re.fullmatch('[1-9][0-9]{0,19}', run_id) is None:
        run_id = None
    report = dict(schema=1, scope='github_hosted_windows_wsl_kernel_startup',
        status='REFUSED_OR_UNKNOWN', stage='environment', source_sha=None,
        source_tree=None, source_unchanged=False, run_id=run_id, run_attempt=1,
        runner_os='Windows', runner_arch='ARM64', expected_package_version=VERSION,
        component_prerequisites_observed=False, components=None, kernel=None,
        kernel_query_attempted=False, kernel_or_container_start_requested=False,
        kernel_start_qualified=False, docker_linux_mode_qualified=False,
        chain321_qualified=False, x64_wallet_qualified=False,
        distro_install_requested=False, downloads_requested=False,
        features_changed=False, reboot_requested=False, wallet_or_node_start_requested=False,
        cleanup_performed=False, vm_disposal_qualified=False)
    try:
        if arguments:
            raise Refused()
        observe(os.environ, report)
    except (Exception, KeyboardInterrupt):
        report.update(status='REFUSED_OR_UNKNOWN', kernel_start_qualified=False)
    encoded = json.dumps(report, sort_keys=True, separators=(',', ':'))
    if not encoded.isascii() or len(encoded.encode()) > 3800:
        print('::error title=WSL kernel startup::REPORT_REFUSED')
        return 1
    print('::notice title=WSL kernel startup::' + encoded)
    return 0 if report['kernel_start_qualified'] and report['source_unchanged'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
