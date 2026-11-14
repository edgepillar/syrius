# Fractional palette scroll bounds

At d472893839300a5bb740e3e9d0026f67a488c672,
[Source748 full Linux 43562948240](https://github.com/edgepillar/syrius/actions/runs/43562948240)
passes the controller gate and every analysis step. The early Ready/window
gate reports one failure in the existing keyboard-scroll visibility case.
The selected row ends at 498.00000000000006 against a viewport ending at
498.0. The new icon-size and label-gap controls complete their eight declared
theme, direction and scale combinations without a failure.

The existing scroll assertions now use Flutter's pinned
[precisionErrorTolerance](https://github.com/flutter/flutter/blob/3.47.7/packages/flutter/lib/src/foundation/constants.dart)
of 1e-10 at both viewport edges. This accommodates accumulated double
round-off from fractional CSS row heights. The row must still fit inside its
viewport to that numerical tolerance; selected-item semantics, heading-aware
scrolling, query-reset behavior and scaled cases remain. Registrations and
every other assertion are unchanged.

Application code, the 38.3-pixel row, compact icon paths, border inset, query
and dispatch owners, workflows, native controllers and generated files retain
their exact Source748 bytes. No local SDK or native application executes.

The original Source748 run stays failed. Its Lock/Token gates, complete
directory and tracked-generation step are skipped, with zero artifacts. No
Windows producer is dispatched for that failed source. Bounded original logs
and exact head/job metadata are retained; the failed job is not retried.
Fresh full execution is required for this correction, followed by the
affected Home palette's Windows output.

[Source748's report](source748-palette-content-metrics.md) preserves the
executed Source747 Home result, eight pair reviews, closed owned image task
and independently retained Lock HTTP timeout. Earlier native and performance
failures retain their sources. Accepted scope stays 76/80 and accepted matches
2/94; V01, V02, V05 and V06 remain open. F06 retains Source722. The accepted
native Windows route does not qualify the original Docker/WSL route.
