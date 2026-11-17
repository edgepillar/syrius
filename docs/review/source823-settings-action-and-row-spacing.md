# Source823 Settings actions and single-line row spacing

Source823 addresses two differences observed in the original Source822
Windows images. Add address and Add contact use the existing 12-pixel plus
path with the ordinary enabled or disabled control ink. The single-line
Launch at startup row uses four pixels of vertical padding around the
switch's unchanged 32-pixel input area. This removes the ten extra pixels
introduced by combining that input area with the ordinary row padding.
The 38 by 22-pixel visible track stays centered in the intended 40-pixel row.

`SettingRow` accepts an optional inset; all callers keep their existing inset
unless they select one. Wallet applies the compact inset only to an available
single-line preference. Hint-bearing rows and unavailable values retain their
ordinary spacing. Both existing layout variants check the row height, centered
switch, input area and visible track, including scaled right-to-left layout.
No test case is added or removed. Preferences, callbacks, ownership checks,
hit areas, account selection and financial behavior remain unchanged.

## Executed Source822 evidence

Source822 is `a30fce1622e2984b8d7d6815f8f53e1fcfc67c00`, tree
`bbaac955c7479bd93399b284dbed2d90d9756be7`.

- [Full Linux](https://github.com/edgepillar/syrius/actions/runs/44000724991)
  passes all thirteen required stages, including selected strict analysis,
  the complete non-chain test directory and generated-file verification.
- [Windows images](https://github.com/edgepillar/syrius/actions/runs/44003643254)
  passes 1517 selected Dart cases, 1229 Python cases with eighteen expected
  Windows skips and selected analysis with zero findings. It retains 24
  general, fourteen Settings and four viewport original PNGs.
- The [independent reader](https://github.com/edgepillar/syrius/actions/runs/44007212973)
  passes all 123 reader controls and verifies those 42 PNGs against their
  original source, run, attempt and archive bindings without replaying the
  wallet or node work.

The required entry, application and five nodes exit normally. Auxiliary
MSVC telemetry is forcibly stopped; whole-runner lifecycle acceptance stays
open. Atomic-frame and locale-preference restoration are not established.
No new send, seed effect or paired P06 measurement is qualified.

All 38 general and Settings originals have individual manual reviews with
zero accepted complete matches. The address balance/action separation, Apps
plus and outlined Fuse zap are visible. General routes still lack the literal
populated preparations; genuine balances, versions, preferences and available
services are retained instead of copying example facts.

The initial local review control handle was lost before its acknowledgement.
Its exit remains UNKNOWN. The same owned task retains the completed review
and both original archives, then closes with FAILURE for that interruption.
Only its registered disposable image copies are removed. All outputs from
the three named runs are consumed without repeating transport or native CI.

## Remaining acceptance

Source823 needs fresh hosted tests, analysis and native visual comparison.
Counts remain 1517/1519 Dart, 1229 Python, 113/114 suites and 291 strict
paths. Earlier failures, the original P06 motion/shader/frame comparison and
independent final review remain open. Acceptance stays 76/80. The two literal
Ready matches belong only to Source730 and are not inherited by later code.
