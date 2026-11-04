# Keep stake cancellation with its confirmed account

The cancellation dialog retained a stake hash while its later event captured
the selected wallet only when publication began. An account or wallet change
during confirmation could therefore replace the original action context.
Concurrent row requests also had no imperative busy check, and late results
could refresh the replacement view.

The table now supplies the stake entry's owner. The button captures the painted
owner, hash, amount and context generation before opening the original dialog.
It also captures the existing WalletActionContext. A retained callback checks
the original paint and visibility before opening; Yes requires that same
context, row and mounted cancellation owner. No still closes the original
dialog without constructing a block. Confirmation text and button geometry
remain unchanged.

After Yes, the original client's Stake API builds the original hash's template.
An owned event carries that exact block, spending account and publication
guard. The existing AccountBlockUtils receives the original address, unchanged
plasma-wait setting and guard. Its wallet acquisition, signing, original result,
history and transport code remain unchanged. The row admits only one question
or submitted request at a time; its bloc also refuses overlap before loading.

Preparation and completion recheck authority. An accepted original remains
owned by the existing publication path; a stale result does not refresh another
context or invoke its row callback. Current failures use the existing error
mapper. Legacy event construction remains available to existing non-UI callers;
the production table uses the owned path.

Four new bloc cases cover exact arguments/guard, duplicate requests, revoked
admission and late accepted/refused outcomes. Seven new real-dialog cases
cover both themes, exact original input, duplicate callbacks, No, hidden and
old paint, account round trips, view removal and late accepted results. Their
publisher records in-memory arguments without a wallet profile, file open,
signer or network transport. All three original bloc cases remain. The existing
seven-case table suite joins unchanged, retaining compact-density geometry,
confirmation, keyed row identity, scaled text, animation and privacy checks.

All previous 85 focused files remain. These three complete files add 21 cases:
88 files in 44/44-file streams, requiring 1,115 ordinary cases (546/569), or
1,117 with the separate asset selection. Eleven cases are newly registered;
no Python registration is added. The owning libraries and complete tests join
strict analysis. Nineteen fully mocked local admission/analysis controls pass.
Python retains 955 controls and three existing hosted skips. Original worker,
deadline, output, source and startup/entry-refusal bounds remain. Fresh focused
engine and zero-finding analysis are pending.

## Original Source405 pre-SDK refusal

Source405 `d5d594baa67762fc0eb975ea1e59a5d4db55568d`, tree
`b8397d6180e22906cde1f356fb30c9af772ff0cb`, retains failed
[41765703173](https://github.com/edgepillar/syrius/actions/runs/41765703173),
attempt one, job 126363452056. Python completes 955 controls with one failure,
zero errors and three existing skips. The failing control requires the fixed
public test-basename catalog to equal the actual source tree. The new
cancel_stake_button_test.dart basename was absent from that catalog.

Asset execution, SDK allocation/restoration, analysis and Dart execution are
all skipped. All source-bound jobs are terminal with zero artifacts. This is
an original pre-SDK refusal, not an application-test or analyzer result. The
original producer is not retried.

## Source406 catalog and context follow-up

The catalog adds only the new versioned public basename. Its exact coverage,
sorting, unknown-name, private-path and output bounds remain unchanged. All
test files, cases, selectors, publication controls and worker limits remain.
The existing five catalog/privacy controls and nineteen mocked admission/
analysis controls pass locally, with no scratch, SDK or native execution.

Source review also adds an explicit mounted check for the original builder
context and captures the existing error label before the dialog's await. A
late callback cannot consult an unmounted descendant context. Dialog text,
original block/address/guard arguments and every existing test remain. Fresh
Source407 focused engine and zero-finding analysis are pending; the original
Source406 analysis result is retained below.

## Original Source406 analysis refusal

Source406 `db93a4b4a6857493d7da2e5eba508e6c0c60bb9a`, tree
`b6568d78b8882b9c93d9e6c0d3a2d4561db81524`, retains failed
[41766560606](https://github.com/edgepillar/syrius/actions/runs/41766560606),
attempt one, job 126366181551. Python completes all 955 controls without
failures/errors and retains three existing skips. Fourteen assets pass.
Analysis exits normally with complete 958-byte output, zero errors/warnings
and five infos: two CURLY_BRACES_IN_FLOW_CONTROL_STRUCTURES at 135:56 and
156:39, and three AVOID_RELATIVE_LIB_IMPORTS at 12:8, 13:8 and 14:8. All are
categorized as other. Raw diagnostic paths are not retained or reconstructed.
The zero-info gate refuses; Dart is skipped. All jobs are terminal with zero
artifacts, and the original producer is not retried.

## Source407 declaration cleanup

Source correspondence identifies two multiline returns and the new widget
test's three relative library imports. That correspondence is source inference,
not a reconstructed raw diagnostic path. The returns now have braces and the
test imports the same declarations through package URIs. The complete fixture
and test bodies are byte-identical. No test, condition, publication argument,
worker or output bound changes. X564 separates this declaration cleanup from
X563's application-flow acceptance. Fresh strict analysis and all 1,115 focused
cases remain required.

The fast first-delivery priority continues. No new full Windows build, native
chain producer, image transport or local SDK execution accompanies this source
change. Native cancellation effects and full visual/platform/performance
acceptance remain open. The original ledger stays 72/80, 50/94 literal outputs,
44 missing and zero accepted whole-image matches. Earlier success, failure and
UNKNOWN observations retain their original source and scope. Source403's
Deposit readiness is focused-qualified; Native108's separate cause remains
NOT_ESTABLISHED and its native replay remains deferred.
