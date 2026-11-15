# Measure the strip's rendered line boxes

[Source779 Linux 43675916184](https://github.com/edgepillar/syrius/actions/runs/43675916184)
passes 1226 Python controls, both application analyses, the strict 284-file
selection, Ready and Lock gates. Its compact gate fails in five existing
Accelerator cases. Each reports the same 0.5-pixel vertical RenderFlex
overflow: the fixed strip permits 46.5 pixels for two paragraphs that need
47 pixels. The complete directory and generated-file check are skipped.
The original failed job and complete 493838-byte log remain retained.

The style arithmetic introduced in Source779 did not include each
paragraph's actual line-box rounding. Source780 measures the label and
value styles with TextPainter, using the current text scaler, direction
and locale. It sums their measured heights and the existing three-pixel
gap. Both temporary painters are disposed, including on failure. The
[pinned Flutter implementation](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/painting/text_painter.dart)
provides the paragraph height after layout.

The 46-pixel text-content minimum, ordinary strip default, 48-pixel actual
animation slots, padding, actions, callbacks and financial admission remain.
The existing strip case now puts its centered-action and enlarged-text
variants into the computed fixed height, matching the Accelerator's layout
contract. Its existing overflow, geometry, ordering, direction and callback
checks remain. No test method, suite registration or count changes.

Source779's managed log task is closed successfully and its registered
scratch is removed. All outputs are consumed before this correction.
There is no retry of that original CI job and no Windows execution at
Source779. Source778 remains the latest qualified native/image source.

Fresh full Linux must pass before another native observation. Expected
native counts remain 1505 Dart and 1226 Python cases, with eighteen existing
Python skips; strict selection remains 284. No local SDK, new image match,
performance result or full acceptance is claimed. Accepted scope and
Source730 Ready pairs stay 76/80 and 2/94. V01/V06 remain in review; V02/V05
remain blocked, including the comparison-page refusal.
