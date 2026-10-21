import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';

/// The values of the interface that Material has no role for: the quiet text
/// tone, the token inks, the warning, the hover tint, the focus ring, the
/// gaps and the radius.
///
/// They are a [ThemeExtension] and not constants for two reasons. A constant
/// is the same in both themes, and several of these must not be: the green
/// that reads on a dark card is too pale to be text on a white one, and so
/// are the dark theme's QSR blue and warning yellow. And an extension has a
/// [lerp], so a change of theme moves these with every other colour instead
/// of jumping at the end.
///
/// Read them with [AppTokens.of]:
///
/// ```dart
/// final AppTokens tokens = AppTokens.of(context);
/// Text('QSR', style: TextStyle(color: tokens.qsrInk));
/// ```
///
/// The statics on [AppColors] keep their dark-theme values for the code that
/// still reads them.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Creates a set of tokens.
  const AppTokens({
    required this.faint,
    required this.znnInk,
    required this.qsrInk,
    required this.warn,
    required this.hover,
    required this.focusRing,
    required this.panelGap,
    required this.cardGap,
    required this.cardRadius,
  });

  /// The tokens of the theme in use. A theme that carries none (a bare
  /// MaterialApp in a test) gets the set for its brightness.
  static AppTokens of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.light ? light : dark);
  }

  /// The dark theme's tokens: the values the `AppColors` statics hold.
  static const AppTokens dark = AppTokens(
    faint: AppColors.faint,
    znnInk: AppColors.znnColor,
    qsrInk: AppColors.qsrInk,
    warn: AppColors.warn,
    hover: Color(0x0DFFFFFF),
    focusRing: AppColors.znnColor,
    panelGap: 14,
    cardGap: 10,
    cardRadius: kCardRadius,
  );

  /// The light theme's tokens. Each ink is dark enough to be text on a
  /// white card (4.5 to 1 or better), which the dark theme's are not.
  static const AppTokens light = AppTokens(
    faint: Color(0xFF6B706B),
    znnInk: Color(0xFF1B8534),
    qsrInk: Color(0xFF005FE6),
    warn: Color(0xFF8A6100),
    hover: Color(0x0A000000),
    focusRing: Color(0xFF1B8534),
    panelGap: 14,
    cardGap: 10,
    cardRadius: kCardRadius,
  );

  /// Text that is present but secondary: units, ledger labels, quiet icons.
  final Color faint;

  /// ZNN green as text or as a line. The brand green itself
  /// ([AppColors.znnColor]) stays the fill of the primary button in both
  /// themes.
  final Color znnInk;

  /// QSR blue as text.
  final Color qsrInk;

  /// Needs the person: an update, a missed momentum.
  final Color warn;

  /// Laid over a surface under the pointer: a table row, a menu item.
  final Color hover;

  /// The line round a control that has the keyboard focus.
  final Color focusRing;

  /// The gap between panels on a page.
  final double panelGap;

  /// The gap between two fields, or two rows, inside a card.
  final double cardGap;

  /// The corner radius of a card and of a field. Buttons are pills.
  final double cardRadius;

  @override
  AppTokens copyWith({
    Color? faint,
    Color? znnInk,
    Color? qsrInk,
    Color? warn,
    Color? hover,
    Color? focusRing,
    double? panelGap,
    double? cardGap,
    double? cardRadius,
  }) {
    return AppTokens(
      faint: faint ?? this.faint,
      znnInk: znnInk ?? this.znnInk,
      qsrInk: qsrInk ?? this.qsrInk,
      warn: warn ?? this.warn,
      hover: hover ?? this.hover,
      focusRing: focusRing ?? this.focusRing,
      panelGap: panelGap ?? this.panelGap,
      cardGap: cardGap ?? this.cardGap,
      cardRadius: cardRadius ?? this.cardRadius,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      faint: Color.lerp(faint, other.faint, t)!,
      znnInk: Color.lerp(znnInk, other.znnInk, t)!,
      qsrInk: Color.lerp(qsrInk, other.qsrInk, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      panelGap: lerpDouble(panelGap, other.panelGap, t)!,
      cardGap: lerpDouble(cardGap, other.cardGap, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
    );
  }

  // By value: ThemeData compares its extensions, and a lerp builds a new
  // object. By identity, a theme that settled on the same tokens would
  // still count as changed and rebuild everything under it.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppTokens &&
        other.faint == faint &&
        other.znnInk == znnInk &&
        other.qsrInk == qsrInk &&
        other.warn == warn &&
        other.hover == hover &&
        other.focusRing == focusRing &&
        other.panelGap == panelGap &&
        other.cardGap == cardGap &&
        other.cardRadius == cardRadius;
  }

  @override
  int get hashCode => Object.hash(
    faint,
    znnInk,
    qsrInk,
    warn,
    hover,
    focusRing,
    panelGap,
    cardGap,
    cardRadius,
  );
}

const DividerThemeData kDefaultDividerThemeData = DividerThemeData(
  thickness: 1,
  indent: 0,
  endIndent: 0,
  space: 1,
);

/// The interface face. Numbers and identifiers use [kMonoFontFamily].
const String kSansFontFamily = 'SpaceGrotesk';

/// Amounts, addresses, hashes and heights: mono with tabular figures, so
/// columns line up and a changing value does not jitter.
const String kMonoFontFamily = 'JetBrainsMono';

/// The bundled face for Arabic: Noto Sans Arabic.
const String kArabicFontFamily = 'NotoSansArabic';

/// The bundled face for Hindi: Noto Sans Devanagari.
const String kDevanagariFontFamily = 'NotoSansDevanagari';

/// Where a character goes that [kSansFontFamily] and [kMonoFontFamily] do
/// not have, in this order. Neither has one Han, Devanagari or Arabic glyph.
///
/// Without the list Flutter asks the operating system for each character.
/// A minimal Linux then draws empty boxes, and a Han character can come
/// back in a Japanese or Traditional face, whichever the system lists first.
///
/// Arabic and Devanagari are bundled, so they come first and look the same
/// everywhere. The two files have no Latin letters, so they take nothing
/// from the faces above.
///
/// No Chinese face is bundled: one is 8 to 17 MB, several times the rest of
/// the installer's assets. Han comes from the system instead, and naming
/// the Simplified faces is what keeps it Simplified: Windows, then macOS,
/// then the ones a Linux desktop carries.
///
/// The last four are the system's own Arabic and Devanagari faces, behind
/// the bundled ones should an asset fail to load.
///
/// A style that sets a family of its own takes this list only if it is
/// built on a theme style or with [monoStyle]. One built from nothing, and
/// used where nothing is merged into it (a button's `textStyle`, a nested
/// `TextSpan`), names the list itself. The engine reads a family and its
/// fallbacks as one list, so a family set without them drops them; and a
/// list given to a style with no family replaces the system face, Latin
/// included, with the first face here that has the letter.
const List<String> kFontFamilyFallback = <String>[
  kArabicFontFamily,
  kDevanagariFontFamily,
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'PingFang SC',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'Segoe UI',
  'Nirmala UI',
  'Geeza Pro',
  'Kohinoor Devanagari',
];

/// The interface languages not written in Latin letters: Arabic, Hindi and
/// Chinese.
const Set<String> kNonLatinLanguages = <String>{'ar', 'hi', 'zh'};

/// Whether the interface language is written in Latin letters.
///
/// The small labels are spaced capitals. Letter spacing pulls the joined
/// letters of Arabic apart and does nothing for Devanagari or Han, and none
/// of the three has capitals, so a label asks this before it does either.
/// Without a locale above [context] the answer is yes.
bool usesLatinScript(BuildContext context) => !kNonLatinLanguages.contains(
  Localizations.maybeLocaleOf(context)?.languageCode,
);

/// The radius of a card. Buttons and chips are pills.
const double kCardRadius = 8;

/// A mono style for data, built on [base].
TextStyle monoStyle(TextStyle? base) => (base ?? const TextStyle()).copyWith(
  fontFamily: kMonoFontFamily,
  fontFamilyFallback: kFontFamilyFallback,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

final ButtonStyle kElevatedButtonStyle = ElevatedButton.styleFrom(
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const StadiumBorder(),
  minimumSize: const Size(55, 42),
  backgroundColor: AppColors.znnColor,
);

/// The text on a filled green button.
const Color kOnZnnColor = Color(0xFF06230D);

/// The main action of a card (Send, Stake, Collect, Delegate, Fuse). The app
/// builds these as OutlinedButtons; in the refreshed interface the main
/// action is a filled green pill, and one that cannot be pressed yet is an
/// empty outline, so "not ready" reads at a glance.
ButtonStyle primaryButtonStyle({required Color disabledLine}) =>
    OutlinedButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      minimumSize: const Size(64, 40),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      textStyle: kOutlinedButtonTextStyle,
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? Colors.transparent
            : states.contains(WidgetState.hovered)
            ? const Color(0xFF63DB78)
            : AppColors.znnColor,
      ),
      side: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? BorderSide(color: disabledLine)
            : BorderSide.none,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.disabled) ? disabledLine : kOnZnnColor,
      ),
    );

final ButtonStyle kOutlinedButtonStyle = OutlinedButton.styleFrom(
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const StadiumBorder(),
  side: const BorderSide(
    color: AppColors.znnColor,
  ),
  textStyle: kOutlinedButtonTextStyle,
);

const TextStyle kDisplaySmallTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

const TextStyle kBodyLargeTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

const TextStyle kBodyMediumTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
);

const TextStyle kBodySmallTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

const TextStyle kHeadlineLargeTextStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w500,
);

const TextStyle kHeadlineMediumTextStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w500,
);

const TextStyle kHeadlineSmallTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w400,
);

/// The label of a main action, and of any button at its size.
///
/// A button's `textStyle` replaces the theme's label style, so this names
/// the face and [kFontFamilyFallback] itself; without them the label was
/// drawn in the operating system's face. Medium is the heaviest weight
/// bundled under Bold: a 600 would be drawn as Bold.
const TextStyle kOutlinedButtonTextStyle = TextStyle(
  fontFamily: kSansFontFamily,
  fontFamilyFallback: kFontFamilyFallback,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

/// The label of a TextButton and of the compact buttons; a complete style,
/// as [kOutlinedButtonTextStyle] is.
const TextStyle kTextButtonTextStyle = TextStyle(
  fontFamily: kSansFontFamily,
  fontFamilyFallback: kFontFamilyFallback,
  fontSize: 13,
  fontWeight: FontWeight.w500,
);

const TextStyle kTitleMediumTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: AppColors.subtitleColor,
);

const TextStyle kTitleSmallTextStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: AppColors.subtitleColor,
);

final TextButtonThemeData kTextButtonThemeData = TextButtonThemeData(
  style: TextButton.styleFrom(
    textStyle: kTextButtonTextStyle,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: const Size(55, 25),
    backgroundColor: AppColors.znnColor,
    shape: const StadiumBorder(),
  ),
);

const TextStyle kHintTextStyle = TextStyle(
  fontWeight: FontWeight.w400,
  fontSize: 14,
);

const TextStyle kTextFormFieldErrorStyle = TextStyle(
  color: AppColors.errorColor,
);

const OutlineInputBorder kOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(kCardRadius)),
);

class AppTheme {
  AppTheme._();
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[AppTokens.light],
    hoverColor: AppColors.lightTextFormFieldFill,
    textButtonTheme: kTextButtonThemeData,
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: primaryButtonStyle(disabledLine: const Color(0xFFB9BCB9)).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.black38;
            }
            return kOnZnnColor;
          },
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: kElevatedButtonStyle,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.znnColor,
      selectionHandleColor: AppColors.znnColor,
    ),
    fontFamily: kSansFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
    inputDecorationTheme: InputDecorationTheme(
      fillColor: AppColors.lightTextFormFieldFill,
      hintStyle: kHintTextStyle.copyWith(
        color: AppColors.lightHintTextColor,
      ),
      errorStyle: kTextFormFieldErrorStyle,
      enabledBorder: kOutlineInputBorder.copyWith(
        borderSide: BorderSide.none,
      ),
      disabledBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.inactiveIconsGray),
      ),
      focusedBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.inactiveIconsGray),
      ),
      errorBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(
          color: AppColors.errorColor,
          width: 2,
        ),
      ),
      focusedErrorBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(
          color: AppColors.errorColor,
          width: 2,
        ),
      ),
    ),
    dividerTheme: kDefaultDividerThemeData.copyWith(
      color: AppColors.lightDividerColor,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.lightSecondary,
    ),
    textTheme: TextTheme(
      bodyLarge: kBodyLargeTextStyle.copyWith(
        color: Colors.black,
      ),
      bodyMedium: kBodyMediumTextStyle.copyWith(
        color: Colors.black,
      ),
      bodySmall: kBodySmallTextStyle.copyWith(
        color: Colors.black,
      ),
      // The dark theme's grey is too faint on the light ground.
      titleMedium: kTitleMediumTextStyle.copyWith(
        color: AppColors.lightSubtitleColor,
      ),
      titleSmall: kTitleSmallTextStyle.copyWith(
        color: AppColors.lightSubtitleColor,
      ),
      headlineLarge: kHeadlineLargeTextStyle.copyWith(
        color: Colors.black,
      ),
      headlineMedium: kHeadlineMediumTextStyle.copyWith(
        color: Colors.black,
      ),
      headlineSmall: kHeadlineSmallTextStyle.copyWith(
        color: Colors.black,
      ),
    ),
    unselectedWidgetColor: AppColors.lightSecondaryContainer,
    // On is the green fill with the dark ink of a filled button as its
    // thumb; off is a quiet track with an outline and a faint thumb. Thumb
    // and track once resolved to the same green when on, which drew a solid
    // pill that could not be read as either state.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? kOnZnnColor.withValues(alpha: 0.5)
              : AppTokens.light.faint.withValues(alpha: 0.4);
        }
        if (on) {
          return kOnZnnColor;
        }
        return states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)
            ? AppColors.lightSubtitleColor
            : AppTokens.light.faint;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? AppColors.znnColor.withValues(alpha: 0.4)
              : AppColors.lightTextFormFieldFill.withValues(alpha: 0.4);
        }
        if (on) {
          return states.contains(WidgetState.hovered)
              ? const Color(0xFF63DB78)
              : AppColors.znnColor;
        }
        return AppColors.lightTextFormFieldFill;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? Colors.transparent
              : AppTokens.light.faint.withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.focused)) {
          return AppTokens.light.focusRing;
        }
        return on ? Colors.transparent : AppTokens.light.faint;
      }),
      trackOutlineWidth: WidgetStateProperty.resolveWith<double?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.focused) ? 2 : 1,
      ),
      // Named for every state: the default is the scheme's primary, which
      // is white in this theme.
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.focused)) {
          return AppTokens.light.focusRing.withValues(alpha: 0.24);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return AppTokens.light.hover;
        }
        return Colors.transparent;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return AppColors.znnColor;
        }
        return null;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return AppColors.znnColor;
        }
        return null;
      }),
    ),
    colorScheme: const ColorScheme.light(
      primary: Colors.white,
      primaryContainer: AppColors.lightPrimaryContainer,
      secondary: AppColors.lightSecondary,
      secondaryContainer: AppColors.lightSecondaryContainer,
      error: AppColors.errorColor,
    ).copyWith(surface: AppColors.backgroundLight),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[AppTokens.dark],
    hoverColor: AppColors.darkTextFormFieldFill,
    textButtonTheme: kTextButtonThemeData,
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: primaryButtonStyle(disabledLine: const Color(0xFF4A4D4A)).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.white38;
            }
            return kOnZnnColor;
          },
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: kElevatedButtonStyle,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: Colors.white.withOpacity(0.1),
      cursorColor: AppColors.znnColor,
      selectionHandleColor: AppColors.znnColor,
    ),
    fontFamily: kSansFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
    inputDecorationTheme: InputDecorationTheme(
      fillColor: AppColors.darkTextFormFieldFill,
      hintStyle: kHintTextStyle.copyWith(
        color: AppColors.darkHintTextColor,
      ),
      errorStyle: kTextFormFieldErrorStyle,
      enabledBorder: kOutlineInputBorder.copyWith(
        borderSide: BorderSide.none,
      ),
      disabledBorder: kOutlineInputBorder.copyWith(
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      focusedBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.znnColor),
      ),
      errorBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(
          color: AppColors.errorColor,
          width: 2,
        ),
      ),
      focusedErrorBorder: kOutlineInputBorder.copyWith(
        borderSide: const BorderSide(
          color: AppColors.errorColor,
          width: 2,
        ),
      ),
    ),
    dividerTheme: kDefaultDividerThemeData.copyWith(
      color: AppColors.darkDividerColor,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.lightSecondary,
    ),
    textTheme: TextTheme(
      bodyLarge: kBodyLargeTextStyle.copyWith(
        color: Colors.white,
      ),
      bodyMedium: kBodyMediumTextStyle.copyWith(
        color: Colors.white,
      ),
      bodySmall: kBodySmallTextStyle.copyWith(
        color: Colors.white,
      ),
      titleMedium: kTitleMediumTextStyle,
      titleSmall: kTitleSmallTextStyle,
      headlineLarge: kHeadlineLargeTextStyle.copyWith(
        color: Colors.white,
      ),
      headlineMedium: kHeadlineMediumTextStyle.copyWith(
        color: Colors.white,
      ),
      headlineSmall: kHeadlineSmallTextStyle.copyWith(
        color: Colors.white,
      ),
    ),
    unselectedWidgetColor: AppColors.darkSecondaryContainer,
    // The same switch as the light theme's, on this theme's tokens. The
    // disabled thumb keeps its full ink when on: dimmed as well, it would
    // sink into the dimmed green on a dark panel.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? kOnZnnColor
              : AppTokens.dark.faint.withValues(alpha: 0.4);
        }
        if (on) {
          return kOnZnnColor;
        }
        return states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)
            ? AppColors.subtitleColor
            : AppTokens.dark.faint;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? AppColors.znnColor.withValues(alpha: 0.4)
              : AppColors.darkTextFormFieldFill.withValues(alpha: 0.4);
        }
        if (on) {
          return states.contains(WidgetState.hovered)
              ? const Color(0xFF63DB78)
              : AppColors.znnColor;
        }
        return AppColors.darkTextFormFieldFill;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        final bool on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? Colors.transparent
              : AppTokens.dark.faint.withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.focused)) {
          return AppTokens.dark.focusRing;
        }
        return on ? Colors.transparent : AppTokens.dark.faint;
      }),
      trackOutlineWidth: WidgetStateProperty.resolveWith<double?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.focused) ? 2 : 1,
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.focused)) {
          return AppTokens.dark.focusRing.withValues(alpha: 0.24);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return AppTokens.dark.hover;
        }
        return Colors.transparent;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return AppColors.znnColor;
        }
        return null;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.selected)) {
          return AppColors.znnColor;
        }
        return null;
      }),
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      primaryContainer: AppColors.darkPrimaryContainer,
      secondary: AppColors.darkSecondary,
      secondaryContainer: AppColors.darkSecondaryContainer,
      error: AppColors.errorColor,
    ).copyWith(surface: AppColors.backgroundDark),
  );
}
