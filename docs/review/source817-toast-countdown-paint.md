# Isolate countdown paint from the frosted toast

The toast drains a three-pixel bar for five seconds. Its changing width was
inside the same painted subtree as the static frosted card. A repaint
boundary now contains that bar, including its existing clip and fill.
Message, detail, blur, shadow, geometry, direction, semantics, hover/focus
pause, dismissal and the original 300 ms entrance remain unchanged.

This targets a concrete repaint path. It does not establish that a toast
caused the preceding Windows frame failure, or that native timing improves.
The measured page and disclosure remain unchanged, as do original frame
collection, commands, deadlines, baseline overlay and comparison predicates.

## Controls

The existing dark/LTR and light/RTL cases retain every earlier assertion.
They now also require the static card's PictureLayer to survive a clock tick
while the bar advances from 50 to 48 percent and stays at the reading start.
This checks retained paint and live progress rather than a widget count.
These extended Flutter assertions still require hosted execution.

All eight existing toast cases enter the Windows selection once. Every
previous suite remains: standard/cold totals become 1517/1519 Dart cases in
113/114 suites, with unchanged 1229 Python cases and eighteen Windows skips.
The two toast source/test paths extend strict analysis from 289 to 291 paths.
Old totals and partial/extra/replayed groups remain refused. Group budgets,
the exact total guard and all thirteen full Linux stage names are retained.

Forty-five related Python memory controls pass with zero failures, errors
or skips. No local SDK executes. Fresh hosted full Linux and native
qualification remain required for this source.

The pinned Flutter implementation already makes animated opacity a repaint
boundary while visible. The separate countdown boundary therefore targets
the changing descendant, preserving its static frosted ancestor. Framework
paint retention does not prove engine raster-cache or Windows timing gains.
See the pinned [opacity implementation](https://github.com/flutter/flutter/blob/abaf9c523780a608bd46686fd5e53740a07077f8/packages/flutter/lib/src/rendering/proxy_box.dart)
and [repaint-boundary contract](https://github.com/flutter/flutter/blob/abaf9c523780a608bd46686fd5e53740a07077f8/packages/flutter/lib/src/widgets/basic.dart).

## Preceding executed evidence

[Source816 full Linux](https://github.com/edgepillar/syrius/actions/runs/43917192719)
passes all thirteen required stages. Its
[original Windows producer](https://github.com/edgepillar/syrius/actions/runs/43919602067)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43923420993)
verify all 1509 selected Dart cases, 1229 Python cases/eighteen skips, zero
selected analysis findings, Release and both finite native measurements.

Both current and P06 complete sixteen commands on the same fixture address.
Both entry processes, both wallets and five nodes exit normally, with
complete unforced output. Current records fourteen page-change and fifteen
disclosure frames; P06 records twenty-two and twenty-six. The earlier
startup/close failures are not reproduced; their causes remain unknown.
The new startup diagnostic is not triggered in that successful preparation.

The original 16000-microsecond and frame-gap comparisons fail in both
windows. Retained rows contain no build duration above 16 ms. Raster work
dominates: current disclosure takes about 36-60 ms versus 19-37 ms in P06;
page-change raster peaks are about 204 ms and 118 ms. This identifies the
costly stage without establishing its rendering cause.

The original 11784-byte archive was read once under managed storage with
its independent digest verified. Only its registered extraction scratch was
removed after a successful close. No native task was repeated. All owned
outputs are consumed; prior failures and the original predicates remain.

No new visual match, performance improvement, financial success or final
acceptance is claimed. Rows remain 76/80; the two literal Ready matches
remain Source730 evidence, giving 2/94. V01/V02/V05/V06 stay open.

## Executed Source817 result

[Full Linux](https://github.com/edgepillar/syrius/actions/runs/43931513271)
passes all thirteen required stages. The
[original Windows producer](https://github.com/edgepillar/syrius/actions/runs/43934475881)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43939496209)
verify 1517 selected Dart cases, 1229 Python cases/eighteen skips, zero
selected analysis findings and Release. All eight toast cases, including
the static-card PictureLayer retention assertions, pass.

The current wallet completes sixteen measurement commands with eleven
page-change and thirteen disclosure frames. Both wallets and five nodes
exit normally. The original producer fails at P06 preparation: `importWallet`
cannot observe `welcome_import` before startup initialization. One finite
snapshot records 56 film frames, zero-based last presented index 2 and
`done=false`. It proves neither input delivery nor a rendering root cause.
P06 never reaches measurement; no native timing improvement is established.

All original outputs are consumed without a retry or local artifact download.
The [next input-targeting change](source818-original-startup-focus.md) requires
fresh execution. Original failures, 76/80 acceptance and Source730's 2/94
literal matches remain.
