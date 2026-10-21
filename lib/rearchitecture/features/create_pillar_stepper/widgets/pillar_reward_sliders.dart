import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// Reward distribution sliders for registering and for updating a pillar.
class PillarRewardSliders extends StatelessWidget {
  /// Creates [PillarRewardSliders].
  const PillarRewardSliders({
    required this.delegateRewardPercentage,
    required this.momentumRewardPercentage,
    super.key,
  });

  /// Percentage of delegation rewards given to delegators.
  final ValueNotifier<double> delegateRewardPercentage;

  /// Percentage of momentum rewards given to delegators.
  final ValueNotifier<double> momentumRewardPercentage;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RewardSlider(
          sliderKey: const Key('pillar_momentum_reward_slider'),
          description: context.l10n.percentageOfMomentumRewards,
          percentage: momentumRewardPercentage,
        ),
        SizedBox(height: tokens.cardGap),
        _RewardSlider(
          sliderKey: const Key('pillar_delegation_reward_slider'),
          description: context.l10n.percentageDelegationRewardsGiven,
          percentage: delegateRewardPercentage,
        ),
      ],
    );
  }
}

/// One share, from none to all of it, and under the slider how it splits
/// between the Pillar and its delegators.
class _RewardSlider extends StatelessWidget {
  const _RewardSlider({
    required this.sliderKey,
    required this.description,
    required this.percentage,
  });

  final Key sliderKey;
  final String description;
  final ValueNotifier<double> percentage;

  @override
  Widget build(BuildContext context) {
    final TextStyle? split = Theme.of(context).textTheme.titleSmall;
    return ValueListenableBuilder<double>(
      valueListenable: percentage,
      builder: (BuildContext context, double value, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CustomSlider(
              activeColor: AppTokens.of(context).znnInk,
              sliderKey: sliderKey,
              description: description,
              descriptionPosition: SliderDescriptionPosition.top,
              startValue: value,
              min: 0,
              maxValue: 100,
              callback: (double newValue) {
                percentage.value = newValue;
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  context.l10n.pillarsWithNumber(100 - value.toInt()),
                  style: split,
                ),
                Text(
                  context.l10n.delegators(value.toInt()),
                  style: split,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
