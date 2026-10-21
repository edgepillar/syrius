import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The delegation before the first answer arrives: the delegated card with
/// bars where the pillar's name, its two rows and Undelegate will be, so the
/// card does not move when the answer lands.
class DelegationStatsLoading extends StatelessWidget {
  /// Creates a DelegationLoading object.
  const DelegationStatsLoading({super.key});

  /// The size of the Undelegate button the bar stands for.
  static const Size _button = Size(112, 32);

  @override
  Widget build(BuildContext context) {
    final double gap = AppTokens.of(context).cardGap;
    return SingleChildScrollView(
      padding: kCardBodyPadding,
      physics: const NeverScrollableScrollPhysics(),
      child: RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const FigureSkeleton(label: 'Delegated to'),
            SizedBox(height: gap),
            const CardRow(
              label: 'Weight',
              value: Skeleton(width: 112),
            ),
            const CardRow(
              label: 'Pillar',
              value: Skeleton(width: 64),
            ),
            SizedBox(height: gap),
            Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(
                width: _button.width,
                height: _button.height,
                radius: _button.height / 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
