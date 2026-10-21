import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';

/// Step that collects token mint and burn options.
class TokenMintableBurnableStep extends StatefulWidget {
  /// Creates a [TokenMintableBurnableStep].
  const TokenMintableBurnableStep({
    required this.onBackPressed,
    required this.onContinuePressed,
    required this.tokenData,
    this.active = true,
    super.key,
  });

  /// Called when the user wants to go back.
  final VoidCallback onBackPressed;

  /// Called when the user continues.
  final VoidCallback onContinuePressed;

  /// Token data draft updated by this step.
  final ValueNotifier<NewTokenData> tokenData;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<TokenMintableBurnableStep> createState() =>
      _TokenMintableBurnableStepState();
}

class _TokenMintableBurnableStepState extends State<TokenMintableBurnableStep> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NewTokenData>(
      valueListenable: widget.tokenData,
      builder: (BuildContext context, NewTokenData data, _) => TokenStepFrame(
        active: widget.active,
        onBack: widget.onBackPressed,
        onSubmit: widget.onContinuePressed,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TokenStepToggle(
              checkboxKey: const Key('token_mintable_checkbox'),
              adaptive: true,
              label: context.l10n.mintable,
              help: context.l10n.tokenMintableTooltip,
              value: data.isMintable,
              onChanged: (bool value) {
                widget.tokenData.value = widget.tokenData.value.copyWith(
                  isMintable: value,
                );
              },
            ),
            TokenStepToggle(
              checkboxKey: const Key('token_burnable_checkbox'),
              adaptive: true,
              label: context.l10n.burnableToken,
              help: context.l10n.tokenBurnTooltip,
              value: data.isBurnable,
              onChanged: (bool value) {
                widget.tokenData.value = widget.tokenData.value.copyWith(
                  isBurnable: value,
                );
              },
            ),
          ],
        ),
        primary: OutlinedButton(
          key: const Key('token_options_next_button'),
          onPressed: widget.onContinuePressed,
          child: Text(context.l10n.continueText),
        ),
      ),
    );
  }
}
