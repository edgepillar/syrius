# Fixed preparation diagnostics for paired frame profiles

The original Source788 interactive job stops before P06 frame windows. Its
preparation process exits with code 1 and complete output, but the entry marker
discards the recipe's existing filtered failure labels. This leaves the actual
preparation cause unestablished.

The paired entry now records a fixed preparation phase on failure. A typed recipe
refusal may also retain its existing allowlisted action, control, reason and
optional startup labels. Raw exception text, recipe exception codes, requests,
credentials, addresses and private paths are excluded. The successful marker is
unchanged.

The parent accepts these labels only from a complete, bounded, normally observed
code-1 process result with an exact marker. It rejects duplicate fields, extra
fields, unknown labels and noncanonical output. The independent archive reader
rechecks the fixed labels against the failed preparation stage, original process
result and marker size. A failed preparation still refuses before measurement;
it cannot produce a successful acquisition or performance comparison.

No original recipe, renderer, frame action, wait, clock, command limit,
performance threshold, workflow, SDK pin or test selection changes. The entry
digest follows the diagnostic change. Both the current and original P06 recipes
already expose the typed refusal and public-label filter used here.

## Verification

All ten existing interactive-manifest Python controls pass locally without
errors, failures or skips. Extended assertions cover safe failed markers,
private and inconsistent metadata, actual process failure predicates and the
unchanged refusal before measurement. Existing Dart assertions also cover the
typed label projection; current hosted execution remains required. No local SDK
executes, and no native artifact is transferred locally.

[Source789 full Linux 43713429377](https://github.com/edgepillar/syrius/actions/runs/43713429377)
passes all thirteen required steps, including analysis, the complete non-chain
directory and generation.
[Source789 retained reader 43713626210](https://github.com/edgepillar/syrius/actions/runs/43713626210)
revalidates the original Source788 manifests. It locates P06 at prepare_profile:
exit code 1, complete 115-byte output, no overflow and no forced termination.
The byte count does not establish the inner error. Both applications and five
lab nodes exit normally; only the current preparation entry succeeds.

All prior owned outputs are consumed and registered local storage is closed.
Fresh current-source full Linux and a new paired native measurement are required
before relying on the new labels. The original Source645, Source744 and
Source788 failures remain preserved; no retry, root-cause fix, speedup or new
visual match is claimed.

## Acceptance boundary

Accepted scope remains 76/80, with 2/94 accepted Ready pairs at Source730.
V01/V06 remain in review and V02/V05 remain blocked. Complete visual, motion,
comparison-page and independent final acceptance stay open. The original
Docker/WSL route remains unqualified. F06 retains its Source722 qualification;
this change qualifies no new financial send or seed flow.
