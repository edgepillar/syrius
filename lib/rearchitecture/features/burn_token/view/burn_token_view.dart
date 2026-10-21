import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/burn_token/bloc/burn_token_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/multiple_balance/multiple_balance.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The dialog that burns an amount of a ZTS token from the selected address.
///
/// It was the back of a flipping token card. A dialog keeps the list still
/// and gives the form the same width whatever the row it was opened from.
class BurnTokenView extends StatelessWidget {
  /// Creates a [BurnTokenView].
  const BurnTokenView({
    required this._token,
    super.key,
  });

  final Token _token;

  /// Opens the dialog for [token] and reads the balances again, so the
  /// amount that can be burned is the current one.
  static Future<void> show(BuildContext context, {required Token token}) {
    final MultipleBalanceBloc balances = context.read<MultipleBalanceBloc>()
      ..add(
        MultipleBalanceFetch(
          addresses: kDefaultAddressList.map((String? e) => e!).toList(),
        ),
      );
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider<MultipleBalanceBloc>.value(
        value: balances,
        child: BurnTokenView(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BurnTokenBloc>(
      create: (_) => BurnTokenBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
        zenonAddressUtils: ZenonAddressUtils(),
      ),
      child: _View(token: _token),
    );
  }
}

class _View extends StatefulWidget {
  const _View({required this._token});

  final Token _token;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final GlobalKey<LoadingButtonState> _buttonKey = GlobalKey();
  final TextEditingController _amountController = TextEditingController();

  /// Whether the confirmation is open, so a second Enter does not open
  /// another one.
  bool _confirming = false;

  String get _amount => _amountController.text;

  String? _amountError(BigInt balance) => InputValidators.correctValue(
    _amount,
    balance,
    widget._token.decimals,
    BigInt.zero,
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<BurnTokenBloc, BurnTokenState>(
      listener: _onBurnTokenStateChanged,
      child: BlocBuilder<BurnTokenBloc, BurnTokenState>(
        buildWhen: (BurnTokenState previous, BurnTokenState next) =>
            (previous is BurnTokenLoading) != (next is BurnTokenLoading),
        builder: (BuildContext context, BurnTokenState burnState) {
          final bool sending = burnState is BurnTokenLoading;
          // While the burn is sent a stray click on the barrier, or Escape,
          // must not close the dialog and lose its outcome.
          return PopScope(
            canPop: !sending,
            // One group for the field and the buttons, in reading order.
            child: FocusTraversalGroup(
              child: _buildCard(sending: sending),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required bool sending}) {
    return BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
      buildWhen: (MultipleBalanceState previous, MultipleBalanceState next) =>
          previous.status != next.status || previous.data != next.data,
      builder: (BuildContext context, MultipleBalanceState state) {
        // A refresh keeps the last balances, so the form stays up while
        // the new ones are read.
        final BigInt? balance = state.data?[kSelectedAddress]?.getBalance(
          widget._token.tokenStandard,
        );
        return DialogCard(
          title: '${context.l10n.burn} ${widget._token.symbol}',
          body: StateSwitcher(
            alignment: Alignment.topLeft,
            child: balance != null
                ? _Form(
                    key: const ValueKey<String>('populated'),
                    amountController: _amountController,
                    balance: balance,
                    onMaxPressed: () => _onMaxPressed(balance),
                    onSubmitted: () => unawaited(_burnToken(balance)),
                    token: widget._token,
                  )
                : state.status == MultipleBalanceStatus.failure
                ? Text(
                    cardErrorText(state.error!),
                    key: const ValueKey<String>('error'),
                  )
                : const SkeletonRows(key: ValueKey<String>('loading')),
          ),
          actions: <Widget>[
            TextButton(
              style: quietButtonStyle(context),
              onPressed: sending ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            ListenableBuilder(
              listenable: _amountController,
              builder: (BuildContext context, _) => LoadingButton.stepper(
                key: _buttonKey,
                text: context.l10n.burn,
                onPressed: balance != null && _amountError(balance) == null
                    ? () => unawaited(_burnToken(balance))
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Asks before burning, naming the amount: a burn cannot be undone.
  Future<void> _burnToken(BigInt balance) async {
    final BurnTokenBloc bloc = context.read<BurnTokenBloc>();
    // Enter in the field reaches here too, and the busy button does not
    // stop it: a second Enter would send a second burn.
    if (_confirming ||
        bloc.state is BurnTokenLoading ||
        _amountError(balance) != null) {
      return;
    }
    final BigInt amount = _amount.extractDecimals(widget._token.decimals);
    _confirming = true;
    final bool confirmed = await showWarningDialog(
      context: context,
      title: context.l10n.burnTokenConfirm(
        cardAmount(amount, widget._token.decimals, widget._token.symbol),
      ),
      description: context.l10n.cannotBeUndone,
      buttonText: context.l10n.burn,
    );
    _confirming = false;
    if (!confirmed || !mounted) {
      return;
    }
    bloc.add(BurnTokenRequested(amount: amount, token: widget._token));
  }

  void _onBurnTokenStateChanged(BuildContext context, BurnTokenState state) {
    if (state is BurnTokenLoading) {
      _buttonKey.currentState?.animateForward();
    } else if (state is BurnTokenDone) {
      unawaited(_sendSuccessfulNotification(state.accountBlock));
      Navigator.pop(context);
    } else if (state is BurnTokenFailure) {
      _buttonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorBurningZts,
        ),
      );
    }
  }

  void _onMaxPressed(BigInt balance) {
    final String maxAmount = balance.addDecimals(widget._token.decimals);
    if (_amount != maxAmount) {
      _amountController.text = maxAmount;
    }
  }

  Future<void> _sendSuccessfulNotification(
    AccountBlockTemplate accountBlock,
  ) async {
    final String amount = accountBlock.amount.addDecimals(
      widget._token.decimals,
    );
    // Read before the first await: the dialog closes as this is sent.
    final WalletNotification notification = WalletNotification(
      title: context.l10n.successfullyBurned(amount, widget._token.symbol),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      details: context.l10n.successfullyBurnedRequestedAmount(
        amount,
        accountBlock.hash,
        widget._token.symbol,
      ),
      type: NotificationType.burnToken,
    );

    await sl.get<NotificationsBloc>().addNotification(notification);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.amountController,
    required this.balance,
    required this.onMaxPressed,
    required this.onSubmitted,
    required this.token,
    super.key,
  });

  final TextEditingController amountController;
  final BigInt balance;
  final VoidCallback onMaxPressed;
  final VoidCallback onSubmitted;
  final Token token;

  @override
  Widget build(BuildContext context) {
    final Color ink = cardTokenInk(token.tokenStandard, context);
    return CardFields(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The balance is read again as the dialog opens; the flash is the
          // sign that it changed.
          ValueFlash(
            value: balance,
            color: ink,
            child: CardAvailable(
              amount: balance,
              decimals: token.decimals,
              symbol: token.symbol,
              symbolColor: ink,
            ),
          ),
          SizedBox(height: AppTokens.of(context).cardGap),
          ListenableBuilder(
            listenable: amountController,
            // A refused key, a comma for one, says so under the field, over
            // what the validator says.
            builder: (BuildContext context, _) => AmountRefusalScope(
              controller: amountController,
              builder: (_, String? refusal) => TextField(
                key: const Key('burn_amount_field'),
                autofocus: true,
                controller: amountController,
                style: monoStyle(cardValueStyle(context)),
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  amountController.text,
                ),
                decoration: InputDecoration(
                  errorText:
                      refusal ??
                      (amountController.text.isEmpty
                          ? null
                          : InputValidators.correctValue(
                              amountController.text,
                              balance,
                              token.decimals,
                              BigInt.zero,
                            )),
                  hintText: context.l10n.amount,
                  suffixIcon: CardFieldAction(
                    label: context.l10n.max,
                    onPressed: balance > BigInt.zero ? onMaxPressed : null,
                  ),
                ),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
