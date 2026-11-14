# Transition end sample and following frame

The pinned Flutter interpolation simulation returns its target value at the
duration boundary and reports completion only after that boundary. See the
[Flutter 3.47.7 implementation](https://raw.githubusercontent.com/flutter/flutter/3.47.7/packages/flutter/lib/src/animation/animation_controller.dart).
A transition-completion future and controller status can therefore require
the following frame even after the sampled end value is reached.

The four existing framed Bell variants retain their two 120 ms samples.
They now explicitly require the original 240 ms reverse duration and a zero
end value at that boundary, then advance one sixteen-millisecond harness
frame for dismissal and portal disposal before the unchanged completion,
absence, input and focus assertions. The Node collection case retains both
500 ms samples and adds the same following-frame flush before its existing
idle-state and identity checks. No duration or assertion is removed.

These are test-clock corrections based on the pinned SDK contract, not a
new native result or a physical refresh-rate claim. Application, workflows,
282-file strict selection, six Python notice cases and all test registrations
remain unchanged. No Source771 hosted run was dispatched; its source-review
cascade correction and this frame correction will share one full Linux run.

## Retained boundary

[Source770 full Linux 43652104173](https://github.com/edgepillar/syrius/actions/runs/43652104173)
retains one strict info and five skipped widget/generation stages, with its
bounded source-location notice consumed. The original code remains opaque;
the Source771 cascade is a source-review interpretation. No full log or
binary transfer was needed. Older failures remain preserved.

Fresh full Linux must execute the combined Bell/frame and Source770 control
metrics before native/image work. Current native/image evidence remains
Source765. Accepted scope stays 76/80 and accepted Source730 Ready pairs
stay 2/94. V01/V06 remain in review; V02/V05 remain blocked. No new image or
performance pass is established.
