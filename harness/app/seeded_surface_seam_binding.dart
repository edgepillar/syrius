import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;

import 'fixtures/seed_policy.dart';
import 'native_window_owner.dart';

/// Keeps the same application, navigator and native owner across all probes.
final class SeededSurfaceSeamOwner {
  SeededSurfaceSeamOwner._(
    this._window, this._startup, this._root, this._navigator,
    this._view, this._flutterView, this._readWindow, this._readView,
  );

  /// A missing first-show receipt cannot be replaced by a later capture.
  factory SeededSurfaceSeamOwner.capture({
    required NativeWindowOwner window,
    required NativeWindowOwner? Function() readWindow,
    required RenderView Function() readView,
  }) {
    final NativeWindowStartupReceipt? startup = window.startup().receipt;
    final Element? root = WidgetsBinding.instance.rootElement;
    final NavigatorState? navigator = app.globalNavigatorKey.currentState;
    if (startup == null || root == null || navigator == null) {
      throw const SeedRefused('seeded-surface-seam-owner-changed');
    }
    final RenderView view = readView();
    return SeededSurfaceSeamOwner._(
      window, startup, root, navigator, view, view.flutterView,
      readWindow, readView,
    )..requireCurrent();
  }

  final NativeWindowOwner _window;
  final NativeWindowStartupReceipt _startup;
  final Element _root;
  final NavigatorState _navigator;
  final RenderView _view;
  final ui.FlutterView _flutterView;
  final NativeWindowOwner? Function() _readWindow;
  final RenderView Function() _readView;
  bool _held = false;

  /// Loss or replacement holds this owner even if a caller restores it.
  void requireCurrent() {
    try {
      if (_held || !_root.mounted ||
          !identical(WidgetsBinding.instance.rootElement, _root) ||
          !_navigator.mounted ||
          !identical(app.globalNavigatorKey.currentState, _navigator) ||
          !_view.attached || !identical(_readView(), _view) ||
          !identical(_view.flutterView, _flutterView) ||
          !identical(_readWindow(), _window) || !_window.isCurrent(_startup)) {
        throw const SeedRefused('seeded-surface-seam-owner-changed');
      }
    } on Object {
      _held = true;
      throw const SeedRefused('seeded-surface-seam-owner-changed');
    }
  }

  /// Await the original native callback before dispatching any pointer.
  Future<void> observeFrame(void Function() requireOwner) async {
    try {
      requireOwner();
      requireCurrent();
      final NativeWindowCall<NativeWindowFrameReceipt> frame =
          _window.requestFrame();
      if (frame.original == null) {
        throw const SeedRefused('seeded-surface-seam-owner-changed');
      }
      final NativeWindowFrameReceipt receipt = await frame.completion;
      requireOwner();
      requireCurrent();
      if (!identical(receipt.startup, _startup) ||
          !identical(frame.receipt, receipt)) {
        throw const SeedRefused('seeded-surface-seam-owner-changed');
      }
    } on Object {
      _held = true;
      throw const SeedRefused('seeded-surface-seam-owner-changed');
    }
  }
}
