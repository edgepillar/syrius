# Current checks and remaining redesign acceptance

This is the Source694 snapshot. [Source695](source695-seam-coverage.md)
subsequently closes the original V03 coverage requirement, bringing progress
to 73/80 without repeating native execution. The earlier snapshot below remains.

Recorded 2026-11-12. The original scope remains 80 rows: 72 done, four in
review and four blocked. The core interface is available for Draft review;
this is not complete redesign acceptance or a release qualification.

## Full Linux checks

The [existing PR Fast Validation run](https://github.com/edgepillar/syrius/actions/runs/43140599549)
succeeds at `97f47420dff3f24553b7c134f73326024e525ddf`, tree
`dd3d7583c043ca167a12e132633d33cbc206864c`, attempt one, job `130926373157`.
Its [unchanged workflow](https://github.com/edgepillar/syrius/blob/97f47420dff3f24553b7c134f73326024e525ddf/.github/workflows/pr-validation.yml)
runs on Ubuntu 24.04 with the pinned Flutter 3.47.7 SDK. All steps complete
successfully, including:

- The isolated Python controller suite before SDK allocation.
- Locked dependency restoration for the application and patched package.
- Patched package analysis and full application/integration source analysis.
- `flutter test test --exclude-tags chain`, covering the full `test/` directory.
- Code generation, integration-source formatting and `git diff --exit-code`.

Application analysis permits informational findings. This observation does not
project an exact full-suite test/skip count or an informational finding count.
The earlier 1,476-case selected Windows harness result belongs to
[Source692](https://github.com/edgepillar/syrius/actions/runs/43137401800);
that count is not substituted for the full Linux suite. The final Git check
establishes no tracked diff after generation and formatting. The workflow has
no native wallet build, devnet lane or artifact upload. It does not qualify
Windows runtime, images, frame times or a release.

## Original end state

| Requirement | Current evidence and remaining work |
| --- | --- |
| Reproducible Windows setup and Debug/Release builds | Earlier Windows evidence retains its original revisions. The documented Windows Docker route and current complete setup acceptance remain open under P03/P09. |
| Application analysis and unit/widget tests | The full Linux steps above pass at the exact revision. The selected Source692 Windows harness checks retain their separate scope. No Windows/native inference is made from Linux execution. |
| All 47 screens in both themes and every pair accepted | All 94 literal outputs are available; 50 pairs have individual review bindings and 44 await review. Zero whole-image matches are accepted. |
| Running Motion/Shaders review and baseline frame times | Three paired native measurements and the running-build review remain open. Widget timing and passive diagnostics do not replace them. |
| Every seam refuses from its control, shortcut and Go To | Existing Settings, entry and surface observations remain qualified at their recorded revisions. Complete native route coverage remains open, including the failed Home prefix. |

## Seed scope

The [Source548 producer](https://github.com/edgepillar/syrius/actions/runs/42634466792)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/42638567706)
retain the six confirmed seed effects: Stake, Fuse, Token, HTLC deposit, Project
and a second funded address, with normal copied actor closure. These receipts
alone do not close F06's required screen-state proof.

The original task requires existing capabilities to be wired and missing
services to remain drawn behind seams. The reachable Swap seed is the existing
HTLC deposit. Implementing the missing two-sided offer/acceptance coordinator
is not part of this redesign; `Seam.swapTerms` remains in place. Native proof
of the required post-seed screen states, including the populated existing Swap
presentation, remains necessary. A synthetic fixture or an empty earlier frame
does not prove that a real deposit appears in that presentation.

## Remaining original rows

| Row | Required next evidence |
| --- | --- |
| P03 | Complete the written Windows setup, including the unresolved Docker Linux route. Preserve the earlier WSL installation success and kernel refusal separately. |
| P09 | Execute and qualify the documented Windows Docker/`lab.sh` route. Earlier isolated native sends and Linux lab checks retain their own scope. |
| F06 | Complete the required post-seed screen-state proof using existing capabilities and the explicitly permitted harness fixtures. Do not build the missing Swap coordinator. |
| V01 | Compare and resolve all 94 literal pairs, then explicitly accept each match. |
| V02 | Review every running Motion/Shaders row and complete the three baseline frame-time comparisons. |
| V03 | Finish native refusal observations for every registered control, shortcut and Go To route. |
| V05 | Complete the remaining individual views, the rendered compare page and the independent 94-pair review. |
| V06 | Verify all five original end-state requirements together. Passing the full Linux workflow closes no unrelated native or visual gate. |

Detailed platform, image and motion work remains in the deferred phase chosen
for the fast first delivery. No new native experiment or local SDK/artifact
transfer is admitted by this audit. Earlier failures, unknown causes and
pending archive authority remain preserved.
