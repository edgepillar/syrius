import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/sheen.dart';

/// The main action of a card or page: the plasma pill, with its sheen.
///
/// The gradient belongs to this explicit primary control. Applying it to the
/// outlined-button theme would also fill secondary and destructive actions.
/// The button keeps Material's input, semantics and focus handling; the
/// decoration changes only its paint.
class PrimaryPill extends StatelessWidget {
  /// A pill round [child]. A null [onPressed] holds input and hover and
  /// dims the surface by default. Accepted-result feedback remains presentation.
  const PrimaryPill({
    required this.onPressed,
    required this.child,
    this.icon,
    this.sheen,
    this.busy = false,
    this.dimWhenDisabled = true,
    this.style,
    super.key,
  });

  /// Called on a tap. Null disables the pill.
  final VoidCallback? onPressed;

  /// The label.
  final Widget child;

  /// Drawn before the label.
  final Widget? icon;

  /// Reports only this action's original accepted result.
  final SheenController? sheen;

  /// Holds feedback over a busy spinner without changing input admission.
  final bool busy;

  /// Allows a surrounding transition to own the surface opacity.
  final bool dimWhenDisabled;

  /// Merged over the theme's pill. It must keep the stadium shape and the
  /// shrink-wrapped tap target, which the sheen's clip relies on. Explicit
  /// density overrides remain owned by the caller.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool enabled = onPressed != null;
    final ButtonStyle pillStyle = (style ?? const ButtonStyle())
        .merge(
          ButtonStyle(
            visualDensity: VisualDensity.standard,
            minimumSize: WidgetStatePropertyAll<Size>(
              Size(0, tokens.buttonHeight),
            ),
            textStyle: WidgetStatePropertyAll<TextStyle>(tokens.buttonText),
            padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
              tokens.primaryButtonPadding,
            ),
          ),
        )
        .copyWith(
          backgroundColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(
            tokens.primaryButtonForeground,
          ),
          iconColor: WidgetStatePropertyAll<Color>(
            tokens.primaryButtonForeground,
          ),
          side:
              style?.side ??
              const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
        );
    final Widget button = icon == null
        ? OutlinedButton(
            onPressed: onPressed,
            style: pillStyle,
            child: child,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: pillStyle,
            icon: icon,
            label: child,
          );
    return Sheen(
      enabled: enabled,
      busy: busy,
      controller: sheen,
      child: Opacity(
        opacity: enabled || !dimWhenDisabled ? 1 : tokens.disabledOpacity,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            gradient: tokens.plasma,
            shape: const StadiumBorder(),
          ),
          child: button,
        ),
      ),
    );
  }
}
