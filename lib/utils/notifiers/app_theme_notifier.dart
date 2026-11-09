import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

/// Owns the theme used by the root application and Display settings.
class AppThemeNotifier extends ChangeNotifier {
  /// Starts in the already selected theme when preferences are available.
  AppThemeNotifier([this._currentThemeMode = kDefaultThemeMode]);

  ThemeMode? _currentThemeMode;

  void changeThemeMode(ThemeMode? newThemeMode) {
    if (_currentThemeMode != newThemeMode) {
      _currentThemeMode = newThemeMode;
      notifyListeners();
    }
  }

  ThemeMode? get currentThemeMode => _currentThemeMode;
}
