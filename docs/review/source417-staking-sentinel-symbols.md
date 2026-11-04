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

## Original Source417 focused result

The original [run 41786938967](https://github.com/edgepillar/syrius/actions/runs/41786938967),
attempt one, job 126431136640, is closed at Source417
`96ef81b79d8d45930288ff5e9307e4656b0c61d8`, tree
`5faf6eb6791b53a0159c20ff1d6d8084fa19c355`. Python passes all 955 controls
with three existing skips and assets pass all fourteen controls. Selected
analysis records zero errors/warnings and two infos, so the strict controller
refuses that step and Dart tests are skipped. There are zero artifacts and all
source-bound jobs are terminal. The original failed producer is not retried.

The complete 331-byte analysis output has actual analyzer exit zero and
SHA-256 `2d95e8516ed0d36c3d7927db870fc540a27614c62f5fcc17c8ffbfa147af2cc0`.
The sanitized observer records PREFER_INITIALIZING_FORMALS at 320:8 and
UNNECESSARY_RAW_STRINGS at 9:5. Both source classes are `other`; the original
raw paths are unretained and are not reconstructed as producer evidence.

Source418's on-disk correspondence identifies the new chip initializer and
the helper's raw-string prefix as the matching source candidates. It uses the
private-field initializing formal already supported by the pinned SDK and
removes the unnecessary raw prefix. The resulting constructor argument and
regular-expression contents remain the same. This attribution is source
inference; the original observation above retains its scope. Every other
application, test, Python, controller, dependency and workflow byte stays
unchanged from Source417. The 37 completed local controls are reused against
unchanged Python bytes. The 1,184/1,186 counts, all registrations and original
process/refusal bounds remain. Fresh Source418 Flutter qualification is pending.

## Original Source418 runtime result

The separate [run 41788470976](https://github.com/edgepillar/syrius/actions/runs/41788470976),
attempt one, job 126436010901, is closed at Source418
`dfd10741454b1287419b0634c36c3359c127edd2`, tree
`2d7d1df827a99bbcc01e0547339d1ccbe6240bd8`. Selected analysis is complete and
empty, with zero errors/warnings/infos. All 955 Python controls pass with three
existing skips, and all fourteen asset controls pass.

Both original Dart streams finish normally and completely, without overflow,
forced cleanup, retries or unfinished cases. The first 47-file stream passes
all 568 cases in 188.468 seconds. The second 46-file stream records 614 passes
and two failures in 165.906 seconds, for 1,182 passes/two failures overall.
All source-bound jobs are terminal and there are zero artifacts. This remains
the original failed result and is not retried.

The bounded closed text reader retains both ASSERTION details at
`sentinel_values_test.dart:254`, in the two existing theme cases. The complete
original expected/actual messages are unretained. Source inspection identifies
the newly added `in 1 h` expectation: the unchanged formatter selects
`durationHoursMinutes(1, 0)`, whose existing English localization yields
`1 h 0 m`, wrapped by `nodesInDuration`.

Source419 changes only that new expectation to the exact `in 1 h 0 m` label.
The fixture's one-hour input and clock, all original assertions and all SVG
source/size/foreground/semantics checks remain. No application byte changes.
This correspondence is source inference, rather than a reconstruction of the
unretained message. Every test registration, controller, workflow, dependency,
1,184/1,186 count and original refusal/process bound remains. The completed
37 local controls are reused on unchanged Python bytes. Fresh Source419
Flutter qualification remains pending; heavy acceptance stays deferred.

## Fresh Source419 focused result

Qualified: 2026-11-04T07:30Z.

The separate [run 41791263517](https://github.com/edgepillar/syrius/actions/runs/41791263517),
attempt one, job 126444948422, independently qualifies Source419
`ae9ed0a0cac093a7b864b2bfc1e448d46457c162`, tree
`a821559bd134fa2dea6043fee2291735ac535e2d`.

| Stream | Files | Passed | Seconds | Complete output bytes |
| --- | --- | --- | --- | --- |
| First | 47 | 568 | 186.250 | 304590 |
| Second | 46 | 616 | 162.984 | 303193 |

All 1,184 ordinary cases pass with zero failures/errors/skips. Both actual
streams finish normally, completely and without forced cleanup, overflow,
retries or unfinished cases. They retain 131 hidden events and 1,315 terminal
events. The original one-worker, 240-second per-command, 480-second combined
and 4 MiB output bounds remain.

Python passes 955 controls with zero failures/errors and three existing hosted
skips. All fourteen asset controls pass. Selected analysis completes normally
with empty output and zero errors/warnings/infos. The three original startup
checks and both pre-build refusal controls pass. Every source-bound job is
terminal and there are zero artifacts.

All 89 earlier focused paths and the complete existing Sentinel list/value/strip
and standalone rail suites pass. Both theme cases now reach the exact one-hour
label and both original revocation SVG checks. Stake/Close, Rewards, compact
Spawn with enabled/disabled and large-text states, owner menu, locked/unlocked
chips and all earlier action, amount, privacy, owner, timer and RTL controls
pass. The original two Material-shape assertions require their corresponding
reference SVGs; original functional assertions and registrations remain.
The 1,186 asset-fidelity variant remains outside this ordinary selection.

Source420 changes documentation only and preserves all tested application,
test, controller, workflow and dependency bytes. The original Source417
two-info failure and Source418 two-assertion failure above retain their exact
observations and scope. No original failed producer is retried or relabelled.

The original microtasks still define 80 rows: 72 done, four review and four
blocked. P03/P09/F06, full current Windows/root analysis, all 94 visual matches,
running motion/shaders/frame time, native seam interaction, independent review
and the complete original end state remain open. The 50/94 literal outputs,
44 missing outputs and zero accepted whole-image matches remain. X556 native
container pixels and current Staking/Sentinel pixels stay in phase two.
