import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/decrypt_wallet_file_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/services/htlc_swaps_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Changes the password that unlocks the wallet.
///
/// The current password is proven by decrypting the wallet file with it;
/// only then is the file re-encrypted under the new one.
class ChangeWalletPasswordScreen extends StatefulWidget {
  const ChangeWalletPasswordScreen({
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  State<ChangeWalletPasswordScreen> createState() =>
      _ChangeWalletPasswordScreenState();
}

class _ChangeWalletPasswordScreenState
    extends State<ChangeWalletPasswordScreen> {
  String? _currentPassErrorText;

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _currentPasswordKey = GlobalKey();
  final GlobalKey<FormState> _newPasswordKey = GlobalKey();
  final GlobalKey<FormState> _confirmPasswordKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _loadingButtonKey = GlobalKey();

  late LoadingButton _loadingButton;

  @override
  Widget build(BuildContext context) {
    return SettingsScreenFrame(
      top: NotificationWidget(
        onSeeMorePressed: widget.onStepperNotificationSeeMorePressed,
      ),
      title: 'Change password',
      note:
          'At least 8 characters, with an upper and a lower case letter, a '
          'number and a symbol.',
      actions: <Widget>[
        ScreenBackAction(
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        _buildDecryptKeyStoreFileViewModel(),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Form(
            key: _currentPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              errorText: _currentPassErrorText,
              controller: _currentPasswordController,
              hintText: 'Current password',
              onChanged: (String value) {
                setState(() {
                  if (_currentPassErrorText != null) {
                    _currentPassErrorText = null;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: kSettingFormGap),
          Form(
            key: _newPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              controller: _newPasswordController,
              validator: InputValidators.validatePassword,
              onChanged: (String value) {
                setState(() {});
              },
              hintText: 'New password',
            ),
          ),
          const SizedBox(height: kSettingFormGap),
          Form(
            key: _confirmPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              controller: _confirmPasswordController,
              validator: (String? value) => InputValidators.checkPasswordMatch(
                _newPasswordController.text,
                value,
              ),
              hintText: 'Repeat new password',
              onSubmitted: (String value) {
                if (_arePasswordsValid()) {
                  _loadingButton.onPressed!();
                }
              },
              onChanged: (String value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: kSettingFormGap + 4),
          PasswordProgressBar(
            password: _newPasswordController.text,
            passwordKey: _newPasswordKey,
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final Address baseAddress = WalletUtils.baseAddress;
    await kWalletFile!.changePassword(currentPassword, newPassword);
    await HtlcSwapsService.getInstance().closeBoxes();
    await HtlcSwapsService.getInstance().openBoxes(
      baseAddress.toString(),
      Crypto.digest(utf8.encode(currentPassword)),
      newCipherKey: Crypto.digest(utf8.encode(newPassword)),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  bool _arePasswordsValid() {
    return _currentPassErrorText == null &&
        InputValidators.validatePassword(_newPasswordController.text) == null &&
        InputValidators.checkPasswordMatch(
              _newPasswordController.text,
              _confirmPasswordController.text,
            ) ==
            null;
  }

  Widget _buildDecryptKeyStoreFileViewModel() {
    return ViewModelBuilder<DecryptWalletFileBloc>.reactive(
      onViewModelReady: (DecryptWalletFileBloc model) {
        model.stream.listen(
          (WalletFile? walletFile) async {
            if (walletFile != null) {
              setState(() {
                _currentPassErrorText = null;
              });
              try {
                await _changePassword(
                  _currentPasswordController.text,
                  _newPasswordController.text,
                );
              } catch (e) {
                await NotificationUtils.sendNotificationError(
                  e,
                  'An error occurred while trying to change password',
                );
              } finally {
                _loadingButtonKey.currentState?.animateReverse();
              }
            }
          },
          onError: (e) async {
            _loadingButtonKey.currentState?.animateReverse();
            if (e is IncorrectPasswordException) {
              setState(() {
                _currentPassErrorText = 'Incorrect password';
              });
            } else {
              await NotificationUtils.sendNotificationError(
                e,
                'An error occurred while trying to decrypt wallet',
              );
            }
          },
        );
      },
      builder: (_, DecryptWalletFileBloc model, _) {
        _loadingButton = _buildLoadingButton(model);
        return _loadingButton;
      },
      viewModelBuilder: DecryptWalletFileBloc.new,
    );
  }

  LoadingButton _buildLoadingButton(DecryptWalletFileBloc model) {
    return LoadingButton(
      key: _loadingButtonKey,
      minimumSize: kScreenActionSize,
      onPressed: _arePasswordsValid()
          ? () {
              _loadingButtonKey.currentState!.animateForward();
              model.decryptWalletFile(
                kWalletPath!,
                _currentPasswordController.text,
              );
            }
          : null,
      text: 'Change password',
    );
  }

  @override
  void dispose() {
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
