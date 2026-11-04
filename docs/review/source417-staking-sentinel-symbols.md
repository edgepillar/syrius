# Staking and Sentinel control symbols

Prepared: 2026-11-04T06:30Z.

Source417 replaces the remaining Material substitutes in the Staking strip,
stake unlock chips and Sentinel controls with the original reference vectors.
The reference HTML, reference images, action callbacks and financial data keep
their existing source. This is a source correction; current native pixels and
whole-image acceptance still require the deferred visual pass.

## Reference and implementation

`mockups/redesign/src/30-earn.html` specifies these symbols. The shared
`00-head.html` defines the ordinary, small and extra-small SVG sizes as
18, 14 and 12 pixels. Its original six symbol contents are copied into the
existing shell adapter, without changing the renderer or any older symbol.

| Surface | Original symbols and sizes |
| --- | --- |
| Staking strip | Rewards chart 14, Stake plus 18, Close cross 18 |
| Stake unlock chips | Clock or check 12 |
| Sentinel list | Spawn plus 12 |
| Sentinel strip | Rewards chart 14, owner menu 14 |
| Sentinel revocation chip | Clock or check 12 |

Three semantic size tokens keep those values out of the page widgets. Action
symbols inherit their original button's foreground, including disabled state.
Time/status symbols retain the existing QSR/green semantic ink. The generic
Sentinel Active, Revoked and Yours chips keep their original icons, fills,
labels and status meaning; their private chip now accepts its drawn icon.

The existing buttons, tooltips, enabled predicates, open/close callbacks,
owner checks, timers, refresh requests, confirmation and publication paths
are retained. No service, network endpoint, dependency or generated file is
added or changed.

## Bounded checks

Five existing widget files extend their existing cases. The two old Material
icon assertions in the stake-table cases become checks for the corresponding
original SVGs. Every other existing assertion and every existing registration
remains. The common test helper reads the original HTML independently of the
application's symbol map, then checks the actual loader source, rendered size,
foreground, excluded icon semantics and unchanged text-direction behavior.
It uses the [public loader equality API](https://pub.dev/documentation/flutter_svg/latest/flutter_svg/SvgStringLoader-class.html)
of the already pinned flutter_svg 2.3.0.

Both themes cover Stake/Close, locked/unlocked stakes, compact Spawn with
enabled/disabled and large-text states, Sentinel strip actions and both
revocation-chip states. Existing real callback, confirmation, exact amount,
privacy, timer, pagination and RTL assertions remain. The existing populated
Staking case also checks its Rewards symbol.

The complete existing Sentinel list, value and strip files add 12, 11 and nine
cases to the focused selection. The unchanged standalone rail suite adds
29 cases to cover the shared adapter's existing consumers. These are 61 newly
selected existing cases, with zero new global Dart registrations. All 89
previous paths retain their order; the four files are appended once. The
prepared ordinary selection is 1,184 cases in 47/46-file streams (568/616).
The separately selected asset-fidelity variant expects 1,186 cases.

The selected analyzer additionally includes the affected page/view files,
those existing cases and the common helper. Thirty-seven fully mocked or
read-only Python admission, analysis and failure-catalog controls pass with
zero failures/errors/load errors and no SDK, native or filesystem scratch
execution. Existing stale-count refusals remain, with the new adjacent count
refusals added. Python registration count remains 955 with three existing
hosted skips. Fresh source-bound Flutter test and analysis results are pending.

## Delivery boundary

The [first delivery](fast-first-delivery.md) continues to cover the core
interface and existing basic functionality for Draft code review. No new
full Windows build, native lab producer, screenshot transport or performance
job is scheduled here. The original 72/80 rows, 50/94 literal outputs,
44 missing outputs and zero accepted whole-image matches remain. X556's
native Pillar container pixels and every original final acceptance criterion
stay open.

[Exact preceding PR body326](pr-body-326.md) preserves the earlier source-bound
results and failures. Source415's 1,123-case result and Source368's full Windows
baseline retain their exact revisions; neither is execution proof for this
new source. The PR remains Draft and all public content remains English and
privacy-safe.
