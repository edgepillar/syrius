import 'package:material_ui/material_ui.dart';

/// Shows one [child] at a time and, when it is replaced, fades the new one
/// in while it rises [rise] pixels into place.
///
/// For destinations with no order between them, such as the pages behind
/// the side rail: a sideways slide would claim one. The old child fades out
/// fast and does not move, then leaves the tree, so once the switch has
/// settled only the current child is built.
///
/// A child is "replaced" when its type or key differs from the last one, so
/// give each destination its own key:
///
/// ```dart
/// RiseSwitcher(
///   child: KeyedSubtree(key: ValueKey<int>(index), child: page),
/// )
/// ```
///
/// The child fills the switcher. The first child appears without motion.
class RiseSwitcher extends StatelessWidget {
  /// Creates a switcher showing [child].
  const RiseSwitcher({
    required this.child,
    this.rise = 6,
    this.duration = Durations.medium2,
    this.reverseDuration = Durations.short2,
    super.key,
  });

  /// The current destination, keyed.
  final Widget child;

  /// How far below its place the new child starts, in logical pixels.
  final double rise;

  /// How long the new child takes to arrive.
  final Duration duration;

  /// How long the old child takes to fade out.
  final Duration reverseDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: reverseDuration,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: _buildLayout,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          _FadeRise(animation: animation, rise: rise, child: child),
      child: child,
    );
  }

  static Widget _buildLayout(Widget? current, List<Widget> previous) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[...previous, ?current],
    );
  }
}

/// The transition of one child of a [RiseSwitcher].
///
/// AnimatedSwitcher runs the same animation forward for the child arriving
/// and in reverse for the one leaving. The status tells them apart: only
/// the arriving child is moved, and the leaving one takes no input.
class _FadeRise extends StatelessWidget {
  const _FadeRise({
    required this.animation,
    required this.rise,
    required this.child,
  });

  final Animation<double> animation;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (BuildContext context, Widget? child) {
          final bool leaving = animation.status == AnimationStatus.reverse;
          return Transform.translate(
            offset: Offset(0, leaving ? 0 : rise * (1 - animation.value)),
            child: IgnorePointer(ignoring: leaving, child: child),
          );
        },
      ),
    );
  }
}
