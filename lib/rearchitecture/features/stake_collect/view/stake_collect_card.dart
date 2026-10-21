import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Provides what [StakeCollectButton] needs: the selected address's
/// uncollected staking rewards, and a bloc to send the collect block.
///
/// It wraps the whole Staking page rather than the button alone, so the
/// strip's figure and the list's refresh button reach the uncollected
/// amount too.
class StakeCollectScope extends StatelessWidget {
  /// Creates the scope around [child].
  const StakeCollectScope({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<UncollectedStakingRewardsBloc>(
          create: (_) => UncollectedStakingRewardsBloc(zenon: zenon!)
            ..add(
              FetchRequestData(address: Address.parse(kSelectedAddress!)),
            ),
        ),
        BlocProvider<SendTransactionBloc>(
          create: (_) => SendTransactionBloc(),
        ),
      ],
      child: child,
    );
  }
}

/// The button that collects what the selected address earned from its
/// stakes. Needs a [StakeCollectScope] above it.
///
/// It stands in the Staking page's strip beside the amount; the head of a
/// rewards card that used to hold both is gone with that card.
class StakeCollectButton extends StatefulWidget {
  /// Creates the button. Disabled while there is nothing to collect.
  const StakeCollectButton({required this.enabled, super.key});

  /// Whether there is anything to collect.
  final bool enabled;

  @override
  State<StakeCollectButton> createState() => _StakeCollectButtonState();
}

class _StakeCollectButtonState extends State<StakeCollectButton> {
  final GlobalKey<LoadingButtonState> _collectButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // The card's one primary action, like every other Collect; it used to
    // be drawn in QSR blue, which made it look like a second kind of button.
    return BlocListener<SendTransactionBloc, SendTransactionState>(
      listener: (_, SendTransactionState state) =>
          _onTransactionStateChanged(state),
      child: LoadingButton.stepper(
        key: _collectButtonKey,
        text: context.l10n.collect,
        onPressed: widget.enabled
            ? () => _onCollectPressed(
                bloc: context.read<SendTransactionBloc>(),
              )
            : null,
      ),
    );
  }

  void _onTransactionStateChanged(SendTransactionState state) {
    if (state.status == SendTransactionStatus.loading) {
      _collectButtonKey.currentState?.animateForward();
    } else if (state.status == SendTransactionStatus.success) {
      _collectButtonKey.currentState?.animateReverse();
      _sendConfirmationNotification(block: state.data!);
      _refreshRewardsAfterDelay();
    } else if (state.status == SendTransactionStatus.failure) {
      _collectButtonKey.currentState?.animateReverse();
      unawaited(
        NotificationUtils.sendNotificationError(
          state.error!,
          context.l10n.errorCollectingStakingRewards,
        ),
      );
    }
  }

  void _refreshRewardsAfterDelay() {
    Future<void>.delayed(
      kDelayAfterAccountBlockCreationCall,
      () {
        if (mounted) {
          final Address address = Address.parse(kSelectedAddress!);
          context.read<UncollectedStakingRewardsBloc>().add(
            FetchRequestData(address: address),
          );
          context.read<StakingRewardsHistoryBloc>().add(
            FetchRequestData(address: address),
          );
        }
      },
    );
  }

  void _onCollectPressed({required SendTransactionBloc bloc}) {
    bloc.add(
      SendTransactionInitiateFromBlock(
        block: zenon!.embedded.stake.collectReward(),
        fromAddress: kSelectedAddress!,
        reasonForGeneratingPlasma:
            context.l10n.plasmaPurposeCollectStakingRewards,
      ),
    );
  }

  void _sendConfirmationNotification({required AccountBlockTemplate block}) {
    unawaited(
      sl.get<NotificationsBloc>().addNotification(
        WalletNotification(
          title: context.l10n.stakingRewardsBlockCreated,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          details: context.l10n.hashValue(block.hash.toString()),
          type: NotificationType.paymentSent,
        ),
      ),
    );
  }
}
