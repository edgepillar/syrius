import 'dart:convert';

import '../app/readonly_native_commands.dart'
    show readonlyActivityMessageSeamCommand, readonlyAgedFuseFixtureCommand,
        readonlyEyeMotionCommand,
        readonlyHomeZapPreviewCommand,
        readonlySeamPointerCommand,
        readonlySegmentMotionCommand,
        readonlySendWarningSyncCommand, readonlySheenHoverCommand,
        readonlySyncPulseCommand;
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
    readonlySyncPulseCommand,
    readonlySegmentMotionCommand,
    readonlyEyeMotionCommand,
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
              name == readonlySendWarningSyncCommand ||
              name == readonlySyncPulseCommand ||
              name == readonlySegmentMotionCommand ||
              name == readonlyEyeMotionCommand) &&
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

  /// Samples the status halo and the painted Home drift without new frames.
  Future<List<List<int>>> observeSyncPulse() async {
    await _requireScreenHome();
    final Stopwatch elapsed = Stopwatch()..start();
    const Duration limit = Duration(seconds: 6);
    const Duration interval = Duration(milliseconds: 200);
    final List<List<int>> samples = <List<int>>[];
    while (samples.length < 31) {
      final Duration sent = elapsed.elapsed;
      if (sent + interval >= limit) break;
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': readonlySyncPulseCommand},
        limit - sent,
      );
      final Object? phase = reply['phaseMilli'];
      final Object? drift = reply['paintedHomeDriftMillionths'];
      if (reply['ok'] != true || phase is! int || phase < 0 || phase > 1000 ||
          (drift != null && (drift is! int || drift < 0 || drift > 1000000))) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      final Duration observed = elapsed.elapsed;
      if (observed > limit) break;
      samples.add(<int>[
        sent.inMicroseconds, observed.inMicroseconds, phase,
        if (drift is int) drift,
      ]);
      await Future<void>.delayed(interval);
    }
    await _requireScreenHome();
    return samples;
  }

  Future<List<Object>?> _readHomeFieldClock(Duration timeout) async {
    final Map<String, dynamic> reply = await send(
      <String, Object?>{'cmd': readonlySyncPulseCommand}, timeout,
    );
    final Object? clock = reply['homeFieldClock'];
    if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
    if (clock == null) return null;
    if (clock case [final bool running, final int us]
        when us >= 0 && us <= 1800000000) {
      return <Object>[running, us];
    }
    _refuse(ReadonlyInspectionReason.reply);
  }

  /// Reads the same Home field around one normal Go To open and dismissal.
  Future<Map<String, Object?>> observeHomeFieldOcclusion() async {
    await _requireScreenHome();
    const Duration timeout = Duration(seconds: 5);
    const Duration spacing = Duration(milliseconds: 250);

    Future<void> key(String value) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': 'key', 'key': value}, timeout,
      );
      if (reply['ok'] != true || reply['handled'] != true) {
        _refuse(ReadonlyInspectionReason.reply);
      }
    }

    Future<void> waitForPalette({required bool gone}) async {
      final Map<String, dynamic> reply = await send(<String, Object?>{
        'cmd': 'wait', 'key': 'go_to_field', 'exact': true, 'gone': gone,
        'timeoutMs': 4000,
      }, timeout);
      if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
    }

    final List<Object>? before = await _readHomeFieldClock(timeout);
    await key('ctrl+k');
    await waitForPalette(gone: false);
    await Future<void>.delayed(spacing);
    final List<Object>? coveredStart = await _readHomeFieldClock(timeout);
    await Future<void>.delayed(spacing);
    final List<Object>? coveredEnd = await _readHomeFieldClock(timeout);
    await key('escape');
    await waitForPalette(gone: true);
    await Future<void>.delayed(spacing);
    final List<Object>? after = await _readHomeFieldClock(timeout);
    await _requireScreenHome();
    return <String, Object?>{
      'before': before, 'covered_start': coveredStart,
      'covered_end': coveredEnd, 'after': after,
    };
  }

  /// Observes the original Home clock through native minimize and show.
  Future<Map<String, Object?>?> observeHomeFieldMinimize() async {
    await _requireScreenHome();
    const Duration timeout = Duration(seconds: 5);
    const Duration spacing = Duration(milliseconds: 250);

    Future<Map<String, dynamic>> window([String? action]) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': 'window', 'do': ?action},
        timeout,
      );
      if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
      return reply;
    }

    final Map<String, dynamic> initial = await window();
    final Object? bounds = initial['window'];
    if (initial['minimized'] != false || initial['maximized'] != false ||
        bounds is! List || bounds.length != 4 ||
        bounds.any((dynamic value) => value is! num || !value.isFinite)) {
      return null;
    }
    final List<Object>? before = await _readHomeFieldClock(timeout);
    if (before == null) return null;
    final Map<String, dynamic> minimized = await window('minimize');
    if (minimized['minimized'] != true) _refuse(ReadonlyInspectionReason.reply);
    await Future<void>.delayed(spacing);
    final List<Object>? minimizedStart = await _readHomeFieldClock(timeout);
    await Future<void>.delayed(spacing);
    final List<Object>? minimizedEnd = await _readHomeFieldClock(timeout);
    final Map<String, dynamic> shown = await window('show');
    if (shown['minimized'] != false || shown['maximized'] != false ||
        jsonEncode(shown['window']) != jsonEncode(bounds)) {
      _refuse(ReadonlyInspectionReason.reply);
    }
    await Future<void>.delayed(spacing);
    List<Object>? after = await _readHomeFieldClock(timeout);
    if (after != null && minimizedEnd != null && after[1] == minimizedEnd[1]) {
      // A restarted ticker may not have received an advancing frame yet.
      await Future<void>.delayed(spacing);
      after = await _readHomeFieldClock(timeout);
    }
    await _requireScreenHome();
    return <String, Object?>{
      'before': before,
      'minimized_start': minimizedStart,
      'minimized_end': minimizedEnd,
      'after': after,
    };
  }

  /// Reads the original Home Send paint after an ordinary pointer hover.
  Future<List<List<int>>> observeSheenHover() async {
    await _requireScreenHome();
    const Duration budget = Duration(seconds: 2);
    const Duration spacing = Duration(milliseconds: 25);
    const int end = 1000000;

    Future<void> hover(Map<String, Object?> target, int settleMs) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': 'hover', ...target, 'settleMs': settleMs},
        budget,
      );
      if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
    }

    Future<int> phaseAfterPaint(Duration timeout) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': readonlySheenHoverCommand}, timeout,
      );
      final Object? phase = reply['paintedProgress'];
      if (reply['ok'] != true || phase is! int || phase < 0 || phase > end) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      return phase;
    }

    final Map<String, Object?> away = <String, Object?>{'at': <int>[0, 0]};
    await hover(away, 650);
    final int before = await phaseAfterPaint(budget);
    if (before != 0 && before != end) _refuse(ReadonlyInspectionReason.reply);
    await hover(<String, Object?>{'key': 'home_send', 'exact': true}, 0);
    final Stopwatch clock = Stopwatch()..start();
    final List<List<int>> samples = <List<int>>[];
    try {
      for (int index = 0; index < 32 && clock.elapsed < budget; index++) {
        final int phase = await phaseAfterPaint(budget - clock.elapsed);
        if (clock.elapsed > budget) break;
        if (phase > 0 &&
            (phase < end || samples.isNotEmpty ||
                clock.elapsedMilliseconds >= 700)) {
          if (samples.isNotEmpty && phase < samples.last[1]) {
            _refuse(ReadonlyInspectionReason.reply);
          }
          samples.add(<int>[clock.elapsedMicroseconds, phase]);
          if (phase == end) break;
        }
        if (clock.elapsed + spacing >= budget) break;
        await Future<void>.delayed(spacing);
      }
      if (samples.isEmpty || samples.last[1] != end) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      return samples;
    } finally {
      await hover(away, 0);
    }
  }

  /// Samples both directions of the original Home balance eye and restores it.
  Future<Map<String, List<List<int>>>> observeEyeMotion() async {
    await _requireScreenHome();
    const Duration budget = Duration(seconds: 2);
    const Duration interval = Duration(milliseconds: 40);

    Future<(bool, int)> read(Duration timeout) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': readonlyEyeMotionCommand},
        timeout,
      );
      final Object? hidden = reply['hidden'];
      final Object? frame = reply['frameMilli'];
      if (reply['ok'] != true || hidden is! bool || frame is! int) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      return (hidden, frame);
    }

    if (await read(budget) != (false, 226000)) {
      _refuse(ReadonlyInspectionReason.reply);
    }
    final Map<String, List<List<int>>> result = <String, List<List<int>>>{};
    for (final bool hide in <bool>[true, false]) {
      final int first = hide ? 3250 : 200000;
      final int last = hide ? 30000 : 226000;
      final Map<String, dynamic> tapped = await send(
        <String, Object?>{'cmd': 'tap', 'key': 'home_eye', 'settleMs': 0},
        budget,
      );
      if (tapped['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
      final Stopwatch clock = Stopwatch()..start();
      final List<List<int>> samples = <List<int>>[];
      for (int index = 0; index < 16 && clock.elapsed < budget; index++) {
        final (bool hidden, int frame) = await read(budget - clock.elapsed);
        if (clock.elapsed > budget) break;
        if (hidden == hide) {
          if (frame < first || frame > last ||
              (samples.isNotEmpty && frame < samples.last[1])) {
            _refuse(ReadonlyInspectionReason.reply);
          }
          samples.add(<int>[clock.elapsedMicroseconds, frame]);
          if (frame == last) break;
        } else if (samples.isNotEmpty) {
          _refuse(ReadonlyInspectionReason.reply);
        }
        if (clock.elapsed + interval >= budget) break;
        await Future<void>.delayed(interval);
      }
      if (samples.isEmpty || samples.last[1] != last) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      result[hide ? 'hide' : 'show'] = samples;
    }
    await _requireScreenHome();
    return result;
  }

  /// Observes the original thumb after an ordinary segment tap on each page.
  Future<Map<String, Object>> observeSegmentMotion() async {
    await _requireScreenHome();
    final Map<String, Object> result = <String, Object>{};
    const Duration budget = Duration(seconds: 2);
    const Duration interval = Duration(milliseconds: 40);
    const Duration ordinary = Duration(seconds: 30);

    Future<void> tap(Map<String, Object?> arguments) async {
      final Map<String, dynamic> reply = await send(
        <String, Object?>{'cmd': 'tap', ...arguments}, ordinary,
      );
      if (reply['ok'] != true) _refuse(ReadonlyInspectionReason.reply);
    }

    bool settled(List<int> values) =>
        values[0] == values[2] && values[1] == values[3];

    for (final (String tab, String prefix, List<String> choices) in const <
      (String, String, List<String>)
    >[
      ('transfer', 'transfer_mode', <String>['send', 'receive', 'zap']),
      ('tokens', 'tokens_filter', <String>['held', 'all', 'favorites']),
    ]) {
      await tap(<String, Object?>{'tab': tab});
      final (String original, List<int> before) = await _readSegment(ordinary);
      if (!choices.contains(original) || !settled(before)) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      final String next =
          choices.first == original ? choices[1] : choices.first;
      await tap(<String, Object?>{'key': '${prefix}_$next', 'settleMs': 0});
      final Stopwatch clock = Stopwatch()..start();
      final List<List<int>> samples = <List<int>>[];
      for (int i = 0; i < 12 && clock.elapsed < budget; i++) {
        final (String current, List<int> values) =
            await _readSegment(budget - clock.elapsed);
        if (current != next && (current != original || samples.isNotEmpty)) {
          _refuse(ReadonlyInspectionReason.reply);
        }
        if (clock.elapsed > budget) break;
        if (current == next) {
          samples.add(<int>[clock.elapsedMicroseconds, ...values]);
          if (settled(values)) break;
        }
        if (clock.elapsed + interval >= budget) break;
        await Future<void>.delayed(interval);
      }
      if (samples.isEmpty || !settled(samples.last.sublist(1))) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      await tap(<String, Object?>{'key': '${prefix}_$original'});
      final (String restored, List<int> finish) = await _readSegment(ordinary);
      if (restored != original || !settled(finish)) {
        _refuse(ReadonlyInspectionReason.reply);
      }
      result[tab] = <String, Object>{
        'before': before.take(2).toList(), 'samples': samples,
      };
    }
    await tap(<String, Object?>{'tab': 'dashboard'});
    await _requireScreenHome();
    return result;
  }

  Future<(String, List<int>)> _readSegment(Duration timeout) async {
    final Map<String, dynamic> reply = await send(
      <String, Object?>{'cmd': readonlySegmentMotionCommand}, timeout,
    );
    final Object? selected = reply['selected'];
    final Object? geometry = reply['geometry'];
    if (reply['ok'] != true || selected is! String ||
        geometry is! List || geometry.length != 4 ||
        geometry.any((Object? n) => n is! int || n < 0 || n > 1_280_000)) {
      _refuse(ReadonlyInspectionReason.reply);
    }
    return (selected, List<int>.from(geometry));
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
