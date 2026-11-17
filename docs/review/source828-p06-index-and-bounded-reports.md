# Source828 P06 index preparation and bounded Git reports

[Source827 full Linux](https://github.com/edgepillar/syrius/actions/runs/44053526564)
fails in the new SDK-free P06 preflight. Checkout and the bounded-controller
stage pass; the other eleven original required stages are skipped. Flutter
setup is skipped and no Windows job starts. There are no artifacts.

The previous-patch command exits one with complete output and no forced
termination. Its 305-byte output is identified by the retained length and
SHA-256: all five original paths report that they do not match the index.
This fails the required patch-refusal diagnostic; it does not qualify the
negative regression or exercise the corrected patch. GitHub also truncates
the single large annotation, leaving the complete report unavailable.
Post-refusal fixture immutability remains UNKNOWN. The original failure,
incomplete annotation and unknown are preserved; all owned outputs are consumed.

## Prepare the isolated index

The helper now uses checkout-index -u for the same five original regular
files in its fresh isolated worktree and alternate index. This refreshes
the checked-out entries' stat information. It verifies the unchanged
original P06 tree before attempting either patch. See
[checkout-index](https://git-scm.com/docs/git-checkout-index) and
[the strict index requirement](https://git-scm.com/docs/git-apply#Documentation/git-apply.txt---index).

The original patch must still fail with the required patch-refusal diagnostic
and leave its original files and index unchanged. The corrected patch must
still pass ordinary git apply --index --whitespace=error-all and produce
bae21ad6dfa4a84df7522ff71846091bb07a0b89 after adding the unchanged collector.

The 16002-byte patch, its 16384-byte cap, all five applied file contents,
collector, pointer path, geometry checks, film, decoder, clocks, assets,
recipe, deadlines and timing criteria are unchanged.

## Preserve complete bounded reports

The complete manifest retains the existing 32768-byte cap. The summary and
each command-ledger part are at most 3500 ASCII bytes. Each part binds the
source head/tree, run/attempt, part count, complete-report digest and
complete-ledger digest. The summary gives the command and part counts.
A reader reconstructs every command in order and verifies both digests.
Oversized records refuse without truncation.

The existing failed command remains a failed command with its actual exit,
completeness and output digest. Expected negative controls receive their
separate marker only after their diagnostic qualifies.

## Executed controls and limits

All 25 existing selected mocked Python methods pass, with zero failures,
errors or skips. Eight environment-rejection controls start no commands,
scratch or artifacts. Nine in-memory report controls pass: empty, retained
failure, complete and 64-command round trips; four size/count refusals; and
tampered-ledger rejection. The largest emitted test annotation is 3444 bytes.
Synthetic reports test transport only.

No test registration or selection changes. All fourteen current Linux
stages, including the thirteen original stages and the Git gate before
Flutter, remain required. Fresh Source828 hosted Git, full Linux and native
execution are pending. Source827's failed preflight is not a passing Linux run.

Acceptance remains 76/80. V01/V02/V05/V06, all 94 current literal pairs,
nineteen motion and four shader rows, P06 comparisons, the comparison page,
independent final review and end-state audit remain open. Source730's two
Ready matches remain bound to that source.
