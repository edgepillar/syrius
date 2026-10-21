import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';

/// An amount in its compact form, with the whole amount and its symbol in a
/// tooltip.
///
/// Both run left to right in every language. This was a subclass of
/// [Tooltip]; it now builds one under an [Ltr], because a tooltip's message
/// takes the direction of the place the tooltip stands in, and under a
/// right-to-left interface "1204.5 ZNN" was drawn "ZNN 1204.5". Where the
/// amount sits in its cell is still the caller's business.
class FormattedAmountWithTooltip extends StatelessWidget {
  /// Creates the amount.
  const FormattedAmountWithTooltip({
    required this.amount,
    required this.tokenSymbol,
    required this.builder,
    super.key,
  });

  /// The whole amount, with its decimals.
  final String amount;

  /// The token's symbol.
  final String tokenSymbol;

  /// Draws the compact amount and the symbol.
  final Widget Function(String, String) builder;

  @override
  Widget build(BuildContext context) {
    return Ltr(
      child: Tooltip(
        message: '$amount $tokenSymbol',
        child: builder(compactAmount(amount), tokenSymbol),
      ),
    );
  }
}

/// [amount], a whole amount with its decimals, as
/// [FormattedAmountWithTooltip] draws it: `1.23M`, an amount under one as
/// it is, and `…` for what would not fit.
///
/// The format is named `en`, not left to intl's default locale: an amount
/// reads the same in every language, and under a Spanish default `1.23M`
/// would come out `1,23 M`.
String compactAmount(String amount) {
  if (amount.toNum() == 0) {
    return '0';
  }
  if (amount.startsWith('0.')) {
    return amount;
  }
  final String compact = NumberFormat.compact(
    locale: 'en',
  ).format(amount.toNum());
  return compact.length > 8 ? '…' : compact;
}
