# Share the original serial test budget

Source737 (`62880e850985a7733dd96c60b4ee8eabc7409597`) passes
[full Linux validation](https://github.com/edgepillar/syrius/actions/runs/43486007428).
Its [Windows run](https://github.com/edgepillar/syrius/actions/runs/43489266267)
passes strict analysis and 1,220 Python cases/eighteen platform skips, then
times out the first Dart group after 240.125 seconds. The retained partial
stream has 685 ordinary and 75 hidden completions with no error events.
It has no engine terminal success, so no whole-suite pass is claimed.
The original test child is forcibly stopped; app build and native execution
are skipped, and no artifact is produced. This failure remains preserved.

The two serial groups now share an enforced 480-second monotonic budget.
Each launch receives at most 300 seconds and only the remaining total time.
Elapsed wall time is checked after each command; both successful command
durations must also sum to at most 480 seconds. An exhausted budget refuses
the next launch, and over-budget completion cannot qualify the aggregate.
The total budget, complete ordered selection, exact profile counts, serial
execution, output caps and terminal/exit/replay checks remain required.
There is no retry of the original failed run or omission of a test.

All fourteen existing controller-admission memory cases pass. Added vectors
cover a healthy 250-second first group followed by 200 seconds, the exact
480-second boundary, exhaustion before the next launch, over-budget results
and invalid clocks. No local SDK or native app runs. Case registrations are
unchanged.

Only Python controller/test code and documentation change. Flutter source,
tests, assets, dependencies and workflows remain byte-identical to Source737.
Its complete Dart/Linux validation retains that source; it is not relabeled
as a new full Linux run. The fresh Windows lane must run all current Python
controls before SDK allocation and the complete selected Dart groups before
building or capturing the app.

The [new readonly timing inspection](https://github.com/edgepillar/syrius/actions/runs/43490058468)
also passes at Source737, without new native execution or local binary
transport. Its unchanged dataset remains Source715, producer 43344313240.
Reported windows are 10.383 seconds current and 70.848 seconds P06. Build
durations stay below 16 ms; raster p95 is 122.751 ms current versus 39.430 ms
P06. These are reported-sample statistics from the old source, not a current
performance qualification or a hardware-cause finding. Both original timing
acceptance checks remain failed.

Accepted scope remains 76/80. V01, V02, V05 and V06 remain open. Four verified
Source736 Staking/Token PNGs await local review; no new visual match is
accepted, and the Source730 total remains 2/94. The original Docker/WSL route
is unqualified under the owner-approved native CI substitution.
