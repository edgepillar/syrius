# Lock command diagnostics and picker expectation correction

The [Source704 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43293669273)
passes application and patched-package analysis but fails four menu cases.
Both themes and directions still expect 13 px at
`test/lock/wallet_picker_test.dart:350`; Source703 intentionally enlarged the
menu names to 13.5 px. This change corrects that expectation. Application
typography, menu geometry and registered test counts are unchanged. The
failed run does not qualify generated-file checks, which were not reached.

## Finite Lock refusal notice

The [Source703 Lock producer](https://github.com/edgepillar/syrius/actions/runs/43286179442)
stops in its first normal capture with `COMMAND_FAILED`, before any PNG.
Its [independent reader](https://github.com/edgepillar/syrius/actions/runs/43292445165)
confirms zero PNGs and two normal actor exits. The inner command cause
remains `NOT_ESTABLISHED`; the incomplete source-stability check does not
establish a changed source.

The Lock controller now retains the first refused RPC as fixed command,
phase, HTTP status and reply-category labels. Its notice is emitted after
the original process cleanup returns. A later cleanup refusal cannot
replace the first command. Unknown commands, phases and reply messages
are withheld. Command arguments, password text, reply details, raw error
messages and paths are never projected. The original `COMMAND_FAILED`
exception, action-completion checks and cleanup behavior remain in place.
There is no fallback result or automatic retry.

One existing pure Python case is extended to check the finite projection,
first-failure preservation, forwarded RPC options, unchanged successful
replies and suppression of arbitrary private input. It passes in memory
with no on-disk fixtures, native execution or network operation. Python
syntax checks pass. Full hosted checks and a new instrumented Lock
observation remain pending. A new successful run would not establish the
cause of the original failed run.

Production application and Dart harness bytes remain identical to Source703.
Source703's separate Ready producer and reader retain their two-PNG catalog
qualification and normal required actor/node closure; atomic-frame and
local visual acceptance are not added here. Source702 retains the most
recent successful full Linux workflow.

Original acceptance remains 73/80. P03, P09, F06, V01, V02, V05 and V06 stay
open, with zero accepted whole-image matches.
