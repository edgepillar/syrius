import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';

Widget _host(Object? value, {String text = 'figure'}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: ValueFlash(value: value, child: Text(text)),
  ),
);

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
      await tester.pumpWidget(_host(1));
      await tester.pumpWidget(_host(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_paint, paints..rrect());

      await tester.pumpAndSettle();
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
  });
}
