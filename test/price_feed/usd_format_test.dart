import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';

/// A price as CoinGecko would send it.
Usd _price(num dollars) => Usd.ofJson(dollars)!;

/// Whole and fractional coins as base units of a coin with 8 decimals.
BigInt _coins(String text) {
  final List<String> parts = text.split('.');
  final String fraction = (parts.length > 1 ? parts[1] : '').padRight(8, '0');
  return BigInt.parse('${parts[0]}$fraction');
}

/// Dollars written as a plain decimal, formatted.
String _format(String dollars, {bool approx = false}) {
  final List<String> parts = dollars.replaceFirst('-', '').split('.');
  final String fraction = parts.length > 1 ? parts[1] : '';
  final BigInt units = BigInt.parse('${parts[0]}$fraction');
  return Usd(dollars.startsWith('-') ? -units : units, fraction.length)
      .format(approx: approx);
}

void main() {
  group('the README examples', () {
    test('a balance: two places and the dollar sign', () {
      expect(_price(0.62).worth(_coins('1204.5'), 8).format(), r'$746.79');
      expect(_price(0.031).worth(_coins('12880'), 8).format(), r'$399.28');
    });

    test('under a dollar: four places', () {
      expect(_price(0.5704).worth(_coins('1'), 8).format(), r'$0.5704');
    });

    test('a sum takes the sign in front, with a space', () {
      final Usd sum = _price(0.62).worth(_coins('1204.5'), 8) +
          _price(0.031).worth(_coins('12880'), 8);
      expect(sum.format(approx: true), r'≈ $1,146.07');
    });
  });

  group('places', () {
    test('zero is under a dollar, so four places, as the extension', () {
      expect(_format('0'), r'$0.0000');
      expect(_price(0.62).worth(BigInt.zero, 8).format(), r'$0.0000');
    });

    test('under a cent is still told apart', () {
      expect(_format('0.03'), r'$0.0300');
      expect(_format('0.0003'), r'$0.0003');
      expect(_format('0.00005'), r'$0.0001');
      expect(_format('0.00004'), r'$0.0000');
    });

    test('exactly a dollar and over: two places', () {
      expect(_format('1'), r'$1.00');
      expect(_format('1.005'), r'$1.01');
      expect(_format('1.004'), r'$1.00');
      expect(_format('12.3456'), r'$12.35');
    });

    test('the places are chosen before rounding, as toFixed does', () {
      expect(_format('0.99994'), r'$0.9999');
      expect(_format('0.99996'), r'$1.0000');
    });

    test('one base unit of a coin is not nothing but rounds to it', () {
      expect(_price(0.62).worth(BigInt.one, 8).format(), r'$0.0000');
    });
  });

  group('thousands', () {
    test('are grouped from the right', () {
      expect(_format('999.99'), r'$999.99');
      expect(_format('999.995'), r'$1,000.00');
      expect(_format('1000'), r'$1,000.00');
      expect(_format('12345.678'), r'$12,345.68');
      expect(_format('1234567.891'), r'$1,234,567.89');
    });

    test('a sum no double can hold keeps every digit', () {
      // 90,071,992.54740993 coins is 2^53 + 1 base units: as a double the
      // last unit is lost before the price is applied.
      final BigInt amount = BigInt.parse('9007199254740993');
      expect(
        _price(1000000).worth(amount, 8).format(),
        r'$90,071,992,547,409.93',
      );
      // The whole supply of ZNN, at a price with six places.
      expect(
        _price(0.157929).worth(BigInt.parse('1190555916718187'), 8).format(),
        r'$1,880,233.05',
      );
    });
  });

  group('the sign', () {
    test('goes before the dollar sign', () {
      expect(_format('-5.2'), r'-$5.20');
      expect(_format('-0.5'), r'-$0.5000');
      expect(_format('-1234.5', approx: true), r'≈ -$1,234.50');
    });

    test('is dropped when what is left is nothing', () {
      expect(_format('-0.00001'), r'$0.0000');
    });
  });

  group('adding', () {
    test('is exact across scales, either way round', () {
      final Usd cents = Usd(BigInt.from(150), 2);
      final Usd fine = Usd(BigInt.from(250001), 5);
      expect(cents + fine, Usd(BigInt.from(400001), 5));
      expect(fine + cents, Usd(BigInt.from(400001), 5));
      expect((cents + fine).format(), r'$4.00');
    });
  });

  group('a price from JSON', () {
    test('is the decimal that was sent, not the double nearest it', () {
      expect(_price(0.5704), Usd(BigInt.from(570400000000), 12));
      expect(_price(0.1) + _price(0.2), _price(0.3));
      expect(_price(3), Usd(BigInt.parse('3000000000000'), 12));
    });

    test('is nothing for what is not a finite number', () {
      expect(Usd.ofJson(null), isNull);
      expect(Usd.ofJson('0.57'), isNull);
      expect(Usd.ofJson(true), isNull);
      expect(Usd.ofJson(double.nan), isNull);
      expect(Usd.ofJson(double.infinity), isNull);
      expect(Usd.ofJson(1e21), isNull);
    });
  });

  group('the answer', () {
    test('carries both coins', () {
      final Map<PricedCoin, Usd> prices = PriceFeed.parse(
        '{"zenon-2":{"usd":0.157929},"quasar":{"usd":0.148823}}',
      );
      expect(prices[PricedCoin.znn], _price(0.157929));
      expect(prices[PricedCoin.qsr], _price(0.148823));
    });

    test('with one coin missing still prices the other', () {
      final Map<PricedCoin, Usd> prices = PriceFeed.parse(
        '{"zenon-2":{"usd":0.62},"quasar":{"usd":"soon"}}',
      );
      expect(prices, <PricedCoin, Usd>{PricedCoin.znn: _price(0.62)});
      expect(PriceFeed.parse('{"zenon-2":{}}'), isEmpty);
      expect(PriceFeed.parse('[]'), isEmpty);
    });

    test('that is not JSON throws', () {
      expect(() => PriceFeed.parse('<html>'), throwsFormatException);
    });
  });

  group('the request', () {
    test('is the one the extension sends: both ids, a bare comma', () {
      expect(
        PriceFeed.url.toString(),
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=zenon-2,quasar&vs_currencies=usd',
      );
    });

    test('a coin is known by its token standard and no other token is', () {
      expect(
        PricedCoin.ofTokenStandard('zts1znnxxxxxxxxxxxxx9z4ulx'),
        PricedCoin.znn,
      );
      expect(
        PricedCoin.ofTokenStandard('zts1qsrxxxxxxxxxxxxxmrhjll'),
        PricedCoin.qsr,
      );
      expect(PricedCoin.ofTokenStandard('zts1qqqqqqqqqqqqqqqqtq587y'), isNull);
    });
  });
}
