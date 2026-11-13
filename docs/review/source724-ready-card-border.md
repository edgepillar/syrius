# Ready card border geometry

Updated 2026-11-13.

The two original Source717 Ready captures were individually compared with
their references again. Their card is slightly shorter and its action is
slightly wider. Text baselines, address rendering and the light shadow retain
visible differences. The captures remain bound to
`cbf77124ebc4128b45165b029d643cd85d774a92`, its
[Windows producer](https://github.com/edgepillar/syrius/actions/runs/43356581345)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43359191086).
The application source is unchanged between that revision and Source723.

## Change

The reference's 540 px card includes its one-pixel border outside its
32/26/32/24 px content padding. The Flutter `DecoratedBox` painted that border
without reserving its space. Source724 uses `Container` for the same bordered
surface, allowing the decoration's border inset to participate in layout.
The expected result is two additional pixels of card height and two fewer
pixels of inner action width. The card remains centered and its content can
still scroll in a short window.

The existing address binding, original map animation, localized text and
once-only opening/copy callbacks keep their existing implementation. The
owner-selected `#00D557` / `#0061EB` colors still apply. Font hinting, the
runtime address and animation phase require their existing comparison scope.

## Validation

The [full Linux workflow](https://github.com/edgepillar/syrius/actions/runs/43390950742),
[Ready Windows producer](https://github.com/edgepillar/syrius/actions/runs/43392824160)
and [independent reader](https://github.com/edgepillar/syrius/actions/runs/43396117591)
pass at `1e8e808b949a4828127c517f44140ac2e154ca79`. Full Linux analysis,
the non-chain test directory and tracked generation pass. Windows has zero
selected analysis findings, 1,481 selected Dart passes and 1,218 Python cases
with eighteen skips. The reader passes 123 cases and verifies both PNGs.
Required application actors and five original nodes close normally; separate
MSVC telemetry cleanup is retained with zero remaining helpers.

The existing bounded layout, scaled RTL, copy and once-only opening tests
remain the behavioral checks; no additional test is registered for this
presentation change.

Both new PNG/reference pairs were individually viewed. Card bounds and the
action width now align visually. The map's captured animation frame and text
rendering still differ, as do the light glass/shadow treatment. The prompt
allows example addresses and font hinting, but still requires animation-frame
agreement. Zero whole-image matches are accepted. The existing bounded
artwork sampler covers the Welcome globe and entry field; it does not sample
the Ready map.

The repeated local inspection reused the already verified archive. Recording
and closing its managed review task encountered metadata contention. That
failure is retained separately from the actual image observations; it is not
reported as a successful managed execution or a reason to repeat transport.
That earlier task was subsequently reconciled and closed as FAILURE. The
new Source724 archive inspection closes successfully, retaining its one
verified archive and removing only its registered disposable scratch. The
existing storage policy and original ownership hold are preserved.

The separate [Staking/Token attempt](source724-staking-reopen-observe.md)
stops at copied-session observation before its seed prerequisites and PNGs.
Its failure remains separate from the successful Ready capture.

V01 remains in review with zero accepted whole-image matches. The F06 audit
retains its Source722 qualification. Original progress remains 74/80, with
P03, P09, V01, V02, V05 and V06 open.
