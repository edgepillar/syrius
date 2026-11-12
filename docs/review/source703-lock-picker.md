# Expanded Lock picker and finite failure diagnostics

The six reviewed Source701 Lock images show a compact menu over an active
password field and Unlock action. The display-only picker now holds those
controls while expanded, omits the lower links and releases the same field
when closed. It re-hides a revealed password and guards retained reveal
and submit callbacks. The password controller, Lock State and caller's
action owner stay mounted. A retained callback checks the current hold
before it can act.

Wallet rows reserve 49 px, the final Add action 36 px, and the menu keeps
its 7 px border/content inset. Three supplied wallet rows form a 206 px menu.
Text scaling can grow these minimum heights. The field-to-menu gap includes
the column's label gap. No wallet names, addresses or catalog records are
invented. The unavailable catalog remains behind its registered seam.

The existing dark/light and LTR/RTL cases are extended to check held inputs,
refused retained callbacks, unchanged text and State, and resumption after
closing. The measured-menu cases check the new inset and total height.
Registered case counts are unchanged.

## Ready failure diagnostics

Source701's separate Ready producer failed with `ENTRY_REFUSED`, exit 1 and
zero images. Its independent reader confirms the original failure. The inner
cause remains `NOT_ESTABLISHED`.

A refused entry marker now produces only fixed marker/order categories and
allowlisted stage, action, control and reason labels, bound to the source and
run. Unknown fields, raw replies, exception text and private input are omitted.
This notice does not replace the original failure, relax admission or create
a fallback success. One extended existing pure Python case passes in memory;
the full hosted controls and a new instrumented native observation remain
necessary.

## Validation scope

The [Source702 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43276815364)
passes analysis, the non-chain test directory and tracked generation checks.
Its [Windows producer](https://github.com/edgepillar/syrius/actions/runs/43276861188)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43282474675)
verify four Staking/Token PNGs, both original prerequisites and normal required
wallet and node closure. Selected checks pass 1,480 Dart cases, 1,214 Python
cases with eighteen platform skips and analysis with zero findings. The
separate MSVC telemetry helper termination remains recorded. These results
keep their own source bindings. This revision still needs fresh hosted
qualification.

Original acceptance remains 73/80. P03, P09, F06, V01, V02, V05 and V06 stay
open, with zero accepted whole-image matches.

Source702's four fresh pairs were actually viewed after archive verification.
Max, This address and Send are readable in both themes and the unit suffix
is neutral. Remaining table and detail differences are retained as X695-X698.

## Subsequent exact-source results

The [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43286127964)
fails analysis because the new picker test host lacks the foundation import
for `ValueListenable`. Source704 corrects that test import; the original failed
result is preserved. The full unit/widget step was not reached.

The [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43286604695)
and [reader](https://github.com/edgepillar/syrius/actions/runs/43291737582)
verify two PNGs, normal required actor and node closure, 1,480 selected Dart
passes and 1,214 Python cases with eighteen skips and zero selected analysis
findings. The reader passes 123 actual cases. The separate MSVC telemetry
helper termination is retained. Atomic-frame and visual acceptance remain
open. This successful new run does not reclassify Source701's failed run.

The [Lock producer](https://github.com/edgepillar/syrius/actions/runs/43286179442)
retains `COMMAND_FAILED` during its first normal capture, zero PNGs and two
normal actor exits. The [reader](https://github.com/edgepillar/syrius/actions/runs/43292445165)
confirms this failed receipt. Its inner cause remains unestablished. See the
[follow-up record](source704-picker-test-import.md) for the separate scopes.
