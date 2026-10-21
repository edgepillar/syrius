import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_well.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

// The shader does not load under test, so a box of the mark's size stands in
// for PlasmaGlow, set in the well as each call site sets it.

/// The Plasma page's mark: a 200 px square, the disc as wide.
Widget _pageMark() => const PlasmaWell(
  child: SizedBox.square(key: Key('plasma_page_mark'), dimension: 200),
);

/// The status strip's mark: 36 px under a radial fade, the disc 38 px.
Widget _stripMark() => PlasmaWell(
  overhang: 1,
  child: ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (Rect bounds) => const RadialGradient(
      colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      stops: <double>[0.6, 1],
    ).createShader(bounds),
    child: const SizedBox.square(key: Key('strip_plasma'), dimension: 36),
  ),
);

Widget _under(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

Finder _wellOf(String mark) => find.descendant(
  of: find.ancestor(
    of: find.byKey(Key(mark)),
    matching: find.byType(PlasmaWell),
  ),
  matching: find.byKey(const Key('plasma_well')),
);

void main() {
  final Map<String, ({Widget Function() build, double disc})> sites =
      <String, ({Widget Function() build, double disc})>{
        'plasma_page_mark': (build: _pageMark, disc: 200),
        'strip_plasma': (build: _stripMark, disc: 38),
      };

  for (final MapEntry<String, ({Widget Function() build, double disc})> site
      in sites.entries) {
    group(site.key, () {
      testWidgets('sits in a dark disc under the light theme', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _under(AppTheme.lightTheme, site.value.build()),
        );

        final Finder well = _wellOf(site.key);
        expect(well, findsOneWidget);
        final BoxDecoration ground =
            tester.widget<DecoratedBox>(well).decoration as BoxDecoration;
        expect(ground.shape, BoxShape.circle);
        expect(ground.color, const Color(0xFF262726));

        // Centred on the mark and wide enough to hold its inscribed circle,
        // which is where the strip's fade ends.
        final Finder mark = find.byKey(Key(site.key));
        expect(tester.getCenter(well), tester.getCenter(mark));
        expect(tester.getSize(well), Size.square(site.value.disc));
        expect(
          tester.getSize(well).width,
          greaterThanOrEqualTo(tester.getSize(mark).width),
        );

        final ClipOval clip = tester.widget<ClipOval>(
          find.ancestor(of: mark, matching: find.byType(ClipOval)),
        );
        expect(clip.clipBehavior, Clip.antiAlias);
      });

      testWidgets('has no ground and no clip under the dark theme', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _under(AppTheme.darkTheme, site.value.build()),
        );

        expect(_wellOf(site.key), findsNothing);
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
          findsNothing,
        );
        final ClipOval clip = tester.widget<ClipOval>(
          find.ancestor(
            of: find.byKey(Key(site.key)),
            matching: find.byType(ClipOval),
          ),
        );
        expect(clip.clipBehavior, Clip.none);
      });
    });
  }
}
