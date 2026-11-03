# Shared transfer control symbols

Updated: 2026-11-03T18:57Z.

The original Transfer mockup uses stroked vectors for Send, Copy address, QR,
Save and the address selectors. These controls still used Material glyphs.
They now reuse the existing original-symbol renderer with the exact `up`,
`copy`, `qr`, `dl` and `chev` paths from `mockups/redesign/src/00-head.html`.
Only QR adds a map entry; the other four paths already exist unchanged.

The previous Home-only adapter becomes the shared `ShellSymbol`. It resolves
the foreground and an omitted size inside the control's icon theme. Home keeps
its explicit sizes and colors, while Send keeps its inherited size. Receive
keeps its existing normal and compact dimensions. The QR save action keeps its
existing export expression. Share image retains its actual share operation and
label. No clipboard, amount, request encoding, address selection, input guard,
busy state, financial callback or persistence policy changes.

The existing Receive geometry and QR foreground assertions now locate the
symbol through the original action keys. Their exact sizes, theme assertions,
normal/compact scenarios and all clipboard/QR/export tests remain. No test
registration or selected file changes. Home, Transfer, Receive, sender-menu and
actual sender-header controls remain in the unchanged 72-file, 902-case focused
selection. Python remains 955 controls with three existing hosted skips.
Current-source focused execution is pending.

The [fast first-delivery plan](fast-first-delivery.md) remains. Only one existing
nonnative focused gate is scheduled for this batch. New Windows builds, native
lab producers, image transport and detailed visual/performance acceptance stay
in phase two. Original 72/80 main rows, 50/94 literal outputs, 44 missing outputs
and zero accepted whole-image matches remain. The prepared Deposit input wait
remains unapplied, and previous failures and unknowns retain their source.
