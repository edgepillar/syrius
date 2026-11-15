# Paired entry analysis style

The paired entry now initializes its optional private transport through a
positional field formal. Its only decorated instance passes the same transport
in that position. The owner callback receives the existing remaining-time
function directly. Its return value is still discarded by the void callback.
These changes address two strict analysis findings without changing the
original handoff, command payload, deadline, readiness or retirement behavior.
The profile digest is updated for the 12919-byte entry; its 16384-byte cap and
all qualification predicates remain unchanged.

[Source796 full Linux 43750848364](https://github.com/edgepillar/syrius/actions/runs/43750848364)
passes package and application analysis, then stops at two info findings in
strict selected analysis: prefer_initializing_formals and unnecessary_lambdas.
It reports no errors or warnings. Ready, Lock, compact, full unit tests and
generation are skipped. The job is terminal, has no artifacts and is preserved
without retry. No Source796 native job was dispatched. All owned outputs are
consumed and registered local storage is closed before this change.

The existing [Source796 handoff and Apps changes](source796-original-handoff-and-apps-labels.md)
still require hosted Dart execution. Fresh current-source full Linux and paired
native qualification remain required. No workflow, test selection, original
recipe, timing action, threshold or process-exit predicate changes.

Scope stays 76/80 and accepted Ready pairs stay 2/94. V01/V06 remain in review;
V02/V05 remain blocked. No new visual match, performance improvement, financial
send or seed qualification is claimed. No local SDK executes and no archive is
downloaded locally.
