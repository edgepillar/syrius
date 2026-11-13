# Restore the Ready paint test scope before framework checks

Updated 2026-11-13.

The [Source729 Linux run](https://github.com/edgepillar/syrius/actions/runs/43417855980)
passes controller tests and both analysis steps. Its early Ready gate records
21 passes and one failure. The framework detects a changed painting debug
variable after the test body returns. Full-directory execution and generation
are skipped, zero artifacts remain and no Windows job is dispatched.

The raster case temporarily enables real shadows. Its original addTearDown
restoration runs after the framework's painting invariant check. Source730
restores the exact original flag in finally before the test body returns,
including exceptional exits. The framework check stays enabled.

All interior/exterior pixel comparisons, both themes, actual production painter,
case registrations and cleanup of the owning widget remain. No application,
asset, dependency, workflow, controller or Python test source changes. The
Source729 rendering implementation retains its source bounds; this change does
not qualify native images or reinterpret the original failed case as a pass.

The earlier 46 focused memory controls retain their Source729 result. Their
unchanged Python and vocabulary inputs are checked without repeating them.
No local SDK or engine execution occurs. The selected totals remain 1,505
Dart cases in 112 files, 1,220 controller cases and 123 Ready reader cases.

Fresh full Linux execution, including all 22 early Ready cases, the complete
non-chain directory and generation, is required. Windows Ready and Staking/Token
execution, independent archive verification and individual image review follow
that result. All original failures remain preserved and are not retried.
Original acceptance stays 74/80 with P03, P09, V01, V02, V05 and V06 open,
F06 bound to Source722 and zero accepted whole-image matches.
