import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

const Key _surface = Key('meter_surface');
const MethodChannel _window = MethodChannel('window_manager');

Widget _host(
  double value, {
  TextDirection direction = TextDirection.ltr,
  bool active = false,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Directionality(
    textDirection: direction,
    child: Center(
      child: RepaintBoundary(
        key: _surface,
        child: SizedBox(
          width: 200,
          height: 6,
          child: PlasmaMeter(
            value: value,
            active: active,
            trackColor: AppTokens.dark.line,
          ),
        ),
      ),
    ),
  ),
);

Future<ByteData> _barPixels(
  WidgetTester tester, {
  double pixelRatio = 1,
}) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_surface));
  final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      return await image.toByteData();
    } finally {
      image.dispose();
    }
  });
  return bytes!;
}

/// The drawn fill boundary, independent of whether the test engine uses
/// its shader or the flat fallback.
Future<int> _filledPixels(WidgetTester tester) async {
  final ByteData data = await _barPixels(tester);
  final Color track = AppTokens.dark.line;
  final List<int> rgb = <int>[
    (track.r * 255).round(),
    (track.g * 255).round(),
    (track.b * 255).round(),
  ];
  int filled = 0;
  for (int x = 3; x < 197; x++) {
    final int offset = (3 * 200 + x) * 4;
    if (data.getUint8(offset) != rgb[0] ||
        data.getUint8(offset + 1) != rgb[1] ||
        data.getUint8(offset + 2) != rgb[2]) {
      filled += 1;
    }
  }
  return filled + 3;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, (MethodCall call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_window, null);
  });

  testWidgets('an idle meter has its exact level and schedules no frames', (
    WidgetTester tester,
  ) async {
    for (final TextDirection direction in TextDirection.values) {
      await tester.pumpWidget(_host(0, direction: direction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 501));
      final ByteData empty = await _barPixels(tester, pixelRatio: 2);
      final Color track = AppTokens.dark.line;
      // Check the leading AA pixel at 2x, where the fill shader's soft edge
      // used to be visible even with a zero level.
      final int offset =
          (6 * 400 + (direction == TextDirection.ltr ? 0 : 399)) * 4;
      // Raw RGBA stores premultiplied color at the rounded edge.
      final int alpha = empty.getUint8(offset + 3);
      expect(alpha, greaterThan(200));
      expect(empty.getUint8(offset), closeTo(track.r * alpha, 1));
      expect(empty.getUint8(offset + 1), closeTo(track.g * alpha, 1));
      expect(empty.getUint8(offset + 2), closeTo(track.b * alpha, 1));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(_host(0.25, direction: direction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 501));
      await tester.pump();
      expect(await _filledPixels(tester), closeTo(50, 1));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 5));
      expect(await _filledPixels(tester), closeTo(50, 1));
    }
  });

  testWidgets('one ticker retains the 500 ms level easing, then stops', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(_host(0.25));
    await tester.pump();
    await tester.pumpWidget(_host(0.75));
    await tester.pump();
    expect(await _filledPixels(tester), closeTo(50, 1));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump(const Duration(milliseconds: 250));
    final int middle = await _filledPixels(tester);
    expect(middle, greaterThan(50));
    expect(middle, lessThan(150));
    await tester.pump(const Duration(milliseconds: 249));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await _filledPixels(tester), closeTo(150, 1));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_host(0.75, active: true));
    for (
      int attempt = 0;
      attempt < 50 && tester.binding.transientCallbackCount == 0;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(tester.binding.transientCallbackCount, 1);
    final ByteData initial = await _barPixels(tester);
    await tester.pump(const Duration(milliseconds: 350));
    final ByteData flowing = await _barPixels(tester);
    expect(
      flowing.buffer.asUint8List(),
      isNot(orderedEquals(initial.buffer.asUint8List())),
    );
    expect(await _filledPixels(tester), closeTo(150, 1));

    await tester.pumpWidget(_host(0.75));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    final ByteData idle = await _barPixels(tester);
    expect(
      idle.buffer.asUint8List(),
      orderedEquals(flowing.buffer.asUint8List()),
    );
    expect(tester.takeException(), isNull);
  });
}
