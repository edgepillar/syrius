import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

/// What a [Switch] in one state is painted with.
class _Paint {
  const _Paint(this.thumb, this.track, this.outline);

  final Color thumb;
  final Color track;
  final Color outline;
}

/// Pumps a [Switch] under [theme] and resolves the colours it gets for
/// [states]: its own first, as the widget does, then the theme's.
Future<_Paint> _paintOf(
  WidgetTester tester,
  ThemeData theme,
  Set<WidgetState> states,
) async {
  final bool on = states.contains(WidgetState.selected);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Material(
        child: Switch(
          value: on,
          onChanged: states.contains(WidgetState.disabled) ? null : (_) {},
        ),
      ),
    ),
  );
  final Switch widget = tester.widget<Switch>(find.byType(Switch));
  expect(widget.value, on);
  final SwitchThemeData switchTheme = SwitchTheme.of(
    tester.element(find.byType(Switch)),
  );
  return _Paint(
    (widget.thumbColor ?? switchTheme.thumbColor)!.resolve(states)!,
    (widget.trackColor ?? switchTheme.trackColor)!.resolve(states)!,
    (widget.trackOutlineColor ?? switchTheme.trackOutlineColor)!.resolve(
      states,
    )!,
  );
}

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'dark': AppTheme.darkTheme,
    'light': AppTheme.lightTheme,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    group('Switch in the ${entry.key} theme', () {
      const Set<WidgetState> onStates = <WidgetState>{WidgetState.selected};
      const Set<WidgetState> offStates = <WidgetState>{};

      testWidgets('on: the thumb is not the colour of its track', (
        WidgetTester tester,
      ) async {
        final _Paint on = await _paintOf(tester, entry.value, onStates);
        expect(on.thumb, isNot(on.track));
        expect(on.thumb.a, 1);
        expect(on.track.a, 1);
      });

      testWidgets('off: the thumb is not the colour of its track', (
        WidgetTester tester,
      ) async {
        final _Paint off = await _paintOf(tester, entry.value, offStates);
        expect(off.thumb, isNot(off.track));
        // The outline is what separates the quiet track from the panel.
        expect(off.outline.a, 1);
        expect(off.outline, isNot(off.track));
      });

      testWidgets('the on track is not the off track', (
        WidgetTester tester,
      ) async {
        final _Paint on = await _paintOf(tester, entry.value, onStates);
        final _Paint off = await _paintOf(tester, entry.value, offStates);
        expect(on.track, isNot(off.track));
        expect(on.thumb, isNot(off.thumb));
      });

      testWidgets('disabled: still two states, each with a thumb', (
        WidgetTester tester,
      ) async {
        final _Paint on = await _paintOf(tester, entry.value, <WidgetState>{
          WidgetState.selected,
          WidgetState.disabled,
        });
        final _Paint off = await _paintOf(tester, entry.value, <WidgetState>{
          WidgetState.disabled,
        });
        expect(on.thumb, isNot(on.track));
        expect(off.thumb, isNot(off.track));
        expect(on.track, isNot(off.track));

        final _Paint enabled = await _paintOf(tester, entry.value, onStates);
        expect(on.track, isNot(enabled.track));
      });
    });
  }
}
