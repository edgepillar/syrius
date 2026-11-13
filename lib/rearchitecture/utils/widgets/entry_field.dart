import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/shaders/shader_clock.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/window_frame.dart';

class _EntryCaptionRepaint extends ChangeNotifier {
  void markPaint() => notifyListeners();
}

typedef _EntryCaptionPaint = ({
  ValueListenable<double> seconds,
  Size body,
  double height,
  double pixelRatio,
  Color background,
  Color green,
  Color blue,
  Color pink,
  Object generation,
});

/// The entry mockup's soft light over the window background.
///
/// The three closest-side radial gradients, grouped opacity, blur and drift
/// follow `.lockpage::before` in the original mockup. The Home card keeps its
/// separate hero shader. This field shares the original clock's route, window
/// and overlay holds; it never reads the OS animation-effects setting.
class EntryField extends StatefulWidget {
  /// Creates the continuously animated entry backdrop.
  const EntryField({this.paintCaption = true, super.key});

  /// A launch owner keeps the native caption separate until its transform
  /// settles. The original body field and its clock remain mounted.
  final bool paintCaption;

  @override
  State<EntryField> createState() => _EntryFieldState();
}

class _EntryFieldState extends State<EntryField>
    with SingleTickerProviderStateMixin
    implements ReferenceArtworkSource {
  late final ShaderClock _clock;
  final _EntryFieldRaster _raster = _EntryFieldRaster();
  ReferenceArtworkFrame? _referenceFrame;
  ValueListenable<double>? _referenceSeconds;
  ValueListenable<double>? _paintedSeconds;
  final _EntryCaptionRepaint _captionChanges = _EntryCaptionRepaint();
  late final Listenable _captionRepaint;
  AppWindowFrameState? _captionFrame;
  ModalRoute<dynamic>? _captionRoute;
  bool _captionTickerEnabled = false;
  AppWindowEntryBackdrop? _captionLease;
  _EntryCaptionPaint? _captionRequested;
  _EntryCaptionPaint? _captionPainted;
  AppWindowEntryBackdrop? _captionPaintedLease;

  bool _captionGeometryCurrent() {
    final AppWindowFrameState? frame = _captionFrame;
    final _EntryCaptionPaint? request = _captionRequested;
    if (!mounted || frame == null || !frame.mounted ||
        !frame.hasClientCaption || request == null ||
        !identical(request.generation, _clock)) {
      return false;
    }
    final RenderObject? fieldObject = context.findRenderObject();
    final RenderObject? frameObject = frame.context.findRenderObject();
    if (fieldObject is! RenderBox || frameObject is! RenderBox ||
        !fieldObject.attached || !frameObject.attached ||
        !fieldObject.hasSize || !frameObject.hasSize) {
      return false;
    }
    final Size body = fieldObject.size;
    final Size client = frameObject.size;
    if (body != request.body || body.isEmpty || client.isEmpty) return false;
    final Offset origin = fieldObject.localToGlobal(
      Offset.zero, ancestor: frameObject,
    );
    const double tolerance = 0.001;
    return origin.dx.abs() < tolerance &&
        (origin.dy - request.height).abs() < tolerance &&
        (body.width - client.width).abs() < tolerance &&
        (body.height + request.height - client.height).abs() < tolerance;
  }

  AppWindowEntryBackdropPhase _captionPhase() {
    if (!widget.paintCaption || !_captionTickerEnabled ||
        !_captionGeometryCurrent()) {
      return AppWindowEntryBackdropPhase.hidden;
    }
    final ModalRoute<dynamic>? route = _captionRoute;
    if (route == null) return AppWindowEntryBackdropPhase.current;
    if (!route.isActive) return AppWindowEntryBackdropPhase.hidden;
    return route.isCurrent ? AppWindowEntryBackdropPhase.current
        : AppWindowEntryBackdropPhase.covered;
  }

  void _bindCaption() {
    final AppWindowFrameState? frame = _captionFrame;
    if (!mounted || frame == null || !frame.hasClientCaption ||
        _captionLease != null) {
      return;
    }
    final ShaderClock generation = _clock;
    late final AppWindowEntryBackdrop? original;
    original = frame.attachEntryBackdrop(
      owner: this, phase: _captionPhase, repaint: _captionRepaint,
      paint: (Canvas canvas, Size size) {
        final AppWindowEntryBackdrop? lease = original;
        final _EntryCaptionPaint? request = _captionRequested;
        if (!mounted || lease == null || request == null ||
            !identical(_captionLease, lease) || !lease.isVisible ||
            !identical(_captionFrame, frame) ||
            !identical(_clock, generation) ||
            !identical(request.generation, generation) ||
            (size.width - request.body.width).abs() >= 0.001 ||
            (size.height - request.height).abs() >= 0.001) {
          return;
        }
        canvas
          ..save()
          ..translate(0, request.height);
        _EntryFieldPainter._paintViewport(canvas, request.body,
          Rect.fromLTWH(0, -request.height,
              request.body.width, request.height),
          seconds: request.seconds.value, background: request.background,
          green: request.green, blue: request.blue, pink: request.pink,
          raster: _raster, pixelRatio: request.pixelRatio,
        );
        canvas.restore();
        if (mounted && identical(_captionLease, lease) && lease.isVisible &&
            identical(_captionFrame, frame) && request == _captionRequested) {
          // This is an actual original paint, not a registration or request.
          _captionPainted = request;
          _captionPaintedLease = lease;
        }
      },
    );
    _captionLease = original;
  }

  void _captionForLayout(Size size, AppTokens tokens,
      ValueListenable<double> seconds, double pixelRatio) {
    final _EntryCaptionPaint? request =
        size.width.isFinite && size.height.isFinite && !size.isEmpty
        ? (seconds: seconds, body: size, height: tokens.windowCaptionHeight,
          pixelRatio: pixelRatio,
          background: tokens.background, green: tokens.znn,
          blue: tokens.qsr, pink: tokens.pink, generation: _clock)
        : null;
    if (_captionRequested == request) return;
    _captionRequested = request;
    // This marks only the caption's original painter dirty, even in layout.
    // It never starts another clock or rebuilds the Navigator/frame ancestor.
    _captionChanges.markPaint();
  }

  bool _captionMatches(ValueListenable<double> seconds, {
    required AppWindowFrameState? frame, required bool needed,
  }) {
    if (!needed) return true;
    final AppWindowEntryBackdrop? lease = _captionLease;
    final _EntryCaptionPaint? requested = _captionRequested;
    final _EntryCaptionPaint? painted = _captionPainted;
    return frame != null && frame.mounted &&
        identical(_captionFrame, frame) && lease != null && lease.isVisible &&
        identical(_captionPaintedLease, lease) &&
        requested != null && painted != null && requested == painted &&
        identical(painted.seconds, seconds) &&
        identical(painted.generation, _clock);
  }

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
    final AppWindowFrameState? captionFrame = _captionFrame;
    final bool needsCaption = captionFrame?.hasClientCaption ?? false;
    final AppWindowEntryBackdrop? originalCaption = _captionLease;
    if (needsCaption &&
        (originalCaption == null || !originalCaption.isVisible)) {
      return null;
    }
    const Animation<double> sample = AlwaysStoppedAnimation<double>(6);
    bool originalCurrent() => mounted && identical(_clock, original) &&
        identical(_captionFrame, captionFrame) &&
        (!needsCaption || identical(_captionLease, originalCaption) &&
            originalCaption != null && originalCaption.isVisible) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    late final ReferenceArtworkFrame frame;
    frame = ReferenceArtworkFrame(
      owner: this, generation: original, kind: referenceArtworkKind,
      observation: <String, Object>{'kind': 'entry_field', 'seconds': 6},
      current: () => originalCurrent() && original.isRunning &&
          identical(_referenceFrame, frame) &&
          identical(_referenceSeconds, sample),
      observed: () => identical(_paintedSeconds, sample) &&
          _captionMatches(sample, frame: captionFrame, needed: needsCaption),
      restore: () => setState(() {
        _referenceFrame = null;
        _referenceSeconds = null;
      }),
      restoration: () => originalCurrent() && _referenceFrame == null &&
          _referenceSeconds == null &&
          identical(_paintedSeconds, original) &&
          _captionMatches(original, frame: captionFrame, needed: needsCaption),
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
    _captionRepaint = Listenable.merge(<Listenable>[_clock, _captionChanges]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.updateVisibility(context);
    final AppWindowFrameState? frame =
        context.findAncestorStateOfType<AppWindowFrameState>();
    if (!identical(frame, _captionFrame)) {
      _captionLease?.dispose();
      _captionLease = null;
      _captionPainted = null;
      _captionPaintedLease = null;
      _captionFrame = frame;
    }
    _captionRoute = ModalRoute.of(context);
    _captionTickerEnabled = TickerMode.valuesOf(context).enabled;
    _bindCaption();
    _captionChanges.markPaint();
  }

  @override
  void didUpdateWidget(EntryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paintCaption != widget.paintCaption) {
      _captionChanges.markPaint();
    }
  }

  @override
  void dispose() {
    _captionLease?.dispose();
    _captionLease = null;
    _captionChanges.dispose();
    _raster.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final ValueListenable<double> paintedSeconds = _referenceSeconds ?? _clock;
    final double pixelRatio = View.of(context).devicePixelRatio;
    _paintedSeconds = paintedSeconds;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _captionForLayout(
          constraints.biggest, tokens, paintedSeconds, pixelRatio,
        );
        return RepaintBoundary(
          child: ClipRect(
            child: CustomPaint(
              painter: _EntryFieldPainter(
                seconds: paintedSeconds,
                background: tokens.background,
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
      },
    );
  }
}

typedef _EntryRasterKey = ({
  Rect field,
  Color green,
  Color blue,
  Color pink,
  double pixelRatio,
});

// One borrowed image serves both original painters. Its owner retires it on
// geometry/colour/DPR replacement and when the field leaves the tree.
class _EntryFieldRaster {
  static const int _maxPixels = 16 * 1024 * 1024;
  static const int _maxSide = 8192;
  _EntryRasterKey? _key;
  ui.Image? _image;

  ui.Image? imageFor(Rect field, {
    required Color green, required Color blue, required Color pink,
    required double pixelRatio,
  }) {
    final Rect bounds = field.inflate(180);
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
    final _EntryRasterKey key = (
      field: field, green: green, blue: blue, pink: pink,
      pixelRatio: pixelRatio,
    );
    if (_key == key) return _image;
    dispose();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-bounds.left, -bounds.top);
    _EntryFieldPainter._paintBlurredField(
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

class _EntryFieldPainter extends CustomPainter {
  _EntryFieldPainter({
    required this.seconds,
    required this.background,
    required this.green,
    required this.blue,
    required this.pink,
    required this.raster,
    required this.pixelRatio,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final Color background;
  final Color green;
  final Color blue;
  final Color pink;
  final _EntryFieldRaster raster;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) => _paintViewport(
    canvas, size, Offset.zero & size,
    seconds: seconds.value, background: background,
    green: green, blue: blue, pink: pink,
    raster: raster, pixelRatio: pixelRatio,
  );

  static void _paintViewport(Canvas canvas, Size size, Rect viewport, {
    required double seconds, required Color background,
    required Color green, required Color blue, required Color pink,
    required _EntryFieldRaster raster, required double pixelRatio,
  }) {
    if (size.isEmpty || viewport.isEmpty) {
      return;
    }
    canvas.drawRect(viewport, Paint()..color = background);

    // CSS inset:-20% enlarges each side by a fraction of the parent, while
    // translate percentages use this enlarged field's own dimensions.
    final Rect field = Rect.fromLTWH(
      -size.width * 0.2,
      -size.height * 0.2,
      size.width * 1.4,
      size.height * 1.4,
    );
    final double leg = (seconds % 40) / 20;
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
      // Oversized surfaces keep the original paint instead of downsampling.
      _paintBlurredField(canvas, field, green: green, blue: blue, pink: pink);
    } else {
      final Rect bounds = field.inflate(180);
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
    // Blur the combined transparent field, then composite it at .35. The
    // window base is outside this layer. Its 60 logical-pixel sigma and the
    // original 3-sigma bounds are independent of the rigid drift transform.
    canvas.saveLayer(
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
    canvas.restore();
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
      old.pink != pink ||
      old.raster != raster ||
      old.pixelRatio != pixelRatio;
}
