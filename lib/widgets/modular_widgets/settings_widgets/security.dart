import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/background_crypto.dart';
import 'package:zenon_syrius_wallet_flutter/utils/clipboard_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/functions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

const int _kMinMinutesOfInactivity = 1;
const int _kMaxMinutesOfInactivity = 30;
const int _kMinUnlockAttempts = 3;
const int _kMaxUnlockAttempts = 10;

/// Security: the password, the two locks, and signing and verifying with
/// the selected address.
///
/// Auto-lock and auto-erase apply when the slider is let go. Each used to
/// need a Confirm press, and a slider moved without it changed nothing.
/// Auto-erase cannot be switched off here: it is on from the first start at
/// [kAutoEraseNumAttemptsDefault] attempts, and the slider only moves the
/// count.
class SecurityWidget extends StatefulWidget {
  const SecurityWidget(
    this._onChangeAutoLockTime, {
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  final VoidCallback _onChangeAutoLockTime;
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  State createState() {
    return _SecurityWidgetState();
  }
}

class _SecurityWidgetState extends State<SecurityWidget> {
  final GlobalKey<LoadingButtonState> _signButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _signFileButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _verifyButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _verifyFileButtonKey = GlobalKey();

  final TextEditingController _textToBeSignedController =
      TextEditingController();
  final TextEditingController _signedTextController = TextEditingController();
  final TextEditingController _publicKeyController = TextEditingController();
  final TextEditingController _textToBeVerifiedController =
      TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  final TextEditingController _publicKeyToBeFilledController =
      TextEditingController();
  final TextEditingController _fileHashController = TextEditingController();
  final TextEditingController _publicKeySignFileController =
      TextEditingController();
  final TextEditingController _fileHashVerifyController =
      TextEditingController();
  final TextEditingController _publicKeyVerifyFileController =
      TextEditingController();

  String? _toBeSignedFilePath;
  String? _toBeVerifiedFilePath;

  /// What signing last refused, until the message is edited.
  String? _signError;

  final GlobalKey<SelectFileWidgetState> _signSelectFileWidgetKey = GlobalKey();
  final GlobalKey<SelectFileWidgetState> _verifySelectFileWidgetKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Every panel is as tall as its content and the section scrolls as one.
    // Sign and Verify used to share what the window left under Lock and
    // scroll inside themselves, so at the least window height Verify showed
    // half of its file zone and nothing said there was more.
    return SettingsSection(
      children: <Widget>[
        Panel(
          title: 'Lock',
          shrinkWrap: true,
          child: FocusTraversalGroup(
            child: SettingsList(
              children: <Widget>[
                SettingRow(
                  label: 'Password',
                  hint: 'The one that unlocks this wallet',
                  trailing: SecondaryAction(
                    child: SettingsButton(
                      text: 'Change',
                      onPressed: _onChangePasswordPressed,
                    ),
                  ),
                ),
                SliderSetting(
                  key: const Key('settings_auto_lock'),
                  label: 'Auto-lock',
                  hintOf: (int minutes) => minutes == 1
                      ? 'After 1 minute of inactivity'
                      : 'After $minutes minutes of inactivity',
                  saved: kAutoLockWalletMinutes!,
                  min: _kMinMinutesOfInactivity,
                  max: _kMaxMinutesOfInactivity,
                  onCommitted: _applyAutoLock,
                ),
                SliderSetting(
                  key: const Key('settings_auto_erase'),
                  label: 'Auto-erase',
                  hintOf: (int attempts) =>
                      'After $attempts failed password attempts',
                  saved: kAutoEraseWalletLimit!.toInt(),
                  min: _kMinUnlockAttempts,
                  max: _kMaxUnlockAttempts,
                  onCommitted: _applyAutoErase,
                ),
              ],
            ),
          ),
        ),
        SettingsColumns(
          children: <Widget>[
            Panel(
              title: 'Sign',
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildSignBody(),
                    const SizedBox(height: 18),
                    _buildLabel('File'),
                    _buildSignFileBody(),
                  ],
                ),
              ),
            ),
            Panel(
              title: 'Verify',
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildVerifyBody(),
                    const SizedBox(height: 18),
                    _buildLabel('File'),
                    _buildVerifyFileBody(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(), style: ledgerLabelStyle(context)),
    );
  }

  /// A read-only result, a signature or a key, with its copy button.
  Widget _buildResult(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildLabel(label),
        Row(
          children: <Widget>[
            Expanded(
              child: InputField(
                enabled: false,
                controller: controller,
                inputtedTextStyle: settingMonoStyle(context),
              ),
            ),
            CopyToClipboardButton(controller.text, iconSize: 16),
          ],
        ),
      ],
    );
  }

  /// Pastes the clipboard into [controller]. The page rebuilds after the
  /// paste lands, so a Verify that was waiting for that field enables.
  Widget _buildPasteButton(TextEditingController controller) {
    return IconButton(
      tooltip: 'Paste',
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      icon: const Icon(Icons.content_paste, color: AppColors.faint),
      onPressed: () {
        ClipboardUtils.pasteToClipboard(
          callback: (String value) {
            if (!mounted) return;
            setState(() {
              controller.text = value;
            });
          },
        );
      },
    );
  }

  TextStyle get _monoInput => monoStyle(
    const TextStyle(fontSize: 13, color: AppColors.znnColor),
  );

  void _onChangePasswordPressed() {
    NavigationUtils.push(
      context,
      ChangeWalletPasswordScreen(
        onStepperNotificationSeeMorePressed:
            widget.onStepperNotificationSeeMorePressed,
      ),
    );
  }

  /// Saves the auto-lock interval and restarts the lock timer with it.
  /// Returns whether it was saved; the slider goes back when it was not.
  Future<bool> _applyAutoLock(int minutes) async {
    // Read before the await: the slider saves a pending value as it is
    // disposed, and this page is gone by the time that write returns.
    final VoidCallback restartLockTimer = widget._onChangeAutoLockTime;
    try {
      await sharedPrefsService!.put(kAutoLockWalletMinutesKey, minutes);
      kAutoLockWalletMinutes = minutes;
      restartLockTimer();
      return true;
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while confirming auto-lock interval',
      );
      return false;
    }
  }

  /// Saves how many wrong passwords erase the wallet. Kept as a double, the
  /// type the lock screen and the settings box already hold it in.
  Future<bool> _applyAutoErase(int attempts) async {
    try {
      final double limit = attempts.toDouble();
      await sharedPrefsService!.put(kAutoEraseNumAttemptsKey, limit);
      kAutoEraseWalletLimit = limit;
      await sl.get<NotificationsBloc>().addNotification(
        WalletNotification(
          title: 'Auto-erase attempts limit successfully changed',
          details: 'The auto-erase limit has now $attempts attempt(s)',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: NotificationType.autoEraseNumAttemptsChanged,
        ),
      );
      return true;
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while confirming auto-erase limit',
      );
      return false;
    }
  }

  /// Why [message] cannot be signed or verified as text, in the words of
  /// the [FormatException] the shared signing function raises for it; null
  /// when it can. Asked as the person types, so the line is under the field
  /// before Sign is pressed rather than in a notification after.
  String? _refusalOf(String message) {
    try {
      messageBytesToSign(message);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  Widget _buildSignBody() {
    final String? signRefusal =
        _signError ??
        _refusalOf(
          _textToBeSignedController.text,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InputField(
          controller: _textToBeSignedController,
          hintText: 'Message',
          errorText: signRefusal,
          onChanged: (String? value) {
            setState(() {
              _signError = null;
            });
          },
          suffixIcon: CopyToClipboardButton(
            _textToBeSignedController.text,
            iconSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: LoadingButton.settings(
            key: _signButtonKey,
            text: 'Sign',
            onPressed:
                _textToBeSignedController.text.isNotEmpty && signRefusal == null
                ? _onSignButtonPressed
                : null,
          ),
        ),
        if (_signedTextController.text.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _buildResult('Signature', _signedTextController),
          const SizedBox(height: 10),
          _buildResult('Public key', _publicKeyController),
        ],
      ],
    );
  }

  Future<void> _onSignButtonPressed() async {
    try {
      _signButtonKey.currentState?.animateForward();
      final Signature signature = await walletSignMessage(
        _textToBeSignedController.text,
      );
      if (!mounted) return;
      setState(() {
        _signedTextController.text = signature.signature;
        _publicKeyController.text = signature.publicKey;
      });
    } on FormatException catch (e) {
      // The button is off for a refused message, so this is the case of
      // the rule changing under the panel: still one line, under the field.
      if (!mounted) return;
      setState(() {
        _signError = e.message;
      });
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while signing message',
      );
    } finally {
      _signButtonKey.currentState?.animateReverse();
    }
  }

  Widget _buildVerifyBody() {
    final String? verifyRefusal = _refusalOf(_textToBeVerifiedController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InputField(
          onChanged: (String value) {
            setState(() {});
          },
          controller: _textToBeVerifiedController,
          hintText: 'Message',
          errorText: verifyRefusal,
          suffixIcon: _buildPasteButton(_textToBeVerifiedController),
        ),
        const SizedBox(height: 10),
        InputField(
          onChanged: (String value) {
            setState(() {});
          },
          controller: _signatureController,
          hintText: 'Signature',
          inputtedTextStyle: _monoInput,
          suffixIcon: _buildPasteButton(_signatureController),
        ),
        const SizedBox(height: 10),
        InputField(
          onChanged: (String value) {
            setState(() {});
          },
          controller: _publicKeyToBeFilledController,
          hintText: 'Public key',
          inputtedTextStyle: _monoInput,
          suffixIcon: _buildPasteButton(_publicKeyToBeFilledController),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: LoadingButton.settings(
            key: _verifyButtonKey,
            text: 'Verify',
            onPressed:
                _textToBeVerifiedController.text.isNotEmpty &&
                    verifyRefusal == null &&
                    _signatureController.text.isNotEmpty &&
                    _publicKeyToBeFilledController.text.isNotEmpty
                ? _onVerifyButtonPressed
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _onVerifyButtonPressed() async {
    try {
      _verifyButtonKey.currentState?.animateForward();
      final bool verified = await BackgroundCrypto.verify(
        FormatUtils.decodeHexString(_signatureController.text),
        Uint8List.fromList(
          messageBytesToSign(_textToBeVerifiedController.text),
        ),
        FormatUtils.decodeHexString(_publicKeyToBeFilledController.text),
      );
      if (verified) {
        await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'Message verified successfully',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details:
                'The message: ${_textToBeVerifiedController.text} '
                'was successfully verified with the signature: '
                '${_signatureController.text}',
            type: NotificationType.paymentSent,
          ),
        );
        if (!mounted) return;
        setState(() {
          _textToBeVerifiedController.clear();
          _signatureController.clear();
          _publicKeyToBeFilledController.clear();
        });
      } else {
        throw 'Message or signature invalid';
      }
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while verifying message',
      );
    } finally {
      _verifyButtonKey.currentState?.animateReverse();
    }
  }

  @override
  void dispose() {
    _textToBeSignedController.dispose();
    _signedTextController.dispose();
    _publicKeyController.dispose();
    _textToBeVerifiedController.dispose();
    _signatureController.dispose();
    _publicKeyToBeFilledController.dispose();
    _fileHashController.dispose();
    _publicKeySignFileController.dispose();
    _fileHashVerifyController.dispose();
    _publicKeyVerifyFileController.dispose();
    super.dispose();
  }

  Widget _buildSignFileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SelectFileWidget(
          onPathFoundCallback: (String path) {
            setState(() {
              _toBeSignedFilePath = path;
            });
          },
          textStyle: Theme.of(context).textTheme.titleMedium,
          key: _signSelectFileWidgetKey,
        ),
        if (_toBeSignedFilePath != null) ...<Widget>[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryAction(
              child: LoadingButton.settings(
                key: _signFileButtonKey,
                text: 'Sign file',
                onPressed: _onSignFileButtonPressed,
              ),
            ),
          ),
        ],
        if (_fileHashController.text.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _buildResult('Signed hash', _fileHashController),
          const SizedBox(height: 10),
          _buildResult('Public key', _publicKeySignFileController),
        ],
      ],
    );
  }

  Future<void> _onSignFileButtonPressed() async {
    try {
      _signFileButtonKey.currentState?.animateForward();
      final Signature fileSignature = await walletSign(
        await BackgroundCrypto.digestFile(_toBeSignedFilePath!),
      );
      if (!mounted) return;
      setState(() {
        _fileHashController.text = fileSignature.signature;
        _publicKeySignFileController.text = fileSignature.publicKey;
        _toBeSignedFilePath = null;
        _signSelectFileWidgetKey.currentState!.resetMessageToUser();
      });
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while signing message',
      );
    } finally {
      _signFileButtonKey.currentState?.animateReverse();
    }
  }

  Widget _buildVerifyFileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SelectFileWidget(
          onPathFoundCallback: (String path) {
            setState(() {
              _toBeVerifiedFilePath = path;
            });
          },
          textStyle: Theme.of(context).textTheme.titleMedium,
          key: _verifySelectFileWidgetKey,
        ),
        const SizedBox(height: 10),
        InputField(
          onChanged: (String value) {
            setState(() {});
          },
          controller: _fileHashVerifyController,
          hintText: 'Signed hash',
          inputtedTextStyle: _monoInput,
          suffixIcon: _buildPasteButton(_fileHashVerifyController),
        ),
        const SizedBox(height: 10),
        InputField(
          onChanged: (String value) {
            setState(() {});
          },
          controller: _publicKeyVerifyFileController,
          hintText: 'Public key',
          inputtedTextStyle: _monoInput,
          suffixIcon: _buildPasteButton(_publicKeyVerifyFileController),
        ),
        if (_toBeVerifiedFilePath != null) ...<Widget>[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryAction(
              child: LoadingButton.settings(
                key: _verifyFileButtonKey,
                text: 'Verify file',
                onPressed:
                    _fileHashVerifyController.text.isNotEmpty &&
                        _publicKeyVerifyFileController.text.isNotEmpty
                    ? _onVerifyFileButtonPressed
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onVerifyFileButtonPressed() async {
    try {
      _verifyFileButtonKey.currentState?.animateForward();
      final bool verified = await BackgroundCrypto.verify(
        FormatUtils.decodeHexString(_fileHashVerifyController.text),
        await BackgroundCrypto.digestFile(_toBeVerifiedFilePath!),
        FormatUtils.decodeHexString(_publicKeyVerifyFileController.text),
      );
      if (verified) {
        await sl.get<NotificationsBloc>().addNotification(
          WalletNotification(
            title: 'File hash verified successfully',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details:
                'File hash was successfully verified with the signed hash: '
                '${_fileHashVerifyController.text}',
            type: NotificationType.paymentSent,
          ),
        );
        if (!mounted) return;
        setState(() {
          _toBeVerifiedFilePath = null;
          _verifySelectFileWidgetKey.currentState!.resetMessageToUser();
          _fileHashVerifyController.clear();
          _publicKeyVerifyFileController.clear();
        });
      } else {
        throw 'Hash or public key invalid';
      }
    } catch (e) {
      await NotificationUtils.sendNotificationError(
        e,
        'Error while verifying file hash:',
      );
    } finally {
      _verifyFileButtonKey.currentState?.animateReverse();
    }
  }
}
