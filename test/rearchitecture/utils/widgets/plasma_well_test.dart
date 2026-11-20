import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_glow.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_well.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

Future<ByteData> _markPixels(WidgetTester tester, Finder mark) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(mark);
  final ByteData? pixels = await tester.runAsync<ByteData?>(() async {
    final ui.Image frame = await boundary.toImage();
    try {
      return await frame.toByteData();
    } finally {
      frame.dispose();
    }
  });
  return pixels!;
}

void main() {
  for (final double size in <double>[96, 120]) {
    testWidgets('the $size px plasma halo blends into both themes', (
      WidgetTester tester,
    ) async {
      // Stand in for the shader to observe the backing and layout separately.
      final Widget mark = SizedBox.square(
        key: const Key('plasma_page_mark'),
        dimension: size,
      );
      final Widget well = PlasmaWell(child: mark);
      Widget under(ThemeData theme) => MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: well)),
      );

      await tester.pumpWidget(under(AppTheme.lightTheme));
      final Finder markFinder = find.byKey(const Key('plasma_page_mark'));
      final Finder haloFinder = find.byKey(const Key('plasma_well'));
      final Element originalMark = tester.element(markFinder);

      for (final ThemeData theme in <ThemeData>[
        AppTheme.lightTheme,
        AppTheme.darkTheme,
      ]) {
        await tester.pumpWidget(under(theme));
        await tester.pumpAndSettle();

        final BoxDecoration halo =
            tester.widget<DecoratedBox>(haloFinder).decoration as BoxDecoration;
        expect(halo.shape, BoxShape.circle);
        expect(halo.color, isNull);
        final RadialGradient gradient = halo.gradient! as RadialGradient;
        expect(
          gradient.colors.first.withValues(alpha: 1),
          AppColors.plasmaPink,
        );
        expect(gradient.colors[1].withValues(alpha: 1), AppColors.qsrColor);
        expect(gradient.colors.last.a, 0);
        expect(tester.getRect(haloFinder), tester.getRect(markFinder));
        expect(tester.getSize(find.byWidget(well)), Size.square(size));
        expect(tester.element(markFinder), same(originalMark));
        expect(
          find.ancestor(of: markFinder, matching: find.byType(ClipOval)),
          findsNothing,
        );
      }
    });
  }

  testWidgets('the white Plasma core stays white while the halo moves', (
    WidgetTester tester,
  ) async {
    const MethodChannel window = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(window, (_) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(window, null));

    const int size = 120;
    const int center = (size ~/ 2 * size + size ~/ 2) * 4;
    Widget host({required bool active}) => MaterialApp(
      home: Center(child: PlasmaGlow(size: size.toDouble(), active: active)),
    );
    await tester.pumpWidget(host(active: false));
    final Finder mark = find.descendant(
      of: find.byType(PlasmaGlow),
      matching: find.byType(RepaintBoundary),
    );
    for (int attempt = 0; attempt < 50 && mark.evaluate().isEmpty; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(mark, findsOneWidget);
    expect((await _markPixels(tester, mark)).getUint32(center), 0xffffffff);
    await tester.pumpWidget(host(active: true));
    await tester.pump();
    final ByteData initial = await _markPixels(tester, mark);
    await tester.pump(const Duration(milliseconds: 550));
    final ByteData later = await _markPixels(tester, mark);
    expect(later.getUint32(center), 0xffffffff);
    expect(
      later.buffer.asUint8List(),
      isNot(orderedEquals(initial.buffer.asUint8List())),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
