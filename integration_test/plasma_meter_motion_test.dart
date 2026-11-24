import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/pow_generating_status_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_meter.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/strip/plasma_status.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show PowStatus;

const Key _meterSurface = Key('native_plasma_meter_motion');
const Key _statusSurface = Key('native_plasma_status_motion');
const Key _statusBolt = Key('strip_plasma');

Widget _host(PowGeneratingStatusBloc owner, {required bool light}) {
  final AppTokens tokens = light ? AppTokens.light : AppTokens.dark;
  return MaterialApp(
    theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepaintBoundary(
              key: _meterSurface,
              child: SizedBox(
                width: 240,
                child: StreamBuilder<PowGenerationState>(
                  stream: owner.stream,
                  initialData: owner.value,
                  builder: (_, AsyncSnapshot<PowGenerationState> snapshot) =>
                      PlasmaMeter(
                        value: .6,
                        active: snapshot.data?.isGenerating ?? false,
                        trackColor: tokens.line,
                      ),
                ),
              ),
            ),
            RepaintBoundary(
              key: _statusSurface,
              child: SizedBox(
                width: 360,
                height: 44,
                child: GenerationStatus(status: owner.stream),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Uint8List> _pixels(
  WidgetTester tester,
  Key surfaceKey, {
  Key? crop,
}) async {
  final Finder boundary = find.byKey(surfaceKey);
  final RenderRepaintBoundary surface = tester
      .renderObject<RenderRepaintBoundary>(boundary);
  final ui.Image image = await surface.toImage();
  try {
    final ByteData frame = (await image.toByteData())!;
    final Uint8List pixels = frame.buffer.asUint8List(
      frame.offsetInBytes,
      frame.lengthInBytes,
    );
    if (crop == null) return pixels;

    // Isolate the painted bolt from the elapsed-time text.
    final Rect box = tester
        .getRect(find.byKey(crop))
        .shift(
          -tester.getTopLeft(boundary),
        );
    final int left = box.left.floor();
    final int right = box.right.ceil();
    final int top = box.top.floor();
    final int bottom = box.bottom.ceil();
    expect(left, greaterThanOrEqualTo(0));
    expect(right, lessThanOrEqualTo(image.width));
    expect(top, greaterThanOrEqualTo(0));
    expect(bottom, lessThanOrEqualTo(image.height));

    const int bytesPerPixel = 4;
    final int rowBytes = (right - left) * bytesPerPixel;
    final Uint8List result = Uint8List((bottom - top) * rowBytes);
    for (int y = top; y < bottom; y++) {
      final int start = (y * image.width + left) * bytesPerPixel;
      final int offset = (y - top) * rowBytes;
      result.setRange(offset, offset + rowBytes, pixels, start);
    }
    return result;
  } finally {
    image.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  testWidgets(
    'the desktop Plasma meter and status bolt paint during fixture generation',
    (WidgetTester tester) async {
      final PowGeneratingStatusBloc owner = PowGeneratingStatusBloc();
      addTearDown(owner.dispose);
      await windowManager.ensureInitialized();
      await tester.pumpWidget(_host(owner, light: false));
      await windowManager.waitUntilReadyToShow();
      await windowManager.show();
      await windowManager.focus();

      for (final bool light in <bool>[false, true]) {
        await tester.pumpWidget(_host(owner, light: light));
        expect(find.byKey(_statusBolt), findsNothing);
        final PowWorkToken work = owner.claimWork();
        expect(owner.update(work, PowStatus.generating), isTrue);
        await tester.pump();
        expect(find.byKey(_statusBolt), findsOneWidget);

        Uint8List previousMeter = await _pixels(tester, _meterSurface);
        Uint8List previousBolt = await _pixels(
          tester,
          _statusSurface,
          crop: _statusBolt,
        );
        int meterChanges = 0;
        int boltChanges = 0;
        for (
          int attempt = 0;
          attempt < 40 && (meterChanges < 3 || boltChanges < 3);
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
          final Uint8List meter = await _pixels(tester, _meterSurface);
          final Uint8List bolt = await _pixels(
            tester,
            _statusSurface,
            crop: _statusBolt,
          );
          if (!listEquals(previousMeter, meter)) meterChanges++;
          if (!listEquals(previousBolt, bolt)) boltChanges++;
          previousMeter = meter;
          previousBolt = bolt;
        }
        expect(meterChanges, greaterThanOrEqualTo(3));
        expect(boltChanges, greaterThanOrEqualTo(3));

        expect(owner.update(work, PowStatus.done), isTrue);
        await tester.pump();
        expect(find.byKey(_statusBolt), findsNothing);
        final Uint8List held = await _pixels(tester, _meterSurface);
        await tester.pump(const Duration(milliseconds: 350));
        expect(await _pixels(tester, _meterSurface), orderedEquals(held));
      }

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
