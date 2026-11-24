import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show ContainerLayer, Layer, PictureLayer;

/// Reads picture identities from a painted scene without building a new scene.
///
/// At most 4,096 layers are visited. The identities stay inside the harness
/// and describe only the two observed scenes, including any retained paint.
Set<ui.Picture>? captureFramePictures(Layer? root) {
  if (root == null) return null;
  final Set<ui.Picture> pictures = Set<ui.Picture>.identity();
  final List<Layer> pending = <Layer>[root];
  int visited = 0;
  while (pending.isNotEmpty) {
    if (++visited > 4096) return null;
    final Layer current = pending.removeLast();
    final Layer? sibling = identical(current, root)
        ? null
        : current.nextSibling;
    if (sibling != null) pending.add(sibling);
    if (current is ContainerLayer) {
      final Layer? first = current.firstChild;
      if (first != null) pending.add(first);
    }
    if (current is PictureLayer) {
      final ui.Picture? picture = current.picture;
      if (picture != null) pictures.add(picture);
    }
  }
  return pictures;
}

/// Counts shared pictures without returning layer or picture identities.
Map<String, int>? retainedFramePictures(
  Set<ui.Picture>? before,
  Set<ui.Picture>? after,
) => before == null || after == null
    ? null
    : <String, int>{
        'before': before.length,
        'after': after.length,
        'shared': after.where(before.contains).length,
      };

typedef _Sample = ({
  int number,
  int start,
  int build,
  int raster,
  int rasterStart,
  int total,
  int waitForBuild,
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
  ///
  /// Interactive measurements retain raster starts and the longest frame's
  /// wait before build on the engine clock. `retainRasterStarts` adds exact
  /// raster starts to packed receipts with at most [maxFrames] samples.
  HarnessFrameWindow(
    this._startUs, {
    this._packed = false,
    this._retainRasterStarts = false,
    this._includeInteractiveDiagnostics = false,
  });

  /// Maximum samples in the ordinary JSON reply.
  static const int maxFrames = 512;

  /// Maximum samples in the lossless paired launch reply.
  static const int maxPackedFrames = 4096;
  static const int _maxWindowUs = 60000000;
  static const int _maxPackedWindowUs = 120000000;
  static const int _packedRowBytes = 20;

  final int _startUs;
  final bool _packed;
  final bool _retainRasterStarts;
  final bool _includeInteractiveDiagnostics;
  int get _windowLimitUs => _packed ? _maxPackedWindowUs : _maxWindowUs;
  final List<_Sample> _samples = <_Sample>[];
  final Completer<void> _delivered = Completer<void>();
  int? _endUs;
  HarnessFrameWindowRefusal? _failure;
  int _peakRasterUs = -1;
  Map<String, int>? _peakRasterCache;

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
      final int waitForBuild = _includeInteractiveDiagnostics
          ? start - timing.timestampInMicroseconds(ui.FramePhase.vsyncStart)
          : 0;
      if (_samples.length == capacity) {
        _refuse(HarnessFrameWindowRefusal.frameLimit);
        return;
      }
      if (start - _startUs >= _windowLimitUs ||
          build < 0 ||
          raster < 0 ||
          waitForBuild < 0 ||
          total < build + raster + waitForBuild ||
          total > _maxWindowUs) {
        _refuse(HarnessFrameWindowRefusal.frameTiming);
        return;
      }
      if (_includeInteractiveDiagnostics && raster > _peakRasterUs) {
        _peakRasterUs = raster;
        final int layers = timing.layerCacheCount;
        final int layerBytes = timing.layerCacheBytes;
        final int pictures = timing.pictureCacheCount;
        final int pictureBytes = timing.pictureCacheBytes;
        _peakRasterCache =
            layers >= 0 && layers < 1 << 32 &&
            pictures >= 0 && pictures < 1 << 32 &&
            layerBytes >= 0 && layerBytes <= 1 << 40 &&
            pictureBytes >= 0 && pictureBytes <= 1 << 40
            ? <String, int>{
                'frame': number,
                'layer_count': layers,
                'layer_bytes': layerBytes,
                'picture_count': pictures,
                'picture_bytes': pictureBytes,
              }
            : null;
      }
      _samples.add((
        number: number,
        start: start,
        build: build,
        raster: raster,
        rasterStart: _includeInteractiveDiagnostics || _retainRasterStarts
            ? timing.timestampInMicroseconds(ui.FramePhase.rasterStart)
            : 0,
        total: total,
        waitForBuild: waitForBuild,
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
      if (_includeInteractiveDiagnostics)
        'peakBuildWaitUs': _samples
            .reduce((_Sample a, _Sample b) => a.total >= b.total ? a : b)
            .waitForBuild,
      if (_includeInteractiveDiagnostics)
        'rasterStartsUs': <int>[
          for (final _Sample sample in _samples) sample.rasterStart - _startUs,
        ],
      if (_peakRasterCache case final Map<String, int> peak)
        'rasterCacheAtPeak': <String, int>{
          ...peak,
          'frame': peak['frame']! - first,
        },
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
      if (_retainRasterStarts && _samples.length <= maxFrames)
        'rasterStartsUs': <int>[
          for (final _Sample sample in _samples) sample.rasterStart - _startUs,
        ],
    };
  }
}
