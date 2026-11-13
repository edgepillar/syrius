# Token disclosure and paired launch observation

The Token ledger now gives its open row and detail the reference's card2
surface. Its disclosure arrow turns from down to up in either text direction.
Other RowDetail callers retain their existing surface and arrow behavior.
The detail inset includes the table cell's leading padding, and the Mint
fields use the reference's 1:1.6 width ratio. The original exact fields,
current-owner checks, validation and publication path remain in use.

The harness theme control now observes the original notifier, stored preference
and rendered brightness for at most five existing settle passes. It writes and
changes the theme once, retaining every original success predicate. The existing
positive case delays rendering until the third observation and requires exactly
one preference write; failed-write and never-rendered refusals remain in place.
This addresses a possible observation race without establishing the cause of
the Source712 native failure.

The Staking and Token catalog recipes also wait up to ten seconds for the
original EventToast to disappear. The existing type selector and gone
predicate perform that read. No toast is dismissed or suppressed, and the
ordinary notification clock and event history are unchanged.

## Reviewed Source711 captures

Producer [43321761577](https://github.com/edgepillar/syrius/actions/runs/43321761577)
and independent reader
[43325404188](https://github.com/edgepillar/syrius/actions/runs/43325404188)
bind the four actual files at
`d5b1cf54ebd6c459f08340e3411613ad981a5412`. Each actual and tracked
reference image has now been viewed individually.

| Pair | Retained findings |
|---|---|
| 13-staking-dark.png | One original lab stake and zero rewards differ from the reference fixture. Table bands, type and unlock alignment differ; a genuine receive toast covers the header. |
| 13-staking-light.png | The same populated lab state has no toast overlay. Strip spacing and table bands, type and alignment still differ. |
| 24-token-mine-dark.png | One original lab token differs from the three-token reference. Filter bands, columns, metadata, tabs and form placement differ; the open arrow points down. |
| 24-token-mine-light.png | The same catalog differences remain, with a gray expanded surface where the reference uses white. |

All four verdicts remain mismatch. Source712's band changes and this change
require later captures. Original wallet and chain facts are retained; these
earlier images do not qualify a newer revision.

## Paired launch window

The original Source698 comparison stopped with STARTUP_DEADLINE while its
post-deadline P06 observation showed 43 of 56 original film frames. That fact
suggests the comparison may stop before the film finishes; it does not
establish the cause of its slow progress.

Only the packed paired-launch mode now permits a 120-second collection
window, 90 seconds for the original enabled lock field, a 100-second frame
reply cutoff and a 120-second original actor bound. The ordinary JSON window
stays at sixty seconds. Individual frame timings keep their sixty-second
validation cap, and the packed frame count remains 4,096. Ordering, delivery,
lossless encoding and the 16 ms comparison are unchanged.

The existing packed tests exercise all retained rows across sixty seconds,
the exact longer bound, invalid offsets, excessive individual timings,
corrupt payloads and unchanged ordinary refusals. Nineteen in-memory Python
cases pass; both extended regression witnesses fail with the old catalog
code. No test method is added. The P06 instrumentation patch is unchanged;
both the original overlay and the new collector overlay are independently
recomputed from the original source in memory, without writing Git objects
or creating another worktree.

## Qualification

The Source712
[full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43329663673)
passes controller tests, application and patched-package analysis, the full
non-chain test directory and tracked generation at
`5fb9dc6af827dff19e4185b6ab3389d51de38b3e`.

The Source712
[Ready producer](https://github.com/edgepillar/syrius/actions/runs/43331682716)
passes 1,480 selected Dart cases, 1,214 Python cases with eighteen skips and
selected analysis with zero findings, then ends with ENTRY_FAILED. Its finite
record identifies wallet-ready, light, themeSelection and an unknown reply
category. The
[independent reader](https://github.com/edgepillar/syrius/actions/runs/43334770411)
passes 123 actual cases, verifies 81 producer files and both original archives,
and preserves zero verified PNGs and required-actor forced cleanup. All five
original nodes exit zero normally. The underlying cause and complete lab
closure remain unqualified. This result is separate from Source711's original
ENTRY_REFUSED capture-stage failure.

The Token, theme observation and longer paired window changes need hosted qualification
on their own revision. No current capture match, successful timing
comparison or complete F06 acceptance is inferred from these preparations.
Earlier failed attempts retain their original outcomes.

GitHub still describes nested virtualization as unsupported in its
[hosted-runner documentation](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners).
Docker Desktop's
[Windows requirements](https://docs.docker.com/desktop/setup/install/windows-install/)
exclude Windows Server. These platform limits do not diagnose the earlier
ARM kernel failure or qualify the written Windows Docker route.

Original acceptance remains 73/80. P03, P09, F06, V01, V02, V05 and V06 remain
open, with zero accepted whole-image matches.
