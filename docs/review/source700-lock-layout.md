# Lock field geometry and picker alignment

The archived Lock capture places its 420 px card 35 px above the reference.
The shell previously reserved the 44 px status strip plus 26 px of entry
insets before centering the card. Entry now uses the full body field while
the status stays at the bottom with its original inset. Working pages
continue to reserve the measured status height and their 12 px gap.

The same page, authentication State, rail and status children retain their
owners while entry and working modes change. Existing regressions now check
full-field entry geometry and a reachable status in both text directions.

The wallet picker's label and optional address now share the remaining
width as one group, keeping its disabled arrow at the trailing field edge.
The current wallet's display facts and unavailable catalog seam remain.
The existing dark/light and LTR/RTL cases check the measured arrow edge.

## Validation

Source699's [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43252288032)
passes application and patched-package analysis, the full non-chain test
directory and the tracked generated-file check. Exact global test and
informational finding counts are not projected.

The [Source699 Windows producer](https://github.com/edgepillar/syrius/actions/runs/43252347402)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43256566119)
verify the original Stake and Token prerequisites, four genuine catalog PNGs
and normal required wallet/node closure. The selected Windows suite passes
1,480 Dart cases and 1,214 Python cases with eighteen platform skips; selected
analysis has zero findings. The separately recorded MSVC telemetry helper was
terminated after the required actors had closed. These captures still need
visual review.

The [Source700 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43258042063)
passes analysis, the non-chain test directory and tracked generation checks.
The [Windows producer](https://github.com/edgepillar/syrius/actions/runs/43258106512)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43261487421)
verify six genuine Lock PNGs and four normal actor exits. Selected Windows
checks pass 1,482 Dart cases, 1,214 Python cases with eighteen platform skips
and analysis with zero findings. Visual comparison of these captures remains
pending. No new visual match is accepted. The original
acceptance remains 73/80; P03, P09, F06, V01, V02, V05 and V06 stay open.

