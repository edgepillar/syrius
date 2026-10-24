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

At publication head `423e9e02299fbfc280fe6f3fd977c0682213b585`, fork Fast
Validation 40050561068 attempt 1 completed successfully: Python, both analysis
steps, all 183 Python checks, 4,116 unit/widget tests with one existing skip,
and generation consistency passed. Its complete retained log has 1,081,265
bytes and SHA-256
`27a1cadede49de66a2029db96d40a8c59c7f9b0842273592bbfc4b043aa83700`.
The retention task closed `SUCCESS` with positive owned cleanup. In scoped
run 40050598248, the ordinary Windows harness Debug build and finite
controller tests passed, then real entry capture failed. Devnet also failed.
The complete retained Windows baseline log has 38,319 bytes and SHA-256
`530f5a74b2e2a834462838535534deca5672e8f31c145db6f9f4ba42280e1a98`;
its retention task closed `SUCCESS` with positive owned cleanup. All 12
baseline checks passed: Windows desktop doctor, locked restoration,
Debug/Release builds, root and vendored analysis, 4,115 unit/widget tests
with two skips, generated correspondence, and separate source/Debug/Release
DLL map/export probes. Each required child exited 0 with complete bounded
output and no forced termination. Root analysis retains 1,314 infos and no
error or warning; vendored analysis has zero diagnostics. All three DLL
digests equal
`f1f79ee184b9c0e3cd92d2f5c49e52c68e7a4670357a0cf1df95a0ac6de8973a`.
Mapping and export lookup establish no wallet loader call, node startup or
ABI behavior.

The overall baseline job still failed afterward: the executed Flutter action
`1a449444c387b1966244ae4d4f8c696479add0b2` failed while evaluating its
recursive pub-cache lockfile hash in the post-step. The locally qualified
follow-up `8861f95eb1f3` retains SDK caching and uses one explicit pub-cache
step keyed by the two committed lockfiles. It addresses the observed failure
point; its hosted behavior and the underlying directory-walk cause remain
unqualified.
Target Fast 40050516638, builder 40050516614 and
blockchain 40050516655 require maintainer approval and have zero jobs, as
observed at 01:38Z. Fork results remain separate from that target gate.

The source/run/attempt-bound entry artifact and complete job log are retained.
The first entry failure is `CLIENT_RESIZE_UNOBSERVED`: after five attempts,
the requested 1280x780 client remains 1184x749, with physical 1184x749,
outer 1200x788 and device-pixel ratio 1. There are zero captures. The original
process exit 0, output completeness and original window-geometry restoration
were observed; entry restoration and native capture acceptance remain
unproven. The small retained archive has SHA-256
`894209080b2edf5a9d020a0247ac694939f6c8af2a47cda6b47f715853854c70`.
A harness-only tracking-bound change and its six new offline fixture cases
are qualified in local commit `40466630ead4`, as detailed below. Windows
tracking limits are a candidate explanation;
the actual desktop cause is not established.

The complete devnet log reaches the exact original submitted pillar hash,
then times out while polling that hash, before block-field or registry
assertions. This establishes neither confirmation nor rejection. The
original operation and hash remain preserved; there is no resend or new
signing attempt. A finite observer using the captured original context is
applied under separate local qualification. Its actual hosted behavior is not
qualified by this log.

The first separate X153 qualification task closed `FAILURE` with `UNKNOWN`
boundary evidence and no launched qualification command. Its original
negative result and owned cleanup are preserved. The fresh reviewed batch
passed the same five gates in one managed command, freezing 11 source inputs
immediately after formatting: strict analysis has zero diagnostics; all 47
confirmation cases pass with zero skips, failures or errors; root analysis
has zero errors or warnings and 1,314 infos; the diff check is clean.
The original worker exited 0 with complete retained output, SHA-256
`53e6c8f933aa4b787debfaed5892bf1920fda7e94531f1c6a4c7bbe2ec8db620`
and 272,518 bytes. Independent replay, genuine `SUCCESS` closure and positive
owned cleanup were verified. Local anonymous commit
`e39e8ed4d99dbd9087ed1b3a4524bd9426f5923c` carries all 11 exact raw inputs;
these local results do not claim a new hosted or native result.

The first separate tracking batch completed all five gates and closed
`FAILURE` with positive owned cleanup. Formatting, zero-diagnostic strict
analysis, root analysis and the diff check passed; seven visible cases and
two hidden loading checks passed, while four new refusal cases hit a Flutter
`pump`/`expectLater` guarded-API conflict. Their original negative evidence
remains preserved. The corrected fixture awaits the original command before
matching its retained error. The fresh source-bound batch passed all eleven
visible cases and two hidden loading checks, zero-diagnostic strict analysis,
root analysis with zero errors or warnings and 1,314 infos, formatting and the
diff check. Its original worker exited 0 with complete retained output:
252,536 bytes, SHA-256
`7f894e8e8c9810326cc11d899f6e88e1db590cf1b9deea916d6decd83a697ff3`.
The task closed `SUCCESS` with positive owned cleanup. Local anonymous commit
`40466630ead4646834eb127848d1bb2f329ff0bf` carries all twelve exact raw
inputs. These offline fixtures establish no native Windows cause or capture.

The first separate Pillar-observer batch completed all five gates and closed
`FAILURE` with positive owned cleanup. All 38 visible cases and three hidden
checks passed without skips, failures or errors; formatting and the diff
check also passed. Strict analysis reported eleven infos, and root analysis
reported zero errors or warnings and 1,324 infos. The complete original
output is retained: 272,614 bytes, SHA-256
`451a6e10ea908536db9e46c80d762098c987cf39df40bb4bb8bb2200afebc227`.
The second separate batch again passed all 38 cases and three hidden checks,
formatting and diff, but strict analysis retained two infos: the existing
BDD ignore needed its explanation restored, and a fixture cascade needed to
join its original initializer. Root analysis reported zero errors or
warnings and 1,315 infos. Its complete original output is retained: 268,424
bytes, SHA-256
`a2dac3ce68f3833590a460ff36d88f3f79322f5753998aa23f3f34a7029bac7a`.
It closed `FAILURE` with positive owned cleanup. After these two failures,
the remaining two-file lint cleanup was split into X157. The scoped
batch below formatted only those two files and kept the other ten inputs
unchanged even during formatting. It required four-file strict analysis and
all 38 regressions. Both earlier results remain negative evidence.

The fresh X157 batch passed two-file formatting, four-file strict analysis
with zero diagnostics, all 38 observer cases and three hidden checks with
zero skips or errors, root analysis with zero errors or warnings and 1,313
infos, and the diff check. The other ten source hashes remained unchanged
even during formatting. Its original worker exited 0 with complete retained
output: 267,524 bytes, SHA-256
`a394bc3bcb9c3ea4dfbfa44530fce49d574f9faad0341a17c248d8c70cec247c`.
Independent replay, genuine `SUCCESS` closure and positive owned cleanup
were verified. Local anonymous commit
`584428b0e15aa805fd8449e93887d2f6366bd221` contains the four changed paths
and all twelve exact qualification inputs. The following workflow-only cache
change has separate semantic qualification; no new hosted outcome is
inferred from these offline observer results.

The first cache qualification was refused before any task or command was
created because its private project identifier exceeded the storage
manager's length limit. Its `UNKNOWN` record is preserved; no successful
closure or cleanup is claimed for that refused admission. All 22 source
hashes still match its admission snapshot. A separately reviewed attempt
uses a shorter identifier and retains the same Ruby semantics, source pins,
quotas and free-space floor.

That fresh attempt passed the real Ruby comparison of all five workflow
documents. Only the baseline cache steps changed: SDK caching remains
enabled, pub dependencies use the two explicit committed lockfiles, and the
qualification commands and `dev` PR filter are preserved. The original
command exited 0 with complete retained output: 268 bytes, SHA-256
`ea7e7656f18bd35dd181e340d2dde1afda6b01de6c7f73c5acb5a8543a5ce295`.
Independent source, argv, output and closure checks passed; the task closed
`SUCCESS` with positive owned cleanup. Local anonymous commit
`8861f95eb1f30a1fbedc931df2ccf1431e5749d5` contains only that workflow delta
and all 22 final selected raw source inputs. The ten selected Dart files
remain unchanged by this workflow-only commit. This semantic check runs no
tests or hosted CI; the fresh hosted cache post-step remains pending.

## Follow-up qualification on 2026-10-24

At `87228af165671e8471250db19f85ea871d5addce`,
[fork Fast Validation 40058695755](https://github.com/edgepillar/syrius/actions/runs/40058695755)
attempt 1 passes all 183 Python cases, both analysis steps, 4,176 unit/widget
tests with one existing skip, and generation consistency. Root analysis has
zero errors, zero warnings and 1,313 infos; vendored analysis has zero
diagnostics. The complete retained job log has 1,091,081 bytes and SHA-256
`8b847693e141cb22e0c32ff9c1a4a8d221439d90f2760e6ab504521194c044a3`.
Its original transport exits 0 with complete output; independent source,
CAS, genuine `CLOSED/SUCCESS` and positive owned-cleanup checks pass.

In [scoped run 40058701466](https://github.com/edgepillar/syrius/actions/runs/40058701466)
attempt 1, the complete Windows baseline job succeeds, including all cache
post-steps. Its retained log has 39,299 bytes and SHA-256
`7bac9ddf59b38e45a5a6136b005dceb348ecfdaf7c3bc61db713c1eb1dab2c3e`.
All twelve controller checks pass: Windows desktop doctor, locked dependency
restoration, root and vendored analysis, unit/widget tests, generated-file
correspondence, Debug and Release builds, and source/Debug/Release library
hash and map/export checks. Every required child exits 0 with complete
bounded output, without overflow or forced termination. There are 4,175
visible passed tests, two existing skips, 497 hidden terminal events and
4,674 total terminal events, with no failures or error events. Root analysis
retains 1,313 infos and zero errors or warnings; vendored analysis has zero
diagnostics. All three library digests remain
`f1f79ee184b9c0e3cd92d2f5c49e52c68e7a4670357a0cf1df95a0ac6de8973a`.
The original retained command, object ledger, free task lease, genuine
`CLOSED/SUCCESS` and owned cleanup were independently verified. This
qualifies the cache follow-up's hosted post-steps; the earlier failure's
directory-walk cause remains unproven. Library mapping and export lookup do
not establish node ABI invocation, wallet startup or owner-machine behavior.

That same scoped run fails ordinary entry capture and devnet integration.
The six-build matrix and isolated presentation lane are disabled by input.
The complete entry log has 48,905 bytes and SHA-256
`8b8998014a4e33f129cc5bafd707dbfee5c2e7bfd5b7a239dcc1ecfe0dfd01f0`.
The retained source/run/attempt-bound artifact contains only its finite
manifest: requested client matching, original window-geometry restoration,
original exit 0 and complete output are positive. The first capture is
refused as `PNG_INVALID`; no image is retained and entry restoration remains
unproven. A later `ENTRY_INVALID` response is consistent with the incomplete
capture count; it does not independently prove a restoration defect. The
complete devnet log has 329,410 bytes and SHA-256
`b9eefa81ff2ae892bdc081fd33c88dc1966f5ae3429a2f7fcd2eb395ef1c77a1`.
Its first stake fixture lacks `SelectedAddressNotifier`, before stake
submission; source review also identifies its removed dropdown selector.
Both log-retention tasks closed `SUCCESS` with positive owned cleanup. These
failures establish no new Pillar or Sentinel confirmation outcome.

Target Fast 40058610232, builder 40058610245 and blockchain 40058610231
remain `action_required` with zero jobs, observed at 03:33Z. Fork execution
does not satisfy that maintainer gate. The owner has no Windows test session
available at present. All 94 actual screen/theme comparisons, independent
visual review, owned lab checkpoints, motion, frame-time and seam acceptance
remain pending.

### Bounded PNG channel precision

Published anonymous commit `edecd9b3465feea6dd9a0bf47904a6902fcdc76a` admits
exactly one standard pre-IDAT `sBIT` chunk, with three RGB or four RGBA channel
values in 1..8. CRC, dimensions, bounded decompression, scanline validation
and text/profile/unknown-metadata refusals remain enforced. Six new test
methods cover 55 variants; all 189 Python CI cases pass without skips,
errors or contradictory verdicts. The original command exits 0 with complete
output; its 289-byte stderr digest is
`c8547c2584f926b354a721564274a885e07f0a86962a0a0b6e4e0ff610376853`.
Independent replay verifies all 21 pinned raw inputs, genuine
`CLOSED/SUCCESS`, owned cleanup and the preserved original checkout.

The pinned Flutter framework
[`abaf9c523780a608bd46686fd5e53740a07077f8` PNG encoder](https://raw.githubusercontent.com/flutter/flutter/abaf9c523780a608bd46686fd5e53740a07077f8/engine/src/flutter/lib/ui/painting/image_encoding.cc)
uses Skia's default PNG encoding options. Its
[`DEPS` pin](https://raw.githubusercontent.com/flutter/flutter/abaf9c523780a608bd46686fd5e53740a07077f8/DEPS)
selects Skia `8df24be66531469e576a806749a0202ae26b8d08`, whose
[`SkPngEncoderImpl.cpp`](https://raw.githubusercontent.com/google/skia/8df24be66531469e576a806749a0202ae26b8d08/src/encode/SkPngEncoderImpl.cpp)
emits channel precision through `png_set_sBIT`. The admitted shape and
placement follow the [PNG specification](https://www.w3.org/TR/png-3/).
These pinned sources establish a producer/consumer compatibility mismatch;
the rejected hosted image bytes were not retained, so their exact failing
chunk remains unproven. The fresh native outcome is recorded below.

The normal push independently verifies the exact two-file commit delta,
all 21 qualification inputs, anonymous UTC author and committer headers,
unchanged original checkout, fork permissions and Draft PR target. Pending
Dart repairs are excluded from the published tree. Entry-only fork
[run 40062851700](https://github.com/edgepillar/syrius/actions/runs/40062851700)
attempt 1 succeeds at that exact head; all other scoped qualification lanes
are disabled. Its complete 48,293-byte log has SHA-256
`79b9237b3b5639e987cbc50087c7e35a934e2102cb345bd0536df42ce4a49dc1`.
The original retention exits 0 with complete output and genuine
`CLOSED/SUCCESS/CLEANED`. The finite schema-2 report passes all 18 checks,
including exact client matching, both window and entry restoration, and
original exit 0 without overflow or forced termination.

Artifact 12547993546 contains four genuine 1280 by 780 PNGs and one finite
manifest. Its 2,295,836-byte archive has SHA-256
`512dcca850d0e54dcda47131da29d6ba4271a9734f4ce40d760546ac6da062c0`;
the 1,530-byte manifest has SHA-256
`9b91f5b18fec715011a2008a7eb213769e65d1e0d50fed598f9c15d3721147a9`.
Independent verification checks fresh GitHub artifact identity and digest,
all explicit archive members, each individual retained image, the bounded
PNG parser, exact agreement between the manifest and complete job log, and
the original source, task, object ledger, free lease and absent process
group. That retention also genuinely closes `SUCCESS` with owned cleanup.
No archive is repackaged and no build binary is downloaded.

Limited independent inspection of the four entry pairs identifies a
source-confirmed entry backdrop mismatch, the reference's separate 32px
client titlebar contract, and Import component geometry/border differences.
These are tracked as X163-X165. The shorter truthful Welcome import hint,
empty seed example data, approved brand accents and possible font hinting
are distinguished from defects. The globe continues rotating; a different
pose alone establishes no animation defect. Four retained captures do not
qualify the complete compare page, motion, frame-time or native controls;
90 other actual captures and all 94 visual matches remain pending.

### GeneralStats disposal candidate

The first candidate preserves the four original SDK reads while preventing
their late completion from restarting polling after disposal. Its ten offline
regressions and one loading check pass without skips, errors or failures;
formatting and the diff check pass. The candidate fails strict analysis with
seven infos in the new test. Root analysis has zero errors, zero warnings and
1,316 infos. The original worker exits 1 with complete retained output:
253,045 bytes, SHA-256
`b18d297e31392cbb2c30cdebd35485158c75902ef2b257dfeb4e6e46a253fd10`.
Independent replay verifies those stage results and source preservation.
The task genuinely closes `FAILURE`; isolated analyzer state remains under
storage `HOLD`, so the original overall closure stays `UNKNOWN`. No cleanup
is claimed. Six tearoff changes and one brace fix are applied only to the
new fixture as inputs to a fresh second qualification.

The fresh second attempt qualifies local anonymous commit
`f5b503afd2644cb7fe486dbc7e497db6229efbf9`. All ten GeneralStats regressions
and one loading check pass without skips or errors. Both changed files have
zero strict diagnostics; root analysis has zero errors, zero warnings and
1,309 infos. Formatting and the diff check pass. All five original stages
exit 0, and the complete 250,523-byte output has SHA-256
`07398f6f72a6ce1275fb1b258fce045b1bcaf9cd8a66d38013f5ff44f9527c44`.
Independent replay verifies the ten raw source pins, original command and
streams, genuine `CLOSED/SUCCESS`, a free task lease, and absence of the
original process group. Isolated analyzer state remains under storage
`HOLD`; it is preserved and no cleanup is claimed. The anonymous two-file
commit preserves the original checkout. The first failure and its original
`UNKNOWN` closure remain unchanged. This scoped result does not qualify the
full suite or native acceptance.

### Original wallet signing fixture compatibility

The first original wallet signing candidate reaches all five finite stages,
but the new fixture uses a `group` timeout argument unsupported by Flutter's
compatibility API. Strict and root analysis each report that one error; the
34 regression cases do not execute because the file fails to compile.
Root analysis retains 1,301 infos and zero warnings. The original command
exits 1 with complete 245,923-byte output, SHA-256
`6b6ece2df067ad19b96e265696cf568e4c1fb1c6817949df0581202a3ffde1f5`.
Independent replay verifies the source pins, all recorded stage outcomes,
genuine `CLOSED/FAILURE`, free lease and absent original process group.
Isolated analyzer state remains under storage `HOLD` without cleanup.
Only the unsupported group argument is removed for the fresh second
attempt; the original CLI timeout remains. The failed source is exactly
reconstructable from the preserved delta.

The second attempt qualifies local anonymous commit
`8f22be1456767e0dc85e86d9abb939f0103c149a`. All 34 offline signing
regressions and one loading check pass without skips or errors. The three
changed files have zero strict diagnostics, and root analysis has zero
errors, zero warnings and 1,301 infos. Formatting and the diff check pass.
All five original stages exit 0; complete 259,669-byte output has SHA-256
`65b43f60b85ef29b2ffd87ab991a5a551713f4b69f22b462ebdcd739a4e41ec7`.
Independent replay verifies all eleven raw source pins, the original
command, complete streams, genuine `CLOSED/SUCCESS`, a free lease and
absence of the original process group. Isolated analyzer state remains
under storage `HOLD`; no cleanup is claimed. The exact three-file commit
has anonymous UTC headers and preserves the original checkout. It retains
original wallet and account ownership, immutable message bytes, acquired
file closure and settled results across delayed operations. These offline
results do not qualify hardware, live wallet signing or delivery; retaining
a result does not authorize a replacement signature or retry.

### Stake fixture scoped analysis

The first provider and Segment-duration repair passes all three offline
ownership/render regressions and one loading check. Strict analysis finds
three infos: two long BDD comment lines and one test-only error-catching
lint. There are no scoped errors or warnings; root analysis has zero errors,
zero warnings and 1,300 infos. Formatting and the diff check pass. The
original command exits 1 with complete 246,574-byte output, SHA-256
`1e2abc8dc9937351f0f2b797f14c5ba3c6d4ec2d6f5633c90a7215562b85f1af`.
Independent replay verifies all eleven raw pins, the five original stage
results, genuine `CLOSED/FAILURE`, a free lease and absence of the original
process group. Isolated analyzer state remains under storage `HOLD`
without cleanup. Two comment wraps and an equivalent exact-error matcher
prepare a fresh second attempt. The failed source and complete evidence
remain preserved; these passing offline cases do not qualify hosted
devnet behavior or a real stake.

The second attempt qualifies local anonymous commit
`71143c49b3e418e776061776196e22d7c857ce7b`. All three regressions and one
loading check pass without skips or errors. The three scoped files have
zero diagnostics; root analysis has zero errors, zero warnings and 1,297
infos. Formatting and the diff check pass. All five original stages exit 0
with complete 245,134-byte output, SHA-256
`c74cfebd2290c662d3f8444c7a8863ee7220201af7bb722e89db1ccbe64ab74b`.
Independent replay verifies all eleven source pins, original command and
streams, genuine `CLOSED/SUCCESS`, a free lease and absence of the original
process group. Isolated analyzer state remains under storage `HOLD`
without cleanup. Original balance and transaction assertions remain intact;
this local fixture result does not qualify hosted devnet behavior.

### Entry and desktop geometry source follow-up

The held Windows frame candidate preserves the existing window manager,
Navigator, modal subtree and shutdown owner. It adds a genuine 32px client
caption with 44px accessible controls; macOS and Linux retain their native
caption and existing body layout. Its 32 authored offline cases have not
executed. Generated localization parity, source analysis, test results,
native controls, DPI behavior and fresh captures remain separate gates.

Pinned button-resolution source also shows that desktop compact density
subtracts 8px from ordinary `PrimaryPill` minimum heights. Existing measured
tests use the default Android test platform, so those results do not cover
that desktop reduction. Tight external Lock and Send constraints preserve
their requested height. Held shared-component, Receive and Home secondary
candidates add measured compact desktop cases. Receive's companion keeps
both actions at the reference's 38px ordinary height and 30px QR-expanded
height; Home's companion retains 38px secondary controls. These companions
must accompany the shared change. Further local repairs target explicit
26px chips and secondary controls and the 30px Collect all action. Shared
modal and Accelerator height differences remain separate decisions. No
screenshot match or runtime result is inferred from this source inventory.

### WalletConnect text-policy admission

The first offline qualification attempt was refused by shared scratch
capacity before a task or command was created. No tests ran and no passing
result exists for that attempt. Its UNKNOWN record and unchanged source
remain preserved. Read-only sizing of comparable completed narrow batches
measures approximately 96-130MiB of final logical scratch; these figures do
not measure peak allocation. A fresh scoped attempt uses a 1GiB task limit,
over seven times the largest comparable final size, with the same existing
SDK, packages and bounded output. Shared quotas, the physical free-space
floor, original tasks and storage runtime remain unchanged. The manager
still enforces admission and the complete allocation limit; no cleanup or
quota increase is inferred from the new plan.

The fresh attempt qualifies local anonymous commit
`555ed3d0ca461c02617a0270aa1e40301422d4c6`. All 13 regressions and three
loading checks pass without skips, failures or errors. The test file has
zero diagnostics; the production file retains its exact 44 inherited
infos. Root analysis has zero errors, zero warnings and 1,297 infos.
All six original gates exit 0 with complete 259,903-byte output, SHA-256
`d7c3ba2ca0d9215e5ab9d69949dc37e7feafd4a9be3ec767c073119ab4bb6267`.
Independent replay verifies ten raw source pins, the original record and
streams, genuine `CLOSED/SUCCESS`, a free lease and absence of the original
process group. The task's actual expected and quota limits are both 1GiB.
Isolated analyzer state remains under storage `HOLD` without cleanup. The
first admission's UNKNOWN evidence remains intact. These offline results
do not establish live wallet signing or hosted behavior.

### Combined repair-suite qualification

The combined local source at
`555ed3d0ca461c02617a0270aa1e40301422d4c6` passes the complete serial
Flutter test suite: 4,226 visible successes, 500 hidden successes, one
existing skip, and no failures or error events. Independent event replay
verifies the exact skipped receive-block case in
`test/dapp_bridge/dapp_bridge_parity_test.dart`; no new skip is accepted.
Formatting, strict analysis of the nine repaired Dart files, root analysis
and the diff check also pass. Strict analysis has zero diagnostics; root
analysis has zero errors, zero warnings and 1,297 infos.

All five original stages and the original producer exit 0 with complete
output. The retained 2,724,670-byte stdout has SHA-256
`b59bfa4652c03634dcb5af37f753a6fc71afa2f8428521c7d4793aaec71f13a5`;
stderr is empty. Independent replay verifies all 24 immutable source pins,
the original command, complete streams, intent and preclose records,
genuine `CLOSED/SUCCESS`, a free lease and absence of the original process
group. The existing checkout and all earlier failures remain preserved.
Analyzer state remains under storage `HOLD`; no cleanup is claimed.

The new task's expected and quota limits are both 1,536MiB. This was an
explicit unproven allocation candidate, not a measured peak. The shared
storage policy, 10GiB free-space floor and historical tasks are unchanged.
The manager admitted the new task and enforced its allocation limit.
These local results do not establish fresh hosted devnet behavior, native
Windows integration, live wallet signing or a visual match. The four
verified ordinary entry captures remain pinned to `edecd9b3465f`.

### Held UI follow-ups

The first held UI group combines 37 paths for the entry background, Import
component geometry, genuine Windows client caption and local compact
button sizing. Exact source composition and overlap checks are complete;
formatting, generation parity, analysis and its selected tests remain
pending. Its shared PrimaryPill change includes Receive and Home
companions for qualification with their actual desktop callers.

A later disjoint 21-path group aligns shared ordinary, small and xs
neutral styles, Staking and Plasma Close, Plasma Cancel, Accelerator,
Node Update and the remaining Transfer controls. It preserves original
callbacks, warnings, busy and ownership guards, and the legacy explicit
LoadingButton minimum. Its one known inherited import-order info has a
mechanical prepared repair. The expected 117 visible cases and eleven hidden
checks are source-derived inventories, not executed results. Whole-Plasma
page appearance and native reference matching remain unqualified.

The separate held entry-caption observer adds four original-action
observations after the four ordinary captures. It preserves the original
eighteen checks, original operation Futures, one absolute deadline and
one ordinary quit. Maximize and caption restore wait for the next retained
control to become enabled; minimized observation never requires a painted
frame. Fifteen Dart cases and thirteen additional Python methods remain
unexecuted. An artifact's preclose evidence-contract acceptance is kept
separate from genuine retention closure; a positive independent post-run
receipt is required before any publication claim. None of these held
candidates qualifies native motion, frame times or the complete 94-pair
visual acceptance.

### First combined UI qualification

The first exact 37-file candidate on publication parent
`da402c9b44a4442b26396c0ec4a7dca7c3b0c19d` has a verified negative
closure. The index remains unchanged; all 54 post-format raw inputs and a
reconstructable source patch are preserved with the complete original
output. The managed task is genuinely closed with FAILURE and the known
analyzer scratch HOLD; the lease is free and the original process group
is absent. No held scratch was cleaned.

Formatting exits 65 because one window fixture contains nullable-void
Future syntax. Strict analysis reports fourteen errors, two warnings and
67 infos, including a second fixture's incorrect cascade receiver. The
test stream records 148 visible and sixteen hidden successes, two window
loader errors and two light/dark scaled stake Cancel overflows of 14px.
Its terminal result is invalid, so this is a failed qualification.
Localization generation parity and the diff check pass. Root analysis
reports fourteen errors, two warnings and 1364 infos.

Narrow source corrections and the hidden lifecycle inventory are being
reviewed before a fresh attempt. The original fifteen-hidden expectation
is retained as part of the failed evidence and will not be rewritten.
The actual 1GiB task limits preserve existing policy and historical tasks;
they are not a measured peak. No UI publication or native match is claimed.

At 07:22Z, the current-head GitHub API reports Fast 40072506196 successful
and devnet-only 40072557304 failed at its integration step, both attempt 1.
Complete-log retention and independent verification remain pending.

The reviewed window and stake corrections are now applied with exact raw
hash equality and an unchanged index. The corrected candidate has 38 changed
paths, including the additional CancelStakeButton constraint companion,
36 Dart files, six new files and seventeen protected inputs: 55 raw pins.
Its existing scaled stake cases additionally assert the same cancellation
provider, actual horizontal cell bounds and the declined original amount
confirmation with no SDK access or refresh replay.

Pinned runner source explains the corrected expected inventory of 182
visible and eighteen hidden successes: twelve loaders, three setup-all
hooks and three synthetic teardown-all hooks. The original failed
expectation and results are preserved. A fresh managed six-stage attempt
is prepared with the same 1GiB candidate, output/time limits and production
floor. Admission is pending while another active process holds the shared
metadata lock; that process and all historical data remain untouched.

The first two private log-retention wrappers lose their capture records
because their caller incorrectly unpacks a two-value return as three.
Subsequent reconciliation retains the exact registered bytes under their
original task and artifact leases. Both tasks are independently verified
CLOSED with FAILURE and CLEANED scratch. Original command receipts remain
unchanged: Fast records exit 0 and complete output, while devnet transport
exit and completeness remain UNKNOWN. Neither failed local lifecycle is
converted to success from observed CI. No transport is repeated.

### Second combined UI qualification

The corrected 38-path candidate has a verified negative closure with all
55 post-format raw inputs and complete original output preserved. Formatting,
localization parity, strict analysis and diff checks pass. Strict analysis
has zero diagnostics; root analysis has zero errors, zero warnings and
1297 infos. The task is genuinely CLOSED with FAILURE and the known analyzer
scratch HOLD. Its lease is free and its original process group is absent.

Tests report 167 visible and eighteen hidden successes, fifteen frame errors
and no skips. All seventeen controller cases, scaled stake cases and other
UI cases pass within that failed group. Four frame cases report platform
override lifetime violations. Eleven mounted Windows cases report missing
caption Tooltip Overlay ancestry; production has the same frame-above-
Navigator topology. Three additional assertion failures remain preserved
without assuming that an Overlay repair resolves them.

Separate platform-lifetime and production Overlay repairs are in review.
After two failed combined attempts, the next qualification separates the
32 window cases plus two loaders from the remaining 150 UI cases plus
sixteen hidden lifecycle checks. Both gates retain their original assertions
and share one managed allocation. Metadata-intensive operations are queued
until original log promotion and task closure finish. No fresh qualification,
native behavior, visual match or UI publication is claimed.

### Split UI qualification

The third attempt preserves all 55 raw inputs and complete 371887-byte
output with a genuine CLOSED/FAILURE outcome and analyzer scratch HOLD.
Independent replay verifies its free lease and absent original process
group. Formatting, localization, the remaining-UI gate, root analysis and
diff checks pass. Strict analysis reports only one redundant import;
root analysis has zero errors, zero warnings and 1298 infos.

The separate remaining-UI gate passes all 150 visible tests and sixteen
hidden lifecycle checks. The window gate passes 29 visible tests and two
loaders, with three errors and no skips. Retained output identifies a real
text-input regression: LookupBoundary hides the inherited View from the
original body. The other two failures identify a tooltip assertion on an
outer semantics node and an undrained original 40 ms double-tap timer.

A separate caption Overlay that is a sibling of the original body is being
prepared. It must retain body View identity, root Overlay bounds, original
Navigator and modal ownership, pointer delivery and all original actions.
The fixture correction must preserve every accessibility requirement on
its actual semantics node and drain the original finite gesture timer.
The three failed attempts remain preserved; no successful combined UI
qualification, native match or publication is claimed from them.

### Fourth UI qualification and keyboard focus correction

The fourth attempt preserves all 55 raw inputs and complete 358102-byte
output with a genuine CLOSED/FAILURE outcome and analyzer scratch HOLD.
Independent replay verifies the original closed task, retained streams, free
lease and absent original process group. Strict analysis has zero diagnostics;
root analysis has zero errors, zero warnings and 1297 infos. The remaining-UI
gate passes 150 visible tests and sixteen hidden checks. The window gate passes
31 visible tests and two loaders with one error and no skips.

The body-first Stack and sibling caption Overlay retain original View identity,
root body Overlay bounds, text input, pointer delivery, Navigator and modal
ownership. Tooltip assertions now inspect the actual annotation node, and one
finite gesture-clock pump drains the original timer. The sole remaining error
assumes that initial Tab must focus Minimize even while the body Navigator
owns initial focus. A fixture-only correction establishes focus through the
original supported semantic focus action, then requires Tab and Shift+Tab to
round-trip before the unchanged Enter, Space and native operation assertions.
All four negative attempts remain unchanged. This correction enters a fresh
seven-gate qualification; no positive result or native match is inferred.

### Isolated keyboard follow-up

The fifth UI attempt also closes FAILURE with retained analyzer scratch HOLD.
All 55 source inputs and complete 358181-byte output are independently verified;
stdout SHA-256 is `db69d9dba5e52b25bc6e13f4010871542019d87adbb65600e0cccc73e1b5afe4`.
Strict analysis remains at zero diagnostics, the remaining-UI gate passes
150 visible plus sixteen hidden checks, and the window gate passes 31 visible
plus two loaders with one error. Root analysis has zero errors, zero warnings
and 1297 infos. The original task, free lease and absent process group are
verified without repeating tests or changing its outcome.

The actual failure is the first focused-state assertion after the supported
semantic focus action, before Tab or native activation. A separate one-case
probe replaces the three single focus pumps with the fixture's existing finite
settle and requires the original Minimize FocusNode and semantics to agree.
Every original accessibility, traversal and native operation assertion remains.
The first probe's result is described below. All five negative full attempts
remain preserved.

The first one-case probe reaches framework end-of-test verification after the
original focus, traversal, Enter, Space and native call-count assertions. Its
only reported error is an active SemanticsHandle: the registered addTearDown
disposal occurs too late for that verification. This remains a genuine
CLOSED/FAILURE with complete 2961-byte stdout, SHA-256
`e4618f364a23b26b3b02c3e47d982fa2af5bef2dfe7fff0d00a2d625a35f34a9`,
a free lease, absent original process group and retained scratch HOLD.

The separate correction disposes that same handle in a test-body finally block.
Every original statement and assertion is preserved except the late disposal
registration. The second one-case probe passes one visible case and one loader
with zero errors, failures or skips, actual exit zero and complete output.
Its CLOSED/SUCCESS outcome, free lease, absent original process group,
unchanged 55 raw source inputs and retained scratch HOLD are verified. The
1384-byte stdout has SHA-256
`b3cb063526a12ec65f532986005977ccb4f816dfe81731514b827f1c02a83f6f`.
This fixture correction has no production-code delta. The later full UI group
has its own independent result, described below.

### Qualified UI surfaces and original window controls

Anonymous commit `579ce016618a79439bcb42ea9289399bb1ab266e` contains the 38
qualified UI paths. Its fresh seven-gate group passes formatting, localization
parity, zero-diagnostic strict analysis, all 32 window cases plus two loaders,
all 150 other UI cases plus sixteen hidden checks, root analysis with zero
errors, zero warnings and 1297 infos, and the whitespace check. There are no
test errors, failures or skips.

All 55 raw source inputs match the commit. The original command exits zero
with complete 356429-byte stdout, SHA-256
`108c715fec0d3221674684aa7c16bf605c8b5962a7978273e80f65f2c93877c2`,
and empty stderr. Independent replay verifies actual CLOSED/SUCCESS, the
original command and retained streams, a free lease, absent original process
group and exact outcome and cleanup receipts. Analyzer scratch remains HOLD;
no extra cleanup occurs. The 1 GiB task limit is configured capacity, not a
measured peak. All earlier negative evidence remains unchanged.

This is offline widget and source qualification. The earlier full-suite and
native captures retain their earlier source scope; they do not qualify this
commit. Fresh hosted Fast, Windows baseline and entry capture remain pending,
as do all 94 visual matches, motion, frame-time and owned lab acceptance.

### Shared style qualification

The separate 21-path shared-style group is qualified in anonymous commit
`b2af047763a090e4f3a39d14caa13b544151936d`, after UI publication at
`408e4cb04767`. Shared quiet and secondary controls use the theme button height
and stable density; explicit compact transfer controls retain their geometry.
Callbacks, warnings, confirmation and transaction guards remain intact.
Its initial source admission applies the
reviewed style patch and refuses before task creation because one inherited
fixture uses a user-directory-shaped path. A single neutral fixture path
preserves its filename and all original assertions. The original refusal and
unbound bytes remain preserved; no SDK execution, task, quota change or cleanup
precedes the correction. All 41 current raw inputs are then rechecked. The
subsequent 1 GiB candidate is refused by the unchanged 10 GiB shared scratch
limit before task creation or SDK execution. Its recorded result remains
UNKNOWN, with no test or analyzer result.

A serialized read-only inventory observes 9720086217 logical shared scratch
bytes. The latest successful UI task is genuinely CLOSED and retains
136384120 logical scratch bytes; this closing observation is not its peak.
A fresh task with both expected allocation and task cap set to 512 MiB passes
all five original gates: formatting, zero-diagnostic strict analysis, all 117
visible regressions plus eleven hidden checks, root analysis with zero errors,
zero warnings and 1296 infos, and the whitespace check. There are no test
errors, failures or skips. All 41 raw inputs match the commit. The original
command exits zero with complete 320340-byte stdout, SHA-256
`6033bf2acbc3c0d6017a15f590a4c8e4215d5ef77b1097506a95aab8fe3524a5`,
and empty stderr. Independent replay verifies genuine CLOSED/SUCCESS, retained
streams and CAS ownership, free lease, absent original process group and exact
outcome and cleanup receipts. Analyzer scratch remains HOLD without cleanup.

The 10 GiB shared scratch limit, 10 GiB free-space floor, safety margin and
other policy fields remain unchanged. The configured 512 MiB cap is not a
measured peak or a promise about future capacity. The unused capacity-increase
proposal is not applied, and no historical cleanup occurs. These are offline
results; fresh complete-suite CI and native acceptance remain separate.

### Token form fixture follow-up

Retained diagnostics from devnet-only 40072557304 identify a stale token-form
selector after the real interface became a four-step form. The interrupted
local log lifecycle remains FAILURE, with transport exit and completeness
UNKNOWN; this diagnosis does not qualify the complete log or token issuance.

A held three-file correction navigates the original details, supply, options
and issue frames using enabled controls and one finite deadline. It returns
the original Issue control without tapping it. The original subscription
still precedes the single submission, and the original result Future, returned
block, success observation, 90-second wait and downstream token assertions
remain intact. Five offline cases and one loader are source expectations;
application, analysis, execution and fresh hosted devnet results are pending.

### Target CI observation refresh

At 08:45Z, bounded read-only API queries report target attempt 2 Fast
40072431054 successful, all Linux/Windows/macOS jobs in builder 40072430810
successful, release skipped and blockchain 40072430963 failed. Each run
reports head da402c9b44a4442b26396c0ec4a7dca7c3b0c19d. Their earlier
zero-job approval-gate observations remain historical records.

This refresh dispatches no workflow or retry and qualifies no artifact.
Original complete logs, source/run/platform correspondence and independent
retention verification remain pending. These results cover the published
repair head; the current uncommitted UI candidate is outside their scope.
