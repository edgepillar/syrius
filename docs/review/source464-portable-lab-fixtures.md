# Portable Linux lab fixture paths

Updated: 2026-11-05T00:43Z.

Source463's original focused run 41942346719 fails before SDK allocation with
fourteen controller errors. The finite failed-case list includes literal lab
resource/lifecycle tests; raw inner errors are not retained. The palette itself
has not run in that trial.

The pure fixture uses Linux Docker mount strings such as /fixture/assets, but
constructed the expected path with the current host's concrete Path class. On
Windows its string has backslashes. The unchanged Linux producer correctly
refuses that different source path; success fixtures and lifecycle subtests fail
before reaching their intended assertions.

A controlled lexical reproduction replaces the original test module's Path with
PureWindowsPath, forbids subprocess creation and runs all thirty existing tests.
It reproduces fourteen RESOURCE_CHANGED errors, including the four profile
subtests. This is a lexical fixture model, not local Windows or Docker execution.
It isolates the source issue without reconstructing missing original messages.

Source464 uses explicit PurePosixPath for all nine mocked Linux path constructors.
The existing positive container-binding case also requires a PureWindowsPath
asset argument to be refused with RESOURCE_CHANGED. Production container path
comparison, ownership, ports, IDs, normal-exit/no-OOM requirements, time/resource
bounds and the actual lab recipe are unchanged. No test is skipped or removed.

All thirty corrected local pure cases pass with subprocess creation forbidden,
zero failures/errors/skips and no filesystem scratch. All original method names
remain. Source463 palette/application bytes and existing Dart regressions are
unchanged. Fresh hosted focused qualification is pending: 1,063 controllers with
eighteen explicit Windows skips, fourteen assets, clean selected analysis and
1,230 ordinary cases in 48/48-file streams (597/633). The 1,232 asset variant
remains unselected. No full wallet, devnet, image or motion job is selected.

The earlier failed run stays failed. Source447 UI, Source459 Linux defaults and
Source461 component success/kernel failure retain their own pins. No visual match
or original acceptance row closes; 72/80 and heavy phase-two work remain open.
The PR stays Draft and public text remains English and privacy-safe.
