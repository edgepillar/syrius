// Makes the texture the plasma glow shader reads
// (assets/shaders/heatmap.frag): the Syrius plasma bolt, pre-blurred.
//
//   dart run tool/heatmap_texture.dart                 writes the asset
//   dart run tool/heatmap_texture.dart --inspect <png> prints sample pixels
//
// The shader cannot blur at run time, so the blur is baked into the channels
// of one image, as Paper's `toProcessedHeatmap` does for the shader this one
// is ported from (paper-design/shaders, heatmap.ts):
//   R  silhouette coverage: 0 inside the mark, 1 outside
//   G  the shape under a wide blur: drives the inner and outer glow
//   B  the shape under a tight blur: the hot contour at the edge
// The square texture keeps the original blur radii and padding.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The Plasma and Fuse mockups use M13 2 4 14h7l-1 8 9-12h-7z.
const List<List<double>> _bolt = <List<double>>[
  <double>[13, 2],
  <double>[4, 14],
  <double>[11, 14],
  <double>[10, 22],
  <double>[19, 10],
  <double>[12, 10],
];

const int _rasterBase = 512;
const int _slotSize = 120;

void main(List<String> args) {
  if (args.length == 2 && args[0] == '--inspect') {
    _inspect(args[1]);
    return;
  }
  final int maxBlur = (_rasterBase * 0.15).floor();
  final int padding = (maxBlur * 2.5).ceil();
  final int size = _rasterBase + 2 * padding;
  final List<List<double>> polygon = _boltOutline(size);

  final Uint8List gray = Uint8List(size * size);
  const int samples = 4;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int inside = 0;
      for (int sy = 0; sy < samples; sy++) {
        for (int sx = 0; sx < samples; sx++) {
          if (_contains(
            polygon,
            x + (sx + 0.5) / samples,
            y + (sy + 0.5) / samples,
          )) {
            inside++;
          }
        }
      }
      // White ground, black mark, as the source image is for Paper.
      gray[y * size + x] = 255 - (255 * inside / (samples * samples)).round();
    }
  }

  final Uint8List wide = _blur(gray, size, size, maxBlur, 3);
  final Uint8List contour = _blur(gray, size, size, 5, 1);
  // Integrate the silhouette over roughly one pixel at the authored slot
  // size. A point sample of the unfiltered mask fills the narrow miter tips.
  final int coverageRadius = (size / (2 * _slotSize)).floor();
  final Uint8List coverage = _blur(gray, size, size, coverageRadius, 1);

  final img.Image out = img.Image(width: size, height: size, numChannels: 4);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int i = y * size + x;
      out.setPixelRgba(x, y, coverage[i], wide[i], contour[i], 255);
    }
  }
  final File file = File('assets/images/plasma_heatmap.png')
    ..writeAsBytesSync(img.encodePng(out));
  stdout.writeln('${file.path}: ${size}x$size, ${file.lengthSync()} bytes');
}

List<List<double>> _boltOutline(int textureSize) {
  // The 24-unit SVG is 54 px square in the reference's 120 px slots.
  final double scale = textureSize * 54 / (_slotSize * 24);
  final double offset = (textureSize - 24 * scale) / 2;
  final List<List<double>> outline = <List<double>>[];
  for (int i = 0; i < _bolt.length; i++) {
    final List<double> point = _bolt[i];
    final (double ax, double ay) =
        _leftNormal(_bolt[(i + _bolt.length - 1) % _bolt.length], point);
    final (double bx, double by) =
        _leftNormal(point, _bolt[(i + 1) % _bolt.length]);
    // Expand the filled polygon by the reference's 1-unit miter stroke.
    // All six joins fit inside the SVG default miter limit.
    final double extension = 0.5 / (1 + ax * bx + ay * by);
    outline.add(<double>[
      offset + (point[0] + (ax + bx) * extension) * scale,
      offset + (point[1] + (ay + by) * extension) * scale,
    ]);
  }
  return outline;
}

(double, double) _leftNormal(List<double> start, List<double> end) {
  final double dx = end[0] - start[0];
  final double dy = end[1] - start[1];
  final double length = math.sqrt(dx * dx + dy * dy);
  return (-dy / length, dx / length);
}

bool _contains(List<List<double>> polygon, double x, double y) {
  bool inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final double xi = polygon[i][0];
    final double yi = polygon[i][1];
    final double xj = polygon[j][0];
    final double yj = polygon[j][1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// A box blur over an integral image, [passes] times; three passes come
/// close to a Gaussian.
Uint8List _blur(Uint8List gray, int width, int height, int radius, int passes) {
  Uint8List input = gray;
  for (int p = 0; p < passes; p++) {
    final Uint8List out = Uint8List(width * height);
    final Uint32List integral = Uint32List(width * height);
    for (int y = 0; y < height; y++) {
      int row = 0;
      for (int x = 0; x < width; x++) {
        final int i = y * width + x;
        row += input[i];
        integral[i] = row + (y > 0 ? integral[i - width] : 0);
      }
    }
    for (int y = 0; y < height; y++) {
      final int y1 = y - radius < 0 ? 0 : y - radius;
      final int y2 = y + radius > height - 1 ? height - 1 : y + radius;
      for (int x = 0; x < width; x++) {
        final int x1 = x - radius < 0 ? 0 : x - radius;
        final int x2 = x + radius > width - 1 ? width - 1 : x + radius;
        final int a = integral[y2 * width + x2];
        final int b = x1 > 0 ? integral[y2 * width + x1 - 1] : 0;
        final int c = y1 > 0 ? integral[(y1 - 1) * width + x2] : 0;
        final int d = x1 > 0 && y1 > 0
            ? integral[(y1 - 1) * width + x1 - 1]
            : 0;
        final int area = (x2 - x1 + 1) * (y2 - y1 + 1);
        out[y * width + x] = ((a - b - c + d) / area).round();
      }
    }
    input = out;
  }
  return input;
}

void _inspect(String path) {
  final img.Image image = img.decodePng(File(path).readAsBytesSync())!;
  stdout.writeln('$path: ${image.width}x${image.height}');
  for (final List<double> at in <List<double>>[
    <double>[0.5, 0.5],
    <double>[0.5, 0.4],
    <double>[0.3, 0.5],
    <double>[0.2, 0.2],
    <double>[0.02, 0.02],
  ]) {
    final img.Pixel p = image.getPixel(
      (at[0] * image.width).floor(),
      (at[1] * image.height).floor(),
    );
    stdout.writeln(
      '  at ${at[0]},${at[1]}: r=${p.r} g=${p.g} b=${p.b} a=${p.a}',
    );
  }
}
