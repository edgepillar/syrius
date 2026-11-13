# Disclosure comment width

The new disclosure-arrow documentation is split within the eighty-character
limit. Executable Dart, tests, catalog commands, dependencies and workflows
remain unchanged from Source714. A source comparison covers this comment-only
revision; full-suite execution remains bound to Source714.

The [Source714 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43339365877)
passes controllers, application/patched analysis, the complete non-chain test
directory and tracked generation at `d9c78871199dd7a8af0e032ab354d15695de6500`.

The separate Windows [paired launch](https://github.com/edgepillar/syrius/actions/runs/43341310937),
[Staking/Token](https://github.com/edgepillar/syrius/actions/runs/43341500127) and
[Ready](https://github.com/edgepillar/syrius/actions/runs/43341721428) attempts
each stop at selected analysis with one LINES_LONGER_THAN_80_CHARS info,
line 511, column 81, and zero errors or warnings. The new disclosure comment
at that location is 81 characters. All 1,214 Python cases pass with eighteen
platform skips. Selected Dart execution and wallet builds are not reached;
all three attempts retain zero artifacts. No native capture or runtime
acceptance follows from those attempts.

The strict analysis requirement remains in place. Fresh selected Windows
analysis, tests and native observations are pending for the wrapped comment.
Original failures and the earlier Ready diagnostics retain their own sources.
Original acceptance remains 73/80, with zero accepted whole-image matches.
