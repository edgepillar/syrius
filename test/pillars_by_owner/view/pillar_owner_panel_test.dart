import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/widgets/amount_text.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillars_by_owner/model/pillar_owner_snapshot.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/pillars_by_owner/view/pillar_owner_panel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/skeleton.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';

import '../../helpers/mockup_symbol.dart';

final DateTime _time = DateTime.utc(2030);

PillarOwnerSnapshot _snapshot({
  Object? authority,
  BigInt? lockedZnn,
  PillarOwnerFact<BigInt>? deposit,
  PillarOwnerFact<BigInt>? cost,
  int producedMomentums = 1760,
  int expectedMomentums = 1762,
  bool revocable = true,
  bool boundaryAvailable = true,
  DateTime? boundary,
}) => (
  authority: authority ?? Object(),
  ownerAddress: 'z1owner00000000000000000000000000000000',
  name: 'dev1',
  producerAddress: 'z1producer00000000000000000000000000000',
  rewardAddress: 'z1reward0000000000000000000000000000000',
  weight: BigInt.from(9920) * BigInt.from(100000000),
  lockedZnn: lockedZnn,
  depositedQsr: deposit ?? PillarOwnerFact<BigInt>.available(BigInt.zero),
  registrationCostQsr:
      cost ??
      PillarOwnerFact<BigInt>.available(
        BigInt.from(150000) * BigInt.from(100000000),
      ),
  momentumRewardPercent: 0,
  delegateRewardPercent: 100,
  producedMomentums: producedMomentums,
  expectedMomentums: expectedMomentums,
  isRevocable: revocable,
  revocationBoundaryUtc: boundaryAvailable
      ? boundary ?? _time.add(const Duration(hours: 1))
      : null,
);

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final Uint8List bytes = utf8.encode(
      jsonEncode(<String, Object>{
        'v': '5.7.4',
        'fr': 60,
        'ip': 0,
        'op': 120,
        'w': 64,
        'h': 64,
        'nm': 'Owner object fixture',
        'ddd': 0,
        'assets': <Object>[],
        'layers': <Object>[],
      }),
    );
    return ByteData.sublistView(bytes);
  }
}

class _Host extends StatefulWidget {
  const _Host({
    required this.snapshot,
    required this.onAction,
    this.confirm,
    this.light = false,
    this.rtl = false,
    super.key,
  });

  final PillarOwnerSnapshot snapshot;
  final Future<void> Function(PillarOwnerAction, PillarOwnerSnapshot) onAction;
  final PillarOwnerConfirmation? confirm;
  final bool light;
  final bool rtl;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  final _Bundle bundle = _Bundle();
  late PillarOwnerSnapshot snapshot = widget.snapshot;
  Set<PillarOwnerAction> enabled = Set<PillarOwnerAction>.of(
    PillarOwnerAction.values,
  );
  bool busy = false;
  bool current = true;
  bool visible = true;
  bool shown = true;
  int closed = 0;
  int refreshed = 0;
  DateTime now = _time;

  void change(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    theme: widget.light ? AppTheme.lightTheme : AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: const <Locale>[Locale('en')],
    locale: const Locale('en'),
    home: Scaffold(
      body: Directionality(
        textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: DefaultAssetBundle(
          bundle: bundle,
          child: Align(
            alignment: Alignment.topCenter,
            child: shown
                ? TickerMode(
                    enabled: visible,
                    child: SizedBox(
                      width: 1180,
                      child: PillarOwnerPanel(
                        snapshot: snapshot,
                        busy: busy,
                        enabledActions: enabled,
                        stillCurrent: (PillarOwnerSnapshot read) =>
                            current &&
                            identical(read.authority, snapshot.authority),
                        onAction: widget.onAction,
                        onClose: () => closed++,
                        onRefresh: () => refreshed++,
                        confirmForTesting: widget.confirm,
                        nowForTesting: () => now,
                      ),
                    ),
                  )
                : const Text('Panel closed'),
          ),
        ),
      ),
    ),
  );
}

Future<_HostState> _mount(
  WidgetTester tester, {
  PillarOwnerSnapshot? snapshot,
  PillarOwnerConfirmation? confirm,
  Future<void> Function(PillarOwnerAction, PillarOwnerSnapshot)? onAction,
  bool light = false,
  bool rtl = false,
}) async {
  final GlobalKey<_HostState> key = GlobalKey<_HostState>();
  tester.view.physicalSize = const Size(1280, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    AppLottie.debugClear();
    BalanceVisibility.debugReset();
  });
  await tester.pumpWidget(
    _Host(
      key: key,
      snapshot: snapshot ?? _snapshot(),
      confirm: confirm,
      onAction:
          onAction ??
          (PillarOwnerAction action, PillarOwnerSnapshot read) async {},
      light: light,
      rtl: rtl,
    ),
  );
  for (int i = 0; i < 200 && find.byType(Lottie).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(find.byType(Lottie), findsOneWidget);
  await tester.pump();
  return key.currentState!;
}

Finder _button(PillarOwnerAction action) =>
    find.byKey(ValueKey<String>('pillar_owner_${action.name}'));

VoidCallback _saved(WidgetTester tester, PillarOwnerAction action) =>
    tester.widget<OutlinedButton>(_button(action)).onPressed!;

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pillar_owner_revoke_accept')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  for (final bool light in <bool>[false, true]) {
    for (final bool rtl in <bool>[false, true]) {
      testWidgets('exact independent facts, light $light, RTL $rtl', (
        WidgetTester tester,
      ) async {
        await _mount(
          tester,
          snapshot: _snapshot(
            deposit: const PillarOwnerFact<BigInt>.unavailable(),
            cost: const PillarOwnerFact<BigInt>.loading(),
          ),
          light: light,
          rtl: rtl,
        );

        expect(find.text('Unavailable'), findsNWidgets(2));
        expect(find.byType(Skeleton), findsOneWidget);
        expect(find.textContaining('15,000'), findsNothing);
        expect(find.textContaining('150,000'), findsNothing);
        expect(find.text('0% block · 100% delegate'), findsOneWidget);
        expect(
          find.text('1,760 of 1,762 · 99.9%', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.byTooltip('z1producer00000000000000000000000000000'),
          findsOneWidget,
        );
        final Rect panel = tester.getRect(
          find.byKey(const Key('pillar_owner_panel')),
        );
        final Rect artwork = tester.getRect(
          find.byKey(const Key('pillar_owner_object')),
        );
        final Rect locked = tester.getRect(find.text('LOCKED'));
        expect(panel.height, lessThan(220));
        expect(artwork.size, const Size.square(132));
        expect(artwork.top - panel.top, closeTo(8, 0.01));
        expect(
          rtl ? panel.right - artwork.right : artwork.left - panel.left,
          closeTo(4, 0.01),
        );
        expect(
          rtl ? panel.right - locked.right : locked.left - panel.left,
          closeTo(156, 0.01),
        );
        final Rect deposited = tester.getRect(find.text('DEPOSITED'));
        final Rect depositValue = tester.getRect(
          find.text('Unavailable').at(1),
        );
        expect(
          rtl
              ? deposited.left - depositValue.right
              : depositValue.left - deposited.right,
          closeTo(20, 0.01),
        );
        expect(
          tester.getRect(find.text('REGISTRATION COST')).top,
          greaterThan(tester.getRect(find.text('WEIGHT')).bottom),
        );
        for (final (String first, String second) in <(String, String)>[
          ('LOCKED', 'DEPOSITED'),
          ('PRODUCER', 'REVOCABLE'),
          ('REWARD', 'SHARING'),
          ('MOMENTUMS', 'WEIGHT'),
        ]) {
          final Offset leading = tester.getCenter(find.text(first));
          final Offset trailing = tester.getCenter(find.text(second));
          expect(leading.dy, closeTo(trailing.dy, 0.01));
          expect(
            leading.dx,
            rtl ? greaterThan(trailing.dx) : lessThan(trailing.dx),
          );
        }
        for (final (PillarOwnerAction action, String symbol)
            in <(PillarOwnerAction, String)>[
          (PillarOwnerAction.update, 'edit'),
          (PillarOwnerAction.depositQsr, 'down'),
          (PillarOwnerAction.withdrawQsr, 'up'),
          (PillarOwnerAction.revokeConfirmed, 'trash'),
        ]) {
          final Finder button = _button(action);
          final OutlinedButton control = tester.widget<OutlinedButton>(button);
          final ButtonStyle style = control.style!;
          expect(style.minimumSize!.resolve(<WidgetState>{})!.height, 30);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(30));
          expectMockupSymbol(tester, within: button, symbol: symbol, size: 14);
        }
        final Finder copies = find.byTooltip('Copy');
        expect(copies, findsNWidgets(2));
        final AppTokens tokens = AppTokens.of(tester.element(copies.first));
        final Finder producer = find.descendant(
          of: find.byTooltip('z1producer00000000000000000000000000000'),
          matching: find.byType(Text),
        );
        final TextStyle addressStyle = tester.widget<Text>(producer).style!;
        expect(addressStyle.fontSize, 13.5);
        expect(addressStyle.color, tokens.dim);
        expect(
          tester
              .widget<Text>(find.text('0% block · 100% delegate'))
              .style!
              .fontSize,
          13.5,
        );
        final Rect address = tester.getRect(producer);
        final Rect copy = tester.getRect(copies.first);
        expect(
          rtl ? address.left - copy.right : copy.left - address.right,
          closeTo(8, 0.01),
        );
        for (int index = 0; index < 2; index++) {
          expectMockupSymbol(
            tester,
            within: copies.at(index),
            symbol: 'copy',
            size: 12,
            color: tokens.dim,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('actual zero and cost are separate exact amounts', (
    WidgetTester tester,
  ) async {
    await _mount(
      tester,
      snapshot: _snapshot(producedMomentums: 0, expectedMomentums: 0),
    );
    expect(find.text('0 of 0', findRichText: true), findsOneWidget);
    final List<AmountText> amounts = tester
        .widgetList<AmountText>(find.byType(AmountText))
        .toList();
    expect(
      amounts.where((AmountText amount) => amount.symbol == 'ZNN'),
      hasLength(1),
    );
    expect(
      amounts.where((AmountText amount) => amount.raw == BigInt.zero),
      hasLength(1),
    );
    expect(find.text('0 QSR', findRichText: true), findsOneWidget);
    expect(find.text('150,000 QSR', findRichText: true), findsOneWidget);
    expect(find.textContaining('.00000000'), findsNothing);
    tester.view.physicalSize = const Size(720, 780);
    await tester.pump();
    final double locked = tester.getCenter(find.text('LOCKED')).dy;
    final double deposited = tester.getCenter(find.text('DEPOSITED')).dy;
    final double producer = tester.getCenter(find.text('PRODUCER')).dy;
    expect(locked, lessThan(deposited));
    expect(deposited, lessThan(producer));
    expect(find.text('0 QSR', findRichText: true), findsOneWidget);
    expect(find.text('150,000 QSR', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy removes monetary text and semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await _mount(
        tester,
        snapshot: _snapshot(
          lockedZnn: BigInt.from(15000) * BigInt.from(100000000),
        ),
      );
      BalanceVisibility.instance.set(true);
      await tester.pump();
      expect(
        find.text('15,000 ZNN', findRichText: true).hitTestable(),
        findsNothing,
      );
      expect(
        find.semantics.byLabel(RegExp('15,000|150,000|9,920')),
        findsNothing,
      );
      expect(find.text('0% block · 100% delegate'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the original object runs once at 132 and keeps hover replay', (
    WidgetTester tester,
  ) async {
    await _mount(tester);
    final AppLottie object = tester.widget<AppLottie>(find.byType(AppLottie));
    expect(object.asset, AppLottieAsset.pillar);
    expect(object.size, 132);
    expect(object.repeat, isFalse);
    expect(object.controller, isNull);
    final Animation<double> clock = tester
        .widget<Lottie>(find.byType(Lottie))
        .controller!;
    await tester.pump(const Duration(seconds: 2));
    expect(clock.value, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(clock.value, 1);
    final TestGesture mouse = await tester.createGesture(
      kind: ui.PointerDeviceKind.mouse,
    );
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(AppLottie)));
    await tester.pump();
    expect(clock.value, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.value, closeTo(0.25, 0.001));
  });

  for (final bool busy in <bool>[false, true]) {
    testWidgets('disabled entries refuse every activation, busy $busy', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        final List<PillarOwnerAction> admitted = <PillarOwnerAction>[];
        final _HostState host = await _mount(
          tester,
          onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
            admitted.add(action);
          },
        );
        final List<VoidCallback> saved = <VoidCallback>[
          for (final PillarOwnerAction action in PillarOwnerAction.values)
            _saved(tester, action),
        ];
        final FocusNode focus = Focus.of(tester.element(find.text('Update')));
        host.change(() {
          host.busy = busy;
          if (!busy) host.enabled = <PillarOwnerAction>{};
        });
        await tester.pump();
        focus.requestFocus();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        for (final PillarOwnerAction action in PillarOwnerAction.values) {
          final Finder button = _button(action);
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
          await tester.tap(button, warnIfMissed: false);
          final SemanticsNode node = tester.getSemantics(button);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isFalse,
          );
          node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        }
        for (final VoidCallback callback in saved) {
          callback();
        }
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        expect(admitted, isEmpty);
        expect(
          find.byKey(const Key('pillar_owner_revoke_first_dialog')),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final String boundary in <String>[
    'new authority',
    'hidden view',
    'stale context',
    'disposed panel',
    'another route',
  ]) {
    testWidgets('a saved entry refuses after $boundary', (
      WidgetTester tester,
    ) async {
      int admitted = 0;
      final _HostState host = await _mount(
        tester,
        onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
          admitted++;
        },
      );
      final VoidCallback saved = _saved(tester, PillarOwnerAction.update);
      switch (boundary) {
        case 'new authority':
          host.change(() => host.snapshot = _snapshot());
        case 'hidden view':
          host.change(() => host.visible = false);
        case 'stale context':
          host.change(() => host.current = false);
        case 'disposed panel':
          host.change(() => host.shown = false);
        case 'another route':
          host.navigator.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const Scaffold(
                body: Text('Another page'),
              ),
            ),
          );
      }
      await tester.pump();
      saved();
      await tester.pump();
      expect(admitted, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two actual routes admit the captured owner once', (
    WidgetTester tester,
  ) async {
    final List<PillarOwnerAction> admittedActions = <PillarOwnerAction>[];
    final List<PillarOwnerSnapshot> admitted = <PillarOwnerSnapshot>[];
    final Completer<void> pending = Completer<void>();
    final PillarOwnerSnapshot snapshot = _snapshot();
    await _mount(
      tester,
      snapshot: snapshot,
      onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) {
        admittedActions.add(action);
        admitted.add(read);
        return pending.future;
      },
    );
    final VoidCallback original = _saved(
      tester,
      PillarOwnerAction.revokeConfirmed,
    );
    original();
    original();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Disassemble dev1?'), findsOneWidget);
    expect(admitted, isEmpty);
    await _accept(tester);
    expect(find.text('This removes dev1 as a pillar.'), findsOneWidget);
    expect(admitted, isEmpty);
    final VoidCallback finalAnswer = tester
        .widget<OutlinedButton>(
          find.byKey(const Key('pillar_owner_revoke_accept')),
        )
        .onPressed!;
    finalAnswer();
    finalAnswer();
    original();
    await tester.pump();
    expect(admittedActions, <PillarOwnerAction>[
      PillarOwnerAction.revokeConfirmed,
    ]);
    expect(admitted, <PillarOwnerSnapshot>[snapshot]);
    expect(
      tester
          .widget<OutlinedButton>(_button(PillarOwnerAction.update))
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  });

  for (final bool cancelFinal in <bool>[false, true]) {
    testWidgets('cancel question ${cancelFinal ? 2 : 1} admits nothing', (
      WidgetTester tester,
    ) async {
      int admitted = 0;
      await _mount(
        tester,
        onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
          admitted++;
        },
      );
      await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      if (cancelFinal) await _accept(tester);
      await tester.tap(find.byKey(const Key('pillar_owner_revoke_cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(admitted, 0);
      expect(
        find.byKey(const Key('pillar_owner_revoke_final_dialog')),
        findsNothing,
      );
    });
  }

  testWidgets('Escape cancels the owned final question', (
    WidgetTester tester,
  ) async {
    int admitted = 0;
    await _mount(
      tester,
      onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
        admitted++;
      },
    );
    await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await _accept(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(admitted, 0);
    expect(
      find.byKey(const Key('pillar_owner_revoke_final_dialog')),
      findsNothing,
    );
  });

  for (final bool finalQuestion in <bool>[false, true]) {
    testWidgets(
      'context change after question ${finalQuestion ? 2 : 1} refuses',
      (
        WidgetTester tester,
      ) async {
        final Completer<bool?> first = Completer<bool?>();
        final Completer<bool?> second = Completer<bool?>();
        int questions = 0;
        int admitted = 0;
        final _HostState host = await _mount(
          tester,
          confirm:
              ({
                required PillarOwnerSnapshot snapshot,
                required bool finalConfirmation,
              }) {
                questions++;
                return finalConfirmation ? second.future : first.future;
              },
          onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
            admitted++;
          },
        );
        await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
        await tester.pump();
        if (finalQuestion) {
          first.complete(true);
          await tester.pump();
        }
        host.change(() => host.snapshot = _snapshot());
        await tester.pump();
        if (finalQuestion) {
          second.complete(true);
        } else {
          first.complete(true);
        }
        await tester.pump();
        expect(questions, finalQuestion ? 2 : 1);
        expect(admitted, 0);
      },
    );
  }

  for (final String change in <String>[
    'busy',
    'disabled',
    'hidden',
    'disposed',
    'stale',
  ]) {
    testWidgets('the final answer refuses after the owner becomes $change', (
      WidgetTester tester,
    ) async {
      final Completer<bool?> second = Completer<bool?>();
      int admitted = 0;
      final _HostState host = await _mount(
        tester,
        confirm:
            ({
              required PillarOwnerSnapshot snapshot,
              required bool finalConfirmation,
            }) => finalConfirmation ? second.future : Future<bool?>.value(true),
        onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
          admitted++;
        },
      );
      await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
      await tester.pump();
      host.change(() {
        switch (change) {
          case 'busy':
            host.busy = true;
          case 'disabled':
            host.enabled = <PillarOwnerAction>{};
          case 'hidden':
            host.visible = false;
          case 'disposed':
            host.shown = false;
          case 'stale':
            host.current = false;
        }
      });
      await tester.pump();
      second.complete(true);
      await tester.pump();
      expect(admitted, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the clock is reread after the second answer without a tick', (
    WidgetTester tester,
  ) async {
    final Completer<bool?> second = Completer<bool?>();
    int admitted = 0;
    final _HostState host = await _mount(
      tester,
      confirm:
          ({
            required PillarOwnerSnapshot snapshot,
            required bool finalConfirmation,
          }) => finalConfirmation ? second.future : Future<bool?>.value(true),
      onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
        admitted++;
      },
    );
    await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
    await tester.pump();
    host.now = _time.add(const Duration(hours: 2));
    second.complete(true);
    await tester.pump();
    expect(admitted, 0);
  });

  testWidgets(
    'teardown removes only its owned question, preserving another dialog',
    (
      WidgetTester tester,
    ) async {
      int admitted = 0;
      final _HostState host = await _mount(
        tester,
        onAction: (PillarOwnerAction action, PillarOwnerSnapshot read) async {
          admitted++;
        },
      );
      final ModalRoute<dynamic> ownerRoute = ModalRoute.of(
        tester.element(find.byType(PillarOwnerPanel)),
      )!;
      await tester.tap(_button(PillarOwnerAction.revokeConfirmed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final VoidCallback oldAnswer = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('pillar_owner_revoke_accept')),
          )
          .onPressed!;
      final NavigatorState navigator = host.navigator.currentState!
        ..push<void>(
          RawDialogRoute<void>(
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) => const Center(child: Text('Other dialog')),
          ),
        );
      await tester.pump();
      oldAnswer();
      await tester.pump();
      expect(find.text('Other dialog'), findsOneWidget);
      final ModalRoute<dynamic> otherRoute = ModalRoute.of(
        tester.element(find.text('Other dialog')),
      )!;
      await tester.pump(otherRoute.transitionDuration);
      await tester.pump(const Duration(microseconds: 1));
      // Removing the route disposes the owner even while dialogs cover it.
      navigator.removeRoute(ownerRoute);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(microseconds: 1));
      expect(
        find.byType(PillarOwnerPanel, skipOffstage: false),
        findsNothing,
      );
      oldAnswer();
      await tester.pump();
      expect(find.text('Other dialog'), findsOneWidget);
      expect(
        find.byKey(
          const Key('pillar_owner_revoke_first_dialog'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(admitted, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a closed revocation window cannot ask either question', (
    WidgetTester tester,
  ) async {
    await _mount(
      tester,
      snapshot: _snapshot(
        revocable: false,
        boundary: _time.add(const Duration(days: 12, hours: 4, minutes: 20)),
      ),
    );
    final Finder countdown = find.byKey(
      const Key('pillar_owner_revocation_waiting'),
    );
    final ShapeDecoration decoration =
        tester.widget<Container>(countdown).decoration! as ShapeDecoration;
    expect(
      decoration.color,
      AppTokens.dark.qsr.withValues(alpha: 0.14),
    );
    expect(tester.getSize(countdown).height, 26);
    final Finder caption = find.descendant(
      of: countdown,
      matching: find.text('in 12 d 4 h'),
    );
    expect(caption, findsOneWidget);
    final TextStyle captionStyle = tester.widget<Text>(caption).style!;
    expect(captionStyle.fontFamily, AppTokens.dark.sansFontFamily);
    expect(captionStyle.fontSize, 12);
    expect(captionStyle.color, AppTokens.dark.qsrInk);
    expect(
      find.byTooltip('Until revocation window opens (12 d 04:20:00)'),
      findsOneWidget,
    );
    final OutlinedButton disassemble = tester.widget<OutlinedButton>(
      _button(PillarOwnerAction.revokeConfirmed),
    );
    expect(disassemble.onPressed, isNull);
    const Set<WidgetState> disabled = <WidgetState>{WidgetState.disabled};
    expect(
      disassemble.style!.backgroundColor!.resolve(disabled),
      Colors.transparent,
    );
    expect(disassemble.style!.side!.resolve(disabled), BorderSide.none);
    await tester.tap(
      _button(PillarOwnerAction.revokeConfirmed),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      find.byKey(const Key('pillar_owner_revoke_first_dialog')),
      findsNothing,
    );
  });

  testWidgets('an unavailable window cannot ask either question', (
    WidgetTester tester,
  ) async {
    await _mount(tester, snapshot: _snapshot(boundaryAvailable: false));
    expect(
      tester
          .widget<OutlinedButton>(
            _button(PillarOwnerAction.revokeConfirmed),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Unavailable'), findsNWidgets(2));
  });

  testWidgets('expiry asks for one current-owner refresh', (
    WidgetTester tester,
  ) async {
    final _HostState host = await _mount(tester);
    host.now = _time.add(const Duration(hours: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(host.refreshed, 1);
  });
}
