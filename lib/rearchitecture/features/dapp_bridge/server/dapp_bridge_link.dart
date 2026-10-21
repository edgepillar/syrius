import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_origin.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_server.dart';

/// The methods a `syrius://request` may carry: the Android app's list.
///
/// `znn_disconnect` is not among them. A link proves nothing about who wrote
/// it, so any page could disconnect any site by naming its callback.
const Set<String> kDappBridgeLinkMethods = <String>{
  'znn_connect',
  'znn_sendTransaction',
  'znn_signAndSendBlock',
  'znn_sign',
  'znn_accounts',
  'znn_chainId',
  'znn_nodeUrl',
};

/// Links kept while another is being answered. A burst of links is one
/// person clicking, not a queue, so the oldest gives way. The Android app's
/// number.
const int kDappBridgeMaxLinks = 4;

/// The longest callback URL opened whole. Windows refuses to open a URL much
/// past 2,000 characters.
const int kDappBridgeMaxCallback = 2000;

/// One request read from a `syrius://request` link.
class DappBridgeLinkRequest {
  /// Creates a request.
  const DappBridgeLinkRequest({
    required this.method,
    required this.params,
    required this.id,
    required this.callback,
    required this.requester,
  });

  /// One of [kDappBridgeLinkMethods].
  final String method;

  /// The decoded params, or null.
  final Object? params;

  /// The page's correlation id, returned as is.
  final String id;

  /// Where the answer is opened.
  final Uri callback;

  /// Who is asking: the callback's origin behind [kDappBridgeLinkPrefix].
  final String requester;
}

/// Whether [link] is a `syrius://request`, whatever else is wrong with it.
///
/// The action is the host. `syrius:request?…` puts it in the path, and
/// Windows hands over `syrius://request/?…`.
bool isDappBridgeLink(Uri link) {
  if (link.scheme != 'syrius') {
    return false;
  }
  final String action = link.host.isNotEmpty
      ? link.host
      : link.path.replaceAll(RegExp(r'^/+|/+$'), '');
  return action.toLowerCase() == 'request';
}

/// Reads a `syrius://request?method&params&id&callback` link, in the form
/// the Syrius Android app takes (`syrius-extension/docs/APP-REQUESTS.md`).
///
/// Returns null for a link that does not parse. Such a link gets no answer:
/// there is nowhere safe to send one.
DappBridgeLinkRequest? parseDappBridgeLink(Uri link, {DateTime? now}) {
  if (!isDappBridgeLink(link) ||
      link.toString().length > kDappBridgeMaxMessage) {
    return null;
  }
  final Map<String, String> query;
  try {
    query = link.queryParameters;
  } on Object {
    return null;
  }
  final String? method = query['method'];
  final Uri? callback = Uri.tryParse(query['callback'] ?? '');
  if (method == null ||
      !kDappBridgeLinkMethods.contains(method) ||
      callback == null) {
    return null;
  }
  final String? requester = dappBridgeLinkRequester(callback);
  if (requester == null) {
    return null;
  }
  final Object? params;
  try {
    params = _decodeParams(query['params']);
  } on Object {
    return null;
  }
  final String? id = query['id'];
  return DappBridgeLinkRequest(
    method: method,
    params: params,
    // A page that sent no usable id still gets an answer it can recognise
    // as the wallet's.
    id: id != null && id.isNotEmpty && id.length <= 128
        ? id
        : 'syrius-${(now ?? DateTime.now()).millisecondsSinceEpoch}',
    callback: callback,
    requester: requester,
  );
}

/// The callback with the answer added: `id`, and `result` or `error` as
/// base64url JSON. A parameter of the same name is replaced; the rest of the
/// callback, fragment included, is kept.
Uri dappBridgeCallback(
  Uri callback,
  String id, {
  Object? result,
  DappBridgeError? error,
}) {
  final Map<String, List<String>> query = <String, List<String>>{
    for (final MapEntry<String, List<String>> entry
        in callback.queryParametersAll.entries)
      if (!const <String>{'id', 'result', 'error'}.contains(entry.key))
        entry.key: entry.value,
    'id': <String>[id],
    if (error != null)
      'error': <String>[_base64UrlJson(error.toJson())]
    else
      'result': <String>[_base64UrlJson(result)],
  };
  return callback.replace(queryParameters: query);
}

/// `params` as JSON, or as base64url of the JSON (the form that survives
/// every program's link handling).
Object? _decodeParams(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final String text = RegExp(r'^\s*[\[{"]').hasMatch(raw)
      ? raw
      : utf8.decode(base64Url.decode(base64Url.normalize(raw)));
  return jsonDecode(text);
}

String _base64UrlJson(Object? value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

/// Answers `syrius://request` links: the path for a page whose browser will
/// not open a socket to loopback.
///
/// The request goes through the same handler as a socket's, so the rules,
/// the approvals and the consent are the same. Only the transport differs:
/// the answer is opened as the callback URL in the browser, which is why
/// every answer costs the person a browser tab.
class DappBridgeLinks {
  /// Creates the link path over [handler]. [open] opens a URL in the browser.
  DappBridgeLinks({
    required DappBridgeHandler handler,
    required Future<void> Function(Uri url) open,
  }) : _handler = handler,
       _open = open;

  final DappBridgeHandler _handler;
  final Future<void> Function(Uri url) _open;
  final Logger _logger = Logger('DappBridgeLinks');
  final Queue<(DappBridgeLinkRequest, Completer<bool>)> _waiting =
      Queue<(DappBridgeLinkRequest, Completer<bool>)>();
  bool _running = false;

  /// Takes [link]. Completes with true once its answer has been opened, and
  /// with false when the link did not parse or gave way to newer ones.
  Future<bool> handle(Uri link) {
    final DappBridgeLinkRequest? request = parseDappBridgeLink(link);
    if (request == null) {
      return Future<bool>.value(false);
    }
    final Completer<bool> done = Completer<bool>();
    _waiting.add((request, done));
    while (_waiting.length > kDappBridgeMaxLinks) {
      _waiting.removeFirst().$2.complete(false);
    }
    if (!_running) {
      unawaited(_drain());
    }
    return done.future;
  }

  /// One at a time: the next approval waits for the one on screen.
  Future<void> _drain() async {
    _running = true;
    try {
      while (_waiting.isNotEmpty) {
        final (DappBridgeLinkRequest request, Completer<bool> done) = _waiting
            .removeFirst();
        done.complete(await _answer(request));
      }
    } finally {
      _running = false;
    }
  }

  Future<bool> _answer(DappBridgeLinkRequest request) async {
    Uri answer;
    try {
      final Object? result = await _handler(
        request.requester,
        request.method,
        request.params,
      );
      answer = dappBridgeCallback(request.callback, request.id, result: result);
      // A sent block comes back with its JSON. With a contract call inside,
      // that makes a URL longer than Windows will open, so the block gives
      // way and the hash, which finds it on any node, stays.
      if (answer.toString().length > kDappBridgeMaxCallback &&
          result is Map &&
          result.containsKey('hash')) {
        answer = dappBridgeCallback(
          request.callback,
          request.id,
          result: <String, Object?>{'hash': result['hash']},
        );
      }
    } on DappBridgeError catch (e) {
      answer = dappBridgeCallback(request.callback, request.id, error: e);
    } on Object catch (e, s) {
      _logger.warning('link request from ${request.requester} failed', e, s);
      answer = dappBridgeCallback(
        request.callback,
        request.id,
        error: const DappBridgeError.internal(),
      );
    }
    try {
      await _open(answer);
      return true;
    } on Object catch (e, s) {
      _logger.warning('callback not opened', e, s);
      return false;
    }
  }
}
