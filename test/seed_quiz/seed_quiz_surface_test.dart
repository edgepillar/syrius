import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/entry_action_boundary.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/new_wallet/seed_quiz.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/new_wallet/seed_quiz_surface.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';

import '../import_redesign/support.dart';

SeedQuiz _quiz() => SeedQuiz(
  List<String>.generate(12, (int index) => 'fixture-$index'),
  random: Random(9),
  isValidWord: (_) => true,
  validateMnemonic: (_) => true,
);

class _Fixture extends StatefulWidget {
  const _Fixture({required this.quiz, required this.onContinue});

  final SeedQuiz quiz;
  final VoidCallback onContinue;

  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  Object _source = Object();

  @override
  void didUpdateWidget(_Fixture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.quiz, widget.quiz)) _source = Object();
  }

  @override
  Widget build(BuildContext context) => EntryActionBoundary(
    source: _source,
    builder: (_, EntryActionLease lease) => SeedQuizSurface(
      quiz: widget.quiz,
      onSelected: (int question, String word) {
        if (lease.isCurrent && widget.quiz.select(question, word)) {
          setState(() => _source = Object());
        }
      },
      onBack: lease.guard(() {}),
      onContinue: widget.quiz.complete ? lease.guard(widget.onContinue) : null,
      background: const SizedBox.expand(),
    ),
  );
}

Finder _choice(SeedQuiz quiz, int question, String word) => find.byKey(
  ValueKey<String>(
    'seed_quiz_${question}_${quiz.questions[question].choices.indexOf(word)}',
  ),
);

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} quiz reveals four choices per active row',
      (
        WidgetTester tester,
      ) async {
        prepareEntryViewport(tester);
        final SeedQuiz quiz = _quiz();
        await tester.pumpWidget(
          entryHost(
            _Fixture(quiz: quiz, onContinue: () {}),
            light: light,
          ),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('seed_quiz_screen_marker')))
              .width,
          620,
        );
        for (final String word in quiz.questions.first.choices) {
          expect(_choice(quiz, 0, word), findsOneWidget);
        }
        expect(_choice(quiz, 1, quiz.questions[1].answer), findsNothing);
        expect(find.text('0 of 3 done.'), findsOneWidget);
        await tester.tap(_choice(quiz, 0, quiz.questions[0].answer));
        await tester.pump();
        for (final String word in quiz.questions[1].choices) {
          expect(_choice(quiz, 1, word), findsOneWidget);
        }
        expect(_choice(quiz, 2, quiz.questions[2].answer), findsNothing);
        expect(find.text('1 of 3 done.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'wrong answers stay put and three exact answers enable Continue',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final SeedQuiz quiz = _quiz();
      int continuations = 0;
      await tester.pumpWidget(
        entryHost(_Fixture(quiz: quiz, onContinue: () => continuations++)),
      );
      final String wrong = quiz.questions[0].choices.firstWhere(
        (String word) => word != quiz.questions[0].answer,
      );
      await tester.tap(_choice(quiz, 0, wrong));
      await tester.pump();
      expect(find.text('Check your seed before continuing.'), findsOneWidget);
      expect(
        tester
            .widget<PrimaryPill>(find.byKey(const Key('seed_quiz_continue')))
            .onPressed,
        isNull,
      );
      for (int question = 0; question < 3; question++) {
        await tester.tap(
          _choice(quiz, question, quiz.questions[question].answer),
        );
        await tester.pump();
      }
      expect(find.text('3 of 3 done.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('seed_quiz_continue')));
      expect(continuations, 1);
    },
  );

  testWidgets(
    'keyboard traversal selects a visible word through the real chip button',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final SeedQuiz quiz = _quiz();
      await tester.pumpWidget(
        entryHost(_Fixture(quiz: quiz, onContinue: () {})),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(quiz.selected(0), quiz.questions[0].choices.first);
    },
  );

  testWidgets(
    'a replacement quiz revokes saved choice and continuation callbacks',
    (
      WidgetTester tester,
    ) async {
      prepareEntryViewport(tester);
      final SeedQuiz first = _quiz();
      int continuations = 0;
      Widget host(SeedQuiz quiz) =>
          entryHost(_Fixture(quiz: quiz, onContinue: () => continuations++));
      await tester.pumpWidget(host(first));
      final Finder firstButton = find.descendant(
        of: _choice(first, 0, first.questions[0].answer),
        matching: find.byType(OutlinedButton),
      );
      final VoidCallback oldChoice = tester
          .widget<OutlinedButton>(firstButton)
          .onPressed!;
      for (int question = 0; question < 3; question++) {
        await tester.tap(
          _choice(first, question, first.questions[question].answer),
        );
        await tester.pump();
      }
      final VoidCallback oldContinue = tester
          .widget<PrimaryPill>(find.byKey(const Key('seed_quiz_continue')))
          .onPressed!;
      final SeedQuiz second = _quiz();
      await tester.pumpWidget(host(second));
      oldChoice();
      oldContinue();
      expect(second.selected(0), isNull);
      expect(continuations, 0);
    },
  );

  testWidgets(
    'the scaled RTL quiz wraps words and keeps its action reachable',
    (
      WidgetTester tester,
    ) async {
      const Size size = Size(540, 360);
      prepareEntryViewport(tester, size: size);
      final SeedQuiz quiz = _quiz();
      for (int question = 0; question < 3; question++) {
        quiz.select(question, quiz.questions[question].answer);
      }
      int continuations = 0;
      await tester.pumpWidget(
        entryHost(
          _Fixture(quiz: quiz, onContinue: () => continuations++),
          size: size,
          scale: 2.5,
          rtl: true,
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('seed_quiz_continue')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('seed_quiz_continue')));
      expect(continuations, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
