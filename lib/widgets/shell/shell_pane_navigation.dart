import 'package:material_ui/material_ui.dart';

/// Keeps a destination's routes inside its pane of the current shell.
class ShellPaneNavigation extends StatefulWidget {
  /// Hosts the permanent destination and its local routes.
  const ShellPaneNavigation({
    required this.child,
    this.keepTickersUnderDialogs = false,
    super.key,
  });

  /// The permanent route beneath this pane's transient routes.
  final Widget child;

  /// Keeps the original destination's confirmation owner live under dialogs.
  final bool keepTickersUnderDialogs;

  /// The outer route stays authoritative while a local route is current.
  static ModalRoute<dynamic>? hostRouteOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ShellPaneHost>()
      ?.route;

  /// Checks the local route and the shell route that can cover it.
  static bool isCurrentRoute(BuildContext context) =>
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (hostRouteOf(context)?.isCurrent ?? true);

  @override
  State<ShellPaneNavigation> createState() => _ShellPaneNavigationState();
}

class _ShellPaneNavigationState extends State<ShellPaneNavigation> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? host = ModalRoute.of(context);
    final bool visible = host?.isCurrent ?? true;
    final bool enabled = visible && TickerMode.valuesOf(context).enabled;
    return NavigatorPopHandler<void>(
      enabled: enabled,
      onPopWithResult: (_) {
        final NavigatorState? navigator = _navigator.currentState;
        if (mounted &&
            enabled &&
            (host?.isCurrent ?? true) &&
            navigator != null &&
            navigator.canPop()) {
          navigator.pop<void>();
        }
      },
      child: _ShellPaneHost(
        route: host,
        child: TickerMode(
          enabled: visible || widget.keepTickersUnderDialogs,
          child: HeroControllerScope.none(
            child: Navigator(
              key: _navigator,
              pages: <Page<void>>[
                MaterialPage<void>(
                  key: const ValueKey<String>('shell_pane_root'),
                  child: widget.child,
                ),
              ],
              // Only routes above the permanent page are dismissible here.
              onDidRemovePage: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellPaneHost extends InheritedWidget {
  const _ShellPaneHost({required this.route, required super.child});

  final ModalRoute<dynamic>? route;

  @override
  bool updateShouldNotify(_ShellPaneHost oldWidget) =>
      !identical(route, oldWidget.route);
}
