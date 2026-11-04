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
