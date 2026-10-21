import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/screens/export/export_wallet_info_screen.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The second export step: the key the Seed Vault is encrypted with, then
/// where to save the file.
class ExportWalletPasswordScreen extends StatefulWidget {
  const ExportWalletPasswordScreen(
    this.seed, {
    this.backupWalletFlow = false,
    super.key,
  });
  final String seed;
  final bool backupWalletFlow;

  @override
  State<ExportWalletPasswordScreen> createState() =>
      _ExportWalletPasswordScreenState();
}

class _ExportWalletPasswordScreenState
    extends State<ExportWalletPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _passwordKey = GlobalKey();
  final GlobalKey<FormState> _confirmPasswordKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SettingsScreenFrame(
      title: 'Seed Vault key',
      note:
          'The key that opens the file. At least 8 characters, with an upper '
          'and a lower case letter, a number and a symbol.',
      actions: <Widget>[
        const ScreenBackAction(),
        _buildExportButton(),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ExportStepLabel(step: 2),
          const SizedBox(height: kSettingFormGap),
          Form(
            key: _passwordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              hintText: 'Seed Vault key',
              controller: _passwordController,
              validator: InputValidators.validatePassword,
              onChanged: (String value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: kSettingFormGap),
          Form(
            key: _confirmPasswordKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PasswordInputField(
              hintText: 'Repeat key',
              controller: _confirmPasswordController,
              validator: (String? value) => InputValidators.checkPasswordMatch(
                _passwordController.text,
                value,
              ),
              onChanged: (String value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: kSettingFormGap + 4),
          PasswordProgressBar(
            password: _passwordController.text,
            passwordKey: _passwordKey,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton(
      key: const Key('export_seed_vault_export'),
      style: OutlinedButton.styleFrom(minimumSize: kScreenActionSize),
      onPressed: _arePasswordsValid() ? _onExportPressed : null,
      child: const Text('Export'),
    );
  }

  Future<void> _onExportPressed() async {
    String? initialDirectory;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      initialDirectory = (await getApplicationDocumentsDirectory()).path;
    }
    final String stamp = FormatUtils.fileStamp(DateTime.now());
    final FileSaveLocation? walletPath = await getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'file',
          extensions: <String>['json'],
        ),
      ],
      initialDirectory: initialDirectory,
      suggestedName: 'zenon-syrius-wallet-backup-$stamp.json',
    );
    if (walletPath != null) {
      final KeyStoreManager keyStoreManager = KeyStoreManager(
        walletPath: Directory(
          path.dirname(walletPath.path),
        ),
      );
      final KeyStore keyStore =
          await BackgroundKeyStore.fromMnemonic(widget.seed);
      await keyStoreManager.saveKeyStore(
        keyStore,
        _passwordController.text,
        name: path.basename(walletPath.path),
      );
      if (widget.backupWalletFlow) {
        await _sendSuccessNotification(walletPath.path);
      } else {
        _updateExportedSeedList();
      }
      if (!mounted) return;
      NavigationUtils.popRepeated(context, 2);
    }
  }

  void _updateExportedSeedList() {
    final List<String> exportedSeeds = <String>[];
    exportedSeeds.addAll(
      Provider.of<ValueNotifier<List<String>>>(
        context,
        listen: false,
      ).value,
    );
    exportedSeeds.add(widget.seed);
    Provider.of<ValueNotifier<List<String>>>(
      context,
      listen: false,
    ).value = exportedSeeds;
  }

  Future<void> _sendSuccessNotification(String path) async {
    await sl.get<NotificationsBloc>().addNotification(
      WalletNotification(
        title: 'Seed Vault successfully exported',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: 'The Seed Vault was successfully exported to $path',
        type: NotificationType.paymentSent,
      ),
    );
  }

  bool _arePasswordsValid() {
    return InputValidators.validatePassword(_passwordController.text) == null &&
        InputValidators.checkPasswordMatch(
              _passwordController.text,
              _confirmPasswordController.text,
            ) ==
            null;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
