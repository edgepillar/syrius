# Declutter: what each page shows at rest

The owner, 2026-10-13: "i want menus to be collapsible and generally
compressed by default / the UI is too cluttered".

This is the audit behind that work (task K0 in `HANDOFF.md`). It was made
from the twelve screenshots of `.harness/default/tour-b13/` (dark, 1266x704,
lab devnet, an address with little on it), not from the code. A page with
more data on it may read differently; where that matters it is said.

## What makes the pages cluttered

Counted across the twelve pages:

| Cause | Where | Count |
|---|---|---|
| A rail of thirteen labelled entries, always 200 px | every page | 1 |
| A card that is empty and still holds its full box | Home 2, Transfer 1, Pillars 2, Sentinels 2, Staking 2, Tokens 1, Connected sites 3 | 13 |
| A form shown at rest that is not the page's one action | Transfer (Receive), Staking (New stake), Connected sites (pairing), Plasma (Fuse) | 4 |
| A refresh icon on a card header | ten of the twelve pages, up to four on one | 24 |
| A table wider than five columns | Transfer Activity 7, Pillars 8, WalletConnect 6 | 3 |
| The same list on two pages | Activity on Home and on Transfer | 1 |
| A second menu beside the rail | Settings | 1 |

P2P Swap, Accelerator and Tokens already have the shape the others should
take: one strip with the headline figures and the page's action, then one
list.

## The rules

1. **A page at rest is a strip and a list.** The strip holds the two or
   three figures that answer "where do I stand" and the page's one main
   action. The list is the thing the page is named for. Everything else
   is one click away.
2. **An empty card is one line.** It keeps its header and "None yet"
   beside it, and takes its box back when it has something to show.
3. **A secondary form opens on demand,** in place under its button, or
   in a dialog when it is a flow of several steps.
4. **Five columns at rest.** The rest of a row opens under it.
5. **A card that follows the chain has no refresh icon.** Where a manual
   refresh is still needed it sits in the card's overflow menu.
6. **The rail is icons** until it is opened.
7. **What a user opened stays open.** Every disclosure stores its state,
   so "collapsed by default" is the first run, not every run.

Rule 7 is what keeps this from hiding things a regular user needs: the
default is compact, and one click makes it theirs.

## Page by page

| Page | At rest | One click away | Dropped |
|---|---|---|---|
| Shell | Icon rail, status strip | Labelled rail | |
| Home | Hero (balance, plasma, Send, Receive, Swap), Activity at full width | To collect and Tokens when empty, as one-line headers | |
| Transfer | One card with a Send and Receive switch, Send shown; To receive when it has rows | Receive (QR, address, amount) | The Activity list: Home has it (owner) |
| Plasma | Glow, level, plasma, fused QSR, Fuse button, Fused list | The per-address levels; the Fuse form; the beneficiary field (it defaults to this address) | |
| Pillars | Strip: to collect with Collect, delegated to, your pillar or Spawn. Then the list: name, weight, delegate %, uptime, Delegate | The reward chart; producer address, momentum %, momentums in the row | |
| Sentinels | Strip: to collect with Collect, your sentinel or Spawn. Then the list | The reward chart | |
| Staking | Strip: to collect with Collect, staked total, Stake button. Then the list | The New stake form; the reward chart | |
| Tokens | As now | Balances when empty | |
| P2P Swap | As now | | |
| Accelerator | As now | | |
| Connected sites | Web apps switch, one list of connected sites, Connect button | WalletConnect sessions and pairings as one closed group; the pairing form as a dialog | |
| Notifications | Nothing: a dot on the bell | A panel from the bell: what needs the user first, runs of the same message folded ("Account-block published" was 6 of the 11 rows on screen) | The page |
| Settings | The section menu and the open section's groups, closed | Each group; Account chain on Addresses | |

The pillar, sentinel and ZTS object animations stay (owner, task 7): they
move into the strip at a smaller size, or stay in the "Your pillar" part
of it.

## Tasks cut from this

One agent each, no two sharing a file. K5 first: the others build on it.

| Task | What | Where |
|---|---|---|
| K1 | The rail collapses to icons and starts collapsed | `lib/widgets/main_app_container.dart` |
| K5 | `Panel` can collapse: the header toggles it, a chevron shows the state, the body animates, the state is stored by a key; `collapsedWhenEmpty` | `lib/rearchitecture/utils/widgets/page/page_widgets.dart` |
| K6 | Transfer: Send and Receive in one card, To receive only with rows, Activity removed | the Transfer page |
| K7 | Home: empty side cards as one line, Activity takes the width | the Home page |
| K8a, K8b, K8c | Pillars, Sentinels, Staking: the strip replaces the top cards | one page each |
| K9 | Pillars list: five columns, the rest in the row | the pillars list |
| K10 | Plasma: per-address levels and the Fuse form closed | the Plasma page |
| K11 | Connected sites: one list, WalletConnect as a closed group, pairing in a dialog | the Connected sites page |
| K12 | Notifications: a panel from the bell, what needs the user first, the rest folded | the shell and a new panel file |
| K14 | The banner: every kind dismisses itself, a bar fills to dismissal | `notification_widget.dart` |
| K2 | Settings: each group a disclosure, closed | `settings_widgets/` |
| K13 | Refresh icons: gone where the card follows the chain, else in an overflow menu | card headers |
| K4 | Density: one compact set of row heights, gaps and paddings in `AppTokens` | `lib/utils/app_theme.dart` |

## Settled by the owner, 2026-10-13 16:05 UTC

- Notifications is a panel that opens from the bell, not a page ("let's
  make it a panel"). Its popups dismiss themselves after a short delay,
  with a bar that shows the time left, as the Syrius extension's do.
- Transfer has no Activity list ("not necessary, keep it in home, so
  this should free up some real estate").

## Open

- Not seen for this audit: any page in light, any page with a full list,
  the five other Settings sections, dialogs and steppers.
