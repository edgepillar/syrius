import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';

/// Shows a page: a rail page by its number, or the lock.
class OpenPageIntent extends Intent {
  /// Creates the intent for [tab].
  const OpenPageIntent(this.tab);

  /// The page to show.
  final Tabs tab;
}

/// Opens the "Go to" palette.
class OpenGoToIntent extends Intent {
  /// Creates the intent.
  const OpenGoToIntent();
}

/// Opens the rail if it is collapsed, collapses it if it is open.
class ToggleRailIntent extends Intent {
  /// Creates the intent.
  const ToggleRailIntent();
}

/// Whether the chord key is Cmd. On macOS Ctrl with a letter edits text
/// (Ctrl+K kills to the end of the line), and Cmd is where a Mac user looks
/// for an application's shortcuts.
final bool _kChordIsMeta = defaultTargetPlatform == TargetPlatform.macOS;

/// The chord key's name, for the hints in the palette.
final String kChordName = _kChordIsMeta ? 'Cmd' : 'Ctrl';

/// [key] with the chord key and nothing else held.
SingleActivator _chord(LogicalKeyboardKey key) =>
    SingleActivator(key, control: !_kChordIsMeta, meta: _kChordIsMeta);

const List<LogicalKeyboardKey> _kDigitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const List<LogicalKeyboardKey> _kNumpadKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// The shell's bindings while the wallet is unlocked.
final Map<ShortcutActivator, Intent> kShellShortcuts =
    <ShortcutActivator, Intent>{
      for (
        int i = 0;
        i < kRailPages.length && i < 9;
        i++
      ) ...<ShortcutActivator, Intent>{
        _chord(_kDigitKeys[i]): OpenPageIntent(kRailPages[i].tab),
        _chord(_kNumpadKeys[i]): OpenPageIntent(kRailPages[i].tab),
      },
      _chord(LogicalKeyboardKey.keyL): const OpenPageIntent(Tabs.lock),
      _chord(LogicalKeyboardKey.keyK): const OpenGoToIntent(),
      _chord(LogicalKeyboardKey.keyB): const ToggleRailIntent(),
    };
