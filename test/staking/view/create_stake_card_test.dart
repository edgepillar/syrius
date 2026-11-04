import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/disclosure.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/segment.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class _Balances extends MockBloc<MultipleBalanceEvent, MultipleBalanceState>
    implements MultipleBalanceBloc {}

class _Transactions extends MockBloc<SendTransactionEvent, SendTransactionState>
    implements SendTransactionBloc {}

class _Zenon extends Mock implements Zenon {}

class _Embedded extends Mock implements EmbeddedApi {}

class _Stake extends Mock implements StakeApi {}

class _Request extends Mock implements SendRequestHandle {}

const Key _amountKey = Key('create_stake_amount_field');
const Key _submitKey = Key('create_stake_submit_button');

AccountInfo _account(int wholeZnn) => AccountInfo(
  address: emptyAddress.toString(),
  blockCount: 1,
  balanceInfoList: <BalanceInfoListItem>[
    BalanceInfoListItem(
      token: kZnnCoin,
      balance: BigInt.from(wholeZnn) * BigInt.from(10).pow(kZnnCoin.decimals),
    ),
  ],
);

MultipleBalanceState _balanceState(
  int amount, {
  MultipleBalanceStatus status = MultipleBalanceStatus.success,
}) => MultipleBalanceState(
  status: status,
  data: <String, AccountInfo>{emptyAddress.toString(): _account(amount)},
);

void main() {
  late _Balances balances;
  late _Transactions transactions;
  late StreamController<MultipleBalanceState> balanceStates;
  late StreamController<SendTransactionState> transactionStates;
  late _Stake stake;
  late Zenon? previousZenon;
  late String? previousAddress;
  late SelectedAddressNotifier selection;
  late List<Completer<SendRequestResult>> outcomes;
  late List<bool Function()> startGuards;
  late List<bool Function()> publishGuards;
  late bool refuseAdmission;

  setUpAll(() {
    registerFallbackValue(() => true);
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(const MultipleBalanceFetch(addresses: <String>[]));
    registerFallbackValue(
      SendTransactionInitiateFromBlock(
        block: AccountBlockTemplate(blockType: 1),
        fromAddress: emptyAddress.toString(),
        reasonForGeneratingPlasma: '',
      ),
    );
  });

  setUp(() {
    previousAddress = kSelectedAddress;
    previousZenon = app.zenon;
    kSelectedAddress = emptyAddress.toString();
    selection = SelectedAddressNotifier();
    balances = _Balances();
    transactions = _Transactions();
    outcomes = <Completer<SendRequestResult>>[];
    startGuards = <bool Function()>[];
    publishGuards = <bool Function()>[];
    refuseAdmission = false;
    balanceStates = StreamController<MultipleBalanceState>.broadcast(
      sync: true,
    );
    transactionStates = StreamController<SendTransactionState>.broadcast(
      sync: true,
    );
    whenListen(
      balances,
      balanceStates.stream,
      initialState: _balanceState(1000),
    );
    whenListen(
      transactions,
      transactionStates.stream,
      initialState: const SendTransactionState(),
    );
    when(
      () => transactions.trySubmitContract(
        any(),
        canStart: any(named: 'canStart'),
        canPublish: any(named: 'canPublish'),
      ),
    ).thenAnswer((Invocation invocation) {
      if (refuseAdmission) return null;
      final SendTransactionInitiateFromBlock event =
          invocation.positionalArguments.single
              as SendTransactionInitiateFromBlock;
      final Completer<SendRequestResult> outcome =
          Completer<SendRequestResult>();
      final _Request request = _Request();
      when(() => request.requestId).thenReturn(event.requestId!);
      when(() => request.result).thenAnswer((_) => outcome.future);
      outcomes.add(outcome);
      startGuards.add(invocation.namedArguments[#canStart] as bool Function());
      publishGuards.add(
        invocation.namedArguments[#canPublish] as bool Function(),
      );
      // Observe the enqueued event; real admission is tested with the sender.
      transactions.add(event);
      return request;
    });
    app.sl.registerSingleton<MultipleBalanceBloc>(balances);

    final _Zenon zenon = _Zenon();
    final _Embedded embedded = _Embedded();
    stake = _Stake();
    when(() => zenon.embedded).thenReturn(embedded);
    when(() => embedded.stake).thenReturn(stake);
    app.zenon = zenon;
  });

  tearDown(() async {
    WalletContextRevision.invalidate();
    for (final Completer<SendRequestResult> outcome in outcomes) {
      if (!outcome.isCompleted) {
        outcome.complete(SendRequestResult(error: StateError('Owner closed')));
      }
    }
    await balanceStates.close();
    await transactionStates.close();
    await app.sl.unregister<MultipleBalanceBloc>();
    selection.dispose();
    kSelectedAddress = previousAddress;
    app.zenon = previousZenon;
  });

  Widget host({
    bool light = false,
    bool rtl = false,
    double width = 1180,
    DisclosureController? disclosure,
    VoidCallback? onCreated,
    ValueChanged<AccountBlockTemplate>? onPublished,
  }) {
    final Widget form = CreateStakeCard(
      framed: false,
      createTransactionBloc: () => transactions,
      onStakeCreated: onCreated ?? () {},
      onStakePublished: onPublished,
    );
    return MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<SelectedAddressNotifier>.value(
            value: selection,
          ),
          BlocProvider<MultipleBalanceBloc>.value(value: balances),
        ],
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: width,
                child: disclosure == null
                    ? form
                    : Disclosure.bare(
                        controller: disclosure,
                        keepAlive: true,
                        child: form,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(child);
    await tester.pump(const Duration(milliseconds: 400));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  Future<void> chooseSixMonths(WidgetTester tester) async {
    await tester.tap(find.byKey(Segment.keyOf('create_stake_months', 6)));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('presets and exact amount validation retain the chain limits', (
    WidgetTester tester,
  ) async {
    await show(tester, host());
    final Segment<int> segment = tester.widget<Segment<int>>(
      find.byType(Segment<int>),
    );
    expect(segment.items.map((SegmentItem<int> item) => item.value), <int>[
      1,
      2,
      3,
      6,
      9,
      12,
    ]);
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('create_stake_unlock_date')))
          .data,
      isEmpty,
    );

    await chooseSixMonths(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('create_stake_unlock_date')))
          .data,
      DateFormat(
        'd MMM yyyy',
        'en',
      ).format(DateTime.now().add(Duration(seconds: 6 * stakeTimeUnitSec))),
    );
    await tester.enterText(find.byKey(_amountKey), '1001');
    await tester.pump();
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).decoration!.errorText,
      isNotNull,
    );
    await tester.enterText(find.byKey(_amountKey), '0.1');
    await tester.pump();
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('create_stake_max_button')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      _account(
        1000,
      ).getBalance(kZnnCoin.tokenStandard).addDecimals(kZnnCoin.decimals),
    );
    expect(find.text('Stake 1,000 ZNN'), findsOneWidget);
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNotNull,
    );
    verifyNever(() => transactions.add(any()));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the same draft survives disclosure close and balance refresh', (
    WidgetTester tester,
  ) async {
    final DisclosureController disclosure = DisclosureController();
    addTearDown(disclosure.dispose);
    await show(tester, host(disclosure: disclosure));
    disclosure.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    final TextEditingController controller = tester
        .widget<TextField>(find.byKey(_amountKey))
        .controller!;
    disclosure.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    disclosure.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller,
      same(controller),
    );
    expect(controller.text, '300');
    expect(tester.widget<Segment<int>>(find.byType(Segment<int>)).selected, 6);

    balanceStates.add(
      _balanceState(1000, status: MultipleBalanceStatus.loading),
    );
    await tester.pump();
    balanceStates.add(_balanceState(500));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller,
      same(controller),
    );
    expect(controller.text, '300');
    expect(find.text('of 500 ZNN'), findsOneWidget);
    verifyNever(() => transactions.add(any()));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard resubmission cannot enqueue a second stake', (
    WidgetTester tester,
  ) async {
    int created = 0;
    final BigInt amount =
        BigInt.from(300) * BigInt.from(10).pow(kZnnCoin.decimals);
    final AccountBlockTemplate block = AccountBlockTemplate(blockType: 1);
    when(() => stake.stake(6 * stakeTimeUnitSec, amount)).thenReturn(block);
    final List<AccountBlockTemplate> observed = <AccountBlockTemplate>[];
    await show(tester, host(onCreated: () => created++,
      onPublished: (AccountBlockTemplate original) {
        observed.add(original);
        throw StateError('Read observer refused');
      }));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    final ValueChanged<String> submit = tester
        .widget<TextField>(find.byKey(_amountKey))
        .onSubmitted!;
    final VoidCallback max = tester
        .widget<TextButton>(
          find.byKey(const Key('create_stake_max_button')),
        )
        .onPressed!;
    final ValueChanged<int> duration = tester
        .widget<Segment<int>>(find.byType(Segment<int>))
        .onChanged;
    submit('300');
    submit('300');
    max();
    duration(1);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      '300',
    );
    expect(tester.widget<Segment<int>>(find.byType(Segment<int>)).selected, 6);
    verify(() => stake.stake(6 * stakeTimeUnitSec, amount)).called(1);
    final List<dynamic> sent = verify(
      () => transactions.add(captureAny()),
    ).captured;
    expect(sent, hasLength(1));
    final SendTransactionInitiateFromBlock event =
        sent.single as SendTransactionInitiateFromBlock;
    expect(event.block, same(block));
    expect(event.fromAddress, emptyAddress.toString());
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNull,
    );

    transactionStates.add(
      const SendTransactionState(status: SendTransactionStatus.loading),
    );
    await tester.pump();
    submit('300');
    verifyNever(() => transactions.add(any()));
    transactionStates.add(
      SendTransactionState(status: SendTransactionStatus.success, data: block),
    );
    await tester.pump();
    expect(created, 0);
    expect(observed, isEmpty);
    outcomes.single.complete(SendRequestResult(block: block));
    await tester.pump();
    expect(created, 1);
    expect(observed, hasLength(1));
    expect(observed.single, same(block));
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<Segment<int>>(find.byType(Segment<int>)).selected,
      isNull,
    );
    verify(() => balances.add(any())).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('old controls reject address round trips before a frame', (
    WidgetTester tester,
  ) async {
    await show(tester, host());
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    final TextEditingController amount = tester
        .widget<TextField>(find.byKey(_amountKey)).controller!;
    final VoidCallback max = tester.widget<TextButton>(
      find.byKey(const Key('create_stake_max_button')),
    ).onPressed!;
    final ValueChanged<int> duration = tester
        .widget<Segment<int>>(find.byType(Segment<int>)).onChanged;
    final ValueChanged<String> submit = tester
        .widget<TextField>(find.byKey(_amountKey)).onSubmitted!;
    for (final String address in <String>[
      Address('z', <int>[0, 1, ...List<int>.filled(18, 7)]).toString(),
      emptyAddress.toString(),
    ]) {
      kSelectedAddress = address;
      WalletContextRevision.invalidate();
      max();
      duration(1);
      submit('300');
      expect(amount.text, '300');
    }
    verifyZeroInteractions(stake);
    verifyNever(() => transactions.add(any()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('create_stake_max_button')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      '1000',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    max();
    duration(1);
    submit('300');
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained controls cannot edit a closed kept-alive form', (
    WidgetTester tester,
  ) async {
    final DisclosureController disclosure = DisclosureController();
    addTearDown(disclosure.dispose);
    await show(tester, host(disclosure: disclosure));
    disclosure.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    final TextEditingController amount = tester
        .widget<TextField>(find.byKey(_amountKey)).controller!;
    final VoidCallback max = tester.widget<TextButton>(
      find.byKey(const Key('create_stake_max_button')),
    ).onPressed!;
    final ValueChanged<int> duration = tester
        .widget<Segment<int>>(find.byType(Segment<int>)).onChanged;
    final ValueChanged<String> submit = tester
        .widget<TextField>(find.byKey(_amountKey)).onSubmitted!;
    disclosure.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    max();
    duration(1);
    submit('300');
    expect(amount.text, '300');
    verifyZeroInteractions(stake);
    verifyNever(() => transactions.add(any()));
    disclosure.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Segment<int>>(find.byType(Segment<int>)).selected, 6);
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller,
      same(amount),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an original accepted result outlives its form', (
    WidgetTester tester,
  ) async {
    final AccountBlockTemplate block = AccountBlockTemplate(blockType: 1);
    when(() => stake.stake(6 * stakeTimeUnitSec, any())).thenReturn(block);
    final List<AccountBlockTemplate> observed = <AccountBlockTemplate>[];
    int created = 0;
    await show(tester, host(
      onCreated: () => created++,
      onPublished: observed.add,
    ));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    tester.widget<TextField>(find.byKey(_amountKey)).onSubmitted!('300');
    expect(startGuards.single(), isTrue);
    expect(publishGuards.single(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    outcomes.single.complete(SendRequestResult(block: block));
    await tester.pump();
    expect(observed, <AccountBlockTemplate>[block]);
    expect(created, 0);
    verifyNever(() => balances.add(any()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old accepted result cannot clear a replacement draft', (
    WidgetTester tester,
  ) async {
    final AccountBlockTemplate block = AccountBlockTemplate(blockType: 1);
    when(() => stake.stake(6 * stakeTimeUnitSec, any())).thenReturn(block);
    final List<AccountBlockTemplate> observed = <AccountBlockTemplate>[];
    int created = 0;
    await show(tester, host(
      onCreated: () => created++,
      onPublished: observed.add,
    ));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    tester.widget<TextField>(find.byKey(_amountKey)).onSubmitted!('300');
    WalletContextRevision.invalidate();
    expect(startGuards.single(), isFalse);
    expect(publishGuards.single(), isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '400');
    await tester.pump();
    outcomes.single.complete(SendRequestResult(block: block));
    await tester.pump();
    expect(observed, <AccountBlockTemplate>[block]);
    expect(created, 0);
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      '400',
    );
    verifyNever(() => balances.add(any()));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refused admission releases only its pending display', (
    WidgetTester tester,
  ) async {
    final AccountBlockTemplate block = AccountBlockTemplate(blockType: 1);
    when(() => stake.stake(6 * stakeTimeUnitSec, any())).thenReturn(block);
    refuseAdmission = true;
    await show(tester, host());
    await chooseSixMonths(tester);
    await tester.enterText(find.byKey(_amountKey), '300');
    await tester.pump();
    tester.widget<TextField>(find.byKey(_amountKey)).onSubmitted!('300');
    await tester.pump();
    expect(outcomes, isEmpty);
    expect(
      tester.widget<TextField>(find.byKey(_amountKey)).controller!.text,
      '300',
    );
    expect(
      tester.widget<PrimaryPill>(find.byKey(_submitKey)).onPressed,
      isNotNull,
    );
    verifyNever(() => transactions.add(any()));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'compact form fits the ${light ? 'light' : 'dark'} RTL layout',
      (
        WidgetTester tester,
      ) async {
        await show(tester, host(light: light, rtl: true, width: 980));
        await chooseSixMonths(tester);
        await tester.enterText(find.byKey(_amountKey), '300.5');
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byKey(_amountKey)).textDirection,
          TextDirection.ltr,
        );
        expect(find.text('Stake 300.5 ZNN'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
