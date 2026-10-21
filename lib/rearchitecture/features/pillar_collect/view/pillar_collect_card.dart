import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Provides what [PillarCollect] needs: the selected address's uncollected
/// pillar rewards, and a bloc to send the collect block.
///
/// It wraps the whole rewards card rather than the strip alone, so the
/// card's refresh button reaches the uncollected amount too.
class PillarCollectScope extends StatelessWidget {
  /// Creates the scope around [child].
  const PillarCollectScope({required this.child, super.key});

  /// The rewards card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<UncollectedPillarRewardsBloc>(
          create: (_) => UncollectedPillarRewardsBloc(zenon: zenon!)
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

/// What the selected address can collect as a pillar, and the button that
/// collects it. The head of the pillar rewards card; it was a card of its
/// own, which spent a third of the row on one number.
class PillarCollect extends StatelessWidget {
  /// Creates the strip. Needs a [PillarCollectScope] above it.
  const PillarCollect({super.key});

  @override
  Widget build(BuildContext context) {
    const String label = 'To collect';
    return BlocBuilder<
      UncollectedPillarRewardsBloc,
      FetchState<UncollectedReward>
    >(
      builder: (_, FetchState<UncollectedReward> state) {
        final BigInt znn = state is FetchPopulated<UncollectedReward>
            ? state.data.znnAmount
            : BigInt.zero;
        return CardCollect(
          figures: <Widget>[
            switch (state) {
              FetchInitial<UncollectedReward>() => const Figure(
                label: label,
                value: '',
              ),
              FetchFailure<UncollectedReward>() => Figure(
                label: label,
                value: cardErrorText(state.exception),
                valueStyle: cardDimStyle(context),
              ),
              FetchPopulated<UncollectedReward>() => cardAmountFigure(
                context,
                label: label,
                amount: znn,
                decimals: kZnnCoin.decimals,
                symbol: kZnnCoin.symbol,
                ink: AppColors.znnColor,
              ),
            },
          ],
          button: _CollectButton(enabled: znn > BigInt.zero),
        );
      },
    );
  }
}

class _CollectButton extends StatefulWidget {
  const _CollectButton({required this.enabled});

  final bool enabled;

  @override
  State<_CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<_CollectButton> {
  final GlobalKey<LoadingButtonState> _collectButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
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
          context.l10n.errorCollectingPillarRewards,
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
          context.read<UncollectedPillarRewardsBloc>().add(
            FetchRequestData(address: address),
          );
          context.read<PillarRewardsHistoryBloc>().add(
            FetchRequestData(address: address),
          );
        }
      },
    );
  }

  void _onCollectPressed({required SendTransactionBloc bloc}) {
    bloc.add(
      SendTransactionInitiateFromBlock(
        block: zenon!.embedded.pillar.collectReward(),
        fromAddress: kSelectedAddress!,
        reasonForGeneratingPlasma:
            context.l10n.plasmaPurposeCollectPillarRewards,
      ),
    );
  }

  void _sendConfirmationNotification({
    required AccountBlockTemplate block,
  }) {
    final String title = context.l10n.pillarRewardsBlockCreated;

    unawaited(
      sl.get<NotificationsBloc>().addNotification(
        WalletNotification(
          title: title,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          details: context.l10n.hashValue(block.hash.toString()),
          type: NotificationType.paymentSent,
        ),
      ),
    );
  }
}
