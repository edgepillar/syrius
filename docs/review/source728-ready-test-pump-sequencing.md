# Ready test pump sequencing and strict analysis

Updated 2026-11-13.

## Original result

The [Source727 Linux run](https://github.com/edgepillar/syrius/actions/runs/43409077601)
records 1,220 controller cases with seventeen platform skips and no failures.
Patched-package and application analysis pass. The latter retains 22 infos in the new Ready
and copied-observe code. The full non-chain directory records 5,077 passes,
two failures and one skip. Generation is skipped and zero artifacts are
produced. No Source727 Windows job is dispatched.

Both failures are guarded-call conflicts in the new Ready test driver. The
positive readback calls guarded tester accessors while the pump driver is
active. The lost-admission case attaches its asynchronous expectation after
that driver has already begun pumping. Neither result establishes a native
Ready capture or a production frame-gate failure. The original failed run is
preserved and is not retried.

## Change

The positive readback now records the actual original renderer State, sampled
widget and running-clock facts without invoking test APIs. All existing
composition, owner, sample-position, clock, frame and restoration assertions
run after the pump driver returns. The refusal expectation is attached before
that driver starts. The late-frame refusal case and all three registrations
remain selected.

The new Ready helper and its test join the explicit strict-analysis arguments,
with fixed privacy-safe diagnostic labels. The 22 new findings are addressed
through line wrapping, complete blocks, the existing private-field constructor
form and named condition arguments. The condition evaluations keep their
original order. Tests deliver the exact original failure through Future.error
without formatting or replacing it. No lint suppression is added.

The existing Linux workflow now runs those three Ready cases before the full
test directory. This gives an earlier failure signal while retaining complete
non-chain testing and tracked generation as separate required steps.

Application rendering, asset sampling, admission, original frame deadlines,
permanent holds, positive restoration, copied-session reads and financial
conditions retain their implementation. The selected totals remain 1,486
Dart cases in 110 files, 1,220 controller cases and 123 Ready reader cases.

## Validation and limits

All 46 focused memory controls pass locally without SDK, native execution,
network or fixture creation. They cover the public failure catalog, exact
serial groups, strict-analysis selection and closed observe diagnostics.
The local test results do not qualify the Dart changes.

Fresh full Linux execution, original Windows Ready and Staking/Token runs,
independent archive verification and individual image comparison remain
required. The prepared Source727 Ready controller remains unexecuted and
source-bound. Earlier failures, F06's Source722 audit and original 74/80
acceptance retain their scope. P03, P09, V01, V02, V05 and V06 stay open;
zero whole-image matches are accepted.
