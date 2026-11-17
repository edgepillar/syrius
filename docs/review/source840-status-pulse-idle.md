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
also unmount the dot with a pending wake-up. Hosted execution is pending.

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
