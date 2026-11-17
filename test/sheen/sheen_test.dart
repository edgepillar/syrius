import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/widgets/send_button.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/buttons.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

Finder get _paint => find.descendant(
  of: find.byType(Sheen),
  matching: find.byWidgetPredicate(
    (Widget w) => w is CustomPaint && w.foregroundPainter != null,
  ),
);

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump();
  return mouse;
}

void main() {
  group('Sheen', () {
    testWidgets('paints nothing at rest', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          Sheen(
            child: OutlinedButton(onPressed: () {}, child: const Text('go')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_paint, isNot(paints..clipRRect()));
    });

    testWidgets('hover runs one 600 ms pass and leaves no band', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Sheen(
            child: OutlinedButton(onPressed: () {}, child: const Text('go')),
          ),
        ),
      );
      await _hover(tester, find.byType(OutlinedButton));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, paints..clipRRect()..rect());
      await tester.pump(const Duration(milliseconds: 290));
      expect(_paint, paints..clipRRect()..rect());

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(_paint, isNot(paints..clipRRect()));
      // The button's own hover fade may still be running; the sheen is not.
      await tester.pumpAndSettle();
      expect(_paint, isNot(paints..clipRRect()));
    });

    testWidgets('the pass keeps its length when the OS asks for less motion', (
      WidgetTester tester,
    ) async {
      final SheenController controller = SheenController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Sheen(
            controller: controller,
            child: OutlinedButton(onPressed: () {}, child: const Text('go')),
          ),
          reduceMotion: true,
        ),
      );
      controller.pass();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_paint, paints..clipRRect()..rect());
    });

    testWidgets('a disabled child gets no pass', (WidgetTester tester) async {
      final SheenController controller = SheenController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Sheen(
            enabled: false,
            controller: controller,
            child: const OutlinedButton(onPressed: null, child: Text('go')),
          ),
        ),
      );
      await _hover(tester, find.byType(OutlinedButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, isNot(paints..clipRRect()));

      controller.pass();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, isNot(paints..clipRRect()));
    });

    testWidgets('pass() runs one', (WidgetTester tester) async {
      final SheenController controller = SheenController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Sheen(
            controller: controller,
            child: OutlinedButton(onPressed: () {}, child: const Text('go')),
          ),
        ),
      );
      // The app shell's own first frames, so the count below is the sheen's.
      await tester.pumpAndSettle();
      controller.pass();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, paints..clipRRect()..rect());

      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, isNot(paints..clipRRect()));
      // A controller reports done on the first tick past its duration.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('clips to a stadium, or to the radius it is given', (
      WidgetTester tester,
    ) async {
      final SheenController controller = SheenController();
      addTearDown(controller.dispose);
      Widget host(BorderRadius? radius) => _app(
        Sheen(
          controller: controller,
          borderRadius: radius,
          child: const SizedBox(width: 120, height: 40),
        ),
      );

      await tester.pumpWidget(host(null));
      controller.pass();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _paint,
        paints..clipRRect(
          rrect: RRect.fromLTRBR(0, 0, 120, 40, const Radius.circular(20)),
        ),
      );

      await tester.pumpWidget(host(BorderRadius.circular(16)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _paint,
        paints..clipRRect(
          rrect: RRect.fromLTRBR(0, 0, 120, 40, const Radius.circular(16)),
        ),
      );
    });

    testWidgets('does not change the child size or swallow its tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      Widget button() => OutlinedButton(
        key: const Key('b'),
        onPressed: () => taps++,
        child: const Text('go'),
      );

      await tester.pumpWidget(_app(button()));
      final Size bare = tester.getSize(find.byKey(const Key('b')));

      await tester.pumpWidget(_app(Sheen(child: button())));
      expect(tester.getSize(find.byKey(const Key('b'))), bare);
      expect(tester.getSize(find.byType(Sheen)), bare);

      await tester.tap(find.byKey(const Key('b')));
      expect(taps, 1);
    });
  });

  group('PrimaryPill', () {
    testWidgets('is the themed pill, sheen on only when it can be pressed', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _app(PrimaryPill(onPressed: () => taps++, child: const Text('go'))),
      );
      expect(tester.widget<Sheen>(find.byType(Sheen)).enabled, isTrue);
      await tester.tap(find.byType(PrimaryPill));
      expect(taps, 1);

      await tester.pumpWidget(
        _app(const PrimaryPill(onPressed: null, child: Text('go'))),
      );
      expect(tester.widget<Sheen>(find.byType(Sheen)).enabled, isFalse);
    });
  });

  group('LoadingButton', () {
    final GlobalKey<LoadingButtonState> key = GlobalKey<LoadingButtonState>();

    testWidgets('hover and landed() each run a pass; busy runs none', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _app(LoadingButton(key: key, onPressed: () => taps++, text: 'go')),
      );
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 1);

      await _hover(tester, find.byType(OutlinedButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, paints..clipRRect()..rect());
      await tester.pumpAndSettle();
      expect(_paint, isNot(paints..clipRRect()));

      key.currentState!.landed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, paints..clipRRect()..rect());
      await tester.pumpAndSettle();

      key.currentState!.animateForward();
      await tester.pump();
      key.currentState!.landed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_paint, isNot(paints..clipRRect()));

      // The spinner never settles: back to idle before the test ends.
      key.currentState!.animateReverse();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(key.currentState!.btnState, ButtonState.idle);

      final GlobalKey<LoadingButtonState> compact =
          GlobalKey<LoadingButtonState>();
      await tester.pumpWidget(
        _app(
          LoadingButton(
            key: compact,
            onPressed: () => taps++,
            text: 'Collect',
            minimumSize: const Size(30, 30),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              backgroundColor: AppTokens.dark.card2,
              disabledBackgroundColor: AppTokens.dark.card2,
              side: BorderSide(color: AppTokens.dark.line),
            ),
          ),
        ),
      );
      final Size idle = tester.getSize(find.byType(OutlinedButton));
      expect(idle.height, 30);
      compact.currentState!.animateForward();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(find.byType(OutlinedButton)), const Size(30, 30));
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 1);
      compact.currentState!.animateReverse();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.getSize(find.byType(OutlinedButton)), idle);
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled one gets no pass', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(const LoadingButton(key: Key('off'), onPressed: null, text: 'go')),
      );
      expect(tester.widget<Sheen>(find.byType(Sheen)).enabled, isFalse);
    });

    testWidgets('a caller style keeps the label in the app font', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          LoadingButton.settings(
            key: const Key('s'),
            onPressed: () {},
            text: 'go',
          ),
        ),
      );
      final RichText label = tester.widget<RichText>(
        find.descendant(of: find.text('go'), matching: find.byType(RichText)),
      );
      expect(label.text.style!.fontFamily, kOutlinedButtonTextStyle.fontFamily);
      expect(label.text.style!.fontSize, kBodyMediumTextStyle.fontSize);
    });
  });

  testWidgets('accepted feedback keeps a disabled face and its full clock', (
    WidgetTester tester,
  ) async {
    final SheenController controller = SheenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(
      PrimaryPill(
        onPressed: null,
        sheen: controller,
        child: const Text('Sent'),
      ),
      reduceMotion: true,
    ));
    await tester.pumpAndSettle();
    controller.landed(isCurrent: () => true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 590));
    expect(_paint, paints..clipRRect()..rect());
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull);
    await tester.pump(const Duration(milliseconds: 10));
    expect(_paint, isNot(paints..clipRRect()));
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted feedback waits for an existing hover pass', (
    WidgetTester tester,
  ) async {
    final SheenController controller = SheenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(Sheen(
      controller: controller,
      child: OutlinedButton(onPressed: () {}, child: const Text('go')),
    )));
    await _hover(tester, find.byType(OutlinedButton));
    await tester.pump(const Duration(milliseconds: 200));
    controller.landed(isCurrent: () => true);
    await tester.pump(const Duration(milliseconds: 399));
    expect(_paint, paints..clipRRect()..rect());
    await tester.pump(const Duration(milliseconds: 1));
    expect(_paint, isNot(paints..clipRRect()));
    // The visual endpoint precedes the SDK's completed status by a tick.
    await tester.pump(const Duration(microseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, paints..clipRRect()..rect());
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, isNot(paints..clipRRect()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale owners retire active and queued accepted feedback', (
    WidgetTester tester,
  ) async {
    final SheenController controller = SheenController();
    addTearDown(controller.dispose);
    bool current = true;
    await tester.pumpWidget(_app(Sheen(
      controller: controller,
      child: const SizedBox(width: 120, height: 40),
    )));
    await tester.pumpAndSettle();
    controller.pass();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.landed(isCurrent: () => current);
    current = false;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paint, isNot(paints..clipRRect()));

    current = true;
    controller.landed(isCurrent: () => current);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paint, paints..clipRRect()..rect());
    current = false;
    await tester.pump(const Duration(milliseconds: 1));
    expect(_paint, isNot(paints..clipRRect()));
    current = true;
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paint, isNot(paints..clipRRect()));

    controller.landed(isCurrent: () => current);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.cancel();
    await tester.pump();
    expect(_paint, isNot(paints..clipRRect()));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoadingButton delivers one accepted pass after idle rebuild', (
    WidgetTester tester,
  ) async {
    final GlobalKey<LoadingButtonState> action =
        GlobalKey<LoadingButtonState>();
    bool enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (_, StateSetter update) {
        rebuild = update;
        return LoadingButton(
          key: action,
          onPressed: enabled ? () {} : null,
          text: 'Fuse',
        );
      },
    )));
    await tester.pumpAndSettle();
    action.currentState!.animateForward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    action.currentState!.landed(isCurrent: () => true);
    action.currentState!.landed(isCurrent: () => true);
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paint, isNot(paints..clipRRect()));
    action.currentState!.animateReverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    expect(action.currentState!.btnState, ButtonState.idle);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, paints..clipRRect()..rect());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_paint, isNot(paints..clipRRect()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, isNot(paints..clipRRect()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoadingButton retires an earlier pending operation', (
    WidgetTester tester,
  ) async {
    final GlobalKey<LoadingButtonState> action =
        GlobalKey<LoadingButtonState>();
    await tester.pumpWidget(_app(LoadingButton(
      key: action, onPressed: () {}, text: 'Fuse',
    )));
    await tester.pumpAndSettle();
    action.currentState!.animateForward();
    action.currentState!.landed(isCurrent: () => true);
    action.currentState!.animateReverse();
    action.currentState!.animateForward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_paint, isNot(paints..clipRRect()));
    action.currentState!.animateReverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    expect(action.currentState!.btnState, ButtonState.idle);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, isNot(paints..clipRRect()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale send completion cannot cross a new operation', (
    WidgetTester tester,
  ) async {
    final GlobalKey<SendButtonState> action = GlobalKey<SendButtonState>();
    bool current = true;
    await tester.pumpWidget(_app(SendButton(
      key: action, onPressed: () {}, text: 'Send',
    )));
    await tester.pumpAndSettle();
    action.currentState!.animateForward();
    await tester.pump();
    action.currentState!.animateReverse();
    action.currentState!.landed(isCurrent: () => current);
    action.currentState!.animateForward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, isNot(paints..clipRRect()));
    action.currentState!.animateReverse();
    action.currentState!.landed(isCurrent: () => current);
    await tester.pump();
    // Rebuild the idle face, then initialize the post-frame ticker.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_paint, paints..clipRRect()..rect());
    current = false;
    await tester.pump(const Duration(milliseconds: 1));
    expect(_paint, isNot(paints..clipRRect()));
    expect(tester.takeException(), isNull);
  });
}
