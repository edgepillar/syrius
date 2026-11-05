# Source514: passive Stake effect counts

The independently verified [Native112 result](source512-native112-stake-effect.md)
has thirteen absent account-block reads followed by five effect_pending rounds
at copied Stake. Those counters do not distinguish an empty effect list from
a record that fails an existing predicate. The original outcome remains
UNKNOWN and its cause NOT_ESTABLISHED.

The pinned node uses the original send hash for the Stake entry id and adds
the requested duration to the start timestamp. The RPC reports the total
active entry count separately from its page. These source facts support the
existing checks; they do not establish the cause of Native112's result.
See the pinned [Stake receive implementation](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/vm/embedded/implementation/stake.go#L62-L82)
and [Stake RPC](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/rpc/api/embedded/stake.go#L176-L218).

## Change

Source514 captures a bounded negative summary from the same already-returned
Stake list. Reported and returned counts remain separate. Predicate counts
are present only when the existing full-list gate passes. The successive
counts identify rows matching the original id, then owner, amount and duration.
An exact single matching row is positive and cannot enter this negative data.
An incomplete list exposes NOT_RUN without invented predicate counts.

The original effect predicate remains intact and determines the same boolean
result before passive collection. Collection adds no RPC call or publication.
The captured source binds its cached immutable summary to the current owner
context and original private hash; neither value enters the public summary.
An unavailable diagnostic preserves the original negative outcome.

The guard reads this data only after the existing false Stake effect read.
It clears the current summary for every round, so an earlier effect read
cannot decorate a final absent/unconfirmed round. Only the exhausted original
publish refusal with a final effect_pending round may carry the summary.
The original eighteen-round window, delays, receipt/effect requirements,
admission and once-only journal/publication behavior remain.

The actual CLI reply accepts the previous singleton details or the exact
confirmation-plus-Stake envelope. The trace copies immutable values only for
the original Stake publish reply. Python applies the same closed schema,
phase/reason/last-round checks and monotonic integer bounds. Other fields,
identities, raw rows, amounts, timestamps, paths and exception text are refused.
No summary grants success, operation authority or retry permission.

## Validation scope

Thirty-nine local memory/mocked control methods pass, including the exact
Python projections, analyzer path admission, known-file privacy and updated
fixed-count admission. A synthetic extension of the retained parent verifies
all five bounded frames, with sizes 3096/623/622/637/1581 bytes and unchanged
parent bindings. That extension is a memory control, not new native evidence.

Twelve new Dart registrations cover progressive/duplicate matches, incomplete
and bounded lists, privacy, original read/tap/journal counts, stale final
rounds, failed diagnostics, positive/foreign recipes and actual CLI envelopes.
Three new Python registrations cover copying, schema/privacy and context.
All preceding selected test paths remain. The fixed count gate now requires
1350 ordinary or 1352 asset cases; old counts and adjacent counts still refuse.
The ordinary two groups remain 51/51 files, with expected passes 644/706.
Python expects 1087 cases and eighteen existing Windows skips. The new pure
fixture is included in selected analysis and known-file failure projection.

Fresh hosted Dart/analysis qualification is pending. The new counters have no
native observation yet. No new native run, old profile or original operation
is started by this source qualification. P03/P09/F06 and V01/V02/V03/V05/V06,
the original 72/80 ledger and zero accepted whole-image matches remain open.
