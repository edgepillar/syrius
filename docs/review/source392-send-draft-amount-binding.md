# Keep saved Send amounts with their original owner and asset

Restoring a Send draft dropped an unavailable sender or asset to the form's
defaults while assigning its amount unconditionally. A saved quantity could
therefore appear under another owner or asset. Applying a draft to a mounted
form had the same issue. A balance update that removed the current sender
also kept that sender's displayed amount after selecting a fallback.

The form now restores or applies a quantity only when the resolved sender
and token standard equal the draft's original pair. The recipient remains;
an unavailable pair leaves the amount empty and requires a new entry before
Send becomes available. An available pair keeps its exact quantity string.
Restoring or applying an unavailable draft leaves that original in-memory
payload intact. Losing a mounted sender clears the amount through the normal
draft listener and records the fallback pair with an empty amount. Explicit
sender and token editing retain their existing behavior.

Session capture, immutable confirmation, original-request admission, exact
decimal parsing, signing/publication and result handling keep their source.
No service, wallet file, dependency, localization or native producer changes
accompany this correction.

Three real widget regressions cover restoration, an arriving draft and a
balance-owner fallback, including positive exact-amount retention for an
available QSR pair. Every original form case remains unchanged. All 21 form
cases join the full prior focused selection: 83 files in 42/41-file streams,
requiring 1,051 ordinary passes (528/523). The separate asset-fidelity
selection requires 1,053. The existing strict Send library selection now
also includes its form test. Nineteen local mocked admission/analysis
controls pass. Python retains 955 controls and three existing hosted skips.
Worker, deadline, output and process-completion bounds remain unchanged.
The completed hosted widget and strict-analysis result is recorded below.

The [fast first-delivery scope](fast-first-delivery.md) continues. New heavy
Windows/lab producers, image transport and complete visual/performance
acceptance stay in phase two. The original 72/80 rows, 50/94 literal outputs,
44 missing and zero accepted whole-image matches remain. Prior successful
and FAILURE/HOLD/UNKNOWN observations retain their original source and scope.
The Deposit candidate remains unapplied. No local SDK execution is added.

## Focused result

Original [41739664927](https://github.com/edgepillar/syrius/actions/runs/41739664927),
attempt one, job 126277713956, succeeds at Source392
`19e322e0c019ce986cca70db78ab189db060a1e8`, tree
`fb39dfe00b489d1047d201aae627e0735c6309a9`. Independent read-only qualification
accounts for both complete 42/41-file streams: 528/523 passes, all 1,051
ordinary cases, 111 hidden and 1,162 terminal events, zero failures/errors/
skips. Both original processes finish normally with complete bounded output
in 171.797/147.141 seconds. Every earlier focused path and registration remains.

All 21 Send form cases pass. The three new regressions qualify restored and
arriving unavailable owner/asset pairs with empty displayed amounts, intact
recipients and original payloads, plus a missing balance owner with an empty
amount recorded for its fallback. Invalid fallbacks keep Send disabled and
add no sender event. An available QSR pair retains its exact quantity and
normal enabled action. The original busy/deferred valid draft and every
earlier form assertion also pass. The separate asset-fidelity selection
remains 1,053 cases.

Python completes 955 controls without failures/errors and retains three
existing hosted skips. Fourteen assets succeed. Selected analysis has zero
errors, warnings and infos, including the Send library and its form test.
All source-bound jobs are terminal with zero artifacts. Source393 changes
documentation only and preserves every tested application, test, workflow
and dependency byte. No new full Windows build, native producer, local SDK
execution or artifact transport accompanies this result.

Original first-delivery and full-acceptance boundaries remain. Prior failure
and UNKNOWN observations are preserved; this result does not qualify native
financial effects, all visual pairs, platform installation or frame-time
acceptance.
