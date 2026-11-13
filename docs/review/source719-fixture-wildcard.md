# Keep ignored fixture parameters lint clean

Updated 2026-11-13.

Source718 passes its full Linux workflow. Its original Windows attempt stops
before selected Dart execution, wallet build or lab startup because the new
invalid-profile callback names an ignored parameter with two underscores.
Strict analysis reports one UNNECESSARY_UNDERSCORES info and no other finding.
The failed attempt has zero artifacts and retains its original scope.

Source719 names both ignored positional parameters with Dart wildcards. This
changes one test callback's unused parameter name; application and harness
runtime inputs are unchanged. The existing invalid-profile refusal and
transport prohibition remain the test's assertions.

Its full Linux workflow 43365837667 passes. The original Windows attempt
43366040425 passes strict analysis, 1,480 selected Dart cases and 1,214 Python
cases with eighteen skips. It then fails production revalidation before
wallet input, with zero PNGs and no aged-fuse witness. Reader 43368622856
passes 123 cases and verifies 88 producer files. Five original nodes exit
normally; required application actors need forced cleanup. The producer
failure and its unknown underlying cause remain preserved. See the
[build-before-lab scheduling change](source720-build-before-lab.md).

The [aged-fuse scope](source718-readonly-aged-fuse.md), original seed guards,
publication restrictions, image manifest and acceptance gates are unchanged.
Original progress remains 73/80; this style fix closes no acceptance row.
