import 'dart:async';
import 'dart:ui';

import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/node_change.dart';

mixin RefreshBlocMixin {
  StreamSubscription? _restartWsStreamSubscription;
  StreamSubscription<void>? _nodeChangeSubscription;

  void listenToWsRestart(VoidCallback onWsConnectionRestartedCallback) {
    // A node chosen in Settings is not a restart to the SDK, and has to
    // bring the same refresh.
    _nodeChangeSubscription = NodeChange.stream.listen(
      (_) => onWsConnectionRestartedCallback(),
    );
    _restartWsStreamSubscription = zenon?.wsClient.restartedStream.listen(
          (bool restarted) {
        _restartWsStreamSubscription = zenon?.wsClient.restartedStream.listen(
          (bool restarted) {
        if (restarted) {
          onWsConnectionRestartedCallback();
        }},
        );
      },
    );
  }

  void cancelStreamSubscription() {
    _restartWsStreamSubscription?.cancel();
    _nodeChangeSubscription?.cancel();
  }
}
