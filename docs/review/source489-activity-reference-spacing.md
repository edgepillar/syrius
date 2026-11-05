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
