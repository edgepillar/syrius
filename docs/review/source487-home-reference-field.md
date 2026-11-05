# Home field reference geometry

Based on Source486 668f5501d982b2bb575086154ad63d66cace32b2, tree
19dfd6d8d7a5020fdab2f5238edd9251af48931d.

Source487 adds a Home preset for the existing HeroField. The original reference
is .hero::before in mockups/redesign/src/00-head.html: inset minus forty percent,
three closest-side gradients, forty-pixel blur, grouped opacity 0.55 and
eighteen-second alternating ease-in-out drift. Green is at 30%/40%, blue at
70%/60% and pink at 50%/90%. The first CSS background paints over the later
backgrounds.

The previous Home field used independent Gaussian sources and nonrepeating
elliptical motion. Its palette order had already been corrected in Source357,
but its geometry, blur, composition and period differed from this reference.
The new Home preset uses SDK radial-gradient shaders and a grouped blur, with
the exact field expansion, light centres, source opacities and transform. The
existing default fragment painter and asset keep their bytes. Other callers
retain that default. The existing ShaderClock still owns the one ticker and
its visibility, route, window and frost holds; no OS motion setting is read.

Only the Home background selects the new preset. Balance/price arithmetic,
hidden values, plasma state, address controls, financial callbacks, SDK and
dependency pins remain. The widget is exported through the existing utility
barrel so its focused tests can use the canonical package import.

## Reference observations and controls

The two original Home rest PNGs were read without local image conversion or a
new download. Their card rectangle is 60/36/1204/153. A bounded standard-library
PNG reader verifies chunk CRCs, dimensions, eight-bit noninterlaced layout and
complete decompression before sampling three background points. Original image
digests are:

| Theme | SHA-256 |
| --- | --- |
| Dark | 70617942960638e9ad855344dcc7aa1433058bb4d060155f1cfb36592ca332a6 |
| Light | 280f31f618a20af2f275bd516afc3280849180f4788f38ae7c3fdebaedd36b7c |

The owner's approved RULES colours are green #00D557 and blue #0061EB. The RGB
envelopes adjust only those two palette entries from the original PNG samples,
using the original source-over colour weights; base and pink remain. They allow
eight levels for eight-bit blur/compositing rounding and the palette projection.
The empty-field fixture measures 1204 by 153 and checks full opacity.

| Card-relative point | Expected dark RGB | Expected light RGB |
| --- | --- | --- |
| 150,110 | 36 / 55 / 44 | 221 / 240 / 229 |
| 1040,100 | 33 / 49 / 73 | 204 / 220 / 244 |
| 600,145 | 43 / 42 / 54 | 230 / 228 / 241 |

Four new widget registrations run in both themes: reference colour regions,
the two eighteen-second legs returning to the first frame, a hidden clock hold
without a resume jump, and movement with the OS disable-animations flag set.
Every original Home test line remains. No image buffer or financial value is
printed by these tests.

The complete focused selection keeps its original one hundred files and two
50/50-file streams. Eight added widget cases prepare 1,305 ordinary passes
(627/678), or 1,307 with asset fidelity. The original one-worker, 240-second
command, 480-second total, stream caps, startup/refusal and final-source checks
remain. The existing fourteen mocked admission methods pass locally with zero
failures/errors/skips, no filesystem fixtures and no SDK/native execution.
They reject the previous and neighbouring totals while requiring the complete
current selection. The hosted Python selection stays 1,063 cases, with eighteen
expected Windows skips. Fresh strict analysis and complete widget execution are
pending; these counts are expectations, not executed Dart results.

## Retained scope

The separate [Native109 result](source485-native109-deposit-reply.md) keeps its
failed copied Deposit reply and UNKNOWN outcome. A source-only audit covers all
seventy-seven literal seed refusals with the existing ninety-eight closed
labels; no missing literal label establishes that old cause. No new native
wallet, chain, financial operation, archive or catalog capture is admitted for
this UI follow-up.

The [first delivery](fast-first-delivery.md) remains available for Draft review.
Current Windows pixels, GPU/frame-time cost of the grouped blur, populated Home
states and complete image/motion acceptance remain deferred. The isolated colour
and clock controls cannot accept a whole screenshot. X521-X528 remain attached
to their original views; X612 tracks this selected field scope. Original
progress remains 72/80, with 50/94 historical literal outputs, 44 missing and
zero accepted whole-image matches. All original FAILURE/HOLD/UNKNOWN records
and actual previous PR bodies remain unchanged.
