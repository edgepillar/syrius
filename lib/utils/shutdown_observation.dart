/// Fixed labels for the application's existing close operations.
enum ShutdownPhase {
  /// No application close callback has started.
  idle,
  /// Reads native maximized state.
  windowMaximizedRead,
  /// Saves native maximized state.
  windowMaximizedSave,
  /// Reads native size.
  windowSizeRead,
  /// Saves native width.
  windowWidthSave,
  /// Saves native height.
  windowHeightSave,
  /// Reads native position.
  windowPositionRead,
  /// Saves native horizontal position.
  windowXSave,
  /// Saves native vertical position.
  windowYSave,
  /// Requests the original SDK socket stop.
  webSocketStop,
  /// Enters the original embedded-node close operation.
  embeddedNodeClose,
  /// Reads the platform wake-lock state.
  wakeLockRead,
  /// Releases an existing wake lock.
  wakeLockDisable,
  /// Sends the original embedded-node stop request.
  embeddedStopRequest,
  /// Awaits the original embedded-node exit receipt.
  embeddedStopWait,
  /// Cancels the original exit subscription.
  embeddedCleanup,
  /// Resets the existing service registry.
  serviceReset,
  /// Runs the existing root-widget cleanup.
  widgetDispose,
  /// Calls the original process exit.
  exitRequested,
}

/// A passive close observation. It owns no operation, timer or error payload.
class ShutdownObservation {
  Object? _owner;
  ShutdownPhase _phase = ShutdownPhase.idle;
  bool _failed = false;
  void Function(Map<String, Object>)? _observer;

  /// Retains one process observer; a later caller cannot replace it.
  bool observe(void Function(Map<String, Object>) observer) {
    if (_observer != null) return false;
    _observer = observer;
    _emit();
    return true;
  }

  void _emit() {
    try {
      _observer?.call(snapshot());
    } on Object {
      // A diagnostic sink must never interrupt the original close operation.
    }
  }

  /// Retains the first closing root; another root cannot replace its record.
  void begin(Object owner) {
    _owner ??= owner;
    mark(owner, ShutdownPhase.windowMaximizedRead);
  }

  /// Records only the original root and ignores late terminal-stage changes.
  void mark(Object owner, ShutdownPhase phase) {
    if (!identical(owner, _owner) ||
        _failed ||
        _phase == ShutdownPhase.exitRequested ||
        _phase == phase ||
        phase == ShutdownPhase.idle) {
      return;
    }
    _phase = phase;
    _emit();
  }

  /// Retains failure without retaining an exception, stack or private value.
  void fail(Object owner) {
    if (identical(owner, _owner) && !_failed) {
      _failed = true;
      _emit();
    }
  }

  /// Exposes fixed labels only; callers cannot mutate the retained record.
  Map<String, Object> snapshot() => <String, Object>{
    'phase': _phase.name,
    'failed': _failed,
  };
}

/// Observed by the authenticated harness without changing application close.
final ShutdownObservation appShutdownObservation = ShutdownObservation();
