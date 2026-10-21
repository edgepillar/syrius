import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// The first of the two export steps: what a Seed Vault is, and the promise
/// to keep it, without which the next step stays shut.
class ExportWalletInfoScreen extends StatefulWidget {
  const ExportWalletInfoScreen(
    this.seed, {
    this.backupWalletFlow = false,
    super.key,
  });
  final String seed;
  final bool backupWalletFlow;

  @override
  State<ExportWalletInfoScreen> createState() => _ExportWalletInfoScreenState();
}

class _ExportWalletInfoScreenState extends State<ExportWalletInfoScreen> {
  bool? _isSecure = false;

  @override
  Widget build(BuildContext context) {
    return SettingsScreenFrame(
      title: 'Export Seed Vault',
      note:
          'A Seed Vault is a file of the seed, encrypted with a key you '
          'choose next. Keep the file and the key apart and offline. '
          'Lose either and the funds are lost.',
      actions: <Widget>[
        const ScreenBackAction(),
        OutlinedButton(
          key: const Key('export_seed_vault_continue'),
          style: OutlinedButton.styleFrom(minimumSize: kScreenActionSize),
          onPressed: _isSecure!
              ? () {
                  NavigationUtils.push(
                    context,
                    ExportWalletPasswordScreen(
                      widget.seed,
                      backupWalletFlow: widget.backupWalletFlow,
                    ),
                  );
                }
              : null,
          child: const Text('Continue'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ExportStepLabel(step: 1),
          const SizedBox(height: kSettingFormGap),
          _SecurePromise(
            value: _isSecure!,
            onChanged: (bool value) {
              setState(() {
                _isSecure = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Where the person is in the export: "STEP 1 OF 2".
class ExportStepLabel extends StatelessWidget {
  /// Creates the label for [step] of the two.
  const ExportStepLabel({required this.step, super.key});

  /// The step, from 1.
  final int step;

  @override
  Widget build(BuildContext context) {
    return Text('STEP $step OF 2', style: ledgerLabelStyle(context));
  }
}

/// The promise to store the vault and its key, as one row that is pressed
/// anywhere: the box alone is a small target for a mouse.
class _SecurePromise extends StatelessWidget {
  const _SecurePromise({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(kCardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('export_seed_vault_promise'),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
          child: Row(
            children: <Widget>[
              // The row is the control; the box only shows its state.
              ExcludeFocus(
                child: IgnorePointer(
                  child: Checkbox(
                    value: value,
                    onChanged: (bool? value) {},
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'I will keep the Seed Vault and its key safe',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
