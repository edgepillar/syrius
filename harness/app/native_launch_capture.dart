import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
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

/// Observes one reference state during the original cold launch.
/// The callback follows existing frames without advancing either clock.
final class NativeLaunchCapture {
  /// Reserves one observation before the original app attaches its root.
  NativeLaunchCapture({
    required this.theme,
    required this._settle,
    required this._window,
    required this._readView,
  }) : _startup = _window.startup() {
    WidgetsBinding.instance.addPostFrameCallback(_observe);
  }

  /// The theme saved by the closed preparation process.
  final String theme;
  final bool _settle;
  final NativeWindowOwner _window;
  final RenderView Function() _readView;
  final NativeWindowCall<NativeWindowStartupReceipt> _startup;
  final Stopwatch _elapsed = Stopwatch()..start();
  String? _refusal;
  Uint8List? _png;
  Rect? _stage;
  _LaunchHandoff? _handoff;

  /// The one screen admitted by this process's startup configuration.
  String get screen => _settle ? 'launch-settle' : 'launch';

  static const Size _client = Size(1280, 780);
  static const int _filmLength = 56;
  // The reference uses floor(totalFrames * 0.42).
  static const int _referenceIndex = 23;
  // The reference lock card has 0.4 opacity. Admit the first nearby painted
  // frame, leaving room for the real frame clock to cross that threshold.
  static const double _settleFrom = .4;
  static const double _settleThrough = .72;

  void _observe(Duration _) {
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
      if (startup != null && _tryCapture(startup)) return;
      WidgetsBinding.instance.addPostFrameCallback(_observe);
    } on CaptureRefused catch (error) {
      _refusal = error.code;
    } on Object {
      _refusal = 'original-launch-frame-unavailable';
    }
  }

  bool _tryCapture(EntryStartupReceipt startup) {
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
    if (_settle) {
      if (progress < _settleFrom) return false;
      if (progress > _settleThrough ||
          owner.filmInWell ||
          !film.isDone ||
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
    final Rect? stage = _stageRect(element);
    if (Theme.of(element).brightness.name != theme ||
        app.sharedPrefsService?.get(kThemeModeKey) != 'ThemeMode.$theme') {
      throw const CaptureRefused('original-launch-theme-refused');
    }
    if (!_window.isCurrent(native) || stage == null) {
      throw const CaptureRefused('original-launch-frame-unavailable');
    }
    if (_settle) {
      final Element? well = originalLaunchLockedWell(owner);
      final Rect? wellRect = _rect(well?.findRenderObject());
      if (well == null ||
          wellRect == null ||
          stage.width >= _client.width ||
          stage.height >= _client.height ||
          stage.width <= wellRect.width ||
          stage.height <= wellRect.height) {
        throw const CaptureRefused('original-launch-handoff-refused');
      }
      _handoff = (
        owner: owner,
        film: element,
        well: well,
        wellRect: wellRect,
        progress: progress,
      );
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

  Future<void> _capture(
    EntryStartupReceipt startup,
    NativeWindowStartupReceipt native,
    RenderView view,
  ) async {
    try {
      final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
      final RetainedRendererFrame frame = await RetainedRendererFrame.capture(
        view: view,
        expectedSize: _client,
        sourceCurrent: () => !registry.held &&
            identical(registry.startup, startup) &&
            _window.isCurrent(native) && identical(_readView(), view),
      );
      final Uint8List png;
      try {
        png = await frame.encodePng();
      } finally {
        await frame.release();
      }
      if (png.isEmpty || png.length > 8 * 1024 * 1024) {
        throw const CaptureRefused('original-launch-png-refused');
      }
      _png = png;
    } on Object {
      _refusal = 'original-launch-frame-unavailable';
    }
  }

  /// Reads the same retained bytes. Polling never schedules another image.
  Map<String, Object?> read(String requestedTheme) {
    if (requestedTheme != theme) {
      throw const CaptureRefused('original-launch-theme-refused');
    }
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
