import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';

/// The height of each step, by index.
const List<double> _heights = <double>[100, 240, 60];

const double _width = 400;

int _built = 0;
int _disposed = 0;

class _Step extends StatefulWidget {
  const _Step(this.index, {this.height});

  final int index;
  final double? height;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
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
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey<String>('step_${widget.index}'),
    width: double.infinity,
    height: widget.height ?? _heights[widget.index],
  );
}

/// A switcher 400 wide at the top left of the window, free to be any height.
Widget _host(
  int step, {
  TextDirection direction = TextDirection.ltr,
  Color? fill,
  double? height,
  Widget? child,
}) {
  final Widget content = child ?? _Step(step, height: height);
  return Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: _width,
        child: fill == null
            ? StepSwitcher(step: step, child: content)
            : StepSwitcher(step: step, fillColor: fill, child: content),
      ),
    ),
  );
}

Finder _step(int index) => find.byKey(ValueKey<String>('step_$index'));

double _left(WidgetTester tester, int index) =>
    tester.getTopLeft(_step(index)).dx;

double _switcherHeight(WidgetTester tester) =>
    tester.getSize(find.byType(StepSwitcher)).height;

void main() {
  setUp(() {
    _built = 0;
    _disposed = 0;
  });

  group('StepSwitcher', () {
    testWidgets('the first step appears in place, without motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      expect(tester.getTopLeft(_step(0)), Offset.zero);
      expect(_switcherHeight(tester), 100);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the new step replaces the old', (WidgetTester tester) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      await tester.pumpAndSettle();
      expect(find.byType(_Step), findsOneWidget);
      expect(_step(1), findsOneWidget);
      expect(_step(0), findsNothing);
      expect(_built, 2);
      expect(_disposed, 1);
      expect(tester.getTopLeft(_step(1)), Offset.zero);
    });

    testWidgets('mid-transition both steps are in the tree', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_step(0), findsOneWidget);
      expect(_step(1), findsOneWidget);
      expect(_disposed, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('a rebuild with the same step keeps the step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(0));
      expect(_built, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a higher step enters from the end, a lower from the start', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      // Left to right the end is the right: the new step starts 30 px out.
      expect(_left(tester, 1), 30);
      expect(_left(tester, 0), 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_left(tester, 1), inExclusiveRange(0, 30));
      expect(_left(tester, 0), lessThan(0));

      await tester.pumpAndSettle();
      expect(_left(tester, 1), 0);

      await tester.pumpWidget(_host(0));
      expect(_left(tester, 0), -30);
      expect(_left(tester, 1), 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_left(tester, 0), inExclusiveRange(-30, 0));
      expect(_left(tester, 1), greaterThan(0));

      await tester.pumpAndSettle();
      expect(_left(tester, 0), 0);
    });

    testWidgets('right to left the sides swap', (WidgetTester tester) async {
      const TextDirection rtl = TextDirection.rtl;
      await tester.pumpWidget(_host(0, direction: rtl));
      await tester.pumpWidget(_host(1, direction: rtl));
      // The end is the left now.
      expect(_left(tester, 1), -30);
      expect(_left(tester, 0), 0);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_left(tester, 1), inExclusiveRange(-30, 0));
      expect(_left(tester, 0), greaterThan(0));

      await tester.pumpAndSettle();
      expect(_left(tester, 1), 0);

      await tester.pumpWidget(_host(0, direction: rtl));
      expect(_left(tester, 0), 30);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_left(tester, 0), inExclusiveRange(0, 30));
      expect(_left(tester, 1), lessThan(0));

      await tester.pumpAndSettle();
      expect(_left(tester, 0), 0);
    });

    testWidgets('the height travels from one step to the next', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));

      // To a taller step: no jump on the frame of the change.
      await tester.pumpWidget(_host(1));
      expect(_switcherHeight(tester), 100);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_switcherHeight(tester), inExclusiveRange(100, 240));
      // Neither step is squeezed into the height shown.
      expect(tester.getSize(_step(0)), const Size(_width, 100));
      expect(tester.getSize(_step(1)), const Size(_width, 240));
      await tester.pumpAndSettle();
      expect(_switcherHeight(tester), 240);

      // To a shorter one: the old step is not cut to the new height at once.
      await tester.pumpWidget(_host(2));
      expect(_switcherHeight(tester), 240);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_switcherHeight(tester), inExclusiveRange(60, 240));
      expect(tester.getSize(_step(1)), const Size(_width, 240));
      expect(tester.getSize(_step(2)), const Size(_width, 60));
      await tester.pumpAndSettle();
      expect(_switcherHeight(tester), 60);
    });

    testWidgets('a taller step is cut at the height shown, only in motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);

      await tester.pumpWidget(_host(1));
      await tester.pump(const Duration(milliseconds: 100));
      final Rect clip = tester.layers
          .whereType<ClipRectLayer>()
          .single
          .clipRect!;
      expect(clip.height, _switcherHeight(tester));
      // Room at the sides for the step's travel.
      expect(clip.width, greaterThan(_width));

      await tester.pumpAndSettle();
      expect(tester.layers.whereType<ClipRectLayer>(), isEmpty);
    });

    testWidgets('a step that grows by itself is followed at once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(0, height: 150));
      expect(_switcherHeight(tester), 150);
      expect(_built, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a switcher of a fixed height keeps both steps that tall', (
      WidgetTester tester,
    ) async {
      Widget host(int step) => Directionality(
        textDirection: TextDirection.ltr,
        child: StepSwitcher(
          step: step,
          child: Column(
            key: ValueKey<String>('step_$step'),
            children: const <Widget>[Spacer(), SizedBox(height: 10)],
          ),
        ),
      );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(_step(0)), const Size(800, 600));
      expect(tester.getSize(_step(1)), const Size(800, 600));
      await tester.pumpAndSettle();
    });

    testWidgets('the leaving step takes no input', (WidgetTester tester) async {
      int taps = 0;
      Widget host(int step) => _host(
        step,
        child: step == 0
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: double.infinity, height: 100),
              )
            : const SizedBox(width: double.infinity, height: 100),
      );
      await tester.pumpWidget(host(0));
      await tester.tapAt(const Offset(100, 50));
      expect(taps, 1);
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(const Offset(100, 50));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('the fill is never the theme canvas', (
      WidgetTester tester,
    ) async {
      const Color canvas = Color(0xFFFF0000);
      const Color card = Color(0xFF101010);
      // Every fill the package has in the tree while two steps swap.
      Set<Color> fills() => tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(StepSwitcher),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((ColoredBox box) => box.color)
          .toSet();
      Widget host(int step, {Color? fill}) => Theme(
        data: ThemeData(canvasColor: canvas),
        child: _host(step, fill: fill),
      );

      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 30));
      expect(fills(), <Color>{Colors.transparent});
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(1, fill: card));
      await tester.pumpWidget(host(2, fill: card));
      await tester.pump(const Duration(milliseconds: 30));
      expect(fills(), <Color>{card});
      await tester.pumpAndSettle();
    });

    testWidgets('MediaQuery.disableAnimations does not shorten the swap', (
      WidgetTester tester,
    ) async {
      Widget host(int step) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(step),
      );
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_left(tester, 1), inExclusiveRange(0, 30));
      expect(_switcherHeight(tester), inExclusiveRange(100, 240));

      // 300 ms in all: the old step is there to the end and gone after it.
      await tester.pump(const Duration(milliseconds: 140));
      expect(_step(0), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(_step(0), findsNothing);
      expect(_switcherHeight(tester), 240);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    // The platform's own flag is another matter. The package builds its two
    // controllers without `AnimationBehavior.preserve` and takes no
    // controller from outside, so under the flag its swap runs in a
    // twentieth of the time whatever this widget does; that is put right
    // once for the whole app, in the binding. What the widget owns is the
    // height, and the height keeps its duration.
    testWidgets('the height keeps its duration when the platform asks for '
        'less motion', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(_host(0));
      await tester.pumpWidget(_host(1));
      await tester.pump(const Duration(milliseconds: 150));
      // The flag is in force: the package's swap, 15 ms now, is long over.
      expect(_step(0), findsNothing);
      expect(_switcherHeight(tester), inExclusiveRange(100, 240));
      await tester.pump(const Duration(milliseconds: 140));
      expect(_switcherHeight(tester), lessThan(240));
      await tester.pump(const Duration(milliseconds: 20));
      expect(_switcherHeight(tester), 240);
      await tester.pumpAndSettle();
    });
  });
}
