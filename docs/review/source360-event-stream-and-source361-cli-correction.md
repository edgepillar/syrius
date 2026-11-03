# Source360 event refusal and Source361 CLI correction

Source360 is `b74c30db8bb017bf0f16f5db592b25093ff1dfcf`, tree
`1c0be79d621619918ebe471e8dd518e79fa6f3cc`.

The original [focused attempt 41633102235](https://github.com/edgepillar/syrius/actions/runs/41633102235)
fails. All 953 Python controls pass with three existing skips, fourteen asset
observations pass, and strict analysis has zero errors, warnings or infos.
Both original Dart child processes exit zero normally with complete output.
The first 36-file group qualifies 441 passes, no failures/errors/skips and
44 hidden terminal events. Its 231,450-byte stream has SHA-256
`7092fb6b2dddccf9b9de799e5c8129fcfa7806b8c6940e1633337558d651cce8`.
The second 36-file group's 225,565-byte stream has SHA-256
`c92c7e168b8f57f268e933f9f31276956f38e7d641b5e80f4bc33d6026e9e4ab`.
Its counts and progress are refused with `TEST_EVENTS_INVALID`. The original
exact event-level cause is not exported and remains `NOT_ESTABLISHED`.
Zero artifacts exist and the complete 900-case gate is unqualified; process
exit zero cannot substitute for valid test events. Native106 is not admitted.

## Source-derived corrections

The new Project widget regression calls the actual CLI, whose report writes
human-readable status directly to `dart:io` stdout. The test previously had
no local stdout capture, so those writes can pollute the JSON runner channel.
Source361 uses the existing repository test pattern: a test-local Stdout fake
inside [IOOverrides.runZoned](https://api.dart.dev/dart-io/IOOverrides/runZoned.html),
scoped only to the actual CLI call. Every captured line must begin with the
CLI's real `ok` prefix and there must be one line per actual agent command.
The CLI, agent, strict event parser and production stdout behavior are unchanged.
This source finding does not reconstruct the missing original event bytes.

A second source inspection finds that the CLI's scroll case reads its final
positional argument and ignores a `--dy` flag. The two literal Project lines
now use `scroll --key accelerator_action_url 320` and
`scroll --key accelerator_action_znn 160`. The recipe accepts only these exact
Project view commands, at most once each before its sole original publication.
The old ignored flag is now refused. Both-theme genuine-form/CLI/agent cases
assert the actual outgoing selector keys and 320/160 deltas, all five original
controller values, zero publications before Continue, one inert publication
and the original route exit. Every prior test label and registration remains;
no new case is added. Fresh execution of all 900/902 cases is required.

Application UI, SDK/dependencies, original values, publication/receipt/owner
policy, Python controllers and workflow are unchanged. No local SDK/native
execution or new artifact transport occurs. Previously passed local mocked
admission controls are not repeated for byte-identical Python code.

## Full acceptance remains open

The original F06 requires all screen states, including a swap. The current
Deposit script explicitly describes one HTLC deposit with no offer/terms
coordinator. Its receipt cannot establish all coordinated Swap states or all
remaining screen preparations. Runtime coordinator availability was not
queried. Any unreachable-state fixture must stay in the harness-only path;
no ordinary-build backend behavior is changed or qualified here.

Main progress stays 72/80 original rows, 50/94 literal outputs, 44 missing and
zero accepted whole-image matches. Native101/103/104 UNKNOWN and Native105's
four incomplete prefix observations/Project pre-publication refusal retain
their exact original scopes. All earlier failures remain failed. The exact
preceding [body296](pr-body-296.md) preserves its historical text and links.
The PR stays Draft, with English public text and edgepillar no-reply identity.
