# Compile the readonly wallet before lab startup

Updated 2026-11-13.

Source719's [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43365837667)
passes. Its [Windows attempt](https://github.com/edgepillar/syrius/actions/runs/43366040425)
passes strict analysis, 1,480 selected Dart cases and 1,214 Python cases with
eighteen skips, then fails production revalidation before wallet input.
The [independent reader](https://github.com/edgepillar/syrius/actions/runs/43368622856)
passes 123 cases and verifies 88 producer files, zero PNGs, five normal node
exits and required application actor forced cleanup. No aged-fuse witness is
reached. The original failure remains a failure.

The pinned node's [worker condition](https://github.com/zenon-network/go-zenon/blob/2d1b929cc3fa5269cf133757d4a6963821137984/pillar/worker.go#L110)
suppresses a momentum broadcast after the producer event's start plus three
seconds. The compiled lab patch changes only a closed-task check in
`pillar/manager.go`. Failed-broadcast log events therefore identify this
source condition, without establishing its underlying cause, generation
duration or an accepted chain height.

Source720 changes scheduling in the readonly inspection controller. The same
original Dart child completes the release build, emits one fixed completion
marker and waits. Its owner then starts the five original lab nodes and runs
the unchanged initial production observation. Only a current source, live
owned child and positive lab observation release application startup. The
fresh pre-input production revalidation remains mandatory. A failed lab
admission closes the waiting child's input before owned job cleanup.

The closed receipt records build completion, lab start attempt, initial
production observation and application release attempt in that order. The
reader retains it without granting additional qualification. Legacy archives
keep their earlier scope. Finite controls cover the pending child, exact
handshake, replaced owners/source, failed production and refused replay. Seven
selected Python controls pass locally using memory fixtures, without launching
an SDK, node or native wallet or using the network.

This removes compile/node overlap as a potential source of contention; it is
not a proven fix for Source719's failure. Fresh full Linux, Windows and
original-archive verification remain necessary. Node deadlines, genesis,
publication guards, storage limits and the 16 ms comparison are unchanged.
Original acceptance remains 73/80, with zero accepted whole-image matches.
