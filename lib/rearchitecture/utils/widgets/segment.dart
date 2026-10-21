import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// Between the track's line and a segment. No token names a gap this small
/// (the nearest, `cardGap`, is 10), so the mockup's 3 px is kept as it is.
const double _kTrackPadding = 3;

/// Round a label, from the mockup. The 14 is `panelGap`'s number and not its
/// meaning: a page that spaced its panels wider must not fatten every pill.
const EdgeInsets _kSegmentPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 5,
);

const double _kIconSize = 14;
const double _kIconGap = 6;

/// The focus ring is the switch's: 2 px, drawn inside the track's edge so
/// that taking the focus moves nothing.
const double _kFocusRingWidth = 2;

/// One choice of a [Segment].
@immutable
class SegmentItem<T> {
  /// Creates the choice [value], shown as [label].
  const SegmentItem({required this.value, required this.label, this.icon});

  /// What [Segment.onChanged] is given when this is picked.
  final T value;

  /// The word on the segment, already in the interface language.
  final String label;

  /// Drawn before the label, in the label's colour.
  final IconData? icon;
}

/// A choice between a few values on one pill-shaped track, with one thumb
/// that slides to whichever is picked.
///
/// It is the only control of its kind in the interface: Send, Receive and
/// Zap on Transfer, the filters over a list, the choices in Settings. A
/// choice made here applies at once; there is no confirm step under it.
///
/// ```dart
/// Segment<TokenFilter>(
///   keyPrefix: 'tokens_filter',
///   items: const <SegmentItem<TokenFilter>>[
///     SegmentItem<TokenFilter>(value: TokenFilter.held, label: 'Held'),
///     SegmentItem<TokenFilter>(value: TokenFilter.all, label: 'All'),
///   ],
///   selected: filter,
///   onChanged: (TokenFilter value) => setState(() => filter = value),
/// )
/// ```
///
/// The control holds no selection of its own. [onChanged] reports a pick,
/// and the thumb moves when the widget is rebuilt with the new [selected],
/// wherever that came from: a click, an arrow key, or the page itself.
///
/// Each segment is as wide as its label. Under a width too small for all of
/// them the segments narrow in proportion and the labels are cut with an
/// ellipsis, so the control never overflows. Given more width than it needs
/// it keeps its own and sits at the start, which is the right side under a
/// right-to-left interface; the order of the segments mirrors there too.
///
/// The keyboard treats it as one stop: Tab reaches the control, and the
/// left and right arrows move the selection towards that side of the screen.
class Segment<T> extends StatefulWidget {
  /// Creates a choice between [items].
  const Segment({
    required this.items,
    required this.selected,
    required this.onChanged,
    this.keyPrefix,
    super.key,
  });

  /// How long the thumb takes from one segment to another.
  static const Duration slideDuration = Duration(milliseconds: 360);

  /// The thumb's easing: slow away, fast across, slow home.
  static const Cubic slideCurve = Cubic(0.65, 0, 0.35, 1);

  /// What can be picked, in reading order.
  final List<SegmentItem<T>> items;

  /// The value in effect. With null, or a value that is not among [items],
  /// no segment is lit and the thumb is closed.
  final T? selected;

  /// Called with the value picked, once per pick, and never with the value
  /// already in effect.
  final ValueChanged<T> onChanged;

  /// When given, each segment carries [keyOf] of it and its value, which is
  /// how the UI harness finds one.
  final String? keyPrefix;

  /// The key of the segment for [value] under [keyPrefix]: the prefix, an
  /// underscore, then the name of an enum value or the `toString` of any
  /// other.
  static ValueKey<String> keyOf(String keyPrefix, Object? value) =>
      ValueKey<String>('${keyPrefix}_${value is Enum ? value.name : value}');

  @override
  State<Segment<T>> createState() => _SegmentState<T>();
}

class _MoveIntent extends Intent {
  const _MoveIntent({required this.right});

  /// Towards the right of the screen, whichever way the interface runs.
  final bool right;
}

class _SegmentState<T> extends State<Segment<T>>
    with SingleTickerProviderStateMixin {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(
          right: false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(
          right: true,
        ),
      };

  // At rest the controller sits at 1, with the thumb on the selected
  // segment. It keeps its length whatever the system says about reduced
  // motion ([AnimationBehavior.preserve]; the default plays it in a
  // twentieth of the time, which is a jump).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Segment.slideDuration,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  late final CurvedAnimation _slide = CurvedAnimation(
    parent: _controller,
    curve: Segment.slideCurve,
  );

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _MoveIntent: CallbackAction<_MoveIntent>(onInvoke: _move),
  };

  /// How lit each label was when the slide under way began, 0 dim to 1
  /// full. A pick made mid-slide starts each label from the colour it has,
  /// as the thumb starts from where it is.
  Map<T, double> _inkFrom = <T, double>{};

  bool _showRing = false;

  int _indexIn(Segment<T> of) {
    final T? selected = of.selected;
    return selected == null
        ? -1
        : of.items.indexWhere(
            (SegmentItem<T> item) => item.value == selected,
          );
  }

  double _inkAt(T value, T? selected, double t) =>
      lerpDouble(_inkFrom[value] ?? 0, value == selected ? 1 : 0, t)!;

  @override
  void didUpdateWidget(Segment<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The index and not the value: it is what the thumb's place hangs on,
    // and the render object starts its slide on the same change.
    if (_indexIn(oldWidget) != _indexIn(widget)) {
      final double t = _slide.value;
      _inkFrom = <T, double>{
        for (final SegmentItem<T> item in oldWidget.items)
          item.value: _inkAt(item.value, oldWidget.selected, t),
      };
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _pick(T value) {
    if (value != widget.selected) {
      widget.onChanged(value);
    }
  }

  Object? _move(_MoveIntent intent) {
    if (widget.items.isEmpty) {
      return null;
    }
    final int index = _indexIn(widget);
    // An arrow points at a side of the screen, and the segments run from
    // the right under a right-to-left interface.
    final bool forward =
        intent.right == (Directionality.of(context) == TextDirection.ltr);
    final int next = index < 0
        ? 0
        : (index + (forward ? 1 : -1)).clamp(0, widget.items.length - 1);
    if (next != index) {
      widget.onChanged(widget.items[next].value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final String? prefix = widget.keyPrefix;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: FocusableActionDetector(
        shortcuts: _shortcuts,
        actions: _actions,
        onShowFocusHighlight: (bool show) => setState(() => _showRing = show),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: StadiumBorder(side: BorderSide(color: _lineOf(theme))),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: _showRing
                    ? BorderSide(
                        color: tokens.focusRing,
                        width: _kFocusRingWidth,
                      )
                    : BorderSide.none,
              ),
            ),
            child: Padding(
              // The track's own line takes the first pixel.
              padding: const EdgeInsets.all(_kTrackPadding + 1),
              child: _SegmentRow(
                selectedIndex: _indexIn(widget),
                slide: _slide,
                textDirection: Directionality.of(context),
                children: <Widget>[
                  const SegmentThumb(),
                  for (final SegmentItem<T> item in widget.items)
                    _SegmentCell(
                      key: prefix == null
                          ? null
                          : Segment.keyOf(prefix, item.value),
                      label: item.label,
                      icon: item.icon,
                      selected: item.value == widget.selected,
                      slide: _slide,
                      ink: () =>
                          _inkAt(item.value, widget.selected, _slide.value),
                      onTap: () => _pick(item.value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _lineOf(ThemeData theme) =>
    theme.dividerTheme.color ?? theme.dividerColor;

/// The pill under the selected label of a [Segment].
///
/// A segment has exactly one, for as long as it lives: picking another value
/// moves and resizes this widget, it does not build a second.
class SegmentThumb extends StatelessWidget {
  /// Creates the thumb. [Segment] does; nothing else needs to.
  const SegmentThumb({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        // The mockup's third card tone has no name in the theme. The hover
        // tint laid over the track lands within three steps of it in both
        // themes, and stays a step above the track if either is retuned.
        color: Color.alphaBlend(
          AppTokens.of(context).hover,
          theme.colorScheme.primaryContainer,
        ),
        shape: StadiumBorder(side: BorderSide(color: _lineOf(theme))),
      ),
    );
  }
}

class _SegmentCell extends StatefulWidget {
  const _SegmentCell({
    required this.label,
    required this.icon,
    required this.selected,
    required this.slide,
    required this.ink,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  /// Ticks while the thumb moves, which is when [ink] changes.
  final Listenable slide;

  /// How lit the label is now, 0 dim to 1 full.
  final ValueGetter<double> ink;

  final VoidCallback onTap;

  @override
  State<_SegmentCell> createState() => _SegmentCellState();
}

class _SegmentCellState extends State<_SegmentCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    // Medium, the weight of the compact buttons: the mockup's segments take
    // whatever weight surrounds them, 600 in a card's header and 400 in a
    // settings row, and one control cannot be both.
    final TextStyle style = theme.textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w500,
    );
    final Color lit = style.color ?? theme.colorScheme.onSurface;
    final Color dim = theme.textTheme.titleMedium?.color ?? tokens.faint;
    final IconData? icon = widget.icon;

    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.selected ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              // Not on the selected one: the thumb is already there, and a
              // tint over it would read as a third state.
              color: _hovered && !widget.selected ? tokens.hover : null,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: _kSegmentPadding,
              // Sized to the label when the row asks what it needs, centred
              // when the row hands it a taller or a narrower box.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: AnimatedBuilder(
                  animation: widget.slide,
                  builder: (BuildContext context, Widget? _) {
                    final TextStyle inked = style.copyWith(
                      color: Color.lerp(dim, lit, widget.ink()),
                    );
                    if (icon == null) {
                      return Text(
                        widget.label,
                        style: inked,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    // One paragraph and not a Row: a paragraph narrower
                    // than its icon is clipped, a Row reports an overflow.
                    // The paragraph also puts the icon on the leading side
                    // by itself under a right-to-left interface.
                    return Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: _kIconGap,
                              ),
                              child: Icon(
                                icon,
                                size: _kIconSize,
                                color: inked.color,
                              ),
                            ),
                          ),
                          TextSpan(text: widget.label),
                        ],
                      ),
                      style: inked,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays the segments out in a row, each as wide as it asks, and the thumb
/// over the selected one.
///
/// The first child is the thumb; the rest are the segments in order. It is
/// a render object and not a `Stack` with an `AnimatedPositioned` because
/// the thumb's place is the segments' measured rectangles, which a widget
/// only learns a frame late: here they are known in the same layout pass, so
/// a label that changes length, a new text scale or a new direction moves
/// the thumb with it and never leaves it behind for a frame.
class _SegmentRow extends MultiChildRenderObjectWidget {
  const _SegmentRow({
    required this.selectedIndex,
    required this.slide,
    required this.textDirection,
    required super.children,
  });

  final int selectedIndex;
  final Animation<double> slide;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSegmentRow(
    selectedIndex: selectedIndex,
    slide: slide,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSegmentRow renderObject,
  ) {
    renderObject
      ..selectedIndex = selectedIndex
      ..slide = slide
      ..textDirection = textDirection;
  }
}

class _SegmentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSegmentRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SegmentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SegmentParentData> {
  _RenderSegmentRow({
    required this._selectedIndex,
    required this._slide,
    required this._textDirection,
  });

  /// Where the thumb was last laid out, and where the slide under way set
  /// off from. Rectangles and not indices: a pick made mid-slide starts
  /// from between two segments.
  Rect? _thumbRect;
  Rect? _slideFrom;

  int get selectedIndex => _selectedIndex;
  int _selectedIndex;
  set selectedIndex(int value) {
    if (value == _selectedIndex) {
      return;
    }
    _selectedIndex = value;
    _slideFrom = _thumbRect;
    markNeedsLayout();
  }

  Animation<double> get slide => _slide;
  Animation<double> _slide;
  set slide(Animation<double> value) {
    if (value == _slide) {
      return;
    }
    if (attached) {
      _slide.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _slide = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    // The row mirrors in one step: a slide across it would be motion that
    // no pick asked for.
    _slideFrom = null;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _slide.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _slide.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SegmentParentData) {
      child.parentData = _SegmentParentData();
    }
  }

  List<RenderBox> get _segments {
    final List<RenderBox> segments = <RenderBox>[];
    RenderBox? child = firstChild == null ? null : childAfter(firstChild!);
    while (child != null) {
      segments.add(child);
      child = childAfter(child);
    }
    return segments;
  }

  /// The size of each segment under [constraints]: what its label asks for,
  /// or the same share less of each where the labels do not fit, and one
  /// height for all. A hovered pill a pixel shorter than its neighbour
  /// shows.
  ///
  /// Measured dry, so that each segment is laid out once per pass and not
  /// once to be asked and once to be told.
  List<Size> _measure(List<RenderBox> segments, BoxConstraints constraints) {
    final BoxConstraints natural = BoxConstraints(
      maxHeight: constraints.maxHeight,
    );
    final List<Size> asked = <Size>[
      for (final RenderBox child in segments) child.getDryLayout(natural),
    ];
    double width = 0;
    double height = 0;
    for (final Size size in asked) {
      width += size.width;
      height = math.max(height, size.height);
    }
    final double squeeze = width > constraints.maxWidth
        ? constraints.maxWidth / width
        : 1;
    return <Size>[
      for (final Size size in asked) Size(size.width * squeeze, height),
    ];
  }

  Size _sizeOf(List<Size> sizes, BoxConstraints constraints) =>
      constraints.constrain(
        Size(
          sizes.fold(0, (double sum, Size size) => sum + size.width),
          sizes.isEmpty ? 0 : sizes.first.height,
        ),
      );

  @override
  double computeMinIntrinsicWidth(double height) => _segments.fold(
    0,
    (double sum, RenderBox child) => sum + child.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _segments.fold(
    0,
    (double sum, RenderBox child) => sum + child.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _segments.fold(
    0,
    (double tallest, RenderBox child) =>
        math.max(tallest, child.getMinIntrinsicHeight(double.infinity)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _segments.fold(
    0,
    (double tallest, RenderBox child) =>
        math.max(tallest, child.getMaxIntrinsicHeight(double.infinity)),
  );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final List<RenderBox> segments = _segments;
    final List<Size> sizes = _measure(segments, constraints);
    double? highest;
    for (int i = 0; i < segments.length; i++) {
      final double? distance = segments[i].getDryBaseline(
        BoxConstraints.tight(sizes[i]),
        baseline,
      );
      if (distance != null) {
        highest = highest == null ? distance : math.min(highest, distance);
      }
    }
    return highest;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _sizeOf(_measure(_segments, constraints), constraints);

  @override
  void performLayout() {
    final RenderBox? thumb = firstChild;
    if (thumb == null) {
      size = constraints.smallest;
      return;
    }
    final List<RenderBox> segments = _segments;
    final List<Size> sizes = _measure(segments, constraints);
    size = _sizeOf(sizes, constraints);

    final bool rtl = _textDirection == TextDirection.rtl;
    final List<Rect> rects = <Rect>[];
    double edge = rtl ? size.width : 0;
    for (int i = 0; i < segments.length; i++) {
      segments[i].layout(BoxConstraints.tight(sizes[i]));
      if (rtl) {
        edge -= sizes[i].width;
      }
      final Offset offset = Offset(edge, 0);
      (segments[i].parentData! as _SegmentParentData).offset = offset;
      rects.add(offset & sizes[i]);
      if (!rtl) {
        edge += sizes[i].width;
      }
    }

    // With nothing selected the thumb closes on the spot it held, and it
    // opens again on the spot it is given.
    final Rect? target = _selectedIndex >= 0 && _selectedIndex < rects.length
        ? rects[_selectedIndex]
        : null;
    final Rect? from = (_slideFrom?.isEmpty ?? true) ? null : _slideFrom;
    final Rect end = target ?? _closed(from ?? Rect.zero);
    final Rect rect = Rect.lerp(from ?? _closed(end), end, _slide.value)!;
    thumb.layout(BoxConstraints.tight(rect.size));
    (thumb.parentData! as _SegmentParentData).offset = rect.topLeft;
    _thumbRect = rect;
  }

  static Rect _closed(Rect rect) =>
      Rect.fromCenter(center: rect.center, width: 0, height: rect.height);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      // A closed thumb is not drawn: a stadium of no width still strokes
      // its line.
      if (!child.size.isEmpty) {
        context.paintChild(
          child,
          (child.parentData! as _SegmentParentData).offset + offset,
        );
      }
      child = childAfter(child);
    }
  }
}
