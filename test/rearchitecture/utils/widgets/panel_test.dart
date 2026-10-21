import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

// The app theme: its divider takes 1 px, Material's default takes 16.
Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(
    body: SizedBox(width: 400, height: 600, child: child),
  ),
);

void main() {
  group('Panel', () {
    testWidgets('a titled panel fills the height it is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Panel(
            key: Key('panel'),
            title: 'To collect',
            child: SizedBox(height: 30),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('panel'))).height, 600);
    });

    testWidgets(
      'shrinkWrap makes it as tall as its title row and body, in a column '
      'that gives no height',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(
            const Column(
              children: <Widget>[
                Panel(
                  key: Key('panel'),
                  title: 'To collect',
                  shrinkWrap: true,
                  padding: EdgeInsets.all(10),
                  child: SizedBox(height: 30),
                ),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // 48 title row, 1 divider, 10 + 30 + 10 body.
        expect(tester.getSize(find.byKey(const Key('panel'))).height, 99);
      },
    );

    testWidgets('an untitled panel is as tall as its body either way', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              Panel(
                key: Key('panel'),
                shrinkWrap: true,
                child: SizedBox(height: 30),
              ),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('panel'))).height, 30);
    });
  });
}
