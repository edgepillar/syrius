import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/auto_receive_tx_worker.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/transfer/view/transfer_page.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../harness/app/agent.dart';
import '../helpers/hydrated_bloc.dart';

class _Balances extends MockBloc<MultipleBalanceEvent, MultipleBalanceState>
    implements MultipleBalanceBloc {}

class _Tokens extends MockBloc<AllTokensEvent, AllTokensState>
    implements AllTokensBloc {}

class _Transactions extends MockBloc<SendTransactionEvent, SendTransactionState>
    implements SendTransactionBloc {}

class _Pending
    extends MockBloc<InfiniteListEvent, InfiniteListState<AccountBlock>>
    implements PendingTransactionsBloc {}

class _Worker extends AutoReceiveTxWorker {
  _Worker(this.sender);

  final SendTransactionBloc sender;
  final List<Hash> calls = <Hash>[];
  Completer<AccountBlockTemplate?>? _completion;

  @override
  bool running = false;

  @override
  ReceiveOrigin? captureOrigin({bool Function()? sourceIsCurrent}) {
    final String? selected = kSelectedAddress;
    if (selected == null || !(sourceIsCurrent?.call() ?? true)) return null;
    final List<String> addresses = kDefaultAddressList.cast<String>().toList();
    return ReceiveOrigin(
      sender: sender,
      ledger: LedgerApi(),
      stats: StatsApi(),
      chainId: 321,
      nodeChainId: 321,
      selectedAddress: selected,
      addresses: addresses,
      isCurrent: () =>
          kSelectedAddress == selected &&
          kDefaultAddressList.length == addresses.length &&
          kDefaultAddressList.indexed.every(
            ((int, String?) member) => member.$2 == addresses[member.$1],
          ) &&
          (sourceIsCurrent?.call() ?? true),
    );
  }

  @override
  Future<AccountBlockTemplate?> autoReceiveTransactionHash(
    Hash hash, {
    ReceiveOrigin? origin,
    bool Function()? sourceIsCurrent,
  }) {
    if (origin == null ||
        !origin.isCurrent ||
        !(sourceIsCurrent?.call() ?? true)) {
      return Future<AccountBlockTemplate?>.error(const ReceiveRefused());
    }
    calls.add(hash);
    running = true;
    inFlight.value = <Hash>{...inFlight.value, hash};
    _completion = Completer<AccountBlockTemplate?>();
    return _completion!.future;
  }

  void finish({bool hold = true, bool fail = false}) {
    running = false;
    if (!hold) inFlight.value = <Hash>{};
    if (fail) {
      _completion!.completeError(StateError('test refusal'));
    } else {
      _completion!.complete();
    }
    _completion = null;
  }
}

InfiniteListState<AccountBlock> _rows(
  List<AccountBlock> rows, {
  bool more = false,
}) => InfiniteListState<AccountBlock>(
  status: InfiniteListStatus.success,
  data: rows,
  hasReachedMax: !more,
);

Future<T> _drive<T>(WidgetTester tester, Future<T> command) async {
  bool done = false;
  T? result;
  Object? error;
  StackTrace? trace;
  unawaited(command.then((T value) {
    result = value;
    done = true;
  }, onError: (Object value, StackTrace stack) {
    error = value;
    trace = stack;
    done = true;
  }));
  for (int frame = 0; frame < 80 && !done; frame++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(done, isTrue, reason: 'The actual header command must settle');
  if (error != null) Error.throwWithStackTrace(error!, trace!);
  return result as T;
}

void main() {
  initHydratedStorage();
  late _Balances balances;
  late _Tokens tokens;
  late _Transactions transactions;
  late _Pending pending;
  late _Worker worker;
  late SendDraftCubit draft;
  late PriceFeed prices;
  late TransferController controller;
  late StreamController<InfiniteListState<AccountBlock>> pendingStates;
  late StreamController<MultipleBalanceState> balanceStates;
  late StreamController<SendTransactionState> transactionStates;
  late ValueNotifier<bool> senderBusy;
  late String? previousAddress;
  late List<String?> previousAddresses;
  late Map<String, String> previousLabels;
  late SharedPrefsService? previousPreferences;

  setUpAll(() {
    registerFallbackValue(const MultipleBalanceFetch(addresses: <String>[]));
    registerFallbackValue(const AllTokensRequested());
    registerFallbackValue(const InfiniteListRequested());
    registerFallbackValue(
      SendTransactionInitiateFromBlock(
        block: AccountBlockTemplate(blockType: 1),
        fromAddress: emptyAddress.toString(),
        reasonForGeneratingPlasma: '',
      ),
    );
  });

  setUp(() async {
    previousAddress = kSelectedAddress;
    previousAddresses = kDefaultAddressList;
    previousLabels = kAddressLabelMap;
    previousPreferences = app.sharedPrefsService;
    kSelectedAddress = emptyAddress.toString();
    kDefaultAddressList = <String?>[kSelectedAddress];
    kAddressLabelMap = <String, String>{kSelectedAddress!: 'Address 1'};
    Hive.init('transfer-sender-preferences');
    final Box<dynamic> preferences = await Hive.openBox<dynamic>(
      kSharedPrefsBox,
      bytes: Uint8List(0),
    );
    await preferences.put(kAutoReceiveKey, false);
    app.sharedPrefsService = await SharedPrefsService.getInstance();
    BalanceVisibility.debugReset();
    balances = _Balances();
    tokens = _Tokens();
    transactions = _Transactions();
    pending = _Pending();
    worker = _Worker(transactions);
    draft = SendDraftCubit();
    prices = PriceFeed(request: (_) async => '{}');
    controller = TransferController();
    pendingStates = StreamController<InfiniteListState<AccountBlock>>.broadcast(
      sync: true,
    );
    balanceStates = StreamController<MultipleBalanceState>.broadcast(
      sync: true,
    );
    transactionStates = StreamController<SendTransactionState>.broadcast(
      sync: true,
    );
    senderBusy = ValueNotifier<bool>(false);
    when(() => transactions.busy).thenReturn(senderBusy);
    whenListen(
      balances,
      balanceStates.stream,
      initialState: MultipleBalanceState(
        status: MultipleBalanceStatus.success,
        data: <String, AccountInfo>{
          kSelectedAddress!: AccountInfo(
            address: kSelectedAddress,
            blockCount: 1,
            balanceInfoList: <BalanceInfoListItem>[
              BalanceInfoListItem(
                token: kZnnCoin,
                balance: BigInt.from(100000000000),
              ),
              BalanceInfoListItem(
                token: kQsrCoin,
                balance: BigInt.from(100000000000),
              ),
            ],
          ),
        },
      ),
    );
    whenListen(
      tokens,
      const Stream<AllTokensState>.empty(),
      initialState: AllTokensPopulated(data: <Token>[kZnnCoin, kQsrCoin]),
    );
    whenListen(
      transactions,
      transactionStates.stream,
      initialState: const SendTransactionState(),
    );
    whenListen(
      pending,
      pendingStates.stream,
      initialState: _rows(<AccountBlock>[]),
    );
  });

  tearDown(() async {
    await pendingStates.close();
    await balanceStates.close();
    await transactionStates.close();
    senderBusy.dispose();
    await draft.close();
    prices.dispose();
    controller.dispose();
    worker.dispose();
    await Hive.close();
    app.sharedPrefsService = previousPreferences;
    kSelectedAddress = previousAddress;
    kDefaultAddressList = previousAddresses;
    kAddressLabelMap = previousLabels;
    BalanceVisibility.debugReset();
    AppLottie.debugClear();
  });

  Widget host({bool light = false, bool reduced = false}) => MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<MultipleBalanceBloc>.value(value: balances),
        BlocProvider<AllTokensBloc>.value(value: tokens),
        BlocProvider<SendTransactionBloc>.value(value: transactions),
        BlocProvider<PendingTransactionsBloc>.value(value: pending),
        BlocProvider<SendDraftCubit>.value(value: draft),
      ],
      child: Scaffold(
        body: TransferPage(
          controller: controller,
          receiveWorker: worker,
          priceFeed: prices,
        ),
      ),
    ),
  );

  Future<void> show(
    WidgetTester tester, {
    bool light = false,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(light: light, reduced: reduced));
    await tester.pump(const Duration(milliseconds: 500));
  }

  String addSecondAddress() {
    final String second = Address(
      'z', <int>[0, 2, ...List<int>.filled(18, 3)],
    ).toString();
    kDefaultAddressList = <String?>[emptyAddress.toString(), second];
    kSelectedAddress = second;
    kAddressLabelMap[second] = 'Address 2';
    balanceStates.add(MultipleBalanceState(
      status: MultipleBalanceStatus.success,
      data: <String, AccountInfo>{
        ...balances.state.data!,
        second: AccountInfo(
          address: second, blockCount: 1,
          balanceInfoList: <BalanceInfoListItem>[
            BalanceInfoListItem(
              token: kZnnCoin, balance: BigInt.from(2500000000),
            ),
          ],
        ),
      },
    ));
    return second;
  }

  for (final bool light in <bool>[false, true]) {
    testWidgets('actual Transfer header selects its typed owner $light',
        (WidgetTester tester) async {
      await show(tester, light: light);
      final String owner = addSecondAddress();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final StatefulElement form =
          tester.element(find.byType(SendPopulated)) as StatefulElement;
      final SendFormOrigin original = form.state as SendFormOrigin;
      expect(original.draftSender, isNot(owner));
      bool current = true;
      addTearDown(() async {
        current = false;
        await tester.pump(const Duration(milliseconds: 40));
      });
      void requireCurrent() {
        if (!current || !form.mounted ||
            !identical(form.state, original) || kSelectedAddress != owner ||
            !kDefaultAddressList.contains(owner)) {
          throw StateError('The original header owner changed');
        }
      }
      final HarnessAgent agent = HarnessAgent.forTest();
      await _drive(tester, agent.selectLabSenderForTest(owner, requireCurrent));
      expect(draft.state.fromAddress, owner);
      expect(original.draftSender, owner);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an open actual sender menu retains its original choices',
      (WidgetTester tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('transfer_sender')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final List<Widget> original = find.byType(PopupMenuItem<String>)
        .evaluate().map((Element item) => item.widget).toList();
    expect(original, hasLength(1));
    final String owner = addSecondAddress();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final List<Widget> current = find.byType(PopupMenuItem<String>)
        .evaluate().map((Element item) => item.widget).toList();
    expect(current, original);
    expect(current.where((Widget item) =>
      (item as PopupMenuItem<String>).value == owner), isEmpty);
    final SendPopulated form = tester.widget<SendPopulated>(
      find.byType(SendPopulated),
    );
    expect(form.balances.containsKey(owner), isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
