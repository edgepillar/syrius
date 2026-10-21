# Extension parity: what the Syrius extension has that desktop lacks

Wishlist item 1. Written 2026-10-13 06:30 UTC against `syrius-extension` at
`863f6bf` (version 0.3.6) and `syrius-sol` at `70040a24` plus the uncommitted
tree. Six agents were editing `lib/` while this was written, so a desktop line
number may have moved by a few lines; the symbol named beside it has not.

The page-facing provider (`window.zenon`, connected sites, approvals) is left
out: it is item 9 and has its own document, `webapp-to-syrius.md`.

## Recommendation

Port in this order. The first six are small, each removes something a user
meets every day, and none needs a new dependency.

1. Update notice (table row 1, design in `update-detection.md`).
2. Address book and recent recipients on Send (row 2).
3. Settings that apply when chosen, no Confirm button (row 3).
4. Notifications and history that say what happened (rows 4 and 5).
5. Explorer choice, links that follow the chain (row 6).
6. Hide balances (row 7).

Then the three medium ones that change how the wallet feels: a block followed
to its momentum instead of a 31 second wait (row 8), operator modes (row 9,
design in `wallet-selection-and-modes.md`), and Zap (row 10, design in
`zap.md`). The wallet picker (row 11) is item 6 and is in the same document as
modes.

Leave the transaction journal, vanity token ids and Sporks for last: each is
large or serves few people.

## Conventions

- `ext:` is `C:\dev\zenon\syrius-extension\`. Other paths are in `syrius-sol`.
- Size: **S** is one feature folder and under a day, **M** touches the shell or
  several features, **L** needs a new subsystem or a protocol-level check.
- "Changelog" is `ext:CHANGELOG.md`.

## Missing on desktop, by value over cost

| # | Feature | In the extension | Desktop today | Port |
|---|---|---|---|---|
| 1 | A line on the lock screen and an About row when a newer release is out | `ext:src/services/utils/release.js:15-81` (ask, cache 6 h, compare); shown at `ext:src/pages/dashboard/dashboard-password/dashboard-password.js:180`; About at `ext:src/pages/settings/about/about.js` | A button that opens the releases page, no check: `lib/widgets/modular_widgets/help_widgets/update_card.dart:30-37` | **S.** One cubit, one line in the status strip. Upstream tags end in `-alphanet`, which the extension's parser would reject (`release.js:27-30`), so the parser is not copied as is. |
| 2 | Address book, offered on Send with the last five recipients | `ext:src/pages/settings/contacts/contacts.js`; store at `ext:src/services/utils/storage.js:163-200` (200 contacts, 5 recent); picker at `ext:src/pages/send-receive/send/send.js:152-153` | None. The box for it is opened and never read: `kRecipientAddressBox`, `lib/utils/constants.dart:38`, `lib/utils/init_utils.dart:100-101` | **S.** A `contacts` feature over the existing box and a picker beside the recipient field (`lib/rearchitecture/features/send/widgets/send_populated.dart:132-137`). Careful: that box is in `kCacheBoxesToBeDeleted` (`constants.dart:45-54`), so "Delete cache" would erase the address book. Move it out of that list. |
| 3 | A setting applies when it is chosen | Segmented rows, saved on click: `ext:src/pages/settings/settings/settings.js:98-107,130-151,214-219` | Theme, text scale, auto-lock and auto-erase each need a second Confirm press: `lib/widgets/modular_widgets/settings_widgets/display.dart:172,220`, `security.dart:169` (the handoff's Traps list records an agent caught by this) | **S.** Call the existing confirm handlers from `onChanged`. The settings pages agent owns these files this round. |
| 4 | Notifications say what moved | Incoming: "Incoming 1.5 ZNN", "From z1…" (`ext:src/components/app-watch/app-watch.js:65-66`); every error has a number and one sentence (`ext:src/services/utils/errorCatalog.js`, `errors.js:22-24`) | "Transaction received on <label>" with a hash and no amount: `lib/blocs/auto_receive_tx_worker.dart:161-172`. "Account-block published, type userSend": `lib/utils/account_block_utils.dart:57-67`. Errors print the raw exception: `lib/utils/notification_utils.dart:9-19` | **S** for the two messages (the send block is already fetched at `auto_receive_tx_worker.dart:72-73`, and holds amount, token and sender). **M** for an error catalogue, because the call sites are many. |
| 5 | History rows name what the block did: Fused, Unfused, Staked, Delegated, Swap created, "From Plasma"; no "Sent 0" beside a contract call | Selector table `ext:src/services/utils/contractCalls.js`, names `ext:src/services/utils/contracts.js`, applied at `ext:src/services/hooks/useTransactions.js:122-131`; `npm test` re-derives it from go-zenon's definitions | Sender, receiver, hash, amount, date, a send or receive icon, asset: `_getCellsForTransferWidget` in `lib/rearchitecture/features/latest_transactions/view/latest_transactions_card.dart`. A delegation shows as a send of 0 ZNN to a 40 character contract address | **M.** The decoder exists (`AccountBlockUtils.getDecodedBlockData`, `lib/utils/account_block_utils.dart:86-108`) and the SDK ships the ABIs (`znn_sdk_dart/lib/src/embedded/definitions.dart`). Needed: a method-to-label map, a contract-name map, one new table cell, a bloc test per label. |
| 6 | Explorer links follow the chain, and the explorer is a setting | `ext:src/services/utils/explorer.js:6-12`, `ext:src/components/explorer-link/explorer-link.js`, setting at `settings.js:125-136` | Two links, both hard-coded to `explorer.zenon.network` on any chain: `lib/widgets/modular_widgets/settings_widgets/general.dart:146`, `account_chain_stats.dart:72`. Transaction rows have no link at all (`lib/rearchitecture/utils/widgets/infinite_scroll_table/cells/hash_cell.dart`) | **S.** One `explorerUrl(kind, id)` function, a setting, a link icon in `HashCell` and `AddressCell`. No link off chain 1. |
| 7 | Hide balances (the eye on Home) | `ext:src/pages/dashboard/dashboard/dashboard.js:70,288-289` | None (`lib/rearchitecture/features/home/view/home_view.dart`) | **S.** A flag in shared prefs read by `AmountText` (`lib/rearchitecture/features/home/widgets/amount_text.dart`); tables use `AmountCell`. |
| 8 | A sent block is followed to its momentum from the page that sent it; in-flight blocks sit in one strip; a failed one stays with its reason | `ext:src/components/outgoing-watch/outgoing-watch.js`, `ext:src/services/wallet/outgoingWatch.js`, Changelog 0.3.5 "Changed" and 0.3.6 "Changed" | A fixed 31 s wait after a block before the page refreshes, in ten places: `kDelayAfterAccountBlockCreationCall`, `lib/utils/constants.dart:198-200`, for example `lib/rearchitecture/features/delegation/bloc/delegation_bloc.dart:22`. On the lab, where a momentum takes about 15 s and a contract call two momentums, 31 s is sometimes too short and usually too long | **M.** One app-wide cubit fed by `createAccountBlock`, listening to the account-block subscription the wallet already holds (`lib/utils/node_utils.dart:204-207`); the status strip shows it (`_buildStatusStrip`, `lib/widgets/main_app_container.dart:404`). Each of the ten features then refreshes on its event instead of a timer. |
| 9 | Operator modes: Pillar, Sentinel, Sporks, switched in Settings | `ext:src/services/utils/menu.js:28-47`, `settings.js:160-183`, defaults `ext:src/services/utils/storage.js:219-222` | Every page is on the rail for every address: `_buildRail`, `lib/widgets/main_app_container.dart:254-338` | **M.** See `wallet-selection-and-modes.md`. |
| 10 | Zap | `ext:src/services/zap/zap.js`, `ext:src/pages/settings/zap/zap.js`, `ext:src/components/modals/zap-modal.js` | None | **M.** See `zap.md`. |
| 11 | Several wallets, chosen at unlock; "Add wallet" in the menu | Picker `dashboard-password.js:116-138,207-220`; last wallet remembered `storage.js:77-81`; Add wallet `ext:src/components/burger-popover/burger-popover.js:69` | One wallet path, slot 0 of a Hive box: `lib/utils/wallet_utils.dart:40-62`. A second wallet is reached only by Reset, which deletes the first's file (`lib/screens/splash_screen.dart:139-147`) | **M.** See `wallet-selection-and-modes.md`. |
| 12 | "Generating plasma" with a countdown (~12s, ~3m) | `ext:src/components/pow-countdown/pow-countdown.js`; rate measured first, `ext:src/services/wallet/powSearch.js:15-21,57` | An icon that animates: `_getGenerationStatus`, `lib/widgets/main_app_container.dart:458` | **S** for elapsed time plus "usually about N s" from the last few runs kept in shared prefs. A true countdown needs a hash rate, and desktop's proof of work runs inside the SDK's native `libpow_links` (`znn_sdk_dart/lib/src/pow/`), which reports only start and done (`PowStatus`): not verified whether it can report progress. |
| 13 | The password rule is stated when a password is refused | `ext:src/services/wallet/password.js:5` | "Password not strong enough" or "Invalid password", with no rule: `lib/utils/input_validators.dart:140-152` | **S.** One string. Entry screens agent owns the screens. |
| 14 | Node stats call a stopped chain "Stalled" whatever the node says | `ext:src/services/node/stats.js:28,40` (older than 12 momentums) | Height, peers and timestamp are shown (`lib/widgets/modular_widgets/settings_widgets/general.dart:46-152`) and a sync icon; nothing compares the frontier's timestamp with the clock | **S.** A check in the node sync cubit (`lib/rearchitecture/features/node_sync_status/`), a third colour on the strip's icon. A stopped chain accepts blocks into its pool and looks alive (`ext:tools/devnet/lab/README.md`, "Pointing the harness at it"). |
| 15 | Delegate: sort by weight, APR or production; an APR estimate per pillar | `ext:src/services/pillar/sort.js:6-13`, `ext:src/services/pillar/apr.js` | Sort code is written and switched off: `lib/rearchitecture/features/pillars/view/pillars_card.dart:287-330` ("to be used when sorting is enabled"). No APR | **S** to switch sorting on. **M** for APR: port `apr.js` and its checks. |
| 16 | Plasma: select several fuses, cancel together | `ext:src/services/plasma/batchCancel.js:20-26`, sent as one job `ext:src/services/wallet/blockJobs.js:35-38` | One Cancel button per row: `lib/rearchitecture/features/fused_plasma/view/fused_plasma_card.dart:122` | **S to M.** Checkboxes and a loop over `createAccountBlock`; say how many landed if one fails. |
| 17 | New wallet: confirm three words by position, four choices each | `ext:src/services/wallet/phraseQuiz.js:1-8` | Six words placed by hand (`kNumOfSeedWordsToBeFound`, `lib/utils/constants.dart:92`) | **S to M.** Entry screens agent owns the screen. |
| 18 | Lists say "Loading" only after 3 s | `ext:src/services/hooks/useDelayedFlag.js:13` | A spinner at once on every card (`SyriusLoadingWidget`) | **S.** `docs/flutter-dev-practices.md` section 8 already decides on skeleton rows; this is the same change. |
| 19 | Pillar revoke asks for the password, then once more | `ext:src/services/pillar/revokeGuard.js:7-18` | One yes or no dialog: `lib/rearchitecture/features/revoke_pillar/view/revoke_pillar_button.dart:68-76` | **S.** |
| 20 | Accelerator phase: Max fills what the project has left | `ext:src/pages/pillar/az-form.js:30` | Not verified in `lib/widgets/modular_widgets/accelerator_widgets/` | **S.** |
| 21 | Sporks page: every spork and its state; an administrator can create and activate | `ext:src/pages/settings/sporks/sporks.js`, `ext:src/services/spork/spork.js` | None (no match for "spork" under `lib/`). The SDK has the calls: `znn_sdk_dart/lib/src/api/embedded/spork.dart:15-31` | **M.** Read-only first. Activation stopped the public devnet on 2026-10-11 (`ext:tools/devnet/lab/README.md:3-5`); keep the extension's typed-name guard. |
| 22 | Approximate value in dollars, mainnet only | `ext:src/services/utils/tokenPrice.js:10-15` (CoinGecko), `ext:src/services/hooks/usePriceFeed.js:10-12` | None | **S**, but it is a request to a third party from a wallet. The extension lists it in its privacy policy. Owner decides (question 1). |
| 23 | Transaction journal: a block is recorded before it is sent, an interrupted one is looked up and resent as the same bytes, never re-signed | `ext:src/services/wallet/journal.js:45-47`, `ext:src/services/wallet/publisher.js` | Sends from one wallet take turns through a mutex and a one second sleep: `lib/utils/account_block_utils.dart:25-27,69-75`. Nothing is recorded, so a crash between signing and the node's answer leaves the outcome unknown | **L.** Lower value than in the extension, whose popup closes mid-send by design; a desktop process rarely dies there. |
| 24 | Token issue with a chosen id prefix or suffix | `ext:src/services/token/vanity.js:11,57`, `ext:src/services/token/ztsSearch.js` | None (`lib/rearchitecture/features/create_token_stepper/`) | **L.** Worker isolates and a search tied to the account's frontier block. Few users. |

## Partly there

| Feature | Extension | Desktop | Gap |
|---|---|---|---|
| Sign a message from Settings | `ext:src/pages/settings/sign-message/sign-message.js`; UTF-8, and a message of exactly 32 bytes is refused because that is a block hash (`ext:src/services/wallet/signMessage.js:30-65`) | Security, Sign and Verify: `lib/widgets/modular_widgets/settings_widgets/security.dart:102-103,310-325`. It signs `text.codeUnits` with no length rule (`security.dart:314`) | Two encodings in one app: the channel signs UTF-8 and refuses 32 bytes (`lib/rearchitecture/features/dapp_bridge/dapp_bridge.dart:178`, `server/dapp_bridge_service.dart:198`), Settings signs UTF-16 code units narrowed to bytes. Same for ASCII, different otherwise. **S**: use one function for both. |
| Lock after | 5, 15, 60 minutes or On close (`settings.js:26-31`) | A minutes slider plus Confirm (`security.dart:128-190`), default 15 (`constants.dart:168`) | Shape only. See row 3. |
| Token management | Issue, mint, burn, update owner and flags (`ext:src/pages/tokens/token-manage.js`) | Create, mint, burn, transfer ownership (`lib/rearchitecture/features/{create_token_stepper,mint_token,burn_token,transfer_token}`; `updateToken` at `transfer_token/bloc/transfer_token_bloc.dart:34`) | Whether desktop can change the mintable and burnable flags alone: not verified. |
| Remove a wallet | Removes that wallet only (`ext:src/pages/settings/reset-wallet/reset-wallet.js`) | Reset wallet deletes the file and every cache box (`lib/screens/splash_screen.dart:103-147`) | Becomes "remove this wallet" once there is more than one. |

## Desktop already has it

Auto-receive on every address (`lib/blocs/auto_receive_tx_worker.dart`,
`lib/utils/node_utils.dart:172-207`), fuse plasma for another address
(`lib/utils/notifiers/plasma_beneficiary_address_cubit.dart`), address labels
(`lib/widgets/reusable_widgets/settings_address.dart:205`), backup phrase and
keystore backup (`lib/widgets/modular_widgets/settings_widgets/backup.dart`),
change password, node list with a chain identifier and a mismatch warning
(`node_management.dart:358-438`), `syrius://` links
(`lib/widgets/main_app_container.dart:696-1000`), pillar and sentinel
registration, QSR deposit and withdrawal, reward collection, Accelerator-Z,
P2P swaps, hardware wallets. The last three the extension does not have.

## Not ported, because the platform differs

| Extension feature | Why not |
|---|---|
| The popup reopens where it closed (`ext:src/services/utils/popupState.js`) | A desktop window does not close when it loses focus. |
| Background block service in an offscreen page (`ext:src/sections/Receiver/`) | The desktop process is the background. |
| Self-update into the unpacked folder (`ext:src/services/update/chromeUpdate.js`) | Specific to an unpacked Chrome install. What carries over is its rule: verify the published checksum and the version before writing anything (`chromeUpdate.js:18,131-135`). |
| Fingerprint and Face ID, QR scan, Share, FLAG_SECURE (`ext:src/platform/nativeFeatures.js`) | Phone only. Windows Hello is a separate idea, listed in `qol-ideas.md`. |

## Questions for the owner

1. Dollar values (row 22): acceptable for desktop to ask CoinGecko, and if so
   on by default or opt-in?
2. Rows 3, 13, 17 and 19 sit in files other agents own this round. Fold them
   into the reskin, or keep them as a separate pass after it?
