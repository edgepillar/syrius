import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class Signature {

  Signature(this.signature, this.publicKey);
  String signature;
  String publicKey;
}

/// The bytes a text message is signed as, and verified against: its UTF-8
/// encoding. One function, so the web channel, the Sign panel and the Verify
/// panel cannot disagree about what was signed.
///
/// Throws a [FormatException] for a message of exactly 32 bytes: that is the
/// size of an account block hash, and signing it would sign a transaction
/// under the name of a message.
List<int> messageBytesToSign(String message) {
  final List<int> bytes = utf8.encode(message);
  if (bytes.length == 32) {
    // Shown under the message field of the Sign and Verify panels. A web page
    // never gets this text: the dapp bridge refuses such a message itself, in
    // its own fixed words, before it asks for a signature.
    throw FormatException(currentL10n.signMessage32BytesError);
  }
  return bytes;
}

/// Signs [message] as text with the selected address. See
/// [messageBytesToSign].
Future<Signature> walletSignMessage(String message) =>
    walletSign(messageBytesToSign(message));

Future<Signature> walletSign(List<int> message) async {
  final Wallet wallet = await kWalletFile!.open();
  try {
    final WalletAccount walletAccount = await wallet
        .getAccount(kDefaultAddressList.indexOf(kSelectedAddress));
    final List<int> publicKey = await walletAccount.getPublicKey();
    final List<int> signature = await walletAccount.sign(
      Uint8List.fromList(
        message,
      ),
    );
    return Signature(
        BytesUtils.bytesToHex(signature), BytesUtils.bytesToHex(publicKey),);
  } finally {
    kWalletFile!.close();
  }
}

Future<dynamic> loadJsonFromAssets(String filePath) async {
  final String jsonString = await rootBundle.loadString(filePath);
  return jsonDecode(jsonString);
}