import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// How long one pass of the band takes, edge to edge.
const Duration kSheenDuration = Duration(milliseconds: 600);

/// Tells a [Sheen] that the action its button stands for has landed.
///
/// The button does not know that on its own: a send is confirmed by a bloc,
/// long after the press. Whoever hears the confirmation calls [pass].
class SheenController extends ChangeNotifier {
  /// Runs one pass of the band, unless the [Sheen] is disabled.
  void pass() => notifyListeners();
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
    this.borderRadius,
    this.controller,
    this.color,
    super.key,
  });

  /// The button.
  final Widget child;

  /// False while the button cannot be pressed. A pill that is not ready must
  /// not answer the pointer, so no pass starts and a running one is dropped.
  final bool enabled;

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

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _pass = AnimationController(
    vsync: this,
    duration: kSheenDuration,
    // The pass is the feedback itself. The default behaviour shortens it to
    // a twentieth when the OS asks for less motion, which would leave a
    // single bright frame: a flash, worse than the movement it replaces.
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_run);
  }

  @override
  void didUpdateWidget(Sheen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_run);
      widget.controller?.addListener(_run);
    }
    if (!widget.enabled && _pass.isAnimating) {
      _pass
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_run);
    _pass.dispose();
    super.dispose();
  }

  void _run() {
    // A pass in flight is left to finish: restarting it on every enter would
    // make a pointer resting on the pill's edge strobe the band.
    if (!widget.enabled || _pass.isAnimating) {
      return;
    }
    // Left at 1 when done: the painter draws nothing there, and winding it
    // back would cost a frame to repaint nothing.
    _pass.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        // The region only watches. Deferring to the child keeps the button
        // the one thing under the pointer, cursor and tap included.
        hitTestBehavior: HitTestBehavior.deferToChild,
        onEnter: (_) => _run(),
        child: CustomPaint(
          foregroundPainter: _SheenPainter(
            pass: _pass,
            color: widget.color ?? Sheen.bandOf(Theme.of(context).brightness),
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  _SheenPainter({
    required this.pass,
    required this.color,
    required this.borderRadius,
  }) : super(repaint: pass);

  final Animation<double> pass;
  final Color color;
  final BorderRadius? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = pass.value;
    if (t <= 0 || t >= 1 || size.isEmpty) {
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
