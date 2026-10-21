import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/color_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A ZTS token whose colour is [rgb]: a token's own colour is the last three
/// bytes of its standard.
TokenStandard _ztsOfColour(int rgb) => TokenStandard.fromBytes(<int>[
  ...List<int>.filled(TokenStandard.coreSize - 3, 7),
  (rgb >> 16) & 0xFF,
  (rgb >> 8) & 0xFF,
  rgb & 0xFF,
]);

/// The WCAG contrast ratio of two colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

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
  final TokenStandard black = emptyZts;
  final TokenStandard nearWhite = _ztsOfColour(0xF2F2F2);
  final TokenStandard mid = _ztsOfColour(0x808080);

  test('the made-up standards carry the colours they are named for', () {
    expect(ColorUtils.getTokenColor(black), const Color(0xFF000000));
    expect(ColorUtils.getTokenColor(nearWhite), const Color(0xFFF2F2F2));
    expect(ColorUtils.getTokenColor(mid), const Color(0xFF808080));
  });

  final Map<String, ThemeData> themes = <String, ThemeData>{
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    group('cardTokenInk in the ${entry.key} theme', () {
      late BuildContext context;
      late Color card;
      late Color body;
      late AppTokens tokens;

      Future<void> pumpTheme(WidgetTester tester) async {
        context = await _contextUnder(tester, entry.value);
        final ThemeData theme = Theme.of(context);
        // A Panel is painted in the colour scheme's primary.
        card = theme.colorScheme.primary;
        body = theme.textTheme.bodyLarge!.color!;
        tokens = AppTokens.of(context);
      }

      testWidgets('ZNN takes the theme ZNN ink', (WidgetTester tester) async {
        await pumpTheme(tester);
        expect(cardTokenInk(kZnnCoin.tokenStandard, context), tokens.znnInk);
      });

      testWidgets('QSR takes the theme QSR ink', (WidgetTester tester) async {
        await pumpTheme(tester);
        expect(cardTokenInk(kQsrCoin.tokenStandard, context), tokens.qsrInk);
      });

      testWidgets('a mid colour keeps its own colour', (
        WidgetTester tester,
      ) async {
        await pumpTheme(tester);
        expect(cardTokenInk(mid, context), const Color(0xFF808080));
      });

      testWidgets('black keeps its colour only on the light card', (
        WidgetTester tester,
      ) async {
        await pumpTheme(tester);
        expect(
          cardTokenInk(black, context),
          entry.key == 'light' ? const Color(0xFF000000) : body,
        );
      });

      testWidgets('near white keeps its colour only on the dark card', (
        WidgetTester tester,
      ) async {
        await pumpTheme(tester);
        expect(
          cardTokenInk(nearWhite, context),
          entry.key == 'dark' ? const Color(0xFFF2F2F2) : body,
        );
      });

      testWidgets('every answer is about 3 to 1 against the card', (
        WidgetTester tester,
      ) async {
        await pumpTheme(tester);
        for (final TokenStandard zts in <TokenStandard>[
          black,
          nearWhite,
          mid,
          kZnnCoin.tokenStandard,
          kQsrCoin.tokenStandard,
        ]) {
          expect(
            _contrast(cardTokenInk(zts, context), card),
            greaterThanOrEqualTo(2.9),
            reason: '$zts',
          );
        }
      });
    });
  }

  group('cardTokenInk without a context', () {
    test('gives the dark-theme answers it gave before the rule', () {
      expect(cardTokenInk(kZnnCoin.tokenStandard), AppColors.znnColor);
      expect(cardTokenInk(kQsrCoin.tokenStandard), AppColors.qsrInk);
      expect(cardTokenInk(mid), const Color(0xFF808080));
    });

    test('keeps a token its own colour, which one of the cards can show', () {
      // Unknown theme: no colour is replaced, since body ink for one theme
      // would vanish on the other. Black still reads on the light card and
      // near white on the dark one.
      expect(cardTokenInk(black), const Color(0xFF000000));
      expect(cardTokenInk(nearWhite), const Color(0xFFF2F2F2));
    });
  });
}
