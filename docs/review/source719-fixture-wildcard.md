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

Fresh full Linux and readonly Sentinel/aged-fuse jobs may run concurrently
on separate hosted runners against the same frozen source. Final qualification
requires both jobs and the independent original-archive reader to pass. The
earlier full Linux result remains bound to Source718 rather than projected
onto the new commit. No local SDK or artifact download is needed for this fix.

The [aged-fuse scope](source718-readonly-aged-fuse.md), original seed guards,
publication restrictions, image manifest and acceptance gates are unchanged.
Original progress remains 73/80; this style fix closes no acceptance row.
