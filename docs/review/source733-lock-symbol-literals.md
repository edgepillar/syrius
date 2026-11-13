# Lock symbol literal analysis

The key and USB SVG contents now each use one string literal. Their decoded
contents remain byte-identical to Source732 and the original reference HTML.
No lint suppression, reference path, assertion or case registration changes.

## Source732 results

The [full Linux run](https://github.com/edgepillar/syrius/actions/runs/43444391753)
at 446b31972bca24830baec9fb535b82bfbe786caf passes controllers, both analysis
steps, early Ready and Lock gates, the complete non-chain test directory and
tracked generation. The four selected-symbol color failures from Source731
are fixed. Global case and analyzer-info counts are not projected.

The [original Windows Lock run](https://github.com/edgepillar/syrius/actions/runs/43447648690)
passes 1,220 Python cases with eighteen platform skips and restores unchanged
locked dependencies. Strict selected analysis records zero errors, zero
warnings and two MISSING_WHITESPACE_BETWEEN_ADJACENT_STRINGS infos at lines
46 and 49. The Dart analyzer exits zero, but the strict gate correctly refuses
nonzero findings. Its complete 322-byte analysis stream has SHA-256
69cd4ad08a2fb1ca978ddc0b775b6e8a2d030dd2f3772823ce646de2474e16b4.
Those positions correspond to the two split SVG literals in the prepared
source. The finite public annotation classifies their file as `other`; the
file correspondence is established by source inspection.

Selected Dart tests, native build and capture are skipped. There are zero
artifacts, so no independent archive reader applies. The original run remains
failed and is not retried. Fresh hosted execution must qualify this source.

## Four Source730 Staking and Token reviews

All four actual PNGs and their individual references were viewed. None is
accepted as a whole-image match. Their verified archive is 210,292 bytes with
SHA-256 496e286a70a8c5742bf30848a53a8def87ad9ac2c80d3c06d9b814705a006b4d;
manifest SHA-256 is
3b8742cbd08a457e48bb523e5bf01c6ca1675bade6a735ff67e2bab301db5883.
The producer and reader remain bound to Source730, not to these later edits.

| Actual PNG | SHA-256 | Remaining observation |
| --- | --- | --- |
| 13-staking-dark.png | 6f5aa8b12a73c6feba6c5647294df9f92aa531ea9c3bea1ad0bc3fea5af1313d | Collect width, primary-action width, header/table bands and Duration alignment differ. |
| 13-staking-light.png | a255e4d80f2ad9f79c4244409b91108c8ce2d9dac02d3b994a41c094cf8adac3 | The same Staking geometry differences remain. |
| 24-token-mine-dark.png | 8d1c8cc09c8736a312b43f83547ea026e2e2bc9c1ff4bd8f486547397497c613 | Held search, table columns, detail facts, owner marker, tabs and mint-form geometry differ. |
| 24-token-mine-light.png | 8422d9907e4abbc7a4f16fbdfbfd154f0e03102c104b72b8d60fe3a5dd43eba2 | Expanded-card ink is corrected; the same Token layout differences remain. |

The missing receive toast, expanded Light card and upward disclosure corrections
are visible. Genuine fixture identities, balances, dates, ownership and row
counts retain the prompt's data allowance. The approved brand colors and
native font hinting retain their existing allowances. They do not excuse the
remaining layout differences. The managed review closed successfully with
the verified archive retained and registered temporary images removed.

Original acceptance stays 74/80, with 2/94 accepted matches, both Ready pairs
at Source730. P03, P09, V01, V02, V05 and V06 remain open. F06 remains complete
at Source722. Neither this formatting change nor the completed four-pair
review closes a remaining acceptance gate.
