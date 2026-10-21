import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The last step: the wallet is made. The map animation is kept as it was.
class WalletSuccessScreen extends StatefulWidget {
  const WalletSuccessScreen({
    this.progressBarNumLevels = 5,
    super.key,
  });
  final int progressBarNumLevels;

  @override
  State<WalletSuccessScreen> createState() => _WalletSuccessScreenState();
}

class _WalletSuccessScreenState extends State<WalletSuccessScreen> {
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.progressBarNumLevels,
      steps: widget.progressBarNumLevels,
      title: "You're all set",
      subtitle: 'Your wallet is ready',
      maxWidth: 560,
      primary: _getAccessWalletActionButton(),
      child: const SizedBox(
        height: 260,
        // The animation repaints every frame; its own layer keeps that off
        // the page.
        child: AppLottie(AppLottieAsset.map, fit: BoxFit.contain),
      ),
    );
  }

  Widget _getAccessWalletActionButton() {
    return OnboardingButton(
      onPressed: () {
        Navigator.popUntil(
          context,
          ModalRoute.withName(AccessWalletScreen.route),
        );
        NavigationUtils.pushReplacement(
          context,
          const MainAppContainer(
            redirectedFromWalletSuccess: true,
          ),
        );
      },
      text: 'Access wallet',
    );
  }
}
