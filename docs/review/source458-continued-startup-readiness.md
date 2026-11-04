# Continued startup readiness within the original bound

The [Source456 reference result](source456-reference-lab-build.md#actual-source456-result)
qualifies normal retirement of all five original containers, but remains failed
at production. Up returns after height one becomes two; the immediate status
window then stays at two for thirty seconds. A closed late-broadcast code is
observed, without proof of the sole stall cause. No failed trial is retried.

Source458 strengthens the actual `lab.sh up` readiness condition. Its existing
180-second progress window now requires at least two height advances, through
`frontier.js --advances 2`, after the existing ninety-second initial RPC wait.
Status retains its thirty-second window and one-advance requirement. The node
source, reference compiler recipe, stop grace and protocol broadcast deadline
remain unchanged. This is a readiness correction and a longer observation
within the existing startup bound, not a proven repair of node production.

The JavaScript reader rejects malformed, fractional, zero or repeated advance
options, invalid timing values, a foreign chain and invalid heights. A regressing
frontier cannot pass. The controller independently requires the two-advance delta
for up, retains the one-advance status guard and reports `startup_min_advances=2`.
An unsuccessful up retains only a closed stalled/insufficient-progress record
with bounded chain, heights, duration and requested delta. Raw RPC errors are not
exported. A partial advance cannot become a positive startup receipt.

The existing failed/unknown-start rule remains: resources are not adopted after
a failed up command, and no guessed down is submitted. If the stricter startup
fails, the fresh VM's resources remain held; VM disposal is not qualified. The
five normal exits from Source456 remain evidence for that earlier source/run,
not a guarantee for this new selection.

Source CI now checks every pinned lab input before its suite, and changes to any
of those inputs select the source workflow. Two new pure cases exercise the
positive startup boundary and refused partial-progress records. One hosted-only
actual-Bash case checks the up/status argument contracts. Two hosted-only
JavaScript cases execute the actual script in Node with an inert HTTP adapter
and a fake clock: multiple advances, a single partial advance, both unchanged
windows, initial RPC retry, malformed options, foreign/invalid heights and
regression. No socket, Docker daemon, Go chain node, wallet or SDK is involved in
these fixtures. They do not qualify real RPC transport or production.

All twenty-nine local pure controls pass; eleven Bash and two JavaScript cases
remain unselected locally. Hosted preparation is 1,048 Python cases. Fresh
source and reference runtime execution are pending. All five lab input pins,
source/tree/run/attempt bindings, original identity checks, parent deadlines,
stream/storage limits, single-down rule and five-zero-exit/no-OOM criteria remain.
The strengthened receipt-size test includes partial startup observations.

No application Dart, dependency manifest, design reference, local SDK execution,
binary/image transport, full Windows build or heavy seed/visual/motion job changes.
Full acceptance stays 72/80 with zero accepted whole-image matches. P03/P09/F06
and final platform, visual and performance acceptance remain open; the PR stays
Draft and public artifacts remain English and privacy-safe.
