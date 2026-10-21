import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
}
