# Home control symbols

Updated: 2026-11-03T18:12Z.

The closed Source353 Home review retained header and action glyph differences.
Home used Material glyphs where `mockups/redesign/src/00-head.html`
defines stroked vectors. The shell already renders the original paths with
the reference view box, 1.8 stroke, round caps and joins.

Home now reuses that renderer for copy, the address dropdown, Send, Receive
and Zap. Copy/up/down/zap reuse existing entries; the dropdown adds the exact
original down-chevron path. All five path strings equal the original source.
The private Home adapter resolves foreground color inside its button, retaining
primary and secondary button color ownership. Existing token dimensions and
the original animated eye remain.

Control keys, labels, tooltips, address selection, clipboard callback, transfer
navigation and Zap's seam keep their existing expressions. Financial amounts,
prices, SDK calls, persistence, workflows and dependencies are unchanged.
The deferred Deposit readiness candidate remains unapplied.

No test registration or selection changes. Existing Home and harness
rail-navigation controls remain in the same 72-file focused selection:
902 ordinary cases or 904 with asset fidelity, plus 955 Python controls with
three existing hosted skips. The [focused results](source370-focused-results.md)
now qualify both original streams and selected analysis. The separate
`test/shell/rail_test.dart` suite was not selected in this run. No new local SDK
or native process is used.

The [fast first delivery](fast-first-delivery.md) remains available at its
qualified source. Source368's 4,900-pass nonchain Windows suite and normal
Debug/Release builds stay bound to that earlier source. This small source
follow-up does not add a native image or accepted match. New expensive
platform/lab jobs and image transport remain deferred. The original 72/80,
50/94 available, 44 missing and zero accepted matches remain.
