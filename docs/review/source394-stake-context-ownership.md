# Bind Stake controls and results to their original context

The Stake form read the global selected address when a retained submit
callback ran. Its Max callback also had no imperative busy check. Address
changes before the next frame, hidden retained forms and overlapping input
could therefore act on a form whose displayed ownership was no longer current.
The form also consumed general sender status instead of its own request result.

The populated form now owns a painted address and wallet-context generation.
Generation changes create a fresh form; ordinary balance refreshes and closing
and reopening a kept-alive disclosure preserve the draft in the same context.
Max, duration and submit recheck mounting, visibility, generation and busy
state. A template uses the form's original address and exact existing chain
duration/quantity expressions.

A new contract admission method requires a request identity, contract origin
and explicit start/publication guards. It shares the existing reservation,
overlap, close, completion and transport machinery. Stake captures its address,
generation, client and wallet identity before admission. Start is checked after
loading observers; the existing transport receives the original publication
guard. Legacy admission and transport implementations remain unchanged.

Stake observes its original handle. Foreign display states cannot clear its
draft or report success. An accepted response keeps its captured read-only
observer even after the form leaves. UI completion and refresh require the
original current context; a replacement draft is not cleared. Refused admission
releases its own display without discarding the draft. No retry is added.

Five new widget cases and the strengthened duplicate-submit case cover retained
controls, address round trips, hidden forms, view removal, late accepted results
and refusal. Six new real-sender cases cover guarded contract admission,
ownership revocation, reentrant loading, exact result/guard retention, enqueue
errors, reservations and close. All five original Stake cases and all 21
original sender-admission cases remain. The focused lane adds the complete
27-case sender file and five Stake cases: 84 files in 42/42-file streams,
requiring 1,083 ordinary passes (528/555), or 1,085 with the separate asset
selection. Both libraries and tests join strict analysis. Nineteen local mocked
admission/analysis controls pass; hosted execution and strict analysis remain
pending. Python retains 955 controls and three existing hosted skips. Original
worker, deadline, output and process-completion bounds remain.

The [fast first-delivery scope](fast-first-delivery.md) continues. New full
Windows builds, native chain producers, image transport and complete visual,
platform and performance acceptance remain phase two. The original 72/80 rows,
50/94 literal outputs, 44 missing and zero accepted whole-image matches remain.
Earlier success, failure and UNKNOWN observations keep their exact source and
scope. The Deposit candidate remains unapplied. No local SDK execution or
native financial operation replay accompanies this change.
