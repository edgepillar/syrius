import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The pillar rewards of the selected address: what it can collect now, with
/// the Collect button, over the chart of what it earned.
///
/// The amount to collect used to be a card of its own beside this one.
class PillarRewardsCard extends StatelessWidget {
  /// Constructs a new instance.
  const PillarRewardsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const PillarCollectScope(child: _View());
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Rewards',
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            final Address address = Address.parse(kSelectedAddress!);
            context.read<PillarRewardsHistoryBloc>().add(
              FetchRequestData(address: address),
            );
            context.read<UncollectedPillarRewardsBloc>().add(
              FetchRequestData(address: address),
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const PillarCollect(),
          const Divider(),
          Expanded(
            child:
                BlocBuilder<
                  PillarRewardsHistoryBloc,
                  FetchState<RewardHistoryList>
                >(
                  builder: (_, FetchState<RewardHistoryList> state) {
                    return switch (state) {
                      FetchFailure<RewardHistoryList>() => CardNote.error(
                        state.exception,
                      ),
                      FetchInitial<RewardHistoryList>() => const CardLoading(),
                      FetchPopulated<RewardHistoryList>() => _Chart(
                        rewardsHistoryList: state.data,
                      ),
                    };
                  },
                ),
          ),
        ],
      ),
    );
  }
}

/// A [StandardChart] adapted to show the pillar rewards
class _Chart extends StatelessWidget {
  /// Constructs a new instance.
  const _Chart({
    required this._rewardsHistoryList,
  });

  final RewardHistoryList _rewardsHistoryList;

  @override
  Widget build(BuildContext context) {
    return StandardChart(
      maxY: _getMaxValueOfZnnRewards() < 1.0
          ? _getMaxValueOfZnnRewards().toDouble()
          : _getMaxValueOfZnnRewards().ceilToDouble(),
      lineBarsData: _linesBarData(),
      lineBarDotSymbol: kZnnCoin.symbol,
      titlesReferenceDate:
          DateTime.fromMillisecondsSinceEpoch(genesisTimestamp * 1000).add(
            Duration(
              // First epoch is zero
              days: _rewardsHistoryList.list.reversed.last.epoch + 1,
            ),
          ),
    );
  }

  List<FlSpot> _getRewardsSpots() => List<FlSpot>.generate(
    _rewardsHistoryList.list.length,
    (int index) => FlSpot(
      index.toDouble(),
      _getRewardsByIndex(index).toDouble(),
    ),
  );

  List<LineChartBarData> _linesBarData() => <LineChartBarData>[
    StandardLineChartBarData(
      color: AppColors.znnColor,
      spots: _getRewardsSpots(),
    ),
  ];

  num _getRewardsByIndex(int index) => _rewardsHistoryList.list.reversed
      .toList()[index]
      .znnAmount
      .addDecimals(
        coinDecimals,
      )
      .toNum();

  num _getMaxValueOfZnnRewards() {
    BigInt max = _rewardsHistoryList.list.first.znnAmount;
    for (final RewardHistoryEntry element in _rewardsHistoryList.list) {
      if (element.znnAmount > max) {
        max = element.znnAmount;
      }
    }
    return max.addDecimals(coinDecimals).toNum();
  }
}
