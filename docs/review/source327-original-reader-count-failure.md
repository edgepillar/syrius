# Source327 original reader-count failure

Source `e5355f5072205ea4164562304abd199c62ee3709`, tree `bf840c03bc3bb42b8a8391350ca43e0c17a37a29`, has one original attempt-one [focused run, 41457387394](https://github.com/edgepillar/syrius/actions/runs/41457387394), job `125317431131`. It completes with failure before SDK setup. The isolated controller result reports 940 tests, three existing skips, one failure, zero errors and no native wallet or node execution. The failed case is `ReaderControlTests.test_exact_suites_do_not_depend_on_an_external_regular_test_package`.

The original admission step passes. Asset observations, Flutter SDK setup, selected analysis and Dart ownership/recipe tests are skipped. Full Windows, native catalogs and artifact readers are not dispatched, and the original run has zero artifacts. The failed run is not retried.

The new shared Settings diagnostic test adds one reader registration. The reader roster therefore contains 105 cases while its gate and discovery fixture still require 104. The same three reader-discovery controls were selected locally under the memory-only guards: two pass and one reproduces exactly `105 != 104`, with actual controller exit one and no blocked native, network or write attempt. This local counterexample supplements the original hosted failed-case evidence; it does not turn that hosted failure into success.

Source327's UI changes and real-view regression remain uncompiled and unqualified. Source326 remains the preceding independently qualified Windows/catalog scope; its original Settings failure and native licence-footer clipping remain open. Acceptance stays 72/80 rows, 36 distinct literal outputs, 58 missing and zero matches. Earlier FAILURE, HOLD and UNKNOWN evidence remains preserved.
