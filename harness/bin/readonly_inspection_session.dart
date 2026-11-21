import 'dart:convert';

import '../app/readonly_native_commands.dart'
    show readonlyActivityMessageSeamCommand, readonlyAgedFuseFixtureCommand,
        readonlyHomeZapPreviewCommand,
        readonlySeamPointerCommand,
        readonlySendWarningSyncCommand;
import '../app/readonly_native_mode.dart';
import 'screen_capture.dart';
import 'wallet_recipe.dart' show WalletRecipeSend;

/// A fixed refusal label never carries private input or response diagnostics.
enum ReadonlyInspectionReason { process, retired, command, reply, binding }

/// No uncertain command can be replayed through this inspection session.
class ReadonlyInspectionRefused
    implements Exception, ScreenCaptureReplyFailure,
        ScreenCaptureFrameStateFailure {
  /// The reason is source-defined rather than copied from an original error.
  const ReadonlyInspectionRefused(this.reason, {
    this._captureReply, this._captureFrameState,
  });

  /// The missing admission, without a profile, address, token or error text.
  final ReadonlyInspectionReason reason;
  final ScreenCaptureReplyCode? _captureReply;
  final CaptureFrameState? _captureFrameState;

  @override
  ScreenCaptureReplyCode? get captureReply => _captureReply;

  @override
  CaptureFrameState? get captureFrameState => _captureFrameState;
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
    readonlyHomeZapPreviewCommand,
    readonlySendWarningSyncCommand,
    readonlySeamPointerCommand,
    readonlyActivityMessageSeamCommand,
    readonlyAgedFuseFixtureCommand,
  };
  static const int _collapsedRail = 40;
  static const int _expandedRail = 184;

  /// The same native process must answer every subsequent original command.
  final int processId;
  final WalletRecipeSend _original;
  bool _held = false;
  bool _running = false;
  bool _binding = false;
  bool _bindingReserved = false;
  bool _walletBound = false;
  bool _agedFuseReserved = false;
  ScreenCaptureReplyCode? _heldReply;
  CaptureFrameState? _heldFrameState;

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
      if ((!_commands.contains(name) &&
              !(name == 'readonly-wallet-bind' && _binding)) ||
          (name == readonlyHomeZapPreviewCommand ||
              name == readonlyActivityMessageSeamCommand ||
              name == readonlyAgedFuseFixtureCommand ||
              name == readonlySendWarningSyncCommand) &&
              (!_walletBound || command.length != 1)) {
        _refuse(ReadonlyInspectionReason.command);
      }
      if (name == readonlyAgedFuseFixtureCommand) {
        if (_agedFuseReserved) _refuse(ReadonlyInspectionReason.command);
        _agedFuseReserved = true;
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
        _heldReply = classifyScreenCaptureReply(
          reply['error'], reply['detail'],
        );
        _heldFrameState = classifyScreenCaptureFrameState(
          reply['error'], reply['detail'],
        );
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

  /// Reads one completed rail width from the original positive tree reply.
  /// Text is folded into buttons; it is not a separate label-key node.
  Future<bool> railExpanded() async {
    final int width = (await _readRail(const Duration(seconds: 30))).first;
    if (width != _collapsedRail && width != _expandedRail) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.railGeometryInvalid);
    }
    return width == _expandedRail;
  }

  Future<List<int>> _readRail(Duration timeout, {bool motion = false}) async {
    if (!_walletBound) _refuse(ReadonlyInspectionReason.binding);
    final Map<String, dynamic> reply = await send(
      <String, Object?>{'cmd': 'tree', if (motion) 'railMotion': true}, timeout,
    );
    final Object? nodes = reply['nodes'];
    if (reply['ok'] != true || nodes is! List || nodes.length > 16384) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.railTreeInvalid);
    }
    Map<String, dynamic>? toggle;
    for (final Object? node in nodes) {
      if (node is! Map<String, dynamic> || node['kind'] == 'error') {
        _refuse(ReadonlyInspectionReason.reply,
          captureReply: ScreenCaptureReplyCode.railTreeInvalid);
      }
      if (node['key'] == 'rail_toggle') {
        if (toggle != null || node['kind'] != 'button' ||
            (node['enabled'] != null && node['enabled'] != true)) {
          _refuse(ReadonlyInspectionReason.reply,
            captureReply: ScreenCaptureReplyCode.railTreeInvalid);
        }
        toggle = node;
      }
    }
    if (toggle == null) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.railTreeInvalid);
    }
    final Object? rect = toggle['rect'];
    // Original AppTokens widths 56/200, minus the two 8-pixel rail insets.
    // The original agent emits logical [left, top, width, height] integers.
    if (rect is! List || rect.length != 4 ||
        rect.any((Object? value) => value is! int ||
            value < 0 || value > 32768) ||
        rect[3] != 32 ||
        (rect[2] as int) < _collapsedRail || (rect[2] as int) > _expandedRail) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.railGeometryInvalid);
    }
    final int width = rect[2] as int;
    if (!motion) return <int>[width];
    final Object? presentation = reply['railMotion'];
    if (presentation is! List || presentation.length != 2 ||
        presentation[0] is! int || presentation[1] is! int ||
        (presentation[0] as int) < 0 || (presentation[0] as int) > 3142 ||
        (presentation[1] as int) < 0 || (presentation[1] as int) > 1000) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.railGeometryInvalid);
    }
    return <int>[width, presentation[0] as int, presentation[1] as int];
  }

  /// Prepares only the already opened Home in this bound native session.
  Future<void> prepareScreenHome() => restoreScreenRail(expanded: false);

  /// Restores the Home rail through positive replies from the same process.
  /// A failed script on another page is held rather than navigated blindly.
  Future<void> restoreScreenRail({required bool expanded}) async {
    await _requireScreenHome();
    if (await railExpanded() != expanded) {
      await _moveScreenRail(expanded ? _expandedRail : _collapsedRail);
    }
    await _requireScreenHome();
  }

  /// Samples both rail directions from the same original Home process.
  /// Offsets are measured after the tap reply, including tree response time.
  Future<Map<String, List<List<int>>>> observeRailMotion() async {
    await _requireScreenHome();
    final bool originallyExpanded = await railExpanded();
    final List<List<int>> opening = <List<int>>[];
    final List<List<int>> closing = <List<int>>[];
    final int first = originallyExpanded ? _collapsedRail : _expandedRail;
    final int last = originallyExpanded ? _expandedRail : _collapsedRail;
    await _moveScreenRail(
      first, samples: originallyExpanded ? closing : opening,
    );
    await _moveScreenRail(
      last, samples: originallyExpanded ? opening : closing,
    );
    await _requireScreenHome();
    return <String, List<List<int>>>{'opening': opening, 'closing': closing};
  }

  Future<void> _moveScreenRail(int target, {List<List<int>>? samples}) async {
    final Map<String, dynamic> reply = await send(
      <String, Object?>{
        'cmd': 'tap', 'key': 'rail_toggle', if (samples != null) 'settleMs': 0,
      },
      const Duration(seconds: 30),
    );
    if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);

    // A pointer reply may arrive before the original spring paints its last
    // frame. Observe only the positive tree for this single owned toggle.
    final Stopwatch elapsed = Stopwatch()..start();
    const Duration window = Duration(seconds: 2);
    final Duration interval =
        Duration(milliseconds: samples == null ? 120 : 40);
    final int sampleLimit = samples == null ? 6 : 12;
    final int expectedAngle = target == _expandedRail ? 3142 : 0;
    final int expectedOpacity = target == _expandedRail ? 1000 : 0;
    for (int sample = 0; sample < sampleLimit; sample++) {
      final Duration remaining = window - elapsed.elapsed;
      if (remaining <= Duration.zero) break;
      final List<int> values = await _readRail(
        remaining, motion: samples != null,
      );
      final int offset = elapsed.elapsedMicroseconds;
      if (offset > window.inMicroseconds) break;
      samples?.add(<int>[offset, ...values]);
      if (values.first == target &&
          (samples == null ||
              values[1] == expectedAngle && values.last == expectedOpacity)) {
        return;
      }
      if (sample < sampleLimit - 1 && elapsed.elapsed + interval < window) {
        await Future<void>.delayed(interval);
      }
    }
    _refuse(ReadonlyInspectionReason.reply,
      captureReply: ScreenCaptureReplyCode.railEndpointMissing);
  }

  Future<void> _requireScreenHome() async {
    if (!_walletBound) _refuse(ReadonlyInspectionReason.binding);
    final Map<String, dynamic> state = await send(
      <String, Object?>{'cmd': 'state'}, const Duration(seconds: 30),
    );
    final Object? tabs = state['tabs'];
    if (state['ok'] != true || state['walletUnlocked'] != true ||
        state['walletInitCompleted'] != true ||
        state['tab'] != 'dashboard' || state['locale'] != 'en' ||
        state['direction'] != 'ltr' || tabs is! List ||
        tabs.isEmpty || tabs.length > 16 ||
        tabs.any((Object? value) => value is! String) ||
        tabs.toSet().length != tabs.length || !tabs.contains('dashboard')) {
      _refuse(ReadonlyInspectionReason.reply,
        captureReply: ScreenCaptureReplyCode.homeStateInvalid);
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

  Never _refuse(ReadonlyInspectionReason reason, {
    ScreenCaptureReplyCode? captureReply,
  }) {
    _held = true;
    throw ReadonlyInspectionRefused(reason,
      captureReply: _heldReply ?? captureReply,
      captureFrameState: _heldFrameState,
    );
  }
}
