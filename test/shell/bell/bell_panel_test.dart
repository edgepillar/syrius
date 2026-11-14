import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/event_toast.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/bell_panel.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/window_frame.dart';

import '../../helpers/mockup_symbol.dart';
import 'support.dart';

class _WindowVariant extends TargetPlatformVariant {
  const _WindowVariant(super.values);

  @override
  String describeValue(TargetPlatform value) => '';
}

const TargetPlatformVariant _windows = _WindowVariant(
  <TargetPlatform>{TargetPlatform.windows},
);

List<MethodCall> _prepareFrame(WidgetTester tester) {
  const MethodChannel channel = MethodChannel('window_manager');
  final List<MethodCall> calls = <MethodCall>[];
  tester.view
    ..physicalSize = const Size(1280, 780)
    ..devicePixelRatio = 1;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        if (call.method == 'isMaximized' || call.method == 'isFullScreen') {
          return false;
        }
        return null;
      });
  addTearDown(() {
    tester.view.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return calls;
}

Widget _app(
  BellController controller, {
  bool dark = true,
  bool rtl = false,
  bool framed = false,
  FocusNode? field,
  GlobalKey<NavigatorState>? navigator,
}) => MaterialApp(
  navigatorKey: navigator,
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: framed
      ? (_, Widget? child) => AppWindowFrame(child: child!)
      : null,
  home: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      body: Builder(
        builder: (BuildContext context) => Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                TextField(focusNode: field, key: const Key('underlying_field')),
                TextButton(
                  key: const Key('open_bell'),
                  onPressed: () => unawaited(
                    showBellPanel(context: context, controller: controller),
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: BellToast(controller: controller),
            ),
          ],
        ),
      ),
    ),
  ),
);

void _bellTest(
  String description,
  Future<void> Function(
    WidgetTester tester,
    MemoryBellHistory history,
    BellController controller,
  )
  body, {
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  testWidgets(description, (WidgetTester tester) async {
    // Futures created by widget frames must finish before fake time stops.
    final MemoryBellHistory history = MemoryBellHistory();
    final BellController controller = bell(history)..setPrivate(value: false);
    try {
      await body(tester, history, controller);
    } finally {
      await _closeBell(tester, controller, history);
    }
  }, variant: variant);
}

Future<void> _closeBell(
  WidgetTester tester,
  BellController controller,
  MemoryBellHistory history,
) async {
  try {
    await tester.pumpWidget(const SizedBox.shrink());
  } finally {
    try {
      await _finishOwnedFuture(tester, controller.close());
    } finally {
      await history.close();
    }
  }
}

Future<void> _finishOwnedFuture(
  WidgetTester tester,
  Future<void> operation,
) async {
  bool finished = false;
  final Future<void> observed = operation.whenComplete(() => finished = true);
  // Subscription cancellation may finish on the real event loop. Start the
  // operation in fake time, then let both queues progress before awaiting it.
  for (int turn = 0; turn < 20 && !finished; turn++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  expect(finished, isTrue, reason: 'Owned asynchronous cleanup must finish');
  await observed;
}

void main() {
  for (final bool dark in <bool>[true, false]) {
    _bellTest(
      'a 380 px frosted panel opens over $dark theme and clears unseen',
      (
        WidgetTester tester,
        MemoryBellHistory history,
        BellController controller,
      ) async {
        history.put(1, event(timestamp: DateTime.now().millisecondsSinceEpoch));
        expect(controller.hasUnseen.value, isTrue);
        await tester.pumpWidget(_app(controller, dark: dark));
        expect(find.byType(EventToast), findsNothing);
        await tester.tap(find.byKey(const Key('open_bell')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('bell_panel')), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('bell_panel'))).width, 380);
        expect(find.text('Stored event'), findsOneWidget);
        expect(find.byType(FrostedSurface), findsOneWidget);
        expect(controller.hasUnseen.value, isFalse);
        await tester.tap(find.byKey(const Key('bell_close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bell_panel')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  _bellTest('full 240 ms motion remains under the OS animation flag', (
    WidgetTester tester,
    MemoryBellHistory history,
    BellController controller,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const Key('open_bell')));
    await tester.pump();
    final BuildContext panel = tester.element(
      find.byKey(const Key('bell_panel')),
    );
    final ModalRoute<dynamic> route = ModalRoute.of(panel)!;
    expect(route.transitionDuration, const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 120));
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.value, lessThan(1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(route.animation!.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _bellTest('RTL panel uses the reading end and Escape restores focus', (
    WidgetTester tester,
    MemoryBellHistory history,
    BellController controller,
  ) async {
    final FocusNode field = FocusNode();
    await tester.pumpWidget(_app(controller, rtl: true, field: field));
    field.requestFocus();
    await tester.pump();
    // A shell shortcut opens the panel without moving focus to its opener.
    final BuildContext context = tester.element(
      find.byKey(const Key('open_bell')),
    );
    final Future<void> closed = showBellPanel(
      context: context,
      controller: controller,
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('bell_panel'))).dx, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _finishOwnedFuture(tester, closed);
    expect(find.byKey(const Key('bell_panel')), findsNothing);
    expect(field.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    field.dispose();
  });

  _bellTest('privacy removes this panel while preserving a newer route', (
    WidgetTester tester,
    MemoryBellHistory history,
    BellController controller,
  ) async {
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(controller, navigator: navigator));
    await tester.tap(find.byKey(const Key('open_bell')));
    await tester.pumpAndSettle();
    navigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Unrelated route')),
      ),
    );
    await tester.pumpAndSettle();
    controller.setPrivate(value: true);
    await tester.pumpAndSettle();
    expect(find.text('Unrelated route'), findsOneWidget);
    expect(
      find.byKey(const Key('bell_panel'), skipOffstage: false),
      findsNothing,
    );
    expect(FrostHold.count.value, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _bellTest(
    'new events use the five-second toast without replay or seen marks',
    (
      WidgetTester tester,
      MemoryBellHistory history,
      BellController controller,
    ) async {
      history.items[0] = event(title: 'Old');
      controller.refresh();
      await tester.pumpWidget(_app(controller));
      expect(find.byType(EventToast), findsNothing);
      history.put(1, event(title: 'Fresh'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Fresh'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(EventToast), findsNothing);
      expect(controller.hasUnseen.value, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('real pending scope leads history and Clear never decides', (
    WidgetTester tester,
  ) async {
    final FakeApprovalClient client = FakeApprovalClient()..add(1);
    final MemoryBellHistory history = MemoryBellHistory();
    final BellController controller = bell(
      history,
      approvals: client.controller,
    )..setPrivate(value: false);
    try {
      history.put(1, event());
      await tester.pumpWidget(_app(controller));
      await tester.tap(find.byKey(const Key('open_bell')));
      await tester.pumpAndSettle();
      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(find.text('app.example'), findsOneWidget);
      expect(find.text('zenon:1:address-a'), findsOneWidget);
      expect(find.text('zenon:1:address-b'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byKey(const Key('bell_clear')));
      await tester.pump();
      expect(client.approveCalls + client.declineCalls, 0);
      expect(client.controller.value, hasLength(1));
      expect(history.items, isEmpty);
    } finally {
      try {
        await _closeBell(tester, controller, history);
      } finally {
        client.controller.dispose();
      }
    }
  });

  testWidgets('widget teardown awaits seen writes and owned stream closure', (
    WidgetTester tester,
  ) async {
    final MemoryBellHistory history = MemoryBellHistory();
    final Completer<void> writing = Completer<void>();
    final Completer<void> finishWrite = Completer<void>();
    final List<List<String>> persisted = <List<String>>[];
    final BellController controller = BellController(
      history: history,
      scope: testScope,
      readSeen: (String scope) => <String>[],
      writeSeen: (String scope, List<String> identities) async {
        if (!writing.isCompleted) writing.complete();
        await finishWrite.future;
        persisted.add(identities);
      },
    )..setPrivate(value: false);
    final Future<void> toastsClosed = controller.toasts.drain<void>();
    final Future<void> statesClosed = controller.stream.drain<void>();
    try {
      history.put(1, event());
      await tester.pumpWidget(_app(controller));
      await tester.tap(find.byKey(const Key('open_bell')));
      await tester.pumpAndSettle();
      expect(writing.isCompleted, isTrue);
      expect(controller.hasUnseen.value, isFalse);
      final Set<String> acknowledged = controller.state.identities;
      await tester.pumpWidget(const SizedBox.shrink());
      bool closed = false;
      final Future<void> firstClose = controller.close().then<void>((_) {
        closed = true;
      });
      final Future<void> secondClose = controller.close();
      await tester.pump();
      expect(controller.state.private, isTrue);
      expect(closed, isFalse);
      expect(persisted, isEmpty);
      finishWrite.complete();
      await _finishOwnedFuture(tester, firstClose);
      await secondClose;
      await toastsClosed;
      await statesClosed;
      expect(closed, isTrue);
      expect(controller.isClosed, isTrue);
      expect(persisted, hasLength(1));
      expect(persisted.single, unorderedEquals(acknowledged));
      await controller.close();
    } finally {
      if (!finishWrite.isCompleted) finishWrite.complete();
      await _closeBell(tester, controller, history);
      await toastsClosed;
      await statesClosed;
    }
  });

  for (final bool dark in <bool>[false, true]) {
    for (final bool rtl in <bool>[false, true]) {
      _bellTest(
        'the native client panel starts at zero, dark=$dark rtl=$rtl',
        (
          WidgetTester tester,
          MemoryBellHistory history,
          BellController controller,
        ) async {
          final List<MethodCall> calls = _prepareFrame(tester);
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.binding.platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
          final FocusNode field = FocusNode();
          addTearDown(field.dispose);
          final GlobalKey<NavigatorState> navigator =
              GlobalKey<NavigatorState>();
          await tester.pumpWidget(_app(
            controller, dark: dark, rtl: rtl, framed: true,
            field: field, navigator: navigator,
          ));
          field.requestFocus();
          await tester.pump();
          final Rect body = tester.getRect(
            find.byKey(const ValueKey<String>('window-body')),
          );
          final EditableTextState original = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          expect(body.top, 32);
          expect(body.size, const Size(1280, 748));
          final Future<void> closed = showBellPanel(
            context: tester.element(find.byKey(const Key('open_bell'))),
            controller: controller,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          final Finder panel = find.byKey(const Key('bell_panel'));
          final ModalRoute<dynamic> route =
              ModalRoute.of(tester.element(panel))!;
          expect(route.settings.name, 'bell-panel');
          expect(route.animation!.value, inExclusiveRange(0, 1));
          expect(Navigator.of(tester.element(panel)),
            same(navigator.currentState));
          await tester.pump(const Duration(milliseconds: 120));
          expect(route.animation!.value, 1);
          final Rect rect = tester.getRect(panel);
          expect(rect.top, 0);
          expect(rect.bottom, 780);
          expect(rect.width, 380);
          expect(rtl ? rect.left : rect.right, rtl ? 0 : 1280);
          expect(MediaQuery.sizeOf(tester.element(panel)),
            const Size(1280, 780));
          expect(tester.getRect(
            find.byKey(const ValueKey<String>('window-body'))), body);
          final Rect close = tester.getRect(
            find.byKey(const Key('bell_close')),
          );
          expect(close.size, const Size(32, 32));
          expect(
            tester.getSize(find.byKey(const Key('bell_header'))).height,
            48,
          );
          expect(
            tester.getSize(find.byKey(const Key('bell_clear'))).height,
            32,
          );
          expectMockupSymbol(
            tester,
            within: find.byKey(const Key('bell_close')),
            symbol: 'x',
            size: 14,
            color: AppTokens.of(tester.element(panel)).faint,
          );
          final Offset captionPoint = Offset(close.center.dx, close.top + 4);
          expect(captionPoint.dy, lessThan(32));
          expect(close.contains(captionPoint), isTrue);
          await tester.tapAt(captionPoint);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          expect(route.animation!.status, AnimationStatus.reverse);
          expect(route.animation!.value, inExclusiveRange(0, 1));
          expect(panel, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 120));
          await _finishOwnedFuture(tester, closed);
          expect(find.byKey(const Key('bell_panel')), findsNothing);
          expect(calls.where((MethodCall call) => call.method == 'close'),
            isEmpty);
          expect(tester.state<EditableTextState>(find.byType(EditableText)),
            same(original));
          expect(field.hasFocus, isTrue);
          expect(FrostHold.count.value, 0);
          expect(tester.takeException(), isNull);
        },
        variant: _windows,
      );
    }
  }

  _bellTest(
    'a newer dialog stays interactive and restores the original panel',
    (
      WidgetTester tester,
      MemoryBellHistory history,
      BellController controller,
    ) async {
      _prepareFrame(tester);
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(
        controller, navigator: navigator, framed: true,
      ));
      final Future<void> closed = showBellPanel(
        context: tester.element(find.byKey(const Key('open_bell'))),
        controller: controller,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      final Element original = tester.element(
        find.byKey(const Key('bell_panel')),
      );
      int taps = 0;
      final Future<void> newer = navigator.currentState!.push<void>(
        FrostedDialogRoute<void>(
          barrierLabel: 'Close',
          pageBuilder: (_, _, _) => Align(
            alignment: Alignment.topRight,
            child: Material(
              child: TextButton(
                key: const Key('newer_route_action'),
                onPressed: () => taps++,
                child: const Text('Newer route'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bell_panel')), findsNothing);
      expect(tester.element(find.byKey(
        const Key('bell_panel'), skipOffstage: false)), same(original));
      await tester.tap(find.byKey(const Key('newer_route_action')));
      await tester.pump();
      expect(taps, 1);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _finishOwnedFuture(tester, newer);
      expect(tester.element(find.byKey(const Key('bell_panel'))),
        same(original));
      controller.setPrivate(value: true);
      await tester.pump();
      await _finishOwnedFuture(tester, closed);
      expect(find.byKey(const Key('bell_panel'), skipOffstage: false),
        findsNothing);
      expect(FrostHold.count.value, 0);
      expect(tester.takeException(), isNull);
    },
    variant: _windows,
  );
}
