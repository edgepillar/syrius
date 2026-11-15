# Explicit entry phase type guard

The paired entry now requires the observed phase to be a String before
retaining it in the stable context tuple. This removes the nullable-to-String
cast. The original startup and Welcome admission conditions, quiet period,
owner/revision/signing checks and all action payloads remain.
The initial gate and Welcome-only tap adapter introduced earlier are retained.
The entry is 13759 bytes within the unchanged 16384-byte cap; the profile binds
its updated digest. Marker fields, command/entry/actor budgets and qualification
predicates remain unchanged.

[Source798 full Linux 43758084444](https://github.com/edgepillar/syrius/actions/runs/43758084444)
passes package and application analysis, then stops at one strict analysis
info finding on the entry phase cast. The bounded original log confirms
cast_nullable_to_non_nullable; the privacy-safe notice had reported its code
as other. It reports zero errors and warnings. Ready, Lock, compact, full unit
tests and generation are skipped. There are no artifacts or Source798 native
jobs. The new initial-entry Dart scenarios still require hosted execution.

The original failed job and first refused log read remain preserved without
CI retry. The succeeding read retains the complete original log privately;
both owned storage tasks are closed with their actual outcomes. No local SDK
executes and no original artifact archive is downloaded locally.

The [Source798 record](source798-stable-original-entry-admission.md) retains
Source797's thirteen passing Linux steps and independently verified Windows
failure: both normal wallet exits, five normal node exits, thirteen current
frames in each window, and the P06 Welcome refusal before initialization.
The first original observation and exact runtime cause remain unestablished.

Fresh current-source full Linux, paired native execution and visual review
remain required. Scope stays 76/80 and accepted Ready pairs stay 2/94.
V01/V06 remain in review; V02/V05 remain blocked. No new visual match,
performance improvement, financial send or seed qualification is claimed.
