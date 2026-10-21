import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// The confirmation before the wallet is erased from this computer.
///
/// Reset is the red outline, never the filled action, and Cancel takes the
/// focus first, so Enter on arrival does not erase anything.
class ResetWalletScreen extends StatefulWidget {
  const ResetWalletScreen({super.key});

  @override
  State<ResetWalletScreen> createState() => _ResetWalletScreenState();
}

class _ResetWalletScreenState extends State<ResetWalletScreen> {
  @override
  Widget build(BuildContext context) {
    return SettingsScreenFrame(
      title: 'Reset wallet',
      note:
          'Erases this wallet from this computer, for good. Without the seed '
          'phrase, or a Seed Vault and its key, the funds are lost.',
      actions: <Widget>[
        const ScreenBackAction(label: 'Cancel', autofocus: true),
        DangerAction(
          child: OutlinedButton(
            key: const Key('reset_wallet_confirm'),
            style: OutlinedButton.styleFrom(minimumSize: kScreenActionSize),
            onPressed: _onResetPressed,
            child: const Text('Reset'),
          ),
        ),
      ],
      child: const SizedBox.shrink(),
    );
  }

  Future<void> _onResetPressed() async {
    NodeUtils.closeEmbeddedNode();

    kLastDismissedNotification = kLastNotification;

    Navigator.pop(context);

    NavigationUtils.pushReplacement(
      context,
      const SplashScreen(
        resetWalletFlow: true,
      ),
    );
  }
}
