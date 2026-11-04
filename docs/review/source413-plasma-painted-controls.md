# Plasma controls retain the displayed visit and read

K01 retains one owned fusion list with row selection and single/batch
cancellation. The active list already freezes exact facts before asking and
revokes an open question when its page leaves. That boundary did not cover a
retained row or batch callback invoked before any question had opened. A later
return could authorize it using a new page visit. A fresh owner read could also
revive a callback for the same fusion hash.

This is a source finding in the active FusedPlasmaCard, not a claim about an
observed native publication. The unused legacy CancelPlasmaBloc is unchanged.

## Correction

Every painted row and batch control captures the original owner, visibility
epoch and read ticket. Its callback checks that snapshot before changing
selection or opening the original confirmation. Row callbacks also recheck the
owner's existing exact-facts, strict-expiry and busy/request-hold admission.
Hidden rows are disabled. Returning to the page or completing a new read cannot
revive an old callback. Pagination preserves the controller's existing ticket
and continues to extend the same displayed read.

The existing question, route ownership, original session capture, sender,
per-hash proof, block template, address, publication arguments and journal are
unchanged. Selection is still local UI state. No callback bypasses the original
question or starts a new transport. Layout, strings, amounts, motion, assets,
dependencies, signing and native code are unchanged.

## Regression coverage and prepared gate

The existing five Plasma list cases retain their bodies. Three added cases use
the real list and original keyed controls:

- An old checkbox refuses both a hidden visit and a return; a fresh real tap
  still selects the original fusion.
- Old row and batch buttons cannot open a question after a hidden visit. A
  fresh batch tap opens the original exact-hash question and No closes it.
- A fresh read revokes all three old controls even when the fusion facts are
  unchanged. A fresh row tap still opens the original exact-hash question.

All three require no cancellation preparation or publication, no held question
after No and no framework exception. Existing strict-expiry dark/light,
26-pixel controls, exact question, stale-route, open-question visit and submitted
row cases remain. Fixtures use in-memory reads and recording transport; no
wallet, key, file, socket or chain is used.

The complete eight-case file joins the previous 88 focused files, preserving
their order and every earlier case. The new 89-file selection prepares 45/44
streams with 553/570 cases, 1,123 ordinary cases. The separate asset-fidelity
variant expects 1,125. The selected analyzer adds the active list and its full
test file. Existing controller cases exercise both new paths at every refused
severity and reject the previous 1,115/1,117 totals. Python registrations remain
955 with three existing hosted skips. One worker, 240 seconds per group,
480 seconds overall and 4 MiB per group are unchanged.

Thirty-seven local mocked/read-only controls pass in disjoint 33/4 batches.
The first wrapper retains its actual exit one after its 33-case child succeeds:
the wrapper expected 37 while selecting 33. The four unexecuted mocked analyzer
refusals pass separately; completed controls are not repeated. This local
accounting refusal is preserved. These controls qualify Python admission,
analysis projection and catalog behavior, not Flutter execution. Fresh selected
analysis and the complete 1,123-case engine gate remain pending.

## Evidence and delivery scope

The base is Source412 `3d535e7257ecab7161e783919a23e6060f2d502b`, tree
`93b01bc03f0f44efb132fb94c4a0688e88589dad`. Its application and test bytes
equal focused-qualified Source411
`7ced2135d937ae1aacf776009ef587fea9601a7f`, tree
`2d6d74b4da0ad84a41363d2bf0171b29baa2f147`, in
[41773894715](https://github.com/edgepillar/syrius/actions/runs/41773894715).
That result retains all 1,115 cases, 955 Python controls/three existing skips,
fourteen assets and zero selected findings. It does not qualify this correction.
The exact [preceding body324](pr-body-324.md) is archived without alteration.

Core interface/basic functionality remains the first-delivery priority. No new
full Windows build, native chain producer, image transport, local SDK or motion
qualification is scheduled. Native Plasma effects, full seeded workflows and
visual/platform/performance acceptance remain open. The original ledger stays
72/80, 50/94 literal outputs, 44 missing and zero accepted whole-image matches.
Earlier failures and UNKNOWNs retain their source and scope. The PR stays Draft;
public content remains English with edgepillar no-reply/UTC attribution.
