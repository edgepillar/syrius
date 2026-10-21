import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';

/// Where the choice is kept in the shared prefs box. Its own key: the
/// per-card entries of the old discreet mode are keyed by card title and
/// mean something else.
const String kBalancesHiddenKey = 'balances_hidden';

/// Whether every amount in the wallet is drawn as dots: the stored choice,
/// and the one place that reads and writes it.
///
/// One state for the whole wallet, because the use is sharing a screen and
/// a figure left showing on one page defeats it. A notifier and not a field
/// of a page, because three things change it (the eye in the Home hero, the
/// shortcut and the switch in Settings) and every page that shows an amount
/// follows it.
///
/// A profile that has never chosen sees its balances. With no box open (a
/// test, or a start that has not reached the preferences yet) it works in
/// memory and stores nothing, so a widget that reads it never needs one.
class BalanceVisibility extends ChangeNotifier {
  /// Starts from what is stored, or shown when nothing is.
  BalanceVisibility() : _hidden = _stored();

  static BalanceVisibility? _instance;

  /// The wallet's own. Made when first asked for and not before: it reads
  /// the box as it is made, and the box opens during start.
  // Not a constructor: it hands back the one it made before.
  // ignore: prefer_constructors_over_static_methods
  static BalanceVisibility get instance => _instance ??= BalanceVisibility();

  /// Forgets [instance], so the next one reads the box again.
  @visibleForTesting
  static void debugReset() => _instance = null;

  bool _hidden;

  /// Whether amounts are dots.
  bool get hidden => _hidden;

  /// Hides what is shown and shows what is hidden.
  void toggle() => set(!_hidden);

  /// Hides or shows, and stores which for the next start. Says nothing when
  /// that is already the state, so a switch bound both ways does not loop.
  // A setter in all but name: a switch hands its value straight to it.
  // ignore: avoid_positional_boolean_parameters
  void set(bool hidden) {
    if (hidden == _hidden) {
      return;
    }
    _hidden = hidden;
    notifyListeners();
    unawaited(_store(hidden));
  }

  static bool _stored() {
    final SharedPrefsService? prefs = sharedPrefsService;
    if (prefs == null) {
      return false;
    }
    try {
      // Anything but a bool is a damaged entry, and reads as never chosen.
      final Object? stored = prefs.get(kBalancesHiddenKey);
      return stored is bool && stored;
    } on Object {
      // A service whose box was never opened.
      return false;
    }
  }

  static Future<void> _store(bool hidden) async {
    try {
      await sharedPrefsService?.put(kBalancesHiddenKey, hidden);
    } on Object {
      // The box is closed: the choice lasts as long as this notifier.
    }
  }
}
