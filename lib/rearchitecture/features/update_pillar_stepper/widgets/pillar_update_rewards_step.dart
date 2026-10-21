import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_pillar_stepper/widgets/pillar_reward_sliders.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';

/// Reward distribution step for updating a pillar.
class PillarUpdateRewardsStep extends StatelessWidget {
  /// Creates a [PillarUpdateRewardsStep].
  const PillarUpdateRewardsStep({
    required this.delegateRewardPercentage,
    required this.momentumRewardPercentage,
    required this.onBackPressed,
    required this.onNextPressed,
    this.active = true,
    super.key,
  });

  /// Percentage of delegation rewards given to delegators.
  final ValueNotifier<double> delegateRewardPercentage;

  /// Percentage of momentum rewards given to delegators.
  final ValueNotifier<double> momentumRewardPercentage;

  /// Called when the user returns to the previous step.
  final VoidCallback onBackPressed;

  /// Called when the user continues to the submit step.
  final VoidCallback onNextPressed;

  /// Whether this is the step shown.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TokenStepFrame(
      active: active,
      onBack: onBackPressed,
      onSubmit: onNextPressed,
      // The two sliders registering a Pillar has, starting where the Pillar
      // stands.
      body: PillarRewardSliders(
        delegateRewardPercentage: delegateRewardPercentage,
        momentumRewardPercentage: momentumRewardPercentage,
      ),
      primary: OutlinedButton(
        onPressed: onNextPressed,
        child: Text(context.l10n.next),
      ),
    );
  }
}
