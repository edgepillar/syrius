// The channel as the app runs it: on and off, how long consent lasts, what a
// page learns before it is connected, and the syrius://request path.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_link.dart';

import 'support.dart';

Object? _decode(String text) => jsonDecode(
  utf8.decode(base64Url.decode(base64Url.normalize(text))),
);

Uri _link(
  String method, {
  Object? params,
  String id = '42',
  String callback = '$kSite/zenon/return',
}) => Uri(
  scheme: 'syrius',
  host: 'request',
  queryParameters: <String, String>{
    'method': method,
    'id': id,
    'callback': callback,
    if (params != null)
      'params': base64Url
          .encode(utf8.encode(jsonEncode(params)))
          .replaceAll('=', ''),
  },
);

void main() {
  late FakeWallet wallet;
  late MemoryStore store;
  late FakeClock clock;
  late List<Uri> opened;
  late DappBridgeChannel channel;

  setUp(() async {
    wallet = FakeWallet();
    store = MemoryStore();
    clock = FakeClock();
    opened = <Uri>[];
    channel = testChannel(
      wallet: wallet,
      store: store,
      clock: clock,
      opened: opened,
    );
    await channel.start();
  });

  tearDown(() => channel.close());

  group('before consent', () {
    test('the hello names the wallet and nothing about it', () async {
      final Page first = await Page.open(channel.port!);
      await first.result('znn_connect');
      final Page page = await Page.open(channel.port!, origin: kOther);
      expect(await page.hello.future, <String, Object?>{
        'wallet': 'syrius-desktop',
        'protocol': kDappBridgeProtocol,
      });
      await first.close();
      await page.close();
    });

    test('a page learns no address, chain or node, even with another '
        'origin connected and the wallet unlocked', () async {
      final Page connected = await Page.open(channel.port!);
      await connected.result('znn_connect');
      final Page page = await Page.open(channel.port!, origin: kOther);
      expect(await page.result('znn_accounts'), <String>[]);
      expect(await page.result('znn_chainId'), isNull);
      expect(await page.result('znn_nodeUrl'), isNull);
      expect(await page.code('znn_sign', 'hello'), 4100);
      wallet
        ..selected = kB
        ..chainId = 9;
      await settle();
      wallet.selected = kA;
      await settle();
      expect(page.events, isEmpty);
      expect(connected.events, isNotEmpty);
      await connected.close();
      await page.close();
    });
  });

  group('the switch', () {
    test('off: the port closes, open pages drop, and it is kept', () async {
      final Page page = await Page.open(channel.port!);
      final int port = channel.port!;
      await channel.setEnabled(enabled: false);
      expect(channel.port, isNull);
      expect(channel.enabled, isFalse);
      expect(store.values[kDappBridgeEnabledKey], isFalse);
      await expectLater(
        WebSocket.connect(
          'ws://127.0.0.1:$port',
          headers: <String, dynamic>{'Origin': kSite},
        ),
        throwsA(isA<SocketException>()),
      );
      expect(page.socket.closeCode, isNotNull);
      await page.close();

      // Restarted with the choice off, it stays off.
      final DappBridgeChannel again = testChannel(
        wallet: wallet,
        store: store,
        clock: clock,
      );
      await again.start();
      expect(again.port, isNull);
      await again.setEnabled(enabled: true);
      expect(again.port, isNotNull);
      await again.close();
    });

    test('off: a link gets no answer', () async {
      await channel.setEnabled(enabled: false);
      expect(await channel.handleLink(_link('znn_accounts')), isFalse);
      expect(opened, isEmpty);
    });

    test('changes fire on a switch and on a grant', () async {
      final List<void> seen = <void>[];
      final StreamSubscription<void> sub = channel.changes.listen(seen.add);
      await channel.setEnabled(enabled: false);
      await channel.setEnabled(enabled: true);
      final Page page = await Page.open(channel.port!);
      await page.result('znn_connect');
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, greaterThanOrEqualTo(3));
      await sub.cancel();
      await page.close();
    });

    test('two starts at once bind one port', () async {
      await channel.stop();
      await Future.wait(<Future<void>>[channel.start(), channel.start()]);
      expect(channel.port, isNotNull);
    });
  });

  group('consent', () {
    test('survives a restart of the wallet', () async {
      final Page page = await Page.open(channel.port!);
      await page.result('znn_connect');
      await page.close();
      await channel.stop();
      final DappBridgeChannel again = testChannel(
        wallet: wallet,
        store: store,
        clock: clock,
      );
      await again.start();
      final Page back = await Page.open(again.port!);
      expect(await back.result('znn_accounts'), <String>[kA]);
      await back.close();
      await again.close();
    });

    test('does not survive Disconnect in the wallet', () async {
      final Page page = await Page.open(channel.port!);
      await page.result('znn_connect');
      page.events.clear();
      await channel.disconnect(kSite);
      expect(await page.nextEvent(), <Object?>['accountsChanged', <String>[]]);
      expect(channel.sites, isEmpty);
      expect(await page.code('znn_sign', 'hello'), 4100);
      expect(await page.result('znn_accounts'), <String>[]);
      await page.close();
    });

    test('a store that does not parse means no consent', () {
      store.values[kDappBridgeConsentKey] = '{not json';
      expect(channel.sites, isEmpty);
      store.values[kDappBridgeConsentKey] = '{"$kSite": "z1"}';
      expect(channel.sites, isEmpty);
      store.values[kDappBridgeConsentKey] = '["$kSite"]';
      expect(channel.sites, isEmpty);
    });
  });

  group('syrius://request', () {
    test('parses the Android app form, and its Windows and path forms', () {
      final DappBridgeLinkRequest request = parseDappBridgeLink(
        _link('znn_sign', params: <String, Object?>{'message': 'hi'}),
      )!;
      expect(request.method, 'znn_sign');
      expect(request.params, <String, Object?>{'message': 'hi'});
      expect(request.id, '42');
      expect(request.requester, 'link:$kSite');

      // params as plain JSON rather than base64url
      const String plainJson =
          'syrius://request?method=znn_sign&id=1&callback=https://a.example/r'
          '&params=%7B%22message%22%3A%22hi%22%7D';
      for (final String raw in <String>[
        'syrius://request/?method=znn_accounts&id=1&callback=https://a.example/r',
        'syrius:request?method=znn_accounts&id=1&callback=https://a.example/r',
        plainJson,
      ]) {
        expect(parseDappBridgeLink(Uri.parse(raw)), isNotNull, reason: raw);
      }
      expect(
        parseDappBridgeLink(
          Uri.parse(
            'syrius://request?method=znn_accounts&callback=https://a.example/',
          ),
          now: DateTime.fromMillisecondsSinceEpoch(5),
        )!.id,
        'syrius-5',
      );
    });

    test('refuses what it cannot answer safely', () {
      for (final Uri link in <Uri>[
        _link('znn_disconnect'),
        _link('eth_accounts'),
        _link('znn_accounts', callback: 'javascript:alert(1)'),
        _link('znn_accounts', callback: 'myapp://return'),
        _link('znn_accounts', callback: 'ms-settings:privacy'),
        _link('znn_accounts', callback: 'file:///C:/x'),
        _link('znn_accounts', callback: 'http://evil.example/r'),
        _link('znn_accounts', callback: 'https://u:p@a.example/r'),
        _link('znn_accounts', callback: ''),
        Uri.parse(
          'syrius://request?method=znn_sign&params=%7Bnope'
          '&callback=https://a.example/',
        ),
        Uri.parse('syrius://transfer?address=z1&amount=1'),
        Uri.parse('https://request?method=znn_accounts'),
      ]) {
        expect(parseDappBridgeLink(link), isNull, reason: '$link');
      }
      expect(
        parseDappBridgeLink(
          _link('znn_accounts', callback: 'http://192.168.1.20:8787/'),
        ),
        isNotNull,
      );
    });

    test(
      'connect by link: asked, kept apart, answered at the callback',
      () async {
        expect(await channel.handleLink(_link('znn_connect')), isTrue);
        expect(wallet.prompts, <String>['connect link:$kSite $kA']);
        final Uri answer = opened.single;
        expect(answer.origin, kSite);
        expect(answer.path, '/zenon/return');
        expect(answer.queryParameters['id'], '42');
        expect(_decode(answer.queryParameters['result']!), <String>[kA]);
        expect(channel.sites.single.viaLink, isTrue);
        expect(channel.sites.single.origin, kSite);

        // The socket from that same origin is not connected by it.
        final Page page = await Page.open(channel.port!);
        expect(await page.result('znn_accounts'), <String>[]);
        await page.close();
      },
    );

    test(
      'a link naming a site connected over the socket gets nothing',
      () async {
        final Page page = await Page.open(channel.port!);
        await page.result('znn_connect');
        wallet.prompts.clear();
        // Any page can write this link with bridge.zenon.foo as the callback.
        expect(
          await channel.handleLink(
            _link(
              'znn_sendTransaction',
              params: <String, Object?>{
                'to': kTo,
                'tokenStandard': kZnn,
                'amount': '1',
              },
            ),
          ),
          isTrue,
        );
        expect(wallet.prompts, isEmpty);
        expect(wallet.sent, isEmpty);
        expect(
          _decode(opened.single.queryParameters['error']!),
          <String, Object?>{'code': 4100, 'message': 'Not connected'},
        );
        await page.close();
      },
    );

    test('the callback keeps its own query and fragment', () async {
      await channel.handleLink(
        _link('znn_accounts', callback: '$kSite/r?id=old&keep=1&result=x#frag'),
      );
      final Uri answer = opened.single;
      expect(answer.queryParametersAll['id'], <String>['42']);
      expect(answer.queryParameters['keep'], '1');
      expect(answer.fragment, 'frag');
      expect(_decode(answer.queryParameters['result']!), <String>[]);
    });

    test('a short sent block comes back whole', () async {
      await channel.handleLink(_link('znn_connect'));
      opened.clear();
      await channel.handleLink(
        _link(
          'znn_sendTransaction',
          params: <String, Object?>{
            'to': kTo,
            'tokenStandard': kZnn,
            'amount': '1',
          },
        ),
      );
      final Map<String, dynamic> result =
          _decode(opened.single.queryParameters['result']!)!
              as Map<String, dynamic>;
      expect(result['hash'], 'h1');
      expect(result['block'], isA<Map<String, dynamic>>());
    });

    test('a block too long for a URL comes back as its hash', () async {
      await channel.handleLink(_link('znn_connect'));
      opened.clear();
      // 3,000 bytes of call data: the block's JSON alone is past what
      // Windows opens.
      await channel.handleLink(
        _link(
          'znn_signAndSendBlock',
          params: <String, Object?>{
            'toAddress': kTo,
            'amount': '1',
            'data': base64.encode(List<int>.filled(3000, 7)),
          },
        ),
      );
      expect(
        opened.single.toString().length,
        lessThanOrEqualTo(kDappBridgeMaxCallback),
      );
      expect(
        _decode(opened.single.queryParameters['result']!),
        <String, Object?>{'hash': 'h1'},
      );
    });

    test('one at a time; a burst keeps the newest four', () async {
      wallet.hold = Completer<bool>();
      final Future<bool> first = channel.handleLink(_link('znn_connect'));
      await settle();
      final List<Future<bool>> burst = <Future<bool>>[
        for (int i = 0; i < kDappBridgeMaxLinks + 1; i++)
          channel.handleLink(_link('znn_accounts', id: 'b$i')),
      ];
      expect(await burst.first, isFalse, reason: 'the oldest gave way');
      wallet.hold!.complete(true);
      expect(await first, isTrue);
      expect(await Future.wait(burst.skip(1)), everyElement(isTrue));
      expect(
        opened.map((Uri u) => u.queryParameters['id']),
        <String>['42', 'b1', 'b2', 'b3', 'b4'],
      );
    });

    test('a link that does not parse gets no answer', () async {
      expect(
        await channel.handleLink(Uri.parse('syrius://request?method=x')),
        isFalse,
      );
      expect(opened, isEmpty);
    });
  });
}
