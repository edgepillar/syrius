import 'dart:io';
import 'dart:math';

import 'package:hex/hex.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The ordinary cold lock displays this isolated wallet's filename.
const String launchSettleWalletName = 'Main';

/// Startup restores this preference before decryption without connecting.
const String launchSettleNode = 'ws://127.0.0.1:9';

/// Creates only the encrypted file and preferences needed by cold startup.
Future<void> prepareLaunchSettleProfile(String home, String appData) async {
  final Directory directory = Directory(appData);
  final String data = path.canonicalize(appData);
  final String cache = znnDefaultPaths.cache.path;
  final String wallets = znnDefaultWalletDirectory.path;
  final String profile = path.basename(home);
  if (!RegExp(r'^ci-entry-smoke-[a-f0-9]{24}$').hasMatch(profile) ||
      data != path.canonicalize(path.join(home, 'AppData', 'Roaming')) ||
      path.canonicalize(directory.resolveSymbolicLinksSync()) != data ||
      !path.isWithin(data, path.canonicalize(cache)) ||
      !path.isWithin(data, path.canonicalize(wallets)) ||
      !await directory.list(followLinks: false).isEmpty) {
    throw StateError('Launch settle requires a fresh isolated profile');
  }
  ensureDirectoriesExist();
  Hive.init(cache);
  try {
    final Random random = Random.secure();
    final String password = HEX.encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final KeyStoreWalletFile wallet = await KeyStoreWalletFile.create(
      Mnemonic.generateMnemonic(128),
      password,
      name: launchSettleWalletName,
    );
    if (path.basename(wallet.walletPath) != launchSettleWalletName ||
        !path.isWithin(wallets, wallet.walletPath)) {
      throw StateError('Launch settle profile returned an unexpected wallet');
    }
    final Box<dynamic> pointer = await Hive.openBox<dynamic>(kKeyStoreBox);
    final Box<dynamic> preferences = await Hive.openBox<dynamic>(
      kSharedPrefsBox,
    );
    await pointer.put(0, wallet.walletPath);
    await preferences.putAll(<String, Object>{
      kSelectedNodeKey: launchSettleNode,
      kChainIdKey: 321,
    });
  } finally {
    await Hive.close();
  }
}
