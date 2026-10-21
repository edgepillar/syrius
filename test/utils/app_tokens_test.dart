import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// Pumps an app under [theme] and returns the context of a widget inside it.
Future<BuildContext> _contextUnder(WidgetTester tester, ThemeData theme) async {
  late BuildContext found;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) {
          found = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return found;
}

void main() {
  group('AppTokens in the app themes', () {
    testWidgets('the light theme carries the light tokens', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextUnder(
        tester,
        AppTheme.lightTheme,
      );
      final AppTokens? tokens = Theme.of(context).extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens, AppTokens.light);
      expect(AppTokens.of(context), AppTokens.light);
    });

    testWidgets('the dark theme carries the dark tokens', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextUnder(
        tester,
        AppTheme.darkTheme,
      );
      final AppTokens? tokens = Theme.of(context).extension<AppTokens>();
      expect(tokens, isNotNull);
      expect(tokens, AppTokens.dark);
      expect(AppTokens.of(context), AppTokens.dark);
    });

    test('the two sets differ, so the checks above tell them apart', () {
      expect(AppTokens.dark, isNot(AppTokens.light));
    });
  });

  group('AppTokens.lerp', () {
    test('returns the ends at 0 and at 1', () {
      expect(AppTokens.dark.lerp(AppTokens.light, 0), AppTokens.dark);
      expect(AppTokens.dark.lerp(AppTokens.light, 1), AppTokens.light);
    });

    test('is between the ends at one half, for a colour and a double', () {
      // The two sets share their gaps and radius, so the double is checked
      // against an end that does not.
      final AppTokens wide = AppTokens.light.copyWith(panelGap: 30);
      final AppTokens mid = AppTokens.dark.lerp(wide, 0.5);

      expect(
        mid.faint,
        Color.lerp(AppTokens.dark.faint, AppTokens.light.faint, 0.5),
      );
      expect(mid.faint, isNot(AppTokens.dark.faint));
      expect(mid.faint, isNot(AppTokens.light.faint));

      expect(mid.panelGap, greaterThan(AppTokens.dark.panelGap));
      expect(mid.panelGap, lessThan(wide.panelGap));
      expect(mid.panelGap, (AppTokens.dark.panelGap + 30) / 2);
    });

    test('keeps its own values when there is nothing to move towards', () {
      expect(AppTokens.dark.lerp(null, 0.5), AppTokens.dark);
    });

    test('runs when ThemeData is lerped between the app themes', () {
      final ThemeData mid = ThemeData.lerp(
        AppTheme.darkTheme,
        AppTheme.lightTheme,
        0.5,
      );
      expect(
        mid.extension<AppTokens>(),
        AppTokens.dark.lerp(AppTokens.light, 0.5),
      );
    });
  });

  group('AppTokens.copyWith', () {
    test('changes the named field and keeps the rest', () {
      final AppTokens changed = AppTokens.dark.copyWith(cardGap: 99);
      expect(changed.cardGap, 99);
      expect(changed.copyWith(cardGap: AppTokens.dark.cardGap), AppTokens.dark);
    });
  });

  group('AppTokens.of without the app theme', () {
    testWidgets('a bare light MaterialApp gets the light tokens', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextUnder(
        tester,
        ThemeData(brightness: Brightness.light),
      );
      expect(Theme.of(context).extension<AppTokens>(), isNull);
      expect(AppTokens.of(context), AppTokens.light);
    });

    testWidgets('a bare dark MaterialApp gets the dark tokens', (
      WidgetTester tester,
    ) async {
      final BuildContext context = await _contextUnder(
        tester,
        ThemeData(brightness: Brightness.dark),
      );
      expect(Theme.of(context).extension<AppTokens>(), isNull);
      expect(AppTokens.of(context), AppTokens.dark);
    });
  });
}
