import 'dart:convert';

import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The largest contract call a page may ask for, in bytes. The extension's
/// limit.
const int kDappBridgeMaxData = 16 * 1024;

/// The largest amount taken as a JSON number: JavaScript's
/// `Number.MAX_SAFE_INTEGER`. Anything larger must be a string.
const int kDappBridgeMaxSafeInteger = 9007199254740991;

/// What a page asks the wallet to send: the four fields that say what a block
/// does.
///
/// A page hands over a whole account block. Everything else in it (a hash, a
/// height, a previous hash, a signature, another sender) is the wallet's to
/// fill in, so it is never read: the block the person approves is built from
/// these four fields and nothing the page computed.
class DappBridgeBlock {
  /// Creates a block.
  const DappBridgeBlock({
    required this.toAddress,
    required this.tokenStandard,
    required this.amount,
    required this.data,
  });

  /// Reads the four fields from an account block as JSON. Throws a
  /// [DappBridgeError.invalidParams] for anything that is not a send.
  factory DappBridgeBlock.parse(Map<Object?, Object?> json) {
    // 2 is a send from an account. A receive is the wallet's own work; a
    // contract's blocks are not an account's to make.
    final Object? blockType = json['blockType'];
    if (blockType != null && blockType != 2) {
      throw const DappBridgeError.invalidParams('Only a send block');
    }
    try {
      final BigInt amount = _amount(json['amount'] ?? '0');
      final List<int> data = _bytes(json['data']);
      if (data.length > kDappBridgeMaxData) {
        throw const FormatException();
      }
      return DappBridgeBlock(
        toAddress: Address.parse(json['toAddress']! as String),
        tokenStandard: TokenStandard.parse(
          json['tokenStandard'] as String? ?? znnTokenStandard,
        ),
        amount: amount,
        data: data,
      );
    } on DappBridgeError {
      rethrow;
    } on Object {
      throw const DappBridgeError.invalidParams('Not an account block');
    }
  }

  /// The receiver, or the contract called.
  final Address toAddress;

  /// The token sent.
  final TokenStandard tokenStandard;

  /// How much, in the token's smallest unit.
  final BigInt amount;

  /// The contract call, or empty for a plain send.
  final List<int> data;

  /// An amount in the token's smallest unit, in the forms the extension
  /// takes (`ethers.BigNumber.from`): a decimal string, a `0x` hex string,
  /// or a JSON number that is a whole number no larger than 2^53 - 1. A
  /// larger number was already rounded by the page that wrote it.
  static BigInt _amount(Object raw) {
    if (raw is int) {
      if (raw < 0 || raw > kDappBridgeMaxSafeInteger) {
        throw const FormatException();
      }
      return BigInt.from(raw);
    }
    if (raw is! String ||
        !RegExp(r'^([0-9]{1,78}|0x[0-9a-fA-F]{1,64})$').hasMatch(raw)) {
      throw const FormatException();
    }
    return BigInt.parse(raw);
  }

  /// Base64, as the SDK writes it; a byte array; or a Node `Buffer` as JSON.
  /// The three forms the extension takes.
  static List<int> _bytes(Object? raw) {
    Object? value = raw;
    if (value == null || value == '') {
      return const <int>[];
    }
    if (value is String) {
      return base64.decode(value);
    }
    if (value is Map && value['type'] == 'Buffer') {
      value = value['data'];
    }
    if (value is List &&
        value.every((Object? b) => b is int && b >= 0 && b <= 255)) {
      return value.cast<int>();
    }
    throw const FormatException();
  }
}
