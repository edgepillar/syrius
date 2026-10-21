import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/dollar_text.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

const String _prices = '{"zenon-2":{"usd":0.62},"quasar":{"usd":0.031}}';

/// 1,204.5 ZNN and 12,880 QSR, the mockup's balances, in base units.
final BigInt _znn = BigInt.parse('120450000000');
final BigInt _qsr = BigInt.parse('1288000000000');

/// Stands in for CoinGecko.
class _Gecko {
  int asked = 0;
  String answer = _prices;

  /// When set, the request waits for it: an answer that has not come yet.
  Completer<String>? pending;

  Future<String> call(Uri url) {
    asked++;
    return pending?.future ?? Future<String>.value(answer);
  }
}

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// The one text drawn, or null when nothing is.
String? _drawn(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byType(DollarText),
      matching: find.byType(Text),
    ),
  );
  return texts.isEmpty ? null : texts.single.data;
}

void main() {
  late _Gecko gecko;
  late PriceFeed feed;

  setUp(() {
    sharedPrefsService = null;
    gecko = _Gecko();
    feed = PriceFeed(request: gecko.call);
  });

  tearDown(() => sharedPrefsService = null);

  testWidgets('an amount of ZNN is drawn in dollars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), r'$746.79');
    expect(gecko.asked, 1);
  });

  testWidgets('an amount of QSR is drawn at its own price', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _qsr,
          decimals: 8,
          coin: PricedCoin.qsr,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), r'$399.28');
  });

  testWidgets('an estimate has the sign in front', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          approx: true,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), r'≈ $746.79');
  });

  testWidgets('two amounts are one sum, marked as an estimate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText.sum(
          <CoinAmount>[
            (amount: _znn, decimals: 8, coin: PricedCoin.znn),
            (amount: _qsr, decimals: 8, coin: PricedCoin.qsr),
          ],
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), r'≈ $1,146.07');
    // One feed, one request, however many amounts.
    expect(gecko.asked, 1);
  });

  testWidgets('hidden draws dots, and keeps the sign of an estimate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: <Widget>[
            DollarText(
              amount: _znn,
              decimals: 8,
              coin: PricedCoin.znn,
              hidden: true,
              feed: feed,
            ),
            DollarText(
              amount: _qsr,
              decimals: 8,
              coin: PricedCoin.qsr,
              approx: true,
              hidden: true,
              feed: feed,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('••••'), findsOneWidget);
    expect(find.text('≈ ••••'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('nothing is drawn before the first price', (
    WidgetTester tester,
  ) async {
    gecko.pending = Completer<String>();
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), isNull);
    expect(tester.getSize(find.byType(DollarText)), Size.zero);

    // And it appears when the answer does, with nothing else rebuilt.
    gecko.pending!.complete(_prices);
    await tester.pump();
    await tester.pump();
    expect(_drawn(tester), r'$746.79');
  });

  testWidgets('hidden draws nothing either while there is no price', (
    WidgetTester tester,
  ) async {
    gecko.pending = Completer<String>();
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          hidden: true,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), isNull);
  });

  testWidgets('a token that is neither coin draws nothing and asks nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: null,
          feed: feed,
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 5));
    expect(_drawn(tester), isNull);
    expect(gecko.asked, 0);
  });

  testWidgets('a sum with a token that has no price is not drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText.sum(
          <CoinAmount>[
            (amount: _znn, decimals: 8, coin: PricedCoin.znn),
            (amount: BigInt.from(500), decimals: 0, coin: null),
          ],
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), isNull);
    expect(gecko.asked, 0);
  });

  testWidgets('a sum is not drawn while one of its prices is missing', (
    WidgetTester tester,
  ) async {
    gecko.answer = '{"zenon-2":{"usd":0.62}}';
    await tester.pumpWidget(
      _app(
        DollarText.sum(
          <CoinAmount>[
            (amount: _znn, decimals: 8, coin: PricedCoin.znn),
            (amount: _qsr, decimals: 8, coin: PricedCoin.qsr),
          ],
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(_drawn(tester), isNull);
  });

  group('the setting', () {
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('dollar_text_test');
      Hive.init(dir.path);
      final Box<dynamic> box =
          await Hive.openBox<dynamic>(kSharedPrefsBox, bytes: Uint8List(0));
      await box.put(kDollarValuesKey, false);
      sharedPrefsService = await SharedPrefsService.getInstance();
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    testWidgets('off draws nothing and asks nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DollarText(
            amount: _znn,
            decimals: 8,
            coin: PricedCoin.znn,
            feed: feed,
          ),
        ),
      );
      await tester.pump(const Duration(minutes: 5));
      expect(_drawn(tester), isNull);
      expect(gecko.asked, 0);
    });

    testWidgets('switched on and off, what is on screen follows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          DollarText(
            amount: _znn,
            decimals: 8,
            coin: PricedCoin.znn,
            feed: feed,
          ),
        ),
      );
      await tester.pump();
      expect(_drawn(tester), isNull);

      feed.enabled = true;
      await tester.pump();
      await tester.pump();
      expect(_drawn(tester), r'$746.79');

      feed.enabled = false;
      await tester.pump();
      expect(_drawn(tester), isNull);
    });
  });

  testWidgets('it asks only while it is mounted', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(gecko.asked, 2);

    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pump(const Duration(minutes: 10));
    expect(gecko.asked, 2);
  });

  testWidgets('a new price is drawn when it arrives', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    gecko.answer = '{"zenon-2":{"usd":0.0004},"quasar":{"usd":0.031}}';
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(_drawn(tester), r'$0.4818');
  });

  testWidgets('a widget given another coin or amount follows it', (
    WidgetTester tester,
  ) async {
    Widget of(BigInt amount, PricedCoin? coin) => _app(
          DollarText(amount: amount, decimals: 8, coin: coin, feed: feed),
        );
    await tester.pumpWidget(of(_znn, PricedCoin.znn));
    await tester.pump();
    await tester.pumpWidget(of(_qsr, PricedCoin.qsr));
    expect(_drawn(tester), r'$399.28');
    await tester.pumpWidget(of(_qsr, null));
    expect(_drawn(tester), isNull);
    // No longer listening, so no longer asking.
    await tester.pump(const Duration(minutes: 5));
    expect(gecko.asked, 1);
    await tester.pumpWidget(of(_znn, PricedCoin.znn));
    await tester.pump();
    expect(_drawn(tester), r'$746.79');
  });

  testWidgets('the look: faint, mono, 13 px', (WidgetTester tester) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    final Text text = tester.widget<Text>(find.text(r'$746.79'));
    final TextStyle style = text.style!;
    expect(style.fontSize, 13);
    expect(style.fontFamily, kMonoFontFamily);
    expect(style.fontFamilyFallback, kFontFamilyFallback);
    expect(style.fontWeight, FontWeight.w400);
    final BuildContext context = tester.element(find.byType(DollarText));
    expect(style.color, AppTokens.of(context).faint);
    expect(text.maxLines, 1);
  });

  testWidgets('the colour can be the stronger one, for the total', (
    WidgetTester tester,
  ) async {
    const Color dim = Color(0xFFA5AAA5);
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          color: dim,
          feed: feed,
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<Text>(find.text(r'$746.79')).style!.color, dim);
  });

  testWidgets('left to right under a right-to-left interface, at its start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DollarText(
          amount: _znn,
          decimals: 8,
          coin: PricedCoin.znn,
          approx: true,
          feed: feed,
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pump();
    final Finder text = find.text(r'≈ $746.79');
    expect(
      Directionality.of(tester.element(text)),
      TextDirection.ltr,
    );
    expect(tester.widget<Text>(text).textAlign, TextAlign.right);
  });
}
