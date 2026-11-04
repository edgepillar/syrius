# Reference compiler recipe for the actual lab commands

The [actual Source455 candidate result](source455-pinned-node-candidate.md#actual-source455-result)
still stalls at height two and has four nonzero exits. Its exact inner causes
remain NOT_ESTABLISHED. An unchanged source trial is not scheduled again.

The existing [hosted backend](../../tool/ci/hosted_chain321.py) uses Go 1.24.1,
CGO, `-trimpath`, `-buildvcs=false`, locked modules, `netgo,osusergo` and external
static linking. Its Docker stop grace is twenty seconds. The upstream
[Dockerfile](https://github.com/zenon-network/go-zenon/blob/0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b/Dockerfile)
uses Go 1.23 and `make znnd`; the original lab stop grace is ten seconds.
These are source-observed differences, not established causes of the old failure.

Source456 adds the explicit `dev-0e80915-reference` workflow choice. It selects
the same fixed unmodified node SHA/tree as `dev-0e80915` and sets only the
`reference` build recipe. `original` remains the default. Unknown choices refuse
before allocation; neither a moving ref nor a local Go patch is introduced.

The new [Dockerfile.reference](../../tools/devnet/lab/Dockerfile.reference) checks
the exact Linux/amd64 Go 1.24.1 version, disables automatic toolchain switching,
sets CGO explicitly and uses the existing static build flags. Module files must
remain byte-identical after download and build. The role-aware entrypoint and
devnet assets still come from the pinned upstream export. The C runtime/compiler
and Alpine runtime differ from the custom backend's GNU compiler/scratch image;
image tags remain mutable. This is not binary reproducibility, frozen-image
provenance, an ELF check, or transferred runtime qualification.

`lab.sh` accepts only `upstream` and `reference` recipes. Reference images carry
a distinct `-reference` tag suffix. A mismatched or malformed stored tag refuses
before Docker execution, including inside Compose command substitution; failed
builds cannot publish a revision. The reference recipe submits the same validated
five-ID stop batch with the existing backend's twenty-second grace. Upstream
keeps ten seconds. The parent's forty-five-second down limit and the requirement
for five original zero-exit/no-OOM events remain unchanged.

The controller binds choice, node SHA/tree, recipe and tag, and pins all five
repository lab inputs. An upstream image cannot satisfy the reference header.
The thirty-second progress window, fresh project, original ID/start/PID and
source/genesis checks, stream/storage limits, and single-down rule remain.

Four additional hosted-only actual-Bash fixture cases cover reference retirement,
recipe/tag refusal before Docker, both build recipes and failed-build retention.
They use regular files and fake Git/Docker commands, without a daemon, compiler,
node or wallet. Two new pure cases cover reference binding/refusal. A third adds
fixed producer generation/broadcast/contract error categories from the pinned
[worker source](https://github.com/zenon-network/go-zenon/blob/0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b/pillar/worker.go).
Only closed codes, at most four per role, are exported; raw messages stay private.
Empty recognized codes still do not prove absence of errors.

All twenty-seven local pure controls pass; ten shell cases remain explicitly
unselected locally. Full hosted preparation is 1,043 Python cases. Fresh source
and reference runtime execution are pending. No local SDK/native execution,
binary transport, Windows rebuild, wallet operation or image transport occurs.
No application Dart, dependency manifest or reference changes. Full acceptance
remains 72/80 with zero accepted whole-image matches; P03/P09/F06 and final
platform, visual and performance acceptance remain open. The PR stays Draft.

## Actual Source456 result

Source `73ffe7cc96438ebd8799264fcea05777c3945d72`, tree
`065db71ed87a5aa0bc2a9a357353366a630f3072`, passes 1,043 source controls with
two existing Linux skips and all ten actual-script fixtures in source-only
[41925765311](https://github.com/edgepillar/syrius/actions/runs/41925765311)
and manual [41926018636](https://github.com/edgepillar/syrius/actions/runs/41926018636).
Both runs are terminal with zero artifacts. The manual runtime job
126910766421, attempt one, remains failed at the production check.

All ten source/tree/run/attempt-bound notices and 34 complete unforced command
receipts independently consume; the largest notice is 3,049 bytes. The report
binds the exact upstream SHA/tree to `dev-0e80915-reference` and the reference
recipe. Up advances chain 321 from one to two over forty-five seconds. Status
exits one after height two remains two for thirty seconds.

Down exits zero. Every original container has one zero-exit die event and no
observed OOM; the following empty-project and empty-network checks pass. This
qualifies normal retirement for this source/run, with no close error. It does
not identify whether the compiler settings, grace interval or another factor
explains the difference from older runs.

All five main files read. Pillar's error file also reads and projects the closed
code NODE_MOMENTUM_NOT_BROADCAST; the other four error sources remain unavailable.
The pinned worker emits that message when a generated momentum misses its
three-second broadcast window. This source correspondence is not proof that it
is the sole cause of the thirty-second stall; its inner timing and the other
file refusals remain NOT_ESTABLISHED. Old raw logs are not reinterpreted using
the new classifier.

Production and final native source remain unqualified. Normal shutdown does not
turn the failed runtime into a pass, and VM disposal remains unqualified. All
earlier failure facts and strict criteria are preserved. The next correction
will require continued startup progress within the existing startup bound,
instead of treating the first single advance as sufficient readiness. The
thirty-second status window and protocol broadcast deadline will not increase.
