import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';

int _built = 0;
int _disposed = 0;

class _Page extends StatefulWidget {
  const _Page(this.name);

  final String name;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    _built++;
  }

  @override
  void dispose() {
    _disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(key: ValueKey<String>('page_${widget.name}'));
}

Widget _host(int index) => Directionality(
  textDirection: TextDirection.ltr,
  child: RiseSwitcher(
    child: KeyedSubtree(
      key: ValueKey<int>(index),
      child: _Page('$index'),
    ),
  ),
);

Finder _page(int index) => find.byKey(ValueKey<String>('page_$index'));

void main() {
  setUp(() {
    _built = 0;
    _disposed = 0;
  });

  group('RiseSwitcher', () {
    testWidgets('the first page appears in place, without motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      expect(tester.getTopLeft(_page(0)), Offset.zero);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the new page rises 6 px; the old one does not move', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      expect(tester.getTopLeft(_page(1)).dy, 6);
      expect(tester.getTopLeft(_page(0)).dy, 0);

      await tester.pump(const Duration(milliseconds: 50));
      final double rising = tester.getTopLeft(_page(1)).dy;
      expect(rising, greaterThan(0));
      expect(rising, lessThan(6));
      expect(tester.getTopLeft(_page(0)).dy, 0);

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_page(1)), Offset.zero);
    });

    testWidgets('the old page is gone before the new one has arrived', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      expect(_page(0), findsOneWidget);
      // Past the 100 ms fade out, inside the 300 ms arrival.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(_page(0), findsNothing);
      expect(_disposed, 1);
      expect(tester.getTopLeft(_page(1)).dy, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('only the current page is built once settled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(2));
      await tester.pumpAndSettle();
      expect(_built, 3);
      expect(_disposed, 2);
      expect(find.byType(_Page), findsOneWidget);
      expect(_page(2), findsOneWidget);
    });

    testWidgets('a rebuild with the same key keeps the page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(0));
      expect(_built, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the leaving page takes no input', (WidgetTester tester) async {
      int taps = 0;
      Widget host(int index) => Directionality(
        textDirection: TextDirection.ltr,
        child: RiseSwitcher(
          child: KeyedSubtree(
            key: ValueKey<int>(index),
            child: index == 0
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                  )
                : const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });
  });
}
