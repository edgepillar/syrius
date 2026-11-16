# Select the original receiver before requesting focus

Source818 tried to restore startup focus after selecting the original hint.
The selector required that receiver to already have primary focus, so a
different focused control caused an earlier refusal. The new focus request
could never run in the exact case it was intended to handle.

Selection now requires the same original receiver to be able to request
focus. The action still requests focus, applies pending changes, rechecks
the original owner/control and requires primary focus before the existing
complete Space pair. Original route, film/controller identity, shared Focus
ancestor, key callback and pointer reachability checks remain. No widget
callback, decoder or initialization shortcut replaces ordinary input.

Both current and P06 adapters receive this predicate change. The original
widgets, film/decoder, assets, CLI, collector, commands, waits, exit budgets
and 16000-microsecond/frame-gap comparisons remain unchanged.

## Regression coverage

The existing positive startup case keeps primary focus on an unrelated
consuming root sibling before the recipe. It now also requires the genuine
startup control to remain discoverable. The recipe must perform the original
skip without sending keys to the sibling; every earlier assertion remains.

The existing refusal case first makes the original receiver unfocusable.
Its hint must be absent and the command must refuse without a skip effect.
After restoration, the original early-keyboard-handler case still requires
an unconfirmed-effect refusal. These are extensions to existing cases;
fresh Flutter execution remains required.

Forty-five related mocked Python controls pass with zero failures, errors
or skips. No local SDK executes. Counts stay 1517/1519 selected Dart cases,
1229 Python cases/eighteen Windows skips, 113/114 suites and 291 strict
analysis paths. No test method, selected path or suite is removed or added.

The P06 source/tree remain `e06330fd5c630fee82f59efd42140f7190260ff9`
and `197785948b180221aa3521b35fcc4def52620ba9`. The new overlay tree is
`77d34a31fae1da66ca049fdb45c280bb5f51929e`; its patch is 15756 bytes
under the original 16384-byte limit, SHA-256
`df273871338251d3b65935d02c0f3077157d6c79d160c355836fad6a4901c7dc`.

## Original Source818 failure

The [original full Linux run](https://github.com/edgepillar/syrius/actions/runs/43945119834),
attempt one, passes eleven required stages. Unit/widget tests report
5095 passed, one failed and one skipped; the generated-file check is skipped.
The only failed case is `startup recipe acknowledges its original film skip
effect` in `test/harness/startup_key_confirm_test.dart`.

The retained stack points to `_recipeControl` at
[Source818 line 3385](https://github.com/edgepillar/syrius/blob/b6d493a759658c11f8bca242f1be413340b3c16d/harness/app/agent.dart#L3385):
the original hint is absent before the focus request. Its caller is the
initial control selection, not the later primary-focus or skip-effect check.
The test has already confirmed that the unrelated sibling is primary.
This establishes the selector-order defect in that widget test.

The complete 1416122-byte original job text is retained once by SHA-256
`05364d20d9a0baf3d5c5b268b1dd4272352cf9baa8f11325385b5708bfd40cd1`.
The successful managed read closes normally; the earlier CLI capture refusal
remains separately recorded. No CI test is retried to obtain the failure.
All owned outputs are consumed and scratch is closed before source changes.

Source818 never starts a Windows measurement. This test failure does not
establish the cause of Source817's incomplete P06 film. Fresh full Linux
and native qualification remain required for Source819. Original failures,
76/80 acceptance and Source730's two literal Ready matches remain; there is
no new visual match, native repair, performance gain or financial claim.
V01/V02/V05/V06 stay open.

## Original Source819 strict-analysis result

The [original Source819 full Linux run](https://github.com/edgepillar/syrius/actions/runs/43965442320)
passes seven required stages. Strict selected analysis reports zero errors,
zero warnings and one info: `cascade_invocations` at line 18 of
`test/harness/startup_key_refusal_test.dart`. Its diagnostic locations are
complete and untruncated. The unchanged zero-finding gate refuses the result.
Ready, Lock, compact controls, unit/widget tests and generation verification
are skipped. No new Flutter assertion or Windows measurement is qualified.

The original typed report is sufficient to locate this formatting issue;
no artifact or raw-log download is needed. All owned outputs are consumed,
the original failure is retained and no native job starts.

## Source820 analysis format

The existing Focus.of initializer now cascades its immediately following
`canRequestFocus = false` assignment. It configures the same receiver before
the same refusal assertions and restores it in the same finally block.
Production code, guards, test methods, selection, workflows and the zero-info
analysis requirement remain unchanged.

Source819's forty-five related mocked controls remain evidence at that source.
Fresh hosted analysis and engine execution are required for Source820. The
P06 overlay stays at 15756 bytes, tree
`77d34a31fae1da66ca049fdb45c280bb5f51929e`, patch SHA-256
`df273871338251d3b65935d02c0f3077157d6c79d160c355836fad6a4901c7dc`.
Acceptance remains 76/80; Source730's two Ready matches remain source-bound.
