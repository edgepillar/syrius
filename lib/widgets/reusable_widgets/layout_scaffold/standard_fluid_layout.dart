import 'package:material_ui/material_ui.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:layout/layout.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/layout_scaffold/widget_animator.dart';

const int kStaggeredNumOfColumns = 12;

/// The shortest a grid row may be. Rows were as tall as a column is wide, so
/// when the side rail took 200 px from the page every card got shorter and
/// the Send card lost its button. 110 px is a row's height at 1500 px wide
/// before the rail: cards keep that height and grow on wider windows.
const double kMinGridRowHeight = 110;

class StandardFluidLayout extends StatelessWidget {
  final List<FluidCell> children;
  final int? defaultCellWidth;
  final double? defaultCellHeight;

  /// See [kMinGridRowHeight]. 0 keeps rows exactly as wide as a column, for
  /// a screen outside the rail whose cards must fit the window.
  final double minRowHeight;

  const StandardFluidLayout({
    required this.children,
    this.defaultCellWidth,
    this.defaultCellHeight = kStaggeredNumOfColumns / 4,
    this.minRowHeight = kMinGridRowHeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Layout(
      format: FluidLayoutFormat(),
      child: Builder(
        builder: (BuildContext context) {
          const int crossAxisCount = kStaggeredNumOfColumns;

          final double spacing = context.breakpoint < LayoutBreakpoint.sm
              ? 4.0
              : 12.0;

          final int totalDurationMs = children.length > 5 ? 800 : 400;

          final int durationPerTile = totalDurationMs ~/ children.length;

          final List<StaggeredGridTile> tiles =
              List<StaggeredGridTile>.generate(
                children.length,
                (int index) {
                  final int widgetAnimatorOffset =
                      durationPerTile * (index + 1);

                  return _generateStaggeredTitle(
                    children[index],
                    widgetAnimatorOffset,
                  );
                },
              );

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double column =
                  (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
              final double row = column < minRowHeight ? minRowHeight : column;
              return SingleChildScrollView(
                child: StaggeredGrid.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  children: <Widget>[
                    for (int i = 0; i < tiles.length; i++)
                      StaggeredGridTile.extent(
                        crossAxisCellCount: tiles[i].crossAxisCellCount,
                        mainAxisExtent: _extent(
                          children[i].height ?? defaultCellHeight!,
                          row,
                          spacing,
                        ),
                        child: tiles[i].child,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// The height of a tile [cells] rows tall, gaps between its rows included,
  /// as `StaggeredGridTile.count` measured it.
  static double _extent(double cells, double row, double spacing) =>
      cells * row + (cells - 1).clamp(0, double.infinity) * spacing;

  StaggeredGridTile _generateStaggeredTitle(
    FluidCell fluidCell,
    int widgetAnimatorOffset,
  ) {
    return StaggeredGridTile.count(
      crossAxisCellCount: fluidCell.width ?? defaultCellWidth!,
      mainAxisCellCount: fluidCell.height ?? defaultCellHeight!,
      child: WidgetAnimator(
        animationOffset: Duration(
          milliseconds: widgetAnimatorOffset,
        ),
        child: fluidCell.child,
      ),
    );
  }
}

class FluidCell {
  const FluidCell({
    required this.child,
    this.width,
    this.height,
  });

  FluidCell.large({
    required Widget child,
    required BuildContext context,
  }) : this(
         width: context.layout.value(
           xl: kStaggeredNumOfColumns ~/ 1.2,
           lg: kStaggeredNumOfColumns ~/ 1.2,
           md: kStaggeredNumOfColumns ~/ 1.2,
           sm: kStaggeredNumOfColumns,
           xs: kStaggeredNumOfColumns,
         ),
         child: child,
       );

  FluidCell.medium({required Widget child, required BuildContext context})
    : this(
        width: context.layout.value(
          xl: kStaggeredNumOfColumns ~/ 2,
          lg: kStaggeredNumOfColumns ~/ 2,
          md: kStaggeredNumOfColumns ~/ 2,
          sm: kStaggeredNumOfColumns,
          xs: kStaggeredNumOfColumns,
        ),
        child: child,
      );

  FluidCell.small({required Widget child, required BuildContext context})
    : this(
        width: context.layout.value(
          xl: kStaggeredNumOfColumns ~/ 6,
          lg: kStaggeredNumOfColumns ~/ 6,
          md: kStaggeredNumOfColumns ~/ 6,
          sm: kStaggeredNumOfColumns,
          xs: kStaggeredNumOfColumns,
        ),
        child: child,
      );

  final int? width;
  final double? height;
  final Widget child;
}
