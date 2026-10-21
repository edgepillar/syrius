/// A deliberate change of node, told to whoever holds data from the old one.
///
/// The SDK's `restartedStream` speaks only when a dropped connection comes
/// back. A node chosen in Settings is not that, so nothing heard of it: the
/// blocs that outlive a page (balances, the activity lists, the token list)
/// kept the other node's answers, and the Send card showed 0 ZNN on a funded
/// address until its Refresh was pressed. And the cache each page paints from
/// was keyed by the bloc's type alone, so a page first showed the other
/// chain's figures.
///
/// Two halves. [NodeChange.announce] is called once the wallet talks to the
/// new node, and every `RefreshBlocMixin` bloc fetches again.
/// [nodeScopedStoragePrefix] keys a hydrated bloc's cache by the node, so a
/// page built after the switch starts from that node's last answers, or
/// from nothing, and never from another chain's.
library;

import 'dart:async';

import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

/// See the library comment.
abstract final class NodeChange {
  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  /// One event per change of node.
  static Stream<void> get stream => _changes.stream;

  /// To be called after `kCurrentNode` holds the new node and the
  /// connection to it is up.
  static void announce() => _changes.add(null);
}

/// The storage prefix of a hydrated bloc of [type], for the current node.
String nodeScopedStoragePrefix(Type type) => '${kCurrentNode ?? ''}|$type';
