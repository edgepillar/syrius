import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/zap.dart'
    show ZapReceivedMessage;
import 'package:zenon_syrius_wallet_flutter/widgets/modals.dart'
    show showFrostedDialog;
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show Address;

/// Labels the sample directly inside the message area of the original card.
const String homeZapPreviewMessage =
    'Sample Zap message for visual inspection.';

final String _sender = Address('z', <int>[0, ...List<int>.filled(19, 5)])
    .toString();

/// Opens the original message surface using presentation data in the harness.
Future<void> showHomeZapPreview(BuildContext context) async {
  await showFrostedDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => ZapReceivedMessage(
      sender: _sender,
      znn: BigInt.from(100000000),
      qsr: BigInt.from(1000000000),
      message: homeZapPreviewMessage,
      onClose: () {
        if (ModalRoute.of(dialogContext)?.isCurrent == true) {
          Navigator.of(dialogContext).pop();
        }
      },
    ),
  );
}
