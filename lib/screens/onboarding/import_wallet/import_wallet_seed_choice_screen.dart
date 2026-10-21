import 'package:material_ui/material_ui.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/seed/seed_cell.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class ImportWalletSeedChoiceScreen extends StatefulWidget {
  const ImportWalletSeedChoiceScreen({super.key});

  @override
  State<ImportWalletSeedChoiceScreen> createState() =>
      _ImportWalletSeedChoiceScreenState();
}

class _ImportWalletSeedChoiceScreenState
    extends State<ImportWalletSeedChoiceScreen> {
  bool _isSeed12Selected = false;

  String? _walletFilePath;

  final GlobalKey<SeedGridState> _seedGridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _openHiveAddressesBox();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      // If the seed is imported from a file, an extra step to decrypt the
      // file is needed.
      steps: _walletFilePath == null ? 4 : 5,
      title: 'Import your wallet',
      subtitle: 'Type your seed, or drop a wallet file',
      onBack: _onBackPressed,
      maxWidth: 880,
      primary: _getContinueButton(),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 40,
            child: _getSeedChoice(),
          ),
          const SizedBox(height: 16),
          _getSeedGrid(),
          const SizedBox(height: 20),
          _getUploadFileContainer(),
        ],
      ),
    );
  }

  Widget _getUploadFileContainer() {
    // As wide as the grid above it: the full column for 24 words, three
    // cells for 12.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _isSeed12Selected
            ? 3 * kSeedWordCellWidth + 2 * kSeedCellGap
            : double.infinity,
      ),
      child: SelectFileWidget(
        validator: WalletFile.isKeyStoreFile,
        invalidFileMessage: 'Not a Syrius wallet file',
        // The path alone enables Continue. Clearing the grid's own flag here
        // as well left Continue enabled after the path was dropped again.
        onPathFoundCallback: (String path) {
          setState(() {
            _walletFilePath = path;
          });
        },
        // A refused file replaces an accepted one in the zone, so the
        // earlier path goes too: Continue would import a file the screen no
        // longer shows.
        onFileRefusedCallback: () {
          setState(() {
            _walletFilePath = null;
          });
        },
      ),
    );
  }

  Widget _getContinueButton() {
    return OnboardingButton(
      onPressed:
          _seedGridKey.currentState != null &&
                  _seedGridKey.currentState!.continueButtonDisabled == false ||
              _walletFilePath != null
          ? () {
              if (_seedGridKey.currentState!.continueButtonDisabled == false &&
                  _walletFilePath == null) {
                if (Mnemonic.validateMnemonic(
                  _seedGridKey.currentState!.getSeedWords,
                )) {
                  NavigationUtils.push(
                    context,
                    ImportWalletPasswordScreen(
                      _seedGridKey.currentState!.getSeed,
                      progressBarNumLevels: 4,
                    ),
                  );
                } else {
                  showDialog<void>(
                    context: context,
                    builder: (BuildContext context) => DialogCard(
                      title: 'Seed not valid',
                      body: const Text('Check the words and their order'),
                      actions: <Widget>[
                        OutlinedButton(
                          child: const Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                }
              } else if (_walletFilePath != null) {
                NavigationUtils.push(
                  context,
                  ImportWalletDecryptScreen(_walletFilePath!),
                );
              }
            }
          : null,
      text: 'Continue',
    );
  }

  void _onBackPressed() {
    Navigator.popUntil(
      context,
      ModalRoute.withName(AccessWalletScreen.route),
    );
  }

  Widget _getSeedChoice() {
    return SeedChoice(
      isSeed12Selected: _isSeed12Selected,
      onSeed24Selected: () {
        setState(() {
          _isSeed12Selected = false;
          _seedGridKey.currentState!.changedSeed(
            List.generate(24, (int index) => ''),
          );
        });
      },
      onSeed12Selected: () {
        setState(() {
          _isSeed12Selected = true;
          _seedGridKey.currentState!.changedSeed(
            List.generate(12, (int index) => ''),
          );
        });
      },
    );
  }

  SeedGrid _getSeedGrid() {
    return SeedGrid(
      _isSeed12Selected
          ? List.generate(
              12,
              (int index) => '',
            )
          : List.generate(
              24,
              (int index) => '',
            ),
      key: _seedGridKey,
      isContinueButtonDisabled: true,
      onTextFieldChangedCallback: () {
        setState(() {});
      },
    );
  }

  void _openHiveAddressesBox() {
    Hive.boxExists(kAddressesBox).then(
      (bool addressesBoxExists) {
        if (addressesBoxExists) {
          Hive.openBox(kAddressesBox).then(
            (Box addressesBox) => addressesBox.clear(),
          );
        }
      },
    );
  }
}
