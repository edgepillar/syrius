# Original analysis refusal and narrow Dart correction

Source355 `651c43863108708dba812b9b398a151d048344f9`, tree
`31d310c50fde08b3f08daff2571b244ce98f870a`, retains its original failed
[run 41585468265](https://github.com/edgepillar/syrius/actions/runs/41585468265),
attempt one, job `125749801774`.

All 953 Python controls pass with the three existing skips and no failures or
errors. Both original asset controls and all fourteen observations pass. The
analyzer exits zero normally with complete 678-byte output, zero errors,
zero warnings and four infos:

| Source | Original line | Info |
| --- | --- | --- |
| `harness/seed/restored_seed_workflow.dart` | 77 | `LINES_LONGER_THAN_80_CHARS` |
| `test/harness/restored_seed_workflow_test.dart` | 810 | `CAST_NULLABLE_TO_NON_NULLABLE` |
| `test/harness/restored_seed_workflow_test.dart` | 821 | `CAST_NULLABLE_TO_NON_NULLABLE` |
| `test/harness/restored_seed_workflow_test.dart` | 836 | `CAST_NULLABLE_TO_NON_NULLABLE` |

The strict zero-info gate fails. Startup checks and both Dart child commands
are skipped, so zero Dart cases execute. Every other job is skipped and the
run has zero artifacts. The original failed run is not retried or relabelled.

Source356 splits the long private-prefix map line and restores explicit
non-null assertions on the three test-map lookups. The seed workflow is
otherwise identical after whitespace normalization. Test assertions, five
new Dart registrations and every previous registration remain. All Python,
marker, controller, ordinary app, dependency and workflow bytes are unchanged
from Source355.

The original 53 memory-only controls and Source355's 953 hosted Python
controls retain that unchanged-code scope. Fresh strict analysis and the
complete 888-case ordinary Dart gate are required for Source356. The
asset-fidelity variant remains 890 cases; both ordinary 36-file groups,
one-worker limits, deadlines, both refusals and three startup checks remain.

The [confirmed-prefix change](source355-confirmed-seed-prefix.md) remains a
preparation for fresh owned runtime and independent-reader qualification.
A partial prefix cannot replace all six exact final receipts or admit a retry.
Native101/103 stay `UNKNOWN`; Native104 is unadmitted. No original
financial/profile/password/seed/send/reopen flow is replayed. The original
Source336 Home failure and all earlier FAILURE/HOLD/UNKNOWN remain source-bound.

Main acceptance remains 72/80 original rows, nineteen preparations, 50/94
available literal outputs, 44 missing and zero accepted visual matches.
The [exact preceding body289](pr-body-289.md) retains its submitted text and
URLs. The PR remains Draft with English-only public content and edgepillar
no-reply/UTC attribution.
