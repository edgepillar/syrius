# Bounded strict-analysis failure notices

Source767's original hand path was divided between Dart string literals at
an arbitrary byte boundary. Strict analysis reports missing whitespace
between adjacent strings. The path is now divided only at its existing
spaces. Concatenation remains byte-for-byte identical to 00-head.html;
artwork, geometry and callbacks do not change.

The strict runner retains its original analyzer command, selected 280 files,
fatal-infos flag and actual child exit. It streams the original child output
and keeps at most 256 KiB in runner memory for an advisory failure notice.
Overflow still drains the child and preserves its exit, while location
projection is refused. No local file, SDK, download or temporary workspace is
needed by this wrapper.

On a failure, the check annotation contains at most 3,800 bytes of selected
repository-relative locations, numeric positions and known diagnostic codes.
It reuses the existing source-path guard. Raw messages and absolute roots are
excluded; unknown codes become a fixed opaque label. Counts and truncation
remain explicit. An annotation is an observation, not qualification and not
a replacement for the original process result. This makes bounded locations
available for diagnosis without routinely transferring a complete job log.

Six new memory-only Python cases pass for Linux/Windows source projection,
foreign/unselected/traversal/URI refusal, message and unknown-code privacy,
notice bounds, exact original analyzer arguments/exits and overflow drainage.
They launch no SDK or wallet. Existing tests and gates remain; fresh full
hosted Linux is required. The CI workflow bytes are unchanged in this packet.

## Preserved Source767 result

[Full Linux 43648027442](https://github.com/edgepillar/syrius/actions/runs/43648027442)
passes Python policy controls and patched/global analysis. Strict analysis
reports only the one SVG string-spacing info, establishing that Source766's
six previous infos are corrected. Ready, Lock, compact widgets, the complete
non-chain directory and generation remain skipped. Neither the Bell cases
nor the Accelerator geometry/artwork cases execute in that run.

The complete 318,170-byte original job log is retained with an explicit
manifest reference. The owned diagnostic task closes successfully and removes
only its registered scratch. All dispatched outputs are consumed; the failed
CI job is not retried. Source766's original failure and both earlier local
diagnostic failures remain preserved.

Windows/image work stays grouped. Current native/image evidence remains
Source765, as recorded in [the Bell result](source766-bell-client-layout.md).
Accepted scope stays 76/80 and accepted Source730 Ready pairs stay 2/94.
V01/V06 remain in review; V02/V05 remain blocked. No new visual match,
performance pass or final acceptance is established.
