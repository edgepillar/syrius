import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  HarnessFrameWindow(this._startUs, {this._packed = false});

  /// Maximum samples in the ordinary JSON reply.
  static const int maxFrames = 512;

  /// Maximum samples in the lossless paired launch reply.
  static const int maxPackedFrames = 4096;
  static const int _maxWindowUs = 60000000;
  static const int _maxPackedWindowUs = 120000000;
  static const int _packedRowBytes = 20;

  final int _startUs;
  final bool _packed;
  int get _windowLimitUs => _packed ? _maxPackedWindowUs : _maxWindowUs;
  final List<_Sample> _samples = <_Sample>[];
  final Completer<void> _delivered = Completer<void>();
  int? _endUs;
  HarnessFrameWindowRefusal? _failure;

  /// Records only frames whose UI build began inside this window.
  void observe(List<ui.FrameTiming> timings) {
    if (_delivered.isCompleted) return;
    final int capacity = _packed ? maxPackedFrames : maxFrames;
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
      if (_samples.length == capacity) {
        _refuse(HarnessFrameWindowRefusal.frameLimit);
        return;
      }
      if (start - _startUs >= _windowLimitUs ||
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
        duration > _windowLimitUs ||
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
    if (_packed) return _packedReceipt(duration, first);
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

  Map<String, Object?> _packedReceipt(int duration, int first) {
    if (_samples.last.number - first > 0xffffffff) {
      throw const HarnessFrameWindowRefused(
        HarnessFrameWindowRefusal.frameTiming,
      );
    }
    // Preserve the five original values in little-endian unsigned words.
    final ByteData rows = ByteData(_samples.length * _packedRowBytes);
    int offset = 0;
    for (final _Sample sample in _samples) {
      rows
        ..setUint32(offset, sample.number - first, Endian.little)
        ..setUint32(offset + 4, sample.start - _startUs, Endian.little)
        ..setUint32(offset + 8, sample.build, Endian.little)
        ..setUint32(offset + 12, sample.raster, Endian.little)
        ..setUint32(offset + 16, sample.total, Endian.little);
      offset += _packedRowBytes;
    }
    return <String, Object?>{
      'schema': 2,
      'scope': 'harness_frame_window',
      'windowUs': duration,
      'frameCount': _samples.length,
      'packedFrames': base64Encode(zlib.encode(rows.buffer.asUint8List())),
    };
  }
}
