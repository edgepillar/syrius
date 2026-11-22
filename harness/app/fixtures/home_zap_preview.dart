import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/view/zap_sparks.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/zap.dart'
    show ZapReceivedMessage;
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modals.dart'
    show showFrostedDialog;
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/event_toast.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show Address;

/// Labels the sample directly inside the message area of the original card.
const String homeZapPreviewMessage =
    'Sample Zap message for visual inspection.';

final String _sender = Address('z', <int>[
  0,
  ...List<int>.filled(19, 5),
]).toString();

/// Opens the original message surface using presentation data in the harness.
Future<void> showHomeZapPreview(BuildContext context) async {
  await showFrostedDialog<void>(
    context: context,
    barrierDismissible: false,
    frostWindowCaption: true,
    builder: (BuildContext dialogContext) => ZapReceivedMessage(
      sender: _sender,
      znn: BigInt.from(100000000),
      qsr: BigInt.from(1000000000),
      message: homeZapPreviewMessage,
      onClose: () {
        if (ModalRoute.of(dialogContext)?.isCurrent == true) {
          Navigator.of(dialogContext).pop();
        }
      },
    ),
  );
}

/// Plays the original painter on the current window using only preview data.
Future<Map<String, int>> observeHomeZapSparks(BuildContext context) async {
  final Completer<Map<String, int>> result = Completer<Map<String, int>>();
  final OverlayEntry entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(child: _SparkPreview(onComplete: result.complete)),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    return await result.future.timeout(const Duration(seconds: 6));
  } finally {
    entry
      ..remove()
      ..dispose();
  }
}

class _SparkPreview extends StatefulWidget {
  const _SparkPreview({required this.onComplete});

  final ValueChanged<Map<String, int>> onComplete;

  @override
  State<_SparkPreview> createState() => _SparkPreviewState();
}

class _SparkPreviewState extends State<_SparkPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  int _paintedFrames = 0;
  int _firstPaint = -1;
  int _peakActivePaint = -1;
  bool _terminalPaint = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: AppTokens.zapSparkDuration,
      animationBehavior: AnimationBehavior.preserve,
    )..forward();
  }

  void _didPaint(double progress) {
    if (_terminalPaint) return;
    final int sample = (progress * 1000).floor();
    if (_firstPaint < 0) _firstPaint = sample;
    if (progress < 1) {
      if (sample > _peakActivePaint) {
        _paintedFrames++;
        _peakActivePaint = sample;
      }
      return;
    }
    _terminalPaint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onComplete(<String, int>{
        'first_permille': _firstPaint,
        'peak_active_permille': _peakActivePaint,
        'active_frames': _paintedFrames,
        'terminal_permille': sample,
        'destinations': ZapSparksPainter.destinations.length,
      });
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _motion,
      builder: (BuildContext context, Widget? child) => CustomPaint(
        painter: _ObservedSparkPaint(
          progress: _motion.value,
          tokens: AppTokens.of(context),
          didPaint: _didPaint,
        ),
        child: child,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _ObservedSparkPaint extends ZapSparksPainter {
  _ObservedSparkPaint({
    required super.progress,
    required super.tokens,
    required this.didPaint,
  });

  final ValueChanged<double> didPaint;

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    if (!size.isEmpty) didPaint(progress);
  }
}

/// Observes the original toast through its rendered card and countdown bar.
Future<Map<String, int>> observeHomeToast(
  BuildContext context, {
  required Future<void> Function(Offset) movePointer,
  required VoidCallback requireWallet,
}) async {
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final AppTokens tokens = AppTokens.of(context);
  final GlobalKey<State<EventToast>> toast = GlobalKey<State<EventToast>>();
  final Completer<void> dismissed = Completer<void>();
  const Duration interval = Duration(milliseconds: 240);
  const Offset outside = Offset(1, 1);

  void requireOwner() {
    requireWallet();
    if (!context.mounted || route?.isCurrent != true) {
      throw StateError('Home toast preview owner changed');
    }
  }

  ({Rect card, int remaining}) sample() {
    requireOwner();
    final Element? root = toast.currentContext as Element?;
    if (root == null) throw StateError('Home toast preview did not mount');
    final Element? card = _findToastElement<MouseRegion>(root);
    final Element? bar = _findToastElement<FractionallySizedBox>(root);
    final RenderObject? render = card?.findRenderObject();
    final double? remaining =
        (bar?.widget as FractionallySizedBox?)?.widthFactor;
    if (render is! RenderBox ||
        !render.hasSize ||
        remaining == null ||
        !remaining.isFinite) {
      throw StateError('Home toast preview geometry is unavailable');
    }
    return (
      card: render.localToGlobal(Offset.zero) & render.size,
      remaining: (remaining * 1000).round(),
    );
  }

  await movePointer(outside);
  requireOwner();
  final OverlayEntry entry = OverlayEntry(
    builder: (_) => PositionedDirectional(
      top: tokens.toastTop,
      start: tokens.toastEdge,
      end: tokens.toastEdge,
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        heightFactor: 1,
        child: EventToast(
          key: toast,
          message: 'Sample notification for visual inspection.',
          onDismiss: dismissed.complete,
        ),
      ),
    ),
  );
  overlay.insert(entry);
  final Stopwatch elapsed = Stopwatch()..start();
  try {
    await WidgetsBinding.instance.endOfFrame;
    final double firstTop = sample().card.top;
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final ({Rect card, int remaining}) settled = sample();
    await movePointer(settled.card.center);
    await WidgetsBinding.instance.endOfFrame;
    final int heldStart = sample().remaining;
    await Future<void>.delayed(interval);
    final int heldEnd = sample().remaining;
    await movePointer(outside);
    await Future<void>.delayed(interval);
    final int resumed = sample().remaining;
    await dismissed.future.timeout(const Duration(seconds: 8));
    await WidgetsBinding.instance.endOfFrame;
    requireOwner();
    if (_findToastElement<MouseRegion>(toast.currentContext as Element?) !=
        null) {
      throw StateError('Dismissed toast preview still has a card');
    }
    return <String, int>{
      'rise_milli_px': ((firstTop - settled.card.top) * 1000).round(),
      'before_hold_permille': settled.remaining,
      'held_start_permille': heldStart,
      'held_end_permille': heldEnd,
      'resumed_permille': resumed,
      'dismissed_ms': elapsed.elapsedMilliseconds,
    };
  } finally {
    entry
      ..remove()
      ..dispose();
  }
}

Element? _findToastElement<T extends Widget>(Element? root) {
  Element? target;
  root?.visitChildElements((Element child) {
    target ??= child.widget is T ? child : _findToastElement<T>(child);
  });
  return target;
}
