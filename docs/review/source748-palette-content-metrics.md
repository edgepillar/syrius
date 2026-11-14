# Palette content metrics

Source747 fixes the Windows palette's 32-pixel origin error. Both individually
viewed theme pairs now start at client y120, matching their references. The
selection fill still spans forty flat pixels against thirty-eight in the
reference. Its result symbols, label starts and matched-text weight differ.

## Current change

The palette reserves its one-pixel border inside the original 560-pixel
width. Query and result content use the reference row's ten-pixel gap; result
symbols occupy fourteen pixels. Existing icon builders keep their original
widgets inside that bounded footprint. The rendered-size controls exercise
both a borrowed eighteen-pixel builder and the legacy icon path, in both
themes, text directions and existing text scales. Flutter's pinned
[geometry reader](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_test/lib/src/controller.dart)
measures transformed corner positions.

The normal result row follows its original CSS line box: fourteen-pixel text
at 1.45 line height plus eighteen pixels of vertical padding, or 38.3 pixels.
Scaled text adds its existing line-height growth without rounding every row
up again. The footer's width bound accounts for the same border inset.

Matching text uses the HTML bold role, 700 under the existing normal parent.
The query caret retains its one-pixel width, font-scaled height and original
blink, with the reference's forty-percent foreground opacity. The query
controller, IME, filtering, route, ownership and dispatch remain unchanged.
No example contact is inserted to reproduce the illustrated result list.

Existing geometry and emphasis cases are updated without new registrations.
The geometry file joins the existing early Ready/window gate. Its original
assertions, the native-caption surface phase, complete directory and actual
tracked-generation checks remain required; the workflow still has thirteen
required steps. No native capture, retry, timing or lab controller changes.

## Executed Source747 evidence

Tested head 804d0bf76d70d0223a8b0b44dcb666ded408d555, tree
c06caf1ae6f22b052ad5827867d6dc016dc43c61, passes
[full Linux 43556789422](https://github.com/edgepillar/syrius/actions/runs/43556789422)
with all thirteen required steps and actual tracked generation. No global
test or analyzer-info count is inferred from step completion.

[Home 43558323865](https://github.com/edgepillar/syrius/actions/runs/43558323865)
and [reader 43560458140](https://github.com/edgepillar/syrius/actions/runs/43560458140)
verify 1,505 selected Dart cases, 1,220 Python cases with eighteen platform
skips, zero selected findings and 123 memory-only reader cases. Required
entry/application and all five native nodes exit normally. Auxiliary forced
cleanup is recorded separately; complete runner lifecycle is unqualified.
Eight Home, twenty-four generic and four viewport PNGs are independently
verified. All eight Home actual/reference pairs are individually viewed:
two palette mismatches and six unresolved sparse-data or animation contexts,
with no new accepted match. Generic and viewport PNGs are not locally viewed.
The owned review closes successfully, retaining one archive and removing only
its registered disposable PNG scratch. No comparison page or derivative image
is rendered.

[Lock 43558108568](https://github.com/edgepillar/syrius/actions/runs/43558108568)
passes 1,507 selected Dart cases, the same Python and analysis gates and its
Release build. The first dark normal shot times out over HTTP; fixed capture
progress is unavailable. Both attempted actors exit normally, but zero PNGs
remain. [Reader 43560378124](https://github.com/edgepillar/syrius/actions/runs/43560378124)
verifies the failed manifest without starting a runtime. The original failure
is preserved, its inner cause is NOT_ESTABLISHED and the job is not retried.
Source747 Lock visuals remain unqualified.

## Remaining acceptance

Fresh full Linux and original Windows output are required for this change.
Existing eye animation and runtime balances, scope, history, rewards, contacts
and update state are preserved. This readonly qualification establishes no
new send or seed effects; F06 remains bound to Source722. Earlier failures and
Source744's failed performance comparison remain visible. Accepted scope stays
76/80 and accepted matches 2/94; V01, V02, V05 and V06 remain open. The accepted
native Windows route remains distinct from the unqualified Docker/WSL route.
