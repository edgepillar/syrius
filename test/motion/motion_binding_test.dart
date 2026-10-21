import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/motion_binding.dart';

// MotionBinding itself cannot be installed here: a test process has one
// binding and it must be a test binding. The rule lives in the mixin, so the
// test binding takes the same mixin and the same two overrides are under
// test. What is left out is only MotionBinding.ensureInitialized.
class _MotionTestBinding extends AutomatedTestWidgetsFlutterBinding
    with MotionAlwaysBinding {}

const Duration _length = Duration(milliseconds: 400);

Widget _box(double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: AnimatedContainer(duration: _length, width: width, height: 10),
  ),
);

double _width(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedContainer)).width;

void _platformAsksForNoAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  // Before the first testWidgets, which would install the plain test binding.
  _MotionTestBinding();

  group('MotionAlwaysBinding', () {
    testWidgets('answers false while the platform asks for no animations', (
      WidgetTester tester,
    ) async {
      _platformAsksForNoAnimations(tester);

      expect(tester.binding, isA<MotionAlwaysBinding>());
      // The flag did arrive: the binding holds it and declines to pass it on.
      expect(tester.binding.accessibilityFeatures.disableAnimations, isTrue);
      expect(SemanticsBinding.instance.disableAnimations, isFalse);
    });

    testWidgets('an implicit animation takes its full length', (
      WidgetTester tester,
    ) async {
      _platformAsksForNoAnimations(tester);

      await tester.pumpWidget(_box(100));
      await tester.pumpWidget(_box(200));
      // The SDK's own answer to the flag is a twentieth, 20 ms, which would
      // have this at 200 already.
      await tester.pump(_length ~/ 2);
      expect(_width(tester), moreOrLessEquals(150, epsilon: 0.5));
      await tester.pump(_length ~/ 2);
      expect(_width(tester), 200);
    });

    testWidgets('a controller built the default way runs at full length', (
      WidgetTester tester,
    ) async {
      _platformAsksForNoAnimations(tester);

      final AnimationController controller = AnimationController(
        vsync: tester,
        duration: _length,
      );
      addTearDown(controller.dispose);
      expect(controller.animationBehavior, AnimationBehavior.normal);

      controller.forward();
      await tester.pump();
      await tester.pump(_length ~/ 2);
      expect(controller.value, moreOrLessEquals(0.5, epsilon: 0.01));
      await tester.pump(_length ~/ 2);
      expect(controller.value, 1.0);
      // The controller reports the end on the frame after it reaches it.
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.isCompleted, isTrue);
    });

    testWidgets('the tree under the root view reads false from MediaQuery', (
      WidgetTester tester,
    ) async {
      _platformAsksForNoAnimations(tester);

      // What the root MediaQuery holds, and what Image would stop on.
      expect(MediaQueryData.fromView(tester.view).disableAnimations, isTrue);

      late bool read;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            read = MediaQuery.disableAnimationsOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(read, isFalse);
    });
  });

  group('MotionAlways', () {
    Widget host(MediaQueryData above, ValueSetter<MediaQueryData> onRead) =>
        MediaQuery(
          data: above,
          child: MotionAlways(
            child: Builder(
              builder: (BuildContext context) {
                onRead(MediaQuery.of(context));
                return const SizedBox();
              },
            ),
          ),
        );

    testWidgets('turns the flag off and keeps the rest', (
      WidgetTester tester,
    ) async {
      const MediaQueryData above = MediaQueryData(
        size: Size(321, 123),
        textScaler: TextScaler.linear(1.5),
        highContrast: true,
        disableAnimations: true,
      );
      late MediaQueryData read;
      await tester.pumpWidget(host(above, (MediaQueryData d) => read = d));

      expect(read.disableAnimations, isFalse);
      expect(read, above.copyWith(disableAnimations: false));
    });

    testWidgets('follows the MediaQuery above it', (WidgetTester tester) async {
      late MediaQueryData read;
      void onRead(MediaQueryData d) => read = d;

      await tester.pumpWidget(
        host(
          const MediaQueryData(size: Size(300, 200), disableAnimations: true),
          onRead,
        ),
      );
      expect(read.size, const Size(300, 200));

      await tester.pumpWidget(
        host(
          const MediaQueryData(size: Size(640, 480), disableAnimations: true),
          onRead,
        ),
      );
      expect(read.size, const Size(640, 480));
      expect(read.disableAnimations, isFalse);
    });

    testWidgets('an implicit animation under it takes its full length', (
      WidgetTester tester,
    ) async {
      _platformAsksForNoAnimations(tester);

      Widget under(double width) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MotionAlways(child: _box(width)),
      );
      await tester.pumpWidget(under(100));
      await tester.pumpWidget(under(200));
      await tester.pump(_length ~/ 2);
      expect(_width(tester), moreOrLessEquals(150, epsilon: 0.5));
    });
  });
}
