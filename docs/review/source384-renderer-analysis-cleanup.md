# Shared renderer analysis cleanup

Original Source383 run 41720925174, attempt one, job 126213164441, remains
failed at the strict analyzer gate. All 955 Python controls complete without
failures/errors and with three existing hosted skips; fourteen asset
observations succeed. The analyzer command exits normally with zero errors,
zero warnings and seven infos. The controller correctly refuses those infos,
and all Dart tests are skipped. The original run is terminal with zero
artifacts. It is not retried or treated as engine qualification.

The retained locations identify five adjacent-string whitespace infos at
25/53/56/57/58 and two initializing-formal infos at 104/105, all column seven.
The producer labels their source as `other`; raw source paths are not retained.
Those locations correspond to the newly selected shared renderer. That source
correspondence is an inference, rather than a recovered original pathname.
The complete negative observation remains bound to Source383
`139f83e16506d3a7c34257796fdb28486fbaf15d` and tree
`1918b8b33553974e6505cf8a6dfa53fcc9a01d46`.

Source384 splits the ext and QR literals at existing spaces and joins the
short search literal. All 28 symbol contents remain byte-identical; no SVG
whitespace or geometry changes. The constructor uses private initializing
formals. Its caller names remain `size` and `color`, with identical nullable
defaults, field values and key forwarding. This language feature is supported
by the existing `>=3.12.0` constraint; no dependency or SDK declaration changes.
See [Dart private named parameters](https://dart.dev/language/constructors#private-named-parameters).

All other renderer source, the Activity row, every test, selection, controller,
workflow, dependency and financial/owner/privacy guard remain unchanged.
The 987/989 case totals, 40/39 ordinary files, 486/501 expected group passes,
955 Python controls/three existing skips and every command/output/deadline
bound remain. No finding is suppressed. Fresh hosted analysis and all original
widget cases remain required; the original seven-info refusal stays failed.

The [fast first-delivery scope](fast-first-delivery.md) remains. New full
Windows builds, native producers, image transport and detailed visual/motion/
performance acceptance stay in phase two. Original 72/80 rows, 50/94 literal
outputs, 44 missing and zero accepted whole-image matches remain. Earlier
FAILURE/HOLD/UNKNOWN evidence and the unapplied Deposit candidate retain their
scope. No local SDK execution or financial operation is added.
