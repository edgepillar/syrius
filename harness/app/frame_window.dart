import 'dart:async';
import 'dart:ui' as ui;

typedef _Sample = ({
  int number,
  int start,
  int build,
  int raster,
  int total,
});

/// Fixed reasons the original collector cannot qualify a frame interval.
enum HarnessFrameWindowRefusal {
  /// Engine timings arrived out of order.
  frameOrder,

  /// The interval exceeded the bounded number of retained frames.
  frameLimit,

  /// One timing was outside the admitted bounds.
  frameTiming,

  /// The proposed interval or end was invalid.
  windowBounds,

  /// A later frame arrived, but the interval contained no samples.
  noFrames,
}

/// The interval does not contain a complete timing sample.
class HarnessFrameWindowRefused implements Exception {
  /// Reports an invalid or incomplete interval.
  const HarnessFrameWindowRefused(this.reason);

  /// The fixed rejection from the original collector.
  final HarnessFrameWindowRefusal reason;
}

/// Attributes batched engine timings to one bounded monotonic interval.
///
/// A sample beginning at or after the end confirms delivery of the preceding
/// reported timings on the same raster stream.
class HarnessFrameWindow {
  /// Begins collecting at a time on the engine's Dart timeline clock.
  HarnessFrameWindow(this._startUs);

  /// Keep an individual reply below the loopback transport limit.
  static const int maxFrames = 512;
  static const int _maxWindowUs = 60000000;

  final int _startUs;
  final List<_Sample> _samples = <_Sample>[];
  final Completer<void> _delivered = Completer<void>();
  int? _endUs;
  HarnessFrameWindowRefusal? _failure;

  /// Records only frames whose UI build began inside this window.
  void observe(List<ui.FrameTiming> timings) {
    if (_delivered.isCompleted) return;
    for (final ui.FrameTiming timing in timings) {
      final int start = timing.timestampInMicroseconds(
        ui.FramePhase.buildStart,
      );
      final int number = timing.frameNumber;
      if (number < 1 ||
          (_samples.isNotEmpty &&
              (number <= _samples.last.number ||
                  start < _samples.last.start))) {
        _refuse(HarnessFrameWindowRefusal.frameOrder);
        return;
      }
      if (start < _startUs) continue;
      final int? end = _endUs;
      if (end != null && start >= end) {
        _delivered.complete();
        return;
      }
      final int build = timing.buildDuration.inMicroseconds;
      final int raster = timing.rasterDuration.inMicroseconds;
      final int total = timing.totalSpan.inMicroseconds;
      if (_samples.length == maxFrames) {
        _refuse(HarnessFrameWindowRefusal.frameLimit);
        return;
      }
      if (start - _startUs >= _maxWindowUs ||
          build < 0 ||
          raster < 0 ||
          total < build + raster ||
          total > _maxWindowUs) {
        _refuse(HarnessFrameWindowRefusal.frameTiming);
        return;
      }
      _samples.add((
        number: number,
        start: start,
        build: build,
        raster: raster,
        total: total,
      ));
    }
  }

  void _refuse(HarnessFrameWindowRefusal reason) {
    _failure = reason;
    _delivered.complete();
  }

  /// Closes the interval and awaits an excluded post-window raster sample.
  Future<Map<String, Object?>> finish({
    required int endUs,
    required void Function() requestFrame,
  }) async {
    final int duration = endUs - _startUs;
    final HarnessFrameWindowRefusal? before = _failure;
    if (before != null) throw HarnessFrameWindowRefused(before);
    if (_endUs != null ||
        duration <= 0 ||
        duration > _maxWindowUs ||
        (_samples.isNotEmpty && _samples.last.start >= endUs)) {
      throw const HarnessFrameWindowRefused(
        HarnessFrameWindowRefusal.windowBounds,
      );
    }
    _endUs = endUs;
    requestFrame();
    await _delivered.future.timeout(const Duration(seconds: 4));
    final HarnessFrameWindowRefusal? after = _failure;
    if (after != null) throw HarnessFrameWindowRefused(after);
    if (_samples.isEmpty) {
      throw const HarnessFrameWindowRefused(
        HarnessFrameWindowRefusal.noFrames,
      );
    }
    final int first = _samples.first.number;
    return <String, Object?>{
      'schema': 1,
      'scope': 'harness_frame_window',
      'windowUs': duration,
      'frames': <List<int>>[
        for (final _Sample sample in _samples)
          <int>[
            sample.number - first,
            sample.start - _startUs,
            sample.build,
            sample.raster,
            sample.total,
          ],
      ],
    };
  }
}
