import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/extensions.dart';

/// A short list of points, inset: the card tone, so it reads as a block on
/// the raised surface of the modals it is used in.
class BulletPointCard extends StatelessWidget {
  /// Creates the list.
  const BulletPointCard({
    required this.bulletPoints,
    super.key,
  });

  /// The points, top to bottom.
  final List<RichText> bulletPoints;

  /// A span in the list's text style.
  static TextSpan textSpan(String text, {List<TextSpan>? children}) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.45,
        fontFamily: kSansFontFamily,
        // A RichText merges nothing into its span, so the list is named.
        fontFamilyFallback: kFontFamilyFallback,
        color: AppColors.subtitleColor,
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.all(Radius.circular(kCardRadius)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bulletPoints
              .map(
                (RichText e) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // The dot sits on the first line of its point.
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: SizedBox.square(
                        dimension: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.faint,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: e),
                  ],
                ),
              )
              .toList()
              .zip(
                List<Widget>.generate(
                  bulletPoints.length - 1,
                  (int index) => const SizedBox(height: 10),
                ),
              ),
        ),
      ),
    );
  }
}
