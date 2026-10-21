import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Step that displays the token issuance address and required ZNN fee.
class TokenZnnCheckStep extends StatelessWidget {
  /// Creates a [TokenZnnCheckStep].
  const TokenZnnCheckStep({
    required this.accountInfo,
    required this.addressController,
    required this.onContinuePressed,
    required this.tokenData,
    this.active = true,
    super.key,
  });

  /// Account info for the selected address.
  final AccountInfo accountInfo;

  /// Selected address controller displayed by the disabled address field.
  final TextEditingController addressController;

  /// Called when the user can continue to token details.
  final VoidCallback onContinuePressed;

  /// Token data draft updated by this step.
  final ValueNotifier<NewTokenData> tokenData;

  /// Whether this is the step shown.
  final bool active;

  void _onContinuePressed() {
    tokenData.value = tokenData.value.copyWith(
      address: addressController.text,
    );
    onContinuePressed();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool enough =
        accountInfo.getBalance(kZnnCoin.tokenStandard) >=
        tokenZtsIssueFeeInZnn;
    return TokenStepFrame(
      active: active,
      onSubmit: enough ? _onContinuePressed : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AccField(
            label: context.l10n.address,
            help: context.l10n.tokenIssuanceAddressDescription,
            child: DisabledAddressField(addressController),
          ),
          // What the address holds, under the field: it is what decides
          // whether the step can go on.
          AccBalanceLine(kZnnCoin, accountInfo),
          SizedBox(height: tokens.cardGap),
          DottedBorderInfoWidget(
            text: context.l10n.burnTokenIssueFee(
              cardAmount(tokenZtsIssueFeeInZnn, coinDecimals, ''),
              kZnnCoin.symbol,
            ),
            borderColor: tokens.znnInk,
          ),
        ],
      ),
      primary: OutlinedButton(
        key: const Key('token_znn_next_button'),
        onPressed: enough ? _onContinuePressed : null,
        child: Text(context.l10n.continueText),
      ),
    );
  }
}
