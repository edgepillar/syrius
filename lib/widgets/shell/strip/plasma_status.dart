import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_glow.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_well.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/strip/priority_row.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Time that only goes forward, read as the time since some fixed moment.
///
/// Not `DateTime.now`: the wall clock is stepped by the system (a sync, a
/// resume from sleep), and a generation timed across a step came out
/// negative or an hour long.
typedef Uptime = Duration Function();

final Stopwatch _sinceStart = Stopwatch()..start();

Duration _uptime() => _sinceStart.elapsed;

/// How long the last few plasma generations took on this computer.
///
/// Kept in memory for the session and not stored: the time depends on the
/// machine and on what else it is doing, so last week's figure is no better
/// a guide than the first one of today, and the strip says nothing about a
/// typical time until it has measured one.
class PlasmaTimes {
  /// Creates an empty record.
  PlasmaTimes();

  /// The record of this run of the wallet. It outlives the strip, which is
  /// taken down while the wallet is locked.
  static final PlasmaTimes session = PlasmaTimes();

  /// How many generations are remembered. Few, so that a change in the
  /// machine's load shows within a handful of blocks.
  static const int kept = 8;

  final List<Duration> _recent = <Duration>[];

  /// Records one finished generation.
  void add(Duration took) {
    _recent.add(took);
    if (_recent.length > kept) {
      _recent.removeAt(0);
    }
  }

  /// The median of what is remembered; null before the first generation.
  ///
  /// The median and not the mean: one generation run beside a build takes
  /// several times as long and would pull a mean of eight well off.
  Duration? get typical {
    if (_recent.isEmpty) {
      return null;
    }
    final List<Duration> sorted = <Duration>[..._recent]..sort();
    final int middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }
}

/// The plasma mark. While the wallet generates plasma (proof of work for a
/// block) it is the original bolt tracing its outline, with the seconds so
/// far and how long it usually takes; otherwise the glow, held still.
///
/// The glow's shader paints its halo opaque out to the edge of its square,
/// so the box showed as a dark blue square on the strip. The mask fades the
/// halo out before the inscribed circle, which leaves the bolt (the middle
/// 57%) untouched and the corners empty. In the light theme the well sets it
/// on the dark ground it was drawn for, a disc 38 px across, so the mask's
/// fade (it ends 18 px out) ends a pixel inside the disc's edge.
class GenerationStatus extends StatefulWidget {
  /// Creates the plasma mark. Everything is the wallet's own when left out.
  const GenerationStatus({this.status, this.uptime, this.times, super.key});

  /// Says when a generation starts and ends; the wallet's
  /// [PowGeneratingStatusBloc] when null.
  final Stream<PowStatus>? status;

  /// The clock the seconds are counted on.
  final Uptime? uptime;

  /// Where finished generations are recorded; [PlasmaTimes.session] when
  /// null.
  final PlasmaTimes? times;

  @override
  State<GenerationStatus> createState() => _GenerationStatusState();
}

class _GenerationStatusState extends State<GenerationStatus> {
  StreamSubscription<PowStatus>? _subscription;
  Timer? _ticker;
  Duration? _startedAt;
  int _seconds = 0;
  bool _joinedMidway = false;
  bool _recorded = true;

  Uptime get _now => widget.uptime ?? _uptime;

  PlasmaTimes get _times => widget.times ?? PlasmaTimes.session;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(GenerationStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      unawaited(_subscription?.cancel());
      _listen();
    }
  }

  void _listen() {
    final Stream<PowStatus> stream =
        widget.status ?? sl.get<PowGeneratingStatusBloc>().stream;
    // The bloc repeats its last event to a new listener. A strip built
    // while a generation runs can only count from when it was built, so
    // that generation is shown and not recorded: it would enter the record
    // shorter than it was.
    _joinedMidway =
        stream is ValueStream<PowStatus> &&
        stream.valueOrNull == PowStatus.generating;
    _subscription = stream.listen(
      _onStatus,
      // The bloc carries no errors of its own; one from a stream handed in
      // must not end the wallet's zone.
      onError: (Object _) {},
    );
  }

  void _onStatus(PowStatus status) {
    if (status == PowStatus.generating) {
      if (_startedAt != null) {
        return;
      }
      _recorded = !_joinedMidway;
      _joinedMidway = false;
      setState(() {
        _startedAt = _now();
        _seconds = 0;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      return;
    }
    _joinedMidway = false;
    final Duration? startedAt = _startedAt;
    if (startedAt == null) {
      return;
    }
    if (_recorded) {
      _times.add(_now() - startedAt);
    }
    _ticker?.cancel();
    setState(() => _startedAt = null);
  }

  void _tick() {
    final Duration? startedAt = _startedAt;
    if (startedAt == null) {
      return;
    }
    final int seconds = (_now() - startedAt).inSeconds;
    if (seconds != _seconds) {
      setState(() => _seconds = seconds);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startedAt == null) {
      return Tooltip(
        message: context.l10n.stripPlasmaIdle,
        // Outside the mask, or the mask would fade the disc too.
        child: PlasmaWell(
          overhang: 1,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => const RadialGradient(
              colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              stops: <double>[0.6, 1],
            ).createShader(bounds),
            child: const PlasmaGlow(
              key: Key('strip_plasma'),
              size: 36,
              active: false,
            ),
          ),
        ),
      );
    }
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle dim = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontSize: 13);
    final Duration? typical = _times.typical;
    // The label gives way before the seconds do, and the typical time
    // before either: on a narrow strip the bolt and its count are the news.
    return PriorityRow(
      gap: tokens.cardGap - 2,
      fill: false,
      children: <Prioritized>[
        const Prioritized(
          priority: 0,
          // Green and grey strokes, drawn for either ground: it needs no
          // well. 18 px, the size of the strip's text line.
          child: AppLottie(
            AppLottieAsset.plasmaGeneration,
            key: Key('strip_plasma'),
            size: 18,
          ),
        ),
        Prioritized(
          priority: 2,
          shrink: true,
          minWidth: 48,
          child: Text(
            context.l10n.stripGeneratingPlasma,
            style: dim,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Prioritized(
          priority: 1,
          child: Ltr(
            child: Text(
              context.l10n.stripSeconds(_seconds),
              key: const Key('strip_plasma_elapsed'),
              style: monoStyle(dim),
            ),
          ),
        ),
        if (typical != null)
          Prioritized(
            priority: 3,
            child: Text(
              // Never "about 0 s": a generation under half a second is
              // still about one.
              '· ${context.l10n.stripPlasmaTypical(_wholeSeconds(typical))}',
              key: const Key('strip_plasma_typical'),
              style: dim.copyWith(color: tokens.faint),
            ),
          ),
      ],
    );
  }

  static int _wholeSeconds(Duration duration) {
    final int rounded = (duration.inMilliseconds / 1000).round();
    return rounded < 1 ? 1 : rounded;
  }
}
