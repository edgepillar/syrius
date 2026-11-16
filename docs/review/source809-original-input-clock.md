# Bind input-frame samples to the original wait

[Source808 full Linux](https://github.com/edgepillar/syrius/actions/runs/43820841702)
passes eleven required stages, including application and strict analysis and
the Ready, Lock and compact gates. The complete test directory reports 5094
passes, one failure and one skip. The final generation step is skipped.

The new typing matrix fails at its expected-null sample immediately before
the intended timeout boundary: the operation has already returned the fixed
wallet-recipe-control-refused result. The original complete 1413578-byte log
is retained in one verified CAS object. Its bounded reader exits zero with
complete output and closes its owned storage task successfully. The CI job
is not retried. All owned outputs are consumed before this correction.

## Original clock origin

The matrix advances a small polling turn to notice that the original frame
wait has started. That turn can already advance the fake clock. Advancing a
further 999 ms from the later observation does not establish that the sample
is still one millisecond before the original one-second deadline.

The injected original wait now records the binding's clock when it is offered.
Each timeout sample subtracts the elapsed time from that same origin, requires
a positive remaining interval, checks the original pending result one
millisecond before the deadline and explicitly checks refusal at the deadline.
The delayed-completion, original text-update, error, privacy and late-result
assertions remain. No assertion or test registration is removed.

Production code is byte-identical to Source808. Its original-frame requirement,
one-second admission, original input/click/owner checks, outer budgets and
performance predicates remain. The P06 overlay, original widgets, CLI,
collector, workflows, selected suites and exact-count guard are unchanged.
The selected Dart total stays 1508; Python stays 1227 with eighteen Windows
skips, all 112 suites and all 289 strict paths remain.

Forty-three Python memory controls pass with zero failures, errors or skips.
Fresh hosted Dart and full Linux execution remain required before the next
original native run. No SDK runs or downloads locally.

The latest successful full Linux remains Source807. Its earlier disabled
import_continue native refusal and the previous missing nav_settings and close
failures retain their original source bounds. No P06 root cause, native input
fix, paired performance, financial effect or visual match is established here.

Acceptance stays 76/80 and Source730 Ready matches stay 2/94.
V01/V02/V05/V06 remain open.
