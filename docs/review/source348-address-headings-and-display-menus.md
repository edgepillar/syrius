# Source348 Addresses headings and Display menu geometry

Prepared from source f859f24665a4d877573f657908d2824c9a4e2ab1, tree
e083012c6ec479957851dce059c5aa0f36b47d85. Both original view files remain
byte-identical to Source336 before this preparation. The retained
[Settings review](source336-settings-visual-review.md) records the wider Display
menus, lower card extent and eight-pixel Addresses heading inset in both themes.
No new actual/reference image is transported or accepted for this source change.

## Presentation change

The shared Addresses card helper now adds the ordinary leading header inset,
so both Your addresses and Contacts start at sixteen pixels, including RTL.
Its original count, actions, table, source ownership and all operation bodies
remain. No identifier, balance, selected account or contact is substituted.

Display language and explorer fields now size to the actual displayed label,
using the existing compact type role, active text scaler, locale and direction.
A twelve-pixel chevron has a twenty-pixel slot beside the same horizontal
insets. Four pixels remain for RenderEditable's caret margin. The text painter
is disposed immediately. At large text sizes the minimum thirty-pixel field
height can grow; no maximum height clips a scaled label.

The existing DropdownMenu remains, with width unset. A parent SizedBox bounds
its closed field. The [pinned Flutter implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/material/dropdown_menu.dart)
otherwise sizes that field from the widest option and icon, and an explicit
DropdownMenu.width also constrains open entry labels. The parent constraint
avoids that explicit per-entry width. The decoration uses a noninteractive
chevron; original field input and menu-controller handling remain. The tests
must prove arrow-area activation and every supported option through original
harness pointer commands before this change is qualified.

Selection, save/error handlers, theme, scaling, explorer provider/chain rules,
rail, shared eye and visible-only price policy remain unchanged. The explorer
continues to be disabled off supported chains. Its genuine host and the saved
language remain visible; no English/System preference is forced to match an
illustration. Original input, key, signing, send and resource guards remain.

## Bounded controls and remaining acceptance

The existing Display cases load the bundled Space Grotesk, Arabic and Devanagari
weights. They require no horizontal scrolling inside the selected language and
explorer text, including language changes and large Arabic. The original
harness case covers all six existing AppLanguage values in both themes and
both tested window heights. The direction case taps the actual decorative
chevron's position, then checks the genuine menu selection and saved value.
Every existing assertion, unsupported-chain refusal and zero-price-request
check remains. No test registration is added.

Every prior seventy focused files is retained. The existing seven-case
Addresses view file is added, giving seventy-one files and 863 ordinary cases,
or 865 with asset fidelity. Both unfiltered serial groups, one worker, original
240-second/four-MiB child bounds, aggregate deadline, refusal and strict-analysis
gates remain. The fourteen local Python admission controls pass. Fresh hosted
analysis, all 863 cases and actual selected-text geometry remain pending.
No local SDK, full build, native producer or original financial flow runs.

The earlier Source346 856-case result stays source-bound. The first delivery
remains pinned to 19c7b2af5e1c for Draft review. Original acceptance stays
72/80, nineteen preparations, 50/94 available outputs, 44 missing and zero
matches. Detailed visuals, motion/performance and extended platform/lab gates,
including localization/glyph acceptance, remain open with all previous
FAILURE/HOLD/UNKNOWN preserved.
