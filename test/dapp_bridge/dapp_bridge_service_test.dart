import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';

import 'support.dart';

Matcher _refused(int code) => throwsA(
  isA<DappBridgeError>().having((DappBridgeError e) => e.code, 'code', code),
);

void main() {
  late FakeWallet wallet;
  late DappBridgeConsentStore consent;
  late FakeClock clock;
  late DappBridgeService service;
  late List<String> events;

  setUp(() {
    wallet = FakeWallet();
    consent = DappBridgeConsentStore(MemoryStore());
    clock = FakeClock();
    events = <String>[];
    service =
        DappBridgeService(
            wallet: wallet,
            consent: consent,
            now: () => clock.now,
          )
          ..emit = (String event, Object? params, {String? origin}) =>
              events.add('$event $params $origin');
  });

  test('consent is per address and per origin', () async {
    await service.handle(kSite, 'znn_connect', null);
    expect(await service.handle(kOther, 'znn_accounts', null), <String>[]);
    wallet.selected = kB;
    expect(await service.handle(kSite, 'znn_accounts', null), <String>[]);
    await expectLater(service.handle(kSite, 'znn_sign', 'hi'), _refused(4100));
    expect(wallet.prompts, hasLength(1));
    wallet.selected = kA;
    expect(await service.handle(kSite, 'znn_accounts', null), <String>[kA]);
  });

  test('a second address is asked for, and added', () async {
    await service.handle(kSite, 'znn_connect', null);
    wallet.selected = kB;
    expect(await service.handle(kSite, 'znn_connect', null), <String>[kB]);
    expect(consent.sites.single.addresses, <String>[kA, kB]);
  });

  test('connect and disconnect always say what the page now sees', () async {
    await service.handle(kSite, 'znn_connect', null);
    await service.handle(kSite, 'znn_connect', null);
    await service.handle(kSite, 'znn_disconnect', null);
    expect(events, <String>[
      'accountsChanged [$kA] $kSite',
      'accountsChanged [$kA] $kSite',
      'accountsChanged [] $kSite',
    ]);
  });

  test('walletChanged: the first sight is recorded, not announced', () async {
    service.walletChanged(<String>[kSite, kOther]);
    expect(events, isEmpty);
    await service.handle(kSite, 'znn_connect', null);
    events.clear();
    wallet.selected = kB;
    service.walletChanged(<String>[kSite, kOther]);
    expect(events, <String>['accountsChanged [] $kSite']);
  });

  test('walletChanged: chain and node go to connected origins only', () async {
    await service.handle(kSite, 'znn_connect', null);
    service.walletChanged(<String>[kSite, kOther]);
    events.clear();
    wallet
      ..chainId = 3
      ..nodeUrl = 'ws://127.0.0.1:35998';
    service.walletChanged(<String>[kSite, kOther]);
    expect(events, <String>[
      'chainChanged 3 $kSite',
      'nodeChanged ws://127.0.0.1:35998 $kSite',
    ]);
  });

  test('walletChanged forgets origins whose sockets closed', () async {
    await service.handle(kSite, 'znn_connect', null);
    service
      ..walletChanged(<String>[kSite])
      ..walletChanged(<String>[]);
    events.clear();
    wallet.selected = kB;
    // Seen again as new: recorded, not announced.
    service.walletChanged(<String>[kSite]);
    expect(events, isEmpty);
  });

  test('a decline holds the origin back for the cooldown only', () async {
    await service.handle(kSite, 'znn_connect', null);
    wallet.approve = false;
    await expectLater(service.handle(kSite, 'znn_sign', 'hi'), _refused(4001));
    await expectLater(
      service.handle(kSite, 'znn_sign', 'hi'),
      _refused(-32005),
    );
    // Another origin is not held back by this one's decline.
    await expectLater(
      service.handle(kOther, 'znn_connect', null),
      _refused(4001),
    );
    // An answer that needs no prompt is not held back either.
    expect(await service.handle(kSite, 'znn_connect', null), <String>[kA]);
    clock.advance(kDappBridgeDeclineCooldown);
    wallet.approve = true;
    expect(
      await service.handle(kSite, 'znn_sign', 'hi'),
      containsPair('message', 'hi'),
    );
  });

  test('16 approvals at most, across origins', () async {
    wallet.hold = Completer<bool>();
    final List<Future<Object?>> held = <Future<Object?>>[
      for (int i = 0; i < kDappBridgeMaxPending; i++)
        service.handle('https://s$i.example', 'znn_connect', null),
    ];
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      service.handle(kSite, 'znn_connect', null),
      _refused(-32005),
    );
    wallet.hold!.complete(true);
    await Future.wait(held);
    expect(consent.sites, hasLength(kDappBridgeMaxPending));
  });

  test('an unknown method is refused', () {
    expect(() => service.handle(kSite, 'eth_accounts', null), _refused(4200));
  });

  test('publicNodeUrl keeps scheme, host and port only', () {
    expect(publicNodeUrl('ws://127.0.0.1:35998'), 'ws://127.0.0.1:35998');
    expect(publicNodeUrl('wss://n.example:443/path?key=1'), 'wss://n.example');
    expect(publicNodeUrl('wss://u:p@n.example/x#f'), 'wss://n.example');
    expect(publicNodeUrl('https://n.example'), isNull);
    expect(publicNodeUrl('Embedded Node'), isNull);
    expect(publicNodeUrl(null), isNull);
  });
}
