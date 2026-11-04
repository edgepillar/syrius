# Home paragraph baseline alignment

The original Source445 observation
[41879360932](https://github.com/edgepillar/syrius/actions/runs/41879360932),
attempt one, job 126747573974, retains its failed first widget group: 596 passes
and one failure, with the second group unreached. All 1,006 Python controls
complete with three existing skips; fourteen asset observations and selected
analysis pass with zero findings. The original run is terminal with zero
artifacts. Earlier failures remain attached to their own sources.

The bounded synthetic fixture observation is dark, RTL, normal text scale and
the primary coin. The amount baseline is 95.94000053405762, the dollar baseline
95.54000091552734, and the amount's top is 65. The configured target baseline is
30.540000915527344. The dollar therefore follows its target, but is approximately
0.4 logical pixels above the amount's actual paragraph baseline. This exceeds
the original 0.1 tolerance. The closed failure kind is OTHER; no full error text
or private value is retained or reconstructed.

Source446 uses `TextPainter.computeDistanceToActualBaseline` with the alphabetic
baseline for the existing constant `0 0` measurement. Flutter 3.47.7's
[paragraph implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/rendering/paragraph.dart)
uses that API for both actual and dry paragraph baselines. Its
[text painter](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/painting/text_painter.dart)
returns the paragraph's alphabetic baseline separately from line metrics.
Using the same baseline API is the source-derived correction; fresh hosted
execution must determine whether it resolves the observed difference.

The sample, painter, symbol gap, height, typography, responsive Wrap and financial
data/actions remain. No private amount is measured. Every test byte, input,
theme/direction/scale combination, reachability assertion and tolerance remains
unchanged. The selection stays 1,230 ordinary cases in 48/48-file groups
(597/633), or 1,232 with asset fidelity. The unchanged Python projection keeps
its actual 23 local passing controls; the hosted total remains 1,006 with three
existing skips. No local SDK/native execution or artifact transport is added.

Fresh hosted qualification is pending. Full Windows, chain-321, native seed,
visual, motion and frame-time acceptance remain deferred/open. The original
ledger stays 72/80, 50/94 historical literal outputs, 44 missing and zero accepted
whole-image matches. The PR remains Draft with English public text and
edgepillar attribution.
