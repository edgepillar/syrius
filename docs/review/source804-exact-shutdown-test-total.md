# Exact shutdown test total

Source803 adds two shutdown owner/terminal-record tests inside the existing
wallet recipe suite. The native runner's public expected total was still
1505. This revision updates it to 1507 and retains the exact equality guard.
The earlier count is explicitly refused by the existing admission cases.
No Dart source, test-file selection, process bound or success predicate is
changed. Fourteen existing Python memory controls pass without failures,
errors or skips; no SDK executes locally.

Source803's [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43790202142)
passes all thirteen required stages. Its
[Windows job](https://github.com/edgepillar/syrius/actions/runs/43792120636)
retains two normal, complete 56-suite groups: 693 and 814 passed cases, zero
failures, zero skips, 160 hidden events and 1667 terminal events in total.
The groups have distinct original output digests. Replaying the real grouped
count validator over their retained receipts gives 1507, while the checked-out
public constant is 1505. The final total check therefore refuses the job.

The same job passes 1227 Python cases/eighteen skips and zero selected analysis
findings. Release, lab checkout, node execution and paired observation are
skipped. It retains no artifact; no artifact reader is dispatched without
original manifests. The shutdown observations have not run in the native
wallet, and Source802's close timeout remains unresolved.

The original failed job and all owned outputs are preserved and consumed
before this correction. There is no retry of that job. Fresh hosted and
native qualification remain required. Scope stays 76/80 and Source730 Ready
matches stay 2/94. V01/V02/V05/V06 remain open. No close fix, performance
improvement, financial operation or final acceptance is claimed.
