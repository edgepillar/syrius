# Selected Lock symbol ink

Source731's new reference-symbol checks expose the same defect in both themes
and both text directions: the selected wallet's SVG inherits the normal dim
icon color, while its row text and background are selected. The glyph theme
now explicitly binds the same selected foreground or normal dim token as the
owning row. The reference-path, size and color assertions remain unchanged.

The Lock picker file now runs before the full Linux test directory, after the
existing Ready gate. A selected-symbol or seam-refusal failure can stop this
lane early. The complete directory and generated-file checks remain required.
No case registration changes.

## Original Source731 result

The [original Linux run](https://github.com/edgepillar/syrius/actions/runs/43438735767)
at 5f2eb0462f2348c90a7a59ec9f04c44d57e134a1 passes 1,220 Python cases with
seventeen Linux skips, both analysis steps and all 22 early Ready cases.
The complete directory reports 5,076 passes, four failures and one skip.
All four failures are the selected-row color assertion in the existing
dark/light and LTR/RTL measured-menu cases. Generation is skipped and there
are zero artifacts. No native Lock attempt is dispatched for that source.

The complete 1,285,735-byte job log is retained with SHA-256
d3669aabff4d1a93cca528e4496153ca4f8deaf6d9958ad0ea2cffe1163c4613.
The original failure remains failed. Fresh hosted execution is required for
this correction; neither a source edit nor a passing parent qualifies it.

Source730 retains its [two accepted Ready pairs](source731-lock-picker-symbols.md#two-accepted-ready-pairs)
and independently verified Staking/Token archive. Original acceptance stays
74/80, with 2/94 visual matches and P03/P09/V01/V02/V05/V06 open. F06 remains
complete at Source722. Current Lock pixels remain pending. The four Source730
Staking/Token comparisons were subsequently completed with four mismatches;
their exact sources and observations appear in the
[Source733 result record](source733-lock-symbol-literals.md).

## Executed Source732 results

The [full Linux run](https://github.com/edgepillar/syrius/actions/runs/43444391753)
passes, including both early Ready and Lock gates, the complete non-chain
directory and tracked generation. The original
[Windows Lock run](https://github.com/edgepillar/syrius/actions/runs/43447648690)
then stops at two strict-analysis infos before Dart tests or native build.
Zero artifacts remain. Its original failure and the literal-only Source733
correction are recorded in the result record above.
