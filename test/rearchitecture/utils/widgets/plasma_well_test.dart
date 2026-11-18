import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_well.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

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
}
