import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class _Stakes extends MockBloc<InfiniteListEvent, InfiniteListState<StakeEntry>>
    implements StakesBloc {}

class _Zenon extends Mock implements Zenon {}

Hash _hash(int index) => Hash.parse(index.toRadixString(16).padLeft(64, '0'));

StakeEntry _entry(int index, {bool unlocked = false}) {
  final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final int start = now - Duration(days: unlocked ? 60 : 3).inSeconds;
  return StakeEntry(
    amount:
        BigInt.from(unlocked ? 200 : 500) *
        BigInt.from(10).pow(kZnnCoin.decimals),
    weightedAmount: BigInt.zero,
    startTimestamp: start,
    expirationTimestamp: start + (unlocked ? 1 : 6) * stakeTimeUnitSec,
    address: emptyAddress,
    id: _hash(index),
  );
}

InfiniteListState<StakeEntry> _populated(List<StakeEntry> entries) =>
    InfiniteListState<StakeEntry>(
      status: InfiniteListStatus.success,
      data: entries,
      hasReachedMax: true,
    );

Finder _row(int index) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is ListEntranceItem &&
      widget.key == ValueKey<String>(_hash(index).toString()),
);

double _rowOpacity(WidgetTester tester, int index) => tester
    .widget<Opacity>(
      find.descendant(of: _row(index), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  late _Stakes stakes;
  late StreamController<InfiniteListState<StakeEntry>> states;
  late String? previousAddress;
  late Zenon? previousZenon;

  setUpAll(() {
    registerFallbackValue(const InfiniteListRefreshRequested());
  });

  setUp(() {
    previousAddress = kSelectedAddress;
    previousZenon = app.zenon;
    kSelectedAddress = emptyAddress.toString();
    app.zenon = _Zenon();
    stakes = _Stakes();
    states = StreamController<InfiniteListState<StakeEntry>>.broadcast(
      sync: true,
    );
    BalanceVisibility.debugReset();
  });

  tearDown(() async {
    await states.close();
    kSelectedAddress = previousAddress;
    app.zenon = previousZenon;
    BalanceVisibility.debugReset();
    AppLottie.debugClear();
  });

  Widget host({bool light = false}) => MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<StakesBloc>.value(
      value: stakes,
      child: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: StakesCard(),
        ),
      ),
    ),
  );

  Future<void> show(
    WidgetTester tester,
    List<StakeEntry> entries, {
    bool light = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    whenListen(stakes, states.stream, initialState: _populated(entries));
    await tester.pumpWidget(host(light: light));
  }

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'unlock status and action are distinct in ${light ? 'light' : 'dark'}',
      (
        WidgetTester tester,
      ) async {
        await show(tester, <StakeEntry>[
          _entry(1),
          _entry(2, unlocked: true),
        ], light: light);
        await tester.pump(const Duration(milliseconds: 450));
        for (final String heading in <String>[
          'AMOUNT',
          'DURATION',
          'STARTED',
          'UNLOCKS',
        ]) {
          expect(find.text(heading), findsOneWidget);
        }
        expect(find.text('3 d ago'), findsOneWidget);
        expect(find.text('Unlocked'), findsOneWidget);
        final Finder locked = find.byKey(
          ValueKey<String>('staking_cancel_locked_${_hash(1)}'),
        );
        expect(tester.widget<OutlinedButton>(locked).onPressed, isNull);
        expect(find.text('Cancel and withdraw'), findsOneWidget);
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('staking_stakes_count')))
              .data,
          '2',
        );
        verifyNever(() => stakes.add(any()));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('reordering and an empty refresh never replay a known stake', (
    WidgetTester tester,
  ) async {
    final List<StakeEntry> entries = <StakeEntry>[
      _entry(1),
      _entry(2),
      _entry(3),
    ];
    await show(tester, entries);
    expect(_rowOpacity(tester, 1), 0);
    await tester.pump(const Duration(milliseconds: 450));
    expect(_rowOpacity(tester, 1), 1);
    states.add(_populated(entries.reversed.toList()));
    await tester.pump();
    expect(_rowOpacity(tester, 1), 1);
    states.add(_populated(const <StakeEntry>[]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('None yet'), findsOneWidget);
    states.add(_populated(entries));
    await tester.pump();
    expect(_rowOpacity(tester, 1), 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('old offscreen rows appear settled when lazily mounted', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      List<StakeEntry>.generate(80, (int index) => _entry(index + 1)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(_row(50), findsNothing);
    await tester.scrollUntilVisible(
      _row(50),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_rowOpacity(tester, 50), 1);
    await tester.scrollUntilVisible(
      _row(1),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_rowOpacity(tester, 1), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden balances suppress the stake amounts in semantics', (
    WidgetTester tester,
  ) async {
    await show(tester, <StakeEntry>[_entry(1)]);
    await tester.pump(const Duration(milliseconds: 450));
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      BalanceVisibility.instance.set(true);
      await tester.pump();
      expect(find.text('••••'), findsOneWidget);
      expect(find.semantics.byLabel(RegExp('500.*ZNN')), findsNothing);
    } finally {
      semantics.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
