# Source743: observe pixel-ratio changes through MediaQuery

Source742's full Linux run passes every analysis and early Ready/Lock/Token
gate, then reports 5,079 tests passed, one failed and one skipped. The new
pixel-ratio phase of the existing theme-change case expects two field images
and observes the original single 2,152 by 1,452 image. Generation is skipped;
the original failure and zero artifacts remain preserved.

## Correction

The field now reads `MediaQuery.devicePixelRatioOf(context)`. Flutter's
[View.of contract](https://api.flutter.dev/flutter/widgets/View/of.html)
subscribes to view identity; mutable view properties do not notify that
dependency. The [MediaQuery accessor](https://api.flutter.dev/flutter/widgets/MediaQuery/devicePixelRatioOf.html)
subscribes specifically to changes in the inherited pixel ratio. This lets a
ratio change invalidate the existing body/caption cache key while their
logical dimensions remain the same.

The test helper had also supplied a fixed local `MediaQueryData` with its
default ratio of one. Its new optional ratio defaults to one for existing
callers, and the existing ratio-two phase now supplies two to both the view
and that local media query. The expected second image, retirement of the
first, doubled raster dimensions, reuse across the next clock sample and
final disposal checks remain. That phase additionally checks the independent
background and light-color envelopes. No test is removed or registered.

The raster limit, fallback, lifetime, original drift/blur/clip/clock and
caption/ownership controls are unchanged. Lock wording and all expected
localization artifacts retain their Source742 bytes. The backend, workflows,
test counts, command caps and comparison criteria are unchanged.

## Evidence and limits

[Source742 full Linux 43521322983](https://github.com/edgepillar/syrius/actions/runs/43521322983)
and job 132216029875 retain the actual failure at
`test/shaders/entry_field_test.dart:381`. The failed run is not retried.
Complete bounded log ranges retain the assertion and final test totals;
they are not represented as a complete copy of the job log.

Source743 changes one application line, the existing test fixture/case and
three documentation files. Whitespace, exact file boundaries and public-text
privacy controls pass locally. No SDK or native app is run locally. Fresh
full Linux must pass the complete directory and actual generated-file check
before fresh Windows images or timing are qualified.

Source741's two Windows failures, their independent readers and Source738's
failed paired timing keep their original sources. No capture, closure,
visual-match or performance result is promoted by this correction. Accepted
scope stays 76/80 and matches 2/94, both Ready at Source730. V01, V02, V05 and
V06 remain open; F06 retains Source722 and the original Docker/WSL route
remains unqualified.
