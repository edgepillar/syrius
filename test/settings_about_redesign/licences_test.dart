import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/licences.dart';

import 'support.dart';

class _ObservedRawNotice extends LicenseEntryWithLineBreaks {
  _ObservedRawNotice(
    super.packages,
    super.text,
    this.onRead, {
    this.onTextRead,
  });

  final VoidCallback onRead;
  final VoidCallback? onTextRead;

  @override
  String get text {
    onTextRead?.call();
    return super.text;
  }

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
        int laterTextReads = 0;
        int laterParagraphReads = 0;
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
                  _ObservedRawNotice(
                    const <String>['mixed'],
                    'A later genuine notice is still readable.',
                    () => laterParagraphReads++,
                    onTextRead: () => laterTextReads++,
                  ),
                  LicenseEntryWithLineBreaks(
                    const <String>['mixed', 'zzz-shared'],
                    verifiedNotice,
                  ),
                  for (int index = 0; index < 20; index++)
                    LicenseEntryWithLineBreaks(
                      <String>['zz-filler-$index'],
                      'A finite list fixture.',
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
          isFalse,
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
        expect(rowBounds.height, closeTo(39.3, .01));
        final double ratio = tester.view.devicePixelRatio;
        for (final String name in <String>['alpha', 'mixed']) {
          final Finder rule = find
              .descendant(
                of: find.byKey(ValueKey<String>('about_licence_$name')),
                matching: find.byType(CustomPaint),
              )
              .first;
          expect(
            tester.widget<CustomPaint>(rule).child,
            isA<RepaintBoundary>(),
          );
          final double top = tester.getTopLeft(rule).dy;
          if (name == 'mixed') {
            final double physicalTop = top * ratio;
            expect(
              (physicalTop - physicalTop.round()).abs(),
              greaterThan(.01),
            );
          }
          expect(
            rule,
            paints..something((Symbol method, List<dynamic> arguments) {
              if (method != #drawRect) return false;
              final Object? rect = arguments[0];
              final Object? paint = arguments[1];
              return rect is Rect &&
                  ((top + rect.top) * ratio - (top * ratio).round()).abs() <
                      0.0001 &&
                  rect.height == 1 &&
                  paint is Paint &&
                  !paint.isAntiAlias;
            }),
          );
        }
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
        expect(laterTextReads, 0);
        expect(laterParagraphReads, 0);
        await _open(tester, 'alpha');
        expect(tester.widget<RotationTransition>(chevronFinder).turns.value, 0);
        expect(reads, 1);
        expect(
          find.text('Complete raw notice text continues.'),
          findsOneWidget,
        );
        expect(find.text(firstText), findsOneWidget);
        expect(find.text(secondText), findsOneWidget);
        final Text title = tester.widget<Text>(
          find.text('Synthetic notice title'),
        );
        expect(title.textAlign, TextAlign.center);
        expect(title.maxLines, isNull);
        final Text paragraph = tester.widget<Text>(find.text(firstText));
        expect(paragraph.maxLines, isNull);
        final SelectableRegionState selection = tester.state(
          find.descendant(
            of: find.byKey(const Key('about_licence_alpha')),
            matching: find.byType(SelectableRegion),
          ),
        );
        String? copied;
        final TestDefaultBinaryMessenger messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              ..setMockMethodCallHandler(SystemChannels.platform, (
                MethodCall call,
              ) async {
                if (call.method == 'Clipboard.setData') {
                  final Map<Object?, Object?> data =
                      call.arguments as Map<Object?, Object?>;
                  copied = data['text']! as String;
                }
                return null;
              });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        selection.selectAll(SelectionChangedCause.keyboard);
        final ContextMenuButtonItem copy = selection.contextMenuButtonItems
            .singleWhere(
              (ContextMenuButtonItem item) =>
                  item.type == ContextMenuButtonType.copy,
            );
        copy.onPressed!();
        await tester.pump();
        expect(copied, allOf(contains(firstText), contains(secondText)));
        await _open(tester, 'alpha');
        await _open(tester, 'zeta');
        expect(reads, 1);
        expect(
          find.text('Complete raw notice text continues.'),
          findsOneWidget,
        );
        final Finder sharedRow = find.byKey(
          const ValueKey<String>('about_licence_zzz-shared'),
        );
        expect(sharedRow, findsNothing);
        await _open(tester, 'mixed');
        expect(laterParagraphReads, 1);
        expect(
          find.text('A later genuine notice is still readable.'),
          findsOneWidget,
        );
        await _open(tester, 'mixed');
        await tester.scrollUntilVisible(
          sharedRow,
          250,
          scrollable: find.descendant(
            of: find.byKey(const Key('about_licences_list')),
            matching: find.byType(Scrollable),
          ),
          maxScrolls: 12,
        );
        expect(find.descendant(of: sharedRow, matching: known), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  aboutTestWidgets('bundled yapf notices share one licence identifier', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    // Use the SDK source from pub's package configuration. The test embedder
    // can load an already compiled kernel without resolving package URIs.
    final File packageConfig = File('.dart_tool/package_config.json');
    final Map<String, Object?> config =
        jsonDecode(packageConfig.readAsStringSync()) as Map<String, Object?>;
    final List<Object?> packages = config['packages']! as List<Object?>;
    final Map<String, Object?> skyEngine = packages
        .whereType<Map<String, Object?>>()
        .singleWhere(
          (Map<String, Object?> package) => package['name'] == 'sky_engine',
        );
    final String root = skyEngine['rootUri']! as String;
    final Uri engineRoot = packageConfig.absolute.uri.resolve(
      root.endsWith('/') ? root : '$root/',
    );
    final String bundle = File.fromUri(
      engineRoot.resolve('LICENSE'),
    ).readAsStringSync();
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
    final Finder list = find.byKey(const Key('about_licences_list'));
    final Finder row = find.byKey(const Key('about_licence_yapf'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
      maxScrolls: 10,
    );
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
          matching: find.text(firstParagraph),
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
      await tester.pumpAndSettle();
      final Licences original = tester.widget<Licences>(find.byType(Licences));
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(2560, 1560);
      await tester.pumpWidget(
        aboutHost(
          Licences(
            loadLicences: original.loadLicences,
            trailingBuilder: original.trailingBuilder,
            preserveEndOnReveal: true,
          ),
          width: 700,
          height: 240,
        ),
      );
      await tester.pumpAndSettle();
      expect(hook.hitTestable(), findsOneWidget);
      final Finder rule = find
          .descendant(of: finalRow, matching: find.byType(CustomPaint))
          .first;
      final double top = tester.getTopLeft(rule).dy;
      final double ratio = tester.view.devicePixelRatio;
      expect(tester.getSize(rule).height, closeTo(39.5, .01));
      expect(
        rule,
        paints..something((Symbol method, List<dynamic> arguments) {
          if (method != #drawRect) return false;
          final Object? rect = arguments[0];
          return rect is Rect &&
              ((top + rect.top) * ratio - ((top - .5) * ratio).round()).abs() <
                  0.0001 &&
              rect.height == 1;
        }),
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
