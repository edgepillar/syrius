# Source359 analysis refusal and Source360 test correction

Source359 is `68b98f5d5f73f1bbe761bfd9b8cc0a816226b692`, tree
`692cc4916be44442277acf2282bee17f050af37e`.

The original [focused attempt 41631614577](https://github.com/edgepillar/syrius/actions/runs/41631614577)
fails. All 953 Python controls pass with three existing skips; fourteen asset
observations pass. Strict analysis has zero errors, zero warnings and one info:
`CURLY_BRACES_IN_FLOW_CONTROL_STRUCTURES`, in the new Project input loop at
`test/harness/restored_seed_workflow_test.dart:1411:62`. Analysis transport is
complete: 183 bytes, SHA-256
`adddaa7e6ec1df658b0598916cddac7be969c3680b64725c623adfdae22879aa`.
The analyzer exits zero, while the separate strict gate correctly refuses
this info. Startup/Dart execution is skipped; no Dart case or native actor
executes and zero artifacts exist. The original failure remains failed.

Source360 adds braces around that one existing assignment. Every assertion,
label, registration, input value, scroll, actual agent, application, SDK,
dependency, Python controller and workflow byte is unchanged from Source359.
The expected gate remains exactly 900 ordinary cases across the same 72 files
in 36/36 groups (441/459), or 902 with asset fidelity, plus 953 Python controls
and three existing hosted skips. No already completed local Python controls
are repeated for this test-only syntax correction. Fresh hosted strict
analysis and both actual Dart streams remain required.

The [Project source preparation and Native105 results](native105-project-fields-and-source359-preparation.md)
retain their separate scopes. Native105 has four incomplete confirmed-prefix
observations and refuses Project before its guarded publication call; its
unexported exact UI cause is still `NOT_ESTABLISHED`. Source358's 897-case
strict success does not qualify this newer source. No old consumed operation
is retried and Native106 is not admitted.

Main acceptance stays 72/80 original rows, with 50 literal outputs, 44 missing
and zero accepted whole-image matches. All earlier FAILURE/HOLD/UNKNOWNs,
including Native101/103/104 uncertainty, remain source-bound. The exact
preceding [body295](pr-body-295.md) preserves its historical text and links.
The PR stays Draft with English public text and edgepillar no-reply identity.
