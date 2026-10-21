import 'dart:async';

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

/// Every pillar, with what it shares and how well it produces.
///
/// The pillar the address delegates to is marked "Delegated". Every other
/// row offers Delegate, which moves the delegation without undelegating
/// first; it is hidden while the address holds too little ZNN to delegate.
class PillarsCard extends StatelessWidget {
  /// {@macro default_constructor}
  const PillarsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DelegationBloc>(
      create: (_) => DelegationBloc(
        accountBlockUtils: AccountBlockUtils(),
        zenon: zenon!,
      ),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: context.l10n.pillars,
      actions: <Widget>[
        RefreshButton(
          onPressed: () {
            context.read<PillarsBloc>().add(
              InfiniteListRefreshRequested(
                address: Address.parse(kSelectedAddress!),
              ),
            );
          },
        ),
      ],
      child: BlocBuilder<PillarsBloc, InfiniteListState<PillarInfo>>(
        builder: (_, InfiniteListState<PillarInfo> state) {
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
              // table's key, and the first pillar would appear with no fade.
              InfiniteListStatus.success when state.data!.isEmpty =>
                SyriusErrorWidget(
                  context.l10n.noItemsFound,
                  key: const ValueKey<String>('empty'),
                ),
              InfiniteListStatus.success => _Populated(
                key: const ValueKey<String>('table'),
                hasReachedMax: state.hasReachedMax,
                pillars: state.data!,
              ),
            },
          );
        },
      ),
    );
  }
}

/// The table's head, and a row with a Delegate button in it, as the table
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
      child: SkeletonRows(rows: 5, gap: _kRowHeight + 1 - _kSkeletonBar),
    );
  }
}

class _Populated extends StatefulWidget {
  const _Populated({
    required this.hasReachedMax,
    required this.pillars,
    super.key,
  });

  final bool hasReachedMax;
  final List<PillarInfo> pillars;

  @override
  State<_Populated> createState() => _PopulatedState();
}

class _PopulatedState extends State<_Populated> {
  final Map<String, GlobalKey<LoadingButtonState>> _delegateButtonKeys =
      <String, GlobalKey<LoadingButtonState>>{};

  /// The pillar a delegation is being sent to, until the block is answered.
  String? _delegatingTo;

  @override
  void initState() {
    super.initState();
    sl.get<MultipleBalanceBloc>().add(
      MultipleBalanceFetch(
        addresses: kDefaultAddressList.map((String? e) => e!).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The list reads two things besides the pillars, and only these two
    // values of them: a balance or a delegation that changes in any other
    // way does not rebuild the table.
    final bool canDelegate = context.select<MultipleBalanceBloc, bool>(
      (MultipleBalanceBloc bloc) =>
          (bloc.state.data?[kSelectedAddress]?.znn() ?? BigInt.zero) >=
          kMinDelegationAmount,
    );
    final String? delegatedTo = context.select<DelegationStatsBloc, String?>((
      DelegationStatsBloc bloc,
    ) {
      final FetchState<DelegationInfo> state = bloc.state;
      return state is FetchPopulated<DelegationInfo> ? state.data.name : null;
    });

    return BlocListener<DelegationBloc, DelegationState>(
      listener: _onDelegationStateChanged,
      // Delegate repeats on every row, so it is a secondary button; a column
      // of filled green pills would drown the list.
      child: CardSecondaryButtons(
        // Tab goes through the rows' buttons, top to bottom, before it
        // leaves the card.
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SizedBox.expand(
            child: InfiniteScrollTable<PillarInfo>(
              // Keeps the scroll position when the page is left and shown
              // again.
              key: const PageStorageKey<String>('pillars_table'),
              itemKeyGenerator: (PillarInfo pillarInfo) =>
                  ValueKey<String>(pillarInfo.name),
              items: widget.pillars,
              hasReachedMax: widget.hasReachedMax,
              columns: _columns,
              heads: _heads(context),
              generateRowCells: (PillarInfo pillarInfo) => _buildRowCells(
                context,
                pillarInfo,
                canDelegate: canDelegate,
                delegatedTo: delegatedTo,
              ),
              onScrollReachedBottom: () {
                context.read<PillarsBloc>().add(
                  const InfiniteListMoreRequested(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onDelegationStateChanged(BuildContext context, DelegationState state) {
    if (state is DelegationDone) {
      context.read<DelegationStatsBloc>().add(
        FetchRequestData(address: Address.parse(kSelectedAddress!)),
      );
    } else if (state is DelegationFailure) {
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.pillarDelegationError,
        ),
      );
    } else {
      return;
    }
    _delegateButtonKeys[_delegatingTo]?.currentState?.animateReverse();
    setState(() => _delegatingTo = null);
  }

  void _onDelegatePressed(PillarInfo pillarInfo) {
    _delegateButtonKeys[pillarInfo.name]?.currentState?.animateForward();
    setState(() => _delegatingTo = pillarInfo.name);
    context.read<DelegationBloc>().add(
      DelegationRequested(
        address: Address.parse(kSelectedAddress!),
        pillarName: pillarInfo.name,
      ),
    );
  }

  List<InfiniteScrollTableCell> _buildRowCells(
    BuildContext context,
    PillarInfo pillarInfo, {
    required bool canDelegate,
    required String? delegatedTo,
  }) {
    final AppTokens tokens = AppTokens.of(context);
    final bool own = pillarInfo.ownerAddress.toString() == kSelectedAddress;
    final Color? ink = own ? tokens.znnInk : null;
    final TextStyle mono = monoStyle(null);

    return <InfiniteScrollTableCell>[
      InfiniteScrollTableCell.withText(
        content: pillarInfo.name,
        textStyle: TextStyle(color: ink),
        flex: _nameFlex,
        // A pillar's name may be 40 characters; the hover has all of it.
        tooltipMessage: pillarInfo.name,
      ),
      InfiniteScrollTableCell.textFromAddress(
        address: pillarInfo.producerAddress,
        flex: _producerFlex,
        isStakeAddress: own,
      ),
      InfiniteScrollTableCell(
        flex: _weightFlex,
        // Aligned, so the flash is as wide as the weight and not as the
        // column.
        child: Align(
          alignment: Alignment.centerLeft,
          child: ValueFlash(
            // Keyed by the pillar: a row that comes to show another pillar
            // is not a change of this one's weight.
            key: ValueKey<String>(pillarInfo.name),
            value: pillarInfo.weight,
            color: tokens.znnInk,
            // Short form in the column ("9.92K"), which has no trailing
            // zeros; the exact weight is on hover.
            child: FormattedAmountWithTooltip(
              amount: pillarInfo.weight.addDecimals(kZnnCoin.decimals),
              tokenSymbol: kZnnCoin.symbol,
              builder: (String formattedAmount, String tokenSymbol) =>
                  Text.rich(
                    TextSpan(
                      style: mono.copyWith(color: ink),
                      children: <InlineSpan>[
                        TextSpan(text: formattedAmount),
                        TextSpan(
                          text: ' $tokenSymbol',
                          style: TextStyle(
                            fontFamily: kSansFontFamily,
                            fontWeight: FontWeight.w500,
                            color: tokens.znnInk,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
          ),
        ),
      ),
      InfiniteScrollTableCell.withText(
        content: '${pillarInfo.giveMomentumRewardPercentage}%',
        textStyle: mono,
        flex: _shareFlex,
      ),
      InfiniteScrollTableCell.withText(
        content: '${pillarInfo.giveDelegateRewardPercentage}%',
        textStyle: mono,
        flex: _shareFlex,
      ),
      InfiniteScrollTableCell.withText(
        content:
            '${pillarInfo.expectedMomentums}/${pillarInfo.producedMomentums}',
        textStyle: mono,
        flex: _momentumsFlex,
      ),
      InfiniteScrollTableCell.withText(
        content: '${_uptime(pillarInfo)}%',
        textStyle: mono,
        flex: _uptimeFlex,
      ),
      InfiniteScrollTableCell(
        flex: _delegationFlex,
        child: _DelegateCell(
          delegated: delegatedTo == pillarInfo.name,
          offered: canDelegate,
          buttonKey: _delegateButtonKeys.putIfAbsent(
            pillarInfo.name,
            GlobalKey<LoadingButtonState>.new,
          ),
          // While one delegation is on its way, every Delegate is disabled;
          // the one pressed shows its progress.
          onPressed: _delegatingTo == null
              ? () => _onDelegatePressed(pillarInfo)
              : null,
        ),
      ),
    ];
  }

  /// The share of the momentums expected of a pillar that it produced.
  static int _uptime(PillarInfo pillarInfo) {
    if (pillarInfo.expectedMomentums == 0) return 0;
    final double percentage =
        pillarInfo.producedMomentums / pillarInfo.expectedMomentums * 100;
    return percentage.isNaN ? 0 : percentage.round();
  }

  static const List<InfiniteScrollTableColumnType> _columns =
      <InfiniteScrollTableColumnType>[
        .pillarName,
        .producerAddress,
        .weight,
        .momentumReward,
        .delegationReward,
        .expectedProducedMomentums,
        .uptime,
        .delegation,
      ];

  // Eight columns share 932 px in the narrowest window (1200 px), so each
  // takes what its widest value needs and no more: a short address with its
  // copy button, a weight, the 96 px button, and a few characters for the
  // rest. With one unit of flex each, a percentage had as much room as a
  // name, and the three long heads were cut.
  static const int _nameFlex = 14;
  static const int _producerFlex = 18;
  static const int _weightFlex = 10;
  static const int _shareFlex = 9;
  static const int _momentumsFlex = 9;
  static const int _uptimeFlex = 7;
  static const int _delegationFlex = 11;

  /// The heads, in the order of [_columns]. The three that were too long for
  /// a narrow column have a short name and say the full one on hover.
  static Map<InfiniteScrollTableColumnType, InfiniteScrollTableHead> _heads(
    BuildContext context,
  ) => <InfiniteScrollTableColumnType, InfiniteScrollTableHead>{
    .pillarName: const InfiniteScrollTableHead(flex: _nameFlex),
    .producerAddress: const InfiniteScrollTableHead(flex: _producerFlex),
    .weight: const InfiniteScrollTableHead(flex: _weightFlex),
    .momentumReward: InfiniteScrollTableHead(
      name: 'Momentum %',
      tooltip: context.l10n.momentumReward,
      flex: _shareFlex,
    ),
    .delegationReward: InfiniteScrollTableHead(
      name: 'Delegate %',
      tooltip: context.l10n.delegationReward,
      flex: _shareFlex,
    ),
    .expectedProducedMomentums: InfiniteScrollTableHead(
      name: 'Momentums',
      tooltip: context.l10n.expectedProducedMomentums,
      flex: _momentumsFlex,
    ),
    .uptime: const InfiniteScrollTableHead(flex: _uptimeFlex),
    .delegation: const InfiniteScrollTableHead(flex: _delegationFlex),
  };
}

/// The last cell of a row: "Delegated" for the pillar the address backs,
/// Delegate for the others, nothing while the address holds too little ZNN
/// to delegate.
class _DelegateCell extends StatelessWidget {
  const _DelegateCell({
    required this.delegated,
    required this.offered,
    required this.buttonKey,
    required this.onPressed,
  });

  /// Whether the address delegates to this pillar.
  final bool delegated;

  /// Whether the address holds enough ZNN to delegate.
  final bool offered;

  /// Lets the card run the button's progress.
  final GlobalKey<LoadingButtonState> buttonKey;

  /// Null while a delegation is on its way, which disables the button.
  final VoidCallback? onPressed;

  static const Size _buttonSize = Size(96, 32);

  @override
  Widget build(BuildContext context) {
    if (delegated) {
      return const Center(child: StatusDot(on: true, label: 'Delegated'));
    }
    if (!offered) {
      return const SizedBox.shrink();
    }
    return Center(
      child: LoadingButton(
        key: buttonKey,
        onPressed: onPressed,
        text: 'Delegate',
        minimumSize: _buttonSize,
      ),
    );
  }
}
