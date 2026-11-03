# Pending seed deposits and hero colour order

This change follows the [Native104 result](native104-prefix-and-deposit-results.md).
Its exact inner Deposit cause remains NOT_ESTABLISHED. The adapter correction
below follows pinned protocol sources and does not reconstruct that old cause.

## Pending HTLC effect reads

The pinned [HTLC API](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/rpc/api/embedded/htlc.go)
returns an error for an unknown or spent entry. The
[storage definition](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/vm/embedded/definition/htlc.go)
uses the [missing-data constant](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/vm/constants/errors.go).
The server's [default error code](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/rpc/server/errors.go)
and [response encoder](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/rpc/server/json.go)
produce code `-32000`, message `data non existent` and no error data for this
plain error. The locked
[SDK method](https://github.com/maznnwell/znn_sdk_dart/blob/16bf294b3e347cb4f9c1f47a7da5d60034724f95/lib/src/api/embedded/htlc.dart)
does not turn that response into a nullable entry. The selected
[JSON-RPC client](https://github.com/dart-lang/tools/blob/ab1a6168f0f9276f4af4c6f939822c58dc741551/pkgs/json_rpc_2/lib/src/client.dart)
decodes it as a typed exception. That release tag identifies version 4.1.0,
which is already selected in the unchanged lockfile.

The isolated seed binding now treats only that exact typed code/message/null-data
combination as a pending effect. It makes one original request per invocation
and checks ownership before the request and after either outcome. Other errors
retain their original identity while the owner remains current. Changed owners
refuse both positive and missing results.

Pending is not success. Existing hash, owner, counterparty, token and amount
checks still apply to a present entry. The original publication remains a
single consumed attempt. The unchanged policy permits at most eighteen
confirmation/effect observations, retains its two-second spacing and requires
the exact confirmed effect. A permanently missing entry ends held. There is no
SDK/dependency update, timeout increase, new publication, numeric-limit change
or retry of an old financial operation.

Nine new Dart cases cover positive identity, exact absence, other RPC shapes,
lookalike errors, ownership changes and both later-effect and permanent-absence
paths through the existing guard. All earlier test bodies remain unchanged.
The complete selection remains 72 files in two 36-file groups, now expecting
897 ordinary passes (441/456) or 899 with asset fidelity. Existing one-worker,
240-second command, 480-second total, output, refusal and startup bounds remain.

Fourteen mocked Python admission controls pass locally without SDK, filesystem
fixtures or native execution. The hosted Python selection remains 953 methods
with three existing skips. Fresh strict analysis, Dart execution and native
qualification of this correction are pending; Native105 is not admitted.

## Hero palette direction

The [reference CSS](../../mockups/redesign/src/00-head.html) places green on the
left and blue on the right. The shared field had those semantic colours reversed;
its source centres remain on their respective sides throughout the animation.
The Home and Lock field now binds green to the left source and blue to the right.
The approved [RULES](../design/RULES.md) values `#00D557` and `#0061EB`, middle
pink, shader equations, clock, strengths and visibility behavior remain.

This is a three-line palette-order correction. Exact CSS geometry and fresh
pixel fidelity are not established by it. The previous actual/reference
differences remain recorded, and no new native image or visual match is claimed.
The original ledger stays 72/80 and the first-delivery pin is unchanged.
