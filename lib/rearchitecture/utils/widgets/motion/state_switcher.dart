import 'package:material_ui/material_ui.dart';

/// Cross-fades between the states of one surface: loading, populated, empty,
/// error; or one step of a flow and the next.
///
/// Give each state's widget a different [Key]: the switcher animates when
/// the key (or the widget's type) changes, and not when the same state is
/// rebuilt with new data.
///
/// With [axis] set, the incoming state also travels a few pixels along that
/// axis and the outgoing one leaves the other way: Material's shared axis,
/// for steps that follow one another (a stepper, onboarding). Without it the
/// states are unrelated and only fade.
class StateSwitcher extends StatelessWidget {
  /// Creates a switcher showing [child].
  const StateSwitcher({
    required this.child,
    this.axis,
    this.forward = true,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  /// The current state.
  final Widget child;

  /// The axis related steps share, or null for a plain fade.
  final Axis? axis;

  /// With [axis]: whether the flow is moving on, or back.
  final bool forward;

  /// Where a smaller state sits while a larger one fades.
  final AlignmentGeometry alignment;

  static const double _travel = 16;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Durations.medium1,
      reverseDuration: Durations.short2,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Easing.emphasizedAccelerate,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: alignment,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Widget faded = FadeTransition(opacity: animation, child: child);
        final Axis? along = axis;
        if (along == null) {
          return faded;
        }
        // The incoming child's animation runs forward, the outgoing one's in
        // reverse, so one tween gives both their direction.
        final bool incoming = child.key == this.child.key;
        final double sign = (incoming == forward) ? 1 : -1;
        final Offset from = along == Axis.horizontal
            ? Offset(sign * _travel, 0)
            : Offset(0, sign * _travel);
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) =>
              Transform.translate(
                offset: from * (1 - animation.value),
                child: child,
              ),
          child: faded,
        );
      },
      child: child,
    );
  }
}
