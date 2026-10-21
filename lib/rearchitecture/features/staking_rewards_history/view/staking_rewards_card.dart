import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The height of the chart under its title row.
const double _kChartHeight = 200;

/// The chart of what the selected address earned from its stakes over the
/// last days, as a card of its own height: what opens under the Staking
/// page's strip.
///
/// The amount to collect and its button, once the head of this card, are in
/// the strip. A week without rewards is the title row and a note, not an
/// empty card the height of a chart.
class StakingRewardsChart extends StatelessWidget {
  /// Constructs a new instance.
  const StakingRewardsChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StakingRewardsHistoryBloc, FetchState<RewardHistoryList>>(
      builder: (_, FetchState<RewardHistoryList> state) {
        return Panel(
          title: context.l10n.stakingLast7Days,
          shrinkWrap: true,
          emptyNote: context.l10n.noItemsFound,
          // A week without rewards comes from the bloc as a failure.
          isEmpty:
              state is FetchFailure<RewardHistoryList> &&
              state.exception is NoRewardsLastWeekException,
          child: SizedBox(
            height: _kChartHeight,
            child: StateSwitcher(
              child: switch (state) {
                FetchFailure<RewardHistoryList>() => CardNote.error(
                  state.exception,
                  key: const ValueKey<String>('failure'),
                ),
                FetchInitial<RewardHistoryList>() => const _ChartLoading(
                  key: ValueKey<String>('loading'),
                ),
                FetchPopulated<RewardHistoryList>() => _Chart(
                  key: const ValueKey<String>('chart'),
                  rewardsHistoryList: state.data,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// The chart while it loads: bars down the space it will fill.
class _ChartLoading extends StatelessWidget {
  const _ChartLoading({super.key});

  @override
  Widget build(BuildContext context) {
    // A short card shows fewer bars instead of overflowing.
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: kCardBodyPadding,
      child: SkeletonRows(rows: 5, gap: 26),
    );
  }
}

/// A [StandardChart] adapted to show the staking rewards.
class _Chart extends StatelessWidget {
  /// Constructs a new instance.
  const _Chart({
    required this.rewardsHistoryList,
    super.key,
  });

  final RewardHistoryList rewardsHistoryList;

  @override
  Widget build(BuildContext context) {
    return StandardChart(
      maxY: _getMaxValueOfQsrRewards() < 1.0
          ? _getMaxValueOfQsrRewards().toDouble()
          : _getMaxValueOfQsrRewards().ceilToDouble(),
      lineBarsData: _linesBarData(),
      lineBarDotSymbol: kQsrCoin.symbol,
      titlesReferenceDate:
          DateTime.fromMillisecondsSinceEpoch(genesisTimestamp * 1000).add(
            Duration(
              // First epoch is zero
              days: rewardsHistoryList.list.reversed.last.epoch + 1,
            ),
          ),
    );
  }

  List<FlSpot> _getRewardsSpots() => List<FlSpot>.generate(
    rewardsHistoryList.list.length,
    (int index) => FlSpot(
      index.toDouble(),
      _getRewardsByIndex(index).toDouble(),
    ),
  );

  List<LineChartBarData> _linesBarData() => <LineChartBarData>[
    StandardLineChartBarData(
      color: AppColors.qsrColor,
      spots: _getRewardsSpots(),
    ),
  ];

  num _getRewardsByIndex(int index) => rewardsHistoryList.list.reversed
      .toList()[index]
      .qsrAmount
      .addDecimals(
        coinDecimals,
      )
      .toNum();

  num _getMaxValueOfQsrRewards() {
    BigInt max = rewardsHistoryList.list.first.qsrAmount;
    for (final RewardHistoryEntry element in rewardsHistoryList.list) {
      if (element.qsrAmount > max) {
        max = element.qsrAmount;
      }
    }
    return max
        .addDecimals(
          coinDecimals,
        )
        .toNum();
  }
}
