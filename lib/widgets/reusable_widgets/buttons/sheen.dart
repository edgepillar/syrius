import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// How long one pass of the band takes, edge to edge.
const Duration kSheenDuration = Duration(milliseconds: 600);

enum _SheenRequest { pass, landed, cancel }

/// Separates available-button passes from an original accepted result.
class SheenController extends ChangeNotifier {
  _SheenRequest _request = _SheenRequest.pass;
  bool Function()? _current;

  /// Runs one pass while the button is available.
  void pass() => _notify(_SheenRequest.pass);

  /// Reports an accepted result without changing the button's input state.
  void landed({required bool Function() isCurrent}) =>
      _notify(_SheenRequest.landed, current: isCurrent);

  /// Retires an earlier operation's active and queued feedback.
  void cancel() => _notify(_SheenRequest.cancel);

  void _notify(_SheenRequest request, {bool Function()? current}) {
    final _SheenRequest previous = _request;
    final bool Function()? previousCurrent = _current;
    _request = request;
    _current = current;
    try {
      notifyListeners();
    } finally {
      _request = previous;
      _current = previousCurrent;
    }
  }
}

/// Samples at most one accepted-result pass from the original painter.
class SheenCompletionObservation {
  final Stopwatch _clock = Stopwatch();
  final Completer<void> _finished = Completer<void>();
  int _first = 0;
  int _last = 0;
  int _count = 0;
  int _terminalMicros = 0;

  /// Waits for the terminal paint or cancellation of the observed pass.
  Future<void> get finished => _finished.future;

  /// Returns only bounded, distinct painted phases of a completed pass.
  Map<String, int>? get receipt {
    if (_terminalMicros <= 0 || _terminalMicros > 5000000 || _count < 2) {
      return null;
    }
    return <String, int>{
      'intermediate_paints': _count,
      'first_phase_millionths': _first,
      'last_phase_millionths': _last,
      'terminal_after_start_us': _terminalMicros,
    };
  }

  void _begin() {
    if (!_finished.isCompleted && !_clock.isRunning) _clock.start();
  }

  void _cancel() {
    if (!_clock.isRunning) return;
    _clock.stop();
    _finished.complete();
  }

  void _record(double phase) {
    if (!_clock.isRunning) return;
    if (phase == 1) {
      _terminalMicros = _clock.elapsedMicroseconds;
      _cancel();
      return;
    }
    final int progress = (phase * 1000000).floor();
    if (progress <= _last) return;
    if (_count == 0) _first = progress;
    _last = progress;
    if (_count < 128) _count++;
  }
}

/// One band of light that crosses a primary pill: once when the pointer
/// enters it, and once when [controller] says the action landed.
///
/// The band is a [LinearGradient] moved by a [GradientTransform] and drawn
/// over the child, clipped to the child's shape. It is paint on the button,
/// not a [ShaderMask] and not a fragment shader, so it costs one clipped
/// rectangle per frame and nothing at rest.
///
/// The child must fill the box it is given: a button whose tap target is
/// padded beyond its painted shape (anything but
/// [MaterialTapTargetSize.shrinkWrap]) would be clipped to the wrong pill.
class Sheen extends StatefulWidget {
  /// Wraps [child], which is a pill unless [borderRadius] says otherwise.
  const Sheen({
    required this.child,
    this.enabled = true,
    this.busy = false,
    this.borderRadius,
    this.controller,
    this.color,
    super.key,
  });

  /// The button.
  final Widget child;

  /// Whether ordinary hover and controller passes are available.
  /// Accepted-result feedback never changes this input gate.
  final bool enabled;

  /// Holds every pass while the surface is a busy spinner.
  final bool busy;

  /// The child's corners. Null is a stadium, the shape of every pill.
  final BorderRadius? borderRadius;

  /// Starts a pass from outside: the action landed.
  final SheenController? controller;

  /// The band at its brightest. Null is [Sheen.bandOf] for the theme.
  final Color? color;

  /// The band for [brightness]. The pill is the same green with the same
  /// dark label in both themes, so the band is white in both; it is kept a
  /// little lower on the light theme, where the page round the pill is
  /// already bright and the pass reads louder.
  static Color bandOf(Brightness brightness) => brightness == Brightness.light
      ? const Color(0x38FFFFFF)
      : const Color(0x47FFFFFF);

  /// The phase last processed by this original foreground painter.
  static double? paintedProgressOf(BuildContext context) {
    final State<StatefulWidget>? state =
        context is StatefulElement ? context.state : null;
    return state is _SheenState ? state._paintObservation.progress : null;
  }

  /// Arms the original widget's next accepted-result paint observation.
  static SheenCompletionObservation? observeCompletionOf(
    BuildContext context,
  ) {
    final State<StatefulWidget>? state =
        context is StatefulElement ? context.state : null;
    if (state is! _SheenState) return null;
    return state._paintObservation.completion ??= SheenCompletionObservation();
  }

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _pass = AnimationController(
    vsync: this,
    duration: kSheenDuration,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final _SheenPaintObservation _paintObservation =
      _SheenPaintObservation();
  bool _completion = false;
  bool Function()? _completionCurrent;
  bool Function()? _queuedCompletion;

  @override
  void initState() {
    super.initState();
    _pass
      ..addListener(_checkCurrent)
      ..addStatusListener(_onStatus);
    widget.controller?.addListener(_requested);
  }

  @override
  void didUpdateWidget(Sheen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_requested);
      _cancel();
      widget.controller?.addListener(_requested);
    }
    if (widget.busy) {
      _cancel();
    } else if (!widget.enabled && !_completion && _pass.isAnimating) {
      _stopPass();
      _startQueued();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_requested);
    _paintObservation.completion?._cancel();
    _pass.dispose();
    super.dispose();
  }

  bool _stillCurrent(bool Function()? current) {
    try {
      return current?.call() ?? true;
    } on Object {
      // Presentation uncertainty cannot replace an original result.
      return false;
    }
  }

  void _requested() {
    final SheenController? controller = widget.controller;
    if (controller == null) return;
    switch (controller._request) {
      case _SheenRequest.pass:
        _run();
        return;
      case _SheenRequest.landed:
        final bool Function()? current = controller._current;
        if (widget.busy || current == null || !_stillCurrent(current)) return;
        if (_pass.isAnimating) {
          _queuedCompletion = current;
        } else {
          _run(completion: current);
        }
        return;
      case _SheenRequest.cancel:
        _cancel();
        return;
    }
  }

  void _checkCurrent() {
    if (_queuedCompletion != null && !_stillCurrent(_queuedCompletion)) {
      _queuedCompletion = null;
    }
    if (_pass.isAnimating &&
        _completion &&
        !_stillCurrent(_completionCurrent)) {
      _cancel();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _completion = false;
      _completionCurrent = null;
      _startQueued();
    }
  }

  void _startQueued() {
    final bool Function()? current = _queuedCompletion;
    _queuedCompletion = null;
    if (current != null) _run(completion: current);
  }

  void _stopPass() {
    _paintObservation.completion?._cancel();
    if (_pass.isAnimating || _pass.value != 0) {
      _pass
        ..stop()
        ..value = 0;
    }
    _completion = false;
    _completionCurrent = null;
  }

  void _cancel() {
    _queuedCompletion = null;
    _stopPass();
  }

  void _run({bool Function()? completion}) {
    if (widget.busy ||
        _pass.isAnimating ||
        (!widget.enabled && completion == null) ||
        !_stillCurrent(completion)) {
      return;
    }
    // A result waits for an existing hover pass; it never shortens that pass.
    _completion = completion != null;
    _completionCurrent = completion;
    if (completion == null) {
      _paintObservation.completion?._cancel();
    } else {
      _paintObservation.completion?._begin();
    }
    _pass.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.deferToChild,
        onEnter: (_) => _run(),
        child: CustomPaint(
          foregroundPainter: _SheenPainter(
            pass: _pass,
            observation: _paintObservation,
            color: widget.color ?? Sheen.bandOf(Theme.of(context).brightness),
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SheenPaintObservation {
  double? progress;
  SheenCompletionObservation? completion;
}

class _SheenPainter extends CustomPainter {
  _SheenPainter({
    required this.pass,
    required this.observation,
    required this.color,
    required this.borderRadius,
  }) : super(repaint: pass);

  final Animation<double> pass;
  final Color color;
  final BorderRadius? borderRadius;
  final _SheenPaintObservation observation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double t = pass.value;
    observation.progress = t;
    observation.completion?._record(t);
    if (t <= 0 || t >= 1) {
      return;
    }
    final Rect rect = Offset.zero & size;
    final RRect shape =
        borderRadius?.toRRect(rect) ??
        RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2));
    // Fading to the band's own colour at zero alpha, not to transparent
    // black, keeps the band's edges from greying the green under them.
    final Color clear = color.withValues(alpha: 0);
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[clear, color, clear],
        stops: const <double>[0.3, 0.5, 0.7],
        transform: _SheenSlide(Curves.easeInOutCubic.transform(t)),
      ).createShader(rect);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(rect, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_SheenPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

/// Carries the band from one full width before the pill to one after it,
/// leaning ten degrees off vertical, as the mockup's `.btn.go::after` does.
class _SheenSlide extends GradientTransform {
  const _SheenSlide(this.t);

  final double t;

  static const double _lean = 10 * math.pi / 180;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final Offset c = bounds.center;
    final double dx = (-1.2 + 2.4 * t) * bounds.width;
    return Matrix4.translationValues(c.dx + dx, c.dy, 0)
        .multiplied(Matrix4.rotationZ(_lean))
        .multiplied(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}
