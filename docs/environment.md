# Redesign build environment

Recorded on 2026-10-23 for the desktop redesign based on `sol-znn/syrius`
`dev` at `add99a2cb7128d3e754733130394b9869b708f86`.
The publication source commit is `e13abb38757726018481158f27a7ad72d62f8171` on `redesign`.

## Publication and evidence binding

This publication preserves the public base and adds anonymous contribution
commits. The original local implementation history and private qualification
receipts are retained separately. Progress-row hashes identify the accessible
publication source commit; row dates record the earlier implementation work.

The separate local checkout is shallow at the exact public `dev` base above,
matching the implementation checkout's boundary. It uses its own Git objects
without alternates or hard links. The publication destination must already
contain that public base. The older public ancestry remains upstream.

The application, test, harness, asset and tool files are identical to the
qualified local source. A read-only comparison of the retained payload verifies
1887 paths, their Git modes and blob IDs. The SHA-256 of the sorted
manifest is `3481809bd8fff693f2e4e0d3597fd8eed6a8504bc91736407dfe827d84ac0373`. Each manifest record is UTF-8
`mode + NUL + path + NUL + blob ID + LF`. The manifest excludes only this file,
`PROMPT-redesign-build.md` and the three workflow files listed below.

All 343 files in the final qualification source pin also match their recorded
SHA-256 digests. The only publication changes relative to that final local tree
are the three PR-branch filters and these two documentation files. No application
dependency version, lockfile, analyzer rule, generated localization, embedded
native library or behavior has changed during publication preparation.

The results below were completed before this publication history was created.
Source equality carries that local evidence; it is not a fresh execution at the
publication commit. Failed, interrupted and incomplete earlier runs retain their
original outcomes and remain preserved privately. Private paths, raw logs,
profiles, caches and storage receipts are not included in the contribution.

## Toolchain

Qualification ran on macOS arm64 using an isolated Flutter 3.47.7 tag checkout
and Dart 3.13.5. The framework revision is
`abaf9c523780a608bd46686fd5e53740a07077f8`; the engine revision is
`deb287481e3ce9468f3434937ced4240a70539ca`.
The framework reports `[user-branch]` for the tag checkout. This does not attest
a signed Flutter distribution archive. The application lockfile requires Dart
`>=3.13.0 <4.0.0` and Flutter `>=3.47.0`.

Locked dependency restoration and genuine localization generation completed in
the implementation environment. The eight retained localization source/output
digests remain unchanged. The existing toolchain and package cache were reused
for final qualification. Publication preparation downloaded no toolchain or
dependency and generated no duplicate binary package.

## Local checks

| Check | Observed result |
| --- | --- |
| Formatting and diff checks for the final implementation batch | Exit 0 |
| Strict analysis of that batch | 299 selected non-generated Dart files; zero diagnostics; exit 0 |
| Focused harness cases | 123 passed; exit 0 |
| Full serial unit/widget suite | 3,960 passed; one existing skip; no failures or errors; exit 0; 906.654 seconds |
| Root analysis with `--no-fatal-infos` | Zero errors, zero warnings, 1,322 infos; exit 0; 30.150 seconds |

The strict selection covers the final implementation batch, not every file in
the complete contribution. Root analysis and the full suite cover the complete
application tree. No test skip was added. Default analysis still treats the
informational backlog as fatal.

The full suite used `flutter test --no-pub --reporter json --concurrency=1
--timeout 60s test`. Application tool invocations suppressed analytics and version
checks. Stage boundaries, exits and terminal test events were observed in one
bounded foreground transcript. They are not separate command receipts or a
hosted CI run.

Settings, onboarding, Swap and Accelerator use captured original sources and
terminal outcome holds. Receive, notification, initialization, maintenance and
HTLC work retain their original ownership and uncertainty boundaries. Password
migration and full two-sided Swap terms remain behind registered seams.

Six inert read-only presentation components can start before production wallet
startup. They refuse wallet actions and shot evidence. The native capture
adapter remains unavailable. Synthetic presentation, visible content and equal
theme values do not prove native preparation, restoration or a wallet capture.

## Pull request workflows

The following `pull_request.branches` filters now name the PR base `dev`:

- `.github/workflows/pr-validation.yml`
- `.github/workflows/blockchain-integration-tests.yml`
- `.github/workflows/syrius_builder.yml`

All three YAML documents parse locally. Their other workflow semantics are
unchanged from the qualified local implementation. The Flutter pin remains
3.47.7; push triggers still name `master` and `v*` tags, and release upload remains
tag-gated. Hosted CI has not run. Its default parallel test execution, generation
checks, native builds and devnet integration require their own exact-head
results. The local serial suite does not establish those results.

## Native acceptance gates

| Required acceptance | Current evidence | Remaining gate |
| --- | --- | --- |
| Windows debug and release builds | Pinned source/toolchain; offline checks | Windows host, MSVC and Windows SDK |
| Running native harness | Source adapters and injected tests | Native desktop tooling and original owner lifecycle |
| Isolated chain 321 send | Source scripts only | Producing owned devnet, imported harness-only profile and confirmed send |
| 47 screens in both themes | 47 scripts with final assertions | All 94 actual captures, comparisons and independent pair review |
| Motion, shaders and frame times | Finite widget and original-art cases | Running native build and baseline measurements |
| Disabled seams | Registry and injected control tests | Every native control, shortcut and Go to entry tried |
| Minimum window and RTL | Selected scaled/RTL widget fixtures | Complete native wallet at 1200 by 600 and Arabic layout |
| Restoration and cold startup | Conservative source guards | Original native owner, renderer frame pins and positive restoration receipts |

The macOS host has Command Line Tools without full Xcode. Windows desktop tools
and a usable Docker daemon are unavailable. No hosted CI, native build, signing,
real-wallet operation, live-chain effect or production acceptance is claimed.
The PR must remain a Draft until the outstanding qualification is resolved.

## Mockup and font provenance

The portable mockup pipeline previously passed 13 synthetic checks, reproduced
all 12 art scripts byte-for-byte and rendered all 94 references at 1280 by 780
using an isolated Chrome for Testing 156.0.8078.47 profile. Platform text rendering
differs from the original references. The original references were retained;
these renders are not running-wallet captures.

The Space Grotesk SemiBold source/output digests, deterministic derivation,
coverage limits and OFL notices are recorded in `assets/fonts/REDESIGN.md`.
Existing full-coverage faces and locale fallbacks remain bundled. Binary metadata
and offline widget checks do not establish native font rendering or parity.

The mockup fills (`#4FD166`, `#006AFF`) differ from the general design-rule values
(`#00D557`, `#0061EB`). That source discrepancy still requires owner resolution.
