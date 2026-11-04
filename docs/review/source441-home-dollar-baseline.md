# Home dollar baseline

The Home reference places each `.usd` span in the amount's inline formatting
context. Its normal vertical alignment is the shared alphabetic baseline.
The primary `.big` row uses line height 1.1; the secondary `.num` row inherits
the body line height 1.45. These are source observations from
`mockups/redesign/src/10-home.html` and `00-head.html`, separate from measuring
the earlier Source353 native images.

The Home view instead centered the small dollar widget in its amount row's
wrap, and the secondary numeric style used line height 1.1. Source441 retains
the wrap and its narrow-window reflow while giving each dollar widget the
corresponding amount line's baseline and height. The secondary numeric style
now inherits the reference's 1.45 line height. Symbol sizes, measured interior
spaces, twelve-pixel dollar gap, colors and the original hidden-eye placement
remain.

The existing constant-glyph text measurement now also returns line height and
baseline. It does not read a hidden amount, and adds no extra text painter or
numeric formatting path. Both the rendered row and its width planner use that
same measurement. Exact values, prices, total calculation, feed listeners,
privacy state, original animation clocks and action callbacks remain unchanged.

One appended widget case compares actual rendered numeric/dollar baselines
with bundled fonts in both themes, directions and normal/double text sizes.
It also requires the original estimates and Send/Receive controls to remain
reachable at 1024 by 780. Every preceding Home case body remains byte-identical.
The same 96-file selection prepares 1,230 ordinary cases in 48/48-file groups
(597/633), or 1,232 with asset fidelity. The complete hosted controller selection
now expects 1,001 cases with its three existing skips, including the separately
qualified WSL query/installation controls. Process, worker, output and total
bounds are unchanged. No local SDK executes.

Hosted analysis and widget execution are pending. The original Source428 UI
result retains its tested source; it does not qualify these changed Home bytes.
The Source439 WSL installation result remains source-bound and is not replayed.
Full Windows builds, wallet/lab work, image transport and motion/performance
qualification stay deferred. No new native image or whole-image match is
accepted. Main progress remains 72/80, with 50/94 historical literal outputs,
44 missing and zero accepted matches. The PR remains Draft.

[Exact preceding body334](pr-body-334.md) preserves the prior published handoff.

## Numeric span observation correction

Source442 corrects one new test observation while the original Source441 run
41862348827 retains its source and attempt. The pinned
[Flutter 3.47.7 Text implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/widgets/text.dart#L695-L704)
wraps a supplied rich span in an outer span with the ambient style. AmountText
supplies its numeric style on the inner span. Reading the outer style cannot
establish the amount's line height.

The test now reads that inner numeric span. Its exact 1.1/1.45 expectations,
rendered baseline comparison, all theme/direction/scale/viewport inputs,
reachability checks, case registrations and every application byte remain.
This is a source-derived correction, not an executed failure diagnosis. The
original queued producer is neither cancelled nor replayed; its actual result
and any later fresh-source qualification must retain their separate sources.
The same 1,230-case widget and 1,001-case Python selections remain pending.
[Exact preceding body335](pr-body-335.md) preserves the published pending state.

## Original Source441 result and baseline query correction

[Original run 41862348827](https://github.com/edgepillar/syrius/actions/runs/41862348827),
attempt one, job 126687333819, finishes failed at its original Source441 tree.
All 1,001 Python controls complete with three existing skips and no failures or
errors; fourteen assets and empty selected analysis pass. The first 48-file
widget stream exits one normally with complete output, 596 passes, one failure,
68 hidden and 665 terminal events. Its second group is unreached. The finite
detail records home_hero_test.dart:1194 and a Flutter box assertion at line 2479;
the full original error message is not retained. All original jobs are terminal
with zero artifacts. The dispatched tree is verified from immutable Git objects
while the separately admitted Source442 successor is checked out.

The pinned [RenderBox contract](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/rendering/box.dart)
restricts getDistanceToBaseline to layout/paint calls. The test calls it after
pumping. Source443 uses getDryBaseline with the paragraph's actual constraints
and keeps the actual global top position. The documented dry result represents
the baseline at those same constraints without changing layout. This source
diagnosis fits the retained location; no unretained message is reconstructed.

The numeric/dollar baseline tolerance, non-null requirement, inner numeric-span
height expectations, all original input/viewport/reachability checks, case
counts and application bytes remain. Source442's separate wrapper observation
correction stays source-derived. Neither original producer nor any financial
operation is replayed. Fresh Source443 execution is pending; full native pixels,
platform/lab acceptance and the original 72/80 scope remain open.
