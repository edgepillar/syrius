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
