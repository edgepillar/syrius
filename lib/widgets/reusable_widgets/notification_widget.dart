import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// A page with the notification banner floating over its top edge.
///
/// The banner is laid over the page and takes no room from it. It used to
/// sit above the page in the shell's column, so each notification pushed
/// the page down by the banner's height, cut off the page's last row, and
/// dropped the page back up when it was dismissed.
///
/// The banner is inset from the page's edges by the gap inside a card, so it
/// is never wider than the page and never reaches the rail beside it.
class NotificationOverlay extends StatelessWidget {
  /// Lays [banner] over the top of [child].
  const NotificationOverlay({
    required this.banner,
    required this.child,
    super.key,
  });

  /// The banner, usually a floating [NotificationWidget].
  final Widget banner;

  /// The page. It fills the overlay whether the banner shows or not.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double gap = AppTokens.of(context).cardGap;
    return Stack(
      // The banner's shadow falls past its edges.
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: child),
        Positioned(top: gap, left: gap, right: gap, child: banner),
      ],
    );
  }
}

/// The banner over a page for the latest notification: its title, See more
/// and Dismiss. A new notification fades in over the last one. Escape
/// dismisses it while the keyboard focus is on one of its actions.
///
/// Floating, every banner dismisses itself, as if Dismiss were pressed: it
/// covers the top of every card, their Refresh buttons included, and used
/// to stay there until the user cleared it. Nothing is lost with it: the
/// Notifications list keeps every one. A success or a piece of information
/// goes after [autoDismissAfter]; an error, a warning or a prompt to confirm
/// on a hardware device after [autoDismissAlertAfter].
///
/// A thin bar along the banner's top edge fills as the time runs and is
/// full as the banner leaves. The count and the bar hold where they are
/// while the pointer is over the banner or the focus is in it, go on from
/// there when both have left, and start again from zero, with the new
/// kind's time, when a newer notification replaces the banner.
///
/// Inline, in a column above the content, it stays until it is dismissed or
/// replaced: there is no timeout and no bar.
class NotificationWidget extends StatefulWidget {
  const NotificationWidget({
    this.onSeeMorePressed,
    this.onDismissPressed,
    this.onNewNotificationCallback,
    this.popBeforeSeeMoreIsPressed = true,
    this.floating = false,
    super.key,
  });
  final VoidCallback? onSeeMorePressed;
  final VoidCallback? onDismissPressed;
  final VoidCallback? onNewNotificationCallback;
  final bool popBeforeSeeMoreIsPressed;

  /// Whether the banner floats over the page, in a [NotificationOverlay],
  /// with a shadow and no gap under it. Otherwise it sits in a column above
  /// the content and brings its own gap to it.
  final bool floating;

  /// How long a floating success or information banner stays. It confirms
  /// what the user just did, and is read on the way past.
  static const Duration autoDismissAfter = Duration(seconds: 3);

  /// How long a floating error, warning or prompt to confirm stays: the
  /// kinds the banner draws in the error or alert colour. Twice the time of
  /// a confirmation, because a failure has to be read.
  static const Duration autoDismissAlertAfter = Duration(seconds: 6);

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget>
    with SingleTickerProviderStateMixin {
  late NotificationsBloc _notificationsBloc;

  /// The one clock of the shown banner, floating only. Its value is the bar
  /// and its end is the dismissal, so the two cannot drift apart as a timer
  /// beside an animation could.
  late final AnimationController _countdown;

  /// The banner [_countdown] counts for, or null when it counts for none.
  WalletNotification? _counted;

  /// The clock as the shown banner's bar sees it. Each banner gets its own,
  /// so one that is replaced fades out with its bar where it stood, and
  /// does not snap back to empty with its successor's count.
  ProxyAnimation _bar = ProxyAnimation();
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      // The full time whatever the OS says about motion. Under "reduce
      // motion" a controller runs in a twentieth of its time by default,
      // and the banner would be gone before it was read.
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onCountdownStatus);
    _initNotificationsBloc();
    _restartCountdown();
  }

  @override
  void didUpdateWidget(NotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.floating != widget.floating) {
      _restartCountdown();
    }
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  static Duration _dismissAfter(WalletNotification notification) {
    switch (notification.type) {
      case NotificationType.error:
      case NotificationType.stakingDeactivated:
      case NotificationType.confirm:
        return NotificationWidget.autoDismissAlertAfter;
      default:
        return NotificationWidget.autoDismissAfter;
    }
  }

  /// Starts the count for the shown banner from zero, with its kind's time,
  /// or clears it when there is nothing to count: inline, or no banner.
  void _restartCountdown() {
    // The banner on its way out keeps the bar it had.
    _bar.parent = AlwaysStoppedAnimation<double>(_countdown.value);
    _countdown.value = 0;
    _counted = null;
    if (!widget.floating || !_shouldShowNotification()) {
      return;
    }
    final WalletNotification shown = kLastNotification!;
    _counted = shown;
    _bar = ProxyAnimation(_countdown);
    _countdown.duration = _dismissAfter(shown);
    _runCountdown();
  }

  /// Runs the count on from where it stands, or holds it there while the
  /// pointer or the focus is on the banner. Never back to zero: a banner
  /// the pointer only crossed would otherwise get its whole time again.
  void _runCountdown() {
    if (_counted == null) {
      return;
    }
    if (_hovered || _focused) {
      _countdown.stop();
    } else {
      _countdown.forward();
    }
  }

  void _onCountdownStatus(AnimationStatus status) {
    final WalletNotification? counted = _counted;
    if (status != AnimationStatus.completed || counted == null) {
      return;
    }
    _counted = null;
    if (_shouldShowNotification() &&
        kLastNotification?.timestamp == counted.timestamp) {
      _dismissNotification();
    } else {
      // Dismissed since from somewhere that does not rebuild this widget:
      // Dismiss on the inline banner of a screen over this one, or a wallet
      // reset. It was still drawn here, and would have stayed with its bar
      // full. Drawn again it leaves. This widget dismissed nothing, so
      // onDismissPressed is not called.
      setState(() {});
    }
  }

  void _onHover(bool hovered) {
    if (_hovered == hovered) return;
    _hovered = hovered;
    _runCountdown();
  }

  void _onFocus(bool focused) {
    if (_focused == focused) return;
    _focused = focused;
    _runCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final Widget switcher = _buildSwitcher();
    if (!widget.floating) {
      return switcher;
    }
    // Round the switcher, not each banner, so the pointer and the focus
    // carry over when a newer banner replaces the one under them. With no
    // banner the switcher has no size, so neither can be in it. Clicks go
    // only where the banner is, never to the region round it.
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.deferToChild,
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _onFocus,
        child: switcher,
      ),
    );
  }

  Widget _buildSwitcher() {
    final bool show = _shouldShowNotification();
    return AnimatedSwitcher(
      duration: Durations.medium1,
      reverseDuration: Durations.short3,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Easing.emphasizedAccelerate,
      // Floating, the banner drops a third of its height into place; in a
      // column it only settles, as the content under it moves anyway.
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, widget.floating ? -0.35 : -0.15),
                end: Offset.zero,
              ).animate(animation),
              // A banner on its way out takes no clicks: Dismiss pressed
              // twice would dismiss the one fading in after it.
              child: AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (BuildContext context, Widget? child) =>
                    IgnorePointer(
                      ignoring: animation.status == AnimationStatus.reverse,
                      child: child,
                    ),
              ),
            ),
          ),
      child: show
          ? KeyedSubtree(
              key: ValueKey<int?>(kLastNotification!.timestamp),
              child: _buildBanner(kLastNotification!),
            )
          : const SizedBox(key: ValueKey<String>('no_notification')),
    );
  }

  Widget _buildBanner(WalletNotification notification) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final BorderSide outline = widget.floating
        ? BorderSide(color: theme.dividerColor)
        : BorderSide.none;
    final Widget content = SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: <Widget>[
            notification.getIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: notification.title,
                waitDuration: Durations.long2,
                child: Text(
                  notification.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (kCurrentPage != Tabs.lock && widget.onSeeMorePressed != null)
              _BannerAction(
                label: context.l10n.commonSeeMore,
                color: notification.getColor(),
                onTap: _navigateToNotification,
              ),
            _BannerAction(
              label: context.l10n.commonDismiss,
              color: theme.textTheme.titleMedium!.color!,
              onTap: _dismissNotification,
            ),
          ],
        ),
      ),
    );
    final Widget banner = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _dismissNotification,
      },
      child: Material(
        color: theme.colorScheme.primary,
        // Floating over a card of the same colour, the shadow and the
        // outline are what set it apart.
        elevation: widget.floating ? 8 : 0,
        shadowColor: theme.colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: outline,
        ),
        child: widget.floating
            ? Stack(
                children: <Widget>[
                  content,
                  // Inside the outline, which is drawn over the banner's
                  // content and would cover half of the bar.
                  PositionedDirectional(
                    top: outline.width,
                    start: outline.width,
                    end: outline.width,
                    child: _DismissBar(
                      progress: _bar,
                      // The colour See more is drawn in for this kind.
                      color: notification.getColor(),
                      cornerRadius: tokens.cardRadius - outline.width,
                    ),
                  ),
                ],
              )
            : content,
      ),
    );
    if (widget.floating) {
      return banner;
    }
    return Padding(
      // The gap to the content under it, the same as between panels.
      padding: EdgeInsets.only(bottom: tokens.panelGap),
      child: banner,
    );
  }

  bool _shouldShowNotification() =>
      kLastNotification != null &&
      kLastNotification?.timestamp != kLastDismissedNotification?.timestamp;

  void _initNotificationsBloc() {
    _notificationsBloc = sl.get<NotificationsBloc>();
    _notificationsBloc.stream.listen(
      (WalletNotification? value) {
        if (mounted) {
          setState(() {
            kLastNotification = value;
          });
          // A newer banner gets its own full time.
          _restartCountdown();
          widget.onNewNotificationCallback?.call();
        }
      },
    );
  }

  void _navigateToNotification() {
    if (kCurrentPage != Tabs.lock) {
      if (widget.popBeforeSeeMoreIsPressed) {
        Navigator.popUntil(
          context,
          ModalRoute.withName(MainAppContainer.route),
        );
      }
      _dismissNotification();
      widget.onSeeMorePressed?.call();
    }
  }

  /// Dismiss pressed, Escape, See more, or the timeout: all come here.
  void _dismissNotification() {
    // The bar stays where the count stood while the banner fades out.
    _countdown.stop();
    _counted = null;
    setState(() {
      kLastDismissedNotification = kLastNotification;
    });
    widget.onDismissPressed?.call();
  }
}

/// The time a floating banner has left, as a thin bar along its top edge
/// that fills from the start side and is full as the banner leaves. There
/// is no track behind it: the banner's own edge is the track.
///
/// It changes on every frame for seconds at a time, so it is a layer of its
/// own that the clock repaints directly. Nothing is rebuilt, and neither the
/// banner nor the page under it is painted again.
class _DismissBar extends StatelessWidget {
  const _DismissBar({
    required this.progress,
    required this.color,
    required this.cornerRadius,
  });

  /// From 0, nothing drawn, to 1, the banner's whole width.
  final Animation<double> progress;
  final Color color;

  /// The radius of the banner's top corners where the bar meets them.
  final double cornerRadius;

  static const double _height = 2;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          height: _height,
          child: CustomPaint(
            key: const ValueKey<String>('notification_dismiss_bar'),
            painter: _DismissBarPainter(
              progress: progress,
              color: color,
              cornerRadius: cornerRadius,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissBarPainter extends CustomPainter {
  _DismissBarPainter({
    required this.progress,
    required this.color,
    required this.cornerRadius,
    required this.textDirection,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double cornerRadius;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * progress.value;
    final Radius corner = Radius.circular(cornerRadius);
    canvas
      // The banner's top corners. The bar is thinner than they are deep,
      // so the shape cut out is taller than the bar.
      ..clipRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height + cornerRadius),
          topLeft: corner,
          topRight: corner,
        ),
      )
      ..drawRect(
        Rect.fromLTWH(
          textDirection == TextDirection.rtl ? size.width - width : 0,
          0,
          width,
          size.height,
        ),
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_DismissBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.textDirection != textDirection;
}

/// A text action of the banner, with the hover and click cursor of a link.
class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.of(context).cardRadius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
