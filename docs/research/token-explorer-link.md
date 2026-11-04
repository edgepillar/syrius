# Token explorer link

The holder row in `mockups/redesign/src/40-plasma-tokens.html`, screen `tokens`,
draws Burn, Send and an explorer link. The link uses the original `ext` symbol
at 12 pixels, dim ink and a 12.5-pixel label. The redesign prompt requires a
drawn control with an absent backing implementation to remain visible behind
the registered `Not yet` gate.

At Source426 `b10455f11762bd7ed909856f4090ff42944aa3e9`, the wallet's
`lib/utils/explorer_links.dart` configures only transaction and momentum links
for chain 1. Those helpers validate 64-character hashes. No token route is
configured there. The token panel's existing links open its validated domain
and, after submission, the original transaction. Neither is a token page.

The remote provider's token-route support remains unverified. An incomplete
external source search does not establish that the provider lacks such a
page. Do not derive a route by substituting a token standard into a transaction
or momentum URL, or redirect an unsupported chain to a mainnet result.

`Seam.tokenExplorer` gates the holder control. `TokenExplorerService` and its
`UnbuiltTokenExplorerService` implementation describe the missing operation;
direct callers receive `SeamNotBuilt(Seam.tokenExplorer)`. The gate preserves
paint while refusing pointer, focus and semantic activation. The retained
button callback also uses `runUnlessSeamed`. No global shortcut or palette
entry currently opens this token link; the enum-wide indirect guards cover it.
The ordinary domain and submitted-transaction links retain their existing path.

Before removing the gate, verify a supported provider and exact route, bind it
to the original chain and token standard, validate the identifier and retain
the original view/owner lifetime across callbacks. Add positive supported-chain
checks and refusal cases for unsupported chains, malformed standards and stale
contexts. No browser, network or wallet dependency belongs in the current
refusing service. Native pixels and whole-image correspondence remain separate
acceptance work.
