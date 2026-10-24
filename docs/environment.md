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
startup. They refuse wallet actions and shot evidence. At that initial source,
the native capture adapter was unavailable. Synthetic presentation, visible content and equal
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

### Hosted follow-up at e67d0fab4c54

The following results are bound to
`e67d0fab4c54920862e470387540ea65941a0f05`, attempt 1. They do not qualify
subsequent changes to the devnet fixture.

| Check | Observed result |
| --- | --- |
| [Fast Validation 40012208457](https://github.com/edgepillar/syrius/actions/runs/40012208457) | Passed patched-package and application analysis, 3,997 unit/widget tests with one existing skip, and generation consistency |
| [Desktop qualification 40012204159](https://github.com/edgepillar/syrius/actions/runs/40012204159), Linux job | Debug and Release builds passed |
| Same run, macOS job | Debug and Release builds passed |
| Same run, Windows job | Debug and Release builds, controller tests, separate harness build and isolated presentation probe passed |
| Same run, Docker devnet job | First scenario failed during setup with a wallet/node session-identity refusal |

The desktop workflow's overall result is failure because its devnet job failed.
The retained failure and test-support source identify missing wallet-path and
verified node-chain identity in that fixture. Production admission guards remain
unchanged. The Docker workflow uses chain 69; it does not qualify the redesign
lab's separate chain 321 checkpoints or send.

The target repository's [Fast Validation](https://github.com/sol-znn/syrius/actions/runs/40012153005),
[builder](https://github.com/sol-znn/syrius/actions/runs/40012153007) and
[blockchain integration](https://github.com/sol-znn/syrius/actions/runs/40012153018)
runs at that source require maintainer approval and have zero jobs. Fork build
and test results remain separate from target acceptance.

### Devnet fixture repair

Source commit `8ea04bc8caea59e4f35a3cc9e8c8d59f1ee5ad79` binds the
integration fixture to its owned in-memory wallet path, original node socket
and positively verified chain 69. It restores the previous identity values and
collection objects, and refuses foreign wallet or node owners. Production
publication admission is unchanged.

All six retained qualification inputs match that commit: the two changed Dart
files and four protected dependency/analyzer inputs. All five local stages
passed: formatting, strict two-file analysis with zero diagnostics, 105
admission regressions without skips, root analysis and the diff check. The
regressions include eighteen new offline fixture cases and 87 existing
publication-session cases. Root analysis reports zero errors, zero warnings
and the existing 1,322 infos. The eighteen new offline cases acquired no signer
and made no RPC request. Source equality carries these local results to
`d225317cce491b8c590a19571b8552ee982b66c5`.

At that published head, attempt 1 of
[Fast Validation 40018735731](https://github.com/edgepillar/syrius/actions/runs/40018735731)
passed patched-package/application analysis, 4,015 unit/widget tests with one
existing skip, and generation consistency.
[Devnet qualification 40018730800](https://github.com/edgepillar/syrius/actions/runs/40018730800)
advanced into the first Pillar registration stepper and failed because its
isolated host lacked `SendTransactionBloc`. The earlier identity refusal did
not recur. The devnet startup, readiness and teardown steps passed; later
scenarios remain unqualified. Unchanged desktop builds and presentation checks
were disabled for this fixture-only follow-up.

### Native entry follow-up

The authored follow-up adds two independent, default-off Windows lanes. The
baseline lane records a bounded tool inventory, Windows doctor sections,
locked restoration, actual Dart test terminal counts, generated-file
correspondence and Debug/Release builds. It hashes the source and packaged
embedded libraries and maps each in a separate Dart process to look up
`RunNode` and `StopNode` without calling either export. Mapping can still run
DLL initialization; this is separate from node startup or chain qualification.

The entry lane builds the ordinary harness target in a fresh hosted profile.
It requires the original Windows process, controller, view and native window,
the actual first-show callback and a later native frame callback. Capture
retains a real renderer image through its original PNG encoding operation
while ordinary motion continues. Each attempt verifies the original entry,
service, theme and preference owners and awaits actual restoration.

Entry receipts require an explicit harness opt-in before startup. Ordinary
production entry retains no route, State or controller in the registry. Late
opt-in cannot adopt an existing entry session. An Import capture requires the
original Welcome action's untouched empty route; edits, file offers, picker
requests and source replacement revoke that proof. Restoration awaits the
original navigation, route transition and controller disposal.

The hosted controller admits only Welcome and empty Import in both themes at
1280 by 780 logical pixels. It verifies bounded PNG structure and actual
original process exit. Exactly four PNGs and a finite manifest may be uploaded;
partial failure keeps an `UNKNOWN` manifest. Profiles, tokens, private owner
identities and raw process output are excluded from these artifacts. These
captures would establish entry evidence, not visual parity or full-wallet
readiness.

The same batch gives each isolated registration stepper one owning
`SendTransactionBloc` provider while borrowing the original balance provider.
The host retains its sender through rebuilds and closes only that sender on
disposal. Production registration admission is unchanged.

The local follow-up pins 34 inputs, including 23 Dart files and the four
unchanged dependency/analyzer inputs. All 34 blobs match code commit
`5f9faeb37c820e8817b075f0bf9a2850b8fb41f5`. The managed evidence task closed
with outcome `SUCCESS`; the original command exited 0 with complete output,
and the retained output digest was verified. These results come from the
frozen source before that commit; source equality carries the evidence,
rather than a fresh execution at a publication commit.

| Check | Observed result |
| --- | --- |
| Formatting | 23 Dart files; exit 0 |
| Strict follow-up analysis | Zero diagnostics; exit 0 |
| Entry and registration-host gate | Six passed; no failures, errors or skips; exit 0 |
| Python controllers | 90 finite cases passed; exit 0 |
| Workflow semantics | Five documents; existing lanes preserved; new Windows lanes default off; five explicit artifact files |
| Focused lifecycle regressions | 350 passed; no failures, errors or skips; exit 0 |
| Root analysis with `--no-fatal-infos` | Zero errors, zero warnings, 1,314 infos; exit 0 |
| Diff check | Exit 0 |
| Full serial unit/widget suite | 4,051 passed, one existing skip; no failures or errors; exit 0 |

The six-case gate observes actual Navigator pushes before waiting for those
same routes to become visible. Provider teardown observes the original close
Futures through finite real-queue turns. Neither correction weakens original
ownership, late-opt-in refusal or disposal assertions. Earlier failed runs and
the complete output from a failed summary-record attempt remain preserved.

The owner selected the `docs/design/RULES.md` brand colours: green `#00D557`
and blue `#0061EB`. Applying those values to the shared palette is a separate
follow-up; it is not included in the qualified source above.

Hosted follow-up at `8b019e3eb6d701982729165ee13b668193e2329a` passed fork
Fast Validation with 4,051 tests and one existing skip. Its ordinary Windows
harness Debug build compiled the new owner hooks, but capture failed with
`SOURCE_REFUSED` and zero images. The retained artifact contains only an
`UNKNOWN` manifest. The independent baseline failed with `SOURCE_CHANGED`
before its inventory and doctor checks. The same source built Linux for
devnet testing, then failed the pillar stepper scenario; that retained failure
is under separate diagnosis.

The workflow-only commit `2f98e42b9a942734a54c902a390266903255ed60` sets
`core.autocrlf=false` before checkout in both new Windows jobs. A finite local
Git fixture verified that checkout policy and preserved genuine edit refusal;
it did not establish the cause of the earlier hosted failure. Both Windows
jobs in run 40035196304 attempt 1 now pass source admission and fail at later
gates. Baseline reports `DOCTOR_UNPROVEN`, with both required headings unknown
despite a complete exit-0 doctor command. Entry passes startup, authentication
and original window observation, then reports `COMMAND_FAILED` at
show-and-resize. Its verified source/run-bound artifact has zero captures and
an `UNKNOWN` manifest; original window restoration and process exit 0 were
observed without force. No images or full-wallet restoration have passed
these attempts. Target builder, Fast and blockchain runs for this
source were `action_required` with zero jobs at 2026-10-23T22:43Z.

## Native acceptance gates

| Required acceptance | Current evidence | Remaining gate |
| --- | --- | --- |
| Windows debug and release builds | Hosted builds passed at e67d0fab4c54; ordinary harness Debug compiled new owner hooks at 8b019e3eb6d7 | Follow-up Release, baseline and runtime qualification remain separate below |
| Windows baseline and embedded library | Hosted native builds at e67d0fab4c54 | Inventory, doctor, Windows Dart tests, generated-file correspondence and explicit library mapping/export checks at the follow-up source |
| Running native harness | Hosted isolated Welcome/empty-Import presentation passes; source adapters and injected tests | Complete native wallet startup, tour and original owner lifecycle |
| Isolated chain 321 send | Source scripts only | Producing owned devnet, imported harness-only profile and confirmed send |
| 47 screens in both themes | 47 scripts with final assertions | All 94 actual captures, comparisons and independent pair review |
| Motion, shaders and frame times | Finite widget and original-art cases | Running native build and baseline measurements |
| Disabled seams | Registry and injected control tests | Every native control, shortcut and Go to entry tried |
| Minimum window and RTL | Selected scaled/RTL widget fixtures | Complete native wallet at 1200 by 600 and Arabic layout |
| Restoration and cold startup | Conservative source guards | Original native owner, renderer frame pins and positive restoration receipts |

The macOS host has Command Line Tools without full Xcode. Windows desktop tools
and a usable Docker daemon are unavailable locally. The hosted results above
do not establish owner-machine provisioning. Signing, real-wallet operation,
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
(`#00D557`, `#0061EB`). The owner selected the design-rule values. The palette
follow-up applies that decision while retaining the original references.
The shared green also supplies dark-theme ZNN ink; the separately defined
blue inks and light-theme green ink retain their reference values for
readability. Visual review must account for these approved colour changes;
source-token checks do not establish visual parity.

## Recipe, lab-policy and confirmation follow-up

Implementation commit `be6a7612aa364dd48e72b54e21a402a464de58ff` follows
`2f98e42b9a942734a54c902a390266903255ed60`. Its 22 implementation files and
eight protected inputs are byte-identical to the final 30-input local source.
The successful task finished before the commit; exact raw blob equality carries
these results to the commit rather than claiming fresh execution there.

| Fresh local check | Observed result |
| --- | --- |
| Formatting | 11 Dart files; exit 0 |
| Strict follow-up analysis | Zero diagnostics; exit 0 |
| Python controllers and lab policy | 183 passed; exit 0 |
| Recipe and confirmation regressions | 65 passed, zero skips, failures or errors; exit 0 |
| Root analysis with `--no-fatal-infos` | Zero errors, zero warnings, 1,314 infos; exit 0 |
| Diff check | Exit 0 |

The original command exited 0 with complete, rehashed output. Its protected
stdout is 277,259 bytes, SHA-256
`175dc927efac71377dece0730aa5edd668a3dedc2cd80a47f983be6e3a65d26b`;
stderr is empty. Positive task closure and cleanup of its own registered
scratch completed. Earlier failed and interrupted attempts retain their actual
outcomes. The unchanged 55 parser checks, 49 manifest-contract checks and 387
unaffected focused cases retain separate earlier source-bound evidence. The
separate palette task passed 37 theme cases. The older 4,051-case full-suite
result above is not a fresh full-suite result for this follow-up.

The owner-selected green `#00D557` and blue `#0061EB` now apply to the shared
palette. Original references and theme-specific readable inks are preserved
as described above. No actual screen match follows from token checks.

The harness recipes require original context and finite completion before
another action. Registration fixtures retain their original sender operation
and require exact confirmation and effect observations before advancing.
These 31 offline confirmation cases do not qualify native registration; the
two earlier Sentinel pre-deposit reads remain the separate X153 follow-up.
Production admission and publication guards remain unchanged.

The injected owned-lab supervisor has no actual build or Docker/storage
adapter: default admission remains `BUILD_UNKNOWN`, and seed admission remains
false. Its direct socket boundary passed 42 cases, including three actual
local socket-mechanics cases; those cases establish no TCP node, producing
chain 321, checkpoint or wallet send. Native build and owner capabilities
remain separate requirements in `docs/testing/owned-lab-admission.md`.

Windows doctor-prefix parsing and schema-2 finite entry diagnostics passed
their offline cases. Their repair of the earlier hosted failures requires a
new exact-source run. CI commit
`e2a2dd648e17c512f93a2040b94d044e9d6ff52c` adds only one finite Python test
step to PR Fast Validation. The actual Ruby semantic check verified all five
workflow documents, the preserved `dev` filter and existing Flutter and
generated-source behavior. Its original command exited 0 with complete,
rehashed output, genuine `SUCCESS` closure and positive owned cleanup.
All 34 selected raw inputs match that commit. This is workflow semantic
qualification; no new hosted execution is claimed here.
