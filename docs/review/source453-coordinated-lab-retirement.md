# Coordinated lab retirement

The [Source451 trial](source451-bounded-lab-observations.md#actual-source451-result)
retains a failed thirty-second progress check and observer/rpc exit events 137.
Three pillar exits are zero, and no OOM event is observed. The exact inner causes
remain NOT_ESTABLISHED. Neither original trial is retried or relabelled.

The reviewed [Compose v2.40.3 source](https://github.com/docker/compose/blob/v2.40.3/pkg/compose/down.go)
removes services in reverse dependency order. The lab graph can therefore retire
rpc and observer while their peers remain live. The separately qualified custom
backend submits its complete original set together. This is a source-derived
reason to correct ordering, not proof that ordering caused the old exit codes.

The repository's `lab.sh down` now reads the current Compose project IDs, validates
every offered value before mutation, and submits at most five unique full hex IDs
in one `docker stop --timeout 10` command. The reviewed
[Docker CLI v28.5.2 source](https://github.com/docker/cli/blob/v28.5.2/cli/command/container/stop.go)
dispatches a multi-container stop through parallel operations. Ten seconds is
the documented [default Linux grace](https://docs.docker.com/reference/cli/docker/container/stop/).
This change does not raise it. Compose removes the stopped project only after
the stop command succeeds. Listing/identity/stop errors return without removal
or retry. An already empty project skips the stop and preserves named volumes.

The hosted controller still independently rechecks the five original ID/start/PID,
image, role, port, asset and volume bindings before the one down invocation.
Unknown starts are not adopted. Five original zero-exit/no-OOM events, unchanged
source/genesis and positive chain-321 progress remain required. A successful
Docker stop command cannot admit nonzero application exits.

Only `lab.sh` changes among the four pinned lab inputs; the controller pins the
new bytes. Node `590f43ca7a24dccd8e883bc8903a0cb02e54528a`, the upstream
Dockerfile, Compose startup graph, assets, frontier script and its thirty-second
status window remain unchanged. The original 900/45/45-second parent command
limits, output/storage caps and default-off manual runtime selection remain.
Production failure is not repaired by extending its observation window.

Six opt-in Linux controls exercise the actual Bash down path against a
regular-file Docker fixture: one complete batch, listing refusal, invalid or
duplicate/excess identities, stop refusal without removal, an empty project,
and removal refusal without a second stop. They start no Docker daemon, chain
node, wallet or SDK. Local execution retains twenty passing pure/mocked controls
and six explicitly unselected shell cases. The full hosted preparation is
1,032 Python cases; fresh source and runtime qualification is pending.

No application Dart, financial route, dependency or reference changes. The
1,230-case UI qualification remains bound to Source447. This recipe change does
not qualify Windows Docker Desktop, wallet import/send, seed state, native pixels
or final acceptance. Full progress stays 72/80, with zero accepted visual matches;
heavy Windows, image and performance work remains deferred.

## Actual Source453 result

Source453 `fa24bd54936d3f01cb1832c8ff95aaa251b7f7f1`, tree
`701aa8adcb0f726d8b6e78ed2e7b3a6b31715703`, completes its source-only
[41909585709](https://github.com/edgepillar/syrius/actions/runs/41909585709)
with 1,032 controls, two existing Linux skips and zero failures/errors. All six
actual-script/fake-Docker cases execute successfully. Source checks pass before
and after; runtime is skipped and artifacts are zero.

The separate corrected-recipe trial
[41910010050](https://github.com/edgepillar/syrius/actions/runs/41910010050),
attempt one, runtime job 126855015671, is terminal and failed with zero artifacts.
Its source job also passes 1,032 controls with two skips and zero failures/errors.
All seven bound notices and 22 complete unforced command receipts consume; the
largest notice is 3,051 bytes. Original up exits zero, observing chain 321 from
one to two over thirty seconds. Status then exits one after height two remains
unchanged for thirty seconds. Its exact inner cause remains NOT_ESTABLISHED.

The one corrected down command exits zero. Pillar/pillar2/pillar3/rpc each have
one zero-exit event; observer has one exit-137 event. No OOM event is observed.
This differs from Source451's two nonzero roles, but separate fresh executions
do not establish the old inner cause or a stable RPC repair. The strict five-zero
predicate still refuses shutdown. Production and final native source checking
remain unqualified, with COMMAND_FAILED and separate STOP_UNKNOWN retained.

Container stdout/stderr log reads yield no recognized code. The pinned logger
uses files; [Source454](source454-node-log-file-observations.md) adds fixed
file observations without changing production, resource or exit requirements.
No original trial is retried. Full Windows/wallet/seed/visual/performance scope
remains open; 72/80 and zero accepted matches are unchanged.
