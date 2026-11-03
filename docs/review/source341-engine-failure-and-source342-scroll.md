# Source341 original engine failure and Source342 scroll fixture

The original [41552455171](https://github.com/edgepillar/syrius/actions/runs/41552455171)
remains failed on source 4040428c2000c392baea224fc077102a9ad2b3b0, tree
d3a524e751baa09c3ce8732d87535b219243a048. It is not retried or relabelled.
Selected analysis is clean: zero errors, warnings or infos. All 940 Python
controller cases pass with three existing skips; fourteen original asset
observations, both pre-build refusal controls and all three startup checks pass.

The first 35-file group exits normally with code one after 417 passes, two
failures, zero skips, two error events and 43 hidden cases. Its complete stream
has 462 terminal events. Neither a deadline, output cap nor forced cleanup is
hit. The second group is not executed. All other jobs are skipped, with zero
artifacts, native wallets or nodes.

Both failures point to the new dark/light Apps case at its scroll helper call,
line 173. Their finite framework projection retains a stack-frame context at
flutter_test_async line 74, column 41. It does not expose the inner message or
establish whether that context is the initial cause. The compact populated and
empty height assertions and ordinary heading inset precede the failing call.
They are not removed or weakened.

Source342 changes test choreography only: bounded direct drags of the actual
list scrollable replace the nested scroll-until-visible helper. The original
last disconnect-action availability check remains, with an additional check
that the last action is hit-testable. The fixture still has thirty synthetic
connections and cannot perform a real connection action. All other case
assertions, the application UI and every guard stay unchanged.

The [pinned Flutter controller implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_test/lib/src/controller.dart)
shows that scrollUntilVisible nests dragUntilVisible and test async scopes.
That source review motivates the simpler fixture; it does not establish the
original failure's inner cause. Fresh hosted results are pending. The exact
69-file, 848-case gate, two groups, single worker and all deadlines/caps remain.
No registration or original financial/lab authority changes.

The first delivery stays pinned to 19c7b2af5e1c. Original acceptance remains
72/80, nineteen preparations, 50/94 available outputs, 44 missing and zero
matches. Detailed visuals and extended platform/lab checks stay in phase two.
