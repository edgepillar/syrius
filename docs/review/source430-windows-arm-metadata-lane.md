# Windows Arm metadata lane

Source430 adds `.github/workflows/windows-arm-capability.yml` for the existing
finite `tool/ci/windows_container_capability.ps1` query. The probe is unchanged.
This is a bounded feasibility check for the open P03/P09 environment route,
separate from Windows wallet builds, native chain-321 work and visual acceptance.

The main qualification workflow's `windows_inventory_only` input starts both
the Arm query and the x64 inventory job. The latter unconditionally sets up
Flutter before running its inventory controller. It is not an SDK-free route.
That workflow already defines 25 inputs, the documented
[workflow-dispatch limit](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_dispatchinputs).
The separate lane adds no input to that interface and changes none of its jobs.

The fork's retained Source429 API snapshot identifies `master` as its default
branch. The new lane uses a path-filtered `redesign` push to run one small Linux
source check; the Windows job is skipped for that event. This registers the
published workflow without changing a branch setting. A subsequent manual
dispatch selects only the Windows job. GitHub documents
[dispatch after a workflow has run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).
The source and manual observations below now bind both event profiles.

Both jobs use shallow checkout, omit persisted credentials, have a five-minute
bound and request only `contents: read`. The push job checks the exact head and
a clean tree. The manual job uses the standard `windows-11-arm` label listed in
[GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
It opts into the unchanged probe through its existing environment gate. There
is no SDK setup, dependency installation, build, cache or artifact upload step.
No probe event or runtime environment value is substituted.

The probe reads a fixed set of OS/architecture facts, virtualization flags,
optional-feature states and tool presence. Individual CIM queries retain their
five-second bound; output remains a finite allowlisted JSON notice. Unknown
values remain unknown. The original probe still refuses unsupported contexts,
checks source identity before and after, preserves attempt-one admission and
reports nested virtualization as `NOT_ESTABLISHED`. It starts no kernel,
container, wallet or node and enables no feature.

Source review and the hosted observations below confirm the wrapper and
preserved probe. No local PowerShell or SDK is executed.
Application, Dart/Python test, harness, dependency, probe and main
qualification-workflow bytes retain the completed first-delivery lineage from
tested Source428 through documentation-only Source429. The existing 1,229-case
and zero-finding selected-analysis result is reused with its original source;
this new workflow is not claimed to have run in that earlier qualification.
[Exact body330](pr-body-330.md) preserves the prior handoff.

This lane cannot establish Docker Desktop installation, Docker Linux mode,
nested virtualization, a usable x64 wallet or chain-321. P03/P09 and the complete
original acceptance gates remain open. Heavy platform/lab, image transport,
motion/frame-time and final acceptance stay deferred. Original acceptance stays
72/80, with 50/94 historical literal outputs, 44 missing and zero accepted
whole-image matches. The existing PR remains Draft.

## Source430 hosted observations

Tested metadata source is `d2b8ae9c116efd23b5977308278c65dbd36a150d`, tree
`225a631c14195f5f3161d2dca47b5607a185c66d`.
[Source registration 41828792703](https://github.com/edgepillar/syrius/actions/runs/41828792703),
attempt one, job 126570296401, completes the Linux source check successfully;
the Windows job is skipped. That result establishes registration and source
checking, not platform facts.

[Manual observation 41829942037](https://github.com/edgepillar/syrius/actions/runs/41829942037),
attempt one, job 126574219858, completes the Windows Arm query successfully;
the source-only job is skipped. Independent read-only API reconciliation binds
the exact workflow, source, job, attempt and complete allowlisted final frame.
Both source-bound runs are terminal with zero artifacts. Neither run is retried,
and the original platform query is not replayed during reconciliation.

| Field | Observed value |
| --- | --- |
| OS and process architecture | `arm64` / `arm64` |
| Windows product type | `1` (desktop) |
| Hypervisor present | `true` |
| Firmware virtualization, VM monitor and SLAT flags | `false`, as reported on Arm; no native x86 inference |
| Virtual Machine Platform | `enabled` |
| Windows Subsystem for Linux feature | `enabled` |
| Hyper-V hypervisor feature | `enabled` |
| WSL application on PATH | `true` |
| Docker application on PATH | `false` |
| Standard Docker Desktop file | `false` |
| Nested virtualization | `NOT_ESTABLISHED` |
| Docker Linux mode, x64 wallet and chain-321 qualified | `false` |

These values describe this one fresh hosted Arm VM. A hypervisor, enabled
features and a WSL command do not establish a running kernel or a working Linux
container. The three reported CPU flags do not establish Arm nested capability
or its absence. The missing standard file is not a search of every installation
location. The probe records no installation, feature change, download, kernel,
container, wallet or chain-node startup, and source remains unchanged.

Source431 changes documentation only. The original application/test/harness,
probe, dependency, reference and main-workflow bytes remain identical to the
qualified UI lineage from Source428. The new wrapper is qualified separately by
its actual source and manual runs. No current-source Flutter rerun or complete
Windows wallet build is claimed. The first delivery remains ready for Draft
code review; P03 installation, P09's Docker route and all full platform/lab,
visual, motion/performance and final acceptance gates remain open and deferred.
