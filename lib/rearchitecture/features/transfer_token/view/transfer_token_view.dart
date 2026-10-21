import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/notifications_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/transfer_token/bloc/transfer_token_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _kTitle = 'Transfer ownership';
const String _kNote = 'Only the new owner can give it back.';

/// The dialog that hands a ZTS token to a new owner.
///
/// It was the back of a flipping token card; see `BurnTokenView`.
class TransferTokenView extends StatelessWidget {
  /// Creates a [TransferTokenView].
  const TransferTokenView({
    required this._token,
    super.key,
  });

  final Token _token;

  /// Opens the dialog for [token].
  static Future<void> show(BuildContext context, {required Token token}) =>
      showDialog<void>(
        context: context,
        builder: (_) => TransferTokenView(token: token),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransferTokenBloc>(
      create: (_) => TransferTokenBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
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
  final TextEditingController _newOwnerAddressController =
      TextEditingController();

  /// Whether the confirmation is open, so a second Enter does not open
  /// another one.
  bool _confirming = false;

  /// The address the transfer in flight was confirmed for.
  String? _confirmedOwnerAddress;

  String get _newOwnerAddress => _newOwnerAddressController.text;

  String? get _newOwnerAddressError => InputValidators.checkAddress(
    _newOwnerAddress,
  );

  bool get _canTransfer =>
      _newOwnerAddress.isNotEmpty && _newOwnerAddressError == null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransferTokenBloc, TransferTokenState>(
      listener: _onTransferTokenStateChanged,
      child: BlocBuilder<TransferTokenBloc, TransferTokenState>(
        buildWhen: (TransferTokenState previous, TransferTokenState next) =>
            (previous is TransferTokenLoading) !=
            (next is TransferTokenLoading),
        builder: (BuildContext context, TransferTokenState transferState) {
          final bool sending = transferState is TransferTokenLoading;
          // While the transfer is sent a stray click on the barrier, or
          // Escape, must not close the dialog and lose its outcome.
          return PopScope(
            canPop: !sending,
            // One group for the field and the buttons, in reading order.
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
    final Token token = widget._token;
    final Color ink = cardTokenInk(token.tokenStandard, context);
    return DialogCard(
      title: '$_kTitle: ${token.symbol}',
      body: CardFields(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // What changes hands: the say over this supply.
            ValueFlash(
              value: token.totalSupply,
              color: ink,
              child: Row(
                children: <Widget>[
                  Text(
                    context.l10n.totalSupply.toUpperCase(),
                    style: ledgerLabelStyle(context),
                  ),
                  SizedBox(width: tokens.cardGap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        token.totalSupply,
                        decimals: token.decimals,
                        style: cardValueStyle(context),
                        symbol: token.symbol,
                        symbolColor: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.cardGap),
            const Text(_kNote),
            SizedBox(height: tokens.cardGap),
            ListenableBuilder(
              listenable: _newOwnerAddressController,
              builder: (BuildContext context, _) => TextField(
                key: const Key('transfer_owner_field'),
                autofocus: true,
                controller: _newOwnerAddressController,
                style: monoStyle(cardValueStyle(context)),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-z]')),
                ],
                decoration: InputDecoration(
                  errorText: _newOwnerAddress.isEmpty
                      ? null
                      : _newOwnerAddressError,
                  hintText: context.l10n.newOwnerAddress,
                  suffixIcon: FieldSuffixButtons(
                    controller: _newOwnerAddressController,
                  ),
                ),
                onSubmitted: (_) => unawaited(_transferToken()),
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
          listenable: _newOwnerAddressController,
          builder: (BuildContext context, _) => LoadingButton.stepper(
            key: _buttonKey,
            text: context.l10n.transfer,
            onPressed: _canTransfer ? () => unawaited(_transferToken()) : null,
          ),
        ),
      ],
    );
  }

  /// Asks before transferring, naming the new owner: only that address can
  /// hand the token back.
  Future<void> _transferToken() async {
    final TransferTokenBloc bloc = context.read<TransferTokenBloc>();
    // Enter in the field reaches here too, and the busy button does not
    // stop it: a second Enter would send a second transfer.
    if (_confirming || bloc.state is TransferTokenLoading || !_canTransfer) {
      return;
    }
    final String newOwnerAddress = _newOwnerAddress;
    _confirming = true;
    final bool confirmed = await showWarningDialog(
      context: context,
      title: context.l10n.transferTokenConfirm(widget._token.symbol),
      description: context.l10n.transferTokenConfirmTo(newOwnerAddress),
      buttonText: context.l10n.transfer,
    );
    _confirming = false;
    if (!confirmed || !mounted) {
      return;
    }
    // The field can still be typed in while the transfer is sent; the
    // notification names the address that was confirmed.
    _confirmedOwnerAddress = newOwnerAddress;
    bloc.add(
      TransferTokenRequested(
        newOwnerAddress: Address.parse(newOwnerAddress),
        token: widget._token,
      ),
    );
  }

  void _onTransferTokenStateChanged(
    BuildContext context,
    TransferTokenState state,
  ) {
    if (state is TransferTokenLoading) {
      _buttonKey.currentState?.animateForward();
    } else if (state is TransferTokenDone) {
      unawaited(
        _sendSuccessfulNotification(
          _confirmedOwnerAddress ?? _newOwnerAddress,
        ),
      );
      Navigator.pop(context);
    } else if (state is TransferTokenFailure) {
      _buttonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorTransferringTokenOwnership,
        ),
      );
    }
  }

  Future<void> _sendSuccessfulNotification(String newOwnerAddress) async {
    // Read before the first await: the dialog closes as this is sent.
    final WalletNotification notification = WalletNotification(
      title: context.l10n.transferredTokenOwnership(widget._token.name),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      details: context.l10n.transferredTokenOwnershipToAddress(
        newOwnerAddress,
        widget._token.name,
      ),
      type: NotificationType.paymentSent,
    );

    await sl.get<NotificationsBloc>().addNotification(notification);
  }

  @override
  void dispose() {
    _newOwnerAddressController.dispose();
    super.dispose();
  }
}
