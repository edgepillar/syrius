# Compact ledger bands and capture refusals

The Token filter heading now uses the reference's 11 px vertical and 16 px
horizontal padding. Staking's title band, 32 px column-heading minimum and
9 px row insets follow the reference. Unlocks aligns with the status chips;
human durations and relative start dates use the interface face, with exact
amounts retaining their mono component. The loading rows use the same new
metrics. The shared table exposes these metrics as optional settings and
retains its existing defaults for other callers. Its header can grow with
larger text.

These changes use the reference CSS and the earlier reviewed Staking
captures. The two table component files at Source711 are byte-identical to
Source702's reviewed components. Source711's four new PNGs are independently
qualified but have not yet been visually reviewed. No new match is claimed.
Paging, keyed rows, original transaction controls and existing data sources
remain in use.

## Recognized failure records

The Dart capture protocol already emits targetUnavailable, frameBusy,
frameDeadlineExceeded, frameOriginalFailed and frameAdmissionFailed. The
Python details reader omitted these five codes while the Settings reader
recognized them. A valid original failure could therefore be rejected as an
unrecognized entry marker.

The details reader now recognizes the same closed codes. The existing test
also passes them through the actual Ready failure-marker validator. All five
cases in the selected in-memory suite pass, including existing unknown-field,
private-input and malformed-record refusals. The extended witness fails with
the old allowlist. The fixed code set matches the Dart enum. No test case is
registered, and successful capture checks remain unchanged.

This source correction does not establish which code caused the old Ready
failure. Fresh hosted qualification remains required.

## Source711 results

The [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43320997585)
passes application/patched analysis, the complete non-chain test directory
and tracked generation at `d5b1cf54ebd6c459f08340e3411613ad981a5412`.
The [Staking/Token producer](https://github.com/edgepillar/syrius/actions/runs/43321761577)
and [independent chain reader](https://github.com/edgepillar/syrius/actions/runs/43325404188)
verify four PNGs, the original Stake/Token prerequisites and normal required
original/copied actor and five-node closure. Selected checks pass 1,480 Dart
cases, 1,214 Python cases with eighteen skips and zero analysis findings.
The chain reader executes 75 and 10 cases in its two actual suites, totaling
85. The separate MSVC telemetry helper termination remains recorded.

The parallel [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43324623868)
fails before any PNG with ENTRY_REFUSED and entry exit 1. The finite marker
identifies wallet_ready_catalog, a capture diagnostic and three prior stage
markers; the underlying capture cause is unestablished. The
[readonly reader](https://github.com/edgepillar/syrius/actions/runs/43327615362)
passes 123 actual cases and verifies both failure archives, zero PNGs and
required-actor forced cleanup. Five original nodes exit normally; complete
lab closure is not qualified. No original native run is retried.

The Source709 F06 failure and all earlier source-bound results retain their
scope. Original acceptance remains 73/80, with P03, P09, F06, V01, V02, V05
and V06 open and zero accepted whole-image matches.
