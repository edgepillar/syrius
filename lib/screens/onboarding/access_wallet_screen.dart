import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The welcome: the three ways into a wallet, one under the other, with
/// creating a new one as the main action.
class AccessWalletScreen extends StatefulWidget {
  const AccessWalletScreen({super.key});
  static const String route = 'access-wallet-screen';

  @override
  State<AccessWalletScreen> createState() => _AccessWalletScreenState();
}

class _AccessWalletScreenState extends State<AccessWalletScreen> {
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Welcome',
      maxWidth: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: _onCreateWalletButtonPressed,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: _buildIcon('assets/svg/ic_create_new.svg', kOnZnnColor),
            label: const Text('Create wallet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _onImportWalletButtonPressed,
            style:
                secondaryButtonStyle(
                  context,
                ).copyWith(
                  minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
                ),
            icon: _buildIcon(
              'assets/svg/ic_import_wallet.svg',
              AppColors.znnColor,
            ),
            label: const Text('Import wallet'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _onHardwareWalletButtonPressed,
            style:
                secondaryButtonStyle(
                  context,
                ).copyWith(
                  minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
                ),
            icon: _buildIcon(
              'assets/svg/ic_hardware_wallet.svg',
              AppColors.znnColor,
            ),
            label: const Text('Hardware wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String asset, Color color) {
    return SvgPicture.asset(
      asset,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  void _onCreateWalletButtonPressed() {
    NavigationUtils.push(
      context,
      const NewWalletSeedChoiceScreen(
        export: false,
      ),
    );
  }

  void _onImportWalletButtonPressed() {
    NavigationUtils.push(
      context,
      const ImportWalletSeedChoiceScreen(),
    );
  }

  void _onHardwareWalletButtonPressed() {
    NavigationUtils.push(
      context,
      const HardwareWalletDeviceChoiceScreen(),
    );
  }
}
