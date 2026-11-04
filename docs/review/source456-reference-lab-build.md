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
