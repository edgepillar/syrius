# Seeded Swap list capture

The new `swap-seeded` catalog selection prepares the missing post-seed
Swap list view for F06. It runs only in the owned fork's explicit Windows
wallet-tour lane. Ordinary builds and default catalog selections are unchanged.

The original six-recipe workflow must finish Stake, Fuse, Token, Deposit,
Project and Fund Address with distinct confirmed receipts and matching original
journals. The Deposit already persists its real one-sided HTLC history entry.
No missing two-sided coordinator, synthetic swap or additional financial action
is introduced.

The existing Swap script is reused. Its final assertion is bound to the copy
control inside the exact original Deposit row. Before either theme's frame
readback, the driver waits for that row, opens it only if its disclosure is
absent, then requires its original copy control. An open disclosure stays open
for the second theme. The copy control is observed, never invoked.

The original owner is checked before and after every request. Missing rows,
covered targets, unknown or malformed replies and owner changes stop capture.
Only the two literal `26-swap-list` PNGs and their manifest are uploaded.
Schema 15 binds them to all six seed receipts and the original required actor
and node closure; the existing independent reader verifies the same source,
archive digest, exact members and seed-receipt digest.

Forty-eight local memory controls pass, including catalog/member/receipt
validation and existing controller admission. Four new Dart regressions cover
two-theme disclosure retention, an original pending read across owner loss,
invalid replies and an invalid receipt before observation. The selected Dart
expectation is 1,480; Python controller and reader registrations remain 1,214
and 123 because their existing case matrices gained the new family.

The [Windows producer](https://github.com/edgepillar/syrius/actions/runs/43231376077)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43235264703)
now succeed at `93824f35f2c2253f1362eceaa5c3d749b2a12a50`, attempt one.
All 1,480 selected Dart cases pass without failures or skips. The 1,214 Python
cases complete with eighteen platform skips, and selected analysis has zero
errors, warnings or infos.

The reader verifies both schema-15 Swap PNGs, the exact six-receipt digest,
the original wallet tour and normal original/copied actors and five-node
closure. Its memory-test step succeeds; an exact executed reader count is
not projected by the retained annotations. The registered reader expectation
remains 123.

This closes the missing real Deposit-row capture. The complete F06 state audit,
including the permitted aged-fuse fixture witness, remains open. No whole-image
match or timing comparison is accepted. Original progress remains 73/80, and
earlier failures retain their own sources and outcomes.
