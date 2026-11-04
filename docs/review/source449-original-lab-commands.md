# Original lab command qualification lane

The retained Linux Docker result
[40229022991](https://github.com/edgepillar/syrius/actions/runs/40229022991)
at `15f324953f2b79d4b1073538c4c80e43a42ea0c1` succeeds for the existing
source-built custom backend. Repeating that job would not execute the original
`tools/devnet/lab/lab.sh` image/command route required by P09. That distinction
and Windows Docker Desktop/Linux mode remain open.

Source449 adds a separate **Original lab commands** workflow. A path-filtered
push to dev/redesign runs controller tests only. Manual execution defaults off;
an explicit first-attempt dispatch on the fork's redesign branch selects one
fresh Ubuntu runner. The existing main workflow's 25 inputs remain unchanged.
The job uses the original `up`, `status` and `down` commands without changing
their four pinned script/configuration inputs or the original node revision
`590f43ca7a24dccd8e883bc8903a0cb02e54528a` and tree
`3bedc2fde71035c983997451c2d7e76b66d2d210`.

The original upstream
[Dockerfile](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/Dockerfile)
uses moving base-image tags. Each actual trial therefore records its final
image digest; a source pin alone does not freeze the base images for future
builds. No dependency, application, reference HTML/PNG or Dart test changes.

Admission requires an empty original project namespace and absent build/assets
directories. Child tools receive a new private environment without Actions
credentials. The original commands must observe increasing heights on chain
321. Five containers must match their image, original ID/start/PID, role, peer
address, read-only assets and exact loopback HTTP/WS bindings. A changed
identity refuses the name-based down command. A partial unadopted start stays
held for unqualified VM disposal; it is not guessed into a successful cleanup.

After one original down command, bounded
[Docker event history](https://docs.docker.com/reference/cli/docker/system/events/)
is restricted to the five bound IDs. Every original must have one zero exit
and no OOM event; missing, repeated or nonzero exits refuse. Source and genesis
are rechecked. A close failure cannot erase an earlier observation failure.
Named volumes and raw private evidence remain; VM disposal is not qualified.

The up/status/down command limits are 900/45/45 seconds inside a twenty-minute
job. Each stream is capped at 2 MiB. Cooperative samples cap owned paths and
observed allocation growth at 4 GiB, with the declared fresh non-secret fixture's
2 GiB floor and 4 GiB initial reserve. These are sampled controls, not an
OS-enforced quota. Local production storage retains its 10 GiB floor and all
existing data. No local binary transport or SDK/native execution is introduced.

All sixteen local pure/mocked controls pass. They cover admission, real command
wiring, progress, original identity, public binding refusal, asset ownership,
exit events, privacy and separate first/close failures. The prepared full Python
suite becomes 1,022 cases; actual hosted skips/results must be observed. Fresh
source registration and manual runtime execution remain pending.

The qualified 1,230-case UI remains at Source447; all 1,970 existing runtime
entries are unchanged and the two new Python files are separately scoped.
The environment document now leads with that current qualification and retains
Source353 as a historical snapshot. P03/P09, wallet import/send on this instance,
F06, current full Windows/native, visual pairs and performance acceptance remain
open. Main progress stays 72/80 with zero accepted whole-image matches.
