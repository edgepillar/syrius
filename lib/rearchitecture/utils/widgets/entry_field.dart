import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';

/// The entry mockup's soft light over the window background.
///
/// The three closest-side radial gradients, grouped opacity, blur and drift
/// follow `.lockpage::before` in the original mockup. The Home card keeps its
/// separate hero shader. This field shares the original clock's route, window
/// and overlay holds; it never reads the OS animation-effects setting.
class EntryField extends StatefulWidget {
  /// Creates the continuously animated entry backdrop.
  const EntryField({super.key});

  @override
  State<EntryField> createState() => _EntryFieldState();
}

class _EntryFieldState extends State<EntryField>
    with SingleTickerProviderStateMixin
    implements ReferenceArtworkSource {
  late final ShaderClock _clock;
  ReferenceArtworkFrame? _referenceFrame;
  ValueListenable<double>? _referenceSeconds;
  ValueListenable<double>? _paintedSeconds;

  @override
  ReferenceArtworkKind get referenceArtworkKind =>
      ReferenceArtworkKind.entryField;

  @override
  Object get referenceArtworkGeneration => _clock;

  @override
  Future<Object?>? get referenceArtworkReadiness => null;

  @override
  ReferenceArtworkFrame? captureReferenceArtwork() {
    if (!mounted || !_clock.isRunning || _referenceFrame != null ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return null;
    }
    final ShaderClock original = _clock;
    const Animation<double> sample = AlwaysStoppedAnimation<double>(6);
    bool originalCurrent() => mounted && identical(_clock, original) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    late final ReferenceArtworkFrame frame;
    frame = ReferenceArtworkFrame(
      owner: this, generation: original, kind: referenceArtworkKind,
      observation: <String, Object>{'kind': 'entry_field', 'seconds': 6},
      current: () => originalCurrent() && original.isRunning &&
          identical(_referenceFrame, frame) &&
          identical(_referenceSeconds, sample),
      observed: () => identical(_paintedSeconds, sample),
      restore: () => setState(() {
        _referenceFrame = null;
        _referenceSeconds = null;
      }),
      restoration: () => originalCurrent() && _referenceFrame == null &&
          _referenceSeconds == null &&
          identical(_paintedSeconds, original),
    );
    setState(() {
      _referenceFrame = frame;
      _referenceSeconds = sample;
    });
    return frame;
  }

  @override
  void initState() {
    super.initState();
    _clock = ShaderClock(vsync: this)..active = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.updateVisibility(context);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final ValueListenable<double> paintedSeconds = _referenceSeconds ?? _clock;
    _paintedSeconds = paintedSeconds;
    return RepaintBoundary(
      child: ClipRect(
        child: CustomPaint(
          painter: _EntryFieldPainter(
            seconds: paintedSeconds,
            background: tokens.background,
            green: tokens.znn,
            blue: tokens.qsr,
            pink: tokens.pink,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EntryFieldPainter extends CustomPainter {
  _EntryFieldPainter({
    required this.seconds,
    required this.background,
    required this.green,
    required this.blue,
    required this.pink,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final Color background;
  final Color green;
  final Color blue;
  final Color pink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect viewport = Offset.zero & size;
    canvas.drawRect(viewport, Paint()..color = background);

    // CSS inset:-20% enlarges each side by a fraction of the parent, while
    // translate percentages use this enlarged field's own dimensions.
    final Rect field = Rect.fromLTWH(
      -size.width * 0.2,
      -size.height * 0.2,
      size.width * 1.4,
      size.height * 1.4,
    );
    final double leg = (seconds.value % 40) / 20;
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
      ..translate(-center.dx, -center.dy)
      // Blur the combined transparent field, then composite it at .35. The
      // window base is outside this layer, so it is never blurred or tinted
      // as a raised card. CSS blur(60px) uses a 60 logical-pixel sigma.
      ..saveLayer(
        field.inflate(180),
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, 0.35)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 60,
            sigmaY: 60,
            tileMode: ui.TileMode.decal,
          ),
      );
    // CSS paints its first background on top of the later backgrounds.
    _paintLight(canvas, field, pink, const Offset(0.55, 0.2), 0.3);
    _paintLight(canvas, field, blue, const Offset(0.7, 0.65), 0.4);
    _paintLight(canvas, field, green, const Offset(0.3, 0.35), 0.4);
    canvas
      ..restore()
      ..restore();
  }

  static void _paintLight(
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
      center.dx - field.left,
      field.right - center.dx,
    );
    final double radiusY = math.min(
      center.dy - field.top,
      field.bottom - center.dy,
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
  bool shouldRepaint(_EntryFieldPainter old) =>
      old.seconds != seconds ||
      old.background != background ||
      old.green != green ||
      old.blue != blue ||
      old.pink != pink;
}
