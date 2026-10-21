import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';

class NavigationUtils {
  static Future<void> openUrl(String url) async {
    if (!RegExp('^http').hasMatch(url)) {
      url = 'https://$url';
    }
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await sl.get<NotificationsBloc>().addNotification(
            WalletNotification(
              title: currentL10n.openUrlFailedNotificationTitle(url),
              timestamp: DateTime.now().millisecondsSinceEpoch,
              details: currentL10n.openUrlFailedNotificationDetails(url),
              type: NotificationType.error,
            ),
          );
    }
  }

  //TODO(maznnwell): check if there is a desire to impose a right-to-left transition
  static void push(context, Widget child) {
    Navigator.push(
      context,
       MaterialPageRoute<void>(
         builder: (_) => child,
      ),
    );
  }

  static void pushReplacement(context, Widget child) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => child,
      ),
    );
  }

  static void popRepeated(context, int times) {
    int count = 0;
    Navigator.popUntil(context, (Route route) => count++ == times);
  }
}
