# Align summary artwork, amount units and dialog sections

Source787 addresses layout findings from Source786's individual original PNG
review. It changes presentation while retaining existing amount precision,
live counts, source/session guards and action callbacks.

The Tokens strip draws the original 52-pixel Lottie composition inside its
reference 38 by 36-pixel flow footprint, with the authored negative margins
and 28-pixel following gap. Ordinary strip leads keep their original defaults.
The text-only minimum permits the compact strip to grow with real paragraph
metrics and text scaling. No composition, pose or animation clock is replaced.

AmountText leaves the separating space in the amount's full-size run and keeps
the smaller unit in the inherited mono font and weight. Exact BigInt splitting
and insignificant-zero removal are unchanged. The Send selector restores its
decorative middle dot and spacing before the chevron; hidden values still use
the existing privacy wrapper.

DialogCard uses separate header, scrollable body and action-footer insets from
the reference. The header has a divider. Footer actions can move to another
line when needed. Its existing exterior-shadow painter runs after the glass,
so the backdrop cannot sample its own shadow. Existing blur, tint, radius
overrides, route ownership and always-running entrance clocks remain.

Send confirmation uses ledger labels and a raised secondary Cancel button.
Full selectable addresses, immutable transfer facts, actual first-send/contact
states, the hardware-only notice and original callbacks remain. Existing
transfer-card radius policy is retained.

Existing amount-direction, Tokens-page, sender-header and real confirmation
cases cover the changed layout. The two confirmation theme cases also require
both actions to remain reachable in a 400 by 400-pixel viewport. No test method,
native selection, workflow or command limit changes.

## Validation boundary

[Source786 Linux 43691421388](https://github.com/edgepillar/syrius/actions/runs/43691421388)
passes all thirteen required steps, including 286-file strict analysis, the
complete non-chain directory and tracked generation.
[Windows 43692591063](https://github.com/edgepillar/syrius/actions/runs/43692591063)
and [reader 43694795977](https://github.com/edgepillar/syrius/actions/runs/43694795977)
verify 1505 Dart passes, 1226 Python cases with eighteen skips, 123 reader
controls, 87 source files and 42 original PNGs. Required actors and five nodes
exit normally; forced auxiliary compiler cleanup leaves full runner lifecycle
unqualified.

All 24 Source786 general originals were individually viewed. The review retains
twelve mismatches, twelve unresolved pairs and zero new matches. Eight original
references were reopened. The archive and prevalidated report are retained,
the owned task closes successfully and disposable scratch is removed. All
outputs are consumed before Source787. Earlier failures remain preserved.

Current-source SDK execution and new image results require fresh hosted
qualification. Memory-only local controls do not establish rendering or native
behavior. Accepted scope stays 76/80 and Source730 Ready pairs stay 2/94.
V01/V06 remain in review; V02/V05 remain blocked. The comparison-page refusal,
unchanged performance requirements and unqualified Docker/WSL route remain.
