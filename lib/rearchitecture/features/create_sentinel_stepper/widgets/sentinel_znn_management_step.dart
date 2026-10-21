import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// ZNN management step for the sentinel creation flow.
class SentinelZnnManagementStep extends StatelessWidget {
  /// Creates a [SentinelZnnManagementStep].
  const SentinelZnnManagementStep({
    required this.accountInfo,
    required this.addressController,
    required this.onNextPressed,
    required this.znnAmountController,
    this.onBackPressed,
    this.active = true,
    super.key,
  });

  /// Account balances for the selected address.
  final AccountInfo accountInfo;

  /// Selected address controller displayed by the disabled address field.
  final TextEditingController addressController;

  /// Called when the user can continue to the next step.
  final VoidCallback onNextPressed;

  /// Controller containing the required ZNN amount.
  final TextEditingController znnAmountController;

  /// Called when the user wants to go back. No Back button when null.
  final VoidCallback? onBackPressed;

  /// Whether this is the step shown.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool enough = accountInfo.znn()! >= sentinelRegisterZnnAmount;
    return TokenStepFrame(
      active: active,
      onBack: onBackPressed,
      onSubmit: enough ? onNextPressed : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AccField(
            label: context.l10n.address,
            child: DisabledAddressField(addressController),
          ),
          // What the address holds, under the field: it is what decides
          // whether the step can go on.
          AccBalanceLine(kZnnCoin, accountInfo),
          SizedBox(height: tokens.cardGap),
          // What registering locks. It is not typed: the network sets it.
          AccField(
            label: context.l10n.createPillarCollateralLabel,
            child: TextField(
              enabled: false,
              controller: znnAmountController,
              style: accFieldTextStyle(context, mono: true),
              // An amount reads left to right in every language.
              textDirection: TextDirection.ltr,
              textAlign: ltrTextAlign(context),
              decoration: InputDecoration(
                suffixText: kZnnCoin.symbol,
                suffixStyle: accFieldTextStyle(
                  context,
                ).copyWith(color: tokens.znnInk),
              ),
            ),
          ),
          SizedBox(height: tokens.cardGap),
          DottedBorderInfoWidget(
            text: context.l10n.disassembleSentinelToUnlockCoin(kZnnCoin.symbol),
            borderColor: tokens.znnInk,
          ),
        ],
      ),
      // The key stays on a wrapper: the button is looked up under it.
      primary: KeyedSubtree(
        key: const Key('sentinel_znn_next_button'),
        child: OutlinedButton(
          onPressed: enough ? onNextPressed : null,
          child: Text(context.l10n.next),
        ),
      ),
    );
  }
}
