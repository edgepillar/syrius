import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// Splits [raw], in the smallest unit, into its significant digits with
/// thousands separators and the trailing zeros that say nothing.
///
/// `120450000000` with 8 decimals is `('1,204.5', '0000000')`. Nothing is
/// rounded: the zeros are shown, only quieter.
///
/// The digits are Latin in every language and carry no direction mark, so
/// that they can be copied. Whatever draws them pins them left to right
/// (`Ltr`, or `textDirection: TextDirection.ltr`), or a right-to-left
/// interface moves the sign and the symbol to the other side.
(String, String) splitAmount(BigInt raw, int decimals) {
  final bool negative = raw.isNegative;
  final String digits = raw.abs().toString().padLeft(decimals + 1, '0');
  final String whole = digits.substring(0, digits.length - decimals);
  final String fraction = digits.substring(digits.length - decimals);
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) {
      grouped.write(',');
    }
    grouped.write(whole[i]);
  }
  final String sign = negative ? '-' : '';
  if (decimals == 0) {
    return ('$sign$grouped', '');
  }
  final String significant = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (significant.isEmpty) {
    return ('$sign$grouped', '.$fraction');
  }
  return (
    '$sign$grouped.$significant',
    fraction.substring(significant.length),
  );
}

/// An amount in mono, without its insignificant trailing zeros.
class AmountText extends StatelessWidget {
  /// Creates an amount of [raw] smallest units with [decimals].
  const AmountText(
    this.raw, {
    required this.decimals,
    required this.style,
    this.symbol,
    this.symbolColor,
    super.key,
  });

  /// The amount in the smallest unit.
  final BigInt raw;

  /// The token's decimals.
  final int decimals;

  /// The style of the significant digits.
  final TextStyle style;

  /// Shown after the amount, smaller.
  final String? symbol;

  /// The symbol's colour; the token's own colour where it has one.
  final Color? symbolColor;

  @override
  Widget build(BuildContext context) {
    // The owner's call (2026-10-13): balances show no trailing zeros, not
    // even dimmed. Nothing is rounded; only zeros that say nothing go.
    final (String head, _) = splitAmount(raw, decimals);
    final TextStyle mono = monoStyle(style);
    return Text.rich(
      TextSpan(
        style: mono,
        children: <InlineSpan>[
          TextSpan(text: head),
          if (symbol != null)
            TextSpan(
              text: ' $symbol',
              style: TextStyle(
                fontFamily: kSansFontFamily,
                fontSize: (style.fontSize ?? 14) * 0.53 < 13
                    ? 13
                    : (style.fontSize ?? 14) * 0.53,
                fontWeight: FontWeight.w500,
                color: symbolColor,
              ),
            ),
        ],
      ),
      // Left to right in every language: under a right-to-left interface
      // "1,204.5 ZNN" would otherwise be drawn "ZNN 1,204.5". Its start
      // stays the app's start.
      textDirection: TextDirection.ltr,
      textAlign: ltrTextAlign(context),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}
