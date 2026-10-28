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

### Source133 results and the optional startup observation lane

Source `56681c8df917` passes all 740 Python cases with three existing skips,
290 Dart cases and clean selected analysis in producer `40678579258`.
Independent reader `40681812731` preserves its failed original Release
startup: the key is confirmed, initialization has not started and an
original middle-frame decode is pending at the deadline. Required actors
need forced cleanup. Copied unlock and all six wallet-driven seed effects
are not reached. Five original lab nodes exit normally; no current reopen,
checkpoint or seed authority is inferred. The exact index/progress/cause
was not recorded, and no original failed or UNKNOWN result is rewritten.

Separate producer `40679712623` and reader `40684642736` qualify 4569
non-chain passes/two existing skips, root analysis zero errors/warnings
with 1295 infos, clean vendored analysis, Debug/Release builds and four
prepared Debug entry captures/restoration/normal exit. Actual image review
confirms the corrected sans field and bottom counter placement, while
selector extents, original Welcome frame/drop behavior and incomplete-draft
decoration remain open. There are zero accepted matches, ninety missing
catalog outputs and nineteen literal preparation prerequisites.

The candidate's default-off `windows_startup_probe` workflow input selects
a bounded ordinary Release observation without a node cluster or wallet
import. Existing recipe ownership and real key/effect confirmation still
admit its single optional Skip. Finite samples read the same original
registered film's count, shown/decoding indices, wait stage and booleans;
they never request another frame or replace its original Future. A missed
twenty-second deadline remains failed through later original-process cleanup.
Natural startup does not become Skip qualification. Only a finite manifest
is retained, and no wallet, chain, seed or visual acceptance is granted.
New controller, genuine-State and hosted execution proof remain pending.

The twelve new protocol/projection cases now pass within 234 selected
pure-memory controls with zero failures/errors/skips or native, network,
scratch and shared-store access. A deadline-coincident RPC failure remains
recorded, missing source/run/payload pins deny success and natural handoff
never grants Skip qualification. Current genuine-State and hosted execution
remain pending. The local review task is closed with its original metadata
failure preserved; the verified image archive is retained without a second
transport or runtime.

### Source134 original progress and the full-frame candidate

Original run `40693805385` at `415b992ba5da` passes 752 Python cases/three
existing skips, all 290 Dart cases, clean selected analysis and Release
build. Seventy-one original samples advance from decoder index 2 to 42 of
56 during the unchanged twenty-second boundary. One original recipe key
is confirmed. Startup remains failed; the original process exits zero with
complete output, no force and verified source/payload/window restoration.
This supplies no copied reopen, seed effect or retrospective native cause.

The full text report survives the 4096-byte annotation truncation. The
candidate summary is bounded below 3800 bytes and binds every sample by a
report digest; stdout and manifest retain the full history. Memory tests
verify that changing a middle sample changes that binding.

The independent-frame launch candidate retains the same master pictures,
56 frames, 2560 by 1440 dimensions, durations and one loop. It changes only
full-size encoding; the master, smaller well, original decoder/Futures,
key flow, renderer and twenty-second deadline remain. Its 1501054-byte
in-memory readback scores worst PSNR 40.39 dB, mean 49.81 dB. Performance
improvement is unqualified. The startup-only gate opts into two existing
engine asset-fidelity cases for 292 total, preserving every original
expectation; ordinary wallet-tour admission remains 290. Native proof and
all F06 effects remain pending.

### Source135 result and the original Skip ending

Run `40704899983` at `5e23b2bf1caf` passes 752 Python cases/three existing
skips, all 292 Dart cases including both engine fidelity checks, clean
selected analysis and Release build. The bounded notice exactly binds all
67 samples in the complete original log. Decoder indices advance 3 to 21
of 56, one key is confirmed and startup misses its unchanged deadline.
Original exit zero, complete output and restoration do not heal that
failure. No comparative runner cause, copied reopen or seed effect follows.

The larger experiment is preserved in history and the smaller original
film is restored exactly. Skip alone may use a 9458-byte independent still
whose original compressed payload and final pixels are retained. The
pending original frame returns before its codec is disposed; the same
decoder run then awaits the actual still and retains its result/error
through cleanup. Natural frame order and clocks, source master and well,
recipe-owned key, signing/ownership guards and deadline remain unchanged.
Five new engine regressions require 295 ordinary passes, or 297 in startup
with both existing asset cases and exact final-pixel equality. All 234
memory controls pass; current engine/native and all F06 proof remain open.

Source136 `d1fe7944f439` / `40709856724` passes all 752 Python cases/three
existing skips, then retains two selected nullable-access analysis errors
at `launch_film.dart` lines 487 and 497. Dart, build and native steps are
skipped. The candidate retains the first codec in a final non-null local,
separate from its nullable cleanup owner. Awaited operations, disposal
order, assets, assertions, guards and deadlines remain unchanged. The
original refusal stays preserved and no engine, startup or F06 acceptance
is inferred before the same 297-case gate and actual native execution.

At source137 `de47eb36c003`, `40712460421` passes all 752 Python cases/three
existing skips and clean selected analysis. Its Dart gate retains 295
passes, two failures and three error events; build/native steps are skipped.
Two tiny-film bundles also serve their eight-frame movie for the ending
name. Only that name is now bound to the same tiny film's one-frame ending,
with the original pending movie Future and all assertions retained.
Product runtime, assets, guards, deadlines and the strict 297-case gate
remain unchanged. The original failure and absence of current native/F06
proof stay preserved.


At source138 `7e851d350ac7`, startup `40715154449` passes all 752 Python
cases/three existing skips, 297 Dart cases, clean selected analysis and
Release build. Exact engine equality between the original final frame and
the still passes. One confirmed original Skip reaches genuine Welcome at
4250 ms within the unchanged twenty-second boundary. Thirteen checks and
normal complete unforced original exit pass. This producer observation
supplies no natural-playback, motion/frame-time or full-lab acceptance.

Native80 `40717245830` and independent reader `40722889316` qualify original
index-1 UI send of exactly one ZNN to index 0, twelve tour/capture checks,
complete quiescence and normal required app/entry/five-node exits. Auxiliary
force is separately recorded. The producer still fails at the copied
password-field input request (`UNLOCK_TYPE_REFUSED`, `HARNESS_REFUSED`).
This names an operation, not a Dart TypeError, wrong-password result or
exact guard. Partial input effect remains unknown. All four copied
components remain incomplete and six effects remain unqualified. The
original profile/password is not retried; reader success preserves failure.

Two new real LockCard/agent regressions require readiness before any
password input while fields are absent, disabled or covered, and exactly
one write/submit when reachable. A bounded covered-field ready wait must
refuse without changing text. Runtime is unchanged for this controlled
before-fix run. The strict gate selects all 297 ordinary cases, or 299 with
both original asset cases. All 234 pure-memory controls pass without native,
network, scratch or shared-store access. No readiness fix, copied reopen,
six-effect or historical cause is inferred from these controls.


Source139 `25faff6d9fb2` / `40726560405` passes all 752 Python cases/three
existing skips. Selected analysis retains zero errors/warnings and two
infos in the new readiness test: an unnecessary underscore name and one
long assertion line. The Dart step is skipped, so no actual readiness
behavior result is inferred. The style-only candidate removes the unused
builder name and wraps the same command-list expectation. All original
runtime bytes and test meanings remain unchanged. All 234 current memory
controls pass; clean analysis and the same 297-case before-fix gate remain
required before the runtime candidate is published.


At source140 `d1208b5f8e85`, controlled `40728093871` has clean selected
analysis, all 752 Python cases/three skips and all 295 original Dart passes.
Exactly two new real LockCard/agent readiness assertions fail at lines 136
and 182, with complete unforced original output and no native wallet run.
The complete original log and fixed projections are retained. This
reproduces the missing-field early input and covered-field presence-only
wait without assigning Native80's unobserved exact refusal condition.

The candidate retains that genuine regression file byte-for-byte. Unlock
first makes a read-only five-second wait for one enabled, reachable field,
then the unchanged original password write, submit and twenty-second
post-submit wait. Existing presence waits and input guards remain. A
readiness refusal exports only `UNLOCK_FIELD_READY_REFUSED`, alongside all
six prior operation labels and privacy/refusal vectors. There is no input
retry or formatted private reply. All 234 current memory controls pass;
the same 297-case ordinary gate must pass before a fresh owned native lab
runs copied unlock/readiness, all four components and six effects. Both
original asset cases remain selected in the 299-case startup variant.
Source139's two-info analysis refusal and skipped Dart remain preserved.


Source141 `b091e1df2a0f` / Native81 `40730222576` passes clean selected
analysis, all 752 Python cases/three skips and all 295 original Dart cases.
Both new cases retain an assertion at the observer's pending check, line
95. Node checkout/compiler, lab build/runtime and both manifests are
skipped. No positive completion of those synthetic original Futures is
observed; the complete original failure and source pins remain retained.

The agent uses real Stopwatch time as well as timer/frame Futures, while
the helper advances only fake test time. The candidate advances wall time
by ten milliseconds alongside every existing forty-millisecond frame pump,
with a 300-iteration observation cap. Every genuine widget, assertion and
original Future remains; all product runtime bytes, waits and guards are
unchanged. All 234 current pure-memory controls pass. The same 297-case
ordinary gate must pass before fresh native allocation; readiness, copied
reopen, four components, six effects and final acceptance stay open.


At source142 `37665e96f9d9`, Native82 `40732953625` passes all 297 ordinary
Dart cases, all 752 Python cases/three skips and clean selected analysis.
This includes the two genuine LockCard/agent readiness controls with both
wall and frame clocks observed. Reader `40737067681` independently binds
both finite archives and all four copied component frames. Original
one-ZNN UI send, twelve tour/capture checks, complete quiescence and normal
required app/entry/five-node exits pass; auxiliary force remains separate.
The copied input and submit requests are acknowledged, then the unlock
wait returns `UNLOCK_WAIT_REFUSED`. This establishes no authentication,
timeout or wrong-password result. All four copied components and six
effects stay incomplete. The original profile/password is not retried;
reader success preserves the producer failure and every older UNKNOWN.

The Welcome candidate mounts the existing drop adapter only on the Import
row and only under its genuine current lease. Its bounded content probe
transfers an admitted selection, or explicit refusal, into the original
Import route and controller owner. No Continue or decryption runs on drop.
An initial offer revokes untouched-empty capture admission, including an
invalid or multiple-file offer. Private paths remain outside presentation.
Pure component/shader fixtures use inert drop adapters.

One new real route regression covers accepted, refused and multiple files,
permanently stale callbacks after coverage/return, production structural
probing through closed bounded memory handles, original navigation Futures,
controller disposal and same Welcome owner/Element restoration. Only the
startup policy and file handle are fixtures. The focused gate retains all
298 ordinary cases, or 300 with both original engine asset cases. All 234
memory controls pass. Full Windows root/non-chain and vendored analysis,
localization/source regeneration equality, Debug/Release builds and four
original prepared entry captures remain required. No current pixel match,
copied reopen, six-effect or final acceptance is inferred from this source.


Source143 `02dc394f59f6` / `40739159280` passes all 752 Python cases/three
existing skips, then selected analysis refuses one `UNNECESSARY_IMPORT`
info in the new route test. Dart is skipped. The candidate removes that
redundant typed-data import and preserves the original refusal.

The retained cross_file 0.3.5+2 implementation constructs a File for XFile
metadata and reads its path before any content open. The memory fixture
therefore supplies File.path and allocates/counts a probe handle only on
openSync, with read mode asserted. File metadata construction is not an
actual probe. This contract gap is source-observed; the source143 route
case did not execute. Every original route/privacy assertion, genuine
owner, input callback and product runtime byte remains. All 234 memory
controls pass. Clean analysis and the same 298/300 focused gate, followed
by full Windows/root, generation, builds and entry captures remain required.


## Passive copied-lock owner observation candidate

The Native82 copied input and submit requests are acknowledged before
`UNLOCK_WAIT_REFUSED`; authentication and the exact wait condition are
unobserved. The new candidate retains the original genuine lock Element before
its ordinary unlock. It exports fixed view/route/focus/lifecycle booleans and
a bounded visible failure count, with an explicit replaced/retired result
instead of adopting a later owner. No input, wallet data, error text or stack
is read. Both closed projections reject private or unknown fields.

Original wallet callbacks, attempt storage, signing and lifecycle guards,
one password/submit sequence, the twenty-second wait and cleanup remain.
No decryption or callback is started by observation, and a failed observation
never retries or replaces the original unlock refusal. Two genuine-owner and
two closed-schema/driver cases join a pending 323-case ordinary gate. All 236
current memory controls pass; actual copied reopen and six effects remain
unqualified. The failed original profile/password is never retried.


## Observed style correction and bounded root diagnostics

Source145 40750664024 passes all 754 Python cases/three skips before eleven
selected style infos refuse Dart. Only the observed brace/cascade/type and
null-aware-map syntax changes; original owner identity, observations, input,
assertions, attempt/signing/lifecycle guards and waits remain. All 239 memory
controls pass. The current gate requires 756 Python and 323 ordinary Dart
cases, or 325 with both existing startup asset cases.

Future failed root suites retain at most three fixed source locations without
raw errors or private input. The independent reader validates the closed
projection and exact producer parser. This does not retrospectively identify
the source144 failed test, qualify copied authentication or supply six effects.
The original failed copied profile/password is not retried.


## Pre-SDK tool-version observation boundary

Source146 40753149071 passes all 756 Python cases/three skips before the
original Node version process reaches its five-second limit with no output
and forced exit. Asset control execution, SDK setup, analysis and Dart are
skipped. The candidate uses the existing fifteen-second asset-control budget
for that one metadata command only; the single attempt, 256-byte output cap,
complete unforced exit/version requirements and one-minute workflow step stay.
No wallet, signing, attempt, lifecycle or twenty-second unlock deadline changes.

The controlled before-fix refusal and actual original timeout remain negative.
All 246 memory controls pass. The current hosted gate requires 757 Python
cases and 323 ordinary Dart cases, or 325 startup cases. Actual copied reopen,
six effects and original failed profile/password retry remain outside this
tool-version observation and are not inferred.


## Restored test fixture field promotion

Source147 40755209257 qualifies 757 Python cases/three skips and actual
original tool-version/asset controls. It then retains one selected nullable
cast info and skipped Dart. The same final mock field is captured in a typed
local and guarded before the identical Map copy; field values, refusal,
commands, callbacks and assertions remain. Product/harness code and the
323/325 case counts are unchanged. Previous 246 memory controls are reused
for unchanged Python inputs; no extra local SDK/native test is run. Actual
copied authentication, six effects and the failed original profile/password
remain unqualified and unretried.


## Original lock progress and baseline-only inspection

Source148 focused 40757196779 passes 757 Python cases/three skips, all 323
ordinary Dart cases and zero selected findings. Native83 40759392257 and
independent 40761639128 qualify original send/tour/quiescence and normal
required app/entry/five-node exits. Copied unlock retains UNLOCK_WAIT_REFUSED.
Its same original post-refusal owner is current, visible, input-enabled,
startup-interactive and idle, without password/error/storage-failure signs.
This does not establish earlier callback execution or authentication.

The candidate stores only bounded request count and fixed callback phases.
It reads no input or error text and invokes no callback, wallet I/O or frame.
Removing diagnostic writes reconstructs the complete original callback.
Original input, attempt, signing, lifecycle, path and deadline guards remain.
Legacy views remain legacy observations; rich fields must be paired and
closed. Two genuine-owner controls cover empty-input refusal and the original
typed-input/pointer route reaching an unavailable capture guard. They open no
wallet and still need hosted execution.

Baseline-only inspection requires the exact completed skipped entry with
zero steps, preserves the actual baseline outcome and emits an explicitly
unqualified entry summary without fetching an entry artifact. Malformed or
mismatched jobs still refuse and false success cannot replace a failed test.
All 261 pure-memory controls pass without native/network/scratch/store access.
The next gate requires 763 Python cases/three skips and 325 ordinary or 327
startup Dart cases with zero selected findings.

Source148 full Windows 40760650691 remains separately source-bound and is
still being observed. Its entry job is deliberately skipped. Four verified
source144 images remain queued after six metadata preflight refusals, before
any local task or transport. Approved small-archive limits, policy and floor
remain. Copied reopen/six effects, nineteen preparations, ninety outputs,
all 94 matches and earlier failure/UNKNOWN evidence remain open.
