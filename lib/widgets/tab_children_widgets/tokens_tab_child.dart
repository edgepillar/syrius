import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/tokens/tokens.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/shell_pane_navigation.dart';

/// Tokens has one ledger with the selected address's balance in each row.
class TokensTabChild extends StatelessWidget {
  /// Preserves the existing create-token notification route.
  const TokensTabChild({
    required this._onStepperNotificationSeeMorePressed,
    this.controller,
    this.onSendToken,
    this.isPageCurrent,
    super.key,
  });

  final VoidCallback _onStepperNotificationSeeMorePressed;

  /// The shell retains filter, query and scroll across ordinary navigation.
  final TokensPageController? controller;

  /// Opens the original selected token in the shell's Send mode.
  final ValueChanged<String>? onSendToken;

  /// The shell checks whether this destination still owns its pane.
  final bool Function()? isPageCurrent;

  @override
  Widget build(BuildContext context) {
    final TokensPage page = TokensPage(
      controller: controller,
      onSendToken: onSendToken,
      isPageCurrent: isPageCurrent,
      onStepperNotificationSeeMorePressed: _onStepperNotificationSeeMorePressed,
    );
    return isPageCurrent == null ? page : ShellPaneNavigation(child: page);
  }
}
