# Deposit input readiness preparation

Native108's original copied workflow refused its first Deposit amount input
before publication. Source review shows that the real Start modal temporarily
locks that field while its first account read is pending. The original native
cause remains NOT_ESTABLISHED; this preparation does not replay that workflow.

The authored Deposit recipe now waits for its original amount field to become
ready after the Start marker and immediately before its first type command.
The existing CLI/agent readiness path requires the same unique, enabled and
reachable target used by input. The wait is capped at thirty seconds. No
selector, amount, counterparty, publication or confirmation control changes.

The parser admits exactly one such wait for Deposit, before publication, with
the original marker and first amount type on either side. Missing, duplicated,
relocated, differently targeted or unbounded waits refuse. Other recipes cannot
borrow the flag. Every previous command, lifecycle, source and publication
restriction remains.

Two existing dark/light widget cases now defer the real modal's account reply.
They require original type to refuse while loading, the original CLI wait to
remain pending, then the unchanged first amount field to accept input after
the reply. The second amount field stays empty and backend mutations stay
zero. The fixture has no profile or network transport. Existing assertions
remain. The parser's existing eleven cases add readiness/order/refusal checks.

All previous 84 focused files remain. The parser file joins as file 43,
producing 85 files in complete 43/42-file streams: 1,094 ordinary cases
(539/555), or 1,096 with the separate asset selection. Both parser files join
strict analysis. No test registration or dependency is added. Nineteen local
fully mocked admission/analysis controls pass. Python retains 955 controls and
three existing hosted skips. Original worker, command/output limits and source
refusals remain. The first focused result and its correction are recorded below.

The first-delivery application code remains unchanged. New full Windows builds,
native producers, image transport and detailed visual/performance acceptance
stay deferred. F06 and complete six-effect/lifecycle acceptance remain open.
Original progress stays 72/80 rows, 50/94 literal outputs, 44 missing and zero
accepted whole-image matches. All prior failures and UNKNOWNs retain their
original source and scope.

## Original Source402 focused result

Source402 `43ec4b6bf1d87932ef70259dcd3ea0e6a7212656`, tree
`0a8ba2eab2edc64bf20d851de3286d049960ee73`, retains failed
[41760786455](https://github.com/edgepillar/syrius/actions/runs/41760786455),
attempt one, job 126347733038. Python completes 955 controls without failures
or errors and with three existing skips. Fourteen asset controls pass; selected
analysis completes normally with zero errors, warnings and infos.

Both original test streams complete within their unchanged bounds. The first
43 files pass all 539 cases. The second 42 files pass 553 cases and fail two,
without skips. Both failures identify the existing dark/light Deposit test's
finite command-completion assertion at line 100. The total is 1,092 passes,
two failures, 115 hidden events and 1,209 terminal events. Original command
exits are zero/one, with complete output, no overflow and no forced kill.
All source-bound jobs are terminal with zero artifacts. The aggregate remains
unqualified; the original producer is not retried.

## Source403 explicit ordinal correction

Source review shows two original amount fields share the same key. The original
readiness loop required a unique match even when the caller supplied `--nth 0`,
so it could not select the recipe's first field. This source correspondence
explains the correction; the failed driver's projected record does not contain
a thirty-second agent timeout. Native108's separate cause remains
NOT_ESTABLISHED.

The readiness loop now selects an explicitly supplied nonnegative ordinal from
the same ranked matches used by input. A missing ordinal still requires one
unique match. An invalid or out-of-range ordinal cannot fall back to another
field. Enabled and reachable checks, the deadline, positive-selector and
read-only region restrictions remain. Ordinary presence/gone waits, type,
financial controls and application code are unchanged.

The two existing real-modal cases retain their delayed-reply, original CLI
command, first-field type, untouched second field and zero-mutation assertions.
They also require ambiguous, out-of-range, negative and noninteger readiness
selectors to refuse. Their finite pump bound is unchanged. All 85 files and
1,094 ordinary cases remain selected. Fresh Source403 focused qualification
is pending; full Windows/lab and visual/performance work remains deferred.
