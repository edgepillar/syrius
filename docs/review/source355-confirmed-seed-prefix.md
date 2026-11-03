# Retain confirmed seed stages before a later failure

The copied F06 workflow previously returned its receipt list only after all six
recipes finished. A later refusal therefore left the earlier confirmed recipes
without exported final receipts. Native103's original Token confirmation/effect
remains `UNKNOWN`; this change cannot reconstruct that earlier execution.

## Change

The harness workflow now emits one immutable private receipt prefix after each
original recipe returns its exact confirmed result and the original owner check
passes. It awaits the existing output flush before starting the next
recipe. Prefix receipt maps and their list are independent immutable snapshots.
A failed sink stops the workflow and retains the consumed original attempt.

The controller accepts exactly one new recipe at a time in the original order:
Stake, Fuse, Token, Deposit, Project and fund-address. It reads only that new
recipe's three existing attempt/accepted/confirmed journals, with the original
2,048-byte limit, regular-file identity checks and exact receipt-hash binding.
Previously retained identities remain pinned and are checked before and after
the new observation. A replay, gap, changed predecessor or inconsistent journal
refuses before progress can replace the previous prefix.

The private transport record retains the latest validated prefix if a later
recipe fails. Its public diagnostic contains only the bounded count, fixed
recipe names and a digest of the private receipts. It always has
`complete: false` and `seed_admitted: false`, including at six receipts.
Addresses, original hashes, paths and error messages are not included in that
public prefix projection.

Full success still requires the final six-receipt message, exactly matching the
last retained prefix, final journal identity/content correspondence, original
owner checks and normal closure. Legacy stored full-result schemas remain
strict. A prefix cannot be passed to the full seed-result or reopen validator
as completed work.

No SDK, dependency, ordinary application UI, recipe selector, original
publication/confirmation/effect call, amount, retry policy, deadline or output
cap changes. No original financial/profile/password/seed/send/reopen flow is
replayed to prepare this source.

## Source review and controls

The locked SDK remains
`16bf294b3e347cb4f9c1f47a7da5d60034724f95`.
Its [ledger method](https://github.com/maznnwell/znn_sdk_dart/blob/16bf294b3e347cb4f9c1f47a7da5d60034724f95/lib/src/api/ledger.dart)
returns a null block for a null RPC result and otherwise constructs the block
model. The inspected method and WebSocket request path do not catch a request
or model exception and convert it to a null block. The current binding, seed
policy and command files remain byte-identical to Native103's versions.
This source review establishes no earlier runtime cause or SDK bug; Token
absence/confirmation remains `NOT_ESTABLISHED` and its outcome stays `UNKNOWN`.

All 53 selected memory-only controls pass, including execution of the actual
controller wait function with two valid prefixes followed by the next child's
failure. Tests cover immutable snapshots, a blocked sink, owner replacement,
later negative receipts, journal mismatches, skipped/replayed progress, private
field rejection and the distinction between a prefix and full success.
No local SDK, wallet, node, network service or filesystem fixture runs for these
controls.

Five new Dart cases join all existing selected cases. Thirteen Python cases
join all existing controller cases. The exact ordinary/startup Dart totals are
888/890; expected Python discovery is 953 with the three existing skips.
The ordinary 72-file selection, both complete 36-file groups, one worker, original
deadlines, both pre-build refusals and all three startup checks remain.
The former 883/885 totals are retained as negative admission cases. Fresh
hosted strict analysis and execution are pending.

## Acceptance remains open

This is a harness evidence-retention change. A fresh source-bound owned runtime
and independent reader must still qualify its real receipt/journal flow before
any new financial seed acceptance. Native104 remains unadmitted; Native101/103,
the original Source336 Home failure and all prior FAILURE/HOLD/UNKNOWN records
retain their original status.

The [Source353 Windows and Home evidence](source353-windows-and-home-results.md)
retains its original source and review scope. Main acceptance remains 72/80
original rows, nineteen preparations, 50/94 available literal outputs, 44
missing and zero accepted visual matches. The
[exact preceding body288](pr-body-288.md) preserves its submitted text and URLs.
Public content stays English-only with edgepillar no-reply/UTC attribution,
and the PR remains Draft.
