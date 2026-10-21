// Makes the texture the plasma glow shader reads
// (assets/shaders/heatmap.frag): the Syrius plasma bolt, pre-blurred.
//
//   dart run tool/heatmap_texture.dart                 writes the asset
//   dart run tool/heatmap_texture.dart --inspect <png> prints sample pixels
//
// The shader cannot blur at run time, so the blur is baked into the channels
// of one image, as Paper's `toProcessedHeatmap` does for the shader this one
// is ported from (paper-design/shaders, heatmap.ts):
//   R  the shape itself: 0 inside the mark, 1 outside
//   G  the shape under a wide blur: drives the inner and outer glow
//   B  the shape under a tight blur: the hot contour at the edge
// The sizes follow the same proportions (blur 15% of the mark, padding 2.5
// blurs), on a square canvas so the widget can be square.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Material Design Icons' lightning-bolt, the bolt Syrius uses for plasma,
/// on its 24 unit grid: M11 15H6L13 1V9H18L11 23V15Z.
const List<List<double>> _bolt = <List<double>>[
  <double>[11, 15],
  <double>[6, 15],
  <double>[13, 1],
  <double>[13, 9],
  <double>[18, 9],
  <double>[11, 23],
];

const int _mark = 512;

void main(List<String> args) {
  if (args.length == 2 && args[0] == '--inspect') {
    _inspect(args[1]);
    return;
  }
  final int maxBlur = (_mark * 0.15).floor();
  final int padding = (maxBlur * 2.5).ceil();
  final int size = _mark + 2 * padding;

  // The bolt, centred, as tall as the mark area.
  final double scale = _mark / 22; // the path spans y 1..23
  final double offsetX = padding + (_mark - 12 * scale) / 2 - 6 * scale;
  final double offsetY = padding - 1 * scale;
  final List<List<double>> polygon = <List<double>>[
    for (final List<double> p in _bolt)
      <double>[p[0] * scale + offsetX, p[1] * scale + offsetY],
  ];

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

  final img.Image out = img.Image(width: size, height: size, numChannels: 4);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int i = y * size + x;
      out.setPixelRgba(x, y, gray[i], wide[i], contour[i], 255);
    }
  }
  final File file = File('assets/images/plasma_heatmap.png')
    ..writeAsBytesSync(img.encodePng(out));
  stdout.writeln('${file.path}: ${size}x$size, ${file.lengthSync()} bytes');
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
