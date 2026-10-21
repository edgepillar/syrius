// The channel as wired into the app: its store is the wallet's settings box,
// and a wallet reset deletes that box. This file compiles the whole app, so
// it fails to load while any part of the app does not compile.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' show sharedPrefsService;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/dapp_bridge.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

import 'support.dart';

/// The same box the app's store uses, written to from the test.
class _PrefsStore implements DappBridgeStore {
  @override
  Object? read(String key) => sharedPrefsService!.get(key);

  @override
  Future<void> write(String key, Object? value) =>
      sharedPrefsService!.put(key, value);
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('syrius_dapp_bridge_');
    Hive.init(dir.path);
    sharedPrefsService = await SharedPrefsService.getInstance();
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('the widgets find the app channel without importing the app', () {
    // The instance is lazy: `main` creates it by starting it, and only then
    // is it registered.
    final DappBridge app = DappBridge.instance;
    expect(DappBridgeControl.of(), same(app));
  });

  test('consent does not survive a wallet reset', () async {
    await DappBridgeConsentStore(_PrefsStore()).grant(kSite, kA);
    expect(DappBridge.instance.sites.single.requester, kSite);

    // What a reset does to the boxes (SplashScreen._deleteCache).
    expect(kCacheBoxesToBeDeleted, contains(kSharedPrefsBox));
    await Hive.close();
    for (final String box in kCacheBoxesToBeDeleted) {
      await Hive.deleteBoxFromDisk(box);
    }
    expect(DappBridge.instance.sites, isEmpty, reason: 'box closed');
    await sharedPrefsService!.checkIfBoxIsOpen();
    expect(DappBridge.instance.sites, isEmpty, reason: 'box reopened');
  });

  test('the switch is kept in the same box, and reset with it', () async {
    await DappBridge.instance.setEnabled(enabled: false);
    expect(sharedPrefsService!.get(kDappBridgeEnabledKey), isFalse);
    expect(DappBridge.instance.port, isNull);
    await Hive.close();
    await Hive.deleteBoxFromDisk(kSharedPrefsBox);
    await sharedPrefsService!.checkIfBoxIsOpen();
    expect(DappBridge.instance.enabled, isTrue);
  });

  test('handleLink takes syrius://request and nothing else', () {
    expect(
      DappBridge.instance.handleLink(Uri.parse('syrius://request?method=x')),
      isTrue,
    );
    expect(
      DappBridge.instance.handleLink(Uri.parse('syrius://request/?method=x')),
      isTrue,
    );
    expect(
      DappBridge.instance.handleLink(Uri.parse('syrius://wc?uri=x')),
      isFalse,
    );
    expect(
      DappBridge.instance.handleLink(Uri.parse('syrius://transfer')),
      isFalse,
    );
  });
}
