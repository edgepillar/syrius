import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The wallet's notifications, newest first, in one list that fills the
/// page. A row opens to show its details.
class NotificationsTabChild extends StatefulWidget {
  const NotificationsTabChild({super.key});

  @override
  State<NotificationsTabChild> createState() => _NotificationsTabChildState();
}

class _NotificationsTabChildState extends State<NotificationsTabChild> {
  List<WalletNotification>? _notifications;

  /// The row that is open, by timestamp.
  int? _open;

  @override
  Widget build(BuildContext context) {
    _loadNotifications();
    final List<WalletNotification> items = _notifications!;
    return PageGrid(
      rows: <PageRow>[
        PageRow.fill(<PageCell>[
          PageCell(
            Panel(
              title: 'Notifications',
              actions: <Widget>[
                Text('${items.length}', style: ledgerLabelStyle(context)),
                const SizedBox(width: 8),
              ],
              child: items.isEmpty
                  ? const QuietNote('None yet')
                  : ListView.separated(
                      key: const PageStorageKey<String>('notifications_list'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (BuildContext context, int index) =>
                          _buildRow(items[index]),
                    ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildRow(WalletNotification notification) {
    final ThemeData theme = Theme.of(context);
    final bool open = _open == notification.timestamp;
    final int timestamp = notification.timestamp!;
    return InkWell(
      onTap: () => setState(() {
        _open = open ? null : notification.timestamp;
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(width: 20, child: notification.getIcon()),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTitle(
                    notification.title ?? '',
                    open: open,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  FormatUtils.formatNotificationStamp(timestamp),
                  style: monoStyle(theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: const Icon(Icons.close, color: AppColors.faint),
                  onPressed: () => _deleteNotification(notification.timestamp),
                ),
              ],
            ),
            AnimatedSize(
              duration: Durations.short4,
              curve: Easing.standard,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(left: 32, top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: SelectableText(
                              notification.details ?? '',
                              style: settingHintStyle(context),
                            ),
                          ),
                          CopyToClipboardButton(
                            notification.details ?? '',
                            iconSize: 16,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// A row's title: whole when the row is open, one line when it is closed.
  /// A closed title that does not fit is cut at its end and carries the
  /// whole text in a tooltip; one that fits has no tooltip to repeat it.
  Widget _buildTitle(String title, {required bool open, TextStyle? style}) {
    if (open) {
      return Text(title, style: style);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Text line = Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        final TextPainter painter = TextPainter(
          text: TextSpan(text: title, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final bool cut = painter.didExceedMaxLines;
        painter.dispose();
        return cut ? Tooltip(message: title, child: line) : line;
      },
    );
  }

  List<WalletNotification> _getNotificationsFromDb() {
    try {
      final Box notificationsBox = Hive.box(kNotificationsBox);
      final List keys = notificationsBox.keys.toList();
      if (keys.length >= kNotificationsResultLimit) {
        return List<WalletNotification>.from(
          notificationsBox.valuesBetween(
            startKey: keys[keys.length - kNotificationsResultLimit],
            endKey: keys[keys.length - 1],
          ),
        );
      }
      return notificationsBox.keys
          .map<WalletNotification>(
            (e) => notificationsBox.get(e),
          )
          .toList();
    } catch (e) {
      return <WalletNotification>[];
    }
  }

  Future<void> _deleteNotification(int? notificationTimestamp) async {
    final Box notificationsBox = Hive.box(kNotificationsBox);

    final notificationKey = notificationsBox.keys.firstWhere(
      (key) => notificationsBox.get(key).timestamp == notificationTimestamp,
    );

    await notificationsBox.delete(notificationKey);

    setState(() {});
  }

  void _loadNotifications() {
    _notifications = _getNotificationsFromDb();
    _notifications!.sort(
      (WalletNotification a, WalletNotification b) =>
          b.timestamp!.compareTo(a.timestamp!),
    );
  }
}
