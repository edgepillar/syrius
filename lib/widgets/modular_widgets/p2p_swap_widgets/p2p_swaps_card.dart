import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/p2p_swaps_list_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/refresh_button/view/refresh_button.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/native_p2p_swap_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/modals/recover_deposit_modal.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/p2p_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';

enum _SwapsMenu { recoverDeposit, tutorial, clearHistory }

/// The swaps this wallet has made, as the table that fills the P2P Swap
/// page. A row opens its swap.
///
/// The list comes from [bloc], which the page owns so that the figures above
/// the table read the same data.
class P2pSwapsCard extends StatefulWidget {
  /// Creates the table over [bloc].
  const P2pSwapsCard({required this.bloc, super.key});

  /// The wallet's swaps, refreshed periodically.
  final P2pSwapsListBloc bloc;

  @override
  State<P2pSwapsCard> createState() => _P2pSwapsCardState();
}

class _P2pSwapsCardState extends State<P2pSwapsCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Swaps',
      actions: <Widget>[
        if (htlcSwapsService!.isMaxSwapsReached) _buildHistoryFullNote(),
        RefreshButton(onPressed: widget.bloc.getData),
        PopupMenuButton<_SwapsMenu>(
          key: const Key('p2p_swaps_menu'),
          tooltip: 'More',
          iconSize: 18,
          icon: const Icon(Icons.more_horiz, color: AppColors.faint),
          onSelected: _onMenuSelected,
          itemBuilder: (_) => const <PopupMenuEntry<_SwapsMenu>>[
            PopupMenuItem<_SwapsMenu>(
              value: _SwapsMenu.recoverDeposit,
              child: Text('Recover deposit'),
            ),
            PopupMenuItem<_SwapsMenu>(
              value: _SwapsMenu.tutorial,
              child: Text('Swap tutorial'),
            ),
            PopupMenuItem<_SwapsMenu>(
              value: _SwapsMenu.clearHistory,
              child: Text('Clear history'),
            ),
          ],
        ),
      ],
      child: StreamBuilder<List<P2pSwap>>(
        stream: widget.bloc.stream,
        builder: (_, AsyncSnapshot<List<P2pSwap>> snapshot) {
          if (snapshot.hasError) {
            return RepaintBoundary(child: SyriusErrorWidget(snapshot.error!));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: SyriusLoadingWidget(size: 18, strokeWidth: 1.5),
            );
          }
          final List<P2pSwap> swaps = snapshot.data!;
          if (swaps.isEmpty) {
            return Center(
              child: Text(
                'None yet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(fontSize: 14),
              ),
            );
          }
          return _buildTable(swaps);
        },
      ),
    );
  }

  Widget _buildHistoryFullNote() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'The oldest swap is dropped when a new one starts',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.info_outline, size: 14, color: AppColors.warn),
            const SizedBox(width: 6),
            Text(
              'History full',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontSize: 12,
                color: AppColors.warn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<P2pSwap> swaps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(),
        const Divider(),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.separated(
              key: const PageStorageKey<String>('p2p_swaps'),
              controller: _scrollController,
              itemCount: swaps.length,
              separatorBuilder: (_, _) => const Divider(thickness: 0.75),
              itemBuilder: (_, int index) {
                final P2pSwap swap = swaps[index];
                return P2pSwapsListItem(
                  key: ValueKey<String>(swap.id),
                  swap: swap,
                  onTap: _onSwapTapped,
                  onDelete: _onDeleteSwapTapped,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    const List<String> names = <String>[
      'Status',
      'You send',
      'You receive',
      'Counterparty',
      'Started',
    ];
    final TextStyle label = ledgerLabelStyle(context);
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kP2pSwapRowPadding),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < names.length; i++)
              Expanded(
                flex: kP2pSwapColumnFlex[i],
                child: Text(
                  names[i].toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
            const SizedBox(width: kP2pSwapActionWidth),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(_SwapsMenu choice) {
    switch (choice) {
      case _SwapsMenu.recoverDeposit:
        unawaited(
          showCustomDialog(
            context: context,
            content: const RecoverDepositModal(),
          ),
        );
      case _SwapsMenu.tutorial:
        unawaited(NavigationUtils.openUrl(kP2pSwapTutorialLink));
      case _SwapsMenu.clearHistory:
        unawaited(_onDeleteSwapHistoryTapped());
    }
  }

  void _onSwapTapped(String swapId) {
    unawaited(
      showCustomDialog(
        context: context,
        content: NativeP2pSwapModal(swapId: swapId),
      ),
    );
  }

  Future<void> _onDeleteSwapTapped(P2pSwap swap) async {
    final bool? deleteConfirmed = await showDialogWithNoAndYesOptions(
      context: context,
      isBarrierDismissible: true,
      title: 'Delete swap',
      description: 'This cannot be undone.',
    );

    if (deleteConfirmed ?? false) {
      if (swap.mode == P2pSwapMode.htlc) {
        await htlcSwapsService!.deleteSwap(swap.id);
      }
      widget.bloc.getData();
    }
  }

  Future<void> _onDeleteSwapHistoryTapped() async {
    final bool? deleteHistoryConfirmed = await showDialogWithNoAndYesOptions(
      context: context,
      isBarrierDismissible: true,
      title: 'Clear history',
      description: 'Active swaps are kept. This cannot be undone.',
    );

    if (deleteHistoryConfirmed ?? false) {
      await htlcSwapsService!.deleteInactiveSwaps();
      widget.bloc.getData();
    }
  }
}
