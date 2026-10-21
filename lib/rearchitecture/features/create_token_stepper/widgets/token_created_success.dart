import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// Success UI shown after a token has been created.
class TokenCreatedSuccess extends StatelessWidget {
  /// Creates a [TokenCreatedSuccess].
  const TokenCreatedSuccess({
    required this.onCreateAnotherTokenPressed,
    required this.onViewTokensPressed,
    super.key,
  });

  /// Called when the user wants to create another token.
  final VoidCallback onCreateAnotherTokenPressed;

  /// Called when the user wants to return to the tokens view.
  final VoidCallback onViewTokensPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: 50,
        bottom: 20,
      ),
      // The quiet way on first, the main one last, as under every step.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextButton.icon(
            style: quietButtonStyle(context),
            onPressed: onCreateAnotherTokenPressed,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(context.l10n.createAnotherToken),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onViewTokensPressed,
            child: Text(context.l10n.viewMyTokens),
          ),
        ],
      ),
    );
  }
}

/// Animated token success illustration.
class TokenCreatedSuccessAnimation extends StatelessWidget {
  /// Creates a [TokenCreatedSuccessAnimation].
  const TokenCreatedSuccessAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    // At the end of the line, so it stays clear of the steps when the
    // interface runs right to left.
    return const PositionedDirectional(
      end: 50,
      child: SizedBox(
        width: 400,
        height: 400,
        child: Center(
          child: AppLottie(AppLottieAsset.zts, size: 400, repeat: false),
        ),
      ),
    );
  }
}
