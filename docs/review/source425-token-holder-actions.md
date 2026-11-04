# Token holder actions

Source425 follows the ownership distinction in
`mockups/redesign/src/40-plasma-tokens.html`. An expanded token owned by another
address starts with four metadata facts and compact Burn/Send controls. The
owner keeps Mint, Burn, Transfer ownership and Flags. Existing dialogs retain
their fixed action and existing form.

The compact controls use the existing theme tokens for the reference's
26-pixel minimum height, 10-pixel horizontal padding, 12-pixel medium labels,
surface, foreground and border. Both directions use logical layout. Burn opens
the retained form only after an explicit activation with a current proof that
permits burning. Owner-only Burn is absent for another selected address, even
when that owner is elsewhere in the wallet's address list. A valid Send control
establishes that the read-only holder case has a complete current proof.

The new Burn disclosure captures the original proof and view epoch and checks
them again before opening. Pending confirmation/publication, an existing held
outcome and a replaced publisher prevent activation. Scope changes close its
draft. A confirmed original can still use Another to obtain a fresh proof and
open an empty Burn form. The existing Send callback is shared between the
compact control and the owner's footer, retaining its exact standard and
context checks.

Form validation, submission, question, receipt, notification and disposal code
remain byte-identical. Another adds only its view flag after the existing fresh
proof succeeds. Token action/session/publisher, sender and transport files are
unchanged. Existing domain and submitted-transaction links retain their current
path. A configured token-explorer link remains unverified; this change does not
establish complete expanded-row visual correspondence.

The original 26 inline-action case bodies remain byte-identical. Four new cases
cover both themes and text directions. They require the initial read-only view,
26-pixel Burn control, stale Burn/Send refusal after publisher replacement,
working fresh exact-standard Send and Burn input, a declined synthetic question
without publication, one accepted in-memory publication, close/reopen of its
held outcome, confirmed Another and refusal of the earlier submit callback.
All accepted/confirmed outcomes are isolated fixtures, not live-chain evidence.

The three existing Burn permission scenarios retain their owners, capabilities,
85-unit supply and valid 40-unit balance. They now use the holder disclosure or
owner segment as appropriate. The selected non-owner case requires absent Burn
controls alongside a working exact-standard Send callback and zero publication.

The focused selection retains all 96 files in the same order. Four new global
Dart cases prepare 1,227 ordinary cases in 48/48-file serial streams (595/632).
The asset-fidelity variant is 1,229 and remains outside the ordinary selection.
Python registration count and every process/output/worker bound are unchanged.
Thirty-seven local mocked/read-only controls pass. Fresh hosted Flutter tests
and selected analysis remain pending; no local SDK is executed.

The first delivery remains a Draft code-review milestone. Heavy Windows builds,
native chain-321 execution, image transport, all 94 visual comparisons,
motion/frame-time observations and final independent acceptance remain phase
two. Original acceptance stays 72/80, with 50/94 historical literal outputs,
44 missing and zero accepted whole-image matches. Reference files, dependencies
and original failure/UNKNOWN evidence are preserved.
