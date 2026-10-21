import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

class ImportWalletPasswordScreen extends StatefulWidget {
  const ImportWalletPasswordScreen(
    this.seed, {
    this.progressBarNumLevels = 5,
    super.key,
  });
  final String seed;
  final int progressBarNumLevels;

  @override
  State<ImportWalletPasswordScreen> createState() =>
      _ImportWalletPasswordScreenState();
}

class _ImportWalletPasswordScreenState
    extends State<ImportWalletPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _passwordKey = GlobalKey();
  final GlobalKey<FormState> _confirmPasswordKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: widget.progressBarNumLevels - 2,
      steps: widget.progressBarNumLevels,
      title: 'Create a wallet password',
      subtitle: 'You will need it to unlock the wallet',
      onBack: () {
        Navigator.pop(context);
      },
      primary: _getContinuePassword(),
      child: Column(
        children: <Widget>[
          Form(
            key: _passwordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              hintText: 'Password',
              controller: _passwordController,
              validator: InputValidators.validatePassword,
              onChanged: (String value) {
                setState(() {});
              },
              onSubmitted: (String value) {
                if (_arePasswordsValid()) {
                  NavigationUtils.push(
                    context,
                    CreateKeyStoreScreen(
                      widget.seed,
                      _passwordController.text,
                      progressBarNumLevels: widget.progressBarNumLevels,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _confirmPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              hintText: 'Confirm password',
              controller: _confirmPasswordController,
              validator: (String? value) => InputValidators.checkPasswordMatch(
                _passwordController.text,
                value,
              ),
              onChanged: (String value) {
                setState(() {});
              },
              onSubmitted: (String value) {
                if (_arePasswordsValid()) {
                  NavigationUtils.push(
                    context,
                    CreateKeyStoreScreen(
                      widget.seed,
                      _passwordController.text,
                      progressBarNumLevels: widget.progressBarNumLevels,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          PasswordProgressBar(
            password: _passwordController.text,
            passwordKey: _passwordKey,
          ),
          const SizedBox(height: 12),
          Text(
            kPasswordRuleHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: dimColorOf(context)),
          ),
        ],
      ),
    );
  }

  bool _arePasswordsValid() {
    return InputValidators.validatePassword(_passwordController.text) == null &&
        InputValidators.checkPasswordMatch(
              _passwordController.text,
              _confirmPasswordController.text,
            ) ==
            null;
  }

  Widget _getContinuePassword() {
    return OnboardingButton(
      onPressed: _arePasswordsValid()
          ? () {
              NavigationUtils.push(
                context,
                CreateKeyStoreScreen(
                  widget.seed,
                  _passwordController.text,
                  progressBarNumLevels: widget.progressBarNumLevels,
                ),
              );
            }
          : null,
      text: 'Confirm password',
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
