import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/send.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notification_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// How a party to a send is named in a notification: its label, else its
/// address with the middle cut out, so the line fits a notification row.
String sentPartyName(String address, Map<String, String> labels) {
  final String? label = labels[address];
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return address.length <= 16
      ? address
      : '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

/// The title of the notification for a send that was published.
///
/// Every part comes from the published block, never from the form. A balance
/// refresh while the block waits for plasma replaces the form with its
/// loading state, and the form that comes back is empty: read from its
/// fields, the title was "Sent  ZNN from Address 2 to".
String sentNotificationTitle({
  required AppLocalizations l10n,
  required BigInt amount,
  required int decimals,
  required String symbol,
  required String sender,
  required String recipient,
  required Map<String, String> labels,
}) => l10n.sentDetails(
  // Without trailing zeros, whatever was typed.
  amount.addDecimals(decimals),
  sentPartyName(recipient, labels),
  sentPartyName(sender, labels),
  symbol,
);

/// A widget with multiple [DropdownMenu] and [TextField] that allow the user
/// to select and input the information needed for sending a transaction
class SendPopulated extends StatefulWidget {
  /// Creates a new instance.
  const SendPopulated({
    required this.balances,
    super.key,
  });

  /// A map with wallet addresses as keys, and account info objects as values
  final Map<String, AccountInfo> balances;

  @override
  State<SendPopulated> createState() => _SendPopulatedState();
}

class _SendPopulatedState extends State<SendPopulated> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final FocusNode _recipientFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  final GlobalKey<LoadingButtonState> _sendPaymentButtonKey = GlobalKey();

  final List<Token> _availableAssets = <Token>[];

  Token _selectedToken = kDualCoin.first;

  String _selectedSenderAddress = kSelectedAddress!;

  // The amount as inputted by the user
  String get _amount => _amountController.text;

  String get _recipient => _recipientController.text;

  AccountInfo get _accountInfo => widget.balances[_selectedSenderAddress]!;

  String? get _recipientErrorText =>
      _recipient.isNotEmpty ? InputValidators.checkAddress(_recipient) : null;

  String? get _amountErrorText => _amountController.text.isNotEmpty
      ? InputValidators.correctValue(
          _amountController.text,
          _accountInfo.getBalance(
            _selectedToken.tokenStandard,
          ),
          _selectedToken.decimals,
          BigInt.zero,
        )
      : null;

  bool get _isInputValid =>
      _recipientErrorText == null &&
      _amountErrorText == null &&
      _amountController.text.isNotEmpty &&
      _recipient.isNotEmpty;

  bool get _isValidTransaction => _hasBalance(_accountInfo) && _isInputValid;

  /// Where the form is kept while its page is not shown. Null where nothing
  /// above provides one (a test, another host): the form then forgets, as it
  /// did before.
  SendDraftCubit? _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<SendDraftCubit?>();
    _restoreDraft();
    _recipientController.addListener(_saveDraft);
    _amountController.addListener(_saveDraft);
  }

  /// Puts back what was typed before the page was left. A sender or a token
  /// that is no longer on offer is dropped, and the form falls back to its
  /// defaults for that field.
  void _restoreDraft() {
    final SendDraft? draft = _draft?.state;
    if (draft == null || draft.isEmpty) {
      return;
    }
    final String? from = draft.fromAddress;
    if (from != null && widget.balances.containsKey(from)) {
      _selectedSenderAddress = from;
    }
    _fillAvailableTokens(
      initialTokens: kDualCoin,
      list: _availableAssets,
      tokensWithBalance: _getTokensWithBalance(_accountInfo),
    );
    for (final Token token in _availableAssets) {
      if (token.tokenStandard.toString() == draft.tokenStandard) {
        _selectedToken = token;
      }
    }
    _recipientController.text = draft.recipient;
    _amountController.text = draft.amount;
  }

  void _saveDraft() => _draft?.save(
    fromAddress: _selectedSenderAddress,
    tokenStandard: _selectedToken.tokenStandard.toString(),
    recipient: _recipient,
    amount: _amount,
  );

  @override
  Widget build(BuildContext context) {
    if (_availableAssets.isEmpty) {
      _fillAvailableTokens(
        initialTokens: kDualCoin,
        list: _availableAssets,
        tokensWithBalance: _getTokensWithBalance(
          widget.balances[_selectedSenderAddress]!,
        ),
      );
    }

    return BlocListener<SendTransactionBloc, SendTransactionState>(
      listener: (_, SendTransactionState state) {
        if (state.status == SendTransactionStatus.loading) {
          _sendPaymentButtonKey.currentState?.animateForward();
        } else if (state.status == SendTransactionStatus.success) {
          unawaited(_sendConfirmationNotification(block: state.data!));
          _sendPaymentButtonKey.currentState?.animateReverse();
          _amountController.clear();
          _recipientController.clear();
          _draft?.clear();
        } else if (state.status == SendTransactionStatus.failure) {
          _sendPaymentButtonKey.currentState?.animateReverse();
          unawaited(_sendErrorNotification(state.error!));
        }
      },
      // A scroll view, so an error line under each field can never push the
      // Send button off the card, whatever the window's height.
      child: CardFields(
        child: SingleChildScrollView(
          padding: kCardBodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildDefaultAddressDropdown(),
                  ),
                  const SizedBox(width: kCardGap),
                  Expanded(
                    child: _buildCoinDropdown(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CardAvailable(
                amount: _accountInfo.getBalance(_selectedToken.tokenStandard),
                decimals: _selectedToken.decimals,
                symbol: _selectedToken.symbol,
                symbolColor: cardTokenInk(_selectedToken.tokenStandard),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _recipientController,
                builder: (_, TextEditingValue recipient, _) {
                  return TextField(
                    key: const Key('send_recipient_field'),
                    controller: _recipientController,
                    style: monoStyle(const TextStyle(fontSize: 14)),
                    // An address is typed and read left to right in every
                    // language, from the app's start. The hint, the suffix
                    // and the error line keep the app's direction.
                    textDirection: TextDirection.ltr,
                    textAlign: ltrTextAlign(context, TextAlign.start),
                    decoration: InputDecoration(
                      errorText: _recipientErrorText,
                      hintText: context.l10n.recipientAddress,
                      suffixIcon: FieldSuffixButtons(
                        controller: _recipientController,
                      ),
                    ),
                    focusNode: _recipientFocusNode,
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_amountFocusNode);
                    },
                  );
                },
              ),
              const SizedBox(height: kCardGap),
              // The amount and the one action of the card share a line.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _amountController,
                      builder: (_, TextEditingValue amount, _) {
                        // A refused key, a comma for one, says so under the
                        // field, over what the validator says.
                        return AmountRefusalScope(
                          controller: _amountController,
                          builder: (_, String? refusal) => TextField(
                            key: const Key('send_amount_field'),
                            controller: _amountController,
                            style: monoStyle(const TextStyle(fontSize: 14)),
                            // An amount, like the address above.
                            textDirection: TextDirection.ltr,
                            textAlign: ltrTextAlign(context, TextAlign.start),
                            decoration: InputDecoration(
                              errorText: refusal ?? _amountErrorText,
                              hintText: context.l10n.amount,
                              suffixIcon: CardFieldAction(
                                label: context.l10n.max,
                                onPressed: () => _onMaxPressed(_accountInfo),
                              ),
                            ),
                            focusNode: _amountFocusNode,
                            inputFormatters:
                                FormatUtils.getAmountTextInputFormatters(
                                  _amountController.text,
                                ),
                            onSubmitted: (String value) {
                              if (_isValidTransaction) {
                                unawaited(_onSendPaymentPressed());
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: kCardGap),
                  ListenableBuilder(
                    listenable: Listenable.merge(<Listenable>[
                      _amountController,
                      _recipientController,
                    ]),
                    builder: (_, _) {
                      return KeyedSubtree(
                        key: const Key('send_submit_button'),
                        child: SendButton(
                          key: _sendPaymentButtonKey,
                          text: context.l10n.send,
                          onPressed: _isValidTransaction
                              ? _onSendPaymentPressed
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSendPaymentPressed() async {
    final String title = context.l10n.send;

    final String symbol = _selectedToken.symbol;

    final String recipient = ZenonAddressUtils.getLabel(_recipient);

    final String description = context.l10n.areYouSureTranfer(
      _amount,
      recipient,
      symbol,
    );

    final bool? txConfirmed = await showDialogWithNoAndYesOptions(
      isBarrierDismissible: false,
      context: context,
      title: title,
      description: description,
    );

    if (txConfirmed ?? false) {
      _sendPayment();
    }
  }

  void _sendPayment() {
    context.read<SendTransactionBloc>().add(
      SendTransactionInitiate(
        amount: _amount.extractDecimals(_selectedToken.decimals),
        fromAddress: _selectedSenderAddress,
        toAddress: _recipient,
        token: _selectedToken,
      ),
    );
  }

  Widget _buildDefaultAddressDropdown() {
    return NewAddressesDropdown(
      addresses: kDefaultAddressList.map((String? e) => e!).toList(),
      onSelectedCallback: (String value) => setState(
        () {
          _selectedSenderAddress = value;
          _selectedToken = kDualCoin.first;
          _availableAssets.clear();
          _saveDraft();
        },
      ),
      selectedAddress: _selectedSenderAddress,
    );
  }

  Widget _buildCoinDropdown() => ZtsDropdown(
    availableTokens: _availableAssets,
    selectedToken: _selectedToken,
    onChangeCallback: (Token value) {
      if (_selectedToken != value) {
        setState(
          () {
            _selectedToken = value;
            _saveDraft();
          },
        );
      }
    },
  );

  void _onMaxPressed(AccountInfo accountInfo) {
    final BigInt maxBalance = accountInfo.getBalance(
      _selectedToken.tokenStandard,
    );

    final BigInt currentBalance = _amount.isEmpty
        ? BigInt.zero
        : _amount.extractDecimals(_selectedToken.decimals);

    if (currentBalance < maxBalance) {
      _amountController.text = maxBalance.addDecimals(_selectedToken.decimals);
    }
  }

  Future<void> _sendErrorNotification(SyriusException error) async {
    final String recipient = ZenonAddressUtils.getLabel(_recipient);

    final String symbol = _selectedToken.symbol;

    final String title = context.l10n.couldNotSend(_amount, recipient, symbol);

    await NotificationUtils.sendNotificationError(
      error,
      title,
    );
  }

  Future<void> _sendConfirmationNotification({
    required AccountBlockTemplate block,
  }) async {
    final Token token = _tokenOf(block.tokenStandard);

    // A block the node filled in carries its sender; one that does not is
    // the form's own.
    final String sender = block.address == emptyAddress
        ? _selectedSenderAddress
        : block.address.toString();

    final String title = sentNotificationTitle(
      l10n: context.l10n,
      amount: block.amount,
      decimals: token.decimals,
      symbol: token.symbol,
      sender: sender,
      recipient: block.toAddress.toString(),
      labels: kAddressLabelMap,
    );

    await sl.get<NotificationsBloc>().addNotification(
      WalletNotification(
        title: title,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: context.l10n.hashValue(block.hash.toString()),
        type: NotificationType.paymentSent,
      ),
    );
  }

  /// The token a published block moved, looked up by its standard: the
  /// form's own choice first, then every token an address of the wallet
  /// holds, then the two coins.
  Token _tokenOf(TokenStandard standard) {
    final Iterable<Token> known = <Token>[
      _selectedToken,
      ..._availableAssets,
      for (final AccountInfo info in widget.balances.values)
        for (final BalanceInfoListItem item
            in info.balanceInfoList ?? <BalanceInfoListItem>[])
          ?item.token,
      ...kDualCoin,
    ];
    for (final Token token in known) {
      if (token.tokenStandard == standard) {
        return token;
      }
    }
    return _selectedToken;
  }

  bool _hasBalance(AccountInfo accountInfo) =>
      accountInfo.getBalance(
        _selectedToken.tokenStandard,
      ) >
      BigInt.zero;

  List<Token> _getTokensWithBalance(AccountInfo accountInfo) {
    final List<Token> tokens = <Token>[];
    final List<BalanceInfoListItem> balanceInfoList =
        accountInfo.balanceInfoList!;

    for (final BalanceInfoListItem balanceInfo in balanceInfoList) {
      final BigInt balance = balanceInfo.balance!;
      final Token token = balanceInfo.token!;
      if (balance > BigInt.zero) {
        tokens.add(token);
      }
    }

    return tokens;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _fillAvailableTokens({
    required List<Token> initialTokens,
    required List<Token> list,
    required List<Token> tokensWithBalance,
  }) {
    final List<Token> emptyList = <Token>[...tokensWithBalance];
    // The available tokens should always contain the two coins
    if (!emptyList.contains(kZnnCoin)) {
      emptyList.insert(0, kZnnCoin);
    }
    if (!emptyList.contains(kQsrCoin)) {
      emptyList.insert(0, kQsrCoin);
    }

    list.addAll(sortAssets(emptyList));
  }
}
