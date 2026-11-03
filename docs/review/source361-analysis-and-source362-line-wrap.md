# Source361 analysis refusal and Source362 line wrapping

Source361 is `199edae3926d7a3ad695dfd8db430f705c08dfab`, tree
`61dd832016838ff5cd7de8c203274e0d3fe1024c`.

The original [focused attempt 41635973809](https://github.com/edgepillar/syrius/actions/runs/41635973809)
fails. All 953 Python controls pass with three existing skips, and fourteen
asset observations pass. Strict analysis has zero errors, zero warnings and
one LINES_LONGER_THAN_80_CHARS info on the new Project key expectation at
`restored_seed_workflow_test.dart:1444:81`. Analysis exits zero with complete
166-byte output, SHA-256
`2cc2538778b53aec9b411263cb182e43ab958052adeb7b490415dd517c08a86e`;
the strict gate refuses the info. Dart is skipped, zero cases execute and
zero artifacts exist. The original failed run is not retried or relabelled.

Source362 wraps only that existing expectation and adds its optional trailing
comma. Every assertion, label, registration and all Source361 runtime,
CLI/agent/parser/UI/SDK/Python/workflow/dependency bytes remain unchanged.
The six added lines have at most 76 UTF-16 units. The private publication
preflight now checks inserted/replaced Dart lines against the existing
80-unit rule before network work; unrelated existing lines are preserved.
This source-only check supplements the required hosted analyzer.

All three Project parser/actual-agent cases and the exact 900/902 total remain.
Fresh strict analysis and both actual 36-file Dart streams (441/459 expected)
are required. Completed local mocked checks are not repeated for unchanged
Python code. Native106 is not admitted and no consumed operation is replayed.

[Source360's original event refusal and Source361 corrections](source360-event-stream-and-source361-cli-correction.md)
retain their separate scopes. Source360 qualifies only its first 441 cases;
the second stream and full 900-case gate remain unqualified despite normal
child exits. The strict parser, test-local output capture, positional 320/160
scrolls and actual outgoing delta/key assertions are preserved.

Full F06 requires all screen states, beyond six receipts and one HTLC deposit.
Main progress stays 72/80 rows, 50 literal outputs, 44 missing and zero accepted
whole-image matches. Earlier FAILURE/HOLD/UNKNOWNs remain source-bound.
The exact preceding [body297](pr-body-297.md) preserves its historical text
and all links. The PR stays Draft with English public text and edgepillar
no-reply/UTC attribution. No local SDK/native execution or image transport occurs.
