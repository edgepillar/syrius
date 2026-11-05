# Activity reference spacing

Based on Source488 691e3d0b1f0cb178c1eae3ee26db9759e74cabb1, tree
a74f4cf60d2e0fdeb1c215aca1eba9f1f925b8e0.

The Home reference uses a ten-pixel `.row` gap between the movement mark and
label. Activity used the eight-pixel token-row gap instead. A dedicated
semantic token now follows the original movement spacing without changing
token badges or other rows.

The reference's plain external-link mark is the fourteen-pixel `.i.s` SVG.
Activity already used the original vector, but its IconButton reserved the
shared twenty-six-pixel small-button extent. That control could enlarge the
row beyond its forty-pixel minimum. Its icon, minimum and maximum extent now
use fourteen pixels with standard density and zero padding. Scaled text can
still grow the row. The twenty-six-pixel Message pill retains its own size
and unavailable-service gate.

Explorer URI/hash/chain selection and callback, source-owned entries, relative
time, exact amounts, beneficiary labels, privacy masking, movement colours,
hover motion and all vector paths retain their implementation. No dependency,
service, chain operation or interface string is added.

## Selected controls

Every previous Activity test line and all ten static registrations remain.
The existing normal-size dark/light cases check the rendered ten-pixel gap,
fourteen-pixel explorer box and forty-pixel row. The existing RTL case also
checks the mirrored gap and the row's natural line growth at 1.5 text scale.
Expected geometry comes from the reference's fourteen-pixel, 1.45 line box,
nine-pixel vertical insets and one-pixel separator. Existing exact amount,
original mark, link, pointer/key refusal and semantics assertions remain.

All one hundred focused files and both 50-file groups remain. Counts stay
1,305 ordinary widget cases (627/678), or 1,307 with the separate asset
selection, plus 1,063 Python controls and eighteen explicit Windows skips.
The existing bounds, one worker, startup/refusal and source checks remain.
Current-source selected analysis and widget execution are pending. No local
SDK or native process is executed for preparation.

X613 tracks this selected correction. Fresh native pixels and whole-image
review remain open under X521-X528. The first delivery remains ready for Draft
code review, with detailed platform/lab, seed, seam, motion/performance and
final acceptance in phase two. Original progress stays 72/80, with 50/94
historical literal outputs, 44 missing and zero accepted matches. Native109's
copied Deposit remains UNKNOWN and its inner cause NOT_ESTABLISHED. All
original failure/hold/unknown evidence and actual PR body archives remain.

## Original Source489 result and Source490 list fixture

Original [42030825906](https://github.com/edgepillar/syrius/actions/runs/42030825906),
attempt one, job 127256540515, tests Source489
c6894ee69ec7e401aeadaa2e1fa18a62b95fe999, tree
d55769398892d36da9862efc4a89d01749ac92a1. The first 50-file stream finishes
normally with exit one, 624 passes, three failures/errors, zero skips,
70 hidden and 697 terminal events. All three retained failures point to the
new row-height assertion. The preceding movement-gap and explorer-box checks
pass. The second group is unselected. The complete unforced stream is 350,248
bytes in 217.047 seconds. All 1,063 Python controls/eighteen explicit Windows
skips, fourteen assets and zero selected analyzer findings pass. Startup and
refusal controls pass; all jobs are terminal with zero artifacts.

Source review shows a fixture mismatch: the test placed an ActivityRow directly
under a bounded viewport, while the actual card creates its rows in a vertical
ListView. Flutter documents that [Align expands under bounded constraints and
shrinks to its child when unconstrained](https://api.flutter.dev/flutter/widgets/Align-class.html).
That distinction applies to the row's amount and action Align widgets. The
old actual heights were not retained, so their numeric values are not inferred
from this explanation.

Source490 puts the existing test child inside a zero-padding vertical ListView,
matching the production row constraint model. All original gap, control-size,
height, exact amount, mark, action, privacy and semantics assertions remain.
The Activity implementation and tokens retain Source489's bytes. Registrations,
all one hundred selected files, both original groups and every bound remain.
Fresh 1,305-widget qualification is pending. The original failed run is not
retried, and native pixels/full acceptance remain open.

## Source490 result and Source491 component fixture

Original [42033801208](https://github.com/edgepillar/syrius/actions/runs/42033801208),
attempt one, job 127266622775, tests Source490
6b14bc192c5271ea0f4d87846a25cb2e41a36037, tree
72437833223c5f0d040e77ef05488f751c77a5ec. Its first complete 50-file stream
finishes with 625 passes, two failures/errors, zero skips, 70 hidden and 697
terminal events. The remaining failures point to the height assertion and the
original visible amount-label assertion. The complete unforced command exits
one in 202.125 seconds with 348,287 bytes. Group two is unselected. All 1,063
Python controls/eighteen Windows skips, fourteen assets and zero selected
findings pass. All jobs are terminal with zero artifacts. Neither old run is
retried. Old actual numeric heights and label counts remain NOT_RETAINED.

Source491 separates the component's layout contract from a list's extra
semantics: a horizontal-axis UnconstrainedBox releases the vertical constraint
just as the production list does, while retaining the original component-test
semantics. The same exact one-label and hidden-label assertions remain.

The reference height now shapes independent fourteen-pixel/1.45 sans and mono
line boxes before adding the nine-pixel insets and one-pixel separator. This
replaces the raw font-size product; the forty-pixel minimum and 0.1-pixel
comparison stay. The actual row is never used to compute the expected height.
Movement gap, explorer extent, amounts, marks, actions and all older assertions
remain. Production Activity and token files retain Source489's bytes.

Only fixed fixture geometry or a visible-label match count can enter the new
failure diagnostic. It is bound to the originating Activity test and admits no
text, amounts, hashes, addresses, labels, paths or exception payload. Unknown
fields, duplicates, nonfinite or out-of-range values and foreign test context
refuse. Five existing pure projection cases pass locally with all old controls
retained, no filesystem fixtures, no SDK and no new registrations. Current
1,305-widget/1,063-controller qualification remains pending. All previous
failures, native pixel limits and original 72/80 acceptance remain unchanged.

## Source492 bundled-font batch

The component file now loads Space Grotesk and JetBrains Mono in their existing
regular, medium, semibold and bold weights before every case and independent
reference measurement. The same eight-file setup is already used by the Home
fixture. This uses the committed assets and changes neither their bytes nor
the dependency manifest. It avoids relying on the test engine's default font
for reference measurements.

The exact Source491 head has zero hosted runs, verified before this preparation.
Its new fixture and bounded diagnostics are combined with this font setup in
one Source492 focused execution. Source491 is not independently dispatched and
neither earlier failed run is retried. All assertions, ten static registrations,
1,305 ordinary/1,307 asset expectations, 1,063 Python cases and one hundred
selected paths remain. Setup events remain hidden lifecycle observations; they
do not increase ordinary passes. Current selected analysis/widgets and complete
native/visual acceptance remain pending. No local SDK, font or archive download
is started.

## Actual Source492 focused result

Tested Source492 a1dd38c462699959cb9066f03db2b5136a33848e, tree
819cc21dae4e58faccec0b13103ac5844897f175, succeeds in original
[42039587847](https://github.com/edgepillar/syrius/actions/runs/42039587847),
attempt one, job 127286567686. Independent source/result reconciliation
qualifies all 1,305 widgets with zero failures/errors/skips, 146 hidden and
1,451 terminal events. The original one hundred files finish in complete
50/50-file streams, with 627/678 passes. Both original commands exit zero
normally, with 346,223/344,417 complete unforced bytes in 215.984/211.203
seconds. The two additional hidden setup/teardown events do not add passes.

The normal dark/light and scaled RTL geometry controls pass with all eight
bundled font files, independent reference shaping, the original ten-pixel gap,
fourteen-pixel explorer extent and strict height tolerance. The original
visible/hidden semantics, exact amounts, marks, actions and registrations pass.
All 1,063 Python cases finish with eighteen explicit Windows skips and zero
failures/errors. Fourteen asset controls and zero selected analyzer
errors/warnings/infos pass. Aggregate, startup/refusal and final source checks
complete; all tested-source runs and jobs are terminal with zero artifacts.

X613 closes for selected implementation/engine scope. Source489/490 remain
failed, with their old numeric geometry/counts NOT_RETAINED. Source491 has zero
separate runs. The local result reader's stale status literal refused before
live queries; its protected replacement qualifies this same original run.
No SDK/native execution is repeated for that metadata correction.

Source493 records this result and exact English body349 in documentation only,
preserving all 1,976 Source492 runtime/source entries. Current native pixels,
populated states, X521-X528, GPU/frame time, Native109's Deposit UNKNOWN and
full original acceptance stay open. Main progress remains 72/80, with 50/94
historical literal outputs, 44 missing and zero accepted whole-image matches.
