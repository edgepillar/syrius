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
