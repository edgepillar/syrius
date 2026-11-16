# Retain typed diagnostic transport failures

[Source810 full Linux](https://github.com/edgepillar/syrius/actions/runs/43837385438)
passes all thirteen required stages. Its
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/43839946333)
passes 1508 selected Dart cases, 1227 Python cases with eighteen skips,
zero selected analysis findings and the current Release build.
The [independent reader](https://github.com/edgepillar/syrius/actions/runs/43843545439)
verifies both original finite manifests without starting runtime.

All sixteen original current measurement commands return. The preparation
entry exits zero after 35.5 seconds with complete 97-byte output. Six
page-change and twelve disclosure frames are retained. The wallet acknowledges
close, but its original process wait reports EXIT_TIMEOUT. The final retained
exit is zero with complete output and no forced kill; that does not qualify
the original normal-exit check. The shutdown observation is unavailable with
INTERNAL_ERROR. All five nodes exit normally. P06 measurement is not reached,
and its Source810 startup preparation remains unqualified. All owned outputs
are consumed before this change.

## Shared transport errors

The diagnostic handlers catch StartupProbe's specialized Failure. The
inherited request exchange can instead raise the shared SmokeFailure for
transport, response and deadline failures, or propagate ConnectionRefusedError.
Those paths previously reach the generic INTERNAL_ERROR branch, losing their
existing fixed category.

Both shutdown and original absent-navigation diagnostics now retain the shared
failure's closed-set label. A refused connection maps to HTTP_FAILED. Unknown
exceptions retain INTERNAL_ERROR, and exception text or private data is never
projected. The Source810 observation keeps its original meaning; its actual
underlying transport error is not reconstructed from that label.

The existing regression case now drives the real inherited request/exchange
path with memory-only transports. It covers timeout, refused connection,
shared failure, malformed response and an expired original deadline for both
diagnostics. It checks the one-second request cap, no transport after expiry,
no additional process wait or kill, fixed labels and preservation of the same
original EXIT_TIMEOUT exception. The selected case fails against the original
implementation and passes after the change. All 43 related Python controls
pass with zero failures, errors or skips; no test method is added.

Original diagnostic triggers, single-request limits, command payloads,
process wait/cleanup, 10-second exit admission and performance predicates remain.
Current Dart, application close code, baseline overlay, frame collector,
preparation entry, workflows and 1508/1227 selections remain unchanged. All
112 suites and 289 strict paths remain. No local SDK runs or artifact archives
are downloaded. Fresh hosted qualification is required.

The closure cause remains unestablished. This is a diagnostic classification
fix, with no native closure, P06 preparation, paired performance, financial
or visual acceptance claim. Scope stays 76/80; Source730 Ready matches stay
2/94. V01/V02/V05/V06 remain open.
