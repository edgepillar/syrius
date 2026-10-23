import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/welcome_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';

/// The welcome: the three ways into a wallet, one under the other, with
/// creating a new one as the main action.
class AccessWalletScreen extends StatefulWidget {
  /// Presents entry choices without eagerly mounting their wallet owners.
  const AccessWalletScreen({super.key});

  /// Stable route name for the existing wallet-entry destination.
  static const String route = 'access-wallet-screen';

  @override
  State<AccessWalletScreen> createState() => _AccessWalletScreenState();
}

class _AccessWalletScreenState extends State<AccessWalletScreen> {
  final Object _source = Object();

  @override
  Widget build(BuildContext context) => WelcomeSurface(
    source: _source,
    onSelected: _onSelected,
  );

  void _onSelected(WelcomeDestination destination) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    // These owners generate seed material, clear address state or construct
    // Ledger access on mount. Only an admitted row press constructs one.
    switch (destination) {
      case WelcomeDestination.createWallet:
        NavigationUtils.push(
          context,
          const NewWalletSeedChoiceScreen(),
        );
      case WelcomeDestination.importWallet:
        NavigationUtils.push(context, const ImportWalletSeedChoiceScreen());
      case WelcomeDestination.hardwareWallet:
        NavigationUtils.push(
          context,
          const HardwareWalletDeviceChoiceScreen(),
        );
    }
  }
}
