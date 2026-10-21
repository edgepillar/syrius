import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';

/// The height of one seed word's box.
const double kSeedCellHeight = 36;

/// The gap between seed word boxes, across and down.
const double kSeedCellGap = 8;

/// The width of a seed word's box in a row of [perRow] boxes, given the
/// width there is. Never wider than the old fixed cell, never so narrow that
/// an eight-letter word is cut.
double seedCellWidth(BoxConstraints constraints, int perRow, double widest) {
  if (!constraints.hasBoundedWidth) return widest;
  final double fit =
      (constraints.maxWidth - kSeedCellGap * (perRow - 1)) / perRow;
  return fit.clamp(112, widest).floorToDouble();
}

/// The text style of a seed word: mono, so every word lines up.
TextStyle seedWordStyle(Color? color) =>
    monoStyle(TextStyle(fontSize: 13, height: 1.3, color: color));

/// A field with no frame of its own; the [SeedCell] draws it.
const InputDecoration kSeedFieldDecoration = InputDecoration(
  isDense: true,
  filled: false,
  hintText: '',
  contentPadding: EdgeInsets.fromLTRB(6, 9, 8, 9),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

/// One word of a seed: its position, then the word, in a box whose line
/// says whether the word is right.
///
/// The position is a control as well: hovering it reveals the word, and
/// pressing it keeps the word shown. Both are the caller's state.
class SeedCell extends StatelessWidget {
  /// Creates the box for word [number].
  const SeedCell({
    required this.number,
    required this.field,
    required this.lineColor,
    this.numberColor = AppColors.faint,
    this.onNumberTap,
    this.onNumberHover,
    this.width,
    super.key,
  });

  /// The position, from 1.
  final int number;

  /// The word: a field without a frame of its own.
  final Widget field;

  /// The box's line.
  final Color lineColor;

  /// The position's colour.
  final Color numberColor;

  /// Pressing the position.
  final VoidCallback? onNumberTap;

  /// The pointer entering and leaving the position.
  final ValueChanged<bool>? onNumberHover;

  /// The box's width; the old fixed cell when null.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Durations.short3,
      curve: Easing.standard,
      width: width,
      height: kSeedCellHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: lineColor),
      ),
      child: Row(
        children: <Widget>[
          // An InkWell, not a GestureDetector, so the position takes focus
          // and Enter or Space press it. Its ink is switched off: the number's
          // colour is the only feedback this control has.
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onNumberTap,
              onHover: onNumberHover,
              mouseCursor: SystemMouseCursors.click,
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: SizedBox(
                width: 30,
                height: kSeedCellHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$number',
                    style: monoStyle(
                      TextStyle(
                        fontSize: 12,
                        color: numberColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }
}

/// The line of a seed box at rest: the theme's divider.
Color seedRestLine(BuildContext context) => lineColorOf(context);
