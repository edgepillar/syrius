# Opt-in system-kernel query after the verified WSL component

## Source461 preparation (2026-11-04)

The [Source439 component result](source439-windows-time-binding.md#hosted-source439-result)
qualifies the pinned Microsoft WSL installation and version/status queries on a
fresh hosted Windows Arm VM. It starts no Linux kernel. The earlier
Source194 metadata probe already reports the finite Arm platform facts; it is
not repeated. Microsoft's [processor property documentation](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-processor)
describes VMMonitorModeExtensions as an Intel/AMD extension property. Those Arm
flags are not proof of a working or unavailable nested Linux kernel. The WSL
[boot architecture](https://github.com/microsoft/WSL/blob/master/doc/docs/technical-documentation/boot-process.md)
also separates component metadata from creating the WSL2 VM.

Source461 adds one default-off `kernel_probe` input to the existing WSL
installation workflow. With file_identity_only false, the original verified
component installation must succeed before the new step can run. A fresh VM
still downloads exactly the existing 341,086,208-byte WSL 3.0.3.0 Arm64 MSI,
checks its fixed digest/Microsoft signature/file identity and invokes it once.
No user distribution image is requested. The existing installer, PowerShell
helper and package checks remain unchanged; no failed producer is retried.

The separate controller admits only the first manual, explicitly selected,
GitHub-hosted Windows Arm fork run. It uses the fixed installed WSL executable,
rechecks exact package version 3.0.3.0 and successful version/status commands,
then submits exactly `--system --exec /bin/uname -r`, once, with a thirty-second
process limit and 16 KiB output cap. It does not install a user distribution,
change a feature, request a reboot or start Docker, a wallet or a chain node.
The system-distro command's availability and actual kernel result remain
unqualified until the new native trial; no version/metadata result substitutes
for executing that command.

Only a bounded numeric Microsoft WSL2 release, original command outcomes,
captured-output digest and known diagnostic codes leave memory. Private text,
paths, hostnames and unknown error strings are not exported. A nonzero exit,
forced stop, overflow, incomplete transport or ambiguous release cannot qualify
startup. Wrong component metadata prevents the kernel request. Source is checked
before and after; a final source refusal cannot qualify a valid-looking reply.
There is no retry or guessed WSL shutdown. Kernel/VM lifecycle, VM disposal and
OS-wide allocation enforcement are not qualified by the bounded foreground
command or the existing cooperative installer scratch samples.

The kernel result is a separate source/tree/run/attempt-bound notice from the
original component-installation notice. A failed kernel step keeps the preceding
installation outcome and its original exit intact. The kernel step itself
requests no additional download; the workflow's separate MSI transport remains
explicit. Docker Linux mode, x64 wallet compatibility, chain 321 and full P03/P09
acceptance remain unqualified even if the kernel command succeeds.

Twelve new pure cases cover admission, exact release parsing, encoding/privacy,
original nonzero/unknown/forced/incomplete outcomes, fixed command/count/bounds,
component refusal, source drift and absence of native execution on refusal.
All fifty-eight local selected cases pass: the new twelve plus all unchanged
thirty-two installation and fourteen readiness cases. Source CI prepares all
1,063 Python controls, including existing hosted-only Bash/JavaScript fixtures,
and parses the unchanged PowerShell helper. Fresh source qualification and the
small positive/negative Windows file gate must precede the one new package/kernel
trial. No local SDK, PowerShell, WSL, binary/image transport, full Windows wallet,
seed, visual or motion work runs locally or is selected as part of this lane.

The [Source459 Linux defaults](source459-reference-default.md#actual-source459-default-result)
and Source447 focused UI results retain their own pins. No application Dart,
dependency manifest, design reference, lab input or old failure changes. Original
acceptance stays 72/80 with zero accepted whole-image matches; heavy full
Windows/native wallet and visual/performance acceptance remain phase two. The PR
stays Draft and public artifacts remain English and privacy-safe.


## Actual Source461 result

The tested source is `2b084df944b34532b751bf3d123be20015f5c561`, tree
`fc34a2a2280a2948ec0a479362fdc78622620fdf`. All three original runs are terminal,
attempt one, with zero artifacts. Bounded read-only API receipts independently
bind the source, workflow, jobs, steps and finite annotation frames. The original
kernel trial remains failed; the successful installation is a separate result.

| Original run | Observed result |
| --- | --- |
| [41938113604](https://github.com/edgepillar/syrius/actions/runs/41938113604) | Source controls: 1,063 cases, two existing Linux skips, zero failures/errors. All thirteen Bash and two JavaScript fixtures execute. The PowerShell helper parses successfully without execution. |
| [41938484962](https://github.com/edgepillar/syrius/actions/runs/41938484962), job 126952920757 | Native file gate: the original verifier accepts a correct 32-byte regular file and refuses the separate digest-mismatch file. All seven path/handle metadata comparisons remain true before and after; final source identity passes. No package allocation or startup occurs. |
| [41939295324](https://github.com/edgepillar/syrius/actions/runs/41939295324), job 126955667166 | The 32 installation and twelve kernel controls pass. The component installation succeeds; the separate kernel command fails. Both finite reports complete with unchanged source. |

The fresh package trial receives exactly 341,086,208 bytes with HTTP 200 and the
pinned digest. Microsoft signature and final file verification pass. One installer
exits zero normally, without reboot, followed by successful installed version and
status queries reporting WSL 3.0.3.0. This independently qualifies component
installation on this source/run; the later step does not overwrite that outcome.

The separate kernel step repeats successful version/status prerequisites and
submits the fixed `--system --exec /bin/uname -r` command exactly once. The original
command exits `4294967295` after 0.095 seconds with 504 complete bytes, no forced
termination, overflow or captured command-error code. No valid release is
observed; the result is `KERNEL_START_UNQUALIFIED` / `COMMAND_FAILED`. Its captured
output digest is `756a9ae833f91603d69b5ee0e38d855073252c2585b8808c37f801cf43646c15`.
Raw output and unknown error strings remain unexported. No recognized diagnostic
code is projected; the exact inner cause remains `NOT_ESTABLISHED`.

This failed command does not establish that nested virtualization is generally
available or unavailable, nor that the selected system-distro command can work
without another prerequisite. No retry, guessed shutdown, feature change, reboot,
extra distro download, Docker, wallet or node command follows. Kernel/VM lifecycle
and disposal remain unqualified. The separate hosted installer uses cooperative
4 GiB work samples and a declared isolated 2 GiB floor; these are not an OS-wide
allocation quota and do not change local storage policy.

Source462 records these results and exact body340 without runtime changes or
repeated SDK/native/artifact work. The qualified Source459 Linux defaults and
Source447 focused UI remain separately pinned. All earlier failure/unknown
records remain. Original acceptance is still 72/80 rows, with four in review,
four blocked and zero accepted whole-image matches. Heavy full Windows wallet,
F06, seam, visual and performance work remains phase two; the PR stays Draft.
