import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// A shortcut key with the reference's content padding and outer border.
class AppKeyHint extends StatelessWidget {
  /// Displays [label] in left-to-right keyboard notation.
  const AppKeyHint(String label, {super.key}) : _label = label;

  final String _label;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final Border outline = Border.all(color: tokens.line);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: outline,
        borderRadius: BorderRadius.circular(tokens.keyboardHintRadius),
      ),
      child: Padding(
        padding: tokens.keyboardHintPadding.add(outline.dimensions),
        child: Text(
          _label,
          style: tokens.keyboardHintText,
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  }
}
