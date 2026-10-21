import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A row that leaves out what does not fit, least important first.
///
/// The strip's parts are not known to one another: a block in flight, a
/// plasma label and an update notice each appear on their own clock, and
/// together they are wider than the smallest window. A `Row` paints its
/// overflow stripes then, and a `Flexible` on every part would squeeze the
/// height's digits as readily as the peer count. Here each child says how
/// much it matters ([Prioritized.priority], 0 first) and room is handed out
/// in that order. A child that does not fit is not drawn, not hit and not
/// read out, and neither is any child that matters less; it stays built, so
/// it keeps its state and comes back on the frame the room does.
///
/// Children are placed in the order they are given, from the start; those
/// marked [Prioritized.end] sit against the far edge. A child of no width
/// takes no gap.
class PriorityRow extends MultiChildRenderObjectWidget {
  /// Creates the row. Every child is a [Prioritized].
  const PriorityRow({
    required List<Prioritized> super.children,
    this.gap = 0,
    this.fill = true,
    super.key,
  });

  /// The room between two children that are shown.
  final double gap;

  /// Whether the row is as wide as it is allowed, or as wide as what it
  /// shows.
  final bool fill;

  @override
  RenderPriorityRow createRenderObject(BuildContext context) =>
      RenderPriorityRow(
        gap: gap,
        fill: fill,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPriorityRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..fill = fill
      ..textDirection = Directionality.of(context);
  }
}

/// One part of a [PriorityRow] and how much it matters.
class Prioritized extends ParentDataWidget<PriorityRowParentData> {
  /// Places [child] in the row with [priority]; 0 is given room first.
  const Prioritized({
    required this.priority,
    required super.child,
    this.shrink = false,
    this.minWidth = 0,
    this.end = false,
    super.key,
  });

  /// The order in which room is handed out, lowest first.
  final int priority;

  /// Whether the child can be drawn narrower than it asks: one that cuts
  /// its own text. It is given what is left and takes what it needs of it.
  /// A child that cannot is shown at its own width or not at all.
  final bool shrink;

  /// For a [shrink] child: with less room than this it is left out.
  final double minWidth;

  /// Whether the child sits against the row's far edge.
  final bool end;

  @override
  void applyParentData(RenderObject renderObject) {
    final PriorityRowParentData data =
        renderObject.parentData! as PriorityRowParentData;
    if (data.priority != priority ||
        data.shrink != shrink ||
        data.minWidth != minWidth ||
        data.end != end) {
      data
        ..priority = priority
        ..shrink = shrink
        ..minWidth = minWidth
        ..end = end;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => PriorityRow;
}

/// What a [RenderPriorityRow] keeps on each child.
class PriorityRowParentData extends ContainerBoxParentData<RenderBox> {
  /// See [Prioritized.priority].
  int priority = 0;

  /// See [Prioritized.shrink].
  bool shrink = false;

  /// See [Prioritized.minWidth].
  double minWidth = 0;

  /// See [Prioritized.end].
  bool end = false;

  /// Whether the last layout found room for the child.
  bool shown = true;
}

/// The layout of a [PriorityRow].
class RenderPriorityRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PriorityRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PriorityRowParentData> {
  /// Creates the layout.
  RenderPriorityRow({
    required this._gap,
    required this._fill,
    required this._textDirection,
  });

  /// See [PriorityRow.gap].
  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (_gap != value) {
      _gap = value;
      markNeedsLayout();
    }
  }

  /// See [PriorityRow.fill].
  bool get fill => _fill;
  bool _fill;
  set fill(bool value) {
    if (_fill != value) {
      _fill = value;
      markNeedsLayout();
    }
  }

  /// Which edge is the start.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PriorityRowParentData) {
      child.parentData = PriorityRowParentData();
    }
  }

  static PriorityRowParentData _data(RenderBox child) =>
      child.parentData! as PriorityRowParentData;

  @override
  void performLayout() {
    final List<RenderBox> children = getChildrenAsList();
    final double maxHeight = constraints.maxHeight;
    // Its own width, whatever that is: how a child that must not be
    // squeezed is measured, and how one that is left out is laid out, so
    // that nothing in it overflows unseen.
    final BoxConstraints natural = BoxConstraints(maxHeight: maxHeight);

    // By priority, and by place among equals: List.sort keeps no order.
    final List<int> order = <int>[for (int i = 0; i < children.length; i++) i]
      ..sort((int a, int b) {
        final int byPriority = _data(
          children[a],
        ).priority.compareTo(_data(children[b]).priority);
        return byPriority != 0 ? byPriority : a.compareTo(b);
      });

    double left = constraints.maxWidth;
    double used = 0;
    int shown = 0;
    // Once a part is left out, so is every part that matters less, even
    // one small enough for the room that remains: the peers must not stay
    // when the chain has gone.
    bool full = false;
    for (final int index in order) {
      final RenderBox child = children[index];
      final PriorityRowParentData data = _data(child);
      final double lead = shown > 0 ? gap : 0;
      final bool fits;
      if (!full && data.shrink && left - lead >= data.minWidth) {
        child.layout(
          BoxConstraints(maxWidth: left - lead, maxHeight: maxHeight),
          parentUsesSize: true,
        );
        fits = true;
      } else {
        child.layout(natural, parentUsesSize: true);
        // A part with nothing in it is not left out, and ends nothing.
        // Half a pixel of slack otherwise: a text's width is not a whole
        // number, and a part that fits to the eye should not blink out.
        fits =
            child.size.width == 0 ||
            (!full && !data.shrink && child.size.width + lead <= left + 0.5);
      }
      data.shown = fits;
      if (!fits) {
        full = true;
        continue;
      }
      final double width = child.size.width;
      if (width > 0) {
        left -= width + lead;
        used += width + lead;
        shown += 1;
      }
    }

    double height = 0;
    for (final RenderBox child in children) {
      if (_data(child).shown && child.size.height > height) {
        height = child.size.height;
      }
    }
    size = constraints.constrain(
      Size(
        fill && constraints.hasBoundedWidth ? constraints.maxWidth : used,
        height,
      ),
    );

    double fromStart = 0;
    for (final RenderBox child in children) {
      final PriorityRowParentData data = _data(child);
      if (!data.shown || data.end) {
        continue;
      }
      _place(child, fromStart);
      if (child.size.width > 0) {
        fromStart += child.size.width + gap;
      }
    }
    double fromEnd = size.width;
    for (final RenderBox child in children.reversed) {
      final PriorityRowParentData data = _data(child);
      if (!data.shown || !data.end) {
        continue;
      }
      fromEnd -= child.size.width;
      _place(child, fromEnd);
      if (child.size.width > 0) {
        fromEnd -= gap;
      }
    }
  }

  /// Puts [child] at [start] from the row's start edge, centred vertically.
  void _place(RenderBox child, double start) {
    final double dx = textDirection == TextDirection.ltr
        ? start
        : size.width - start - child.size.width;
    _data(child).offset = Offset(dx, (size.height - child.size.height) / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final PriorityRowParentData data = _data(child);
      if (data.shown) {
        context.paintChild(child, data.offset + offset);
      }
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final PriorityRowParentData data = _data(child);
      final RenderBox current = child;
      if (data.shown &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (BoxHitTestResult result, Offset transformed) =>
                current.hitTest(result, position: transformed),
          )) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      final PriorityRowParentData data = _data(child);
      if (data.shown) {
        visitor(child);
      }
      child = data.nextSibling;
    }
  }

  /// Whether the last layout found room for the child at [index]. For the
  /// tests: a part left out is still in the widget tree.
  @visibleForTesting
  bool debugShown(int index) => _data(getChildrenAsList()[index]).shown;
}
