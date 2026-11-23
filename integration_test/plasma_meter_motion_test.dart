import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

const Key _paintSurface = Key('native_plasma_meter_motion');

Widget _host({required bool generating, required bool light}) {
  final AppTokens tokens = light ? AppTokens.light : AppTokens.dark;
  return MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    home: Center(
      child: RepaintBoundary(
        key: _paintSurface,
        child: SizedBox(
          width: 240,
          child: PlasmaMeter(
            value: .6,
            active: generating,
            trackColor: tokens.line,
          ),
        ),
      ),
    ),
  );
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final RenderRepaintBoundary surface = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_paintSurface));
  final ui.Image image = await surface.toImage();
  try {
    final ByteData? frame = await image.toByteData();
    return frame!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  testWidgets(
    'the desktop Plasma meter animates and then holds in both themes',
    (
      WidgetTester tester,
    ) async {
      await windowManager.ensureInitialized();
      await tester.pumpWidget(_host(generating: false, light: false));
      await windowManager.waitUntilReadyToShow();
      await windowManager.show();
      await windowManager.focus();

      for (final bool light in <bool>[false, true]) {
        await tester.pumpWidget(_host(generating: true, light: light));
        await tester.pump();
        Uint8List previous = await _pixels(tester);
        int changes = 0;
        for (int attempt = 0; attempt < 40 && changes < 3; attempt++) {
          await tester.pump(const Duration(milliseconds: 50));
          final Uint8List current = await _pixels(tester);
          if (!listEquals(previous, current)) changes++;
          previous = current;
        }
        expect(changes, 3, reason: 'the visible meter must paint moving light');

        await tester.pumpWidget(_host(generating: false, light: light));
        await tester.pump();
        final Uint8List held = await _pixels(tester);
        await tester.pump(const Duration(milliseconds: 350));
        expect(await _pixels(tester), orderedEquals(held));
      }

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
