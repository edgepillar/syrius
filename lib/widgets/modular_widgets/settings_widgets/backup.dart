import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Backing up the seed: as an encrypted Seed Vault file (recommended), or
/// shown on screen after the password. Neither exists for a hardware
/// wallet, whose seed never leaves the device.
class BackupWidget extends StatefulWidget {
  const BackupWidget({super.key});

  @override
  State<BackupWidget> createState() => _BackupWidgetState();
}

class _BackupWidgetState extends State<BackupWidget> {
  @override
  Widget build(BuildContext context) {
    final bool hardware = kWalletFile!.isHardwareWallet;
    return Panel(
      title: 'Backup',
      shrinkWrap: true,
      child: SettingsList(
        children: <Widget>[
          SettingRow(
            label: 'Seed Vault',
            hint: hardware
                ? 'Not on a hardware wallet'
                : 'An encrypted file of the seed',
            trailing: SecondaryAction(
              child: SettingsButton(
                onPressed: !hardware ? _onBackupWalletPressed : null,
                text: 'Export',
              ),
            ),
          ),
          SettingRow(
            label: 'Seed phrase',
            hint: hardware
                ? 'Not on a hardware wallet'
                : 'Shown on screen, in clear',
            trailing: SecondaryAction(
              child: SettingsButton(
                onPressed: !hardware ? _onDumpMnemonicPressed : null,
                text: 'Show',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBackupWalletPressed() async {
    kWalletFile!
        .access((Wallet wallet) => Future.value((wallet as KeyStore).mnemonic!))
        .then(
          (String value) => NavigationUtils.push(
            context,
            ExportWalletInfoScreen(
              value,
              backupWalletFlow: true,
            ),
          ),
        );
  }

  void _onDumpMnemonicPressed() {
    NavigationUtils.push(
      context,
      const DumpMnemonicScreen(),
    );
  }
}
