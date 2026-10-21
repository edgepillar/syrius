# Quality-of-life ideas for desktop Syrius

Wishlist item 7: "Any quality-of-life improvements that can be imagined:
research the topic and suggest ideas." Written 2026-10-13 07:10 UTC against
`syrius-sol` at `70040a24` plus the uncommitted tree. `ext:` is
`C:\dev\zenon\syrius-extension\` at `863f6bf`. Ideas that are straight ports
from the extension are described in `extension-parity.md` and only ranked
here, by its row number.

## Recommendation

Do the first eight. Each is small, each removes a mistake or a wasted step a
real user meets, and two of them (1 and 2) stop the wallet destroying the
user's own data.

| Rank | Idea | Size |
|---|---|---|
| 1 | Wrong passwords no longer delete the wallet file | S |
| 2 | "Delete cache" no longer deletes labels and addresses | S |
| 3 | Settings apply when chosen | S |
| 4 | Send warns about a look-alike or first-time recipient | S |
| 5 | Notifications say what moved | S |
| 6 | Keyboard shortcuts | S |
| 7 | "Node not synced" said before the form, not after | S |
| 8 | Explorer links that follow the chain | S |

## The list

### 1. Wrong passwords no longer delete the wallet file

**Problem.** Three wrong passwords (the default) send the app through the
reset path, which deletes the encrypted wallet file
(`lib/utils/constants.dart:167`, `lib/widgets/tab_children_widgets/lock_tab_child.dart:150-161`,
`lib/screens/splash_screen.dart:139-147`). A tired user with Caps Lock on and
no written phrase loses the wallet. It does not stop a thief, who copies the
file and guesses offline. The harness README warns its own users about it
(`harness/README.md`, Limits).

**Change.** Default the limit to off. When on, say "Remove this wallet from
this computer" and make it delete only after confirming the person has the
phrase or a backup file. Needs the owner (question 1).
**Where.** `lock_tab_child.dart`, `security.dart` (auto-erase slider,
`lib/widgets/modular_widgets/settings_widgets/security.dart:148-165`).
**Size.** S.

### 2. "Delete cache" keeps what the person made

**Problem.** "Delete cache" deletes every box in `kCacheBoxesToBeDeleted`
(`lib/utils/constants.dart:45-54`, `splash_screen.dart:118-125`), which
includes the address labels, the list of added addresses and the recipient box
an address book would use. A cache is what can be fetched again; labels
cannot.
**Change.** Split the list: node data and notifications are cache; labels,
addresses, favourite tokens and contacts are not.
**Where.** `constants.dart:45-54`, `wallet_options.dart:96-110` (the button's
text).
**Size.** S.

### 3. Settings apply when chosen

Extension parity row 3. Theme, text scale, auto-lock and auto-erase each need
a second "Confirm" press (`display.dart:172,220`, `security.dart:169`).
**Size.** S.

### 4. Send warns about a look-alike or first-time recipient

**Problem.** Address poisoning: an attacker sends a dust amount from an
address whose first and last characters match one the victim uses, hoping it
is copied from history next time. A `z1` address is 40 characters and people
check the ends.
**Prior art.** MetaMask compares the destination with past counterparties and
blocks with a warning when the first four and last four characters match but
the middle differs; it also warns on a first-time recipient
([MetaMask support](https://support.metamask.io/stay-safe/protect-yourself/wallet-and-hardware/address-poisoning-scams)).
**Change.** On Send, before the confirm dialog: compare the recipient with the
address book and the last few hundred counterparties of this address; a
look-alike is a blocking warning that shows both addresses with the differing
middle highlighted; a first-time recipient is one line in the confirm dialog.
**Where.** `lib/rearchitecture/features/send/widgets/send_populated.dart`
(confirm at about line 203); counterparties from `LatestTransactionsBloc`, or
the unused `recipient_address_box` (`constants.dart:38`).
**Size.** S.

### 5. Notifications say what moved

Extension parity row 4. "Transaction received on Address 1" with a hash
becomes "Received 1.5 ZNN from z1qq…0mq"; "Account-block published, type
userSend" becomes "Sent 1.5 ZNN to …" or "Delegated to pillar X"
(`lib/blocs/auto_receive_tx_worker.dart:161-172`,
`lib/utils/account_block_utils.dart:57-67`). The desktop notification setting
(`kEnableDesktopNotificationsKey`, `constants.dart:174`) then becomes worth
turning on. **Size.** S.

### 6. Keyboard shortcuts

**Problem.** A desktop wallet driven only by the mouse. `docs/flutter-dev-practices.md`
section 4 plans shortcuts and records none in place.
**Change.** Ctrl+L lock; Ctrl+1 to Ctrl+9 the rail's pages in order; Ctrl+K a
"go to" box over page names and the address book; Esc closes a dialog
(Material does); Enter submits a focused form. Off while a text field has
focus, as the practices document requires.
**Where.** The shell, `lib/widgets/main_app_container.dart`, with `Shortcuts`
and `Actions` round the page area.
**Size.** S.

### 7. "Node not synced" said before the form, not after

**Problem.** Every action fills its form, presses Send, and only then learns
the node is behind: `createAccountBlock` throws `NodeNotSyncedException` when
the node is more than 20 momentums behind (`lib/utils/account_block_utils.dart:19-24,82`).
The only warning is a notification asking the user to "wait until the loading
circle turns green" (`lib/utils/notification_utils.dart:25-40`), sent once,
30 s after each connection (`lib/utils/node_utils.dart:110-111`).
**Change.** The node sync cubit (`lib/rearchitecture/features/node_sync_status/`)
already knows; primary buttons read it and are disabled with the reason as
their tooltip, and the status strip says "Syncing, 1,204 behind".
**Size.** S.

### 8. Explorer links that follow the chain

Extension parity row 6. Today two links, both to the mainnet explorer on any
chain (`general.dart:146`, `account_chain_stats.dart:72`), and none on
transaction rows. **Size.** S.

### 9. Address book with recent recipients

Extension parity row 2. **Size.** S.

### 10. Blocks followed to their momentum; no fixed 31 second waits

Extension parity row 8. Ten features wait `kDelayAfterAccountBlockCreationCall`
(`constants.dart:198-200`) before refreshing. **Size.** M.

### 11. History rows that name what a block did

Extension parity row 5. **Size.** M.

### 12. A stopped chain called stalled

Extension parity row 14. **Size.** S.

### 13. Hide balances, for screen sharing

Extension parity row 7. **Size.** S.

### 14. Proof of work: elapsed time and a typical duration

Extension parity row 12. **Size.** S.

### 15. Loading, empty and broken look different

**Problem.** Every card shows the same spinner while loading
(`SyriusLoadingWidget`) and a raw exception string when it fails
(`SyriusErrorWidget(snapshot.error.toString())`, for example
`lib/widgets/tab_children_widgets/accelerator_tab_child.dart:25`). A node that
is down looks like a slow node.
**Change.** Skeleton rows after a short delay (the extension waits 3 s,
`ext:src/services/hooks/useDelayedFlag.js:13`), "None yet" for empty (already
done on restyled cards, `HANDOFF.md` State), one sentence and Retry for a
failure, with the detail in the log.
**Size.** S per card; M across the app.

### 16. One function signs messages

Extension parity, "Partly there". Settings signs UTF-16 code units narrowed
to bytes with no length rule (`security.dart:314`); the web channel signs UTF-8
and refuses exactly 32 bytes, the size of a block hash
(`lib/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart:196-201`).
Use the channel's function in both. **Size.** S.

### 17. Delegate: sorting on, then APR

Extension parity row 15. The sort code is written and switched off
(`lib/rearchitecture/features/pillars/view/pillars_card.dart:287`). **Size.** S, then M.

### 18. Export history and labels

**Problem.** No way to take records out of the wallet: for taxes, for an
accountant, or to move labels to a new computer.
**Prior art.** Ledger Live exports an account's operation history as CSV
(described by tax tools that import it, for example
[CoinTracking](https://cointracking.info/import/ledger_live); not an official
Ledger page). For labels, BIP 329 proposes one JSON Lines format because
wallets each invented their own ([BIP 329](https://bitcoin.org/bip/329/)).
**Change.** History to CSV: date, momentum height, hash, type, counterparty,
token, amount, label. Labels to and from a JSON Lines file of
`{"type":"addr","ref":"z1…","label":"…"}`, BIP 329's shape.
**Where.** A menu on the transactions card; `address_labels_box`.
**Size.** M.

### 19. Unlock with Windows Hello or Touch ID

**Problem.** With a 15 minute auto-lock (`constants.dart:168`) a long password
is typed many times a day, which pushes people to short passwords.
**Prior art.** The extension's phone app keeps the password in the Android
Keystore or iOS Keychain behind the fingerprint (`ext:CHANGELOG.md` 0.3.6;
`ext:src/pages/settings/biometric/biometric.js`).
**Cost.** The password must then live in the OS keychain, and it needs two
new packages (`local_auth`, a secure-storage plugin): a supply-chain decision
for a wallet (`docs/flutter-dev-practices.md` section 8). Owner's call
(question 2).
**Size.** M to L.

### 20. Several wallets, user modes, Zap, update notice

Wishlist items 6, 10, 8 and 4, each with its own document:
`wallet-selection-and-modes.md`, `zap.md`, `update-detection.md`.

## Not proposed, and why

| Idea | Why not |
|---|---|
| Fiat values by default | A request to a third party from a wallet. Listed as parity row 22 with an owner question |
| Close to tray instead of quitting | The window's close handler exits by design after saving its size (`lib/main.dart:459-492`); keeping a wallet alive unseen is a security choice for the owner, not a convenience |
| A transaction journal now | Parity row 23: large, and a desktop process rarely dies mid-publish |

## Questions for the owner

1. Auto-erase (idea 1): off by default, or removed?
2. Windows Hello and Touch ID (idea 19): wanted, given two new dependencies
   and a password kept by the OS?
3. Keyboard shortcuts (idea 6): any you want beyond these?
