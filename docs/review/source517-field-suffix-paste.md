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
