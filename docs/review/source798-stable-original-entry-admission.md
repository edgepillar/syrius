# Stable admission before the original import recipe

The initial paired entry gate now waits for one second of stable, genuine
empty Welcome or the original enabled startup handoff control. Unknown and
initialization-in-progress stages are not admitted. Owner, revision, signing
chain and entry phase must remain stable. Duplicate controls are refused.
The captured owner and empty profile are checked again before invoking the
unchanged original import recipe and CLI factory.

This initial gate sends only observations. The original recipe retains its
conditional startup handoff and all action payloads and guards. The existing
tap adapter still requires genuine Welcome; startup readiness is admitted
only before the recipe begins. The existing 90-second observation maximum,
210-second entry cap, original recipe/command budgets and actor limits remain.
The entry is 13742 bytes within the unchanged 16384-byte cap. Its digest is
updated in the profile; marker fields and qualification predicates remain.

Existing Dart cases now cover stable startup and Welcome admission, unknown
and initialization-in-progress stages, disabled controls, revision changes,
duplicate startup controls and the default Welcome-only refusal. Existing
handoff/tap ordering, timeout and retirement cases remain. These changes
require fresh hosted Dart execution.

## Verified Source797 results

[Full Linux 43752165370](https://github.com/edgepillar/syrius/actions/runs/43752165370)
passes all thirteen required steps, including the complete non-chain directory,
new handoff/retirement and real Arabic Apps cases, and tracked generation.
[Windows 43753713215](https://github.com/edgepillar/syrius/actions/runs/43753713215)
passes 1505 selected Dart cases, 1226 Python cases/eighteen skips, zero selected
findings and the current Release build. Its paired measurement fails in
p06_interactive. [Independent reader 43756131967](https://github.com/edgepillar/syrius/actions/runs/43756131967)
rehashes both original finite archives.

Both wallet processes and all five lab nodes exit normally with complete
output. The current entry succeeds with complete 97-byte output in 28.938
seconds. All sixteen measurement commands return; thirteen page-change and
thirteen disclosure frames are retained. P06 preparation fails with complete
287-byte output in 34.312 seconds, without overflow or forced termination.
The Welcome wait still observes startup-before-initialization with the
control absent. P06 has no timing windows or paired comparison.

The first original recipe observation is not retained. Its exact startup
branch remains unestablished. The pinned original recipe decides whether to
attempt its handoff from that first entry phase. Source797 begins the original
recipe without an initial stable-entry gate; its later Welcome wait cannot
establish the earlier branch. This revision closes that admission gap.
The exact runtime cause still requires evidence. No original recipe, agent,
baseline renderer, element/center guard, timing action or threshold changes.

Original failed jobs and manifests remain preserved without retry. All owned
outputs are consumed and local registered storage is closed before this change.
No local SDK executes or original archive is downloaded locally.

Fresh current-source full Linux, paired native execution and visual review
remain required. Scope stays 76/80 and accepted Ready pairs stay 2/94.
V01/V06 remain in review; V02/V05 remain blocked. No new visual match,
performance improvement, financial send or seed qualification is claimed.
