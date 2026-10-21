import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillar_parts/pillar_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart'
    hide
        InfiniteScrollTable,
        InfiniteScrollTableCell,
        InfiniteScrollTableHeaderColumn;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Every active sentinel on the network, by its owner's address.
///
/// The selected address's own sentinel is marked "Yours" and carries the
/// countdown to its revocation window; while that window is open the row
/// also offers Disassemble.
class SentinelsCard extends StatelessWidget {
  /// {@macro default_constructor}
  const SentinelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SentinelsBloc>(
      create: (_) =>
          SentinelsBloc(zenon: zenon!)..add(const InfiniteListRequested()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.l10n.sentinels,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<SentinelsBloc>().add(
              const InfiniteListRefreshRequested(),
            );
          },
        ),
      ],
      child: BlocBuilder<SentinelsBloc, InfiniteListState<SentinelInfo>>(
        builder: (_, InfiniteListState<SentinelInfo> state) {
          return StateSwitcher(
            child: switch (state.status) {
              InfiniteListStatus.initial => const _Loading(
                key: ValueKey<String>('loading'),
              ),
              InfiniteListStatus.failure => CardNote.error(
                state.error!,
                key: const ValueKey<String>('failure'),
              ),
              // The table would say "None yet" itself, but under the
              // table's key, and the first sentinel would appear with no
              // fade.
              InfiniteListStatus.success when state.data!.isEmpty =>
                SyriusErrorWidget(
                  context.l10n.noItemsFound,
                  key: const ValueKey<String>('empty'),
                ),
              InfiniteListStatus.success => _Populated(
                key: const ValueKey<String>('table'),
                hasReachedMax: state.hasReachedMax,
                sentinels: state.data!,
              ),
            },
          );
        },
      ),
    );
  }
}

/// The table's head and one of its rows, as the table lays them out; the
/// loading bars are spaced by them. A row is as tall as the copy button
/// beside its address.
const double _kHeadHeight = 40;
const double _kRowHeight = 40 + kInfiniteTableHorizontalPadding;
const double _kSkeletonBar = 12;

/// The list while it loads: a bar where each of the first rows will be,
/// under the space the column names take, so the rows arrive where the bars
/// stood.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    // A short card shows fewer bars instead of overflowing.
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        kInfiniteTableHorizontalPadding,
        _kHeadHeight + 1 + (_kRowHeight - _kSkeletonBar) / 2,
        kInfiniteTableHorizontalPadding,
        0,
      ),
      child: SkeletonRows(rows: 5, gap: _kRowHeight + 1 - _kSkeletonBar),
    );
  }
}

class _Populated extends StatelessWidget {
  const _Populated({
    required this.hasReachedMax,
    required this.sentinels,
    super.key,
  });

  final bool hasReachedMax;
  final List<SentinelInfo> sentinels;

  @override
  Widget build(BuildContext context) {
    // Tab goes through the rows' buttons, top to bottom, before it leaves
    // the card.
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: SizedBox.expand(
        child: InfiniteScrollTable<SentinelInfo>(
          // Keeps the scroll position when the page is left and shown again.
          key: const PageStorageKey<String>('sentinels_table'),
          itemKeyGenerator: (SentinelInfo sentinelInfo) =>
              ValueKey<String>(sentinelInfo.owner.toString()),
          items: sentinels,
          hasReachedMax: hasReachedMax,
          columns: _columns,
          generateRowCells: (SentinelInfo sentinelInfo) => _buildRowCells(
            context: context,
            sentinelInfo: sentinelInfo,
          ),
          onScrollReachedBottom: () {
            context.read<SentinelsBloc>().add(
              const InfiniteListMoreRequested(),
            );
          },
        ),
      ),
    );
  }

  List<InfiniteScrollTableCell> _buildRowCells({
    required BuildContext context,
    required SentinelInfo sentinelInfo,
  }) {
    // The three cells after the address are for the address's own sentinel
    // and stay empty on every other row.
    final bool own = sentinelInfo.owner.toString() == kSelectedAddress;

    return <InfiniteScrollTableCell>[
      InfiniteScrollTableCell.textFromAddress(
        address: sentinelInfo.owner,
        flex: 3,
        isStakeAddress: own,
      ),
      InfiniteScrollTableCell(
        child: own
            ? Align(
                alignment: Alignment.centerLeft,
                child: StatusDot(on: true, label: context.l10n.sentinelYours),
              )
            : const SizedBox.shrink(),
      ),
      InfiniteScrollTableCell(
        child: own
            ? Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: sentinelInfo.isRevocable
                      ? context.l10n.revocationWindowOpen
                      : context.l10n.untilRevocationWindowOpens,
                  child: RevokeCountdown(
                    seconds: sentinelInfo.revokeCooldown,
                    open: sentinelInfo.isRevocable,
                    alignment: CrossAxisAlignment.start,
                    onFinished: () => _refresh(context),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      InfiniteScrollTableCell(
        // Disassemble is offered only while the revocation window is open.
        child: own && sentinelInfo.isRevocable
            ? Center(
                child: RevokeSentinelButton(
                  onRevoked: () => _refresh(context),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ];
  }

  /// The window opened or closed, or the sentinel is gone: read the list
  /// again.
  void _refresh(BuildContext context) {
    context.read<SentinelsBloc>().add(const InfiniteListRefreshRequested());
  }

  static const List<InfiniteScrollTableColumnType> _columns =
      <InfiniteScrollTableColumnType>[
        .sentinelAddress,
        .blank,
        .blank,
        .blank,
      ];
}
