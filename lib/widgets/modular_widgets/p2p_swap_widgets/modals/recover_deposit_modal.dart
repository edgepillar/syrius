import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/dashboard/balance_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/p2p_swap/htlc_swap/recover_htlc_swap_funds_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/instruction_button.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/important_text_container.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_fields.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/base_modal.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Recovers a deposit by its id, for a swap started on a computer that is
/// no longer at hand.
class RecoverDepositModal extends StatefulWidget {
  /// Creates the dialog.
  const RecoverDepositModal({
    super.key,
  });

  @override
  State<RecoverDepositModal> createState() => _RecoverDepositModalState();
}

class _RecoverDepositModalState extends State<RecoverDepositModal> {
  final TextEditingController _depositIdController = TextEditingController();

  String? _errorText;

  bool _isLoading = false;
  bool _isPendingFunds = false;

  @override
  void initState() {
    super.initState();
    unawaited(sl.get<BalanceBloc>().getBalanceForAllAddresses());
  }

  @override
  void dispose() {
    _depositIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseModal(
      title: _getTitle(),
      child: _getContent(),
    );
  }

  String _getTitle() {
    return _isPendingFunds ? '' : 'Recover deposit';
  }

  Widget _getContent() {
    return _isPendingFunds ? _getPendingFundsView() : _getSearchView();
  }

  Widget _getPendingFundsView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 10),
        SizedBox(
          width: 64,
          height: 64,
          child: SvgPicture.asset(
            'assets/svg/ic_completed_symbol.svg',
            colorFilter: const ColorFilter.mode(
              AppColors.znnColor,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recovery sent. Funds arrive shortly.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _getSearchView() {
    final TextStyle dim = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 20),
        Text(
          'Lost the computer a swap was started on? Recover the deposit '
          'with its ID. The tutorial shows how to find the ID on an '
          'explorer.',
          style: dim,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: dim.color,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => NavigationUtils.openUrl(kP2pSwapTutorialLink),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Swap tutorial'),
          ),
        ),
        const SizedBox(height: 16),
        Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: InputField(
            onChanged: (String value) {
              setState(() {});
            },
            validator: InputValidators.checkHash,
            controller: _depositIdController,
            suffixIcon: RawMaterialButton(
              shape: const CircleBorder(),
              onPressed: () => ClipboardUtils.pasteToClipboard(
                callback: (String value) {
                  _depositIdController.text = value;
                  setState(() {});
                },
              ),
              child: const Icon(
                Icons.content_paste,
                color: AppColors.faint,
                size: 15,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              maxWidth: 45,
              maxHeight: 20,
            ),
            hintText: 'Deposit ID',
            contentLeftPadding: 10,
          ),
        ),
        const SizedBox(height: 20),
        Visibility(
          visible: _errorText != null,
          child: Column(
            children: <Widget>[
              ImportantTextContainer(
                text: _errorText ?? '',
                showBorder: true,
              ),
              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
        _getRecoverButton(),
      ],
    );
  }

  Widget _getRecoverButton() {
    return ViewModelBuilder<RecoverHtlcSwapFundsBloc>.reactive(
      onViewModelReady: (RecoverHtlcSwapFundsBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) async {
            if (event is AccountBlockTemplate) {
              setState(() {
                _isPendingFunds = true;
              });
            }
          },
          onError: (Object error) {
            setState(() {
              _errorText = error.toString();
              _isLoading = false;
            });
          },
        );
      },
      builder: (_, RecoverHtlcSwapFundsBloc model, _) => InstructionButton(
        text: 'Recover deposit',
        isEnabled: _isHashValid(),
        isLoading: _isLoading,
        loadingText: 'Sending',
        instructionText: 'Enter the deposit ID',
        onPressed: () {
          setState(() {
            _isLoading = true;
            _errorText = null;
          });
          unawaited(
            model.recoverFunds(htlcId: Hash.parse(_depositIdController.text)),
          );
        },
      ),
      viewModelBuilder: RecoverHtlcSwapFundsBloc.new,
    );
  }

  bool _isHashValid() =>
      InputValidators.checkHash(_depositIdController.text) == null;
}
