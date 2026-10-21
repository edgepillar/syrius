import 'dart:async';
import 'dart:io';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:logging/logging.dart';
import 'package:reown_core/pairing/utils/pairing_models.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// The Camera button: scans a WalletConnect QR code with this computer's
/// camera and pairs. The scanner only works on macOS, so elsewhere there is
/// no button at all rather than a sentence saying so.
class WalletConnectCameraCard extends StatefulWidget {
  const WalletConnectCameraCard({super.key});

  @override
  State<WalletConnectCameraCard> createState() =>
      _WalletConnectCameraCardState();
}

class _WalletConnectCameraCardState extends State<WalletConnectCameraCard> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();
    // The gap to the button before it is part of this one, so that no gap
    // is left where there is no camera button.
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: SecondaryAction(
        child: OutlinedButton.icon(
          key: const Key('wc_scan_camera'),
          onPressed: _onScanPressed,
          icon: const Icon(Icons.photo_camera_outlined, size: 16),
          label: const Text('Camera'),
        ),
      ),
    );
  }

  Future<void> _onScanPressed() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiBarcodeScanner(
          validator: (BarcodeCapture capture) =>
              _filterBarcodes(capture) != null,
          onDetect: (BarcodeCapture value) async {
            Logger('WalletConnectCameraCard').log(
              Level.INFO,
              'onDetect',
              value.toString(),
            );
            final IWeb3WalletService wcService = sl.get<IWeb3WalletService>();
            final Barcode? barcode = _filterBarcodes(value);
            if (barcode != null) {
              final PairingInfo pairingInfo = await wcService.pair(
                Uri.parse(value.barcodes.first.displayValue!),
              );
              Logger('WalletConnectCameraCard').log(
                Level.INFO,
                'pairing info',
                pairingInfo.toJson(),
              );
              setState(() {});
            }
          },
          onDispose: () {
            Logger('WalletConnectCameraCard').log(Level.INFO, 'onDispose');
          },
          controller: MobileScannerController(
            facing: CameraFacing.front,
            detectionSpeed: DetectionSpeed.noDuplicates,
          ),
          errorBuilder: (BuildContext p0, MobileScannerException p1) {
            // Pop navigator and close camera after 10 seconds
            Timer(const Duration(seconds: 10), () {
              Navigator.pop(context);
            });
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${p1.errorCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Container(height: 16),
                  const Icon(
                    MaterialCommunityIcons.camera_off,
                    size: 32,
                    color: AppColors.errorColor,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool canParseWalletConnectUri(String wcUri) {
    Uri? walletConnectUri;
    walletConnectUri = Uri.tryParse(wcUri);
    if (walletConnectUri != null) {
      return true;
    }
    return false;
  }

  /// A BarcodeCapture can contain multiple barcodes. This function returns
  /// the first valid WC barcode
  Barcode? _filterBarcodes(BarcodeCapture capture) {
    for (final Barcode barcode in capture.barcodes) {
      final String? uri = barcode.displayValue;
      if (uri != null) {
        if (!canParseWalletConnectUri(uri)) {
          return barcode;
        }
      }
    }
    return null;
  }
}
