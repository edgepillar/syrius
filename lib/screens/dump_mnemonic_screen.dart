import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The card's width once the words are shown: six boxes to a row.
const double _kSeedCardWidth = 860;

/// Shows the seed phrase, after the wallet password.
///
/// The words come from decrypting the wallet file with what was typed, never
/// from the unlocked session, and each stays behind dots until the pointer
/// is on it or its number is pressed.
class DumpMnemonicScreen extends StatefulWidget {
  const DumpMnemonicScreen({super.key});

  @override
  State<DumpMnemonicScreen> createState() => _DumpMnemonicScreenState();
}

class _DumpMnemonicScreenState extends State<DumpMnemonicScreen> {
  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<LoadingButtonState> _continueButtonKey = GlobalKey();

  LoadingButton? _continueButton;

  String? _passwordError;

  List<String>? _seedWords;

  @override
  Widget build(BuildContext context) {
    _continueButton = _buildContinueButton();
    final List<String>? seedWords = _seedWords;
    final bool shown = seedWords != null;
    return SettingsScreenFrame(
      title: 'Seed phrase',
      note: shown
          ? 'Anyone with these words can spend from this wallet. Point at a '
                'word to read it, or press its number to keep it shown.'
          : 'Enter the wallet password to show it.',
      width: shown ? _kSeedCardWidth : 480,
      actions: <Widget>[
        if (shown)
          _buildDoneButton()
        else ...<Widget>[
          const ScreenBackAction(),
          _continueButton!,
        ],
      ],
      child: StateSwitcher(
        axis: Axis.horizontal,
        child: shown
            ? SeedGrid(
                seedWords,
                key: const ValueKey<String>('seed_phrase_words'),
                enableSeedInputFields: false,
              )
            // The switcher lays its states out loose; the box gives the
            // field the card's width.
            : SizedBox(
                key: const ValueKey<String>('seed_phrase_password'),
                width: double.infinity,
                child: PasswordInputField(
                  controller: _passwordController,
                  hintText: 'Current password',
                  onSubmitted: (String value) {
                    _continueButton!.onPressed?.call();
                  },
                  onChanged: (String value) {
                    setState(() {});
                  },
                  errorText: _passwordError,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildDoneButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: kScreenActionSize),
      onPressed: () {
        Navigator.of(context).pop();
      },
      child: const Text('Done'),
    );
  }

  Future<void> _onContinueButtonPressed() async {
    if (_passwordController.text.isNotEmpty) {
      try {
        _continueButtonKey.currentState!.animateForward();
        final WalletFile walletFile = await WalletUtils.decryptWalletFile(
          kWalletPath!,
          _passwordController.text,
        );
        walletFile.open().then((Wallet wallet) {
          if (!mounted) return;
          setState(() {
            _passwordController.clear();
            _seedWords = (wallet as KeyStore).mnemonic!.split(' ');
            _passwordError = null;
          });
        });
      } on IncorrectPasswordException {
        setState(() {
          _passwordError = kIncorrectPasswordNotificationTitle;
        });
      } catch (e) {
        setState(() {
          _passwordError = e.toString();
        });
      } finally {
        _continueButtonKey.currentState?.animateReverse();
      }
    }
  }

  LoadingButton _buildContinueButton() {
    return LoadingButton(
      onPressed: _passwordController.text.isNotEmpty
          ? _onContinueButtonPressed
          : null,
      text: 'Show',
      minimumSize: kScreenActionSize,
      key: _continueButtonKey,
    );
  }
}
