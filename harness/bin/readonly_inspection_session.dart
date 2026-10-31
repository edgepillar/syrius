import 'dart:convert';

import '../app/readonly_native_mode.dart';
import 'wallet_recipe.dart' show WalletRecipeSend;

/// A fixed refusal label never carries private input or response diagnostics.
enum ReadonlyInspectionReason { process, retired, command, reply, binding }

/// No uncertain command can be replayed through this inspection session.
class ReadonlyInspectionRefused implements Exception {
  /// The reason is source-defined rather than copied from an original error.
  const ReadonlyInspectionRefused(this.reason);

  /// The missing admission, without a profile, address, token or error text.
  final ReadonlyInspectionReason reason;
}

/// Checks every original reply without rewriting the actual harness mode.
/// The caller retains the original loopback endpoint and process ownership.
class ReadonlyInspectionSession {
  /// Production supplies the original transport; tests own isolated actors.
  ReadonlyInspectionSession({
    required int processId,
    required WalletRecipeSend original,
  }) : this._(processId, original);

  ReadonlyInspectionSession._(this.processId, this._original) {
    if (processId <= 0) {
      _refuse(ReadonlyInspectionReason.process);
    }
  }

  static const Set<String> _commands = <String>{
    'ping', 'state', 'readonly-state', 'readonly-entry', 'lock-view',
    'entry-caption', 'entry-state', 'entry-check', 'entry-capture',
    'tree', 'tap', 'hover', 'type', 'key', 'scroll', 'drag', 'drop',
    'wait', 'assert', 'shot', 'theme', 'logs', 'stalls', 'window', 'quit',
  };

  /// The same native process must answer every subsequent original command.
  final int processId;
  final WalletRecipeSend _original;
  bool _held = false;
  bool _running = false;
  bool _binding = false;
  bool _bindingReserved = false;
  bool _walletBound = false;

  /// The wallet scope begins only after the actual bind command completes.
  bool get walletBound => _walletBound;

  /// A negative reply is returned unchanged, then permanently holds the lane.
  /// Original exceptions and their traces propagate without another request.
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command,
    Duration timeout,
  ) async {
    if (_held || _running) {
      _refuse(ReadonlyInspectionReason.retired);
    }
    _running = true;
    try {
      final Object? name = command['cmd'];
      if (!_commands.contains(name) &&
          !(name == 'readonly-wallet-bind' && _binding)) {
        _refuse(ReadonlyInspectionReason.command);
      }
      // Nested input must not change while the original HTTP request awaits.
      final Map<String, Object?> retained = Map<String, Object?>.unmodifiable(
        jsonDecode(jsonEncode(command)) as Map<String, dynamic>,
      );
      if (_held) {
        _refuse(ReadonlyInspectionReason.retired);
      }
      final Map<String, dynamic> reply = await _original(retained, timeout);
      if (reply['ok'] != true) {
        _held = true;
        return reply;
      }
      if (_held || !harnessReadonlyNativeLaunchMatches(reply, processId) ||
          (_walletBound &&
              !harnessReadonlyNativeWalletMatches(reply, processId))) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      return reply;
    } on Object {
      _held = true;
      rethrow;
    } finally {
      _running = false;
    }
  }

  /// Reserves one original native frame/wallet bind before any transport call.
  Future<Map<String, dynamic>> bindWallet() async {
    if (_held || _running || _bindingReserved) {
      _refuse(ReadonlyInspectionReason.binding);
    }
    _bindingReserved = true;
    _binding = true;
    try {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': 'readonly-wallet-bind'},
        const Duration(seconds: 30),
      );
      if (_held || reply['ok'] != true ||
          !harnessReadonlyNativeWalletMatches(reply, processId)) {
        _refuse(ReadonlyInspectionReason.binding);
      }
      _walletBound = true;
      return reply;
    } finally {
      _binding = false;
    }
  }

  Never _refuse(ReadonlyInspectionReason reason) {
    _held = true;
    throw ReadonlyInspectionRefused(reason);
  }
}
