import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/input_validators.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dropdown/coin_dropdown.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/amount_suffix_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/input_field.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class AmountInputField extends StatefulWidget {

  const AmountInputField({
    required this.controller,
    required this.accountInfo,
    this.onChanged,
    this.valuePadding,
    this.textColor,
    this.initialToken,
    this.hintText = 'Amount',
    this.enabled = true,
    super.key,
  });
  final TextEditingController controller;
  final AccountInfo accountInfo;
  final void Function(Token, bool)? onChanged;
  final double? valuePadding;
  final Color? textColor;
  final Token? initialToken;
  final String hintText;
  final bool enabled;

  @override
  State createState() {
    return _AmountInputFieldState();
  }
}

class _AmountInputFieldState extends State<AmountInputField> {
  final List<Token?> _tokensWithBalance = <Token?>[];
  Token? _selectedToken;

  @override
  void initState() {
    super.initState();
    _tokensWithBalance.addAll(kDualCoin);
    _addTokensWithBalance();
    _selectedToken = widget.initialToken ?? kDualCoin.first;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.key,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // The line for a refused key is the InputField's own: it finds the
      // amount formatter among its formatters (AmountRefusalScope).
      child: InputField(
        onChanged: (String value) {
          setState(() {});
        },
        inputFormatters: FormatUtils.getAmountTextInputFormatters(
          widget.controller.text,
        ),
        validator: (String? value) => InputValidators.correctValue(
          value,
          widget.accountInfo.getBalance(
            _selectedToken!.tokenStandard,
          ),
          _selectedToken!.decimals,
          BigInt.zero,
        ),
        controller: widget.controller,
        // An amount is typed and read left to right in every language, from
        // the app's start. The hint, the suffix and the error line keep the
        // app's direction.
        textDirection: TextDirection.ltr,
        textAlign: ltrTextAlign(context),
        suffixIcon: _getAmountSuffix(),
        hintText: widget.hintText,
        contentLeftPadding: widget.valuePadding ?? kContentPadding,
        enabled: widget.enabled,
      ),
      onChanged: () => (widget.onChanged != null)
          ? widget.onChanged!(
              _selectedToken!,
              (_isInputValid()) ? true : false,
            )
          : null,
    );
  }

  Widget _getAmountSuffix() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _getCoinDropdown(),
        const SizedBox(
          width: 5,
        ),
        AmountSuffixMaxWidget(
          onPressed: _onMaxPressed,
          context: context,
        ),
        const SizedBox(
          width: 5,
        ),
      ],
    );
  }

  void _onMaxPressed() => setState(() {
        final BigInt maxBalance = widget.accountInfo.getBalance(
          _selectedToken!.tokenStandard,
        );
        widget.controller.text =
            maxBalance.addDecimals(_selectedToken!.decimals);
      });

  Widget _getCoinDropdown() => CoinDropdown(
        _tokensWithBalance,
        _selectedToken!,
        (Token? value) {
          if (_selectedToken != value) {
            setState(
              () {
                _selectedToken = value;
                _isInputValid();
                widget.onChanged!(_selectedToken!, _isInputValid());
              },
            );
          }
        },
      );

  void _addTokensWithBalance() {
    for (final BalanceInfoListItem balanceInfo in widget.accountInfo.balanceInfoList!) {
      if (balanceInfo.balance! > BigInt.zero &&
          !_tokensWithBalance.contains(balanceInfo.token)) {
        _tokensWithBalance.add(balanceInfo.token);
      }
    }
  }

  bool _isInputValid() =>
      InputValidators.correctValue(
        widget.controller.text,
        widget.accountInfo.getBalance(
          _selectedToken!.tokenStandard,
        ),
        _selectedToken!.decimals,
        BigInt.zero,
      ) ==
      null;

  @override
  void dispose() {
    super.dispose();
  }
}

/// Says, for the amount field built under it, that a key did nothing, and
/// why.
///
/// [builder] is given the line to show as the field's error text, or null.
///
/// The line stands from a refused edit ([AmountInputRefusal]) through the
/// digits typed after it. `1,5` typed fast leaves `15`: the comma was
/// refused, the 5 went in, and that is the moment the number in the field is
/// not the one that was meant. A line that went with the next key was gone
/// before it could be read. Leaving the field does not withdraw it either.
///
/// It is withdrawn when the amount is no longer what the refused key left
/// behind:
///  - a point goes in, wherever it is typed. That covers deleting the 5 and
///    typing `.5`, and putting the point between the 1 and the 5;
///  - the field is emptied;
///  - the text is set from code: Max, a restored draft, the form cleared
///    after a send. The field may have lost the focus by then. A text set
///    through `TextEditingController.text` has no selection, which is how it
///    is told from a typed one.
///
/// A field of whole numbers takes no point, so there the line goes with the
/// last two only.
///
/// Refusals are recorded once for the whole app, so this decides whether
/// one was its own field's: the field had the focus when it was refused, and
/// its text is the text the refusal left. A field elsewhere that happens to
/// hold the same amount says nothing, and a refusal elsewhere leaves the
/// line of this one standing.
class AmountRefusalScope extends StatefulWidget {
  /// [builder] builds one amount field, the one [controller] is given to.
  const AmountRefusalScope({
    required this.controller,
    required this.builder,
    super.key,
  });

  /// The controller of the amount field that [builder] builds.
  final TextEditingController controller;

  /// Builds the field. `refusal` is its error text while there is one to
  /// show; a field with a validator of its own shows the refusal first.
  final Widget Function(BuildContext context, String? refusal) builder;

  @override
  State<AmountRefusalScope> createState() => _AmountRefusalScopeState();
}

class _AmountRefusalScopeState extends State<AmountRefusalScope> {
  /// Takes no focus itself: it is how this knows the field under it has it.
  final FocusNode _focus = FocusNode(
    debugLabel: 'AmountRefusalScope',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Why the field's edit was refused. Null when there is nothing to say.
  AmountRefusalReason? _reason;

  /// The field's text before the change being heard.
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    AmountInputRefusal.instance.addListener(_onRefusal);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(AmountRefusalScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _text = widget.controller.text;
      _reason = null;
    }
  }

  @override
  void dispose() {
    AmountInputRefusal.instance.removeListener(_onRefusal);
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onRefusal() {
    final AmountInputRefusal refusal = AmountInputRefusal.instance;
    // An accepted edit, here or elsewhere, and another field's refusal are
    // heard too, and change nothing.
    if (refusal.keptText == null ||
        !_focus.hasFocus ||
        refusal.keptText != widget.controller.text) {
      return;
    }
    _say(refusal.reason);
  }

  void _onText() {
    final TextEditingValue value = widget.controller.value;
    final String before = _text;
    final String text = _text = value.text;
    // A caret that moved is heard too.
    if (text == before) {
      return;
    }
    if (text.isEmpty ||
        !value.selection.isValid ||
        (text.contains('.') && !before.contains('.'))) {
      _say(null);
    }
  }

  void _say(AmountRefusalReason? reason) {
    if (reason != _reason) {
      setState(() => _reason = reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Focus(
      focusNode: _focus,
      includeSemantics: false,
      child: widget.builder(
        context,
        switch (_reason) {
          null => null,
          AmountRefusalReason.comma => l10n.validatorAmountUsePoint,
          AmountRefusalReason.notAmount => l10n.validatorAmountDigitsOnly,
          AmountRefusalReason.notWhole => l10n.validatorAmountWholeNumber,
        },
      ),
    );
  }
}
