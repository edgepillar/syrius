import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The asset the field is drawn by. Listed under `flutter: shaders:`.
const String kHeroFieldShader = 'assets/shaders/hero_field.frag';

/// A slow field of green, pink and blue light under the card colour: the
/// surface behind the Home hero.
///
/// The Home preset follows the reference's grouped gradients, blur and drift
/// through SDK shaders. Existing callers use the original fragment shader.
/// That shader fills its box and draws nothing until its program has
/// loaded, so the card is simply its own colour for the first frames. Put it
/// under the content in a `Stack`, inside the card's clip.
///
/// It repaints every frame while it is on screen, so it sits in its own
/// layer and takes nothing around it along. A hidden page, an unfocused
/// window or a frosted overlay holds the field on its current frame.
class HeroField extends StatefulWidget {
  /// Creates the field.
  const HeroField({this.strength, super.key}) : _referenceHome = false;

  /// The Home card's closest-side lights and eighteen-second alternate drift.
  const HeroField.home({super.key})
    : strength = null,
      _referenceHome = true;

  /// How far a light pulls the card colour at its centre, 0 to 1. Null
  /// takes the value for the theme: less on a white card, where the same
  /// pull reads as a stain.
  final double? strength;
  final bool _referenceHome;

  @override
  State<HeroField> createState() => _HeroFieldState();
}

class _HeroFieldState extends State<HeroField>
    with SingleTickerProviderStateMixin {
  late final ShaderClock _clock;
  final _HomeFieldRaster _raster = _HomeFieldRaster();

  @override
  void initState() {
    super.initState();
    _clock = ShaderClock(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.updateVisibility(context);
  }

  @override
  void didUpdateWidget(HeroField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._referenceHome != widget._referenceHome) {
      _clock.active = false;
      _raster.dispose();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _raster.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._referenceHome) {
      final AppTokens tokens = AppTokens.of(context);
      final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
      _clock.active = true;
      return RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            painter: _HomeHeroFieldPainter(
              seconds: _clock,
              base: tokens.card,
              green: tokens.znn,
              blue: tokens.qsr,
              pink: tokens.pink,
              raster: _raster,
              pixelRatio: pixelRatio,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return RepaintBoundary(
      child: ShaderBuilder(
        assetKey: kHeroFieldShader,
        (BuildContext context, ui.FragmentShader shader, Widget? child) {
          // An unavailable shader has no frames worth scheduling.
          _clock.active = true;
          return CustomPaint(
            painter: _HeroFieldPainter(
              shader: shader,
              seconds: _clock,
              // The card colour, as `Panel` paints it.
              base: theme.colorScheme.primary,
              strength: widget.strength ?? (dark ? 0.16 : 0.07),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

typedef _HomeRasterKey = ({
  Rect field,
  Color green,
  Color blue,
  Color pink,
  double pixelRatio,
});

// One bounded image holds the Home lights; the original clock moves it.
// Its owner retires it on geometry/colour/DPR replacement and unmount.
class _HomeFieldRaster {
  static const int _maxPixels = 16 * 1024 * 1024;
  static const int _maxSide = 8192;
  _HomeRasterKey? _key;
  ui.Image? _image;

  ui.Image? imageFor(Rect field, {
    required Color green, required Color blue, required Color pink,
    required double pixelRatio,
  }) {
    final Rect bounds = field.inflate(120);
    final double width = bounds.width * pixelRatio;
    final double height = bounds.height * pixelRatio;
    if (!pixelRatio.isFinite || pixelRatio <= 0 ||
        !width.isFinite || !height.isFinite || width <= 0 || height <= 0 ||
        width > _maxSide || height > _maxSide) {
      dispose();
      return null;
    }
    final int pixelsWide = width.ceil();
    final int pixelsHigh = height.ceil();
    if (pixelsWide * pixelsHigh > _maxPixels) {
      dispose();
      return null;
    }
    final _HomeRasterKey key = (
      field: field, green: green, blue: blue, pink: pink,
      pixelRatio: pixelRatio,
    );
    if (_key == key) return _image;
    dispose();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-bounds.left, -bounds.top);
    _HomeHeroFieldPainter._paintBlurredField(
      canvas, field, green: green, blue: blue, pink: pink,
    );
    final ui.Picture picture = recorder.endRecording();
    try {
      // The engine rasterizes this handle asynchronously. Creation is
      // part of the first original paint, with no extra warm-up or clock.
      final ui.Image image = picture.toImageSync(pixelsWide, pixelsHigh);
      _image = image;
      _key = key;
      return image;
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _key = null;
  }
}

class _HomeHeroFieldPainter extends CustomPainter {
  _HomeHeroFieldPainter({
    required this.seconds,
    required this.base,
    required this.green,
    required this.blue,
    required this.pink,
    required this.raster,
    required this.pixelRatio,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final Color base;
  final Color green;
  final Color blue;
  final Color pink;
  final _HomeFieldRaster raster;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      raster.dispose();
      return;
    }
    final Rect viewport = Offset.zero & size;
    canvas.drawRect(viewport, Paint()..color = base);
    // CSS inset percentages use the card; translation uses the enlarged field.
    final Rect field = Rect.fromLTWH(
      -size.width * 0.4,
      -size.height * 0.4,
      size.width * 1.8,
      size.height * 1.8,
    );
    final double leg = (seconds.value % 36) / 18;
    final double progress = Curves.easeInOut.transform(
      leg <= 1 ? leg : 2 - leg,
    );
    final Offset center = field.center;
    canvas
      ..save()
      ..clipRect(viewport)
      ..translate(
        center.dx + field.width * (-0.03 + 0.06 * progress),
        center.dy + field.height * (-0.02 + 0.04 * progress),
      )
      ..rotate(math.pi / 30 * progress)
      ..translate(-center.dx, -center.dy);
    final ui.Image? image = raster.imageFor(
      field, green: green, blue: blue, pink: pink, pixelRatio: pixelRatio,
    );
    if (image == null) {
      // Oversized surfaces retain the original full-resolution paint.
      _paintBlurredField(canvas, field, green: green, blue: blue, pink: pink);
    } else {
      final Rect bounds = field.inflate(120);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(bounds.left, bounds.top,
          image.width / pixelRatio, image.height / pixelRatio),
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    canvas.restore();
  }

  static void _paintBlurredField(Canvas canvas, Rect field, {
    required Color green, required Color blue, required Color pink,
  }) {
    // Keep the original grouped blur and opacity above the separate card base.
    canvas.saveLayer(
      field.inflate(120),
      Paint()
        ..color = const Color.fromRGBO(255, 255, 255, 0.55)
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 40,
          sigmaY: 40,
          tileMode: ui.TileMode.decal,
        ),
    );
    // The first CSS background is painted over the later backgrounds.
    _light(canvas, field, pink, const Offset(0.5, 0.9), 0.38);
    _light(canvas, field, blue, const Offset(0.7, 0.6), 0.45);
    _light(canvas, field, green, const Offset(0.3, 0.4), 0.45);
    canvas.restore();
  }

  static void _light(
    Canvas canvas,
    Rect field,
    Color color,
    Offset position,
    double opacity,
  ) {
    final Offset center = Offset(
      field.left + field.width * position.dx,
      field.top + field.height * position.dy,
    );
    final double radiusX = math.min(
      center.dx - field.left, field.right - center.dx,
    );
    final double radiusY = math.min(
      center.dy - field.top, field.bottom - center.dy,
    );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(radiusX, radiusY)
      ..drawRect(
        Rect.fromLTRB(
          (field.left - center.dx) / radiusX,
          (field.top - center.dy) / radiusY,
          (field.right - center.dx) / radiusX,
          (field.bottom - center.dy) / radiusY,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            <Color>[
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HomeHeroFieldPainter old) =>
      old.seconds != seconds || old.base != base || old.green != green ||
      old.blue != blue || old.pink != pink || old.raster != raster ||
      old.pixelRatio != pixelRatio;
}

class _HeroFieldPainter extends CustomPainter {
  _HeroFieldPainter({
    required this.shader,
    required this.seconds,
    required this.base,
    required this.strength,
  }) : super(repaint: seconds);

  final ui.FragmentShader shader;
  final ValueListenable<double> seconds;
  final Color base;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    // Floats in the order the shader declares them; a vec3 takes three.
    int i = 0;
    void rgb(Color color) {
      shader
        ..setFloat(i++, color.r)
        ..setFloat(i++, color.g)
        ..setFloat(i++, color.b);
    }

    shader
      ..setFloat(i++, size.width) // u_size
      ..setFloat(i++, size.height)
      ..setFloat(i++, seconds.value); // u_time
    rgb(base); // u_base
    rgb(AppColors.znnColor); // u_a
    rgb(AppColors.plasmaPink); // u_b
    rgb(AppColors.qsrColor); // u_c
    shader.setFloat(i++, strength); // u_strength
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_HeroFieldPainter old) =>
      old.base != base || old.strength != strength || old.shader != shader;
}
