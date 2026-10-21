import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

class NewWalletPasswordScreen extends StatefulWidget {
  const NewWalletPasswordScreen(this.seedWords, {super.key});
  final List<String> seedWords;

  @override
  State<NewWalletPasswordScreen> createState() =>
      _NewWalletPasswordScreenState();
}

class _NewWalletPasswordScreenState extends State<NewWalletPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _passwordKey = GlobalKey();
  final GlobalKey<FormState> _confirmPasswordKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      title: 'Create a wallet password',
      subtitle: 'You will need it to unlock the wallet',
      onBack: () {
        Navigator.pop(context, false);
      },
      primary: _getActionButton(),
      child: Column(
        children: <Widget>[
          Form(
            key: _passwordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              controller: _passwordController,
              validator: InputValidators.validatePassword,
              onChanged: (String value) {
                setState(() {});
              },
              hintText: 'Password',
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _confirmPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              controller: _confirmPasswordController,
              validator: (String? value) => InputValidators.checkPasswordMatch(
                _passwordController.text,
                value,
              ),
              onChanged: (String value) {
                setState(() {});
              },
              hintText: 'Confirm password',
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

  Widget _getActionButton() {
    return OnboardingButton(
      onPressed: _arePasswordsValid()
          ? () {
              NavigationUtils.push(
                context,
                CreateKeyStoreScreen(
                  widget.seedWords.join(' '),
                  _passwordController.text,
                ),
              );
            }
          : null,
      text: 'Confirm password',
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

  @override
  void dispose() {
    _confirmPasswordController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
