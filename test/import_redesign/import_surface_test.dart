import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/hero_field.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_draft.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/import_wallet/import_surface.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';

import 'support.dart';

ImportSeedDraft _draft(String text, {int count = 12, bool valid = false}) =>
    ImportSeedDraft(
      text,
      expectedWords: count,
      isValidWord: (_) => true,
      validateMnemonic: (_) => valid,
    );

ImportSurface _surface(
  TextEditingController controller, {
  bool file = false,
  bool refused = false,
  bool pickerFailed = false,
  VoidCallback? onContinue,
  VoidCallback? onBrowse,
}) => ImportSurface(
  seedController: controller,
  draft: _draft(controller.text),
  fileSelected: file,
  fileRefused: refused,
  pickerFailed: pickerFailed,
  onSeedChanged: (_) {},
  onWordCountChanged: (_) {},
  onBack: () {},
  onContinue: onContinue,
  onBrowse: onBrowse ?? () {},
  background: const SizedBox.expand(),
);

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'the ${light ? 'light' : 'dark'} import view keeps its measured card',
      (
        WidgetTester tester,
      ) async {
        prepareEntryViewport(tester);
        final TextEditingController controller = TextEditingController(
          text: List<String>.generate(
            8,
            (int index) => 'fixture-$index',
          ).join(' '),
        );
        disposeEntryControllers(tester, <TextEditingController>[controller]);
        await tester.pumpWidget(entryHost(_surface(controller), light: light));
        await tester.pump(const Duration(milliseconds: 401));
        expect(
          tester.getSize(find.byKey(const Key('import_screen_marker'))).width,
          620,
        );
        expect(find.text('8 of 12'), findsOneWidget);
        expect(find.byType(HeroField), findsNothing);
        expect(
          tester
              .widget<PrimaryPill>(find.byKey(const Key('import_continue')))
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'file admission displays a fact without receiving a private path',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final TextEditingController controller = TextEditingController();
      disposeEntryControllers(tester, <TextEditingController>[controller]);
      int requests = 0;
      await tester.pumpWidget(
        entryHost(
          _surface(controller, file: true, onContinue: () => requests++),
        ),
      );
      expect(find.text('Wallet file selected'), findsOneWidget);
      expect(find.textContaining('fixture.private'), findsNothing);
      await tester.tap(find.byKey(const Key('import_continue')));
      expect(requests, 1);
      await tester.pumpWidget(entryHost(_surface(controller, refused: true)));
      expect(find.text('Not a Syrius wallet file'), findsOneWidget);
      expect(find.text('Wallet file selected'), findsNothing);
      expect(
        tester
            .widget<PrimaryPill>(find.byKey(const Key('import_continue')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a picker failure has a mapped label and no previous file action',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final TextEditingController controller = TextEditingController();
      disposeEntryControllers(tester, <TextEditingController>[controller]);
      await tester.pumpWidget(
        entryHost(_surface(controller, pickerFailed: true)),
      );
      expect(
        find.text('Could not open the file picker. Try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PrimaryPill>(find.byKey(const Key('import_continue')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a narrow scaled RTL card retains the field and reachable action',
    (
      WidgetTester tester,
    ) async {
      const Size size = Size(540, 360);
      prepareEntryViewport(tester, size: size);
      final TextEditingController controller = TextEditingController();
      disposeEntryControllers(tester, <TextEditingController>[controller]);
      int requests = 0;
      await tester.pumpWidget(
        entryHost(
          _surface(controller, file: true, onContinue: () => requests++),
          size: size,
          rtl: true,
          scale: 2.5,
        ),
      );
      await tester.pump(const Duration(milliseconds: 401));
      await tester.ensureVisible(find.byKey(const Key('import_continue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('import_continue')));
      expect(requests, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('import_seed_field')))
            .textDirection,
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard activation requests browsing without a platform adapter',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final TextEditingController controller = TextEditingController();
      disposeEntryControllers(tester, <TextEditingController>[controller]);
      int requests = 0;
      await tester.pumpWidget(
        entryHost(_surface(controller, onBrowse: () => requests++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(requests, 1);
    },
  );

  testWidgets(
    'pure password and unlock views obscure input and respect busy state',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final TextEditingController password = TextEditingController();
      final TextEditingController confirmation = TextEditingController();
      disposeEntryControllers(tester, <TextEditingController>[
        password,
        confirmation,
      ]);
      await tester.pumpWidget(
        entryHost(
          ImportPasswordSurface(
            password: password,
            confirmation: confirmation,
            onChanged: () {},
            onBack: () {},
            onContinue: null,
            background: const SizedBox.expand(),
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('import_new_password')))
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('import_confirm_password')))
            .obscureText,
        isTrue,
      );
      await tester.pumpWidget(
        entryHost(
          ImportUnlockSurface(
            password: password,
            onChanged: () {},
            onBack: () {},
            onContinue: () {},
            busy: true,
            error: 'Incorrect password',
            background: const SizedBox.expand(),
          ),
        ),
      );
      final TextField unlock = tester.widget<TextField>(
        find.byKey(const Key('import_unlock_password')),
      );
      expect(unlock.obscureText, isTrue);
      expect(unlock.enabled, isFalse);
      expect(
        tester
            .widget<PrimaryPill>(
              find.byKey(const Key('import_unlock_continue')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Incorrect password'), findsOneWidget);
    },
  );
}
