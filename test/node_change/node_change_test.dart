import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/refresh_bloc_mixin.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/node_change.dart';

class _Holder with RefreshBlocMixin {
  int refreshes = 0;
}

void main() {
  tearDown(() => kCurrentNode = null);

  test('a change of node refreshes a RefreshBlocMixin bloc, once each', () async {
    final _Holder holder = _Holder()
      ..listenToWsRestart(() {});
    holder.cancelStreamSubscription();
    final _Holder counted = _Holder();
    counted.listenToWsRestart(() => counted.refreshes++);

    NodeChange.announce();
    await Future<void>.delayed(Duration.zero);
    expect(counted.refreshes, 1);
    NodeChange.announce();
    await Future<void>.delayed(Duration.zero);
    expect(counted.refreshes, 2);

    counted.cancelStreamSubscription();
    NodeChange.announce();
    await Future<void>.delayed(Duration.zero);
    expect(counted.refreshes, 2, reason: 'a disposed bloc hears nothing');
  });

  test('a cache key is the node and the bloc type', () {
    kCurrentNode = 'ws://127.0.0.1:45998';
    final String lab = nodeScopedStoragePrefix(_Holder);
    kCurrentNode = 'wss://node.zenonhub.io:35998';
    final String mainnet = nodeScopedStoragePrefix(_Holder);
    expect(lab, isNot(mainnet));
    expect(lab, contains('_Holder'));
    expect(nodeScopedStoragePrefix(String), isNot(mainnet));
    kCurrentNode = 'ws://127.0.0.1:45998';
    expect(nodeScopedStoragePrefix(_Holder), lab);
  });
}
