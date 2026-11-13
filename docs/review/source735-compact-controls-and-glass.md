# Compact controls, Lock fields and shared glass

Source730's four Staking/Token comparisons and Source733's six Lock comparisons
expose concrete layout differences. This change corrects shared control insets,
compact Collect sizing, Token facts/actions and Lock input/glyph treatment.
Missing services remain behind their original seams; wallet amounts, identity,
ownership, transaction and failure-policy behavior are retained.

## Controls and Token details

Primary pills use the reference's 16 px horizontal inset instead of inheriting
the legacy 20 px inset. Explicit caller padding, density and fixed sizes retain
priority. Staking Collect uses a 30 px outlined secondary control with 13 px
text and natural label width. Its horizontal inset includes the reference's
12 px content padding and one-pixel border. The existing loading lifecycle,
receipt handling and duplicate-submission protection remain. Its compact busy
state removes content padding so the spinner fits the original 30 px target.

Optional loading/outlined-button styles merge over legacy defaults. Existing
callers retain their default behavior. The existing loading case exercises
the styled compact target, busy refusal and original-size restoration; the
Staking case checks the actual compact control's geometry.

Token facts use aligned label/value cells, with two fact pairs per row where
space and text scale permit. Narrow or enlarged layouts use one pair per row.
Management modes sit at the trailing edge. Genuine blank or unavailable facts
do not borrow illustrated data, and no issuance date is invented. Favorite
stars use the existing pink accent. Action admission and exact numeric inputs
are unchanged.

## Lock fields and original symbols

The reference's `svg.i.s` is 14 px. Lock key, USB, plus, eye, warning and
chevron measures now follow that size; the Unlock action retains its 18 px
symbol. The warning path comes from the preserved reference HTML. The picker
arrow uses the original chevron and its open-state rotation. Existing tests
check the actual original paths and explicit 14 px paint, rather than relying
only on the implementation token.

Masked passwords use the reference's 0.2 em tracking. Unmasked text and the
placeholder keep normal tracking. The field retains at least 42 px of painted
height without relying on a suffix icon; its tight extent grows for enlarged
text. This fixes the collapsed disabled picker field. Material hover/focus
overlays no longer change its declared fill. Original focus, disabled/busy,
failure and seam ownership rules remain.

Ready's qualified outer-shadow algorithm moves into the shared
`OuterShadowPainter`. Its paint body is retained. Ready keeps the same
foreground-paint composition and existing pixel regression. Lock and the
picker menu now paint the same declared shadows after their glass, clipped
outside the surface. Their blur, radius and shadow declarations are retained;
the glass no longer samples its own prepainted shadow.

## Earlier feedback in Linux CI

One ordered 255-file selection is shared by Windows and Linux analysis.
Moving the literal paths preserves Windows' original command arguments and
finite diagnostics parser. Linux invokes the same selection with
[`--fatal-infos`](https://dart.dev/tools/dart-analyze), before widget tests.
The broad application analysis still reports existing infos and rejects
errors/warnings. No finding is suppressed.

An early existing-file gate covers primary pills, loading/sheens, Staking and
Token actions before the complete non-chain directory. Ready and Lock early
gates, the complete directory and generation check remain required. Case
registrations are unchanged.

Five preparation-time in-memory analysis-admission cases and two mocked CLI
exit-boundary controls pass on the same Python bytes. They preserve the exact
selection, strict failure handling and original child exit. No local SDK or
native execution is claimed. Git whitespace, source correspondence and the
prepared file boundaries are checked separately. Fresh full Linux and native
captures/readers must qualify this implementation.

## Preserved evidence and limits

The four-gate field in the Source733 Lock catalog enumerates rendered
registered controls. It is not four pointer activations. The two visible
Not yet overlays remain real observations; their activation cause is not
established by that count. The earlier "after seam probes" description was
an unsupported inference. The [Source734 record](source734-native-ci-scope-and-lock-results.md)
now makes this distinction explicit; V03's separately executed audit keeps
its own scope. No capture is altered to hide or fabricate a seam result.

The owner-approved native Windows CI route remains accepted for P03/P09.
Accepted scope stays 76/80, with V01, V02, V05 and V06 open. The original
Docker/WSL route remains unqualified. Accepted matches stay 2/94 at Source730;
all six Source733 Lock and four Source730 Staking/Token pairs remain mismatches.
Source715's unchanged timing comparison and frame-gap checks remain failed.
This prepared source change establishes no new image, motion or release pass.
