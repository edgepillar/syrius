import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';

import 'capture_protocol.dart';
import 'client_window.dart';
import 'fixtures/launch_settle_profile.dart';
import 'logical_capture.dart';
import 'native_window_owner.dart';
import 'retained_renderer_frame.dart';

/// Requests a retained frame only in the isolated Windows launch process.
const String nativeLaunchThemeEnvironment = 'SYRIUS_CI_LAUNCH_THEME';

/// Selects the isolated lock handoff and its preparation profile.
const String nativeLaunchScreenEnvironment = 'SYRIUS_CI_LAUNCH_SCREEN';

/// Selects natural handoff samples in a separate Windows capture run.
const String nativeLaunchMotionScreen = 'launch-motion';

/// The original lock well in the isolated, still-locked startup profile.
Element? originalLaunchLockedWell(StartupStageSession owner) {
  final BuildContext? well = owner.wellKey.currentContext;
  final String? wallet = kWalletPath;
  if (!owner.claimed ||
      !owner.authInShell ||
      owner.isClosed ||
      well is! Element ||
      !well.mounted ||
      wallet == null ||
      path.basename(wallet) != launchSettleWalletName ||
      kCurrentNode != launchSettleNode ||
      kWalletFile != null ||
      kWalletInitCompleted ||
      kDefaultAddressList.isNotEmpty) {
    return null;
  }
  final ModalRoute<dynamic>? route = ModalRoute.of(well);
  return route?.isCurrent == true &&
          identical(route?.settings.arguments, owner)
      ? well
      : null;
}

typedef _LaunchHandoff = ({
  StartupStageSession owner,
  StatefulElement film,
  Element well,
  Rect wellRect,
  double progress,
});

typedef _MotionSample = ({
  int slot,
  int offsetUs,
  Rect stage,
  _LaunchHandoff handoff,
  Uint8List png,
});

/// Observes one reference state during the original cold launch.
/// The handoff observes the authored paint on the running settle clock.
final class NativeLaunchCapture {
  /// Reserves one observation before the original app attaches its root.
  NativeLaunchCapture({
    required this.theme,
    required this._settle,
    required this._window,
    required this._readView,
    this._motion = false,
  }) : _startup = _window.startup() {
    WidgetsBinding.instance.addPostFrameCallback(_observe);
  }

  /// The theme saved by the closed preparation process.
  final String theme;
  final bool _settle;
  final bool _motion;
  final NativeWindowOwner _window;
  final RenderView Function() _readView;
  final NativeWindowCall<NativeWindowStartupReceipt> _startup;
  final Stopwatch _elapsed = Stopwatch()..start();
  String? _refusal;
  Uint8List? _png;
  Rect? _stage;
  StartupStageSession? _referenceOwner;
  _LaunchHandoff? _handoff;
  final Set<int> _scheduledMotion = <int>{};
  final List<_MotionSample> _motionSamples = <_MotionSample>[];
  double? _firstObservedMotionProgress;
  int? _motionOriginUs;
  RenderView? _motionView;
  int _motionPending = 0;
  bool _motionFinished = false;

  /// The one screen admitted by this process's startup configuration.
  String get screen => _motion ? nativeLaunchMotionScreen
      : _settle ? 'launch-settle' : 'launch';

  static const Size _client = Size(1280, 780);
  static const int _filmLength = 56;
  // The reference uses floor(totalFrames * 0.42).
  static const int _referenceIndex = 23;
  void _observe(Duration stamp) {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final EntryStartupReceipt? startup = registry.startup;
    try {
      if (registry.held ||
          _elapsed.elapsed > const Duration(seconds: 45) ||
          (!_settle && startup?.initializationStarted == true) ||
          startup?.initializationError != null) {
        _refusal = 'original-launch-frame-missed';
        return;
      }
      if (startup != null && _tryCapture(startup, stamp)) return;
      WidgetsBinding.instance.addPostFrameCallback(_observe);
    } on CaptureRefused catch (error) {
      _refusal = error.code;
    } on Object {
      _refusal = 'original-launch-frame-unavailable';
    }
  }

  bool _tryCapture(EntryStartupReceipt startup, Duration stamp) {
    if (!_settle && !startup.isCurrent) return false;
    final Object owner = startup.startupOwner;
    if (owner is! StartupStageSession || owner.isClosed) {
      throw const CaptureRefused('original-launch-owner-unavailable');
    }
    final LaunchFilmController film = owner.film;
    if (film.skipRequested || film.cleanupOwnerReplaced ||
        film.frameCount != 0 && film.frameCount != _filmLength) {
      throw const CaptureRefused('original-launch-frame-missed');
    }
    final double progress = owner.motion.value;
    int? motionSlot;
    if (_motion) {
      // Record the first positive post-frame clock value before applying
      // the window and geometry checks for an image.
      if (owner.authInShell && progress > 0) {
        _referenceOwner ??= owner;
        if (!identical(_referenceOwner, owner)) {
          throw const CaptureRefused('original-launch-owner-unavailable');
        }
        _firstObservedMotionProgress ??= progress;
      }
      if (!film.isDone || !owner.authInShell ||
          startup.initialization?.succeeded != true ||
          startup.splashOperation?.succeeded != true || progress <= 0) {
        return false;
      }
      motionSlot = owner.filmInWell ? 2 : (progress < .55 ? 0 : 1);
      if (progress == 1 && !owner.filmInWell) return false;
      if (_scheduledMotion.contains(motionSlot)) return false;
      if (film.frame != _filmLength - 1 || (motionSlot == 2 && progress != 1)) {
        throw const CaptureRefused('original-launch-handoff-refused');
      }
    } else if (_settle) {
      if (_referenceOwner == null) {
        if (!startup.isCurrent || !owner.requestHandoffReferenceFrame()) {
          throw const CaptureRefused('original-launch-handoff-frame-missed');
        }
        _referenceOwner = owner;
      }
      const double reference = AppTokens.launchSettleReferenceProgress;
      if (!identical(_referenceOwner, owner) || owner.filmInWell) {
        throw const CaptureRefused('original-launch-handoff-frame-missed');
      }
      if (progress < reference) return false;
      if (progress != reference) {
        throw const CaptureRefused('original-launch-handoff-frame-missed');
      }
      if (!film.isDone ||
          film.frame != _filmLength - 1 ||
          startup.initialization?.succeeded != true ||
          startup.splashOperation?.succeeded != true) {
        throw const CaptureRefused('original-launch-handoff-refused');
      }
    } else {
      if (film.isDone || film.frame > _referenceIndex) {
        throw const CaptureRefused('original-launch-frame-missed');
      }
      if (film.frame != _referenceIndex) return false;
    }
    final NativeWindowStartupReceipt? native = _startup.receipt;
    if (native == null) return false;
    final BuildContext? element = owner.filmKey.currentContext;
    if (element is! StatefulElement || !element.mounted ||
        element.widget is! LaunchFilm ||
        !identical((element.widget as LaunchFilm).controller, film) ||
        !identical(film.cleanup?.owner, element.state)) {
      throw const CaptureRefused('original-launch-owner-unavailable');
    }
    final RenderView view = _readView();
    final ClientMetrics metrics = ClientMetrics(
      view.flutterView.physicalSize,
      view.flutterView.devicePixelRatio,
    );
    if (!metrics.matches(_client) || view.size != _client) {
      throw const CaptureRefused('original-launch-window-refused');
    }
    final Element? lockedWell =
        _settle ? originalLaunchLockedWell(owner) : null;
    final Rect? wellBounds = _rect(lockedWell?.findRenderObject());
    final Rect? stage = motionSlot == 2 ? wellBounds : _stageRect(element);
    if (Theme.of(element).brightness.name != theme ||
        app.sharedPrefsService?.get(kThemeModeKey) != 'ThemeMode.$theme') {
      throw const CaptureRefused('original-launch-theme-refused');
    }
    if (_motion &&
        (lockedWell == null || wellBounds == null || stage == null)) {
      return false;
    }
    if (!_window.isCurrent(native) || stage == null) {
      throw const CaptureRefused('original-launch-frame-unavailable');
    }
    if (_settle) {
      final Element? well = lockedWell;
      if (well == null) {
        throw const CaptureRefused('original-launch-handoff-well-unavailable');
      }
      final Rect? wellRect = wellBounds;
      if (wellRect == null || motionSlot != 2 && (
          stage.width >= _client.width ||
          stage.height >= _client.height ||
          stage.width <= wellRect.width ||
          stage.height <= wellRect.height)) {
        if (_motion) return false;
        throw const CaptureRefused('original-launch-handoff-geometry-refused');
      }
      if (motionSlot != null) {
        final _LaunchHandoff? previous = _handoff;
        _motionView ??= view;
        if (!identical(_motionView, view) ||
            previous != null &&
                (!identical(previous.film, element) ||
                    !identical(previous.well, well))) {
          throw const CaptureRefused('original-launch-owner-unavailable');
        }
      }
      _handoff = (
        owner: owner,
        film: element,
        well: well,
        wellRect: wellRect,
        progress: progress,
      );
      if (motionSlot != null) {
        if (motionSlot == 2 && !_settled()) {
          throw const CaptureRefused(
            'original-launch-handoff-well-unavailable',
          );
        }
        _scheduledMotion.add(motionSlot);
        _motionOriginUs ??= stamp.inMicroseconds;
        _motionPending++;
        unawaited(_captureMotion(startup, native, view, motionSlot,
            stamp.inMicroseconds - _motionOriginUs!, stage, _handoff!));
        return _motionFinished = motionSlot == 2;
      }
    } else {
      final Object splash = startup.owner;
      if (splash is! State ||
          !splash.mounted ||
          stage != _rect(splash.context.findRenderObject())) {
        throw const CaptureRefused('original-launch-frame-unavailable');
      }
    }
    _stage = stage;
    unawaited(_capture(startup, native, view));
    return true;
  }

  Rect? _stageRect(Element film) {
    RenderObject? stage;
    film.visitAncestorElements((Element ancestor) {
      if (ancestor.widget.key == const Key('startup_stage_rect')) {
        stage = ancestor.renderObject;
        return false;
      }
      return true;
    });
    return _rect(stage);
  }

  Rect? _rect(RenderObject? object) {
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    final Rect rect = logicalClientRect(object);
    return !rect.isEmpty && rect.isFinite &&
        rect.intersect(Offset.zero & _client) == rect ? rect : null;
  }

  bool _settled() {
    final _LaunchHandoff? handoff = _handoff;
    if (handoff == null ||
        !handoff.owner.filmInWell ||
        !identical(originalLaunchLockedWell(handoff.owner), handoff.well) ||
        !identical(handoff.owner.filmKey.currentContext, handoff.film) ||
        handoff.owner.film.cleanupOwnerReplaced) {
      return false;
    }
    bool filmInOriginalWell = false;
    handoff.film.visitAncestorElements((Element ancestor) {
      filmInOriginalWell = identical(ancestor, handoff.well);
      return !filmInOriginalWell;
    });
    return filmInOriginalWell;
  }

  Future<Uint8List> _encode(
    EntryStartupReceipt startup,
    NativeWindowStartupReceipt native,
    RenderView view, {
    bool Function()? stillLocked,
  }) async {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final RetainedRendererFrame frame = await RetainedRendererFrame.capture(
      view: view,
      expectedSize: _client,
      sourceCurrent: () => !registry.held &&
          identical(registry.startup, startup) &&
          _window.isCurrent(native) && identical(_readView(), view) &&
          (stillLocked?.call() ?? true),
    );
    try {
      return await frame.encodePng();
    } finally {
      await frame.release();
    }
  }

  Future<void> _capture(
    EntryStartupReceipt startup,
    NativeWindowStartupReceipt native,
    RenderView view,
  ) async {
    try {
      final Uint8List png = await _encode(startup, native, view);
      if (png.isEmpty || png.length > 8 * 1024 * 1024) {
        throw const CaptureRefused('original-launch-png-refused');
      }
      _png = png;
    } on Object {
      _refusal = 'original-launch-frame-unavailable';
    }
  }

  Future<void> _captureMotion(EntryStartupReceipt startup,
      NativeWindowStartupReceipt native, RenderView view, int slot,
      int offsetUs, Rect stage, _LaunchHandoff handoff) async {
    try {
      final Uint8List png = await _encode(
        startup,
        native,
        view,
        stillLocked: () => identical(
          originalLaunchLockedWell(handoff.owner), handoff.well,
        ) && identical(handoff.owner.filmKey.currentContext, handoff.film),
      );
      if (png.isNotEmpty && png.length <= 256 * 1024) {
        _motionSamples.add((slot: slot, offsetUs: offsetUs, stage: stage,
            handoff: handoff, png: png));
      }
    } on Object {
      // Retain other frames from the same original motion on a readback loss.
    } finally {
      _motionPending--;
    }
  }

  Map<String, Object?> _readMotion() {
    final double? firstProgress = _firstObservedMotionProgress;
    if (_motionPending != 0 || !_motionFinished || firstProgress == null ||
        !_settled()) {
      final String? reason = _refusal;
      return <String, Object?>{
        'status': reason == null ? 'pending' : 'refused',
        'reason': ?reason,
      };
    }
    final List<_MotionSample> samples = _motionSamples.toList()
      ..sort((_MotionSample a, _MotionSample b) => a.slot.compareTo(b.slot));
    if (!identical(_readView(), _motionView)) {
      throw const CaptureRefused('original-launch-owner-unavailable');
    }
    return <String, Object?>{
      'status': 'captured', 'theme': theme, 'frame': _filmLength - 1,
      'frames': _filmLength, 'lockHandoff': true,
      'attemptedSlots': _scheduledMotion.toList()..sort(),
      'firstObservedProgress': firstProgress,
      'samples': <Map<String, Object>>[
        for (final _MotionSample sample in samples) <String, Object>{
          'slot': sample.slot,
          'offsetUs': sample.offsetUs,
          'stage': _bounds(sample.stage),
          'well': _bounds(sample.handoff.wellRect),
          'progress': sample.handoff.progress,
          'png': base64Encode(sample.png),
        },
      ],
    };
  }

  /// Reads the same retained bytes. Polling never schedules another image.
  Map<String, Object?> read(String requestedTheme) {
    if (requestedTheme != theme) {
      throw const CaptureRefused('original-launch-theme-refused');
    }
    if (_motion) return _readMotion();
    final Uint8List? png = _png;
    final Rect? stage = _stage;
    final _LaunchHandoff? handoff = _handoff;
    if (png == null || stage == null || (_settle && !_settled())) {
      final String? reason = _refusal;
      return <String, Object?>{
        'status': reason == null ? 'pending' : 'refused',
        'reason': ?reason,
      };
    }
    return <String, Object?>{
      'status': 'captured',
      'theme': theme,
      'frame': _settle ? _filmLength - 1 : _referenceIndex,
      'frames': _filmLength,
      'stage': _bounds(stage),
      if (handoff != null) ...<String, Object?>{
        'progress': handoff.progress,
        'well': _bounds(handoff.wellRect),
        'lockHandoff': true,
      },
      'png': base64Encode(png),
    };
  }

  static List<double> _bounds(Rect rect) =>
      <double>[rect.left, rect.top, rect.width, rect.height];
}
