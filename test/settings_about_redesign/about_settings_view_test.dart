import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart'
    show Layer, OffsetLayer, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/disclosure.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_information.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/licences.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_parts.dart';

import 'support.dart';

Future<AboutInformation> _information() async => AboutInformation(
  version: '9.8.7-rc.2',
  buildNumber: '00042',
  details: <AboutField, String>{AboutField.commit: 'abcdef1234567890'},
);

Stream<LicenseEntry> _emptyLicences() => const Stream<LicenseEntry>.empty();

class _CountPaint extends CustomPainter {
  _CountPaint(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_CountPaint oldDelegate) => onPaint != oldDelegate.onPaint;
}

Text _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key)));

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  // The sliver's hit-test transform updates during the next layout.
  await tester.pump();
  await tester.tap(target);
}

Future<void> _toggle(WidgetTester tester, String key) async {
  await _tapVisible(tester, find.byKey(ValueKey<String>(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 240));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (String, List<String>) family in
        const <(String, List<String>)>[
      (kSansFontFamily, <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
      (kMonoFontFamily, <String>['Regular', 'Medium', 'SemiBold', 'Bold']),
      (kArabicFontFamily, <String>['Regular', 'Medium', 'Bold']),
      (kDevanagariFontFamily, <String>['Regular', 'Medium', 'Bold']),
    ]) {
      final FontLoader fonts = FontLoader(family.$1);
      for (final String weight in family.$2) {
        fonts.addFont(
          rootBundle.load('assets/fonts/${family.$1}-$weight.ttf'),
        );
      }
      await fonts.load();
    }
  });

  aboutTestWidgets('Settings skips offscreen panel paint and keeps its owner', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    const Key panel = Key('offscreen_settings_panel');
    int paints = 0;
    await tester.pumpWidget(
      aboutHost(
        SettingsSection(
          children: <Widget>[
            const SizedBox(height: 500),
            SizedBox(
              height: 100,
              child: CustomPaint(
                key: panel,
                painter: _CountPaint(() => paints++),
              ),
            ),
          ],
        ),
        height: 260,
      ),
    );
    final Finder offscreen = find.byKey(panel, skipOffstage: false);
    final Element original = tester.element(offscreen);
    final Finder viewport = find.byType(CustomScrollView);
    expect(tester.widget<CustomScrollView>(viewport).shrinkWrap, isFalse);
    expect(tester.getSize(viewport).height, 260);
    expect(paints, 0);
    await tester.ensureVisible(offscreen);
    await tester.pumpAndSettle();
    expect(paints, greaterThan(0));
    expect(tester.element(offscreen), same(original));

    await tester.pumpWidget(
      aboutHost(
        const Align(
          child: SettingsSection(children: <Widget>[SizedBox(height: 100)]),
        ),
        height: 260,
      ),
    );
    expect(tester.widget<CustomScrollView>(viewport).shrinkWrap, isTrue);
    expect(tester.getSize(viewport).height, 100);
  });

  for (final (bool, bool, double) variant in <(bool, bool, double)>[
    (false, false, 1),
    (true, true, 1.5),
  ]) {
    aboutTestWidgets(
      'About is full width with closed groups in variant $variant',
      (
        WidgetTester tester,
      ) async {
        prepareAboutViewport(tester);
        int registryReads = 0;
        final SemanticsHandle semantics = tester.ensureSemantics();
        try {
          final AboutCard card = AboutCard(
            loadInformation: _information,
            loadLicences: () {
              registryReads++;
              return _emptyLicences();
            },
          );
          await tester.pumpWidget(
            aboutHost(card, light: variant.$1, rtl: variant.$2),
          );
          await tester.pump();
          expect(
            tester.getSize(find.byKey(const Key('about_strip'))).height,
            70,
          );
          final Rect version = tester.getRect(
            find.byKey(const Key('about_version')),
          );
          final Rect embedded = tester.getRect(find.text('EMBEDDED NODE'));
          expect(
            variant.$2
                ? version.left - embedded.right
                : embedded.left - version.right,
            closeTo(28, 0.01),
          );
          await tester.pumpWidget(
            aboutHost(
              card,
              light: variant.$1,
              rtl: variant.$2,
              scale: variant.$3,
            ),
          );
          await tester.pump();
          expect(
            tester.getSize(find.byKey(const Key('about_strip'))).width,
            1000,
          );
          expect(
            tester.getSize(find.byKey(const Key('about_strip'))).height,
            variant.$3 > 1 ? greaterThan(71) : 70,
          );
          expect(_text(tester, 'about_version').data, '9.8.7-rc.2');
          expect(_text(tester, 'about_embedded_version').data, 'Unknown');
          expect(_text(tester, 'about_build').data, '00042 · abcdef12');
          final Finder badge = find.byKey(const Key('about_update_badge'));
          final AppTokens tokens = AppTokens.of(tester.element(badge));
          final ShapeDecoration badgeDecoration = tester
              .widget<Container>(badge)
              .decoration! as ShapeDecoration;
          expect(tester.getSize(badge).height, greaterThanOrEqualTo(26));
          expect(badgeDecoration.shape, const StadiumBorder());
          expect(badgeDecoration.color, tokens.pink.withValues(alpha: 0.14));
          expect(_text(tester, 'about_update_label').data, 'Wallet updates');
          expect(
            _text(tester, 'about_update_label').style!.color,
            tokens.pinkInk,
          );
          final ButtonStyle actionStyle = tester
              .widget<OutlinedButton>(
                find.byKey(const Key('about_what_changed')),
              )
              .style!;
          expect(
            actionStyle.minimumSize!.resolve(<WidgetState>{})!.height,
            30,
          );
          expect(
            actionStyle.padding!.resolve(<WidgetState>{}),
            const EdgeInsets.symmetric(horizontal: 13),
          );
          expect(
            actionStyle.textStyle!.resolve(<WidgetState>{})!.fontSize,
            13,
          );
          expect(
            actionStyle.textStyle!.resolve(<WidgetState>{})!.fontWeight,
            FontWeight.w500,
          );
          expect(find.text('Confirm'), findsNothing);
          expect(find.text('0.3.0 is out'), findsNothing);
          expect(find.text('18'), findsOneWidget);
          expect(registryReads, 0);
          expect(find.byType(Licences), findsNothing);
          final Iterable<Disclosure> groups = tester.widgetList<Disclosure>(
            find.byType(Disclosure),
          );
          expect(groups.length, 3);
          for (final Disclosure group in groups) {
            final Finder header = find.byKey(
              ValueKey<String>('${group.keyPrefix}_toggle'),
            );
            final Finder chevron = find.descendant(
              of: header,
              matching: find.byWidgetPredicate(
                (Widget widget) =>
                    widget is RepaintBoundary &&
                    widget.child is RotationTransition,
              ),
            );
            final Rect headerRect = tester.getRect(header);
            final Rect chevronRect = tester.getRect(chevron);
            final double inset = variant.$2
                ? chevronRect.left - headerRect.left
                : headerRect.right - chevronRect.right;
            expect(inset, closeTo(16, 0.01));
          }
          expect(
            groups.every((Disclosure group) => !group.initiallyOpen),
            isTrue,
          );
          expect(
            groups.every((Disclosure group) => group.storeKey == null),
            isTrue,
          );
          expect(
            find.byKey(const Key('about_link_0')).hitTestable(),
            findsNothing,
          );
          expect(find.semantics.byLabel('Open folder'), findsNothing);
          expect(find.byType(SeamGate), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final Locale locale in const <Locale>[
            Locale('en'), Locale('ar'),
          ]) {
            await tester.pumpWidget(aboutHost(
              card, light: variant.$1,
              rtl: locale.languageCode == 'ar' || variant.$2,
              scale: variant.$3, locale: locale,
            ));
            await tester.pump();
            final BuildContext view = tester.element(find.byType(AboutCard));
            final AppLocalizations labels = AppLocalizations.of(view)!;
            expect(Localizations.localeOf(view), locale);
            await _toggle(tester, 'about_computer_toggle');
            final String label = locale.languageCode == 'en'
                ? labels.aboutPaths.toUpperCase() : labels.aboutPaths;
            final Text paths = tester.widget<Text>(find.text(label));
            expect(paths.style?.fontSize, 11);
            expect(paths.style?.letterSpacing,
              locale.languageCode == 'en' ? 0.66 : 0);
            expect(paths.style?.color, AppTokens.of(view).faint);
            expect(registryReads, 0);
            expect(tester.takeException(), isNull);
            await _toggle(tester, 'about_computer_toggle');
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  aboutTestWidgets('all eighteen original URLs stay wired to their own rows', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    final List<String> opened = <String>[];
    const String whitepaper =
        'https://github.com/zenon-network/zenon.network/releases/download/'
        'whitepaper/whitepaper.pdf';
    const List<String> expected = <String>[
      'https://zenon.network',
      'https://forum.zenon.org',
      'https://zenon.tools',
      'https://zenon.org',
      'https://zenonhub.io',
      'https://explorer.zenon.network',
      'https://zenonhub.io/explorer',
      'https://twitter.com/Zenon_Network',
      'https://discord.gg/zenonnetwork',
      'https://t.me/zenonnetwork',
      'https://medium.com/@zenon.network',
      'https://github.com/zenon-network',
      'https://bitcointalk.org/index.php?topic=5279643.msg55303681#msg55303681',
      'https://reddit.com/r/Zenon_Network',
      'https://youtube.com/channel/UCDb8ZtqBt6l5l4HugCnJwhQ',
      'https://wiki.zenon.network',
      'https://docs.zenon.org',
      whitepaper,
    ];
    await tester.pumpWidget(
      aboutHost(
        AboutCard(
          loadInformation: _information,
          loadLicences: _emptyLicences,
          openLink: opened.add,
        ),
      ),
    );
    await _toggle(tester, 'about_links_toggle');
    for (int index = 0; index < expected.length; index++) {
      final Finder row = find.byKey(ValueKey<String>('about_link_$index'));
      await _tapVisible(tester, row);
      await tester.pump();
    }
    expect(opened, expected);
    await _toggle(tester, 'about_links_toggle');
    expect(find.byKey(const Key('about_link_0')).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  aboutTestWidgets('replaced metadata cannot overwrite its successor', (
    WidgetTester tester,
  ) async {
    prepareAboutViewport(tester);
    final Completer<AboutInformation> original = Completer<AboutInformation>();
    final Completer<AboutInformation> replacement =
        Completer<AboutInformation>();
    Future<AboutInformation> oldSource() => original.future;
    Future<AboutInformation> newSource() => replacement.future;
    await tester.pumpWidget(
      aboutHost(
        AboutCard(
          loadInformation: oldSource,
          loadLicences: _emptyLicences,
        ),
      ),
    );
    await tester.pumpWidget(
      aboutHost(
        AboutCard(
          loadInformation: newSource,
          loadLicences: _emptyLicences,
        ),
      ),
    );
    replacement.complete(AboutInformation(version: 'replacement'));
    await tester.pump();
    expect(_text(tester, 'about_version').data, 'replacement');
    original.complete(AboutInformation(version: 'obsolete'));
    await tester.pump();
    expect(_text(tester, 'about_version').data, 'replacement');
    expect(find.text('obsolete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  aboutTestWidgets(
    'metadata failure and completion after disposal stay bounded',
    (
      WidgetTester tester,
    ) async {
      prepareAboutViewport(tester);
      final Completer<AboutInformation> source = Completer<AboutInformation>();
      await tester.pumpWidget(
        aboutHost(
          AboutCard(
            loadInformation: () => Future<AboutInformation>.error(
              StateError('synthetic private diagnostic'),
            ),
            loadLicences: _emptyLicences,
          ),
        ),
      );
      await tester.pump();
      expect(_text(tester, 'about_version').data, 'Unknown');
      expect(_text(tester, 'about_build').data, 'Unknown');
      expect(find.textContaining('private diagnostic'), findsNothing);
      await tester.pumpWidget(
        aboutHost(
          AboutCard(
            loadInformation: () => source.future,
            loadLicences: _emptyLicences,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      source.complete(AboutInformation(version: 'detached'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  aboutTestWidgets(
    'computer details mount on first opening and retain local actions',
    (WidgetTester tester) async {
      prepareAboutViewport(tester);
      final List<String> folders = <String>[];
      final List<String> links = <String>[];
      await tester.pumpWidget(
        aboutHost(
          AboutCard(
            loadInformation: () async => AboutInformation(
              details: <AboutField, String>{
                AboutField.origin: 'file:fixture-origin',
                AboutField.cache: 'fixture-cache',
                AboutField.wallet: '',
              },
            ),
            loadLicences: _emptyLicences,
            openLink: links.add,
            openFolder: (String path) async => folders.add(path),
          ),
        ),
      );
      await tester.pump();
      final Finder cache = find.byKey(const Key('about_info_cache'));
      final Finder retainedCache = find.byKey(
        const Key('about_info_cache'),
        skipOffstage: false,
      );
      expect(retainedCache, findsNothing);
      await _toggle(tester, 'about_computer_toggle');
      final Element originalCache = tester.element(cache);
      await _tapVisible(
        tester,
        find.descendant(
          of: cache,
          matching: find.byTooltip('Open folder'),
        ),
      );
      await tester.pump();
      expect(folders, <String>['fixture-cache']);
      expect(links, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(const Key('about_info_wallet')),
          matching: find.byTooltip('Open folder'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('about_info_origin')),
          matching: find.byTooltip('Open link'),
        ),
        findsNothing,
      );
      await _toggle(tester, 'about_computer_toggle');
      await tester.pump(const Duration(milliseconds: 16));
      expect(cache.hitTestable(), findsNothing);
      expect(tester.element(retainedCache), same(originalCache));
      await _toggle(tester, 'about_computer_toggle');
      expect(tester.element(cache), same(originalCache));
      expect(tester.takeException(), isNull);
    },
  );

  aboutTestWidgets(
    'update actions refuse pointer keyboard and direct activation',
    (
      WidgetTester tester,
    ) async {
      prepareAboutViewport(tester);
      await tester.pumpWidget(
        aboutHost(
          const AboutCard(
            loadInformation: _information,
            loadLicences: _emptyLicences,
          ),
        ),
      );
      await tester.pump();
      final Finder update = find.byKey(const Key('about_what_changed'));
      final OutlinedButton button = tester.widget<OutlinedButton>(update);
      expect(button.onPressed, isNotNull);
      expect(button.onPressed, throwsA(isA<SeamNotBuilt>()));
      await tester.tap(update, warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(
        find.byKey(const Key('about_link_0')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  aboutTestWidgets(
    'licences read once on opening and retain the end hook on closing',
    (WidgetTester tester) async {
      prepareAboutViewport(tester);
      int reads = 0;
      final Completer<AboutInformation> information =
          Completer<AboutInformation>();
      await tester.pumpWidget(
        aboutHost(
          AboutCard(
            loadInformation: () => information.future,
            loadLicences: () {
              reads++;
              return Stream<LicenseEntry>.value(
                FixtureLicence(
                  <String>['fixture-package'],
                  const <LicenseParagraph>[
                    LicenseParagraph('Fixture licence text', 0),
                  ],
                ),
              );
            },
            licencesTrailingBuilder: (_) => const Text('Fixture end hook'),
            afterLicences: const Text(
              'Fixture separate card',
              key: Key('fixture_after'),
            ),
          ),
        ),
      );
      expect(reads, 0);
      final Finder toggle = find.byKey(const Key('about_licences_toggle'));
      final Finder panel = find.byKey(const Key('about_licences'));
      final Finder decoration = find.descendant(
        of: toggle,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground,
        ),
      ).first;
      BoxBorder? headerBorder() =>
          (tester.widget<DecoratedBox>(decoration).decoration as BoxDecoration)
              .border;
      final double headerHeight = tester.getSize(toggle).height;
      final double closedHeight = tester.getSize(panel).height;
      final Finder disclosure = find.descendant(
        of: panel,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Disclosure && widget.keyPrefix == 'about_licences',
        ),
      );
      final Disclosure originalDisclosure = tester.widget(disclosure);
      expect(headerBorder(), isNull);
      await _tapVisible(tester, toggle);
      await tester.pump();
      expect(tester.widget<Disclosure>(disclosure), same(originalDisclosure));
      final List<OffsetLayer> precedingLayers = <OffsetLayer>[];
      for (final String key in <String>[
        'about_strip',
        'about_links',
        'about_computer',
      ]) {
        final RenderRepaintBoundary boundary = tester.renderObject(
          find
              .ancestor(
                of: find.byKey(Key(key)),
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );
        precedingLayers.add(boundary.debugLayer! as OffsetLayer);
      }
      expect(precedingLayers.toSet(), hasLength(3));
      final List<Layer?> precedingPaint = <Layer?>[
        for (final OffsetLayer layer in precedingLayers) layer.firstChild,
      ];
      expect(precedingPaint, everyElement(isNotNull));
      void expectRetainedPaint() {
        for (int index = 0; index < precedingLayers.length; index++) {
          expect(
            precedingLayers[index].firstChild,
            same(precedingPaint[index]),
          );
        }
      }

      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getSize(panel).height, greaterThan(closedHeight));
      expectRetainedPaint();
      await tester.pump(const Duration(milliseconds: 160));
      expectRetainedPaint();

      await tester.pump();
      expect(reads, 1);
      expect(find.text('Fixture end hook'), findsOneWidget);
      final AppTokens tokens = AppTokens.of(tester.element(toggle));
      expect(headerBorder(), Border(bottom: BorderSide(color: tokens.line)));
      expect(tester.getSize(toggle).height, headerHeight);
      final Element originalList = tester.element(find.byType(Licences));
      information.complete(AboutInformation(version: 'late-package-info'));
      await tester.pump();
      expect(_text(tester, 'about_version').data, 'late-package-info');
      expect(
        precedingLayers.first.firstChild,
        isNot(same(precedingPaint.first)),
      );
      expect(
        identical(originalList, tester.element(find.byType(Licences))),
        isTrue,
      );
      expect(find.byKey(const Key('fixture_after')), findsOneWidget);
      await _toggle(tester, 'about_licences_toggle');
      expect(find.text('Fixture end hook').hitTestable(), findsNothing);
      expect(headerBorder(), isNull);
      await _toggle(tester, 'about_licences_toggle');
      expect(reads, 1);
      expect(find.text('Fixture end hook'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
