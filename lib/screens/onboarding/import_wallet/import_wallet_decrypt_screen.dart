import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ImportWalletDecryptScreen extends StatefulWidget {
  const ImportWalletDecryptScreen(this.path, {super.key});
  final String path;

  @override
  State<ImportWalletDecryptScreen> createState() =>
      _ImportWalletDecryptScreenState();
}

class _ImportWalletDecryptScreenState extends State<ImportWalletDecryptScreen> {
  String? _passwordErrorText;

  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<LoadingButtonState> _loadingButtonKey = GlobalKey();

  late LoadingButton _loadingButton;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      title: 'Unlock the wallet file',
      subtitle: 'Enter the password it was saved with',
      onBack: () {
        Navigator.pop(context);
      },
      primary: _getDecryptKeyStoreFileViewModel(),
      child: PasswordInputField(
        hintText: 'Password',
        controller: _passwordController,
        onChanged: (String value) {
          setState(() {});
        },
        errorText: _passwordErrorText,
        onSubmitted: (String value) {
          if (_passwordController.text.isNotEmpty) {
            _loadingButton.onPressed!();
          }
        },
      ),
    );
  }

  LoadingButton _getLoadingButton(DecryptWalletFileBloc model) {
    return LoadingButton.onboarding(
      key: _loadingButtonKey,
      onPressed: _passwordController.text.isNotEmpty
          ? () async {
              _loadingButtonKey.currentState!.animateForward();
              await model.decryptWalletFile(
                widget.path,
                _passwordController.text,
              );
            }
          : null,
      text: 'Continue',
    );
  }

  ViewModelBuilder<DecryptWalletFileBloc> _getDecryptKeyStoreFileViewModel() {
    return ViewModelBuilder<DecryptWalletFileBloc>.reactive(
      onViewModelReady: (DecryptWalletFileBloc model) {
        model.stream.listen(
          (WalletFile? walletFile) {
            if (walletFile != null && walletFile is KeyStoreWalletFile) {
              _loadingButtonKey.currentState!.animateReverse();
              setState(() {
                _passwordErrorText = null;
              });
              walletFile
                  .access(
                    (Wallet wallet) =>
                        Future.value((wallet as KeyStore).mnemonic!),
                  )
                  .then(
                    (String value) => NavigationUtils.push(
                      context,
                      ImportWalletPasswordScreen(value),
                    ),
                  );
            }
          },
          onError: (error) {
            _loadingButtonKey.currentState!.animateReverse();
            if (error is IncorrectPasswordException) {
              setState(() {
                _passwordErrorText = 'Incorrect password';
              });
            } else {
              setState(() {
                _passwordErrorText = error.toString();
              });
            }
          },
        );
      },
      builder: (_, DecryptWalletFileBloc model, __) {
        _loadingButton = _getLoadingButton(model);
        return _getLoadingButton(model);
      },
      viewModelBuilder: DecryptWalletFileBloc.new,
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
