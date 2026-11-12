# Original V03 seam coverage

Recorded 2026-11-12 against `376083f8055c3c457e65f6fa04aff610839551e8`.
The original V03 requirement is complete: every one of the fifteen registered
seam values has an executed native control-refusal observation, and the
existing seamed Go To route has pointer and keyboard refusal observations.
This uses retained executions; no native experiment, SDK or artifact transfer
is repeated.

## Coverage

| Seam value | Native control witness |
| --- | --- |
| `swapTerms` | Source686, Start swap terms, both themes |
| `zapSend` | Source670, Home Zap and Go To Zap |
| `zapReceive` | Source670, original Activity Message widget in the explicit activity preview, both themes |
| `walletPicker` | Source648, locked picker; Source676, Settings Wallets |
| `passwordRecovery` | Source648, locked recovery link |
| `passwordChangeMigration` | Source676, Settings password control |
| `operatorModes` | Source676, Settings mode control |
| `walletUpdateNotice` | Source676, About; Source686, shared Home notice in both themes |
| `biometricUnlock` | Source676, Settings biometric control |
| `autoLockOnClose` | Source676, Settings close policy |
| `wrongPasswordLimitOff` | Source676, Settings disabled-limit choice |
| `sporks` | Source676, Settings Sporks control |
| `pillarAprEstimate` | Source686, Pillars estimate, both themes |
| `activityAddressScope` | Source670, Home activity scope |
| `tokenExplorer` | Source686, the original holder token row, both themes |

The enum and registry each contain exactly these fifteen values. The shell
registers no direct missing-feature shortcut. Its only seamed palette target
is `zapSend`; the native Source670 trial opens the palette through Ctrl K and
checks pointer, Down and Enter refusal. The other values have no palette or
direct shortcut registration. Routes are not invented merely to test them.
The common gate and enum-wide indirect guards retain the separate widget/unit
coverage exercised by the [full Source693 Linux checks](https://github.com/edgepillar/syrius/actions/runs/43140599549).

## Executions and provenance

All eight original producer/reader runs and their jobs were rechecked as
successful attempt-one executions at their exact source heads.

| Group | Producer | Reader | Source |
| --- | --- | --- | --- |
| Locked controls | [42936260665](https://github.com/edgepillar/syrius/actions/runs/42936260665) | [42938457881](https://github.com/edgepillar/syrius/actions/runs/42938457881) | `673fe4a1946871b779b22a7afb341ebc9416022b` |
| Home, Activity and palette | [43026625653](https://github.com/edgepillar/syrius/actions/runs/43026625653) | [43030520713](https://github.com/edgepillar/syrius/actions/runs/43030520713) | `2b2c4abdadae6a1c5801b62128e9bf67b45c6dce` |
| Settings | [43072345481](https://github.com/edgepillar/syrius/actions/runs/43072345481) | [43077312134](https://github.com/edgepillar/syrius/actions/runs/43077312134) | `5d555665a6438d5a0370cab5146cdfd9aa48199c` |
| Prepared owner and holder surfaces | [43119410349](https://github.com/edgepillar/syrius/actions/runs/43119410349) | [43122503428](https://github.com/edgepillar/syrius/actions/runs/43122503428) | `15fec4c9120f17e3c76ad571000cbbf1663695a9` |

The locked reader retains the two refused values, original manifest binding
and two normal actor exits. The Settings reader retains the complete ordered
eight-control prefix, original manifests and normal required actor/node
closure. The surface reader retains all eight theme/control observations,
the current holder transition and normal original/copied closure.

Source670's five-control list is retained from its original native producer
notice. Its legacy reader independently verifies the original capture context,
manifests and normal required actor/node closure, but does not separately
project that list. This audit preserves that distinction; it does not create a
new independent per-control reader receipt. The activity row is an explicitly
labelled preview over original history. No real Zap receipt, message decryption
or Zap service is qualified.

## Current source correspondence

The 1,213 tracked runtime entries under `lib/`, `patched_packages/`, the three
desktop platform directories, assets, shaders and the two package manifests
match Source686 exactly. All four executions use Flutter 3.47.7.

Relative to Source648, Source670 and Source676, the sole runtime difference is
`token_inline_actions.dart`. Its holder observation additions are covered by
the later Source686 native holder/explorer trial. All other runtime blobs are
identical. The original lock-card and shared seam-gate SHA-256 bindings also
match current files. These checks establish component correspondence; they do
not relabel the older executions as a new whole-application native run.

## Boundaries

The later eleven-control Home batch remains incomplete. Its failed light Swap,
frame-deadline and theme-selection attempts retain their exact source and
outcome; the causes remain unknown. The successful surface observations supply
the overlapping original controls without changing those failures. V03 does
not require those controls to be repeated in one later batch.

This closes the original fifteen-value refusal requirement only. It grants no
visual match, running motion/frame-time acceptance, Windows setup, seed-state
acceptance, live financial capability or release qualification. Progress is
73/80 original rows, four in review and three blocked; P03, P09, F06, V01, V02,
V05 and V06 remain open.
