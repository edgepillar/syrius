# Pillar sort frame follows the nested tab rules

X556 keeps the sort control's container geometry open. The original reference
places its chip inside a span in the Nodes tabs. The more specific `.tabs span`
rule applies to that nested chip as well. A generic closed stadium outline and
ordinary chip padding therefore do not represent this particular reference.

## Source correspondence

The unchanged [reference stylesheet](../../mockups/redesign/src/00-head.html)
and [Pillars markup](../../mockups/redesign/src/30-earn.html) establish:

| Property | Winning reference rule |
| --- | --- |
| Label | 12 px dim text from `.chip`, medium weight from `.tabs span` |
| Icon and gap | Original extra-small 12 px sort SVG and 6 px gap |
| Padding | `.tabs span` overrides the chip with 12 px vertically and 10 px horizontally |
| Border | One-pixel line on top/sides; the tab rule replaces the bottom with two transparent pixels |
| Height | Declared 26 px with border-box sizing and 27 px of vertical padding/border |
| Position | A negative one-pixel bottom margin in a centered flex row |

The [published box-sizing rule](https://www.w3.org/TR/2026/REC-css-ui-3-20260407/#box-sizing)
floors the inner height at zero. The 27-pixel minimum and half-pixel centered
border offset are source-derived geometry, not a measurement of current native
wallet pixels. Both existing Pillars reference PNGs were viewed read-only; the
references and their bytes are unchanged. No current wallet image is captured
or compared, and no whole-chip or whole-image match is accepted.

## Correction

The shared tokens name the sort frame's minimum height, content/border insets
and centered offset. The content keeps the original icon, gap and qualified
label. Its top/bottom content insets retain the asymmetric border center; the
frame grows with larger text instead of clipping the label.

The outline uses one uniform visible theme color with the reference's unequal
border widths. A separate clip removes only the transparent bottom region,
including its corner joins. The label and original input remain outside that
clip. This follows the
[pinned Flutter border renderer](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/painting/box_border.dart#L644-L664),
which accepts unequal widths with one visible color. There is no new package,
shader, fill, shadow, UI string or reference edit.

The original PopupMenuButton, keys, tooltip, selected value, menu entries,
weight/production actions and disabled APR seam remain. Search, loading,
delegation, amounts, context guards and all backend arguments are unchanged.

## Prepared verification

The existing nine Pillars cases retain their registrations and assertions.
Both-theme cases add actual frame height, border widths/color, open-bottom
mask, icon inset and center observations. Existing compact-density cases retain
their delegation guard checks, add sort-frame growth at the same 1.75 text
scale, and extend that observation to RTL. Existing real sort/menu, row-detail,
refresh and loaded-identity checks remain.

All 89 focused files keep their original order and counts: 1,123 ordinary cases
in complete 45/44-file streams, expected 553/570. The separate asset-fidelity
variant remains 1,125. Python remains 955 controls with three existing hosted
skips. No controller, workflow, dependency, asset or global registration changes.
The prior 37 mocked/read-only Python controls are reused against unchanged
Python bytes; no completed control is repeated. Fresh selected analysis and
complete focused Flutter execution are required for this source correction.

The base is Source414 `5576ea52a10c4608b37d42ee3d7005f00d96ddc3`, tree
`6fff8f12d3a7da03e7e745b43fb38eaf0c57ca25`. Its application/test bytes
equal tested Source413 `c0449fa4d2f6ac52268415c25f0d6005485b1eea`, tree
`2bf33f5eb4642caba4315ed7c98e20bdc397d82d`, in
[41776860011](https://github.com/edgepillar/syrius/actions/runs/41776860011).
That successful result does not qualify this correction. The exact
[preceding body325](pr-body-325.md) is archived unchanged.

## Acceptance boundaries

The original five end-state criteria remain open: Windows installation and
the literal Docker/lab route; current full-suite/native coverage; all 94 visual
pairs; running motion/shader/frame-time checks; and the complete native seam
pass. Source review or selected tests do not replace any of those gates.
The basic interface remains available for Draft code review. This bounded
source correction schedules no full Windows/lab producer or image transport.
X556 keeps current native container geometry and full visual acceptance open.
The original ledger stays 72/80, 50/94 literal outputs, 44 missing and zero
accepted matches. Earlier failures and UNKNOWNs retain their source and scope.

## Fresh Source415 focused result

Source415 `6f371be032545394b5fbe40b573c74d2bfaefa7c`, tree
`828c18e9a3ea81f77a3c2d1b68e1945c0024e2ed`, independently qualifies
[41781844194](https://github.com/edgepillar/syrius/actions/runs/41781844194),
attempt one, job 126414951553. Both complete 45/44-file streams pass, 553/570:
all 1,123 ordinary cases, zero failures/errors/skips, 125 hidden events and
1,248 terminal events. Actual commands close normally in 133.75 and
105.109 seconds without timeout, forced kill or output overflow. The original
one-worker, group/aggregate deadlines and output bounds remain.

All nine Pillars cases pass. Both-theme observations establish the 27-pixel
frame, half-pixel centered offset, original icon inset/center, unequal border
widths, theme color and transparent-bottom mask. Existing compact-density
cases retain delegation guards and pass the enlarged frame at 1.75 scale in
LTR and RTL. Existing actual sort-menu taps, disabled APR, row details,
refresh and loaded-identity checks pass. Every earlier selected path passes;
all original registrations and assertions remain.

Python completes all 955 controls without failures/errors and retains three
existing hosted skips. Fourteen asset controls pass. Selected analysis exits
zero with complete empty output and zero errors, warnings or infos. Every
source-bound job is terminal and artifacts are zero. The 1,125 asset-fidelity
variant and standalone rail widget suite remain outside this ordinary selection.

Source416 changes documentation only, with no second producer. This result
qualifies source correspondence and finite widget geometry. X556 remains open
for current native container pixels and whole-chip/whole-image acceptance.
No reference is edited, no native image is transported, and no visual match
is inferred. The five original end-state criteria and all remaining phase-two
gates retain their full requirements. The PR remains Draft.
