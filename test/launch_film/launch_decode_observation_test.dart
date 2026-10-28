import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';

const String _asset = 'test/launch_film/fixtures/film.webp';

class _FilmBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

Future<void> _until(WidgetTester tester, bool Function() observed) async {
  for (int frame = 0; frame < 200 && !observed(); frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(observed(), isTrue);
}

void main() {
  testWidgets('decode observation never advances or replaces its codec', (
    WidgetTester tester,
  ) async {
    final LaunchFilmController controller = LaunchFilmController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _FilmBundle(),
        child: SizedBox(
          width: 160,
          height: 90,
          child: LaunchFilm(
            asset: _asset,
            autoplay: false,
            controller: controller,
          ),
        ),
      ),
    );
    final LaunchFilmCleanup original = controller.cleanup!;
    expect(controller.decodingFrameIndex, isNull);
    expect(controller.frameCount, 0);
    controller.play();
    expect(controller.decodingFrameIndex, isNull);
    await _until(tester, () => controller.frame >= 0);
    final int index = controller.decodingFrameIndex!;
    expect(
      index,
      inInclusiveRange(controller.frame, controller.frameCount - 1),
    );
    for (int read = 0; read < 5; read++) {
      expect(controller.decodingFrameIndex, index);
      expect(controller.cleanup, same(original));
    }
    controller.skipToEnd();
    expect(controller.decodingFrameIndex, index);
    expect(controller.cleanup, same(original));
    await _until(tester, () => controller.isDone);
    expect(controller.frameCount, 8);
    expect(controller.decodingFrameIndex, 7);
    expect(controller.frame, 7);
    controller.play();
    expect(controller.decodingFrameIndex, isNull);
    expect(controller.cleanup, same(original));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.decodingFrameIndex, isNull);
    expect(controller.cleanup, same(original));
    await _until(tester, () => original.completion.succeeded);
    expect(original.stateDisposed, isTrue);
  });
}
