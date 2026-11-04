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
