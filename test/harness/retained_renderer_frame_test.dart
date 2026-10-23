import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/capture_protocol.dart';
import '../../harness/app/retained_renderer_frame.dart';

void main() {
  Future<void> paint(WidgetTester tester, Color color) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: color),
    ),
  );

  void size(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(64, 48);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('actual held raster survives later live paints', (
    WidgetTester tester,
  ) async {
    size(tester);
    await paint(tester, const Color(0xFFFF0000));
    final RenderView view = tester.binding.renderViews.single;
    final RetainedRendererFrame? frame = await tester.runAsync(
      () => RetainedRendererFrame.capture(
        view: view,
        expectedSize: const Size(64, 48),
        sourceCurrent: () => true,
      ),
    );
    expect(frame, isNotNull);
    await paint(tester, const Color(0xFF0000FF));
    expect(frame!.isCurrent, isTrue);
    await tester.runAsync(() async {
      final Future<Uint8List> encoding = frame.encodePng();
      expect(frame.encodePng(), same(encoding));
      final Uint8List png = await encoding;
      expect(frame.originalEncoding, isNotNull);
      final ui.Codec codec = await ui.instantiateImageCodec(png);
      try {
        final ui.FrameInfo decoded = await codec.getNextFrame();
        try {
          expect(decoded.image.width, 64);
          expect(decoded.image.height, 48);
          final ByteData? pixels = await decoded.image.toByteData();
          expect(pixels!.buffer.asUint8List(pixels.offsetInBytes, 4), <int>[
            255,
            0,
            0,
            255,
          ]);
        } finally {
          decoded.image.dispose();
        }
      } finally {
        codec.dispose();
        final Future<void> release = frame.release();
        expect(frame.release(), same(release));
        await release;
      }
    });
    expect(frame.released, isTrue);
    expect(frame.isCurrent, isFalse);
  });

  testWidgets('source loss stays refused after the source returns', (
    WidgetTester tester,
  ) async {
    size(tester);
    await paint(tester, const Color(0xFF000000));
    bool current = true;
    final RetainedRendererFrame? frame = await tester.runAsync(
      () => RetainedRendererFrame.capture(
        view: tester.binding.renderViews.single,
        expectedSize: const Size(64, 48),
        sourceCurrent: () => current,
      ),
    );
    current = false;
    expect(frame!.isCurrent, isFalse);
    current = true;
    expect(frame.isCurrent, isFalse);
    await tester.runAsync(() async {
      await expectLater(frame.encodePng(), throwsA(isA<CaptureRefused>()));
      expect(frame.originalEncoding, isNull);
      await frame.release();
    });
    expect(frame.released, isTrue);
  });

  testWidgets('unexpected client size refuses before raster readback', (
    WidgetTester tester,
  ) async {
    size(tester);
    await paint(tester, const Color(0xFF000000));
    await tester.runAsync(() async {
      await expectLater(
        RetainedRendererFrame.capture(
          view: tester.binding.renderViews.single,
          expectedSize: const Size(1280, 780),
          sourceCurrent: () => true,
        ),
        throwsA(isA<CaptureRefused>()),
      );
    });
  });
}
