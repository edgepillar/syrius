/// Key work, off the UI isolate.
///
/// The SDK's Ed25519 is big-integer arithmetic in plain Dart: a public key
/// takes about 0.7 s and a signature about 1.2 s, and a verification longer.
/// They are `async` in name only, with no gap in them, so called from the UI
/// isolate they hold every frame for that long: the Sign button's spinner
/// stood still, and each send and each received transaction (an address, then
/// a signature) froze the window for about two seconds. Argon2, through FFI,
/// and the mnemonic's PBKDF2 do the same at unlock.
///
/// Everything here runs through [Isolate.run]. One isolate per call and none
/// kept: nothing to stop when the wallet locks, and no second heap holding
/// the seed between calls.
///
/// Ed25519 itself is `package:cryptography`'s `DartEd25519`, not the SDK's:
/// the same RFC 8032 algorithm on fixed-width limbs, a few milliseconds
/// where the SDK takes a second. Ed25519 is deterministic, so a key and a
/// message have one signature, and `test/background_crypto` holds the two
/// implementations to the same bytes, on the RFC's vectors and on random
/// keys. It is the package the SDK already uses to encrypt the wallet file.
/// The wallet file's cipher, Argon2 and the mnemonic's seed are still the
/// SDK's own code.
///
/// Each closure handed to [Isolate.run] is built in a static function that
/// takes only what it sends. A closure written inline in a method takes the
/// method's whole context with it, `this` included, and fails at run time on
/// the first unsendable field.
///
/// The rule this file exists for: **nothing that computes may be awaited on
/// the UI isolate directly**. `test/background_crypto` holds a timer running
/// through each call and fails when it stalls.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:cryptography/dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The stateless calls: a wallet file's key derivation and cipher, and
/// signature verification.
abstract final class BackgroundCrypto {
  /// [file] decrypted with [password]. Throws [IncorrectPasswordException]
  /// as the SDK does.
  static Future<List<int>> decrypt(EncryptedFile file, String password) =>
      Isolate.run<List<int>>(
        () => file.decrypt(password),
        debugName: 'wallet-decrypt',
      );

  /// [data] encrypted under [password], as `EncryptedFile.encrypt`.
  static Future<EncryptedFile> encrypt(
    List<int> data,
    String password, {
    Map<String, dynamic>? metadata,
  }) =>
      Isolate.run<EncryptedFile>(
        () => EncryptedFile.encrypt(data, password, metadata: metadata),
        debugName: 'wallet-encrypt',
      );

  /// Whether [signature] is [publicKey]'s signature of [message]. False,
  /// not an error, for a signature or a key of the wrong length.
  static Future<bool> verify(
    List<int> signature,
    List<int> message,
    List<int> publicKey,
  ) {
    if (signature.length != 64 || publicKey.length != 32) {
      return Future<bool>.value(false);
    }
    return Isolate.run<bool>(
      () => DartEd25519().verify(
        message,
        signature: cryptography.Signature(
          signature,
          publicKey: cryptography.SimplePublicKey(
            publicKey,
            type: cryptography.KeyPairType.ed25519,
          ),
        ),
      ),
      debugName: 'ed25519-verify',
    );
  }

  /// The SHA3-256 of the file at [path], read and hashed in the background:
  /// the hash is plain Dart too, and a dropped file can be any size.
  static Future<List<int>> digestFile(String path) => Isolate.run<List<int>>(
        () => Crypto.digest(File(path).readAsBytesSync()),
        debugName: 'file-digest',
      );

  static Future<List<int>> _publicKey(List<int> privateKey) =>
      Isolate.run<List<int>>(
        () async {
          final cryptography.SimpleKeyPair pair =
              await DartEd25519().newKeyPairFromSeed(privateKey);
          return (await pair.extractPublicKey()).bytes;
        },
        debugName: 'ed25519-public-key',
      );

  // The public half is worked out again from the private key here, not
  // taken from the caller: an Ed25519 signature made with a public key that
  // is not the private key's own gives the private key away.
  static Future<List<int>> _sign(List<int> message, List<int> privateKey) =>
      Isolate.run<List<int>>(
        () async {
          final DartEd25519 ed25519 = DartEd25519();
          final cryptography.Signature signature = await ed25519.sign(
            message,
            keyPair: await ed25519.newKeyPairFromSeed(privateKey),
          );
          return signature.bytes;
        },
        debugName: 'ed25519-sign',
      );

  static Future<({String mnemonic, String entropy, String seed})>
      _fromEntropy(String entropyHex) => Isolate.run(
            () {
              final KeyStore store = KeyStore.fromEntropy(entropyHex);
              return (
                mnemonic: store.mnemonic!,
                entropy: store.entropy,
                seed: store.seed!,
              );
            },
            debugName: 'mnemonic-seed',
          );

  static Future<({String mnemonic, String entropy, String seed})>
      _fromMnemonic(String sentence) => Isolate.run(
            () {
              final KeyStore store = KeyStore.fromMnemonic(sentence);
              return (
                mnemonic: store.mnemonic!,
                entropy: store.entropy,
                seed: store.seed!,
              );
            },
            debugName: 'mnemonic-seed',
          );
}

/// A [KeyStore] whose accounts work in the background.
///
/// It stays a [KeyStore], so the places that read the mnemonic or the base
/// key off an opened wallet (`wallet as KeyStore`) are unchanged. Only
/// [getAccount] differs: it hands out a [BackgroundKeyPair].
///
/// It holds finished values only, never a pending future, so it can still be
/// sent to an isolate: `KeyStoreManager.saveKeyStore` does that.
class BackgroundKeyStore extends KeyStore {
  BackgroundKeyStore._(
    ({String mnemonic, String entropy, String seed}) parts,
  ) : super.fromSeed(parts.seed) {
    mnemonic = parts.mnemonic;
    entropy = parts.entropy;
  }

  final Map<int, BackgroundKeyPair> _accounts = <int, BackgroundKeyPair>{};

  /// As `KeyStore.fromEntropy`, with the seed's 2048 rounds of PBKDF2 done
  /// in the background. Throws [ArgumentError] for a bad entropy.
  static Future<BackgroundKeyStore> fromEntropy(String entropyHex) async =>
      BackgroundKeyStore._(await BackgroundCrypto._fromEntropy(entropyHex));

  /// As `KeyStore.fromMnemonic`. Throws [ArgumentError] for a bad mnemonic.
  static Future<BackgroundKeyStore> fromMnemonic(String sentence) async =>
      BackgroundKeyStore._(await BackgroundCrypto._fromMnemonic(sentence));

  /// The account at [index]. The same object each time, so a public key is
  /// worked out once per unlock and not once per transaction.
  @override
  Future<WalletAccount> getAccount([int index = 0]) async =>
      _accounts[index] ??= BackgroundKeyPair(
        Crypto.deriveKey(Derivation.getDerivationAccount(index), seed!),
      );
}

/// One account's key pair. What `KeyPair` does, in the background.
class BackgroundKeyPair implements WalletAccount {
  BackgroundKeyPair(this._privateKey);

  final List<int> _privateKey;
  List<int>? _publicKey;
  Address? _address;

  @override
  Future<List<int>> getPublicKey() async =>
      _publicKey ??= await BackgroundCrypto._publicKey(_privateKey);

  @override
  Future<Address> getAddress() async =>
      _address ??= Address.fromPublicKey(await getPublicKey());

  @override
  Future<List<int>> sign(List<int> message) =>
      BackgroundCrypto._sign(message, _privateKey);

  @override
  Future<List<int>> signTx(AccountBlockTemplate tx) =>
      sign(tx.hash.getBytes()!);
}
