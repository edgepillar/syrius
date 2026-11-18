import 'dart:math' as math;
import 'dart:ui';

/// The extent of the reference drift along the field's horizontal axis.
const double fieldDriftX = 0.03;

/// The extent of the reference drift along the field's vertical axis.
const double fieldDriftY = 0.02;

/// The final rotation of a forward leg of the reference drift.
const double fieldDriftAngle = math.pi / 30;

/// An image's bounded device-pixel dimensions and its logical origin.
typedef DriftRasterRegion = ({Offset origin, int width, int height});

/// Encloses all visible samples and the blur margin at every drift phase.
///
/// Aligns the crop to the full image's original pixel grid. An out-of-range
/// allocation leaves the caller's analytic paint available.
DriftRasterRegion? driftRasterRegion({
  required Rect viewport,
  required Rect field,
  required double blurBleed,
  required double pixelRatio,
}) {
  const int maxPixels = 16 * 1024 * 1024;
  const int maxSide = 8192;
  if (!viewport.isFinite || viewport.isEmpty ||
      !field.isFinite || field.isEmpty ||
      !blurBleed.isFinite || blurBleed < 0) {
    return null;
  }
  final Rect full = field.inflate(blurBleed);
  if (!pixelRatio.isFinite || pixelRatio <= 0 ||
      !(full.width * pixelRatio).isFinite ||
      !(full.height * pixelRatio).isFinite) {
    return null;
  }
  // The caption can extend the viewport above the field's center.
  final Offset offset = viewport.center - field.center;
  final double halfWidth =
      viewport.width / 2 + offset.dx.abs() + field.width * fieldDriftX;
  final double halfHeight =
      viewport.height / 2 + offset.dy.abs() + field.height * fieldDriftY;
  final double sine = math.sin(fieldDriftAngle);
  final Rect crop = Rect.fromCenter(
    center: field.center,
    width: 2 * (halfWidth + sine * halfHeight),
    height: 2 * (halfHeight + sine * halfWidth),
  ).inflate(blurBleed).intersect(full);
  if (!crop.isFinite || crop.isEmpty) return null;
  final int left = ((crop.left - full.left) * pixelRatio).floor();
  final int top = ((crop.top - full.top) * pixelRatio).floor();
  final int right = ((crop.right - full.left) * pixelRatio).ceil();
  final int bottom = ((crop.bottom - full.top) * pixelRatio).ceil();
  final int width = right - left;
  final int height = bottom - top;
  if (width <= 0 || height <= 0 || width > maxSide || height > maxSide ||
      width * height > maxPixels) {
    return null;
  }
  return (
    origin: full.topLeft + Offset(left / pixelRatio, top / pixelRatio),
    width: width,
    height: height,
  );
}
