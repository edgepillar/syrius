import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/segment.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

const Key _tabular = ValueKey<String>('tabular_track');
const Key _proportional = ValueKey<String>('proportional_track');

Widget _selector(AppTokens tokens, {required bool tabular}) => Segment<int>(
  key: tabular ? _tabular : _proportional,
  keyPrefix: tabular ? 'tabular' : 'proportional',
  items: <SegmentItem<int>>[
    for (final int count in <int>[12, 24]) SegmentItem<int>(
      value: count,
      label: '$count words',
      labelStyle: tabular ? tokens.compactText : tokens.compactText.copyWith(
        // A diagnostic fixture only. Product numbers retain tabular figures.
        fontFeatures: const <FontFeature>[FontFeature('tnum', 0)],
      ),
    ),
  ],
  selected: 12,
  onChanged: (_) => throw StateError('Layout measurement must not select'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final FontLoader fonts = FontLoader(kSansFontFamily);
    fonts.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
    await fonts.load();
  });

  testWidgets('original font isolates the numeric selector width difference',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    for (final bool light in <bool>[false, true]) {
      await tester.pumpWidget(MaterialApp(
        theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
        home: Scaffold(body: Builder(
          builder: (BuildContext context) {
            final AppTokens tokens = AppTokens.of(context);
            expect(tokens.compactText.fontFeatures,
                const <FontFeature>[FontFeature.tabularFigures()]);
            return Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _selector(tokens, tabular: true),
                  _selector(tokens, tabular: false),
                ],
              ),
            );
          },
        )),
      ));
      await tester.pump();
      final double tabular = tester.getSize(find.byKey(_tabular)).width;
      final double proportional =
          tester.getSize(find.byKey(_proportional)).width;
      // Raw font-table advances predict 3.003 px before shaping. The
      // genuine font and Segment are measured here, with kerning allowed.
      expect(tabular - proportional, inExclusiveRange(2.5, 3.5));
      for (final String prefix in <String>['tabular', 'proportional']) {
        final double cells = <int>[12, 24].fold<double>(0,
          (double sum, int count) => sum + tester.getSize(
            find.byKey(Segment.keyOf(prefix, count)),
          ).width,
        );
        expect(prefix == 'tabular' ? tabular : proportional,
            closeTo(cells + 8, 0.01));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
