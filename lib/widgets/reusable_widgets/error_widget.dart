import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// What a card shows when its data could not be had: one quiet line, and a
/// "Retry" when the caller has one to offer.
///
/// It is also a route of its own (see [route]), shown when the app cannot
/// start, so it brings its own Material.
class SyriusErrorWidget extends StatelessWidget {
  /// Creates the line for [error].
  const SyriusErrorWidget(
    this.error, {
    this.onRetry,
    super.key,
  });

  /// The name of the route that shows a start-up failure.
  static const String route = 'syrius-error-widget';

  /// What went wrong; shown through its `toString`.
  final Object error;

  /// Tries again. No button when null.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final String text = _getErrorText(context, error.toString());
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.faint,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Tooltip(
                        message: text,
                        waitDuration: Durations.long2,
                        child: Text(
                          text,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: dimColorOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: quietButtonStyle(context),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The literal is json_rpc_2's own text and is never translated, so it can
  // be matched in any language.
  String _getErrorText(BuildContext context, String errorText) =>
      errorText.toLowerCase().contains('bad state: the client is closed')
      ? context.l10n.commonNotConnectedError
      : errorText;
}
