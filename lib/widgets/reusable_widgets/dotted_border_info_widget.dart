import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// A hint in a hairline box, marked in [borderColor].
///
/// It was a dashed green frame; the refreshed interface keeps hints quiet, so
/// only the mark carries the colour and the frame is a faint line of it.
class DottedBorderInfoWidget extends StatefulWidget {
  /// Creates the hint.
  const DottedBorderInfoWidget({
    required this.text,
    this.borderColor = AppColors.znnColor,
    super.key,
  });

  /// What it says.
  final String text;

  /// The colour of the mark, and faintly of the frame.
  final Color borderColor;

  @override
  State<DottedBorderInfoWidget> createState() => _DottedBorderInfoWidgetState();
}

class _DottedBorderInfoWidgetState extends State<DottedBorderInfoWidget> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: widget.borderColor.withValues(alpha: 0.35)),
        borderRadius: const BorderRadius.all(Radius.circular(kCardRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.info_outline, size: 16, color: widget.borderColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: dimColorOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
