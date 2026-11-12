import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// Keeps the page owner mounted while entry and working geometry change.
class ShellFrame extends StatelessWidget {
  /// Creates a shell with independently owned rail, page and status surfaces.
  const ShellFrame({
    required this.locked,
    required this.rail,
    required this.page,
    required this.status,
    super.key,
  });

  /// Entry mode removes rail interaction and gives the page the whole field.
  final ValueListenable<bool> locked;

  /// The rail retains its collapse choice while it is hidden at entry.
  final Widget rail;

  /// The current page retains its state across a lock-status change.
  final Widget page;

  /// Connection status remains available at entry without wallet flight data.
  final Widget status;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: locked,
    builder: (BuildContext context, bool locked, _) {
      final AppTokens tokens = AppTokens.of(context);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Offstage(
            offstage: locked,
            child: TickerMode(
              enabled: !locked,
              child: ExcludeFocus(
                excluding: locked,
                child: ExcludeSemantics(
                  excluding: locked,
                  child: IgnorePointer(
                    ignoring: locked,
                    child: RepaintBoundary(child: rail),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: locked ? 0 : tokens.shellRailGap),
          Expanded(
            child: Padding(
              padding: locked ? EdgeInsets.zero : tokens.shellPadding,
              child: CustomMultiChildLayout(
                delegate: _ShellSurfaceLayout(
                  locked: locked,
                  gap: tokens.shellStatusGap,
                ),
                children: <Widget>[
                  LayoutId(
                    id: _ShellSurface.page,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.cardRadius),
                      clipBehavior: locked ? Clip.none : Clip.antiAlias,
                      child: RepaintBoundary(child: page),
                    ),
                  ),
                  LayoutId(
                    id: _ShellSurface.status,
                    child: Padding(
                      padding: locked
                          ? tokens.lockedStatusPadding
                          : EdgeInsets.zero,
                      child: RepaintBoundary(child: status),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

enum _ShellSurface { page, status }

/// Entry is centered in the full field. Its inset status stays above that
/// field; the working page instead reserves the status's actual height.
class _ShellSurfaceLayout extends MultiChildLayoutDelegate {
  _ShellSurfaceLayout({required this.locked, required this.gap});

  final bool locked;
  final double gap;

  @override
  void performLayout(Size size) {
    final Size status = layoutChild(
      _ShellSurface.status,
      BoxConstraints(maxWidth: size.width, maxHeight: size.height),
    );
    positionChild(_ShellSurface.status, Offset(0, size.height - status.height));
    final double pageHeight = locked
        ? size.height
        : (size.height - status.height - gap).clamp(0.0, size.height);
    layoutChild(
      _ShellSurface.page,
      BoxConstraints.tight(Size(size.width, pageHeight)),
    );
    positionChild(_ShellSurface.page, Offset.zero);
  }

  @override
  bool shouldRelayout(_ShellSurfaceLayout oldDelegate) =>
      locked != oldDelegate.locked || gap != oldDelegate.gap;
}
