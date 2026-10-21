import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';

/// The Settings switch's view of the channel.
class DappBridgeSwitchState extends Equatable {
  /// Creates a state.
  const DappBridgeSwitchState({
    required this.enabled,
    this.port,
    this.saving = false,
    this.failed = false,
  });

  /// Whether the person has the channel on.
  final bool enabled;

  /// The port listened on, or null when off or when none was free.
  final int? port;

  /// A change is being saved and applied.
  final bool saving;

  /// The last change could not be saved.
  final bool failed;

  @override
  List<Object?> get props => <Object?>[enabled, port, saving, failed];
}

/// Turns the page-to-desktop channel on and off, and keeps the choice.
class DappBridgeSwitchCubit extends Cubit<DappBridgeSwitchState> {
  /// Creates a cubit over [control].
  DappBridgeSwitchCubit(DappBridgeControl control)
    : _control = control,
      super(_read(control)) {
    _changes = control.changes.listen((_) => _refresh());
  }

  final DappBridgeControl _control;
  late final StreamSubscription<void> _changes;

  /// Saves [enabled] and starts or stops listening.
  Future<void> setEnabled({required bool enabled}) async {
    emit(
      DappBridgeSwitchState(enabled: enabled, port: state.port, saving: true),
    );
    try {
      await _control.setEnabled(enabled: enabled);
      _refresh();
    } on Object {
      if (!isClosed) {
        final DappBridgeSwitchState now = _read(_control);
        emit(
          DappBridgeSwitchState(
            enabled: now.enabled,
            port: now.port,
            failed: true,
          ),
        );
      }
    }
  }

  void _refresh() {
    if (!isClosed) {
      emit(_read(_control));
    }
  }

  static DappBridgeSwitchState _read(DappBridgeControl control) =>
      DappBridgeSwitchState(enabled: control.enabled, port: control.port);

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
