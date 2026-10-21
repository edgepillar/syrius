// The in-app half of the harness: a loopback HTTP server that reads the live
// widget tree and drives it with the same pointer and text-input paths a
// person's mouse and keyboard take. It is linked only into the harness
// entrypoint (harness/app/main.dart), never into lib/main.dart.

// The agent reads framework internals on purpose.
// ignore_for_file: invalid_use_of_protected_member, avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

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
    this.key,
    this.inText = false,
    this.blocked = false,
    this.path = const <String>[],
  });

  final Rect clip;
  final _Node? tappable;
  final InputDecoration? decoration;
  final String? tip;
  final String? key;
  final bool inText;
  final bool blocked;
  final List<String> path;

  _Ctx copy({
    Rect? clip,
    _Node? tappable,
    InputDecoration? decoration,
    String? tip,
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

class HarnessAgent {
  HarnessAgent._();

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

  static HarnessAgent get instance => _instance;

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
        } catch (e, st) {
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
    } catch (e, st) {
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
    switch (c['cmd'] as String? ?? 'ping') {
      case 'ping':
        return <String, Object?>{'pid': pid, 'booted': booted};
      case 'state':
        return _state();
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
      case 'shot':
        return _shot();
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

  Map<String, Object?> _state() {
    String? route;
    app.globalNavigatorKey.currentState?.popUntil((Route<dynamic> r) {
      route = r.settings.name ?? r.runtimeType.toString();
      return true;
    });
    final Size size = _viewSize();
    return <String, Object?>{
      'booted': booted,
      'route': route,
      'tab': kCurrentPage?.name,
      'tabs': <String>[for (final t in kTabs) t.name],
      'node': kCurrentNode,
      'chainId': kNodeChainId,
      'ws': app.zenon?.wsClient.status().name,
      'embeddedNode': kEmbeddedNodeRunning,
      'address': kSelectedAddress,
      'addresses': kDefaultAddressList,
      'walletPath': kWalletPath,
      'walletUnlocked': kWalletFile != null,
      'walletInitCompleted': kWalletInitCompleted,
      'size': <int>[size.width.round(), size.height.round()],
      'appData': Platform.environment['AppData'],
    };
  }

  Size _viewSize() => WidgetsBinding.instance.renderViews.first.size;

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
      return MatrixUtils.transformRect(
        ro.getTransformTo(null),
        Offset.zero & ro.size,
      );
    } catch (_) {
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
      } catch (_) {}
    }
    if (n.blocked) return;

    if (w is ErrorWidget) {
      final Rect? r = _rectOf(e);
      if (r != null) {
        out.add(
          _Node('error', type, e, r, n.path)..parts.add(w.message),
        );
      }
      return;
    }

    final Key? key = w.key;
    if (key is ValueKey<String>) n = n.copy(key: key.value);
    if (w is Tooltip && w.message != null) {
      // Above a button the tip is carried down to it; inside one (IconButton
      // builds its own) it is handed up.
      final _Node? t = n.tappable;
      if (t != null && t.foldable) {
        t.extra.putIfAbsent('tip', () => w.message);
      } else {
        n = n.copy(tip: w.message);
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
      } catch (_) {}
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
  }) async {
    await _moveTo(p);
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
    _send(
      PointerUpEvent(
        pointer: id,
        position: p,
        kind: PointerDeviceKind.mouse,
        device: _device,
      ),
    );
  }

  Future<Map<String, Object?>> _tap(Map<String, dynamic> c) async {
    final ({Offset point, _Node? node}) t = _target(c);
    final _Node? n = t.node;
    if (n != null && c['force'] != true) {
      if (!n.enabled) throw HarnessError('disabled', n.toJson());
      if (!_reachable(n, t.point)) {
        throw HarnessError('covered by something else', n.toJson());
      }
    }
    if (c['right'] == true) {
      await _click(t.point, buttons: kSecondaryButton);
    } else if (c['long'] == true) {
      await _click(t.point, holdMs: 700);
    } else {
      await _click(t.point);
      if (c['double'] == true) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await _click(t.point);
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
      await ServicesBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
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
        buttons: kPrimaryButton,
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
          buttons: kPrimaryButton,
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

  Future<Map<String, Object?>> _type(Map<String, dynamic> c) async {
    final String text = c['value'] as String? ?? '';
    EditableTextState? state;
    _Node? node;
    if (c['at'] != null || _hasSelector(c)) {
      node = _find(
        c,
        kinds: const <String>['field'],
        only: true,
      );
      if (!node.enabled) throw HarnessError('read-only field', node.toJson());
      if (!_reachable(node, node.center)) {
        throw HarnessError('covered by something else', node.toJson());
      }
      // Click into it first, as a person would: focus listeners fire.
      await _click(node.center);
      await _frame();
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

  static final Map<String, (LogicalKeyboardKey, PhysicalKeyboardKey)> _keys =
      <String, (LogicalKeyboardKey, PhysicalKeyboardKey)>{
        'enter': (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
        'tab': (LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
        'escape': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
        'space': (LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
        'backspace': (
          LogicalKeyboardKey.backspace,
          PhysicalKeyboardKey.backspace,
        ),
        'delete': (LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete),
        'up': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
        'down': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
        'left': (LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft),
        'right': (
          LogicalKeyboardKey.arrowRight,
          PhysicalKeyboardKey.arrowRight,
        ),
        'home': (LogicalKeyboardKey.home, PhysicalKeyboardKey.home),
        'end': (LogicalKeyboardKey.end, PhysicalKeyboardKey.end),
        'pageup': (LogicalKeyboardKey.pageUp, PhysicalKeyboardKey.pageUp),
        'pagedown': (LogicalKeyboardKey.pageDown, PhysicalKeyboardKey.pageDown),
        'shift': (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft),
        'ctrl': (
          LogicalKeyboardKey.controlLeft,
          PhysicalKeyboardKey.controlLeft,
        ),
        'alt': (LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft),
        'a': (LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA),
        'c': (LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC),
        'v': (LogicalKeyboardKey.keyV, PhysicalKeyboardKey.keyV),
        'x': (LogicalKeyboardKey.keyX, PhysicalKeyboardKey.keyX),
        'z': (LogicalKeyboardKey.keyZ, PhysicalKeyboardKey.keyZ),
      };

  bool _dispatchKey(KeyEvent e) {
    HardwareKeyboard.instance.handleKeyEvent(e);
    final KeyMessageHandler? h =
        ServicesBinding.instance.keyEventManager.keyMessageHandler;
    return h?.call(KeyMessage(<KeyEvent>[e], null)) ?? false;
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

  Future<Map<String, Object?>> _shot() async {
    await _frame();
    final RenderView view = WidgetsBinding.instance.renderViews.first;
    final OffsetLayer layer = view.layer! as OffsetLayer;
    final ui.Image image = await layer.toImage(view.paintBounds);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final int w = image.width;
    final int h = image.height;
    image.dispose();
    if (png == null) throw HarnessError('the engine returned no image');
    return <String, Object?>{
      'width': w,
      'height': h,
      'scale': view.flutterView.devicePixelRatio,
      'png': base64Encode(png.buffer.asUint8List()),
    };
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
    if (c['width'] != null && c['height'] != null) {
      await windowManager.setSize(
        Size((c['width'] as num).toDouble(), (c['height'] as num).toDouble()),
      );
    }
    if (c['x'] != null && c['y'] != null) {
      await windowManager.setPosition(
        Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()),
      );
    }
    switch (c['do'] as String?) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'minimize':
        await windowManager.minimize();
      case 'maximize':
        await windowManager.maximize();
      case 'restore':
        await windowManager.restore();
    }
    await _settle();
    final Size size = await windowManager.getSize();
    final Offset pos = await windowManager.getPosition();
    return <String, Object?>{
      'window': <int>[
        pos.dx.round(),
        pos.dy.round(),
        size.width.round(),
        size.height.round(),
      ],
      'minimized': await windowManager.isMinimized(),
    };
  }
}
