import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

/// A save the test finishes by hand, in the order and with the outcome it
/// picks.
class _Saves {
  final List<int> values = <int>[];
  final List<Completer<bool>> _open = <Completer<bool>>[];

  Future<bool> call(int value) {
    values.add(value);
    _open.add(Completer<bool>());
    return _open.last.future;
  }

  /// Finishes the save started [index]th, counted from 0.
  void finish(int index, {required bool ok}) => _open[index].complete(ok);
}

Widget _host(_Saves saves) => MaterialApp(
  home: Scaffold(
    body: SliderSetting(
      label: 'Auto-lock',
      hintOf: (int value) => 'After $value minutes',
      saved: 0,
      min: 0,
      max: 10,
      onCommitted: saves.call,
    ),
  ),
);

int _shown(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider)).value.round();

/// Clicks the track where [value] is.
Future<void> _click(WidgetTester tester, int value) async {
  final Rect rect = tester.getRect(find.byType(Slider));
  // The track stops short of each end by the thumb's overlay.
  const double inset = 24;
  await tester.tapAt(
    Offset(
      rect.left + inset + (rect.width - 2 * inset) * value / 10,
      rect.center.dy,
    ),
  );
  await tester.pump();
}

Future<void> _focus(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

void main() {
  group('SliderSetting saves', () {
    testWidgets('a release by pointer saves at once', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      expect(saves.values, <int>[5]);
      expect(find.text('After 5 minutes'), findsOneWidget);

      saves.finish(0, ok: true);
      await tester.pump();
      expect(_shown(tester), 5);
    });

    testWidgets('a failed save goes back to the stored value', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      saves.finish(0, ok: false);
      await tester.pump();
      expect(_shown(tester), 0);

      // The value that failed can be picked again.
      await _click(tester, 5);
      expect(saves.values, <int>[5, 5]);
    });

    testWidgets('an older save failing after a newer one keeps the newer', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      await _click(tester, 8);
      expect(saves.values, <int>[5, 8]);

      saves.finish(1, ok: true);
      await tester.pump();
      saves.finish(0, ok: false);
      await tester.pump();
      expect(_shown(tester), 8);
      expect(find.text('After 8 minutes'), findsOneWidget);

      // 8 is what is stored, so picking it again saves nothing.
      await _click(tester, 8);
      expect(saves.values, <int>[5, 8]);
    });

    testWidgets('an older save failing before a newer one lands is ignored', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      await _click(tester, 8);
      saves.finish(0, ok: false);
      await tester.pump();
      expect(_shown(tester), 8);

      saves.finish(1, ok: true);
      await tester.pump();
      expect(_shown(tester), 8);
    });

    testWidgets('the newest save failing rests on the older one that landed', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      await _click(tester, 8);
      saves.finish(1, ok: false);
      await tester.pump();
      expect(_shown(tester), 0);

      saves.finish(0, ok: true);
      await tester.pump();
      expect(_shown(tester), 5);
    });
  });

  group('SliderSetting keys', () {
    testWidgets('a held arrow key saves once, after the last step', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));
      await _focus(tester);

      for (int step = 0; step < 4; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_shown(tester), 4);
      expect(find.text('After 4 minutes'), findsOneWidget);
      expect(saves.values, isEmpty);

      // 100 ms have passed since the last step.
      await tester.pump(
        kSliderKeySaveDelay - const Duration(milliseconds: 101),
      );
      expect(saves.values, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(saves.values, <int>[4]);

      saves.finish(0, ok: true);
      await tester.pump();
      expect(_shown(tester), 4);
    });

    testWidgets('steps that end on the saved value save nothing', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));
      await _focus(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_shown(tester), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(kSliderKeySaveDelay);
      expect(saves.values, isEmpty);
    });

    testWidgets('a pointer release drops the wait and saves its own value', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));
      await _focus(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _click(tester, 7);
      expect(saves.values, <int>[7]);

      await tester.pump(kSliderKeySaveDelay);
      expect(saves.values, <int>[7]);
    });

    testWidgets('a key step after a click still waits', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));

      await _click(tester, 5);
      saves.finish(0, ok: true);
      await tester.pump();

      await _focus(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_shown(tester), 6);
      expect(saves.values, <int>[5]);

      await tester.pump(kSliderKeySaveDelay);
      expect(saves.values, <int>[5, 6]);
    });

    testWidgets('steps waiting when the slider is disposed are saved', (
      WidgetTester tester,
    ) async {
      final _Saves saves = _Saves();
      await tester.pumpWidget(_host(saves));
      await _focus(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      expect(saves.values, isEmpty);

      await tester.pumpWidget(const SizedBox());
      expect(saves.values, <int>[2]);

      // Nothing is left to fire, and a result that comes back late is not
      // drawn on a slider that is gone.
      await tester.pump(kSliderKeySaveDelay);
      saves.finish(0, ok: false);
      await tester.pump();
      expect(saves.values, <int>[2]);
      expect(tester.takeException(), isNull);
    });
  });
}
