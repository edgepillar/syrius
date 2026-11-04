# Home dollar baseline

The Home reference places each `.usd` span in the amount's inline formatting
context. Its normal vertical alignment is the shared alphabetic baseline.
The primary `.big` row uses line height 1.1; the secondary `.num` row inherits
the body line height 1.45. These are source observations from
`mockups/redesign/src/10-home.html` and `00-head.html`, separate from measuring
the earlier Source353 native images.

The Home view instead centered the small dollar widget in its amount row's
wrap, and the secondary numeric style used line height 1.1. Source441 retains
the wrap and its narrow-window reflow while giving each dollar widget the
corresponding amount line's baseline and height. The secondary numeric style
now inherits the reference's 1.45 line height. Symbol sizes, measured interior
spaces, twelve-pixel dollar gap, colors and the original hidden-eye placement
remain.

The existing constant-glyph text measurement now also returns line height and
baseline. It does not read a hidden amount, and adds no extra text painter or
numeric formatting path. Both the rendered row and its width planner use that
same measurement. Exact values, prices, total calculation, feed listeners,
privacy state, original animation clocks and action callbacks remain unchanged.

One appended widget case compares actual rendered numeric/dollar baselines
with bundled fonts in both themes, directions and normal/double text sizes.
It also requires the original estimates and Send/Receive controls to remain
reachable at 1024 by 780. Every preceding Home case body remains byte-identical.
The same 96-file selection prepares 1,230 ordinary cases in 48/48-file groups
(597/633), or 1,232 with asset fidelity. The complete hosted controller selection
now expects 1,001 cases with its three existing skips, including the separately
qualified WSL query/installation controls. Process, worker, output and total
bounds are unchanged. No local SDK executes.

Hosted analysis and widget execution are pending. The original Source428 UI
result retains its tested source; it does not qualify these changed Home bytes.
The Source439 WSL installation result remains source-bound and is not replayed.
Full Windows builds, wallet/lab work, image transport and motion/performance
qualification stay deferred. No new native image or whole-image match is
accepted. Main progress remains 72/80, with 50/94 historical literal outputs,
44 missing and zero accepted matches. The PR remains Draft.

[Exact preceding body334](pr-body-334.md) preserves the prior published handoff.
