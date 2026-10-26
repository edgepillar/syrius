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

### Complete hosted Windows inventory

At `08fdf0ab62e8258c1e9efe8b1e334c1bc3a54fc4`, tree
`7b17a14bb7928845ab0714e5f2b44563824b39f2`,
[run 40325850769](https://github.com/edgepillar/syrius/actions/runs/40325850769),
attempt one, inventory job `121584678066` succeeds. All nineteen fields are
known, including explicit absences. The native query exits zero normally in
2.656 seconds with 932 complete bytes, all six ordered phases, three Visual
Studio details and one valid JSON frame. No query is forced or truncated;
source and tree checks pass before and after observation.

| Tool or setting | Observed version or state | Provisioning origin |
| --- | --- | --- |
| Windows x64 | 10.0.26100 | GitHub-hosted runner image |
| Git / Git Bash | 2.56.0 / 5.3.15 | Runner image |
| Native desktop workload | 18.11.12315.225 | Runner image's Visual Studio installation |
| MSVC | 14.51.36231 | Same Visual Studio installation |
| CMake | 4.4.4 | Runner image |
| Windows SDK | 10.0.26100.0 | Runner image; installed registry and include directories |
| Flutter / Dart | 3.47.7 / 3.13.5 | Pinned stable tag via the workflow's Flutter setup action/cache |
| Python | 3.12.10 | Runner image |
| Pillow | Absent | Installation remains pending |
| Node | 22.23.4 | Runner image |
| Chrome / Edge | 156.0.8078.48 / 155.0.4283.62 | Runner image |
| Docker client / daemon | 29.7.2 / 29.7.2 | Runner image |
| Docker Desktop | Absent | Installation remains pending |
| Developer Mode | Enabled | Existing runner registry setting; no elevation requested |

This completes P01's inventory requirement. It records what the fresh runner
provides and what is missing. P03's installation reconciliation, the separate
Linux Docker route and full wallet acceptance retain their own requirements.
The earlier incomplete inventories and their original failures are preserved.

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

Anonymous commit `bff78c818167dcb8d02f86ed89e2a1b74dd3eedd` contains the three-file
correction. It navigates the original details, supply, options
and issue frames using enabled controls and one finite deadline. It returns
the original Issue control without tapping it. The original subscription
still precedes the single submission, and the original result Future, returned
block, success observation, 90-second wait and downstream token assertions
remain intact. All 31 raw inputs match the commit after style publication at
`6fae076f0e28`. Fresh five-gate qualification passes formatting,
zero-diagnostic strict analysis, all five offline cases plus one loader, root
analysis with zero errors, zero warnings and 1296 infos, and the whitespace
check. No test errors, failures or skips occur.

The original command exits zero with complete 249361-byte stdout, SHA-256
`d6e0e1ce3cce9e96ffbb1df5cb9ed7e0787cafa99d1ca90c5b92da39890e02da`,
and empty stderr. Independent replay verifies genuine CLOSED/SUCCESS, original
command and CAS streams, free lease, absent original process group and exact
outcome and cleanup receipts. Analyzer scratch remains HOLD without cleanup.
The 512 MiB expected allocation and task cap do not establish a measured peak;
shared policy and the 10 GiB floor remain unchanged. This is offline fixture
qualification; fresh hosted devnet and actual issuance results remain pending.

The first source admission refuses before application or SDK execution because
the historical patch and preparation report retain mode 0644. Their original
bytes and modes are preserved. A reviewed read path now requires those exact
modes, SHA-256 values, owner, single-link regular files and stable descriptor
and path identities. All other preparation and source guards remain intact;
the original refusal is retained separately.

### UI and style full-suite CI

Fresh fork Fast run 40086450027 attempt 1 executes published head
`6fae076f0e285bd387525b96ec95d2ca775f4cc4`. Job 120850271842 completes all
thirteen steps successfully, including every post-step. Its complete retained
log qualifies all 189 Python methods and 4327 unit/widget successes with the
exact one existing receive-block skip. The terminal reports 4327 successes;
the retained reporter separately has 4297 individual success lines. These
counts are distinct; no hidden-count claim is made. Root analysis has
zero errors, zero warnings and 1296 infos, vendored analysis has zero
diagnostics, and generated correspondence passes.

Original transport exit zero and complete 1113092-byte stdout, SHA-256
`8ed2d45548ee0108691fde73a72871882a97bd0e1dad2c1d28ee4cefe41d1d45`,
empty stderr, source/run/attempt and before/after API metadata are replayed.
Independent verification establishes genuine CLOSED/SUCCESS with owned CLEANED
scratch, original command and CAS ownership, free task/artifact leases and an
absent original process group. This result keeps its UI/style source scope and
does not qualify the later token or caption candidates.

### Caption observation qualification

After normal token publication through anonymous `9392878d07da`, the separate
five-file caption observer is applied with 29 raw input pins. The first fresh
six-gate attempt reports six informational diagnostics in the new observer and
one error in the real PointerUp fixture; fourteen other Dart cases plus one
loader pass. Formatting, all 202 Python controller methods, root analysis with
zero errors, zero warnings and 1302 infos, and whitespace checks pass. The
original command exits one with complete 258825-byte stdout, SHA-256
`742cee900e61a9c2d354fa8c1d07a1c3406ebad8dfb7b17a49e191f1399c35a6`,
and empty stderr. Independent replay verifies all 29 raw inputs, stage and CAS
streams, genuine CLOSED/FAILURE, matching outcome and HOLD cleanup, a free
original lease and absent original group. This is a preserved failed attempt.

A reviewed two-file diagnostic correction retains the public constructor API
through an initializing-formal private target, keeps the original assigned
Futures in non-null late fields, and checks the captured original pointer
failure before the release assertion. Every existing pointer, completion and
teardown assertion remains. The original failure stack and release-callback
entry are also retained. The first isolated case genuinely closes
CLOSED/FAILURE/HOLD, retaining original exit one, complete 8105-byte stdout,
SHA-256 `33ed8c0cf70fdfd73434a5dc7d294439fd9cf15e6925a35ed7e300b58881436a`,
empty stderr, one visible error and one successful loader. Independent replay
verifies original command/CAS, source equality, closure/outcome/cleanup, free
lease and absent original group. It exposes Flutter's guarded `expect` being
called from a pointer callback while `tester.pump` is active.

Both original callbacks now use SDK-supported `expectSync`, with identical
actual values and Boolean matchers. The corrected single case passes against
29 raw pins under a 256 MiB expected allocation and task cap. Original exit
zero and complete 1406-byte stdout, SHA-256
`f626a9b6c15f19d0b83f1a2dab7e1008d38e2205f0eee8e02d92430c3d40cdb6`,
empty stderr, one visible success and one successful loader are independently
replayed. Genuine CLOSED/SUCCESS, matching outcome and HOLD cleanup, a free
original lease, absent original process group and unchanged source are
verified. This narrow run performs no formatting or Python202, root-analysis
or all-fifteen repeat.

The second full six-gate attempt passes all 15 Dart cases plus one loader,
all 202 Python methods, formatting, root analysis and whitespace checks.
Strict analysis rejects two diagnostic strings over 80 characters; root
analysis has zero errors, zero warnings and 1298 infos. Original exit one,
complete 255131-byte stdout, SHA-256
`0ff32dc3ed7327f8a5192a99bbdcec95b5cd23d735a24abf9fbb6facdbe8ffdc`,
empty stderr, all six stage frames, genuine CLOSED/FAILURE, matching outcome
and HOLD cleanup, free lease, absent original group and all 29 raw pins are
independently replayed. Only those diagnostics change afterward: the same
conditional cause moves outside interpolation and the same release message
uses adjacent string literals. Every actual matcher and original operation
remains. The next admission is refused before any task or SDK command is
created. Its original result remains UNKNOWN, with no exit, complete output
or closure claimed. The original producer does not retain the refusal text.
A separate read-only calculation identifies only the current shared-scratch
condition as failing. Metadata, task count, free space and reservation
conditions pass in that observation. The user subsequently approves increasing
only shared scratch from 10 GiB to 12 GiB. Original policy bytes are preserved;
the exact one-field atomic change is verified by readback under the original
metadata lock after all task leases are exclusively available and original open
process groups are absent. The 10 GiB free-space floor and every other quota
remain unchanged. No historical data is cleaned. Operational capacity details
remain private.
The original UNKNOWN remains preserved, and the current calculation is not
presented as the lost original refusal message.

The corrected full six-gate qualification passes at anonymous code commit
`96f08a6c888da9a3b00e9c412ff5bf68ef17f318`. All 202 Python methods and 15 Dart
cases plus one loader pass without skips or errors. Strict analysis of all three
Dart paths has zero diagnostics; root analysis has zero errors, zero warnings
and 1296 infos. Formatting and whitespace checks pass. Original exit zero,
complete 254357-byte stdout, SHA-256
`16f515b62b28197c8c9bafc2d377525c6b41d8257946b11a9e099e7fcfc4494d`,
empty stderr, all six stage frames and 29 post-format raw inputs are replayed
independently against original command and CAS records. Genuine CLOSED/SUCCESS,
matching outcome and HOLD cleanup, a free original lease and absent original
process group are verified. All earlier negative and UNKNOWN outcomes remain
unchanged. Analyzer scratch remains HOLD without cleanup. Native acceptance
and a measured peak remain unproven.

The observer retains the original controls and Futures for maximize, caption
restore, minimize and ordinary native restore under one finite budget.
Minimized observation requires no painted frame. The original eighteen native
checks and four caption checks still need fresh hosted execution, original
complete output and independent genuine retention-closure verification. The
512 MiB expected allocation and task cap are not a measured peak. The approved
12 GiB shared limit preserves the 10 GiB floor and all other quotas.

### Caption-head hosted qualification and follow-up

Published source `bcc26fee2ca52bb4a1abdbe21f502c78679e88d4` completes fork
Fast run 40098246659 attempt 1 with all thirteen job steps successful. The
terminal reports 4347 unit/widget successes; the retained reporter separately
has 4317 individual success lines, with one exact existing receive-block skip.
All 202 Python methods,
vendored zero-diagnostic analysis and generation consistency pass. Root
analysis retains 1296 infos with zero errors or warnings. The complete
1116753-byte job log has SHA-256
`702cb155c509ab8f6c304cc754cbb11c2c59a2ac250a2a6f27362b9120c3365d`.

At the same source, scoped run 40098338600 attempt 1 passes baseline job
120885182241, including every cache post-step and all twelve controller
checks. It retains 4346 visible and 506 hidden successes, two existing skips,
4854 terminal events and no test error events. Locked restoration, generation
and localization correspondence, Debug/Release builds, Windows doctor and all
three DLL map/export probes pass. Root analysis retains zero errors, zero
warnings and 1296 infos; vendored analysis has zero diagnostics. The complete
40036-byte job log has SHA-256
`b36fc6c1730b623b7305c17370251ec3d9fcbda92b006d80b9dce0b875503610`.
Optional inventory includes a Windows inventory timeout and unavailable Pillow;
full owner installation, DLL ABI invocation, node and wallet startup remain
unqualified.

Both logs have independently replayed source/run/attempt and before/after API
metadata, original transport exit zero and complete streams, owned CAS,
genuine CLOSED/SUCCESS/CLEANED retention, free task/artifact leases and absent
original groups. This qualifies their exact source, not the subsequent edits.

The same scoped run fails entry job 120885182389 at `caption_bind`, before any
caption action. Four actual 1280x780 captures have valid bounded PNG records.
Original process exit zero and complete output are observed; original window
and entry restoration remain unqualified. The first refusal is collapsed to
`COMMAND_FAILED`, and subsequent restoration is held. The complete 48895-byte
job log has SHA-256
`a897d76f1d58e05a958a9fa3a02401e6c1f85175e4e162ed75a7257151ec3b21`.
The 561228-byte archive has SHA-256
`c12e3f831f0ed8cae719fe50da6b397de170f034578ed680419ecda5a97def0a`.
Its negative contract is independently replayed against archive members,
individual PNG CAS and original command, genuine CLOSED/SUCCESS/CLEANED
retention, free original leases and an absent original transport group. This
successful retention does not convert the native failure into acceptance.
An initial local retainer launch fails to locate `gh` before any task or
transport; that failure is preserved separately from the corrected launch.

Devnet job 120885182372 fails its first Fuse Plasma UI scenario because its
fixture omits `SendTransactionBloc`. It stops while rendering, before this
scenario submits a transaction. The original 360192-byte log has SHA-256
`3718e75b7e78fa7d5f7749c0eb2206bd7ca7dc59adf1ff8311ee28db479b3033`.
Both failed-job logs have independently verified original complete transport,
matching source/job metadata, owned CAS and CLOSED/SUCCESS/CLEANED retention.
No transport is repeated, and the failures keep their original outcomes.

Anonymous follow-up `4c0de7a7def2994ecdaa31b45788f12f8b0b70b6` preserves the
first fixed caption refusal across the harness boundary. Arbitrary remote
errors, original diagnostics and stacks are excluded; unknown values remain
`CAPTION_HELD` or `COMMAND_FAILED`. Caption codes are admitted only in their
finite command phases. Original holds, controls, Futures, budgets and refusal
of replay remain. The Fuse Plasma test host owns its missing sender; original
borrowed balances, subscription, submission and completion assertions remain.

All six fresh local gates pass against 31 raw inputs: 205 Python methods,
20 Dart cases plus two loaders, zero strict diagnostics across four Dart
paths, root zero errors and warnings with 1296 infos, formatting and whitespace
checks. Original exit zero, complete 251666-byte stdout, SHA-256
`750dfc107a669882c7ad6962ae7ad828a3d5c5abd21488c730a59b80be29cc18`,
empty stderr, every stage range and summary, original command/CAS and exact
source are replayed independently. Genuine CLOSED/SUCCESS, free lease and
absent original group are verified; analyzer scratch remains HOLD. The first
admission refuses an overlong task identifier before task/SDK creation. The
next full attempt passes tests but fails one test-only cascade diagnostic,
retaining genuine CLOSED/FAILURE/HOLD and complete original output. Only the
cascade initialization changes before the successful batch. All prior outcomes
remain preserved. The 512 MiB expected allocation and cap are not a measured
peak. Fresh hosted caption diagnosis and fusion execution remain pending.

### Bounded tree traversal and original beneficiary selection

At publication `e19c5bdf53f9eb9f56d9b16d9d744fcf758b77a9`, fork Fast
40103609283 attempt 1 passes all thirteen steps, 4349 unit/widget successes
and the exact one existing receive-block skip. The terminal reports 4349
successes; the retained reporter separately has 4319 individual success lines.
All 205 Python methods, zero-diagnostic
vendored analysis and generation consistency pass; root analysis has zero
errors, zero warnings and 1296 infos. Its complete 1117793-byte log has SHA-256
`b265c7aefa7b68229de9231014c8d209ec129dbe0aa0660db6eeabf88b9ee643`.

Scoped 40103626385 attempt 1 fails entry job 120900677718 with the first
fixed `CAPTION_TREE_REFUSED` at `caption_bind`. All four genuine captures
precede the refusal; caption actions and window/entry restoration remain
unqualified. Original exit zero and complete output are retained. The complete
47475-byte log has SHA-256
`b164b17b910289d40d1dd93476b6e611e268def953a25594991aac50bcaa276a`.
The 559924-byte archive has SHA-256
`9e1b519a4d859c51aa535c5cfb9a69077134c65ea5a151da53c4a78d7394d4b3`.
Its negative contract, archive members, individual PNG CAS, original command,
closed successful retention, owned CLEANED scratch, free task/artifact leases
and absent original group are independently verified. Native acceptance
remains false.

Devnet job 120900677907 passes the former missing-sender point and fails
`WidgetTester.enterText` on the beneficiary field at fixture line 73, before
this scenario subscribes or submits. A selected known beneficiary displays a
selector; the separate Another address field is not yet mounted. Its complete
324647-byte log has SHA-256
`c754f04ed40de9f7272530a55b471f77d1354c3957e27140088fa227f669bc9f`.
All three logs have independently replayed complete original transport,
source/run/job and before/after metadata, owned CAS, genuine
CLOSED/SUCCESS/CLEANED retention, free leases and absent original groups.
Baseline is deliberately disabled; its earlier exact source scope is retained.

Anonymous follow-up `3058e5f9fb8924a33eda1add40407c91b3e43656` uses an explicit
widget work list. Total visited plus pending storage stays within 8192
elements, every mounted check remains, and original frame/control identities
and duplicate-key refusal remain. The iterative traversal supports deep
provider/theme/route ancestry. Capacity and unmounted refusal use separate
fixed codes; original private diagnostics remain held. The fixture opens the
real beneficiary selector and Another address control only when the field is
hidden, then enters the original address. Sender ownership, subscription,
one submit tap and original completion checks remain unchanged.

All six fresh local gates pass against 31 raw inputs: 205 Python methods,
22 Dart cases plus two loaders, zero strict diagnostics across three Dart
paths, root zero errors and warnings with 1296 infos, formatting and whitespace
checks. This includes a 300-level original body that retains its frame owner
and a capacity overflow that refuses before native caption observation.
Original exit zero, complete 252704-byte stdout, SHA-256
`6828d0e86a0a30b5121d3560abdb63d1ede7bf2a8aed8fe3258315e3a039acbf`,
empty stderr, stage ranges/summaries, original command/CAS, all source pins and
genuine CLOSED/SUCCESS are independently verified. Original lease and process
group checks pass; analyzer scratch remains HOLD without cleanup. Earlier
failures remain unchanged. The 512 MiB expected allocation and cap are not a
measured peak. Fresh hosted caption and fusion results remain pending.

### Target CI observation refresh

At 08:45Z, bounded read-only API queries report target attempt 2 Fast
40072431054 successful, all Linux/Windows/macOS jobs in builder 40072430810
successful, release skipped and blockchain 40072430963 failed. Each run
reports head da402c9b44a4442b26396c0ec4a7dca7c3b0c19d. Their earlier
zero-job approval-gate observations remain historical records.

This refresh dispatches no workflow or retry and qualifies no artifact.
Original complete logs, source/run/platform correspondence and independent
retention verification remain pending. These results cover the published
repair head; the later uncommitted caption candidate is outside their scope.

At 11:45Z, one bounded read-only API observation of published token head
`9392878d07da8bf04f42dd3e4f22b0f122b9ffbb` reports target attempt 1 Fast
40088055089, blockchain 40088055078 and builder 40088055082 completed with
`action_required`. This is an approval gate, with no test verdict or job-count
claim. The observation performs no workflow dispatch, retry or artifact
qualification and does not qualify the uncommitted caption source.

### Caption layout and Send confirmation follow-up

At `4c7213663d5359486efd49aba90ba803ce5f93e6`, Fast 40107940859 attempt 1
passes all thirteen job steps, 205 Python methods, generation correspondence
and zero-diagnostic vendored analysis. Its terminal reports 4351 successes and
one exact existing receive-block skip; the retained reporter separately has
4321 individual success lines. Root analysis has zero errors, zero warnings
and 1296 infos. The complete 1117641-byte log has SHA-256
`56ed03ed6401d84c6d1b9eabfd236f0476b9b6f2d64f6f1d766cb5bc5cf2102d`.

Scoped 40108000278 attempt 1 passes original tree binding and native maximize,
then refuses `caption_restore` with the fixed `CAPTION_CONTROL_REFUSED` code.
The four captures remain valid; complete native restoration is unqualified.
Original exit zero and complete output are observed. The complete 48049-byte
entry log has SHA-256
`c59da1f588014c1872c6e15b36b4101656477861197114ca47a11dd7bad210c2`.
The 561580-byte archive has SHA-256
`ca31dece5bdf324b76329c95091466fb856ca17c1300b2a0aad0fe4269a1b72e`.
Its negative contract, original command, archive members, individual PNG CAS
and genuine CLOSED/SUCCESS/CLEANED retention are independently verified.

Devnet job 120913607514 completes five scenarios: Pillar registration,
Sentinel registration, stake creation, token issuance and Plasma fusion.
The Send scenario then fails at its former `dialog_yes_button`, before
acceptance. Its complete 367640-byte log has SHA-256
`590136de168ac0ba301a1eba8bb57ad877f472bb31963ee56249126d32f2c560`.
All three logs have independently verified complete original transport,
source/run/job metadata, owned CAS, genuine CLOSED/SUCCESS/CLEANED retention,
free leases and absent original groups. These chain-69 results qualify
neither the separate chain-321 lab nor real-wallet acceptance.

Anonymous `ee3c9f2cb469856ecf52f617bbf38e98184d0b2c` waits for the visible
caption layout before choosing its pointer target, retaining the exact
original control and checking admission before and after the wait. A queued
resize regression places the previous caption outside the new view and
requires genuine pointer delivery with immediate pending observation. No
paint is awaited after minimize. The Send fixture uses the actual redesigned
confirmation key, preserving the original subscription, one acceptance tap,
original completion Future and on-chain assertions.

All six fresh local gates pass: 205 Python methods, 39 Dart cases plus five
loaders, zero strict diagnostics across all three changed paths, root zero
errors and warnings with 1295 infos, formatting and whitespace checks.
Original exit zero, complete 263438-byte stdout, SHA-256
`4a44d09073d521469313ecccd1335a264ee23dec9da282721c87a535be01e70f`,
empty stderr, all stage ranges and summaries, all 36 raw source pins, original
command/CAS and genuine CLOSED/SUCCESS are independently verified. The lease
is free and the original group absent. Analyzer scratch remains HOLD; the
512 MiB cap is not a measured peak. The first strict-analysis failure retains
its genuine CLOSED/FAILURE/HOLD outcome and complete output. Its 39 Dart and
205 Python cases passed; only three style diagnostics failed, then were
repaired. No historical cleanup is claimed. Fresh hosted caption and Send
results for this follow-up remain pending.


### Positive native caption contract and confirmed Sentinel view refresh

At `efeca119cf2f9b43962a22aba091bc48e0b2b6bb`, ordinary Windows entry job
120927304304 in scoped 40112608635 attempt 1 passes all thirteen job steps,
all eighteen original checks and all four caption checks. Maximize, caption
restore, minimize and native restoration all pass. Four genuine 1280x780
captures, original exit zero, complete output, no overflow or forced kill,
source/run/attempt binding and bounded PNG parsing are independently verified.
The complete 49824-byte job log has SHA-256
`360fd5cf22717769d5c1e84e94d410d5d3f0e4e90033631bcdf0cdd8c9d7ec9a`.
The 560308-byte archive has SHA-256
`7226345edd9bafcb39de5b04e1ca1d47d69917971d3d99ee4025a3cb781b4b68`.
Original transport/CAS, archive members, genuine CLOSED/SUCCESS/CLEANED,
free leases and absence of the original process group are independently
verified. This qualifies the finite ordinary entry/caption contract only.

Devnet job 120927304710 passes Pillar registration, then fails finding the
Sentinel QSR Next control after the deposit preconditions. It does not reach
Send. The complete 294236-byte log has SHA-256
`9d2a0e22c1604aa7592683b9c3488314c84d4f9323bfb7973350a897dcc4d48f`.
Both completed job logs have independently verified complete original
transport, source/run/job metadata, owned CAS and genuine
CLOSED/SUCCESS/CLEANED retention. Fast 40112488091 is observed successful
with all thirteen steps; its original log retention remains queued.

Anonymous `514586d4bda3955722d9fe2e3cfa54230a508c8a` retains the original QSR
information bloc before deposit. After the existing original confirmation
and exact full contract amount have passed, it checks current authority and
requests one read-only refresh from that retained bloc. The publication-time
view read can precede the contract effect. The repair preserves the original
sender, transaction hash, deposit operation, confirmation and subscription;
it does not re-sign or repeat a deposit.

All six fresh local gates pass: 205 Python methods, 53 Dart cases plus nine
hidden successes, zero strict diagnostics, root zero errors and warnings
with 1295 infos, formatting and whitespace checks. Original exit zero,
complete 275411-byte stdout, SHA-256
`649d431f5bc0311dcc8a54f73ad5f743fd362c045784dea72ec71febff1b4b17`,
empty stderr, stage ranges/summaries, all 48 raw pins, original command/CAS,
genuine CLOSED/SUCCESS, a free lease and absent original group are
independently verified. Analyzer scratch remains HOLD; the 512 MiB cap is
not a measured peak. Earlier failures and UNKNOWN outcomes remain preserved.
Fresh hosted Sentinel and Send results remain pending. Entry/caption runtime
inputs and baseline application/platform/dependency inputs are unchanged;
the earlier exact source scopes remain explicit.

Limited inspection of the four current entry pairs finds close main layout
and no apparent earlier caption displacement. Globe timing, Import input
and focus state, helper wording and some typography extents differ from the
retained references. Both sources specify a 1.5 px drop stroke, which is
retained. No image, wallet input or capture contract is changed. This is not
the full fresh-agent comparison; 90 actual captures and all 94 visual matches
remain pending. Reporter totals and individual rendered success lines are
also reconciled separately above. Original logs and earlier receipts remain
preserved; no new execution is inferred from that reconciliation.


### Original Transfer context for devnet Send

At `193f3ad437ebbff6bec12efeee17b411c49aabf8`, devnet job 120938832837 in
40116523103 attempt 1 reports five passing scenarios: Pillar, Sentinel,
stake, token issuance and Plasma fusion. Send then fails because its actual
confirmation control is absent. The complete 346783-byte original log has
SHA-256
`5f1b5fc5a37ceb83ba8c3022898d6539a1443db6831d76dbb723e5d980564311`.
The source/run/job binding, all eighteen terminal step outcomes, original
log transport exit zero, complete streams, owned CAS, genuine CLOSED/SUCCESS/CLEANED,
free leases and absent original group are independently verified. The
retention was initially provisional while API step metadata lagged; that
metadata is now reconciled from the retained original evidence. No transport
is repeated. The earlier batch refusal retains its pre-task STEPS_REFUSED
outcome with no task or download. Fast 40116467804 and earlier 40112488091
are observed successful with all thirteen steps; original Fast log retention
remains queued.

Source review finds that the fixture installs Dashboard while the real
Send session requires Transfer. Anonymous
`b2b25f1bd9ccb01aba5627de8b0791760c1018e0` selects Transfer only through the
original verified in-memory devnet binding. It retains SDK/socket, wallet,
path, node, chain-69, membership, idle-wallet and transition checks. Selection
invalidates the context once, is idempotent while already on Transfer, and
the existing teardown restores the previous page. Production session
admission remains unchanged. The original sender, one submit and acceptance,
subscription, completion Future and on-chain assertions remain intact.

The real Send widget regression refuses the Dashboard context, opens the
actual confirmation after Transfer selection and cancels it without signer
acquisition or RPC. Ownership/page restoration and changed-node refusal also
pass. All six fresh gates pass: 205 Python methods, 84 Dart cases plus seven
hidden successes, zero strict diagnostics across all three changed files,
root zero errors and warnings with 1295 infos, formatting and whitespace
checks. Original exit zero, complete 290032-byte stdout, SHA-256
`447e647d28b7f9b09508f3eaad4b7a88abcf7b984ca69a5a13561bb4eb8fe98d`,
empty stderr, all stage ranges/summaries, all 60 raw inputs, original
command/CAS, genuine CLOSED/SUCCESS, a free lease and absent original group
are independently verified. Analyzer scratch remains HOLD; 512 MiB is a cap,
not a measured peak. The first attempt preserves CLOSED/FAILURE/HOLD for one
unnecessary import, while all 84 cases already passed. That import is removed
before this fresh complete qualification.

Fresh hosted Send behavior remains pending. Native entry/caption runtime
inputs and baseline application/platform/dependency inputs remain unchanged,
with their exact earlier scopes retained. No real-wallet or production
acceptance is established, and all 94 visual matches remain pending.


### Complete hosted qualification of the Transfer repair

At `27938b9bc54613bbe4e28fa1253b21f0dcf271e7`, tree
`b47ee0488379202cd99e3c2102458278625056dc`, both fresh workflows complete
successfully at attempt 1. This is the documentation carry of the repaired
code in `b2b25f1bd9ccb01aba5627de8b0791760c1018e0`.

[Fast 40122053184](https://github.com/edgepillar/syrius/actions/runs/40122053184),
job 120955556893, passes all thirteen steps, including every post-step,
205 Python methods, zero-diagnostic vendored analysis, application and
integration analysis with zero errors, zero warnings and 1295 infos, locked
dependency installation and generation correspondence. Its terminal
reporter records 4355 passing tests and the one existing receive-block
skip; the original log separately contains 4325 individual success
lines. These are separate reporter measures. The complete 1117553-byte
original log has SHA-256 `73cd3e354f9754303a234337ff1a46831b9cfdb338c29d55502322f9600e8b94`.

[Devnet 40122141453](https://github.com/edgepillar/syrius/actions/runs/40122141453),
job 120955822285, passes all six feature files: Pillar registration, Sentinel
registration, stake, token issuance, Plasma fusion and Send. Each reports
one passing test with no failed or skipped scenario. All eighteen job steps
have terminal outcomes: seventeen succeed and the conditional failure-only
log dump is skipped. Original transaction, amount, subscription, confirmation
and on-chain assertions remain intact. The complete 258482-byte
original log has SHA-256 `110bd8e3007d95cb12b184c163cfb25771adb7cccd50af4949dfa12804b218df`. This is chain-69 devnet evidence;
the separate owned chain-321 lab and real-wallet acceptance remain unqualified.

Previously queued Fast logs are now retained at their original sources.
At `efeca119cf2f9b43962a22aba091bc48e0b2b6bb`, job 120926938527 in
40112488091 passes all thirteen steps; its terminal reports 4352
passing tests with one existing skip and 4322 individual success
lines. The 1117841-byte log has SHA-256 `9072d9d097b26678d3cab30eb679179374d80786a58bef809c11d324b2a29d4c`.
At `193f3ad437ebbff6bec12efeee17b411c49aabf8`, job 120938667501 in
40116467804 passes all thirteen steps; its terminal reports 4352
passing tests with one existing skip and 4322 individual success
lines. The 1116219-byte log has SHA-256 `a967b1a6f12ec23c91418bdf54da9d435d4b18b4bf212caaad736f8681396bfa`.

All four original transports exit zero with complete bounded streams and
empty stderr. Source/run/attempt/workflow/job/step metadata, original command
receipts, rehashed CAS objects, genuine CLOSED/SUCCESS/CLEANED retention,
free task and artifact leases, and absence of the original process groups
are independently verified. Earlier failures and UNKNOWN attempts keep
their actual outcomes. Completed transports, native tests and CI are not
repeated to produce this reconciliation.

The accepted entry/caption contract remains pinned to `efeca119cf2f`, with
eighteen original checks, four caption checks and four genuine captures.
Only documentation, integration fixtures and their offline test change
between that source and this qualification; native runtime inputs are
unchanged. Application, platform, dependencies and the baseline controller
also remain unchanged from the qualified `bcc26fee2ca5` Windows baseline.
The final publication tail changes these two progress documents only.
No unchanged CI retry is used for that tail.

All 94 visual matches, 90 other actual captures, the complete formal pair
review, running-build motion/shader/frame-time and seam checks, minimum-window
and Arabic-layout acceptance, owned lab checkpoints, complete wallet/node
startup and production acceptance remain pending. Password migration and
full two-sided Swap terms remain seamed. The inherited informational
analysis backlog remains. No match or full acceptance is inferred from
these positive finite results.

### Retained comparison and Import border box

At `d8dd4a3e20f45a6cb5ba9fff8055e02300fbc68f`, the existing local comparison
generator reads all 94 reference PNGs in place and reuses the four verified
Welcome/Import captures from `efeca119cf2f`. It produces the required 47-screen,
94-pair page with four unreviewed pairs, ninety missing captures and no
reviewed match. Input/focus and animation states still differ; no wallet input
is inserted into a capture. The selected brand-colour exception remains explicit.

The original generator command exits zero with complete output. Its final
metadata reader requires a package record to be read-only before task close,
while the manager makes that metadata read-only during close. The original
refusal therefore remains CLOSED/FAILURE/CLEANED. Separate read-only
reconciliation verifies all eleven exported files, their original command,
CAS objects, image hashes, PNG structure and dimensions, relative image links,
package references and the exact incomplete report state. It neither changes
that failed outcome nor repeats generation, capture, transport or an SDK test.

The explicit local export contains 1466021 bytes. Original aliases, retained
objects and that export account for 3490206 logical bytes under the declared
64 MiB task budget and 16 MiB export cap; this is not a measured physical peak.
No reference image, SDK or archive is copied, and no new download occurs.
The generated report remains local and outside Git. Browser preview is
unverified because the browser tool rejects local-file URLs; no alternate
browser, protocol workaround or render success is claimed.

Source review of the Import pair identifies a separate border-box discrepancy.
The reference has `box-sizing: border-box` and a 1.5 px dashed border. The
pinned `dotted_border` 3.1.0 painter centers its stroke on the supplied path;
zero child padding omits the border from layout. Anonymous
`f1b533811cefc87fa1fc6f0b402ebe31b690d16c` reserves the border width, insets
the centerline by half that width and adjusts its radius to preserve the
outer curve. The original 1.5 px stroke, dash pattern, fill, callbacks, input
owners and continuation admission remain unchanged.

All five focused local gates pass: formatting, zero-diagnostic strict analysis,
thirteen existing presentation cases and one loader with no failure/error/skip,
root analysis with zero errors, zero warnings and 1295 infos, and whitespace
checks. Both themes' card, footer, stable focus, pointer hover/fill and stroke
paint cases pass. The complete 251397-byte original output has SHA-256
`68ee8daf12e90f3cb65caf3f92db001ea1742e65b7026f27d3270798fa227b88`.
All 69 raw inputs, original command and stream boundaries, source correspondence,
genuine CLOSED/SUCCESS, free lease and absence of the original process group
are independently verified. Analyzer scratch remains HOLD. The 512 MiB task
cap and shared 12 GiB scratch cap preserve the 10 GiB floor and other policy
limits; no historical cleanup is performed.

The unchanged Python controllers and earlier chain-69 results retain their
separate source scopes. This Import edit changes a runtime input, so the
earlier ordinary-entry screenshots and Windows application builds do not
qualify it. Fresh Fast, Windows baseline and native entry qualification are
next. All 94 visual matches and the separate owned lab, full wallet lifecycle,
motion/frame-time, seam and minimum-window/RTL acceptance remain pending.

### Bounded Windows process preflight

At `85a7a1a141f131265f17e24d2942dc7309de35cf`, Fast run
[40135062207](https://github.com/edgepillar/syrius/actions/runs/40135062207)
and Windows baseline job 120994851674 in
[40135102175](https://github.com/edgepillar/syrius/actions/runs/40135102175)
complete with successful terminal job metadata. Their complete original log
verification is pending. The same Windows run fails its separate ordinary-entry
job 120994851794 before application launch: `PREFLIGHT_FAILED`, zero captures,
no observed application exit, no authenticated control and no window action.
It establishes no fresh Import geometry or caption result.

The original complete 47669-byte entry log has SHA-256
`8ff5597bbd6975b45ae1f0d5ca075e845fe2bff5693b82775d47fe8361726140`.
The 1254-byte
[artifact 12576548269](https://github.com/edgepillar/syrius/actions/runs/40135102175/artifacts/12576548269)
has SHA-256 `36ce884abf96e5d4bfbbfdf0debc53263dddf515543e16daf0c1e8c5779b229b`
and contains only the 1114-byte finite failure manifest, SHA-256
`0732a0001af40a376cd2d8833ffe02b268e498f13b18ca3ab0a10baf1a4dd9ef`.
Both original transports, owned CAS bytes, exact source/run/job/artifact pins,
original command and complete streams, free leases and absent original groups
have independently verified CLOSED/SUCCESS/CLEANED retention. The native
contract remains negative; successful retention does not relabel the CI failure.

The old controller gives every admission helper five seconds and collapses
timeout, output and helper failure into one code. Its approximately 5.7-second
preflight interval is consistent with a timeout, but the old report cannot
prove that cause. Anonymous `a60f4b1fc0319c708da22f0d62c18058b9c109b8`
allows a bounded fifteen-second cold PowerShell process query and separately
reports `PREFLIGHT_TIMEOUT` and `PREFLIGHT_OUTPUT_REFUSED`. Read-only Git queries
retain five seconds. The process query, existing-process refusal, original
helper handle, finite kill/wait/drain cleanup and private diagnostics remain.
Uncertain cleanup still reports `CLEANUP_FAILED` and never permits a wallet launch.

All 211 Python methods pass without failures, errors or skips, including three
local AF_UNIX mechanics cases and seven explicit preflight regression methods.
They cover a helper completing after five seconds, the fifteen-second refusal,
the unchanged default helper limit, output overflow, incomplete final drain,
uncertain cleanup and stopping entry before profile or wallet launch. These are
offline controller tests, not native Windows observations. The original complete
24934-byte test stream has SHA-256
`d754fd149b440c292cf61d6ba035e3e7a7ea33d5061b3e7781f9aea50e943df8`.
Independent replay verifies all 26 raw source inputs, original exit zero,
CLOSED/SUCCESS/CLEANED, free lease and absence of the original group. The
64 MiB task cap is a declared budget, not a measured physical peak. No SDK,
dependency, reference image or archive copy is downloaded for this follow-up.

Fresh Fast and ordinary-entry execution are next for the changed controller.
Application, platform and dependency files remain unchanged from the completed
85a7a1a141f1 baseline; that result retains its own source scope. The previous
failed entry attempt and earlier positive four-capture contract remain separate.
All 94 visual matches, the owned chain-321 lab, full wallet/node lifecycle and
running-build motion, seam, frame-time and minimum-window/RTL acceptance remain
pending. Public output remains English and excludes profiles, raw local
diagnostics, credentials and personal identity.

### Current native entry and Import dash spacing

At `ad52f6b99fdd893b5617fc0596020e9e782e7076`,
[Fast 40138136852](https://github.com/edgepillar/syrius/actions/runs/40138136852),
attempt 1, job 121003951999, passes all thirteen job steps, 211 Python methods,
vendored analysis, root analysis with zero errors, zero warnings and 1295 infos,
locked restoration and generated-source correspondence. Its terminal reporter
records 4355 passing tests and the existing receive-block skip; 4325 individual
success lines are a separate measure. The complete 1118123-byte original log
has SHA-256 `5367c0ef84265b4a02598c3e45d3e8b3e08f6b04934d125692c117a6906f1a3b`.

At the same source,
[ordinary Windows entry 40138167426](https://github.com/edgepillar/syrius/actions/runs/40138167426),
attempt 1, job 121004042865, passes all thirteen steps and 61 finite controller
methods. Its original report passes eighteen entry checks and four caption
checks: maximize, caption restore, minimize and native restore. It retains four
genuine 1280x780 captures, observes original exit zero and complete output, and
records no overflow, forced kill, command failure or cleanup failure. The complete
48314-byte log has SHA-256
`a5ccdc8cc5f783cacb8d71b7d0a17d34ab5060c32111f982a2987d44721a2fef`.
The 557696-byte
[artifact 12577063084](https://github.com/edgepillar/syrius/actions/runs/40138167426/artifacts/12577063084)
has SHA-256 `dd1d5ae0468b84a418a5cc22421173eafabac50057ebbaa3b8c88c20a32762dd`.
Both complete original job logs and the native artifact have independently
verified exact source/run/job/step bindings, original bounded transport, owned
CAS bytes, genuine CLOSED/SUCCESS/CLEANED retention, free original leases and
absent original groups. No completed transport or test is repeated for this proof.

The preceding Import source `85a7a1a141f131265f17e24d2942dc7309de35cf` now also
has complete source-bound Fast and Windows baseline verification. Fast
40135062207 passes all thirteen steps, 205 Python methods, 4355 terminal-reported
tests with one existing skip and 4325 individual success lines. Its complete
1117586-byte log has SHA-256
`86bb030ba7b31790a5ce33a7b84efb92260c2a0bb446475f77b3470d17404d73`.
Baseline job 120994851674 in 40135102175 passes all ten job steps and twelve
controller checks, including locked restoration, generation correspondence,
Debug/Release builds and three DLL map/export probes. Its JSON test report has
4354 visible successes, 506 hidden successes and two existing skips, for 4862
terminal events with no failure or error event. The complete 38922-byte log
has SHA-256 `32878925b8e291c20bdd130627f7a274e3ac477e925035f7c8b4c929cdf2e9ac`.
Its optional Windows inventory helper is forcibly stopped at its 30-second
timeout; several detailed inventory fields remain unknown. Optional Pillow
inspection reports absence. These outcomes are preserved separately from the
positive Windows desktop doctor and twelve required baseline checks. Mapping
and export lookup establish neither node ABI invocation nor full wallet startup.

The baseline and current log-retention tasks have genuine successful closure.
An earlier new log-batch admission with an overlong project identifier retains
its original UNKNOWN result: it creates no task and performs no transport.
A fresh bounded identifier corrects that local admission. The first independent
baseline parser also retains its refusal because it incorrectly required every
optional inventory stage to be unforced. Read-only source correction preserves
both actual optional negative outcomes and verifies the same retained bytes;
it repeats no CI, native test or artifact transport. The older failed entry
preflight remains a separate negative contract.

Limited inspection of the two new Import pairs finds the principal box geometry
close to the references. Actual input remains empty; reference sample text and
focus differ. A read-only straight-edge scan, at row 312 across columns 400..879
in both themes, measures median native dash/gap runs of 6/4 pixels and reference
runs of 3/2 pixels. The original 1.5 px stroke is retained. Anonymous
`1a540b182e075f9b7522f58a1f1edba5303a0743` changes the single Import dash token to
3/2. It does not establish a complete visual match.

All five local gates for that token pass: formatting, strict analysis with zero
diagnostics, thirteen existing presentation cases plus one loader with no
failure/error/skip, root analysis with zero errors, zero warnings and 1295 infos,
and whitespace checks. Both themes retain their geometry, stable focus,
hover/fill and 1.5 px paint checks. The complete 251303-byte original stdout
has SHA-256 `15e76b27bba753900c9a4118d6491543a819eb9600c4dc17a51b485f224bc766`.
All 69 raw inputs, original command and streams, source correspondence,
CLOSED/SUCCESS, free lease and absent original group are independently verified.
Analyzer scratch remains HOLD. The 512 MiB task cap is a declared limit, not
a measured physical peak; the shared 12 GiB cap and 10 GiB floor remain.

The dash token changes a runtime input after ad52f6b99fdd. Its fresh qualification
and comparison are recorded below. At ad52f6b99fdd the three target PR workflows
are action_required with zero jobs and await maintainer approval. That historical
target state is separate from the subsequent fork qualification.

### Final Import captures and source-bound qualification

Updated 2026-10-25T00:05Z. Qualifying source is
`1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0`, tree
`9a8eec6320aa5cf1be0cad89f4bf9b4e8e979d18`. The final publication tail changes
only this document and the progress log. No qualified application, controller,
platform, dependency or workflow input changes in that tail.

[Fast 40142173583](https://github.com/edgepillar/syrius/actions/runs/40142173583),
attempt 1, job 121016012480, passes all thirteen job steps and 211 Python methods.
Vendored analysis has zero diagnostics; root analysis has zero errors, zero
warnings and 1295 infos. Locked restoration and generation correspondence pass.
The terminal reporter records 4355 passing tests and one existing receive-block
skip; 4325 individual success lines are recorded separately. The complete
1118299-byte original log has SHA-256
`db44619ef5db01b2356d66f46c2eeeb47f9eff7a1d7cacb87a4d2310b0c6d134`.

[Windows 40142185606](https://github.com/edgepillar/syrius/actions/runs/40142185606),
attempt 1, baseline job 121016046890, passes all ten job steps and twelve
controller checks. Locked restoration, source and localization generation
correspondence, desktop doctor, analyses, tests, Debug/Release builds and three
DLL map/export probes pass. The JSON test report records 4354 visible and 506
hidden successes, two existing skips and 4862 terminal events, with no failure
or error event. The complete 39669-byte original log has SHA-256
`6d5b128bf3ee657ba78b7c36e54b12e631e6c954dc282bd376ffe425c8fa40df`.
Optional Windows inventory times out after 30.031 seconds with its helper
forcibly stopped; several detailed inventory fields remain unknown. Optional
Docker daemon inspection exits one and Pillow inspection reports absence.
These negative outcomes remain separate from the twelve positive required
checks. DLL mapping and export lookup do not invoke the node ABI or wallet loader.

In the same Windows run, entry job 121016046846 passes all thirteen job steps,
61 finite controller methods, eighteen original entry checks and four caption
checks. Maximize, caption restore, minimize and native restore pass. Four genuine
1280x780 Welcome/Import PNGs are bound to the original source, process and window.
The original process exits zero with complete output and no overflow or forced
kill. The complete 49053-byte log has SHA-256
`92452734d11259e3f29aa88b81301bdaeddcda13bcad874acb84b39f210ef9e0`.
The 562301-byte
[artifact 12579640614](https://github.com/edgepillar/syrius/actions/runs/40142185606/artifacts/12579640614)
has SHA-256 `20b721e5a343cb5837c5231a8a1c7bfce520a014deefded48dcd625e8f5c6ff2`.
All three complete original job logs and this artifact have independently
verified exact source/run/job/step bindings, bounded original transport, rehashed
owned CAS, genuine CLOSED/SUCCESS/CLEANED retention, free original leases and
absent original process groups. The earlier prelaunch failure retains its
original negative outcome. No unchanged CI, completed native execution or
artifact transport is repeated for this verification.

Read-only straight-edge scans of both final Import captures and both references,
at row 312 across columns 400..879, measure matching median dash/gap runs of
3/2 pixels. The 1.5 px stroke remains. Actual inputs remain empty while references
contain sample words and focus; text rasterization and globe animation phase
also differ. This finite measurement establishes no complete visual match.

The new private comparison reads all 94 existing references in place and uses
four verified final captures. It performs no new download and creates no
reference-image copy. All eleven explicitly exported report files, source pins,
PNG bytes, original zero exit, complete output and genuine CLOSED/SUCCESS/CLEANED
retention are independently verified. Every one of the eleven earlier report
files retains its original path identity and SHA-256, including the earlier
bookkeeping failure. The new export is 1473703 bytes; combined logical accounting
is 3507563 bytes against a 64 MiB task and 16 MiB export cap. These are explicit
logical measurements and budgets, not a measured physical peak. The shared
12 GiB scratch cap and 10 GiB floor remain. The report records 47 screens and
94 pairs: four unreviewed, 90 missing actual captures and zero verified matches.
The earlier browser file-preview refusal remains preserved; static files and
PNG content are verified, while browser rendering remains unverified.

The PR remains Draft. Fork results do not establish target-repository approval,
full wallet/node startup, node ABI behaviour or an owned operator environment.
All 94 visual matches, 90 other actual captures, complete formal review,
running-build motion/shaders/frame-time and seam checks, minimum-window and
Arabic layout, owned chain-321 lab and checkpoints, real-wallet behaviour and
production acceptance remain pending. The six passing chain-69 feature files
retain their earlier 27938b9bc546 source scope. Password migration and full
two-sided Swap terms remain seamed. Public output remains English and excludes
private paths, profiles, raw local diagnostics, credentials and personal identity.

### Hosted chain-321 execution path

A personal Windows machine is not a prerequisite for hosted native acceptance.
The existing hosted Windows builds and ordinary entry captures already establish
that Actions can execute this app's finite native checks. The remaining work
needs an owned runtime and a producing isolated chain, which can be created on
fresh hosted runners rather than on an owner's computer.

The default-off `chain321_lab` input adds Linux Docker and native Windows jobs.
Each checks out the same pinned go-zenon source and builds its node command with
Go 1.24.1 and CGO disabled. The generated chain identifier remains 321. Linux
uses five owned containers on an internal network; Windows uses five original
native process handles and distinct loopback peer ports. HTTP and WS remain at
the exact existing loopback origins. This avoids a public RPC endpoint, a tunnel
between jobs, and a Windows Docker Desktop requirement. Both instances keep
independent source, genesis, binary, configuration and original-exit evidence.

The controller requires advancing height and timestamp, exact HTTP/WS momentum
hash correspondence, unchanged inputs and positive shutdown. Its explicit
allowlisted manifest contains no node data, wallet profile, keys, tokens,
private paths or raw command diagnostics. A sampled 4 GiB work cap and a separate
2 GiB floor plus declared allocation bound the fresh non-secret hosted regression
fixture. Self-hosted execution is refused; local production storage retains its
10 GiB floor and existing quotas.
Actual process shutdown is separate from the runner's later destruction; no
qualified filesystem cleanup is claimed. No SDK or binary artifact is copied
to the local qualification store for this source preparation.

The initial source `bc8c95fcda6ac5ebbc75b57f3e3280de55956c97` ran both jobs in
[40174967274](https://github.com/edgepillar/syrius/actions/runs/40174967274),
attempt 1. Both Python-suite steps pass: Linux has 231 successes without skips;
Windows has 228 successes and three platform skips. Both original
node builds exit one before assets, node startup or wallet work. Complete
original logs have independently verified successful retention and cleanup;
their original negative lab results are preserved. This is not lab execution
success. The compiler's private output is not projected into the public report.

The follow-up aligns Go 1.24.1 and `-buildvcs=false` with the pinned node source's
own release workflow and checks the actual compiler version. The read-only
module constraint remains. Three additional cases verify finite compiler failure
codes and public-symbol projection without paths or raw diagnostics. This does
not attribute the original failure to a single cause; fresh execution is needed.
All three pure diagnostic cases pass locally in memory, without qualification
scratch, native process launch or wallet execution.

The current source has twenty-three offline isolation regressions and runs the complete
Python controller suite on each hosted runner before starting a lab. Local
syntax and whitespace checks are complete; the new suite has not executed
locally because storage-policy admission refused before task creation. Existing
evidence keeps its original scope. Updated hosted execution, original logs and manifest
verification are pending; authored workflow and source are not execution proof.

The new lab jobs do not import a wallet or admit seed recipes. Full native
wallet preparation, reversible checkpoints, the remaining ninety captures,
all ninety-four visual matches and running-build motion, frame-time, seam and
Arabic-layout acceptance remain pending. Those steps will use actual owned
runtime evidence rather than saved reports or synthetic Ready state.

### Read-only hosted evidence inspection

The compiler follow-up at `a9f7936dbb7b755c83d13d2532b531003da26fd8`
ran as [40177753051](https://github.com/edgepillar/syrius/actions/runs/40177753051),
attempt 1. Both Python-suite steps pass and both bounded lab steps fail. The
precise failing stage is not inferred from the job name. The finite manifests
retain the source-bound stage results and allowlisted compiler diagnoses.

A separate default-off inspection path consumes those original manifests
inside a fresh hosted Linux job. This avoids repeating node builds and keeps
local payload storage independent of evidence inspection. The inspector checks
the original repository, workflow, completed run, source SHA, attempt, artifact
names and SHA-256, archive size, sole regular ZIP member and CRC. It reads bounded
bytes in memory and extracts no files. API authorization is never forwarded to
the artifact host; plaintext, lookalike hosts, userinfo and extra redirects are
refused. Only explicit stages, compiler codes and public symbols become job
annotations. Eight in-memory regression cases pass locally without network,
SDK, profile or qualification scratch. An initial local syntax refusal was
corrected before these cases executed; no failed native result is relabelled.

An inspection is a replay of retained evidence. It establishes no fresh node
execution, live resource ownership, seed admission, wallet preparation or
visual match. Actual hosted inspection and any resulting runtime correction
remain pending.

### Portable inspector test discovery

The initial inspector source `707a478e29e0299705872fb8b2c287b07e06eac4`
ran as [40181142128](https://github.com/edgepillar/syrius/actions/runs/40181142128).
Its test step failed with `ModuleNotFoundError: No module named test.ci`
before it read a manifest. The runner resolved another `test` package.
The original 16322-byte log is hash-verified and its retention task is
CLOSED/SUCCESS/CLEANED. This is an inspector failure, separate from the two
original lab failures.

The workflow now discovers `test_inspect_chain321.py` from `test/ci` directly.
All eight in-memory cases pass locally with that exact command. A follow-up
inspection consumes the existing finite lab manifests and starts no runtime.
Its hosted outcome and any resulting runtime repair remain pending.

### Cgo build correction from retained evidence

Read-only inspection at `5b3a08d1783092f8267ebc65a356b9fd3230c623` passed
in [40181786928](https://github.com/edgepillar/syrius/actions/runs/40181786928).
Its eight test cases and both original archive validations succeed. The
source-bound manifests show Go 1.24.1 failing at build on both platforms with
undefined `secp256k1.RecoverPubkey`, `DecompressPubkey` and `CompressPubkey`.
The lab had explicitly disabled Cgo. The pinned dependency defines these
functions in its [Cgo implementation](https://github.com/ethereum/go-ethereum/blob/v1.10.22/crypto/secp256k1/secp256.go).
No node, wallet or seed was admitted in either original failed run.

The controller now enables Cgo and checks the hosted GCC target and version.
The build retains the exact node and locked modules, requests external static
linkage, and uses the standard `netgo,osusergo` tags. Before using the Linux
scratch image, a bounded ELF64 check requires an AMD64 executable with load
segments and refuses an interpreter, dynamic section or malformed header table.
Four new in-memory ELF cases and the three existing diagnostic cases pass
locally. This source repair still requires actual hosted compilation and the
original five-node production and shutdown checks; it establishes no wallet,
seed or visual acceptance.

The independent Docker build-context copy explicitly receives mode 0555;
its bytes must hash to the original verified static binary before image build.
This corrects a source-reviewed `copyfile` mode loss before the first successful
node build reaches image creation. No earlier failed build is presented as
evidence of container startup. Actual hosted startup remains pending.

### Hosted runtime follow-up

Source `a667b3ab1055595ae3c4ff13dba22031e32cf2c7` ran as
[40182361862](https://github.com/edgepillar/syrius/actions/runs/40182361862),
attempt one. Both full controller-suite steps and both Go/C builds succeed.
Both asset and port-preflight stages pass. The native report launches five
original handles and then fails during RPC observation with the old generic
code; Docker fails its resource-health gate. Both report `STOP_UNKNOWN`.
Read-only [inspection 40182680405](https://github.com/edgepillar/syrius/actions/runs/40182680405)
verifies each original archive and manifest. Compiler success is established
separately from chain production and positive shutdown, which remain unqualified.

Source review found that unrecognized wire-policy codes were collapsed into
`INTERNAL_ERROR`, and a close failure could replace the first observation
failure. The follow-up preserves the finite original code and records close
failure separately. It adds bounded observation phases, original native
terminal/signal facts, exact-created Docker resource states and allowlisted
node failure categories. Raw node logs, paths, keys and profile data remain
private. Docker log reads require the retained created ID and just-verified
image/owner labels. No log or saved summary can mint runtime ownership.

Six new cases cover wire/close failure retention, private log projection,
original resource identity, terminal projection and arbitrary data refusal.
Together with the affected existing cases, 21 distinct in-memory cases pass
locally; no native node, network listener or local qualification scratch is
created. Hosted runtime qualification of this follow-up remains pending.

### Winsock unbound socket portability

Microsoft documents [WSAEINVAL before bind](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-getsockname)
for `getsockname`. The transport had required the Unix-style unbound address
return. A new injected Winsock case first reproduced a refusal under that
adapter. The correction accepts only error 10022 before the existing single
loopback bind. A different name error or an already-bound socket still refuses;
no existing connection can be adopted. All 41 injected policy cases pass,
including two new portability/adoption cases. These are in-memory controls,
with no actual socket listener or Windows node execution. Native qualification
and the precise prior hosted wire failure remain separate.

### Node listener and fixture path correction

Read-only [inspection 40185145365](https://github.com/edgepillar/syrius/actions/runs/40185145365)
verifies the original `eb9d670b6546585c0527ae537109bc50fc62c55a` manifests
from [40184395839](https://github.com/edgepillar/syrius/actions/runs/40184395839).
The Windows report preserves `WIRE_REFUSED` at WS handshake and a real RPC
port-conflict category. Docker records three producers exiting one; its
observer and RPC resources stop zero without an OOM. Original failures remain
negative. The Winsock correction at `22a1af0cf79392f249c54036e1e4c19e5bf12b4e`
has separate 41-case injected evidence and has not yet qualified a native lab.

The pinned [RPC startup](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/node/rpc.go)
selects listeners by nonempty host strings. The controller had disabled flags
while retaining hosts, which allowed native roles to contend for the same
HTTP/WS ports. Unused roles now have empty listen hosts; only the intended RPC
node has the loopback endpoints.

Source inspection also identifies a deployment mismatch in the public
keystore fixtures. Each contains an embedded `Path` for the original container
layout. The pinned [reader](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/wallet/keyfile.go)
unmarshals that field over the actual read path, and the manager indexes the
result by that path. Relocating only the file leaves the producer unable to
find its configured key. The correction rewrites only that exact committed
fixture field to the actual owned deployment. It verifies every other field
unchanged, records source/deployed hashes, and rechecks deployed files after
production. It neither decrypts nor re-encrypts fixture material.

Three new fixture relocation/refusal cases and eight configuration cases pass
in memory locally. No real wallet, listener or node is started by those tests.
The source corrections require actual hosted production and shutdown before
lab, wallet or seed acceptance can be claimed.

### Committed fixture filename compatibility

Run [40186222018](https://github.com/edgepillar/syrius/actions/runs/40186222018)
at `0b69e6994c88b724dfdc3a08727bb40a3f5b8baa` passes both node builds, then
refuses asset preparation with `CONFIG_REFUSED` before any node starts.
[Inspection 40186644293](https://github.com/edgepillar/syrius/actions/runs/40186644293)
verifies the two original finite manifests.

The added controller guard incorrectly equated a fixture filename with its
`baseAddress` metadata. Direct checks against the exact committed pillar2 and
pillar3 blobs establish that every other guard passes, while these two fields
legitimately differ. The node does not impose their equality. The correction
preserves the address metadata independently of the filename and changes only
the deployment Path. It retains the exact committed source-path, schema, version
and crypto checks; the node retains its own producer derivation check.

The new compatibility case and twelve selected fixture/configuration cases
pass locally without native execution. Failed runs remain failed. Hosted
startup, advancing production and positive shutdown still require execution.

### Native status and bounded observation follow-up

Run [40187539825](https://github.com/edgepillar/syrius/actions/runs/40187539825)
at `6dbe9a94994e61b2aa78962fa42ed5d8ec3602eb` passes both controller-suite
steps. The complete Windows manifest passes source, build, assets, preflight,
start and stop gates. Every original node exits zero with complete output and
no forced termination. WS admission still reports `WIRE_REFUSED`; production
is unqualified.

[Inspection 40188077234](https://github.com/edgepillar/syrius/actions/runs/40188077234)
verifies the original archives. Its Windows annotation is complete. The Docker
annotation is truncated at 4096 characters and the initial local JSON read fails.
The original API output and truncated text are preserved. Its complete prefix
contains positive start/stop gates and negative production, but is not treated
as the full report. No original failure is changed into success.

Python documents that [native Windows status and POSIX errno can differ](https://docs.python.org/3.13/library/exceptions.html#OSError.winerror).
The socket guard now prefers exact native status 10022 and only uses numeric
errno 10022 when native status is absent. A conflicting native status refuses.
The translated-status case first reproduces a refusal under the old guard;
all 43 injected transport-policy cases now pass locally. Actual Windows wire
admission remains separate.

The inspector validates every retained Docker state, then emits the latest
state per role, phase counts and the first unhealthy event. It enforces a
3800-byte annotation bound, so oversized output refuses before emitting partial
JSON. All eleven inspector cases pass locally, including a 186-event repeated
health history. A further read-only inspection can consume the same original
archives without recompiling or starting a node.

### Internal bridge RPC access

[Inspection 40189022267](https://github.com/edgepillar/syrius/actions/runs/40189022267)
at `5495beae3a031d0dec615596b181269bb028e21b` successfully reads both complete
bounded summaries of original run 40187539825. Docker records 95 healthy
resource events, no unhealthy event and five zero exits, but host RPC readiness
times out with `RPC_UNAVAILABLE`. The network remains internal. The complete
Windows observation retains five zero, complete, unforced exits and WS refusal.
Production remains unqualified on both backends.

Docker documents [host access to an internal bridge](https://docs.docker.com/engine/network/port-publishing/#gateway-modes).
The next controller uses that scoped route: after checking its original network
and five created members, it probes only the fixed RPC member and its two
ports. Only after both direct ports answer and ownership is rechecked does it
create two original loopback relay listeners. No published host port or daemon
configuration change is used. The existing HTTP/WS clients still use their
exact loopback origins and validate real RPC responses and hashes. If direct
readiness fails, no relay is admitted and the lab still refuses.

The relay has no CLI, DNS lookup or configurable destination. It forwards bytes
with bounded buffers, session byte/time limits, active connections and accepts.
It retains original sockets and threads, propagates EOF, preserves unsent
prefixes and joins/closes originals before node shutdown. An unknown stop is
terminal. Raw stream contents and exceptions are never published. Finite relay
lifecycle counts can be inspected as data and never mint a runtime owner.

Eight injected relay cases and twelve inspector cases pass locally without a
real listener, thread or node. Actual direct readiness, byte forwarding,
shutdown and chain production require hosted execution. The translated native
Windows-status correction retains its separate 43-case local evidence.

### Positive Linux lab and targeted native shutdown

Qualifying source is `f594478bbd399e6f8f30b068db9de32e40a8e307`, tree
`85d3eada24aedca3f4f118f35ccb0cb020464a07`. In
[40191648994](https://github.com/edgepillar/syrius/actions/runs/40191648994),
attempt one, Linux job 121163711694 passes both the full controller-suite step
and every lab gate. It proves five original containers, direct RPC readiness,
matching HTTP/WS genesis and frontier hashes, advancing height/timestamp,
unchanged source/binary/configuration/deployed fixture bytes and five zero
container exits without OOM. The two original relays close, all twelve accepted
sessions finish, and active sockets/workers return to zero. Their finite
completed-pump byte count is 19271; this is not a physical storage measurement.

Windows job 121163711844 passes source, build, assets, port preflight, startup,
real RPC advancement and unchanged-input gates. Its RPC node receives shutdown
but exceeds the thirty-second wait and is forced; the other four exit zero.
Its overall result remains failed.
[Inspection 40192456767](https://github.com/edgepillar/syrius/actions/runs/40192456767)
verifies both exact original manifest archives and complete bounded summaries.
These outcomes admit no wallet, seed recipe, checkpoint or visual match.

The native follow-up signals every retained original peer handle once before
waiting for any member. The pinned [peer shutdown contract](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/p2p/server.go)
blocks until its peer goroutines finish; coordinated requests avoid leaving the
other four active while the RPC node drains. This is a proposed controller
correction, not a claim that the exact internal delay has been reproduced.
The thirty-second wait and positive zero/complete/unforced criteria remain.
The injected peer-dependent case first fails under the old order; all nine
original-handle cases now pass, including retained one-attempt signal failure.
Actual coordinated native shutdown requires hosted execution.

The manual workflow now accepts `chain321_backend=both|native|docker`, default
`both`, for execution and finite manifest inspection. The matrix contains only
fixed runner/backend literals. A native-only follow-up avoids rebuilding the
already qualified Linux source for a Windows-only shutdown change. Retained
momentum observations preserve exact first/last heights and timestamps; they
remain data and cannot adopt a runtime. Fourteen inspector cases and workflow
YAML/static matrix parsing pass locally. The Linux result retains its exact
qualifying source scope; target approval and complete wallet acceptance remain
separate.

### Coordinated native result and private shutdown projection

At source `9bbc04b9b3b1d90e5aeb50abd3c837e3a3af9173`, tree
`2244eb1c38aed01b7357928d958593a1be459c8d`, native-only
[40194165893](https://github.com/edgepillar/syrius/actions/runs/40194165893),
attempt one, job 121171329654 passes the full controller-suite step and every
functional lab gate. Actual chain-321 height advances from one to two with
matching HTTP/WS hashes, timestamp 1739923200 to 1792932130 and four samples.
Four original nodes exit zero, complete and unforced. The RPC node again
receives shutdown, exceeds thirty seconds and is forced with exit one. The
overall result remains failed; coordinating peers did not resolve the delay.
[Read-only inspection 40194826026](https://github.com/edgepillar/syrius/actions/runs/40194826026)
verifies the single original native archive, SHA-256
`415191e357f567e7e2b62f248fc470a52725ffbf46071b3f53f05ba49141acdc`,
and manifest `a39fcfd15638cc173e8fedf82bdc94bfce64b2a6e230d4055fc76d3685208eb3`.
The selected lane and finite momentum projection are qualified; successful
Linux execution keeps its earlier source scope and is not repeated.

The pinned [node logger](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/common/logs.go)
writes detailed stages to two files inside the owned data directory. The
diagnostic follow-up reads only those fixed files after original process exit,
using the existing one-MiB file cap, regular-file identity and ancestor guards.
Only finite shutdown codes, read/refusal status, byte counts and hashes enter
the manifest; raw text and paths are not uploaded. Missing or refused logs
remain explicit and cannot replace shutdown failure. Thirty-one injected
runtime, original-handle and inspector cases pass locally. No node source,
stop deadline, signal retry or success gate changes in this follow-up.

At `9b899609d900f9308610f61a31bf14fe5a55c4a7`, tree
`cc24061887d01f3d96d05c4194be12cb5ac6ae32`, native
[40195739913](https://github.com/edgepillar/syrius/actions/runs/40195739913),
attempt one, job 121176061168 passes its full controller-suite step and every
functional lab gate. Chain height advances one to two with nine samples and
last timestamp 1792933390. RPC shutdown still times out; four peers exit zero.
[Inspection 40196078603](https://github.com/edgepillar/syrius/actions/runs/40196078603)
verifies archive `77657fd5b5c381b723fd335b87f488ccccb3a8ff115a8156993bd03d70904248`
and manifest `204ceff2f0bad996c6dc8282a61ffac79375c7eb42246cf63f44ae8c278e3ab5`.
All five private file projections have READ status. Four nodes reach data-lock
release; RPC records a P2P stop request without HTTP-stop or lock-release
completion. Those stages do not yet identify the exact internal wait.

The next diagnostic input, `native_stack_diagnostic`, defaults off. When
explicitly selected, only the original RPC node receives the pinned
[pprof flags](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/app/flags.go)
on preflighted `127.0.0.1:45999`. After an actual thirty-second stop timeout,
the retained process permits one bounded read of its loopback goroutine
endpoint before forced cleanup. No proxy, redirect, credential, configurable
URL or external listener is used. The read has a one-MiB cap, one-second socket
timeouts and a cooperative three-second budget. Projection selects exactly
one node-shutdown goroutine and emits fixed function codes, byte count and
hash only. Missing, ambiguous, late, refused and failed-close observations
remain negative. Raw stacks, memory addresses and paths are not uploaded;
the observation never creates process ownership or successful shutdown.
Forty-one injected controller, projection and inspector cases pass locally,
as does workflow YAML parsing. Actual diagnostic execution remains pending.

### Actual protocol shutdown wait and staged consumer retirement

At `c85a45be3dbe690fe4dc26ef0aa7c99be2d59d9c`, tree
`e10ae90c554a7606757abe9262a43716521ef71d`, diagnostic native
[40202470014](https://github.com/edgepillar/syrius/actions/runs/40202470014),
attempt one, job 121196360676 passes its full controller-suite step and every
functional lab gate. Chain height advances one to two in ten samples, with
last timestamp 1792938690. Shutdown remains failed: RPC times out and is
forced; the first producer exits two with `NODE_PANIC`; three other nodes
exit zero. The producer's precise panic cause remains unclassified.
[Read-only inspection 40202967814](https://github.com/edgepillar/syrius/actions/runs/40202967814)
verifies archive `d9569ede0efd2ab82fc0be842002dd7e035132f4127a72d99a2e0051550aa0ca`
and manifest `3a47542ec4e0fd1a68cb8f74178f9d3ab8b965dd1844c4bab98534fb50246601`.
The exact 20403-byte stack response has SHA-256
`90e5991a6ef71053f53faaa0c7d2f601c7e9191eccc9ad4259ac01ba79524404`.
Its single shutdown goroutine projects `WAIT_GROUP_SEMAPHORE`, `WAIT_GROUP`,
`PROTOCOL_STOP`, `ZENON_STOP` and `NODE_STOP`. This identifies the observed
wait inside the pinned protocol shutdown path, rather than HTTP shutdown;
it does not establish which child synchronization task is holding the group.

The next controller retires the original producers and observer in creation
order before requesting RPC consumer shutdown. The pinned
[protocol stop](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/protocol/handler.go)
waits for its synchronization group. Keeping RPC alive while its peers retire
is a controller candidate, not a reproduced fix for that internal node wait.
Every original is still attempted after any failure, and all five must exit
zero with complete output and no forced kill. Native closure is one-attempt;
the actual attempted role order is retained. There is no timeout increase,
node patch, synthetic exit or retry. New injected order and retirement cases
first reject the former behavior; forty-three selected cases pass locally.
Actual qualification must use the normal profiler-disabled native path.

### Explicit upstream shutdown source

At wallet source `63e0a1282c1fe314ae6de9e72c948b6f7500929e`, tree
`232b178f551cbe9196a5e85460cf535153333c7f`, profiler-disabled native
[40203975794](https://github.com/edgepillar/syrius/actions/runs/40203975794),
attempt one, job 121200867357 passes its full controller-suite step and all
functional gates. Height advances one to two in seven samples, with last
timestamp 1792939840. The attempted retirement order is pillar, pillar2,
pillar3, observer, RPC. RPC, pillar2 and observer exit zero; pillar and pillar3
exceed the unchanged wait and are forced. Ordering alone does not qualify
shutdown. [Inspection 40204414977](https://github.com/edgepillar/syrius/actions/runs/40204414977)
verifies archive `5ecc6fc8af06f16d00bfcf4fabdbd43a10eaa775dad7c000ef9c2e743b2f3d06`
and manifest `bda1edb1c8743989293fb9dbc905c52411bc835f4e8757ecb651985217094c32`.
All prior negative results retain their original source scope.

The original node pin is dated 2026-08-20. Upstream published
[2d1b929cc3fa5269cf133757d4a6963821137984](https://github.com/zenon-network/go-zenon/commit/2d1b929cc3fa5269cf133757d4a6963821137984)
on 2026-10-23 to join the legacy run loop and protocol goroutines during
shutdown. Its exact Git tree is `4467fff960ea6a5409908d7c85497a68482e0edb`.
The manual workflow therefore adds `chain321_node_source=original|upstream`,
defaulting to original. Upstream selects only that reviewed commit, rather
than a moving branch or the latest development tip. No node source patch or
application dependency change is applied. The original `lab.sh` default stays
unchanged; its existing explicit revision override remains available.

The upstream path runs the seven named tests from its
[shutdown regression file](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/p2p/legacy/shutdown_test.go)
after the source build and before lab startup. A zero exit is insufficient:
bounded Go JSON must contain all seven exact parent passes and the package
pass, with no skip or failure. Module restoration stays read-only, and source
cleanliness is checked after the tests. Saved inspection requires the same
explicit node-source selection and publishes its exact SHA/tree and finite
regression outcomes. Reports still cannot create runtime ownership.
Forty-nine injected controller, selection and inspection cases pass locally,
as does workflow YAML parsing. The actual upstream Go regressions and native
lab remain pending; the older Linux pass is not transferred to this new pin.

### Upstream regressions pass; joining peers need coordinated requests

At wallet source `44e98f69ade57a149545d1bfa02c3f9204f83d83`, tree
`6f6d3cf79d9a810d164c8ea15da5a00c4a73bb93`, native
[40210898201](https://github.com/edgepillar/syrius/actions/runs/40210898201),
attempt one, job 121221692366 passes its full Python controller-suite step,
all seven actual upstream Go shutdown parent tests and the package, with
zero skips. Node SHA is `2d1b929cc3fa5269cf133757d4a6963821137984` and tree
`4467fff960ea6a5409908d7c85497a68482e0edb`. Build, assets, source, preflight,
startup, real chain progression and unchanged-input gates all pass. Its
chain-321 genesis hash is
`58d0e20af45243b3246c2643eacd5e65f798b56fe68fb594d0507ff18ca360cd`;
height advances one to two over twelve samples, last timestamp 1792945150.
This genesis belongs to the selected upstream fixture and is not relabeled
as the original pin's genesis.

Under sequential retirement, pillar and pillar2 exceed the wait and are
forced; pillar3, observer and RPC exit zero. The overall native result remains
failed. [Inspection 40211411457](https://github.com/edgepillar/syrius/actions/runs/40211411457)
verifies archive `659119a06494baaa35406083401cbb5d0deda1a1d095baa7037981fbc929e216`
and manifest `180e5ea656384ccf3955046e2133e4f5f563bc12e4d0d378ef4206a6798d57d4`.
The next controller requests all five original peers once in creation order
before waiting for any member, because the selected peer server now joins
its workers. It records both attempted role order and a fixed coordinated
mode. One-attempt close, strict zero/complete/unforced outcomes and the
thirty-second wait stay unchanged. The injected order case first rejects
sequential retirement; fifty selected cases pass locally. Actual coordinated
upstream-node closure still requires hosted execution.

### Coordinated upstream closure exposes an actual producer panic

At wallet source `c080b170f592e1eb9e12cbffe72c1bf3b1ec9ac3`, tree
`0146116d89841d69746166173f5868da43b2f9eb`, native
[40212552921](https://github.com/edgepillar/syrius/actions/runs/40212552921),
attempt one, job 121226724378 passes its full Python controller-suite step,
all seven actual upstream shutdown regressions and every functional lab gate.
Node SHA remains `2d1b929cc3fa5269cf133757d4a6963821137984`, tree
`4467fff960ea6a5409908d7c85497a68482e0edb`. With all five stop requests issued
before waiting, every original exits without forced termination and with
complete output. Four exit zero; pillar2 panics and exits two. The overall
native result remains failed. This attempt has no wait timeout, which does
not establish that later shutdowns are free of races.

Chain 321 advances from height one to two over fourteen samples, with last
timestamp 1792946400 and matching HTTP/WS hashes. Its upstream fixture genesis
remains `58d0e20af45243b3246c2643eacd5e65f798b56fe68fb594d0507ff18ca360cd`.
[Inspection 40214066086](https://github.com/edgepillar/syrius/actions/runs/40214066086)
verifies archive `ce7ee60b2921ad755ae900300fb649a6f6ee58017eed71b9e200920ab11aa8aa`
and manifest `efbacbe4bfb51e8b472ad7ad6e1fd9c13391af46b4998dc3d1b6d52c1b510f6d`.
The panic message and its source location were not retained in that public
manifest, so its cause remains unclassified.

The next controller projects the original bounded output into fixed panic
categories and at most three package, relative-path digest and line facts
from the crashing goroutine. A path digest does not hash file contents.
No raw message, address, local path or function arguments are uploaded.
Inspection validates all panic records and keeps only the first detail plus
count in its finite notice. Eighty-three selected injected cases pass
locally; they include private-text rejection, a five-panic notice bound and
preservation of the original exit-two failure. They do not establish a real
panic cause or a successful native shutdown. Neither full wallet startup,
seed admission nor visual acceptance is claimed.

### Actual panic resolves to the closed producer task

At wallet source `cef655cca3eca4fef05f0f3ab57337a50617ca13`, tree
`7b22ebaef4c5c55cdd5fec4a8aece6128dff6a24`, native
[40215188497](https://github.com/edgepillar/syrius/actions/runs/40215188497),
attempt one, job 121234686592 passes the full controller-suite step, all seven
actual upstream shutdown regressions and every functional lab gate. Chain
321 advances from height one to two over ten samples, with last timestamp
1792948370 and matching HTTP/WS hashes. Exact upstream node SHA/tree and its
fixture genesis remain unchanged from the preceding attempt.

All five originals exit with complete output and no forced termination.
Pillar exits two with an actual NIL_POINTER panic; the other four exit zero.
[Inspection 40215620218](https://github.com/edgepillar/syrius/actions/runs/40215620218)
verifies archive `0e1ff2b4d89971b13bdcbf83023c50dbb46dc3803f7bd46c9bc1554f493e29ff`
and manifest `842d16b3af986679d13744ba340f5b2963af2eb9e9c069ad774f44c38492d829`.
The finite panic observation covers 3270 output bytes with digest
`8308fc54db020405479856a6c773e77523d4b388e9d391d8f75e387d64ef188d`.
Its relative-source-path digest
`3bbf31c838faabed6ba1630c4568a69fb066be9dfb9f671c03d04ae7fc029fd9`
resolves to the public `pillar/manager.go`, at lines 120 and 85 in exact node
`2d1b929cc3fa5269cf133757d4a6963821137984`. Raw panic text, arguments,
addresses and local paths are not uploaded.

The pinned [supervisor](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/pillar/manager.go#L117)
calls `task.Finished()` without checking the task returned by the worker.
The pinned [worker](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/pillar/worker.go#L73)
explicitly returns nil when already closed. The actual crash is consistent
with that late-event path. The public manager blob is
`c19c5c4e7c3146617397ced7307e803a16f4723a`; it is also unchanged at the
separately inspected `ac16bfd7c083e0b808a17014c38a5a77cc0141f1` revision.
A focused real Go regression must reproduce this condition before any lab
source correction. A corrected lab source needs explicit base, patch and
compiled-tree identities; it cannot qualify the unmodified node by proxy.
The overall native result remains failed. Eighty-three local injected cases
and the hosted controller-suite step qualify the observation mechanism,
not successful shutdown, wallet startup, checkpoints, seed or visual matches.

The main progress ledger has 65 of 80 rows marked done, or 81.25 percent,
excluding corrective X rows. This is a count of recorded tasks, not a
weighted completion estimate or independent acceptance of the end state.
All 94 visual matches and fifteen main rows remain open.

### Explicit isolated correction for the closed producer task

The optional `chain321_node_source=lab-fix` choice retains base node
`2d1b929cc3fa5269cf133757d4a6963821137984`, tree
`4467fff960ea6a5409908d7c85497a68482e0edb`. It adds a focused test using the
actual closed worker and producer supervisor. No task is mocked and the
supervisor is called synchronously, so asynchronous test completion cannot
hide its panic. No chain, wallet import or network is started by that test.

The fresh hosted checkout must first fail the actual named test and package
with the observed nil-pointer panic at the original supervisor line. The
command must exit one with complete output and no forced termination.
An unrelated crash, compiler failure, empty filter or skip is refused.
Only then may the controller apply the four-line nil-task guard and require
the same test and package to pass with exit zero. The original failing
command receipt remains present and explicitly expected; it is not rewritten
as a zero exit. A cold compilation has a 600-second parent bound, the patched
test has 180 seconds, and both Go test runtimes remain capped at 30 seconds.

Patch SHA-256 is
`ce0d51dbd7791933a25864a9a03e897ac1120a0a8543150367e66bd31af8d764`;
test-fixture SHA-256 is
`22ae33b7fb4f9809352bd634bae7799c245e68f02fadc9d8c0d7d4afbb660643`.
The entire compiled tree is
`a9262cce18190bfc01e85ac903558500379d014f`, independently calculated from the
verified public base tree, changed manager blob and added regression blob.
After the change, staged-tree identity, unchanged worktree and absence of
untracked source files are required. The built binary, configuration and
deployed public fixture checks remain. All seven actual upstream shutdown
regressions still precede lab startup. Native exit requirements and waits
are unchanged.

Retained-manifest inspection must explicitly select the corrected source.
It validates both regression phases and compiled-tree provenance without
creating runtime ownership. Corrected results cannot be relabeled as
pristine upstream or original results. The default remains `original`;
neither wallet dependencies nor embedded binaries change.

Ninety-seven selected local Python controller cases pass, including fourteen
new source/regression/inspection checks, and workflow YAML parsing verifies
eleven inputs and the three fixed source choices. Ninety-five cases are
memory-only; two existing cases use small temporary filesystem fixtures.
No local Go execution is claimed. Hosted reproduction and the next failed
gate are recorded below; corrected native shutdown, both-platform lab
qualification and all wallet/checkpoint/seed/visual acceptance remain pending.

### Actual closed-task regression passes after correction

At source `4749f3ae920fe58d6a4875e7ed0c32ea86ef15c5`, tree
`b650b9f0205a96570de34025ddb80a6b87065f46`, native
[40220180835](https://github.com/edgepillar/syrius/actions/runs/40220180835),
attempt 1, job 121249862341, passes the full Python controller-suite step.
The actual focused Go test first exits one with the required nil-task panic,
then the same test and package exit zero after the pinned four-line patch.
Both original command outputs are complete and unforced. The compiled tree
is verified as `a9262cce18190bfc01e85ac903558500379d014f`, and its CLI build
passes. This qualifies the focused correction, not overall lab shutdown.

The next command, containing all seven upstream shutdown regressions, fails
with `COMMAND_FAILED` before assets, preflight or any node process starts.
The prior finite manifest does not identify the failed test or assertion.
No timeout, assertion cause or runtime outcome is inferred from that absence.
[Inspection 40220758306](https://github.com/edgepillar/syrius/actions/runs/40220758306)
verifies original archive SHA-256
`fc8f61f839ba9c80c80ea6c30323a6427e74736979c59ca55aaf649fcfdf348d`
and manifest SHA-256
`e05185e7763990c74805d0e430606b9ee10288e725c897b94d34e781c1ee343a`
inside Actions. No local artifact transport is implied.

The next observer retains only known parent-test names and their actual
pass/fail/skip/active states, public `shutdown_test.go` line numbers, fixed
failure categories and original command exit/output/forced facts. Raw logs,
paths and messages remain private. It rethrows the same failure and makes
no retry; all seven tests must still pass before any lab startup. A complete
observation is not a test pass or runtime admission. Six new checks and all
101 selected memory-only controller cases pass locally; the two existing
filesystem-fixture cases are excluded from this local run. Actual diagnosis
with the new observation remains pending. Main progress remains 65 of 80;
all wallet, checkpoint, seed and visual acceptance gates remain open.

### Reconnect regression identifies its failing public assertion

At `4e6a8d2a2ccfc920a20c1b4eff8963465c822d9b`, tree
`d890937c8b623d164ab763bf1b30cd27dc84da71`, native
[40222359939](https://github.com/edgepillar/syrius/actions/runs/40222359939),
attempt 1, job 121256478479, passes the full controller-suite step, actual
producer red/green regression and corrected CLI build. Six upstream shutdown
tests pass. `TestSameIdentityReconnectDuringGatedCleanup` fails at the pinned
`shutdown_test.go:381` assertion with exit one, complete output and no forced
termination. No test skips, assets or lab startup are reported.

That assertion rejects a second-connection error other than
`DiscAlreadyConnected`. Its exact error is not in this manifest; no socket
failure or protocol cause is inferred.
[Inspection 40222588929](https://github.com/edgepillar/syrius/actions/runs/40222588929)
verifies archive SHA-256
`84217f229d10d486e2c98f18700524a33be6504b039325cd3c758ecf07537a06`
and manifest SHA-256
`6689b6dbb64621081b27d67022bf0901e3858f5b89dac021ad3c893143c536f3`
inside Actions. The overall native result remains failed.

The next observer classifies only this exact assertion from its actual named
failed parent into fixed reset, abort, EOF, timeout, write, protocol-reason
or unclassified codes. No socket address, raw error, path or message is
published. It changes no Go test, node tree, original command result or
startup gate. Three new checks and all 104 selected memory-only controller
cases pass; actual rejection classification remains pending.

### Corrected native lab reaches production, then a producer times out

At `07d8045939fc8d3498ef55b122a47b8ace2575d7`, tree
`dbe2525a4d3fef3066f4c765e913712c84384559`, native
[40223243672](https://github.com/edgepillar/syrius/actions/runs/40223243672),
attempt 1, job 121259162560, passes the full controller-suite step, actual
producer red/green regression, corrected CLI build and all seven upstream
shutdown tests without skips. Thus this attempt does not exercise the
reconnect classifier; its earlier failure remains unresolved. No Go source
or assertion is changed between the two attempts.

Every functional lab gate passes. Chain-321 advances from height one to two
across eight samples with matching actual HTTP/WS hashes, genesis
`58d0e20af45243b3246c2643eacd5e65f798b56fe68fb594d0507ff18ca360cd`
and last momentum timestamp 1792954420. Original inputs remain unchanged.
Four originals exit zero, complete and unforced. `pillar2` has an actual
`WAIT_TIMEOUT`, is forced and exits one with complete output. Its finite
private-log projection reaches the P2P stop request without data-lock release.
No nil-task panic is recorded; overall native shutdown remains failed.

[Inspection 40223625714](https://github.com/edgepillar/syrius/actions/runs/40223625714)
verifies original archive SHA-256
`d40442d2c1ab864374fe329cec33658fe17eeb1fe3c8ed8bc47475d4b8d7a1d3`
and manifest SHA-256
`fe87da24cd7506106129f378a1d4e894e3fe95b1e7cb8f7bece4d281c297464e`
inside Actions. This transfers no wallet, seed or checkpoint authority.

The next optional diagnostic gives each original role a fixed, separate
preflighted loopback profiler port. A real stop timeout permits one bounded
read from that original's bound role/port before its existing forced cleanup.
It retains only fixed shutdown-frame codes, byte count and digest. Unknown
bindings are refused. Inspection preserves every exit and per-role status,
validates all probe records and emits one captured detail within its notice
bound. Legacy RPC-only records retain their separate scope. Seven new checks
and all 111 selected memory-only controller cases pass; actual producer
frames remain pending. Waits, Go assertions, node source and default-off
behaviour are unchanged. Main progress remains 65 of 80, with zero accepted
visual matches.

### Actual producer shutdown waits in the protocol manager

At `a0e0b2a7375bd28e2697f43b68c82d76f807471e`, tree
`a8b982119fe471c462c5c5ae8123fecda00bfdf6`, native
[40224595496](https://github.com/edgepillar/syrius/actions/runs/40224595496),
attempt 1, job 121263177846, passes the full controller-suite step, actual
producer red/green regression, corrected CLI build, all seven upstream tests
and every functional chain-321 gate. Eleven samples verify height one to two,
matching HTTP/WS hashes, unchanged inputs and last timestamp 1792955470.

With the explicit diagnostic enabled for original roles, `pillar` actually
times out during stop. One bounded read before its existing forced cleanup
captures 18798 bytes, SHA-256
`618ade1eef094719678088c837a59ceb94c7e7d9aea6d493d0265cfa330ea6fc`.
Its fixed shutdown frames are `WAIT_GROUP_SEMAPHORE`, `WAIT_GROUP`,
`PROTOCOL_STOP`, `ZENON_STOP` and `NODE_STOP`. This locates the wait in
`ProtocolManager.Stop`; it does not identify which joined worker remains.
The original forced exit one and failed overall result remain. The other
four originals exit zero with complete output and no forced termination.

[Inspection 40225084926](https://github.com/edgepillar/syrius/actions/runs/40225084926)
passes its controller-suite step and verifies archive SHA-256
`28f46f167b6efd7d8d018172d1a0428b9265285b9f822ea2473b232028c4ce82`
and manifest SHA-256
`6bc3e62384acbe1dcc0e4f318931e6cfaf8bcf2e0ca7daf4b2cb6d1bf1611ba5`
inside Actions. Raw stack text is not uploaded. Protocol-worker diagnosis
and full corrected lab acceptance remain pending.

### Hosted Windows desktop setup reconciles P04

The retained qualification at application source
`1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0`, tree
`9a8eec6320aa5cf1be0cad89f4bf9b4e8e979d18`, Windows
[40142185606](https://github.com/edgepillar/syrius/actions/runs/40142185606),
attempt 1, job 121016046890, already executes desktop enablement and doctor
with exit zero, complete output and no forced termination. Their durations
are 0.844 and 29.515 seconds. The Windows and Visual Studio doctor sections
pass, which satisfies P04 in the requested hosted Windows desktop scope.
This is not a claim that every unrelated platform doctor section passes.

The original 39669-byte job log is pinned to SHA-256
`6d5b128bf3ee657ba78b7c36e54b12e631e6c954dc282bd376ffe425c8fa40df`.
Read-only reconciliation verifies the retained source/run/log record and
successful transport closure, then confirms unchanged application, harness,
assets, patched packages, dependency files and baseline controller/tests.
No build, test, native process or artifact transport is repeated. Optional
inventory timeout, missing Pillow and unavailable Docker daemon remain
negative records; the personal machine and full wallet startup remain
unqualified. The latest main ledger therefore has 66 of 80 rows done,
or 82.5 percent, with fourteen main rows and all 94 visual matches open.

### Bound the protocol worker source locations before changing shutdown

The pinned `protocol/handler.go` blob
`fc18700d7a09175ea23f2fe7f1b7fd81df3a2522` counts the syncer wrapper and
account-block processing in the wait group observed during stop. Its
`protocol/sync.go` blob is `3a9580d9a33b0340debb1d1364444a75c3f86635`.
The actual stopped-owner stack does not identify which of these worker
paths remains; a source hypothesis alone does not justify a node correction.

The next bounded projection selects only actual syncer-wrapper and
message-handler goroutines from the same captured original shutdown output.
It emits fixed kind and wait-state codes, a public protocol package name,
the SHA-256 of its relative source path and a positive source line number.
The path hash does not hash source contents. Raw function arguments, absolute
paths, goroutine identifiers and arbitrary wait text are not emitted.
Unknown waits become `OTHER`; malformed headers or source locations refuse
all partial worker facts. An absent original shutdown owner admits no worker
projection. Counts retain actual matching workers; at most four unique sites
are retained and two projected, with the syncer first.

Inspection validates every retained site before compaction. Native notices
omit empty Docker and diagnostic fields to preserve the complete 3800-byte
bound; nonempty failure diagnostics remain. Existing four-field probe
records remain readable. Eight new checks and all 119 selected memory-only
controller cases pass. The 35 inspector cases pass after the final compact
projection change. A retained native-notice size check includes two source
sites without starting a process. Actual worker locations remain pending;
no Go source, assertion, timeout, wallet or seed admission changes.

### Corrected Windows lab completes all original exits

At `64b269f8cfdfab920762cf1770ddac8ef5a12532`, tree
`46b67eff147dbd3a262e5e88c5bef81786b2f09a`, native
[40226727980](https://github.com/edgepillar/syrius/actions/runs/40226727980),
attempt 1, job 121269562394, passes every job step and lab gate. The actual
producer red/green regression, corrected CLI build and all seven upstream
Go tests pass without skips. Compiled node tree remains
`a9262cce18190bfc01e85ac903558500379d014f`. Chain-321 advances one to two
across eleven samples with matching actual HTTP/WS hashes, unchanged inputs
and last timestamp 1792957080. All five originals exit zero with complete
output and no forced termination.

[Inspection 40227385030](https://github.com/edgepillar/syrius/actions/runs/40227385030)
verifies archive SHA-256
`005f819bbeac410ff8672318a4dfa1ec1ebbc419f615e3d152187062735020d2`
and manifest SHA-256
`a29398bf465a07a451a1b957d16ee1c029a17a6671b8c84d6160c4a8f35e5c4d`
inside Actions. This positive result uses the explicit per-role profiler
configuration. No timeout occurs and zero stack probes are captured, so the
new protocol-worker projection is not exercised. Earlier intermittent
reconnect and protocol-stop failures remain unresolved. This is a bounded
node-lab result, with no wallet, checkpoint, seed or visual acceptance.

### Corrected Linux production passes before sequential RPC stop fails

At the same source, Docker
[40227495431](https://github.com/edgepillar/syrius/actions/runs/40227495431),
attempt 1, job 121271889337, passes its controller-suite step, static Cgo
build with GCC 13.3.0, actual producer red/green regression, all seven Go
tests and every functional lab gate. Five samples verify height one to two,
matching HTTP/WS hashes, unchanged inputs and last timestamp 1792957600.
Both original loopback relays close with all nine sessions completed, zero
active sessions and no worker alive. Four containers exit zero; RPC exits
137 without OOM during the first sequential stop. Overall qualification
remains failed.

[Inspection 40227913257](https://github.com/edgepillar/syrius/actions/runs/40227913257)
verifies archive SHA-256
`4c60fd71ee32deac4e0a0d785553810907cd33626361517cc7ebb6e9fbc9a614`
and manifest SHA-256
`79790d0aad783e7973c4a2dc651dd8ff8ccb9d0525c9bb821589773b71e66b19`
inside Actions. The controller had not requested the other four stops
while waiting for RPC. This does not prove the cause of the node's wait.

The next controller first verifies the entire owned set, then supplies all
verified original identities to one [Docker stop invocation](https://docs.docker.com/reference/cli/docker/container/stop/).
The twenty-second daemon grace and thirty-second parent bound remain.
It preserves the actual command exit/completeness/forced receipt, observes
every original afterward, rechecks identities and refuses a second stop.
Any original nonzero exit, OOM, changed identity or failed/incomplete/forced
command keeps qualification failed. Seven new checks and all 126 selected
memory-only controller cases pass. Actual corrected Docker closure remains
pending; no node source, Go assertion or wait limit changes.

### Limit the read-only inspector checkout

The inspector materializes only `tool/ci`, `test/ci` and `tools/devnet/lab`
through the existing checkout action's [sparse checkout](https://github.com/actions/checkout/tree/v6#fetch-only-the-root-files-and-github-and-src-folder).
Credentials remain disabled and no explicit filter overrides the sparse
selection. Runtime jobs keep their existing checkout. Source/run binding,
original archive verification and finite projection remain unchanged.
Workflow parsing confirms eleven inputs and unchanged defaults. Hosted
sparse execution and actual byte or disk savings remain unmeasured.

### Corrected Docker batch shutdown completes all original exits

At `15f324953f2b79d4b1073538c4c80e43a42ea0c1`, tree
`3caffb5d47c4dbc27ef39d888a9f31ae0ede47e6`, Docker
[40229022991](https://github.com/edgepillar/syrius/actions/runs/40229022991),
attempt 1, job 121276555950, passes every job step and lab gate. Static Cgo
build, actual producer red/green regression and all seven upstream tests
pass with compiled node `a9262cce18190bfc01e85ac903558500379d014f`.
Eleven samples verify chain-321 height two to three, matching HTTP/WS hashes,
unchanged inputs and last timestamp 1792959070. The original batch-stop
command exits zero with complete output and no forced termination, using
roles RPC, observer, pillar3, pillar2 and pillar. All five containers exit
zero without OOM. Both relays close with all fifteen accepted sessions
completed, zero active sessions and no worker alive.

[Inspection 40229841780](https://github.com/edgepillar/syrius/actions/runs/40229841780)
verifies archive SHA-256
`9b44bb376bda31cf48b6371ab0b151088540b03fa05a8dd26c1386e3852c484d`
and manifest SHA-256
`753b0f995f69ce7162f6a9c6a51083f520ac8eb7b360042012b4a7408d9a7fec`
inside Actions. Its sparse checkout, controller-suite step and original
archive inspection all pass. This qualifies the limited source selection;
actual download bytes and disk savings are not measured. No local archive
transport, cache cleanup or successful storage-task closure is implied.

Together with the separately pinned Windows result at `64b269f8cfdf`, this
provides positive corrected-node lab attempts on both backends. Windows
uses the explicit per-role profiler configuration. It does not establish
that the earlier intermittent Windows protocol wait or reconnect assertion
is resolved. The original default node, unmodified upstream node and prior
failed attempts retain their own scopes. Full native wallet startup and
reversible owned chain/profile checkpoints are next. No wallet or seed
recipe is admitted by these node-lab records; main progress remains 66 of
80, with ninety missing actual captures and zero accepted visual matches.

### Reconcile P05 and P06 with their written hosted requirements

The retained source-bound Windows baseline at
`1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0`, run 40142185606 attempt 1,
job 121016046890, already meets P05's locked dependency, generated source,
localization and DLL loading requirements. Source, Debug and Release DLLs
actually map and expose both expected symbols in separate isolated children.
Their bytes share SHA-256
`f1f79ee184b9c0e3cd92d2f5c49e52c68e7a4670357a0cf1df95a0ac6de8973a`.
All thirteen localization files retain identical before/after digests.
Loading and symbol lookup remain distinct from invoking either export.

The same completed Windows run supplies P06's current baseline:

| Original stage | Seconds | Result |
| --- | ---: | --- |
| Root analysis | 46.141 | 0 errors, 0 warnings, 1295 infos |
| Vendored analysis | 19.234 | 0 diagnostics |
| Unit/widget tests | 888.984 | 4354 passing events, 2 skips, 0 failures/errors; 506 hidden terminal events recorded separately |
| Debug build | 141.703 | Passed |
| Release build | 188.172 | Passed |

Every listed command has original exit zero, complete output, no overflow
and no forced termination. Read-only reconciliation verifies the retained
source/run/log record and successful transport closure. Application,
harness, assets, patched packages, dependencies, analysis options and
baseline/probe sources remain unchanged. No build, native process, test or
artifact transport is repeated. Fast's separate 4355/one-skip count retains
its own platform scope.

P05 and P06 therefore record their written loading and current-baseline
requirements as complete for hosted Windows. Node ABI invocation, full
wallet startup, the debug loop and old-build frame comparison remain
unqualified in their respective gates. Optional inventory failures remain
preserved. The latest main ledger is 68 of 80 rows, or 85 percent; twelve
main rows and all 94 accepted visual matches remain open.

### Optional hosted Windows debug loop: candidate preparation

The manual Public Contribution Qualification workflow adds
`windows_debug_loop`, false by default. Select it with the desktop builds,
presentation, devnet, baseline, entry capture and chain-321 inputs false.
This lane restores the existing lockfile, generates source metadata,
enables Windows desktop, tests the finite controller and analyzes its typed
Dart client before launching an ordinary harness entry. It adds no package
dependency: `vm_service` 15.2.0 is already pinned in the existing lockfile.

The controller creates a new profile under `.harness/`, redirects HOME,
USERPROFILE, APPDATA, LOCALAPPDATA, TEMP, TMP and XDG storage, removes inherited
credentials/proxies and refuses an existing Syrius process. A new Python child
waits for START before launching the SDK. The controller assigns that original
child to a private Windows job before releasing it. The SDK runs the exact
equivalent of:

```sh
flutter run --machine --no-pub -d windows --target harness/app/main.dart \
  --dart-define-from-file=.dart_tool/git_metadata.json
```

The private harness ping, OS job membership, original executable path and
typed `getVM` PID must identify the same application. Only its ordinary root
isolate is admitted. The harness adds a CI-gated counter marker outside shipped
`lib/` sources. The client sets a breakpoint at that marker, observes the
matching pause, resumes and checks the result. Serialized Flutter machine
commands then request hot reload and hot restart. The client requires preserved
counter/isolate state after reload and a new isolate with reset counter state
after restart. No source edit, wallet import, seed or chain operation is part
of this recipe.

One uncertain command holds the session; no command retry or replacement app
is admitted. Explicit app-stop, actual original app/tool exits and complete
bounded output are recorded separately. In this first candidate, closing a
nonempty job is forced cleanup and fails qualification. Only the finite manifest is uploaded; no
profile, token, service authentication URL, process ID, raw output or local
path is an artifact.

All 26 protocol/controller cases pass locally using in-memory streams and fake
processes. Native job ownership, Dart analysis, breakpoint/reload/restart and
actual process exits have not yet executed for this candidate. A DevTools URL
establishes availability only; frontend attachment is still pending. The
controller therefore leaves `debug_loop_qualified` false and P07 open, even
if its narrower runtime checks later pass. Earlier application and capture
results retain their original source bindings; the new harness marker requires
its own hosted evidence.

### Debug controller portability and actual DevTools frontend candidate

The first Windows debug run, `40237881988`, attempt one, job `121303253941`,
at `f7e6d76e804cbdc41bd3ce77eda350220fdd39e4`, completes SDK setup, locked
restoration, metadata generation and desktop enablement. Its Python test step
fails; Dart analysis and native debug execution are skipped. The original
failure remains recorded. A test's POSIX-only string expectations are corrected
to compare the actual path representation and exercise an explicit
`PureWindowsPath` as well. The exact original failure transcript has not been
locally inspected, so this source correction is not claimed as a verified
explanation of that CI failure.

The new frontend controller uses Node 24 and a standard installed Chrome or
Edge browser. A new Node child waits for START and private input until assigned
to the same owned Windows job. Only then does it create a new browser profile
and start the browser in headless mode. The SDK's exact DevTools address must
target the original loopback service. Browser protocol observations must see
that page send `getVM` on its own service socket and receive the correlated
original application PID. Availability, an unsolicited VM reply, a replacement
socket, another PID, an error or a late reply after closure cannot substitute
for that exchange. The loaded page must also identify itself as DevTools.

The browser closes through its protocol; its original zero exit and complete
bounded output must be observed before application stop. Its disk-cache target
is 16 MiB, no browser package is downloaded, and the existing application
lockfile is unchanged. Only after every debug check, actual app/tool exit and
unforced job closure succeeds can this candidate mark `debug_loop_qualified` true.
This headless frontend check does not qualify wallet visuals or the full tour.

All 29 Python and eight frontend policy cases pass locally in memory. They
cover the corrected path representations, finite frontend receipts, original
request/PID binding, held failures and WebSocket control frames. Actual Dart,
browser and debug execution remain pending. CI now emits bounded finite test,
analysis and runtime annotations so later read-only observations can distinguish
these stages without transporting complete job logs. No earlier native test or
successful node-lab run is repeated.

### Direct debug-test discovery on hosted Python

Source `f7568f4f5d25dde3f888dd90785c20e390349f16`, run `40239804863`, attempt
one, job `121308980062`, completes setup and reaches the finite test runner.
Its notice records two errors, both `unittest.loader._FailedTest.ci`, with
zero actual debug cases, native executions or skips. Later Node, Dart and
runtime steps are skipped. The first path correction therefore does not
resolve test loading on that runner. This negative attempt is retained.

The candidate now discovers the two test files directly under `test/ci`,
using standalone module names. Its test fixtures no longer import through
`test.ci`. A regular installed `test` package takes precedence over this
repository's namespace portion under Python's import rules; direct discovery
avoids that dependency. The notice alone does not identify the installed
conflicting package, so its identity is not claimed as observed.
See [Python's namespace-package specification](https://peps.python.org/pep-0420/#specification).

A new in-memory regression control installs a regular `test` module in
`sys.modules` and requires all discovered cases to remain loadable. All thirty
debug-controller cases pass locally. The frontend source and its eight prior
local cases are unchanged. Dart analysis now has an independent non-cancelled
step so a test-load failure cannot hide analysis evidence; native startup still
requires every preceding gate to succeed. Actual hosted debug acceptance
remains pending.

The directly supervised SDK invocation also includes the Flutter tool's existing
`packages/flutter_tools/.dart_tool/package_config.json`, matching the chosen
tag's [Windows launcher](https://github.com/flutter/flutter/blob/3.47.7/bin/flutter.bat).
It still runs the original Dart executable and tool snapshot as an argument
list without a shell. The package configuration must already exist after SDK
setup; it is not generated or replaced by the controller. This argument
correspondence is checked before another hosted attempt, rather than repeating
the earlier source unchanged.

### First owned debug startup and typed-client correction

Source `0f0bb628d12d41cba9ef2add505c2661cb76f707`, tree
`2e7e6b20d9038af420bbf4f3129c1c590f533dbd`, run `40240816505`, attempt one,
job `121312004458`, passes thirty Python and eight frontend policy cases on
Windows. Dart analysis exits zero with zero errors, zero warnings and nine
infos. The actual SDK run starts the ordinary application. Its private
harness identity, original executable and membership in the owned Windows
job are verified. The tool reports a VM service and DevTools availability.

The typed probe fails before VM/root binding. Its exit is one; 136 output
bytes are complete without overflow, SHA-256
`98e0cc9992cb0d08c0fb19c93c9d188c62ea60a72baab24c614de1b0bad8c50d`.
Raw probe output has not been inspected. The parent records forced cleanup;
its zero bootstrap exit cannot establish successful application or tool exit.
No breakpoint, reload, restart, frontend connection or wallet acceptance is
established. The manifest is uploaded separately; no local artifact transport
or retention is claimed.

The candidate launches the typed client directly in the Dart VM with the
existing application package configuration. This removes implicit package
resolution from `dart run`; the original output's cause remains unclassified.
Any new nonprotocol startup line records only a fixed shape code, byte count
and SHA-256. It cannot complete or replay the reserved bind request. The
candidate also addresses the nine newly introduced analyzer infos, including
the counter return, typed callback and long lines; a fresh analysis is required
before calling those diagnostics resolved.

Shutdown requests the ordinary harness's existing `quit` operation once and
requires its exact acknowledgement, original application zero exit, observed
tool stop event and original tool zero exit. A missing acknowledgement is
uncertain and is never retried. This uses the application's normal window-close
path: the pinned Flutter [desktop stop implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_tools/lib/src/desktop_device.dart)
calls process termination, which cannot substitute for a graceful close.
This close path was not reached by the failed attempt.

All thirty-six controller cases pass locally in memory, including startup
projection/privacy, a reserved failed bind and positive, invalid or uncertain
ordinary-close acknowledgements. Frontend code retains its unchanged eight
hosted cases. Static Python/frontend gates now precede Flutter setup to avoid
SDK allocation when those gates fail. Analysis still runs independently after
successful SDK/dependency setup; native execution requires all earlier gates.

### Verified native breakpoint, reload and restart; frontend remains open

Source `2f57967ec07e9edf6e2e00fe911fb804fc403fe7`, tree
`d258e6dd81c901a859ad519f3ba2f562a3c191d9`, run `40266663441`, attempt one,
job `121390457623`, passes 36 Windows controller and eight frontend cases.
Static cases execute before SDK setup. Dart analysis of the client and harness
entry exits zero with no errors, warnings or infos, complete empty output and
no overflow. The nine new infos are resolved for these two inputs; the earlier
application-wide informational backlog retains its own scope.

The original ordinary app starts within the owned job. Its VM PID and single
root isolate match. The actual source breakpoint is hit and resumed, returning
counter one. Hot reload succeeds with the same isolate and counter two; hot
restart succeeds with a new isolate and counter one. The original typed probe
then closes with exit zero and complete output. These are real Windows runtime
facts, not results inferred from the in-memory protocol cases.

The real frontend process exits one with `FRONTEND_UNCONFIRMED`. Its browser
is force-closed; ordinary app/tool close is not reached. Parent forced cleanup
remains negative, and the zero bootstrap exit is not positive shutdown proof.
The earlier frontend notice lacks the intermediate request/page observations,
so neither a missing VM exchange nor premature page readiness is asserted as
the cause. The original finite manifest remains separately uploaded.

The candidate records only fixed frontend phases, original service-socket
presence, correlated getVM request/reply counts, other-socket/worker counts and
page/runtime booleans. Console messages, addresses, IDs and page text remain
private. After a verified frontend VM reply, page readiness may be observed
within a bounded read-only interval; availability, a title or another socket
still cannot establish attachment. Close frames retain their actual closed
state. The receiver refuses contradictory, malformed or incomplete observations
even when a frontend's positive bit is set.

All 37 Python and nine frontend cases pass locally in memory; native frontend
execution for the new observations is pending. Application, harness and typed
Dart client sources remain unchanged from the preceding native attempt. The
remaining complete-debug, full-wallet, checkpoint, seed and visual gates stay
open, with every earlier failure preserved.

### Frontend title guard corrected to SDK-origin identity

Source `af930ac44d55f0d40a78846f92817c1d2af3f20c`, tree
`aa7be39f4c705988f59886dbd6b70511fe7db314`, run `40268791052`, attempt one,
job `121396902811`, passes 37 Windows controller/nine frontend cases and clean
Dart analysis. Native breakpoint, reload and restart checks pass again. The
frontend reaches `vm_matched`: its original service socket sends one `getVM`
and receives the correlated original application PID. The page is loaded and
ready, without runtime exceptions or observed WebGL/Wasm issues. One worker,
one other socket and two failed network requests are finite observations.

The guard rejects the ready page because its title does not contain the word
DevTools. The title text itself is not read into the report. Requiring that
presentation string was an extra constraint, not the specified attachment
proof. The candidate retains the exact SDK-issued frontend address for
navigation and requires the current document's origin to match that SDK
server. A correlated frontend VM reply for the original application, ready
document and actual browser zero exit remain mandatory. The title is observed
without deciding identity. A different origin still refuses acceptance even
when its title says DevTools.

All 38 Python and ten frontend cases pass locally, including title changes,
wrong scheme/host/port and contradictory receiver facts. The controller also
records the actual application exit code and remaining owned-job process
count before closure. Current application, harness and typed Dart sources
remain unchanged. The prior attempt is still failed with forced cleanup;
normal application/tool closure was not reached, and complete P07 remains
pending fresh native execution.

### Complete debug actions and original exits; two owned helpers remain

Source `68134d201468d396f7761ba5cef18a4edab308c7`, tree
`4a2d0cb5b14275ecf6783f0b3de2b5c7fa841046`, run `40270096163`, attempt one,
job `121400837937`, passes 38 Windows controller/ten frontend cases and clean
Dart analysis. All 24 runtime checks pass: original application/VM binding,
breakpoint, reload/state preservation, restart/state reset, actual frontend
SDK-origin/getVM binding and ready document, normal browser exit zero,
typed-probe exit zero, ordinary-close acknowledgement, original application
exit zero, tool/bootstrap exit zero, complete output and unchanged source.
The frontend still has a nonmatching presentation title; its actual origin
and VM reply now establish the required identity correctly.

The owned job reports two active members after those original actors exit.
Closing it is forced cleanup, so the attempt remains failed with
`debug_loop_qualified` false. The remaining images have not been observed;
no Dart, browser or compiler role is guessed. The pinned Flutter
[DevTools launcher](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_tools/lib/src/devtools_launcher.dart)
starts a separate process and terminates it on close, but this source fact
does not identify the two remaining processes in this particular run.

The candidate queries only its original private Windows job, with at most
64 returned members. Each temporary read-only process handle must still
belong to that job before its image is examined. Only fixed executable-name
classes and counts are reported, without process IDs or paths. A changed,
partial or failed query remains UNKNOWN. This observation cannot change a
failed result or prevent the existing owned cleanup. It does not alter the
application, typed client, frontend policy or any shutdown grace period.

The provisioning ledger also reconciles the retained Windows inventory at
source `1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0`: Windows 10.0.26100 x64,
Git 2.56.0, CMake 4.4.4, Flutter 3.47.7, Dart 3.13.5, Python 3.12.10,
Node 22.23.4 and Docker client 29.7.2. The original scoped Git Bash/Pillow
queries did not locate those tools, and optional Windows inventory timeout
leaves several fields unknown. Later builds and actual browser/debug actions
have their own source-bound proof. P01/P03 remain open for complete inventory
and installation reconciliation; they no longer describe the hosted Windows
environment as unavailable. No original test or artifact transport is repeated
for this documentation correction.

### Observed helper images and scoped teardown candidate

Source `649a9ec2760f682ea6ac76700d6a19e25983c8db`, tree
`b51da36c9f73771b9d080a5d52302791a46ed799`, run `40272151250`, attempt one,
job `121407079542`, again passes all 24 runtime checks, 38 Windows controller
cases, ten frontend cases and zero-diagnostic analysis. The original app,
tool, bootstrap, typed probe, frontend controller and browser all exit zero
normally, with complete captured output. The final owned-job observation is
complete and identifies one DART image and one VCTIP image. Closing that
nonempty job sets forced cleanup and the attempt remains failed. An image
class alone does not identify the Dart helper's specific service.

The next candidate separates required debug actors from auxiliary teardown.
Every required check, unchanged source, original zero exit, complete output,
unheld stopped protocol and absence of pending commands must be established
before helper teardown is admitted. At most one helper using the exact pinned
SDK Dart image and one using the VCTIP image beside the CMake-recorded MSVC
compiler are allowed. All original handles, membership, image paths and image
digests are bound before the first termination request. Unknown, duplicate,
changed or partially observed members refuse admission.

An active admitted helper receives one termination request through its retained
handle. Windows termination is asynchronous, so the controller waits for the
original handle and checks its actual exit value, following the
[Windows API contract](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess).
The explicit nonzero marker `0xE000D007`, image digest, request/result and exit
observation are retained. Helper standard streams are not claimed captured.
No signal is retried. A helper that already exited must have actual exit zero;
an earlier nonzero exit cannot be converted into success.

Manifest schema 2 preserves aggregate `forced_cleanup` and adds
`required_actor_forced_cleanup` and `auxiliary_cleanup`. It permits qualification
with explicitly recorded forced auxiliary teardown only after all required
actors passed and the owned job is empty. Any forced required actor, unknown
member, unconfirmed helper exit or remaining member still fails. This is an
explicit change to the controller's auxiliary cleanup policy; it does not
reclassify either earlier failed run or report a forced helper as a normal exit.

All 49 controller cases pass locally in memory, including mixed/duplicate
member refusal before any signal, binding both original handles before
termination, unconfirmed termination without retry, and rejection of failed
required actors. The ten unchanged frontend cases retain their preceding
Windows result. Native execution of this new cleanup policy remains pending;
P07 stays open. The full wallet tour, chain-321 wallet send, captures, visual
matches and final acceptance retain their separate requirements.

### Helper admission refusal and strict full-tour coverage

At source `9ef271a0dc721442dca8a07bec944e5a4130810f`, tree
`460b7a0a40ffcbbe49d77be7dbbdf171e19ea5f5`, run `40275203482`, attempt one,
job `121416384186`, all 49 controller cases, ten frontend cases, clean Dart
analysis and all 24 original debug checks pass. The six required original
actors have actual normal zero exits and complete captured output. The helper
admission returns `HELPER_IMAGE_REFUSED` before recording any admitted helper
or requesting termination. Fallback job closure observes two remaining members,
DART and VCTIP, and preserves the overall failure. The precise image-admission
cause is still unknown; the original result does not justify relaxing its checks.

The next candidate retains those checks and records only a fixed admission
stage, image class, executable byte count and path-match boolean. It exposes
neither process IDs nor executable paths. This distinguishes compiler-metadata,
path and image-pin failures without transporting raw logs or rerunning an
unchanged artifact download.

The full-wallet tour also had a source-level false-success path: a failed
navigation printed a warning and continued without counting a problem. It now
requires the complete current page catalog and visits all eleven main pages
plus Apps. Sentinels is reached through Nodes, and Apps through Settings even
when a WalletConnect project ID is absent. Each page needs successful navigation,
zero error widgets, zero SEVERE/SHOUT/FLUTTER logs and a capture. Existing captures
are refused, raw log/widget details are not printed, and changed wallet context
stops further navigation. A finite final receipt retains requested and actually
visited pages; a partial tour cannot report complete.

Six new regressions exercise complete coverage, both merged sections,
unreachable pages, incomplete/duplicate/unknown catalogs, widget/log failures
and changed wallet context without a native wallet or filesystem capture.
Their hosted Dart execution is pending. The Windows debug lane runs these
selected tests before allocating a native debug build and analyzes the changed
CLI as well. All 49 Python controller cases pass locally; the unchanged ten
frontend cases retain their preceding Windows evidence. This preparation does
not complete P07, P08, a chain-321 wallet send or any visual match.

### Hosted tour regressions pass; CMake metadata lookup is narrowed

Source `e1d4431a53e10819124168cd6d74794585dc510f`, tree
`7f430946a3c9e6b3f892ccae4ac0fe20df28d833`, run `40277412548`, attempt one,
job `121422979571`, passes all six tour regressions with no skip/error event,
49 controller cases and ten frontend cases. The selected Dart analysis has
zero errors, zero warnings and 15 formatting infos. All 24 native debug checks
again pass with original normal zero exits. Helper admission fails at
`compiler_metadata` for VCTIP, before a path match, image pin or signal. The
two-member forced fallback remains a failed result.

The source matcher accepts only plain numeric CMake directories. Microsoft
documents [CMake builds with vendor suffixes](https://learn.microsoft.com/en-us/cpp/build/get-started-linux-cmake?view=msvc-170),
including `3.11.18033000-MSVC_2`. The next candidate admits bounded vendor
version suffixes and adds a regression for these names while rejecting paths
and oversized labels. The exact recorded absolute MSVC compiler, sibling
VCTIP image, original job handle and immutable image requirements remain.
The particular generated directory name from this hosted run was not retained;
this correction is not yet a proven explanation of that original refusal.
All 50 controller cases pass locally. The 15 new Dart infos are corrected in
source; a fresh hosted analysis remains required.

A separate gated Dart entry prepares the actual P08 build/start/import/tour
sequence. It requires an explicit hosted opt-in, a new instance and unused
build destination. It waits before build and again before receiving private
input, allowing its future parent to bind the original app and lab first.
The public lab input travels over stdin. Its profiles and captures stay private.
This entry is not yet connected to the owned lab controller and cannot establish
native wallet qualification. A negative control requires missing opt-in to exit
with the fixed refusal marker before any build destination exists. Both that
control and the new entry's selected analysis await hosted execution. Application
dependencies, published application sources and the Windows workflow's input
defaults remain unchanged.

### Hosted Windows debug loop qualified

Source `fc6515e8ffbc6d86db720f02846598fea9847109`, tree
`6157da75da60acfc32c5726e0ae51d246e507630`,
[run 40279392842](https://github.com/edgepillar/syrius/actions/runs/40279392842),
attempt one, job `121429091241`, passes every selected job step. All 50
controller cases, ten frontend cases and six tour regressions pass. Selected
analysis of the typed client, harness entry, CLI, CI entry and tour tests has
zero errors, warnings and infos, with actual exit zero and complete output.
The existing application-wide informational backlog retains its earlier scope.

All 24 native checks pass, including the same original app/VM/root binding,
breakpoint hit/resume, reload with preserved counter/isolate, restart with new
isolate and reset counter, actual SDK-origin frontend getVM exchange, ordinary
close acknowledgement and unchanged source. Browser, frontend controller,
typed probe, original application, tool and bootstrap all exit zero normally.
Their captured output is complete and no required actor is forcibly stopped.

The corrected metadata lookup admits the actual compiler-associated VCTIP and
exact SDK Dart images. Both owned auxiliary processes receive their single
explicit termination request, with observed nonzero marker `0xE000D007` and
retained image digests. Their standard streams are not claimed captured.
Aggregate forced cleanup remains true, required-actor forced cleanup is false,
and the job has zero members at close. Schema 2 reports this scoped auxiliary
teardown honestly and sets debug-loop qualification true. Earlier failed
attempts are not reclassified. This completes the written P07 debug recipe.

The gated wallet entry's negative control also passes: missing opt-in produces
the fixed 16-byte refusal, actual exit one and complete unforced output before
a build destination exists. This is an expected refusal control, with zero
native wallet executions. P08 still needs its owned lab/controller connection
and actual full onboarding/tour; P09, checkpoints, seeds and visual acceptance
remain open. The main ledger is now 69/80 done, or 86.25 percent; this is a row
count rather than weighted effort or final acceptance.

### Owned chain-321 wallet tour candidate

The manual workflow adds `windows_wallet_tour`, false by default. Select only
that lane, with `chain321_backend=native`, `chain321_node_source=lab-fix` and
`native_stack_diagnostic=true`. Admission rejects other wallet/lab combinations
before SDK allocation. The existing five-node controller retains its source,
compiler, red/green producer regression, seven upstream tests, genesis and
production checks. A wallet callback runs while those original nodes are alive.

The callback creates a gated SDK child in a private Windows job. The Dart entry
uses the actual harness build and fresh-start commands, with locked dependencies
and source metadata. It refuses existing build/profile destinations. The parent
binds the original native app handle, executable and private harness ping, then
revalidates advancing HTTP/WS chain-321 observations before a single stdin write
of the explicitly committed public lab fixture. No private input is placed in
command arguments or public output, and no uncertain write is retried.

The entry imports through the wallet UI, verifies the selected loopback node and
saved signing chain, checks onboarding logs, sizes the client to 1280 by 780 and
runs the strict twelve-page tour. The parent validates finite page coverage and
each private PNG, requires an ordinary-close acknowledgement and actual app exit
zero, releases the entry's final gate and observes its actual zero exit and
complete output. Known auxiliary teardown retains explicit nonzero receipts.
The five original nodes must then close with their existing normal-exit gates.

Only two explicit finite manifests are uploaded. Profiles, fixture/password
input, PNG pixels, process IDs, paths and raw output remain private. Workspace
sampling has a separate 4 GiB cap and 2 GiB free-space floor only on fresh hosted
regression VMs; it is cooperative sampling, not an OS quota. The local 12 GiB
scratch limit, 10 GiB floor and prior transport refusal are unchanged.

All thirteen new policy cases and fifty existing debug controller cases pass
locally without a native wallet, process, network or filesystem scratch. They
cover opt-in admission, ownership refusal, fixture selection, complete ordered
coverage, original exit/output requirements and failed cleanup. The workflow's
thirteen inputs fit GitHub's documented [25-input dispatch limit](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_dispatchinputs).
Actual hosted wallet execution remains pending. No send, checkpoint, seed or
visual match is established by this candidate.

The first dispatch at `2a576b48e9a4e01c5693cb4477c255de7ccbabc7` is rejected
with HTTP 422 before a run is created: GitHub cannot resolve `runner.environment`
inside job-level environment configuration. The complete original failed
request and a read-only no-run observation are retained. The correction moves
that value to the admission step; the runtime step already uses step context.
This is a workflow-source correction, with no repeated native execution or
artifact transport. The YAML parser result established syntax only, and did
not establish GitHub context validity or wallet qualification.

Run `40297424584`, attempt one, job `121486780811`, at
`409cda9f74b6e253941ee331f01747ddbef34cae`, tree
`f193d9b5c53b8e892553714232ac3db11f71f805`, passes hosted admission,
thirteen policy cases, all six Dart tour regressions and zero-diagnostic
selected analysis. The existing full controller-suite step fails. Node build,
lab startup and native wallet execution are skipped, and the failure is retained.

An existing entry-artifact contract still delimits its job at the later devnet
job. Since the intervening debug job was added, its file-list assertion also
consumes that following job. A read-only local execution reproduces the actual
assertion failure, and the corrected next-job boundary passes the same case.
It still requires exactly the original five explicit entry artifacts. This
reproduced defect does not by itself prove that no other hosted case failed.

The wallet lane now runs every controller test before SDK allocation through
the finite reporter. Failed test IDs and counts are exposed without traceback,
test-body stdout or stderr. The full suite's filesystem/socket mechanics remain
restricted to fresh hosted Windows, with an explicit local refusal before test
discovery. Fourteen policy cases, fifty debug cases and the existing read-only
contract pass locally. The full suite has not been rerun locally. A new hosted
result is required before any native wallet result is claimed; no unchanged
native node, wallet execution or artifact transport has been repeated.

### Wallet startup deadline and bounded preflight candidate

Run `40300161709`, attempt one, job `121495783273`, at
`bb546c3e7fc973c9086e5d823361140629efe166`, tree
`b73aa71e464a9f361c44f540bd70833cf959fafb`, passes all 415 controller
cases with three platform skips, all six Dart tour cases and selected analysis
with zero errors, warnings or infos. The negative opt-in control exits one
normally with exactly 16 refusal bytes. All five original lab nodes reach
advancing production and later exit zero with complete unforced output.

The wallet callback fails with `TOTAL_DEADLINE` during its build/start phase.
It observes zero entry-output bytes and no readiness, application binding,
private-input release, visited page or capture. Six owned-job members remain
at closure. The entry's observed exit zero occurs after forced job closure;
it is not a normal successful entry exit. The exact inner stage and cause
are unknown. The lab's unchanged-input gate is not reached after the wallet
failure. This attempt qualifies neither P08 nor the overall wallet lab, and
does not replace earlier failures or the separate positive node-only runs.

The new candidate emits flushed gate, build and start milestones. Before Go
or node allocation, two separate owned processes test the entry gate and a
lightweight Flutter version command. Each has a thirty-second bound and a
new private SDK profile. Assignment to the private Windows job precedes
`START`; the controller input stays open while waiting for the original exit.
Success requires its exact markers, original exit zero, complete output and
an empty unforced job. Fixed image classes identify any remaining owned
members without publishing paths or process IDs. Neither probe builds or
starts a wallet or receives wallet material.

The CI build now closes only its child stdin and drains both original output
streams to EOF along with the original exit. Ordinary manual harness builds
keep their existing default. Two new in-memory Dart cases test EOF ownership
and rejection of an output error despite exit zero; they await hosted SDK
execution. Seventeen Python policy cases, fifty debug cases and four selected
inventory/workflow cases pass locally without native execution or filesystem
scratch. The full controller suite remains hosted-only. This is a diagnostic
candidate; the old timeout cause is not claimed as resolved.

### Inventory-only hosted candidate

The default-off `windows_inventory_only` input uses the existing baseline
source checks and version projection without dependency restoration, doctor,
analysis, tests, builds or DLL mapping. Its finite manifest always keeps
`baseline_qualified` and `wallet_qualified` false. Git Bash lookup covers the
bounded Git `cmd`, `bin` and `mingw64/bin` layouts, and the native workload
records its installation version. Three in-memory cases cover that lookup,
mode isolation and refusal of an unknown required inventory field. P01 and
P03 remain open until a complete actual hosted inventory and any necessary
provisioning are reconciled. The workflow now has fourteen inputs.

Run `40307669329`, attempt one, at
`e02c2b6a8e66263ea4f26c5c601d3e19dd0fd9c2`, tree
`609ca9e23398004601ba3166e3a4d9a1c34fbb18`, fails before the wallet
SDK step. Job `121520708717` reports 421 controller cases, three platform
skips, one failure and no errors. The finite failed identifier selects the
new synthetic Git Bash discovery case. Its fake file predicate compares
Windows-normalized paths to slash-only text, so it rejects the intended
fixture on Windows despite passing locally. The correction compares Path
objects and converts only the expected return value to the native string.
The discovery implementation and startup probes are unchanged. Inventory
job `121520709448` also stops at its controller-test step before collecting
inventory. Neither positive startup probe, new Dart case, node or wallet
executes in this attempt; the prior deadline cause remains unknown. This
negative attempt is retained and will not be retried at unchanged source.

### Owned startup probes pass; storage refusal needs a finite cause

Run `40308403749`, attempt one, at
`86b536a0f33cd44a8a6d9c1c02839a6293a96bf4`, tree
`eb5a884cc66a4d661662c82da559e1b9919ea497`, has 421 controller cases,
three platform skips and zero failures/errors. All eight Dart cases pass
without skips or errors. The negative opt-in control retains its normal
exit one and exact sixteen-byte refusal. Both positive startup probes pass:
the gate and SDK originals exit zero with complete output, the controller
stdin remains open, neither job is forced and both jobs are empty at close.
Selected analysis has zero errors/warnings and three infos: two import-order
notices and one stream-iteration preference. The candidate corrects all three.

Wallet job `121523173102` reaches the gate and build milestones, retaining
107 complete output bytes, then fails with `STORAGE_REFUSED`. Readiness,
application binding, private-input release, pages and captures are unobserved.
The receipt classifies all thirteen remaining owned members before forced
closure; the original entry's subsequent exit zero is not normal success.
All five original lab nodes reach production and exit zero, complete and
unforced. The unchanged-input gate is not reached after the wallet failure.
Neither the wallet nor overall lab is qualified by these partial positives.

The old storage code uses the same refusal code for logical bytes, free
space, entry count, links, reparse entries and unsupported file types. The
receipt cannot identify which one occurred. The new candidate retains its
four-GiB workspace cap, two-GiB isolated fixture floor and strict identity
checks. It records only fixed role labels, logical-byte totals, entry count,
minimum free bytes and a finite refusal reason. Symlinks and reparse entries
are still refused before traversal; no cleanup or limit increase is added.
Three in-memory cases cover attribution, partial totals on cap refusal and
the distinct link/type/entry-limit refusals. Logical bytes are not measured
physical allocation or reclaimed disk space.

### Inspect the existing inventory before repeating a query

Inventory job `121523172669` in the same run passes its controller step,
collects Git Bash `5.3.15`, confirms absent Pillow and retains its finite
manifest. Source and unchanged-source checks pass. Native workload/MSVC,
Windows SDK, Chrome/Edge, Docker Desktop and Developer Mode remain unknown;
the inventory reports `INVENTORY_INCOMPLETE`. The annotation omits individual
query outcomes, so no exact query failure is claimed yet.

The new default-off inspector reads that existing original manifest inside
Actions. It binds exact run/head/tree/attempt and artifact name, verifies
archive size/digest and the sole manifest member, then projects only three
finite command outcomes and the unknown-field names. It reuses the existing
bounded transport and credential boundaries; no archive is downloaded locally.
No tool query, SDK setup, node, wallet or build repeats in the inspector.
Original failures and forced exits remain negative even if inspection itself
succeeds. Three in-memory cases cover the original timeout projection,
source/exit/refusal integrity and local admission before any API client.
The workflow has sixteen inputs; P01/P03 remain open.

Inspection job `121529697686` in run `40310356121` at
`ce3beb9c29cfb161f50e723f04a274d0508e1313` succeeds and verifies the
original `40308403749` inventory archive
`47b1e7616e49f2c4e2406818c7da2bca610ae2e6765a87787ff48ecb7bfa825a`
and manifest
`fe07a649df59a5bc02ee7c568e5b63517f96f90d1fd0647fdd3a7aa527a894db`.
The original native query reports `COMMAND_TIMEOUT`, 30.031 seconds, zero
output bytes, complete output and forced exit one. Git Bash exits zero
normally; the Pillow metadata query exits three normally with zero bytes.
The original incomplete inventory remains negative. No exact inner native
query site was recorded, and no local archive is transported.

The next inventory candidate passes the exact script through PowerShell's
encoded-command argument, with UTF-16LE bytes verified in memory. It emits
flushed fixed markers for entry, Visual Studio, SDK, browsers, Developer Mode
and completion. Only a complete ordered marker sequence plus a JSON object
and normal original command success may populate native inventory fields.
Finite progress and the original command outcome are included in the notice;
raw output and paths remain private. The thirty-second bound, source checks
and incomplete-inventory requirement are unchanged. Five focused in-memory
cases pass, including refusal of partial, duplicate, unknown or private output.
Actual encoded-query execution and P01/P03 qualification remain pending.

### Actual storage refusal is a tool-profile reparse entry

Wallet job `121529697559` in `40310356121` finishes with failure at exact
source `ce3beb9c29cfb161f50e723f04a274d0508e1313`, tree
`ec3836bf2d7ce4c836345a409afa8f7905abe489`. All 427 controller cases have
zero failures/errors and three platform skips. All eight Dart cases and both
owned startup probes pass, and selected analysis now has zero diagnostics.
The lab reaches production and all five original nodes exit zero, complete
and unforced. The wallet has no observed readiness or released private input.

The fifth storage sample refuses a reparse entry in the fresh SDK tool profile.
At refusal it has counted 24 entries and 29559 logical bytes in that role.
The peak across all five samples is 72499 logical bytes; minimum observed
free space is 233983049728 bytes. The native-build role has zero counted bytes
in the refused partial traversal. These partial counts do not prove that
uncounted output paths are empty. The original thirteen job members and forced
closure remain explicit, and the subsequent entry exit zero is not normal
success. The byte and free-space limits are unchanged.

The candidate reads only that refused entry's link metadata in the tool
profile, checks the metadata before and after, and emits a reparse tag and
fixed segment classes. Unknown names are masked. Target containment is labelled
lexical only; the target is never traversed or admitted, and a changed entry
remains unknown. Two new in-memory cases cover masked observation and changed
or external targets. All 22 selected wallet policy cases pass locally.

### Native inventory timeout narrows to Visual Studio discovery

Inventory run `40311330396`, attempt one, job `121532967722`, at
`468522e32685b12d199c9e9a41c75bf9463c6b8b`, tree
`46efbe73ec44e16f9d00fd6691658d1189f6eef1`, passes its controller step.
The encoded command reaches `entry` and `visual_studio`, then retains
`COMMAND_TIMEOUT`, 30.031 seconds, 68 complete output bytes and forced exit
one. No JSON is observed. Docker daemon `29.7.2` is present on this fresh
runner; native Windows fields remain unknown and the inventory remains failed.

The next candidate adds exact installation-query, MSVC-file and workload-query
markers. Only read-only installed-tool discovery may use the actual Windows
profile of a fresh GitHub-hosted runner. Admission requires this fork's manual
workflow, the inventory-only mode and the fixed native stage. The environment
uses an explicit allowlist with credentials excluded; it is never available
for a wallet or SDK command. The Windows setup API's behaviour in the private
SDK profile is a hypothesis, not a proven timeout cause. The same thirty-second
bound and strict source/complete-query gates remain. Six focused in-memory
cases pass, including scope refusal before launch and credential exclusion.

### Native inventory exits normally; explicit JSON framing remains pending

Run `40313052065`, attempt one, at
`043d0844003f41c57620898c194ddf29b0930739`, tree
`9f380bca7410898b6951bbf11ad9a3b8e6243b6b`, inventory job `121538722922`,
completes the native query in 25.234 seconds with normal original exit zero,
1424 complete bytes and no forced termination. All six top-level phases and
all three Visual Studio details are observed. The decoder does not observe a
JSON object, so native fields remain unknown and the inventory stays failed.
No exact cause for that combined output is claimed from the finite receipt.

The next candidate writes exactly one prefixed JSON line directly through
Console output, requests text output and suppresses progress. It records only
frame/unframed-line counts and accepts native values only with one valid frame,
no unframed output, complete ordered markers and normal original command
success. Unexpected or duplicate records remain rejected. All seven focused
in-memory cases pass, including unframed, private and duplicate data refusal.
The fresh-hosted read-only scope and thirty-second bound remain unchanged.

### Original lab command failure precedes the wallet callback

Wallet job `121538722511` in the same run has 432 controller cases, three
platform skips and no failures/errors. All eight Dart cases and both owned
startup probes pass; selected analysis has zero diagnostics. The node build
passes, then the lab controller reports `COMMAND_FAILED` before asset creation,
preflight, node startup or any wallet callback. No reparse observation or new
wallet process is established by this attempt. The finite manifest is retained
for the existing read-only chain-321 inspector; no exact failed command is
claimed until that original manifest is inspected. Earlier node/runtime
failures remain separate negative attempts. The new dispatch selects inventory
and retained-manifest inspection only, repeating no Go build, node or wallet.

### Actual reconnect reset and qualification-only client ordering

Inspection job `121545606607` in run `40315101485`, at
`cbf2f2f3fdb50ae6ed0c025ea5a725bb4df7321a`, verifies the original
`40313052065` archive
`5101bf280794041da144893e6985776fdfb7fa66ce022584ea5259c6279811df`
and manifest
`f4c52b8494f9408fc7bb649ee5ee697d9a803fde7d90c84c5751ccad18881490`.
`TestSameIdentityReconnectDuringGatedCleanup` fails at line 381 with
`GO_RECONNECT_RESET`. The other six tests pass without skips. The original
exit one is complete and unforced; inspection repeats no Go, node or wallet.
The inventory job in that run remains failed after a 30.032-second timeout
before the first Visual Studio detail or JSON frame; it is not repeated by
the following wallet candidate.

Read-only source verification binds the original test file through the pinned
root, p2p and legacy Git trees. The test client concurrently sends and reads
the protocol handshake; the server may reject the duplicate identity before
that handshake. The candidate reads that early rejection before writing.
It does not replace the required disconnect reason with a reset or alter
production transport code. Its native effect is not claimed before execution.

Only the Windows wallet lane applies the fixture, after the original CLI
build. Original test-file SHA-256 is
`532c7bd18d746bc1457d49b9b16420220d7a0f3a97462fc3101d96310516a8b5`;
adapted file is
`7e92c04318641610ba5e288299846ee7f3a6988b1dfec3e92034ea2b832eb6ac`.
The complete suffix containing all seven test bodies remains byte-identical,
SHA-256 `c4cb203af516459ab6e3224ef13ca23bbd1480a044e4f0ecf3dadb5279ee77b3`.
The effective test input is production tree `a9262cce1819` plus fixed patch
`88360342c36f591dad99f2442c7c1a0cd6fe5ec6ea5b534db1ab9a7e70dc540c`;
it is distinct from an unmodified upstream test-client result.

After a confirmed complete unforced test command, the controller restores
only the exact adapted file and rechecks the original complete production
tree before assets or runtime. Normal test failure is restored and rethrown.
An uncertain launch, forced/incomplete command or changed input stays held
without reverse application. The production CLI tree and ordinary node-only
qualification paths remain unchanged. Explicit fixture receipts retain the
original test exit and restoration facts; inspector admission requires
successful restoration before assets or runtime can be qualified.

All 64 selected memory-only fixture, inspector and wallet-policy cases pass
locally. They include preservation of a normal failure, refusal to restore
over changed input, forced-command holds and strict inspector gates. The
complete controller suite, actual seven Go tests, reparse observation and
full wallet tour await the new hosted source. No native process or filesystem
scratch is used locally, and prior negative attempts are not retried unchanged.

### Direct system APIs for native inventory

The inventory candidate replaces metadata cmdlets with direct .NET file,
directory, version-resource and registry APIs already available to Windows
PowerShell. It retains the exact two `vswhere` queries and their ordered
markers. No PowerShell module import or general JSON serializer is needed
for these installed-tool reads. Module initialization remains a hypothesis
for the earlier pre-query delay; its exact cause is not claimed as proven.
SDK lookup reads both registry views and bounds the direct version-directory
listing. Registry keys are closed explicitly; no user-folder scan is added.

The seven native fields have fixed keys. The frame emitter admits only known
state/scope labels and numeric version strings; a present item with no valid
version becomes unknown. A missing Developer Mode registry value is recorded
as absent, without inferring that the mode is enabled. Access/query exceptions
remain unknown. The Python decoder still requires one complete frame, no
unframed output, complete phase order and a normal complete original exit.
The thirty-second deadline and fresh-hosted read-only scope are unchanged.

All seven existing protocol cases pass locally with the new exact encoded
script. Actual installed versions and P01/P03 remain unqualified until the
independent hosted inventory runs. This change does not repeat the separate
Windows wallet qualification or alter its test client, node or production tree.

### Read-first client passes the actual Windows seven-test gate

Run `40319698922`, attempt one, job `121562807468`, at
`70ad939d313017c8d6694f3c95303eb0609c8e80`, tree
`70409cedd8ba30f5553e71a4049fb25c391e5142`, passes all 438 controller
cases with three platform skips and zero failures/errors, all eight Dart
cases, both owned startup probes and zero-diagnostic selected analysis.
The explicit client fixture passes all seven Go tests with complete unforced
exit zero. All seven bodies stay exact, and restoration of the original file
and complete production tree is verified before assets. This qualifies that
test input; the earlier unmodified-client reset remains a negative attempt.

The full run remains failed. The lab produces and the wallet reaches build,
then a tool-profile mount-point junction is refused. Its metadata is stable,
tag `2684354563`, with a lexical target inside the same profile. Four samples
record 72467 peak logical bytes and 155758481408 minimum free bytes. Thirteen
owned wallet-job members require forced closure; the entry's later exit zero
is not normal success and no private input or capture is released. Pillar2
also times out and is forced to exit one; the other four original nodes exit
zero, complete and unforced. Overall wallet/lab qualification remains failed.

### Bound canonical SDK aliases without traversing a junction

The new sampler captures the original SDK profile's directory identity
before launch and rechecks it around each sample. Only a directory mount-point
junction in that tool profile can qualify as internal metadata. The literal
target must normalize inside the same root, its canonical ancestor chain must
contain only plain same-volume directories, and every identity is rechecked.
The junction metadata is checked again after the chain. No junction traversal
or second walk occurs: its canonical target is already inside the ordinary
tree walk. Metadata bytes count once, with at most sixteen verified aliases.
Wallet/app profiles, other tags, external targets, changed roots, reparse
ancestors and unknown targets remain refused. The byte cap and free floor
are unchanged; this remains cooperative accounting rather than an OS quota.

All 27 selected memory-only wallet-policy cases pass, including original-root
binding, cross-volume/reparse-ancestor refusal, changed directory identities,
literal parent traversal refusal and counting a verified alias without another
walk. Actual native alias accounting and the complete wallet tour await the
new source. The original pillar2 manifest is selected for independent read-only
inspection rather than an unchanged runtime retry.

### Native inventory reaches one unknown workload field

Run `40322634019`, attempt one, job `121571177249`, at
`13f7bd84f5fe183baf66b2d34ac727a8e3a62567`, tree
`a47ddf7beeecd98127d2ad362d83180b5f37bd0f`, completes native inventory
normally in 2.937 seconds with 919 complete bytes, all phases and one valid
JSON frame. MSVC `14.51.36231`, SDK `10.0.26100.0`, Chrome `156.0.8078.48`,
Edge `155.0.4283.62` and enabled Developer Mode are recorded. Pillow and
Docker Desktop are absent; Docker daemon `29.7.2` is present. Only the native
desktop-workload version is unknown, so the inventory remains failed.

The workload query supplied IDs after `-requiresAny` without `-requires`.
The candidate adds the required list option, matching the documented
[vswhere component-query syntax](https://github.com/microsoft/vswhere/wiki/Examples).
It does not turn an unknown field into a positive result; actual workload
observation on the new source is still required. No deadline or source gate
is relaxed, and the original unknown-field outcome remains preserved.

### Bound retained wallet-stop notices without losing node milestones

Run `40325850769` at `08fdf0ab62e8` fails its independent retained-manifest
inspection at `parse_native`; that broad phase does not identify its precise
substep. A complete synthetic report combining restored client evidence,
five original exits, advancing-chain observations and worker details exceeds
the existing notice limit before compaction. The candidate shares validated
node milestone labels in `node_diagnostics_catalog`; each node's ordered
`diagnostic_indices` reconstructs its exact original labels. Original exits,
forced/output facts, role bindings, client restoration and worker sites remain
present. Validation still examines every original category before sharing it.

All forty memory-only inspector cases pass. The complete five-node synthetic
wallet-stop notice is 3776 bytes including archive and manifest digests,
within the unchanged 3800-byte bound. Separate unpack, projection and notice
phases identify any next refusal. The original report is not available
locally, so the exact cause and corrected actual inspection remain pending;
no node, build or wallet is repeated by this inspector.

### Reconcile the two completed Windows wire-admission corrections

Retained native run `40226727980` at `64b269f8cfdf`, attempt one, job
`121269562394`, and its independent archive inspection verify advancing
matching HTTP/WS chain-321 observations and five complete unforced zero
exits. Its `tools/devnet/lab/socket_transport.py` bytes are identical to the
current `08fdf0ab62e8` file, SHA-256
`48b869148eb38f6fb29b30ba9e1a184adad051bb5a808a1ae18ee35e3757ea3d`.
This completes the actual wire-admission follow-up in X193/X196. Their
injected status/precedence cases remain separately scoped; no individual
error branch is declared observed from the successful chain result, and
earlier negative attempts retain their original outcomes.

### SDK accounting reaches the actual owned wallet onboarding

At `08fdf0ab62e8`, run `40325850769`, attempt one, Windows wallet job
`121584678158` passes all 443 controller cases with three platform skips and
no failures/errors, eight Dart cases, both owned startup probes and selected
analysis with zero diagnostics and a complete normal original exit zero.
All seven Go tests pass with their exact bodies; the original test file and
production node tree are restored before assets.

The wallet builds and starts. Original app ownership and owned chain-321
revalidation pass before the single private-input release. All 57 storage
samples complete; one stable, same-profile canonical SDK junction is counted
without traversal. Peak logical bytes are 266243491 and minimum free bytes
155037913088. No storage refusal occurs and both resource limits are unchanged.

Onboarding then reports `wallet-recipe-command-refused`; no page is visited
or captured. The app's cleanup exit is zero, the original entry exits one
with 489 complete output bytes, and a remaining VCTIP helper requires forced
closure. Aggregate and required-actor forced flags remain true. Every original
node exits zero, complete and unforced. Final source/input gates are not
reached, and the overall wallet/lab result remains failed.

### Identify a refused recipe without disclosing its private exchange

The server previously collapsed every recipe error to one refusal, and the
client collapsed that reply again. The candidate preserves only enumerated
server codes without detail payloads. A failed client command keeps the same
terminal refusal and retires its driver, with optional immutable action,
control and reason labels. Dynamic node-selection keys collapse to one fixed
label. Values, endpoints, exception text and reply details are omitted.
The CI entry independently rechecks all labels; its parent rejects extra
fields, unknown labels and diagnostics outside the original onboarding failure.
These labels convey no permission to repeat or continue a failed action.

All seventy selected Python cases pass in memory: 41 inspector and 29 wallet
policy cases. Four new Dart regressions cover private-data omission, dynamic
key masking, terminal retirement and the server's original owner refusal.
They are selected with the eight existing cases for hosted execution and
have not run locally. The selected analyzer also includes their exact source.

### Admit the producer's explicit wallet phase in retained inspection

At `23d0aa546328`, read-only run `40328798543` fails at `projection_native`.
The finer phase distinguishes this from archive unpacking and notice length.
The producer enters `wallet_tour` before calling the wallet, but the reader's
phase list omitted it. The candidate accepts that phase only for an explicit
native corrected-node wallet run with verified production and restored client
evidence. Other backends, absent wallet selection, missing client proof and
non-producing reports stay refused. The complete synthetic stop report now
uses this actual producer phase; corrected retained inspection remains pending.
No inspection starts a runtime or qualifies the original failed attempt.

### Include the existing recipe contract in hosted qualification

The next candidate selects all 34 existing `wallet_recipe_test.dart` cases
with the four new failure-label cases and eight tour/build-output cases,
requiring 46 successful cases, no skips and a successful complete terminal
event. This checks the existing owner, consent, signing and retirement
contracts after changing refusal propagation. Their source is also included
in selected analysis. No test body, expected outcome, deadline or runtime
admission is relaxed; the complete suite runs before the native lab/wallet.
This selection change has no new local Dart execution.

### Complete recipe regression gate reaches an unsettled onboarding wait

At `cee4dcb5e2bed5902859f49a181af1d873497ac8`, tree
`461b18d7f360b75c5c1e2414388ddb777618a67a`,
[run 40332088622](https://github.com/edgepillar/syrius/actions/runs/40332088622),
attempt one, Windows job `121608239447` passes all 448 controller cases with
three platform skips and zero failures/errors. All 46 Dart cases pass, with
four loading events, no skipped/failed/error events and a successful terminal
record. Both owned startup probes retain normal complete zero exits.

Selected analysis exits zero with no errors/warnings and three
`CAST_NULLABLE_TO_NON_NULLABLE` infos in `wallet_recipe_failure.dart`, lines
73-75. The candidate replaces those casts with explicit string checks and
promoted local values. Unknown or non-string labels remain refused; no rule
is suppressed. Actual zero-info qualification on the new source is pending.

The seven exact Go test bodies pass and production source is restored. The
wallet builds/starts and its ownership, lab revalidation and single input
release pass. All 64 storage samples complete with one verified SDK alias,
peak 266243535 logical bytes and minimum free 154947973120 bytes. Onboarding
then reports `wallet-recipe-stage-unsettled`; no page is visited or captured.
The app's cleanup exit is zero, the entry exits one with 489 complete bytes,
and a VCTIP helper is forced. All five original nodes exit zero normally.
Overall wallet/lab acceptance and final source/input gates remain unqualified.

The candidate attaches the expected fixed control and its last observed
absent/disabled state to this terminal wait refusal. It keeps the same total
budget, turn bounds and retired driver. No new command or retry follows the
failure, and no raw observation, value or endpoint is published. Two new Dart
cases cover both unavailable-control states without offering a private action;
all 48 selected Dart cases await the next hosted run. Seventy selected Python
cases pass locally and their fixed-label sets match Dart.

Fresh app startup has a 1200 by 600 fallback, while the CI entry previously
first requested the specified 1280 by 780 client area after onboarding. The
candidate moves that existing verified show/resize request before keyed
onboarding actions, after the parent has bound the original app and lab and
released its single input envelope. The prior native geometry was not recorded,
so this ordering correction is not declared the cause of the original wait.
Actual onboarding at the requested client area remains pending.

### Retained original pillar2 wait is now source-bound

The same run's independent read-only job `121608240087` succeeds at the
current inspector source. It verifies original run `40319698922`, attempt
one, at `70ad939d313017c8d6694f3c95303eb0609c8e80`, archive SHA-256
`9d41409f2d35b5827850f190b078c693f90f154cf20bc3eff7fa6f5ed28915cd`
and manifest SHA-256
`a340bf3d57899fe09499d8edc60587e950ca18a82a518646b7b1d97c0a1e7335`.
The original client restoration and seven-test gate pass; pillar2 still has
its original forced exit one and `WAIT_TIMEOUT`. Other originals exit normally.

One captured `SYNCER` site is `protocol/downloader/downloader.go`, line 414.
Its path digest and cached commit-bound blob
`dd30f482860e3a52a44860309884940e5a719f03` identify
`Downloader.Terminate()` waiting on its work group. This locates the outer
wait and does not identify the inner processing goroutine or establish a
root cause. The full source file's SHA-256 is
`4e318cf2872f621d492fdeeb1419bb194c729febec0334e3d91e9d356c0eab9d`.
No native runtime, source download or artifact transport is repeated locally;
the existing cached Git response and the complete hosted projection are reused.
Original failures remain negative and X212 stays open.

### Native wait identifies an absent first Welcome control

At `3fccb33dd66c8d407763787e1b7347f618908ac1`, tree
`7f6e691b801ba2bff8d924e0ad32afede13f6466`,
[run 40338226701](https://github.com/edgepillar/syrius/actions/runs/40338226701),
attempt one, Windows job `121625469509` passes 448 controller cases with three
platform skips and no failures/errors. All 48 Dart cases pass without skips,
failed/error events, with four loading events and a successful terminal record.
Selected analysis has zero errors/warnings and one `LINES_LONGER_THAN_80_CHARS`
info in `wallet_recipe.dart`, line 453. The candidate wraps that line; no
analyzer rule is suppressed.

The existing verified show/resize request completes before onboarding. Its
first `welcome_import` wait still reports `wallet-recipe-control-absent`,
followed by the original terminal `wallet-recipe-stage-unsettled`. Geometry
ordering alone did not resolve the missing control. The callback visits and
captures no page. Original app ownership, lab revalidation and the single
input-envelope release pass. The original entry exits one with 841 complete
bytes; app cleanup exits zero and a remaining VCTIP helper is forced. All five
nodes exit zero, complete and unforced. Overall wallet/lab acceptance remains
failed and final source/input checks are not reached.

All seven Go bodies stay exact and pass with restored production source. The
58 storage samples complete with one verified non-traversed SDK alias, peak
266243615 logical bytes and minimum free 154946871296 bytes. Resource bounds
and failure retention remain unchanged.

### Observe the actual entry view before another native attempt

The candidate adds a regression using the actual `WelcomeSurface`, original
keys and harness observation at 1280 by 780. Only artwork is replaced by the
existing deterministic view fixture; no wallet owner, process or network is
constructed. This checks the source component rather than a lookalike button.

The existing onstage traversal also collects fixed entry widget types. A
terminal wait may include one optional enumerated entry label. Known startup
exceptions contribute only their fixed family; displayed text, raw messages,
stacks, paths and service identities remain private. This observation never
grants an action or changes startup, route ownership or refusal policy.
Both Dart and the parent reject unknown labels and extra fields. Legacy
three-field diagnostics remain supported. The original wait bounds, retired
driver and absence of follow-up commands are preserved.

Seventy selected Python cases pass locally and all four fixed-label sets match
Dart. Two added Dart cases bring the hosted selection to 50, including actual
Welcome observation and entry-label privacy. Their execution and native entry
classification remain pending. Installed Flutter framework, Overlay and
Offstage traversal source was inspected read-only; those methods visit their
onstage children in release as well as debug. The harness remains a Release
build. No local SDK execution or source download is added.

### Retained preparation timeout, 2026-10-26T15:18Z

At source `d95f51bd24f3af3976fcd1423460468d9a2ee2e0`, tree
`d764fa90bdeb66136157b71862d83c296cc67b8c`, run `40345162301` attempt one,
job `121650033274`, all 50 selected Dart cases pass with no skips or failures.
This includes observation of the actual Welcome component. Its original
command exits zero with 22165 complete bytes, no forced termination and SHA-256
`b26d685b2eab231748b27de58d9f0624b011ba1fbd4c7ce61adf010a2ac26629`.
All 448 controller cases complete with three platform skips and zero failures
or errors. Selected analysis exits zero with complete empty output: zero
errors, warnings and infos.

The compiled node tree is unchanged. All seven Go test bodies pass, the
qualification client is restored and the production source is restored.
Preparation then reports `COMMAND_TIMEOUT`; assets, preflight and node start
are false. No node or wallet execution is established by this run. The fixed
native entry diagnostic is therefore not reached. This is a failed run,
preserved independently of its passing test gates.

The retained-manifest inspector now selects only the final three command
ordinals, original exits, completeness/forced flags, byte counts and stream
digests when preparation times out before node start. Unknown receipts remain
explicitly unknown. It does not copy argv, output text, host paths or profiles,
and does not start a runtime or admit seed material. Seventy-three selected
memory-only Python cases pass, including three added privacy and outcome
cases. Hosted inspection of this exact failed run remains pending. Existing
deadlines, application source and local storage limits are unchanged.

### Asset-helper command identified, 2026-10-26T15:34Z

At inspector source `ef03c1d33cba31a5eb6fa4c727a37cf0dace4410`, tree
`ea9dba9a4c0dd8ad790d44577bef82b75ca3d690`, run `40348664138` attempt one,
job `121662408010`, the boundary-test step and retained inspection succeed.
The original failed source/run remain `d95f51bd24f3af3976fcd1423460468d9a2ee2e0`
and `40345162301`. The original archive SHA-256 is
`154e3e6df2c14dee08dd629312123daa926f973eb4e03761e3a6d5c34299416d`;
its manifest SHA-256 is
`e699536af2af98d43c7d6d9f1704b827513e4e05a944ad2fe010ceb6151a2907`.

There are 49 original commands. Commands 47 and 48 exit zero normally with
complete empty streams; command 49 is forced, exits one and has complete
empty streams. The pinned source sequence identifies command 49 as
`node tools/devnet/lab/make-assets.js`. This locates the failed process;
its internal stall site and root cause remain unknown. No node or wallet is
started by this read-only inspection, and the failed attempt is preserved.

The candidate adds an explicit `--progress` option to that same helper.
Fourteen ordered fixed labels cover JavaScript entry, genesis and each role's
copy/config completion. The ordinary two-argument path retains its output
behavior. No generated asset transform changes. The parent observes the
original process and its bounded stderr even on failure, retaining the same
20-second timeout and actual exit/forced/completeness facts. Unknown, duplicate
or reordered phase labels are refused; raw text and paths never enter the
public projection. Retained inspection validates the full phase record and
exports one fixed label so all five original exits still fit the notice.

Eighty-one selected memory-only Python cases pass. A separate hosted Node VM
control runs the real helper against an in-memory filesystem before SDK
allocation. Its four cases compare legacy/progress bytes, exact genesis and
config changes, unchanged nested binary inputs, invalid arguments, existing
genesis refusal and interruption at the second role. Those JavaScript cases
and the changed-source native run remain unexecuted at this source-writing
checkpoint. No local SDK, wallet, node, binary download or disk scratch is
added. Full wallet, send, seed and visual acceptance remain pending.

### Ordinary startup wait identified, 2026-10-26T16:07Z

At source `abc671d0627014531309b6e996c636b5e15165d3`, tree
`d354347d33903da7c9dbb27757c8365ccfdfd755`, run `40351356568` attempt one,
job `121671964177`, all four Node VM controls pass, including unchanged asset
bytes. All 459 Python controller cases complete with three platform skips
and zero failures/errors. All 50 Dart cases pass without failures or skips.
Selected analysis exits zero with complete empty output: no errors, warnings
or infos. The qualification client passes all seven exact Go test bodies and
restores production source.

All fourteen asset-helper phases complete under the unchanged timeout. Lab
source, build, assets, preflight, start and production checks pass; all five
original nodes exit zero normally with complete output. The final unchanged
input gate is not reached. Ordinary application ownership, lab revalidation
and one input-envelope release pass. The first `welcome_import` wait fails
with `startup-before-initialization`: the real startup has not invoked its
initializer. No page is visited or captured. Application cleanup exits zero;
entry exits one with 881 complete bytes and SHA-256
`799b958cd222bf37ff3e5d19c3267482094053c41b92cfae673169fc2e67d501`.
A VCTIP helper remains at job close; forced/required-actor cleanup remain true.
Storage completes 57 samples with one verified untraversed SDK alias, peak
266276251 logical bytes and minimum free 154947239936 bytes. Overall wallet/lab
acceptance remains failed. The earlier preparation timeout is preserved.

The candidate includes the existing startup hint in the recipe only while
the original registered startup is current, unheld, open and not initializing.
The hint and the original film's GlobalKey/controller must share the same
primary keyboard receiver. Foreign hints/overlays cannot substitute that
owner. Admission rechecks original receipt, element, geometry and wallet
context, then dispatches only the existing Space key pair in one turn. It
never calls initialization, routes, film completion or a controller skip
directly. Normal initialization already in progress receives no skip.
The same original turn/time limits and terminal retirement remain in place.

Eighty-two selected Python cases pass locally and all four cross-language
label sets agree. Four actor cases and one actual StartupStage/keyboard-view
case are added to the hosted Dart selection, now 55. The view fixture owns no
wallet, process, SDK, profile or network and reads only the committed tiny
movie. Its foreign-overlay and real keyboard checks do not substitute for
the pending native authenticated recipe. No local Dart/Flutter execution,
artifact download or disk scratch is added. This exercises the normal user
skip; unskipped animation, motion/shader/frame-time checks and all 94 visual
matches remain pending. Shipped application source is unchanged.

### Dart gate failure preserved, 2026-10-26T16:26Z

At source `9222e7e2b69a0d04fbe30db79062e61d778e90a1`, tree
`598ebda95ab7ec33ef644a9eefa273a711289f74`, run `40357181470` attempt one,
job `121692687315`, four Node byte controls and 460 Python controller cases
pass, with three platform skips and zero Python failures/errors. Selected
analysis exits zero with complete empty output: no errors, warnings or infos.
Both original startup probes complete normally with zero exits and empty
owned jobs; the negative opt-in control remains an expected original exit one.

The Dart gate records 54 passing cases, one failed case, one error event and
five hidden loading events, with an unsuccessful terminal event. Its original
command exits one normally in 32.469 seconds, without forced termination or
overflow, with 26462 complete bytes and SHA-256
`a9c26e9584a81d45937fd6cf15d93cdc5c16d3d57f612c133f318266cceeb8af`.
Native lab/wallet allocation is skipped. That report does not expose the
failed assertion's location; it cannot establish its cause. The failure is
preserved independently of passing earlier 50-case sources.

The candidate's movie view test now yields to the real decoder before each
fake-clock pump, matching the existing startup fixture method. Its 120-frame
bound remains; production code, timeouts and turn limits are unchanged.
This change awaits hosted verification and is not a diagnosis of the earlier
unavailable assertion.

Failed Dart commands also gain a bounded projection of at most three error
events: a whitelisted test basename, a positive source line if present, and
fixed assertion/unhandled and expected-value labels. Total error count is
retained independently. Raw test names, error text, stack text, paths and
values are not exported. Malformed or oversized input is refused. Four added
memory-only privacy cases bring the selected Python total to 86; all pass.
The largest three-item failure notice measured against the retained command
facts is 2144 bytes, within the unchanged 3800-byte limit. No local SDK or
native execution, artifact download or disk scratch is added. Full acceptance
and all 94 visual matches remain pending.

### Framework failure context, 2026-10-26T16:53Z

At source `dd7599132c00c8fe1aa67df52a177905c3f729c0`, tree
`d68a3ea2e8b54d34bc63f737d33def5b96e03b50`, run `40360124951` attempt one,
job `121702999604`, four Node byte controls and 464 Python cases complete
with three platform skips and zero Python failures/errors. Selected analysis
has zero errors, warnings and infos. Dart again records 54 passes, one failure,
one error event and five hidden loading events among 60 terminal events.
The original command exits one normally in 26.016 seconds with 26462 complete
bytes, no overflow/forced termination and SHA-256
`6ac824e1c059484b8b9e714d10c7cf4cf371c32638c253edce946a4ced8e670e`.
Its filtered event is unhandled with unknown location and expectation. Both
startup probes remain normal complete zero exits; native allocation is skipped.
The earlier failures remain negative, and the failed case/cause is not assumed.

Read-only inspection of the installed Flutter test exception reporter confirms
that it writes framework error details to the console before registering a
generic exception with an empty stack. The candidate therefore associates a
bounded preceding print context only by the same integer test identity. A
different test's context cannot supply a location or category. Known locations
may come from the original stack, error text or that preceding context; their
source is identified explicitly. At most three records expose only whitelisted
basenames/positive lines and fixed kind, category and expectation labels.
Raw messages, descriptions, stacks, host paths and values are not published.

Print contexts are limited to 16384 characters per test and 256 identities,
within the existing four-MiB stream cap. Malformed input remains refused.
Two new association/privacy cases bring the selected memory-only Python total
to 88; all pass. A three-item notice is 2291 bytes, within the unchanged
3800-byte limit. All 55 Dart cases, their existing control flow and production
bounds are retained. Hosted diagnosis remains pending; no assertion or native
result is relabelled by the improved reader. No local SDK/native execution,
artifact download or disk scratch is added. Full acceptance remains open.

### Initial overlay focus, 2026-10-26T17:08Z

At source `1cefefd9289c144f16bb870778a69f4caa5a4e31`, tree
`4ea4dcae137c31015e4a32ff946bc9a000b7e30a`, run `40363854054` attempt one,
job `121716129644`, four Node byte controls and 466 Python cases complete
with three platform skips and zero Python failures/errors. Selected analysis
has zero errors/warnings/infos. Dart still records 54 passes and one failure.
The complete filtered framework print now identifies an expected-true
assertion at `wallet_recipe_startup_test.dart:101`: the original startup hint
is not offered by the recipe. This precedes keyboard input and decoder waiting.
Native allocation is skipped; the failed attempt remains negative.

The installed Flutter focus implementation applies autofocus only when the
enclosing scope has no focused child. The startup overlay is outside the
already focused route's scope. The candidate therefore requests its own first
keyboard focus after mounting, only while the same original session is still
mounted, open and unfinished. A closed, replaced or already completed owner
cannot request that focus. It is a one-time initial request, not a focus loop
on rebuild or a harness override. The existing primary-receiver admission
guard is retained. Hosted verification must establish the resulting behavior.

The harness also preserves `HardwareKeyboard.handleKeyEvent`'s handled result.
The legacy Focus bridge runs only for an unhandled event, preventing a second
dispatch after a hardware handler has already consumed it. Two added Dart
regressions check the hardware and fallback paths, complete key pairs and
released pressed-key state. All prior cases remain, for a selection of 57.
Eighty-eight memory-only Python cases pass; no Dart/Flutter/native code runs
locally. Existing time, turn, storage and privacy bounds remain unchanged.

This is the first shipped application change after the retained
`1d663dc58b9ce6f2abdbe66898e85e2ef850a8c0` baseline. Its results and four
captures remain historical source-scoped evidence. A new full Windows
baseline is required after the focused gate passes; no prior application
success is rebound to this candidate. Full native entry, send, seed, motion
and all 94 visual matches remain pending.


### Startup recipe after an unsettled first observation

At source `f024e78bf777d9b16d9e4a81c295ef092c9bf79d`, run
`40367360833` attempt one, job `121728581279`, passes all 57 selected
Dart cases, four Node byte controls, 466 Python cases with three platform
skips and selected analysis with zero errors, warnings and infos. All fourteen
asset phases complete; all seven original Go bodies pass with production
source restored. Five original lab nodes stop normally with complete zero
exits. The actual wallet still fails during onboarding: `welcome_import` is
absent and the last phase is `startup-before-initialization`. No page is
visited or captured. Entry exits one with 881 complete bytes, SHA-256
`fbbaed04b3f8a960079d464bc42bf38893000b2a850f6eeedd2e7c1316b5dd29`.
Application cleanup exits zero; a remaining VCTIP helper retains forced and
required-actor cleanup. Overall wallet acceptance stays failed.

The first recipe observation can arrive before the original startup receipt
settles. Previously the skip decision was made only from that first phase;
a later startup-before-initialization phase was then ignored while waiting
for Welcome. The candidate always enters the existing bounded startup wait.
It sends the fixed Space action only with the authenticated enabled hint
and the startup-before-initialization phase. Initialization already started
or a natural Welcome handoff needs no key. Four actor regressions cover
unsettled observations with absent or present controls, natural handoff,
and permanent uncertainty that retires without input or follow-up. All
previous cases and production limits remain; the next exact gate is 61.
This closes a source-level race; the original run does not expose its first
phase, so the race is not declared the sole observed runtime cause.

Fresh application qualification remains source-bound to `f024e78bf777` in
run `40368833678`: the full Windows baseline is observed in progress and
the ordinary-entry job `121733765522` is green. Detailed receipts, retained
artifacts and new captures remain unqualified. The driver-only candidate
does not change application code again or rebind older baseline results.


### Retained full Windows qualification without another runtime

Application source `f024e78bf777d9b16d9e4a81c295ef092c9bf79d` finishes
run `40368833678` attempt one with baseline job `121733764905` and entry
job `121733765522` green. This metadata is distinct from independent
inspection of their detailed original receipts and new captures. The
`efdb2deac022dd018d40968d7671e2345571d12d` wallet run `40372647485`
passes its mandatory 61-case Dart gate step and enters the original
isolated lab; its native result remains pending at this observation.

The new `inspect_windows_run` and `inspect_windows_head` inputs select
only a default-off Ubuntu read-only lane. It requires a completed original
run, exact source and attempt, two original job identities and unchanged
baseline/entry producer files. The original baseline job log is capped at
4 MiB and inspected in memory for exactly one timestamped producer frame.
Only fixed original checks, analysis/test counts, command exits, timings,
correspondence digests and finite errors reach its notice. The original
entry artifact is fetched once with its API size and SHA-256, checked for
an exact manifest/capture member set and verified against its recorded
PNG hashes, dimensions, CRCs and pixel payloads. Explicit caps apply to
archive and member bytes. No files are extracted or written by the reader.

The two scopes retain separate notices. A successful inspection can
preserve a failed original result; it never heals a nonzero or forced
exit, starts an application or node, or establishes a visual match.
Thirteen selected memory-only controls pass, including negative original
outcomes, source/process substitutions, missing stages, duplicate frames,
invalid archive members/pixels and local admission before networking.
The existing inventory reader is unchanged. Local SDK/native executions,
artifact downloads and filesystem scratch remain zero.


The completed `efdb2deac022` run `40372647485`, job `121747181548`,
reports all 61 selected Dart cases passing, 466 Python cases with three
platform skips, four Node byte controls and selected analysis with zero
errors, warnings and infos. Actual onboarding still waits for
`welcome_import` at `startup-before-initialization`, with zero visited or
captured pages. The retained diagnostic does not distinguish an attempted
skip from a natural handoff decision; neither source-level race correction
is declared the sole runtime cause. The retained-reader refusal path now
emits only its fixed inspection phase as an Actions notice, allowing a
bounded API observation without fetching raw diagnostics locally.


### Fresh application baseline and ordinary entry independently inspected

Read-only inspector source `443d0e9c6577379da08ae8b44b6417a9b25e2ce1`,
run `40376130619` attempt one, job `121759565325`, succeeds. It inspects
original application source `f024e78bf777d9b16d9e4a81c295ef092c9bf79d`,
run `40368833678` attempt one, baseline job `121733764905` and entry
job `121733765522`. All three selected producer files match the original
source. The inspector starts no application/node and extracts no files.

All twelve original baseline checks pass. The non-chain unit/widget suite
has 4377 passing events, two skips, 511 hidden events and 4890 terminal
events, with no failures/errors. Root analysis has zero errors/warnings
and 1304 infos; vendored analysis has none. Analysis takes 48.343/20.000s,
tests 924.187s and Debug/Release builds 139.328/189.406s. All five selected
commands have actual exit zero, observed exit, complete output and no
forced kill or overflow. Generation/localization/source correspondence
and all three matching DLL map/export probes pass. No node ABI is invoked.
The 39402-byte original job log has SHA-256
`a9fc1ad72a013256698a74c9b05f0d1229da15779dc29de3738a91915e55d15a`.
Root infos increase from the earlier 1295 to 1304. This retained summary
does not attribute the nine additional findings to source locations; that
analysis follow-up remains open. No full-wallet or production result
follows from this baseline.

All eighteen original entry checks and four caption checks pass. The
original exit is zero, observed, complete and unforced, with 2255 output
bytes and no overflow. The exact entry archive has SHA-256
`9758e706f5d9050f640609030070b1d018a09787b2c7d40b85250a0fbf066496`;
its manifest has SHA-256
`33ca0ca651da5055d9bd6a68cf027f1f0bf4218d2fb9eb849079ece8bcffec16`.
All four genuine PNGs are 1280 by 780; the reader verifies their hashes,
CRCs, dimensions and pixel payloads without a local artifact download.

| Capture | Bytes | SHA-256 |
| --- | ---: | --- |
| welcome-dark.png | 165908 | `5af1dbe5a6530b11b075f59f55b6596d6fb3e7aaf4658b64b720da51500f2a85` |
| welcome-light.png | 192060 | `c4d98e6ae820e016fccc74171f5a16234996e973291298f8b0cc29cd9a882ca3` |
| import-dark.png | 89944 | `f2453f147af0546244f84b0a4b7424ed0302294083bd87a74fa2098f240306cc` |
| import-light.png | 110105 | `ee160da5f1b65e69b8aec5528478c746ccb06d417367b0ebdfab95a0e00851c8` |

These four captures are current for that application source. They are
unreviewed against the mockups; the earlier comparison report stays pinned
to its original source. Ninety other actual captures and all 94 visual
matches remain open. The later recipe/inspector changes do not modify
application code or rebind this baseline to a different source.


### Preserve the pinned Flutter hardware and Focus delivery contract

Read-only verification of the already installed Flutter 3.47.7 checkout
pins revision `abaf9c523780a608bd46686fd5e53740a07077f8`. Both keyboard
and focus source files exactly match their Git objects. No SDK is run
or downloaded. In that revision, `KeyEventManager.handleRawKeyMessage`
delivers to the hardware handlers and then the key-message handler even
when an earlier result is handled. `FocusManager.registerGlobalHandlers`
registers Focus through that bridge. See the original [keyboard source](https://github.com/flutter/flutter/blob/abaf9c523780a608bd46686fd5e53740a07077f8/packages/flutter/lib/src/services/hardware_keyboard.dart)
and [Focus registration](https://github.com/flutter/flutter/blob/abaf9c523780a608bd46686fd5e53740a07077f8/packages/flutter/lib/src/widgets/focus_manager.dart).

The earlier harness change incorrectly returned after a handled hardware
event. The candidate now delivers once to each relevant destination and
combines their actual results after both calls. The original two cases
remain, with the hardware-consumed case corrected to the pinned framework
contract. Two new cases check an event ignored by both destinations and
an actual focused widget receiving exactly one down/up pair despite a
hardware consumer. Pressed-key state is released in every case. This
corrects a source-proven delivery bug; its role in the observed native
startup failure still needs original runtime evidence.

A refusal can additionally retain one `startup` label: `observing`,
`key-sent`, `key-confirmed`, `natural-welcome` or `natural-initialization`.
The driver changes this label only at its original decision/command
boundary. Dart and Python both revalidate the fixed set; key text, input,
endpoints and arbitrary diagnostic fields remain refused. The label
changes no input decision, context/owner check, timeout or retirement.
Thirty-one selected memory-only Python cases pass. The next mandatory
Dart gate is exactly 63, including the two new keyboard cases; no native
allocation precedes it. Application code remains unchanged from the
independently verified `f024e78bf777` focus source.


### Bind rail navigation keys to their actual input owner

At `4a21e088779fda13b30d47de9ad16a266b3b9dca`, original run
`40379047583` attempt one, job `121769975293`, passes all 63 selected
Dart cases, 477 Python cases with three platform skips, four Node byte
controls and selected analysis with zero errors/warnings/infos. Actual
execution advances beyond the earlier Welcome wait and now refuses at
`nav_settings`, with entry `unknown` and original startup decision
`natural-welcome`. No tour page is visited or captured. All fourteen asset
phases complete; seven exact original Go bodies pass with production
source restored and five original lab nodes stop normally with complete
zero exits. App cleanup exits zero and entry exits one with 885 complete
bytes, SHA-256
`1623d6f17eb4cb81f577cc927413d73844c04ca7dc8034fabbe054f6c0d2729d`.
A remaining VCTIP helper retains forced/required-actor cleanup. Overall
wallet acceptance remains failed; natural progress does not establish
the sole cause of the earlier startup refusal.

The actual rail assigned `nav_<tab>` to a decorative child inside its
InkWell. The snapshot classifies that button before visiting descendants,
so its recipe key was missing even though tab metadata reached its parent.
The candidate places the existing key on the original InkWell. The
snapshot retains tab metadata on directly keyed buttons as well as its
existing descendant-key path. Geometry, decoration, callbacks, locking
and owner/context admission are unchanged. The existing focus-border test
still reads the same decoration and retains its exact paint assertion.

Three new real ShellRail cases cover collapsed and expanded Settings
navigation through the original harness pointer path, unique enabled
Dashboard/Settings controls, retained tab metadata, one original callback
and locked refusal without a callback. They create no wallet, profile or
network client. All previous selected cases remain, making the next
mandatory gate 66. The finite failure reader admits this test basename
without raw paths or diagnostics. Because this changes application code,
a fresh full Windows baseline and ordinary-entry qualification must
follow the focused gate; f024 evidence is not rebound. No local SDK/native
execution, artifact download or filesystem scratch is added.
