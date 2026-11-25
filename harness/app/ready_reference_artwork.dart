import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart'
    show ClipPathLayer, ContainerLayer, FollowerLayer, Layer, MatrixUtils,
        OffsetLayer, PictureLayer, RenderBox, RenderEditable, RenderObject,
        RenderPhysicalShape, RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
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
    refusal: (_) => const ReadyReferenceArtworkRefused(),
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

/// A confirmed registration whose original art could not be sampled.
class PillarReferenceArtworkRefused implements Exception {
  /// Reports only the finite failure stage.
  const PillarReferenceArtworkRefused(this.stage);

  /// The phase at which the original art became unavailable.
  final ReferenceArtworkFailureStage stage;
}

const Rect _pillarHeaderMark = Rect.fromLTWH(84, 36, 2, 24);

T? _pillarPaintTarget<T extends RenderBox>(Element? root, String key) {
  if (root == null) return null;
  T? target;
  int visited = 0;
  void visit(Element element) {
    if (++visited > 16384) throw StateError('Pane observation limit');
    if (element.widget.key == ValueKey<String>(key)) {
      final RenderObject? render = element.findRenderObject();
      if (target != null || render is! T) {
        throw StateError('Unexpected Pillar paint target');
      }
      target = render;
      return;
    }
    element.debugVisitOnstageChildren(visit);
  }

  visit(root);
  return target;
}

Rect? _localPillarMark(RenderBox? box) {
  if (box == null || !box.attached || !box.hasSize) return null;
  final Offset origin = box.localToGlobal(Offset.zero);
  if (!origin.isFinite ||
      origin != Offset(origin.dx.roundToDouble(), origin.dy.roundToDouble()) ||
      box.localToGlobal(const Offset(1, 0)) != origin + const Offset(1, 0) ||
      box.localToGlobal(const Offset(0, 1)) != origin + const Offset(0, 1)) {
    return null;
  }
  final Rect mark = _pillarHeaderMark.shift(-origin);
  return mark.left < 0 ||
          mark.top < 0 ||
          mark.right > box.size.width ||
          mark.bottom > box.size.height
      ? null
      : mark;
}

Future<String> _readPillarMark(ui.Image image, Rect mark) async {
  final ByteData? rgba = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (rgba == null || image.colorSpace != ui.ColorSpace.sRGB) {
    return 'unavailable';
  }
  final int first = rgba.getUint32(
    (mark.top.toInt() * image.width + mark.left.toInt()) * 4,
  );
  if (first != 0x00D557FF && first != 0x168A35FF) return 'absent';
  for (int y = mark.top.toInt(); y < mark.bottom.toInt(); y++) {
    for (int x = mark.left.toInt(); x < mark.right.toInt(); x++) {
      if (rgba.getUint32((y * image.width + x) * 4) != first) return 'absent';
    }
  }
  return 'present';
}

/// Checks whether the observed mark is entirely painted by the pane header.
Future<String> observePillarHeaderLayerMark(Element? root) async {
  ui.Image? image;
  try {
    final RenderRepaintBoundary? header =
        _pillarPaintTarget<RenderRepaintBoundary>(root, 'pillar_create_header');
    final Rect? mark = _localPillarMark(header);
    if (mark == null) return 'unavailable';
    image = await header!.toImage();
    return await _readPillarMark(image, mark);
  } on Object {
    return 'unavailable';
  } finally {
    image?.dispose();
  }
}

/// Reads only the 48 pixels of the mark from the pane's existing content clip.
Future<String> observePillarPaneClipMark(
  Element? root,
  Layer? Function(RenderPhysicalShape) paintedLayer,
) async {
  ui.Scene? scene;
  ui.Image? image;
  try {
    final RenderPhysicalShape? pane =
        _pillarPaintTarget<RenderPhysicalShape>(root, 'pillar_create_pane');
    final Rect? mark = _localPillarMark(pane);
    if (mark == null) return 'unavailable';
    final Layer? layer = paintedLayer(pane!);
    if (layer is! ClipPathLayer) return 'unavailable';
    final Rect? clip = layer.clipPath?.getBounds();
    if (clip == null || !clip.isFinite || clip.size != pane.size) {
      return 'unavailable';
    }

    // PhysicalShape offsets this path and its clipped children together.
    final Offset corner = mark.topLeft + clip.topLeft;
    final ui.SceneBuilder builder = ui.SceneBuilder()
      ..pushOffset(-corner.dx, -corner.dy);
    scene = layer.buildScene(builder);
    image = await scene.toImage(mark.width.toInt(), mark.height.toInt());
    return await _readPillarMark(image, Offset.zero & mark.size);
  } on Object {
    return 'unavailable';
  } finally {
    image?.dispose();
    scene?.dispose();
  }
}

/// Checks the nearest existing repaint boundary enclosing the Pillar pane.
/// With [outsideNearest], it searches up to four more enclosing boundaries.
Future<String> observePillarEnclosingPaintMark(
  Element? root,
  Layer? Function(RenderBox) paintedLayer, {
  bool outsideNearest = false,
}) async {
  try {
    final RenderRepaintBoundary? ancestor = _enclosingPillarBoundary(root);
    if (ancestor == null) return 'unavailable';
    if (!outsideNearest) {
      return await _readPillarBoundary(ancestor, paintedLayer);
    }

    final List<RenderBox> boundaries = <RenderBox>[];
    for (RenderObject? next = ancestor.parent;
        next != null;
        next = next.parent) {
      if (next is! RenderBox || !next.isRepaintBoundary) continue;
      if (boundaries.length == 4) return 'unavailable';
      boundaries.add(next);
    }
    final List<String> results = await Future.wait(<Future<String>>[
      for (final RenderBox boundary in boundaries)
        _readPillarBoundary(boundary, paintedLayer),
    ]);
    if (results.contains('present')) return 'present';
    return results.isNotEmpty && !results.contains('unavailable')
        ? 'absent'
        : 'unavailable';
  } on Object {
    return 'unavailable';
  }
}

RenderRepaintBoundary? _enclosingPillarBoundary(Element? root) {
  final RenderPhysicalShape? pane =
      _pillarPaintTarget<RenderPhysicalShape>(root, 'pillar_create_pane');
  return _nextPillarBoundary(pane);
}

RenderRepaintBoundary? _nextPillarBoundary(RenderObject? object) {
  for (RenderObject? parent = object?.parent;
      parent != null;
      parent = parent.parent) {
    if (parent is RenderRepaintBoundary) return parent;
  }
  return null;
}

Set<Layer> _pillarEditorPaintLayers(
  Element? root,
  Layer? Function(RenderBox) paintedLayer,
) {
  final Set<Layer> layers = Set<Layer>.identity();
  int visited = 0;
  void visit(Element element) {
    if (++visited > 16384) throw StateError('Editor observation limit');
    if (element case RenderObjectElement(
        renderObject: final RenderEditable editor,
      ) when editor.attached) {
      editor.visitChildren((RenderObject child) {
        if (child is RenderBox && child.attached && child.isRepaintBoundary) {
          final Layer? layer = paintedLayer(child);
          if (layer != null) layers.add(layer);
        }
      });
    }
    // A retained editor can have an old layer even when it is not onstage.
    // Only layers that are also traversed in the captured scene can match.
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  return layers;
}

/// Searches translated pictures for the exact mark before clipping or opacity.
/// Call immediately after building the original scene.
Future<String> observePillarRecordedMark(
  Element? elements,
  ContainerLayer scene,
  Layer? Function(RenderBox) paintedLayer, {
  required double devicePixelRatio,
}) async {
  try {
    final RenderRepaintBoundary? enclosing = _enclosingPillarBoundary(elements);
    final Layer? pane = enclosing == null ? null : paintedLayer(enclosing);
    if (pane == null || !devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      return 'unavailable';
    }
    final RenderRepaintBoundary? page =
        _pillarPaintTarget<RenderRepaintBoundary>(elements, 'shell_page_paint');
    final Layer? pageLayer = page == null ? null : paintedLayer(page);
    // MaterialPageRoute puts its transitions around a second repaint
    // boundary. If the page is the next boundary, there is no separate one.
    final RenderRepaintBoundary? transition = _nextPillarBoundary(enclosing);
    final Layer? transitionLayer = transition == null ||
            identical(transition, page)
        ? null
        : paintedLayer(transition);
    final Set<Layer> editorLayers =
        _pillarEditorPaintLayers(elements, paintedLayer);
    final double pixelScale = 1 / devicePixelRatio;
    final List<(Layer, Matrix4, String)> pending = <(Layer, Matrix4, String)>[
      (scene, Matrix4.diagonal3Values(pixelScale, pixelScale, 1), 'outside'),
    ];
    final List<(ui.Picture, Rect, String, bool)> crops =
        <(ui.Picture, Rect, String, bool)>[];
    bool pageIsInScene = false;
    bool paneIsInScene = false;
    int visited = 0;
    while (pending.isNotEmpty) {
      if (++visited > 1024) return 'unavailable';
      final (Layer layer, Matrix4 transform, String parentScope) =
          pending.removeLast();
      String scope = parentScope;
      if (identical(layer, pageLayer)) {
        pageIsInScene = true;
        scope = 'in_shell_page';
      }
      if (identical(layer, transitionLayer)) {
        scope = switch (scope) {
          'in_shell_page' => 'in_pane_transition',
          'in_shell_follower' => 'in_pane_transition_follower',
          _ => scope,
        };
      }
      if (layer is FollowerLayer && layer.link.leader != null) {
        scope = switch (scope) {
          'in_shell_page' => 'in_shell_follower',
          'in_pane_transition' => 'in_pane_transition_follower',
          _ => scope,
        };
      }
      if (identical(layer, pane)) {
        paneIsInScene = true;
        scope = 'inside';
      }
      if (editorLayers.contains(layer)) scope = 'in_editor_paint';
      if (layer is ContainerLayer) {
        for (Layer? child = layer.firstChild;
            child != null;
            child = child.nextSibling) {
          final Matrix4 childTransform = Matrix4.copy(transform);
          layer.applyTransform(child, childTransform);
          pending.add((child, childTransform, scope));
          if (pending.length > 1024) return 'unavailable';
        }
      }
      if (layer is! PictureLayer || layer.picture == null) continue;
      final Offset? origin = MatrixUtils.getAsTranslation(transform);
      if (origin == null ||
          !origin.isFinite ||
          origin.dx != origin.dx.roundToDouble() ||
          origin.dy != origin.dy.roundToDouble()) {
        continue;
      }
      final Rect mark = _pillarHeaderMark.shift(-origin);
      if (layer.canvasBounds.overlaps(mark)) {
        if (crops.length == 32) return 'unavailable';
        // The stack visits later-painted siblings first.
        crops.add((layer.picture!, mark, scope, paneIsInScene));
      }
    }
    if (crops.isEmpty) return 'unavailable';
    final List<String> results = await Future.wait(<Future<String>>[
      for (final (ui.Picture picture, Rect mark, _, _) in crops)
        _readRecordedPillarMark(picture, mark),
    ]);
    if (results.contains('unavailable')) return 'unavailable';
    final List<int> hits = <int>[
      for (final (int index, String mark) in results.indexed)
        if (mark == 'present') index,
    ];
    if (hits.length == 1) {
      final (_, _, String scope, bool paneVisited) = crops[hits.single];
      if (scope == 'in_shell_page' && paneIsInScene) {
        return paneVisited ? 'below_pane_in_shell' : 'above_pane_in_shell';
      }
      return scope == 'outside' && pageIsInScene ? 'outside_shell_page' : scope;
    }
    return hits.isEmpty ? 'no_picture' : 'multiple_pictures';
  } on Object {
    return 'unavailable';
  }
}

Future<String> _readRecordedPillarMark(ui.Picture picture, Rect mark) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..translate(-mark.left, -mark.top)
    ..drawPicture(picture);
  final ui.Picture crop = recorder.endRecording();
  ui.Image? image;
  try {
    image = await crop.toImage(mark.width.toInt(), mark.height.toInt());
    return await _readPillarMark(image, Offset.zero & mark.size);
  } on Object {
    return 'unavailable';
  } finally {
    image?.dispose();
    crop.dispose();
  }
}

Future<String> _readPillarBoundary(
  RenderBox boundary,
  Layer? Function(RenderBox) paintedLayer,
) async {
  final Rect? mark = _localPillarMark(boundary);
  final Layer? layer = paintedLayer(boundary);
  if (mark == null || layer is! OffsetLayer) return 'unavailable';
  ui.Image? image;
  try {
    image = await layer.toImage(mark);
    return await _readPillarMark(image, Offset.zero & mark.size);
  } on Object {
    return 'unavailable';
  } finally {
    image?.dispose();
  }
}

/// Observes caret geometry at the known Pillar receipt header mark.
///
/// Returns a finite status without editor identity, text or selection.
String observePillarHeaderCaret(Element? root, EditableTextState? focused) {
  if (root == null) return 'unavailable';

  String status(EditableTextState editor) {
    final RenderEditable render = editor.renderEditable;
    if (!render.attached || !render.hasSize) return 'unavailable';
    final TextSelection? selection = render.selection;
    if (!render.showCursor.value ||
        (render.cursorColor?.a ?? 0) == 0 ||
        selection == null ||
        !selection.isValid ||
        !selection.isCollapsed) {
      return 'caret_inactive';
    }
    final Rect caret = MatrixUtils.transformRect(
      render.getTransformTo(null),
      render.getLocalRectForCaret(selection.extent),
    );
    if (!caret.isFinite || caret.isEmpty) return 'unavailable';
    return caret.overlaps(_pillarHeaderMark)
        ? 'caret_overlaps'
        : 'caret_elsewhere';
  }

  try {
    int visited = 0;
    bool overlap = false;
    bool unavailable = false;
    void visit(Element element) {
      if (overlap) return;
      if (++visited > 16384) throw StateError('Caret observation limit');
      if (element case StatefulElement(:final EditableTextState state)
          when !identical(state, focused)) {
        final String observed = status(state);
        overlap = observed == 'caret_overlaps';
        unavailable |= observed == 'unavailable';
      }
      element.debugVisitOnstageChildren(visit);
    }

    visit(root);
    if (overlap) return 'unfocused_caret_overlaps';
    if (unavailable) return 'unavailable';
    return focused == null ? 'no_focused_editor' : status(focused);
  } on Object {
    return 'unavailable';
  }
}

/// Samples the original Pillar player inside one admitted receipt.
class PillarReferenceArtwork {
  /// The owning receipt and its positive registration check are supplied by
  /// the original capture route.
  PillarReferenceArtwork({required this._owner, required this._admitted});

  final Element _owner;
  final bool Function() _admitted;
  bool _readingSample = false;
  late final _ReferenceArtworkCapture _capture = _ReferenceArtworkCapture(
    current: _current,
    sources: _sources,
    requiresReadiness: (_) => true,
    refusal: PillarReferenceArtworkRefused.new,
    settleOverlay: _settleTooltips,
  );

  bool _current() =>
      _owner.mounted &&
      ModalRoute.of(_owner)?.isCurrent == true &&
      TickerMode.valuesOf(_owner).enabled &&
      _admitted();

  /// The natural completion was checked before the original frame was held.
  /// While reading it, the normal receipt assertion still verifies its owner.
  bool isReadingSample(Element owner) =>
      _readingSample && identical(owner, _owner) && _current();

  Future<void> _settleTooltips() async {
    if (!await settleCaptureTooltips(_current)) {
      throw const PillarReferenceArtworkRefused(
        ReferenceArtworkFailureStage.overlay,
      );
    }
  }

  List<ReferenceArtworkSource> _sources() {
    final List<ReferenceArtworkSource> sources = <ReferenceArtworkSource>[];
    int visited = 0;
    void visit(Element element) {
      if (++visited > 16384) {
        throw const PillarReferenceArtworkRefused(
          ReferenceArtworkFailureStage.renderers,
        );
      }
      if (element
          case StatefulElement(state: final ReferenceArtworkSource source)
          when source.referenceArtworkKind ==
              ReferenceArtworkKind.pillarRegistration) {
        sources.add(source);
      }
      element.debugVisitOnstageChildren(visit);
    }

    _owner.debugVisitOnstageChildren(visit);
    if (sources.length != 1) {
      throw const PillarReferenceArtworkRefused(
        ReferenceArtworkFailureStage.renderers,
      );
    }
    return sources;
  }

  /// Restores the same renderer binding after the atomic readback.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) => _capture.capture<T>(
    frames: frames,
    readback: () async {
      if (Tooltip.dismissAllToolTips()) {
        throw const PillarReferenceArtworkRefused(
          ReferenceArtworkFailureStage.overlay,
        );
      }
      _readingSample = true;
      try {
        return await readback();
      } finally {
        _readingSample = false;
      }
    },
  );
}

/// Dismisses hover tooltips and confirms a painted frame while [current].
Future<bool> settleCaptureTooltips(bool Function() current) async {
  const Duration budget = Duration(seconds: 1);
  final Stopwatch elapsed = Stopwatch()..start();
  final WidgetsBinding binding = WidgetsBinding.instance;
  // A native pointer can stay over a tooltip after a scripted tap. A pending
  // hover can also open on the next frame.
  bool clearBeforeFrame = false;
  while (current()) {
    final bool clear = !Tooltip.dismissAllToolTips();
    if (clear && clearBeforeFrame) return true;
    clearBeforeFrame = clear;
    final Duration remaining = budget - elapsed.elapsed;
    if (remaining <= Duration.zero) break;
    // An existing endOfFrame may belong to paint before the dismissal.
    final Completer<void> painted = Completer<void>();
    final int callback = binding.scheduleFrameCallback((Duration _) {
      binding.addPostFrameCallback((Duration _) => painted.complete());
    });
    try {
      await painted.future.timeout(remaining);
    } on TimeoutException {
      return false;
    } finally {
      if (!painted.isCompleted) binding.cancelFrameCallbackWithId(callback);
    }
  }
  return false;
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
    refusal: (_) => const StakingReferenceArtworkRefused(),
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

/// The original Home field could not provide or restore its sampled frame.
class HomeReferenceArtworkRefused implements Exception {
  /// Refuses without retaining original renderer details.
  const HomeReferenceArtworkRefused();
}

/// Samples the Home field without changing the running shader clock.
Future<T> captureHomeReferenceArtwork<T>({
  required Element? root,
  required bool Function() admitted,
  required CaptureFrameGate frames,
  required Future<T> Function() readback,
}) {
  final List<StatefulElement> fields = <StatefulElement>[];
  int visited = 0;
  void visit(Element element) {
    if (++visited > 16384) throw const HomeReferenceArtworkRefused();
    if (element is StatefulElement && element.widget is HeroField &&
        element.state is ReferenceArtworkSource &&
        ModalRoute.of(element)?.isCurrent == true &&
        TickerMode.valuesOf(element).enabled) {
      fields.add(element);
    }
    element.visitChildren(visit);
  }
  if (root != null) visit(root);
  if (fields.length != 1) throw const HomeReferenceArtworkRefused();
  final StatefulElement owner = fields.single;
  final ModalRoute<dynamic>? route = ModalRoute.of(owner);
  final ReferenceArtworkSource source = owner.state as ReferenceArtworkSource;
  return _ReferenceArtworkCapture(
    current: () => admitted() && owner.mounted && route?.isCurrent == true &&
        identical(ModalRoute.of(owner), route) &&
        TickerMode.valuesOf(owner).enabled,
    sources: () => <ReferenceArtworkSource>[source],
    requiresReadiness: (_) => false,
    refusal: (_) => const HomeReferenceArtworkRefused(),
  ).capture<T>(frames: frames, readback: readback);
}

/// The stage at which the original artwork could no longer be sampled.
enum ReferenceArtworkFailureStage {
  /// This capture was already held or active.
  held,

  /// The original visit cannot admit a capture.
  owner,

  /// The original renderers are missing or have changed.
  renderers,

  /// The original assets did not become ready within the preparation budget.
  readiness,

  /// An open tooltip was still present at the resting receipt capture.
  overlay,

  /// A renderer refused to select its authored sample.
  sample,

  /// The selected samples were not observed on the original frame.
  observation,

  /// The original renderers did not restore after sampling.
  restoration,
}

/// The original gallery cannot supply its complete set of artwork frames.
class OriginalsReferenceArtworkRefused implements Exception {
  /// Reports only the capture scope, without retaining an asset error.
  const OriginalsReferenceArtworkRefused(this.stage);

  /// The last operation at which the original capture refused.
  final ReferenceArtworkFailureStage stage;
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
      if (++visited > 16384) {
        throw const OriginalsReferenceArtworkRefused(
          ReferenceArtworkFailureStage.owner,
        );
      }
      if (element is StatefulElement &&
          element.state is State<OriginalsCard> &&
          ModalRoute.of(element)?.isCurrent == true &&
          TickerMode.valuesOf(element).enabled) {
        owners.add(element.state as State<OriginalsCard>);
      }
      element.visitChildren(visit);
    }

    if (root != null) visit(root);
    if (owners.length != 1) {
      throw const OriginalsReferenceArtworkRefused(
        ReferenceArtworkFailureStage.owner,
      );
    }
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
    // The gallery's 56-frame decoder must display frame 23, not just load.
    // All nine original assets share one preparation deadline.
    prepareBudget: const Duration(seconds: 4),
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
      if (++visited > 16384) {
        throw const OriginalsReferenceArtworkRefused(
          ReferenceArtworkFailureStage.renderers,
        );
      }
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
        if (source == null) {
          throw const OriginalsReferenceArtworkRefused(
            ReferenceArtworkFailureStage.renderers,
          );
        }
        sources.add(source);
      }
      element.visitChildren(visit);
    }

    _owner.context.visitChildElements(visit);
    if (sources.length != 9) {
      throw const OriginalsReferenceArtworkRefused(
        ReferenceArtworkFailureStage.renderers,
      );
    }
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
    this._prepareBudget,
    this._settleOverlay,
  });

  final bool Function() _current;
  final List<ReferenceArtworkSource> Function() _sources;
  final bool Function(ReferenceArtworkSource) _requiresReadiness;
  final Exception Function(ReferenceArtworkFailureStage) _refusal;
  final Duration? _prepareBudget;
  final Future<void> Function()? _settleOverlay;
  bool _held = false;
  bool _busy = false;
  CaptureFrameGate? _originalFrames;

  bool get held => _held;

  Never _refuse(ReferenceArtworkFailureStage stage) {
    _held = true;
    throw _refusal(stage);
  }

  /// Both sample and restoration use the same existing native frame gate.
  Future<T> capture<T>({
    required CaptureFrameGate frames,
    required Future<T> Function() readback,
  }) async {
    if (_held || _busy) _refuse(ReferenceArtworkFailureStage.held);
    if (!_current()) _refuse(ReferenceArtworkFailureStage.owner);
    _originalFrames ??= frames;
    if (!identical(_originalFrames, frames)) {
      _refuse(ReferenceArtworkFailureStage.owner);
    }
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
      ReferenceArtworkFailureStage stage =
          ReferenceArtworkFailureStage.readiness;
      try {
        final Duration? budget = _prepareBudget;
        if (budget != null) {
          await Future.wait<Object?>(
            readiness.whereType<Future<Object?>>(),
            eagerError: true,
          ).timeout(budget);
        }
        for (int index = 0; index < sources.length; index++) {
          final Future<Object?>? original = readiness[index];
          if (_requiresReadiness(sources[index]) && original == null) {
            _refuse(stage);
          }
          if (original != null && budget == null) {
            await original.timeout(const Duration(seconds: 1));
          }
          if (!_current() ||
              !identical(sources[index].referenceArtworkGeneration,
                generations[index]) ||
              !identical(sources[index].referenceArtworkReadiness, original)) {
            _refuse(stage);
          }
        }
        final Future<void> Function()? settleOverlay = _settleOverlay;
        if (settleOverlay != null) {
          stage = ReferenceArtworkFailureStage.overlay;
          await settleOverlay();
          if (!_current()) _refuse(stage);
        }
        stage = ReferenceArtworkFailureStage.renderers;
        final List<ReferenceArtworkSource> fresh = _sources();
        if (fresh.length != sources.length) _refuse(stage);
        for (int index = 0; index < sources.length; index++) {
          if (!identical(fresh[index], sources[index])) _refuse(stage);
        }
        stage = ReferenceArtworkFailureStage.sample;
        for (int index = 0; index < sources.length; index++) {
          final ReferenceArtworkSource source = sources[index];
          final ReferenceArtworkFrame? sample =
              source.captureReferenceArtwork();
          if (sample == null) _refuse(stage);
          samples.add(sample);
          if (!_current() || !sample.isCurrent ||
              !identical(sample.owner, source) ||
              !identical(sample.generation, generations[index]) ||
              sample.kind != source.referenceArtworkKind) {
            _refuse(stage);
          }
        }
      } on Object {
        _refuse(stage);
      }
      void requireObserved() {
        if (!_current() || samples.length != sources.length ||
            !samples.every((ReferenceArtworkFrame sample) => sample.observed)) {
          _refuse(ReferenceArtworkFailureStage.observation);
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
          if (!requested) _refuse(ReferenceArtworkFailureStage.restoration);
          await frames.capture<void>(() async {
            if (!_current() ||
                !samples.every((ReferenceArtworkFrame sample) =>
                  sample.restored)) {
              _refuse(ReferenceArtworkFailureStage.restoration);
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
