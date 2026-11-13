# Compact Token facts and stable Lock fields

The Source736 Staking/Token review and Source738 Lock review expose three
remaining presentation defects: Token facts stretch across unused row space,
the disabled password field paints below its reserved height, and a short
wallet-name tooltip can cover the password label.

## Presentation changes

Token facts keep the existing two-pair grid at its natural content width.
Flexible value columns can still shrink within the available width. Narrow
and enlarged layouts retain the one-pair fallback. Genuine values, missing
issuance metadata, action admission and exact numeric input remain factual.

The expanded Lock picker supplies an inert suffix within the existing field
constraints. This keeps the filled password container at the same 42 px
target while its reveal action is unavailable. The existing field state,
focus refusal, password value and submit ownership are retained.

Wallet-name tooltips now appear when the displayed name actually truncates.
The full name remains available to semantics, and shortened addresses retain
their tooltips. Registered service-gate tooltips keep their original behavior.

Eight existing Token theme/direction/scale cases add natural-grid geometry
and narrow Flags checks. Four existing Lock theme/direction cases check the
actual filled container through
[InputDecorator.containerOf](https://api.flutter.dev/flutter/material/InputDecorator/containerOf.html),
plus short/long name tooltip and semantics behavior. Case registrations are
unchanged. Fresh full Linux and native image qualification are required;
preparation does not establish a new visual match or performance pass.

## Executed Source738 evidence

[Windows Lock 43494273465](https://github.com/edgepillar/syrius/actions/runs/43494273465)
and [reader 43496540964](https://github.com/edgepillar/syrius/actions/runs/43496540964)
pass at `5a4ec0ccfc084151e1cda2f1febec4b9fbb2ebc4`. Current controls pass
1,220 Python cases with eighteen platform skips and zero selected analysis
findings. Both serial Dart groups pass, 720 + 787 = 1,507 cases, with normal
exits and complete bounded output. Their elapsed time is 297.188 seconds
within the unchanged 480-second total. Release build, six PNGs and four
normal required actor exits are verified. Source737's full Linux result
continues to qualify only its byte-identical Flutter inputs at Source738;
there is no new Source738 full Linux claim.

All six Lock pairs have been individually reviewed. Normal Lock geometry,
glass and symbols closely agree, while masked text/caret details remain under
review. Wrong-password views retain a wallet-name overlay and truthful
reset-at-limit wording. Picker views still paint a short disabled field;
two service overlays are visible in the light view. Their activation cause
remains unestablished. The four-gate count enumerates controls, not clicks.
These observations accept no new match.

The four Source736 Staking/Token pairs have also been individually reviewed.
Collect has the expected compact width. Ledger columns, label weights, Token
fact spacing and detail geometry retain differences. The owned review reuses
the original verified archive and closes successfully; its earlier interrupted
review failure is preserved. Runtime evidence remains bound to Source736.

## Current timing result and remaining acceptance

[Paired producer 43500805067](https://github.com/edgepillar/syrius/actions/runs/43500805067)
and [reader 43503969670](https://github.com/edgepillar/syrius/actions/runs/43503969670)
verify a fresh Source738/P06 acquisition and five normal actor exits. The
selected gates again pass 1,507 Dart and 1,220 Python cases/eighteen skips,
with zero findings and 358.469 seconds of serial test elapsed time. A local
observer's stale archive-prefix refusal is retained separately; reconciliation
uses its completed metadata reads and does not repeat CI or artifact transport.

The reported windows contain 261 frames over 9.006 seconds and 1,827 over
46.278 seconds. Build maxima are 11.601 and 14.902 ms. Raster p95 is 98.756 ms
current versus 35.217 ms P06; slow reported raster frames occur in every
window quarter. The unchanged 16,000 us comparison and frame-key gap checks
both fail. These samples establish no hardware or inner rendering cause.
The independent reader starts no runtime, and no timing archive is transferred
locally. V02 remains open; Source715's earlier failed result is preserved.

Accepted scope stays 76/80 and visual matches 2/94, both Ready pairs at
Source730. V01, V02, V05 and V06 remain open. The owner-approved native Windows
CI route for P03/P09 retains its scope; the original Docker/WSL route remains
unqualified. F06 remains complete at Source722. Source738 runtime evidence
does not qualify the presentation changes prepared here.
