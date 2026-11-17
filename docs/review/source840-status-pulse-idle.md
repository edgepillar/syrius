# Status halo idle interval

The connection and publication dots now stop requesting frames while their
halos are transparent. A timer wakes the existing phase clock for the next
pulse. The first 1,680 ms retain the original radius, alpha and easing. The
720 ms hold retains its transparent paint. Color changes keep the phase, and
the clock follows the surrounding ticker mode. Removing the dot cancels its
pending wake-up.

The existing motion tests exercise both operating system animation settings.
They check that the visible pulse requests frames, the hold leaves no frame
callbacks pending, and the next pulse resumes at the cycle boundary. They
also unmount the dot with a pending wake-up. Both pulse cases pass in the
Source840 Linux run.

At `cf7e3633ae6a3547be025762ecde67c6fe5875c3`, all fourteen Linux stages
pass. Windows builds the Release harness and completes the sixteen original
actions for both the current build and P06. The independent reader confirms
both retained windows and normal process exits. The original 16 ms check
fails for raster and distinct frames in both windows. The current raster
peaks are 192.531 ms for the page change and 57.832 ms for the disclosure.
Both builds report gaps in the frame numbers. The measured cause remains
open, and the new pulse requires a fresh measurement. The original launch
comparison and the full visual and motion reviews remain open.

- [Linux qualification](https://github.com/edgepillar/syrius/actions/runs/44153340478)
- [Windows measurement](https://github.com/edgepillar/syrius/actions/runs/44156814395)
- [Independent reader](https://github.com/edgepillar/syrius/actions/runs/44162358687)

## Plasma fixture follow-up

At `ea19d9780c4ae65e8cc18f2fc1aa4c49d168f6b0`, the first twelve Linux
stages pass, including strict analysis and the original P06 Git check. The
full test directory reports 5,109 passed, one failed and one skipped.
Generation is skipped. The sole failure expects the plasma bolt to disappear
on completion. The original job log is retained once, and Windows testing
for this revision did not start. [Source840 Linux](https://github.com/edgepillar/syrius/actions/runs/44171618550).

At 14 seconds the status halo is in its transparent hold. Flutter's test
binding checks for a scheduled frame before it flushes pending microtasks
on a durationless pump. With the halo quiet, the test can observe the old
widget before it renders the asynchronous completion. [Flutter 3.47.7 test binding](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter_test/lib/src/binding.dart#L2113-L2128).

Source841 awaits the existing completion event before pumping. The same
assertions require the bolt and elapsed time to disappear and the fixture
to record 14 seconds. The status strip and pulse suites also run in the
early compact stage, with the complete test directory still running later.
Fresh Linux execution and the paired Windows frame measurements remain open.

## Restart fixture follow-up

At `3c2114fe560fd1ee4538d0e03954a78f34b71c00`, the early test stage
reports 497 passed and one failed. Both pulse cases pass. The plasma
fixture verifies completion and records 14 seconds, then reads the counter
before the asynchronous second start renders. The full test directory and
generation stages are skipped. The original job log is retained once.
[Source841 Linux](https://github.com/edgepillar/syrius/actions/runs/44176269903).

Source842 waits for delivery in both existing fixture helpers. All callers
await each start or completion before pumping. The test still requires the
second run to start from zero and show the first run's 14-second duration.
The early strip and pulse suites and complete Linux pass will verify this
revision. The Windows comparison remains open.

## Executed Source842 result

At `d7ba1cd56ee5b228932b2354519ddd2bde22b79e`, the fourteen Linux stages
pass. The Windows Release build completes both interactive samples and the
independent reader validates the original manifests.
[Linux](https://github.com/edgepillar/syrius/actions/runs/44178587454),
[Windows](https://github.com/edgepillar/syrius/actions/runs/44180857029),
[reader](https://github.com/edgepillar/syrius/actions/runs/44185500081).

The original 16 ms comparison fails for raster and distinct frame durations
in both windows. The longest end-to-end spans are 282.791 ms for the page
change and 136.125 ms for the disclosure. The corresponding P06 spans are
163.031 ms and 64.617 ms. All retained build durations are at or below
16 ms. Both builds report frame-number gaps in both windows.

The pinned Flutter engine assigns a new number at the vsync callback.
When the layer-tree pipeline is full, the animator schedules another frame
before building one for that number. This provides one mechanism for skipped
numbers. Attributing these specific gaps requires a trace of the runs.
[Frame numbering](https://github.com/flutter/flutter/blob/deb287481e3ce9468f3434937ced4240a70539ca/engine/src/flutter/flow/frame_timings.cc#L41-L45),
[vsync callback](https://github.com/flutter/flutter/blob/deb287481e3ce9468f3434937ced4240a70539ca/engine/src/flutter/shell/common/vsync_waiter.cc#L136-L141),
[full pipeline](https://github.com/flutter/flutter/blob/deb287481e3ce9468f3434937ced4240a70539ca/engine/src/flutter/shell/common/animator.cc#L95-L108).

## About disclosure paint

The About section scrolls its cards in one viewport. The version strip now
has its own repaint boundary so its recorded paint can survive the changing
height of an opening disclosure. The existing test checks that the
Licences panel grows while the strip retains its paint at an intermediate
frame and at the end. It also checks the original late version update.
Hosted execution and a fresh native measurement are pending.

## First-open update

[Source843 Linux](https://github.com/edgepillar/syrius/actions/runs/44188242255)
passes eleven stages through the Lock checks, including strict analysis and
the original twenty-two P06 Git commands. The compact test sees the Licences
panel grow at 80 ms and then sees a replacement version strip PictureLayer.
The full test directory and generation steps are skipped.

The first registry open now rebuilds the Licences disclosure through its
local builder. The version strip and adjacent groups are outside that
state update. The same test still checks retained paint at 80 ms and 240 ms,
the late version update and the original registry lifecycle. Hosted
execution is pending.
