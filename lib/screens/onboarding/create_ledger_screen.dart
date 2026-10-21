import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/ledger_wallet_file_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/screens/screens.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_file.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Writes the hardware wallet's file, then asks which node to use.
class CreateLedgerWalletScreen extends StatefulWidget {
  const CreateLedgerWalletScreen(
    this.deviceInfo,
    this.password, {
    this.progressBarNumLevels = 4,
    super.key,
  });
  final WalletDefinition deviceInfo;
  final String password;
  final int progressBarNumLevels;

  @override
  State<CreateLedgerWalletScreen> createState() =>
      _CreateLedgerWalletScreenState();
}

class _CreateLedgerWalletScreenState extends State<CreateLedgerWalletScreen> {
  late LedgerWalletFileBloc _ledgerWalletFileBloc;

  @override
  void initState() {
    super.initState();
    _ledgerWalletFileBloc = LedgerWalletFileBloc()
      ..getLedgerWalletPath(
        widget.deviceInfo.walletId,
        widget.password,
        widget.deviceInfo.walletName,
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: StreamBuilder<LedgerWalletFile?>(
          stream: _ledgerWalletFileBloc.stream,
          builder: (_, AsyncSnapshot<LedgerWalletFile?> snapshot) {
            if (snapshot.hasData) {
              return Column(
                children: <Widget>[
                  OnboardingStepPosition(
                    step: widget.progressBarNumLevels - 1,
                    steps: widget.progressBarNumLevels,
                  ),
                  Expanded(
                    child: NodeManagementScreen(
                      nodeConfirmationCallback: () {
                        NavigationUtils.push(
                          context,
                          WalletSuccessScreen(
                            progressBarNumLevels: widget.progressBarNumLevels,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            } else if (snapshot.hasError) {
              return SyriusErrorWidget(snapshot.error!);
            }
            return const Center(child: SyriusLoadingWidget());
          },
        ),
      ),
    );
  }
}
