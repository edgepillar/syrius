# Full-client notification panel

The general Source765 notification captures begin below the 32-pixel client
caption and use a taller header than the reference. The Bell route now places
its existing panel in the frame's full-client overlay. The original body
Navigator remains below the caption, with its own overlay, route barriers,
View, page state and controllers. The outer overlay is the explicit full-client
destination; ordinary nearest-overlay and Navigator lookups retain their body
owners. Caption tooltips keep their separate nearest overlay.

Startup film and Originals replay now select the original root Navigator's
overlay explicitly. This preserves their previous body bounds after the new
outer overlay is introduced. Existing window tests retain body, caption,
normal-dialog, input interception, theme/provider and state-retention checks;
their root-overlay observations now distinguish the intentional full-client
host from the unchanged body and caption owners.

The panel remains owned by the original FrostedDialogRoute and shell
BellController. An OverlayPortal preserves the route's inherited scope while
painting in the full client. A newer route hides the panel and excludes its
focus without replacing its element; closing that route reveals the original
panel. The original 240 ms opacity/translation also runs on dismissal and
under the OS animation flag. Privacy removes the exact Bell route. Returning
focus requires the original page still to be current.

The header uses 32-pixel Clear/Close controls within its 48-pixel content row
and the original 14-pixel close symbol. Existing history, event grouping,
approval callbacks, five-second toast lifetime and financial owners remain.

Five cases extend the existing Bell test file: both themes and reading
directions cover full 1280 by 780 client bounds, the unchanged 748-pixel body,
caption-area input, canonical close artwork, entry/exit motion, original text
state and focus restoration. A newer-dialog case checks interaction, element
retention, restoration and privacy closure. The Bell implementation and
existing test join strict analysis, taking the selection from 275 to 277.
The test joins the early compact gate. Fresh hosted Linux execution is
required; Windows/image work remains grouped with subsequent control fixes.

Flutter documents the [root overlay destination](https://api.flutter.dev/flutter/widgets/OverlayPortal/OverlayPortal.html)
and [inherited ownership of portal content](https://api.flutter.dev/flutter/widgets/OverlayPortal-class.html).
These API contracts motivate the implementation; they do not establish its
runtime result.

## Executed Source765 results

[Full Linux 43638180557](https://github.com/edgepillar/syrius/actions/runs/43638180557)
passes all thirteen required steps, including 275-source strict analysis,
early gates, the complete non-chain directory and tracked generation.
The three Home raster engine/resource cases pass, including full 18/36-second
motion, bounded reuse, sampled analytic fallback, DPR/geometry replacement
and disposal. No measured speedup or cold-lock cause is established.

[Windows 43639780927](https://github.com/edgepillar/syrius/actions/runs/43639780927)
and [independent reader 43642361243](https://github.com/edgepillar/syrius/actions/runs/43642361243)
verify 1,505 selected Dart passes, 1,220 Python cases with eighteen skips,
zero selected findings, 123 reader controls and 87 original files. Fourteen
Settings, twenty-four general and four viewport PNGs are verified. Required
entry/application actors and all five owned lab nodes exit normally.
Auxiliary VCTIP termination leaves complete runner lifecycle unqualified.
This read-only profile does not repeat the financial send, new seed or
performance qualification.

All twenty-four general originals and their pinned references are individually
viewed: sixteen mismatches, eight unresolved and no new accepted pair. The
single archive and complete 21,342-byte report are retained after successful
owned closure. Only registered disposable scratch is removed. Standard
manager transport has one complete successful command and empty stderr; no
adapter or marker payload is introduced. Fourteen Settings and four viewport
PNGs remain verified without another local transfer or local image review.
All dispatched Source765 outputs are consumed before this source change.

General captures remain pattern evidence rather than literal catalog states.
The Plasma slot and Swap corrections are visible; remaining geometry and
unprepared states retain their recorded verdicts. The empty Staking footer,
Plasma heatmap and dark well in light retain their settled intent. No
comparison page or derivative image is produced.

Accepted scope stays 76/80 and accepted Source730 Ready pairs stay 2/94.
V01/V06 remain in review; V02/V05 remain blocked. Source744's failed paired
performance checks remain. F06 retains its Source722 send/six-effect evidence
and the approved native P03/P09 substitute. The original Docker/WSL route
remains unqualified. Full image, motion and final acceptance remain open.
