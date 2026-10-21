import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/cancel_plasma/bloc/cancel_plasma_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/cancel_plasma/view/cancel_countdown.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Button that handles the Plasma cancellation flow.
///
/// While the fusion is still locked it stands in the same place, disabled,
/// counting down to the momentum it unlocks at; the row then keeps one
/// height and the button does not appear out of nothing.
class CancelPlasmaButton extends StatelessWidget {
  /// Creates a [CancelPlasmaButton].
  const CancelPlasmaButton({
    required this.plasmaHash,
    required this.amount,
    required this.onCancelled,
    this.unlocksIn,
    this.onUnlocked,
    super.key,
  });

  /// Hash of the Plasma fusion entry that should be cancelled.
  final Hash plasmaHash;

  /// The QSR fused, in the smallest unit: the confirmation names it, so a
  /// click on the wrong row is caught before it is sent.
  final BigInt amount;

  /// Called after the Plasma cancellation succeeds.
  final VoidCallback onCancelled;

  /// The time until the fusion can be cancelled, or null when it can be now.
  final Duration? unlocksIn;

  /// Called once [unlocksIn] has run out.
  final VoidCallback? onUnlocked;

  @override
  Widget build(BuildContext context) {
    final Duration? left = unlocksIn;
    if (left != null) {
      return CancelCountdown(
        duration: left,
        onFinished: onUnlocked ?? () {},
        builder: (BuildContext context, String text) => Tooltip(
          message: context.l10n.cancelUnlocksIn(text),
          child: OutlinedButton.icon(
            // No line colour: a locked Cancel is not yet an undo, and the
            // theme's disabled text says it cannot be pressed.
            style: cardSecondaryButtonStyle(context),
            onPressed: null,
            label: Text(text, style: monoStyle(null)),
            icon: const Icon(Icons.lock_clock_outlined, size: 16),
          ),
        ),
      );
    }
    return BlocProvider<CancelPlasmaBloc>(
      create: (_) => CancelPlasmaBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
        zenonAddressUtils: ZenonAddressUtils(),
      ),
      child: Row(
        mainAxisAlignment: .center,
        mainAxisSize: .min,
        children: <Widget>[
          BlocConsumer<CancelPlasmaBloc, CancelPlasmaState>(
            listener: (BuildContext context, CancelPlasmaState state) {
              if (state is CancelPlasmaDone) {
                onCancelled();
              } else if (state is CancelPlasmaFailure) {
                unawaited(
                  NotificationUtils.sendNotificationError(
                    state.exception,
                    context.l10n.errorWhileCancellingPlasma,
                  ),
                );
              }
            },
            builder: (BuildContext context, CancelPlasmaState state) {
              return switch (state) {
                CancelPlasmaLoading() => const SyriusLoadingWidget(size: 25),
                _ => _buildButton(context),
              };
            },
          ),
        ],
      ),
    );
  }

  OutlinedButton _buildButton(BuildContext context) {
    return OutlinedButton.icon(
      // A secondary action with a red line: it undoes something, and the
      // card's filled button is kept for its main action.
      style: cardSecondaryButtonStyle(context, line: AppColors.errorColor),
      onPressed: () async {
        final CancelPlasmaBloc cancelPlasmaBloc = context
            .read<CancelPlasmaBloc>();
        final bool? cancellationConfirmed = await showDialogWithNoAndYesOptions(
          isBarrierDismissible: false,
          context: context,
          title: context.l10n.cancel,
          description:
              'Cancel the fusion of '
              '${cardAmount(amount, kQsrCoin.decimals, kQsrCoin.symbol)}?',
        );

        if (cancellationConfirmed ?? false) {
          cancelPlasmaBloc.add(
            CancelPlasmaRequested(plasmaHash: plasmaHash),
          );
        }
      },
      label: Text(context.l10n.cancel),
      icon: const Icon(Icons.close, size: 16),
    );
  }
}
