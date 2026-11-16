# Target the original startup keyboard receiver

The startup recipe selects the original `launch_skip_hint`, but previously
applied pending focus changes without focusing that hint's keyboard receiver.
An unrelated primary focus can consume Space before the original film sees it.
The current driver already refuses an unconfirmed skip; the original P06
widget has no matching public skip-request getter.

Both adapters now find the selected hint's nearest FocusNode without adding
an inherited dependency. They require a focusable receiver with its original
key callback, request focus, apply the pending change and recheck the original
owner/control admission. Primary focus must belong to that receiver before
the existing complete Space down/up pair is dispatched. The current driver's
original skip-effect confirmation remains.

This improves input targeting. It does not establish that misplaced focus
caused the preceding P06 preparation failure. No widget callback or film
controller is invoked directly, and no extra key pair or initialization
shortcut is added.

## Controls and source boundary

The existing startup confirmation case first gives primary focus to an
unrelated handler that consumes keys. Its node is attached as a root sibling,
so events cannot bubble through the original startup receiver. The same
authenticated recipe must perform the original skip without sending keys to
that sibling. Every earlier owner, preference, chain and decoder assertion
remains. This extended Flutter assertion requires hosted execution.

Forty-five related mocked Python controls pass with zero failures, errors or
skips. No local SDK executes. Selection remains 1517/1519 Dart cases,
1229 Python cases, eighteen Windows Python skips, 113/114 suites and 291
strict analysis paths; no test method or selected path is added or removed.

The original P06 source/tree remain `e06330fd5c630fee82f59efd42140f7190260ff9`
and `197785948b180221aa3521b35fcc4def52620ba9`. Only the baseline adapter's
focus targeting changes. Its overlay tree is
`24db15e64eb769b2be93d7c0561a0c7cda875d59`; the patch is 15400 bytes under
the original 16384-byte limit, SHA-256
`f60fd17be9894f950a60d3340bef6b32c1243de4f4b62baf4f33bd1a386e57a8`.
The CLI, collector, widgets, film/decoder, assets, dependencies, commands,
waits, exit budgets and original performance predicates remain unchanged.

The pinned SDK supplies the ancestor lookup and explicit focus attachment
contracts: [Focus.maybeOf](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/widgets/focus_scope.dart)
and [FocusNode / FocusAttachment](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/widgets/focus_manager.dart).

## Preceding executed Source817 result

[Full Linux](https://github.com/edgepillar/syrius/actions/runs/43931513271)
passes all thirteen required stages. The
[original Windows producer](https://github.com/edgepillar/syrius/actions/runs/43934475881)
and [independent retained reader](https://github.com/edgepillar/syrius/actions/runs/43939496209)
verify 1517 selected Dart cases, 1229 Python cases/eighteen skips, zero
selected analysis findings and Release. The toast paint-retention assertions
pass in both hosted lanes.

The current wallet completes all sixteen measurement commands, retaining
eleven page-change and thirteen disclosure frames. Both wallets and five
nodes exit normally. The P06 entry exits with its preparation failure after
35.375 seconds: `importWallet` cannot observe `welcome_import` while the
original startup is still before initialization. Its finite snapshot reports
56 film frames, zero-based last presented index 2, and `done=false`.

That single snapshot establishes an incomplete film at the recorded instant.
It does not establish progression, delivery of the original skip input,
decoding failure or a root cause. P06 never reaches measurement; there is no
same-fixture timing comparison or native performance improvement from that
run. All original outputs are consumed, with no retry or local download.

Fresh full Linux and native execution are required for Source818. Earlier
failures remain. Accepted rows stay 76/80; the two literal Ready matches
belong only to Source730, giving 2/94. V01/V02/V05/V06 remain open.

## Executed Source818 failure

The [original full Linux run](https://github.com/edgepillar/syrius/actions/runs/43945119834)
passes eleven required stages. Unit/widget tests report 5095 passed, one
failed and one skipped; generated-file verification is skipped. The extended
positive startup case fails at the initial `_recipeControl` lookup, before
the new focus request can run. The selector still requires primary focus
while that test deliberately gives it to an unrelated sibling.

The complete original job text and stack are retained by digest in managed
storage. The read closes successfully; earlier admission/capture failures
remain separately recorded. No original CI test or native task is repeated.
All owned outputs are consumed. Source818 has no Windows measurement.

[Source819](source819-focusable-startup-selector.md) separates focusable
selection from the existing primary-focus admission immediately before
input. The original P06 preparation cause remains unestablished; fresh
execution is required. Acceptance stays 76/80 with Source730's 2/94 matches.
