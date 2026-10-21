import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// A line that says what is being waited for, with a small ring before it
/// and an optional explanation behind a help mark.
class LoadingInfoText extends StatelessWidget {
  /// Creates the line.
  const LoadingInfoText({
    required this.text,
    this.tooltipText,
    super.key,
  });

  /// What is being waited for.
  final String text;

  /// Why, shown on hover of the help mark; no mark when null.
  final String? tooltipText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SyriusLoadingWidget(
          size: 14,
          strokeWidth: 1.5,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: dimColorOf(context)),
        ),
        if (tooltipText != null) ...<Widget>[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltipText,
            child: const Icon(
              Icons.help_outline,
              color: AppColors.faint,
              size: 14,
            ),
          ),
        ],
      ],
    );
  }
}
