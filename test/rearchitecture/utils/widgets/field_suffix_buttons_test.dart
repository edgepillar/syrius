import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

class _Clipboard {
  final List<Completer<Object?>> reads = <Completer<Object?>>[];

  Future<Object?> handle(MethodCall call) async {
    if (call.method != 'Clipboard.getData') return null;
    expect(call.arguments, 'text/plain');
    final Completer<Object?> reply = Completer<Object?>();
    reads.add(reply);
    return reply.future;
  }

  void answer(int index, String text) =>
      reads[index].complete(<String, Object?>{'text': text});
}

Widget _host(TextEditingController controller, {ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                suffixIcon: FieldSuffixButtons(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );

_Clipboard _clipboard(WidgetTester tester) {
  final _Clipboard clipboard = _Clipboard();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    clipboard.handle,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, null,
    ),
  );
  return clipboard;
}

Future<void> _paste(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Paste'));
  await tester.pump();
}

void main() {
  for (final (String, ThemeData) theme in <(String, ThemeData)>[
    ('dark', AppTheme.darkTheme),
    ('light', AppTheme.lightTheme),
  ]) {
    testWidgets('suffix labels and current paste work in ${theme.$1}', (
      WidgetTester tester,
    ) async {
      final _Clipboard clipboard = _clipboard(tester);
      final TextEditingController controller = TextEditingController(
        text: 'draft',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, theme: theme.$2));
      expect(find.byTooltip('Paste'), findsOneWidget);
      expect(find.byTooltip('Clear'), findsOneWidget);
      await _paste(tester);
      expect(clipboard.reads, hasLength(1));
      expect(controller.text, 'draft');
      clipboard.answer(0, 'current clipboard');
      await tester.pump();
      expect(controller.text, 'current clipboard');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(controller.text, isEmpty);
      final IconButton clear = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.clear),
      );
      expect(clear.onPressed, isNull);
      expect(find.byTooltip('Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('clear invalidates an earlier clipboard request', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController controller = TextEditingController(
      text: 'draft',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _paste(tester);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    clipboard.answer(0, 'stale clipboard');
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(clipboard.reads, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing and restoring the original text still cancels paste', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController controller = TextEditingController(
      text: 'draft',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _paste(tester);
    await tester.enterText(find.byType(TextField), 'new edit');
    await tester.enterText(find.byType(TextField), 'draft');
    clipboard.answer(0, 'stale clipboard');
    await tester.pump();
    expect(controller.text, 'draft');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer paste owns the answer when reads finish out of order', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _paste(tester);
    await _paste(tester);
    expect(clipboard.reads, hasLength(2));
    clipboard.answer(1, 'new clipboard');
    await tester.pump();
    clipboard.answer(0, 'old clipboard');
    await tester.pump();
    expect(controller.text, 'new clipboard');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a replacement controller cannot receive the earlier answer', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController first = TextEditingController(text: 'first');
    final TextEditingController second = TextEditingController(text: 'second');
    addTearDown(second.dispose);
    await tester.pumpWidget(_host(first));
    final State<StatefulWidget> state = tester.state(
      find.byType(PasteContentButton),
    );
    await _paste(tester);
    await tester.pumpWidget(_host(second));
    expect(tester.state(find.byType(PasteContentButton)), same(state));
    first.dispose();
    clipboard.answer(0, 'stale clipboard');
    await tester.pump();
    expect(second.text, 'second');
    expect(tester.takeException(), isNull);
    await _paste(tester);
    clipboard.answer(1, 'replacement clipboard');
    await tester.pump();
    expect(second.text, 'replacement clipboard');
  });

  testWidgets('an unmounted suffix never writes to its disposed controller', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController controller = TextEditingController();
    await tester.pumpWidget(_host(controller));
    await _paste(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    clipboard.answer(0, 'stale clipboard');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving and restoring the selection invalidates paste', (
    WidgetTester tester,
  ) async {
    final _Clipboard clipboard = _clipboard(tester);
    final TextEditingController controller = TextEditingController(
      text: 'draft',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await _paste(tester);
    final TextSelection before = controller.selection;
    controller.selection = const TextSelection.collapsed(offset: 0);
    controller.selection = before;
    clipboard.answer(0, 'stale clipboard');
    await tester.pump();
    expect(controller.text, 'draft');
    expect(tester.takeException(), isNull);
  });
}
