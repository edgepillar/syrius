# Lock input leading content

[Source745 full Linux](https://github.com/edgepillar/syrius/actions/runs/43538095767)
passes all thirteen required steps and tracked generation. Its
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/43539788663)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43541901135)
verify six PNGs, 1,507 Dart cases, 1,220 Python cases with eighteen platform
skips, zero selected analysis findings and four normal required actor exits.

Every actual and reference image was individually viewed. The native caret,
two light-picker tooltip overlays and extra wrong/picker status strips are
gone. The normal strip remains. The full-height disabled field and truthful
removal warning remain correct. No new whole-image match is accepted because
the input's leading text is still displaced.

Bounded observations of each existing PNG retain only text-ink coordinates.
Both themes put the empty placeholder at x476 through x538, versus reference
x473 through x535, with matching vertical bounds. All twelve masked glyphs
have a leading displacement of about 4.4 px. Their tracking is the original
0.2 em at 14 px; the correction accounts for its half-leading advance as well
as the measured 3 px input displacement. No comparison page or derivative
image is generated, and numeric coordinates do not grant visual acceptance.

The password field now uses a 9 px leading inset for its placeholder/revealed
value, and 7.6 px for a nonempty masked value. The 12 px trailing inset stays.
Its existing controller notifies a local builder when the value changes,
preserving the same field, focus node and controller through typing, reveal,
clear and picker transitions. The existing ownership case checks actual
editable-box movement and retained state, without new test registrations.

The shell status, animation, shader cache, fonts, colors, field height, suffix
control and authentication behavior keep their Source745 implementation.
Fresh hosted analysis, tests and native image review are required for the
leading-content correction. No local SDK or native wallet executes.

The reviewed 739,455-byte archive is retained once and its owned disposable
PNGs are removed after normal task closure. Earlier source-bound results and
failures remain. Scope stays 76/80 and accepted pairs 2/94. V01, V02, V05 and
V06 remain open, including Source744's failed performance checks. The accepted
Windows native CI route remains distinct from the unqualified Docker/WSL path.
