# Shared entry field and Ready composition

Lock and Wallet Ready both use the reference `.lockpage` field. Lock previously
used the old card shader; Ready drew its map over a flat window background.
Both now reuse the measured `EntryField` already used by Welcome and Import.
The shared field retains its own route, focus, window and overlay clock holds.

During the original launch transform, Lock keeps the caption's field delegate
inactive. It becomes eligible when the transform settles. The body field and
its original clock stay mounted. The existing caption-owner regression now
checks the held caption, refused sampling and same-clock return.

Ready contains the original map in the available viewport and reuses
`EntryStepPosition` for its completed steps. The localized create, import and
hardware paths retain their ordered labels. The compact copy control preserves
the reference address-line height. Original Lottie assets are unchanged.

## Validation

The [Source701 full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43262983299)
passes application and patched-package analysis, the full non-chain test
directory and tracked generated-file checks. Exact global case and finding
counts are not projected.

The [Lock producer](https://github.com/edgepillar/syrius/actions/runs/43263126406)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43273520112)
verify six genuine Lock captures and four normal actor exits. Selected checks
pass 1,482 Dart cases, 1,214 Python cases with eighteen platform skips and
analysis with zero findings. All six actual images and their references were
then viewed. Normal and error-card positions now agree with the reference;
the selector arrow reaches its trailing edge. Field paint, icons and live
status still differ. The expanded picker has shorter rows, different card
height and bottom links, and active password and Unlock controls. Two genuine
seam tooltips remain visible in its light capture. X689-X694 retain these
mismatches. The original wallet and node facts are not replaced with examples.

The [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43263756630)
fails during onboarding with `ENTRY_REFUSED`, exit 1 and zero images. Its
[independent reader](https://github.com/edgepillar/syrius/actions/runs/43271310197)
passes 123 actual cases and confirms the original failed receipt. The inner
cause remains `NOT_ESTABLISHED`; required-actor forced cleanup is recorded.
Ready's new composition has no positive native capture qualification. No
native retry or normal closure is claimed for that producer.

The existing caption regression is extended without adding a registered case.
Zero whole-image matches are accepted. Original acceptance remains 73/80,
with P03, P09, F06, V01, V02, V05 and V06 open.
