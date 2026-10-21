import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Step that collects token name, symbol, and domain.
class TokenDetailsStep extends StatefulWidget {
  /// Creates a [TokenDetailsStep].
  const TokenDetailsStep({
    required this.onBackPressed,
    required this.onContinuePressed,
    required this.tokenData,
    required this.tokenDomainController,
    required this.tokenNameController,
    required this.tokenSymbolController,
    this.active = true,
    super.key,
  });

  /// Called when the user wants to go back.
  final VoidCallback onBackPressed;

  /// Called when the user can continue.
  final VoidCallback onContinuePressed;

  /// Token data draft updated by this step.
  final ValueNotifier<NewTokenData> tokenData;

  /// Controller for token domain input.
  final TextEditingController tokenDomainController;

  /// Controller for token name input.
  final TextEditingController tokenNameController;

  /// Controller for token symbol input.
  final TextEditingController tokenSymbolController;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<TokenDetailsStep> createState() => _TokenDetailsStepState();
}

class _TokenDetailsStepState extends State<TokenDetailsStep> {
  // TODO(maznnwell): the error messages from of validators seem to be mixed up
  String? get _nameError =>
      Validations.tokenName(widget.tokenNameController.text);

  String? get _symbolError =>
      Validations.tokenSymbol(widget.tokenSymbolController.text);

  String? get _domainError =>
      InputValidators.checkUrl(widget.tokenDomainController.text);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.tokenNameController,
        widget.tokenSymbolController,
        widget.tokenDomainController,
      ]),
      builder: (BuildContext context, _) {
        final double gap = AppTokens.of(context).cardGap;
        final TextStyle text = accFieldTextStyle(context);
        final bool valid = _areTokenDetailsCorrect();
        return TokenStepFrame(
          active: widget.active,
          onBack: widget.onBackPressed,
          onSubmit: valid ? _onContinuePressed : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AccField(
                label: context.l10n.tokenName,
                child: TextField(
                  key: const Key('token_name_field'),
                  controller: widget.tokenNameController,
                  style: text,
                  decoration: InputDecoration(
                    errorText: widget.tokenNameController.text.isNotEmpty
                        ? _nameError
                        : null,
                  ),
                ),
              ),
              SizedBox(height: gap),
              AccField(
                label: context.l10n.tokenSymbol,
                child: TextField(
                  key: const Key('token_symbol_field'),
                  controller: widget.tokenSymbolController,
                  style: text,
                  decoration: InputDecoration(
                    errorText: widget.tokenSymbolController.text.isNotEmpty
                        ? _symbolError
                        : null,
                  ),
                ),
              ),
              SizedBox(height: gap),
              // Blockchain seems to accept only "testing.com" URLs, not
              // "https://testing.com" also
              AccField(
                label: context.l10n.tokenDomain,
                child: TextField(
                  key: const Key('token_domain_field'),
                  controller: widget.tokenDomainController,
                  style: text,
                  decoration: InputDecoration(
                    errorText: widget.tokenDomainController.text.isNotEmpty
                        ? _domainError
                        : null,
                    hintText: context.l10n.createTokenDomainHint,
                    suffixIcon: FieldSuffixButtons(
                      controller: widget.tokenDomainController,
                    ),
                  ),
                ),
              ),
            ],
          ),
          primary: OutlinedButton(
            key: const Key('token_details_next_button'),
            onPressed: valid ? _onContinuePressed : null,
            child: Text(context.l10n.continueText),
          ),
        );
      },
    );
  }

  bool _areTokenDetailsCorrect() =>
      _nameError == null && _symbolError == null && _domainError == null;

  void _onContinuePressed() {
    widget.tokenData.value = widget.tokenData.value.copyWith(
      tokenDomain: widget.tokenDomainController.text,
      tokenName: widget.tokenNameController.text,
      tokenSymbol: widget.tokenSymbolController.text,
    );
    widget.onContinuePressed();
  }
}
