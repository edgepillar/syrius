import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/init_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The lock screen: one password field and "Unlock", centred.
///
/// A wrong password is a short line under the button, with the attempts
/// left; the wallet still erases itself when they run out.
class LockTabChild extends StatefulWidget {
  const LockTabChild(
    this.afterUnlockCallback,
    this.afterInitCallback, {
    super.key,
  });
  final Future<void> Function(String) afterUnlockCallback;
  final Function() afterInitCallback;

  @override
  State<LockTabChild> createState() => _LockTabChildState();
}

class _LockTabChildState extends State<LockTabChild> {
  final TextEditingController _passwordController = TextEditingController();

  String _messageToUser = '';

  /// What went wrong with the last try; empty when nothing did.
  String _errorToUser = '';

  final GlobalKey<LoadingButtonState> _actionButtonKey = GlobalKey();

  LoadingButton? _actionButton;

  @override
  void initState() {
    super.initState();
    _actionButton = _getActionButton();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: RiseIn(
          child: Material(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(kCardRadius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: lineColorOf(context)),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.znnColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PasswordInputField(
                    key: const Key('wallet_password_field'),
                    controller: _passwordController,
                    hintText: 'Password',
                    onSubmitted: (String value) {
                      _actionButton!.onPressed!();
                    },
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: const Key('wallet_unlock_button'),
                    child: _actionButton!,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: kPasswordInputFieldWidth,
                    // A fixed height: the card does not jump when the line
                    // comes and goes.
                    height: 40,
                    child: AnimatedSwitcher(
                      duration: Durations.medium1,
                      child: _buildStatusLine(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One line under the button: the wallet opening, what went wrong, or
  /// how many tries are left once one has failed.
  Widget _buildStatusLine(BuildContext context) {
    final int attemptsLeft =
        kAutoEraseWalletLimit!.toInt() - kNumFailedUnlockAttempts!;
    final TextStyle base = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: dimColorOf(context),
    );

    if (_messageToUser.isNotEmpty) {
      return Row(
        key: const ValueKey<String>('opening'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SyriusLoadingWidget(size: 12, strokeWidth: 1.5, padding: 2),
          const SizedBox(width: 8),
          Flexible(child: Text(_messageToUser, style: base)),
        ],
      );
    }

    final String attempts = attemptsLeft == 1
        ? 'Last attempt. A wrong password resets the wallet'
        : '$attemptsLeft attempts left';

    if (_errorToUser.isNotEmpty) {
      return Text(
        attemptsLeft < kAutoEraseWalletLimit!.toInt()
            ? '$_errorToUser. $attempts'
            : _errorToUser,
        key: ValueKey<String>('error $_errorToUser $attemptsLeft'),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base.copyWith(
          color: attemptsLeft == 1 ? AppColors.warn : AppColors.errorColor,
        ),
      );
    }

    if (kNumFailedUnlockAttempts! > 0) {
      return Text(
        attempts,
        key: ValueKey<String>('attempts $attemptsLeft'),
        textAlign: TextAlign.center,
        style: attemptsLeft == 1 ? base.copyWith(color: AppColors.warn) : base,
      );
    }

    return const SizedBox.shrink(key: ValueKey<String>('none'));
  }

  LoadingButton _getActionButton() {
    return LoadingButton(
      onPressed: _onActionButtonPressed,
      key: _actionButtonKey,
      text: 'Unlock',
      minimumSize: const Size(kPasswordInputFieldWidth, 40),
      circularBorderRadius: 20,
    );
  }

  Future<void> _onError(String errorMessage, Object error) async {
    if (_messageToUser.isNotEmpty) {
      setState(() {
        _messageToUser = '';
      });
    }
    await NotificationUtils.sendNotificationError(error, errorMessage);
    if (error is IncorrectPasswordException) {
      kNumFailedUnlockAttempts = kNumFailedUnlockAttempts! + 1;
      await _saveNumFailedUnlockAttempts(kNumFailedUnlockAttempts);
    }
    if (mounted) {
      setState(() {
        _errorToUser = error is IncorrectPasswordException
            ? 'Wrong password'
            : errorMessage;
      });
    }
    if (kNumFailedUnlockAttempts == kAutoEraseWalletLimit) {
      NavigationUtils.pushReplacement(
        context,
        const SplashScreen(
          resetWalletFlow: true,
        ),
      );
    }
  }

  Future<void> _onActionButtonPressed() async {
    if (_passwordController.text.isNotEmpty &&
        _actionButtonKey.currentState!.btnState == ButtonState.idle) {
      try {
        _actionButtonKey.currentState!.animateForward();
        kWalletFile = await WalletUtils.decryptWalletFile(
          kWalletPath!,
          _passwordController.text,
        );
        if (kWalletInitCompleted == false) {
          setState(() {
            _messageToUser = 'Opening the wallet';
          });
          await InitUtils.initWalletAfterDecryption(
            Crypto.digest(utf8.encode(_passwordController.text)),
          );
          sl.get<MultipleBalanceBloc>().add(
            MultipleBalanceFetch(
              addresses: kDefaultAddressList.map((String? e) => e!).toList(),
            ),
          );
          widget.afterInitCallback();
        } else {
          await widget.afterUnlockCallback(_passwordController.text);
        }
        _restNumOfFailedAttempts();
        _resetScreenState();
      } on IncorrectPasswordException {
        _onError(
          kIncorrectPasswordNotificationTitle,
          IncorrectPasswordException(),
        );
      } on LedgerError catch (e) {
        _onError('Ledger: ${e.toFriendlyString()}', e);
      } catch (e) {
        _onError(kUnlockFailedNotificationTitle, e);
      } finally {
        _actionButtonKey.currentState?.animateReverse();
      }
    }
  }

  Future<void> _saveNumFailedUnlockAttempts(int? numAttempts) async {
    await sharedPrefsService!.put(kNumUnlockFailedAttemptsKey, numAttempts);
  }

  void _resetScreenState() {
    setState(_cleanScreen);
  }

  void _cleanScreen() {
    _clearInput();
    _clearMessageToUser();
  }

  void _clearInput() {
    _passwordController.clear();
  }

  void _clearMessageToUser() {
    _messageToUser = '';
    _errorToUser = '';
  }

  void _restNumOfFailedAttempts() {
    _saveNumFailedUnlockAttempts(0).then(
      (_) {
        kNumFailedUnlockAttempts = sharedPrefsService!.get(
          kNumUnlockFailedAttemptsKey,
        );
      },
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
