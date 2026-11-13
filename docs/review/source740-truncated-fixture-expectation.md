# Truncated wallet-name fixture expectation

Source739's new Lock check assumed that the existing synthetic wallet name
fit its field. The actual widget-test paragraph ellipsizes that name in every
theme/direction variant. Its tooltip is therefore required by the new
overflow-only behavior.

The existing four cases now expect the observed truncation and retained
tooltip. Their separate short `Main` and long-name phases continue to check
tooltip absence/presence and full semantics. The actual filled-container
height, input preservation, focus refusal and submit ownership checks remain.
Application code and test registrations are unchanged.

[Source739 full Linux 43506083035](https://github.com/edgepillar/syrius/actions/runs/43506083035)
passes bounded controllers, patched/application analysis, strict selected
analysis and the Ready gate. The Lock gate reports 34 passes and four
failures, all at the same new truncation expectation. The compact/Token gate,
full directory and generation check are skipped; no full-suite pass is
claimed. The original failed run remains preserved and is not retried.

The completed bounded log range identifies all four original failures.
The earlier CLI output refusal and incomplete capped read retain their actual
outcomes; they are not relabeled as complete log reads. No SDK or native
application is executed locally.

Fresh full Linux is required for this test correction before native capture
of the prepared Source739 presentation. Source738 Lock and paired timing
evidence retains its exact source and scope. Accepted scope remains 76/80,
visual matches 2/94, and V01/V02/V05/V06 remain open. The original Docker/WSL
route stays unqualified; the owner-approved native CI route and Source722's
F06 qualification are unchanged.
