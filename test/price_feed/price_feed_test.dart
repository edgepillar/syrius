import 'dart:io';
import 'dart:typed_data';

// Pinned by flutter_test, which runs every widget test inside it.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/price_feed.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

const String _first = '{"zenon-2":{"usd":0.62},"quasar":{"usd":0.031}}';
const String _second = '{"zenon-2":{"usd":0.7},"quasar":{"usd":0.04}}';

final Usd _znnFirst = Usd.ofJson(0.62)!;
final Usd _znnSecond = Usd.ofJson(0.7)!;

/// Stands in for CoinGecko: counts what it is asked and answers with
/// whatever [answer] holds then.
class _Gecko {
  int asked = 0;
  final List<Uri> urls = <Uri>[];

  /// A body, or an [Exception] to throw.
  Object answer = _first;

  Future<String> call(Uri url) async {
    asked++;
    urls.add(url);
    final Object now = answer;
    if (now is Exception) {
      throw now;
    }
    return now as String;
  }
}

/// A feed on [async]'s clock, asking [gecko].
PriceFeed _feed(FakeAsync async, _Gecko gecko) {
  final DateTime start = DateTime.utc(2026, 10, 13, 12);
  return PriceFeed(
    request: gecko.call,
    now: () => start.add(async.elapsed),
  );
}

void _listener() {}

void _other() {}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('price_feed_test');
    Hive.init(dir.path);
    // No box: the setting reads as never chosen, which is on.
    sharedPrefsService = null;
  });

  tearDown(() async {
    sharedPrefsService = null;
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  /// Preferences in memory, with [stored] under the setting's key.
  Future<void> preferences([Object? stored]) async {
    final Box<dynamic> box =
        await Hive.openBox<dynamic>(kSharedPrefsBox, bytes: Uint8List(0));
    if (stored != null) {
      await box.put(kDollarValuesKey, stored);
    }
    sharedPrefsService = await SharedPrefsService.getInstance();
  }

  group('the timer', () {
    test('nothing is asked while nobody listens', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko);
        async.elapse(const Duration(minutes: 10));
        expect(gecko.asked, 0);
        expect(feed.priceOf(PricedCoin.znn), isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('the first listener asks at once, then once a minute', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.flushMicrotasks();
        expect(gecko.asked, 1);
        expect(gecko.urls.single, PriceFeed.url);
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);
        expect(feed.priceOf(PricedCoin.qsr), Usd.ofJson(0.031));

        async.elapse(const Duration(seconds: 59));
        expect(gecko.asked, 1);
        async.elapse(const Duration(seconds: 1));
        expect(gecko.asked, 2);
        async.elapse(const Duration(minutes: 3));
        expect(gecko.asked, 5);
        feed.removeListener(_listener);
      });
    });

    test('a second listener starts no second timer', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.elapse(const Duration(seconds: 20));
        feed.addListener(_other);
        async.flushMicrotasks();
        expect(gecko.asked, 1);
        expect(async.pendingTimers, hasLength(1));

        async.elapse(const Duration(seconds: 40));
        expect(gecko.asked, 2);
        feed
          ..removeListener(_listener)
          ..removeListener(_other);
      });
    });

    test('it runs until the last listener goes, and stops then', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)
          ..addListener(_listener)
          ..addListener(_other);
        async.flushMicrotasks();
        feed.removeListener(_listener);
        async.elapse(const Duration(minutes: 1));
        expect(gecko.asked, 2);

        feed.removeListener(_other);
        expect(async.pendingTimers, isEmpty);
        async.elapse(const Duration(minutes: 10));
        expect(gecko.asked, 2);
        // What was last answered is still there for the next screen.
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);
      });
    });

    test('a listener back within the minute waits out the rest of it', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.elapse(const Duration(seconds: 10));
        feed.removeListener(_listener);
        async.elapse(const Duration(seconds: 20));

        // 30 s after the answer: not old enough to ask again.
        feed.addListener(_listener);
        async.flushMicrotasks();
        expect(gecko.asked, 1);
        async.elapse(const Duration(seconds: 29));
        expect(gecko.asked, 1);
        async.elapse(const Duration(seconds: 1));
        expect(gecko.asked, 2);
        // And every minute from there.
        async.elapse(const Duration(minutes: 1));
        expect(gecko.asked, 3);
        feed.removeListener(_listener);
      });
    });

    test('a listener back after more than a minute asks at once', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.flushMicrotasks();
        feed.removeListener(_listener);
        async.elapse(const Duration(seconds: 61));
        expect(gecko.asked, 1);

        feed.addListener(_listener);
        async.flushMicrotasks();
        expect(gecko.asked, 2);
        feed.removeListener(_listener);
      });
    });

    test('opening and closing a screen over and over asks once a minute', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko()..answer = const SocketException('down');
        final PriceFeed feed = _feed(async, gecko);
        for (int i = 0; i < 30; i++) {
          feed.addListener(_listener);
          async.elapse(const Duration(seconds: 1));
          feed.removeListener(_listener);
          async.elapse(const Duration(seconds: 1));
        }
        // A minute of it, with every request failing: the one at the start.
        expect(gecko.asked, 1);
      });
    });

    test('listeners hear of a new price and not of the same one again', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        int heard = 0;
        void count() => heard++;
        final PriceFeed feed = _feed(async, gecko)..addListener(count);
        async.flushMicrotasks();
        expect(heard, 1);
        async.elapse(const Duration(minutes: 1));
        expect(heard, 1);
        gecko.answer = _second;
        async.elapse(const Duration(minutes: 1));
        expect(heard, 2);
        expect(feed.priceOf(PricedCoin.znn), _znnSecond);
        feed.removeListener(count);
      });
    });
  });

  group('a failed request', () {
    test('keeps the last answer and is not tried again before the tick', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        int heard = 0;
        void count() => heard++;
        final PriceFeed feed = _feed(async, gecko)..addListener(count);
        async.flushMicrotasks();
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);

        gecko.answer = const SocketException('no route');
        async.elapse(const Duration(minutes: 1));
        expect(gecko.asked, 2);
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);
        expect(feed.priceOf(PricedCoin.qsr), Usd.ofJson(0.031));
        expect(heard, 1);

        // No retry in between: the next request is the next minute's.
        async.elapse(const Duration(seconds: 59));
        expect(gecko.asked, 2);
        gecko.answer = _second;
        async.elapse(const Duration(seconds: 1));
        expect(gecko.asked, 3);
        expect(feed.priceOf(PricedCoin.znn), _znnSecond);
        feed.removeListener(count);
      });
    });

    test('an answer that is not JSON is a failed request', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.flushMicrotasks();
        gecko.answer = '<html>Too many requests</html>';
        async.elapse(const Duration(minutes: 1));
        expect(gecko.asked, 2);
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);
        feed.removeListener(_listener);
      });
    });

    test('a first request that fails leaves no price', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko()
          ..answer = const HttpException('HTTP 429');
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.flushMicrotasks();
        expect(gecko.asked, 1);
        expect(feed.priceOf(PricedCoin.znn), isNull);
        feed.removeListener(_listener);
      });
    });

    test('an answer after the feed is disposed is dropped', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        _feed(async, gecko)
          ..addListener(_listener)
          ..dispose();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 5));
        expect(gecko.asked, 1);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('the setting', () {
    test('is on when nothing is stored, and when the entry is damaged',
        () async {
      expect(PriceFeed(request: _Gecko().call).enabled, isTrue);
      await preferences();
      expect(PriceFeed(request: _Gecko().call).enabled, isTrue);
      await sharedPrefsService!.put(kDollarValuesKey, 'yes');
      expect(PriceFeed(request: _Gecko().call).enabled, isTrue);
    });

    test('is on when the box has been closed', () async {
      await preferences(false);
      await sharedPrefsService!.close();
      expect(PriceFeed(request: _Gecko().call).enabled, isTrue);
    });

    test('off makes no request at all', () async {
      await preferences(false);
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        expect(feed.enabled, isFalse);
        async.elapse(const Duration(minutes: 10));
        expect(gecko.asked, 0);
        expect(async.pendingTimers, isEmpty);
        expect(feed.priceOf(PricedCoin.znn), isNull);
        feed.removeListener(_listener);
      });
    });

    test('turned off, it stops asking, hides the price and is stored',
        () async {
      await preferences();
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        int heard = 0;
        void count() => heard++;
        final PriceFeed feed = _feed(async, gecko)..addListener(count);
        async.flushMicrotasks();
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);

        feed.enabled = false;
        async.flushMicrotasks();
        expect(heard, 2);
        expect(feed.priceOf(PricedCoin.znn), isNull);
        expect(sharedPrefsService!.get(kDollarValuesKey), isFalse);
        async.elapse(const Duration(minutes: 10));
        expect(gecko.asked, 1);
        expect(async.pendingTimers, isEmpty);
        feed.removeListener(count);
      });
    });

    test('turned on with a screen open, it asks at once', () async {
      await preferences(false);
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..addListener(_listener);
        async.elapse(const Duration(minutes: 2));
        expect(gecko.asked, 0);

        feed.enabled = true;
        async.flushMicrotasks();
        expect(gecko.asked, 1);
        expect(feed.priceOf(PricedCoin.znn), _znnFirst);
        expect(sharedPrefsService!.get(kDollarValuesKey), isTrue);
        async.elapse(const Duration(minutes: 1));
        expect(gecko.asked, 2);
        feed.removeListener(_listener);
      });
    });

    test('turned on with no screen open, it asks nothing', () async {
      await preferences(false);
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)..enabled = true;
        async.elapse(const Duration(minutes: 5));
        expect(gecko.asked, 0);
        expect(feed.enabled, isTrue);
      });
    });

    test('changes with no box at all, for as long as the wallet runs', () {
      fakeAsync((FakeAsync async) {
        final _Gecko gecko = _Gecko();
        final PriceFeed feed = _feed(async, gecko)
          ..addListener(_listener)
          ..enabled = false;
        async.elapse(const Duration(minutes: 5));
        expect(feed.enabled, isFalse);
        expect(gecko.asked, 1);
        feed.removeListener(_listener);
      });
    });
  });

  test('the wallet has one feed', () {
    expect(PriceFeed.instance, same(PriceFeed.instance));
  });
}
