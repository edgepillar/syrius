# F06 seed states and permitted fixtures

Updated 2026-11-13.

F06's seed-data setup is qualified. The [Source722 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43381114695),
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/43381591719)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43384604930)
pass at `00d57dcdd31c9e18f183b02325303d38fcbf85e0`. The same copied session
confirms all six original seed effects and observes the aged-fuse fixture.
Original and copied required actors and both sets of five nodes close normally.
Earlier failures and unknown outcomes retain their original records.

## Requirement audit

| F06 requirement | Evidence and scope |
| --- | --- |
| Wallet-driven Stake, Fuse, owned Token, reachable Swap state, Project and second funded address | Source722 confirms `stake`, `fuse`, `token`, `deposit`, `project` and `fund-address`, with six distinct original effects, consistent journals, stable owner, index 1 selected and three wallet members. The receipt-set digest is `9f337c9dfd2a62e1418a5df6bb2da53828f4f361293403d5d0618409febf8c1c`. Fund Address includes its exact receive and positive target balance. |
| Initial `dev1` owner and three fuses | The [pinned node genesis](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/docker/devnet/genesis.json) matches the lab README's index-1 owner and three 10,000 QSR fuses. The assets generator is unchanged from the earlier qualified run. This is source verification of the initial data; a separate current RPC enumeration is not claimed. |
| Sentinel fixture | [Source721's producer](https://github.com/edgepillar/syrius/actions/runs/43375613717) and [reader](https://github.com/edgepillar/syrius/actions/runs/43377707140) qualify the Sentinel catalog and both PNGs. Its fixture, agent, route and script files are byte-identical at Source722. The proof remains bound to Source721. |
| Fuse old enough to cancel | Source722 observes two expired rows and disabled cancel controls, the read-only banner, actual route close, cleared cleanup, current ownership and zero fixture publication commands, after all six seeds in that same copied session. |
| Harness-only fixture boundary | The fixture code stays under `harness/app/`. The ordinary `lib` tree has no harness import/export directives; the harness entrypoint imports the real application. This is the source boundary, not an independent binary-link scan. |

The existing one-sided HTLC Deposit supplies the reachable Swap seed. The
missing two-sided coordinator remains the registered seam, as recorded in the
earlier F06 ledger; it is outside this implementation task. Full coordinated
swap execution is not claimed.

## Post-seed presentation evidence

These earlier native captures establish the available state routes at their
own revisions. Source722's current effects do not re-date their pixels.

| State | Source and independent reader |
| --- | --- |
| Populated Staking and owned Token/Mint draft | Source561, [reader 42684811796](https://github.com/edgepillar/syrius/actions/runs/42684811796), four PNGs |
| New Stake draft | Source563, [reader 42689398504](https://github.com/edgepillar/syrius/actions/runs/42689398504), two PNGs |
| Pillar Spawn prerequisites | Source607, [reader 42785959996](https://github.com/edgepillar/syrius/actions/runs/42785959996), two PNGs |
| Completed Pillar registration | Source611, [reader 42804291806](https://github.com/edgepillar/syrius/actions/runs/42804291806), two PNGs |
| Confirmed Project detail | Source613, [reader 42810930398](https://github.com/edgepillar/syrius/actions/runs/42810930398), two PNGs |
| Real Deposit row in Swap history | Source698, [reader 43235264703](https://github.com/edgepillar/syrius/actions/runs/43235264703), two PNGs |

## Qualification limits

Source722 passes strict analysis with zero findings, 1,481 selected Dart cases
and 1,218 Python cases with eighteen skips. The reader's memory-boundary step
and both original archives pass; its two suites register 75 and 10 methods,
with no separately emitted actual case total projected here. The original
one-ZNN UI send, positive quiescence, independent checkpoint, pointer binding
and current source/owner/deadline guards remain part of admission.

Source723 records this audit through documentation-only changes. Runtime
qualification stays pinned to Source722. Original progress becomes 74/80:
P03, P09, V01, V02, V05 and V06 remain open. All 94 archived pairs retain their
initial individual reviews and zero accepted whole-image matches. Current
visual, motion, comparison-page, Windows Docker-route and final acceptance
remain separate work.
