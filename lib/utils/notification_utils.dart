import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/src/model/stats.dart';

class NotificationUtils {
  static Future<void> sendNotificationError(
    Object error,
    String title,
  ) async {
    Logger('NotificationUtils')
        .log(Level.WARNING, 'sendNotificationError', error);
    await sl.get<NotificationsBloc>().addErrorNotification(
          error,
          title,
        );
  }

  static bool shouldShowNotification() =>
      kLastNotification != null &&
      kLastNotification?.timestamp != kLastDismissedNotification?.timestamp;

  static Future<void> sendNodeSyncingNotification() async {
    final SyncInfo syncInfo = await zenon!.stats.syncInfo();
    if (syncInfo.targetHeight == 0 ||
        syncInfo.currentHeight == 0 ||
        (syncInfo.targetHeight - syncInfo.currentHeight) > 20) {
      await sl.get<NotificationsBloc>().addNotification(
            WalletNotification(
              title: currentL10n.nodeSyncingNotificationTitle,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              details: currentL10n.nodeSyncingNotificationDetails,
              type: NotificationType.changedNode,
            ),
          );
    }
  }
}
