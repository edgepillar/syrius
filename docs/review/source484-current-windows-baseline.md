# Current full Windows baseline

Updated: 2026-11-05T07:51Z.

Source484 `7c4848a293698d02a6e99a8dcaa33ad81d4b9f70`, tree
`d366eb8c1223dee6e3df3c5aba6785cdd5774b48`, is independently qualified for
the complete nonchain Windows suite, Debug/Release and all twelve baseline checks.
The existing PR remains Draft.

| Evidence | Original run | Job |
| --- | --- | --- |
| Windows producer | [41983354537](https://github.com/edgepillar/syrius/actions/runs/41983354537) | 127098312295 |
| SDK-free independent reader | [41987601274](https://github.com/edgepillar/syrius/actions/runs/41987601274) | 127111977515 |

Both run at attempt one, complete successfully and have zero artifacts.
Every tested-source run is terminal. The reader consumes the original 42,182-byte
job log, digest 5fa9f62077c8bac344e8d4722f611322206623f3f503895f430a369f0ad558be,
in hosted memory without repeating tests, builds or native work.

## Actual results

The complete suite has 4,939 passes, one existing skip, zero failures/error events,
577 hidden and 5,517 terminal events. Its original process exits zero normally
in 955.094 seconds with 2,643,592 complete bytes, no overflow or forced closure.
The selection remains the entire test directory with only chain-tagged cases
excluded; unfiltered chain tests are not qualified.

Root analysis reports zero errors, zero warnings and 1,299 infos. Vendored
analysis reports no findings. Root infos remain recorded; this is not a
zero-finding global analyzer claim. The separately pinned
[Source483 focused result](source481-about-strip-geometry.md#fresh-source483-focused-result)
retains 1,297 widget passes and zero selected findings, with the same 1,976
runtime/source entries and digest
fcfd7c7e62389657ceaf949893c6c651dc5d14d623335c5dafd3dff06648c608.

| Baseline check | Result |
| --- | --- |
| Source identity and initial cleanliness | pass |
| Locked dependency restoration | pass |
| Windows desktop doctor | Windows and Visual Studio pass |
| Vendored analysis | zero findings |
| Root analysis | zero errors/warnings, 1,299 infos |
| Entire nonchain unit/widget suite | 4,939 passes, one existing skip |
| Generated source/localization correspondence | pass |
| Debug build | normal zero exit, 116.157 seconds |
| Release build | normal zero exit, 146.250 seconds |
| Source/Debug/Release DLL hashes | identical |
| Three DLL map/export lookups | pass |
| Final source cleanliness | pass |

All original commands have complete output and no forced termination.
The three DLL variants share SHA-256
f1f79ee184b9c0e3cd92d2f5c49e52c68e7a4670357a0cf1df95a0ac6de8973a.
The probes map each DLL and look up exports. Export invocation, ABI behavior,
DLL initialization side effects and wallet use remain outside that evidence.

## Count reconciliation

The initial source-only expectation was 4,935 passes plus the existing skip.
It counted 35 explicit additions after Source368's 4,900-pass baseline.
Two added seams, `activityAddressScope` and `tokenExplorer`, also expand
the existing per-service and per-seam Go To registries from thirteen entries to
fifteen. Each registry adds two generated cases. Those four additional cases
give 39 total additions and the observed 4,939 passes.

The source comparison binds the original
a06c9bfa5d6caa207f97f950cae6287bea3ec0f8 and the exact Source484 revision above.
Initial expectations, producer inputs, original outputs and reconciliation are
preserved. No completed test, build or SDK allocation is repeated to resolve
the source-count omission.

## Remaining acceptance

The earlier [Source368 native result](source368-windows-native108-and-fast-delivery.md)
keeps its original Deposit refusal, incomplete seed prefix and unknown outcomes.
This nonchain baseline does not qualify current wallet startup/transactions,
complete F06 states, Windows Docker Desktop/Linux mode, VM disposal, native
pixels or a visual match. A deposit alone does not establish a completed Swap.

The [Source459 Linux default lab result](source459-reference-default.md#actual-source459-default-result)
and [Source461 WSL component/kernel result](source461-wsl-system-kernel.md#actual-source461-result)
retain their own exact source pins and limits. No original failed run is retried.

Source485 changes documentation and exact body346 only, preserving all 1,976
qualified runtime/source entries. This record allocates no duplicate SDK, build,
wallet, catalog transfer or motion job. Main acceptance remains 72/80 original
rows: P03/P09/F06 and V01/V02/V03/V05/V06 stay open. Fifty literal outputs remain
available, 44 are missing and zero of 94 whole-image matches are accepted.
The first delivery remains ready for Draft code review.
