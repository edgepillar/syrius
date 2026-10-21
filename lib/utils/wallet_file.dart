import 'dart:convert';
import 'dart:io';

import 'package:hex/hex.dart';
import 'package:mutex/mutex.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/background_crypto.dart';
import 'package:znn_ledger_dart/znn_ledger_dart.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const int _kMaxWalletFileSize = 1024 * 1024;

abstract class WalletFile {

  WalletFile(this._path);
  final String _path;

  static Future<WalletFile> decrypt(String walletPath, String password) async {
    final EncryptedFile encrypted = await WalletFile.read(walletPath);
    final walletType =
        encrypted.metadata != null ? encrypted.metadata![walletTypeKey] : null;
    if (walletType == null || walletType == keyStoreWalletType) {
      return KeyStoreWalletFile.decrypt(walletPath, password);
    } else if (walletType == ledgerWalletType) {
      return LedgerWalletFile.decrypt(walletPath, password);
    } else {
      throw WalletException(
        currentL10n.walletFileTypeNotSupportedError(
          '${encrypted.metadata![walletTypeKey]}',
        ),
      );
    }
  }

  static Future<EncryptedFile> read(String walletPath) async {
    final File file = File(walletPath);
    if (!file.existsSync()) {
      throw WalletException(
        currentL10n.walletFilePathNotFoundError(walletPath),
      );
    }
    return EncryptedFile.fromJson(json.decode(file.readAsStringSync()));
  }

  /// Whether the file at [walletPath] parses as a key store wallet file,
  /// whatever it is named. A backup is often renamed or loses its extension,
  /// so the content decides, not the name. Nothing is decrypted here.
  static bool isKeyStoreFile(String walletPath) {
    try {
      final File file = File(walletPath);
      // A key store file is under 1 KB; the bound keeps a dropped video from
      // being read into memory.
      if (!file.existsSync() || file.lengthSync() > _kMaxWalletFileSize) {
        return false;
      }
      final dynamic decoded = json.decode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final EncryptedFile encrypted = EncryptedFile.fromJson(decoded);
      final walletType = encrypted.metadata?[walletTypeKey];
      if (walletType != null && walletType != keyStoreWalletType) {
        return false;
      }
      final crypto = encrypted.crypto;
      return crypto != null &&
          crypto.argon2Params?.salt != null &&
          crypto.argon2Params!.salt!.isNotEmpty &&
          crypto.nonce != null &&
          crypto.nonce!.isNotEmpty &&
          crypto.cipherData != null &&
          crypto.cipherData!.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> write(String walletPath, String password, List<int> data,
      {Map<String, dynamic>? metadata,}) async {
    final File file = File(walletPath);
    final EncryptedFile encrypted =
        await BackgroundCrypto.encrypt(data, password, metadata: metadata);
    file.writeAsString(json.encode(encrypted), mode: FileMode.writeOnly);
  }

  String get walletPath => _path;

  String get walletType;

  bool get isOpen;

  bool get isHardwareWallet;

  Future<Wallet> open();

  void close();

  Future<T> access<T>(Future<T> Function(Wallet) accessSection) async {
    final Wallet wallet = await open();
    try {
      return await accessSection(wallet);
    } finally {
      close();
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword,) async {
    final EncryptedFile file = await WalletFile.read(walletPath);
    final List<int> decrypted =
        await BackgroundCrypto.decrypt(file, currentPassword);
    await WalletFile.write(walletPath, newPassword, decrypted,
        metadata: file.metadata,);
  }
}

class KeyStoreWalletFile extends WalletFile {

  KeyStoreWalletFile._internal(super._path, this._walletSeed);
  final Mutex _lock = Mutex();
  final String _walletSeed;
  KeyStore? _keyStore;

  static final KeyStoreManager keyStoreWalletManager =
      KeyStoreManager(walletPath: znnDefaultWalletDirectory);

  static Future<KeyStoreWalletFile> create(String mnemonic, String password,
      {String? name,}) async {
    final BackgroundKeyStore wallet =
        await BackgroundKeyStore.fromMnemonic(mnemonic);
    // Named here: left to `saveKeyStore`, the name is the base address
    // worked out on the calling isolate, which is the UI's.
    name ??= (await (await wallet.getAccount()).getAddress()).toString();
    final KeyStoreDefinition walletDefinition =
        await keyStoreWalletManager.saveKeyStore(wallet, password, name: name);
    return KeyStoreWalletFile._internal(
        walletDefinition.walletId, wallet.entropy,);
  }

  static Future<KeyStoreWalletFile> decrypt(
      String walletPath, String password,) async {
    final EncryptedFile encrypted = await WalletFile.read(walletPath);
    if (encrypted.metadata != null &&
        encrypted.metadata![walletTypeKey] != null &&
        encrypted.metadata![walletTypeKey] != keyStoreWalletType) {
      throw WalletException(
        currentL10n.walletFileTypeNotSupportedError(
          '${encrypted.metadata![walletTypeKey]}',
        ),
      );
    }
    final List<int> decrypted =
        await BackgroundCrypto.decrypt(encrypted, password);
    return KeyStoreWalletFile._internal(walletPath, HEX.encode(decrypted));
  }

  @override
  String get walletType => keyStoreWalletType;

  @override
  bool get isOpen => _lock.isLocked;

  @override
  bool get isHardwareWallet => false;

  @override
  Future<Wallet> open() async {
    await _lock.acquire();
    try {
      _keyStore ??= await BackgroundKeyStore.fromEntropy(_walletSeed);
      return _keyStore!;
    } catch (_) {
      _lock.release();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_lock.isLocked) _lock.release();
  }
}

class LedgerWalletFile extends WalletFile {

  LedgerWalletFile._internal(super._path, this._walletName);
  final Mutex _lock = Mutex();
  final String _walletName;
  LedgerWallet? _wallet;

  static final LedgerWalletManager ledgerWalletManager = LedgerWalletManager();

  static Future<LedgerWallet> _connect(String walletIdOrName) async {
    for (final WalletDefinition walletDefinition
        in await ledgerWalletManager.getWalletDefinitions()) {
      if (walletDefinition.walletId == walletIdOrName ||
          walletDefinition.walletName == walletIdOrName) {
        return await ledgerWalletManager.getWallet(walletDefinition)
            as LedgerWallet;
      }
    }
    throw LedgerError.connectionError(
      origMessage: currentL10n.walletFileLedgerNotFoundError,
    );
  }

  static Future<LedgerWalletFile> create(String walletId, String password,
      {String? walletName,}) async {
    final LedgerWallet wallet = await _connect(walletId);
    try {
      final Address baseAddress = await (await wallet.getAccount()).getAddress();
      walletName ??= baseAddress.toString();
      final String walletPath = path.join(znnDefaultWalletDirectory.path, walletName);
      await WalletFile.write(walletPath, password, utf8.encode(walletName),
          metadata: <String, String>{
            baseAddressKey: baseAddress.toString(),
            walletTypeKey: ledgerWalletType,
          },);
      return LedgerWalletFile._internal(walletPath, walletName);
    } finally {
      await wallet.disconnect();
    }
  }

  static Future<LedgerWalletFile> decrypt(
      String walletPath, String password,) async {
    final EncryptedFile encrypted = await WalletFile.read(walletPath);
    if (encrypted.metadata == null ||
        encrypted.metadata![walletTypeKey] != ledgerWalletType) {
      throw WalletException(
        currentL10n.walletFileTypeNotSupportedError(
          '${encrypted.metadata![walletTypeKey]}',
        ),
      );
    }
    final List<int> decrypted =
        await BackgroundCrypto.decrypt(encrypted, password);
    return LedgerWalletFile._internal(walletPath, utf8.decode(decrypted));
  }

  @override
  String get walletType => ledgerWalletType;

  @override
  bool get isOpen => _lock.isLocked;

  @override
  bool get isHardwareWallet => true;

  @override
  Future<Wallet> open() async {
    await _lock.acquire();
    try {
      _wallet = await _connect(_walletName);
      return _wallet!;
    } catch (_) {
      _lock.release();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_wallet != null) {
      try {
        await _wallet!.disconnect();
      } catch (_) {
      } finally {
        _wallet = null;
      }
    }
    if (_lock.isLocked) _lock.release();
  }
}
