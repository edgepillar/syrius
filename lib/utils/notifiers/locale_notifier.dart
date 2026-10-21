import 'package:flutter/widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

/// The languages the interface can be shown in.
///
/// Each is named in its own script, so a person who cannot read the
/// language the wallet is in now can still find theirs in the list.
enum AppLanguage {
  /// Follows the operating system, resolved by [resolveAppLocale].
  system(null, 'System'),
  english(Locale('en'), 'English'),

  /// Simplified Chinese: the only Chinese there is, so zh_TW lands here too.
  chinese(Locale('zh'), '中文'),
  hindi(Locale('hi'), 'हिन्दी'),
  spanish(Locale('es'), 'Español'),
  arabic(Locale('ar'), 'العربية');

  const AppLanguage(this.locale, this.nativeName);

  /// What `MaterialApp.locale` is set to; null leaves it to the system.
  final Locale? locale;

  /// The language's name in its own script.
  final String nativeName;

  /// The language saved as [stored], which is its `toString`, the form the
  /// theme and the text size are saved in. Anything else is the default: a
  /// first start, or a language a newer version saved and this one lacks.
  static AppLanguage fromStored(Object? stored) => values.firstWhere(
    (AppLanguage language) => language.toString() == stored,
    orElse: () => kDefaultAppLanguage,
  );
}

/// The app's locale for a person whose [preferred] locales, most wanted
/// first, are these: the first one whose language the app has, matched on
/// the language alone, so zh_TW and zh_Hans_CN both become zh. When none
/// match, English.
///
/// Given to `MaterialApp.localeListResolutionCallback`. Flutter's own
/// fallback is the first of [supported] after a partial match on country,
/// which would make an unsupported language depend on the list's order.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final Locale wanted in preferred ?? const <Locale>[]) {
    for (final Locale locale in supported) {
      if (locale.languageCode == wanted.languageCode) {
        return locale;
      }
    }
  }
  return const Locale('en');
}

class LocaleNotifier extends ChangeNotifier {
  /// Starts in [initial]. `main` passes the saved language, so the first
  /// frame is already in it; set later, an Arabic wallet opened left to
  /// right in English and flipped once the launch animation had played.
  LocaleNotifier([AppLanguage initial = kDefaultAppLanguage])
    : _currentLanguage = initial {
    _chosen = initial;
  }

  AppLanguage _currentLanguage;

  /// The language of the notifier made or changed last; the app has one.
  /// Kept for `currentL10n` (lib/l10n/l10n.dart), which words the messages
  /// made where there is no BuildContext to find the notifier through.
  static AppLanguage _chosen = kDefaultAppLanguage;

  /// What the app's `MaterialApp.locale` is set to, read without a context.
  static Locale? get chosenLocale => _chosen.locale;

  void changeLanguage(AppLanguage newLanguage) {
    if (_currentLanguage != newLanguage) {
      _currentLanguage = newLanguage;
      _chosen = newLanguage;
      notifyListeners();
    }
  }

  AppLanguage get currentLanguage => _currentLanguage;

  /// What `MaterialApp.locale` is set to.
  Locale? get locale => _currentLanguage.locale;
}
