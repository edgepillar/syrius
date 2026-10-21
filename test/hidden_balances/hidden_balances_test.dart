import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/eye_toggle.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/balance_visibility.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';

const Key _eye = ValueKey<String>('hero_eye');
const Key _amount = Key('amount');
const Key _wrapped = Key('wrapped');

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

/// The frame the eye's controller is on.
double _frame(WidgetTester tester) =>
    tester.widget<AppLottie>(find.byType(AppLottie)).controller!.value *
    EyeToggle.frames;

/// Closes the preferences and opens them again from the file, which is what
/// quitting and starting the wallet does to them.
Future<void> _restart() async {
  await sharedPrefsService!.close();
  await sharedPrefsService!.checkIfBoxIsOpen();
}

void main() {
  group('the stored choice', () {
    late Directory dir;

    // Whatever a test opens lands in a folder of its own, never in the
    // wallet's.
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('syrius_hidden_');
      Hive.init(dir.path);
      sharedPrefsService = await SharedPrefsService.getInstance();
      BalanceVisibility.debugReset();
    });

    tearDown(() async {
      await Hive.close();
      sharedPrefsService = null;
      dir.deleteSync(recursive: true);
    });

    test('a profile that has never chosen sees its balances', () {
      expect(BalanceVisibility().hidden, isFalse);
      // Reading is not choosing.
      expect(sharedPrefsService!.get(kBalancesHiddenKey), isNull);
    });

    test('hiding is stored and read back after a restart', () async {
      BalanceVisibility().toggle();
      await _restart();
      expect(sharedPrefsService!.get(kBalancesHiddenKey), isTrue);
      expect(BalanceVisibility().hidden, isTrue);

      BalanceVisibility().set(false);
      await _restart();
      expect(sharedPrefsService!.get(kBalancesHiddenKey), isFalse);
      expect(BalanceVisibility().hidden, isFalse);
    });

    test('set tells its listeners once, and not for the same state', () {
      final BalanceVisibility visibility = BalanceVisibility();
      int told = 0;
      visibility
        ..addListener(() => told += 1)
        ..set(true)
        ..set(true);
      expect(visibility.hidden, isTrue);
      expect(told, 1);
    });

    test('a damaged entry reads as never chosen', () async {
      await sharedPrefsService!.put(kBalancesHiddenKey, 'yes');
      expect(BalanceVisibility().hidden, isFalse);
    });

    test('the wallet has one, made when first asked for', () async {
      await sharedPrefsService!.put(kBalancesHiddenKey, true);
      final BalanceVisibility first = BalanceVisibility.instance;
      expect(first.hidden, isTrue);
      expect(BalanceVisibility.instance, same(first));
    });

    test('a closed box leaves it working in memory', () async {
      final BalanceVisibility visibility = BalanceVisibility();
      await Hive.close();
      visibility.toggle();
      await pumpEventQueue();
      expect(visibility.hidden, isTrue);
      expect(BalanceVisibility().hidden, isFalse);
    });
  });

  group('with no box', () {
    setUp(() {
      sharedPrefsService = null;
      BalanceVisibility.debugReset();
    });

    test('it starts shown and toggles in memory', () async {
      final BalanceVisibility visibility = BalanceVisibility();
      expect(visibility.hidden, isFalse);
      visibility.toggle();
      await pumpEventQueue();
      expect(visibility.hidden, isTrue);
      visibility.toggle();
      expect(visibility.hidden, isFalse);
    });

    group('HiddenAmount', () {
      testWidgets('swaps the amount for dots, and back', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(
          _host(
            HiddenAmount(
              visibility: visibility,
              child: const Text('1250.5', key: _amount),
            ),
          ),
        );
        expect(find.byKey(_amount).hitTestable(), findsOneWidget);
        expect(find.semantics.byLabel('1250.5'), findsOne);
        expect(find.text(kHiddenAmountDots), findsNothing);

        visibility.toggle();
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsOneWidget);
        // Still there, for its state and its height, but not drawn, not
        // pressed and not read out.
        expect(find.byKey(_amount), findsOneWidget);
        expect(find.byKey(_amount).hitTestable(), findsNothing);
        expect(
          tester
              .widget<Visibility>(
                find.ancestor(
                  of: find.byKey(_amount),
                  matching: find.byType(Visibility),
                ),
              )
              .visible,
          isFalse,
        );
        expect(find.semantics.byLabel('1250.5'), findsNothing);

        visibility.toggle();
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsNothing);
        expect(find.byKey(_amount).hitTestable(), findsOneWidget);
        handle.dispose();
      });

      testWidgets('is as tall hidden as shown, and no wider than its dots', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(
          _host(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                HiddenAmount(
                  key: _wrapped,
                  visibility: visibility,
                  // Larger than the style the dots inherit: the height
                  // must be the amount's, not the dots'.
                  child: const Text(
                    '123456789.12345678',
                    style: TextStyle(fontSize: 34),
                  ),
                ),
              ],
            ),
          ),
        );
        final Size shown = tester.getSize(find.byKey(_wrapped));

        visibility.toggle();
        await tester.pump();
        final Size hidden = tester.getSize(find.byKey(_wrapped));
        expect(hidden.height, shown.height);
        expect(
          hidden.width,
          tester.getSize(find.text(kHiddenAmountDots)).width,
        );
        expect(hidden.width, lessThan(shown.width));

        visibility.toggle();
        await tester.pump();
        expect(tester.getSize(find.byKey(_wrapped)), shown);
      });

      testWidgets('draws its dots in the mono face of the style it is in', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility()..set(true);
        await tester.pumpWidget(
          _host(
            DefaultTextStyle(
              style: const TextStyle(fontSize: 18, color: Color(0xFF123456)),
              child: HiddenAmount(
                visibility: visibility,
                child: const Text('7'),
              ),
            ),
          ),
        );
        final TextStyle style = tester
            .widget<Text>(find.text(kHiddenAmountDots))
            .style!;
        expect(style.fontFamily, kMonoFontFamily);
        expect(style.fontSize, 18);
        expect(style.color, const Color(0xFF123456));
      });

      testWidgets('puts the dots where the alignment says', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility()..set(true);
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 200,
              child: HiddenAmount(
                key: _wrapped,
                visibility: visibility,
                alignment: AlignmentDirectional.centerEnd,
                child: const Text('7'),
              ),
            ),
          ),
        );
        expect(
          tester.getRect(find.text(kHiddenAmountDots)).right,
          tester.getRect(find.byKey(_wrapped)).right,
        );
      });

      testWidgets('follows the wallet own notifier when given none', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_host(const HiddenAmount(child: Text('7'))));
        expect(find.text(kHiddenAmountDots), findsNothing);
        BalanceVisibility.instance.toggle();
        await tester.pump();
        expect(find.text(kHiddenAmountDots), findsOneWidget);
      });
    });

    group('EyeToggle', () {
      Widget eye(BalanceVisibility visibility) => _host(
        EyeToggle(
          keyPrefix: 'hero',
          tooltip: 'Hide balances',
          visibility: visibility,
        ),
      );

      testWidgets('rests closed while balances show, open while hidden', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(eye(BalanceVisibility()));
        expect(_frame(tester), closeTo(EyeToggle.shownFrame, 1e-6));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(eye(BalanceVisibility()..set(true)));
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));
      });

      testWidgets('a tap hides and the next shows, each over half a second', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));

        await tester.tap(find.byKey(_eye));
        expect(visibility.hidden, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        // The opening part, 0 to 30.
        expect(_frame(tester), greaterThan(3));
        expect(_frame(tester), lessThan(EyeToggle.hiddenFrame));
        await tester.pump(const Duration(milliseconds: 260));
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));

        await tester.tap(find.byKey(_eye));
        expect(visibility.hidden, isFalse);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        // The closing part, 200 to 232.
        expect(_frame(tester), greaterThan(200));
        expect(_frame(tester), lessThan(EyeToggle.shownFrame));
        await tester.pump(const Duration(milliseconds: 260));
        expect(_frame(tester), closeTo(EyeToggle.shownFrame, 1e-6));
      });

      testWidgets('Enter toggles it once it has the focus', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(visibility.hidden, isTrue);
        await tester.pumpAndSettle();
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(visibility.hidden, isFalse);
        await tester.pumpAndSettle();
        expect(_frame(tester), closeTo(EyeToggle.shownFrame, 1e-6));
      });

      testWidgets('follows a change made elsewhere', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));
        visibility.set(true);
        await tester.pumpAndSettle();
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));
      });

      testWidgets('blinks once every several seconds, only while hidden', (
        WidgetTester tester,
      ) async {
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));

        // Shown: it never moves.
        await tester.pump(EyeToggle.blinkEvery * 3);
        expect(tester.hasRunningAnimations, isFalse);
        expect(_frame(tester), closeTo(EyeToggle.shownFrame, 1e-6));

        visibility.set(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));
        // Still, until the blink is due.
        await tester.pump(
          EyeToggle.blinkEvery - const Duration(milliseconds: 1000),
        );
        expect(tester.hasRunningAnimations, isFalse);

        // Past the interval: this frame starts the blink, the next ends
        // its first half.
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pump(const Duration(milliseconds: 100));
        // The lid is down.
        expect(_frame(tester), lessThan(5));
        await tester.pumpAndSettle();
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));

        // And still again for the rest of the interval.
        await tester.pump(const Duration(seconds: 5));
        expect(tester.hasRunningAnimations, isFalse);
        expect(_frame(tester), closeTo(EyeToggle.hiddenFrame, 1e-6));

        // Shown again: the blinking stops with it.
        visibility.set(false);
        await tester.pumpAndSettle();
        await tester.pump(EyeToggle.blinkEvery * 2);
        expect(tester.hasRunningAnimations, isFalse);
        expect(_frame(tester), closeTo(EyeToggle.shownFrame, 1e-6));
      });

      testWidgets('is a button that says whether it is on, at its size', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));
        expect(
          tester.getSemantics(find.byKey(_eye)),
          isSemantics(
            isButton: true,
            hasToggledState: true,
            isToggled: false,
            isFocusable: true,
            hasTapAction: true,
          ),
        );
        visibility.set(true);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(_eye)),
          isSemantics(isButton: true, isToggled: true),
        );
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Tooltip && widget.message == 'Hide balances',
          ),
          findsOneWidget,
        );
        // 20 px of eye and the room round it.
        expect(tester.getSize(find.byKey(_eye)), const Size.square(32));
        handle.dispose();
      });

      testWidgets('keeps its durations under reduced motion', (
        WidgetTester tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final BalanceVisibility visibility = BalanceVisibility();
        await tester.pumpWidget(eye(visibility));
        visibility.set(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(_frame(tester), lessThan(EyeToggle.hiddenFrame));
      });
    });
  });
}
