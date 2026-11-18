import 'package:material_ui/material_ui.dart';

/// Keeps project details in the Accelerator pane of the current shell.
class AcceleratorPanelNavigation extends StatefulWidget {
  /// Hosts the owned project list and its detail transitions.
  const AcceleratorPanelNavigation({required this.child, super.key});

  /// The permanent list route beneath the project detail transitions.
  final Widget child;

  /// The outer route stays authoritative while an inner detail is current.
  static ModalRoute<dynamic>? hostRouteOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AcceleratorPanelHost>()
      ?.route;

  @override
  State<AcceleratorPanelNavigation> createState() =>
      _AcceleratorPanelNavigationState();
}

class _AcceleratorPanelNavigationState
    extends State<AcceleratorPanelNavigation> {
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
        if (mounted && enabled && (host?.isCurrent ?? true) &&
            navigator != null && navigator.canPop()) {
          navigator.pop<void>();
        }
      },
      child: _AcceleratorPanelHost(
        route: host,
        child: TickerMode(
          enabled: visible,
          child: HeroControllerScope.none(
            child: Navigator(
              key: _navigator,
              pages: <Page<void>>[
                MaterialPage<void>(
                  key: const ValueKey<String>('accelerator_projects_page'),
                  child: widget.child,
                ),
              ],
              // Only the pageless project details are dismissible here.
              onDidRemovePage: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceleratorPanelHost extends InheritedWidget {
  const _AcceleratorPanelHost({required this.route, required super.child});

  final ModalRoute<dynamic>? route;

  @override
  bool updateShouldNotify(_AcceleratorPanelHost oldWidget) =>
      !identical(route, oldWidget.route);
}
