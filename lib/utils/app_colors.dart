import 'package:material_ui/material_ui.dart';

class AppColors {
  static const Color znnColor = Color(0xFF4FD166);
  static const Color qsrColor = Color(0xFF006AFF);
  static const Color ztsColor = Color(0xFFFC54AE);

  /// The Zenon design system's pink, the hot end of the plasma glow's ramp
  /// (`assets/shaders/heatmap.frag`) and one light of the hero field. For
  /// plasma surfaces only: [ztsColor] stays the ink for tokens.
  static const Color plasmaPink = Color(0xFFF91690);

  static const Color errorColor = Color(0xFFF40442);

  static const Color backgroundLight = Color(0xFFEAEAEA);
  static const Color backgroundDark = Color(0xFF1B1C1B);

  static const Color subtitleColor = Color(0xFFA5AAA5);
  static const Color lightSubtitleColor = Color(0xFF535853);

  static const Color maxAmountBorder = Color(0xFF474747);

  static const Color lightSecondary = Color(0xFFB3B3B3);
  static const Color lightSecondaryContainer = Color(0xFF545454);
  static const Color darkSecondary = Color(0xFF3F3F3F);
  static const Color darkSecondaryContainer = Color.fromRGBO(46, 46, 46, 1);

  static const Color alertNotification = Color(0xFFDAE240);

  static const Color accessWalletContainersGray = Color.fromRGBO(46, 46, 46, 1);
  static const Color inactiveIconsGray = Color.fromRGBO(51, 51, 51, 1);

  static const Color darkPrimary = Color(0xFF262726);
  static const Color darkPrimaryContainer = Color(0xFF2E302E);
  static const Color lightPrimaryContainer = Color(0xFFF6F7F6);

  static const Color lightDividerColor = Color.fromRGBO(193, 193, 193, 0.8);
  static const Color darkDividerColor = Color(0xFF383A38);

  static const Color lightTextFormFieldFill = Color(0xFFE4E4E4);
  static const Color darkTextFormFieldFill = Color.fromRGBO(51, 51, 51, 1);

  static const Color darkHintTextColor = Color.fromRGBO(99, 99, 99, 1);
  static const Color lightHintTextColor = Color.fromRGBO(179, 179, 179, 1);

  static const Color seedUnderlineBorderColor = Color.fromRGBO(99, 99, 99, 1);
  static const Color unselectedSeedChoiceColor = Color(0xFF636363);
  static const Color selectedSeedChoiceColor = Color(0xFF292929);

  /// Text that is present but secondary: units, insignificant zeros, labels.
  static const Color faint = Color(0xFF717671);

  /// QSR as text on a dark card; [qsrColor] is too dark to read there.
  static const Color qsrInk = Color(0xFF5B9DFF);

  /// Needs the person: an update, a missed momentum.
  static const Color warn = Color(0xFFDAB544);
}
