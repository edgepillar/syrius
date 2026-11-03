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
The original focused result below retains its pre-SDK refusal; current-source engine and analysis remain pending.

The [fast first-delivery plan](fast-first-delivery.md) remains. Only one existing
nonnative focused gate is scheduled for this batch. New Windows builds, native
lab producers, image transport and detailed visual/performance acceptance stay
in phase two. Original 72/80 main rows, 50/94 literal outputs, 44 missing outputs
and zero accepted whole-image matches remain. The prepared Deposit input wait
remains unapplied, and previous failures and unknowns retain their source.

## Original focused result

At 2026-11-03T19:09Z, original [41699376744](https://github.com/edgepillar/syrius/actions/runs/41699376744),
attempt one, job 126138324568, fails at Source374 `41b0f7239b3ecf1939f98f9a7001ff70e9c0e3e8`, tree
`174bdbc724b5bb13a36f6bacfa7f00787208921b`. All 955 Python controls pass without failures or errors,
with three existing hosted skips. The asset helper then stops in `node_version`.

The unchanged command is `node --version`, bounded to 15 seconds and 256 output
bytes. Its original observation reports `COMMAND_TIMEOUT`, 16.750 seconds,
forced termination, observed exit one and zero complete output bytes. The
parent records `OUTPUT_REFUSED`; no asset observations are reached. Exact inner
cause remains `NOT_ESTABLISHED`. The asset helper, process wrapper and workflow
are byte-identical to the earlier successful Source372 versions.

SDK setup, dependency restoration, selected analysis and both Dart test streams
are skipped. Zero current-source Dart cases or analyzer findings are measured;
neither is treated as a passing result. All other jobs are skipped and zero
artifacts exist. No native wallet or lab node runs. The producer is not retried,
and timeout, output and failure gates are unchanged.

All source-bound jobs are terminal. The documentation successor changes only
reports and retains these unqualified application/test bytes. The preceding
[Source372 result](source372-goto-symbol-and-keycaps.md#focused-result) remains
the latest successful focused source. New focused engine/analysis evidence is
still required for these transfer changes. Heavy Windows/lab, image transport
and final acceptance stay deferred under the first-delivery plan.
