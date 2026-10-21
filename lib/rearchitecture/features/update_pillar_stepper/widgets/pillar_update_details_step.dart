import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// Details step for updating a pillar.
class PillarUpdateDetailsStep extends StatelessWidget {
  /// Creates a [PillarUpdateDetailsStep].
  const PillarUpdateDetailsStep({
    required this.onCancelPressed,
    required this.onNextPressed,
    required this.pillarNameController,
    required this.pillarProducerController,
    required this.pillarRewardController,
    this.active = true,
    super.key,
  });

  /// Called when the user cancels the update flow.
  final VoidCallback onCancelPressed;

  /// Called when valid details can continue to the next step.
  final VoidCallback onNextPressed;

  /// Controller containing the immutable pillar name.
  final TextEditingController pillarNameController;

  /// Controller containing the reward address.
  final TextEditingController pillarRewardController;

  /// Controller containing the producer address.
  final TextEditingController pillarProducerController;

  /// Whether this is the step shown.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        pillarRewardController,
        pillarProducerController,
      ]),
      builder: (BuildContext context, _) {
        final double gap = AppTokens.of(context).cardGap;
        // An address reads left to right in every language.
        final TextStyle address = accFieldTextStyle(context, mono: true);
        final TextAlign addressAlign = ltrTextAlign(context);
        final bool valid = _arePillarDetailsValid();
        return TokenStepFrame(
          active: active,
          onSubmit: valid ? onNextPressed : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AccField(
                label: context.l10n.pillarName,
                child: TextField(
                  controller: pillarNameController,
                  enabled: false,
                  style: accFieldTextStyle(context),
                ),
              ),
              SizedBox(height: gap),
              AccField(
                label: context.l10n.pillarRewardAddress,
                help: context.l10n.addressToCollectRewards,
                child: TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: pillarRewardController,
                  validator: InputValidators.checkAddress,
                  style: address,
                  textDirection: TextDirection.ltr,
                  textAlign: addressAlign,
                  decoration: InputDecoration(
                    suffixIcon: FieldSuffixButtons(
                      controller: pillarRewardController,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              AccField(
                label: context.l10n.pillarProducerAddress,
                help: context.l10n.addressToProduceMomentums,
                child: TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: pillarProducerController,
                  validator: InputValidators.validatePillarMomentumAddress,
                  style: address,
                  textDirection: TextDirection.ltr,
                  textAlign: addressAlign,
                  decoration: InputDecoration(
                    suffixIcon: FieldSuffixButtons(
                      controller: pillarProducerController,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // The frame's quiet action is Back, and the first step has nothing
          // to go back to: its way out is Cancel, in the same place and tone.
          primary: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                style: quietButtonStyle(context),
                onPressed: onCancelPressed,
                child: Text(context.l10n.cancel),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: valid ? onNextPressed : null,
                child: Text(context.l10n.next),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _arePillarDetailsValid() =>
      InputValidators.checkAddress(pillarRewardController.text) == null &&
      InputValidators.validatePillarMomentumAddress(
            pillarProducerController.text,
          ) ==
          null;
}
