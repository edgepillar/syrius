import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/view/zap_sparks.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/zap.dart'
    show ZapReceivedMessage;
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modals.dart'
    show showFrostedDialog;
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
