import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/logical_capture.dart';

void main() {
  for (final double ratio in <double>[1, 1.25, 1.5, 2, 3]) {
    testWidgets(
      'complete 1x capture and logical pointer targets at DPR $ratio',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(1280 * ratio, 780 * ratio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final List<int> taps = <int>[0, 0, 0];
        const List<Rect> targets = <Rect>[
          Rect.fromLTWH(0, 0, 80, 60),
          Rect.fromLTWH(600, 360, 80, 60),
          Rect.fromLTWH(1200, 720, 80, 60),
        ];
        const List<Color> colors = <Color>[
          Color(0xFFFF0000),
          Color(0xFF00FF00),
          Color(0xFF0000FF),
        ];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: Stack(
                children: <Widget>[
                  for (int i = 0; i < targets.length; i++)
                    Positioned.fromRect(
                      rect: targets[i],
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          taps[i]++;
                        },
                        child: ColoredBox(
                          key: ValueKey<int>(i),
                          color: colors[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        for (int i = 0; i < targets.length; i++) {
          final RenderBox box = tester.renderObject<RenderBox>(
            find.byKey(ValueKey<int>(i)),
          );
          final Rect actual = logicalClientRect(box);
          expect(actual, targets[i]);
          await tester.tapAt(actual.center);
          await tester.pump();
          expect(taps[i], 1);
        }
        final RenderView view = tester.binding.renderViews.single;
        expect(view.size, const Size(1280, 780));
        final OffsetLayer layer = view.debugLayer! as OffsetLayer;
        await tester.runAsync(() async {
          final ui.Image image = await captureLogicalView(view, layer);
          try {
            expect(image.width, 1280);
            expect(image.height, 780);
            final ByteData? data = await image.toByteData();
            expect(data, isNotNull);
            for (int i = 0; i < targets.length; i++) {
              final Offset center = targets[i].center;
              final int offset =
                  (center.dy.toInt() * 1280 + center.dx.toInt()) * 4;
              final List<int> rgba = data!.buffer.asUint8List(
                data.offsetInBytes + offset,
                4,
              );
              expect(rgba, <int>[
                if (i == 0) 255 else 0,
                if (i == 1) 255 else 0,
                if (i == 2) 255 else 0,
                255,
              ]);
            }
          } finally {
            image.dispose();
          }
        });
      },
    );
  }
}
