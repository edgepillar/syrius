import 'package:animations/animations.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// How far the package slides a step along the axis, in logical pixels. The
/// clip leaves this much room at each side, so a step in motion is cut at
/// the bottom edge and nowhere else.
const double _kTravel = 30;

/// Shows one step of a flow at a time and, when [step] changes, moves along
/// the axis the steps share: a higher step comes in from the end side while
/// the old one leaves to the start side, a lower step the other way round.
///
/// For steps that follow one another: a stepper, onboarding. Destinations
/// with no order between them take `RiseSwitcher`, and the states of one
/// surface take `StateSwitcher`.
///
/// ```dart
/// StepSwitcher(step: index, child: steps[index])
/// ```
///
/// Only [step] decides when the content is replaced: a rebuild with the same
/// step updates the child in place. Once the switch has settled only the
/// current step is built, so what a step must remember across Back is kept
/// above the switcher.
///
/// The switcher is as tall as the current step. While two steps swap, its
/// height travels from the old step's to the new one's, so what sits under
/// it moves once and does not jump. The first step appears without motion.
class StepSwitcher extends StatefulWidget {
  /// Creates a switcher showing [child], the content of step [step].
  const StepSwitcher({
    required this.step,
    required this.child,
    this.fillColor = Colors.transparent,
    this.duration = Durations.medium2,
    super.key,
  });

  /// The index of the step shown. A higher one than before moves the flow
  /// on, a lower one moves it back.
  final int step;

  /// The content of the step.
  final Widget child;

  /// Painted behind the step that leaves. Transparent, so the card under
  /// the switcher stays what is seen: left to itself the package fills with
  /// the theme's canvas colour, which is not the card's and shows as a
  /// flash. Pass the card's own surface where the two steps must not show
  /// through each other.
  final Color fillColor;

  /// How long the swap takes, and the change of height with it.
  final Duration duration;

  @override
  State<StepSwitcher> createState() => _StepSwitcherState();
}

class _StepSwitcherState extends State<StepSwitcher>
    with SingleTickerProviderStateMixin {
  // Drives the height. `preserve`, because a controller built without it
  // runs twenty times faster when the platform asks for less motion, and
  // motion always runs here. At rest it sits at 1, where the height is the
  // current step's.
  late final AnimationController _resize = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  // Counts the changes of step. It keys the child, so the content is
  // replaced when the step changes and at no other time, and it tells the
  // step that leaves from the one that arrives: going 1, 2, 1 quickly puts
  // two steps numbered 1 in the tree.
  int _swaps = 0;

  bool _forward = true;

  @override
  void didUpdateWidget(StepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resize.duration = widget.duration;
    if (widget.step != oldWidget.step) {
      _forward = widget.step > oldWidget.step;
      _swaps++;
    }
  }

  @override
  void dispose() {
    _resize.dispose();
    super.dispose();
  }

  Widget _buildTransition(
    Widget child,
    Animation<double> primary,
    Animation<double> secondary,
  ) {
    return _StepEntry(
      swaps: (child.key! as ValueKey<int>).value,
      child: SharedAxisTransition(
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: widget.fillColor,
        child: child,
      ),
    );
  }

  // Steps sit at the top and the start, the stack's own default, where a
  // form begins. Nothing is clipped here: the step that leaves may be taller
  // than the one this stack is sized to, and it is the animated height above
  // that cuts it.
  static Widget _buildLayout(List<Widget> entries) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The package's horizontal axis is physical: moving on, the new step
    // comes in from the right. Its `reverse` mirrors every offset, so read
    // right to left the two directions trade places.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return _StepExtent(
      resize: _resize,
      swaps: _swaps,
      // The step that leaves is taken out of the layout, which would let it
      // be any height. It keeps the limits it had while it was the current
      // one, read here.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            _CurrentStep(
              swaps: _swaps,
              heights: constraints.heightConstraints(),
              child: PageTransitionSwitcher(
                duration: widget.duration,
                reverse: _forward == rtl,
                layoutBuilder: _buildLayout,
                transitionBuilder: _buildTransition,
                child: KeyedSubtree(
                  key: ValueKey<int>(_swaps),
                  child: widget.child,
                ),
              ),
            ),
      ),
    );
  }
}

/// Tells the steps under it which of them is the current one, and how tall
/// a step may be.
class _CurrentStep extends InheritedWidget {
  const _CurrentStep({
    required this.swaps,
    required this.heights,
    required super.child,
  });

  final int swaps;
  final BoxConstraints heights;

  static _CurrentStep of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CurrentStep>()!;

  @override
  bool updateShouldNotify(_CurrentStep oldWidget) =>
      oldWidget.swaps != swaps || oldWidget.heights != heights;
}

/// One step in the switcher's stack, in motion or at rest.
///
/// The stack takes the size of the current step alone. A step that leaves
/// is pinned over it and takes no input: it no longer holds the layout
/// open, and a press meant for the new step cannot land on the old one. The
/// widgets are the same in both cases, so a step keeps its state as it
/// turns from one into the other.
class _StepEntry extends StatelessWidget {
  const _StepEntry({required this.swaps, required this.child});

  /// The value of the switcher's count when this step arrived.
  final int swaps;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final _CurrentStep scope = _CurrentStep.of(context);
    final bool leaving = scope.swaps != swaps;
    return PositionedDirectional(
      top: leaving ? 0 : null,
      start: leaving ? 0 : null,
      end: leaving ? 0 : null,
      child: ConstrainedBox(
        constraints: scope.heights,
        child: IgnorePointer(ignoring: leaving, child: child),
      ),
    );
  }
}

/// Sizes itself to its child, except that after a change of [swaps] its
/// height travels from what it was to the child's over [resize].
///
/// `AnimatedSize` does this for any change of size, on a controller of its
/// own that cannot be told to keep its duration. Here the controller is the
/// switcher's, and a step that grows by itself, for a message under a field,
/// is followed at once.
class _StepExtent extends SingleChildRenderObjectWidget {
  const _StepExtent({
    required this.resize,
    required this.swaps,
    required super.child,
  });

  final AnimationController resize;
  final int swaps;

  @override
  _RenderStepExtent createRenderObject(BuildContext context) =>
      _RenderStepExtent(resize, swaps);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStepExtent renderObject,
  ) {
    renderObject.swaps = swaps;
  }
}

class _RenderStepExtent extends RenderProxyBox {
  _RenderStepExtent(this._resize, this._swaps);

  final AnimationController _resize;
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  int _swaps;

  // Set by a change of step, taken by the next layout: only there is the
  // new step's height known.
  bool _swapped = false;

  // The height the change starts from, and the height last laid out.
  double? _from;
  double? _shown;

  // The controller's value at the last layout. A tick that brings nothing
  // new asks for no layout, which is what lets the change be started from
  // inside one.
  double _lastValue = 1;

  int get swaps => _swaps;

  set swaps(int value) {
    if (value == _swaps) {
      return;
    }
    _swaps = value;
    _swapped = true;
    markNeedsLayout();
  }

  void _onTick() {
    if (_resize.value != _lastValue) {
      markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _resize.addListener(_onTick);
  }

  @override
  void detach() {
    _resize.removeListener(_onTick);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    _lastValue = _resize.value;
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final double target = child.size.height;
    if (_swapped) {
      _swapped = false;
      _from = _shown;
      _lastValue = 0;
      _resize.forward(from: 0);
    }
    final double from = _from ?? target;
    final double t = Easing.standard.transform(_resize.value);
    final double height = from + (target - from) * t;
    _shown = height;
    // The width is the child's throughout: only the height differs from
    // one step to the next.
    size = constraints.constrain(Size(child.size.width, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // At rest the child fits and there is nothing to cut. In motion one of
    // the two steps is taller than the height shown.
    if (child == null || !_resize.isAnimating) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(-_kTravel, 0, size.width + _kTravel, size.height),
      super.paint,
      oldLayer: _clip.layer,
    );
  }
}
