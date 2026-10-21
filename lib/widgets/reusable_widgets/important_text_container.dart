import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// A note the person should read before going on. With [showBorder] it is a
/// warning and takes the error colour.
class ImportantTextContainer extends StatelessWidget {
  /// Creates the note.
  const ImportantTextContainer({
    required this.text,
    this.showBorder = false,
    this.isSelectable = false,
    super.key,
  });

  /// What it says.
  final String text;

  /// Whether it is a warning.
  final bool showBorder;

  /// Whether the text can be selected and copied.
  final bool isSelectable;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: Theme.of(context).textTheme.bodyLarge?.color,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        border: Border.all(
          color: showBorder ? AppColors.errorColor : lineColorOf(context),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(kCardRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              size: 16,
              color: showBorder ? AppColors.errorColor : AppColors.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isSelectable
                  ? SelectableText(text, style: style)
                  : Text(text, style: style),
            ),
          ],
        ),
      ),
    );
  }
}
