# Installed WSL component readiness

Source430's finite Arm observation finds enabled Windows features and a WSL
command, but it does not query the installed WSL package. Source432 adds a
separate, manually selected query of `wsl.exe --version` and `wsl.exe --status`.
This resolves an installation prerequisite before allocating Docker or a lab.

The [Microsoft command reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#check-wsl-version)
distinguishes version and status queries from installation and launch commands.
[Docker's Windows requirements](https://docs.docker.com/desktop/setup/install/windows-install/#system-requirements)
currently require WSL 2.1.5 or later. An observed package meeting that version
does not establish a usable kernel, nested virtualization or Docker Linux mode.

`tool/ci/windows_wsl_readiness.py` retains the existing bounded command runner.
Each query has a fifteen-second deadline and a 16 KiB output limit. Original
exit, output-completeness, timeout, overflow and forced-termination facts remain
separate. A nonzero original exit can be a complete negative observation; it
cannot supply a successful version. Incomplete or forced queries stay UNKNOWN.
No query is retried. Source head, tree and clean status are checked before and
after both original queries.

Only numeric versions, fixed reported diagnostic codes and finite command
outcomes leave memory. Raw output, distribution names, paths and exceptions are
never printed or uploaded. English version labels are parsed conservatively;
unknown locales, malformed data and duplicate records stay unknown. A component
version is reported as installed metadata, never as a running Linux kernel.
The child environment omits GitHub credentials and inherited command overrides.

The dedicated `.github/workflows/windows-wsl-readiness.yml` requests only
`contents: read`, uses shallow checkout without persisted credentials and bounds
each job to five minutes. A path-filtered `redesign` push runs the fourteen
mocked controls on Linux and registers the workflow. Manual dispatch selects
the Windows Arm query and repeats those small controls before WSL is invoked.
The query refuses other repositories, events, branches, platforms, runner types
and attempts. The original Arm probe, its workflow and the main qualification
workflow remain unchanged. No SDK, installer, cache or artifact upload is added;
no install, update, feature change or kernel/container/wallet/node startup is
requested. Local PowerShell and SDK execution remain unused.

All fourteen local mocked controls pass, with no native child, network or
scratch allocation. They cover redirected UTF-16 output, numeric version
comparison, private output, original failed/incomplete outcomes, exact admission,
the real controller's fixed query arguments and source-change refusal without
replay. The new Python controls are separate from Source428's original 955-case
result. All original application, Dart test, harness and dependency bytes retain
their qualified 1,229-case UI lineage. Newly added query code and its tests need
their own hosted evidence; the old result does not cover them.

Hosted source registration and the actual WSL observation are pending. P03/P09
and the original acceptance ledger stay open at 72/80. Full Windows/lab, 94-pair
visual, motion/performance and final acceptance remain second-phase work. The
first delivery remains available for Draft code review. [Exact body331](pr-body-331.md)
preserves the previous handoff and original failures and UNKNOWN outcomes.
