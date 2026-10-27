// The in-app half of the harness: a loopback HTTP server that reads the live
// widget tree and drives it with the same pointer and text-input paths a
// person's mouse and keyboard take. It is linked only into the harness
// entrypoint (harness/app/main.dart), never into lib/main.dart.

// The agent reads framework internals on purpose.
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:animations/animations.dart' show FadeThroughTransition;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_create_frame.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/node_update/node_update.dart'
    show NodeUpdateCard;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/send/widgets/send_confirmation.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/list_entrance.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/rise_switcher.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/state_switcher.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_wallet_seed_choice_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/wallet_ready_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/wallet_success_screen.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/welcome_surface.dart';
import 'package:zenon_syrius_wallet_flutter/screens/splash_screen.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/node_transition.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_initialization.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/node_settings_presenter.dart'
    show NodeSettingsEntry;
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/node_settings_view.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart'
    show SettingsSection;
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/startup_stage.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart'
    show WebsocketStatus, getChainIdentifier;

import '../seed/seed_recipe.dart' show requireSeedTokenPreparation;
import '../wallet_recipe_failure.dart' show walletRecipeFailureCodes;
import 'capture_frame.dart';
import 'capture_protocol.dart' show CaptureRefused;
import 'client_window.dart';
import 'entry_caption_observer.dart';
import 'fixtures/seed_commands.dart';
import 'fixtures/seed_policy.dart';
import 'logical_capture.dart';
import 'native_entry_capture.dart';
import 'native_window_owner.dart';
import 'presentation_close.dart';
import 'presentation_host.dart';
import 'presentation_mode.dart';
import 'recipe_control_admission.dart';
import 'theme_control.dart';

/// Widgets that say nothing about where a node sits; left out of `path`.
const Set<String> _kPathNoise = <String>{
  'Padding',
  'Container',
  'Row',
  'Column',
  'Expanded',
  'Flexible',
  'SizedBox',
  'Align',
  'Center',
  'Stack',
  'Positioned',
  'DecoratedBox',
  'ConstrainedBox',
  'Builder',
  'Semantics',
  'Material',
  'InkWell',
  'InkResponse',
  'Listener',
  'GestureDetector',
  'RawGestureDetector',
  'MouseRegion',
  'Focus',
  'FocusScope',
  'Actions',
  'Shortcuts',
  'RepaintBoundary',
  'IgnorePointer',
  'AbsorbPointer',
  'Opacity',
  'Transform',
  'ClipRect',
  'ClipRRect',
  'ColoredBox',
  'LimitedBox',
  'Visibility',
  'KeyedSubtree',
  'MediaQuery',
  'Theme',
  'DefaultTextStyle',
  'AnimatedDefaultTextStyle',
  'IconTheme',
  'AnimatedBuilder',
  'ListenableBuilder',
  'LayoutBuilder',
  'StreamBuilder',
  'FutureBuilder',
  'ValueListenableBuilder',
  'CustomPaint',
  'PhysicalModel',
  'PhysicalShape',
  'AnimatedPhysicalModel',
  'NotificationListener',
  'Scrollable',
  'Viewport',
  'SliverPadding',
  'SliverList',
  'Wrap',
  'Spacer',
  'FittedBox',
  'IntrinsicHeight',
  'IntrinsicWidth',
  'SafeArea',
  'Text',
  'RichText',
  'Icon',
  'AnimatedContainer',
  'AnimatedOpacity',
  'FadeTransition',
  'SlideTransition',
  'ScaleTransition',
  'Tooltip',
  'ExcludeSemantics',
  'MergeSemantics',
  'BlockSemantics',
  'Offstage',
  'TickerMode',
  'CustomSingleChildLayout',
  'CustomMultiChildLayout',
  'InputDecorator',
  'EditableText',
  'TextField',
  'TextFormField',
  'UnconstrainedBox',
  'OverflowBox',
  'AspectRatio',
  'Card',
  'Ink',
  'TextSelectionGestureDetector',
  'IndexedSemantics',
  'LayoutId',
  'ClipPath',
  'OverlayPortal',
  'AutomaticKeepAlive',
  'KeepAlive',
  'SliverToBoxAdapter',
  'CustomScrollView',
  'ListView',
  'GridView',
  'Scaffold',
  'Tab',
  'Flex',
  'ScrollConfiguration',
  'PrimaryScrollController',
  'ScrollNotificationObserver',
  'RawScrollbar',
  'Scrollbar',
  'SingleChildScrollView',
  'UnmanagedRestorationScope',
  'RestorationScope',
  'PageStorage',
  'HeroControllerScope',
  'TapRegion',
  'TextFieldTapRegion',
  'TapRegionSurface',
  'Directionality',
  'Localizations',
  'Title',
  'CheckedModeBanner',
  'Banner',
  'DefaultSelectionStyle',
  'SelectionContainer',
  'DefaultTextEditingShortcuts',
  'ButtonTheme',
  'IconButtonTheme',
  'AnimatedTheme',
  'CupertinoTheme',
  'InheritedCupertinoTheme',
  'IconThemeData',
  'ScaffoldMessenger',
  'SharedAppData',
  'View',
  'RawView',
  'FocusTraversalGroup',
  'Consumer',
  'Provider',
  'InheritedProvider',
  'ListenableProvider',
  'ChangeNotifierProvider',
  'MultiProvider',
  'BlocProvider',
  'MultiBlocProvider',
  'BlocBuilder',
  'BlocListener',
  'BlocConsumer',
  'BlocSelector',
  'Nested',
  'SingleChildBuilder',
};

/// A tappable larger than this takes no label from the text inside it: it is
/// a page-wide "tap to unfocus" detector or a whole card, not a button.
const double _kFoldArea = 90000;

class _Node {
  _Node(this.kind, this.type, this.element, this.rect, this.path);

  int ref = 0;
  final String kind;
  final String type;
  final Element element;
  final Rect rect;
  final List<String> path;
  final List<String> parts = <String>[];

  /// Text inside a tappable too large to fold; becomes its label only when
  /// there is little of it.
  final List<String> loose = <String>[];
  final Map<String, Object?> extra = <String, Object?>{};
  String? key;
  bool enabled = true;
  bool foldable = false;

  String get label => parts.join(' ');

  Offset get center => rect.center;

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': ref,
    'kind': kind,
    if (label.isNotEmpty) 'label': label,
    'type': type,
    if (key != null) 'key': key,
    if (!enabled) 'enabled': false,
    ...extra,
    'rect': <int>[
      rect.left.round(),
      rect.top.round(),
      rect.width.round(),
      rect.height.round(),
    ],
    if (path.isNotEmpty) 'path': path,
  };
}

class _Ctx {
  const _Ctx({
    required this.clip,
    this.tappable,
    this.decoration,
    this.tip,
    this.semanticTip = false,
    this.key,
    this.inText = false,
    this.blocked = false,
    this.path = const <String>[],
  });

  final Rect clip;
  final _Node? tappable;
  final InputDecoration? decoration;
  final String? tip;
  final bool semanticTip;
  final String? key;
  final bool inText;
  final bool blocked;
  final List<String> path;

  _Ctx copy({
    Rect? clip,
    _Node? tappable,
    InputDecoration? decoration,
    String? tip,
    bool? semanticTip,
    String? key,
    bool clearKey = false,
    bool clearTip = false,
    bool? inText,
    bool? blocked,
    List<String>? path,
  }) => _Ctx(
    clip: clip ?? this.clip,
    tappable: tappable ?? this.tappable,
    decoration: decoration ?? this.decoration,
    tip: clearTip ? null : (tip ?? this.tip),
    semanticTip: !clearTip && (semanticTip ?? this.semanticTip),
    key: clearKey ? null : (key ?? this.key),
    inText: inText ?? this.inText,
    blocked: blocked ?? this.blocked,
    path: path ?? this.path,
  );
}

class HarnessError implements Exception {
  HarnessError(this.message, [this.detail]);

  final String message;
  final Object? detail;

  @override
  String toString() => message;
}

class _RecipeSelection {
  _RecipeSelection({
    required this.id,
    required this.source,
    required this.presenter,
    required this.file,
    required this.client,
    required this.socket,
    required this.ledgerTransport,
    required this.node,
    required this.originalNode,
    required this.revision,
    required this.signingChain,
    required this.expectedChain,
  });

  final int id;
  final Element source;
  final Object presenter;
  final Object? file;
  final Object? client;
  final Object? socket;
  final Object? ledgerTransport;
  final String node;
  final String? originalNode;
  final int revision;
  final int signingChain;
  final int? expectedChain;
  Element? question;
  Route<dynamic>? questionRoute;
  VoidCallback? questionCallback;
  bool accepted = false;
}

class HarnessAgent {
  HarnessAgent._()
    : _captureFrames = CaptureFrameGate(
        waitForFrame: () => WidgetsBinding.instance.endOfFrame,
      ),
      _closePresentation = windowManager.close,
      _waitForPresentationClose = null;

  @visibleForTesting
  HarnessAgent.forTest({
    Future<void> Function()? closePresentation,
    Future<void> Function()? waitForCaptureFrame,
    Future<void> Function()? waitForCaptureFrameDeadline,
    this._waitForPresentationClose,
  }) : _captureFrames = CaptureFrameGate(
         waitForFrame: waitForCaptureFrame ?? _refuseTestCaptureFrame,
         waitUntilDeadline: waitForCaptureFrameDeadline,
       ),
       _closePresentation = closePresentation ?? _refuseTestClose;

  static Future<void> _refuseTestClose() =>
      throw HarnessError('no test close callback was supplied');

  static Future<void> _refuseTestCaptureFrame() =>
      throw HarnessError('no test capture frame callback was supplied');

  /// Runs no server, timers, native window or app startup. Transport tests and
  /// production commands still go through the authenticated loopback server.
  @visibleForTesting
  Future<Map<String, Object?>> commandForTest(Map<String, dynamic> command) =>
      _run(command);

  static final HarnessAgent _instance = HarnessAgent._();

  static const int _device = 97;

  final List<Map<String, Object?>> _logs = <Map<String, Object?>>[];
  Map<int, _Node> _last = <int, _Node>{};
  int _tabs = 0;
  Future<void> _queue = Future<void>.value();
  int _pointer = 1000;
  int _logSeq = 0;
  bool _mouseAdded = false;
  Offset _mouseAt = Offset.zero;
  bool booted = false;
  Object? _recipeFile;
  Object? _recipeClient;
  Object? _recipeSocket;
  int _recipeOwner = 0;
  int _recipeSelectionId = 0;
  _RecipeSelection? _recipeSelection;
  bool _recipeReadyOpening = false;
  final SeedCommands _seeds = SeedCommands();
  HarnessPresentationController? _presentation;
  NativeEntryCapture? _nativeEntry;
  EntryCaptionObserver? _entryCaption;
  bool Function()? _presentationIsCurrent;
  BuildContext? Function()? _presentationContext;
  Element? _presentationElement;
  bool _modeSelected = false;
  bool _presentationRevoked = false;
  int _presentationEpoch = 0;
  int _presentationRevision = 0;
  final CaptureFrameGate _captureFrames;
  final Future<void> Function() _closePresentation;
  final Future<void> Function()? _waitForPresentationClose;
  bool _presentationCloseReserved = false;
  PresentationCloseAttempt? _presentationCloseAttempt;

  @visibleForTesting
  PresentationCloseAttempt? get presentationCloseForTest =>
      _presentationCloseAttempt;

  /// Exposes the original receipt without a native readback or HTTP payload.
  @visibleForTesting
  CaptureFrameReceipt? get captureFrameForTest => _captureFrames.receipt;

  static HarnessAgent get instance => _instance;

  /// The ordinary Windows process retains one native entry scope from startup.
  void useNativeEntry({required NativeWindowOwner window}) {
    if (_modeSelected ||
        booted ||
        _presentation != null ||
        _nativeEntry != null) {
      throw HarnessError('the harness host mode is already reserved');
    }
    _modeSelected = true;
    _nativeEntry = NativeEntryCapture(
      window: window,
      readView: () => _view,
      openImport: (VoidCallback admission) async {
        await _tap(
          <String, dynamic>{'key': 'welcome_import'},
          requireAdmission: admission,
        );
      },
    );
  }

  /// Chooses the independent host before the first remote command or startup.
  void usePresentation({
    required HarnessPresentationController controller,
    required bool Function() isCurrent,
    required BuildContext? Function() context,
  }) {
    if (_modeSelected || booted || _presentation != null) {
      throw HarnessError('the harness host mode is already reserved');
    }
    _modeSelected = true;
    _presentation = controller;
    _presentationIsCurrent = isCurrent;
    _presentationContext = context;
    controller.addListener(() => _presentationRevision++);
  }

  static Future<void> start({required int port, required String token}) async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    _instance._hookLogs();
    _instance._hookStalls();
    server.listen((HttpRequest req) => _instance._serve(req, token));
  }

  // --------------------------------------------------------------- transport

  Future<void> _serve(HttpRequest req, String token) async {
    Map<String, Object?> out;
    int status = 200;
    try {
      if (req.headers.value('x-harness-token') != token) {
        throw HarnessError('bad token');
      }
      final String body = await utf8.decoder.bind(req).join();
      final Map<String, dynamic> cmd = body.isEmpty
          ? <String, dynamic>{'cmd': 'ping'}
          : jsonDecode(body) as Map<String, dynamic>;
      // One command at a time: two interleaved taps would share one mouse.
      final Completer<Map<String, Object?>> done =
          Completer<Map<String, Object?>>();
      _queue = _queue.then((_) async {
        try {
          done.complete(await _run(cmd));
        } on Object catch (e, st) {
          done.completeError(e, st);
        }
      });
      out = <String, Object?>{'ok': true, ...await done.future};
    } on HarnessError catch (e) {
      status = 400;
      out = <String, Object?>{
        'ok': false,
        'error': e.message,
        if (e.detail != null) 'detail': e.detail,
      };
    } on Object catch (e, st) {
      status = 500;
      out = <String, Object?>{
        'ok': false,
        'error': e.toString(),
        'stack': st.toString(),
      };
    }
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(out));
    await req.response.close();
  }

  Future<Map<String, Object?>> _run(Map<String, dynamic> c) async {
    final HarnessPresentationController? presentation = _presentation;
    if (presentation != null) {
      return _runPresentation(presentation, c);
    }
    _modeSelected = true;
    return _runWalletCommand(c);
  }

  Element _requirePresentationCurrent() {
    if (_presentationRevoked) {
      throw HarnessError('the original presentation host was retired');
    }
    bool current = false;
    BuildContext? context;
    try {
      current = _presentationIsCurrent?.call() == true;
      if (current && !_presentationRevoked) {
        context = _presentationContext?.call();
      }
    } on Object {
      _presentationRevoked = true;
      rethrow;
    }
    if (!current ||
        _presentationRevoked ||
        context is! Element ||
        !context.mounted ||
        _presentationElement != null &&
            !identical(context, _presentationElement)) {
      _presentationRevoked = true;
      throw HarnessError('the original presentation host was retired');
    }
    _presentationElement ??= context;
    return context;
  }

  String _presentationBrightness() {
    final Element context = _requirePresentationCurrent();
    Brightness? observed;
    void visit(Element element) {
      if (observed != null) return;
      final Widget widget = element.widget;
      if (widget is Theme) {
        observed = widget.data.brightness;
      } else {
        element.visitChildren(visit);
      }
    }

    context.visitChildren(visit);
    if (observed == null) {
      throw HarnessError('the presentation theme is not attached');
    }
    return observed!.name;
  }

  Future<Map<String, Object?>> _runPresentation(
    HarnessPresentationController presentation,
    Map<String, dynamic> command,
  ) async {
    final String name = command['cmd'] as String? ?? 'ping';
    if (!harnessPresentationAllows(name)) {
      throw HarnessError('read-only presentation refuses this command');
    }
    if (name == 'ping') {
      if (booted) _requirePresentationCurrent();
      return <String, Object?>{
        'pid': pid,
        'booted': booted,
        'harnessMode': 'presentation',
        'presentationScreen': presentation.surface,
      };
    }
    _requirePresentationCurrent();
    if (name == 'state') {
      return <String, Object?>{
        ...presentation.snapshot(),
        'harnessMode': 'presentation',
        'presentationScreen': presentation.surface,
        'booted': booted,
        'walletUnlocked': false,
        'walletInitCompleted': false,
        'tabs': <String>[],
        if (_presentationCloseAttempt case final PresentationCloseAttempt close)
          'close': close.snapshot(),
      };
    }
    if (_presentationCloseReserved &&
        <String>{'presentation', 'theme', 'window'}.contains(name)) {
      throw HarnessError('the presentation close is already reserved');
    }
    // Validate before callbacks. Unsupported requests cannot change the host.
    if (name == 'presentation') {
      final Object? surface = command['surface'];
      if (surface is! String ||
          !harnessPresentationSurfaces.contains(surface)) {
        throw HarnessError('a supported presentation surface is required');
      }
    } else if (name == 'theme' &&
        (command['restore'] != null ||
            command['mode'] != null &&
                !<String>{'dark', 'light'}.contains(command['mode']))) {
      throw HarnessError('presentation theme is dark or light, in memory');
    }
    final int epoch = ++_presentationEpoch;
    final String expectedSurface = name == 'presentation'
        ? command['surface'] as String
        : presentation.surface;
    final String expectedTheme = name == 'theme' && command['mode'] is String
        ? command['mode'] as String
        : presentation.theme;
    final int expectedRevision =
        _presentationRevision +
        (expectedSurface != presentation.surface ||
                expectedTheme != presentation.theme
            ? 1
            : 0);
    final bool mutating = <String>{
      'presentation',
      'theme',
      'window',
      'quit',
    }.contains(name);
    try {
      final Map<String, Object?> result;
      if (name == 'theme' || name == 'presentation') {
        if (name == 'presentation') {
          presentation.show(command['surface'] as String);
        } else if (command['mode'] case final String theme) {
          presentation.setTheme(theme);
        }
        _requirePresentationCurrent();
        // A preview theme response requires the original frame completion.
        // The ordinary input helper's quiet-wait timeout is not that receipt.
        await WidgetsBinding.instance.endOfFrame;
        await _settle();
        _requirePresentationCurrent();
        final String brightness = _presentationBrightness();
        if (brightness != presentation.theme) {
          throw HarnessError('the presentation theme was not observed');
        }
        result = <String, Object?>{
          ...presentation.snapshot(),
          'mode': presentation.theme,
          'brightness': brightness,
        };
      } else if (name == 'assert') {
        result = _assertPresentation(command);
      } else if (name == 'quit') {
        result = <String, Object?>{
          'close': _queuePresentationClose(presentation),
        };
      } else {
        result = await _runWalletCommand(command);
      }
      _requirePresentationCurrent();
      if (epoch != _presentationEpoch ||
          !identical(presentation, _presentation) ||
          expectedRevision != _presentationRevision ||
          expectedSurface != presentation.surface ||
          expectedTheme != presentation.theme) {
        _presentationRevoked = true;
        throw HarnessError('the presentation changed during this command');
      }
      return <String, Object?>{
        ...result,
        'harnessMode': 'presentation',
        'presentationScreen': presentation.surface,
        'readOnly': true,
      };
    } on Object {
      if (mutating) _presentationRevoked = true;
      rethrow;
    }
  }

  Map<String, Object?> _queuePresentationClose(
    HarnessPresentationController presentation,
  ) {
    if (_presentationCloseReserved) {
      final PresentationCloseAttempt? retained = _presentationCloseAttempt;
      if (retained == null) {
        throw HarnessError('the original close reservation is pending');
      }
      return retained.snapshot();
    }
    final int revision = _presentationRevision;
    final String surface = presentation.surface;
    final String theme = presentation.theme;
    // Reserve before the original delay callback can reenter the agent.
    _presentationCloseReserved = true;
    final PresentationCloseAttempt attempt = PresentationCloseAttempt(
      waitUntilAdmission: _waitForPresentationClose,
      requireCurrent: () {
        _requirePresentationCurrent();
        if (!identical(presentation, _presentation) ||
            revision != _presentationRevision ||
            surface != presentation.surface ||
            theme != presentation.theme) {
          _presentationRevoked = true;
          throw HarnessError('the presentation changed before close');
        }
      },
      close: _closePresentation,
    );
    _presentationCloseAttempt = attempt;
    return attempt.snapshot();
  }

  Future<Map<String, Object?>> _runWalletCommand(Map<String, dynamic> c) async {
    switch (c['cmd'] as String? ?? 'ping') {
      case 'ping':
        return <String, Object?>{
          'pid': pid,
          'booted': booted,
          'harnessMode': 'wallet',
        };
      case 'state':
        return _state();
      case 'wallet-recipe':
        return _walletRecipeCommand(c);
      case 'entry-caption':
        return _entryCaptionCommand(c);
      case 'entry-state':
      case 'entry-check':
      case 'entry-capture':
        return _entryCommand(c);
      case 'seed':
        try {
          return await _seeds.run(
            c,
            booted: booted,
            ui: _run,
            tap: (Map<String, dynamic> selector, void Function() admission) =>
                _tap(selector, requireAdmission: admission),
          );
        } on SeedRefused catch (error) {
          throw HarnessError(error.code);
        }
      case 'tree':
        return _tree(c);
      case 'tap':
        return _tap(c);
      case 'hover':
        return _hover(c);
      case 'type':
        return _type(c);
      case 'key':
        return _key(c);
      case 'scroll':
        return _scroll(c);
      case 'drag':
        return _drag(c);
      case 'drop':
        return _drop(c);
      case 'wait':
        return _wait(c);
      case 'assert':
        return _assert(c);
      case 'shot':
        return _shot(c);
      case 'theme':
        return _theme(c);
      case 'logs':
        return _logsCmd(c);
      case 'stalls':
        return _stallsCmd(c);
      case 'clipboard':
        return _clipboard(c);
      case 'window':
        return _window(c);
      case 'quit':
        // The app's own close path: it saves window state, stops the
        // embedded node and exits.
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 100),
            windowManager.close,
          ),
        );
        return <String, Object?>{};
      default:
        throw HarnessError('unknown command ${c['cmd']}');
    }
  }

  // ------------------------------------------------------------------- state

  Future<Map<String, Object?>> _entryCommand(
    Map<String, dynamic> command,
  ) async {
    final NativeEntryCapture? entry = _nativeEntry;
    if (command['cmd'] == 'entry-state') {
      if (command.keys.any((String key) => key != 'cmd')) {
        throw HarnessError('unsupported entry state input');
      }
      return <String, Object?>{
        'available': entry != null,
        ...?entry?.snapshot(),
      };
    }
    if (entry == null) {
      throw HarnessError('native entry capture is unavailable');
    }
    _requireCaptureFrameIdle();
    try {
      if (command['cmd'] == 'entry-check') {
        if (command.keys.any((String key) => key != 'cmd')) {
          throw HarnessError('unsupported entry check input');
        }
        return <String, Object?>{
          'available': true,
          ...await entry.verifyCurrent(),
        };
      }
      if (command.keys.any(
            (String key) => !<String>{'cmd', 'screen', 'theme'}.contains(key),
          ) ||
          command['screen'] is! String ||
          command['theme'] is! String) {
        throw HarnessError('unsupported entry capture input');
      }
      return await entry.capture(
        screen: command['screen'] as String,
        theme: command['theme'] as String,
      );
    } on CaptureRefused catch (error) {
      throw HarnessError(error.code);
    } on NativeWindowRefused {
      throw HarnessError('original native entry window is unavailable');
    }
  }

  Future<Map<String, Object?>> _entryCaptionCommand(
    Map<String, dynamic> command,
  ) async {
    final Object? action = command['do'];
    if (command.keys.any(
          (String key) => !<String>{'cmd', 'do'}.contains(key),
        ) ||
        !<String>{
          'bind',
          'maximize',
          'restore',
          'minimize',
          'observe',
        }.contains(action)) {
      _entryCaption?.hold(const CaptionRefused('caption-input-refused'));
      throw HarnessError('caption-input-refused');
    }
    final NativeEntryCapture? entry = _nativeEntry;
    if (entry == null) {
      throw HarnessError('caption-entry-unavailable');
    }
    _requireCaptureFrameIdle();
    try {
      if (action == 'bind') {
        if (_entryCaption != null) {
          throw const CaptionRefused('caption-replay-refused');
        }
        final EntryCaptionObserver original = EntryCaptionObserver(
          readEntry: entry.snapshot,
          readWindow: _captionWindowSnapshot,
          tap: _tapCaptionControl,
        );
        _entryCaption = original; // Retain before any native observation.
        return await original.bind();
      }
      final EntryCaptionObserver? original = _entryCaption;
      if (original == null) {
        throw const CaptionRefused('caption-unavailable');
      }
      if (action == 'observe') {
        return await original.observe();
      }
      return await original.tap(action! as String);
    } on Object catch (error) {
      _entryCaption?.hold(error);
      throw HarnessError(_entryCaption?.publicFailureCode ?? 'CAPTION_HELD');
    }
  }

  Future<Map<String, Object?>> _captionWindowSnapshot({
    required bool geometry,
  }) async {
    final bool minimized = await windowManager.isMinimized();
    final bool maximized = await windowManager.isMaximized();
    if (!geometry || minimized || maximized) {
      return <String, Object?>{'minimized': minimized, 'maximized': maximized};
    }
    return _windowSnapshot();
  }

  Future<void> _tapCaptionControl(
    Element original,
    VoidCallback admission,
    VoidCallback released,
  ) async {
    admission();
    // Native resize completion can precede the next visible layout. Choose the
    // pointer target after that frame, while retaining the original control.
    await _frame();
    admission();
    _Node control() {
      final List<_Node> hits = _snapshot()
          .where(
            (_Node node) =>
                node.kind == 'button' && identical(node.element, original),
          )
          .toList();
      if (hits.length != 1 ||
          !hits.single.enabled ||
          !_reachable(hits.single, hits.single.center)) {
        throw const CaptionRefused('caption-control-refused');
      }
      return hits.single;
    }

    final _Node before = control();
    await _click(
      before.center,
      requireAdmission: () {
        admission();
        final _Node current = control();
        if (current.center != before.center) {
          throw const CaptionRefused('caption-control-changed');
        }
      },
      afterRelease: released,
    );
    // Minimize must not wait for a painted frame or generic settle afterward.
  }

  /// Exercises original pointer dispatch without granting native entry proof.
  @visibleForTesting
  Future<void> tapCaptionForTest(
    Element original,
    VoidCallback admission,
    VoidCallback released,
  ) => _tapCaptionControl(original, admission, released);

  Map<String, Object?> _state() {
    String? route;
    app.globalNavigatorKey.currentState?.popUntil((Route<dynamic> r) {
      route = r.settings.name ?? r.runtimeType.toString();
      return true;
    });
    final Size size = _viewSize();
    return <String, Object?>{
      'harnessMode': 'wallet',
      'booted': booted,
      'route': route,
      'tab': kCurrentPage?.name,
      'tabs': <String>[for (final Tabs t in kTabs) t.name],
      'node': kCurrentNode,
      'chainId': kNodeChainId,
      ..._recipeSigningPolicy(),
      'nodeTransitionPending': NodeTransitions.pending,
      'ws': app.zenon?.wsClient.status().name,
      'embeddedNode': kEmbeddedNodeRunning,
      'address': kSelectedAddress,
      'addresses': kDefaultAddressList,
      'walletPath': kWalletPath,
      'walletUnlocked': kWalletFile != null,
      'walletInitCompleted': kWalletInitCompleted,
      if (_seeds.fixtureName != null) 'harnessFixture': _seeds.fixtureName,
      'size': <int>[size.width.round(), size.height.round()],
      'appData': Platform.environment['AppData'],
    };
  }

  Map<String, Object?> _recipeSigningPolicy() {
    Object? saved;
    bool known = false;
    bool nodeSaved = false;
    try {
      if (app.sharedPrefsService != null && Hive.isBoxOpen(kSharedPrefsBox)) {
        final Box<dynamic> box = Hive.box<dynamic>(kSharedPrefsBox);
        saved = box.get(kChainIdKey, defaultValue: kChainIdDefaultValue);
        known = box.isOpen && saved is int && saved > 0;
        nodeSaved =
            kCurrentNode != null && box.get(kSelectedNodeKey) == kCurrentNode;
      }
    } on Object {
      // An unreadable preference is unknown, never an invented default.
    }
    return <String, Object?>{
      'signingChainId': getChainIdentifier(),
      'savedSigningChainId': known ? saved : null,
      'signingPolicyReady': known,
      'nodeSelectionSaved': nodeSaved,
    };
  }

  static bool _recipeKey(String? key) =>
      key != null &&
      (<String>{
            'launch_skip_hint',
            'welcome_import',
            'import_words_12',
            'import_words_24',
            'import_seed_field',
            'import_continue',
            'import_new_password',
            'import_confirm_password',
            'import_password_continue',
            'node_settings_add',
            'node_settings_endpoint',
            'node_settings_endpoint_save',
            'node_onboarding_continue',
            'node_settings_question_accept',
            'node_settings_chain_toggle',
            'node_settings_client_chain',
            'node_settings_chain_save',
            'wallet_ready_open',
            'nav_settings',
            'nav_dashboard',
            'settings_node',
          }.contains(key) ||
          key.startsWith('node_settings_select_'));

  bool _recipeEnabled(_Node node) {
    final Widget widget = node.element.widget;
    return node.enabled &&
        (widget is! Radio || widget.enabled != false) &&
        _recipeEntranceSettled(node.element) &&
        _recipeSettingsLayoutSettled(node);
  }

  bool _recipeSettingsLayoutSettled(_Node node) {
    const Set<String> controls = <String>{
      'node_settings_chain_toggle',
      'node_settings_client_chain',
      'node_settings_chain_save',
    };
    if (!controls.contains(node.key)) return true;
    Element? section;
    bool settled = true;
    node.element.visitAncestorElements((Element ancestor) {
      if (ancestor is StatefulElement) {
        final State<StatefulWidget> state = ancestor.state;
        if (state is ScrollableState &&
            state.position.isScrollingNotifier.value) {
          settled = false;
          return false;
        }
      }
      if (ancestor.widget is SettingsSection) {
        section = ancestor;
        return false;
      }
      return true;
    });
    if (!settled || section == null) return settled;
    const Set<String> loadKeys = <String>{
      'node_update_loading', 'node_update_ready', 'node_update_failed',
    };
    String? loadKey(Key? key) => key is ValueKey<String> &&
            loadKeys.contains(key.value) ? key.value : null;
    int cards = 0;
    void card(Element element, {bool loadTransition = false}) {
      if (!settled) return;
      final Widget widget = element.widget;
      if (widget is StateSwitcher && loadKey(widget.child.key) != null) {
        if (loadKey(widget.child.key) == 'node_update_loading') {
          settled = false;
          return;
        }
        loadTransition = true;
      }
      if (loadTransition &&
          widget is FadeTransition && !widget.opacity.isCompleted) {
        settled = false;
        return;
      }
      if (loadKey(widget.key) != null) loadTransition = false;
      if (element is RenderObjectElement) {
        final RenderObject render = element.renderObject;
        if (render is RenderAnimatedSize && render.isAnimating) {
          settled = false;
          return;
        }
      }
      element.debugVisitOnstageChildren((Element child) =>
          card(child, loadTransition: loadTransition));
    }
    void visit(Element element) {
      if (!settled) return;
      if (element.widget is NodeUpdateCard) {
        cards++;
        card(element);
      } else {
        element.debugVisitOnstageChildren(visit);
      }
    }
    // The sibling updater can resize this section after its entrance ends.
    // Read its original state/fade/size clocks, never its data or callbacks.
    section!.debugVisitOnstageChildren(visit);
    return settled && cards <= 1;
  }

  bool _recipeEntranceSettled(Element element) {
    // Visible rows and incoming Settings pages can still rise between
    // pointer admissions. Read each original entrance clock without
    // changing ordinary input or waiting on unrelated hover animations.
    Element child = element;
    FadeThroughTransition? switchEntrance;
    bool settled = true;
    element.visitAncestorElements((Element ancestor) {
      final Widget widget = ancestor.widget;
      if (widget is FadeThroughTransition) switchEntrance = widget;
      if (widget is RiseSwitcher) {
        final FadeThroughTransition? transition = switchEntrance;
        if (transition == null ||
            !transition.animation.isCompleted ||
            !transition.secondaryAnimation.isDismissed) {
          settled = false;
          return false;
        }
        switchEntrance = null;
      }
      if (widget is ListEntranceItem) {
        final Widget built = child.widget;
        final Listenable? animation =
            built is AnimatedBuilder ? built.animation : null;
        if (animation is! Animation<double> || !animation.isCompleted) {
          settled = false;
          return false;
        }
      }
      child = ancestor;
      return true;
    });
    return settled;
  }

  List<Element> _recipeNodeViews({Set<String>? entryPhases}) {
    final List<Element> views = <Element>[];
    void visit(Element element) {
      final Widget widget = element.widget;
      if (widget is NodeSettingsView) views.add(element);
      if (entryPhases != null) {
        if (widget is SplashScreen) entryPhases.add('startup');
        if (widget is WelcomeSurface) entryPhases.add('welcome');
        if (widget is ImportWalletSeedChoiceScreen) entryPhases.add('import');
        if (widget is WalletSuccessScreen) entryPhases.add('ready');
        if (widget is NodeSettingsView) entryPhases.add('node');
        if (widget is SyriusErrorWidget) entryPhases.add('error');
      }
      element.debugVisitOnstageChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.debugVisitOnstageChildren(visit);
    if (views.length > 1) {
      throw HarnessError('wallet-recipe-node-view-ambiguous');
    }
    return views;
  }

  String _recipeEntryPhase(Set<String> phases) {
    final EntryStartupReceipt? startup = EntryCaptureRegistry.instance.startup;
    final Object? error = startup?.initializationError;
    if (error != null &&
        (phases.contains('startup') || phases.contains('error'))) {
      if (error is WalletInitializationRefused) {
        return 'startup-initialization-refused';
      }
      if (error is FileSystemException) return 'startup-filesystem-error';
      if (error is PlatformException) return 'startup-platform-error';
      if (error is HiveError) return 'startup-hive-error';
      return 'startup-other-error';
    }
    if (phases.length != 1) return 'unknown';
    if (phases.single == 'startup' && startup != null) {
      return startup.initializationStarted
          ? 'startup-initialization-started'
          : 'startup-before-initialization';
    }
    return phases.single;
  }

  String? _recipeStartupFilmState() {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final EntryStartupReceipt? startup = registry.startup;
    if (registry.held || startup == null || !startup.isCurrent) return null;
    final Object owner = startup.startupOwner;
    if (owner is! StartupStageSession ||
        owner.isClosed || owner.film.cleanupOwnerReplaced) {
      return null;
    }
    final BuildContext? film = owner.filmKey.currentContext;
    if (film is! Element || !film.mounted) return null;
    final Widget movie = film.widget;
    if (movie is! LaunchFilm || !identical(movie.controller, owner.film)) {
      return null;
    }
    if (owner.film.isDone) return 'ended';
    final TickerModeData mode = TickerMode.getValuesNotifier(film).value;
    if (!mode.enabled) return 'ticker-muted';
    if (!SchedulerBinding.instance.framesEnabled && !mode.forceFrames) {
      return 'frames-suspended';
    }
    if (owner.film.frameCount == 0) return 'opening';
    if (owner.film.frame < 0) return 'first-frame-pending';
    if (owner.film.frame >= owner.film.frameCount - 1) return 'last-frame';
    return 'frame-visible';
  }

  _Node? _recipeStartupHint(List<_Node> nodes) {
    final EntryCaptureRegistry registry = EntryCaptureRegistry.instance;
    final EntryStartupReceipt? startup = registry.startup;
    if (registry.held ||
        startup == null ||
        !startup.isCurrent ||
        startup.initializationStarted) {
      return null;
    }
    final Object owner = startup.startupOwner;
    if (owner is! StartupStageSession || owner.isClosed || owner.film.isDone) {
      return null;
    }
    final BuildContext? film = owner.filmKey.currentContext;
    if (film is! Element || !film.mounted) return null;
    final Widget movie = film.widget;
    if (movie is! LaunchFilm || !identical(movie.controller, owner.film)) {
      return null;
    }
    final List<_Node> hints = nodes.where(
      (_Node node) =>
          node.key == 'launch_skip_hint' && node.kind == 'text',
    ).toList();
    if (hints.length != 1) return null;
    Element? receiver(Element element) {
      Element? found;
      element.visitAncestorElements((Element ancestor) {
        final Widget widget = ancestor.widget;
        if (widget is Focus &&
            widget.onKeyEvent != null &&
            widget.focusNode?.hasPrimaryFocus == true) {
          found = ancestor;
          return false;
        }
        return true;
      });
      return found;
    }
    final Element? original = receiver(film);
    final _Node hint = hints.single;
    if (original == null ||
        !identical(receiver(hint.element), original) ||
        !_reachable(hint, hint.center)) {
      return null;
    }
    return hint;
  }

  bool _recipeReady(_Node node) {
    WalletSuccessScreen? owner;
    WalletReadySurface? surface;
    node.element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget case final WalletSuccessScreen value) owner = value;
      if (ancestor.widget case final WalletReadySurface value) surface = value;
      return true;
    });
    return owner != null &&
        identical(owner!.originalFile, kWalletFile) &&
        surface?.binding?.transportQuarantined == false &&
        surface?.binding?.isCurrent == true &&
        ModalRoute.of(node.element)?.isCurrent == true &&
        kWalletInitCompleted &&
        !NodeTransitions.pending;
  }

  int? _recipeQuestion(
    List<_Node> nodes,
    List<Element> views,
    Map<String, dynamic> command,
  ) {
    final List<_Node> accepts = nodes
        .where((_Node node) => node.key == 'node_settings_question_accept')
        .toList();
    if (accepts.isEmpty) return null;
    final _RecipeSelection? selection = _recipeSelection;
    if (accepts.length != 1 || views.length != 1 || selection == null) {
      throw HarnessError('wallet-recipe-question-unowned');
    }
    final _Node accept = accepts.single;
    final NodeSettingsView source = views.single.widget as NodeSettingsView;
    DialogCard? dialog;
    accept.element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget case final DialogCard value) dialog = value;
      return dialog == null;
    });
    final AppLocalizations? l10n = AppLocalizations.of(accept.element);
    final ModalRoute<dynamic>? route = ModalRoute.of(accept.element);
    final Widget button = accept.element.widget;
    final Widget? body = dialog?.body;
    final List<Widget>? children = body is Column ? body.children : null;
    final int? expected = selection.expectedChain;
    if (expected == null ||
        l10n == null ||
        command['expectedNode'] != selection.node ||
        command['expectedNodeChain'] != expected ||
        command['originalSigningChain'] != selection.signingChain ||
        !identical(views.single, selection.source) ||
        !identical(source.presenter, selection.presenter) ||
        !identical(kWalletFile, selection.file) ||
        !identical(app.zenon, selection.client) ||
        !identical(app.zenon?.wsClient, selection.socket) ||
        !identical(app.zenon?.ledger.client, selection.ledgerTransport) ||
        app.zenon?.wsClient.url != selection.node ||
        app.zenon?.wsClient.status() != WebsocketStatus.running ||
        kCurrentNode != selection.originalNode ||
        WalletContextRevision.value != selection.revision + 1 ||
        getChainIdentifier() != selection.signingChain ||
        !NodeTransitions.pending ||
        source.presenter.state.pendingNode != selection.node ||
        source.presenter.state.clientChain != selection.signingChain ||
        dialog?.title != l10n.nodeSettingsMismatchTitle ||
        route is! FrostedDialogRoute<bool> ||
        button is! TextButton ||
        button.onPressed == null ||
        dialog?.actions.length != 2 ||
        dialog!.actions.first.key !=
            const Key('node_settings_question_cancel') ||
        !identical(dialog!.actions.last, button) ||
        children == null ||
        children.length != 3 ||
        children.first is! Text ||
        (children.first as Text).data !=
            l10n.nodeSettingsMismatchBody(expected, selection.signingChain) ||
        children.last is! Text ||
        (children.last as Text).data != selection.node ||
        !route.isCurrent) {
      throw HarnessError('wallet-recipe-question-facts-refused');
    }
    selection.question ??= accept.element;
    selection.questionRoute ??= route;
    selection.questionCallback ??= button.onPressed;
    if (!identical(selection.question, accept.element) ||
        !identical(selection.questionRoute, route) ||
        !identical(selection.questionCallback, button.onPressed)) {
      throw HarnessError('wallet-recipe-question-replaced');
    }
    return selection.id;
  }

  Map<String, Object?> _recipeObservation(Map<String, dynamic> command) {
    if (_recipeOwner == 0 ||
        !identical(_recipeFile, kWalletFile) ||
        !identical(_recipeClient, app.zenon) ||
        !identical(_recipeSocket, app.zenon?.wsClient)) {
      _recipeFile = kWalletFile;
      _recipeClient = app.zenon;
      _recipeSocket = app.zenon?.wsClient;
      _recipeOwner++;
    }
    final List<_Node> nodes = _snapshot();
    final _Node? startupHint = _recipeStartupHint(nodes);
    final Set<String> entryPhases = <String>{};
    final List<Element> views = _recipeNodeViews(entryPhases: entryPhases);
    final NodeSettingsView? view = views.isEmpty
        ? null
        : views.single.widget as NodeSettingsView;
    final List<_Node> controls = nodes
        .where(
          (_Node node) =>
              _recipeKey(node.key) &&
              <String>{'button', 'toggle', 'field'}.contains(node.kind),
        )
        .toList();
    return <String, Object?>{
      'harnessMode': 'wallet',
      'booted': booted,
      'entryPhase': _recipeEntryPhase(entryPhases),
      'startupFilmState': ?_recipeStartupFilmState(),
      'owner': _recipeOwner,
      'revision': WalletContextRevision.value,
      'walletPresent': kWalletFile != null,
      'walletInitCompleted': kWalletInitCompleted,
      'tab': kCurrentPage?.name,
      'node': kCurrentNode,
      'chainId': kNodeChainId,
      'nodeConnected':
          kCurrentNode != null &&
          app.zenon?.wsClient.status() == WebsocketStatus.running &&
          app.zenon?.wsClient.url == kCurrentNode,
      ..._recipeSigningPolicy(),
      'transitionPending': NodeTransitions.pending,
      'nodeBusy': view?.presenter.state.busy ?? false,
      'nodePicker': view != null,
      'nodeCatalog': <String>[
        if (view != null)
          for (final NodeSettingsEntry row in view.presenter.state.entries)
            row.node,
      ],
      'question': _recipeQuestion(nodes, views, command),
      'readyOriginal': controls.any(
        (_Node node) => node.key == 'wallet_ready_open' && _recipeReady(node),
      ),
      'hasError':
          nodes.any((_Node node) => node.kind == 'error') ||
          view?.presenter.state.failure != null,
      'controls': <Map<String, Object?>>[
        if (startupHint != null)
          <String, Object?>{'key': 'launch_skip_hint', 'enabled': true},
        for (final _Node node in controls)
          <String, Object?>{
            'key': node.key,
            'enabled': _recipeEnabled(node) && _reachable(node, node.center),
            if (node.key == 'node_settings_chain_toggle')
              'expanded': _recipeExpanded(node.element),
          },
      ],
    };
  }

  bool? _recipeExpanded(Element element) {
    bool? expanded;
    element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget case final Semantics semantics) {
        expanded ??= semantics.properties.expanded;
      }
      return expanded == null;
    });
    return expanded;
  }

  _Node _recipeControl(String key, {required bool field}) {
    final List<_Node> nodes = _snapshot();
    if (nodes.any((_Node node) => node.kind == 'error')) {
      throw HarnessError('wallet-recipe-visible-error');
    }
    if (key == 'launch_skip_hint' && !field) {
      final _Node? hint = _recipeStartupHint(nodes);
      if (hint == null) throw HarnessError('wallet-recipe-control-refused');
      return hint;
    }
    final List<_Node> hits = nodes
        .where(
          (_Node node) =>
              node.key == key &&
              (field
                  ? node.kind == 'field'
                  : <String>{'button', 'toggle'}.contains(node.kind)),
        )
        .toList();
    if (hits.length != 1 ||
        !_recipeEnabled(hits.single) ||
        !_reachable(hits.single, hits.single.center)) {
      throw HarnessError('wallet-recipe-control-refused');
    }
    return hits.single;
  }

  Future<Map<String, Object?>> _walletRecipeCommand(
    Map<String, dynamic> command,
  ) async {
    try {
      if (command.keys.any(
        (String key) => !<String>{
          'cmd',
          'action',
          'key',
          'value',
          'owner',
          'revision',
          'dy',
          'expectedNode',
          'expectedNodeChain',
          'originalSigningChain',
          'originNode',
          'originRevision',
          'question',
        }.contains(key),
      )) {
        throw HarnessError('wallet-recipe-input-refused');
      }
      final Object? action = command['action'];
      if (action == 'observe') return _recipeObservation(command);
      final Map<String, Object?> observed = _recipeObservation(command);
      void current() {
        final Map<String, Object?> fresh = _recipeObservation(command);
        if (!identical(_recipeFile, kWalletFile) ||
            !identical(_recipeClient, app.zenon) ||
            command['owner'] != _recipeOwner ||
            command['revision'] != WalletContextRevision.value ||
            fresh['hasError'] != false ||
            fresh['signingPolicyReady'] != true ||
            fresh['signingChainId'] != fresh['savedSigningChainId']) {
          throw HarnessError('wallet-recipe-original-owner-changed');
        }
      }

      current();
      if (action == 'scroll') {
        if (NodeTransitions.pending ||
            observed['question'] != null ||
            !<int>{-300, 300}.contains(command['dy'])) {
          throw HarnessError('wallet-recipe-scroll-refused');
        }
        await _scroll(<String, dynamic>{'dy': command['dy']});
        return <String, Object?>{'acted': true};
      }
      final Object? key = command['key'];
      if (key is! String ||
          !_recipeKey(key) ||
          (key == 'launch_skip_hint'
              ? action != 'key'
              : action != 'tap' && action != 'type')) {
        throw HarnessError('wallet-recipe-action-refused');
      }
      if (NodeTransitions.pending && key != 'node_settings_question_accept') {
        throw HarnessError('wallet-recipe-transition-held');
      }
      final bool field = action == 'type';
      final _Node original = _recipeControl(key, field: field);
      final EntryStartupReceipt? startup = key == 'launch_skip_hint'
          ? EntryCaptureRegistry.instance.startup
          : null;
      if (key.startsWith('node_settings_select_') ||
          key == 'node_onboarding_continue') {
        final List<Element> views = _recipeNodeViews();
        if (views.length != 1 ||
            command['expectedNode'] is! String ||
            !command.containsKey('originNode') ||
            command['originNode'] != kCurrentNode ||
            command['originRevision'] != WalletContextRevision.value ||
            command['originalSigningChain'] != getChainIdentifier() ||
            (key.startsWith('node_settings_select_') &&
                key != 'node_settings_select_${command['expectedNode']}') ||
            (key == 'node_onboarding_continue' &&
                command['expectedNode'] != kCurrentNode)) {
          throw HarnessError('wallet-recipe-selection-origin-refused');
        }
        final NodeSettingsView view = views.single.widget as NodeSettingsView;
        _recipeSelection = _RecipeSelection(
          id: ++_recipeSelectionId,
          source: views.single,
          presenter: view.presenter,
          file: kWalletFile,
          client: app.zenon,
          socket: app.zenon?.wsClient,
          ledgerTransport: app.zenon?.ledger.client,
          node: command['expectedNode'] as String,
          originalNode: kCurrentNode,
          revision: WalletContextRevision.value,
          signingChain: getChainIdentifier(),
          expectedChain: command['expectedNodeChain'] as int?,
        );
      }
      final _RecipeSelection? selection = _recipeSelection;
      if (key == 'node_settings_question_accept') {
        if (selection == null ||
            selection.accepted ||
            command['question'] != observed['question'] ||
            command['question'] != selection.id) {
          throw HarnessError('wallet-recipe-question-already-used');
        }
        selection.accepted = true;
      }
      if (key == 'wallet_ready_open') {
        if (_recipeReadyOpening || !_recipeReady(original)) {
          throw HarnessError('wallet-recipe-original-ready-unavailable');
        }
        _recipeReadyOpening = true;
      }
      void admission() {
        current();
        if (key == 'launch_skip_hint' &&
            !identical(EntryCaptureRegistry.instance.startup, startup)) {
          throw HarnessError('wallet-recipe-original-owner-changed');
        }
        final _Node fresh = _recipeControl(key, field: field);
        final String? change = recipeControlChange(
          original: original.element,
          current: fresh.element,
          originalRect: original.rect,
          currentRect: fresh.rect,
        );
        if (change != null) {
          throw HarnessError(change);
        }
        if (key == 'node_settings_question_accept') {
          if (!identical(selection, _recipeSelection) ||
              _recipeQuestion(_snapshot(), _recipeNodeViews(), command) !=
                  selection?.id) {
            throw HarnessError('wallet-recipe-original-question-changed');
          }
        }
        if (key == 'wallet_ready_open' && !_recipeReady(fresh)) {
          throw HarnessError('wallet-recipe-original-ready-changed');
        }
      }

      final Map<String, dynamic> input = <String, dynamic>{'key': key};
      if (action == 'key') {
        // The owned startup receiver consumes Space on key-down. Dispatch
        // the complete key pair in one turn so its ordinary handoff does not
        // become a second pointer admission against the retired hint.
        admission();
        final Map<String, Object?> reply = await _key(
          <String, dynamic>{'key': 'space', 'settleMs': 0},
        );
        if (reply['handled'] != true) {
          throw HarnessError('wallet-recipe-control-refused');
        }
      } else if (field) {
        final Object? value = command['value'];
        if (value is! String || value.length > 512) {
          throw HarnessError('wallet-recipe-private-input-refused');
        }
        await _type(
          <String, dynamic>{...input, 'value': value},
          requireAdmission: admission,
        );
      } else {
        await _tap(input, requireAdmission: admission);
      }
      // Generic type/tree replies can contain private field data. Recipe
      // commands return only the fact that their original action completed.
      return <String, Object?>{'acted': true};
    } on HarnessError catch (error) {
      if (error.detail == null &&
          walletRecipeFailureCodes.contains(error.message)) {
        rethrow;
      }
      throw HarnessError('wallet-recipe-refused');
    } on Object {
      throw HarnessError('wallet-recipe-refused');
    }
  }

  RenderView get _view {
    final List<RenderView> views = WidgetsBinding.instance.renderViews.toList();
    if (views.length != 1) {
      throw HarnessError('expected one owned Flutter view', views.length);
    }
    return views.single;
  }

  ClientMetrics _clientMetrics() {
    final ui.FlutterView view = _view.flutterView;
    return ClientMetrics(view.physicalSize, view.devicePixelRatio);
  }

  Size _viewSize() => _clientMetrics().logicalSize;

  // ---------------------------------------------------------------- snapshot

  List<_Node> _snapshot() {
    final List<_Node> out = <_Node>[];
    final Element? root = WidgetsBinding.instance.rootElement;
    if (root == null) return out;
    _tabs = 0;
    _visit(root, _Ctx(clip: Offset.zero & _viewSize()), out);
    for (int i = 0; i < out.length; i++) {
      out[i].ref = i + 1;
      if (out[i].parts.isEmpty && out[i].loose.length <= 3) {
        out[i].parts.addAll(out[i].loose);
      }
    }
    _last = <int, _Node>{for (final _Node n in out) n.ref: n};
    return out;
  }

  Rect? _rectOf(Element e) {
    final RenderObject? ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    try {
      return logicalClientRect(ro);
    } on Object catch (_) {
      return null;
    }
  }

  void _visit(Element e, _Ctx c, List<_Node> out) {
    final Widget w = e.widget;
    final String type = w.runtimeType.toString();
    _Ctx n = c;

    // A route that is not on top of its navigator sits under a dialog or a
    // menu: drawn, but out of reach.
    if (type.startsWith('_ModalScopeStatus')) {
      try {
        if (!((w as dynamic).isCurrent as bool)) n = n.copy(blocked: true);
      } on Object catch (_) {}
    }
    if (n.blocked) return;

    if (w is ErrorWidget) {
      final Rect? r = _rectOf(e);
      if (r != null) {
        out.add(_Node('error', type, e, r, n.path)..parts.add(w.message));
      }
      return;
    }

    final Key? key = w.key;
    if (key is ValueKey<String>) n = n.copy(key: key.value);
    if (w is Semantics && w.properties.tooltip != null) {
      n = n.copy(tip: w.properties.tooltip, semanticTip: true);
      n.tappable?.extra['tip'] = w.properties.tooltip;
    }
    if (w is Tooltip) {
      final InlineSpan? rich = w.richMessage;
      final String? tip =
          w.message ??
          (rich is TextSpan ? rich.semanticsLabel : null) ??
          rich?.toPlainText(includePlaceholders: false);
      // Above a button the tip is carried down to it; inside one (IconButton
      // builds its own) it is handed up.
      final _Node? t = n.tappable;
      if (tip != null && !n.semanticTip) {
        if (t != null && t.foldable) {
          t.extra.putIfAbsent('tip', () => tip);
        } else {
          n = n.copy(tip: tip);
        }
      }
    }
    // The side rail names each item by key, `nav_<tab>`.
    final Key? navKey = w.key;
    if (navKey is ValueKey<String> && navKey.value.startsWith('nav_')) {
      final _Node? t = n.tappable;
      if (t != null) t.extra['tab'] = navKey.value.substring(4);
    }
    if (w is Tab) {
      // The main tab bar is built in kTabs order; half of it is icons.
      final _Node? t = n.tappable;
      if (t != null && _tabs < kTabs.length) t.extra['tab'] = kTabs[_tabs].name;
      _tabs++;
    }
    if (w is TextField) {
      n = n.copy(decoration: w.decoration ?? const InputDecoration());
    }
    if (w is Scrollable || w is ClipRect || w is ClipRRect) {
      final Rect? r = _rectOf(e);
      if (r != null) n = n.copy(clip: n.clip.intersect(r));
      if (n.clip.width <= 0 || n.clip.height <= 0) return;
    }
    if (!type.startsWith('_') && !_kPathNoise.contains(_bare(type))) {
      final List<String> p = <String>[...n.path, type];
      n = n.copy(path: p.length > 5 ? p.sublist(p.length - 5) : p);
    }

    _Node? made;
    Rect? visible() {
      final Rect? r = _rectOf(e);
      if (r == null) return null;
      final Rect v = r.intersect(n.clip);
      return (v.width <= 0.5 || v.height <= 0.5) ? null : v;
    }

    if (w is EditableText) {
      final Rect? r = visible();
      if (r != null) {
        final InputDecoration? d = n.decoration;
        made = _Node('field', type, e, r, n.path)
          ..enabled = !w.readOnly
          ..extra.addAll(<String, Object?>{
            'value': w.obscureText
                ? '•' * w.controller.text.length
                : w.controller.text,
            if (w.obscureText) 'obscured': true,
            if (w.focusNode.hasFocus) 'focused': true,
            if (d?.hintText != null) 'hint': d!.hintText,
            if (d?.labelText != null) 'labelText': d!.labelText,
            if (d?.errorText != null) 'error': d!.errorText,
          });
      }
    } else if (w is Text || (w is RichText && !n.inText)) {
      final String text = _clean(
        w is Text
            ? (w.data ?? w.textSpan?.toPlainText() ?? '')
            : (w as RichText).text.toPlainText(),
      );
      // Inside a TextField the hint, label and error are reported on the
      // field itself.
      if (text.isNotEmpty && n.decoration == null) {
        final _Node? t = n.tappable;
        if (t != null && t.foldable) {
          t.parts.add(text);
        } else {
          t?.loose.add(text);
          final Rect? r = visible();
          if (r != null) {
            made = _Node('text', type, e, r, n.path)..parts.add(text);
          }
        }
      }
      n = n.copy(inText: true);
    } else if (w is Icon || w is SvgPicture || w is Image) {
      final _Node? t = n.tappable;
      if (t != null && t.foldable) {
        final String? name = _graphicName(w);
        if (name != null) {
          (t.extra.putIfAbsent('icons', () => <String>[])! as List<String>).add(
            name,
          );
        }
      }
    } else {
      final ({String kind, bool enabled, Map<String, Object?> extra})? k =
          _classify(w);
      if (k != null) {
        final Rect? r = visible();
        final _Node? parent = n.tappable;
        // A button is several nested detectors; report the outermost one.
        final bool sameAsParent =
            r != null &&
            parent != null &&
            _contains(parent.rect, r) &&
            r.width * r.height >= 0.5 * parent.rect.width * parent.rect.height;
        if (r != null && !sameAsParent) {
          made = _Node(k.kind, type, e, r, n.path)
            ..enabled = k.enabled
            ..foldable = r.width * r.height <= _kFoldArea
            ..extra.addAll(k.extra);
          if (n.tip != null) made.extra['tip'] = n.tip;
        }
      }
    }

    if (made != null) {
      made.key = n.key;
      final String? selector = made.key;
      if (made.kind == 'button' &&
          selector != null &&
          selector.startsWith('nav_')) {
        made.extra['tab'] = selector.substring(4);
      }
      out.add(made);
      n = n.copy(clearKey: true, clearTip: true);
      if (made.kind != 'text' && made.kind != 'field') {
        n = n.copy(tappable: made);
      }
    }

    final _Ctx next = n;
    e.debugVisitOnstageChildren((Element child) => _visit(child, next, out));
  }

  /// Icon fonts draw glyphs from the private use areas; as text they are
  /// noise.
  static String _clean(String s) => String.fromCharCodes(
    s.runes.where(
      (int r) =>
          r != 0xFFFC &&
          !(r >= 0xE000 && r <= 0xF8FF) &&
          !(r >= 0xF0000 && r <= 0x10FFFD),
    ),
  ).trim();

  static String _bare(String type) {
    final int i = type.indexOf('<');
    return i < 0 ? type : type.substring(0, i);
  }

  static bool _contains(Rect outer, Rect inner) =>
      inner.left >= outer.left - 1 &&
      inner.top >= outer.top - 1 &&
      inner.right <= outer.right + 1 &&
      inner.bottom <= outer.bottom + 1;

  static String? _graphicName(Widget w) {
    if (w is Icon) {
      final IconData? d = w.icon;
      if (d == null) return null;
      return '${d.fontFamily ?? 'icon'}:${d.codePoint.toRadixString(16)}';
    }
    if (w is SvgPicture) {
      final Object loader = w.bytesLoader;
      return loader is SvgAssetLoader ? loader.assetName : 'svg';
    }
    if (w is Image) {
      final ImageProvider p = w.image;
      return p is AssetImage ? p.assetName : 'image';
    }
    return null;
  }

  static ({String kind, bool enabled, Map<String, Object?> extra})? _classify(
    Widget w,
  ) {
    const Map<String, Object?> none = <String, Object?>{};
    if (w is ButtonStyleButton) {
      return (kind: 'button', enabled: w.onPressed != null, extra: none);
    }
    if (w is IconButton) {
      return (
        kind: 'button',
        enabled: w.onPressed != null,
        extra: <String, Object?>{if (w.tooltip != null) 'tip': w.tooltip},
      );
    }
    if (w is MaterialButton) {
      return (kind: 'button', enabled: w.onPressed != null, extra: none);
    }
    if (w is RawMaterialButton) {
      return (kind: 'button', enabled: w.onPressed != null, extra: none);
    }
    if (w is FloatingActionButton) {
      return (kind: 'button', enabled: w.onPressed != null, extra: none);
    }
    if (w is Checkbox) {
      return (
        kind: 'toggle',
        enabled: w.onChanged != null,
        extra: <String, Object?>{'checked': w.value},
      );
    }
    if (w is Switch) {
      return (
        kind: 'toggle',
        enabled: w.onChanged != null,
        extra: <String, Object?>{'checked': w.value},
      );
    }
    if (w is Radio) {
      Object? group;
      try {
        group = (w as dynamic).groupValue;
      } on Object catch (_) {}
      return (
        kind: 'toggle',
        enabled: true,
        extra: <String, Object?>{
          'value': w.value.toString(),
          'checked': group != null && group == w.value,
        },
      );
    }
    if (w is Slider) {
      return (
        kind: 'slider',
        enabled: w.onChanged != null,
        extra: <String, Object?>{'value': w.value, 'min': w.min, 'max': w.max},
      );
    }
    if (w is DropdownButton) {
      return (
        kind: 'dropdown',
        enabled: w.onChanged != null,
        extra: <String, Object?>{
          if (w.value != null) 'value': w.value.toString(),
        },
      );
    }
    if (w is PopupMenuButton) {
      return (kind: 'button', enabled: w.enabled, extra: none);
    }
    if (w is InkResponse) {
      final bool on =
          w.onTap != null || w.onDoubleTap != null || w.onLongPress != null;
      return on ? (kind: 'button', enabled: true, extra: none) : null;
    }
    if (w is GestureDetector) {
      final bool on =
          w.onTap != null ||
          w.onTapDown != null ||
          w.onTapUp != null ||
          w.onDoubleTap != null ||
          w.onLongPress != null ||
          w.onSecondaryTap != null;
      return on ? (kind: 'button', enabled: true, extra: none) : null;
    }
    return null;
  }

  Map<String, Object?> _tree(Map<String, dynamic> c) {
    final List<_Node> nodes = _snapshot();
    final String? kind = c['kind'] as String?;
    final Size size = _viewSize();
    return <String, Object?>{
      'size': <int>[size.width.round(), size.height.round()],
      'nodes': <Map<String, Object?>>[
        for (final _Node n in nodes)
          if (kind == null || n.kind == kind) n.toJson(),
      ],
    };
  }

  // --------------------------------------------------------------- selectors

  /// Resolves `sel` to one node. `kinds` is the order of preference when the
  /// selector alone does not decide.
  _Node _find(
    Map<String, dynamic> c, {
    List<String> kinds = const <String>[
      'button',
      'toggle',
      'dropdown',
      'slider',
      'field',
      'text',
    ],
    bool only = false,
  }) {
    final Object? ref = c['ref'];
    if (ref is int) {
      final _Node? old = _last[ref];
      if (old == null || !old.element.mounted) {
        throw HarnessError('ref $ref is stale; take a new tree');
      }
      // Same element, wherever it is now.
      for (final _Node n in _snapshot()) {
        if (identical(n.element, old.element) && n.kind == old.kind) return n;
      }
      throw HarnessError('ref $ref is no longer on screen');
    }
    final List<_Node> hits = _matches(c, kinds: kinds, only: only);
    if (hits.isEmpty) {
      throw HarnessError('nothing matches', _describe(c));
    }
    final int nth = c['nth'] as int? ?? 0;
    if (nth >= hits.length) {
      throw HarnessError('only ${hits.length} match', _describe(c));
    }
    return hits[nth];
  }

  static Map<String, Object?> _describe(Map<String, dynamic> c) =>
      <String, Object?>{
        for (final String k in <String>[
          'text',
          'key',
          'type',
          'kind',
          'tab',
          'nth',
        ])
          if (c[k] != null) k: c[k],
      };

  List<_Node> _matches(
    Map<String, dynamic> c, {
    required List<String> kinds,
    bool only = false,
  }) {
    final String? text = (c['text'] as String?)?.toLowerCase();
    final String? key = c['key'] as String?;
    final String? type = c['type'] as String?;
    final String? kind = c['kind'] as String?;
    final String? tab = c['tab'] as String?;
    final bool exact = c['exact'] == true;
    if (text == null &&
        key == null &&
        type == null &&
        kind == null &&
        tab == null) {
      throw HarnessError(
        'a selector needs ref, at, text, key, type, kind or tab',
      );
    }
    final List<(int, int, _Node)> ranked = <(int, int, _Node)>[];
    for (final _Node n in _snapshot()) {
      if (kind != null && n.kind != kind) continue;
      if (only && !kinds.contains(n.kind)) continue;
      if (key != null && n.key != key) continue;
      if (tab != null && n.extra['tab'] != tab) continue;
      if (type != null &&
          _bare(n.type) != type &&
          !n.path.any((String p) => _bare(p) == type)) {
        continue;
      }
      int rank = 0;
      if (text != null) {
        final String label = n.label.toLowerCase();
        final List<String> others = <String>[
          for (final String k in <String>['tip', 'hint', 'labelText', 'tab'])
            if (n.extra[k] is String) (n.extra[k]! as String).toLowerCase(),
          if (n.extra['icons'] is List<String>)
            ...(n.extra['icons']! as List<String>).map(
              (String s) => s.toLowerCase(),
            ),
        ];
        if (label == text) {
          rank = 0;
        } else if (others.contains(text)) {
          rank = 1;
        } else if (exact) {
          continue;
        } else if (label.startsWith(text)) {
          rank = 2;
        } else if (label.contains(text) ||
            others.any((String s) => s.contains(text))) {
          rank = 3;
        } else {
          continue;
        }
      }
      final int k = kinds.indexOf(n.kind);
      ranked.add((rank, k < 0 ? kinds.length : k, n));
    }
    if (ranked.isEmpty) return <_Node>[];
    // Best text rank wins; within it, the preferred kind; then document order.
    ranked.sort(((int, int, _Node) a, (int, int, _Node) b) {
      if (a.$1 != b.$1) return a.$1 - b.$1;
      if (a.$2 != b.$2) return a.$2 - b.$2;
      return a.$3.ref - b.$3.ref;
    });
    final (int, int, _Node) best = ranked.first;
    return <_Node>[
      for (final (int, int, _Node) r in ranked)
        if (r.$1 == best.$1 && r.$2 == best.$2) r.$3,
    ];
  }

  /// A point from `at: [x, y]`, or the centre of the selected node.
  ({Offset point, _Node? node}) _target(
    Map<String, dynamic> c, {
    List<String>? kinds,
  }) {
    final Object? at = c['at'];
    if (at is List) {
      return (
        point: Offset((at[0] as num).toDouble(), (at[1] as num).toDouble()),
        node: null,
      );
    }
    final _Node n = kinds == null ? _find(c) : _find(c, kinds: kinds);
    return (point: n.center, node: n);
  }

  bool _reachable(_Node n, Offset p) {
    final RenderObject? ro = n.element.renderObject;
    if (ro == null) return false;
    return _reachableRender(ro, p);
  }

  bool _reachableRender(RenderObject ro, Offset p) {
    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      p,
      WidgetsBinding.instance.renderViews.first.flutterView.viewId,
    );
    for (final HitTestEntry<HitTestTarget> entry in result.path) {
      final HitTestTarget t = entry.target;
      if (t is! RenderObject) continue;
      for (RenderObject? o = t; o != null; o = o.parent) {
        if (identical(o, ro)) return true;
      }
    }
    return false;
  }

  // ----------------------------------------------------------------- pointer

  Future<void> _frame() => WidgetsBinding.instance.endOfFrame.timeout(
    const Duration(milliseconds: 250),
    onTimeout: () {},
  );

  /// Waits for the frame schedule to go quiet, or for `maxMs`. A looping
  /// animation never goes quiet, hence the cap.
  Future<void> _settle([int maxMs = 600]) async {
    final Stopwatch sw = Stopwatch()..start();
    int quiet = 0;
    while (sw.elapsedMilliseconds < maxMs) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      quiet = SchedulerBinding.instance.hasScheduledFrame ? 0 : quiet + 1;
      if (quiet >= 4) break;
    }
  }

  void _send(PointerEvent e) => GestureBinding.instance.handlePointerEvent(e);

  Future<void> _moveTo(Offset p) async {
    if (!_mouseAdded) {
      _send(
        PointerAddedEvent(
          position: p,
          kind: PointerDeviceKind.mouse,
          device: _device,
        ),
      );
      _mouseAdded = true;
    }
    _send(
      PointerHoverEvent(
        position: p,
        delta: p - _mouseAt,
        kind: PointerDeviceKind.mouse,
        device: _device,
      ),
    );
    _mouseAt = p;
    await _frame();
  }

  Future<void> _click(
    Offset p, {
    int buttons = kPrimaryButton,
    int holdMs = 50,
    void Function()? requireAdmission,
    VoidCallback? afterRelease,
  }) async {
    await _moveTo(p);
    requireAdmission?.call();
    final int id = ++_pointer;
    _send(
      PointerDownEvent(
        pointer: id,
        position: p,
        kind: PointerDeviceKind.mouse,
        device: _device,
        buttons: buttons,
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: holdMs));
    try {
      requireAdmission?.call();
    } on Object {
      _send(
        PointerCancelEvent(
          pointer: id,
          position: p,
          kind: PointerDeviceKind.mouse,
          device: _device,
        ),
      );
      rethrow;
    }
    _send(
      PointerUpEvent(
        pointer: id,
        position: p,
        kind: PointerDeviceKind.mouse,
        device: _device,
      ),
    );
    afterRelease?.call(); // Same dispatch turn; no await or paint intervenes.
  }

  Future<Map<String, Object?>> _tap(
    Map<String, dynamic> c, {
    void Function()? requireAdmission,
  }) async {
    final ({Offset point, _Node? node}) t = _target(c);
    final _Node? n = t.node;
    if (n != null && c['force'] != true) {
      if (!n.enabled) throw HarnessError('disabled', n.toJson());
      if (!_reachable(n, t.point)) {
        throw HarnessError('covered by something else', n.toJson());
      }
    }
    void admission() {
      requireAdmission?.call();
      if (requireAdmission != null) {
        final ({Offset point, _Node? node}) fresh = _target(c);
        if (n == null ||
            fresh.node == null ||
            !identical(fresh.node!.element, n.element) ||
            fresh.point != t.point ||
            !fresh.node!.enabled ||
            !_reachable(fresh.node!, fresh.point)) {
          throw const SeedRefused('original-ui-control-changed');
        }
        if (c['seedTokenPreparation'] == true) {
          TokenCreateFrame? frame;
          fresh.node!.element.visitAncestorElements((Element ancestor) {
            if (ancestor.widget case final TokenCreateFrame value) {
              frame = value;
              return false;
            }
            return true;
          });
          final Key? key = frame?.key;
          requireSeedTokenPreparation(
            frameKey: key is ValueKey<String> ? key.value : null,
            active: frame?.active == true,
            busy: frame?.busy != false,
          );
        }
        if (c['seedOwner'] != null) {
          SendConfirmation? confirmation;
          fresh.node!.element.visitAncestorElements((Element ancestor) {
            if (ancestor.widget case final SendConfirmation value) {
              confirmation = value;
              return false;
            }
            return true;
          });
          final SendConfirmation? shown = confirmation;
          if (shown == null ||
              shown.intent.fromAddress != c['seedOwner'] ||
              shown.intent.toAddress != c['seedRecipient'] ||
              shown.intent.tokenStandard != c['seedToken'] ||
              shown.intent.amount.toString() != c['seedAmount']) {
            throw const SeedRefused('original-transfer-review-mismatch');
          }
        }
      }
    }

    if (c['right'] == true) {
      await _click(
        t.point,
        buttons: kSecondaryButton,
        requireAdmission: admission,
      );
    } else if (c['long'] == true) {
      await _click(t.point, holdMs: 700, requireAdmission: admission);
    } else {
      await _click(t.point, requireAdmission: admission);
      if (c['double'] == true) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await _click(t.point, requireAdmission: admission);
      }
    }
    await _settle(c['settleMs'] as int? ?? 600);
    return <String, Object?>{
      'at': <int>[t.point.dx.round(), t.point.dy.round()],
      if (n != null) 'target': n.toJson(),
    };
  }

  Future<Map<String, Object?>> _hover(Map<String, dynamic> c) async {
    final ({Offset point, _Node? node}) t = _target(c);
    await _moveTo(t.point);
    await _settle(c['settleMs'] as int? ?? 900);
    return <String, Object?>{if (t.node != null) 'target': t.node!.toJson()};
  }

  /// A file dragged in from the desktop. The OS half of a drop cannot be
  /// driven from here, so this enters at the message the desktop_drop plugin
  /// sends once Windows has delivered one: everything from the plugin's Dart
  /// side on, the DropTarget's hit test included, runs as it does for a hand.
  Future<Map<String, Object?>> _drop(Map<String, dynamic> c) async {
    final ({Offset point, _Node? node}) t = _target(c);
    final String path = c['path'] as String;
    if (!File(path).existsSync()) {
      throw StateError('no such file: $path');
    }
    // The plugin reports physical pixels on Windows.
    final double ratio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final List<double> at = <double>[t.point.dx * ratio, t.point.dy * ratio];
    Future<void> send(String method, Object arguments) async {
      ServicesBinding.instance.channelBuffers.push(
        'desktop_drop',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (ByteData? _) {},
      );
    }

    await send('entered', at);
    await send('updated', at);
    await _settle(200);
    await send('performOperation', <String>[path]);
    await _settle(c['settleMs'] as int? ?? 600);
    return <String, Object?>{if (t.node != null) 'target': t.node!.toJson()};
  }

  Future<Map<String, Object?>> _scroll(Map<String, dynamic> c) async {
    final Size size = _viewSize();
    final bool aimed = c['at'] != null || _hasSelector(c);
    final Offset p = aimed ? _target(c).point : size.center(Offset.zero);
    await _moveTo(p);
    _send(
      PointerScrollEvent(
        position: p,
        device: _device,
        scrollDelta: Offset(
          (c['dx'] as num? ?? 0).toDouble(),
          (c['dy'] as num? ?? 0).toDouble(),
        ),
      ),
    );
    await _settle(c['settleMs'] as int? ?? 500);
    return <String, Object?>{
      'at': <int>[p.dx.round(), p.dy.round()],
    };
  }

  static bool _hasSelector(Map<String, dynamic> c) => <String>[
    'ref',
    'text',
    'key',
    'type',
    'kind',
    'tab',
  ].any((String k) => c[k] != null);

  Future<Map<String, Object?>> _drag(Map<String, dynamic> c) async {
    final Offset from = _target(c).point;
    final List<dynamic> by = c['by'] as List<dynamic>;
    final Offset to =
        from + Offset((by[0] as num).toDouble(), (by[1] as num).toDouble());
    await _moveTo(from);
    final int id = ++_pointer;
    _send(
      PointerDownEvent(
        pointer: id,
        position: from,
        kind: PointerDeviceKind.mouse,
        device: _device,
      ),
    );
    const int steps = 12;
    Offset at = from;
    for (int i = 1; i <= steps; i++) {
      final Offset next = Offset.lerp(from, to, i / steps)!;
      _send(
        PointerMoveEvent(
          pointer: id,
          position: next,
          delta: next - at,
          kind: PointerDeviceKind.mouse,
          device: _device,
        ),
      );
      at = next;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    _send(
      PointerUpEvent(
        pointer: id,
        position: to,
        kind: PointerDeviceKind.mouse,
        device: _device,
      ),
    );
    _mouseAt = to;
    await _settle();
    return <String, Object?>{};
  }

  // ---------------------------------------------------------------- keyboard

  EditableTextState? _focusedEditable() {
    final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return null;
    if (ctx is StatefulElement && ctx.state is EditableTextState) {
      return ctx.state as EditableTextState;
    }
    return ctx.findAncestorStateOfType<EditableTextState>();
  }

  Future<Map<String, Object?>> _type(
    Map<String, dynamic> c, {
    void Function()? requireAdmission,
  }) async {
    final String text = c['value'] as String? ?? '';
    EditableTextState? state;
    _Node? node;
    if (c['at'] != null || _hasSelector(c)) {
      node = _find(c, kinds: const <String>['field'], only: true);
      if (!node.enabled) throw HarnessError('read-only field', node.toJson());
      if (!_reachable(node, node.center)) {
        throw HarnessError('covered by something else', node.toJson());
      }
      // Click into it first, as a person would: focus listeners fire.
      await _click(node.center, requireAdmission: requireAdmission);
      await _frame();
      requireAdmission?.call();
      state = (node.element as StatefulElement).state as EditableTextState;
    } else {
      state = _focusedEditable();
      if (state == null) throw HarnessError('no field has focus');
    }
    final String value = c['append'] == true
        ? state.textEditingValue.text + text
        : text;
    // The path the platform text input takes: formatters and onChanged run.
    state.userUpdateTextEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await _frame();
    if (c['submit'] == true) {
      state.performAction(TextInputAction.done);
    }
    await _settle(c['settleMs'] as int? ?? 400);
    return <String, Object?>{
      'value': state.widget.obscureText
          ? '•' * state.textEditingValue.text.length
          : state.textEditingValue.text,
      if (node != null) 'target': node.toJson(),
    };
  }

  static final Map<String, (LogicalKeyboardKey, PhysicalKeyboardKey)>
  _keys = <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
    'enter': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
    'tab': (LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
    'escape': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
    'space': (LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
    'backspace': (LogicalKeyboardKey.backspace, PhysicalKeyboardKey.backspace),
    'delete': (LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete),
    'up': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
    'down': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
    'left': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
    'right': (LogicalKeyboardKey.arrowRight, PhysicalKeyboardKey.arrowRight),
    'home': (LogicalKeyboardKey.home, PhysicalKeyboardKey.home),
    'end': (LogicalKeyboardKey.end, PhysicalKeyboardKey.end),
    'pageup': (LogicalKeyboardKey.pageUp, PhysicalKeyboardKey.pageUp),
    'pagedown': (LogicalKeyboardKey.pageDown, PhysicalKeyboardKey.pageDown),
    'shift': (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft),
    'ctrl': (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft),
    'alt': (LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft),
    'a': (LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA),
    'c': (LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC),
    'h': (LogicalKeyboardKey.keyH, PhysicalKeyboardKey.keyH),
    'k': (LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK),
    'l': (LogicalKeyboardKey.keyL, PhysicalKeyboardKey.keyL),
    'r': (LogicalKeyboardKey.keyR, PhysicalKeyboardKey.keyR),
    'v': (LogicalKeyboardKey.keyV, PhysicalKeyboardKey.keyV),
    'x': (LogicalKeyboardKey.keyX, PhysicalKeyboardKey.keyX),
    'z': (LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
    ',': (LogicalKeyboardKey.comma, PhysicalKeyboardKey.comma),
    '1': (LogicalKeyboardKey.digit1, PhysicalKeyboardKey.digit1),
    '2': (LogicalKeyboardKey.digit2, PhysicalKeyboardKey.digit2),
    '3': (LogicalKeyboardKey.digit3, PhysicalKeyboardKey.digit3),
    '4': (LogicalKeyboardKey.digit4, PhysicalKeyboardKey.digit4),
    '5': (LogicalKeyboardKey.digit5, PhysicalKeyboardKey.digit5),
    '6': (LogicalKeyboardKey.digit6, PhysicalKeyboardKey.digit6),
    '7': (LogicalKeyboardKey.digit7, PhysicalKeyboardKey.digit7),
    '8': (LogicalKeyboardKey.digit8, PhysicalKeyboardKey.digit8),
  };

  bool _dispatchKey(KeyEvent e) {
    final bool handled = HardwareKeyboard.instance.handleKeyEvent(e);
    // Flutter 3.47 delivers to both destinations before combining results.
    // Focus is registered through the message bridge in this pinned SDK.
    // ignore: deprecated_member_use
    final KeyMessageHandler? h =
        // Retain compatibility with the legacy Focus message registration.
        // ignore: deprecated_member_use
        ServicesBinding.instance.keyEventManager.keyMessageHandler;
    // This pinned bridge returns the actual Shortcuts and editing result.
    // ignore: deprecated_member_use
    final bool focusHandled = h?.call(KeyMessage(<KeyEvent>[e], null)) ?? false;
    return handled || focusHandled;
  }

  /// `key` is a chord such as `enter`, `escape`, `shift+tab` or `ctrl+a`.
  Future<Map<String, Object?>> _key(Map<String, dynamic> c) async {
    final List<String> chord = (c['key'] as String).toLowerCase().split('+');
    final List<(LogicalKeyboardKey, PhysicalKeyboardKey)> keys =
        <(LogicalKeyboardKey, PhysicalKeyboardKey)>[
          for (final String k in chord)
            _keys[k] ??
                (throw HarnessError('unknown key $k', _keys.keys.toList())),
        ];
    final Duration ts = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    bool handled = false;
    for (final (LogicalKeyboardKey, PhysicalKeyboardKey) k in keys) {
      handled =
          _dispatchKey(
            KeyDownEvent(logicalKey: k.$1, physicalKey: k.$2, timeStamp: ts),
          ) ||
          handled;
    }
    // On desktop Enter reaches a text field as an input action from the
    // platform's text plugin, not as a key event.
    if (chord.length == 1 && chord.first == 'enter' && !handled) {
      _focusedEditable()?.performAction(TextInputAction.done);
    }
    for (final (LogicalKeyboardKey, PhysicalKeyboardKey) k in keys.reversed) {
      _dispatchKey(
        KeyUpEvent(logicalKey: k.$1, physicalKey: k.$2, timeStamp: ts),
      );
    }
    await _settle(c['settleMs'] as int? ?? 500);
    return <String, Object?>{'handled': handled};
  }

  // -------------------------------------------------------------------- wait

  Future<Map<String, Object?>> _wait(Map<String, dynamic> c) async {
    final int timeout = c['timeoutMs'] as int? ?? 10000;
    final bool gone = c['gone'] == true;
    final Stopwatch sw = Stopwatch()..start();
    while (true) {
      final List<_Node> hits = _matches(
        c,
        kinds: const <String>[
          'button',
          'toggle',
          'dropdown',
          'slider',
          'field',
          'text',
          'error',
        ],
      );
      if (gone ? hits.isEmpty : hits.isNotEmpty) {
        return <String, Object?>{
          'ms': sw.elapsedMilliseconds,
          if (!gone) 'target': hits.first.toJson(),
        };
      }
      if (sw.elapsedMilliseconds >= timeout) {
        throw HarnessError(
          gone
              ? 'still there after $timeout ms'
              : 'not there after $timeout ms',
          _describe(c),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  // -------------------------------------------------------------------- misc

  Map<String, Object?> _assertPresentation(Map<String, dynamic> c) {
    final Element original = _requirePresentationCurrent();
    if (c['ref'] != null || c['at'] != null || c['gone'] == true) {
      throw HarnessError('assert needs a stable positive selector');
    }
    final List<_Node> errors = _snapshot()
        .where((_Node n) => n.kind == 'error')
        .toList();
    if (errors.isNotEmpty) {
      throw HarnessError('error widget on screen', errors.first.toJson());
    }
    final _Node node = _find(<String, dynamic>{...c, 'exact': true});
    bool owned = identical(node.element, original);
    node.element.visitAncestorElements((Element ancestor) {
      if (identical(ancestor, original)) owned = true;
      return !owned;
    });
    if (!owned) {
      throw HarnessError('presentation target has another owner');
    }
    final RenderObject? boundary = presentationVisibilityBoundary(original);
    bool inside = false;
    for (
      RenderObject? object = node.element.renderObject;
      object != null;
      object = object.parent
    ) {
      if (!object.attached ||
          object is RenderOffstage && object.offstage ||
          object is RenderOpacity && object.opacity <= 0 ||
          object is RenderAnimatedOpacity && object.opacity.value <= 0) {
        throw HarnessError('presentation target is hidden', node.toJson());
      }
      if (identical(object, boundary)) inside = true;
    }
    final bool visible = inside && boundary != null
        ? _reachableRender(boundary, node.center)
        : node.key == 'harness_presentation_banner' &&
              _reachable(node, node.center);
    if (!visible) {
      throw HarnessError('presentation target is covered', node.toJson());
    }
    return <String, Object?>{
      'asserted': true,
      'presentationOnly': true,
      'actualCapture': false,
      'target': node.toJson(),
    };
  }

  Map<String, Object?> _assert(Map<String, dynamic> c) {
    if (c['ref'] != null || c['at'] != null || c['gone'] == true) {
      throw HarnessError('assert needs a stable positive selector');
    }
    final List<_Node> errors = _snapshot()
        .where((_Node n) => n.kind == 'error')
        .toList();
    if (errors.isNotEmpty) {
      throw HarnessError('error widget on screen', errors.first.toJson());
    }
    final _Node node = _find(<String, dynamic>{...c, 'exact': true});
    if (!_reachable(node, node.center)) {
      throw HarnessError('assert target is covered', node.toJson());
    }
    return <String, Object?>{'asserted': true, 'target': node.toJson()};
  }

  HarnessThemeControl _themeControl() {
    final SharedPrefsService? prefs = app.sharedPrefsService;
    if (prefs == null) throw HarnessError('theme preferences are not ready');
    return HarnessThemeControl(
      context: () {
        final BuildContext? context = app.globalNavigatorKey.currentContext;
        if (context == null) throw HarnessError('the app theme is not ready');
        return context;
      },
      readPreference: () => prefs.get(kThemeModeKey),
      savePreference: (Object? value) => prefs.put(kThemeModeKey, value),
      settle: () async {
        await _frame();
        await _settle();
      },
    );
  }

  Future<Map<String, Object?>> _theme(Map<String, dynamic> c) async {
    if (c['mode'] != null || c.containsKey('restore')) {
      _requireCaptureFrameIdle();
    }
    final HarnessThemeControl control = _themeControl();
    if (c['restore'] is Map<String, dynamic>) {
      return control.restore(c['restore'] as Map<String, dynamic>);
    }
    if (c['mode'] == null) return control.snapshot();
    return control.change(c['mode'] as String);
  }

  Future<Map<String, Object?>> _shot(Map<String, dynamic> c) async {
    _requireCaptureFrameIdle();
    if (c['expect'] != null) {
      try {
        return await _captureFrames.capture<Map<String, Object?>>(
          () => _readShot(c),
        );
      } on CaptureFrameRefused {
        throw HarnessError('the original capture frame is unavailable');
      }
    }
    await _frame();
    _requireCaptureFrameIdle();
    return _readShot(c);
  }

  void _requireCaptureFrameIdle() {
    try {
      _captureFrames.requireIdle();
    } on CaptureFrameRefused {
      throw HarnessError('the original capture frame is unavailable');
    }
  }

  Future<Map<String, Object?>> _readShot(Map<String, dynamic> c) async {
    final RenderView view = _view;
    final ClientMetrics metrics = _clientMetrics();
    final bool guarded = c['expect'] != null;
    String? theme;
    if (guarded) {
      final Size requested = Size(
        (c['width'] as num).toDouble(),
        (c['height'] as num).toDouble(),
      );
      if (!metrics.matches(requested)) {
        throw HarnessError(
          'capture client dimensions differ',
          <String, Object?>{
            'requestedClient': <double>[requested.width, requested.height],
            ...metrics.toJson(),
          },
        );
      }
      if (await windowManager.isMinimized()) {
        throw HarnessError('a minimized window cannot be captured');
      }
      final Map<String, Object?> observed = _themeControl().snapshot();
      theme = c['theme'] as String;
      if (observed['mode'] != theme || observed['brightness'] != theme) {
        throw HarnessError('capture theme differs', observed);
      }
      _assert(Map<String, dynamic>.from(c['expect'] as Map<Object?, Object?>));
    }
    final Layer? layer = view.layer;
    if (layer is! OffsetLayer) {
      throw HarnessError('the view has no image layer');
    }
    final ui.Image image = await captureLogicalView(view, layer);
    try {
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) throw HarnessError('the engine returned no image');
      if (guarded &&
          (image.width != c['width'] || image.height != c['height'])) {
        throw HarnessError('captured PNG dimensions differ', <String, int>{
          'width': image.width,
          'height': image.height,
        });
      }
      // A resize or automatic route change during encoding invalidates this
      // frame too. Never label it with the state that preceded capture.
      if (guarded) {
        final ClientMetrics after = _clientMetrics();
        final Map<String, Object?> observed = _themeControl().snapshot();
        if (!after.matches(metrics.logicalSize) ||
            after.physicalSize != metrics.physicalSize ||
            after.devicePixelRatio != metrics.devicePixelRatio ||
            observed['brightness'] != theme ||
            observed['mode'] != theme) {
          throw HarnessError('capture state changed while encoding');
        }
        _assert(
          Map<String, dynamic>.from(c['expect'] as Map<Object?, Object?>),
        );
      }
      return <String, Object?>{
        'width': image.width,
        'height': image.height,
        'scale': 1,
        ...metrics.toJson(),
        if (guarded) 'theme': theme,
        if (guarded) 'asserted': true,
        'png': base64Encode(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        ),
      };
    } finally {
      image.dispose();
    }
  }

  void _hookLogs() {
    Logger.root.onRecord.listen((LogRecord r) {
      _log(r.level.name, r.loggerName, r.message, r.error, r.stackTrace);
    });
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      _log('FLUTTER', d.library ?? '', d.exceptionAsString(), null, d.stack);
      previous?.call(d);
    };
  }

  void _log(
    String level,
    String logger,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    _logs.add(<String, Object?>{
      'seq': ++_logSeq,
      'time': DateTime.now().toIso8601String(),
      'level': level,
      'logger': logger,
      'message': message,
      if (error != null) 'error': error.toString(),
      if (stack != null)
        'stack': stack.toString().split('\n').take(12).join('\n'),
    });
    if (_logs.length > 1000) _logs.removeRange(0, _logs.length - 1000);
  }

  // ------------------------------------------------------------------ stalls

  final Stopwatch _stallClock = Stopwatch();
  Duration _stallLast = Duration.zero;
  final List<Map<String, Object?>> _stalls = <Map<String, Object?>>[];

  /// Records each time the UI isolate ran nothing for longer than a frame
  /// and a half ('loop'), and each frame whose build or raster took longer
  /// than one ('build', 'raster').
  ///
  /// A timer is held up by exactly what holds up a frame, and unlike a frame
  /// it is due whether or not anything is animating, so a freeze shows here
  /// even on a still page. The frame timings add what a timer cannot see:
  /// the raster thread, where a large image or a first-use shader costs.
  void _hookStalls() {
    void record(String kind, int ms) {
      _stalls.add(<String, Object?>{
        'time': DateTime.now().toIso8601String(),
        'kind': kind,
        'ms': ms,
      });
      if (_stalls.length > 2000) _stalls.removeRange(0, _stalls.length - 2000);
    }

    _stallClock.start();
    Timer.periodic(const Duration(milliseconds: 8), (_) {
      final Duration now = _stallClock.elapsed;
      final Duration gap = now - _stallLast;
      _stallLast = now;
      if (gap > const Duration(milliseconds: 24)) {
        record('loop', gap.inMilliseconds);
      }
    });
    SchedulerBinding.instance.addTimingsCallback((List<ui.FrameTiming> ts) {
      for (final ui.FrameTiming t in ts) {
        if (t.buildDuration > const Duration(milliseconds: 16)) {
          record('build', t.buildDuration.inMilliseconds);
        }
        if (t.rasterDuration > const Duration(milliseconds: 16)) {
          record('raster', t.rasterDuration.inMilliseconds);
        }
      }
    });
  }

  Map<String, Object?> _stallsCmd(Map<String, dynamic> c) {
    final int min = c['min'] as int? ?? 0;
    final List<Map<String, Object?>> out = <Map<String, Object?>>[
      for (final Map<String, Object?> s in _stalls)
        if ((s['ms']! as int) >= min) s,
    ];
    if (c['reset'] == true) _stalls.clear();
    return <String, Object?>{
      'stalls': out,
      'longestMs': out.fold<int>(
        0,
        (int m, Map<String, Object?> s) =>
            (s['ms']! as int) > m ? s['ms']! as int : m,
      ),
    };
  }

  Map<String, Object?> _logsCmd(Map<String, dynamic> c) {
    final int since = c['since'] as int? ?? 0;
    final int limit = c['limit'] as int? ?? 50;
    final Set<String>? levels = (c['levels'] as List<dynamic>?)
        ?.map((dynamic l) => l.toString().toUpperCase())
        .toSet();
    final List<Map<String, Object?>> hits = <Map<String, Object?>>[
      for (final Map<String, Object?> l in _logs)
        if ((l['seq']! as int) > since &&
            (levels == null || levels.contains(l['level'])))
          l,
    ];
    return <String, Object?>{
      'seq': _logSeq,
      'logs': hits.length > limit ? hits.sublist(hits.length - limit) : hits,
    };
  }

  Future<Map<String, Object?>> _clipboard(Map<String, dynamic> c) async {
    if (c['value'] is String) {
      await Clipboard.setData(ClipboardData(text: c['value'] as String));
    }
    final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
    return <String, Object?>{'text': d?.text};
  }

  Future<Map<String, Object?>> _window(Map<String, dynamic> c) async {
    final Object? original = c['restoreState'];
    final EntryCaptionObserver? caption = _entryCaption;
    if (caption != null) {
      try {
        if (original is Map<String, dynamic> && c.length == 2) {
          caption.requireGeometryRestore();
          return await _restoreWindow(original);
        }
        if (c.length == 2 && c['do'] == 'restore') {
          return await caption.ordinaryRestore(windowManager.restore);
        }
        if (original != null ||
            c['do'] != null ||
            c['width'] != null ||
            c['height'] != null) {
          throw const CaptionRefused('caption-restore-refused');
        }
      } on Object catch (error) {
        caption.hold(error);
        throw HarnessError(caption.publicFailureCode);
      }
    }
    if (original is Map<String, dynamic>) {
      return _restoreWindow(original);
    }
    final bool resize = c['width'] != null || c['height'] != null;
    if (resize && (c['width'] is! num || c['height'] is! num)) {
      throw HarnessError('window needs both client width and height');
    }
    if (resize) {
      final num width = c['width'] as num;
      final num height = c['height'] as num;
      if (!width.isFinite ||
          !height.isFinite ||
          width <= 0 ||
          height <= 0 ||
          width > 16384 ||
          height > 16384) {
        throw HarnessError(
          'client dimensions must be positive and at most 16384',
        );
      }
    }
    final String? action = c['do'] as String?;
    if (resize && (action == 'minimize' || action == 'maximize')) {
      throw HarnessError('client sizing needs a restored window');
    }
    switch (action) {
      case 'show':
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
      case 'minimize':
        await windowManager.minimize();
      case 'maximize':
        await windowManager.maximize();
      case 'restore':
        await windowManager.restore();
      case null:
        break;
      default:
        throw HarnessError('unknown window action $action');
    }
    ClientResizeResult? result;
    if (resize) {
      if (await windowManager.isMaximized() ||
          await windowManager.isMinimized()) {
        await windowManager.restore();
        await _settle();
      }
      try {
        result = await resizeClientArea(
          requested: Size(
            (c['width'] as num).toDouble(),
            (c['height'] as num).toDouble(),
          ),
          readMetrics: _clientMetrics,
          readOuter: windowManager.getSize,
          setOuter: windowManager.setSize,
          settle: () async {
            await _frame();
            await _settle();
          },
        );
      } on ClientResizeError catch (e) {
        throw HarnessError(e.toString(), e.result.toJson());
      }
    }
    final Map<String, Object?> observed = await _windowSnapshot();
    if (result != null && !_clientMetrics().matches(result.requested)) {
      throw HarnessError(
        'client dimensions changed before reporting',
        <String, Object?>{
          ...result.toJson(),
          ...observed,
          'clientMatched': false,
        },
      );
    }
    return <String, Object?>{
      if (result != null) ...result.toJson(),
      ...observed,
    };
  }

  Future<Map<String, Object?>> _windowSnapshot() async {
    final Size size = await windowManager.getSize();
    final Offset pos = await windowManager.getPosition();
    return <String, Object?>{
      'window': <double>[pos.dx, pos.dy, size.width, size.height],
      ..._clientMetrics().toJson(),
      'minimized': await windowManager.isMinimized(),
      'maximized': await windowManager.isMaximized(),
    };
  }

  Future<Map<String, Object?>> _restoreWindow(
    Map<String, dynamic> state,
  ) async {
    final Object? raw = state['window'];
    if (raw is! List ||
        raw.length != 4 ||
        raw.any((dynamic n) => n is! num || !n.isFinite) ||
        state['minimized'] is! bool ||
        state['maximized'] is! bool) {
      throw HarnessError('invalid original window geometry');
    }
    final List<double> values = raw
        .map((dynamic n) => (n as num).toDouble())
        .toList();
    if (values[2] <= 0 || values[3] <= 0) {
      throw HarnessError('invalid original window size');
    }
    await windowManager.restore();
    await windowManager.setSize(Size(values[2], values[3]));
    await windowManager.setPosition(Offset(values[0], values[1]));
    if (state['maximized'] == true) await windowManager.maximize();
    if (state['minimized'] == true) await windowManager.minimize();
    await _settle();
    final Map<String, Object?> observed = await _windowSnapshot();
    if (observed['maximized'] != state['maximized'] ||
        observed['minimized'] != state['minimized']) {
      throw HarnessError('original window mode was not restored', observed);
    }
    if (state['maximized'] == false && state['minimized'] == false) {
      final List<double> actual = observed['window']! as List<double>;
      for (int i = 0; i < values.length; i++) {
        if ((actual[i] - values[i]).abs() >= 0.01) {
          throw HarnessError(
            'original window geometry was not restored',
            observed,
          );
        }
      }
    }
    return <String, Object?>{...observed, 'restored': true};
  }
}
