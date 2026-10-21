/// Dollar prices for ZNN and QSR, and how a dollar value is written.
///
/// As the Syrius extension does it (`tokenPrice.js`, `usePriceFeed.js` and
/// `formatUsd` in `format.js` there): one request to CoinGecko for both
/// coins, once a minute, only while something on screen shows a value.
/// They are mainnet's prices on every chain: a devnet has no coin of its
/// own to price.
///
/// One thing the extension does not have: the request can be switched off
/// ([kDollarValuesKey]). A desktop wallet that asks a third party for
/// something should be able to stop asking.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';

final Logger _log = Logger('PriceFeed');

/// Where Settings > Display > Dollar values is kept, in the shared prefs
/// box: a bool, on when absent.
const String kDollarValuesKey = 'dollar_values';

/// The coins that have a dollar price. No other token has one, so no other
/// token has a dollar value.
enum PricedCoin {
  /// ZNN. CoinGecko's plain `zenon` is an unrelated project.
  znn('zenon-2', 'zts1znnxxxxxxxxxxxxx9z4ulx'),

  /// QSR.
  qsr('quasar', 'zts1qsrxxxxxxxxxxxxxmrhjll');

  const PricedCoin(this.coinGeckoId, this.tokenStandard);

  /// What CoinGecko calls the coin. Neither id is the ticker.
  final String coinGeckoId;

  /// The coin's token standard, as a string.
  final String tokenStandard;

  /// The coin with [tokenStandard], or null for every other token.
  static PricedCoin? ofTokenStandard(String tokenStandard) {
    for (final PricedCoin coin in values) {
      if (coin.tokenStandard == tokenStandard) {
        return coin;
      }
    }
    return null;
  }
}

/// Dollars as an exact decimal: [units] over ten to the [scale].
///
/// A balance is an integer of base units that does not fit in a double, so
/// its worth is worked out in integers too and rounded once, in [format].
@immutable
class Usd {
  /// [units] over ten to the [scale] dollars.
  const Usd(this.units, this.scale) : assert(scale >= 0, 'a negative scale');

  /// The places a price is kept to. CoinGecko sends six or so.
  static const int priceScale = 12;

  /// A price from a JSON number, or null for anything else. As the
  /// extension, which takes any finite number and nothing but a number.
  static Usd? ofJson(Object? value) {
    // From 1e21 on a double is written with an exponent, which is not a
    // price anyone will be sent.
    if (value is! num || !value.isFinite || value.abs() >= 1e21) {
      return null;
    }
    // Rounded at the twelfth place, this is the decimal that was sent:
    // 0.5704 as a double is off by about 1e-17.
    final String digits = value.toDouble().toStringAsFixed(priceScale);
    return Usd(BigInt.parse(digits.replaceFirst('.', '')), priceScale);
  }

  /// The numerator.
  final BigInt units;

  /// The number of decimal places [units] carries.
  final int scale;

  /// What [amount] base units of a coin with [decimals] are worth at this
  /// price for one whole coin. Nothing is rounded.
  Usd worth(BigInt amount, int decimals) =>
      Usd(units * amount, scale + decimals);

  /// The two together, exactly.
  Usd operator +(Usd other) {
    if (scale < other.scale) {
      return other + this;
    }
    return Usd(units + other.units * _tenTo(scale - other.scale), scale);
  }

  /// `$746.79`, and four places under a dollar, `$0.5704`: small holdings
  /// are worth the two more, since $0.03 and $0.0003 read very differently.
  /// Thousands are grouped. [approx] puts `≈ ` in front, for a sum or an
  /// estimate.
  ///
  /// The extension's `formatUsd`, on the exact value: the places are chosen
  /// before rounding, so $0.99996 is written `$1.0000`, and zero `$0.0000`.
  /// A half rounds away from zero.
  ///
  /// Latin digits and no direction mark. Whatever draws it pins it left to
  /// right, or a right-to-left interface moves the sign.
  String format({bool approx = false}) {
    final BigInt one = _tenTo(scale);
    final BigInt magnitude = units.abs();
    final int places = magnitude < one ? 4 : 2;
    final BigInt rounded =
        (magnitude * _tenTo(places) * BigInt.two + one) ~/ (one * BigInt.two);
    final String digits = rounded.toString().padLeft(places + 1, '0');
    final String whole = digits.substring(0, digits.length - places);
    final String fraction = digits.substring(digits.length - places);
    final StringBuffer text = StringBuffer();
    if (approx) {
      text.write('≈ ');
    }
    // Minus nothing is nothing.
    if (units.isNegative && rounded != BigInt.zero) {
      text.write('-');
    }
    text.write(r'$');
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        text.write(',');
      }
      text.write(whole[i]);
    }
    text
      ..write('.')
      ..write(fraction);
    return text.toString();
  }

  static BigInt _tenTo(int exponent) => BigInt.from(10).pow(exponent);

  /// The same numerator and scale. `Usd(5, 1)` and `Usd(50, 2)` are the
  /// same money and not equal; prices all have [priceScale], which is what
  /// the feed compares.
  @override
  bool operator ==(Object other) =>
      other is Usd && other.units == units && other.scale == scale;

  @override
  int get hashCode => Object.hash(units, scale);

  @override
  String toString() => 'Usd($units, $scale)';
}

/// Sends one GET and gives the body back. Anything but a 200 with a body
/// throws an [Exception].
typedef PriceRequest = Future<String> Function(Uri url);

/// The last ZNN and QSR dollar prices.
///
/// It asks only while it has a listener, which is how "only while a screen
/// that shows a value is open" is kept: `DollarText` listens while it is
/// mounted and at no other time. Read a price with [priceOf] inside the
/// listener or the build it causes.
class PriceFeed extends ChangeNotifier {
  /// A feed that asks through [request] and reads the time from [now].
  /// Both are for tests; the wallet uses [instance].
  PriceFeed({PriceRequest? request, DateTime Function()? now})
      : _request = request ?? _httpGet,
        _now = now ?? DateTime.now;

  /// The wallet's one feed. A static is made when it is first read, so
  /// nothing at startup has to make it.
  static final PriceFeed instance = PriceFeed();

  /// How often it asks: often enough that a price feels live, and well
  /// inside CoinGecko's public rate limit.
  static const Duration interval = Duration(minutes: 1);

  /// The extension's request, character for character: both coins in one.
  /// Not built with `Uri.https`, which would write the comma as `%2C`.
  static final Uri url = Uri.parse(
    'https://api.coingecko.com/api/v3/simple/price'
    '?ids=${PricedCoin.znn.coinGeckoId},${PricedCoin.qsr.coinGeckoId}'
    '&vs_currencies=usd',
  );

  final PriceRequest _request;
  final DateTime Function() _now;

  Map<PricedCoin, Usd> _prices = const <PricedCoin, Usd>{};
  Timer? _timer;
  DateTime? _askedAt;
  bool _asking = false;
  bool _disposed = false;

  /// What the setting was last set to here. Null until then, and the box
  /// is read each time: the first widget may ask before the box is open.
  bool? _enabled;

  /// The prices in the body of an answer. A coin the answer has no finite
  /// number for has no price, rather than the whole answer being refused:
  /// the feed having nothing to say about one coin is no reason to blank
  /// the other. Throws [FormatException] when [body] is not JSON.
  static Map<PricedCoin, Usd> parse(String body) {
    final Object? json = jsonDecode(body);
    final Map<PricedCoin, Usd> prices = <PricedCoin, Usd>{};
    if (json is! Map<String, dynamic>) {
      return prices;
    }
    for (final PricedCoin coin in PricedCoin.values) {
      final Object? entry = json[coin.coinGeckoId];
      final Usd? price =
          entry is Map<String, dynamic> ? Usd.ofJson(entry['usd']) : null;
      if (price != null) {
        prices[coin] = price;
      }
    }
    return prices;
  }

  /// Whether dollar values are shown, and so whether anything is asked.
  ///
  /// Setting it stores it, starts or stops the asking, and tells the
  /// listeners. Settings must set it here and not in the box, or what is
  /// on screen does not hear of it.
  bool get enabled => _enabled ?? _stored();

  set enabled(bool value) {
    if (value == enabled) {
      return;
    }
    _enabled = value;
    unawaited(_store(value));
    if (value && hasListeners) {
      _start();
    } else {
      _stop();
    }
    notifyListeners();
  }

  /// The dollar price of one whole [coin]. Null before the first answer,
  /// when the last answer had none for it, and while the setting is off.
  Usd? priceOf(PricedCoin coin) => enabled ? _prices[coin] : null;

  @override
  void addListener(VoidCallback listener) {
    final bool first = !hasListeners;
    super.addListener(listener);
    if (first) {
      _start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _stop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }

  static bool _stored() {
    final Object? stored =
        sharedPrefsService?.get(kDollarValuesKey, defaultValue: true);
    // Anything but a bool is a damaged entry, and reads as never chosen.
    return stored is! bool || stored;
  }

  static Future<void> _store(bool value) async {
    try {
      await sharedPrefsService?.put(kDollarValuesKey, value);
      // What a closed box throws, as `SharedPrefsService.get` catches it.
      // The choice then holds until the wallet quits.
      // ignore: avoid_catching_errors
    } on HiveError catch (e) {
      _log.log(Level.WARNING, 'Could not store $kDollarValuesKey', e);
    }
  }

  void _start() {
    if (_timer != null || !enabled) {
      return;
    }
    // Counted from the last request, not the last answer: a screen opened
    // and closed during an outage must not turn into a request each time.
    final DateTime? asked = _askedAt;
    final Duration wait =
        asked == null ? Duration.zero : interval - _now().difference(asked);
    // Longer than the interval is a clock that was set back.
    if (wait <= Duration.zero || wait > interval) {
      _everyInterval();
    } else {
      _timer = Timer(wait, _everyInterval);
    }
  }

  void _everyInterval() {
    _timer = Timer.periodic(interval, (_) => unawaited(_ask()));
    unawaited(_ask());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One request. A failure leaves what was last answered and is not tried
  /// again before the next tick: a quiet minute is better than a wallet
  /// that hammers a price feed.
  Future<void> _ask() async {
    if (_asking) {
      return;
    }
    _asking = true;
    _askedAt = _now();
    try {
      final Map<PricedCoin, Usd> answer = parse(await _request(url));
      if (!_disposed && !mapEquals(answer, _prices)) {
        _prices = answer;
        notifyListeners();
      }
    } on Exception catch (e) {
      _log.log(Level.FINE, 'No price this time', e);
    } finally {
      _asking = false;
    }
  }
}

const Duration _kTimeout = Duration(seconds: 20);

/// A real answer is under a hundred bytes.
const int _kMaxBody = 64 << 10;

/// Over `dart:io`: `package:http` is only a transitive dependency here.
Future<String> _httpGet(Uri url) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = _kTimeout
    ..userAgent = 'syrius';
  try {
    // On the whole exchange, so a body that stalls is given up too.
    return await _read(client, url).timeout(_kTimeout);
  } finally {
    client.close(force: true);
  }
}

Future<String> _read(HttpClient client, Uri url) async {
  final HttpClientRequest request = await client.getUrl(url);
  // The one host named above and no other: a redirect is not an answer.
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  final HttpClientResponse response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('HTTP ${response.statusCode}', uri: url);
  }
  final BytesBuilder body = BytesBuilder(copy: false);
  await for (final List<int> chunk in response) {
    if (body.length + chunk.length > _kMaxBody) {
      throw HttpException('The answer is too long', uri: url);
    }
    body.add(chunk);
  }
  return utf8.decode(body.takeBytes());
}
