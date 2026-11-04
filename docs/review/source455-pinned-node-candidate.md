# Pinned upstream node candidate

The [Source454 result](source454-node-log-file-observations.md#actual-source454-result)
retains a failed progress window and five nonzero exits. File observations now
read all five main logs, with error-log sources unavailable and no recognized
closed code. The exact inner causes remain NOT_ESTABLISHED. No unchanged trial
is scheduled again.

The upstream dev snapshot
[`0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b`](https://github.com/zenon-network/go-zenon/tree/0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b),
tree `244d362062b03c07e205ef9a2ad7ba1071fe779a`, has a separate
[production-readiness predicate](https://github.com/zenon-network/go-zenon/blob/0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b/protocol/readiness.go)
and [joined legacy retirement](https://github.com/zenon-network/go-zenon/blob/0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b/p2p/legacy/server.go).
These source differences motivate a separate candidate trial. They do not prove
the old failure's cause or the candidate's behavior.

The manual workflow adds exactly one candidate choice, `dev-0e80915`, alongside
the unchanged default `original`. Both choices resolve to fixed SHA/tree pairs.
Unknown names, arbitrary revisions and malformed values refuse before allocation.
The selected pair binds the child build environment, fetched Git objects, image
tag and report. A candidate header cannot borrow an original-node build. There
is no moving branch lookup during execution, patch application or default change.
The repository's actual up/status/down script route is retained.

Compared with original node `590f43c`, the candidate changes locked module inputs
and genesis; its three additional module names are not new to this qualification
tooling. `go.mod`, `go.sum`, Dockerfile and the complete devnet directory are
byte-identical to the already supported upstream/lab-fix base `2d1b929`, tree
`4467fff960ea6a5409908d7c85497a68482e0edb`. Other devnet entries match the original
node as well. This correspondence is input evidence only. The local lab-fix patch
is not applied, and neither its regression proof nor an earlier native pass is
borrowed for this unmodified upstream candidate.

Two new pure controls cover exact profile admission and refusal of an old-node
build under a candidate header. The existing complete lifecycle case now checks
both profiles with the same source, identity, increasing-height, single-down,
zero-exit and final-input assertions. All twenty-four local pure/mocked cases
pass; six shell cases remain explicitly unselected locally. The full hosted
preparation is 1,036 Python cases. Fresh source and candidate runtime execution
are pending.

All four repository lab inputs, the thirty-second status window, 900/45/45-second
parent limits, twenty-second diagnostics, storage/output caps, complete bound
notices and strict five-zero-exit/no-OOM criteria remain. No wallet, Flutter SDK,
application Dart, financial route, dependency manifest or reference changes.
The candidate does not qualify Windows Docker Desktop, wallet import/send, seed
effects, native pixels or performance. Full acceptance stays 72/80 with zero
accepted visual matches, and the PR stays Draft.
