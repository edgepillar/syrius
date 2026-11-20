import 'dart:async';
import 'dart:ui' show ClipOp;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/launch_film.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/window_frame.dart';

/// Builds the actual authentication owner before the launch's first frame.
typedef StartupAuthBuilder =
    Widget Function(
      BuildContext context,
      StartupStageSession session,
    );

/// Owns one launch film and one authentication subtree across the route change.
///
/// The overlay outlives Splash, while its two keyed subtrees move into the
/// shell in separate frames. A second decoder or authentication state would
/// lose the held frame or permit a password before the handoff finishes.
class StartupStageSession implements Listenable {
  /// Creates the stage without starting initialization or opening a wallet.
  StartupStageSession({
    required this.authBuilder,
    required VoidCallback this._onDone,
    this.asset = LaunchFilm.defaultAsset,
    this.wellAsset = 'assets/images/launch_well.webp',
    this.bundle,
  }) {
    detachedReceipt = EntryCaptureCompletion(_detached.future);
    cleanupReceipt = EntryCaptureCompletion(_cleanup.future);
  }

  /// Constructs the real owner using only its existing startup data.
  final StartupAuthBuilder authBuilder;

  VoidCallback? _onDone;

  /// The original full-window movie.
  final String asset;

  /// The original smaller movie used on later manual replays.
  final String wellAsset;

  /// Allows presentation tests to decode a tiny committed movie only.
  final AssetBundle? bundle;

  /// Drives the same film State before and after the container transform.
  final LaunchFilmController film = LaunchFilmController();

  /// The actual well supplies geometry; no estimated card rectangle is used.
  final GlobalKey wellKey = GlobalKey(debugLabel: 'Startup destination well');

  /// The one film is reparented only after the rectangle reaches that well.
  final GlobalKey filmKey = GlobalKey(debugLabel: 'Startup original film');

  final GlobalKey _authKey = GlobalKey(debugLabel: 'Startup authentication');
  final _StartupChanges _changes = _StartupChanges();
  final ValueNotifier<bool> _authInShell = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _filmInWell = ValueNotifier<bool>(false);
  final Completer<void> _detached = Completer<void>();
  final Completer<void> _cleanup = Completer<void>();

  /// Actual detach and resource results. Closing the session proves neither.
  late final EntryCaptureCompletion detachedReceipt;

  /// The original detach and decoder cleanup result, including failure.
  late final EntryCaptureCompletion cleanupReceipt;
  LaunchFilmCleanup? _originalFilmCleanup;

  /// The original two-frame detach Future.
  Future<void> get detached => _detached.future;

  /// The original resource cleanup Future, without a timeout or replacement.
  Future<void> get cleanup => _cleanup.future;

  /// Captured before removal; a later film can never supply this completion.
  LaunchFilmCleanup? get originalFilmCleanup => _originalFilmCleanup;

  /// Only the card's paint listens each frame; authentication does not rerun.
  final ValueNotifier<double> motion = ValueNotifier<double>(0);

  OverlayEntry? _entry;
  VoidCallback? _releaseLaunchCaption;
  Future<void> Function(String)? _afterUnlock;
  VoidCallback? _afterInit;
  ValueListenable<int>? _replay;
  bool _claimed = false;
  bool _settleRequested = false;
  bool _handoffReferencePending = false;
  bool _waiting = false;
  bool _done = false;
  bool _closed = false;

  /// The shell has assumed cleanup responsibility before Splash leaves.
  bool get claimed => _claimed;

  /// The actual authentication State now lives in the shell's Lock slot.
  bool get authInShell => _authInShell.value;

  /// The original film has reached and entered the actual Lock well.
  bool get filmInWell => _filmInWell.value;

  /// Direct callbacks obey this guard as well as pointer and focus barriers.
  bool get interactive => !_closed && filmInWell;

  /// A closed session never starts or exposes another authentication flow.
  bool get isClosed => _closed;

  /// Manual replay remains owned by the shell after handoff.
  ValueListenable<int>? get replay => _replay;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  /// Adds only this session's entry above the Navigator's route entries.
  void show(BuildContext context) {
    if (_closed || _entry != null) return;
    _releaseLaunchCaption = context
        .findAncestorStateOfType<AppWindowFrameState>()
        ?.holdLaunchCaption();
    _entry = OverlayEntry(
      maintainState: true,
      builder: (_) => _StartupStage(session: this),
    );
    Navigator.of(context, rootNavigator: true).overlay!.insert(_entry!);
  }

  void _restoreCaption() {
    _releaseLaunchCaption?.call();
    _releaseLaunchCaption = null;
  }

  /// Binds the existing shell callbacks without rebuilding another owner.
  bool claim({
    required Future<void> Function(String) afterUnlock,
    required VoidCallback afterInit,
    required ValueListenable<int> replay,
  }) {
    if (_closed || _claimed) return false;
    _claimed = true;
    _afterUnlock = afterUnlock;
    _afterInit = afterInit;
    _replay = replay;
    return true;
  }

  /// Moves the keyed owner in the same frame that removes its overlay slot.
  void moveAuthToShell() {
    if (_closed || !_claimed || authInShell) return;
    _authInShell.value = true;
    _changed();
  }

  /// Called after that owner and its actual well have completed layout.
  void settle() {
    if (_closed || !authInShell || !_done || _settleRequested) return;
    _settleRequested = true;
    _changed();
  }

  /// Samples one authored paint as the original clock crosses its progress.
  /// The isolated observer must request it before the handoff starts.
  bool requestHandoffReferenceFrame() {
    if (_closed || _settleRequested || _handoffReferencePending) return false;
    _handoffReferencePending = true;
    return true;
  }

  /// Holds the last frame while the existing app initialization is pending.
  void wait() {
    if (_closed || _waiting) return;
    _waiting = true;
    _changed();
  }

  /// Rebuilds only the Lock slot when the original owner enters the shell.
  Widget buildShellAuth() => ValueListenableBuilder<bool>(
    valueListenable: _authInShell,
    builder: (_, bool attached, _) =>
        attached ? _auth : const SizedBox.expand(),
  );

  // Keep the owner through film completion and the covered wait. Shell
  // adoption refreshes its replay signal and initialized display data.
  late final Widget _auth = KeyedSubtree(
    key: _authKey,
    child: Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[_authInShell, _filmInWell]),
        builder: (BuildContext context, _) => Focus(
          canRequestFocus: false,
          descendantsAreFocusable: interactive,
          child: IgnorePointer(
            ignoring: !interactive,
            child: ExcludeSemantics(
              excluding: !interactive,
              child: authBuilder(context, this),
            ),
          ),
        ),
      ),
    ),
  );

  /// The held image survives reparenting and becomes the well's replay host.
  Widget buildFilm() => LaunchFilm(
    key: filmKey,
    asset: filmInWell ? wellAsset : asset,
    lastFrameAsset: !filmInWell && asset == LaunchFilm.defaultAsset
        ? LaunchFilm.defaultLastFrameAsset
        : null,
    bundle: bundle,
    controller: film,
    // The full stage crops like the original mockup; the final well keeps
    // the same 640 by 360 frame inside its own clip.
    fit: filmInWell ? BoxFit.contain : BoxFit.cover,
    retainImageLayout: true,
    autoplay: !filmInWell,
    onDone: _filmDone,
  );

  /// Refuses even a retained direct callback before the stage has settled.
  Future<void> unlock(String password) async {
    if (!interactive) return;
    await _afterUnlock?.call(password);
  }

  /// Completes the real owner's existing first-unlock path.
  void initialized() {
    if (interactive) _afterInit?.call();
  }

  void _filmDone() {
    if (_closed || _done) return;
    _done = true;
    final VoidCallback? callback = _onDone;
    _onDone = null;
    _changed();
    callback?.call();
  }

  void _changed() {
    if (_closed) return;
    // The mounted stage listens to this signal. Before it mounts, the
    // overlay builder reads the current session on its first build.
    _changes.changed();
  }

  void _finishHandoff() {
    if (_closed || filmInWell || !authInShell) return;
    _filmInWell.value = true;
    motion.value = 1;
    final OverlayEntry? entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    _changes.changed();
  }

  /// Removes only the owned stage and releases signals after its detach frame.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _restoreCaption();
    _originalFilmCleanup = film.cleanup;
    _onDone = null;
    _afterUnlock = null;
    _afterInit = null;
    final OverlayEntry? entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    // Remove the owned subtree before disposing its attached decoder signal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Overlay removal during a build is applied on the following frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          film.dispose();
          motion.dispose();
          _authInShell.dispose();
          _filmInWell.dispose();
          _changes.dispose();
          if (filmKey.currentContext != null ||
              _authKey.currentContext != null) {
            _detached.completeError(
              StateError('Original startup subtree is still attached'),
            );
          } else {
            _detached.complete();
          }
        } on Object catch (error, stack) {
          if (!_detached.isCompleted) _detached.completeError(error, stack);
          rethrow;
        } finally {
          unawaited(_finishCleanup());
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  Future<void> _finishCleanup() async {
    await detachedReceipt.completion;
    final LaunchFilmCleanup? original = _originalFilmCleanup;
    if (original == null) {
      _cleanup.completeError(StateError('Original startup film unavailable'));
      return;
    }
    await original.completion.completion;
    final Object? error = detachedReceipt.error ?? original.completion.error;
    if (error != null) {
      _cleanup.completeError(
        error,
        detachedReceipt.stackTrace ?? original.completion.stackTrace,
      );
    } else if (film.cleanupOwnerReplaced) {
      _cleanup.completeError(StateError('Original startup film was replaced'));
    } else {
      _cleanup.complete();
    }
  }
}

class _StartupChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}

class _StartupStage extends StatefulWidget {
  const _StartupStage({required this.session});

  final StartupStageSession session;

  @override
  State<_StartupStage> createState() => _StartupStageState();
}

class _StartupStageState extends State<_StartupStage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _bounds = GlobalKey(debugLabel: 'Startup stage bounds');
  final FocusNode _focus = FocusNode(debugLabel: 'Launch skip');
  late final AnimationController _settle = AnimationController(
    vsync: this,
    // The stage has the same clock when platform animation effects are off.
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_tick);
  Rect? _destination;
  Size? _viewport;
  bool _geometryScheduled = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    final StartupStageSession original = widget.session;
    // This overlay is outside the route's focus scope. Autofocus does not
    // replace that scope's focused route, so reserve the first skip receiver.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(widget.session, original) &&
          !original.isClosed &&
          !original._done) {
        _focus.requestFocus();
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (widget.session._settleRequested && !_started) _start();
  }

  Rect? _measureDestination() {
    final RenderObject? target = widget.session.wellKey.currentContext
        ?.findRenderObject();
    final RenderObject? bounds = _bounds.currentContext?.findRenderObject();
    if (target is! RenderBox ||
        bounds is! RenderBox ||
        !target.hasSize ||
        !bounds.hasSize ||
        target.size.isEmpty ||
        bounds.size.isEmpty) {
      return null;
    }
    final AppTokens tokens = AppTokens.of(context);
    final Offset origin = bounds.localToGlobal(Offset.zero);
    final Offset offset = target.localToGlobal(Offset.zero) - origin;
    // The real card rises while the stage settles. Its final well is the
    // measured well with only that owned paint translation removed.
    return (offset & target.size).shift(
      Offset(0, -tokens.launchLockRise * (1 - widget.session.motion.value)),
    );
  }

  void _start() {
    if (!mounted || widget.session.isClosed || _started) return;
    _destination = _measureDestination();
    if (_destination == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
      return;
    }
    final AppTokens tokens = AppTokens.of(context);
    _started = true;
    widget.session._restoreCaption();
    _settle
      ..duration = tokens.launchSettleDuration
      ..forward();
  }

  void _tick() {
    final StartupStageSession session = widget.session;
    if (!mounted || session.isClosed) return;
    final AppTokens tokens = AppTokens.of(context);
    final double progress = tokens.launchSettleCurve.transform(_settle.value);
    const double reference = AppTokens.launchSettleReferenceProgress;
    if (session._handoffReferencePending && progress >= reference) {
      session._handoffReferencePending = false;
      // A missed entire handoff must not postpone the original completion.
      if (_settle.value < 1) {
        session.motion.value = reference;
        return;
      }
    }
    session.motion.value = progress;
    if (_settle.value >= 1) {
      // Interpolation's isDone can be reported on a later tick. The paint
      // and input boundary is the complete 400 ms rectangle, exactly.
      session._finishHandoff();
    }
  }

  void _skip() {
    if (!widget.session.isClosed && !widget.session._done) {
      widget.session.film.skipToEnd();
    }
  }

  Rect _stageRect(Rect full, double progress, AppTokens tokens) {
    final Rect? destination = _destination;
    if (destination == null) return full;

    final LaunchSettleReference reference = tokens.launchSettleReference;
    // Scale the authored checkpoint to this body and respect the real well
    // when the window is narrower or shorter than the reference.
    final double width = (reference.stage.width *
            full.width / reference.body.width)
        .clamp(destination.width.clamp(0.0, full.width), full.width);
    final double height = (reference.stage.height *
            full.height / reference.body.height)
        .clamp(destination.height.clamp(0.0, full.height), full.height);
    final Rect authored = Rect.fromLTWH(
      full.center.dx - width / 2,
      (full.center.dy - height * reference.verticalAnchor)
          .clamp(full.top, full.bottom - height),
      width,
      height,
    );
    if (progress <= reference.progress) {
      return Rect.lerp(full, authored, progress / reference.progress)!;
    }
    return Rect.lerp(
      authored, destination,
      (progress - reference.progress) / (1 - reference.progress),
    )!;
  }

  Widget _buildStage(
    Rect full,
    double progress,
    AppTokens tokens,
    Widget? film,
  ) {
    final LaunchSettleReference reference = tokens.launchSettleReference;
    final bool approaching = progress <= reference.progress;
    final double fraction = approaching
        ? progress / reference.progress
        : (progress - reference.progress) / (1 - reference.progress);
    final double weight = approaching ? fraction : 1 - fraction;
    final Size referenceArtwork = Size(
      reference.artwork.width * full.width / reference.body.width,
      reference.artwork.height * full.height / reference.body.height,
    );
    final Size wellArtwork = Size(tokens.lockFilmWidth, tokens.lockFilmHeight);
    final Size artwork = approaching
        ? Size.lerp(full.size, referenceArtwork, fraction)!
        : Size.lerp(referenceArtwork, wellArtwork, fraction)!;
    final BorderRadius radius = BorderRadius.circular(
      reference.radius * weight,
    );
    final BoxShadow shadow = reference.shadow;
    return Positioned.fromRect(
      rect: _stageRect(full, progress, tokens),
      child: CustomPaint(
        willChange: weight > 0,
        painter: weight > 0
            ? _LaunchStageShadow(
                radius: radius,
                opaqueStage: tokens.launchStageBackground.a == 1,
                shadow: BoxShadow(
                  color: shadow.color.withValues(
                    alpha: shadow.color.a * weight,
                  ),
                  offset: shadow.offset * weight,
                  blurRadius: shadow.blurRadius * weight,
                ),
              )
            : null,
        child: ClipRRect(
          key: const ValueKey<String>('startup_stage_rect'),
          borderRadius: radius,
          // At full size the film already clips to this same rectangle.
          // The stage needs its own crop only as it moves into the well.
          clipBehavior: progress == 0 ? Clip.none : Clip.antiAlias,
          child: ColoredBox(
            color: tokens.launchStageBackground,
            child: OverflowBox(
              minWidth: artwork.width,
              maxWidth: artwork.width,
              minHeight: artwork.height,
              maxHeight: artwork.height,
              child: film,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, KeyEvent event) {
        if (event is KeyDownEvent) _skip();
        return KeyEventResult.handled;
      },
      child: BlockSemantics(
        child: ExcludeSemantics(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _skip(),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Rect full = Offset.zero & constraints.biggest;
                if (_viewport != full.size) {
                  _viewport = full.size;
                  if (_started && !_geometryScheduled) {
                    _geometryScheduled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _geometryScheduled = false;
                      if (!mounted || widget.session.isClosed) return;
                      final Rect? measured = _measureDestination();
                      if (measured != null) {
                        setState(() => _destination = measured);
                      }
                    });
                  }
                }
                return SizedBox.expand(
                  key: _bounds,
                  child: Stack(
                    children: <Widget>[
                      if (!widget.session.authInShell)
                        Positioned.fill(child: widget.session._auth),
                      ValueListenableBuilder<double>(
                        valueListenable: widget.session.motion,
                        child: widget.session.buildFilm(),
                        builder: (_, double progress, Widget? film) =>
                            _buildStage(full, progress, tokens, film),
                      ),
                      if (!widget.session._done)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              bottom: tokens.launchHintBottomInset,
                            ),
                            child: Text(
                              context.l10n.launchSkipHint,
                              key: const ValueKey<String>('launch_skip_hint'),
                              style: tokens.launchHintText,
                            ),
                          ),
                        ),
                      if (widget.session._waiting && !_started)
                        Align(
                          alignment: const Alignment(0, .82),
                          child: SizedBox(
                            width: tokens.launchWaitingWidth,
                            height: tokens.launchWaitingHeight,
                            child: RepaintBoundary(
                              key: const ValueKey<String>('launch_waiting'),
                              child: LinearProgressIndicator(
                                color: tokens.znn,
                                backgroundColor: tokens.line,
                                minHeight: tokens.launchWaitingHeight,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    _settle.dispose();
    _focus.dispose();
    super.dispose();
  }
}

class _LaunchStageShadow extends CustomPainter {
  const _LaunchStageShadow({
    required this.radius,
    required this.opaqueStage,
    required this.shadow,
  });

  final BorderRadius radius;
  final bool opaqueStage;
  final BoxShadow shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Rect interior = bounds.deflate(radius.topLeft.x + 1);
    canvas.save();
    if (opaqueStage && !interior.isEmpty) {
      // Keep the shadow under the antialiased edge. The film covers the rest.
      canvas.clipRect(interior, clipOp: ClipOp.difference, doAntiAlias: false);
    }
    canvas
      ..drawRRect(
        radius.toRRect(bounds.shift(shadow.offset)),
        shadow.toPaint(),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LaunchStageShadow oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.opaqueStage != opaqueStage ||
      oldDelegate.shadow != shadow;
}
