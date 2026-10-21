import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

void main() {
  late Directory dir;
  late String keyStoreJson;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('is_key_store_file');
    final EncryptedFile encrypted = await EncryptedFile.encrypt(
      List<int>.filled(32, 7),
      'password',
      metadata: <String, dynamic>{walletTypeKey: keyStoreWalletType},
    );
    keyStoreJson = json.encode(encrypted);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final File file = File('${dir.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(bytes);
    return file.path;
  }

  group('WalletFile.isKeyStoreFile', () {
    test('accepts a key store file under any name', () {
      for (final String name in <String>['a.json', 'a.txt', 'a.bak', 'a']) {
        expect(
          WalletFile.isKeyStoreFile(write(name, utf8.encode(keyStoreJson))),
          isTrue,
          reason: name,
        );
      }
    });

    test('accepts a key store file with no wallet type', () {
      final Map<String, dynamic> decoded = json.decode(keyStoreJson)
        ..remove(walletTypeKey);
      expect(
        WalletFile.isKeyStoreFile(
          write('legacy', utf8.encode(json.encode(decoded))),
        ),
        isTrue,
      );
    });

    test('refuses a ledger wallet file', () {
      final Map<String, dynamic> decoded = json.decode(keyStoreJson);
      decoded[walletTypeKey] = ledgerWalletType;
      expect(
        WalletFile.isKeyStoreFile(
          write('ledger.json', utf8.encode(json.encode(decoded))),
        ),
        isFalse,
      );
    });

    test('refuses what is not a key store file', () {
      final Map<String, dynamic> noCrypto = json.decode(keyStoreJson)
        ..remove('crypto');
      final Map<String, List<int>> cases = <String, List<int>>{
        'empty.json': <int>[],
        'text.json': utf8.encode('not json'),
        'array.json': utf8.encode('[1, 2]'),
        'object.json': utf8.encode('{"a": 1}'),
        'nocrypto.json': utf8.encode(json.encode(noCrypto)),
        'binary.json': <int>[0xff, 0xfe, 0x00, 0x80],
        'large.json': List<int>.filled(1024 * 1024 + 1, 0x20),
      };
      cases.forEach((String name, List<int> bytes) {
        expect(
          WalletFile.isKeyStoreFile(write(name, bytes)),
          isFalse,
          reason: name,
        );
      });
    });

    test('refuses a path that does not exist', () {
      expect(
        WalletFile.isKeyStoreFile('${dir.path}${Platform.pathSeparator}none'),
        isFalse,
      );
    });
  });
}
