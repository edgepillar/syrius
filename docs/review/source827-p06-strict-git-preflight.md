# Source827 P06 strict Git preflight

Source826's compact patch removed trailing context from interior hunks.
Git's ordinary matcher treats a hunk without trailing context as an
end-of-file match. Source826's local syntax and file-projection checks did
not exercise that matcher. Its actual Windows patch application fails.
See the [Git implementation](https://github.com/git/git/blob/v2.47.0/apply.c#L2839-L2847).

The corrected fixture removes leading context instead, retaining trailing
context for every interior hunk. The final hunk ends with a nonempty
original context line to satisfy Git's patch-file whitespace check.
All five applied file contents and the
bae21ad6dfa4a84df7522ff71846091bb07a0b89 overlay tree are unchanged.
The patch is 16002 bytes below the existing 16384-byte cap. Original pointer
admission, cancellation, geometry refusals, film, decoder, clocks, assets,
collector, recipe, CLI and timing criteria remain.

## Real Git gate before SDK allocation

The owned edgepillar/syrius manual redesign lane now checks the fixture
before Set up Flutter, on attempt one. All thirteen original required stages
remain; this adds a fourteenth gate. The upstream pull-request path keeps
its existing stages.

The SDK-free helper uses a fresh hosted temporary directory, an alternate
index and only the five original regular source files. It fetches the exact
original P06 source/tree and the already published failing Source826 patch.
The previous patch must fail strict git apply with complete output and no
forced exit, leaving the original index and files unchanged. This is a
negative regression control; its actual failure is retained.

The corrected patch must then pass git apply --index --whitespace=error-all.
The unchanged collector is added and the complete tree must equal the pinned
overlay. The current source HEAD, index, worktree, patch and collector must
remain unchanged. No zero-context, whitespace-ignore or rejected-hunk
exception is used.

Commands retain bounded exit/completeness records and output hashes. A
10 GiB free-space floor and 256 MiB allocation reservation apply. Only fixed
public diagnostics and source identifiers are emitted. The fixture remains
in its fresh job directory for inspection; no historical or unrelated files
are removed. The helper starts no SDK, wallet or node.

## Executed evidence and limits

All 25 existing selected mocked Python methods pass with zero failures,
errors or skips. Actual hosted Git application and fresh Source827
qualification remain pending. No test registration or selection changes.

Parent [Source826 full Linux](https://github.com/edgepillar/syrius/actions/runs/44039825303)
passes all thirteen original required stages. Its
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/44041901759)
passes 1517 Dart cases, 1229 Python methods with eighteen expected skips,
zero selected findings and the current Release build. The current actor
finishes sixteen commands and records sixteen page-change and eighteen
disclosure frames.

That producer fails with COMMAND_FAILED at patch_p06_agent, before any
P06 runner is built or started. The
[independent SDK-free reader](https://github.com/edgepillar/syrius/actions/runs/44045909211)
binds both original archives and manifests. The current wallet and entry
exit zero with complete output, and all five nodes exit normally. The failed
lab's inputs_unchanged remains false. All three named outputs are consumed
without retry or local artifact download.

No P06 timing window, native preparation repair or performance gain is
established. Acceptance stays 76/80; V01/V02/V05/V06, all 94 current literal
pairs, nineteen motion and four shader rows and independent final review
remain. The two Ready matches belong to Source730 only.
