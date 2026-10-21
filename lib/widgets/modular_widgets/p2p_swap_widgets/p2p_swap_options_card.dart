import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/pow_generating_status_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/toast_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/join_native_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/native_p2p_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/p2p_swap_warning_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/start_native_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The top row of the P2P Swap page: how the wallet's swaps stand, and the
/// two ways into a new one.
///
/// Starting a swap is the page's one primary action. Joining one is the
/// same flow from the other side, so it sits beside it as a quieter button.
class P2pSwapOptionsCard extends StatefulWidget {
  /// Creates the row over the wallet's [swaps].
  const P2pSwapOptionsCard({required this.swaps, super.key});

  /// The wallet's swaps; the figures count them by state.
  final Stream<List<P2pSwap>> swaps;

  @override
  State<P2pSwapOptionsCard> createState() => _P2pSwapOptionsCardState();
}

class _P2pSwapOptionsCardState extends State<P2pSwapOptionsCard> {
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildFigures()),
          const SizedBox(width: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildFigures() {
    return StreamBuilder<List<P2pSwap>>(
      stream: widget.swaps,
      builder: (_, AsyncSnapshot<List<P2pSwap>> snapshot) {
        final List<P2pSwap>? swaps = snapshot.data;
        String count(Set<P2pSwapState> states) => swaps == null
            ? '-'
            : '${swaps.where((P2pSwap s) => states.contains(s.state)).length}';
        final bool needsReclaim =
            swaps != null &&
            swaps.any((P2pSwap s) => s.state == P2pSwapState.reclaimable);
        return Row(
          children: <Widget>[
            Flexible(
              child: Figure(
                key: const Key('p2p_figure_active'),
                label: 'Active',
                value: count(<P2pSwapState>{
                  P2pSwapState.pending,
                  P2pSwapState.active,
                }),
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              child: Figure(
                key: const Key('p2p_figure_completed'),
                label: 'Completed',
                value: count(<P2pSwapState>{P2pSwapState.completed}),
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              child: Figure(
                key: const Key('p2p_figure_reclaim'),
                label: 'To reclaim',
                value: count(<P2pSwapState>{P2pSwapState.reclaimable}),
                // Funds waiting to be taken back are the one figure here
                // that needs the person.
                valueStyle: needsReclaim
                    ? monoStyle(
                        Theme.of(context).textTheme.headlineSmall,
                      ).copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warn,
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActions() {
    final ThemeData theme = Theme.of(context);
    final Color ink = theme.textTheme.bodyLarge!.color!;
    return StreamBuilder<PowStatus>(
      stream: sl.get<PowGeneratingStatusBloc>().stream,
      builder: (_, AsyncSnapshot<PowStatus> snapshot) {
        final bool isGeneratingPlasma = snapshot.data == PowStatus.generating;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OutlinedButton.icon(
              key: const Key('p2p_join_swap'),
              onPressed: () => _open(
                isGeneratingPlasma: isGeneratingPlasma,
                content: JoinNativeSwapModal(onJoinedSwap: _showSwap),
              ),
              icon: const Icon(Icons.call_merge, size: 18),
              label: const Text('Join swap'),
              // The neutral pill of mockup B: the card's raised tone and a
              // hairline, so it does not compete with the filled action.
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                iconColor: ink,
                backgroundColor: theme.colorScheme.primaryContainer,
                side: BorderSide(color: theme.dividerTheme.color!),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              key: const Key('p2p_start_swap'),
              onPressed: () => _open(
                isGeneratingPlasma: isGeneratingPlasma,
                content: StartNativeSwapModal(onSwapStarted: _showSwap),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start swap'),
            ),
          ],
        );
      },
    );
  }

  /// Opens a start or join dialog, after the one-time warning if it has not
  /// been read. A transaction cannot be sent while plasma is generating, so
  /// neither dialog opens then.
  void _open({required bool isGeneratingPlasma, required Widget content}) {
    if (isGeneratingPlasma) {
      ToastUtils.showToast(context, 'Wait for plasma to generate');
      return;
    }
    final Object? hasReadWarning = sharedPrefsService!.get(
      kHasReadP2pSwapWarningKey,
      defaultValue: kHasReadP2pSwapWarningDefaultValue,
    );
    if (hasReadWarning != false) {
      unawaited(showCustomDialog(context: context, content: content));
      return;
    }
    unawaited(
      showCustomDialog(
        context: context,
        content: P2PSwapWarningModal(
          onAccepted: () {
            Navigator.pop(context);
            unawaited(sharedPrefsService!.put(kHasReadP2pSwapWarningKey, true));
            Timer.run(
              () => unawaited(
                showCustomDialog(context: context, content: content),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Replaces the start or join dialog with the swap it created.
  void _showSwap(String swapId) {
    Navigator.pop(context);
    Timer.run(
      () => unawaited(
        showCustomDialog(
          context: context,
          content: NativeP2pSwapModal(swapId: swapId),
        ),
      ),
    );
  }
}
