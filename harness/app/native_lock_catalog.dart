import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'capture_protocol.dart';
import 'client_window.dart';
import 'logical_capture.dart';
import 'native_launch_capture.dart';
import 'native_window_owner.dart';
import 'retained_renderer_frame.dart';

/// Selects the one Windows CI lock catalog profile.
const String lockCatalogScreen = 'lock-catalog';

typedef _Lock = ({
  EntryStartupReceipt receipt,
  StartupStageSession owner,
  Element well,
  NativeWindowStartupReceipt native,
  RenderView view,
});

/// Binds the original lock owner and retains its painted refusal frame.
final class NativeLockCatalog {
  /// Reserves the process's native window before app startup.
  NativeLockCatalog({
    required this._theme,
    required this._window,
    required this._readView,
  }) : _startup = _window.startup();

  static const Size _client = Size(1280, 780);
  static const int _frames = 56;
  static const int _referenceFrame = 23;
  static const Set<String> _pickerKeys = <String>{
    'lock_wallet_picker_entry_0', 'lock_wallet_picker_entry_1',
    'lock_wallet_picker_entry_2', 'lock_wallet_picker_add',
  };

  final String _theme;
  final NativeWindowOwner _window;
  final RenderView Function() _readView;
  final NativeWindowCall<NativeWindowStartupReceipt> _startup;
  final ValueNotifier<bool> _picker = ValueNotifier<bool>(false);
  _Lock? _original;
  Stopwatch? _wrongClock;
  bool _replayVisible = false;
  String? _refusal;
  Uint8List? _wrongPng;

  /// Supplies inert rows to the original lock card in this process only.
  Widget wrapRoot(Widget root) => ValueListenableBuilder<bool>(
    valueListenable: _picker,
    child: root,
    builder: (_, bool visible, Widget? child) => LockWalletPickerPreview(
      visible: visible,
      additionalEntries: const <LockWalletDisplayEntry>[
        LockWalletDisplayEntry(name: 'Ledger', isLedger: true),
        LockWalletDisplayEntry(name: 'Lab devnet'),
      ],
      child: child!,
    ),
  );

  /// Reads finite state and arms one passive observation before submission.
  Map<String, Object?> control(String action) {
    final _Lock? original = _original ??= _bind();
    if (original == null && action == 'status') {
      return <String, Object?>{'status': 'pending'};
    }
    if (original == null || !_current(original)) {
      throw const CaptureRefused('lock-catalog-owner-refused');
    }
    final int failures = kNumFailedUnlockAttempts!;
    final LaunchFilmController film = original.owner.film;
    switch (action) {
      case 'status':
        return <String, Object?>{
          'status': 'ready',
          'theme': _theme,
          'frame': film.frame,
          'frames': film.frameCount,
          'failures': failures,
          'remaining': 3 - failures,
          'picker': _picker.value,
          'gates': _picker.value ? _pickerGates(original.well) : 0,
        };
      case 'open-picker':
      case 'close-picker':
      case 'arm-wrong':
        if (_wrongClock != null || failures != 0 || !film.isDone ||
            film.frameCount != _frames || film.frame != _frames - 1) {
          throw const CaptureRefused('lock-catalog-state-refused');
        }
        if (action == 'arm-wrong') {
          if (_picker.value) {
            throw const CaptureRefused('lock-catalog-state-refused');
          }
          _wrongClock = Stopwatch()..start();
          WidgetsBinding.instance.addPostFrameCallback(_observeWrong);
        } else {
          _picker.value = action == 'open-picker';
        }
        return <String, Object?>{'status': 'accepted'};
      case 'wrong-frame':
        if (_wrongClock == null) {
          throw const CaptureRefused('lock-catalog-state-refused');
        }
        final String? refusal = _refusal;
        final Uint8List? png = _wrongPng;
        if (refusal != null) throw CaptureRefused(refusal);
        if (png == null) return <String, Object?>{'status': 'pending'};
        return <String, Object?>{
          'status': 'captured',
          'theme': _theme,
          'frame': _referenceFrame,
          'frames': _frames,
          'failures': failures,
          'remaining': 3 - failures,
          'png': base64Encode(png),
        };
      default:
        throw const CaptureRefused('lock-catalog-input-refused');
    }
  }

  _Lock? _bind() {
    final EntryStartupReceipt? receipt = EntryCaptureRegistry.instance.startup;
    final Object? owner = receipt?.startupOwner;
    final NativeWindowStartupReceipt? native = _startup.receipt;
    if (receipt == null || owner is! StartupStageSession ||
        !owner.interactive || native == null) {
      return null;
    }
    final Element? well = originalLaunchLockedWell(owner);
    if (well == null) return null;
    return (
      receipt: receipt,
      owner: owner,
      well: well,
      native: native,
      view: _readView(),
    );
  }

  bool _current(_Lock lock) {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final int? failures = kNumFailedUnlockAttempts;
    final String? wallet = kWalletPath;
    final RenderView view = lock.view;
    final ClientMetrics metrics = ClientMetrics(
      view.flutterView.physicalSize,
      view.flutterView.devicePixelRatio,
    );
    return !registry.held &&
        identical(registry.startup, lock.receipt) &&
        lock.owner.interactive &&
        identical(originalLaunchLockedWell(lock.owner), lock.well) &&
        wallet != null &&
        path.isWithin(znnDefaultWalletDirectory.path, wallet) &&
        kAutoEraseWalletLimit == 3 &&
        failures != null &&
        failures <= 1 &&
        failures >= 0 &&
        _window.isCurrent(lock.native) && identical(_readView(), view) &&
        metrics.matches(_client) && view.size == _client &&
        Theme.of(lock.well).brightness.name == _theme &&
        app.sharedPrefsService?.get(kThemeModeKey) == 'ThemeMode.$_theme';
  }

  int _pickerGates(Element well) {
    Element? card;
    well.visitAncestorElements((Element ancestor) {
      if (ancestor.widget.key != const ValueKey<String>('lock_card_surface')) {
        return true;
      }
      card = ancestor;
      return false;
    });
    final Set<String> keys = <String>{};
    bool duplicate = false;
    void visit(Element element) {
      final Widget widget = element.widget;
      final Key? key = widget is SeamGate && widget.seam == Seam.walletPicker
          ? widget.child.key
          : null;
      if (key is ValueKey<String> && _pickerKeys.contains(key.value)) {
        final RenderObject? render = element.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          final Rect rect = logicalClientRect(render);
          if (!rect.isEmpty && rect.isFinite &&
              rect.intersect(Offset.zero & _client) == rect) {
            if (!keys.add(key.value)) duplicate = true;
          }
        }
      }
      element.visitChildElements(visit);
    }
    card?.visitChildElements(visit);
    return duplicate ? 0 : keys.length;
  }

  void _observeWrong(Duration _) {
    final _Lock? lock = _original;
    if (lock == null || !_current(lock) || _picker.value ||
        _wrongClock!.elapsed > const Duration(seconds: 25)) {
      _refusal = 'lock-catalog-replay-refused';
      return;
    }
    final LaunchFilmController film = lock.owner.film;
    if (kNumFailedUnlockAttempts == 1 && !film.isDone &&
        film.frame < _frames - 1) {
      _replayVisible = true;
    }
    if (_replayVisible) {
      if (film.frame > _referenceFrame || film.isDone ||
          film.skipRequested || film.cleanupOwnerReplaced ||
          film.frameCount != _frames) {
        _refusal = 'lock-catalog-reference-frame-missed';
        return;
      }
      if (film.frame == _referenceFrame) {
        unawaited(_retainWrong(lock));
        return;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(_observeWrong);
  }

  Future<void> _retainWrong(_Lock lock) async {
    try {
      final RetainedRendererFrame frame = await RetainedRendererFrame.capture(
        view: lock.view,
        expectedSize: _client,
        sourceCurrent: () => _current(lock) && kNumFailedUnlockAttempts == 1,
      );
      final Uint8List png;
      try {
        png = await frame.encodePng();
      } finally {
        await frame.release();
      }
      _wrongPng = png;
    } on Object {
      _refusal = 'lock-catalog-frame-unavailable';
    }
  }
}
