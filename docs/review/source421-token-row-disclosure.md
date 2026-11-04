# Token ledger disclosure

Source421 follows the original collapsed token rows in
`mockups/redesign/src/40-plasma-tokens.html`: the trailing column contains one
quiet disclosure chevron. Mint, Burn and ownership controls remain in the
existing expanded panel. The separate favorite star remains available.

The header and rows reserve the same 32-pixel disclosure slot. Opening checks
the original list context again, so a callback retained before an address or
node change cannot open an obsolete panel. Closing remains possible. The
existing detail epoch, action proof, amount, confirmation, publisher and
settlement checks remain unchanged.

The owner capture recipe selects the same eligible mintable owner row through
an identifier on its disclosure, then selects the existing Mint segment. It
still only opens a draft; no question, signer or publication runs. This source
change does not qualify the deferred native recipe.

Existing tests now exercise the disclosure and inline action path:

- Both themes and text directions retain exact balances and require the
  single 32-pixel disclosure without collapsed Mint/Burn shortcuts.
- Retained disclosure callbacks refuse a revoked context. Address, node and
  wallet-context changes retain the existing balance and filter checks.
- The real owner disclosure opens the existing mint panel; the established
  close/reopen and other-row checks still reject retained submit/Send callbacks.
- All three Burn cases use the in-memory action proof and existing amount
  form: public burn, owner-only burn, and selected non-owner refusal. Opening
  the panel reads the synthetic token/account once and publishes nothing.

The complete three affected files add 39 existing cases to every previous
focused path. The ordinary selection is 96 files and 1,223 cases, split into
48/48-file serial streams with expected passes of 595/628. No new global Dart
or Python test registration is added. All process, output and worker bounds
remain. Selected analysis includes the affected files and existing action
panel/support. Thirty-seven local mocked/read-only controls pass; fresh hosted
Flutter tests and selected analysis remain pending.

The first delivery remains a Draft code-review milestone. Heavy Windows
builds, native chain-321 execution, image transport, all 94 visual comparisons,
motion/frame-time measurements and final independent acceptance remain in the
second phase. Original acceptance stays 72/80; the historical pool remains
50/94 literal outputs, 44 missing and zero accepted matches. Current native
token pixels and complete expanded-row visual correspondence remain open.
Reference files, dependencies, financial transport and original failed or
unknown qualification evidence are preserved.

## Original Source421 result and Source422 fixture setup

[Run 41796451862](https://github.com/edgepillar/syrius/actions/runs/41796451862),
attempt one, job 126461590848, retains 955 passing Python controls with three
existing skips, fourteen passing assets and complete zero-finding selected
analysis. Both 48-file Dart streams finish normally within the original bounds:
595 passes first, then 625 passes and three failures. Their original outputs are
complete and unforced; no producer is retried.

All three retained details identify `token_card_test.dart:109`, where the new
in-memory action fixture constructs its synthetic sender. Full original error
messages remain unretained. Source inspection identifies a missing prerequisite:
the sender extends HydratedBloc, and the other action widget tests initialize
the shared mock storage before constructing it. This is a source diagnosis,
separate from the closed runtime details.

Source422 adds that existing mock-storage import and initialization to the Burn
file. Every fixture input, permission assertion, action path, application byte,
registration, selected file/count and process bound remains. Completed local
controls are reused on unchanged Python bytes. Fresh 1,223-case hosted runtime
qualification remains pending. Heavy phase-two acceptance stays deferred.

## Original Source422 result and Source423 bounded balance

[Run 41798633281](https://github.com/edgepillar/syrius/actions/runs/41798633281),
attempt one, job 126468680131, retains passing Python/assets and complete
zero-finding analysis. Both 48-file streams finish normally with 595 and 625
passes, plus three failures in the second stream. All retained details now
identify `token_card_test.dart:150`, at entry into the Burn amount field, rather
than the earlier fixture constructor. Full original messages remain unretained.

Source inspection finds that the shared action fixture's large default balance
exceeds this legacy token fixture's issued supply of 85. The existing account
snapshot deliberately refuses a balance above issued supply, so that input
cannot establish an actionable form. This diagnosis comes from the fixture and
the unchanged snapshot validator, separately from the closed runtime locations.

Source423 gives these three cases an explicit synthetic balance of 40. Every
other fixture input, permission assertion, application byte, registration,
selection/count and process bound remains. The supply validator is unchanged.
Completed local Python controls are reused. Fresh 1,223-case hosted execution
remains pending; both original failed producers and all phase-two acceptance
remain preserved.
