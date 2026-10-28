# Isolated lab seed recipes

These F06 recipes, policy cases and presentation routes have finite offline
fixtures. Current executed scope is recorded in
[`docs/environment.md`](../../docs/environment.md). The original native P09
send and normal required-actor closure are qualified at their recorded source.
Native seed execution, verified checkpoint restoration and ordinary reopened
ownership remain separate prerequisites. No fixture here establishes a live
deployment or a visual match.

The recipes use real wallet fields and pointer input. They do not import a
wallet, choose a password, install a client, send JSON-RPC publications, start
Docker, activate a spork, reset a profile or erase a chain. Keep the mnemonic
and password outside scripts, arguments saved as evidence, and repository
files. Use the existing owner-controlled P09 preparation with a separate,
explicitly named harness profile. Do not use `default` or a real wallet.

Before publishing, retain a coordinator-approved reversible checkpoint of the
owned lab chain and its isolated profile. `--checkpoint-ready` acknowledges
that prerequisite; it does not create or verify a checkpoint. Restoration is
an owner operation on those exact retained inputs, after owned processes are
stopped. There is no automatic undo: stakes and deposits may remain locked,
and token/project registration cannot be undone by another wallet send.

The hosted closed-data adapter in `tool/ci/closed_lab_checkpoint.py` creates
one deduplicated checkpoint and an independent bytewise restore only after
the current original wallet and five nodes close normally. It preserves all
originals and holds failed or partial output. Current source/memory tests do
not establish actual native checkpoint use, copied path rebinding, ordinary
reopen or seed admission. `--checkpoint-ready` remains an acknowledgement;
this adapter does not bypass that boundary or authorize a retry.

Canonical restore and path-binding components additionally preserve every
original config/keyfile and all non-path values. A standalone plain-Dart Hive
component binds copied key zero only, refusing backend adoption, repair,
foreign paths, extra entries and lost closure. Coordinator integration and
ordinary restored app/node opening remain unqualified. The current source
adds a one-attempt `lab-quiesce` command after the original confirmed UI send
and tour. It closes admission on the identical file, SDK and receive worker,
then awaits their original operations. SDK/read/release errors, an unaccounted
publication or an unknown inbound hold refuse the checkpoint. Accepted receive
holds remain intact. The exact positive send, result object and confirmation
journal must still agree. A settled Future or normal exit is insufficient.

The schema-two tour controller binds the finite quiescence reply to its live
original entry before closing it. Only that same normally exited entry can
supply the in-memory checkpoint handoff. Saved reports remain observations.
Current native quiescence, checkpoint use and restored ownership require fresh
qualification; source and synthetic cases do not admit any seed action.

The mounted runtime/storage admission and the profile's sole process ownership
must be qualified separately. The source writes at most three small JSON
records per recipe into that existing isolated profile. It creates no cache,
download, image, archive, copied SDK or second evidence payload. Profile path
components must be directories, without links. As with existing harness
captures, later path-based writes require sole ownership; they do not protect
against hostile concurrent directory replacement.

The wallet must already be unlocked, initialized, on index 1 and signing chain
321. The selected node and every captured SDK transport must be exactly
`ws://127.0.0.1:45998`; the independent HTTP check is exactly
`http://127.0.0.1:45997`. DNS aliases, extra paths, redirects, proxy routing,
other ports and public endpoints are refused. Both endpoints must report chain
321 and positively advancing height, timestamp and hash during each admission.
The HTTP momentum must also be found by its exact hash on the original WS
client. A funded selected account and no unresolved earlier original are
required. These checks bind RPC observations to the local lab endpoints; they
are not authenticated consensus proof.

Run one source recipe after native qualification, with the named profile and
both origins supplied explicitly:

```text
harness/h seed stake --instance lab-fixture --ws ws://127.0.0.1:45998 --http http://127.0.0.1:45997 --checkpoint-ready
```

Replace `stake` with one ID from the table. The wrapper preflights the complete
small script before UI changes, then checks its captured context before every
line. Only the `publish` line can consume that recipe's publication attempt;
it uses one guarded real UI tap. Normal `harness/h run` does not understand
`publish` and is not the seed runner. No shell expansion or secret substitution
exists. Waits and polling have finite caps; each publication command has a
five-minute transport limit. A timeout preserves an unresolved original.
Preparation taps use a fixed per-recipe set of nonpublishing controls and
recheck the captured context at pointer down and up. The token control reuses
one key across steps; a preparation tap also requires its active original
Details, Supply or Options frame. The Issue frame requires guarded `publish`.

| ID | Deliberate wallet action | Required positive effect after its exact send |
| --- | --- | --- |
| `stake` | Stake 300 ZNN for six contract time units | Exact stake ID, owner, amount and duration |
| `fuse` | Fuse 100 QSR to selected index 1 | Exact owned fusion ID, beneficiary and amount |
| `token` | Issue `LabToken` / `LAB` | Exact ZTS derived from the original hash, with the captured owner/name/symbol |
| `deposit` | Create one 1 ZNN HTLC deposit | Exact deposit ID, both parties, native token and amount |
| `project` | Create a 100 ZNN / 100 QSR project | Exact original project ID, owner/name and budget |
| `fund-address` | Send 10 ZNN to derived index 2 | Exact send confirmation, exact receive from that hash, and positive target balance |

Index 1 already owns the lab pillar and genesis fuses; the recipes do not
recreate them. To derive the second funded address, first use the existing
Settings UI to append index 2, while exactly indexes 0 and 1 exist:

```text
harness/h run harness/seed/prepare-address.txt --instance lab-fixture
```

That preparatory script derives an address only. Recheck exact index 1 and the
new membership before `seed fund-address`. The runner obtains index 2 from the
captured immutable member list; there is no built-in recipient address.
The final funding tap also checks the existing immutable transfer confirmation:
sender must be selected index 1, recipient index 2, token ZNN and amount exactly
10 ZNN. A retained draft with another sender is refused before pointer release.

`deposit` additionally requires `--counterparty` containing an explicitly
chosen external account on this same isolated lab. It must be outside the
captured wallet members. No counterparty address or key is supplied here. The
full two-sided offer remains `Seam.swapTerms`; this recipe exercises only the
existing Details → Create deposit action. It cannot produce or claim an agreed,
joined or completed swap. Those screen states retain their explicit missing
coordinator/peer prerequisites.

The shared sender retains the first accepted original hash before optional
observers run. The seed guard captures its original operation set before the
tap, requires exactly one new original, waits for that original to settle and
for its wallet release, then looks up that exact copied hash. A toast, a
frontier change, a similar transaction or a settled Future is not confirmation.
Positive account-block confirmation and the operation-specific effect above
are separate checks. The small receipt records contain only recipe, state,
chain and exact original hash. They contain no wallet path or secret.

The read methods and model fields were physically checked against this
checkout's SDK ref `16bf294b3e347cb4f9c1f47a7da5d60034724f95`; no new SDK
publication or read endpoint was invented. This source inspection is separate
from parser, test, native and live-chain evidence.

An attempted recipe cannot run again in that profile. After its attempt is
claimed, a missing confirmation, partial write, unknown publication, ambiguous
new operations, read failure or changed context holds subsequent seed
publications. A preflight refusal has not tapped the publication control and
may be corrected. There is no retry,
replacement, re-sign, resume-send, journal deletion or cleanup command. Preserve
the profile and original evidence for owner review. A fresh profile is not an
authorization to repeat an unknown send on the same chain.

Two unreachable chain states use explicit read-only harness routes:

```text
harness/h seed fixture sentinel --instance lab-fixture --ws ws://127.0.0.1:45998 --http http://127.0.0.1:45997
harness/h seed fixture aged-fuse --instance lab-fixture --ws ws://127.0.0.1:45998 --http http://127.0.0.1:45997
```

They reuse the production Sentinel strip/list and owned-fusion presentation
with local scoped data. Pointer/focus input is blocked, every publication
builder/sender refuses, and no global SDK, node, balance or account list is
replaced. Closing returns to the prior route. A visible harness-only label and
`state.harnessFixture` identify the synthetic view. Source changes expire it.
These card fixtures do not replace the whole shell or qualify the existing
screen-capture prerequisites; native route preparation and shot comparison
remain pending. Ordinary builds cannot reach these routes: only the harness
entrypoint imports the agent and fixtures.


The hosted closed-copy coordinator receives actual wallet/cache paths,
ordered members, persisted selection and the original confirmed send hash
only in the authenticated private reply after original publication and receive
quiescence. These observations remain in memory and grant no write or process
authority on their own. The identical original wallet entry and all five node
processes must close normally before copying or rebinding.

A separate gated Hive child changes only key zero in the copied pointer box.
It requires the exact captured original path and the parent's exclusive
one-attempt claim. The continuous private-input listener retires on parent
EOF, errors, oversized or excess input. Original pointer/cipher files and
copied cipher bytes remain unchanged. The coordinator requires original child
exit zero, complete output and an empty owned job. Failures retain the claim
and private transport record; they cannot admit a retry or seed operation.
This source integration still needs actual hosted native qualification and
ordinary restored app/node opening before it can admit any F06 recipe.


The next hosted coordinator stage opens the independent node and wallet copies
normally. Original process objects stay closed. A captured original momentum,
current dual-transport reads, the same confirmed send hash, copied journal bytes,
ordered membership and committed index-one selection must all agree. Only one
new application handle and token may receive the retained password. No fresh
profile, import, derivation, replacement or original-send replay is performed.

The read-only `lab-reopen-observe` command checks those facts against current
owned resources; a saved receipt cannot construct or activate that owner.
New app, entry and five-node exits are recorded separately from the originals.
This source path still needs actual hosted native qualification. The six real
F06 recipe effects remain pending, and this observation does not admit seed.

The hosted coordinator now continues that same live reopened session with one
additional private admission record. Before any seed runs, the original
Settings controls append exactly index 2 while the committed selection remains
index 1. The original member prefix, Box/transport owner and one revision step
must agree. No import, selected-address replacement or second derivation is
used. The derivation stores address metadata; both encrypted wallet copies
must retain their original bytes.

All six existing recipes then run in their declared order. Every command
checks parent liveness and the same committed address context. Each original
must have its own distinct accepted hash, positive exact confirmation and
recipe-specific effect before the next recipe begins. Unknown, failed, late or
foreign results hold the session without another attempt. The deposit uses
the `dev2` owner in the already verified chain-321 genesis, outside the wallet
members. This fixture comes from the
[pinned node genesis](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/docker/devnet/genesis.json).
It supplies no counterparty key or two-sided Swap coordinator.

The parent compares all eighteen small attempt/accepted/confirmed records with
the exact original results, pins their identities and bytes through normal
closure, rechecks the original send/cipher/config files and reads the same
chain again. Public observations contain only finite counts, recipe IDs and a
receipt digest. Full hashes and transport output remain private. Reports
cannot restart the session or admit a publication. Native execution and full
F06 acceptance still need current hosted qualification.

The original native send and quiescence now have independent source-bound
qualification. The following copy stage refused because `python -m` loaded the
controller as `__main__`, while a helper imported a second controller module.
The strict Native class check therefore saw a different owner type. The CLI
now registers its identical module under the canonical import before either
admission or execution. An existing foreign module or parent alias refuses
before work; it is never replaced. Runtime, original-handle and publication
guards remain unchanged.

The redesign draws unavailable services behind seams. The existing HTLC deposit
provides the reachable Swap seed state; the missing two-sided offer/acceptance
coordinator remains disabled under `Seam.swapTerms`. Visual and seam acceptance
still require its drawn control and every activation route to be checked.

The canonical CLI binding is qualified by original native 40616426810 and
independent reader 40618093199, including all 279 Dart/696 Python gates,
original send/quiescence and normal required-actor closure. Its checkpoint
stage remains refused. The actual storage sampler returns an integer, while
two closed-wallet callers expected a dictionary. Aggregate accounting now
consumes that integer; additional-copy accounting uses the sampler's explicit
receipt and only its wallet role. Shared app/build bytes remain charged once.
Existing closure, profile, alias, quota and floor checks stay unchanged. Two
actual-sampler regressions and all 159 selected memory cases pass. Current
698-case Python and actual checkpoint/reopen/six-effect qualification remain
pending. Earlier failures and unknown originals retain their original status.

At d45f5d85f070, native 40618907222 and independent reader 40620632029 retain
all 279 Dart/698 Python gates, clean selected analysis, original send/quiescence
and normal required actors. The report reaches incomplete node path binding.
A direct Windows lexical control reproduces mixed deployment paths rejected
by the strict binder. New configurations now join native GenesisFile and
WalletPath names consistently; Docker keeps its explicit POSIX paths. No
historical config, binder guard, encrypted field or original outcome changes.
All 169 memory controls pass, including five-role factory/binder round trips.
Current 700-case Python and native copy/Hive/reopen/six-effect qualification
remain pending.

At 1cb99b60d149, original 40621397904 and independent reader 40623745276
retain all 700 Python/279 Dart gates, clean selected analysis and positive
original wallet phases. Hive binding is incomplete; its substep is unknown.
The candidate adds fixed parent/child phase labels and output category/digest
only to an incomplete active pointer failure. It never projects raw errors or
private paths, and a later reopen failure does not acquire a pointer diagnosis.
Unexpected output still refuses, and all ownership, original-file, cipher,
quota, floor and no-retry conditions remain. Eight new Python cases and all
177 memory controls pass. Two new Dart marker cases, the current 281/708
hosted gate and actual Hive/reopen/six effects remain pending.

Nineteen catalog scripts still declare preparation prerequisites. Retained
entry review also requires original globe/hero frames and a reversible
synthetic incomplete Import draft. Those states must be prepared through
their original UI owners; existing empty or differently timed captures do
not qualify the corresponding reference state. No visual match is accepted.

At fd7ff353ae6c, native 40627415772 and independent reader 40628977472 retain
708 Python/281 Dart gates, clean selected analysis and positive original
wallet phases. The pointer diagnostic reaches close without a child error;
overall checkpoint qualification remains failed and reopen is not entered.
A direct control invokes the actual WindowsJob.close method with memory-only
accounting/handles. Its normal empty closure records forced false but returns
null, while both copied-wallet callers require the returned flag to be false.
The shared method now returns its retained forced flag after unchanged close
effects. All caller, file, Hive, process, source, quota and floor checks remain.
Six new direct-method cases fail before the fix; all 183 selected memory cases
pass afterward. Current 714 Python/281 Dart and actual pointer/reopen/six-effect
qualification remain pending. Earlier failures and UNKNOWN originals remain.

At 396f8b1cd556, native 40629899975 and independent reader 40631641773
retain all 714 Python/281 Dart gates, clean selected analysis and positive
original wallet phases. Reopen is entered but incomplete; its failing substep
is unknown. Conservative failed summaries supply no positive binding receipt.

Both owned native handle closes now require a nonzero CloseHandle result.
Failure retains the original handle, raises fixed CLOSE_UNCONFIRMED and keeps
the forced status sticky. A data-only active reopen diagnostic additionally
records finite stages, fixed error kinds/allowlisted codes and bounded output
categories/digests. It never formats private errors or exports output text.
All original reopen guards, inputs, effects and positive schemas remain, and
a later failure cannot acquire a completed reopen diagnosis. Twelve new
Python cases and all 195 selected memory cases pass. Current 726 Python/281
Dart and actual pointer/reopen/six-effect qualification remain pending.
Earlier failures, UNKNOWN originals and all visual/capture gaps remain.

At 7c26b1f4c98f, native 40633782478 and independent reader 40635674241
retain 726 Python cases/three original skips, 281 Dart passes, clean selected
analysis and positive original wallet phases. Reopen remains incomplete at
initial_chain with fixed OTHER_ERROR and no observed domain code. A separate
actual-caller memory control reproduces a retained-height RPC admission
mismatch; its controlled RPC_REFUSED is not a native exception observation.

The candidate adds an HTTP-only scope for the one original parsed momentum
height, count one, alongside genesis. Canonical-by-height equality, genesis,
WebSocket hash agreement, advancement and all owner/wire/close limits remain.
Default HTTP and WebSocket readers retain their original scope. The chain
fixture now invokes actual payload admission. Seven new cases and all 215
memory controls pass; 1056 comparisons retain default admission bytes and
refusals. Current 733 Python/281 Dart and actual reopened ownership/six effects
remain pending. Earlier failures, UNKNOWN originals and all visual gaps remain.

Native 40637530459 at 2f6e94bd17da passes 733 Python/281 Dart gates and
clean selected analysis. Independent 40639144206 preserves the earlier
onboarding refusal with original codec frame pending, forced required-actor
cleanup and no send/quiescence/reopen receipt. The original Future and failed
session remain; the retained-height correction is not natively qualified.

The next source candidate additionally prepares only the public incomplete
Import draft, through the original EditableText input and exact source/action
generations. Its separate preparation receipt never repairs the old empty
receipt. Original navigation, controller disposal and Welcome restoration
remain. Another input, picker, coverage or source replacement refuses. It
performs no Continue/import/publication. All 216 Python memory controls pass;
734 Python/286 Dart and actual both-theme capture/reopen/six-effect
qualification remain pending. Earlier failures, UNKNOWN originals and all
94 visual matches remain open.

Run 40640236144 at 7369542364cd passes all 734 Python cases/three original
skips. Strict analysis refuses sixteen style infos before Dart/native work.
The follow-up preserves all literal inputs, assertions, startup call order,
gates and 734/286 counts while applying line wraps and test-only cascades.
The prior 216 memory controls are reused with unchanged Python inputs; no
local SDK or tests are repeated. Actual entry/reopen/six effects and all
94 visual matches remain pending.

At e5910159e1fb, run 40641069870 passes 734 Python cases/three original
skips and clean selected analysis. Dart reports 285 passes and one unlocated
NULL_CHECK before native allocation. The next test fixture awaits its exact
original Welcome route before receipt lookup. The finite projector adds only
six fixed entry basenames/numeric lines. No old failure is reattributed, and
no production guard or Dart case count is relaxed. All 217 memory cases pass;
735 Python/286 Dart and actual entry/reopen/six-effect qualification remain
pending. All 94 visual matches remain open.

At f2c8db2a416e, run 40643013209 passes 735 Python cases/three original
skips and clean selected analysis. Dart records 285 passes and a preparation
receipt assertion at entry_prepared_draft_test.dart:123 before native work.
The exact internal refusal predicate remains unknown; the earlier
unlocalized NULL_CHECK is not reattributed. The candidate captures the same
original owner's active action generation at reservation, then freezes it.
Original source/controller/route, first prepared-generation, disposal and
negative-scenario requirements remain. All 217 memory controls pass; the
unchanged 735/286 gate and actual entry/reopen/six effects remain pending.
All 94 visual matches remain open.

At d17b474b1362, native 40644753061 passes 735 Python/286 Dart and
clean selected analysis, then fails original onboarding with key-confirmed
and skip-frame-pending. Independent 40647207996 preserves the original
failure, forced required-actor cleanup and normal five-node exits. There is
no send/quiescence/reopen receipt and no observed pending frame index.
Producer 40645871645 and independent 40649202887 qualify 4565 non-chain
passes/two original skips, root analysis zero errors/warnings and 1295 infos,
Debug/Release builds and four genuine prepared Debug entry captures with
normal original exit/restoration. Fresh images remain unreviewed and no
visual match is accepted. The separate Release skip failure stays open.

The candidate passively reads the index requested by the original codec and
exports only fixed first/middle/last wait labels. Decoder operations, Futures,
actions, assets, deadlines and cleanup remain. No failed session is retried
or declared complete. All 218 memory controls pass; current 736 Python/287
Dart and actual entry/reopen/six-effect qualification remain required.
Nineteen catalog preparations and all 94 visual matches remain open.


### Copied startup acknowledgement and bounded child failure

At `8bbc93b0c0a8`, producer `40650905349` passes all 736 Python
cases with three existing platform skips, all 287 selected Dart cases
without failures/skips, and selected analysis with zero findings. Independent
reader `40653076744` qualifies original index-1 send of exactly one ZNN
to index 0, original-request confirmation, twelve tour checks, complete
quiescence and normal required app/entry/five-node exits. The wallet outcome
is schema two; the complete quiescence receipt is schema one. Auxiliary
telemetry termination does not replace required-actor closure.

The overall lab remains failed: its copied child reports startup during
unlock-and-observe. The old label spans window show and restored-lock wait.
No exact window/lock/codec cause, positive copied binding, reopen or six-effect
receipt is inferred. Earlier failed/UNKNOWN outcomes stay intact.

The candidate sends the original show request once, requires an acknowledged
finite 1280x780 client with neither minimized nor maximized state, and exports
no native reply. Separate startup-window and startup labels locate a later
original failure. Only fixed exception families/codes and validated recipe
labels enter the bounded child record. Messages, stacks, paths, replies and
private input are never formatted. The first failure remains a refusal and
cannot grant positive reopen or seed authority. Legacy diagnostic shapes
remain valid. The restored-lock refusal retains its last already-observed
labels without extra observations or commands. Original single skip,
deadlines, retirement, unlock/readiness checks, six-effect order and cleanup
remain unchanged.

Four new Python and three Dart cases raise the strict gate to 740 Python and
290 Dart cases. All 222 selected pure-memory Python controls actually ran
with zero failures/errors/skips and no filesystem scratch. No local SDK or
native test ran. Workflow, analysis rules, application, renderer/codec, entry
capture and existing test bodies remain; suite admission changes only for
three actual added Dart cases. Source126 full-root/build and four prepared
Debug image qualifications stay source-bound, with 1295 root infos and two
existing non-chain skips. Fresh images remain visually unreviewed. Nineteen
catalog preparations, copied reopen/six effects, ninety catalog outputs and
all 94 matches remain open; the main ledger stays 71 of 80 done.


### Original startup signing-policy baseline control

At `bb211cfb2243`, native `40658883876` passes all 740 Python cases
with three existing platform skips, all 290 selected Dart cases without
failures/skips and selected analysis with zero findings. Independent reader
`40661131808` validates original onboarding, index-1 send of exactly one ZNN
to index 0 with original-request confirmation, all twelve tour/capture checks,
complete quiescence and normal required app/entry/five-node exits. The overall
lab still fails during copied startup. Its bounded child record reports
RECIPE_REFUSED, launch_skip_hint key intent and original-owner-changed.
The target-client acknowledgement completed first. No positive copied
checkpoint/path/pointer/reopen or six-effect receipt is inferred.

The independent retained lab notice exceeds the single-notice limit and
therefore uses four existing parent-bound copy components. All four original
annotations are validated and reassembled without another API query, artifact
transport or runtime. They preserve the actual child refusal. The initial
two-scope observer projection and all original receipts remain retained.

The owner-refusal label covers several conditions, so it does not identify
the exact native condition. A separate source-bound control tests a circular
precondition: InitUtils restores the saved signing chain only after the launch
film completes, but the recipe currently requires saved/live equality before
its original Skip input. The actual registered StartupStageSession test keeps
its pending original decoder, same owner/revision and known preference, sets
saved chain 321 against initial SDK chain 1, and expects the unchanged owner
refusal with no Skip effect or chain mutation. It then restores only that
in-memory test preference and retains the original positive Skip, original
codec completion and cleanup checks. No application or harness behavior,
financial policy check, input/deadline, test count or existing gate changes.

This controlled before-fix assertion still requires hosted SDK execution.
The next focused harness lane requires the existing 740 Python/290 Dart
cases, clean selected analysis and one Flutter setup, with no native wallet
or node. The prior 222 pure-memory Python controls retain identical inputs
and are reused; no new local SDK, native or filesystem qualification runs.
Source126 root/build and four prepared Debug image receipts remain separate.
Those images are unreviewed, nineteen catalog preparations remain literal
refusals, and all 94 visual matches and copied reopen/six effects remain open.


### Original Skip before the saved chain is applied

At `db69aa709192`, focused run `40663038443` and job `122730539020`
pass all 740 Python cases with three existing platform skips, all 290 selected
Dart cases without failures/skips and selected analysis with zero findings.
One Flutter setup is used and no native wallet or node is started. The actual
registered StartupStageSession case retains its original pending codec,
owner and revision, sets known saved chain 321 against initial SDK chain 1,
and confirms the unchanged original-owner refusal with no Skip effect or
SDK chain mutation. It then restores only its in-memory preference and retains
the original positive Skip, original codec completion and cleanup assertions.
This qualifies the separate before-fix control. The merged Native75 guard
label still does not identify which individual condition failed in that run.

The candidate binds the exact original startup receipt before observation.
Only that same current receipt, before initialization, with its open original
StartupStageSession and unfinished original film, may receive its existing
Skip before saved/live signing-chain equality. A known positive saved
preference remains mandatory. File/client identity, owner/revision, error,
current receipt, original hint/focus/control geometry, one original Space
pair and actual original-film effect confirmation are retained. Initialization
or a finished/replaced/held owner cannot supply the exception. Financial
tap/type/scroll actions retain the original signing equality. No signing,
preference application, new input, retry, deadline or decoder change is added.
The application's own initializer still applies the saved policy after launch.

The same genuine case now requires the original Skip with saved chain 321
while proving that the SDK remains 1 and the preference stays 321. Stale
owner/revision and unknown preference still refuse before input. The original
foreign-key-handler case now also keeps a pending saved policy: financial
tap/type/scroll refuse, and an intercepted key cannot acknowledge an original
film action. Every original positive key/decode/cleanup and negative handler
assertion is retained. Test counts stay 740 Python/290 Dart; analysis rules,
workflow and all other runtime bytes remain. All 222 selected pure-memory
Python controls actually reran and passed without failures/errors/skips or
filesystem scratch. No local SDK/native test ran; actual current runtime
qualification remains pending.

Source128 original UI/send/quiescence remains independently qualified by
`40661131808`; its failed copied startup and all parent-bound notice components
remain intact. Source126 root/build and four prepared Debug image receipts
remain separately bound. The four fresh images are unreviewed, nineteen
catalog preparations remain literal refusals, and actual copied reopen/six
effects and all 94 visual matches remain open. The main ledger stays 71/80.


### Prepared entry review and copied unlock observation

At `3daccdd2fc0d`, producer `40667432677` and independent reader
`40672842001` qualify the original onboarding, persisted index-1 UI send of
exactly one ZNN to index 0 with original-request confirmation, all twelve
page/capture checks, complete quiescence and normal required app, entry and
five-node exits. All 740 Python cases and 290 selected Dart cases pass;
selected analysis has zero findings. The copied startup procedure returns
and reaches unlock; its key-versus-natural completion path is not recorded. Its original diagnostic retains `HARNESS_REFUSED` with
no operation code; the overall producer remains failed. All four copied
checkpoint/path/pointer/reopen components remain incomplete and parent-bound.
No copied reopen or six-effect qualification is inferred.

The candidate adds passive operation observation to the original unlock.
Only a genuine harness refusal from that one call is mapped to a fixed state,
lock requirement, password-field, button, wait or failure-tree label. Unknown
errors retain their original family and no new detail. The same commands,
password/button attempt, twenty-second wait, original failure-tree read and
cleanup remain. No retry, policy write, password logging or authentication
change is introduced. Existing original positive command assertions remain, and all six
command-refusal vectors are added to the isolated cases.

All four prepared Debug images at source126 `d17b474b1362` have now been
opened against their retained references. Both Welcome globe orientations
differ. Both Import word-counter glyphs start at y496 instead of y507;
seed input uses mono instead of reference sans, and word-selector extents
measure 183/184 pixels versus 176. Font hinting is explicitly allowed by the
acceptance requirement and is not itself a defect. These pairs stay unaccepted.
The candidate uses sans for seed prose, bottom-aligns the existing counter
and explicitly sets normal base tracking. Tabular figures, deliberate ledger
and hero tracking, numeric font roles, callbacks, validation, controller
ownership and original animation clocks are preserved. Real render styles
and counter geometry are asserted within existing genuine-route and both-theme
cases. SDK, fresh-image and current full-root qualification remain pending.

Source129's before-fix control and all earlier failures/UNKNOWN attempts stay
separate. No local SDK/native test runs. The main ledger remains 71/80,
with zero of 94 visual matches accepted, ninety missing catalog outputs and
nineteen literal preparation refusals. The written Docker/lab route, copied
reopen/six effects and every remaining acceptance requirement remain open.

All 222 selected pure-memory Python controls actually pass with zero
failures, errors, skips, blocked native/scratch attempts or filesystem scratch.
Current hosted Dart and native image qualification are still pending.


### Current analysis gate correction

At `9190011cf540`, run `40674595125` passes all 740 Python cases with the
three existing platform skips. Selected analysis then refuses with three
errors, one warning and two infos: a new counter-label variable reused the
name of a later original route receipt, and two new lines exceeded eighty
characters. Dart tests and all native allocation steps are skipped. No
current SDK test or native result is inferred from that run, and it is not
retried. The candidate renames only the new label variable and wraps the
new lines; original assertions, route receipts, commands, deadlines and
case counts remain. The earlier source130 copied startup procedure returned
before unlock; its retained diagnostic does not record whether a key or
natural film completion led there. No specific copied Skip effect is claimed.


### Original editable-render query correction

At `b1dc75d37842`, run `40676239168` passes 740 Python cases with the three
existing platform skips and selected analysis with zero errors, warnings or
infos. The 290-case Dart run completes with 289 passes and one unhandled
`TYPE_ERROR` in the new prepared-entry render query, at line 223; the framework
location is the tester's generic render-object cast. Every original native
allocation step is skipped. The other passing cases include the six isolated
unlock-refusal vectors. No actual copied unlock or seed effect is claimed.

The candidate obtains the same original EditableTextState from its existing
field finder and reads that State's actual renderEditable. It retains the
real renderer's family/tracking assertions, counter geometry, all original
route/controller ownership assertions and the matching both-theme query.
It does not replace the renderer or relax the expectations. All product
runtime bytes, case counts and failure gates remain. The failed original is
preserved and not retried; hosted correction and fresh-image proof are pending.
