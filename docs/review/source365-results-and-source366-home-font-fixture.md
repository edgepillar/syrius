# Source365 results and Source366 Home font fixture

Source365 is `cac7b6abd739243cd59a6da37b502781f63df00b`, tree
`0034513b3a13d30e0c43021e966821f90356de09`.
Original [focused run 41659290594](https://github.com/edgepillar/syrius/actions/runs/41659290594),
attempt one, fails. Its first 36-file group completes normally with 440 passes,
two failures, 44 hidden engine events and no retry or unfinished test. The
original stream hash matches the progress observation. Both failures point to
`home_hero_test.dart:295`, the existing `hero.height < 160` expectation.
The actual height is not exported, so no value or full runtime cause is
invented. The second group is correctly not started; all 901 cases are not
qualified. Selected strict analysis has zero findings, 953 Python controls
with three existing skips and fourteen assets pass. No artifact exists and
no native lab is admitted. The original failure is preserved without replay.

The previous Home file loaded bundled mono fonts only inside its new final
case. Earlier layout comparisons, including the two height assertions, did
not load the shipped fonts first. Source366 moves font loading into the
suite's awaited setup and loads the app's existing sans and mono families,
regular/medium/semibold/bold, before every Home case. The final case's late
loader becomes redundant and is removed. This aligns geometry-test inputs
with the fonts actually shipped; fresh execution must determine its outcome.
The old height bound, every assertion and test label/registration remain.
No padding, font-size limit, tolerance or application behavior is relaxed.

The Source365 Home implementation, original Project completion correction,
numeric formatting, financial SDK, owner/receipt budgets, agent/CLI/parser,
dependencies, workflow and exact 901/903 counts are unchanged. All 72 files
remain selected in two 36-file groups (442/459). The fourteen complete mocked
admission controls are reused with byte-identical source, not re-executed;
Python remains 953/three hosted skips. Eight existing bundled font files are
source-pinned. No local SDK, native process, browser or binary transport runs.

Source364's original 900-case success remains source-bound. Source363's two
Project failures and Native106's exact UI cause NOT_ESTABLISHED are preserved.
Fresh strict/901-case hosted proof is required before the next independent
chain/profile lab. Main acceptance remains 72/80, 50/94 literal outputs, 44
missing and zero accepted matches. Full F06 screen states and coordinated
Swap, complete visuals, Docker/platform, motion/frame time, native seams and
final independent acceptance remain open. Exact [body302](pr-body-302.md)
retains earlier text and URLs. The PR stays Draft, public text stays English
and privacy-safe, and all commits retain edgepillar no-reply/UTC attribution.
No consumed operation is replayed and no historical evidence is cleaned up.
