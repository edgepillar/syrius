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
