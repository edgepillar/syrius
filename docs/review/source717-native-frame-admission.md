# Wait for one original native frame

Updated 2026-11-13.

## Observed boundary

Source716's Ready producer and independent reader retain a light-theme
`shotRequest` refusal. At the original 250 ms admission deadline, the binding
is current, frames are enabled, both native callbacks are registered and a
frame is scheduled. The original request has observed zero persistent frame
callbacks. The scheduler is idle and the lifecycle value is `none`.

These facts identify an uncompleted original frame at that boundary. They do
not identify its eventual completion time or the platform's underlying cause.
The original result remains failed, with zero verified PNGs and required-actor
forced cleanup. See the [executed Source716 result](source716-details-frame-context.md#executed-source716-result).

## Change

The harness's default frame-admission interval is now one second. It still
reserves one receipt, requests one original frame and awaits that same Future.
Only positive original completion permits pixel readback. A deadline, original
failure or invalid admission continues to hold the original receipt; late
completion cannot release or replace it.

This is an observation bound for capture admission. The 16,000 us performance
comparison, its failing Source715 result, frame collection, normal application
rendering and publication guards retain their original behavior. Readback,
theme restoration and parent request bounds are unchanged. No failed original
capture is retried or converted into a successful result.

Two existing widget cases now exercise the actual default timer. A frame
completing after 300 ms must remain the sole original and permit exactly one
readback. A still-pending frame at 999 ms must refuse at one second, with zero
readbacks, and remain held after its late completion. The positive receipt
also remains ready after its admission timer eventually fires. Other existing
injected-deadline, ownership, error and reentrancy controls remain in use.

## Executed Source717 result

The [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43354840499)
passes controllers, application/patched analysis, the complete non-chain test
directory and tracked generation, including the extended default-timer cases.

The [Ready producer](https://github.com/edgepillar/syrius/actions/runs/43356581345)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43359191086)
verify two original 1280 by 780 PNGs and 82 producer files. The producer passes
1,480 selected Dart cases, 1,214 Python cases with eighteen skips and analysis
with zero findings; the reader passes 123 cases. Required application actors
and all five original lab nodes close normally. The separately owned MSVC
telemetry helper requires forced cleanup and has zero remaining processes.
The prior failures and their unknown underlying cause retain their own scope.

Both PNG/reference pairs were individually viewed. The uppercase label,
compact copy glyph and stronger light card shadow are present. Card geometry,
text baselines and address weight retain visual differences. Original addresses
and animated map phases are preserved, as are the approved RULES.md colors.
Zero whole-image matches are accepted. The verified archive is retained; only
this review's registered disposable PNGs are removed after successful closure.

This result qualifies this Ready inspection. It does not establish the earlier
failure's cause, a motion result or complete redesign acceptance. Original
acceptance remains 73/80, with no V01/V02 or F06 closure.
