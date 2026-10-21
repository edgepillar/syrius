import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_origin.dart';

/// Answers one request from [origin]. Throws a [DappBridgeError] to refuse.
typedef DappBridgeHandler =
    Future<Object?> Function(
      String origin,
      String method,
      Object? params,
    );

/// The ports tried in order. A page tries the same three.
const List<int> kDappBridgePorts = <int>[35996, 45996, 55996];

/// The largest message accepted, in UTF-16 code units. The extension's limit.
const int kDappBridgeMaxMessage = 128 * 1024;

/// Open sockets allowed per origin.
const int kDappBridgeMaxPerOrigin = 4;

/// Open sockets allowed in all.
const int kDappBridgeMaxSockets = 32;

/// Requests one socket may have in flight.
const int kDappBridgeMaxInFlight = 8;

/// The longest method name read. The extension's limit.
const int kDappBridgeMaxMethod = 64;

/// The wallet's end of the page-to-desktop channel: a WebSocket on loopback
/// that carries JSON-RPC 2.0.
///
/// A desktop app cannot inject a provider into a page the way the extension
/// does, and WalletConnect needs a relay and a project id, so a page reaches
/// the desktop wallet here instead. The server knows nothing of wallets: it
/// decides who may connect (see `dapp_bridge_origin.dart`) and hands each
/// request, with the origin that made it, to the handler.
class DappBridgeServer {
  /// Creates a server that answers through [handler].
  DappBridgeServer({
    required DappBridgeHandler handler,
    Map<String, Object?> Function()? hello,
    void Function(String origin)? onOpen,
    List<int> ports = kDappBridgePorts,
  }) : _handler = handler,
       _hello = hello,
       _onOpen = onOpen,
       _ports = ports;

  final DappBridgeHandler _handler;
  final Map<String, Object?> Function()? _hello;
  final void Function(String origin)? _onOpen;
  final List<int> _ports;
  final Logger _logger = Logger('DappBridgeServer');
  final Map<WebSocket, String> _sockets = <WebSocket, String>{};
  final Map<WebSocket, int> _inFlight = <WebSocket, int>{};
  HttpServer? _server;

  /// The port being listened on, or null when stopped.
  int? get port => _server?.port;

  /// The address being listened on, or null when stopped. Always loopback.
  InternetAddress? get address => _server?.address;

  /// The origins with an open socket.
  Set<String> get origins => _sockets.values.toSet();

  /// Starts listening on the first free port. Returns it, or null when all
  /// are taken: the wallet then works as before, without the channel.
  Future<int?> start() async {
    if (_server != null) {
      return port;
    }
    for (final int candidate in _ports) {
      try {
        // Loopback only. Nothing off this machine can reach the listener.
        final HttpServer server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          candidate,
        );
        _server = server;
        server.listen(
          _onRequest,
          onError: (Object e, StackTrace s) =>
              _logger.warning('listener error', e, s),
        );
        return server.port;
      } on SocketException {
        continue;
      }
    }
    _logger.warning('no free port among $_ports');
    return null;
  }

  /// Closes the listener and every socket.
  Future<void> stop() async {
    final HttpServer? server = _server;
    _server = null;
    for (final WebSocket socket in _sockets.keys.toList()) {
      await socket.close(WebSocketStatus.goingAway);
    }
    _sockets.clear();
    _inFlight.clear();
    await server?.close(force: true);
  }

  /// Sends a notification to the sockets of [origin], or to all when null.
  void emit(String event, Object? params, {String? origin}) {
    final String frame = jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'method': event,
      'params': params,
    });
    _sockets.forEach((WebSocket socket, String socketOrigin) {
      if (origin == null || origin == socketOrigin) {
        socket.add(frame);
      }
    });
  }

  Future<void> _onRequest(HttpRequest request) async {
    final int? listening = port;
    // A header sent twice has no one value. A browser never does that, so
    // the request is refused like any other that names no origin.
    final String? origin = dappBridgeRequester(_single(request, 'origin'));
    if (listening == null ||
        !isLoopbackHostHeader(_single(request, 'host'), listening) ||
        origin == null ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      await _refuse(request, HttpStatus.forbidden);
      return;
    }
    if (_sockets.length >= kDappBridgeMaxSockets ||
        _sockets.values.where((String o) => o == origin).length >=
            kDappBridgeMaxPerOrigin) {
      await _refuse(request, HttpStatus.serviceUnavailable);
      return;
    }
    final WebSocket socket;
    try {
      // No compression. The size limit is applied to a message after it has
      // been inflated, so with permessage-deflate a few kilobytes on the
      // wire could be made to occupy the wallet's memory many times over
      // before the limit is ever looked at. The messages are small anyway.
      socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
      );
    } catch (e, s) {
      _logger.warning('upgrade failed', e, s);
      return;
    }
    _sockets[socket] = origin;
    _inFlight[socket] = 0;
    _onOpen?.call(origin);
    socket.listen(
      (dynamic frame) => unawaited(_onFrame(socket, origin, frame)),
      onDone: () => _forget(socket),
      onError: (Object _) => _forget(socket),
      cancelOnError: true,
    );
    final Map<String, Object?>? hello = _hello?.call();
    if (hello != null) {
      socket.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'method': 'syrius_hello',
          'params': hello,
        }),
      );
    }
  }

  String? _single(HttpRequest request, String header) {
    final List<String>? values = request.headers[header];
    return values != null && values.length == 1 ? values.single : null;
  }

  /// A refusal says nothing: a status and no body, and no CORS header, so a
  /// page's script cannot read even that.
  Future<void> _refuse(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      await request.response.close();
    } on Object catch (e, s) {
      _logger.fine('refusal not delivered', e, s);
    }
  }

  void _forget(WebSocket socket) {
    _sockets.remove(socket);
    _inFlight.remove(socket);
  }

  Future<void> _onFrame(WebSocket socket, String origin, dynamic frame) async {
    if (frame is! String || frame.length > kDappBridgeMaxMessage) {
      _forget(socket);
      await socket.close(WebSocketStatus.messageTooBig);
      return;
    }
    Object? id;
    try {
      final dynamic message;
      try {
        message = jsonDecode(frame);
      } on FormatException {
        throw const DappBridgeError.invalidParams('Not JSON');
      }
      if (message is! Map<String, dynamic>) {
        throw const DappBridgeError.invalidParams('Not a JSON-RPC request');
      }
      final dynamic rawId = message['id'];
      // An id that cannot be echoed safely is not echoed at all.
      // 1e999 decodes to infinity, which cannot be written back as JSON.
      if ((rawId is num && rawId.isFinite) ||
          (rawId is String && rawId.isNotEmpty && rawId.length <= 128)) {
        id = rawId as Object;
      }
      final dynamic method = message['method'];
      if (id == null ||
          method is! String ||
          method.isEmpty ||
          method.length > kDappBridgeMaxMethod) {
        throw const DappBridgeError.invalidParams('Not a JSON-RPC request');
      }
      if ((_inFlight[socket] ?? 0) >= kDappBridgeMaxInFlight) {
        throw const DappBridgeError.busy();
      }
      _inFlight[socket] = (_inFlight[socket] ?? 0) + 1;
      final Object? result;
      try {
        result = await _handler(origin, method, message['params']);
      } finally {
        if (_inFlight.containsKey(socket)) {
          _inFlight[socket] = _inFlight[socket]! - 1;
        }
      }
      _reply(socket, <String, Object?>{'id': id, 'result': result});
    } on DappBridgeError catch (e) {
      _reply(socket, <String, Object?>{'id': id, 'error': e.toJson()});
    } catch (e, s) {
      // What went wrong inside the wallet is not the page's to read.
      _logger.warning('request from $origin failed', e, s);
      _reply(socket, <String, Object?>{
        'id': id,
        'error': const DappBridgeError.internal().toJson(),
      });
    }
  }

  void _reply(WebSocket socket, Map<String, Object?> body) {
    if (_sockets.containsKey(socket)) {
      socket.add(jsonEncode(<String, Object?>{'jsonrpc': '2.0', ...body}));
    }
  }
}
