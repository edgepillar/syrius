import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/sheen.dart';

/// The main action of a card or page: the filled green pill, with its sheen.
///
/// The app theme already styles every [OutlinedButton] as this pill
/// (`primaryButtonStyle`), so this widget adds only the [Sheen]. It exists
/// so a page can adopt the sheen by renaming one constructor instead of
/// wrapping its button by hand.
class PrimaryPill extends StatelessWidget {
  /// A pill round [child]. A null [onPressed] is the empty outline of an
  /// action that is not ready, which gets no sheen.
  const PrimaryPill({
    required this.onPressed,
    required this.child,
    this.icon,
    this.sheen,
    this.style,
    super.key,
  });

  /// Called on a tap. Null disables the pill.
  final VoidCallback? onPressed;

  /// The label.
  final Widget child;

  /// Drawn before the label.
  final Widget? icon;

  /// Call [SheenController.pass] on it when the action lands.
  final SheenController? sheen;

  /// Merged over the theme's pill. It must keep the stadium shape and the
  /// shrink-wrapped tap target, which the sheen's clip relies on.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return Sheen(
      enabled: onPressed != null,
      controller: sheen,
      child: icon == null
          ? OutlinedButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: child,
            ),
    );
  }
}
