# Go To rows follow text scaling

Updated: 2026-11-05T00:28Z.

The palette previously kept forty-pixel result rows and twenty-eight-pixel
category headings while their text followed the accessibility scale. At doubled
text scale the eleven-pixel heading's 1.45 line-height requires more than the
sixteen pixels left inside its original vertical padding. A fixed body row can
also constrain its doubled fourteen-pixel label. The keyboard scroll target used
the same unscaled constants.

Source463 adds the extra scaled line height to the original row and heading
measurements, keeping their padding. The rendered list, its viewport and keyboard
scroll offsets share those measurements. Dependency changes schedule a fresh
visibility check for the current selection. Normal-scale forty/twenty-eight-pixel
reference dimensions are preserved; smaller text does not shrink them.

The existing geometry regression now measures each actual paragraph's intrinsic
height against its allocated height in both themes and directions at normal and
doubled scale. The existing twenty-four-entry keyboard regression now runs at
both scales, retaining the selected last row inside the viewport, query-reset and
single-match wrap assertions. All thirteen palette registrations remain, so the
ordinary focused selection stays 1,230 cases in 48/48-file streams (597/633); the
asset variant remains 1,232 and is not selected. The complete controller selection
is now 1,063 cases. Its Windows lane expects eighteen explicit skips: fifteen
unselected Linux-only Bash/JavaScript fixtures plus three unavailable AF_UNIX
socketpair cases. The existing source-only Linux fixture result is a separate run.

Only the palette and its existing test file change at runtime. Query matching,
IME handling, entry identity, seam refusal, callbacks and action dispatch retain
their original bodies. Keycaps, symbols, colors, shared tokens, dependencies,
workflow inputs and references are unchanged. The existing nonnative focused
lane will qualify selected analysis and all original cases; its fresh execution
is pending. No local SDK/Dart/Flutter, full Windows wallet, devnet, image transport
or motion/performance acceptance is selected for this correction.

The Source447 focused UI, Source459 actual Linux defaults and Source461 component
success/kernel failure retain their own sources and evidence. All original
FAILURE/HOLD/UNKNOWN outcomes remain. This source correction does not accept any
whole-image pair or close the eight original acceptance rows. Full progress stays
72/80; heavy second-phase qualification remains deferred and the PR stays Draft.
