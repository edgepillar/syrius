import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';

/// How often the countdown looks at the clock.
const Duration _kTick = Duration(seconds: 1);

/// The time left until a fusion or a stake can be cancelled, counting down
/// in the row where its Cancel button will be.
///
/// Quiet mono text: it is a wait, not an alarm. The old timer drew it in a
/// red box and, once at zero, asked for a refresh every second; this one
/// asks once.
///
/// Shared by the fusions and the stakes tables, which is why it is public;
/// it belongs with the other card parts.
class CancelCountdown extends StatefulWidget {
  /// Creates a countdown of [duration] from now.
  const CancelCountdown({
    required this.duration,
    required this.onFinished,
    this.tooltip = '',
    this.builder,
    super.key,
  });

  /// The time left when the widget is built.
  final Duration duration;

  /// Called once, when no time is left.
  final VoidCallback onFinished;

  /// Says what is being waited for.
  final String tooltip;

  /// Draws the time left, given as [FormatUtils.formatDuration] words it in
  /// the app's language (`9 h 52 m`), in place of the quiet text; [tooltip]
  /// is then the builder's to show. For a control
  /// that counts down in its own label, such as a Cancel button still
  /// locked.
  final Widget Function(BuildContext context, String left)? builder;

  @override
  State<CancelCountdown> createState() => _CancelCountdownState();
}

class _CancelCountdownState extends State<CancelCountdown> {
  late DateTime _end;

  /// The time left as it is drawn. Kept as a length of time and worded in
  /// [build], so that a change of language rewords it at once and not at
  /// the next change of the text, which is an hour away while days are left.
  late Duration _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CancelCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Counts to a point on the clock, so a slow tick cannot make it drift.
  void _start() {
    _end = DateTime.now().add(widget.duration);
    _left = widget.duration;
    _timer?.cancel();
    _timer = Timer.periodic(_kTick, (_) => _onTick());
  }

  void _onTick() {
    final Duration left = _end.difference(DateTime.now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      widget.onFinished();
      return;
    }
    // Drawn again only when the text would differ: once an hour while days
    // are left.
    final AppLocalizations l10n = currentL10n;
    if (FormatUtils.formatDuration(l10n, left) !=
        FormatUtils.formatDuration(l10n, _left)) {
      setState(() => _left = left);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = FormatUtils.formatDuration(context.l10n, _left);
    final Widget Function(BuildContext, String)? builder = widget.builder;
    if (builder != null) {
      return builder(context, text);
    }
    return Tooltip(
      message: widget.tooltip,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: monoStyle(cardDimStyle(context)),
      ),
    );
  }
}
