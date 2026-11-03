# Activity address scope

Source discovery: Source376, `6ca85eeb2512a1e19434de03453ca8056d35693f`.

Home's supplied frames draw an All addresses chip with a scope chevron.
The current `LatestTransactionsBloc` owns one address, one page cursor and one
read epoch. It validates the returned address and chain and revokes a response
after selection or node changes. `LatestTransactionsCard` presents only that
exact owner. Those existing functions remain available.

The other account-history readers serve an Accelerator contract frontier,
statistics or a single account's bounded history. None supplies the wallet-wide
aggregation, independent filter and merged pagination behind this control.
Changing the selected-address label to All addresses would misstate its data.

`Seam.activityAddressScope` therefore holds only the new scope opener. Its
`UnbuiltActivityScopeService.open` throws before reads or selection changes.
The label remains the real presented address; the ordinary history, amounts,
privacy toggle, row explorer and existing wallet address switch remain wired.

Before removing the gate, implement a reader that binds the owned address set,
wallet, node and chain to each request. Filtering must not silently change the
wallet's selected sender. Define merged ordering and pagination, de-duplicate
only within the correct source, and refuse missing or stale scope. Bound
concurrent reads and preserve failures without fabricating totals or rows.
Add genuine reader and UI cases for context changes, pagination, empty/error
states and both themes. Source preparation does not qualify native behavior
or a visual match.
