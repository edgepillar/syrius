import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/extensions/buildcontext_extension.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';

/// One destination a [GoToPalette] offers.
class GoToEntry<T> {
  /// Creates an entry that answers [value] when chosen.
  const GoToEntry({
    required this.value,
    required this.label,
    this.icon,
    this.shortcut,
  });

  /// What the palette returns for this entry.
  final T value;

  /// The name shown, and what the typed text is matched against.
  final String label;

  /// Shown before the label.
  final IconData? icon;

  /// The entry's own key chord, shown at the right so it can be learned
  /// ("Ctrl 2"). Not handled here.
  final String? shortcut;
}

/// Opens a [GoToPalette] over the page and completes with the entry chosen,
/// or null when it is dismissed.
Future<T?> showGoToPalette<T>({
  required BuildContext context,
  required List<GoToEntry<T>> entries,
  String? hintText,
}) {
  return showFrostedDialog<T>(
    context: context,
    builder: (BuildContext context) =>
        GoToPalette<T>(entries: entries, hintText: hintText),
  );
}

/// A text field over a filtered list of destinations: type a few letters,
/// press Enter, be there.
///
/// The list narrows to the entries whose label contains what was typed,
/// those that start with it first. Up and Down move the highlight, Enter
/// takes the highlighted entry, Escape closes. The mouse works too: a row
/// highlights under the pointer and a click takes it.
///
/// The palette pops its route with the chosen [GoToEntry.value]; use
/// [showGoToPalette] to open it.
class GoToPalette<T> extends StatefulWidget {
  /// Creates a palette over [entries].
  const GoToPalette({
    required this.entries,
    this.hintText,
    super.key,
  });

  /// Every destination, in the order shown before anything is typed.
  final List<GoToEntry<T>> entries;

  /// The field's hint. Null says "Go to" in the app's language: a default
  /// value cannot read one.
  final String? hintText;

  @override
  State<GoToPalette<T>> createState() => _GoToPaletteState<T>();
}

class _GoToPaletteState<T> extends State<GoToPalette<T>> {
  static const double _kRowHeight = 40;
  static const int _kRowsShown = 8;

  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late List<GoToEntry<T>> _matches = widget.entries;
  int _highlighted = 0;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    final String needle = text.trim().toLowerCase();
    final List<GoToEntry<T>> starts = <GoToEntry<T>>[];
    final List<GoToEntry<T>> contains = <GoToEntry<T>>[];
    for (final GoToEntry<T> entry in widget.entries) {
      final String label = entry.label.toLowerCase();
      if (label.startsWith(needle)) {
        starts.add(entry);
      } else if (label.contains(needle)) {
        contains.add(entry);
      }
    }
    setState(() {
      _matches = <GoToEntry<T>>[...starts, ...contains];
      _highlighted = 0;
    });
  }

  void _move(int by) {
    if (_matches.isEmpty) {
      return;
    }
    setState(() {
      _highlighted = (_highlighted + by) % _matches.length;
    });
    // Keep the highlighted row inside the list's window.
    if (_scroll.hasClients) {
      final double top = _highlighted * _kRowHeight;
      final double bottom = top + _kRowHeight;
      final ScrollPosition position = _scroll.position;
      if (top < position.pixels) {
        _scroll.jumpTo(top);
      } else if (bottom > position.pixels + position.viewportDimension) {
        _scroll.jumpTo(bottom - position.viewportDimension);
      }
    }
  }

  void _take([int? index]) {
    final int at = index ?? _highlighted;
    if (at < 0 || at >= _matches.length) {
      return;
    }
    Navigator.of(context).pop(_matches[at].value);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final Color line = theme.dividerTheme.color ?? theme.dividerColor;
    final int rows = _matches.length.clamp(1, _kRowsShown);
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: theme.colorScheme.primary,
            elevation: 12,
            shadowColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              side: BorderSide(color: line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The arrows belong to the list while the field has the
                // keyboard; in a one-line field they would only jump the
                // caret to an end.
                CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                        _move(1),
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                        _move(-1),
                  },
                  child: TextField(
                    key: const Key('go_to_field'),
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: widget.hintText ?? context.l10n.goToPaletteHint,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: tokens.faint,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _take(),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: line),
                if (_matches.isEmpty)
                  SizedBox(
                    height: _kRowHeight + 12,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.goToPaletteEmpty,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: rows * _kRowHeight + 12,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemExtent: _kRowHeight,
                      itemCount: _matches.length,
                      itemBuilder: (BuildContext context, int index) => _Row<T>(
                        entry: _matches[index],
                        highlighted: index == _highlighted,
                        onHover: () {
                          if (_highlighted != index) {
                            setState(() => _highlighted = index);
                          }
                        },
                        onTap: () => _take(index),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row<T> extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final GoToEntry<T> entry;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppTokens tokens = AppTokens.of(context);
    final Color dim = theme.textTheme.titleMedium?.color ?? tokens.faint;
    final Color ink = theme.textTheme.bodyLarge?.color ?? dim;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            key: ValueKey<String>('go_to_${entry.label}'),
            duration: Durations.short2,
            curve: Easing.standard,
            decoration: BoxDecoration(
              color: highlighted
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(tokens.cardRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                if (entry.icon != null) ...<Widget>[
                  Icon(
                    entry.icon,
                    size: 18,
                    color: highlighted ? tokens.znnInk : dim,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      color: highlighted ? ink : dim,
                    ),
                  ),
                ),
                if (entry.shortcut != null)
                  Text(
                    entry.shortcut!,
                    style: monoStyle(
                      theme.textTheme.titleSmall,
                    ).copyWith(fontSize: 12, color: tokens.faint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
