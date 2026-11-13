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

Source724 requires fresh full Linux analysis/tests and a Windows Ready
capture with independent original-archive verification. Those runs are
pending at publication. The existing bounded layout, scaled RTL, copy and
once-only opening tests remain the behavioral checks; no additional test is
registered for this presentation change.

The repeated local inspection reused the already verified archive. Recording
and closing its managed review task encountered metadata contention. That
failure is retained separately from the actual image observations; it is not
reported as a successful managed execution or a reason to repeat transport.

V01 remains in review with zero accepted whole-image matches. The F06 audit
retains its Source722 qualification. Original progress remains 74/80, with
P03, P09, V01, V02, V05 and V06 open.
