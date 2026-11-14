import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/htlc_swap_details_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/p2p_swaps_list_item.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_binding.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/p2p_swap_widgets/swap_list_view.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/p2p_swap_tab_child.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../helpers/mockup_symbol.dart';
import 'support.dart';

Future<void> frames(WidgetTester tester, [int count = 16]) async {
  for (int frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

Widget host(
  Widget child, {
  bool light = false,
  bool rtl = false,
  double scale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(1280, 780),
      textScaler: TextScaler.linear(scale),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  ),
);

void main() {
  for (final bool closesBeforeRead in <bool>[false, true]) {
    testWidgets(
      'a pending refresh preserves the modal owner '
      'and reloads after close, early=$closesBeforeRead',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 780);
        tester.view.devicePixelRatio = 1;
        final Completer<SwapListPage> pending = Completer<SwapListPage>();
        final SwapListRecord originalRow = swapRecord(1);
        final SwapListRecord lateRow = swapRecord(2);
        final SwapListRecord freshRow = swapRecord(3);
        final SwapListFixture original = SwapListFixture()..add(originalRow);
        final SwapListFixture waiting = SwapListFixture()
          ..add(lateRow)
          ..pageRead = (int page, int size) => pending.future;
        final SwapListFixture fresh = SwapListFixture()..add(freshRow);
        final List<SwapListFixture> sources = <SwapListFixture>[
          original,
          waiting,
          fresh,
        ];
        int captures = 0;
        SwapListView view() =>
            tester.widget<SwapListView>(find.byType(SwapListView));
        try {
          await tester.pumpWidget(
            host(
              P2pSwapTabChild(
                onStepperNotificationSeeMorePressed: () {},
                captureBinding: () => sources[captures++].bind(),
              ),
            ),
          );
          await frames(tester);
          final SwapListPresenter owner = view().presenter!;
          expect(owner.snapshot!.rows.single.record.id, originalRow.id);
          expect(captures, 1);

          view().onRefresh();
          await tester.pump();
          expect(waiting.pages, <int>[0]);
          view().onBusyChanged!(true);
          if (closesBeforeRead) view().onBusyChanged!(false);
          expect(captures, 2);
          pending.complete(
            SwapListPage(
              total: 1,
              more: false,
              records: <SwapListRecord>[lateRow],
            ),
          );
          await frames(tester, 4);

          if (!closesBeforeRead) {
            expect(view().presenter, same(owner));
            expect(owner.canOpen(originalRow), isTrue);
            expect(owner.snapshot!.rows.single.record.id, originalRow.id);
            expect(captures, 2);
            view().onBusyChanged!(false);
            await frames(tester, 4);
          }
          expect(captures, 3);
          expect(view().presenter, isNot(same(owner)));
          expect(owner.canOpen(originalRow), isFalse);
          expect(
            view().presenter!.snapshot!.rows.single.record.id,
            freshRow.id,
          );
          expect(fresh.pages, <int>[0]);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view.reset();
        }
      },
    );
  }

  for (final (bool light, bool rtl, double scale, bool reduced)
      in <(bool, bool, double, bool)>[
        (false, false, 1, false),
        (true, true, 1.5, true),
        (false, true, 2, true),
      ]) {
    testWidgets(
      'one complete strip and table fit theme=$light rtl=$rtl scale=$scale',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 780);
        tester.view.devicePixelRatio = 1;
        final SwapListFixture source = SwapListFixture()
          ..add(swapRecord(3, joined: false))
          ..add(swapRecord(2, state: P2pSwapState.completed))
          ..add(swapRecord(1, state: P2pSwapState.reclaimable));
        final SwapListPresenter presenter = SwapListPresenter(source.bind());
        await presenter.load();
        int starts = 0;
        int refreshes = 0;
        await tester.pumpWidget(
          host(
            SwapListView(
              presenter: presenter,
              onRefresh: () => refreshes++,
              onStart: () => starts++,
              onJoin: () {},
              onOpen: (_) {},
              onRecover: () {},
            ),
            light: light,
            rtl: rtl,
            scale: scale,
            disableAnimations: reduced,
          ),
        );
        await frames(tester);
        expect(find.byKey(const Key('p2p_swaps_strip')), findsOneWidget);
        expect(find.byKey(const Key('p2p_swaps_list')), findsOneWidget);
        final Rect list = tester.getRect(
          find.byKey(const Key('p2p_swaps_list')),
        );
        final Rect title = tester.getRect(find.text('Swaps'));
        expect(rtl ? list.right - title.right : title.left - list.left, 16);
        expectMockupSymbol(
          tester,
          within: find.byKey(const Key('p2p_join_swap')),
          symbol: 'link',
          size: 18,
        );
        expectMockupSymbol(
          tester,
          within: find.byKey(const Key('p2p_start_swap')),
          symbol: 'plus',
          size: 18,
        );
        expect(find.byKey(const Key('swap_refresh')), findsNothing);
        await tester.tap(find.byKey(const Key('p2p_swaps_menu')));
        await frames(tester, 12);
        await tester.tap(find.byKey(const Key('swap_refresh')));
        await frames(tester, 12);
        expect(refreshes, 1);
        expect(find.byType(P2pSwapsListItem), findsNWidgets(3));
        expect(
          find.text('Waiting for the counterparty. Keep Syrius open.'),
          findsOneWidget,
        );
        expect(find.textContaining('deposit comes back'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('p2p_start_swap')));
        await tester.pump();
        expect(starts, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        presenter.dispose();
        tester.view.reset();
      },
    );
  }

  testWidgets(
    'keyboard disclosure opens '
    'and closing removes semantic actions immediately',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 780);
      tester.view.devicePixelRatio = 1;
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        final SwapListRecord record = swapRecord(
          1,
          state: P2pSwapState.completed,
        );
        await tester.pumpWidget(
          host(
            Column(
              children: <Widget>[
                P2pSwapsListItem(
                  row: SwapListRow(record: record),
                  onOpen: (_) {},
                  onDelete: (_) {},
                  canAct: true,
                ),
              ],
            ),
          ),
        );
        expect(
          find.byKey(ValueKey<String>('swap_open_${record.id}')),
          findsNothing,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await frames(tester, 10);
        expect(
          find.byKey(ValueKey<String>('swap_open_${record.id}')),
          findsOneWidget,
        );
        expect(find.semantics.byLabel('Open swap'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.semantics.byLabel('Open swap'), findsNothing);
        await frames(tester, 10);
        expect(
          find.byKey(ValueKey<String>('swap_open_${record.id}')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'Copy for them copies the exact own deposit, never the catalogue id',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 780);
      tester.view.devicePixelRatio = 1;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          }
          return null;
        },
      );
      final SwapListRecord record = swapRecord(
        1,
        direction: P2pSwapDirection.incoming,
      );
      await tester.pumpWidget(
        host(
          Column(
            children: <Widget>[
              P2pSwapsListItem(
                row: SwapListRow(record: record),
                onOpen: (_) {},
                onDelete: (_) {},
                canAct: true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey<String>('swap_${record.id}_row')));
      await frames(tester, 10);
      await tester.tap(find.byKey(ValueKey<String>('swap_copy_${record.id}')));
      await tester.pump();
      expect(copied, record.counterpartyDepositId);
      expect(copied, isNot(record.id));
      await tester.pumpWidget(const SizedBox.shrink());
      // Clipboard feedback owns a finite five-second toast clock.
      await tester.pump(const Duration(seconds: 6));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      tester.view.reset();
    },
  );

  testWidgets(
    'a replaced owner immediately removes data and refuses both modal entries',
    (WidgetTester tester) async {
      final SwapListFixture source = SwapListFixture()..add(swapRecord(1));
      final SwapListPresenter presenter = SwapListPresenter(source.bind());
      await presenter.load();
      int actions = 0;
      Widget view() => host(
        SwapListView(
          presenter: presenter,
          onRefresh: () {},
          onStart: () => actions++,
          onJoin: () => actions++,
          onOpen: (_) => actions++,
        ),
      );
      await tester.pumpWidget(view());
      await frames(tester);
      source.revision++;
      await tester.pumpWidget(view());
      await tester.tap(
        find.byKey(const Key('p2p_start_swap')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const Key('p2p_join_swap')),
        warnIfMissed: false,
      );
      expect(find.byType(P2pSwapsListItem), findsNothing);
      expect(
        find.text('Wallet or node changed. Refresh swaps.'),
        findsOneWidget,
      );
      expect(actions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      presenter.dispose();
    },
  );

  testWidgets(
    'filtering a complete catalogue preserves the unfiltered strip counts',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 780);
      tester.view.devicePixelRatio = 1;
      final SwapListFixture source = SwapListFixture()
        ..add(swapRecord(1))
        ..add(swapRecord(2, state: P2pSwapState.completed));
      final SwapListPresenter presenter = SwapListPresenter(source.bind());
      await presenter.load();
      await tester.pumpWidget(
        host(
          SwapListView(
            presenter: presenter,
            onRefresh: () {},
            onOpen: (_) {},
            onStart: () {},
            onJoin: () {},
          ),
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const Key('swap_filter')));
      await frames(tester, 12);
      final Finder completed = find.text('Completed').hitTestable();
      expect(completed, findsOneWidget);
      await tester.tap(completed);
      await frames(tester, 12);
      expect(find.byType(P2pSwapsListItem), findsOneWidget);
      expect(presenter.snapshot!.active, 1);
      expect(presenter.snapshot!.completed, 1);
      expect(source.pages, <int>[0]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      presenter.dispose();
      tester.view.reset();
    },
  );

  testWidgets(
    'ordinary public detail text, tooltips and semantics omit unlock material',
    (WidgetTester tester) async {
      const String privateFixture = 'synthetic-unlock-material-never-rendered';
      final SwapListRecord record = swapRecord(1);
      final HtlcSwap original = HtlcSwap(
        id: record.id,
        chainId: record.chainId,
        type: P2pSwapType.native,
        direction: record.direction,
        selfAddress: record.selfAddress,
        counterpartyAddress: record.counterpartyAddress,
        fromAmount: record.fromAmount,
        fromTokenStandard: record.fromStandard,
        fromSymbol: record.fromSymbol,
        fromDecimals: record.fromDecimals,
        fromChain: P2pSwapChain.nom,
        toChain: P2pSwapChain.nom,
        startTime: record.started,
        state: record.state,
        hashLock: record.hashLock,
        hashType: record.hashType,
        initialHtlcId: record.initialDepositId,
        initialHtlcExpirationTime: record.initialExpiration,
        counterHtlcId: record.counterpartyDepositId,
        counterHtlcExpirationTime: record.counterpartyExpiration,
        preimage: privateFixture,
      );
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(Column(children: <Widget>[HtlcSwapDetailsWidget(swap: original)])),
      );
      await tester.tap(find.byKey(const Key('htlc_public_details_row')));
      await frames(tester, 10);
      final String texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text text) => text.data ?? text.textSpan?.toPlainText() ?? '')
          .join(' ');
      final String tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((Tooltip tooltip) => tooltip.message ?? '')
          .join(' ');
      final String tree = tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!
          .toStringDeep();
      expect(texts, isNot(contains(privateFixture)));
      expect(texts.toLowerCase(), isNot(contains('secret')));
      expect(tooltips, isNot(contains(privateFixture)));
      expect(tree, isNot(contains(privateFixture)));
      expect(tooltips, contains(record.initialDepositId));
      expect(tooltips, contains(record.counterpartyDepositId));
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );

  test(
    'public projection ignores stored receiving facts and unlock material',
    () {
      final SwapListRecord record = swapRecord(1);
      final SwapListRecord projected = swapListRecordFromJson(<String, dynamic>{
        'id': record.id,
        'chainId': 321,
        'type': 'native',
        'mode': 'htlc',
        'direction': 'outgoing',
        'selfAddress': record.selfAddress,
        'counterpartyAddress': record.counterpartyAddress,
        'fromAmount': record.fromAmount.toString(),
        'fromTokenStandard': znnTokenStandard,
        'fromSymbol': 'ZNN',
        'fromDecimals': 8,
        'fromChain': 'nom',
        'toChain': 'nom',
        'startTime': record.started,
        'state': 'active',
        'hashLock': record.hashLock,
        'hashType': htlcHashTypeSha3,
        'initialHtlcId': record.initialDepositId,
        'initialHtlcExpirationTime': record.initialExpiration,
        'counterHtlcId': record.counterpartyDepositId,
        'counterHtlcExpirationTime': record.counterpartyExpiration,
        'toAmount': '999999999999999999',
        'toSymbol': 'unproven',
        'preimage': 'synthetic-unlock-material-never-projected',
      });
      final SwapListRow row = SwapListRow(record: projected);
      expect(row.receiving, isNull);
      expect(row.rate, isNull);
      expect(projected.initialDepositId, record.initialDepositId);
      expect(projected.counterpartyDepositId, record.counterpartyDepositId);
    },
  );
}
