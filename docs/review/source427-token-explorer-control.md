# Token explorer control

Source427 draws the holder row's missing explorer control from
`mockups/redesign/src/40-plasma-tokens.html`, screen `tokens`. It uses the
existing original `ext` vector at 12 pixels, dim ink, a 12.5-pixel localized
label and the reference's inline space. The compact action row centers the
link beside Burn and Send and retains wrapping for constrained widths.

The current wallet configures transaction and momentum explorer links, with
no configured token route. Remote token-route support remains unverified; an
incomplete external search does not establish its absence. The
[source brief](../research/token-explorer-link.md) records this boundary.
`Seam.tokenExplorer` preserves the drawn control behind the localized `Not yet`
gate. Pointer, focus and semantic activation are denied. A retained callback
also calls `runUnlessSeamed`; the refusing service throws `SeamNotBuilt` for
direct callers without opening a URL, reading a chain or accessing a wallet.
No global shortcut or palette entry currently opens this link.

Existing Burn/Send admission, owner segments, fixed dialogs, form, confirmation,
publication, receipt and settlement code remain unchanged. The ordinary domain
and submitted-transaction links retain their existing path. No token route or
mainnet substitution is invented, and no reference HTML or PNG is changed.

The four existing both-theme/direction holder cases retain their original
fixtures and functional assertions. Added checks require the actual registered
gate, disabled semantics, original SVG source/size/ink, label size, pointer and
retained-callback refusal, zero publication and working fresh Send/Burn. The
explorer callback is also retained across publisher replacement. The existing
service map adds its throwing operation; the existing enum-wide Go To cases
cover its tap, indirect selection and Enter refusal. The registry test checks
the new row, real screen id and source/research paths.

Two enum-driven Dart cases join the unchanged 96-file selection, preparing
1,229 ordinary cases in complete 48/48-file serial streams (596/633). No test
file is added or removed. The 1,231 asset-fidelity variant remains separate.
Python test registration count remains 955. Selected analysis explicitly adds
the seam enum, refusing services and service tests, retaining every prior path.
All process, output, worker and failure bounds remain unchanged.

Thirty-seven local mocked/read-only controls pass without failures, errors or
skips. Fresh hosted Flutter tests and selected analysis remain pending. No local
SDK is executed. [Exact body329](pr-body-329.md) preserves the preceding qualified
Source425 result and all prior failure/UNKNOWN evidence.

This is core interface work for the existing Draft milestone. Native token
pixels, a functional configured token route, full Windows/lab/platform checks,
all 94 visual pairs, motion/frame-time observations and independent final
acceptance remain open. Heavy phase-two work stays deferred. Original acceptance
remains 72/80, with 50/94 historical literal outputs, 44 missing and zero accepted
whole-image matches. The PR remains Draft with English, privacy-safe text and
edgepillar attribution.
