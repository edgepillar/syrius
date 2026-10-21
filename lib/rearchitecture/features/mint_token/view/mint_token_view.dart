import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/mint_token/bloc/mint_token_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The dialog that mints an amount of a ZTS token to an address.
///
/// It was the back of a flipping token card; see `BurnTokenView`.
class MintTokenView extends StatelessWidget {
  /// Creates a [MintTokenView].
  const MintTokenView({
    required this._token,
    super.key,
  });

  final Token _token;

  /// Opens the dialog for [token].
  static Future<void> show(BuildContext context, {required Token token}) =>
      showDialog<void>(
        context: context,
        builder: (_) => MintTokenView(token: token),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MintTokenBloc>(
      create: (_) => MintTokenBloc(
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
  final TextEditingController _beneficiaryAddressController =
      TextEditingController(text: kSelectedAddress);
  final FocusNode _amountFocusNode = FocusNode();

  late final Listenable _fields = Listenable.merge(<Listenable>[
    _amountController,
    _beneficiaryAddressController,
  ]);

  /// What is left to mint before the token reaches its max supply.
  BigInt get _maxAmount => widget._token.maxSupply - widget._token.totalSupply;

  String get _amount => _amountController.text;

  String? get _amountError => InputValidators.correctValue(
    _amount,
    _maxAmount,
    widget._token.decimals,
    BigInt.zero,
  );

  String get _beneficiaryAddress => _beneficiaryAddressController.text;

  String? get _beneficiaryAddressError => InputValidators.checkAddress(
    _beneficiaryAddress,
  );

  bool get _canMint =>
      _beneficiaryAddress.isNotEmpty &&
      _beneficiaryAddressError == null &&
      _maxAmount > BigInt.zero &&
      _amount.isNotEmpty &&
      _amountError == null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<MintTokenBloc, MintTokenState>(
      listener: _onMintTokenStateChanged,
      child: BlocBuilder<MintTokenBloc, MintTokenState>(
        buildWhen: (MintTokenState previous, MintTokenState next) =>
            (previous is MintTokenLoading) != (next is MintTokenLoading),
        builder: (BuildContext context, MintTokenState mintState) {
          final bool sending = mintState is MintTokenLoading;
          // While the mint is sent a stray click on the barrier, or Escape,
          // must not close the dialog and lose its outcome.
          return PopScope(
            canPop: !sending,
            // One group for the fields and the buttons, in reading order.
            child: FocusTraversalGroup(
              child: _buildCard(context, sending: sending),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required bool sending}) {
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle fieldStyle = monoStyle(cardValueStyle(context));
    final Color ink = cardTokenInk(widget._token.tokenStandard, context);
    return DialogCard(
      title: '${context.l10n.mint} ${widget._token.symbol}',
      body: CardFields(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // What is left to mint follows the total supply; the flash is
            // the sign that it changed.
            ValueFlash(
              value: _maxAmount,
              color: ink,
              child: Row(
                children: <Widget>[
                  Text(
                    context.l10n.mintable.toUpperCase(),
                    style: ledgerLabelStyle(context),
                  ),
                  SizedBox(width: tokens.cardGap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        _maxAmount,
                        decimals: widget._token.decimals,
                        style: cardValueStyle(context),
                        symbol: widget._token.symbol,
                        symbolColor: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.cardGap),
            ListenableBuilder(
              listenable: _beneficiaryAddressController,
              builder: (BuildContext context, _) => TextField(
                key: const Key('mint_beneficiary_field'),
                controller: _beneficiaryAddressController,
                style: fieldStyle,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-z]')),
                ],
                decoration: InputDecoration(
                  errorText: _beneficiaryAddress.isEmpty
                      ? null
                      : _beneficiaryAddressError,
                  hintText: context.l10n.beneficiaryAddress,
                  suffixIcon: FieldSuffixButtons(
                    controller: _beneficiaryAddressController,
                  ),
                ),
                onSubmitted: (_) => _amountFocusNode.requestFocus(),
              ),
            ),
            SizedBox(height: tokens.cardGap),
            ListenableBuilder(
              listenable: _amountController,
              // A refused key, a comma for one, says so under the field,
              // over what the validator says.
              builder: (BuildContext context, _) => AmountRefusalScope(
                controller: _amountController,
                builder: (_, String? refusal) => TextField(
                  key: const Key('mint_amount_field'),
                  // The beneficiary opens filled with the selected address,
                  // so the amount is the first field left to fill.
                  autofocus: true,
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  style: fieldStyle,
                  inputFormatters: FormatUtils.getAmountTextInputFormatters(
                    _amount,
                  ),
                  decoration: InputDecoration(
                    errorText:
                        refusal ?? (_amount.isEmpty ? null : _amountError),
                    hintText: context.l10n.amount,
                    suffixIcon: CardFieldAction(
                      label: context.l10n.max,
                      onPressed: _maxAmount > BigInt.zero
                          ? _onMaxPressed
                          : null,
                    ),
                  ),
                  onSubmitted: (_) => _mintToken(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: quietButtonStyle(context),
          onPressed: sending ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        ListenableBuilder(
          listenable: _fields,
          builder: (BuildContext context, _) => LoadingButton.stepper(
            key: _buttonKey,
            text: context.l10n.mint,
            onPressed: _canMint ? _mintToken : null,
          ),
        ),
      ],
    );
  }

  void _mintToken() {
    final MintTokenBloc bloc = context.read<MintTokenBloc>();
    // Enter in the amount field reaches here too, and the busy button does
    // not stop it: a second Enter would send a second mint.
    if (!_canMint || bloc.state is MintTokenLoading) {
      return;
    }
    bloc.add(
      MintTokenRequested(
        amount: _amount.extractDecimals(widget._token.decimals),
        beneficiaryAddress: Address.parse(_beneficiaryAddress),
        token: widget._token,
      ),
    );
  }

  void _onMaxPressed() {
    final String maxAmount = _maxAmount.addDecimals(widget._token.decimals);
    if (_amount != maxAmount) {
      _amountController.text = maxAmount;
    }
  }

  void _onMintTokenStateChanged(BuildContext context, MintTokenState state) {
    if (state is MintTokenLoading) {
      _buttonKey.currentState?.animateForward();
    } else if (state is MintTokenDone) {
      unawaited(_sendSuccessfulNotification(state.accountBlock));
      Navigator.pop(context);
    } else if (state is MintTokenFailure) {
      _buttonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorMintingToken(widget._token.symbol),
        ),
      );
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
      title: context.l10n.successfullyMinted(amount, widget._token.symbol),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      details: context.l10n.successfullyMintedRequestedAmount(
        amount,
        accountBlock.hash,
        widget._token.symbol,
      ),
      type: NotificationType.paymentSent,
    );

    await sl.get<NotificationsBloc>().addNotification(notification);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _beneficiaryAddressController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }
}
