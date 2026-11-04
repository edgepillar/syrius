# Windows package time binding

The finite Source438 projection now identifies its original
[manual 41852871210](https://github.com/edgepillar/syrius/actions/runs/41852871210),
attempt one, job 126653568375: PACKAGE_OPEN_IDENTITY_REFUSED. Only the path/handle
ctime comparison is false; device, file ID, size, mtime and link count are equal.
Preconditions, exact input download and Microsoft signature pass, but MSI is
never invoked and final source-after checking remains unreached. The original
Source435 inner predicate/cause is still unexported; this new result does not
relabel it. The exact underlying timestamp-mapping cause is NOT_ESTABLISHED.

Source438's preceding source controls
[41851572834](https://github.com/edgepillar/syrius/actions/runs/41851572834) and
[two-file control 41852229666](https://github.com/edgepillar/syrius/actions/runs/41852229666)
qualify twenty-eight mocked cases, native VERIFIED for the correct 32-byte
fixture and PACKAGE_DIGEST_REFUSED for a separate same-length payload. No MSI
or large download is selected by that fixture job. Independent API reads bind
all three original runs, jobs, attempts, frames and zero artifacts. None is
retried. The package attempt is a distinct source-bound operation after the
fixture gate, not a replay of the Source435 producer.

[Python documents](https://docs.python.org/3.13/library/os.html#os.stat_result)
the Windows deprecation of ctime and the explicit birthtime field for creation.
Source439 uses that creation field for Windows path/handle binding, together
with the original device, file ID, size, mtime and single-link checks. Missing
or noninteger birthtime refuses; there is no ctime fallback on Windows.

Ctime stability remains required within each API: the path is compared with
its original path snapshot, and the final descriptor with its original opened
descriptor. Windows creation time is additionally required to remain stable
through both lifetimes. This avoids equating potentially different cross-API
ctime values while retaining both original ctime lifetime checks. Other
platforms retain their original ctime binding. The same two path snapshots,
two descriptor snapshots, one payload read, exact length and SHA-256 checks
remain. No extra metadata query, file read, retry, clock or platform fallback
is introduced. Signature, source, process/storage admission and MSI arguments
are unchanged.

Thirty-two local mocked controls pass without native, network, PowerShell or
scratch execution. All twenty-eight earlier cases remain, with four new cases
covering stable divergent API ctimes, separate path/handle ctime changes,
creation-time changes at every binding, and missing creation data. Earlier
portable-field refusal and exception/privacy controls remain selected. This is
separate from a complete current 1,001-case controller qualification.

Hosted source and the existing small Windows positive/negative controls must
qualify this revision before any new package trial is selected. Actual component
installation, kernel/Docker, the lab, full native/visual/motion and final
acceptance remain open. The main ledger stays 72/80; previous failures retain
their original source and conclusions.

## Hosted Source439 result

Source439 `5a5e9d0bc3bd926bb06b219ba8d070428af79812`, tree
`3dd21f964906fc771819b5d8d2c6e90d08d3d82b`, qualifies
[source controls 41857154252](https://github.com/edgepillar/syrius/actions/runs/41857154252),
[native file controls 41857791020](https://github.com/edgepillar/syrius/actions/runs/41857791020)
and the distinct
[package installation 41858076161](https://github.com/edgepillar/syrius/actions/runs/41858076161).
All three original runs finish successfully on attempt one, with zero artifacts.
Source controls pass all thirty-two cases and PowerShell source parsing. The
small Windows job, 126670999571, accepts the correct 32-byte file and rejects
the separate same-length negative file with PACKAGE_DIGEST_REFUSED. All seven
metadata comparisons are equal for that fixture; source remains unchanged.

Package job 126672044828 separately passes the thirty-two controls, positive
Arm64/desktop/admin/enabled-feature prerequisites, exact 341,086,208-byte input
digest and Microsoft signature. The corrected final file check returns VERIFIED.
One no-restart MSI invocation exits zero normally with complete zero-byte output,
no forced stop and no reboot required. The installed version/status commands
both exit zero normally, with 442/40 complete bytes. WSL package version is
3.0.3.0; final source checking passes. No original failed producer is retried.

This qualifies the pinned component installation and metadata queries on this
fresh hosted Arm VM. The kernel version remains unknown. No distro, Linux
kernel, container, wallet or chain node is started; no feature change or reboot
is requested. Docker installation/Linux mode, nested virtualization, the written
lab route and full P03/P09 acceptance remain unqualified. The existing isolated
hosted fixture's cooperative resource samples do not impose an OS-wide installer
quota or qualify VM disposal. No local binary transport or SDK execution occurs.

Independent API reconciliation binds the exact source, jobs, attempts, successful
conclusions and terminal runs. All 1,965 original Source428 application, Dart
test, harness, controller, dependency, reference and main-workflow entries stay
unchanged; its 1,229-case UI result is reused only on those bytes. Five added
Python/PowerShell query, installation and test files have separate observations.
The complete current 1,001-case controller suite and current-source full
Windows/native wallet remain unqualified. Source440 changes documentation only.
The first-delivery scope, 72/80 main rows, all earlier FAILURE/HOLD/UNKNOWN and
every original final acceptance criterion remain preserved.
