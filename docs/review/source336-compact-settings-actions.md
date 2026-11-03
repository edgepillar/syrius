# Source336 compact Settings actions

Updated: 2026-11-02T20:41Z. Prepared on source
4fa665cf968d8165b61fb2b1a559af08ad4421a8, tree
c6f40ddb843b1e309f4cf9db2c3e2cdc5c88cdd1.

Four existing Settings components now preserve their intended 26-pixel compact
action height without ambient compact visual density subtracting eight pixels.
Node keeps its original height, inset, label and callback. Apps and Addresses
use the neutral secondary surface and disabled foreground, retaining original
button widgets and action expressions. Wallet's existing cache TextButton gains
the same neutral outlined treatment and compact dimensions. Its original
current-source and callback guards remain byte-for-byte unchanged. No cache
operation is performed by this preparation.

The reference source is mockups/redesign/src/00-head.html: the base button uses
the secondary card surface and line border, and .btn.xs specifies height 26,
horizontal inset 10 and 12-pixel medium-weight text. Existing height tokens
already equal 26; no token, shared theme, dependency, seam barrier, input path,
timer, presenter or action owner changes.

## Correction to S334-P01

Subsequent correction: the [actual Source336 pair review](source336-settings-visual-review.md)
reinstates the compact-height finding. The reference interpretation below is
retained as a superseded historical statement.

Both exact Apps references, 34-set-apps-dark.png and 34-set-apps-light.png, were
reopened individually. Their Connected card also fills the available vertical
region, with WalletConnect beneath it. The previous description of a stretched
table and the proposed compact-height remedy are withdrawn as unsupported.
The original review record is retained. Table-height calculation, genuine
connection data and empty-state behavior remain unchanged. Actual Source334
frames were not reopened by this reference-only check, and no match is inferred.
The remaining action, heading and row findings require fresh actual review.

## Validation and remaining scope

All 27 selected regular-file memory controls pass with zero failures, errors,
skips or blocked attempts; 940 controller cases remain registered. There are no
new test registrations. This memory lane runs no local SDK/native process and
creates no filesystem scratch. It does not execute or render Dart controls.

The [Source335 results](source335-hosted-and-historical-windows-outcomes.md)
qualify 837 focused cases and the separate historical Source334 full baseline.
Fresh current-source strict analysis, 837 ordinary / 839 startup expectations,
940 Python controls with three existing skips, 105 reader controls, 4,881 full
passes with one skip, all four native families and affected-image review remain
required. Source335's full/native gates are not silently marked complete.

Acceptance remains 72/80 rows, nineteen preparations, 50 literal outputs, 44
missing and zero of 94 accepted matches. Every original motion, shader,
frame-time, seam, environment, fixture and final-review condition remains.
Native101/103 remain UNKNOWN, Native104 remains unadmitted and the PR stays Draft.
