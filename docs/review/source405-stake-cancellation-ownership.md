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

The fast first-delivery priority continues. No new full Windows build, native
chain producer, image transport or local SDK execution accompanies this source
change. Native cancellation effects and full visual/platform/performance
acceptance remain open. The original ledger stays 72/80, 50/94 literal outputs,
44 missing and zero accepted whole-image matches. Earlier success, failure and
UNKNOWN observations retain their original source and scope. Source403's
Deposit readiness is focused-qualified; Native108's separate cause remains
NOT_ESTABLISHED and its native replay remains deferred.
