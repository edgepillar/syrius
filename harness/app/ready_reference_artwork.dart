import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/wallet_ready_surface.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_ready_binding.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/originals_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/staking_tab_child.dart'
    show StakingPage;

import 'capture_frame.dart';

/// A failed original artwork scope cannot admit another capture.
class ReadyReferenceArtworkRefused implements Exception {
  /// Refuses without retaining an asset error, response or private owner.
  const ReadyReferenceArtworkRefused();
}

/// Resolve one actual current Ready owner without constructing a replacement.
State<WalletReadySurface> findReadyArtworkOwner(Element? root) {
  final List<State<WalletReadySurface>> owners = <State<WalletReadySurface>>[];
  int visited = 0;
  void visit(Element element) {
    if (++visited > 16384) throw const ReadyReferenceArtworkRefused();
    if (element is StatefulElement &&
        element.state is State<WalletReadySurface> &&
        ModalRoute.of(element)?.isCurrent == true) {
      owners.add(element.state as State<WalletReadySurface>);
    }
    element.visitChildren(visit);
  }
  if (root != null) visit(root);
  if (owners.length != 1) throw const ReadyReferenceArtworkRefused();
  return owners.single;
}

/// Samples only the original Ready renderers, with their clocks still running.
class ReadyReferenceArtwork {
  /// Retains one original Ready owner and its current admission source.
  ReadyReferenceArtwork({
    required State<WalletReadySurface> owner,
    required this._admitted,
  }) : _owner = owner,
       _binding = owner.widget.binding,
       _route = ModalRoute.of(owner.context);

  final State<WalletReadySurface> _owner;
  final WalletReadyBinding? _binding;
  final ModalRoute<dynamic>? _route;
  final bool Function() _admitted;
  late final _ReferenceArtworkCapture _capture = _ReferenceArtworkCapture(
    current: _current,
    sources: _sources,
    requiresReadiness: (ReferenceArtworkSource source) =>
        source.referenceArtworkKind == ReferenceArtworkKind.walletReadyMap,
    refusal: ReadyReferenceArtworkRefused.new,
  );

  /// A later positive frame or replacement cannot heal an original refusal.
  bool get held => _capture.held;

  bool _current() {
    if (!_owner.mounted || !_admitted()) return false;
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return _binding != null && identical(_owner.widget.binding, _binding) &&
        _binding.isCurrent &&
        !_owner.widget.imported && !_owner.widget.hardware &&
        _route != null && _route.isCurrent &&
        identical(ModalRoute.of(_owner.context), _route) &&
        TickerMode.valuesOf(_owner.context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  List<ReferenceArtworkSource> _sources() {
    final List<ReferenceArtworkSource> sources = <ReferenceArtworkSource>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) throw const ReadyReferenceArtworkRefused();
      if (element is StatefulElement &&
          element.state is ReferenceArtworkSource) {
        sources.add(element.state as ReferenceArtworkSource);
      }
      element.visitChildren(visit);
    }
    _owner.context.visitChildElements(visit);
    if (sources.length != 2 ||
        sources.map((ReferenceArtworkSource value) =>
          value.referenceArtworkKind).toSet().length != 2 ||
        !sources.every((ReferenceArtworkSource value) =>
          value.referenceArtworkKind == ReferenceArtworkKind.entryField ||
          value.referenceArtworkKind == ReferenceArtworkKind.walletReadyMap)) {
      throw const ReadyReferenceArtworkRefused();
    }
    return sources;
  }

  /// Both sample and restoration use the same existing native frame gate.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) => _capture.capture<T>(frames: frames, readback: readback);
}

/// A failed Staking artwork scope has no valid original frame.
class StakingReferenceArtworkRefused implements Exception {
  /// Refuses without including private fields or original errors.
  const StakingReferenceArtworkRefused();
}

/// Samples the two original no-data players on the visible Staking page.
class StakingReferenceArtwork {
  /// Binds a single mounted Staking page from the original widget tree.
  factory StakingReferenceArtwork({
    required Element? root,
    required bool Function() admitted,
  }) {
    final List<State<StakingPage>> owners = <State<StakingPage>>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) throw const StakingReferenceArtworkRefused();
      if (element is StatefulElement &&
          element.state is State<StakingPage> &&
          ModalRoute.of(element)?.isCurrent == true &&
          TickerMode.valuesOf(element).enabled) {
        owners.add(element.state as State<StakingPage>);
      }
      element.visitChildren(visit);
    }
    if (root != null) visit(root);
    if (owners.length != 1) throw const StakingReferenceArtworkRefused();
    return StakingReferenceArtwork._(owners.single, admitted);
  }

  StakingReferenceArtwork._(this._owner, this._admitted)
      : _route = ModalRoute.of(_owner.context);

  final State<StakingPage> _owner;
  final bool Function() _admitted;
  final ModalRoute<dynamic>? _route;
  late final _ReferenceArtworkCapture _capture = _ReferenceArtworkCapture(
    current: _current,
    sources: _sources,
    requiresReadiness: (_) => true,
    refusal: StakingReferenceArtworkRefused.new,
  );

  bool _current() {
    if (!_owner.mounted || !_admitted() || _route?.isCurrent != true) {
      return false;
    }
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return identical(ModalRoute.of(_owner.context), _route) &&
        TickerMode.valuesOf(_owner.context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  List<ReferenceArtworkSource> _sources() {
    final List<ReferenceArtworkSource> sources = <ReferenceArtworkSource>[];
    int footerCount = 0;
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) throw const StakingReferenceArtworkRefused();
      if (element.widget.key == const Key('staking_empty_rewards')) {
        footerCount++;
      }
      if (element is StatefulElement &&
          element.state is ReferenceArtworkSource) {
        final ReferenceArtworkSource source =
            element.state as ReferenceArtworkSource;
        if (source.referenceArtworkKind == ReferenceArtworkKind.noData) {
          sources.add(source);
        }
      }
      element.visitChildren(visit);
    }
    _owner.context.visitChildElements(visit);
    if (footerCount != 1 || sources.length != 2) {
      throw const StakingReferenceArtworkRefused();
    }
    return sources;
  }

  /// Reads the sampled frame and then restores both original bindings.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) => _capture.capture<T>(frames: frames, readback: readback);
}

/// The original gallery cannot supply its complete set of Lottie frames.
class OriginalsReferenceArtworkRefused implements Exception {
  /// Reports only the capture scope, without retaining an asset error.
  const OriginalsReferenceArtworkRefused();
}

/// Samples the Launch film, five Lottie tiles and three small gallery marks.
class OriginalsReferenceArtwork {
  /// Binds the live gallery from the original Settings visit.
  factory OriginalsReferenceArtwork({
    required Element? root,
    required bool Function() admitted,
  }) {
    final List<State<OriginalsCard>> owners = <State<OriginalsCard>>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) throw const OriginalsReferenceArtworkRefused();
      if (element is StatefulElement &&
          element.state is State<OriginalsCard> &&
          ModalRoute.of(element)?.isCurrent == true &&
          TickerMode.valuesOf(element).enabled) {
        owners.add(element.state as State<OriginalsCard>);
      }
      element.visitChildren(visit);
    }

    if (root != null) visit(root);
    if (owners.length != 1) throw const OriginalsReferenceArtworkRefused();
    return OriginalsReferenceArtwork._(owners.single, admitted);
  }

  OriginalsReferenceArtwork._(this._owner, this._admitted)
      : _route = ModalRoute.of(_owner.context);

  final State<OriginalsCard> _owner;
  final bool Function() _admitted;
  final ModalRoute<dynamic>? _route;
  late final _ReferenceArtworkCapture _capture = _ReferenceArtworkCapture(
    current: _current,
    sources: _sources,
    requiresReadiness: (_) => true,
    refusal: OriginalsReferenceArtworkRefused.new,
  );

  bool _current() {
    if (!_owner.mounted || !_admitted() || _route?.isCurrent != true ||
        !_owner.widget.isCurrent() || _owner.widget.artBuilder != null) {
      return false;
    }
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    return identical(ModalRoute.of(_owner.context), _route) &&
        TickerMode.valuesOf(_owner.context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  List<ReferenceArtworkSource> _sources() {
    final List<ReferenceArtworkSource> sources = <ReferenceArtworkSource>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) throw const OriginalsReferenceArtworkRefused();
      if (element is StatefulElement &&
          element.state is ReferenceArtworkSource) {
        final ReferenceArtworkSource source =
            element.state as ReferenceArtworkSource;
        if (source.referenceArtworkKind ==
            ReferenceArtworkKind.originalsGallery) {
          sources.add(source);
        }
      }
      if (element.widget case final LaunchFilm film) {
        final ReferenceArtworkSource? source =
            film.controller?.originalsReferenceArtwork;
        if (source == null) throw const OriginalsReferenceArtworkRefused();
        sources.add(source);
      }
      element.visitChildren(visit);
    }

    _owner.context.visitChildElements(visit);
    if (sources.length != 9) throw const OriginalsReferenceArtworkRefused();
    return sources;
  }

  /// Reads all sampled frames and observes restoration on the original gate.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) => _capture.capture<T>(frames: frames, readback: readback);
}

/// Owns a complete sample and restoration on the same capture gate.
class _ReferenceArtworkCapture {
  _ReferenceArtworkCapture({
    required this._current,
    required this._sources,
    required this._requiresReadiness,
    required this._refusal,
  });

  final bool Function() _current;
  final List<ReferenceArtworkSource> Function() _sources;
  final bool Function(ReferenceArtworkSource) _requiresReadiness;
  final Exception Function() _refusal;
  bool _held = false;
  bool _busy = false;
  CaptureFrameGate? _originalFrames;

  bool get held => _held;

  Never _refuse() {
    _held = true;
    throw _refusal();
  }

  /// Both sample and restoration use the same existing native frame gate.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) async {
    if (_held || _busy || !_current()) _refuse();
    _originalFrames ??= frames;
    if (!identical(_originalFrames, frames)) _refuse();
    try {
      frames.requireIdle();
    } on CaptureFrameRefused {
      _held = true;
      rethrow;
    }
    _busy = true;
    final List<ReferenceArtworkFrame> samples = <ReferenceArtworkFrame>[];
    Object? failure;
    StackTrace? trace;
    late T result;
    try {
      final List<ReferenceArtworkSource> sources = _sources();
      final List<Object> generations = <Object>[
        for (final ReferenceArtworkSource source in sources)
          source.referenceArtworkGeneration,
      ];
      final List<Future<Object?>?> readiness = <Future<Object?>?>[
        for (final ReferenceArtworkSource source in sources)
          source.referenceArtworkReadiness,
      ];
      try {
        for (int index = 0; index < sources.length; index++) {
          final Future<Object?>? original = readiness[index];
          if (_requiresReadiness(sources[index]) && original == null) {
            _refuse();
          }
          if (original != null) {
            await original.timeout(const Duration(seconds: 1));
          }
          if (!_current() ||
              !identical(sources[index].referenceArtworkGeneration,
                generations[index]) ||
              !identical(sources[index].referenceArtworkReadiness, original)) {
            _refuse();
          }
        }
        final List<ReferenceArtworkSource> fresh = _sources();
        if (fresh.length != sources.length) _refuse();
        for (int index = 0; index < sources.length; index++) {
          if (!identical(fresh[index], sources[index])) _refuse();
        }
        for (int index = 0; index < sources.length; index++) {
          final ReferenceArtworkSource source = sources[index];
          final ReferenceArtworkFrame? sample =
              source.captureReferenceArtwork();
          if (sample == null) _refuse();
          samples.add(sample);
          if (!_current() || !sample.isCurrent ||
              !identical(sample.owner, source) ||
              !identical(sample.generation, generations[index]) ||
              sample.kind != source.referenceArtworkKind) {
            _refuse();
          }
        }
      } on Object {
        _refuse();
      }
      void requireObserved() {
        if (!_current() || samples.length != sources.length ||
            !samples.every((ReferenceArtworkFrame sample) => sample.observed)) {
          _refuse();
        }
      }
      result = await frames.capture<T>(() async {
        requireObserved();
        final T value = await readback();
        requireObserved();
        return value;
      });
    } on Object catch (error, stack) {
      _held = true;
      failure = error;
      trace = stack;
    } finally {
      if (samples.isNotEmpty) {
        bool requested = true;
        for (final ReferenceArtworkFrame sample in samples) {
          try {
            if (!sample.restore()) requested = false;
          } on Object {
            requested = false;
          }
        }
        try {
          if (!requested) _refuse();
          await frames.capture<void>(() async {
            if (!_current() ||
                !samples.every((ReferenceArtworkFrame sample) =>
                  sample.restored)) {
              _refuse();
            }
          });
        } on Object catch (error, stack) {
          _held = true;
          failure ??= error;
          trace ??= stack;
        }
      }
      _busy = false;
    }
    if (failure != null) Error.throwWithStackTrace(failure, trace!);
    return result;
  }
}
