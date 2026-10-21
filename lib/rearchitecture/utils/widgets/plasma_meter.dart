import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// The asset the meter's fill is drawn by. Listed under `flutter: shaders:`.
const String kPlasmaFlowShader = 'assets/shaders/plasma_flow.frag';

/// A bar that fills with a share of plasma, with light moving through the
/// fill, and that moves to a new level instead of jumping to it.
///
/// The fill is QSR's brand blue in both themes; the light in it is tinted
/// with the plasma pink. Until the shader has loaded, and wherever it cannot
/// load, the bar is the same fill painted flat: the level is information and
/// must never wait for an ornament.
///
/// The light repaints every frame while the bar is on screen, inside its
/// own layer. Its ticker follows `TickerMode`, so a page that is not shown
/// does not run it.
class PlasmaMeter extends StatefulWidget {
  /// Creates a meter filled to [value], 0 to 1.
  const PlasmaMeter({
    required this.value,
    required this.trackColor,
    this.height = 6,
    super.key,
  });

  /// The level, 0 to 1.
  final double value;

  /// The bar behind the fill.
  final Color trackColor;

  /// The bar's thickness. Its ends are rounded to half of it.
  final double height;

  @override
  State<PlasmaMeter> createState() => _PlasmaMeterState();
}

class _PlasmaMeterState extends State<PlasmaMeter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection direction = Directionality.of(context);
    return Semantics(
      value: '${(widget.value.clamp(0, 1) * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.value.clamp(0, 1).toDouble()),
        duration: Durations.long2,
        curve: Easing.emphasizedDecelerate,
        builder: (BuildContext context, double value, Widget? child) {
          Widget bar(ui.FragmentShader? shader) => CustomPaint(
            painter: _PlasmaMeterPainter(
              shader: shader,
              seconds: _seconds,
              value: value,
              trackColor: widget.trackColor,
              direction: direction,
            ),
            child: SizedBox(height: widget.height, width: double.infinity),
          );
          return RepaintBoundary(
            child: ShaderBuilder(
              assetKey: kPlasmaFlowShader,
              (BuildContext context, ui.FragmentShader shader, Widget? child) =>
                  bar(shader),
              child: bar(null),
            ),
          );
        },
      ),
    );
  }
}

class _PlasmaMeterPainter extends CustomPainter {
  _PlasmaMeterPainter({
    required this.shader,
    required this.seconds,
    required this.value,
    required this.trackColor,
    required this.direction,
  }) : super(repaint: shader == null ? null : seconds);

  /// Null until the shader has loaded: the bar is then painted flat.
  final ui.FragmentShader? shader;
  final ValueNotifier<double> seconds;
  final double value;
  final Color trackColor;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect bar = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final ui.FragmentShader? shader = this.shader;
    if (shader == null) {
      final double width = size.width * value;
      final Rect fill = direction == TextDirection.ltr
          ? Rect.fromLTWH(0, 0, width, size.height)
          : Rect.fromLTWH(size.width - width, 0, width, size.height);
      canvas
        ..save()
        ..clipRRect(bar)
        ..drawRect(Offset.zero & size, Paint()..color = trackColor)
        ..drawRect(fill, Paint()..color = AppColors.qsrColor)
        ..restore();
      return;
    }
    // Floats in the order the shader declares them.
    int i = 0;
    shader
      ..setFloat(i++, size.width) // u_size
      ..setFloat(i++, size.height)
      ..setFloat(i++, seconds.value) // u_time
      ..setFloat(i++, value) // u_fill
      ..setFloat(i++, direction == TextDirection.ltr ? 1 : -1) // u_dir
      ..setFloat(i++, AppColors.qsrColor.r) // u_base
      ..setFloat(i++, AppColors.qsrColor.g)
      ..setFloat(i++, AppColors.qsrColor.b)
      ..setFloat(i++, AppColors.plasmaPink.r) // u_hot
      ..setFloat(i++, AppColors.plasmaPink.g)
      ..setFloat(i++, AppColors.plasmaPink.b)
      ..setFloat(i++, trackColor.r) // u_track
      ..setFloat(i++, trackColor.g)
      ..setFloat(i++, trackColor.b)
      ..setFloat(i++, trackColor.a);
    canvas.drawRRect(bar, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_PlasmaMeterPainter old) =>
      old.value != value ||
      old.trackColor != trackColor ||
      old.direction != direction ||
      old.shader != shader;
}
