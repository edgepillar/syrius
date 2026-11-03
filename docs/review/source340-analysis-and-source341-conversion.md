# Source340 analysis refusal and Source341 conversion correction

The original [41551579763](https://github.com/edgepillar/syrius/actions/runs/41551579763)
remains failed on source 6a600894c133f4cd88c37bcd84a84e99805465a9, tree
9e02c56719da23918c4a95c8d85d682ee94a452e. It is not retried or relabelled.
All 940 Python controller cases pass with three existing skips, and fourteen
original asset observations pass. No native wallet or node executes.

Strict selected analysis reports zero errors, zero warnings and one
NOOP_PRIMITIVE_OPERATIONS info at line 211, column 24, in the finite `other`
source category. The analyzer process exits zero; the strict wrapper correctly
rejects the info. The Dart stage is skipped: zero Dart cases execute. Every
other workflow job is skipped and no artifact is produced.

The new Apps height expression at that position converts an already-double
clamped value with `toDouble()`. Source341 removes that redundant conversion.
The double bounds, minimum and maximum, table structure, actions, tests and all
owner guards remain unchanged. This source correspondence is narrower than a
raw diagnostic-path attribution, which the finite projection does not expose.

The existing eleven-case Apps file remains selected alongside all sixty-eight
previous focused files. The expected count stays 848 ordinary or 850 with
asset fidelity. No registration, worker, group, time, output or failure gate is
relaxed. Fresh corrected-source hosted analysis and engine results are pending.
The first delivery stays pinned to 19c7b2af5e1c; full builds, native captures and
extended lab acceptance remain deferred. The original 72/80 rows, nineteen
preparations, 50/94 available outputs, 44 missing and zero matches are unchanged.
