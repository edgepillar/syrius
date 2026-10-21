import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';

/// The sites the person has connected.
class ConnectedSitesState extends Equatable {
  /// Creates a state.
  const ConnectedSitesState({
    this.sites = const <DappBridgeSite>[],
    this.failed = false,
  });

  /// Sorted by origin.
  final List<DappBridgeSite> sites;

  /// The last Disconnect did not go through.
  final bool failed;

  @override
  List<Object?> get props => <Object?>[sites, failed];
}

/// Lists the connected sites and disconnects them. The list follows the
/// channel: a page that connects or disconnects itself shows at once.
class ConnectedSitesCubit extends Cubit<ConnectedSitesState> {
  /// Creates a cubit over [control].
  ConnectedSitesCubit(DappBridgeControl control)
    : _control = control,
      super(ConnectedSitesState(sites: control.sites)) {
    _changes = control.changes.listen((_) => _refresh());
  }

  final DappBridgeControl _control;
  late final StreamSubscription<void> _changes;

  /// Withdraws [requester]'s consent. Its pages are told they see no
  /// account, and its next request is refused until it connects again.
  Future<void> disconnect(String requester) async {
    try {
      await _control.disconnect(requester);
      _refresh();
    } on Object {
      if (!isClosed) {
        emit(ConnectedSitesState(sites: _control.sites, failed: true));
      }
    }
  }

  void _refresh() {
    if (!isClosed) {
      emit(ConnectedSitesState(sites: _control.sites));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
