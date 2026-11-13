# Ready outer shadow and complete focused coverage

Updated 2026-11-13.

## Preserved Source728 results

The [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43412563461)
passes controller tests, both analysis steps, the early Ready ownership and
restoration gate, the complete non-chain directory and tracked generation.
The earlier Ready driver failures are resolved at this source. Global case and
info totals are not projected from the workflow status.

The separate [Ready](https://github.com/edgepillar/syrius/actions/runs/43414396454)
and [Staking/Token](https://github.com/edgepillar/syrius/actions/runs/43414629882)
Windows jobs each stop at strict analysis with zero errors, zero warnings and
two LINES_LONGER_THAN_80_CHARS infos in app_lottie.dart, lines 271 and 289.
Their complete 330-byte analysis outputs have the same recorded digest.
Wallet compilation, lab startup and native capture are not reached. Both runs
retain zero artifacts, so no archive reader is started. The original failed
runs are preserved and are not retried.

Source729 wraps only those two original expressions; their non-whitespace
tokens, sample positions and observation values remain unchanged.

## Ready shadow

The [CSS outer-shadow definition](https://www.w3.org/TR/css-backgrounds-3/#shadow-shape)
excludes the original border-box interior. Flutter's
[pinned BoxDecoration painter](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/painting/box_decoration.dart)
draws filled shadow shapes before the background and child. Ready previously
placed that decoration behind its translucent backdrop-filter surface.
This provides a source-level contributor to the observed light glass mismatch;
it does not establish the full cause of the earlier image differences.

Ready now paints its original shadow after the glass and clips out the original
rounded border box. The surface cannot sample its own shadow. Shadow color,
offset, spread, sigma, border radius, glass tint and blur retain their tokens.
The original card layout, one-pixel border inset, map, field, localized text,
binding and once-only callbacks retain their implementation. Other surfaces
are unchanged by this narrow fix.

One new engine regression reads the production foreground painter in both
themes. Actual raster pixels must leave the card interior unchanged while
darkening a point outside it. Removing the shadow entirely cannot satisfy that
check. It does not replace native window capture or whole-image comparison.

## Selection and early feedback

All eighteen existing Ready surface/quarantine cases now join the focused
selection. Their earlier full-directory passes remain bound to their original
source. With the new paint case, the selected registry becomes 1,505 Dart cases
in 112 files, two 56-file serial groups. The original 240-second child and
480-second total limits remain. Python registration stays 1,220; independent
Ready reader registration stays 123.

The Ready surface, binding and both existing suites join strict analysis with
fixed diagnostic labels. The privacy projection accepts only their known
basenames. The early Linux gate now runs all three Ready-related files before
the complete directory, covering 22 registered cases.

All 46 focused memory controls pass locally without SDK, native execution,
network or fixture creation. They verify selection, exact grouping, fixed
failure locations and observe vocabulary. The new Dart raster assertion remains
unexecuted locally; its final comparison uses actual 8-bit pixel values.

Fresh full Linux execution, Windows Ready and Staking/Token runs, independent
archive verification and individual image review are required for this source.
Original progress remains 74/80 with P03, P09, V01, V02, V05 and V06 open.
F06 retains its Source722 audit. Zero whole-image matches are accepted.
