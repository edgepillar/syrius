import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/shared_prefs_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/main_app_container.dart';

const double _collapsedWidth = 56;
const double _openWidth = 200;

/// The shell's own padding round the rail, so the rail is as tall here as it
/// is in the wallet.
const EdgeInsets _shellPadding = EdgeInsets.fromLTRB(10, 14, 18, 18);

const Key _toggle = ValueKey<String>('rail_toggle');
const Key _pill = Key('rail_pill');
const Key _page = Key('page');

Key _nav(Tabs tab) => ValueKey<String>('nav_${tab.name}');

/// A rail tooltip by its message. Not `find.byTooltip`: the rail keeps its
/// tooltips out of semantics, and for those the finder reads the message of
/// the SDK's own `Tooltip` class, which material_ui's is not.
Finder _tooltip(String message) => find.byWidgetPredicate(
  (Widget widget) => widget is Tooltip && widget.message == message,
);

/// The rail beside a page, as the shell lays the two out, and nothing else
/// of the shell: no wallet, no node, no shortcuts.
Widget _host({
  required RailCollapse collapse,
  Tabs selected = Tabs.dashboard,
  bool locked = false,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<Tabs>? onSelected,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Directionality(
    textDirection: direction,
    child: Scaffold(
      body: Padding(
        padding: _shellPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ShellRail(
              collapse: collapse,
              selected: selected,
              locked: locked,
              onSelected: onSelected ?? (Tabs _) {},
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox.expand(key: _page)),
          ],
        ),
      ),
    ),
  ),
);

Rect _rail(WidgetTester tester) => tester.getRect(find.byType(ShellRail));

/// Every icon of the rail: the toggle's, the pages' and the wallet's.
Finder _icons() =>
    find.descendant(of: find.byType(ShellRail), matching: find.byType(Icon));

Finder _labels() =>
    find.descendant(of: find.byType(ShellRail), matching: find.byType(Text));

/// How strongly the label [text] is drawn.
double _labelOpacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.text(text), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

/// The smallest window the wallet allows.
void _smallestWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Preferences kept in memory, for the tests that press the toggle.
///
/// The toggle stores as it is pressed, under the test's fake clock. A write
/// to a file begun there never finishes.
Future<void> _preferencesInMemory() async {
  await Hive.openBox<dynamic>(kSharedPrefsBox, bytes: Uint8List(0));
  sharedPrefsService = await SharedPrefsService.getInstance();
}

/// Preferences in a file, as the wallet has them.
Future<void> _preferencesInFile() async {
  sharedPrefsService = await SharedPrefsService.getInstance();
}

/// Closes the preferences and opens them again from the file, which is what
/// quitting and starting the wallet does to them.
Future<void> _restart() async {
  await sharedPrefsService!.close();
  await sharedPrefsService!.checkIfBoxIsOpen();
}

void main() {
  // A press that would not land on the row it was aimed at fails the test:
  // the harness presses rows by the same keys, in the middle.
  WidgetController.hitTestWarningShouldBeFatal = true;

  late Directory dir;

  // Whatever a test opens lands in a folder of its own, never in the
  // wallet's.
  setUp(() {
    dir = Directory.systemTemp.createTempSync('syrius_rail_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  group('the stored choice', () {
    setUp(_preferencesInFile);

    test('a profile that has never chosen gets the rail collapsed', () {
      expect(RailCollapse().value, isTrue);
      // Reading the default stores nothing: it stays "never chosen".
      expect(sharedPrefsService!.get(kRailCollapsedKey), isNull);
    });

    test('is stored when it changes and read at the next start', () async {
      RailCollapse().toggle();
      expect(sharedPrefsService!.get(kRailCollapsedKey), isFalse);
      await _restart();
      expect(RailCollapse().value, isFalse);

      RailCollapse().toggle();
      await _restart();
      expect(sharedPrefsService!.get(kRailCollapsedKey), isTrue);
      expect(RailCollapse().value, isTrue);
    });

    test('a damaged entry reads as never chosen', () async {
      await sharedPrefsService!.put(kRailCollapsedKey, 'open');
      expect(RailCollapse().value, isTrue);
    });
  });

  group('the rail', () {
    setUp(_preferencesInMemory);

    testWidgets('starts collapsed: a strip of centred icons and no text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      final Rect rail = _rail(tester);
      expect(rail.width, _collapsedWidth);
      expect(rail.left, _shellPadding.left);
      expect(_labels(), findsNothing);
      // The toggle, nine pages, and at least Notifications, Settings, Lock.
      expect(_icons().evaluate().length, greaterThanOrEqualTo(13));
      for (final Element icon in _icons().evaluate()) {
        expect(
          tester.getCenter(find.byWidget(icon.widget)).dx,
          rail.center.dx,
          reason: '${icon.widget}',
        );
      }
      // The page has everything the rail does not.
      expect(
        tester.getSize(find.byKey(_page)).width,
        800 - _shellPadding.horizontal - _collapsedWidth - 8,
      );
    });

    testWidgets('starts open when that is what was stored', (
      WidgetTester tester,
    ) async {
      await sharedPrefsService!.put(kRailCollapsedKey, false);
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      // On the first frame: nothing opens as the wallet starts.
      expect(_rail(tester).width, _openWidth);
      expect(find.text('Home'), findsOneWidget);
      expect(_labelOpacity(tester, 'Home'), 1);
      expect(_tooltip('Collapse'), findsOneWidget);
    });

    testWidgets('collapsed, every item is named by a tooltip beside it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      for (final String name in <String>[
        'Expand',
        'Home',
        'Transfer',
        'Pillars',
        'Sentinels',
        'Staking',
        'Plasma',
        'Tokens',
        'P2P Swap',
        'Accelerator',
        'Notifications',
        'Settings',
        'Lock',
      ]) {
        expect(_tooltip(name), findsOneWidget, reason: name);
      }

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_nav(Tabs.transfer))));
      await tester.pumpAndSettle();

      // Beside the item, towards the page, and level with it: under it, it
      // would lie on the next icon.
      final Rect tip = tester.getRect(find.text('Transfer'));
      final Rect item = tester.getRect(find.byKey(_nav(Tabs.transfer)));
      expect(tip.left, greaterThan(_rail(tester).right));
      expect(tip.center.dy, closeTo(item.center.dy, 1));
    });

    testWidgets('open, the labels name the items and no tooltip repeats them', (
      WidgetTester tester,
    ) async {
      await sharedPrefsService!.put(kRailCollapsedKey, false);
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_nav(Tabs.transfer))));
      await tester.pumpAndSettle();

      // The label, and no second "Transfer" floating beside it.
      expect(find.text('Transfer'), findsOneWidget);

      // The toggle has no label, so it keeps its tooltip.
      await mouse.moveTo(tester.getCenter(find.byKey(_toggle)));
      await tester.pumpAndSettle();
      expect(find.text('Collapse'), findsOneWidget);
    });

    testWidgets('the toggle opens it over 200 ms, labels fading on one line', (
      WidgetTester tester,
    ) async {
      final RailCollapse collapse = RailCollapse();
      await tester.pumpWidget(_host(collapse: collapse));
      final double pageCollapsed = tester.getSize(find.byKey(_page)).width;

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(collapse.value, isFalse);
      expect(sharedPrefsService!.get(kRailCollapsedKey), isFalse);

      // On the way: between the two widths, the label already at the size
      // it will have open (so neither wrapped nor cut to a new ellipsis)
      // and not yet at full strength.
      await tester.pump(const Duration(milliseconds: 40));
      final double midWidth = _rail(tester).width;
      expect(midWidth, greaterThan(_collapsedWidth));
      expect(midWidth, lessThan(_openWidth));
      final Size midLabel = tester.getSize(find.text('Notifications'));
      expect(_labelOpacity(tester, 'Notifications'), greaterThan(0));
      expect(_labelOpacity(tester, 'Notifications'), lessThan(1));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 150));
      expect(_rail(tester).width, lessThan(_openWidth));
      await tester.pump(const Duration(milliseconds: 10));
      expect(_rail(tester).width, _openWidth);

      expect(tester.getSize(find.text('Notifications')), midLabel);
      expect(_labelOpacity(tester, 'Notifications'), 1);
      expect(_tooltip('Collapse'), findsOneWidget);
      // The page gave up exactly what the rail took.
      expect(
        tester.getSize(find.byKey(_page)).width,
        pageCollapsed - (_openWidth - _collapsedWidth),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the toggle collapses it again and the labels leave the tree', (
      WidgetTester tester,
    ) async {
      final RailCollapse collapse = RailCollapse();
      await tester.pumpWidget(_host(collapse: collapse));

      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();
      expect(_rail(tester).width, _openWidth);
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      // Still there while it closes, fading: it does not pop out.
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Home'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(collapse.value, isTrue);
      expect(sharedPrefsService!.get(kRailCollapsedKey), isTrue);
      expect(_rail(tester).width, _collapsedWidth);
      expect(_labels(), findsNothing);
      expect(_tooltip('Expand'), findsOneWidget);
    });

    testWidgets('follows a change made outside it, as the shortcut makes', (
      WidgetTester tester,
    ) async {
      final RailCollapse collapse = RailCollapse();
      await tester.pumpWidget(_host(collapse: collapse));

      collapse.toggle();
      await tester.pumpAndSettle();
      expect(_rail(tester).width, _openWidth);

      collapse.toggle();
      await tester.pumpAndSettle();
      expect(_rail(tester).width, _collapsedWidth);
    });

    testWidgets('moves at full length when the system asks for less motion', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      // A controller left to the system's setting would be done in 10 ms.
      await tester.pump(const Duration(milliseconds: 40));
      expect(_rail(tester).width, greaterThan(_collapsedWidth));
      expect(_rail(tester).width, lessThan(_openWidth));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_rail(tester).width, lessThan(_openWidth));
      await tester.pumpAndSettle();
      expect(_rail(tester).width, _openWidth);
    });

    testWidgets('collapsed, an item opens its page and the pill fits', (
      WidgetTester tester,
    ) async {
      final List<Tabs> opened = <Tabs>[];
      await tester.pumpWidget(
        _host(
          collapse: RailCollapse(),
          selected: Tabs.transfer,
          onSelected: opened.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_nav(Tabs.staking)));
      await tester.tap(find.byKey(_nav(Tabs.settings)));
      expect(opened, <Tabs>[Tabs.staking, Tabs.settings]);

      // The pill is the selected row, toggle's row counted, at the strip's
      // width.
      expect(
        tester.getRect(find.byKey(_pill)),
        rectMoreOrLessEquals(
          tester.getRect(find.byKey(_nav(Tabs.transfer))),
          epsilon: 0.01,
        ),
      );
      expect(tester.getSize(find.byKey(_pill)).width, _collapsedWidth);

      // And from the bottom for the wallet's entries.
      await tester.pumpWidget(
        _host(collapse: RailCollapse(), selected: Tabs.settings),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(_pill)),
        rectMoreOrLessEquals(
          tester.getRect(find.byKey(_nav(Tabs.settings))),
          epsilon: 0.01,
        ),
      );
    });

    testWidgets('locked, the toggle takes no pointer and no focus', (
      WidgetTester tester,
    ) async {
      final RailCollapse collapse = RailCollapse();
      final List<Tabs> opened = <Tabs>[];
      await tester.pumpWidget(
        _host(
          collapse: collapse,
          selected: Tabs.lock,
          locked: true,
          onSelected: opened.add,
        ),
      );

      await tester.tap(find.byKey(_toggle), warnIfMissed: false);
      await tester.tap(find.byKey(_nav(Tabs.dashboard)), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(collapse.value, isTrue);
      expect(_rail(tester).width, _collapsedWidth);
      expect(opened, isEmpty);
      expect(sharedPrefsService!.get(kRailCollapsedKey), isNull);

      expect(
        tester
            .widget<ExcludeFocus>(
              find
                  .ancestor(
                    of: find.byKey(_toggle),
                    matching: find.byType(ExcludeFocus),
                  )
                  .first,
            )
            .excluding,
        isTrue,
      );
      for (int i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        bool inRail = false;
        primaryFocus?.context?.visitAncestorElements((Element ancestor) {
          inRail = ancestor.widget is ShellRail;
          return !inRail;
        });
        expect(inRail, isFalse, reason: 'Tab $i reached the rail');
      }
    });

    testWidgets('right to left, it is the same strip on the other side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(collapse: RailCollapse(), direction: TextDirection.rtl),
      );

      // The shell's padding is not directional, so the rail has the page's
      // 18 px beside it here and not its own 10.
      Rect rail = _rail(tester);
      expect(rail.right, 800 - _shellPadding.right);
      expect(rail.width, _collapsedWidth);
      for (final Element icon in _icons().evaluate()) {
        expect(
          tester.getCenter(find.byWidget(icon.widget)).dx,
          rail.center.dx,
        );
      }

      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();
      rail = _rail(tester);
      expect(rail.width, _openWidth);
      // Icon at the start, which is the right, and its label to the left
      // of it.
      final Rect icon = tester.getRect(find.byIcon(Icons.home_outlined));
      final Rect label = tester.getRect(find.text('Home'));
      expect(icon.right, rail.right - 12);
      expect(label.right, icon.left - 12);
    });

    testWidgets('fits the smallest window, collapsed and open', (
      WidgetTester tester,
    ) async {
      _smallestWindow(tester);
      await tester.pumpWidget(_host(collapse: RailCollapse()));

      for (final double width in <double>[_collapsedWidth, _openWidth]) {
        final Rect rail = _rail(tester);
        expect(rail.width, width);
        expect(tester.getRect(find.byKey(_toggle)).top, rail.top + 1);
        expect(
          tester.getRect(find.byKey(_nav(Tabs.lock))).bottom,
          closeTo(rail.bottom - 1, 0.01),
        );
        // Rows keep their order and do not overlap.
        expect(
          tester.getRect(find.byKey(_nav(Tabs.accelerator))).bottom,
          lessThan(tester.getRect(find.byKey(_nav(Tabs.notifications))).top),
        );
        await tester.tap(find.byKey(_toggle));
        await tester.pumpAndSettle();
      }
    });
  });
}
