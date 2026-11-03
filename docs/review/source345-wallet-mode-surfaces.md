# Source345 Wallet mode groups and card surfaces

Prepared from source d0f62bd438efd83db73c2e920a696990c6a88101, tree
af76879e633e9a57f34436c6c180e9b94268557f. The Wallet view before this change
is byte-identical to Source336, whose [actual Settings review](source336-settings-visual-review.md)
retains the wrapped Sporks group, separate outlined mode pills and missing
Wallets card surface. The two exact Wallet reference PNGs were reopened for
this source change; no new actual/native image is produced or viewed.

## Implementation

Pillar, Sentinel and Sporks now use the existing shared Segment control, with
one rounded track for each Auto/On/Off group. The reference's six-pixel
label-to-group gap is a Wallet token. The existing outer wrapping layout,
reading direction and translated labels remain. At the existing normal-width
widget fixture, all three operator labels must share one row. The existing
larger-text/RTL variant remains required.

The operator-mode service is still unavailable. Each item is disabled, every
selected value is null, and the existing operatorModes SeamGate remains.
Direct onChanged callbacks still pass through the original runUnlessSeamed
barrier. No effective Auto/On/Off value, operator capability or native action
is invented. The current-view/lifecycle/ownership code and preference builder
are byte-identical, with original cache/reset callback conditions retained.

Wallets gains the standard Panel surface around its original seamed disclosure.
The existing Maintenance disclosure gains the same surface, retaining its
controller, keepAlive, epoch checks, clipboard preference and guarded reset.
Maintenance is not drawn in the supplied Wallet reference; it is preserved as
an existing feature with a consistent card surface. This corrects the earlier
review wording that implied a reference Maintenance card existed. The genuine
wallet-count capability remains unavailable and no illustrated count is added.
No cache retention promise or stored preference is changed.

## Bounded verification and remaining scope

The existing eight-case Wallet view file is added to every previously selected
focused file: all sixty-nine original files remain, for seventy files and
856 ordinary cases, or 858 with asset fidelity. Both serial groups, one worker,
original deadlines/output caps, pre-build refusals and strict analysis remain.
The direct-callback test now requires three actual Segment widgets, null
selections, disabled items and no additional writes/outcomes, avoiding an empty
legacy-widget query. All original maintenance, resource, reversal, keyboard,
large-text/RTL and persistence assertions remain; no registration is added.
All fourteen selected Python admission controls pass locally. Fresh hosted
analysis and engine results are pending. No local SDK, full build, native
producer, original financial flow or new image transport is started.

Binding, presenter, shared Segment/Disclosure/Panel, locked dependencies and
analysis policy remain unchanged. The previous Source343 848-case success is
retained with its exact source; it does not qualify this changed application.
The first delivery remains pinned to 19c7b2af5e1c for Draft code review.
Detailed visual, motion/performance and extended platform/lab acceptance stay
open. Original progress remains 72/80, nineteen preparations, 50/94 available
outputs, 44 missing and zero matches. Earlier FAILURE/HOLD/UNKNOWN remain.
