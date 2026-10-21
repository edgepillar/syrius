import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/onboarding_scaffold.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/error_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/loading_widget.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/seed/seed_grid.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/stepper_utils.dart';

/// The restyled chrome before the wallet opens, and the dialog and stepper
/// parts every page shares. What is checked is behaviour a restyle must not
/// change, and layout that used to break.
Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: child),
);

Future<void> _setWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('dialogs', () {
    testWidgets('no and yes answer through their keys', (
      WidgetTester tester,
    ) async {
      final List<bool?> answers = <bool?>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => answers.add(
                await showDialogWithNoAndYesOptions(
                  context: context,
                  title: 'Send',
                  description: 'Send 1 ZNN?',
                  isBarrierDismissible: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Send 1 ZNN?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialog_yes_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_no_button')));
      await tester.pumpAndSettle();

      expect(answers, <bool?>[true, false]);
    });

    testWidgets('a warning reports whether its action was pressed', (
      WidgetTester tester,
    ) async {
      final List<bool> answers = <bool>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => answers.add(
                await showWarningDialog(
                  context: context,
                  title: 'Reset',
                  description: 'This erases the wallet',
                  buttonText: '',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // An empty action label falls back to OK.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answers, <bool>[true, false]);
    });

    testWidgets('a custom dialog fades in and is dismissed by its barrier', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showCustomDialog(
                context: context,
                content: const SizedBox(
                  width: 200,
                  height: 100,
                  child: Text('modal'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('modal'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('modal'), findsNothing);
    });
  });

  group('small states', () {
    testWidgets('the error line maps a closed client and offers a retry', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(
        _app(
          SyriusErrorWidget(
            'Bad state: The client is closed',
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.text('Not connected to the network'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('no retry without a handler', (WidgetTester tester) async {
      await tester.pumpWidget(_app(const SyriusErrorWidget('boom')));
      expect(find.text('boom'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('the loading ring keeps its size inside a larger box', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            height: 300,
            child: SyriusLoadingWidget(),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(24, 24),
      );
    });

    testWidgets('the entrance ends fully shown and in place', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const RiseIn(child: Text('in'))));
      await tester.pumpAndSettle();
      final FadeTransition fade = tester.widget(
        find
            .ancestor(
              of: find.text('in'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1);
    });
  });

  group('onboarding', () {
    testWidgets('shows the step position and one primary action', (
      WidgetTester tester,
    ) async {
      int backs = 0;
      await _setWindow(tester, const Size(1200, 600));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: OnboardingScaffold(
            step: 2,
            title: 'Confirm your seed',
            onBack: () => backs++,
            primary: OutlinedButton(
              onPressed: () {},
              child: const Text('Verify'),
            ),
            child: const SizedBox(height: 900),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STEP 2 OF 5'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      await tester.tap(find.text('Back'));
      expect(backs, 1);
      // Content taller than the window scrolls instead of overflowing.
      expect(tester.takeException(), isNull);
    });
  });

  group('seed grid', () {
    testWidgets('24 words fit the narrowest window and take input', (
      WidgetTester tester,
    ) async {
      final GlobalKey<SeedGridState> key = GlobalKey<SeedGridState>();
      int changes = 0;
      await _setWindow(tester, const Size(1200, 600));
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 880,
              child: SeedGrid(
                List<String>.generate(24, (int i) => ''),
                key: key,
                isContinueButtonDisabled: true,
                onTextFieldChangedCallback: () => changes++,
              ),
            ),
          ),
        ),
      );
      // The old fixed 200 px cells made a 24-word row 1,250 px wide.
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(24));

      await tester.enterText(find.byType(TextField).first, 'abandon');
      await tester.pump();
      expect(key.currentState!.getSeedWords.first, 'abandon');
      expect(changes, 1);
      // The other 23 are still empty, so the seed is not yet acceptable.
      expect(key.currentState!.continueButtonDisabled, isTrue);
    });

    testWidgets('a full valid seed enables continue', (
      WidgetTester tester,
    ) async {
      final GlobalKey<SeedGridState> key = GlobalKey<SeedGridState>();
      await _setWindow(tester, const Size(1200, 600));
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 880,
            child: SeedGrid(
              List<String>.generate(12, (int i) => ''),
              key: key,
              isContinueButtonDisabled: true,
            ),
          ),
        ),
      );
      const List<String> words = <String>[
        'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
        'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
      ];
      for (int i = 0; i < words.length; i++) {
        await tester.enterText(find.byType(TextField).at(i), words[i]);
        await tester.pump();
      }
      expect(key.currentState!.getSeed, words.join(' '));
      expect(key.currentState!.continueButtonDisabled, isFalse);
    });
  });

  group('stepper', () {
    testWidgets('draws every step with no overflow', (
      WidgetTester tester,
    ) async {
      await _setWindow(tester, const Size(1200, 600));
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (BuildContext context) => stepper.Stepper(
              currentStep: 1,
              steps: <stepper.Step>[
                for (int i = 0; i < 3; i++)
                  StepperUtils.getMaterialStep(
                    stepTitle: 'Step $i',
                    stepContent: Text('content $i'),
                    stepSubtitle: 'done $i',
                    stepState: StepperUtils.getStepState(i, 0),
                    context: context,
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Step 0'), findsOneWidget);
      // A finished step shows its subtitle; the current one its content.
      expect(find.text('done 0'), findsOneWidget);
      expect(find.text('content 1'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      // The current step's number is drawn in the dark ink of the green dot.
      final Text two = tester.widget(find.text('2'));
      expect(two.style!.color, kOnZnnColor);
    });
  });
}
