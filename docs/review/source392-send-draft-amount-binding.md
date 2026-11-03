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
Fresh hosted widget execution and strict analysis remain pending.

The [fast first-delivery scope](fast-first-delivery.md) continues. New heavy
Windows/lab producers, image transport and complete visual/performance
acceptance stay in phase two. The original 72/80 rows, 50/94 literal outputs,
44 missing and zero accepted whole-image matches remain. Prior successful
and FAILURE/HOLD/UNKNOWN observations retain their original source and scope.
The Deposit candidate remains unapplied. No local SDK execution is added.
