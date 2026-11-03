# Token option event merging

The active create-token Options step passed a complete `NewTokenData` snapshot
from each rendered checkbox callback. Two events before the next frame could
overwrite an earlier choice: setting Mintable, then Burnable, could restore the
old Mintable value. The last callback could also restore the old Utility choice.

Each callback now passes only its own field. The existing step/current-owner/
busy guard is retained, and the update merges into the latest draft. Defaults,
details/supply validation, preflight, publication and confirmation expressions
are unchanged. No legacy step component is changed.

Two genuine widget cases cover both themes and opposite event orders. They
capture the actual rendered checkbox callbacks, invoke all three without a
frame between them, and verify the retained choices. They then exercise the
existing Review supply route, reject callbacks from the now-inactive Options
step, and observe one exact draft through the in-memory fixture callback.
Mintable/Burnable stay true, Utility stays false, and total/max supply stay
10/20. No wallet, signer or chain operation is constructed.

The focused gate keeps every previous 76-file path and adds this existing
create-token view file: nineteen previous cases and two new regressions.
The selection requires 961 ordinary cases in 39/38-file groups (475/486), or
963 with asset fidelity. Python remains 955 controls with three existing hosted
skips. All fourteen local mocked admission/count controls pass. Fresh hosted
analysis and widget execution remain pending.

The [fast first-delivery plan](fast-first-delivery.md) remains. New full Windows
builds, native lab producers, image transport and detailed visual/performance
acceptance stay in phase two. Original 72/80 rows, 50/94 literal outputs,
44 missing and zero accepted matches remain. Earlier failures and UNKNOWNs,
including Native103 Token confirmation/effect, retain their original scope.

## Focused result

Original [41713962502](https://github.com/edgepillar/syrius/actions/runs/41713962502),
attempt one, job 126188986414, succeeds at Source379 `eb794d52ded0348b5a0e277fc3b3b4438ffce608`,
tree `b3d497b96b9f2f8d90d5f6969c6f1f6104ffd3c3`. Independent read-only qualification accounts for both
complete original streams: 39/38 files, 475/486 passes, all 961 ordinary cases,
101 hidden and 1062 total terminal events, zero failures/errors/skips.
The 963 asset-fidelity count remains a separate selection.

All nineteen prior create-token view cases and both new regressions pass.
Each theme retains all three same-frame choices, refuses stale callbacks from
the inactive Options step, and observes one exact 10/20 supply draft through
the in-memory callback. These checks do not execute token issuance or establish
native confirmation/effect. Native103 retains its original UNKNOWN outcome.

All 955 Python controls complete with zero failures/errors and three existing
hosted skips. Fourteen asset observations succeed and selected analysis has
zero errors, warnings or infos. Every previous focused file, startup refusal,
entry gate and command/output/deadline bound remains. All source-bound jobs are
terminal with zero artifacts. There is no local SDK execution or artifact
transport and no new full Windows build or native producer.

Source380 changes documentation only; every application, test, workflow and
dependency byte remains equal to tested Source379. The original first-delivery
pin and full 72/80-row, 50/94-output, zero-match acceptance boundaries remain.
Source374 original Node-version failure, Source368 full Windows/Native108
outcomes, all earlier FAILURE/HOLD/UNKNOWN evidence and the unapplied Deposit
candidate retain their original scope. Heavy qualification remains deferred.
