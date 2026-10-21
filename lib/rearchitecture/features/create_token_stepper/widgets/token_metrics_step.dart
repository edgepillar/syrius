import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Step that collects token decimal and supply metrics.
class TokenMetricsStep extends StatefulWidget {
  /// Creates a [TokenMetricsStep].
  const TokenMetricsStep({
    required this.maxSupplyController,
    required this.onBackPressed,
    required this.onContinuePressed,
    required this.tokenData,
    required this.totalSupplyController,
    this.active = true,
    super.key,
  });

  /// Controller for max supply input.
  final TextEditingController maxSupplyController;

  /// Called when the user wants to go back.
  final VoidCallback onBackPressed;

  /// Called when the user can continue.
  final VoidCallback onContinuePressed;

  /// Token data draft updated by this step.
  final ValueNotifier<NewTokenData> tokenData;

  /// Controller for total supply input.
  final TextEditingController totalSupplyController;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<TokenMetricsStep> createState() => _TokenMetricsStepState();
}

class _TokenMetricsStepState extends State<TokenMetricsStep> {
  String get _maxSupply => widget.maxSupplyController.text;

  bool get _isMintable => widget.tokenData.value.isMintable;

  int get _decimals => widget.tokenData.value.decimals;

  String? get _maxSupplyError => _isMintable
      ? InputValidators.correctValue(
          _maxSupply,
          kBigP255m1,
          _decimals,
          kMinTokenTotalMaxSupply,
          canBeEqualToMin: true,
        )
      : InputValidators.isMaxSupplyZero(_maxSupply);

  String get _totalSupply => widget.totalSupplyController.text;

  String? get _totalSupplyError => InputValidators.correctValue(
    _totalSupply,
    _isMintable
        ? _maxSupply.isNotEmpty
              ? _maxSupply.extractDecimals(_decimals)
              : kBigP255m1
        : kBigP255m1,
    _decimals,
    _isMintable ? BigInt.zero : kMinTokenTotalMaxSupply,
    canBeEqualToMin: true,
  );

  @override
  Widget build(BuildContext context) {
    // The decimals and the mintable choice bound both supplies, so the step
    // is rebuilt for them as well as for what is typed.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.tokenData,
        widget.totalSupplyController,
        widget.maxSupplyController,
      ]),
      builder: (BuildContext context, _) {
        final AppTokens tokens = AppTokens.of(context);
        final TextStyle amount = accFieldTextStyle(context, mono: true);
        final bool valid = _areTokenMetricsCorrect();
        return TokenStepFrame(
          active: widget.active,
          onBack: widget.onBackPressed,
          onSubmit: valid ? _onContinuePressed : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CustomSlider(
                activeColor: tokens.znnInk,
                description: context.l10n.numberOfDecimals(_decimals),
                // What was chosen before, when the step is built again.
                startValue: _decimals.toDouble(),
                min: 0,
                maxValue: 18,
                sliderKey: const Key('token_decimals_slider'),
                callback: (double value) {
                  widget.tokenData.value = widget.tokenData.value.copyWith(
                    decimals: value.toInt(),
                  );
                },
              ),
              SizedBox(height: tokens.cardGap),
              if (_isMintable) ...<Widget>[
                AccField(
                  label: context.l10n.maxSupply,
                  // A refused key, a comma for one, says so under the field,
                  // over what the validator says.
                  child: AmountRefusalScope(
                    controller: widget.maxSupplyController,
                    builder: (_, String? refusal) => TextField(
                      key: const Key('token_max_supply_field'),
                      inputFormatters:
                          FormatUtils.getAmountTextInputFormatters(
                            widget.maxSupplyController.text,
                          ),
                      controller: widget.maxSupplyController,
                      style: amount,
                      decoration: InputDecoration(
                        errorText:
                            refusal ??
                            (_maxSupply.isNotEmpty ? _maxSupplyError : null),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.cardGap),
              ],
              AccField(
                label: context.l10n.totalSupply,
                child: AmountRefusalScope(
                  controller: widget.totalSupplyController,
                  builder: (_, String? refusal) => TextField(
                    key: const Key('token_total_supply_field'),
                    inputFormatters: FormatUtils.getAmountTextInputFormatters(
                      widget.totalSupplyController.text,
                    ),
                    controller: widget.totalSupplyController,
                    style: amount,
                    decoration: InputDecoration(
                      errorText:
                          refusal ??
                          (_totalSupply.isNotEmpty ? _totalSupplyError : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // The key stays on a wrapper: the button is looked up under it.
          primary: KeyedSubtree(
            key: const Key('token_metrics_next_button'),
            child: OutlinedButton(
              onPressed: valid ? _onContinuePressed : null,
              child: Text(context.l10n.continueText),
            ),
          ),
        );
      },
    );
  }

  bool _areTokenMetricsCorrect() =>
      (!_isMintable || _maxSupplyError == null) && _totalSupplyError == null;

  void _onContinuePressed() {
    widget.tokenData.value = widget.tokenData.value.copyWith(
      decimals: _decimals,
      maxSupply: _isMintable
          ? _maxSupply.extractDecimals(_decimals)
          : _totalSupply.extractDecimals(_decimals),
      totalSupply: _totalSupply.extractDecimals(_decimals),
    );
    widget.onContinuePressed();
  }
}
