import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/theming/new_app_themes.dart';

/// Extension on the [BuildContext] class
extension BuildContextExtension on BuildContext {
  /// Getter method for easier access to the [AppLocalizations] instance
  ///
  /// Under the app there is always one. A shared widget shown with no
  /// localisation delegate above it, as one pumped alone in a test, used to
  /// carry its own English and so needed none; it gets [currentL10n] here
  /// rather than a null check that throws.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? currentL10n;

  /// Returns the current ThemeData
  ThemeData get themeData => Theme.of(this);

  /// Returns the current TextTheme
  TextTheme get textTheme => themeData.textTheme;

  /// Whether the app is currently in dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Return the current new theme data
  //TODO(maznnwell): to be deleted/replaced
  ThemeData get newThemeData => isDarkMode ? newDarkTheme : newLightTheme;
}
