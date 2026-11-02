# Source329 Wallet focus and painted fields

The [Source328 results](source328-windows-and-details-results.md) preserve both
native failures and the closed actual Details review. This change addresses four
bounded issues without changing SDK or financial authority.

Wallet settings now watches its nearest focus node and its ancestors. A nested
page entrance can restore an outer focus barrier without notifying the nearest
node. The view rebuilds when that changes visibility, revokes retained callbacks
on a lost visit and removes its own listeners at disposal. One new real Wallet
view regression exercises nested RiseSwitchers in both themes, waits for the
actual callback, observes the original control and checks that a retained callback
cannot write after departure. This is a source-level candidate; Source328's
`targetMissing` inner cause remains unestablished.

Receive supplies amount content padding and line height, and an explicit token
menu decoration with bounded trailing-icon dimensions. Plasma supplies the chosen
beneficiary's painted container padding. The pinned Material implementation
computes a dense container from content and icon heights; an outer minimum alone
does not set that painted height. Existing Receive and Plasma cases now measure
`InputDecorator.containerOf`, retaining original payload, selection, validation
and callback assertions. Error text and scaled text can still grow naturally.
The [pinned implementation](https://github.com/flutter/packages/blob/314537c93f1442fad49854d673a33fd8c15c26fb/packages/material_ui/lib/src/input_decorator.dart)
and [menu decoration resolution](https://github.com/flutter/packages/blob/314537c93f1442fad49854d673a33fd8c15c26fb/packages/material_ui/lib/src/dropdown_menu.dart)
support this distinction; fresh engine and image checks remain required.

The licence end request retains all four existing bounded post-layout observations
even if an intermediate lazy extent reports zero remaining content. Source,
position, reveal, idle, revision, reentrant movement and disposal guards remain.
The long-registry fixture now measures the full painted discovery container after
the genuine trigger. Every previous assertion and physical command remains. No
clock, timeout, input clearing or automatic focus behavior changes.

All 25 selected memory controls pass after application, with 940 Python
registrations. No local SDK, native runtime, network or qualification scratch is
used by that control pass. One added Dart registration changes the expected totals
to 827 ordinary, 829 startup and 4,881 full passes with one existing skip. The
105-case reader roster is unchanged. Existing count fixtures accept the new exact
totals and preserve stale-count, wrong-lane, skip, error, completeness and privacy
refusals. Both serial groups, one worker, 240 seconds/four MiB per child and the
480-second total remain.

Fresh strict selected analysis, focused/full Windows, all four native families,
independent readers and actual affected-image review are pending. Remaining hero,
table, text, badge, licence-identifier and animation differences are still open.
The exact preceding [body271](pr-body-271.md) retains every submitted byte and URL.
Acceptance stays 72/80 rows, 36 literal outputs, 58 missing and zero matches.
Native101/103 remain UNKNOWN and Native104 stays unadmitted. English, privacy-safe
edgepillar no-reply/UTC attribution and the existing Draft PR continue.
