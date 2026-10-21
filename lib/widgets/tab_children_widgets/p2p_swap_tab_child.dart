import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/p2p_swaps_list_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/node_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/p2p_swap_options_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/p2p_swaps_card.dart';

/// P2P Swap: the wallet's swaps are the page.
///
/// A fixed row on top counts them by state and holds the two ways into a
/// new swap; the table of swaps takes every pixel under it. The page owns
/// the list so the figures and the table always agree.
class P2pSwapTabChild extends StatefulWidget {
  /// Creates the P2P Swap page.
  const P2pSwapTabChild({
    required this.onStepperNotificationSeeMorePressed,
    super.key,
  });

  /// Opens the notifications page. Kept for the shell, which passes it to
  /// every page; nothing here raises a stepper notification.
  final VoidCallback onStepperNotificationSeeMorePressed;

  @override
  State<P2pSwapTabChild> createState() => _P2pSwapTabChildState();
}

class _P2pSwapTabChildState extends State<P2pSwapTabChild> {
  final P2pSwapsListBloc _swapsBloc = P2pSwapsListBloc();

  @override
  void initState() {
    super.initState();
    _swapsBloc.getDataPeriodically();
    // A hashed timelock is only as safe as the clock that reads it.
    unawaited(
      NodeUtils.checkForLocalTimeDiscrepancy(
        'Your clock is off. Set the system time before swapping.',
      ),
    );
  }

  @override
  void dispose() {
    _swapsBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageGrid(
      rows: <PageRow>[
        PageRow.fixed(88, <PageCell>[
          PageCell(P2pSwapOptionsCard(swaps: _swapsBloc.stream)),
        ]),
        PageRow.fill(<PageCell>[
          PageCell(P2pSwapsCard(bloc: _swapsBloc)),
        ]),
      ],
    );
  }
}
