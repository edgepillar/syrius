import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The Send button: a pill as tall as the amount field it sits beside.
class SendButton extends LoadingButton {
  /// Creates a new instance, with a default [minimumSize]
  const SendButton({
    required super.onPressed,
    required super.key,
    required super.text,
    super.minimumSize = const Size(104, kCardFieldHeight),
  }) : super(
         paddingAroundChild: const EdgeInsets.symmetric(
           horizontal: 20,
         ),
         circularBorderRadius: kCardFieldHeight / 2,
       );
}
