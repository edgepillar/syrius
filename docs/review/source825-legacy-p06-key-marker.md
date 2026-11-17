# Source825 legacy P06 startup-key marker

The paired entry script is copied into the P06 build repository and runs
there. Its relative imports therefore use P06's original `WalletRecipe` and
failure encoder. An unconfirmed key has exactly three diagnostic fields:
`action`, `control` and `reason`. That encoder has no `startup` field.

Source824's new selector required the newer client's additional
`startup: key-sent` field, so it missed this valid legacy marker. Source825
accepts the exact three-field P06 form as well as the existing exact
four-field form. Both require the original key, the fixed unconfirmed-effect
reason and the failed import-preparation scope. The original Welcome refusal
continues to select the same passive observation.

Existing archive and mocked-probe cases now exercise both forms, including all
eight film-flag combinations. Each retains the original failed outcome,
refuses unrelated or contradictory labels, and leaves the single probe and
cleanup ordering intact. All 25 selected Python methods pass against the
exact proposed files, which are then applied unchanged. All original assertions
and test registrations remain.

The P06 overlay is unchanged from Source824: 14999 bytes under the existing
16384-byte cap, SHA-256
`472a735eae37cd01fd4670456e9cdd387a8c1c8bcfd243b9900d0cbf3f0eb890`,
tree `f23a88649e9e13bb76cf332c4e03240e215db7ec`. The original source, decoder,
clock, assets, owner checks, input actions, collector and timing criteria
remain. This change selects an existing failure record; it neither sends
another key nor advances preparation.

## Executed evidence and remaining work

[Source824 full Linux](https://github.com/edgepillar/syrius/actions/runs/44024629430),
at `b0bda55275c8345e40d8db48d8e561b6ecbaa2a2`, passes all thirteen required
stages, including the complete non-chain directory, strict selected analysis,
bounded controllers and tracked generation. Its zero-artifact outputs are
consumed. The legacy marker mismatch was established from the original P06
source before any Source824 Windows job was started.

Fresh Source825 hosted and native execution remains required. The original
P06 preparation failures and their unestablished cause remain; no native
repair or performance improvement is claimed. Counts stay 1517/1519 Dart,
1229 Python with eighteen expected Windows skips, 113/114 suites and 291
strict paths. Acceptance stays 76/80, with V01/V02/V05/V06 open. The full
94-pair, motion, shader and independent final requirements remain, and the
two Ready matches belong to Source730 only.
