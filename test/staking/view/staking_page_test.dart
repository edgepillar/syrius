import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/staking_tab_child.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../helpers/hydrated_bloc.dart';

class _Stakes extends MockBloc<InfiniteListEvent, InfiniteListState<StakeEntry>>
    implements StakesBloc {}

class _Staking extends MockCubit<StakingState> implements StakingCubit {}

class _Rewards extends MockBloc<FetchEvent, FetchState<UncollectedReward>>
    implements UncollectedStakingRewardsBloc {}

class _History extends MockBloc<FetchEvent, FetchState<RewardHistoryList>>
    implements StakingRewardsHistoryBloc {}

class _Transactions extends MockBloc<SendTransactionEvent, SendTransactionState>
    implements SendTransactionBloc {}

class _Balances extends MockBloc<MultipleBalanceEvent, MultipleBalanceState>
    implements MultipleBalanceBloc {}

class _Uncollected extends Mock implements UncollectedReward {}

class _RewardList extends Mock implements RewardHistoryList {}

class _RewardEntry extends Mock implements RewardHistoryEntry {}

BigInt _coins(String amount) => amount.extractDecimals(kZnnCoin.decimals);

void main() {
  initHydratedStorage();
  late _Stakes stakes;
  late _Staking staking;
  late _Rewards rewards;
  late _History history;
  late _Transactions transactions;
  late _Balances balances;
  late SelectedAddressNotifier selection;
  late PriceFeed prices;
  late String? previousAddress;

  setUp(() {
    previousAddress = kSelectedAddress;
    kSelectedAddress = emptyAddress.toString();
    selection = SelectedAddressNotifier();
    stakes = _Stakes();
    staking = _Staking();
    rewards = _Rewards();
    history = _History();
    transactions = _Transactions();
    balances = _Balances();
    BalanceVisibility.debugReset();
    prices = PriceFeed(
      request: (_) async => '{"zenon-2":{"usd":0.62},"quasar":{"usd":0.031}}',
    );
    whenListen(
      transactions,
      const Stream<SendTransactionState>.empty(),
      initialState: const SendTransactionState(),
    );
    whenListen(
      balances,
      const Stream<MultipleBalanceState>.empty(),
      initialState: const MultipleBalanceState(),
    );
  });

  tearDown(() {
    selection.dispose();
    prices.dispose();
    kSelectedAddress = previousAddress;
    BalanceVisibility.debugReset();
    AppLottie.debugClear();
  });

  void populate({bool empty = false, bool unknown = false}) {
    final _Uncollected uncollected = _Uncollected();
    when(
      () => uncollected.qsrAmount,
    ).thenReturn(empty ? BigInt.zero : _coins('18.4'));
    final _RewardList week = _RewardList();
    final _RewardEntry reward = _RewardEntry();
    when(() => reward.qsrAmount).thenReturn(_coins('41.2'));
    when(() => week.list).thenReturn(<RewardHistoryEntry>[reward]);
    final int start =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 -
        const Duration(days: 3).inSeconds;
    final List<StakeEntry> entries = empty
        ? <StakeEntry>[]
        : List<StakeEntry>.generate(
            3,
            (int index) => StakeEntry(
              amount: _coins('500'),
              weightedAmount: BigInt.zero,
              startTimestamp: start,
              expirationTimestamp: start + 6 * stakeTimeUnitSec,
              address: emptyAddress,
              id: Hash.parse((index + 1).toString().padLeft(64, '0')),
            ),
          );
    whenListen(
      stakes,
      const Stream<InfiniteListState<StakeEntry>>.empty(),
      initialState: unknown
          ? const InfiniteListState<StakeEntry>.initial()
          : InfiniteListState<StakeEntry>(
              status: InfiniteListStatus.success,
              data: entries,
              hasReachedMax: true,
            ),
    );
    whenListen(
      staking,
      const Stream<StakingState>.empty(),
      initialState: unknown
          ? const StakingState()
          : empty
          ? StakingState(
              status: TimerStatus.failure,
              error: NoActiveStakingEntriesException(),
            )
          : StakingState(
              status: TimerStatus.success,
              data: StakeList(
                totalAmount: _coins('1500'),
                totalWeightedAmount: BigInt.zero,
                count: 3,
                list: entries,
              ),
            ),
    );
    whenListen(
      rewards,
      const Stream<FetchState<UncollectedReward>>.empty(),
      initialState: unknown
          ? const FetchInitial<UncollectedReward>()
          : FetchPopulated<UncollectedReward>(data: uncollected),
    );
    whenListen(
      history,
      const Stream<FetchState<RewardHistoryList>>.empty(),
      initialState: unknown
          ? const FetchInitial<RewardHistoryList>()
          : empty
          ? FetchFailure<RewardHistoryList>(
              exception: NoRewardsLastWeekException(),
            )
          : FetchPopulated<RewardHistoryList>(data: week),
    );
  }

  Widget host({bool light = false}) => MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SelectedAddressNotifier>.value(value: selection),
        BlocProvider<StakesBloc>.value(value: stakes),
        BlocProvider<StakingCubit>.value(value: staking),
        BlocProvider<UncollectedStakingRewardsBloc>.value(value: rewards),
        BlocProvider<StakingRewardsHistoryBloc>.value(value: history),
        BlocProvider<SendTransactionBloc>.value(value: transactions),
        BlocProvider<MultipleBalanceBloc>.value(value: balances),
      ],
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: StakingPage(priceFeed: prices),
        ),
      ),
    ),
  );

  Future<void> show(WidgetTester tester, {bool light = false}) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(light: light));
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'established empty state has both original marks, light $light',
      (
        WidgetTester tester,
      ) async {
        populate(empty: true);
        await show(tester, light: light);
        expect(find.byKey(const Key('staking_empty_rewards')), findsOneWidget);
        expect(find.text('None yet'), findsNWidgets(2));
        final List<double> marks = tester
            .widgetList<AppLottie>(find.byType(AppLottie))
            .where((AppLottie mark) => mark.asset == AppLottieAsset.noData)
            .map((AppLottie mark) => mark.size!)
            .toList();
        expect(marks, containsAll(<double>[44, 16]));
        expect(find.byKey(const Key('staking_collect_button')), findsNothing);
        expect(find.byKey(const Key('staking_chart_button')), findsNothing);
        expect(find.byKey(const Key('staking_stake_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('unknown responses never become a fabricated empty address', (
    WidgetTester tester,
  ) async {
    populate(unknown: true);
    await show(tester);
    expect(find.byKey(const Key('staking_empty_rewards')), findsNothing);
    expect(find.byType(AmountText), findsNothing);
    expect(find.text('None yet'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('exact dollar values disappear with their chain amounts', (
    WidgetTester tester,
  ) async {
    populate();
    await show(tester);
    await tester.pump();
    expect(find.text(r'$930.00'), findsOneWidget);
    expect(find.text(r'$0.5704'), findsOneWidget);
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      BalanceVisibility.instance.set(true);
      await tester.pump();
      expect(find.text(r'$930.00'), findsNothing);
      expect(find.text(r'$0.5704'), findsNothing);
      expect(
        find.semantics.byLabel(RegExp(r'1,500|18\.4|\$930')),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
