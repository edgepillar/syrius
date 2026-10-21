import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_link.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_server.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';

/// The version of the handshake, sent in `syrius_hello`.
const int kDappBridgeProtocol = 1;

/// What the wallet's own screens may do with the channel: the Settings
/// switch and the Connected sites list are written against this, so they are
/// tested without a socket.
abstract class DappBridgeControl {
  /// The app's channel, registered by `DappBridge` when the app creates it.
  /// The widgets reach it here rather than by importing the app.
  static DappBridgeControl? app;

  /// [app], or a clear failure when the app has not created its channel.
  static DappBridgeControl of() =>
      app ?? (throw StateError('The page-to-desktop channel is not created'));

  /// Whether the person has the channel on.
  bool get enabled;

  /// The port being listened on, or null when off or when none was free.
  int? get port;

  /// Saves the choice, then starts or stops listening.
  Future<void> setEnabled({required bool enabled});

  /// The connected requesters.
  List<DappBridgeSite> get sites;

  /// Withdraws [requester]'s consent.
  Future<void> disconnect(String requester);

  /// Fires when [enabled], [port] or [sites] may have changed.
  Stream<void> get changes;
}

/// The page-to-desktop channel in one piece: the loopback server, the
/// `syrius://request` path, the service behind both, and the consent and the
/// on/off choice in a [DappBridgeStore].
///
/// It knows the wallet only as a [DappBridgeWallet], so the whole channel
/// runs in a test over a real socket with a fake wallet behind it.
class DappBridgeChannel implements DappBridgeControl {
  /// Creates a channel over [wallet] that keeps its settings in [store].
  /// [open] opens a URL in the browser, for a link's answer.
  DappBridgeChannel({
    required DappBridgeWallet wallet,
    required DappBridgeStore store,
    required Future<void> Function(Uri url) open,
    List<int> ports = kDappBridgePorts,
    Duration watch = const Duration(seconds: 1),
    DateTime Function() now = DateTime.now,
  }) : _store = store,
       _ports = ports,
       _watchEvery = watch,
       _consent = DappBridgeConsentStore(store) {
    _service = DappBridgeService(wallet: wallet, consent: _consent, now: now);
    _links = DappBridgeLinks(handler: _service.handle, open: open);
    _consentChanges = _consent.changes.listen((_) => _notify());
  }

  final DappBridgeStore _store;
  final List<int> _ports;
  final Duration _watchEvery;
  final DappBridgeConsentStore _consent;
  late final DappBridgeService _service;
  late final DappBridgeLinks _links;
  late final StreamSubscription<void> _consentChanges;
  final Logger _logger = Logger('DappBridge');
  final StreamController<void> _changes = StreamController<void>.broadcast();
  DappBridgeServer? _server;
  Timer? _watch;
  Future<void> _turn = Future<void>.value();

  @override
  bool get enabled => _store.read(kDappBridgeEnabledKey) != false;

  @override
  int? get port => _server?.port;

  @override
  List<DappBridgeSite> get sites => _consent.sites;

  @override
  Stream<void> get changes => _changes.stream;

  /// Starts listening, unless the person has turned the channel off.
  Future<void> start() => _inTurn(_start);

  /// Stops listening and closes every page's socket.
  Future<void> stop() => _inTurn(_stop);

  @override
  Future<void> setEnabled({required bool enabled}) => _inTurn(() async {
    await _store.write(kDappBridgeEnabledKey, enabled);
    await (enabled ? _start() : _stop());
  });

  @override
  Future<void> disconnect(String requester) => _service.revoke(requester);

  /// To be called when the selected address changes, the wallet locks or
  /// unlocks, or the node or chain changes. The channel also looks for
  /// itself every second, so a call that is missed costs a second, not an
  /// event.
  void walletChanged() {
    final DappBridgeServer? server = _server;
    if (server != null) {
      _service.walletChanged(server.origins);
    }
  }

  /// Takes a `syrius://request` link. Completes with true once the answer
  /// has been opened. A link that does not parse, or that arrives while the
  /// channel is off, gets no answer.
  Future<bool> handleLink(Uri link) =>
      enabled ? _links.handle(link) : Future<bool>.value(false);

  /// Stops and releases the channel.
  Future<void> close() async {
    await stop();
    await _consentChanges.cancel();
    await _consent.close();
    await _changes.close();
  }

  /// Start and stop one after the other. Two starts at once would each bind
  /// a port.
  Future<void> _inTurn(Future<void> Function() run) {
    final Future<void> next = _turn.then((_) => run());
    _turn = next.catchError((Object _) {});
    return next.whenComplete(_notify);
  }

  Future<void> _start() async {
    if (_server != null || !enabled) {
      return;
    }
    final DappBridgeServer server = DappBridgeServer(
      handler: _service.handle,
      ports: _ports,
      // Said to any page that reaches the socket, before any consent, so it
      // says nothing about this wallet: not an address, not whether it is
      // locked.
      hello: () => <String, Object?>{
        'wallet': 'syrius-desktop',
        'protocol': kDappBridgeProtocol,
      },
      // Records what a new page sees now, so the next change is a change.
      onOpen: (_) => walletChanged(),
    );
    final int? bound = await server.start();
    if (bound == null) {
      _logger.warning('no free port');
      return;
    }
    _logger.info('listening on $bound');
    _service.emit = server.emit;
    _server = server;
    _watch = Timer.periodic(_watchEvery, (_) => walletChanged());
  }

  Future<void> _stop() async {
    _watch?.cancel();
    _watch = null;
    final DappBridgeServer? server = _server;
    _server = null;
    _service.emit = null;
    await server?.stop();
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}
