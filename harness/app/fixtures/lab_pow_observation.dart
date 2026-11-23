import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/pow_generating_status_bloc.dart';

/// An observation during an already admitted lab Send. It never requests
/// generation, schedules a frame, or changes the original status source.
class LabPowObservation {
  /// The caller starts from an idle original source before accepting Send.
  LabPowObservation({
    required PowGeneratingStatusBloc source,
    required this._current,
    required this._boltPhase,
  }) : _source = source {
    _ambiguous = source.value.phase != PowGenerationPhase.idle;
    _subscription = source.stream.listen(_onStatus);
  }

  final PowGeneratingStatusBloc _source;
  final bool Function() _current;
  final double? Function() _boltPhase;
  final Set<int> _phases = <int>{};
  late final StreamSubscription<PowGenerationState> _subscription;
  PowWorkToken? _work;
  bool _ambiguous = false;
  bool _completed = false;
  bool _closed = false;
  int _frames = 0;

  void _onStatus(PowGenerationState state) {
    if (_closed || _ambiguous || !_current()) return;
    final PowWorkToken? work = state.work;
    if (work == null) return;
    final PowWorkToken? original = _work;
    if (original != null && !identical(original, work)) {
      _ambiguous = true;
    } else if (original == null && state.isGenerating) {
      _work = work;
      SchedulerBinding.instance.addPostFrameCallback(_sample);
    } else if (original != null &&
        state.phase == PowGenerationPhase.completed) {
      _completed = true;
    }
  }

  void _sample(Duration _) {
    if (_closed ||
        _ambiguous ||
        !_current() ||
        !identical(_source.value.work, _work) ||
        !_source.value.isGenerating ||
        _frames >= 128) {
      return;
    }
    _frames++;
    final double? phase = _boltPhase();
    if (phase != null && phase.isFinite && phase >= 0 && phase <= 1) {
      _phases.add((phase * 1000000).round());
    }
    if (_frames < 128) SchedulerBinding.instance.addPostFrameCallback(_sample);
  }

  /// Returns only phase facts and the number of distinct controller samples.
  /// A sample is taken after a frame and does not establish a pixel verdict.
  Map<String, Object>? get receipt => _ambiguous || !_current()
      ? null
      : <String, Object>{
          'generation_started': _work != null,
          'completion_observed': _completed,
          'bolt_phase_samples': _phases.length,
        };

  /// Releases the stream watcher without waiting on the original send.
  void close() {
    _closed = true;
    unawaited(_subscription.cancel());
  }
}
