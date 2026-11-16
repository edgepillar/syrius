# Passive shutdown observation

Source802 completes preparation and every measurement action, then misses
the original wallet exit limit. Its retained evidence does not identify the
application operation still pending. This revision adds fixed close-phase
observations without changing those operations or their deadlines.

The original closing root records native window queries, preference writes,
the SDK stop request, embedded-node close, service reset, widget cleanup and
the process-exit request. Embedded-node close also records wake-lock reads
and release, the original stop request, exit wait and subscription cleanup.
The record contains only a fixed phase and a failure bit. A replacement
owner cannot overwrite it; terminal records ignore late phase changes.
Exceptions and private values are not retained. An existing close exception
is rethrown with its original stack.

The authenticated wallet harness exposes this record through shutdown-state,
with no additional command fields. Ordinary application close performs no
new network request, timer or action. Native window operations, preference
writes, node ownership checks, service cleanup and the existing sixty-second
application fallback remain in their original order.

Only after the original ten-second exit wait reports EXIT_TIMEOUT does the
paired controller request one passive snapshot. Its request is bounded by
one second and the original total deadline. It never repeats quit and
rethrows the original timeout, including when the diagnostic request fails.
A missing older-baseline command is unavailable evidence. A valid response
does not convert a failed close into a normal exit or a passing measurement.

The retained reader accepts the optional fixed observation only alongside
an original EXIT_TIMEOUT. Unknown phases, extra fields, private diagnostics
and a close observation attached to a successful actor are refused. Original
frame, normal-exit, output-completeness and performance predicates remain.
The P06 widget source, collector overlay and preparation entry are unchanged.

Twenty-nine related Python memory controls pass without failures, errors or
skips. They preserve the original timeout object, cap the one diagnostic
request and exercise invalid responses and retained-record refusal. Existing
Dart cases add two owner/terminal-record controls and check the read-only
RPC and its input refusal. No Dart case runs locally. The new observation
module is added to strict analysis; all 288 previous paths remain, for 289
total. Added Dart lines fit the existing eighty-character limit.

## Verified Source802 results

All thirteen [full Linux stages](https://github.com/edgepillar/syrius/actions/runs/43780235490)
pass. The [Windows producer](https://github.com/edgepillar/syrius/actions/runs/43781717658)
passes 1505 selected Dart cases, 1226 Python cases/eighteen skips, zero selected
analysis findings and the current Release build. Its
[independent reader](https://github.com/edgepillar/syrius/actions/runs/43784362094)
validates both original manifests without running an SDK, wallet or lab.

Current preparation succeeds in 30.562 seconds with complete 97-byte output.
All sixteen measurement commands return, retaining ten page-change and
twelve disclosure frames. The wallet then retains EXIT_TIMEOUT,
FORCED_TERMINATION and OUTPUT_INCOMPLETE. A final observed code zero does not
qualify its exit. All five nodes exit normally; P06 is not reached and no
paired comparison is established. The closure cause remains unestablished.

Original failures and all owned outputs are retained and consumed before
these changes. Fresh full Linux and native qualification are required.
Acceptance remains 76/80 and Source730 Ready matches 2/94. V01/V02/V05/V06
remain open. No closure fix, performance improvement, new visual match,
financial operation or final acceptance is claimed.
