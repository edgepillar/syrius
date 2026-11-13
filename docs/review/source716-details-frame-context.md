# Retain the original Details frame context

Updated 2026-11-13.

## Change

Ready's failed shot already carries a typed, finite scheduler observation from
the original capture gate. The Details failure projection retained its reply
category but dropped that observation. Home already retains the same facts.

The Details projection now carries those existing facts only for the four
recognized original frame refusals. Its schema 3 requires a validated frame
state and the original reply category. Earlier schema 1 and 2 records retain
their original meaning. Other replies cannot acquire a frame-state claim.
The shared Python validator preserves the original Home validation and refusal
code while applying the same closed field and type checks to Details.

The fields are scheduler phase, lifecycle, frame scheduling and binding flags,
registered-callback flags and a bounded callback count or explicit unknown.
They contain no raw errors, input, identifiers or paths. This does not change
frame scheduling, the 250 ms admission deadline, held-frame semantics, readback,
theme restoration, the 16 ms timing budget or the original publication guards.

Three selected existing Python cases pass in memory. They cover the Details
and Home projections, original entry wrapping, both frame-state versions,
foreign fields, invalid types and callback bounds. The previous Details
parser rejects the extended positive witness. Existing Dart coverage now
checks the Ready projection across every reply category. Executed Source716
checks and the original native failure are recorded below.

## Executed Source715 results

These observations bind to `1b93ee03f63ac443bd2b3ea32bae0ab7c04d9073`, tree
`5d23547227b303c76de4159d0442074b4b8d8a8f`. Source716 has not inherited their
runtime qualification.

The [paired launch producer](https://github.com/edgepillar/syrius/actions/runs/43344313240)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43347311411)
verify 234 current and 2,274 P06 frames, both original windows, the pinned P06
overlay and five normal actor exits. Acquisition succeeds. Timing acceptance
does not: raster and distinct-frame duration dominance fail at the unchanged
16,000 us budget. There are 121 current and 2,213 baseline reported slow frames;
their counts alone do not establish the duration comparison. The windows
retain 395 current and 2,189 baseline frame-number gaps. Longest total spans
are 509,146 us and 252,781 us respectively. V02 remains open, including the
separate page-change, disclosure, Motion and Shaders checks.

The [Staking/Token producer](https://github.com/edgepillar/syrius/actions/runs/43345119346)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43347426307)
preserve ENTRY_FAILED at the initial lab send. The original sender fails during
confirmation with the finite display category `node_not_synced` and
`original-outcome-unknown`. Seeds and catalog images are not reached. The
reader executes 75 and 10 actual cases, totaling 85. Five original nodes exit
normally, while required-actor forced cleanup remains recorded. The underlying
cause and financial outcome remain unestablished.

The [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43345260344)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43347479452)
preserve ENTRY_FAILED at the dark `shotRequest`, with
`frameDeadlineExceeded`, zero verified PNGs and required-actor forced cleanup.
The reader passes 123 actual cases and verifies 81 producer source files and
both original archives. Five original nodes exit normally; full lab closure
and the inner cause remain unqualified. The original failure has no retained
Details frame-state observation; this change does not invent one for it.

All three Source715 producers pass selected zero-finding analysis and 1,214
Python cases with eighteen platform skips. Selected Dart passes are 1,482 for
paired launch and 1,480 for each lab lane. Full non-chain Linux execution
remains bound to Source714 and its exact comment-only correspondence.

No original attempt was retried and no artifact was downloaded locally.
Original acceptance remains 73/80; no new visual match or F06 closure is
claimed. A separate fixed aged-fuse fixture observation remains design work.

## Executed Source716 result

Source `4f96063993dd71872d1870b8d750b59098f77990`, tree
`e2cc9870232dcbb37c422c4f63e8de74811f5241`, passes the
[full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43349554689):
controller tests, application/patched analysis, the full non-chain directory
and tracked generation. Global test and info totals are not projected.

The [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43351077665)
passes 1,480 selected Dart cases, 1,214 Python cases with eighteen platform
skips and selected analysis with zero findings. It then retains ENTRY_FAILED
at the light `shotRequest`, with `frameDeadlineExceeded`. Its schema 3
observation reports a current binding, enabled frames, registered begin/draw
callbacks, a scheduled frame, zero observed persistent callbacks, scheduler
phase `idle` and lifecycle value `none` at the original 250 ms deadline.

The [independent reader](https://github.com/edgepillar/syrius/actions/runs/43353572532)
passes 123 cases and verifies both original archives and 81 producer files.
There are zero verified or retained PNGs, with required-actor forced cleanup.
Five original nodes exit normally; complete lab closure stays unqualified.
Reaching the light shot request does not establish that no earlier dark
capture occurred. The original first failure and its underlying cause remain
separate from Source715's dark shot refusal. No native run or transport is
retried, and no artifact is downloaded locally.
