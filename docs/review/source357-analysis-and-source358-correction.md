# Original throw-type info and the Source358 correction

Source357 [attempt-one run 41598294767](https://github.com/edgepillar/syrius/actions/runs/41598294767)
fails at the strict analysis gate on source
`dd9b97109ae640043dbfb5d6a043438c0426094b`, tree
`2b48462d5a14d04015666926d0b9e344b633adae`.

All 953 Python controls pass with three existing skips, and fourteen asset
observations pass. Analysis exits zero normally with complete 179-byte output,
zero errors, zero warnings and one info: `ONLY_THROW_ERRORS` at line 246,
column 32 in the seed policy test. The strict zero-info gate therefore refuses.
The startup/Dart test step is skipped, no Dart case runs and no artifacts exist.
The original failed run is retained and is not retried.

One new regression loops over a closed collection of synthetic exceptions and
errors, typed as `Object`. Directly throwing that variable triggers the lint.
Source358 narrows it to `Exception` or `Error` before throwing the same original
object. An unexpected fixture type fails the test. Expected identities, every
assertion, all labels and all nine new registrations remain unchanged.

The [pending-deposit adapter and hero palette](source357-deposit-effect-and-hero-order.md)
are byte-identical to Source357. SDK/dependencies, Python controllers/tests,
workflow bytes, recipe commands, numeric policy, eighteen-read bound, shader
clock and every original guard remain. Counts stay 897/899, with complete
36-file groups expecting 441/456 and 953 Python controls with three skips.

Fresh strict analysis and Dart execution are required for Source358. Native105
is not admitted. [Native104](native104-prefix-and-deposit-results.md) retains
its independently inspected three-prefix observation and UNKNOWN Deposit
outcome; its exact inner cause remains NOT_ESTABLISHED. No original consumed
profile or financial operation is replayed, and no new native, full-baseline or
visual-match evidence is claimed by this correction.

The main ledger remains 72/80, with 50/94 available literal outputs, 44 missing
and zero accepted matches. The [exact preceding body292](pr-body-292.md)
retains its submitted pending-state text and links.
