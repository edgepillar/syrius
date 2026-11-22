import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';

/// A shader's clock, measured only while its surface can be seen.
///
/// Muting a Ticker leaves its elapsed time running. Stopping it instead,
/// and accumulating only active ticks, keeps a hidden field from jumping
/// ahead when its page or window returns. No animation-effects setting is
/// read: the owner's motion rule applies whenever the surface is visible.
class ShaderClock extends ChangeNotifier
    with WidgetsBindingObserver, WindowListener
    implements ValueListenable<double> {
  /// Creates one ticker owned by the surface's [vsync].
  ShaderClock({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
    final WidgetsBinding binding = WidgetsBinding.instance;
    _lifecycle = binding.lifecycleState;
    binding.addObserver(this);
    windowManager.addListener(this);
    FrostHold.count.addListener(_sync);
    unawaited(_readWindowFocus());
  }

  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration _lastTick = Duration.zero;
  AppLifecycleState? _lifecycle;
  bool _active = false;
  bool _visible = false;
  bool _focused = true;
  bool _waitingForFocus = false;
  bool _minimized = false;
  bool _disposed = false;
  int _focusRevision = 0;

  /// Seconds spent drawing an active, visible surface.
  @override
  double get value => _elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  /// Whether the effect has work to draw. A still meter leaves this false.
  bool get active => _active;

  /// Starts or holds the effect without changing its accumulated time.
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    _sync();
  }

  /// Whether this clock currently schedules frames.
  bool get isRunning => _ticker.isActive;

  /// Updates visibility from the owner's dependency change, including a
  /// route covered by another page. No BuildContext is retained.
  void updateVisibility(BuildContext context) {
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    _sync();
  }

  void _sync() {
    if (_disposed) return;
    final bool resumed =
        _lifecycle == null || _lifecycle == AppLifecycleState.resumed;
    final bool run =
        _active &&
        _visible &&
        _focused &&
        !_waitingForFocus &&
        !_minimized &&
        resumed &&
        FrostHold.count.value == 0;
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final Duration delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (delta <= Duration.zero) return;
    _elapsed += delta;
    notifyListeners();
  }

  Future<void> _readWindowFocus({bool holdUntilResolved = false}) async {
    final int revision = ++_focusRevision;
    _waitingForFocus = holdUntilResolved;
    if (holdUntilResolved) _sync();
    bool? focused;
    try {
      focused = await windowManager.isFocused();
    } on Object {
      // A missing desktop plugin must not prevent the flat fallback or an
      // isolated widget preview. Lifecycle and TickerMode still apply.
    }
    // A focus event arriving during this query is newer than its answer.
    if (_disposed || revision != _focusRevision) return;
    _focused = focused ?? _focused;
    _waitingForFocus = false;
    _sync();
  }

  @override
  void onWindowBlur() {
    _focusRevision += 1;
    _focused = false;
    _waitingForFocus = false;
    _sync();
  }

  @override
  void onWindowFocus() {
    _focusRevision += 1;
    _focused = true;
    _waitingForFocus = false;
    _sync();
  }

  @override
  void onWindowMinimize() {
    _minimized = true;
    onWindowBlur();
  }

  @override
  void onWindowRestore() {
    if (!_minimized) return;
    _minimized = false;
    // A focus event can precede restore. Verify the restored window's focus.
    onWindowBlur();
    unawaited(_readWindowFocus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      // The focus value from before suspension may no longer be current.
      unawaited(_readWindowFocus(holdUntilResolved: true));
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    FrostHold.count.removeListener(_sync);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }
}
