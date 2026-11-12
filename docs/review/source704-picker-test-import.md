# Picker preview test import and retained native results

The [Source703 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43286127964)
stops at analysis with `undefined_class` in
`test/lock/wallet_picker_test.dart:68:3`. The new preview host uses
`ValueListenable`; its explicit `flutter/foundation.dart` import was missing.
This follow-up adds that import. The failed workflow did not run the full
non-chain unit/widget step. Its original failure remains recorded.

Only the test import and documentation change. Production application,
harness and CI-controller code remain byte-identical to Source703. Existing
registered case counts are unchanged. Fresh full Linux qualification is
pending.

## Separate Windows scopes

The [Source703 Ready producer](https://github.com/edgepillar/syrius/actions/runs/43286604695)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43291737582)
verify both genuine Ready PNGs and normal required actor and five-node closure.
Selected checks pass 1,480 Dart cases, 1,214 Python cases with eighteen platform
skips and analysis with zero findings. The reader passes 123 actual cases.
The separately terminated MSVC telemetry helper remains recorded. These are
catalog-capture results at Source703, with no atomic-frame or whole-image
acceptance. Local visual review awaits the owner's scoped archive authority.
The earlier Source701 Ready failure retains its unestablished inner cause.

The [Source703 Lock producer](https://github.com/edgepillar/syrius/actions/runs/43286179442)
fails before its first PNG. Its dark capture attempt stops in `normal` with
`COMMAND_FAILED`; the outer record reports `STARTUP_OBSERVATION_REFUSED`.
Both recorded actors exit normally with complete output. The
[independent reader](https://github.com/edgepillar/syrius/actions/runs/43292445165)
confirms the original failed receipt and zero PNGs. The inner command
cause remains `NOT_ESTABLISHED`. The incomplete source-stability check does
not establish a source change. No native retry or successful Lock recapture
is claimed.

The broader original acceptance remains 73/80, with P03, P09, F06, V01, V02,
V05 and V06 open and zero accepted whole-image matches.

## Full Linux result

The [Source704 workflow](https://github.com/edgepillar/syrius/actions/runs/43293669273)
passes application and patched-package analysis. The complete non-chain test
directory runs, with four failed menu cases: dark/light and LTR/RTL all retain
the old 13 px name expectation at `test/lock/wallet_picker_test.dart:350`,
while the Source703 menu intentionally uses 13.5 px. The generation step is
not reached. [Source705](source705-lock-command-diagnostics.md) corrects that
stale expectation without changing application typography or adding cases.
The original Source703 analysis failure and this separate Source704 test
failure remain preserved.
