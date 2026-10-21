import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/infinite_scroll_table/infinite_scroll_table.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/copy_to_clipboard_button.dart';

Widget _under(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };

  for (final MapEntry<String, ThemeData> entry in themes.entries) {
    group('in the ${entry.key} theme', () {
      testWidgets('a column head is in the faint token', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _under(
            entry.value,
            const Row(
              children: <Widget>[
                InfiniteScrollTableColumn(
                  alignment: MainAxisAlignment.start,
                  name: 'Amount',
                ),
              ],
            ),
          ),
        );

        final BuildContext context = tester.element(find.text('AMOUNT'));
        final Text head = tester.widget<Text>(find.text('AMOUNT'));
        expect(head.style!.color, AppTokens.of(context).faint);
      });

      testWidgets('the copy button has a tooltip and copies its text', (
        WidgetTester tester,
      ) async {
        final List<String?> copied = <String?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map<Object?, Object?>)['text']
                  as String?);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await tester.pumpWidget(
          _under(
            entry.value,
            const CopyToClipboardButton('z1qq', iconSize: 15),
          ),
        );

        expect(find.byTooltip('Copy'), findsOneWidget);

        // Reachable from the keyboard.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<CopyToClipboardButton>(),
          isNotNull,
        );

        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(copied, <String>['z1qq']);

        // Let the "copied" check and the toast run out.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      });

      testWidgets('a caller tooltip of the same message is not doubled', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _under(
            entry.value,
            const Tooltip(
              message: 'Copy',
              child: CopyToClipboardButton('z1qq'),
            ),
          ),
        );

        expect(find.byTooltip('Copy'), findsOneWidget);
      });
    });
  }
}
