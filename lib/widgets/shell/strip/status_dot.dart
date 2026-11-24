import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// The mockup's status pulse: expand the halo during the first 70 percent,
/// then hold it transparent for the rest of the 2.4 second cycle.
class StatusDot extends StatefulWidget {
  /// Creates a status marker. The fill can change without restarting its clock.
  const StatusDot({required this.color, this.fillKey, super.key});

  /// The current connection or publication state, independent of money values.
  final Color color;

  /// Identifies the solid dot separately from its larger painted halo.
  final Key? fillKey;

  /// The current halo input. One marks the transparent hold.
  static double? haloPhaseOf(BuildContext context) {
    if (context case StatefulElement(:final _StatusDotState state)) {
      return state._pulse.value;
    }
    return null;
  }

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> {
  late final Ticker _clock = Ticker(_tick, debugLabel: 'status pulse');
  final ValueNotifier<double> _pulse = ValueNotifier<double>(0);
  late TickerModeData _mode;
  int _cycleUs = 0;
  int _visibleUs = 0;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mode = TickerMode.valuesOf(context);
    final int cycleUs =
        AppTokens.of(context).statusPulseDuration.inMicroseconds;
    if (_cycleUs != cycleUs) {
      _hold?.cancel();
      _hold = null;
      _clock.stop();
      _cycleUs = cycleUs;
      _visibleUs = (cycleUs * 0.7).round();
      _pulse.value = 0;
    }
    _syncClock();
    if (!_clock.isActive) _clock.start();
  }

  void _syncClock() {
    _clock
      ..forceFrames = _mode.forceFrames
      ..muted = !_mode.enabled || _hold != null;
  }

  void _tick(Duration elapsed) {
    final int phaseUs = elapsed.inMicroseconds % _cycleUs;
    if (phaseUs < _visibleUs) {
      _pulse.value = phaseUs / _visibleUs;
      return;
    }
    _pulse.value = 1;
    // Muting keeps the ticker's epoch. A late frame or timer still resumes at
    // the right phase of the original cycle, including after a visibility hold.
    _hold = Timer(
      Duration(microseconds: ((_cycleUs - phaseUs) * timeDilation).ceil()),
      () {
        _hold = null;
        _syncClock();
      },
    );
    _syncClock();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _clock.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final double halo = tokens.statusDotHalo;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Give the halo its full paint bounds without growing the solid dot.
        Positioned(
          left: -halo,
          top: -halo,
          right: -halo,
          bottom: -halo,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double radius = constraints.biggest.shortestSide / 2;
                return ValueListenableBuilder<double>(
                  valueListenable: _pulse,
                  // Retain the circle while its scale and opacity change.
                  child: RepaintBoundary(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.znn,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  builder: (_, double pulse, Widget? child) {
                    final double remaining = 1 - tokens.ease.transform(pulse);
                    return Opacity(
                      opacity: 0.6 * remaining,
                      child: Transform.scale(
                        scale: (radius - halo * remaining) / radius,
                        child: child,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        AnimatedContainer(
          key: widget.fillKey,
          duration: Durations.short3,
          curve: tokens.ease,
          width: tokens.statusDotSize,
          height: tokens.statusDotSize,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
