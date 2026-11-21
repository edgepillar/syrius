# Independent Windows screenshot review

The independent reviewer inspected all 94 Windows/reference pairs for
`28f9c121058c89dff1138d4c0f68c6a560f0ab11`, tree
`fcefe9e1b768a5b65d0acfc728a78c29ef09b10e`. The review used the comparison
page, the owner decisions in the [mockup README](../../mockups/redesign/README.md)
and the [design checklist](../design/RULES.md#9-checklist-for-a-screen). Earlier
verdicts were hidden from the reviewer. The archived pair selection binds both
PNG digests for each of the 47 states in both themes.

The [strict verdict file](source-28f9c121-screen-verdicts.json) records all
94 original hash-bound decisions. It preserves the 14 matches and 80
mismatches from the strict Screens table. With the current prepared-catalog
checks, the same archives yield 14 reviewed matches, 70 reviewed mismatches
and 10 diagnostic captures. The original archives and reference PNGs were
read directly, with no new screenshots or copies.

The [capture index](source-28f9c121-captures.json) references the 24 original
archives by SHA-256. Set `SYRIUS_ARCHIVE_OBJECTS` to the directory containing
those verified archive objects. From the repository root, open the private
comparison on loopback with:

```sh
python tool/redesign_compare.py \
  --actual-manifest docs/review/source-28f9c121-captures.json \
  --archive-dir "$SYRIUS_ARCHIVE_OBJECTS" \
  --reviews docs/review/source-28f9c121-screen-verdicts.json \
  --target-source 28f9c121058c89dff1138d4c0f68c6a560f0ab11 \
  --serve
```

Use `--summary-only` in place of `--serve` for the source-pinned inventory
without starting a viewer.

The reviewer reported 42 visual matches and 52 visual mismatches. A visual
match here means the named state and its material structure were visible.
Some visual matches still show a differing sampled frame or leave a secondary
state unseen. The progress table retains the stricter whole-image verdicts.
Fixture-limited mismatches identify the state needed for a fresh comparison.

Still images support visible review of typography, hierarchy, placement, color,
controls and status labels. The brand values approved by the owner are
`#00D557` and `#0061EB` with the documented semantic ink tokens. Tooltips,
runtime fetches, source token use, animation curves and timing, persistence,
ownership and transaction behavior require their own evidence.

## Pair findings

| Dark capture | Light capture |
| --- | --- |
| `01-home-rest-dark` **Mismatch.** The default balance eye is barely visible. Live activity, rewards and pending rows differ. | `01-home-rest-light` **Mismatch.** The eye loses its readable outline. Activity and rewards show the sparse fixture. |
| `02-home-open-dark` **Match.** The expanded rail and Tokens card align. Token rows and flash timing differ. | `02-home-open-light` **Match.** The expanded light rail and Tokens disclosure align with an empty token fixture. |
| `03-home-hidden-dark` **Match.** Hero and activity amounts are masked. The green eye is visible. | `03-home-hidden-light` **Match.** The dots and green eye occupy the expected positions. Reward data is absent. |
| `04-home-bell-dark` **Mismatch.** The drawer shell aligns. Approval, grouped history and toast states are missing from the capture. | `04-home-bell-light` **Mismatch.** Drawer elevation appears. Approval and toast states are missing from the fixture. |
| `05-home-goto-dark` **Mismatch.** The address lane is absent, shortening the panel. The title bar remains sharp outside the scrim. | `05-home-goto-light` **Mismatch.** Contacts are absent. The undimmed title bar forms a pale strip. |
| `06-home-zap-dark` **Mismatch.** The dialog sits lower, adds a divider and leaves the title bar sharp. | `06-home-zap-light` **Mismatch.** The dialog sits lower and adds a divider. The bright title bar stays outside the scrim. |
| `07-send-rest-dark` **Mismatch.** The empty fixture omits the populated recipient, recent chips, estimate and receive rows. | `07-send-rest-light` **Mismatch.** The empty form omits the populated form and the in-progress receive state. |
| `08-send-warn-dark` **Match.** The node banner, look-alike comparison and waiting action appear. Shorter text changes card height. | `08-send-warn-light` **Match.** Both warnings and the waiting action appear. Focus and node values differ. |
| `09-receive-dark` **Mismatch.** Copy and Show QR align. The reference's one-line empty To receive row is absent. | `09-receive-light` **Mismatch.** The QR stays behind the button. The reference's one-line empty To receive row is absent. |
| `10-receive-qr-dark` **Mismatch.** Share image replaces Copy image and the amount-token icon is absent. | `10-receive-qr-light` **Mismatch.** The QR and request amount align. The image action changes and the amount-token icon is absent. |
| `11-zap-form-dark` **Mismatch.** The capture lacks recipient selection and the source-address selector. The payment action appears enabled. | `11-zap-form-light` **Mismatch.** The stranger fixture leaves the recipient blank and omits the source selector. The gradient action appears enabled. |
| `12-send-confirm-dark` **Mismatch.** The first-time software-wallet fixture displaces the Ledger prompt and fused-plasma line. The dialog sits lower. | `12-send-confirm-light` **Mismatch.** The first-send warning and plasma presentation replace the hardware-wallet state. The title bar stays undimmed. |
| `13-staking-dark` **Match.** The summary and locked countdown row align. Zero rewards and one stake limit row coverage. | `13-staking-light` **Match.** The summary and table align with one locked stake. The unlocked row remains unseen. |
| `14-staking-new-dark` **Match.** The inline duration, amount and unlock-date form preserves the layout. | `14-staking-new-light` **Match.** Duration, form and Stake retain their positions. The list contains one stake. |
| `15-staking-empty-dark` **Match.** None yet and the one-line Rewards group appear. The mark has a partial slash. | `15-staking-empty-light` **Match.** The empty panel and Rewards line align. The mark is at a different frame. |
| `16-pillars-dark` **Match.** The tabs and expanded row preserve the hierarchy. Search and delegation fixtures differ. | `16-pillars-light` **Match.** The open row and five columns align. Filtering yields one result. |
| `17-pillar-mine-dark` **Mismatch.** Collect moves to the far edge, Producing is absent and the ledger is taller. | `17-pillar-mine-light` **Mismatch.** Art and four actions remain visible. The summary lacks Producing and moves Collect. |
| `18-sentinels-dark` **Match.** The Sentinel asset, Active badge and table align. One row and zero rewards are fixture differences. | `18-sentinels-light` **Match.** The operator strip, tab and status column align. The fixture has one sentinel and different revocability. |
| `19-spawn-dark` **Mismatch.** Blank name and producer fields and disabled Continue leave validation unseen. A tooltip crosses the form. | `19-spawn-light` **Mismatch.** Step two is incomplete under an overlaid tooltip. The validated reference state is absent. |
| `20-pillar-done-dark` **Mismatch.** Address and chain metadata plus a secondary registration action extend the sidebar. | `20-pillar-done-light` **Mismatch.** The sidebar is substantially longer. An address tooltip crosses the panel. |
| `21-plasma-dark` **Mismatch.** The hero bolt is a faint outline with a different glow. The generating strip is absent. | `21-plasma-light` **Mismatch.** A hard black disc bounds the bolt glow. The generating strip and elapsed-time fixture are absent. |
| `22-plasma-fuse-dark` **Mismatch.** The inline form and disclosure appear. Unchecked rows omit the batch action, and the bolt glow differs. | `22-plasma-fuse-light` **Mismatch.** The black disc changes the hero. Unchecked rows omit the selection treatment and batch action. |
| `23-tokens-dark` **Mismatch.** The empty Held fixture leaves balances, token rows and expanded owner controls unseen. | `23-tokens-light` **Mismatch.** Headers remain. Populated rows and disclosure are absent. |
| `24-token-mine-dark` **Match.** Owner actions, Mint selection and inline inputs align. Max and secondary links are added. | `24-token-mine-light` **Match.** The row and Mint hierarchy align. Secondary links extend the row. |
| `25-token-new-dark` **Mismatch.** A plasma and refresh block pushes the preview down. The symbol validation tick is missing. | `25-token-new-light` **Mismatch.** Extra sidebar controls move the preview. The selected symbol field lacks the reference tick. |
| `26-swap-list-dark` **Mismatch.** Waiting and the deposit ID appear. Completed and reclaimed rows are absent, and expiry, hashlock and secret fields differ. | `26-swap-list-light` **Mismatch.** The expanded ledger uses different fields and timing. Completed and reclaimed rows are absent. |
| `27-swap-start-dark` **Mismatch.** Two amount cards remain. The dialog is taller and uses an informational block in place of the amber warning. | `27-swap-start-light` **Mismatch.** The taller dialog has a weaker shadow and changes the amber warning and join-window line. |
| `28-az-dark` **Mismatch.** The empty Voting fixture leaves budgets, vote bars, quorum and status rows unseen. | `28-az-light` **Mismatch.** Fund and filters align. The empty table leaves voting rows unseen. |
| `29-az-project-dark` **Mismatch.** The vote column appears without phases or populated quorum. | `29-az-project-light` **Mismatch.** The two-column layout appears without phase proofs, phase votes or populated quorum. |
| `30-set-node-dark` **Mismatch.** The pre-check state shows a repository input in place of the downloaded-and-verified callout. | `30-set-node-light` **Mismatch.** The earlier update state lacks the installed/latest and download verification treatment. |
| `31-set-security-dark` **Match.** The wrong-password limit shows 3, with the same segment, backup and collapsed actions. | `31-set-security-light` **Match.** The controls and warning align with 3 selected. |
| `32-set-display-dark` **Match.** The Display groups and enabled Dollar values switch align. Locale selection differs. | `32-set-display-light` **Match.** The layout and dollar toggle align. The captured theme selector highlights Light. |
| `33-set-wallet-dark` **Mismatch.** Maintenance adds a row. Delete cache omits the preservation wording. Switch values differ. | `33-set-wallet-light` **Mismatch.** The extra Maintenance row and changed cache copy are visible. Auto-receive and notification selections differ. |
| `34-set-apps-dark` **Mismatch.** Apps is nested under Settings. The empty fixture leaves connected rows and Disconnect controls unseen. | `34-set-apps-light` **Mismatch.** The switch and WalletConnect group align. Connected sessions are absent. |
| `35-set-addresses-dark` **Mismatch.** Address selection appears. The empty contact fixture omits contact, Send and edit rows. | `35-set-addresses-light` **Mismatch.** Addresses are populated but Contacts is empty, leaving its rows unseen. |
| `36-set-about-dark` **Match.** The version area, update actions and three closed groups align with different version data. | `36-set-about-light` **Match.** The light cards and update controls align with different version and update data. |
| `37-set-licences-dark` **Mismatch.** The end field is plain as specified. Per-row licence type is absent. | `37-set-licences-light` **Mismatch.** The list and unlabeled field align. Per-row licence type is absent. |
| `38-set-originals-dark` **Match.** The six tiles, utility row and Play launch align. The field is cleared and artwork samples differ. | `38-set-originals-light` **Match.** The card aligns and the field is cleared as specified. Asset phases and licence columns differ. |
| `39-launch-dark` **Match.** The full-window black stage, green monogram and skip cue align. | `39-launch-light` **Match.** The black stage, centered mark and skip cue align. |
| `40-launch-settle-dark` **Mismatch.** The capture has a flat inset stage and early status strip. The reference shows the shader and emerging lock card. | `40-launch-settle-light` **Mismatch.** The capture has a flat backdrop and smaller stage. The reference shows the shader, shadow and rising card. |
| `41-lock-screen-dark` **Match.** The wordmark, password form and card align. Wallet labels and status data differ. | `41-lock-screen-light` **Match.** The card and sampled black well align. Both wells are blank, so the light end-frame wordmark remains unseen. |
| `42-lock-wrong-dark` **Match.** The mark, crimson outline, warning icon and two-tries text align. | `42-lock-wrong-light` **Match.** The warning and empty password field align. A focus caret is visible. |
| `43-lock-pick-dark` **Match.** The open picker has three choices, a selected item and Add a wallet. | `43-lock-pick-light` **Match.** Picker elevation and wordmark align. Wallet identifiers differ. |
| `44-welcome-dark` **Match.** The globe, backdrop and three routes align. | `44-welcome-light` **Match.** The globe and three light cards align in position and size. |
| `45-import-dark` **Match.** The stepper, drop zone, word count and disabled Continue align. | `45-import-light` **Match.** The light card and incomplete-entry presentation align. |
| `46-seed-quiz-dark` **Match.** Challenge rows, answer pills and progress align. Fixture choices are wider and the copy shorter. | `46-seed-quiz-light` **Match.** Question rows and disabled Continue align with different synthetic choices. |
| `47-wallet-ready-dark` **Match.** The dotted map, completion card and Open wallet align. The address is fixture-specific. | `47-wallet-ready-light` **Match.** The map, glass card and four completed stages align. |

## Open rule and capture questions

- The Receive screen note and reference show an empty To receive row. The README
  specifies To receive only when it has rows. The comparison retains the
  visible difference and the application follows the README.
- The Originals entry field is cleared by design. The reference still displays
  the unlock code. Different art samples remain visible in both themes.
- The launch-settle stills differ. Inspect the running transition at the same
  phase before attributing the difference to the 400 ms motion.
- The light Lock at-rest samples show blank wells. The light picker shows the
  wordmark. The light at-rest end frame still needs a settled capture.
- The open Home flash, empty Staking mark and Originals art need matched
  animation samples for whole-image acceptance.

## Receive amount clarification

The separate [Receive candidate](https://github.com/edgepillar/syrius/commit/f976ff025a434656964b53928377e620c564ca50)
adds a short explanation when a valid amount reaches the QR payload.
[Linux qualification](https://github.com/edgepillar/syrius/actions/runs/44311535648)
passes strict analysis, the compact UI and nonchain suites, and generated-file
verification. The [Windows candidate run](https://github.com/edgepillar/syrius/actions/runs/44313990394/job/134835167224)
stops in the asset helper's branch admission check with `ENVIRONMENT_REFUSED`.
No wallet, native node or screenshot was reached on that candidate run.
