# Windows file identity diagnostic

[Source435 manual run 41843120048](https://github.com/edgepillar/syrius/actions/runs/41843120048),
attempt one, job 126619629840, retains its original failure. All twenty-two
controls pass. Desktop/Arm64/admin and enabled feature preconditions are positive;
no existing MSI binary, Store package or known pending reboot is detected.
One 341,086,208-byte input downloads completely with the exact selected SHA-256.
The independent Windows signature helper reports a valid Microsoft publisher.
Both fact helpers exit zero normally with complete output and no forced stop.

The final frame is `REFUSED_OR_UNKNOWN` at `signature`, before
`installation_requested` becomes true. No MSI invocation or installed-component
query occurs; final source-after checking is unreached. Independent API reads
reconcile the exact original source, run, job, frame, failed conclusion and zero
artifacts without repeating the download. Source review localizes the refusal
to the final `verify_package` region after signature admission, but the exact
failed predicate and inner cause remain NOT_ESTABLISHED.

Source436 adds a separate `file_identity_only` manual input to the existing
workflow. It selects only a five-minute Arm diagnostic; the MSI job is skipped.
The original controller, PowerShell helper, tests, package pins and guards remain
unchanged. No new SDK, package download, installation, feature change, kernel,
container, wallet or chain node is requested.

The diagnostic creates one small regular file in a new private runner directory,
flushes it, makes it read-only, and compares path and descriptor metadata before
and after reading its fixed public fixture bytes. Only equality/availability
booleans, Python version and source/run pins are emitted. Numeric file IDs,
timestamps, paths, names and exceptions remain private. The fixture is regular;
no FIFO, socket, symlink or other special file is created. No cleanup is claimed.
Its fresh hosted fixture reserves 1 MiB above a declared 2 GiB floor; local
production storage and its 10 GiB floor are unchanged.

The unchanged package verifier is also exercised with explicit fixture-only
size/hash constants. That result describes only this tiny fixture and cannot
admit an MSI or qualify package installation. The original MSI policy is not
changed. [Python documents](https://docs.python.org/3.14/library/os.html#os.stat_result)
platform-dependent timestamp semantics and the Windows deprecation of ctime;
those source facts motivate measurement without establishing the original cause.

Local source extraction/AST checking and the hosted source job must precede one
manual diagnostic. Actual metadata comparison remains pending. No large input
is transported again. P03/P09 and all original acceptance remain open at 72/80;
the original failed producer is never relabeled as successful.

## Source436 hosted result

Source is `c51b01bd727e55b142ef5cd2e2f1368773adb7b9`, tree
`fe3f64c1247fa725709f3d1b116c1cfd185157be`.
[Source registration 41845470979](https://github.com/edgepillar/syrius/actions/runs/41845470979)
passes all twenty-two unchanged controls and PowerShell source parsing.
[Identity-only observation 41845942293](https://github.com/edgepillar/syrius/actions/runs/41845942293),
attempt one, job 126629339303, completes successfully with Python `3.13.17`.
Both other jobs, including the installer, are skipped for that manual event.
Both runs are terminal with zero artifacts.

The 32-byte regular, single-link fixture retains its exact bytes. Every compared
field matches between path and handle, between original/final handle metadata
and between original/final path metadata: device, file ID, size, mtime, ctime,
link count and birthtime. Only equality booleans are emitted. The unchanged
original verifier accepts the fixture. Source remains unchanged.

Independent read-only reconciliation verifies exact source/run/job/attempt and
the complete final frame. No large binary is downloaded, no MSI is invoked and
no kernel/container starts. The generic path/handle mismatch hypothesis is not
reproduced by this control. No timestamp guard is changed. This tiny regular
file does not establish behavior of the signed MSI or identify the
original Source435 failed predicate. Its cause stays NOT_ESTABLISHED.

Source437 changes documentation only. The next diagnostic must preserve the
specific failed verification predicate before selecting another package trial;
it must not weaken an identity/time check based on this passing fixture. The
original failed manual attempt and incomplete source-after observation
remain separate. P03/P09, current full Windows/native, visual, motion/performance
and final acceptance remain open. The full original ledger stays 72/80.
