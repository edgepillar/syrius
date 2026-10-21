import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';
import 'package:zxing2/qrcode.dart';


final ScreenCapturer screenCapturer = ScreenCapturer.instance;

class WalletConnectQrCard extends StatefulWidget {
  const WalletConnectQrCard({super.key});

  @override
  State<WalletConnectQrCard> createState() => _WalletConnectQrCardState();
}

class _WalletConnectQrCardState extends State<WalletConnectQrCard> {
  TextEditingController _uriController = TextEditingController(
    text: kLastWalletConnectUriNotifier.value,
  );
  CapturedData? _lastCapturedData;

  final GlobalKey<FormState> _uriKey = GlobalKey<FormState>();

  /// The Scan screen button: hides the wallet, lets the person drag over
  /// the dApp's QR code, reads it and pairs. Needs the screen recording
  /// permission on macOS.
  @override
  Widget build(BuildContext context) {
    return SecondaryAction(
      child: OutlinedButton.icon(
        key: const Key('wc_scan_screen'),
        onPressed: () {
          checkPermissionForMacOS().then((bool value) {
            if (value) {
              windowManager.minimize().then(
                (value) => _handleClickCapture(CaptureMode.region),
              );
            }
          });
        },
        icon: const Icon(Icons.qr_code_scanner, size: 16),
        label: const Text('Scan screen'),
      ),
    );
  }

  Future<void> _pairWithDapp(Uri uri) async {
    try {
      final IWeb3WalletService wcService = sl.get<IWeb3WalletService>();
      final PairingInfo pairingInfo = await wcService.pair(uri);
      Logger('WalletConnectPairingCard')
          .log(Level.INFO, 'pairing info', pairingInfo.toJson());
      _uriController = TextEditingController();
      _uriKey.currentState?.reset();
      setState(() {});
    } catch (e) {
      await NotificationUtils.sendNotificationError(e, 'Pairing failed');
    }
  }

  Future<void> _handleClickCapture(CaptureMode mode) async {
    try {
      final Directory walletConnectDirectory = Directory(
          path.join(znnDefaultPaths.cache.path, walletConnectDirName),);

      if (!walletConnectDirectory.existsSync()) {
        walletConnectDirectory.createSync(recursive: true);
      }

      final String screenshotName =
          'screenshot-${DateTime.now().millisecondsSinceEpoch}';

      final File imagePath = await File(
              '${walletConnectDirectory.absolute.path}${path.separator}$screenshotName.png',)
          .create();

      _lastCapturedData = await screenCapturer.capture(
        mode: mode,
        imagePath: imagePath.absolute.path,
      );

      if (_lastCapturedData != null) {
        final img.Image image = img.decodePng(imagePath.readAsBytesSync())!;

        final LuminanceSource source = RGBLuminanceSource(
            image.width, image.height, image.getBytes().buffer.asInt32List(),);
        final BinaryBitmap bitmap = BinaryBitmap(HybridBinarizer(source));

        final QRCodeReader reader = QRCodeReader();
        final Result result = reader.decode(bitmap);

        if (result.rawBytes!.isNotEmpty) {
          if (result.text.isNotEmpty &&
              Uri.tryParse(result.text) != null) {
            await windowManager.show();
            _uriController.text = result.text;
          } else {
            await windowManager.show();
            await sl<NotificationsBloc>().addNotification(WalletNotification(
                title: 'Invalid QR code',
                timestamp: DateTime.now().millisecondsSinceEpoch,
                details: 'Please scan a valid WalletConnect QR code',
                type: NotificationType.error,),);
          }
        } else {
          await windowManager.show();
          await sl<NotificationsBloc>().addNotification(WalletNotification(
              title: 'QR code scan failed',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              details: 'Please scan a valid WalletConnect QR code',
              type: NotificationType.error));
        }
        await _pairWithDapp(Uri.parse(result.text));
      } else {
        await windowManager.show();
        await sl<NotificationsBloc>().addErrorNotification(
          'User canceled the QR scanning operation',
          'User QR scan canceled',
        );
      }
    } on Exception catch (e) {
      await windowManager.show();
      await sl<NotificationsBloc>()
          .addErrorNotification(e, 'Invalid QR code exception');
    }
  }

  Future<bool> checkPermissionForMacOS() async {
    if (Platform.isMacOS) {
      if (!await _requestAccessForMacOS()) {
        await sl<NotificationsBloc>().addNotification(WalletNotification(
            title: 'Permission required',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            details:
                'Screen Recording permission is required to scan and process the on-screen WalletConnect QR code',
            type: NotificationType.generatingPlasma));
        return false;
      }
      return true;
    }
    return true;
  }

  Future<bool> _requestAccessForMacOS() async {
    final bool isAccessAllowed = await ScreenCapturer.instance.isAccessAllowed();
    if (!isAccessAllowed) {
      await ScreenCapturer.instance.requestAccess();
    }
    return isAccessAllowed;
  }
}
