# WSL file verification predicates

Source435's original package trial remains failed before MSI invocation. Its
exact failed predicate is unexported and its inner cause is NOT_ESTABLISHED.
Source436's separate 32-byte regular-file control accepts with all metadata
equal. That control does not establish the behavior of the signed MSI and does
not justify relaxing a timestamp or identity guard.

Source438 adds fixed refusal codes to the existing `verify_package` decisions.
The type, exact size, single-link rule, six identity fields, stream overflow,
final length and SHA-256 checks keep their original order and acceptance
conditions. Identity refusals can report only six equality booleans from the
already captured snapshots. Numeric file IDs, times and sizes are not exported.
No additional file read, metadata query, retry or platform fallback is added.

`verify_for_installation` calls that verifier exactly once. A refusal is recorded
and the original exception object is rethrown. Unknown exceptions and malformed
or mutated projections remain UNKNOWN; their messages, paths and private
attributes are never formatted. Only a fixed small OS-code allowlist can leave
an original built-in I/O exception. A normal result is returned unchanged with
a separate VERIFIED record. The observation cannot turn a refusal into MSI
admission. Publisher/signature, source, component, process and storage controls
and all package pins remain unchanged.

Twenty-eight local mocked controls pass without native, network, PowerShell or
scratch activity. The six additions cover every original identity field and
phase, separate header/stream/length/digest refusals, unchanged one-call exception
identity, hostile/private error projections, unchanged successful results and
the actual controller's refusal before installer/query work. Every earlier case
remains selected. This is not a complete current 997-case controller run.

The existing identity-only Windows job now exercises the wrapper with two
separate regular 32-byte fixtures. The original payload must produce VERIFIED;
a same-length different payload must produce PACKAGE_DIGEST_REFUSED. Both use
explicit fixture-only size/hash constants and cannot qualify an MSI. No installer
or binary transport is selected. The original seven metadata comparisons remain
in the result, and source must stay unchanged. This native control and hosted
source qualification are pending before any new full-package trial is selected.

The original failed producer is never retried or relabeled. A future source-bound
package trial must retain its own original result and these finite predicates.
The prior first-delivery UI lineage is unchanged; current full Windows/native,
Docker/lab, seeded effects, all 94 visual pairs and motion/final acceptance stay
open. The main ledger remains 72/80. [Exact body333](pr-body-333.md) preserves the
previous handoff and all original failure/UNKNOWN boundaries.

## Source438 original observations

Source `4129dde6cea7366cf9cd4a6525caff343c4e2544`, tree
`961da5a10aee2dc5d9e7f61380cb2a84cdaed9b4`, passes twenty-eight source controls
and helper parsing in registration 41851572834. Identity-only 41852229666
passes native VERIFIED and PACKAGE_DIGEST_REFUSED controls on separate 32-byte
files. The subsequent distinct package run 41852871210 retains its original
failure, now with PACKAGE_OPEN_IDENTITY_REFUSED and only ctime unequal.
Every other original identity comparison is equal. The exact package download
and Microsoft signature pass, but no MSI is invoked. All three runs are terminal
with zero artifacts and independently reconciled source/run/frame bindings.
The original Source435 cause is not reconstructed or changed. The candidate
[Windows time binding](source439-windows-time-binding.md) preserves same-API
ctime stability and adds explicit Windows creation-time binding; its fresh
native and package results remain pending.
