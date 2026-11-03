# Go To symbol and shortcut borders

Updated: 2026-11-03T18:33Z.

Go To used a Material search glyph while the original mockup supplies a stroked
search vector. Its header now reuses the existing shell renderer with that exact
vector, the existing faint foreground and the same 18-pixel token size.

The original `kbd` rule specifies a one-pixel border outside one-pixel vertical
and six-pixel horizontal content padding. The previous `DecoratedBox` painted
the border without adding its dimensions to layout. A shared `AppKeyHint` now
adds those dimensions once. Palette hints and rail tooltip hints retain their
existing typography, colors, radius and left-to-right keyboard notation.

The existing trailing-hint geometry case now checks the reference's seven-pixel
horizontal outer inset, including the border. It retains both themes, both text
directions, normal and doubled text scale, the original tolerance and all other
assertions. No test registration or selection is added. The ordinary focused
selection remains 902 cases in 72 files, with 955 Python controls and three
existing hosted skips. Current-source hosted execution is pending.

Query handling, result selection, keyboard actions, IME handling, callbacks,
identifiers, financial data and seam guards retain their existing expressions.
The mockup, global content-padding token, workflows and dependencies are
unchanged. The Deposit readiness candidate remains unapplied.

The [fast first-delivery scope](fast-first-delivery.md) continues. This small
source correction schedules only the existing nonnative focused gate. New
Windows builds, lab producers, image transport and detailed visual/performance
acceptance stay in phase two. The original 72/80 rows, 50/94 literal outputs,
44 missing outputs and zero accepted whole-image matches remain.
