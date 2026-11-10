import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/entry_action_boundary.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/new_wallet/seed_quiz.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/new_wallet/seed_quiz_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_step_route.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/reference_artwork_source.dart';

import 'capture_protocol.dart';
import 'fixtures/seed_quiz_fixture.dart';
import 'logical_capture.dart';
import 'native_window_owner.dart';
import 'retained_renderer_frame.dart';

const String quizCatalogScreen = 'quiz-catalog';

/// Renders the original quiz surface on the ordinary harness Navigator.
/// The display fixture owns neither a seed generator nor a Continue action.
final class NativeQuizCatalog {
  NativeQuizCatalog({
    required this._window,
    required this._readView,
  }) : _startup = _window.startup();

  final NativeWindowOwner _window;
  final RenderView Function() _readView;
  final NativeWindowCall<NativeWindowStartupReceipt> _startup;
  final GlobalKey _fixture = GlobalKey();
  final SeedQuiz _quiz = createSyntheticSeedQuiz();
  final EntryCaptureRegistry _registry = EntryCaptureRegistry.instance;
  EntryWelcomeReceipt? _welcome;
  OnboardingStepRoute<void>? _route;
  RenderView? _view;
  BuildContext? _fixtureContext;
  ReferenceArtworkFrame? _artwork;
  bool _closed = false;

  static const Size _client = Size(1280, 780);
  static const Key _nextChoice = Key('seed_quiz_1_0');

  static bool get _empty =>
      kWalletPath == null &&
      kWalletFile == null &&
      !kWalletInitCompleted &&
      kSelectedAddress == null &&
      kDefaultAddressList.isEmpty;

  bool get _ownerCurrent {
    final NativeWindowStartupReceipt? native = _startup.receipt;
    final EntryWelcomeReceipt? welcome = _welcome;
    final NavigatorState? navigator = app.globalNavigatorKey.currentState;
    return native != null &&
        _window.isCurrent(native) &&
        welcome != null &&
        identical(_registry.welcome, welcome) &&
        !_registry.held &&
        welcome.isAttached &&
        identical(welcome.route.navigator, navigator) &&
        _view?.attached == true &&
        identical(_view, _readView()) &&
        _empty;
  }

  bool get _routeCurrent {
    final OnboardingStepRoute<void>? route = _route;
    return route != null &&
        _ownerCurrent &&
        !_closed &&
        entryRouteReady(route) &&
        identical(route.navigator, _welcome!.route.navigator);
  }

  void open() {
    final EntryWelcomeReceipt? welcome = _registry.welcome;
    if (_route != null || welcome == null || !welcome.ready) {
      throw const CaptureRefused('quiz-welcome-unavailable');
    }
    if (!_empty) throw const CaptureRefused('quiz-profile-not-empty');
    _welcome = welcome;
    _view = _readView();
    final NavigatorState? navigator = welcome.route.navigator;
    if (!_ownerCurrent || navigator == null) {
      throw const CaptureRefused('quiz-owner-unavailable');
    }
    final OnboardingStepRoute<void> route = OnboardingStepRoute<void>(
      builder: (_) => StatefulBuilder(
        key: _fixture,
        builder: (BuildContext _, StateSetter setState) => EntryActionBoundary(
          source: _quiz,
          builder: (BuildContext context, EntryActionLease lease) =>
              SeedQuizSurface(
                quiz: _quiz,
                onSelected: (int question, String choice) {
                  if (lease.isCurrent && _routeCurrent && _quiz.correct == 0 &&
                      _quiz.select(question, choice)) {
                    setState(() {});
                  }
                },
                onBack: lease.guard(() => Navigator.pop(context)),
                onContinue: null,
              ),
        ),
      ),
    );
    _route = route;
    navigator.push<void>(route);
  }

  String get firstChoice {
    if (!_routeCurrent || _quiz.selected(0) != null) {
      throw const CaptureRefused('quiz-first-choice-unavailable');
    }
    final SeedQuizQuestion question = _quiz.questions.first;
    return 'seed_quiz_0_${question.choices.indexOf(question.answer)}';
  }

  Future<int> _nativeFrame() async {
    final NativeWindowFrameReceipt frame =
        await _window.requestFrame().completion;
    if (!identical(frame.startup, _startup.receipt) || !_ownerCurrent) {
      throw const CaptureRefused('quiz-frame-owner-changed');
    }
    return frame.callbackSerial;
  }

  ReferenceArtworkFrame _sampleArtwork(BuildContext context) {
    final List<ReferenceArtworkSource> sources = <ReferenceArtworkSource>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) {
        throw const CaptureRefused('quiz-artwork-tree-limit');
      }
      if (element is StatefulElement) {
        final Object state = element.state;
        if (state is ReferenceArtworkSource) sources.add(state);
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (sources.length != 1) {
      throw const CaptureRefused('quiz-artwork-owner-unavailable');
    }
    final ReferenceArtworkSource source = sources.single;
    if (source.referenceArtworkKind != ReferenceArtworkKind.entryField) {
      throw const CaptureRefused('quiz-artwork-owner-unavailable');
    }
    final ReferenceArtworkFrame? frame = source.captureReferenceArtwork();
    if (frame == null ||
        !identical(frame.owner, source) ||
        !identical(frame.generation, source.referenceArtworkGeneration) ||
        frame.observation['seconds'] != 6) {
      throw const CaptureRefused('quiz-artwork-frame-unavailable');
    }
    return frame;
  }

  Future<Map<String, Object?>> observe() async {
    final OnboardingStepRoute<void>? route = _route;
    if (route == null || !_ownerCurrent || !route.isCurrent || _closed) {
      throw const CaptureRefused('quiz-route-changed');
    }
    if (!_routeCurrent) return <String, Object?>{'status': 'pending'};
    final BuildContext? context = _fixture.currentContext;
    if (context == null && _fixtureContext == null) {
      return <String, Object?>{'status': 'pending'};
    }
    if (context == null ||
        !context.mounted ||
        (_fixtureContext != null && !identical(context, _fixtureContext)) ||
        !identical(ModalRoute.of(context), route)) {
      throw const CaptureRefused('quiz-fixture-unavailable');
    }
    _fixtureContext ??= context;
    if (_quiz.correct == 1) _artwork ??= _sampleArtwork(context);
    final int callback = await _nativeFrame();
    if (!context.mounted ||
        !_routeCurrent ||
        !identical(context, _fixture.currentContext) ||
        (_artwork != null && !_artwork!.observed)) {
      throw const CaptureRefused('quiz-paint-unavailable');
    }
    final ThemeData? theme = context.findAncestorWidgetOfExactType<Theme>()
        ?.data;
    return <String, Object?>{
      'status': 'ready',
      'theme': switch (theme) {
        _ when theme == AppTheme.darkTheme => 'dark',
        _ when theme == AppTheme.lightTheme => 'light',
        _ => null,
      },
      'correct': _quiz.correct,
      'unlocked': _quiz.unlocked,
      'questions': _quiz.questions.length,
      'choices': <int>[
        for (final SeedQuizQuestion question in _quiz.questions)
          question.choices.length,
      ],
      'complete': _quiz.complete,
      'artwork_seconds': _artwork?.observation['seconds'],
      'native_callback': callback,
    };
  }

  Element _captureTarget(BuildContext context) {
    Element? target;
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) {
        throw const CaptureRefused('quiz-capture-tree-limit');
      }
      if (element.widget is ErrorWidget) {
        throw const CaptureRefused('quiz-capture-error-widget');
      }
      if (element.widget.key == _nextChoice) {
        if (target != null) {
          throw const CaptureRefused('quiz-capture-target-unavailable');
        }
        target = element;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    final Element? original = target;
    if (original == null) {
      throw const CaptureRefused('quiz-capture-target-unavailable');
    }
    return original;
  }

  Future<Map<String, Object?>> capture(
    String theme, {
    required bool Function(RenderObject, Offset) reachable,
  }) async {
    final BuildContext? context = _fixtureContext;
    final RenderView? view = _view;
    final ReferenceArtworkFrame? artwork = _artwork;
    if (!_routeCurrent ||
        context == null ||
        !context.mounted ||
        view == null ||
        artwork == null) {
      throw const CaptureRefused('quiz-capture-source-unavailable');
    }
    final ThemeData expected = switch (theme) {
      'dark' => AppTheme.darkTheme,
      'light' => AppTheme.lightTheme,
      _ => throw const CaptureRefused('quiz-catalog-input-refused'),
    };
    final Element target = _captureTarget(context);
    bool current() {
      if (!_routeCurrent ||
          !context.mounted ||
          !identical(context, _fixture.currentContext) ||
          context.findAncestorWidgetOfExactType<Theme>()?.data != expected ||
          !artwork.observed ||
          _quiz.correct != 1 || _quiz.unlocked != 1 || _quiz.complete ||
          !target.mounted || target.widget.key != _nextChoice) {
        return false;
      }
      final RenderObject? render = target.findRenderObject();
      if (render is! RenderBox || !render.attached || !render.hasSize) {
        return false;
      }
      final Rect bounds = logicalClientRect(render);
      return bounds.isFinite &&
          !bounds.isEmpty &&
          (Offset.zero & _client).contains(bounds.center) &&
          reachable(render, bounds.center);
    }

    if (await windowManager.isMinimized()) {
      throw const CaptureRefused('quiz-capture-window-minimized');
    }
    final RetainedRendererFrame frame = await RetainedRendererFrame.capture(
      view: view,
      expectedSize: _client,
      sourceCurrent: current,
    );
    try {
      final List<int> png = await frame.encodePng();
      if (await windowManager.isMinimized() || !frame.isCurrent) {
        throw const CaptureRefused('quiz-capture-source-changed');
      }
      return <String, Object?>{
        'status': 'captured',
        'theme': theme,
        'width': frame.width,
        'height': frame.height,
        'png': base64Encode(png),
      };
    } finally {
      await frame.release();
    }
  }

  Future<void> close() async {
    final ReferenceArtworkFrame? artwork = _artwork;
    if (!_routeCurrent || artwork == null || !artwork.restore()) {
      throw const CaptureRefused('quiz-restore-refused');
    }
    await _nativeFrame();
    if (!_routeCurrent || !artwork.restored) {
      throw const CaptureRefused('quiz-artwork-restore-unproven');
    }
    final OnboardingStepRoute<void> route = _route!;
    route.navigator!.pop<void>();
    await route.completed;
    await _nativeFrame();
    if (!_ownerCurrent || !_welcome!.ready || _fixture.currentContext != null) {
      throw const CaptureRefused('quiz-welcome-restore-unproven');
    }
    _closed = true;
  }
}
