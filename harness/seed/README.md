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
