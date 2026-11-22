import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_action_controller.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_project_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_project_view.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/buttons/primary_pill.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart' show ShellSymbol;
import 'package:zenon_syrius_wallet_flutter/widgets/shell/shell_frame.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/shell_pane_navigation.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'support.dart';

Widget host(
  Widget child, {
  bool light = false,
  double scale = 1,
  EdgeInsets padding = const EdgeInsets.all(12),
}) =>
    MaterialApp(
      theme: (light ? AppTheme.lightTheme : AppTheme.darkTheme).copyWith(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: Padding(padding: padding, child: child),
        ),
      ),
    );

void main() {
  for (final bool light in <bool>[false, true]) {
    testWidgets(
      'project phase rows, 320 px aside and Unknown quorum in '
      '${light ? 'light' : 'dark'}',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 780));
        final ActionSource source = ActionSource()
          ..project = actionProject(
            phases: <int>[2, 3],
            name: 'Synthetic project',
          );
        int backs = 0;
        final AcceleratorProjectPresenter presenter =
            AcceleratorProjectPresenter(
              projectId: listHash(1),
              actions: AcceleratorActionController(),
            );
        await presenter.load(source);
        final ValueNotifier<bool> locked = ValueNotifier<bool>(false);
        final Widget detail = AcceleratorProjectView(
          presenter: presenter,
          title: 'Original project',
          onBack: () => backs++,
          onRefresh: () {},
          onUpdatePhase: (_, _) {},
        );
        try {
          await tester.pumpWidget(host(detail, light: light));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Synthetic project'), findsOneWidget);
          expect(
            find.byKey(ValueKey<String>('accelerator_phase_${listHash(2)}')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey<String>('accelerator_phase_${listHash(3)}')),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const Key('accelerator_vote_aside')))
                .width,
            320,
          );
          expect(find.text('Unknown'), findsOneWidget);
          expect(find.text('28 of 33'), findsNothing);
          expect(find.text('Your vote'), findsOneWidget);
          final Finder summary = find.byKey(
            const Key('accelerator_vote_summary'),
          );
          final Rect summaryBounds = tester.getRect(summary);
          final Rect yes = tester.getRect(
            find.descendant(of: summary, matching: find.text('Yes')),
          );
          final Rect no = tester.getRect(
            find.descendant(of: summary, matching: find.text('No')),
          );
          expect(yes.left - summaryBounds.left, 12);
          expect(yes.top - summaryBounds.top, closeTo(12, 0.75));
          expect(no.top - yes.bottom, closeTo(8, 0.75));
          final Finder quorum = find.descendant(
            of: summary,
            matching: find.text('Unknown'),
          );
          expect(tester.widget<Text>(quorum).style!.fontSize, 13);
          expect(summaryBounds.right - tester.getRect(quorum).right, 12);

          final Finder budget = find.byKey(
            const Key('accelerator_project_budget'),
          );
          final Rect label = tester.getRect(find.text('BUDGET'));
          expect(tester.getTopLeft(budget).dx, closeTo(label.left, 0.01));
          expect(tester.getTopLeft(budget).dy, closeTo(label.bottom, 0.01));
          final Finder description = find.byKey(
            const Key('accelerator_project_description'),
          );
          final Text paragraph = tester.widget<Text>(
            find.descendant(of: description, matching: find.byType(Text)),
          );
          final TextPainter zero = TextPainter(
            text: TextSpan(text: '0', style: paragraph.style),
            textDirection: TextDirection.ltr,
          )..layout();
          expect(
            tester.widget<ConstrainedBox>(description).constraints.maxWidth,
            closeTo(62 * zero.width, 0.01),
          );
          zero.dispose();
          for (final Key key in <Key>[
            const Key('project_details_back'),
            const Key('acc_create_phase'),
          ]) {
            final Finder control = find.byKey(key);
            final ButtonStyle style = tester
                .widget<ButtonStyleButton>(control)
                .style!;
            expect(tester.getSize(control).height, 26);
            expect(
              style.textStyle!.resolve(<WidgetState>{})!.fontSize,
              12,
            );
            expect(
              style.padding!
                  .resolve(<WidgetState>{})!
                  .resolve(
                    TextDirection.ltr,
                  ),
              const EdgeInsets.symmetric(horizontal: 10),
            );
          }
          expect(
            find.text('Phase voting has no fixed deadline.'),
            findsNothing,
          );
          await tester.tap(find.byKey(const Key('project_details_back')));
          expect(backs, 1);

          await tester.binding.setSurfaceSize(const Size(1200, 600));
          await tester.pumpWidget(
            host(
              Builder(
                builder: (BuildContext context) => ShellFrame(
                  locked: locked,
                  rail: SizedBox(
                    width: AppTokens.of(context).railExpandedWidth,
                  ),
                  page: detail,
                  status: const SizedBox(height: 36),
                ),
              ),
              light: light,
              padding: EdgeInsets.zero,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          final Rect panel = tester.getRect(
            find.byKey(const Key('accelerator_project_detail')),
          );
          final Rect aside = tester.getRect(
            find.byKey(const Key('accelerator_vote_aside')),
          );
          expect(panel.width, 980);
          expect(aside.width, 320);
          expect(aside.right, closeTo(panel.right, 0.01));
          expect(
            find.byKey(const Key('accelerator_detail_vote_yes')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('accelerator_detail_vote_no')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find
                .byKey(const Key('accelerator_detail_vote_abstain'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip('Update phase').hitTestable(),
            findsOneWidget,
          );
          const String fullTitle = '2 · Phase 3';
          final Finder phaseTitle = find.text(fullTitle);
          expect(phaseTitle.hitTestable(), findsOneWidget);
          final TestGesture mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(1, 1));
          addTearDown(mouse.removePointer);
          await tester.pump();
          await mouse.moveTo(tester.getCenter(phaseTitle));
          await tester.pumpAndSettle();
          expect(find.text(fullTitle, findRichText: true), findsNWidgets(2));
          expect(source.publications, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          locked.dispose();
          presenter.dispose();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets(
    'a root dialog blocks a saved vote on the visible panel route',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 780));
      final ActionSource source = ActionSource()
        ..project = actionProject(phases: <int>[2]);
      final AcceleratorProjectPresenter presenter =
          AcceleratorProjectPresenter(
            projectId: listHash(1),
            actions: AcceleratorActionController(),
          );
      await presenter.load(source);
      try {
        await tester.pumpWidget(
          host(
            ShellPaneNavigation(
              child: AcceleratorProjectView(
                presenter: presenter,
                title: 'Original',
                onBack: () {},
                onRefresh: () {},
              ),
            ),
          ),
        );
        final Finder yes = find.descendant(
          of: find.byKey(const Key('accelerator_detail_vote_yes')),
          matching: find.byType(PrimaryPill),
        );
        final BuildContext context = tester.element(yes);
        final VoidCallback saved = tester.widget<PrimaryPill>(yes).onPressed!;
        final ModalRoute<dynamic>? panel = ModalRoute.of(context);
        final NavigatorState shell = Navigator.of(
          context, rootNavigator: true,
        );
        final Future<void> dialog = showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('Synthetic cover')),
        );
        expect(panel?.isCurrent, isTrue);
        saved();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Synthetic cover'), findsOneWidget);
        expect(source.builders, isEmpty);
        expect(source.publications, 0);
        shell.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await dialog;
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        presenter.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'an old Yes callback cannot vote after the selected phase changes',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 780));
      final ActionSource source = ActionSource()
        ..project = actionProject(phases: <int>[2, 3]);
      final AcceleratorProjectPresenter presenter = AcceleratorProjectPresenter(
        projectId: listHash(1),
        actions: AcceleratorActionController(),
      );
      await presenter.load(source);
      try {
        await tester.pumpWidget(
          host(
            AcceleratorProjectView(
              presenter: presenter,
              title: 'Original',
              onBack: () {},
              onRefresh: () {},
            ),
          ),
        );
        final PrimaryPill yes = tester.widget<PrimaryPill>(
          find.descendant(
            of: find.byKey(const Key('accelerator_detail_vote_yes')),
            matching: find.byType(PrimaryPill),
          ),
        );
        final VoidCallback original = yes.onPressed!;
        await tester.tap(
          find.byKey(ValueKey<String>('accelerator_phase_${listHash(2)}')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        original();
        await tester.pump(const Duration(milliseconds: 1));
        expect(presenter.snapshot.selectedId, listHash(2));
        expect(source.publications, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        presenter.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'an existing No vote remains changeable through the injected source only',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 780));
      final ActionSource source = ActionSource()
        ..project = actionProject(phases: <int>[2])
        ..voteReader = (String name, List<String> ids) async => <PillarVote?>[
          null,
          listVote(2, name: name, vote: AcceleratorProjectVote.no.index),
        ];
      final AcceleratorProjectPresenter presenter = AcceleratorProjectPresenter(
        projectId: listHash(1),
        actions: AcceleratorActionController(),
      );
      await presenter.load(source);
      try {
        await tester.pumpWidget(
          host(
            AcceleratorProjectView(
              presenter: presenter,
              title: 'Original',
              onBack: () {},
              onRefresh: () {},
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('accelerator_detail_vote_yes')));
        for (int frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(source.publications, 1);
        expect(source.builders.single.phaseId, listHash(2));
        expect(source.builders.single.vote, AcceleratorProjectVote.yes);
        expect(find.text('Submitted'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        presenter.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets(
    'scaled detail scrolls columns and keeps exit after revocation',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(760, 780));
      final ActionSource source = ActionSource()
        ..project = actionProject(phases: <int>[2]);
      final AcceleratorProjectPresenter presenter = AcceleratorProjectPresenter(
        projectId: listHash(1),
        actions: AcceleratorActionController(),
      );
      await presenter.load(source);
      int backs = 0;
      try {
        await tester.pumpWidget(
          host(
            AcceleratorProjectView(
              presenter: presenter,
              title: 'Original',
              onBack: () => backs++,
              onRefresh: () {},
            ),
            scale: 1.5,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const Key('project_details_back')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Article'), findsOneWidget);
        expect(find.text('Explorer'), findsOneWidget);
        final Finder back = find.byKey(const Key('project_details_back'));
        expect(
          tester.getSize(
            find.descendant(of: back, matching: find.byType(ShellSymbol)),
          ),
          const Size.square(14),
        );
        for (final String label in <String>['Article', 'Explorer']) {
          final Finder link = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((Widget w) => w is TextButton),
          );
          expect(
            tester.getSize(
              find.descendant(of: link, matching: find.byType(ShellSymbol)),
            ),
            const Size.square(12),
          );
        }
        expect(find.text('Your vote'), findsOneWidget);
        expect(tester.takeException(), isNull);
        presenter.invalidate();
        await tester.pump();
        await tester.tap(find.byKey(const Key('project_details_back')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(backs, 1);
        expect(source.publications, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        presenter.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
