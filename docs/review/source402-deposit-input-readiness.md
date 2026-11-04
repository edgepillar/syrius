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
refusals remain. Fresh focused engine and zero-finding analysis are pending.

The first-delivery application code remains unchanged. New full Windows builds,
native producers, image transport and detailed visual/performance acceptance
stay deferred. F06 and complete six-effect/lifecycle acceptance remain open.
Original progress stays 72/80 rows, 50/94 literal outputs, 44 missing and zero
accepted whole-image matches. All prior failures and UNKNOWNs retain their
original source and scope.
