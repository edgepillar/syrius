/// A refusal sent back to a page. The codes are the Syrius extension's, which
/// follow EIP-1193, so a page handles both wallets with one table.
class DappBridgeError implements Exception {
  /// Creates an error with a [code] from the extension's table.
  const DappBridgeError(this.code, this.message);

  /// The person declined.
  const DappBridgeError.declined() : this(4001, 'Declined in wallet');

  /// The origin has not been connected.
  const DappBridgeError.notConnected() : this(4100, 'Not connected');

  /// The method does not exist.
  const DappBridgeError.unknownMethod() : this(4200, 'Unknown method');

  /// The wallet stayed locked, or changed under the request.
  const DappBridgeError.locked([String message = 'Wallet is locked'])
    : this(4900, message);

  /// The parameters are malformed.
  const DappBridgeError.invalidParams([String message = 'Invalid params'])
    : this(-32602, message);

  /// Too many requests are waiting. The page may try again later.
  const DappBridgeError.busy([String message = 'Too many requests waiting'])
    : this(-32005, message);

  /// Nobody answered the approval in time. Nothing was signed.
  const DappBridgeError.expired() : this(-32006, 'Approval expired. Ask again');

  /// Something failed inside the wallet. What failed is not the page's to
  /// read, so the message never varies.
  const DappBridgeError.internal() : this(-32603, 'Wallet error');

  /// The numeric code.
  final int code;

  /// One short line a page can show.
  final String message;

  /// The JSON-RPC error object.
  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
  };

  @override
  String toString() => 'DappBridgeError($code, $message)';
}
