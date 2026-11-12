# Shared entry field and Ready composition

Lock and Wallet Ready both use the reference `.lockpage` field. Lock previously
used the old card shader; Ready drew its map over a flat window background.
Both now reuse the measured `EntryField` already used by Welcome and Import.
The shared field retains its own route, focus, window and overlay clock holds.

During the original launch transform, Lock keeps the caption's field delegate
inactive. It becomes eligible when the transform settles. The body field and
its original clock stay mounted. The existing caption-owner regression now
checks the held caption, refused sampling and same-clock return.

Ready contains the original map in the available viewport and reuses
`EntryStepPosition` for its completed steps. The localized create, import and
hardware paths retain their ordered labels. The compact copy control preserves
the reference address-line height. Original Lottie assets are unchanged.

## Validation

The preceding [Source700 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43258042063)
passes application and patched-package analysis, the full non-chain test
directory and tracked generated-file checks. The
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/43258106512)
and [reader](https://github.com/edgepillar/syrius/actions/runs/43261487421)
verify six Lock captures and four normal actor exits. Its selected checks pass
1,482 Dart cases, 1,214 Python cases with eighteen platform skips and analysis
with zero findings. Exact global Linux and reader case counts are not projected.

Source701 still needs fresh hosted tests and native recaptures. The existing
caption regression is extended without adding a registered case. Visual
comparison is pending. Original acceptance remains 73/80, with zero accepted
whole-image matches.
