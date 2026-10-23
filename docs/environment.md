# Redesign build environment

Recorded on 2026-10-23 for the desktop redesign based on `sol-znn/syrius`
`dev` at `add99a2cb7128d3e754733130394b9869b708f86`.
The initial publication source commit is `e13abb38757726018481158f27a7ad72d62f8171` on `redesign`.

## Publication and evidence binding

This publication preserves the public base and adds anonymous contribution
commits. The original local implementation history and private qualification
receipts are retained separately. Progress-row hashes identify the accessible
publication source commit; row dates record the earlier implementation work.

[Draft PR #6](https://github.com/sol-znn/syrius/pull/6) publishes
`edgepillar/syrius:redesign` to `sol-znn/syrius:dev`. Follow-up commits retain
anonymous contribution metadata and record their own qualification scope.

The separate local checkout is shallow at the exact public `dev` base above,
matching the implementation checkout's boundary. It uses its own Git objects
without alternates or hard links. The publication destination must already
contain that public base. The older public ancestry remains upstream.

At the initial publication source commit, the application, test, harness, asset
and tool files are identical to the qualified local source. A read-only
comparison of that retained payload verifies
1887 paths, their Git modes and blob IDs. The SHA-256 of the sorted
manifest is `3481809bd8fff693f2e4e0d3597fd8eed6a8504bc91736407dfe827d84ac0373`. Each manifest record is UTF-8
`mode + NUL + path + NUL + blob ID + LF`. The manifest excludes only this file,
`PROMPT-redesign-build.md` and the three workflow files listed below.

At that commit all 343 files in the final qualification source pin also match
their recorded SHA-256 digests. The only initial publication changes relative
to that final local tree are the three PR-branch filters and these two
documentation files. No application
dependency version, lockfile, analyzer rule, generated localization, embedded
native library or behavior has changed during publication preparation.

The initial local results below were completed before the initial publication
history was created. Source equality carries that local evidence; it is not a
fresh execution at the publication commit. Failed, interrupted and incomplete earlier runs retain their
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

Restore the vendored package's test tools separately in every checkout before
analysis. Application dependency resolution does not install a dependency's
`dev_dependencies`:

```sh
flutter pub get --enforce-lockfile
cd patched_packages/reown_core-1.3.8
flutter pub get --enforce-lockfile
cd ../..
```

Local follow-up qualification reuses the existing cache with `--offline` for
the vendored restoration. The lockfiles and analyzer rules remain unchanged.

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

### Harness follow-up checks

The frame, fixture cleanup and seed-admission follow-up adds 37 Dart
regressions. The CI presentation controller adds 32 finite standard-library
Python tests. Qualification reused Flutter 3.47.7, Dart 3.13.5 and Python 3.9.6.
The follow-up source commit is
`ddf740e1420686e8360cfc8eb80b110cbb39c4d5`. All sixteen files in the final
local qualification pin match their recorded SHA-256 digests at that commit,
including the eight Dart files, Python controller and tests, workflow changes
and protected dependency/analyzer inputs. Later documentation does not alter
those qualified files.

| Check | Observed result |
| --- | --- |
| Vendored locked test-tool restoration | Offline; exit 0; lockfiles unchanged |
| Vendored package analysis | Zero diagnostics; exit 0 |
| Controller unit tests | 32 passed; exit 0; no native process or network execution |
| Workflow parsing and semantic checks | Five documents pass; all three PR filters name dev; existing behavior preserved |
| Formatting and strict follow-up analysis | Eight Dart files; zero diagnostics; exit 0 |
| Harness suite on final source | 160 passed; no failures or errors; exit 0 |
| Full serial unit/widget suite | 3,997 passed; one existing skip; no failures or errors; exit 0; 1,105.019 seconds |
| Root analysis with `--no-fatal-infos` on final source | Zero errors, zero warnings, 1,322 existing infos; exit 0 |

The full suite ran immediately before removal of one analyzer-confirmed
redundant import. A byte comparison verifies that this is the sole subsequent
Dart source delta. Formatting, strict analysis, all 160 harness cases and root
analysis were then repeated on the final Dart source. The Python controller
and workflow additions were qualified separately in that same final run.
No test skip, dependency version, lockfile or analyzer-rule change was added.
Earlier failed analysis attempts retain their original outcomes privately.
These local results do not establish native Windows execution.

## Pull request workflows

The following `pull_request.branches` filters now name the PR base `dev`:

- `.github/workflows/pr-validation.yml`
- `.github/workflows/blockchain-integration-tests.yml`
- `.github/workflows/syrius_builder.yml`

All three YAML documents parse locally. The Flutter pin remains 3.47.7; push
triggers still name `master` and `v*` tags, and release upload remains tag-gated.
The target runs at `3041ffa73569b4a44a878048a74ea40b5602f62c` require maintainer
approval and contain zero jobs. This is neither a pass nor a test failure.

[Fork Fast Validation run 39998807152](https://github.com/edgepillar/syrius/actions/runs/39998807152)
completed successfully at that exact source. Patched-package analysis,
application analysis, the default parallel unit/widget suite and generation
consistency all passed. Fork evidence is separate from target acceptance.
These results precede the follow-up harness changes and do not qualify them.

The manual `.github/workflows/public-contribution-qualification.yml` workflow
builds Debug and Release sequentially on each of Linux, macOS and Windows.
Each platform shares its runner and cached toolchain between configurations.
The workflow records the exact commit and tree, enforces the dependency lock,
and creates no packaged artifact upload. Its optional devnet job calls the
existing blockchain workflow through `workflow_call`; the local relative
reference selects [the same commit as the caller](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#calling-a-reusable-workflow).
Existing PR, push, tag and release behavior is preserved. A successful build
does not establish startup, frame times, screen matches or wallet safety.

The optional `presentation_smoke` input adds Windows controller unit tests,
a separate Debug build targeting `harness/app/main.dart`, and a bounded
presentation probe. The Python 3.9+ standard-library controller requires a
GitHub-hosted Windows runner, the exact checkout SHA and a fresh profile. It
retains the original process handle, verifies the authenticated presentation
PID, checks visible Welcome and empty Import components in both themes, and
requires refused wallet/input/capture commands to leave the scene unchanged.
Closure requires the original process to exit successfully; forced termination
or incomplete output fails the probe. Public output contains selected runner
and Dart kernel hashes, fixed check results and exit fields. Profiles, control
tokens and raw process diagnostics stay out of that summary. This qualifies
isolated presentation behavior; actual wallet ownership, restoration and the
94 screen captures retain their separate acceptance gates.

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
and a usable Docker daemon are unavailable locally. Hosted build and devnet
results require separate exact-source receipts. Signing, real-wallet operation,
live-chain effects and production acceptance remain unclaimed.
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
