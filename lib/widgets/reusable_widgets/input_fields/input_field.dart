import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/input_fields/amount_input_field.dart';

class InputField extends StatefulWidget {

  const InputField({
    required this.controller,
    this.maxLines = 1,
    this.thisNode,
    this.hintText,
    this.nextNode,
    this.enabled = true,
    this.inputFormatters,
    this.validator,
    this.suffixIcon,
    this.suffixIconConstraints,
    this.contentLeftPadding = kContentPadding,
    this.onChanged,
    this.obscureText = false,
    this.errorText,
    this.onSubmitted,
    this.inputtedTextStyle = const TextStyle(
      fontSize: 14,
      color: AppColors.znnColor,
    ),
    this.disabledBorder,
    this.enabledBorder,
    this.errorBorder,
    this.focusedBorder,
    this.focusedErrorBorder,
    this.textDirection,
    this.textAlign = TextAlign.start,
    super.key,
  });
  final TextEditingController controller;
  final FocusNode? thisNode;
  final FocusNode? nextNode;
  final String? hintText;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final BoxConstraints? suffixIconConstraints;
  final double contentLeftPadding;
  final Function(String)? onChanged;
  final bool obscureText;
  final String? errorText;
  final int maxLines;
  final Function(String)? onSubmitted;
  final TextStyle inputtedTextStyle;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final InputBorder? disabledBorder;
  final InputBorder? errorBorder;
  final InputBorder? focusedErrorBorder;

  /// The direction of what is typed. Null is the app's; an amount, an
  /// address or a hash is given `TextDirection.ltr`, with `ltrTextAlign` as
  /// [textAlign] so that it still starts at the app's start. The hint, the
  /// suffix and the error line keep the app's direction either way.
  final TextDirection? textDirection;

  /// Where what is typed sits in the field.
  final TextAlign textAlign;

  @override
  State createState() {
    return _InputFieldState();
  }
}

class _InputFieldState extends State<InputField> {
  @override
  Widget build(BuildContext context) {
    // An amount field says why a key did nothing. It is told from the
    // formatters, so that every form that builds one is covered without
    // being changed.
    final bool isAmount =
        widget.inputFormatters?.any(
          (TextInputFormatter formatter) => formatter is AmountInputFormatter,
        ) ??
        false;
    if (!isAmount) {
      return _buildField(context);
    }
    return AmountRefusalScope(
      controller: widget.controller,
      builder: (BuildContext context, String? refusal) =>
          _buildField(context, refusal: refusal, isAmount: true),
    );
  }

  /// [refusal] is shown over what the validator says: it is about a key
  /// just pressed, and it shows in a field the form has not validated yet,
  /// as after a first paste that was refused.
  Widget _buildField(
    BuildContext context, {
    String? refusal,
    bool isAmount = false,
  }) {
    return TextFormField(
      forceErrorText: refusal,
      // The forms around the amount fields validate on user interaction, and
      // they are built before this field is given a [refusal] or loses it.
      // Validating here as well gives the validator's line back in the same
      // frame the refusal is withdrawn.
      autovalidateMode: isAmount ? AutovalidateMode.onUserInteraction : null,
      textDirection: widget.textDirection,
      textAlign: widget.textAlign,
      contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
        return AdaptiveTextSelectionToolbar(
            anchors: editableTextState.contextMenuAnchors,
            children: editableTextState.contextMenuButtonItems
                .map((ContextMenuButtonItem buttonItem) {
              return Row(children: <Widget>[
                Expanded(
                    child: TextButton(
                  onPressed: buttonItem.onPressed,
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                      AdaptiveTextSelectionToolbar.getButtonLabel(
                          context, buttonItem,),
                      style: Theme.of(context).textTheme.bodyMedium,),
                ),),
              ],);
            }).toList(),);
      },
      maxLines: widget.maxLines,
      obscureText: widget.obscureText,
      onChanged: widget.onChanged,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters ?? <TextInputFormatter>[],
      enabled: widget.enabled,
      controller: widget.controller,
      focusNode: widget.thisNode,
      onFieldSubmitted: widget.onSubmitted,
      style: widget.inputtedTextStyle,
      decoration: InputDecoration(
        enabledBorder: widget.enabledBorder,
        disabledBorder: widget.disabledBorder,
        focusedBorder: widget.focusedBorder,
        errorBorder: widget.errorBorder,
        focusedErrorBorder: widget.focusedBorder,
        errorText: widget.errorText,
        errorMaxLines: 2,
        contentPadding: EdgeInsets.only(
          left: widget.contentLeftPadding,
          right: kContentPadding,
          top: kContentPadding,
          bottom: kContentPadding,
        ),
        suffixIcon: widget.suffixIcon,
        suffixIconConstraints: widget.suffixIconConstraints,
        filled: true,
        hintText: widget.hintText,
      ),
    );
  }
}
