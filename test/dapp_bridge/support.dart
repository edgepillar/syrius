// Fakes and a page-side client for the channel's tests. Not a test file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_block.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';

/// Real addresses, so the block parser sees what a page would send.
const String kA = 'z1qq9n7fpaqd8lpcljandzmx4xtku9w4ftwyg0mq';
const String kB = 'z1qxemdeddedxplasmaxxxxxxxxxxxxxxxxsctrp';
const String kTo = 'z1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsggv2f';
const String kZnn = 'zts1znnxxxxxxxxxxxxx9z4ulx';
const String kSite = 'https://bridge.zenon.foo';
const String kOther = 'https://other.example';

/// A wallet with no window: it answers approvals from fields and records
/// what it was asked. It signs and sends whatever it is handed, locked or
/// not, so a test that finds nothing signed has tested the service's rule
/// and not this fake's.
class FakeWallet implements DappBridgeWallet {
  String? selected = kA;
  bool locked = false;
  @override
  int chainId = 321;
  @override
  String? nodeUrl = 'wss://user:key@node.example:35998/secret?k=1';

  /// The answer to every approval.
  bool approve = true;

  /// When set, approvals wait on it.
  Completer<bool>? hold;

  /// When set, every approval ends unanswered, as when a lock takes the
  /// dialog down. Read when the approval ends, so a test can set it while
  /// one is held.
  bool dismiss = false;

  /// When set and the wallet is locked, a request waits on it; when null, it
  /// is refused as if the five minutes had passed.
  Completer<void>? unlock;

  /// When set, approvals throw it, as an expired one does.
  DappBridgeError? failWith;

  /// When set, signing throws it: a failure inside the wallet.
  Object? signFailure;

  final List<String> prompts = <String>[];
  final List<String> signed = <String>[];
  final List<DappBridgeBlock> sent = <DappBridgeBlock>[];

  /// How many times a request brought the wallet forward.
  int raised = 0;

  @override
  String? get selectedAddress => locked ? null : selected;

  @override
  Future<void> waitUnlocked() async {
    raised++;
    if (!locked) {
      return;
    }
    final Completer<void>? waiting = unlock;
    if (waiting == null) {
      throw const DappBridgeError.locked();
    }
    await waiting.future;
  }

  Future<DappBridgeAnswer> _ask(String what) async {
    prompts.add(what);
    final DappBridgeError? error = failWith;
    if (error != null) {
      throw error;
    }
    final bool yes = await (hold?.future ?? Future<bool>.value(approve));
    if (dismiss) {
      return DappBridgeAnswer.dismissed;
    }
    return yes ? DappBridgeAnswer.approved : DappBridgeAnswer.declined;
  }

  @override
  Future<DappBridgeAnswer> approveConnect(String origin, String address) =>
      _ask('connect $origin $address');

  @override
  Future<DappBridgeAnswer> approveSign(
    String origin,
    String address,
    String message,
  ) => _ask('sign $origin $address $message');

  @override
  Future<({String publicKey, String signature})> sign(
    String address,
    String message,
  ) async {
    if (signFailure != null) {
      throw signFailure!;
    }
    signed.add(message);
    return (publicKey: 'pk-$address', signature: 'sig-${signed.length}');
  }

  @override
  Future<DappBridgeAnswer> approveSend(
    String origin,
    String address,
    DappBridgeBlock block,
  ) => _ask('send $origin $address ${block.toAddress}');

  @override
  Future<Map<String, Object?>> send(
    String origin,
    String address,
    DappBridgeBlock block,
  ) async {
    sent.add(block);
    return <String, Object?>{
      'hash': 'h${sent.length}',
      'block': <String, Object?>{
        'address': address,
        'toAddress': block.toAddress.toString(),
        'amount': block.amount.toString(),
        'tokenStandard': block.tokenStandard.toString(),
        'data': base64.encode(block.data),
      },
    };
  }
}

/// The settings box, in memory.
class MemoryStore implements DappBridgeStore {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

/// A clock a test moves by hand.
class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 13, 12);

  void advance(Duration by) => now = now.add(by);
}

/// A web page's end of the socket: JSON-RPC requests with their own ids,
/// notifications kept in order.
class Page {
  Page._(this.socket, this.hello) {
    _subscription = socket.listen(_onFrame);
  }

  /// Opens a socket to [port] as a browser would from [origin].
  static Future<Page> open(
    int port, {
    String origin = kSite,
  }) async {
    final WebSocket socket = await WebSocket.connect(
      'ws://127.0.0.1:$port',
      headers: <String, dynamic>{'Origin': origin},
    );
    final Completer<Map<String, dynamic>> hello =
        Completer<Map<String, dynamic>>();
    final Page page = Page._(socket, hello);
    await hello.future;
    return page;
  }

  final WebSocket socket;
  final Completer<Map<String, dynamic>> hello;
  late final StreamSubscription<dynamic> _subscription;
  final Map<Object, Completer<Map<String, dynamic>>> _waiting =
      <Object, Completer<Map<String, dynamic>>>{};
  final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  int _id = 0;

  void _onFrame(dynamic frame) {
    final Map<String, dynamic> message =
        jsonDecode(frame as String) as Map<String, dynamic>;
    if (message['method'] == 'syrius_hello' && !hello.isCompleted) {
      hello.complete(message['params'] as Map<String, dynamic>);
      return;
    }
    if (message.containsKey('id')) {
      _waiting.remove(message['id'])?.complete(message);
      return;
    }
    events.add(message);
    _events.add(message);
  }

  /// Sends a request and waits for its reply.
  Future<Map<String, dynamic>> call(String method, [Object? params]) {
    final int id = ++_id;
    final Completer<Map<String, dynamic>> reply =
        Completer<Map<String, dynamic>>();
    _waiting[id] = reply;
    socket.add(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ?params,
      }),
    );
    return reply.future.timeout(const Duration(seconds: 5));
  }

  /// The result of [method], failing the test on an error.
  Future<Object?> result(String method, [Object? params]) async {
    final Map<String, dynamic> reply = await call(method, params);
    expect(reply['error'], isNull, reason: '$method: ${reply['error']}');
    return reply['result'];
  }

  /// The error code of [method], failing the test on a result.
  Future<int> code(String method, [Object? params]) async {
    final Map<String, dynamic> reply = await call(method, params);
    expect(reply.containsKey('error'), isTrue, reason: '$method: $reply');
    return (reply['error'] as Map<String, dynamic>)['code'] as int;
  }

  /// The next notification, as `[method, params]`.
  Future<List<Object?>> nextEvent() async {
    final Map<String, dynamic> event = await _events.stream.first.timeout(
      const Duration(seconds: 5),
    );
    return <Object?>[event['method'], event['params']];
  }

  /// Every notification so far, as `method params`.
  List<String> get eventLog => <String>[
    for (final Map<String, dynamic> e in events)
      '${e['method']} ${e['params']}',
  ];

  Future<void> close() async {
    await socket.close();
    await _subscription.cancel();
    await _events.close();
  }
}

/// A channel over [wallet] on a port the OS picks, so a suite never meets a
/// running wallet.
DappBridgeChannel testChannel({
  required FakeWallet wallet,
  required DappBridgeStore store,
  required FakeClock clock,
  List<Uri>? opened,
}) => DappBridgeChannel(
  wallet: wallet,
  store: store,
  open: (Uri url) async => opened?.add(url),
  ports: const <int>[0],
  watch: const Duration(milliseconds: 20),
  now: () => clock.now,
);

/// Lets the channel's one-second watch, here twenty milliseconds, run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));
