# Source824 original P06 film acknowledgement

The P06 harness adapter acknowledged a handled Space event without checking
whether the original startup film received it. The current adapter already
checks that effect. Source824 applies the same original-owner requirement
to P06: the original film must have a skip pending, have finished, or have
started its original initializer. A handled event without that effect
returns the existing fixed `wallet-recipe-startup-key-unconfirmed` label.
The complete Space pair and every preceding focus, control and owner check
remain. No direct widget callback replaces keyboard input.

Three read-only getters expose the original film's pending skip, queued frame
and ticking state. A version-two failure snapshot retains those booleans with
the existing bounded frame counters. It is observed once, within the original
one-second and actor deadlines, after the original Welcome refusal or an
explicitly unconfirmed startup key. It cannot advance the film, repeat input,
extend a wait or turn the failed preparation into a successful measurement.

The independent reader keeps the original unversioned counters readable and
accepts the versioned flags only as a complete, typed, closed record. Missing
or extra fields, unknown versions and nonboolean flags refuse. Private error
text and control payloads are excluded. Existing mocked cases cover all eight
flag combinations, malformed records, exact failure selection and unchanged
probe-before-cleanup ordering.

## Source and controls

The P06 source and tree remain `e06330fd5c630fee82f59efd42140f7190260ff9`
and `197785948b180221aa3521b35fcc4def52620ba9`. The overlay tree becomes
`f23a88649e9e13bb76cf332c4e03240e215db7ec`. Its 14999-byte patch remains
below the original 16384-byte limit, SHA-256
`472a735eae37cd01fd4670456e9cdd387a8c1c8bcfd243b9900d0cbf3f0eb890`.

The previous overlay tree was reconstructed in memory before adding the
effect check and passive getters. Shorter diff context preserves its applied
contents. Empty context-line normalization was separately checked against
all five applied files. The original baseline decoder, assets, clock,
collector, budgets and 16000-microsecond/frame-gap comparisons remain.

The two selected Python modules execute all 25 existing methods with zero
failures, errors or skips. Their complete original output is reconciled with
the unchanged module inventories. A later count assertion expected a broader
45-case selection and refused; that refusal is retained without repeating
the tests. The patch-format refusal is also retained. No local SDK runs.

## Evidence and acceptance

[Source823 full Linux](https://github.com/edgepillar/syrius/actions/runs/44019894758),
at `b8f65f5912cfa1f34d135ed23d68b0d9dae01a59`, passes all thirteen required
stages, including the two Wallet geometry variants, full non-chain test
directory, strict selected analysis and tracked generation. Its original
outputs are consumed with zero artifacts and no retry. Fresh Source824
hosted tests and actual P06 overlay/native execution remain required.

Source821's P06 preparation failure remains unchanged. Its single incomplete
film snapshot does not establish the old key's delivery or the cause of the
stall. Source824 has no native repair or performance result yet. Source822's
38 manually reviewed images retain zero complete matches and their original
source bounds. The interrupted review worker remains UNKNOWN and its owned
task closes with FAILURE after retaining the completed review.

Counts stay 1517/1519 Dart, 1229 Python with eighteen expected Windows skips,
113/114 suites and 291 strict paths. No case, suite, selection, workflow or
financial operation is added. Acceptance stays 76/80; V01/V02/V05/V06 and
the full 94-pair, motion, shader and independent final requirements remain.
The two Ready matches belong to Source730 only.
