import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';

Widget _app(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

Finder get _gradient => find.descendant(
  of: find.byType(PrimaryPill),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is ShapeDecoration &&
        (widget.decoration as ShapeDecoration).gradient != null,
  ),
);

void main() {
  for (final ThemeData theme in <ThemeData>[
    AppTheme.darkTheme,
    AppTheme.lightTheme,
  ]) {
    testWidgets('primary plasma fill in ${theme.brightness.name}', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(PrimaryPill(onPressed: () {}, child: const Text('Stake')), theme),
      );
      final AppTokens tokens = theme.extension<AppTokens>()!;
      expect(_gradient, findsOneWidget);
      final ShapeDecoration decoration =
          tester.widget<DecoratedBox>(_gradient).decoration as ShapeDecoration;
      expect(decoration.gradient, tokens.plasma);
      expect(decoration.shape, const StadiumBorder());
      final OutlinedButton button = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(
        button.style!.backgroundColor!.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        button.style!.foregroundColor!.resolve(<WidgetState>{}),
        tokens.primaryButtonForeground,
      );
    });
  }

  testWidgets('disabled action dims its fill without changing geometry', (
    WidgetTester tester,
  ) async {
    const AppTokens tokens = AppTokens.dark;
    await tester.pumpWidget(
      _app(
        PrimaryPill(onPressed: () {}, child: const Text('Stake')),
        AppTheme.darkTheme,
      ),
    );
    final Size enabledSize = tester.getSize(find.byType(PrimaryPill));
    await tester.pumpWidget(
      _app(
        const PrimaryPill(onPressed: null, child: Text('Stake')),
        AppTheme.darkTheme,
      ),
    );
    expect(_gradient, findsOneWidget);
    expect(tester.getSize(find.byType(PrimaryPill)), enabledSize);
    final Finder opacity = find.descendant(
      of: find.byType(PrimaryPill),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity).opacity, tokens.disabledOpacity);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('keyboard activation and caller sizing survive decoration', (
    WidgetTester tester,
  ) async {
    int presses = 0;
    await tester.pumpWidget(
      _app(
        PrimaryPill(
          onPressed: () => presses++,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll<Size>(Size(180, 48)),
          ),
          icon: const Icon(Icons.add),
          child: const Text('Stake'),
        ),
        AppTheme.darkTheme,
      ),
    );
    final Finder button = find.byType(OutlinedButton);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(180));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.add));
    expect(
      IconTheme.of(tester.element(find.byWidget(icon))).color,
      AppTokens.dark.primaryButtonForeground,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 1);
  });
}
