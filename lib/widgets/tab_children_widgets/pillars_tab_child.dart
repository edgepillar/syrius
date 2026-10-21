import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';

/// Pillars: on top, the address's rewards (what it can collect, over what it
/// earned), whom it delegates to, and its own pillar; every pillar, to
/// delegate to, fills the rest.
///
/// The amount to collect is the head of the rewards card instead of a card
/// of its own. The delegation card was on the old dashboard and had no page
/// since; without it there was no way to undelegate.
class PillarsTabChild extends StatelessWidget {
  /// Creates a Pillars tab child.
  const PillarsTabChild({
    required VoidCallback onStepperNotificationSeeMorePressed,
    super.key,
  }) : _onStepperNotificationSeeMorePressed =
           onStepperNotificationSeeMorePressed;

  final VoidCallback _onStepperNotificationSeeMorePressed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PillarsBloc>(
      create: (_) =>
          PillarsBloc(zenon: zenon!)
            ..add(const InfiniteListRequested(address: null)),
      child: PageGrid(
        rows: <PageRow>[
          PageRow.fixed(300, <PageCell>[
            const PageCell(PillarRewardsCard(), flex: 2),
            const PageCell(DelegationCard()),
            PageCell(
              PillarStatsCard(
                onStepperNotificationSeeMorePressed:
                    _onStepperNotificationSeeMorePressed,
              ),
            ),
          ]),
          const PageRow.fill(<PageCell>[PageCell(PillarsCard())]),
        ],
      ),
    );
  }
}
