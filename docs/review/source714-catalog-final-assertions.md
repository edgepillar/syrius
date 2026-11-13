# Final assertions after the toast wait

Staking and Token catalog scripts now wait for the original EventToast before
their final assertion. The last command again proves the intended screen state,
so the existing screenshot guard and Token after-capture cleanup remain valid.
The ten-second wait, original assertions and strict preflight are unchanged.

The [Source713 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43336377747)
passes application and patched-package analysis, then fails two existing cases
in `test/harness/screen_capture_test.dart`: authored scripts must end in an
assertion, and after-capture commands require that completed assertion.
Generation is not reached. No Source713 native experiment is dispatched.
The failed attempt remains recorded and is not retried.

This correction moves two existing lines; it does not relax a guard or change
test expectations. Source inspection confirms both recipes finish in their
original assertion and keep the toast wait before it. Actual Dart execution
and hosted qualification require the new revision's checks.

The [Source713 changes](source713-theme-token-and-launch.md), earlier Ready
failures and four reviewed Staking/Token mismatches keep their separate scopes.
Original acceptance remains 73/80, with no new accepted visual match.
