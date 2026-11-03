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
