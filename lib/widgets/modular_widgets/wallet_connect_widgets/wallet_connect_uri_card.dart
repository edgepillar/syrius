import 'package:material_ui/material_ui.dart';
import 'package:logging/logging.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The height of the link field and of the buttons beside it.
const double kWalletConnectFieldHeight = 44;

/// The WalletConnect link field and its Connect, the main action of the
/// Connected sites page. A link copied while the wallet runs lands here.
class WalletConnectUriCard extends StatefulWidget {
  const WalletConnectUriCard({super.key});

  @override
  State<WalletConnectUriCard> createState() => _WalletConnectUriCardState();
}

class _WalletConnectUriCardState extends State<WalletConnectUriCard> {
  TextEditingController _uriController = TextEditingController(
    text: kLastWalletConnectUriNotifier.value,
  );

  final GlobalKey<FormState> _uriKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      builder: (_, String? value, Widget? child) {
        if (value != null) {
          _uriController.text = value;
          kLastWalletConnectUriNotifier.value = null;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Form(
                key: _uriKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: InputField(
                  validator: (value) {
                    if (Uri.tryParse(value ?? '') != null) {
                      return null;
                    } else {
                      return 'URI invalid';
                    }
                  },
                  onChanged: (String value) {
                    setState(() {});
                  },
                  controller: _uriController,
                  inputtedTextStyle: monoStyle(
                    const TextStyle(fontSize: 13, color: AppColors.znnColor),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    iconSize: 16,
                    icon: const Icon(
                      Icons.content_paste,
                      color: AppColors.faint,
                    ),
                    onPressed: _onPastePressed,
                  ),
                  hintText: 'WalletConnect link',
                ),
              ),
            ),
            const SizedBox(width: 10),
            MyOutlinedButton(
              key: const Key('wc_connect'),
              text: 'Connect',
              onPressed: Uri.tryParse(_uriController.text) != null
                  ? () {
                      _pairWithDapp(
                        Uri.parse(_uriController.text),
                      );
                    }
                  : null,
              minimumSize: const Size(100, kWalletConnectFieldHeight),
            ),
          ],
        );
      },
      valueListenable: kLastWalletConnectUriNotifier,
    );
  }

  /// Pastes the clipboard into the field and rebuilds, so Connect follows
  /// what was pasted.
  void _onPastePressed() {
    ClipboardUtils.pasteToClipboard(
      callback: (String value) {
        if (!mounted) return;
        setState(() {
          _uriController.text = value;
        });
      },
    );
  }

  Future<void> _pairWithDapp(Uri uri) async {
    try {
      final PairingInfo pairingInfo = await sl.get<IWeb3WalletService>().pair(
        uri,
      );
      Logger(
        'WalletConnectPairingCard',
      ).log(Level.INFO, 'pairing info', pairingInfo.toJson());
      _uriController = TextEditingController();
      _uriKey.currentState?.reset();
      setState(() {});
    } catch (e, stackTrace) {
      Logger(
        'WalletConnectPairingCard',
      ).log(Level.INFO, 'pairing failed', e, stackTrace);
      await NotificationUtils.sendNotificationError(e, 'Pairing failed');
    }
  }
}
