# Go To scale calculation uses the required literal

Updated: 2026-11-05T00:53Z.

Source464 passes all 1,063 Windows controller cases with eighteen expected skips
and fourteen assets. Its selected analysis reports zero errors/warnings and one
PREFER_INT_LITERALS info, at line 385/column 23 in the new scale calculation.
The analysis gate refuses the info; the original run 41943782403 remains failed
and its Dart tests are skipped. The separate Linux source run 41943563062 passes
1,063 controls/two skips, including thirteen Bash/two JavaScript fixtures.

Source465 changes the clamp's literal 0.0 to 0, as requested by the analyzer.
The numeric limit, row/heading growth, keyboard calculations and every other
application byte stay identical. All Source463 Dart test bytes and the Source464
portable fixture are unchanged. No assertion, registration, skip, process bound,
workflow or dependency changes. Existing pure fixture controls are reused on
unchanged bytes; no local SDK or duplicate local suite is run.

Fresh focused analysis and the 1,230 ordinary cases in 48/48-file streams
(597/633) remain pending. The complete Windows controller selection remains
1,063 cases/eighteen explicit skips; the 1,232 asset variant is unselected.
No full wallet/devnet, image or motion/performance work is selected. Both failed
originals remain preserved, all eight original acceptance rows remain open and
full progress remains 72/80. The PR stays Draft.
