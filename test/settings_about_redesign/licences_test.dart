import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/licences.dart';

import 'support.dart';

class _ObservedRawNotice extends LicenseEntryWithLineBreaks {
  _ObservedRawNotice(super.packages, super.text, this.onRead);

  final VoidCallback onRead;

  @override
  Iterable<LicenseParagraph> get paragraphs {
    onRead();
    return super.paragraphs;
  }
}

Future<void> _open(WidgetTester tester, String package) async {
  final Finder toggle = find.byKey(
    ValueKey<String>('about_licence_${package}_toggle'),
  );
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 240));
}

void main() {
  for (final (bool, bool, double) variant in <(bool, bool, double)>[
    (false, false, 1),
    (true, true, 1.5),
  ]) {
    aboutTestWidgets(
      'genuine packages and complete paragraphs in variant $variant',
      (WidgetTester tester) async {
        prepareAboutViewport(tester);
        const String firstText =
            'A complete synthetic licence paragraph. '
            'Every word stays available without truncating the legal text.';
        const String secondText =
            'A second independent notice for the same package.';
        final String verifiedNotice = File('LICENSE').readAsStringSync();
        final String changedNotice = verifiedNotice.replaceFirst(
          'Permission',
          'permission',
        );
        expect(changedNotice, isNot(verifiedNotice));
        expect(changedNotice.length, verifiedNotice.length);
        int reads = 0;
        int verifiedReads = 0;
        await tester.pumpWidget(
          aboutHost(
            Licences(
              loadLicences: () => Stream<LicenseEntry>.fromIterable(
                <LicenseEntry>[
                  FixtureLicence(
                    <String>['zeta', 'alpha'],
                    const <LicenseParagraph>[
                      LicenseParagraph(
                        'Synthetic notice title',
                        LicenseParagraph.centeredIndent,
                      ),
                      LicenseParagraph(firstText, 1),
                    ],
                  ),
                  FixtureLicence(
                    <String>['alpha', 'alpha'],
                    const <LicenseParagraph>[LicenseParagraph(secondText, 0)],
                  ),
                  FixtureLicence(
                    <String>['Fixture Font'],
                    const <LicenseParagraph>[
                      LicenseParagraph(
                        'Synthetic font terms. Preserve these words.',
                        0,
                      ),
                    ],
                  ),
                  _ObservedRawNotice(
                    <String>['alpha', 'zeta'],
                    'Complete raw notice\ntext continues.',
                    () => reads++,
                  ),
                  _ObservedRawNotice(
                    <String>['verified-a', 'verified-b', 'mixed'],
                    '\n  ${verifiedNotice.replaceAll('\n', '\r\n')}  ',
                    () => verifiedReads++,
                  ),
                  LicenseEntryWithLineBreaks(
                    const <String>['mixed', 'unverified'],
                    changedNotice,
                  ),
                ],
              ),
            ),
            light: variant.$1,
            rtl: variant.$2,
            scale: variant.$3,
            width: 700,
            height: 500,
          ),
        );
        await tester.pump();
        final Finder name = find.text('alpha');
        expect(name, findsOneWidget);
        expect(tester.widget<Text>(name).style?.fontWeight, FontWeight.w400);
        final Finder row = find.byKey(const Key('about_licence_alpha_toggle'));
        final Finder chevronFinder = find.descendant(
          of: row,
          matching: find.byType(RotationTransition),
        );
        final ListView list = tester.widget<ListView>(
          find.byKey(const Key('about_licences_list')),
        );
        expect(
          (list.childrenDelegate as SliverChildBuilderDelegate)
              .addRepaintBoundaries,
          isTrue,
        );
        expect(
          find.descendant(of: row, matching: find.byType(RepaintBoundary)),
          findsNothing,
        );
        expect(
          tester.widget<RotationTransition>(chevronFinder).turns.value,
          variant.$2 ? .25 : -.25,
        );
        final Rect rowBounds = tester.getRect(row);
        expect(rowBounds.height, closeTo(39.25, .01));
        final Rect chevron = tester.getRect(chevronFinder);
        expect(
          variant.$2
              ? chevron.left - rowBounds.left
              : rowBounds.right - chevron.right,
          closeTo(16, .01),
        );
        expect(
          Theme.of(tester.element(name)),
          same(Theme.of(tester.element(find.byType(Licences)))),
        );
        expect(find.text('zeta'), findsOneWidget);
        expect(find.text('Fixture Font'), findsOneWidget);
        final Finder known = find.text('MIT');
        expect(known, findsNWidgets(2));
        expect(
          tester.getRect(known.first).left,
          tester.getRect(known.last).left,
        );
        for (final String name in <String>['mixed', 'unverified']) {
          expect(find.text(name), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(ValueKey<String>('about_licence_$name')),
              matching: known,
            ),
            findsNothing,
          );
        }
        expect(verifiedReads, 0);
        expect(reads, 0);
        await _open(tester, 'alpha');
        expect(tester.widget<RotationTransition>(chevronFinder).turns.value, 0);
        expect(reads, 1);
        expect(
          find.text('Complete raw notice text continues.'),
          findsOneWidget,
        );
        expect(find.text(firstText), findsOneWidget);
        expect(find.text(secondText), findsOneWidget);
        final SelectableText title = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is SelectableText &&
                widget.data == 'Synthetic notice title',
          ),
        );
        expect(title.textAlign, TextAlign.center);
        expect(title.maxLines, isNull);
        final SelectableText paragraph = tester.widget<SelectableText>(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is SelectableText && widget.data == firstText,
          ),
        );
        expect(paragraph.maxLines, isNull);
        await _open(tester, 'alpha');
        await _open(tester, 'zeta');
        expect(reads, 1);
        expect(
          find.text('Complete raw notice text continues.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  aboutTestWidgets('bundled yapf notices share one licence identifier', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    // Read the SDK notice source that Flutter uses to assemble the registry.
    final Uri? skyEngine = Isolate.resolvePackageUriSync(
      Uri.parse('package:sky_engine/_empty.dart'),
    );
    final String bundle = File.fromUri(skyEngine!.resolve('../LICENSE'))
        .readAsStringSync();
    final List<LicenseEntry> notices = <LicenseEntry>[];
    for (final String section in bundle.split('\n${'-' * 80}\n')) {
      final int split = section.indexOf('\n\n');
      if (split < 0) continue;
      final List<String> packages = section.substring(0, split).split('\n');
      if (packages.contains('yapf')) {
        notices.add(LicenseEntryWithLineBreaks(packages,
            section.substring(split + 2)));
      }
    }
    expect(notices, hasLength(2));
    await tester.pumpWidget(
      aboutHost(
        Licences(
          loadLicences: () => Stream<LicenseEntry>.fromIterable(notices),
        ),
      ),
    );
    await tester.pump();
    // The full engine notice also applies to other packages in the list.
    final Finder row = find.byKey(const Key('about_licence_yapf'));
    expect(
      find.descendant(of: row, matching: find.text('Apache-2.0')),
      findsOneWidget,
    );
    await _open(tester, 'yapf');
    for (final LicenseEntry entry in notices) {
      final String firstParagraph = entry.paragraphs.first.text;
      expect(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is SelectableText &&
                widget.data == firstParagraph,
          ),
        ),
        findsOneWidget,
      );
    }
  });

  aboutTestWidgets(
    'end hook waits for complete enumeration and follows final row',
    (
      WidgetTester tester,
    ) async {
      prepareAboutViewport(tester);
      final StreamController<LicenseEntry> entries =
          StreamController<LicenseEntry>();
      int hookBuilds = 0;
      await tester.pumpWidget(
        aboutHost(
          Licences(
            loadLicences: () => entries.stream,
            trailingBuilder: (_) {
              hookBuilds++;
              return const SizedBox(
                height: 44,
                child: Text('Fixture final hook', key: Key('fixture_hook')),
              );
            },
          ),
          width: 700,
          height: 240,
        ),
      );
      for (int index = 0; index < 30; index++) {
        entries.add(
          FixtureLicence(
            <String>['package-${index.toString().padLeft(2, '0')}'],
            const <LicenseParagraph>[LicenseParagraph('Fixture terms', 0)],
          ),
        );
      }
      await tester.pump();
      expect(find.byKey(const Key('about_licences_loading')), findsOneWidget);
      expect(hookBuilds, 0);
      await observeAboutFuture(
        tester,
        entries.close(),
        operation: 'complete registry close',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('about_licence_package-00')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('about_licence_package-10')),
        findsNothing,
      );
      expect(find.byKey(const Key('fixture_hook')).hitTestable(), findsNothing);
      final Finder list = find.byKey(const Key('about_licences_list'));
      final Finder scrollbarFinder = find.ancestor(
        of: list,
        matching: find.byType(RawScrollbar),
      );
      final RawScrollbar scrollbar = tester.widget<RawScrollbar>(
        scrollbarFinder,
      );
      expect(scrollbar.thickness, 4);
      expect(scrollbar.trackVisibility, isTrue);
      final CustomPaint scrollbarPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: scrollbarFinder,
          matching: find.byWidgetPredicate(
            (Widget child) =>
                child is CustomPaint &&
                child.foregroundPainter is ScrollbarPainter,
          ),
        ),
      );
      final ScrollbarPainter painter =
          scrollbarPaint.foregroundPainter! as ScrollbarPainter;
      expect(painter.fadeoutOpacityAnimation.value, 1);
      expect(
        scrollbar.padding,
        const EdgeInsetsDirectional.only(top: 6, bottom: 6, end: 4),
      );
      expect(scrollbar.mainAxisMargin, 0);
      expect(scrollbar.crossAxisMargin, 0);
      expect(scrollbar.minThumbLength, 46);
      final Finder scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('fixture_hook')),
        200,
        scrollable: scrollable,
        maxScrolls: 20,
      );
      expect(hookBuilds, greaterThan(0));
      final Finder hook = find.byKey(const Key('fixture_hook'));
      final Finder finalRow = find.byKey(
        const Key('about_licence_package-29'),
      );
      expect(hook.hitTestable(), findsOneWidget);
      final double hookTop = tester.getTopLeft(hook).dy;
      final double rowBottom = tester.getBottomLeft(finalRow).dy;
      expect(
        hookTop - rowBottom,
        greaterThanOrEqualTo(-precisionErrorTolerance),
      );
      expect(tester.takeException(), isNull);
    },
  );

  aboutTestWidgets(
    'failed enumeration exposes no partial end hook and can retry',
    (
      WidgetTester tester,
    ) async {
      prepareAboutViewport(tester);
      int attempts = 0;
      int hookBuilds = 0;
      await tester.pumpWidget(
        aboutHost(
          Licences(
            loadLicences: () {
              attempts++;
              if (attempts == 1) {
                return Stream<LicenseEntry>.error(
                  StateError('synthetic private diagnostic'),
                );
              }
              if (attempts == 2) {
                return Stream<LicenseEntry>.value(
                  _ObservedRawNotice(
                    <String>['unreadable-notice'],
                    'Synthetic raw notice',
                    () => throw StateError('synthetic private diagnostic'),
                  ),
                );
              }
              return Stream<LicenseEntry>.value(
                FixtureLicence(
                  <String>['retried-package'],
                  const <LicenseParagraph>[
                    LicenseParagraph('Complete fixture terms', 0),
                  ],
                ),
              );
            },
            trailingBuilder: (_) {
              hookBuilds++;
              return const Text('Fixture final hook');
            },
          ),
          width: 700,
          height: 240,
        ),
      );
      await tester.pump();
      expect(find.text('Could not load licences. Try again.'), findsOneWidget);
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(hookBuilds, 0);
      await tester.tap(find.byKey(const Key('about_licences_retry')));
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('unreadable-notice'), findsOneWidget);
      await _open(tester, 'unreadable-notice');
      expect(find.text('Could not load licences. Try again.'), findsOneWidget);
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(find.text('Fixture final hook'), findsNothing);
      await tester.tap(find.byKey(const Key('about_licences_retry')));
      await tester.pump();
      expect(attempts, 3);
      expect(find.text('retried-package'), findsOneWidget);
      expect(find.text('Fixture final hook'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  aboutTestWidgets('source replacement cancels the original subscription', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    int cancelled = 0;
    final StreamController<LicenseEntry> original =
        StreamController<LicenseEntry>(
          onCancel: () => cancelled++,
        );
    Stream<LicenseEntry> originalSource() => original.stream;
    Stream<LicenseEntry> replacement() => Stream<LicenseEntry>.value(
      FixtureLicence(
        <String>['replacement-package'],
        const <LicenseParagraph>[LicenseParagraph('Replacement terms', 0)],
      ),
    );
    await tester.pumpWidget(aboutHost(Licences(loadLicences: originalSource)));
    original.add(
      FixtureLicence(
        <String>['old-partial-package'],
        const <LicenseParagraph>[LicenseParagraph('Old partial terms', 0)],
      ),
    );
    await tester.pump();
    await tester.pumpWidget(aboutHost(Licences(loadLicences: replacement)));
    await tester.pump();
    expect(cancelled, 1);
    expect(find.text('replacement-package'), findsOneWidget);
    expect(find.text('old-partial-package'), findsNothing);
    await observeAboutFuture(
      tester,
      original.close(),
      operation: 'replaced registry close',
    );
    expect(tester.takeException(), isNull);
  });

  aboutTestWidgets('unmount cancels an unfinished registry read', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    int cancelled = 0;
    final StreamController<LicenseEntry> entries =
        StreamController<LicenseEntry>(
          onCancel: () => cancelled++,
        );
    await tester.pumpWidget(
      aboutHost(Licences(loadLicences: () => entries.stream)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancelled, 1);
    await observeAboutFuture(
      tester,
      entries.close(),
      operation: 'unmounted registry close',
    );
    expect(tester.takeException(), isNull);
  });

  aboutTestWidgets('empty registry is honest and has no hidden end content', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    int hookBuilds = 0;
    await tester.pumpWidget(
      aboutHost(
        Licences(
          loadLicences: () => const Stream<LicenseEntry>.empty(),
          trailingBuilder: (_) {
            hookBuilds++;
            return const Text('Fixture final hook');
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('None yet'), findsOneWidget);
    expect(hookBuilds, 0);
    expect(tester.takeException(), isNull);
  });
}
