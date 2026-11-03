# CSS shadow blur mapping

The five shared outer shadows copied the mockup's CSS blur numbers directly
into Flutter `BoxShadow.blurRadius`. These are different units. CSS requires
a Gaussian standard deviation of half the shadow blur radius, while the pinned
Flutter conversion uses `radius * 0.57735 + 0.5` for positive radii.
See [CSS shadow blurring](https://www.w3.org/TR/css-backgrounds-3/#shadow-blur)
and the [Flutter 3.47.7 conversion](https://github.com/flutter/flutter/blob/3.47.7/engine/src/flutter/lib/ui/painting.dart#L8198).

Each shared token now inverts that conversion once. The dialog, side panel,
toast, floating menu and tooltip reach sigma 30, 25, 18, 15 and 9 respectively,
matching the original CSS values 60, 50, 36, 30 and 18. Colors, offsets, spread,
blur style, inset top edge and surface blur retain their existing values.
The tokens remain ordinary constant BoxShadows, preserving their existing
copy/interpolation behavior. No widget or interaction expression changes.

The existing both-theme component cases now read each original CSS rule and
compare its offset, color and half-radius with the actual token's `blurSigma`,
alongside zero spread and normal blur style. This checks the value used by the
[pinned painter](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/painting/box_shadow.dart#L65).
All previous case registrations remain. The fifteen existing theme cases join
every earlier focused file, giving 78 ordinary files in 39/39-file groups:
976 required cases (475/501), or 978 with the separate asset-fidelity selection.
The theme file also joins the existing strict analyzer arguments. Python stays
at 955 controls with three existing hosted skips. Nineteen local mocked
admission/analysis controls pass. Fresh hosted engine/analysis remain pending.

This corrects one source-level contributor to the retained Go To shadow
differences. It does not accept a whole-image match or establish current native
pixels. The [fast first-delivery scope](fast-first-delivery.md) remains: new
heavy Windows builds, native lab producers, image transport and detailed
visual/performance acceptance stay in phase two. The original 72/80 rows,
50/94 literal outputs, 44 missing outputs and zero accepted matches remain.
All original FAILURE/HOLD/UNKNOWN evidence and the unapplied Deposit candidate
retain their existing scope. No dependency, financial operation or local SDK
execution is added.

## Focused result

Original [41717389503](https://github.com/edgepillar/syrius/actions/runs/41717389503),
attempt one, job 126200884460, succeeds at Source381 `ef76a1c78073dc68982b7dd37add9e86dde51d8b`,
tree `83d304f73f9a39cbfc93803f3b957805bf0f3e09`. Independent read-only qualification accounts for both
complete original streams: 39/39 files, 475/501 passes, all 976 ordinary cases,
102 hidden and 1078 total terminal events, zero failures/errors/skips.
The 978 asset-fidelity count remains a separate selection.

All fifteen existing theme cases pass. Both themes compare all five shadow
tokens directly with the original CSS: actual painter sigma, color, offset,
zero spread and normal blur style. Every previous test registration remains.
This qualifies the source mapping and engine assertions; actual native pixels
and the retained X527/X528 whole-image differences remain open.

All 955 Python controls complete with zero failures/errors and three existing
hosted skips. Fourteen asset observations succeed and selected analysis has
zero errors, warnings or infos, including the explicitly selected theme file.
Every earlier focused file, startup refusal, entry gate and command/output/
deadline bound remains. All source-bound jobs are terminal with zero artifacts.
There is no local SDK execution or artifact transport and no new full Windows
build or native producer.

Source382 changes documentation only; every application, test, workflow and
dependency byte remains equal to tested Source381. The original first-delivery
pin and 72/80-row, 50/94-output, zero-match acceptance boundaries remain.
Source374 original Node-version failure, Source368 full Windows/Native108
outcomes, earlier FAILURE/HOLD/UNKNOWN evidence and the unapplied Deposit
candidate retain their original scope. Heavy qualification remains deferred.
