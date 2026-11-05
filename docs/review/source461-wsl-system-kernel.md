# Opt-in system-kernel query after the verified WSL component

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
