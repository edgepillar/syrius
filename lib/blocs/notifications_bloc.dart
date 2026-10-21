import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

class NotificationsBloc extends BaseBloc<WalletNotification?> {
  Future<void> addNotification(WalletNotification? notification) async {
    try {
      await Hive.openBox(kNotificationsBox);
      final Box notificationsBox = Hive.box(kNotificationsBox);
      if (notificationsBox.length >= kNotificationsEntriesLimit) {
        while (notificationsBox.length >= kNotificationsEntriesLimit) {
          await notificationsBox.delete(notificationsBox.keys.first);
        }
      }
      // Stored as finished text, so a notification keeps the language it was
      // written in: changing the language does not translate the old ones.
      await notificationsBox.add(notification);
      if (notification != null && _areDesktopNotificationsEnabled()) {
        final AppLocalizations l10n = currentL10n;
        final LocalNotification localNotification = LocalNotification(
          title: notification.title ?? l10n.notificationEmptyTitle,
          body: notification.details ?? l10n.notificationNoDetails,
        );
        await localNotification.show();
      }
      addEvent(notification);
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  /// Says that Plasma is about to be generated for a transaction.
  ///
  /// [purposeMessage] is the whole title, the message of a `PlasmaPurpose`
  /// (`utils/plasma_purpose.dart`): the sentence is not put together here,
  /// because one glued from an opening and a fragment cannot be translated.
  Future<void> sendPlasmaNotification(String purposeMessage) async {
    await addNotification(
      WalletNotification(
        title: purposeMessage,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: currentL10n.plasmaNotificationDetails,
        type: NotificationType.generatingPlasma,
      ),
    );
  }

  Future<void> addErrorNotification(Object error, String title) async {
    await addNotification(
      WalletNotification(
        title: title,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: currentL10n.notificationErrorWithDetails(title, error),
        type: NotificationType.error,
      ),
    );
  }

  bool _areDesktopNotificationsEnabled() => sharedPrefsService!.get(
        kEnableDesktopNotificationsKey,
        defaultValue: kEnableDesktopNotificationsDefaultValue,
      );
}
