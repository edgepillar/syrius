import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/cancel_stake/bloc/cancel_stake_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_action_context.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Button that handles the stake cancellation flow.
class CancelStakeButton extends StatefulWidget {
  /// Creates a [CancelStakeButton].
  const CancelStakeButton({
    required this.ownerAddress,
    required this.stakeHash,
    required this.amount,
    required this.onCancelled,
    this.label,
    this.style,
    this.bloc,
    super.key,
  });

  /// The account that owns the displayed stake, never a later selection.
  final String ownerAddress;

  /// Hash of the stake entry that should be cancelled.
  final Hash stakeHash;

  /// The ZNN staked, in the smallest unit: the confirmation names it, so a
  /// click on the wrong row is caught before it is sent.
  final BigInt amount;

  /// Called after the stake cancellation succeeds.
  final VoidCallback onCancelled;

  /// The row's localized action label. Null keeps the compact Cancel action.
  final String? label;

  /// The enclosing table's secondary button style.
  final ButtonStyle? style;

  /// Uses the existing cancellation owner without constructing wallet I/O.
  final CancelStakeBloc? bloc;

  @override
  State<CancelStakeButton> createState() => _CancelStakeButtonState();
}

class _CancelStakeButtonState extends State<CancelStakeButton> {
  bool _confirming = false;
  bool _submitted = false;
  bool Function()? _attemptCurrent;
  VoidCallback? _onCancelled;

  @override
  Widget build(BuildContext context) {
    final Widget child = _buildContent();
    final CancelStakeBloc? bloc = widget.bloc;
    if (bloc != null) {
      return BlocProvider<CancelStakeBloc>.value(value: bloc, child: child);
    }
    return BlocProvider<CancelStakeBloc>(
      create: (_) => CancelStakeBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
        zenonAddressUtils: ZenonAddressUtils(),
      ),
      child: child,
    );
  }

  Widget _buildContent() => Row(
        mainAxisAlignment: .center,
        mainAxisSize: .min,
        children: <Widget>[
          // Keep the original control within its cell as text grows.
          Flexible(
            child: BlocConsumer<CancelStakeBloc, CancelStakeState>(
              listener: (BuildContext context, CancelStakeState state) {
                if (state is CancelStakeLoading) return;
                final bool current = _attemptCurrent?.call() ?? false;
                final VoidCallback? onCancelled = _onCancelled;
                setState(() {
                  _submitted = false;
                  _attemptCurrent = null;
                  _onCancelled = null;
                });
                if (!current) return;
                if (state is CancelStakeDone) {
                  onCancelled?.call();
                } else if (state is CancelStakeFailure) {
                  unawaited(
                    NotificationUtils.sendNotificationError(
                      state.exception,
                      context.l10n.errorWhileCancellingStake,
                    ),
                  );
                }
              },
              builder: (BuildContext context, CancelStakeState state) {
                return switch (state) {
                  CancelStakeLoading() => const SyriusLoadingWidget(size: 25),
                  _ => _buildButton(context),
                };
              },
            ),
          ),
        ],
      );

  OutlinedButton _buildButton(BuildContext context) {
    final String owner = widget.ownerAddress;
    final String hash = widget.stakeHash.toString();
    final BigInt amount = widget.amount;
    final int revision = WalletContextRevision.value;
    bool painted() =>
        mounted &&
        context.mounted &&
        owner == widget.ownerAddress &&
        hash == widget.stakeHash.toString() &&
        amount == widget.amount &&
        owner == kSelectedAddress &&
        revision == WalletContextRevision.value &&
        TickerMode.valuesOf(context).enabled;
    Future<void> cancel() async {
      if (!painted() || _confirming || _submitted) return;
      final CancelStakeBloc cancelStakeBloc = context.read<CancelStakeBloc>();
      if (cancelStakeBloc.isClosed ||
          cancelStakeBloc.state is CancelStakeLoading) {
        return;
      }
      final WalletActionContext? action = WalletActionContext.capture(owner);
      bool current() =>
          painted() &&
          !cancelStakeBloc.isClosed &&
          (action?.isCurrent ?? false);
      final VoidCallback onCancelled = widget.onCancelled;
      final String errorLabel = context.l10n.errorWhileCancellingStake;
      setState(() => _confirming = true);
      try {
        final bool? cancellationConfirmed = await showDialogWithNoAndYesOptions(
          isBarrierDismissible: false,
          context: context,
          title: context.l10n.cancel,
          // Keep the same confirmation for both stake cancellation controls.
          description:
              'Cancel the stake of '
              '${cardAmount(amount, kZnnCoin.decimals, kZnnCoin.symbol)}?',
        );

        if (cancellationConfirmed != true || !current() ||
            cancelStakeBloc.isClosed) {
          return;
        }
        final AccountBlockTemplate block = action!.client.embedded.stake
            .cancel(Hash.parse(hash));
        if (!current()) return;
        setState(() {
          _submitted = true;
          _attemptCurrent = current;
          _onCancelled = onCancelled;
        });
        cancelStakeBloc.add(
          CancelStakeRequested.owned(
            stakeHash: Hash.parse(hash),
            fromAddress: Address.parse(owner),
            block: block,
            canPublish: current,
          ),
        );
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          _submitted = false;
          _attemptCurrent = null;
          _onCancelled = null;
        });
        if (!current()) return;
        unawaited(NotificationUtils.sendNotificationError(
          error is SyriusException ? error : FailureException(),
          errorLabel,
        ));
      } finally {
        if (mounted) setState(() => _confirming = false);
      }
    }

    final ButtonStyle buttonStyle =
        widget.style ??
        cardSecondaryButtonStyle(context, line: AppColors.errorColor);
    final VoidCallback? press = _confirming || _submitted ? null : cancel;
    if (widget.label != null) {
      return OutlinedButton(
        style: buttonStyle,
        onPressed: press,
        child: Text(widget.label!),
      );
    }
    return OutlinedButton.icon(
      style: buttonStyle,
      onPressed: press,
      label: Text(context.l10n.cancel),
      icon: const Icon(Icons.close, size: 16),
    );
  }
}
