import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/empty_note.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The stakes of the selected address, one line each, with its Cancel
/// button or the wait until it can be cancelled.
///
/// The address column is gone: every line is the selected address's, which
/// the shell already names.
class StakesCard extends StatelessWidget {
  /// Creates a stakes list card.
  const StakesCard({this.onRefresh, super.key});

  /// Called as well when the refresh button reloads the list: the page's
  /// other figures have no refresh button of their own.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.l10n.stakesListTitle,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            _refreshStakes(context);
            onRefresh?.call();
          },
        ),
      ],
      child: BlocBuilder<StakesBloc, InfiniteListState<StakeEntry>>(
        builder: (_, InfiniteListState<StakeEntry> state) {
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
              // table's key: the first stake would then appear with no fade.
              InfiniteListStatus.success when state.data!.isEmpty => EmptyNote(
                text: context.l10n.noItemsFound,
                key: const ValueKey<String>('empty'),
              ),
              InfiniteListStatus.success => _Populated(
                key: const ValueKey<String>('table'),
                hasReachedMax: state.hasReachedMax,
                stakes: state.data!,
              ),
            },
          );
        },
      ),
    );
  }
}

/// The table's head, and a row with a Cancel button in it, as the table
/// lays them out; the loading bars are spaced by them.
const double _kHeadHeight = 40;
const double _kRowHeight = 32 + kInfiniteTableHorizontalPadding;
const double _kSkeletonBar = 12;

/// The list while it loads: a bar where each of the first rows will be,
/// under the space the column names take.
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
    required this.stakes,
    super.key,
  });

  final bool hasReachedMax;
  final List<StakeEntry> stakes;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return SizedBox.expand(
      child: InfiniteScrollTable<StakeEntry>(
        itemKeyGenerator: (StakeEntry stakeEntry) =>
            ValueKey<String>(stakeEntry.id.toString()),
        items: stakes,
        hasReachedMax: hasReachedMax,
        columns: const <InfiniteScrollTableColumnType>[
          .amount,
          .duration,
          .expiration,
        ],
        generateRowCells: (StakeEntry stakeEntry) => <Widget>[
          InfiniteScrollTableCell(
            // Aligned, so the flash is as wide as the amount and not as
            // the column. The row is keyed by the stake, so only a change
            // to this stake's amount flashes.
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueFlash(
                value: stakeEntry.amount,
                color: tokens.znnInk,
                child: AmountText(
                  stakeEntry.amount,
                  decimals: kZnnCoin.decimals,
                  style: cardValueStyle(context),
                  symbol: kZnnCoin.symbol,
                  symbolColor: tokens.znnInk,
                ),
              ),
            ),
          ),
          InfiniteScrollTableCell.withText(
            content: stakeDurationText(
              stakeEntry.expirationTimestamp - stakeEntry.startTimestamp,
              context.l10n,
            ),
          ),
          InfiniteScrollTableCell(
            child: Center(child: _Expiration(stakeEntry: stakeEntry)),
          ),
        ],
        onScrollReachedBottom: () {
          context.read<StakesBloc>().add(
            InfiniteListMoreRequested(
              address: Address.parse(kSelectedAddress!),
            ),
          );
        },
      ),
    );
  }
}

/// The last cell of a stake: Cancel once its time is up, the time left
/// until then.
class _Expiration extends StatelessWidget {
  const _Expiration({required this.stakeEntry});

  final StakeEntry stakeEntry;

  @override
  Widget build(BuildContext context) {
    final int secondsLeft =
        stakeEntry.expirationTimestamp -
        DateTime.now().millisecondsSinceEpoch ~/
            Duration.millisecondsPerSecond;
    if (secondsLeft <= 0) {
      return CancelStakeButton(
        stakeHash: stakeEntry.id,
        amount: stakeEntry.amount,
        onCancelled: () => _refreshStakes(context),
      );
    }
    return CancelCountdown(
      duration: Duration(seconds: secondsLeft),
      onFinished: () => _refreshStakes(context),
    );
  }
}

/// A stake's length in the months it was made for: `1 month`, `12 months`.
///
/// In [l10n]'s language, which a widget passes as `context.l10n`; without
/// it, in the app's language of the moment.
String stakeDurationText(int seconds, [AppLocalizations? l10n]) =>
    (l10n ?? currentL10n).stakeDurationMonths(seconds ~/ stakeTimeUnitSec);

void _refreshStakes(BuildContext context) {
  context.read<StakesBloc>().add(
    InfiniteListRefreshRequested(address: Address.parse(kSelectedAddress!)),
  );
}
