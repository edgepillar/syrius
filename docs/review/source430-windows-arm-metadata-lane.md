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
Registration and actual manual execution remain to be observed.

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

Source review confirms the wrapper and preserved probe. The path-filtered source
run and manual Windows observation remain pending. No local PowerShell or SDK
is executed. Application, Dart/Python test, harness, dependency, probe and main
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
