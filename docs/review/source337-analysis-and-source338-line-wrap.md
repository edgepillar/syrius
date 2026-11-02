# Source337 analysis refusal and Source338 line wrap

Updated: 2026-11-02T23:02Z. Parent source
f31f58b600a8ba747ee6d0f74e55a6bd7d63943c, tree
9b9a073f8213282fb77a2cd09c8a433a40b7a8f2.

Original run 41541160881, job 125605370637, finishes failed. All 940 Python
controller cases complete with zero failures/errors and three existing skips.
All fourteen asset observations pass. Strict selected analysis reports zero
errors, zero warnings and one LINES_LONGER_THAN_80_CHARS info at line 816.
Its original output is complete: 157 bytes, SHA-256
2feaa07e8017eeec7a646598ca426f28a5d81462dd83ed2ed2f4eaf02817fea1.

The analyzer process exits zero, while the strict wrapper correctly rejects
the info. The later Dart test step is skipped, so this run executes zero Dart
cases. Every other workflow job is skipped. The original run is not retried
or relabelled as success.

Source338 splits the one 82-character expectLater line in
test/harness/screen_capture_test.dart into 26- and 66-character lines. The
arguments, forwarding assertion, rejection checks and nine finite categories
remain identical. No runtime behavior, capture/frame/input/action guard,
schema, limit, dependency or test registration changes.

Fresh strict analysis and the original 837-case / 940-controller focused gate
are required for the corrected revision. The 29 earlier Python memory controls
remain source-bound to unchanged Python bytes; they are not rerun or described
as Dart execution. Full builds, native capture and image transport remain
outside this focused follow-up.

The first delivery stays pinned to 19c7b2af5e1c13cc0d567e8fe3378682c7b9b750.
The Source336 full Windows result remains historical evidence. Original Home
capture cause remains NOT_ESTABLISHED; Native101/103 remain UNKNOWN and
Native104 unadmitted. The original 72/80 ledger, nineteen preparations,
50 available literal outputs, 44 missing and zero accepted matches remain.
All final visual, motion/shader/frame-time, native seam, environment/lab,
fixture/effect/reopen and independent-review requirements remain open.
