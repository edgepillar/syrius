"""Compare original page and disclosure frames inside one owned Windows lab."""

import json
import os
from pathlib import Path
import re
import stat

from . import native_interactive_frame_actions as actions
from . import restored_wallet_run
from . import windows_interactive_frame_profile as profile
from . import windows_launch_timing_pair as shared


FAMILY = 'interactive-timing-pair'
SCOPE = 'paired_owned_chain321_interactive_frames'
OUTPUT = Path('.harness/ci-interactive-timing-pair')
MAX_MANIFEST = 128 * 1024
MAX_ARCHIVE = MAX_MANIFEST + 65536
WINDOWS = ('page_change', 'disclosure')


def requested(backend, parent):
    if parent.get('SYRIUS_READONLY_CATALOG_FAMILY') != FAMILY:
        return False
    profile.need(backend == 'native' and parent.get('GITHUB_ACTIONS') == 'true'
        and parent.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
        and parent.get('GITHUB_REPOSITORY') == 'edgepillar/syrius'
        and parent.get('GITHUB_REF') == 'refs/heads/redesign'
        and parent.get('GITHUB_RUN_ATTEMPT') == '1'
        and parent.get('SYRIUS_HOSTED_RUNNER') == 'github-hosted'
        and parent.get('SYRIUS_LAB_NODE_SOURCE') == 'lab-fix'
        and parent.get('SYRIUS_NATIVE_STACK_DIAGNOSTIC') == 'true'
        and parent.get('SYRIUS_WINDOWS_WALLET_TOUR', 'false') == 'false'
        and parent.get('SYRIUS_WINDOWS_WALLET_INSPECTION', 'false') == 'false',
        'ENVIRONMENT_REFUSED')
    return True


def source_bytes(path, cap):
    info = shared.launch.bounded.plain(path)
    profile.need(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= cap, 'SOURCE_REFUSED')
    raw = path.read_bytes()
    profile.need(len(raw) == info.st_size, 'SOURCE_REFUSED')
    return raw


def binary_identity(binaries):
    return dict(runner_sha256=binaries[0][1], payload_sha256=binaries[1][1])


def run(repo, parent, runtime, lab_root, observation):
    launch = shared.launch
    report = dict(schema=1, scope=SCOPE, mode='release', theme=launch.TIMING_THEME,
        client=list(launch.TIMING_SIZE), phase='environment', success=False,
        p06=dict(original_sha=shared.P06_ORIGINAL, published_sha=shared.P06_SOURCE,
                 tree=shared.P06_TREE, overlay_tree=shared.P06_OVERLAY_TREE,
                 overlay_verified=False),
        commands=[], samples={}, comparisons=None, same_fixture_address=False, error_codes=[])
    destination = None
    try:
        parent, head = launch.entry.require_ci(parent, None, platform=os.name)
        profile.need(requested('native', parent), 'ENVIRONMENT_REFUSED')
        profile.need(Path(parent['GITHUB_WORKSPACE']).resolve() == repo.resolve(), 'SOURCE_REFUSED')
        parent['SYRIUS_PAIRED_INTERACTIVE_PROFILE'] = 'true'
        launch.bounded.verify_source(repo, head, parent)
        tree = launch.entry.source_tree(repo, parent)
        report.update(source_sha=head, source_tree=tree, run_id=parent['GITHUB_RUN_ID'],
            run_attempt='1', baseline_patch_sha256=shared.PATCH_SHA256,
            collector_sha256=shared.COLLECTOR_SHA256, entry_sha256=profile.ENTRY_SHA256)
        genesis, height = observation.get('genesis_hash'), observation.get('last_height')
        profile.need(type(observation.get('chain')) is int and observation['chain'] == 321
            and observation.get('cross_transport_hash_equal') is True
            and type(genesis) is str and re.fullmatch('[a-f0-9]{64}', genesis)
            and type(height) is int and height > 0, 'LAB_REFUSED')
        report['lab_anchor'] = dict(chain=321, genesis_hash=genesis, first_height=height)
        report['phase'] = 'storage_admission'
        shared.reserve_storage(repo, report)
        entry = source_bytes(repo / profile.ENTRY, 16384)
        profile.need(launch.sha(entry) == profile.ENTRY_SHA256, 'SOURCE_REFUSED')
        fixture = source_bytes(repo / 'tools/devnet/lab/README.md', 65536).decode('utf-8')
        binary_paths = (launch.startup.BINARY, launch.startup.PAYLOAD)
        current = tuple(launch.bounded.binary_hash(repo, path) for path in binary_paths)
        report['current'] = binary_identity(current)
        launch.entry.private_root(repo)
        target = repo / OUTPUT
        target.mkdir(mode=0o700)
        destination = target
        address = None
        observed_height = height

        def revalidate():
            from . import hosted_chain321 as lab

            nonlocal observed_height
            profile.need(lab.sample_storage(lab_root) <= lab.MAX_WORK, 'SPACE_REFUSED')
            anchor = restored_wallet_run.chain_read(runtime)
            profile.need(anchor.owner is runtime and anchor.genesis.hash == genesis
                         and anchor.frontier.height >= observed_height, 'LAB_REFUSED')
            observed_height = anchor.frontier.height
            return dict(chain=321, genesis_hash=anchor.genesis.hash,
                        last_height=observed_height, cross_transport_hash_equal=True)

        def observe(build_repo, binaries, name):
            nonlocal address
            report['phase'] = name + '_interactive'
            sample = {}
            report['samples'][name] = sample

            def confirm(offered):
                nonlocal address
                if name == 'current':
                    profile.need(address is None, 'WALLET_REFUSED')
                    address = offered
                    return True
                report['same_fixture_address'] = address is not None and address == offered
                return report['same_fixture_address']

            profile.measure_process(repo, build_repo, parent, binaries, revalidate,
                actions.observe_interactive, confirm, fixture_text=fixture, genesis=genesis,
                first_height=height, report=sample)
            shared.check_space(repo, report['storage'])
            return sample['observation']['windows']

        now = observe(repo, current, 'current')
        p06 = shared.build_baseline(repo, parent, report)
        report['phase'] = 'bind_p06_entry'
        p06_repo = Path(parent['RUNNER_TEMP']) / 'syrius-p06-frame' / 'source'
        profile.need(len(p06) == len(binary_paths)
            and all(selected[0] == p06_repo / path for selected, path in zip(p06, binary_paths)),
                     'SOURCE_REFUSED')
        with (p06_repo / profile.ENTRY).open('xb') as output:
            output.write(entry)
        shared.check_space(repo, report['storage'])
        before = observe(p06_repo, p06, 'p06')
        profile.need(report['same_fixture_address'] is True, 'WALLET_REFUSED')
        report['comparisons'] = {name: shared.compare_windows(before[name], now[name]) for name in WINDOWS}
        report['phase'] = 'source_recheck'
        launch.bounded.verify_source(repo, head, parent)
        profile.need(launch.entry.source_tree(repo, parent) == tree
            and tuple(launch.bounded.binary_hash(repo, path) for path in binary_paths) == current
            and tuple(launch.bounded.binary_hash(p06_repo, path) for path in binary_paths) == p06,
            'SOURCE_REFUSED')
        report.update(phase='complete', success=True)
    except (launch.bounded.SmokeFailure, shared.PairRefused) as error:
        report['error_codes'].append(error.code)
    except profile.InteractiveRefused as error:
        report['error_codes'].append(str(error))
    except (Exception, KeyboardInterrupt):
        report['error_codes'].append('INTERNAL_ERROR')

    if destination is not None:
        try:
            raw = (json.dumps(report, sort_keys=True, separators=(',', ':')) + '\n').encode('ascii')
            profile.need(len(raw) <= MAX_MANIFEST, 'ARTIFACT_FAILED')
            with (destination / 'manifest.json').open('xb') as output:
                output.write(raw)
        except (Exception, KeyboardInterrupt):
            report['success'] = False
            report['error_codes'].append('ARTIFACT_FAILED')
    print('::notice title=Paired owned interactive frame measurements::' + json.dumps(
        dict(schema=1, scope=SCOPE, source_sha=report.get('source_sha'),
             run_id=report.get('run_id'), phase=report['phase'], success=report['success'],
             error_codes=report['error_codes'], samples={
                 name: dict(success=value.get('success', False),
                            attempt=value.get('attempt'),
                            frame_counts={key: len(window['frames']) for key, window in
                                value.get('observation', {}).get('windows', {}).items()})
                 for name, value in report['samples'].items()}), separators=(',', ':')))
    return report
