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
