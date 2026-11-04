# Pinned WSL component installation

Source432 retains complete original version/status exits 1/50, without an
established inner cause or qualified WSL version. Source434 prepares one new
installation on a fresh, explicitly opted-in GitHub-hosted Windows Arm VM.
The earlier commands and their original producer are not retried.

The input is Microsoft's public `3.0.3` release, ARM64 asset `620248058`,
`wsl.3.0.3.0.arm64.msi`: 341,086,208 bytes, SHA-256
`2937c7ce840bb35ec6e97f052189bdfff27f8c3463bfdd231df9a958212787a3`.
The exact asset size/digest come from the
[official release metadata](https://api.github.com/repos/microsoft/WSL/releases/tags/3.0.3).
The [Microsoft offline-install guide](https://learn.microsoft.com/en-us/windows/wsl/install#offline-install)
identifies the release MSI as the package installation route. No moving latest
URL, Store installer or distribution download is selected.

`tool/ci/windows_wsl_installation.py` admits only attempt-one manual dispatch on
the `edgepillar/syrius` redesign branch in a hosted Windows Arm runner. Its
finite PowerShell helper requires desktop Windows, native Arm64, administrator
rights and both existing VMP/WSL features enabled. A detected MSI binary, Store
package or known CBS/Windows Update pending reboot refuses installation. It
does not query Win32_Product, enable a feature, stop an existing WSL session,
repair an existing installation or modify an owner machine.

One credential-free HTTPS stream has a fixed size/digest, at most three allowed
GitHub release redirects, 64 KiB chunks, fifteen-second blocking reads and a
180-second cooperative download deadline. Truncation, excess bytes and digest
mismatch refuse. The verified file remains in its fresh owned runner directory;
there is no ZIP copy, artifact upload, cache or local package transport.
Windows Authenticode must independently report a valid Microsoft Corporation
publisher. The same regular single-link file is rehashed with stable identity
before execution. Hash equality alone is not treated as publisher proof.

The original MSI runs once with `/qn /norestart REBOOT=ReallySuppress` and a
180-second process bound. The existing owned command implementation retains its
original handle, capped private streams, normal/forced exit and storage samples.
An independently caught timeout/storage/output refusal cannot become success
merely because a late original exit is zero. Microsoft documents
[no-restart installation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/msiexec#restart-options)
and [exit 3010](https://learn.microsoft.com/en-us/windows/win32/msi/error-codes)
separately: that code records reported installer success with reboot required,
without claiming immediately usable components. It requests no reboot and skips
component queries in that state. Other uncertain or failed invocations are not
repeated. No uninstall, repair or automatic cleanup follows a refusal.

Only a normal zero installer exit admits one version/status query of the exact
new MSI binary. Package version must equal `3.0.3.0`, both queries must succeed
normally with complete bounded output, and source head/tree/clean status must
remain unchanged. Even then, the result qualifies installed component metadata,
not a started Linux kernel, nested virtualization, Docker or chain-321.

Allocation is isolated to a new hosted regression VM. Admission reserves 4 GiB
above a declared 2 GiB fixture free-space floor. Existing cooperative samples
bound the owned directory to 4 GiB and check drive free space. Windows Installer
also writes machine-managed installation/cache data outside that directory;
the reservation and free-space samples are not an OS-enforced aggregate quota.
VM disposal is not claimed as verified installer/service shutdown or cleanup.
Local production storage keeps its 10 GiB floor and unchanged policies.

The separate workflow has read-only contents permission, shallow checkout and
no persisted credentials. A path-filtered Linux source job runs twenty-one mocked
controls and parses the PowerShell helper without executing it. Manual dispatch
selects a fresh twelve-minute Windows job, repeats those controls and then runs
the installation controller. A non-cancelling concurrency group serializes this
lane. All child output remains private; only finite JSON facts are emitted.

Twenty-one local controls pass without native, network, PowerShell or scratch work.
They cover exact streaming, redirected-host refusal, signature admission, file
replacement, process uncertainty, replay/context refusal, private-output
protection and real controller sequencing, including no follow-up after 3010.
Hosted source parsing and actual installation remain pending. All original UI,
harness, dependency and existing controller bytes remain unchanged. The new
controls do not establish a fresh complete 990-case controller run or a new
Windows wallet build. P03/P09, full native/visual/motion acceptance and the
original 72/80 ledger remain open. [Exact body332](pr-body-332.md) preserves the
previous Draft handoff and all original failure/UNKNOWN scopes.

## Source435 finite refusal evidence

Source435 preserves schema-checked boolean preflight/signature facts before
requiring their positive values. A refusal can therefore retain its actual
finite negative field without exporting private output. Invalid shapes and
nonboolean fields still refuse before retention. Original helper command exits,
completeness, forced state and byte counts are now separately projected on both
success and refusal. No admission condition is relaxed. The MSI inputs, native
helper, workflow, query arguments, process/storage bounds and existing positive
sequence remain unchanged. No installer has been dispatched for Source434.

The added real-controller case requires a detected Store package to survive as
finite evidence while preventing download/installation and follow-up queries.
All twenty-two local controls pass without native, network, PowerShell or
scratch work. Hosted parsing and one actual Source435 installation remain
pending. The full 991-case current controller suite remains unqualified.

## Original Source435 pre-install refusal

[The actual manual observation](source436-windows-file-identity.md) passes all
twenty-two controls, preflight, exact package download and Microsoft signature.
It then refuses in the final file-verification region before invoking MSI.
The original job remains failed and its exact inner predicate/cause is
NOT_ESTABLISHED. No component installation or final source-after check is
qualified. Source436 prepares a tiny, separate regular-file diagnostic without
repeating the large download or weakening any original package guard.
