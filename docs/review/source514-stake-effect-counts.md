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

At preparation, fresh hosted Dart/analysis qualification was pending. The
actual negative result is recorded below. The new counters have no native
observation yet. No new native run, old profile or original operation is
started by this source qualification. P03/P09/F06 and V01/V02/V03/V05/V06,
the original 72/80 ledger and zero accepted whole-image matches remain open.

## Actual Source514 analysis refusal

Tested head f43b899e1409ed3c827985c222c3e57dc87239b4, tree
ed66f0bf6567f8037a286aae467c84b5fa8e0bd5, has one observed
[run 42130643044](https://github.com/edgepillar/syrius/actions/runs/42130643044),
attempt one, job 127606066879. It fails at selected analysis with zero errors,
zero warnings and eleven infos. All 1087 Python cases finish with eighteen
explicit Windows skips and zero failures/errors. Fourteen asset controls
pass. The Dart engine step is skipped, so no 1350-case Dart result qualifies.
The source remains unchanged; the run is terminal with zero artifacts.

The first dispatch client exits one with unexpected end of JSON input, and
its request outcome stays UNKNOWN. A reviewed request repair adds an explicit
JSON media type and retains HTTP status/headers/body. It receives HTTP 204
with an empty body. Both request attempts remain recorded; the exact request
origin of the single observed run is NOT_ESTABLISHED. Neither HTTP acceptance
nor the Python success replaces the failed analysis or unexecuted Dart gate.

The installed CLI's file-body path does not automatically add the JSON media
type used for map bodies; see its pinned [HTTP request implementation](https://github.com/cli/cli/blob/v2.97.0/pkg/cmd/api/http.go#L26-L72).
That verified omission does not establish the original failure's exact cause.

## Source515 analysis correction

Source515 moves the constructor declarations before members, orders imports,
uses the equivalent null-aware map entry, adds the required flow braces and
uses explicit map types and method tear-offs in the tests. The optional source
capability retains one documented local style exception: the observation is
bound to the captured source as its receiver. Global analyzer rules and the
zero-finding gate remain unchanged.

The effect predicate, guard, round count, delays and every RPC/publication
path remain. No test is removed and no registration is added. Expected counts
remain 1350 Dart (644/706 in 51/51 files) and 1087 Python/eighteen Windows
skips. Fresh hosted qualification is pending; the Source514 failure and all
older UNKNOWN outcomes remain preserved.
