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

## Actual Source459 default result

Source `9a758129afdae895ad253b0ae357b33aa919ed52`, tree
`666e717e573292a073dc544a7c307b3c6887c55b`, passes 1,051 source controls with
two existing Linux skips, all thirteen Bash cases and both JavaScript cases in
source-only [41933458571](https://github.com/edgepillar/syrius/actions/runs/41933458571)
and manual [41933716306](https://github.com/edgepillar/syrius/actions/runs/41933716306).
Both runs are successful, terminal and have zero artifacts. The manual runtime
is attempt one, job 126936947331.

The dispatch omits `node_source`. The runtime reports selection `default` and
`node_uses_script_defaults=true`, with the fixed node SHA/tree and reference
recipe. No node URL/revision/recipe overrides are supplied to the script. All
seven source/tree/run/attempt-bound notices and 21 complete, zero-exit, unforced
receipts independently consume; the largest notice is 2,932 bytes.

Actual up observes chain 321 from one to three over 115 seconds, then status
observes three to four over five seconds. Fresh project, original identities,
production, normal retirement and final source/genesis checks pass, with no
observation/close error or unadopted start. Each of the five original containers
has one zero-exit die event and no observed OOM. Empty project/network checks
pass; volumes remain preserved.

This independently qualifies the script and workflow defaults for the observed
hosted Linux windows. It does not borrow the earlier explicit selection's pass,
establish the old stall's sole cause or indefinitely sustained production, or
qualify ARM64, Windows Docker Desktop, wallet import/send, F06, VM disposal or
full visual/performance acceptance. Source460 records the result and exact
English body339 without runtime changes; all older failures keep their facts.
