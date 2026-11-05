# Settings section names keep their full text height

Updated: 2026-11-05T02:15Z.

The section menu previously constrained every row to 38 pixels and ellipsized
its label. The body token is fourteen pixels with 1.45 line height. At doubled
text scale a single line needs 40.6 pixels before wrapping. The fixed height
could therefore clip the label even though the menu already has a scroll view.
This is a source-derived defect; no new native frame is claimed.

Source470 uses the existing 38-pixel token as the minimum height and permits
complete labels to wrap. The normal-scale 200-pixel menu, 38-pixel rows,
14-pixel icons, twelve-pixel page gap and all color/motion tokens remain.
Longer text increases only the affected row; the existing scroll view keeps
lower destinations accessible. Selection, callbacks, outgoing-page barriers,
section identity and the always-running 150-millisecond transition are unchanged.

All nine existing Settings frame cases remain registered. The four existing
both-theme/direction geometry cases retain their original normal-scale frame,
row, selection and exception assertions. They additionally require every actual
doubled-scale paragraph to contain its intrinsic height without truncated lines.
The existing keyboard case retains the six-Tab Apps activation and checks the
selected row against its actual viewport at normal and doubled scale, using a
short synthetic viewport for the latter. Existing outgoing-action refusal and
all three independent motion-flag cases remain.

The focused lane now includes this existing nine-case file once, along with all
96 previously selected ordinary files. The unchanged split algorithm yields 97
ordinary files in 49/48-file streams, with 606/633 expected passes and 1,239 in
total. The asset variant has 1,241 cases and remains unselected. The analyzer
explicitly includes both changed Dart files. The existing admission cases retain
all prior-count refusals and additionally reject the old 1,230/1,232 totals.
All fourteen local pure/mocked admission cases pass with no errors, failures or
skips, native process, filesystem scratch, SDK or network execution. Python
registrations remain 1,063, with eighteen explicit Windows skips expected.
These controls prepare execution; they do not render the changed widgets.

Fresh strict selected analysis and both complete hosted engine streams remain
required. One worker, 240 seconds/four MiB per child, the 480-second aggregate,
source revalidation, terminal counts and pre-build refusal controls remain.
The previous Source468 1,230-case pass retains its exact source and does not
qualify this change. No heavy build, native wallet/lab, artifact transport or
motion/performance acceptance is selected.

The historical Source334/336 Node-heading finding retains its unestablished
cause. This menu correction does not claim to resolve that native frame. Full
acceptance remains 72/80 original rows, 50/94 historical literal outputs, 44
missing and zero accepted whole-image matches. The eight original acceptance
rows and heavy phase-two checks remain open. All previous failures, ownership
holds and unknowns remain preserved; public metadata uses edgepillar and the
existing PR stays Draft.

## Original Source470 result

Updated: 2026-11-05T02:33Z.

Original [41954579745](https://github.com/edgepillar/syrius/actions/runs/41954579745),
attempt one, job 127006299114, runs on Source470
`e17dc154774d1b932c8d1aed81869af5cf543b27`, tree
`1255742b8ba16525b68693b9f0682a79864f9a27`. All 1,063 controllers/eighteen
expected Windows skips, fourteen assets and zero-finding selected analysis pass.
The original first 49-file stream exits one normally in 131.125 seconds with
334,591 complete bytes, no overflow or forced termination. Its digest is
`ba3e311c1931ed624abce2add0ab0e07383b4f53ecb0671fe7f746e2b604f330`.
There are 605 passes, one failure, one error event, zero skips, 69 hidden and 675
terminal events. The second group is not executed and no aggregate pass exists.
The finite diagnostic binds the Apps page activation assertion at test line 158.
The original failing scale, focused target and inner cause remain NOT_ESTABLISHED.
All other first-group cases, including the four retained menu geometry cases,
pass. The original run is terminal with zero artifacts and is not retried.

## Source471 explicit menu focus

The original normal-size six-Tab/Enter baseline is restored as its own unchanged
opening sequence. The added normal/doubled viewport scenarios separately acquire
and verify Addresses focus, press five Tab keys with settled frames, verify Apps
focus, then deliver Enter. The page, selected-surface and actual viewport bounds
assertions all remain. This gives the added scenarios an explicit keyboard entry
condition instead of depending on whichever focus stop was selected on entry.
It is a fixture correction, not a retrospective claim about the old failure.

All application, Python/controller, workflow, dependency and reference bytes
remain unchanged from Source470. Nine menu cases, all 1,239 ordinary/1,241 asset
cases, 97 ordinary files in 49/48 groups and 606/633 expected passes remain.
The unchanged fourteen local admission controls are reused. Original selected
analysis, both complete hosted streams and their strict gates are required anew.
No local SDK, full wallet/lab, image or motion job is selected. The original
failure and all full 72/80 acceptance boundaries remain; the PR stays Draft.

## Original Source471 analysis result

Updated: 2026-11-05T02:45Z.

Original [41956299483](https://github.com/edgepillar/syrius/actions/runs/41956299483),
attempt one, job 127011895296, binds Source471
`f174cb3c6dc16f298fd8bddc872e1afa8f0e11b4`, tree
`e7f24130942024e8ec00b83a4ef68f63485911d0`. All 1,063 controllers/eighteen
expected Windows skips and fourteen assets pass. Selected analysis retains zero
errors/warnings and one CASCADE_INVOCATIONS info at the added requestFocus line.
Dart is skipped; the original remains failed and terminal with zero artifacts.

## Source472 menu traversal group

Source472 makes the added requestFocus call part of the FocusNode declaration's
cascade. Its value, target, timing, cases and assertions remain unchanged.

The menu's existing scroll view also gains a FocusTraversalGroup. Flutter's
[reading-order policy](https://api.flutter.dev/flutter/widgets/ReadingOrderTraversalPolicy-class.html)
sorts focus targets by screen rectangles. Without a group around the menu,
page controls and section links share that ordering; longer labels or a short
viewport can place a page control between links. This is a source-derived reason
for separating navigation, not proof of the old run's exact focused target.
Flutter documents that a [traversal group](https://api.flutter.dev/flutter/widgets/FocusTraversalGroup-class.html)
is ordered as one unit by its parent. The menu retains its default directional
reading order and can still leave the group for the page.

No focus trap, new destination, shortcut, owner override or action callback is
introduced. Both themes, geometry, complete labels, selection surfaces and
150-millisecond clocks remain. The original six-Tab opening baseline, explicit
normal/doubled focus/viewport checks, paragraph assertions, outgoing-action
refusal and independent motion cases remain. Keyboard execution uses the existing
dark/LTR fixture; both directions/themes retain geometry coverage.

Python/controller bytes and fourteen completed local admission cases are reused.
Nine existing menu cases and 1,239 ordinary/1,241 asset cases remain, with 49/48
ordinary files (606/633). Fresh zero-finding selected analysis and both complete
hosted streams are required. Both failed originals, the original Node-heading
uncertainty, native pixels, full 72/80 acceptance and phase two remain open.

## Fresh Source472 focused result

Updated: 2026-11-05T03:04Z.

Original [41957578090](https://github.com/edgepillar/syrius/actions/runs/41957578090),
attempt one, job 127016071419, succeeds on Source472
`fae94fdc4a847a41693d584d939782a4fc31ccc0`, tree
`fa011d8fa5c83394f1a2d23f771ee2836f496cd9`. Independent consumption verifies both complete
streams, original metadata receipts and fresh terminal run/job/artifact listings.
All tested-source runs are terminal with zero artifacts; no producer is retried.

All 1,239 ordinary cases pass: zero failures/errors/skips, 135 hidden and 1,374
terminal events. The 97 selected files execute once in 49/48 groups, retaining
every prior file and adding nine existing menu cases. Each stream exits zero
normally with complete, unforced output and the original process bounds:

| Group | Files | Passed | Hidden | Terminal | Seconds | Output bytes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 49 | 606 | 69 | 675 | 193.953 | 333166 |
| 2 | 48 | 633 | 66 | 699 | 182.531 | 314909 |

Corresponding output SHA-256 values:

- `01466e12a284393e7ee13630cd50e41400ffbe509b608aeb25859c85ccac737b`
- `430f9c842a5b4b92f34b37dd2e8def363b2776f678a091d1bc4557cc934c8225`

All 1,063 Python controls pass with eighteen explicit Windows skips; fourteen
asset observations and zero selected analyzer errors/warnings/infos pass.
Aggregate publication, startup/refusal and final source checks complete.
The 1,241-case asset variant remains unselected.

All four both-theme/direction geometry cases retain normal-size assertions and
pass complete doubled-scale paragraph fit. The original six-Tab opening and
added explicit-focus normal/doubled viewport checks pass. Outgoing actions still
refuse during exit and all independent motion-flag cases retain their clocks.
Every prior focused path, including Go To scaling, passes. X606/X607 close only
for selected widget/controller qualification. Original Source470 keyboard failure
and Source471 analysis refusal retain their failed outcomes and unknowns.

Source473 records documentation and exact English body342 only, preserving all
1,976 qualified runtime/source entries. No extra SDK, full wallet/lab, native
capture, image or motion allocation is made for that record. Source468, actual
Source459 Linux defaults and the Source461 component/kernel split keep their
own pins and scope. Full acceptance remains 72/80, 50/94 historical literal
outputs, 44 missing and zero accepted whole-image matches. P03/P09/F06 and
V01/V02/V03/V05/V06 remain open; heavy phase-two checks stay deferred.
The first delivery remains ready for Draft code review.
