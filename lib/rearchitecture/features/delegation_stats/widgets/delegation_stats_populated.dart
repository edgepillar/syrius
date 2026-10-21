import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/reusable_widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The pillar the address delegates to, its state, the weight delegated,
/// and Undelegate.
///
/// A pillar that was revoked or disbanded keeps its delegations until each
/// delegator moves; the old card ringed it in red, this one marks it
/// Inactive in the warning colour, since the way out is right under it.
class DelegationStatsPopulated extends StatelessWidget {
  /// Creates a DelegationPopulated object.
  const DelegationStatsPopulated({required this.delegationInfo, super.key});

  /// Field that holds the needed details
  final DelegationInfo delegationInfo;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool active = delegationInfo.status == 1;

    return SingleChildScrollView(
      padding: kCardBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Figure(
            label: 'Delegated to',
            value: delegationInfo.name,
            valueStyle: cardValueStyle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: tokens.cardGap),
          CardRow(
            label: 'Weight',
            // Keyed by the pillar: a new pillar is a new figure, not a
            // change of this one, so moving the delegation does not flash.
            value: ValueFlash(
              key: ValueKey<String>(delegationInfo.name),
              value: delegationInfo.weight,
              child: AmountText(
                delegationInfo.weight,
                decimals: kZnnCoin.decimals,
                style: cardValueStyle(context),
                symbol: kZnnCoin.symbol,
                symbolColor: tokens.znnInk,
              ),
            ),
          ),
          CardRow(
            label: 'Pillar',
            value: active
                ? const StatusDot(on: true, label: 'Active')
                : const _InactiveDot(),
          ),
          SizedBox(height: tokens.cardGap),
          Align(
            alignment: Alignment.centerLeft,
            child: _UndelegateButton(pillarName: delegationInfo.name),
          ),
        ],
      ),
    );
  }
}

/// `StatusDot` in the warning colour: a pillar that stopped is something to
/// act on, not a failure of the wallet's.
///
/// `StatusDot` has only green and red; this mirrors its size and spacing
/// until it has a warning tone of its own.
class _InactiveDot extends StatelessWidget {
  const _InactiveDot();

  static const double _size = 8;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTokens.of(context).warn,
          ),
        ),
        const SizedBox(width: 6),
        Text('Inactive', style: cardValueStyle(context)),
      ],
    );
  }
}

/// A secondary action with a red line: the card's main action is choosing a
/// pillar in the list below, so nothing here is filled.
class _UndelegateButton extends StatefulWidget {
  const _UndelegateButton({required this.pillarName});

  /// Named in the confirmation.
  final String pillarName;

  @override
  State<_UndelegateButton> createState() => _UndelegateButtonState();
}

class _UndelegateButtonState extends State<_UndelegateButton> {
  final GlobalKey<LoadingButtonState> _buttonKey =
      GlobalKey<LoadingButtonState>();

  @override
  Widget build(BuildContext context) {
    return BlocListener<UndelegateBloc, UndelegateState>(
      listener: _onUndelegateStateChanged,
      child: CardSecondaryButtons(
        line: AppColors.errorColor,
        child: LoadingButton(
          onPressed: _onPressed,
          text: 'Undelegate',
          outlineColor: AppColors.errorColor,
          key: _buttonKey,
        ),
      ),
    );
  }

  Future<void> _onPressed() async {
    final UndelegateBloc bloc = context.read<UndelegateBloc>();
    final bool? confirmed = await showDialogWithNoAndYesOptions(
      context: context,
      title: 'Undelegate',
      description: 'Undelegate from ${widget.pillarName}?',
      isBarrierDismissible: true,
    );
    if (confirmed ?? false) {
      bloc.add(UndelegateRequested(address: Address.parse(kSelectedAddress!)));
    }
  }

  void _onUndelegateStateChanged(BuildContext context, UndelegateState state) {
    if (state is UndelegateLoading) {
      _buttonKey.currentState?.animateForward();
    } else if (state is UndelegateDone) {
      _buttonKey.currentState?.animateReverse();
      // The Pillars list reads the same bloc, so its "Delegated" mark goes
      // with this refresh too.
      context.read<DelegationStatsBloc>().add(
        FetchRequestData(address: Address.parse(kSelectedAddress!)),
      );
    } else if (state is UndelegateFailure) {
      _buttonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorUndelegating,
        ),
      );
    }
  }
}
