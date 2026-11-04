# Use the qualified reference recipe as the lab default

The [actual Source458 reference result](source458-continued-startup-readiness.md#actual-source458-result)
qualifies chain-321 progress, five normal exits and final source/genesis checks
for the explicit reference selection. The legacy upstream default remains
unqualified. Source459 makes the working recipe the script and workflow default;
the new default needs its own fresh execution.

`lab.sh` now defaults to fixed unmodified upstream
`0e80915fb9569f2fc3f6bd90c2a54e4c10d7bc1b`, tree
`244d362062b03c07e205ef9a2ad7ba1071fe779a`, and the reference compiler recipe.
That source's locked modules and assets were already covered by the explicit
reference trial. No application dependency manifest or Go patch changes.
The reference recipe retains Go 1.24.1, explicit CGO/static flags, module-file
checks and twenty-second stop grace. Its version guard now checks exact GOVERSION
and Linux GOOS, allowing the build's native Linux architecture instead of
intentionally refusing ARM64. Executed native qualification remains Linux/amd64;
ARM64 runtime acceptance remains open. Image tags are mutable and no binary
reproducibility or frozen-image provenance is claimed.

The workflow's new `default` selection maps to that exact SHA/tree and recipe.
The controller removes node URL/revision/recipe overrides from its child
environment, so this selection executes the actual script defaults. The report
binds `node_uses_script_defaults=true`; an inconsistent selection/header refuses.
Explicit `original`, `dev-0e80915` and `dev-0e80915-reference` choices remain
separate, with fixed child inputs and no borrowed qualification. The fresh
default trial will omit the `node_source` input as well, exercising the workflow
default rather than explicitly overriding it.

Existing image tags and volumes remain preserved. A stored upstream tag refuses
under the new reference default; no automatic image/state migration or wipe is
performed. An operator can still select the original source/upstream recipe
explicitly. This source change does not authorize historical cleanup.

One new pure control checks removed default overrides, fixed explicit legacy
inputs and refusal before mutation. Two new hosted-only actual-Bash fixtures
check the default source fetch URL/SHA, reference build/tag and default stop
grace. Git and Docker are inert regular-file fixtures; no daemon, compiler, Go
chain node or wallet runs in the source suite. Existing complete lifecycle cases
now include the default selection alongside all explicit choices.

Thirty local pure cases pass; thirteen Bash and two JavaScript cases remain
unselected locally. Hosted preparation is 1,051 Python cases. Fresh source and
actual-default runtime execution are pending. Startup still requires two advances
within the existing 180-second progress/ninety-second RPC bounds; status remains
thirty seconds/one advance. Protocol, parent/resource, identity and strict
five-zero-exit/no-OOM criteria are unchanged. No full Windows/native wallet,
seed, visual/motion job, local SDK or binary/image transport is selected.
Original acceptance stays 72/80 with zero accepted whole-image matches. The PR
remains Draft; all earlier failures and unknowns retain their own source/run.
