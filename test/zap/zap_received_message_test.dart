import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/zap.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/balances.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modals.dart';

const String _sender = 'fixture-sender-0123456789-0123456789';
const String _message = 'A plain message supplied by the sender.';

Finder _key(String key) => find.byKey(Key(key));

String _labels(SemanticsNode root) {
  final List<String> result = <String>[];
  void visit(SemanticsNode node) {
    result.add(node.getSemanticsData().label);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return result.join('\n');
}

class _Visibility extends BalanceVisibility {
  bool get active => hasListeners;
}

class _Fixture {
  _Fixture({this.light = false});

  final bool light;
  final _Visibility visibility = _Visibility();
  final FocusNode opener = FocusNode(debugLabel: 'Message fixture opener');
  int closes = 0;

  Future<void> show(
    WidgetTester tester, {
    String message = _message,
    BigInt? znn,
    BigInt? qsr,
    Size size = const Size(1280, 780),
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
    bool disableAnimations = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        locale: Locale(direction == TextDirection.rtl ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: disableAnimations,
          ),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => TextButton(
                key: const Key('open_received_message'),
                focusNode: opener,
                onPressed: () => unawaited(
                  showFrostedDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) =>
                        ZapReceivedMessage(
                          sender: _sender,
                          znn: znn ?? BigInt.from(120450000000),
                          qsr: qsr ?? BigInt.from(700000001),
                          message: message,
                          visibility: visibility,
                          onClose: () {
                            closes++;
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                  ),
                ),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    opener.requestFocus();
    await tester.pump();
    await tester.tap(_key('open_received_message'));
    await tester.pump();
    if (settle) {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(visibility.active, isFalse);
    visibility.dispose();
    opener.dispose();
  }
}

void main() {
  setUp(() => app.sharedPrefsService = null);
  tearDown(() => app.sharedPrefsService = null);
  setUpAll(() async {
    for (final (String, List<String>) family in
        const <(String, List<String>)>[
      (kSansFontFamily, <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
      (kMonoFontFamily, <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
      (kArabicFontFamily, <String>['Regular', 'Medium', 'Bold']),
      (kDevanagariFontFamily, <String>['Regular', 'Medium', 'Bold']),
    ]) {
      final FontLoader loader = FontLoader(family.$1);
      for (final String weight in family.$2) {
        loader.addFont(
          rootBundle.load('assets/fonts/${family.$1}-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  for (final bool light in <bool>[false, true]) {
    testWidgets('received card keeps reference chrome, light $light', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _Fixture(light: light);
      try {
        await fixture.show(tester);
        final Rect card = tester.getRect(_key('zap_received_card'));
        final Rect header = tester.getRect(_key('zap_received_header'));
        final AppTokens tokens = AppTokens.of(
          tester.element(_key('zap_received_card')),
        );
        expect(card.width, 460);
        // CSS is 309.3/49.3; logical font line boxes round up separately.
        expect(card.height, inInclusiveRange(309, 313));
        expect(header.height, inInclusiveRange(49, 50));
        expect(card.center, const Offset(640, 390));
        expect(find.text(_sender), findsOneWidget);
        expect(find.text(_message), findsOneWidget);
        expect(find.text('1,204.5', findRichText: true), findsOneWidget);
        expect(find.text('7.00000001', findRichText: true), findsOneWidget);
        expect(find.text(' ZNN'), findsOneWidget);
        expect(find.text(' QSR'), findsOneWidget);
        expect(find.text('Zap back'), findsOneWidget);
        expect(find.text('Nice'), findsOneWidget);
        expect(
          find.text('Written by the sender, not by Syrius.'),
          findsOneWidget,
        );
        expect(tester.getSize(_key('zap_received_nice')).height, 38);
        expect(
          tester.getSize(_key('zap_received_message_area')).height,
          72,
        );
        final Container area = tester.widget<Container>(
          _key('zap_received_message_area'),
        );
        expect((area.decoration! as BoxDecoration).color, tokens.card2);
        expect(area.padding, tokens.zapMessagePadding);
        final Text sender = tester.widget<Text>(_key('zap_received_sender'));
        expect(sender.style!.fontFamily, kMonoFontFamily);
        expect(sender.style!.fontSize, 13.5);
        expect(sender.textDirection, TextDirection.ltr);
        expect(find.byType(FrostedSurface), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });

    testWidgets('received amounts follow shared privacy, light $light', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _Fixture(light: light);
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        await fixture.show(tester);
        expect(
          _labels(tester.getSemantics(_key('zap_received_card'))),
          contains('7.00000001'),
        );
        fixture.visibility.toggle();
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsNWidgets(2));
        final String labels = _labels(
          tester.getSemantics(_key('zap_received_card')),
        );
        expect(labels, isNot(contains('1,204.5')));
        expect(labels, isNot(contains('7.00000001')));
        expect(labels, contains('ZNN'));
        expect(labels, contains('QSR'));
        expect(find.text(' ZNN'), findsOneWidget);
        expect(find.text(' QSR'), findsOneWidget);
        fixture.visibility.toggle();
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsNothing);
        expect(
          _labels(tester.getSemantics(_key('zap_received_card'))),
          contains('7.00000001'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await fixture.close(tester);
      }
    });

    testWidgets('scaled RTL message remains bounded, light $light', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _Fixture(light: light);
      try {
        await fixture.show(
          tester,
          size: const Size(700, 600),
          scale: 2,
          direction: TextDirection.rtl,
        );
        final Rect card = tester.getRect(_key('zap_received_card'));
        expect(card.left, greaterThanOrEqualTo(24));
        expect(card.right, lessThanOrEqualTo(676));
        expect(card.top, greaterThanOrEqualTo(24));
        expect(card.bottom, lessThanOrEqualTo(576));
        expect(find.text('fixture-…456789'), findsOneWidget);
        expect(find.byTooltip(_sender), findsOneWidget);
        expect(
          tester.widget<Text>(_key('zap_received_sender')).textDirection,
          TextDirection.ltr,
        );
        final Finder money = find.descendant(
          of: _key('zap_received_amounts'),
          matching: find.byType(Text),
        );
        for (final Element element in money.evaluate()) {
          expect(Directionality.of(element), TextDirection.ltr);
        }
        expect(
          tester.getSize(_key('zap_received_nice')).height,
          greaterThan(38),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });

    testWidgets('sender content remains inert plain text, light $light', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _Fixture(light: light);
      try {
        await fixture.show(
          tester,
          message: '<b>https://example.invalid</b>\nA\tB\u202e\u0001\u200d',
        );
        final Text message = tester.widget<Text>(_key('zap_received_message'));
        expect(message.data, '<b>https://example.invalid</b> A B');
        expect(message.textSpan, isNull);
        expect(find.byType(SelectableText), findsNothing);
        expect(fixture.closes, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });

    testWidgets('reply stays seamed and both closes work, light $light', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _Fixture(light: light);
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        await fixture.show(tester);
        final SeamGate gate = tester.widget<SeamGate>(find.byType(SeamGate));
        expect(gate.seam, Seam.zapSend);
        expect(
          tester.getSemantics(find.byType(SeamGate)),
          isSemantics(
            label: 'Not yet',
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        await tester.tap(_key('zap_received_reply'), warnIfMissed: false);
        tester.widget<OutlinedButton>(_key('zap_received_reply')).onPressed!();
        await tester.pump();
        expect(fixture.closes, 0);
        expect(_key('zap_received_card'), findsOneWidget);
        await tester.tap(_key('zap_received_nice'));
        // Start the reverse ticker before advancing its elapsed time.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(_key('zap_received_card'), findsNothing);
        expect(fixture.closes, 1);
        await tester.tap(_key('open_received_message'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('Close'), findsOneWidget);
        await tester.tap(_key('zap_received_close'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(_key('zap_received_card'), findsNothing);
        expect(fixture.closes, 2);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await fixture.close(tester);
      }
    });

    testWidgets('received entrance keeps its clock, light $light', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final _Fixture fixture = _Fixture(light: light);
      try {
        await fixture.show(tester, disableAnimations: true, settle: false);
        final Finder fade = find.descendant(
          of: find.byType(RiseIn),
          matching: find.byType(FadeTransition),
        ).first;
        expect(MediaQuery.of(tester.element(fade)).disableAnimations, isTrue);
        expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          tester.widget<FadeTransition>(fade).opacity.value,
          inExclusiveRange(0, 1),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });
  }

  test('invalid presentation facts and oversized UTF-8 are refused', () {
    ZapReceivedMessage make({
      String sender = _sender,
      String message = _message,
      BigInt? znn,
    }) => ZapReceivedMessage(
      sender: sender,
      znn: znn ?? BigInt.one,
      qsr: BigInt.zero,
      message: message,
      onClose: () {},
    );
    expect(() => make(sender: ''), throwsArgumentError);
    expect(() => make(sender: 'hidden\u202esender'), throwsArgumentError);
    expect(() => make(znn: -BigInt.one), throwsArgumentError);
    expect(() => make(message: 'x' * 141), throwsArgumentError);
    expect(() => make(message: '€' * 47), throwsArgumentError);
    expect(() => make(message: '€' * 46), returnsNormally);
  });

  testWidgets('one-unit amounts retain all eight decimals', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    try {
      await fixture.show(tester, znn: BigInt.one, qsr: BigInt.one);
      expect(find.text('0.00000001', findRichText: true), findsNWidgets(2));
      expect(find.text(' ZNN'), findsOneWidget);
      expect(find.text(' QSR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('dialog focus is closed and Escape restores its opener', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    try {
      await fixture.show(tester);
      for (int i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(fixture.opener.hasFocus, isFalse);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(_key('zap_received_card'), findsNothing);
      expect(fixture.opener.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('empty supplied text and zero amounts are never invented', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    try {
      await fixture.show(
        tester,
        message: '',
        znn: BigInt.zero,
        qsr: BigInt.zero,
      );
      expect(tester.widget<Text>(_key('zap_received_message')).data, '');
      expect(find.text('0', findRichText: true), findsNWidgets(2));
      expect(
        find.text('You got zapped. Have a great day, alien.'),
        findsNothing,
      );
      expect(fixture.closes, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.close(tester);
    }
  });
}
