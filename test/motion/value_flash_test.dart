import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';

Widget _host(
  Object? value, {
  String text = 'figure',
  Duration? duration,
  bool disableAnimations = false,
  bool observePaint = false,
}) {
  final Widget figure = Text(text);
  final ValueFlash flash = ValueFlash(
    value: value,
    duration: duration ?? const Duration(milliseconds: 1200),
    observePaint: observePaint,
    child: figure,
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(child: flash),
    ),
  );
}

Finder get _paint => find.descendant(
  of: find.byType(ValueFlash),
  matching: find.byType(CustomPaint),
);

void main() {
  group('ValueFlash', () {
    testWidgets('does not flash on first build', (WidgetTester tester) async {
      await tester.pumpWidget(_host(1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_paint, isNot(paints..rrect()));
    });

    testWidgets('does not flash while the value stays equal', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(BigInt.from(5)));
      // A new object, the same value, and a different child.
      await tester.pumpWidget(_host(BigInt.from(5), text: 'other'));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_paint, isNot(paints..rrect()));
    });

    testWidgets('flashes once when the value changes, then rests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(1, observePaint: true));
      final Element flash = tester.element(find.byType(ValueFlash));
      expect(ValueFlash.paintedPhaseOf(flash), (0, 1.0));
      await tester.pumpWidget(_host(2, observePaint: true));
      await tester.pump(const Duration(milliseconds: 100));
      final (int, double)? painted = ValueFlash.paintedPhaseOf(flash);
      expect(painted?.$1, 1);
      expect(painted?.$2, closeTo(100 / 1200, 0.0001));
      expect(_paint, paints..rrect());

      await tester.pumpAndSettle();
      expect(ValueFlash.paintedPhaseOf(flash), (1, 1.0));
      expect(_paint, isNot(paints..rrect()));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a second change restarts the flash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(1));
      await tester.pumpWidget(_host(2));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(_host(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_paint, paints..rrect());
      await tester.pumpAndSettle();
      expect(_paint, isNot(paints..rrect()));
    });

    testWidgets('a change from nothing to a value counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(null));
      await tester.pumpWidget(_host('z1qq'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_paint, paints..rrect());
      await tester.pumpAndSettle();
    });

    testWidgets('takes no space of its own', (WidgetTester tester) async {
      await tester.pumpWidget(_host(1));
      expect(
        tester.getSize(find.byType(ValueFlash)),
        tester.getSize(find.text('figure')),
      );
    });

    for (final bool disabled in <bool>[false, true]) {
      testWidgets('flashes for 1200 ms with OS animations off: $disabled', (
        WidgetTester tester,
      ) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: disabled);
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(_host(1, disableAnimations: disabled));
        await tester.pumpWidget(_host(2, disableAnimations: disabled));
        await tester.pump(const Duration(milliseconds: 1199));
        expect(_paint, paints..rrect());
        expect(find.text('figure'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(_paint, isNot(paints..rrect()));
        // The visual endpoint precedes the SDK's next-tick ticker cleanup.
        await tester.pump(const Duration(microseconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets(
      'uses the caller duration and restarts from the latest change',
      (
        WidgetTester tester,
      ) async {
        Widget host(int value) => _host(
          value,
          duration: const Duration(milliseconds: 400),
        );
        await tester.pumpWidget(host(1));
        await tester.pumpWidget(host(2));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(host(3));
        await tester.pump(const Duration(milliseconds: 399));
        expect(_paint, paints..rrect());
        await tester.pump(const Duration(milliseconds: 1));
        expect(_paint, isNot(paints..rrect()));
        await tester.pump(const Duration(microseconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets('explicit zero duration leaves the value still', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(1, duration: Duration.zero));
      await tester.pumpWidget(_host(2, duration: Duration.zero));
      expect(_paint, isNot(paints..rrect()));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
