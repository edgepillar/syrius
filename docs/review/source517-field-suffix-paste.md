# Field suffix clipboard lifetime and labels

## Observed source defect

The shared PasteContentButton is used by the Fuse form and the existing
pillar and token fields through FieldSuffixButtons. Its original callback
writes to the captured controller whenever the asynchronous clipboard read
answers. It has no widget-lifetime, controller-replacement, edit or newer-read
check. A late answer can overwrite a newer draft or touch a disposed field.
This is a source defect; no private clipboard or live wallet is inspected.
The shared Paste and Clear icons also lack the tooltips required by section
9 of the design rules.

## Change

The Paste button owns a local request revision. Controller edits, selection
changes, controller replacement and a newer paste invalidate older answers.
An unmounted button never writes. Listeners move with the controller and are
removed on disposal. A current answer still uses the original clipboard
helper and one exact text assignment. The existing empty-clipboard handling,
glyph, theme, field geometry and form actions remain.

Both suffix icons use existing localized Paste and Clear strings. The Clear
button retains its original enabled state and controller clear callback.
No new dependency, localization generation, wallet, signer, transport or
chain behavior is introduced.

## Validation scope

Eight new widget cases exercise the real shared suffix inside a text field:
current paste and labels in both themes; clearing; typing away and back;
out-of-order reads; controller replacement followed by a valid new read;
unmounting with the controller disposed; and selection away and back.
Only the platform clipboard reply is mocked. No real clipboard is read.

All 102 preceding selected Dart paths remain in their original order, and
the new file is appended. The ordinary selection now has 103 files, split
52/51, with expected passes 653/705: the original nine Pillars cases move to
the first group and eight new suffix cases join the second. Fixed ordinary
and asset totals are 1358/1360. All previous count refusals remain, with the
old totals and new adjacent totals explicitly rejected. The new production
and test files are included in selected analysis and known-file projection.

Twenty local memory/mocked Python methods pass: fourteen admission controls,
five analyzer controls and the existing known-file privacy case extended
with the three new basenames. Python registrations remain 1087, with eighteen
existing Windows skips in the hosted lane. Fresh Dart execution and selected
analysis are pending; local source checks do not establish those results.

The first-delivery scope remains core interface and existing basic functions.
Detailed visuals, native motion/platform and complete lab acceptance remain
phase two. Original 72/80, P03/P09/F06, V01/V02/V03/V05/V06, 50/94 available
literal outputs and zero accepted whole-image matches remain. All original
failures and UNKNOWN outcomes retain their sources.

## Actual Source517 controller refusal

Source517 21fad9313afac8eb208f7a56aca0ceecdedc60f4, tree
26f6c9d78a5999fc238c7d13946cd11f651e0f1e, has one actual
[run 42137045185](https://github.com/edgepillar/syrius/actions/runs/42137045185),
attempt one, job 127627741038. It fails before SDK allocation: 1087 Python
cases report one failure, zero errors and eighteen explicit Windows skips.
The failing root-catalog integrity case detects the new test filename missing
from the sorted complete-test catalog. The separate focused location list
already contains that name; it does not replace complete-catalog coverage.

Assets, SDK setup, selected analysis and Dart execution are skipped. No new
Dart result qualifies. Fresh run/job/source/tree/Draft-head reads independently
reconcile the terminal failure with zero artifacts. The original is not
retried, and all earlier results retain their scopes.

## Source518 catalog correction

Source518 adds only field_suffix_buttons_test.dart to the sorted root
catalog. Every preceding entry remains, with the same privacy projection and
unknown-name refusal. Source517's production, widget-test, selection, count
and analysis bytes remain unchanged. No test registration or threshold moves.

Twenty-five local memory/mocked and read-only source methods pass, including
all five root-catalog privacy cases and the preceding twenty controls. The
new test name belongs to both catalogs, with no path or private error exposed.
Fresh 1358 Dart/1087 Python/eighteen-skip hosted qualification is pending.
Source517's controller failure and unexecuted Dart/analysis stay preserved;
X619, all eight original gates and complete acceptance remain open.
