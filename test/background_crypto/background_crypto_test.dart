import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:zenon_syrius_wallet_flutter/utils/background_crypto.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const String _mnemonic =
    'route become dream access impulse price inform obtain engage ski believe '
    'awful absent pig thing vibrant possible exotic flee pepper marble rural '
    'fire fancy';

/// The longest the calling isolate went without running a timer while
/// [work] was awaited. A frame is a timer's kind of event: where this gap is
/// long, an animation stood still for as long.
Future<Duration> _longestStall(Future<void> Function() work) async {
  final Stopwatch clock = Stopwatch()..start();
  Duration last = Duration.zero;
  Duration longest = Duration.zero;
  final Timer timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final Duration now = clock.elapsed;
    if (now - last > longest) longest = now - last;
    last = now;
  });
  await work();
  final Duration end = clock.elapsed;
  if (end - last > longest) longest = end - last;
  timer.cancel();
  return longest;
}

/// A signature in the calling isolate takes over a second, a public key
/// over half of one. Anything under this was not computed here.
const Duration _fluid = Duration(milliseconds: 200);

void main() {
  late BackgroundKeyStore store;
  late KeyStore plain;

  setUpAll(() async {
    store = await BackgroundKeyStore.fromMnemonic(_mnemonic);
    plain = KeyStore.fromMnemonic(_mnemonic);
  });

  group('the same bytes as the SDK', () {
    test('mnemonic, entropy and seed', () async {
      expect(store.mnemonic, plain.mnemonic);
      expect(store.entropy, plain.entropy);
      expect(store.seed, plain.seed);
      final BackgroundKeyStore again =
          await BackgroundKeyStore.fromEntropy(plain.entropy);
      expect(again.mnemonic, plain.mnemonic);
      expect(again.seed, plain.seed);
    });

    test('public key, address and signature, for two accounts', () async {
      final Uint8List message = Uint8List.fromList(List<int>.filled(40, 7));
      for (final int index in <int>[0, 3]) {
        final WalletAccount account = await store.getAccount(index);
        final KeyPair pair = plain.getKeyPair(index);
        expect(await account.getPublicKey(), await pair.getPublicKey());
        expect(
          (await account.getAddress()).toString(),
          (await pair.getAddress()).toString(),
        );
        expect(await account.sign(message), await pair.sign(message));
      }
    });

    test('a signature verifies, and not against another message', () async {
      final WalletAccount account = await store.getAccount();
      final Uint8List message = Uint8List.fromList(List<int>.filled(33, 1));
      final List<int> signature = await account.sign(message);
      final List<int> publicKey = await account.getPublicKey();
      expect(
        await BackgroundCrypto.verify(signature, message, publicKey),
        isTrue,
      );
      expect(
        await BackgroundCrypto.verify(
          signature,
          Uint8List.fromList(List<int>.filled(33, 2)),
          publicKey,
        ),
        isFalse,
      );
    });

    test('a bad mnemonic is an ArgumentError, as in the SDK', () async {
      await expectLater(
        BackgroundKeyStore.fromMnemonic('not a mnemonic'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a file digest', () async {
      final Directory dir = Directory.systemTemp.createTempSync('bgcrypto');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File file = File('${dir.path}/blob')
        ..writeAsBytesSync(List<int>.generate(5000, (int i) => i % 251));
      expect(
        await BackgroundCrypto.digestFile(file.path),
        Crypto.digest(file.readAsBytesSync()),
      );
    });
  });

  // Signing is package:cryptography's Ed25519, not the SDK's. These hold the
  // two to the same bytes: a wallet that signed differently from the SDK
  // would publish blocks no node accepts.
  group('Ed25519 against RFC 8032 and the SDK', () {
    // RFC 8032, section 7.1, tests 1 to 3: seed, public key, message,
    // signature.
    const List<List<String>> vectors = <List<String>>[
      <String>[
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
        '',
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
            '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      ],
      <String>[
        '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
        '72',
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da'
            '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      ],
      <String>[
        'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
        'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
        'af82',
        '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac'
            '18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
      ],
    ];

    test('the RFC vectors', () async {
      for (final List<String> v in vectors) {
        final BackgroundKeyPair pair = BackgroundKeyPair(HEX.decode(v[0]));
        final List<int> message = HEX.decode(v[2]);
        expect(HEX.encode(await pair.getPublicKey()), v[1]);
        expect(HEX.encode(await pair.sign(message)), v[3]);
        expect(
          await BackgroundCrypto.verify(
            HEX.decode(v[3]),
            message,
            HEX.decode(v[1]),
          ),
          isTrue,
        );
      }
    });

    test('ten random keys and messages, byte for byte with the SDK', () async {
      final Random random = Random(20261013);
      // Empty, one byte, a block hash's 32, and lengths either side of
      // SHA-512's 128 byte block.
      const List<int> lengths = <int>[0, 1, 32, 33, 64, 111, 112, 128, 129, 900];
      for (final int length in lengths) {
        final List<int> seed =
            List<int>.generate(32, (_) => random.nextInt(256));
        final Uint8List message = Uint8List.fromList(
          List<int>.generate(length, (_) => random.nextInt(256)),
        );
        final List<int> sdkPublicKey = await Crypto.getPublicKey(seed);
        final List<int> sdkSignature =
            await Crypto.sign(message, seed, sdkPublicKey);

        final BackgroundKeyPair pair = BackgroundKeyPair(seed);
        final List<int> signature = await pair.sign(message);
        expect(await pair.getPublicKey(), sdkPublicKey, reason: 'key, $length');
        expect(signature, sdkSignature, reason: 'signature, $length');
        // Each accepts the other's signature.
        expect(
          await BackgroundCrypto.verify(sdkSignature, message, sdkPublicKey),
          isTrue,
        );
        expect(
          await Crypto.verify(
            Uint8List.fromList(signature),
            message,
            Uint8List.fromList(sdkPublicKey),
          ),
          isTrue,
        );
      }
    }, timeout: const Timeout(Duration(minutes: 3)),);

    test('a signed account block hash, as signTx signs it', () async {
      final WalletAccount account = await store.getAccount(2);
      final KeyPair pair = plain.getKeyPair(2);
      final AccountBlockTemplate block = AccountBlockTemplate.send(
        Address.parse('z1qq9n7fpaqd8lpcljandzmx4xtku9w4ftwyg0mq'),
        znnZts,
        BigInt.from(100000000),
      )..hash = Hash.digest(<int>[1, 2, 3]);
      expect(await account.signTx(block), await pair.signTx(block));
    });

    test('what does not verify', () async {
      final WalletAccount account = await store.getAccount();
      final List<int> message = <int>[1, 2, 3];
      final List<int> signature = await account.sign(message);
      final List<int> publicKey = await account.getPublicKey();
      final List<int> other =
          await (await store.getAccount(1)).getPublicKey();
      final List<int> flipped = List<int>.of(signature)..[5] ^= 1;
      final List<int> flippedS = List<int>.of(signature)..[40] ^= 1;

      Future<bool> check(List<int> s, List<int> m, List<int> k) =>
          BackgroundCrypto.verify(s, m, k);
      expect(await check(signature, message, publicKey), isTrue);
      expect(await check(flipped, message, publicKey), isFalse);
      expect(await check(flippedS, message, publicKey), isFalse);
      expect(await check(signature, <int>[1, 2, 4], publicKey), isFalse);
      expect(await check(signature, message, other), isFalse);
      expect(await check(signature.sublist(1), message, publicKey), isFalse);
      expect(await check(signature, message, publicKey.sublist(1)), isFalse);
      expect(await check(<int>[], message, <int>[]), isFalse);
      expect(
        await check(List<int>.filled(64, 255), message, publicKey),
        isFalse,
      );
      expect(
        await check(signature, message, List<int>.filled(32, 255)),
        isFalse,
      );
    });
  });

  group('wallet file cipher', () {
    test('round trip, and the wrong password keeps its type', () async {
      final List<int> data = List<int>.generate(32, (int i) => i);
      final EncryptedFile file = await BackgroundCrypto.encrypt(
        data,
        'right',
        metadata: <String, dynamic>{'walletType': 'keystore'},
      );
      expect(file.metadata!['walletType'], 'keystore');
      expect(await BackgroundCrypto.decrypt(file, 'right'), data);
      await expectLater(
        BackgroundCrypto.decrypt(file, 'wrong'),
        throwsA(isA<IncorrectPasswordException>()),
      );
    });
  });

  group('the calling isolate keeps running', () {
    test('the measure itself sees a signature made here', () async {
      final KeyPair pair = plain.getKeyPair(5);
      final Duration stall = await _longestStall(
        () async => pair.sign(Uint8List.fromList(<int>[1, 2, 3])),
      );
      expect(stall, greaterThan(_fluid));
    });

    test('through a new account signing', () async {
      final WalletAccount account = await store.getAccount(7);
      final Duration stall = await _longestStall(
        () async => account.sign(Uint8List.fromList(<int>[1, 2, 3])),
      );
      expect(stall, lessThan(_fluid));
    });

    test('through a verification', () async {
      final WalletAccount account = await store.getAccount();
      final Uint8List message = Uint8List.fromList(<int>[9, 9]);
      final List<int> signature = await account.sign(message);
      final List<int> publicKey = await account.getPublicKey();
      final Duration stall = await _longestStall(
        () async => BackgroundCrypto.verify(signature, message, publicKey),
      );
      expect(stall, lessThan(_fluid));
    });

    test('through opening a key store and an encryption', () async {
      final Duration stall = await _longestStall(() async {
        await BackgroundKeyStore.fromEntropy(plain.entropy);
        await BackgroundCrypto.encrypt(<int>[1, 2, 3], 'password');
      });
      expect(stall, lessThan(_fluid));
    });
  });

  test('a used key store can still be sent to an isolate', () async {
    // KeyStoreManager.saveKeyStore sends the store it is given.
    await (await store.getAccount()).getAddress();
    final String entropy = await Isolate.run(() => store.entropy);
    expect(entropy, plain.entropy);
  });
}
