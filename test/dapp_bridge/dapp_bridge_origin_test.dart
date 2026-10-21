import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_origin.dart';

void main() {
  group('dappBridgeRequester', () {
    test('accepts https from anywhere, in canonical form', () {
      expect(
        dappBridgeRequester('https://bridge.zenon.foo'),
        'https://bridge.zenon.foo',
      );
      expect(
        dappBridgeRequester('https://Bridge.Zenon.Foo:443'),
        'https://bridge.zenon.foo',
      );
      expect(
        dappBridgeRequester('https://app.example:8443'),
        'https://app.example:8443',
      );
    });

    test('accepts http only from a private host', () {
      for (final String origin in <String>[
        'http://localhost:5173',
        'http://dev.localhost',
        'http://127.0.0.1:8080',
        'http://10.1.2.3',
        'http://172.16.0.1',
        'http://172.31.255.255',
        'http://192.168.1.20:8787',
        'http://box.local',
      ]) {
        expect(dappBridgeRequester(origin), isNotNull, reason: origin);
      }
      for (final String origin in <String>[
        'http://example.com',
        'http://172.32.0.1',
        'http://11.0.0.1',
        'http://192.169.1.1',
        'http://127.0.0.1.example.com',
        'http://localhost.example.com',
      ]) {
        expect(dappBridgeRequester(origin), isNull, reason: origin);
      }
    });

    test('refuses what is not a web origin', () {
      for (final String? origin in <String?>[
        null,
        '',
        'null',
        'file://',
        'chrome-extension://abcdef',
        'ws://localhost',
        'javascript:alert(1)',
        'https://',
        'https://user:pw@bridge.zenon.foo',
        'https://bridge.zenon.foo/path',
        'https://bridge.zenon.foo?x=1',
        'https://bridge.zenon.foo#x',
      ]) {
        expect(dappBridgeRequester(origin), isNull, reason: '$origin');
      }
    });
  });

  group('isLoopbackHostHeader', () {
    test('accepts loopback on the listening port only', () {
      expect(isLoopbackHostHeader('127.0.0.1:35996', 35996), isTrue);
      expect(isLoopbackHostHeader('localhost:35996', 35996), isTrue);
      expect(isLoopbackHostHeader('LOCALHOST:35996', 35996), isTrue);
      expect(isLoopbackHostHeader('127.0.0.1:35997', 35996), isFalse);
      expect(isLoopbackHostHeader('127.0.0.1', 35996), isFalse);
      expect(isLoopbackHostHeader('rebind.example:35996', 35996), isFalse);
      expect(isLoopbackHostHeader(null, 35996), isFalse);
    });
  });
}
