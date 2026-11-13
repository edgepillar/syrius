import 'dart:async';

/// Frame completion and permission to read pixels are separate facts.
enum CaptureFrameStatus {
  /// The original frame has not settled or passed its admission deadline.
  pending,

  /// The original frame completed before its admission deadline.
  ready,

  /// Missing, failed or late frame proof permanently holds this scope.
  held,
}

/// A finite refusal category, without the original error or trace.
enum CaptureFrameRefusalReason {
  /// Another original frame or readback still owns admission.
  busy,

  /// The original frame did not settle before its admission deadline.
  deadline,

  /// The original frame callback or Future failed before admission.
  originalFailure,

  /// Observing the frame or its admission clock failed.
  admissionFailure,
}

/// Counts callbacks since the original frame request, without scheduling.
final class CaptureFrameCallbackCounter {
  /// A saturated observation stays unknown until another admitted request.
  static const int maxCallbacks = 65535;

  int _count = 0;
  bool _known = true;

  /// Starts observation before the existing request; it requests no frame.
  void begin() {
    _count = 0;
    _known = true;
  }

  /// Records one actual persistent callback without changing its delivery.
  void observe() {
    if (!_known) return;
    if (_count == maxCallbacks) {
      _known = false;
    } else {
      _count++;
    }
  }

  /// Unknown is explicit, rather than an exact count after saturation.
  Object get value => _known ? _count : 'unknown';
}

/// Closed scheduler facts, without frame, window or wallet identities.
final class CaptureFrameState {
  const CaptureFrameState._(
    this.schedulerPhase, this.lifecycleState, this.framesEnabled,
    this.hasScheduledFrame, this.bindingCurrent, {
    this.beginFrameCallbackRegistered,
    this.drawFrameCallbackRegistered,
    this.persistentCallbacksObserved,
  });

  /// Refuses free text, extra fields and coerced values before retention.
  static CaptureFrameState? fromJson(Object? value) {
    if (value is! Map<Object?, Object?> || value['schema'] is! int ||
        (value['schema'] != 1 && value['schema'] != 2) ||
        value.length != (value['schema'] == 1 ? 6 : 9)) {
      return null;
    }
    final Object? phase = value['scheduler_phase'];
    final Object? lifecycle = value['lifecycle_state'];
    final Object? enabled = value['frames_enabled'];
    final Object? scheduled = value['has_scheduled_frame'];
    final Object? current = value['binding_current'];
    if (phase is! String || !const <String>{
          'idle', 'transientCallbacks', 'midFrameMicrotasks',
          'persistentCallbacks', 'postFrameCallbacks',
        }.contains(phase) ||
        lifecycle is! String || !const <String>{
          'none', 'detached', 'resumed', 'inactive', 'hidden', 'paused',
        }.contains(lifecycle) ||
        enabled is! bool || scheduled is! bool || current is! bool) {
      return null;
    }
    if (value['schema'] == 1) {
      return CaptureFrameState._(phase, lifecycle, enabled, scheduled, current);
    }
    final Object? begin = value['begin_frame_callback_registered'];
    final Object? draw = value['draw_frame_callback_registered'];
    final Object? callbacks = value['persistent_callbacks_observed'];
    if (begin is! bool || draw is! bool ||
        !(callbacks is int && callbacks >= 0 &&
              callbacks <= CaptureFrameCallbackCounter.maxCallbacks ||
          callbacks is String && callbacks == 'unknown')) {
      return null;
    }
    return CaptureFrameState._(phase, lifecycle, enabled, scheduled, current,
      beginFrameCallbackRegistered: begin,
      drawFrameCallbackRegistered: draw,
      persistentCallbacksObserved: callbacks,
    );
  }

  /// Phase read from the original binding at its first refusal.
  final String schedulerPhase;
  /// Lifecycle value read at that same observation.
  final String lifecycleState;
  /// Whether normal frame scheduling was enabled at that observation.
  final bool framesEnabled;
  /// Whether the original binding already had a scheduled frame.
  final bool hasScheduledFrame;
  /// Whether the captured binding still was the installed binding.
  final bool bindingCurrent;
  /// Whether the original dispatcher's begin callback was present at refusal.
  final bool? beginFrameCallbackRegistered;
  /// Whether the original dispatcher's draw callback was present at refusal.
  final bool? drawFrameCallbackRegistered;
  /// Actual callbacks since this request, or unknown after bounded saturation.
  /// Legacy records contain no observation.
  final Object? persistentCallbacksObserved;

  /// Exports only the validated finite facts, never a mutable source map.
  Map<String, Object> toJson() => Map<String, Object>.unmodifiable(
    <String, Object>{
      'schema': beginFrameCallbackRegistered == null ? 1 : 2,
      'scheduler_phase': schedulerPhase,
      'lifecycle_state': lifecycleState, 'frames_enabled': framesEnabled,
      'has_scheduled_frame': hasScheduledFrame,
      'binding_current': bindingCurrent,
      if (beginFrameCallbackRegistered != null) ...<String, Object>{
        'begin_frame_callback_registered': beginFrameCallbackRegistered!,
        'draw_frame_callback_registered': drawFrameCallbackRegistered!,
        'persistent_callbacks_observed': persistentCallbacksObserved!,
      },
    },
  );
}

/// The actual original frame result, including after admission was refused.
final class CaptureFrameOutcome {
  CaptureFrameOutcome._(this.completed, this.error, this.stackTrace);

  /// True only when the original frame Future completed without an error.
  final bool completed;

  /// The unchanged original failure, absent after successful completion.
  final Object? error;

  /// The exact trace received with the original frame failure.
  final StackTrace? stackTrace;
}

/// Anonymous refusal; the original diagnostic stays in its retained receipt.
final class CaptureFrameRefused implements Exception {
  /// Refuses pending admission, a held scope or another capture in progress.
  const CaptureFrameRefused();

  @override
  String toString() => 'The original capture frame is unavailable';
}

/// One original frame Future, with a separate once-only admission decision.
final class CaptureFrameReceipt {
  CaptureFrameReceipt._(this._observeState);

  final CaptureFrameState? Function()? _observeState;
  final Completer<bool> _admission = Completer<bool>();
  final Completer<CaptureFrameOutcome> _completion =
      Completer<CaptureFrameOutcome>();
  Future<void>? _original;
  CaptureFrameOutcome? _outcome;
  CaptureFrameStatus _status = CaptureFrameStatus.pending;
  bool _timedOut = false;
  Object? _admissionError;
  StackTrace? _admissionTrace;
  CaptureFrameState? _refusalState;
  bool _refusalStateObserved = false;

  /// A late original success cannot change held admission back to ready.
  CaptureFrameStatus get status => _status;

  /// The identical returned frame Future, absent after a synchronous throw.
  Future<void>? get original => _original;

  /// Settles once with permission or refusal, never with a fake frame result.
  Future<bool> get admission => _admission.future;

  /// Settles only with the original frame's actual success or failure.
  Future<CaptureFrameOutcome> get completion => _completion.future;

  /// The actual result, absent while the original frame remains pending.
  CaptureFrameOutcome? get outcome => _outcome;

  /// A deadline refusal is not completion of the pending original frame.
  bool get timedOut => _timedOut;

  /// An unchanged observation or clock failure, separate from the frame result.
  Object? get admissionError => _admissionError;

  /// The exact trace received if admission could not observe a timely frame.
  StackTrace? get admissionStackTrace => _admissionTrace;

  /// The first refusal's immutable facts, never a later replacement snapshot.
  CaptureFrameState? get refusalState => _refusalState;

  void _observeRefusalState() {
    if (_refusalStateObserved) return;
    _refusalStateObserved = true;
    try {
      _refusalState = _observeState?.call();
    } on Object {
      // Diagnostic failure cannot settle or replace the original frame.
      _refusalState = null;
    }
  }

  void _start(
    Future<void> Function() waitForFrame,
    Future<void> Function() waitUntilDeadline,
  ) {
    final Future<void> original;
    try {
      original = waitForFrame();
      _original = original;
    } on Object catch (error, trace) {
      _settleOriginal(error, trace);
      return;
    }
    try {
      unawaited(
        original.then<void>(
          _frameCompleted,
          onError: _settleOriginal,
        ),
      );
    } on Object catch (error, trace) {
      // Failed observation cannot settle an otherwise unknown original.
      _hold(error: error, trace: trace);
    }
    if (_status != CaptureFrameStatus.pending) {
      return;
    }
    try {
      unawaited(
        waitUntilDeadline().then<void>(
          (_) => _hold(timedOut: true),
          onError: (Object error, StackTrace trace) =>
              _hold(error: error, trace: trace),
        ),
      );
    } on Object catch (error, trace) {
      _hold(error: error, trace: trace);
    }
  }

  void _hold({bool timedOut = false, Object? error, StackTrace? trace}) {
    if (_status != CaptureFrameStatus.pending) {
      return;
    }
    _timedOut = timedOut;
    _admissionError = error;
    _admissionTrace = trace;
    _status = CaptureFrameStatus.held;
    _observeRefusalState();
    _admission.complete(false);
  }

  void _frameCompleted(void _) => _settleOriginal();

  void _settleOriginal([Object? error, StackTrace? trace]) {
    if (_completion.isCompleted) {
      return;
    }
    final CaptureFrameOutcome outcome = CaptureFrameOutcome._(
      error == null,
      error,
      trace,
    );
    _outcome = outcome;
    if (_status == CaptureFrameStatus.pending) {
      _status = error == null
          ? CaptureFrameStatus.ready
          : CaptureFrameStatus.held;
      if (error != null) _observeRefusalState();
      _admission.complete(error == null);
    }
    _completion.complete(outcome);
  }
}

/// Serial frame admission, without native renderer or restoration proof.
/// Retain this owner: replacing it must not clear a held original frame.
final class CaptureFrameGate {
  /// Reserves before either callback can synchronously reenter the caller.
  CaptureFrameGate({
    required this._waitForFrame,
    this._observeState,
    Future<void> Function()? waitUntilDeadline,
  }) : _waitUntilDeadline = waitUntilDeadline ?? _deadline;

  /// A wait registered during post-frame callbacks needs a new frame request.
  /// Reservation still precedes both effects and retains the original Future.
  CaptureFrameGate.scheduled({
    required void Function() requestFrame,
    required Future<void> Function() waitForFrame,
    CaptureFrameState? Function()? observeState,
    Future<void> Function()? waitUntilDeadline,
  }) : this(
         waitForFrame: () {
           requestFrame();
           return waitForFrame();
         },
         observeState: observeState,
         waitUntilDeadline: waitUntilDeadline,
       );

  final Future<void> Function() _waitForFrame;
  final CaptureFrameState? Function()? _observeState;
  final Future<void> Function() _waitUntilDeadline;
  CaptureFrameReceipt? _receipt;
  bool _busy = false;
  bool _held = false;

  // Wait for one original native frame within a bounded capture interval.
  // This deadline is separate from the measured frame performance budget.
  static Future<void> _deadline() =>
      Future<void>.delayed(const Duration(seconds: 1));

  /// At most one receipt is retained; a held receipt is never replaced.
  /// A finished positive receipt remains available until the next admission.
  CaptureFrameReceipt? get receipt => _receipt;

  /// A timeout or original failure remains held after any late settlement.
  bool get heldUnknown => _held || _receipt?.status == CaptureFrameStatus.held;

  /// A late original result cannot replace the earlier admission refusal.
  /// Unknown held receipts retain the existing anonymous category.
  CaptureFrameRefusalReason? get refusalReason {
    final CaptureFrameReceipt? original = _receipt;
    if (heldUnknown) {
      if (original?.timedOut ?? false) {
        return CaptureFrameRefusalReason.deadline;
      }
      if (original?.admissionError != null) {
        return CaptureFrameRefusalReason.admissionFailure;
      }
      if (original?.outcome?.completed == false) {
        return CaptureFrameRefusalReason.originalFailure;
      }
      return null;
    }
    return _busy ? CaptureFrameRefusalReason.busy : null;
  }

  /// Call before theme effects as well as before starting another readback.
  void requireIdle() {
    if (_busy || heldUnknown) {
      throw const CaptureFrameRefused();
    }
  }

  /// Runs readback only after positive original frame completion.
  /// Admission remains busy until the original readback callback settles.
  Future<T> capture<T>(Future<T> Function() readback) async {
    requireIdle();
    final CaptureFrameReceipt original = CaptureFrameReceipt._(_observeState);
    _receipt = original;
    _busy = true;
    original._start(_waitForFrame, _waitUntilDeadline);
    try {
      final bool admitted = await original.admission;
      if (!admitted ||
          original.status != CaptureFrameStatus.ready ||
          !identical(_receipt, original) ||
          heldUnknown) {
        _held = true;
        throw const CaptureFrameRefused();
      }
      return await readback();
    } finally {
      if (original.status == CaptureFrameStatus.held) {
        _held = true;
      }
      if (!heldUnknown && identical(_receipt, original)) {
        _busy = false;
      }
    }
  }
}
