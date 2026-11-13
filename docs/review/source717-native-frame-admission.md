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

Fresh hosted Dart, strict analysis and native qualification are pending. No
local SDK or new artifact download is used to prepare the change. Original
acceptance remains 73/80, with no new accepted visual match or F06 closure.
