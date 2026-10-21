import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/utils/notifiers/locale_notifier.dart';

/// The delegates `MaterialApp` is given: the app's own messages, then
/// `material_ui`'s set for Material, Cupertino and the widgets layer.
///
/// Not [AppLocalizations.localizationsDelegates]. That list is generated, and
/// its Material and Cupertino delegates are the SDK's `flutter_localizations`
/// ones, which localise the Material frozen in the SDK. The app's widgets
/// come from `material_ui` and look up that package's `MaterialLocalizations`,
/// a different type: given only the generated list, a date picker or a
/// tooltip in Arabic finds none.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

/// The locale the app is showing: the language chosen in Settings, or for
/// "System" the first of the platform's locales the app has, else English.
///
/// Worked out on each read, from what `MaterialApp` is given: the notifier's
/// choice, [resolveAppLocale] and the platform's list. Recording what the
/// resolution callback returned would be one step shorter and wrong: going
/// from a chosen language back to "System", Flutter reuses the locale it
/// resolved at the start and does not call the callback again, so the record
/// would stay on the language just left.
///
/// The platform's list is the engine's own, so that this works with no
/// binding, as in a plain unit test of a validator. A widget test that fakes
/// the list with `localesTestValue` is therefore not seen here: choose the
/// language through a [LocaleNotifier] instead.
Locale get currentAppLocale {
  final Locale? chosen = LocaleNotifier.chosenLocale;
  return resolveAppLocale(
    chosen == null ? PlatformDispatcher.instance.locales : <Locale>[chosen],
    AppLocalizations.supportedLocales,
  );
}

/// The app's messages in [currentAppLocale], for code with no `BuildContext`:
/// the input validators, which are static and called from field callbacks,
/// and the text of a Ledger error or of a time in a table row.
///
/// A widget reads `context.l10n` instead, which also rebuilds it when the
/// language changes. A message from here is a plain string: it is in the
/// language of the moment it was made, so make it when it is shown, and do
/// not keep it.
AppLocalizations get currentL10n => lookupAppLocalizations(currentAppLocale);
