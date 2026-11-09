import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';

import 'capture_protocol.dart';
import 'client_window.dart';
import 'logical_capture.dart';
import 'native_window_owner.dart';
import 'retained_renderer_frame.dart';

/// Requests a retained frame only in the isolated Windows launch process.
const String nativeLaunchThemeEnvironment = 'SYRIUS_CI_LAUNCH_THEME';

/// Observes the original cold launch at the reference film index.
/// The callback follows existing frames and never advances the film clock.
final class NativeLaunchCapture {
  /// Reserves one observation before the original app attaches its root.
  NativeLaunchCapture({
    required this.theme,
    required this._window,
    required this._readView,
  }) : _startup = _window.startup() {
    WidgetsBinding.instance.addPostFrameCallback(_observe);
  }

  /// The theme saved by the closed preparation process.
  final String theme;
  final NativeWindowOwner _window;
  final RenderView Function() _readView;
  final NativeWindowCall<NativeWindowStartupReceipt> _startup;
  final Stopwatch _elapsed = Stopwatch()..start();
  String? _refusal;
  Uint8List? _png;
  Rect? _stage;

  static const Size _client = Size(1280, 780);
  static const int _filmLength = 56;
  // The reference uses floor(totalFrames * 0.42).
  static const int _referenceIndex = 23;

  void _observe(Duration _) {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final EntryStartupReceipt? startup = registry.startup;
    try {
      if (registry.held ||
          _elapsed.elapsed > const Duration(seconds: 45) ||
          startup?.initializationStarted == true) {
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
    if (!startup.isCurrent) return false;
    final Object owner = startup.startupOwner;
    if (owner is! StartupStageSession || owner.isClosed) {
      throw const CaptureRefused('original-launch-owner-unavailable');
    }
    final LaunchFilmController film = owner.film;
    if (film.skipRequested || film.isDone || film.cleanupOwnerReplaced ||
        film.frameCount != 0 && film.frameCount != _filmLength ||
        film.frame > _referenceIndex) {
      throw const CaptureRefused('original-launch-frame-missed');
    }
    final NativeWindowStartupReceipt? native = _startup.receipt;
    if (film.frame != _referenceIndex || native == null) return false;
    final BuildContext? element = owner.filmKey.currentContext;
    final Object splash = startup.owner;
    if (element is! StatefulElement || !element.mounted ||
        element.widget is! LaunchFilm ||
        !identical((element.widget as LaunchFilm).controller, film) ||
        !identical(film.cleanup?.owner, element.state) ||
        splash is! State || !splash.mounted) {
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
    final Rect? stage = _stageRect(element, splash.context);
    if (Theme.of(element).brightness.name != theme ||
        app.sharedPrefsService?.get(kThemeModeKey) != 'ThemeMode.$theme') {
      throw const CaptureRefused('original-launch-theme-refused');
    }
    if (!_window.isCurrent(native) || stage == null) {
      throw const CaptureRefused('original-launch-frame-unavailable');
    }
    _stage = stage;
    unawaited(_capture(startup, native, view));
    return true;
  }

  Rect? _stageRect(Element film, BuildContext splash) {
    RenderObject? stage;
    film.visitAncestorElements((Element ancestor) {
      if (ancestor.widget.key == const Key('startup_stage_rect')) {
        stage = ancestor.renderObject;
        return false;
      }
      return true;
    });
    final RenderObject? painted = stage;
    final RenderObject? route = splash.findRenderObject();
    if (painted is! RenderBox || route is! RenderBox ||
        !painted.attached || !route.attached ||
        !painted.hasSize || !route.hasSize) {
      return null;
    }
    final Rect rect = logicalClientRect(painted);
    return !rect.isEmpty && rect.isFinite &&
        rect == logicalClientRect(route) &&
        rect.intersect(Offset.zero & _client) == rect ? rect : null;
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
    if (png == null || stage == null) {
      final String? reason = _refusal;
      return <String, Object?>{
        'status': reason == null ? 'pending' : 'refused',
        'reason': ?reason,
      };
    }
    return <String, Object?>{
      'status': 'captured',
      'theme': theme,
      'frame': _referenceIndex,
      'frames': _filmLength,
      'stage': <double>[stage.left, stage.top, stage.width, stage.height],
      'png': base64Encode(png),
    };
  }
}
