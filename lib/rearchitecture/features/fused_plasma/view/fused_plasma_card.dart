import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

typedef _FusedState = InfiniteListState<FusionEntryWrapper>;

/// The QSR the selected address has fused, one line per fusion, each with
/// its Cancel button, locked and counting down until it can be pressed.
class FusedPlasmaCard extends StatelessWidget {
  /// Creates a fused Plasma list card.
  const FusedPlasmaCard({this.onFusionCancelled, super.key});

  /// Called after a cancel was published. The fusion is gone only once the
  /// plasma contract has received the cancel, so whoever passes this keeps
  /// reloading until it is; without it the card reloads once.
  final VoidCallback? onFusionCancelled;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Fused',
      actions: <Widget>[
        RefreshButton(onPressed: () => _refreshFusedPlasma(context)),
      ],
      child: _FollowsSelectedAddress(
        child: BlocBuilder<FusedPlasmaBloc, _FusedState>(
          builder: (_, _FusedState state) {
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
                // table's key: the first fusion would then appear with no
                // fade, and the last one cancelled leave with none.
                InfiniteListStatus.success when state.data!.isEmpty =>
                  SyriusErrorWidget(
                    context.l10n.noItemsFound,
                    key: const ValueKey<String>('empty'),
                  ),
                InfiniteListStatus.success => _Populated(
                  key: const ValueKey<String>('table'),
                  hasReachedMax: state.hasReachedMax,
                  fusionEntries: state.data!,
                  onCancelled:
                      onFusionCancelled ?? () => _refreshFusedPlasma(context),
                ),
              },
            );
          },
        ),
      ),
    );
  }
}

/// Reloads the list when another address is selected.
///
/// The bloc belongs to the page and is made once, for the address selected
/// then, and the wallet's address switch reloads only the app-wide lists; so
/// after a switch the card went on showing the last address's fusions until
/// Refresh was pressed.
class _FollowsSelectedAddress extends StatefulWidget {
  const _FollowsSelectedAddress({required this.child});

  final Widget child;

  @override
  State<_FollowsSelectedAddress> createState() =>
      _FollowsSelectedAddressState();
}

class _FollowsSelectedAddressState extends State<_FollowsSelectedAddress> {
  late final SelectedAddressNotifier _notifier = context
      .read<SelectedAddressNotifier>();
  String? _address = kSelectedAddress;

  @override
  void initState() {
    super.initState();
    _notifier.addListener(_onSelected);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onSelected);
    super.dispose();
  }

  void _onSelected() {
    if (kSelectedAddress == _address) return;
    _address = kSelectedAddress;
    _refreshFusedPlasma(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The table's head, and a row with a Cancel button in it, as the table
/// lays them out; the loading bars are spaced by them.
const double _kHeadHeight = 40;
const double _kRowHeight = 32 + kInfiniteTableHorizontalPadding;
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
      child: SkeletonRows(gap: _kRowHeight + 1 - _kSkeletonBar),
    );
  }
}

class _Populated extends StatelessWidget {
  const _Populated({
    required this.hasReachedMax,
    required this.fusionEntries,
    required this.onCancelled,
    super.key,
  });

  final bool hasReachedMax;
  final List<FusionEntryWrapper> fusionEntries;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return SizedBox.expand(
      child: InfiniteScrollTable<FusionEntryWrapper>(
        itemKeyGenerator: (FusionEntryWrapper fusionEntryWrapper) =>
            ValueKey<String>(fusionEntryWrapper.fusionEntry.id.toString()),
        items: fusionEntries,
        hasReachedMax: hasReachedMax,
        columns: const <InfiniteScrollTableColumnType>[
          .amount,
          .beneficiaryAddress,
          .expiration,
        ],
        generateRowCells: (FusionEntryWrapper fusionEntryWrapper) => <Widget>[
          InfiniteScrollTableCell(
            // Aligned, so the flash is as wide as the amount and not as the
            // column.
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueFlash(
                // Keyed by the fusion: a row that comes to show another
                // fusion (another address, a cancel above it) is not a
                // change of this one.
                key: ValueKey<String>(
                  fusionEntryWrapper.fusionEntry.id.toString(),
                ),
                value: fusionEntryWrapper.fusionEntry.qsrAmount,
                color: tokens.qsrInk,
                child: AmountText(
                  fusionEntryWrapper.fusionEntry.qsrAmount,
                  decimals: kQsrCoin.decimals,
                  style: cardValueStyle(context),
                  symbol: kQsrCoin.symbol,
                  symbolColor: tokens.qsrInk,
                ),
              ),
            ),
          ),
          InfiniteScrollTableCell.textFromAddress(
            address: fusionEntryWrapper.fusionEntry.beneficiary,
            flex: 3,
          ),
          InfiniteScrollTableCell(
            child: Center(
              child: _Expiration(
                entry: fusionEntryWrapper,
                onCancelled: onCancelled,
              ),
            ),
          ),
        ],
        onScrollReachedBottom: () {
          context.read<FusedPlasmaBloc>().add(
            InfiniteListMoreRequested(
              address: Address.parse(kSelectedAddress!),
            ),
          );
        },
      ),
    );
  }
}

/// The last cell of a fusion: its Cancel button, locked and counting down
/// until the fusion can be cancelled.
class _Expiration extends StatelessWidget {
  const _Expiration({required this.entry, required this.onCancelled});

  final FusionEntryWrapper entry;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    final FusionEntry fusionEntry = entry.fusionEntry;
    return CancelPlasmaButton(
      plasmaHash: fusionEntry.id,
      amount: fusionEntry.qsrAmount,
      unlocksIn: entry.isRevocable ? null : _unlocksIn(context, fusionEntry),
      // Nobody pressed anything: reload behind the rows, as a refresh would
      // swap the whole table for loading bars.
      onUnlocked: () => context.read<FusedPlasmaBloc>().add(
        InfiniteListRequested(address: Address.parse(kSelectedAddress!)),
      ),
      onCancelled: onCancelled,
    );
  }

  Duration _unlocksIn(BuildContext context, FusionEntry fusionEntry) {
    final int lastMomentumHeight =
        context.read<FusedPlasmaBloc>().lastMomentumHeight ?? 0;
    // A fusion can be cancelled from the momentum after its expiration
    // height, so one that is not there yet always has a momentum to wait:
    // a countdown of nothing would ask for a refresh over and over.
    final int momentumsLeft = math.max(
      fusionEntry.expirationHeight - lastMomentumHeight + 1,
      1,
    );
    return kIntervalBetweenMomentums * momentumsLeft;
  }
}

void _refreshFusedPlasma(BuildContext context) {
  context.read<FusedPlasmaBloc>().add(
    InfiniteListRefreshRequested(address: Address.parse(kSelectedAddress!)),
  );
}
