import 'package:flutter/widgets.dart';

/// Draws [child] left to right, whichever way the interface runs.
///
/// Under a right-to-left interface the bidi algorithm reorders any text that
/// mixes digits, Latin letters and punctuation. "1,204.5 ZNN" is drawn
/// "ZNN 1,204.5", "-5.2" as "5.2-", and a hash cut to "123456...345678" has
/// its two ends swapped. A wallet's figures must read the same in every
/// language, so amounts, the symbol beside an amount, addresses, hashes,
/// chain ids, heights and percentages always run left to right, in Latin
/// digits.
///
/// The direction is set on the widget and never with an invisible mark (LRM,
/// LRI) in the string: a mark would be copied to the clipboard along with
/// the address or the amount it was put beside.
///
/// Only the characters are pinned; where the figure sits is the caller's
/// business. A figure that stood at the start of a row in English stands at
/// the start in Arabic too, which is the right side, and reads left to right
/// there. So wrap the figure alone, not the row it is in: the row keeps the
/// app's direction and places it. A text that is as wide as its content needs
/// nothing more. One that is given more width than that (in an `Expanded`,
/// or stretched) aligns inside itself, and under this widget `start` means
/// left; give it [ltrTextAlign], read from a context above the [Ltr].
///
/// For a single `Text` or field, `textDirection: TextDirection.ltr` on it
/// does the same and leaves what is around it (a field's hint, its suffix,
/// its error line) with the app's direction.
class Ltr extends StatelessWidget {
  /// Pins [child] left to right.
  const Ltr({required this.child, super.key});

  /// The figure: an amount, an address, a hash.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}

/// The alignment of a text that is pinned left to right, so that its start
/// is still the app's start: the right side under a right-to-left interface.
///
/// [align] is what the text would have been given without the pin; null is
/// the surrounding `DefaultTextStyle`'s, then `start`. Under a left-to-right
/// interface it comes back as it is, so nothing changes there.
///
/// [context] must be above any [Ltr]: under one, the app's direction can no
/// longer be read.
TextAlign ltrTextAlign(BuildContext context, [TextAlign? align]) {
  final TextAlign asked =
      align ?? DefaultTextStyle.of(context).textAlign ?? TextAlign.start;
  if (Directionality.maybeOf(context) != TextDirection.rtl) {
    return asked;
  }
  return switch (asked) {
    TextAlign.start => TextAlign.right,
    TextAlign.end => TextAlign.left,
    _ => asked,
  };
}

/// Hebrew, Arabic and the other scripts written right to left.
final RegExp _rtlLetter = RegExp(
  r'[֐-ࣿיִ-﷿ﹰ-ﻼ\u{10800}-\u{10FFF}'
  r'\u{1E800}-\u{1EFFF}]',
  unicode: true,
);

/// The direction for a [text] that may be a figure or may be words: left to
/// right when it has no right-to-left letter, otherwise null, which leaves
/// it to the app's direction.
///
/// A text with no such letter is a number, an amount, an identifier or a
/// Latin name, and left to right is how it is drawn in English. One with
/// such a letter is a translated word or sentence: pinned, its punctuation
/// and any number in it would land on the wrong side.
TextDirection? ltrUnlessRtl(String text) =>
    _rtlLetter.hasMatch(text) ? null : TextDirection.ltr;
