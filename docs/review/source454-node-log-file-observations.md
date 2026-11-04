# Source-bound node log observations

The [Source453 result](source453-coordinated-lab-retirement.md#actual-source453-result)
retains the same failed thirty-second progress window. Its four zero-exit node
events include RPC, while observer still exits 137 without an observed OOM event.
The batch correction is exercised, but production and five normal exits remain
unqualified. The exact inner causes remain NOT_ESTABLISHED.

The pinned node's [logging implementation](https://github.com/zenon-network/go-zenon/blob/590f43ca7a24dccd8e883bc8903a0cb02e54528a/common/logs.go)
routes its log handlers into `log/zenon.log` and `log/error/zenon.error.log`
under its data directory. The previous failure observer reads container stdout
and stderr only. No recognized code in those streams is not evidence that the
node's file logs contain no error. The original raw file contents are unretained;
they cannot be reconstructed from the old empty diagnostic lists.

Source454 adds one bounded tail of each fixed file for each still verified
original container, only after an observation failure. The command rejects
symlinked log directories/files and requires a regular file before reading.
Each source records READ or a closed read/projection refusal code. The existing
node classifier exports at most four known codes per role across readable files.
No path, address, peer, key, raw line or unknown exception text is exported.
Raw streams remain private to the hosted execution with their ordinary bounded
retention receipts; no artifact transport is added. An absent or refused error
file is unqualified, rather than a positive health result.

File-read or projection errors cannot replace the original observation error or
prevent the existing retirement attempt. Original identity is checked again
after diagnostics. The two commands per role use the existing twenty-second
command and 2 MiB per-stream bounds. The original up/status/down route, node,
all four lab input pins, thirty-second progress check and five-zero-exit/no-OOM
criteria stay unchanged from Source453.

Two new local pure controls exercise fixed bound-ID paths, regular/symlink
guards, known-code projection, malformed output and closed command/projection
refusals. The existing eighty-receipt case now supplies the full summary with
large diagnostic/exit values and retains the 3,800-byte notice bound,
all binding/index assertions and complete receipt packing. Twenty-two local
controls pass; six shell cases remain explicitly unselected locally. The full
hosted preparation becomes 1,034 Python cases. Fresh source/runtime execution
is pending. No local shell, Docker, node, wallet or SDK executes.

No application Dart, financial action, dependency or reference changes. The
qualified 1,230-case UI remains bound to Source447. Source450/451/453 failures
keep their own facts and unknowns; no unchanged trial is scheduled again.
Windows Docker Desktop, F06, native visual/performance and final acceptance stay
open at 72/80 and zero accepted visual matches.
