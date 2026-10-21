import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';

const Key _panel = Key('panel');
const Key _body = Key('body');
const Key _rest = Key('rest');
const Key _action = Key('action');

/// Where a panel's state is stored, written out and not read from the
/// widget's file: a profile already holds entries under this prefix, so a
/// change to it loses every reader's choices and should fail a test.
const String _prefix = 'panel_collapsed_';

const double _header = 48;

// The app theme: its divider takes 1 px, Material's default takes 16.
Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SizedBox(width: 400, height: 600, child: child),
        ),
      ),
    );

/// A panel above whatever takes the height it leaves, as a short card sits
/// above a list on a page.
Widget _stacked(Widget panel) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
    panel,
    const Expanded(child: SizedBox.expand(key: _rest)),
  ],
);

/// A collapsible panel as tall as its body: 48 title row, 1 divider, 30
/// body.
Panel _short({
  bool initiallyCollapsed = false,
  String title = 'Activity',
  String collapseKey = 'test.activity',
  List<Widget> actions = const <Widget>[],
}) => Panel(
  key: _panel,
  title: title,
  shrinkWrap: true,
  collapsible: true,
  initiallyCollapsed: initiallyCollapsed,
  collapseKey: collapseKey,
  actions: actions,
  child: const SizedBox(key: _body, height: 30),
);

Finder _chevron() => find.byIcon(Icons.expand_more);

/// The card itself, which a slot of fixed height may be taller than.
Finder _card() => find
    .descendant(of: find.byKey(_panel), matching: find.byType(Material))
    .first;

double _height(WidgetTester tester, Key key) =>
    tester.getSize(find.byKey(key)).height;

/// How far the chevron is turned, in turns.
double _turns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find
          .ancestor(of: _chevron(), matching: find.byType(RotationTransition))
          .first,
    )
    .turns
    .value;

void main() {
  group('a panel that does not fold', () {
    testWidgets('is unchanged: no chevron, no button, its body shown', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Panel(
            key: _panel,
            title: 'Activity',
            child: SizedBox(key: _body, height: 30),
          ),
        ),
      );

      expect(_chevron(), findsNothing);
      expect(find.byKey(_body), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(_height(tester, _panel), 600);
      expect(tester.getSize(_card()).height, 600);
      // The body has what the title row and the divider leave.
      expect(_height(tester, _body), 600 - _header - 1);
      expect(
        find.descendant(
          of: find.byKey(_panel),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);
    });
  });

  group('a collapsible panel, with no preferences open', () {
    testWidgets('starts open, with a chevron at the end of its title row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));

      expect(tester.takeException(), isNull);
      expect(find.byKey(_body), findsOneWidget);
      expect(_chevron(), findsOneWidget);
      expect(_height(tester, _panel), _header + 1 + 30);
      // Trailing: 8 of padding from the card's right edge.
      expect(tester.getRect(_chevron()).right, 400 - 8);
      expect(
        tester.getRect(_chevron()).left,
        greaterThanOrEqualTo(tester.getRect(find.text('Activity')).right),
      );
      // Turned to point up.
      expect(_turns(tester), 0.5);
      // It starts where it is: nothing opens as the page is shown.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('starts closed with initiallyCollapsed: its title row only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_stacked(_short(initiallyCollapsed: true))),
      );

      expect(find.byKey(_body), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(_chevron(), findsOneWidget);
      expect(_turns(tester), 0);
      expect(_height(tester, _panel), _header);
      expect(tester.getSize(_card()).height, _header);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a tap on the title row closes it, and another opens it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
      expect(_turns(tester), 0);

      // Anywhere on the row, not only on the title or the chevron.
      await tester.tapAt(const Offset(200, _header / 2));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);
      expect(_turns(tester), 0.5);

      await tester.tap(_chevron());
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
      // With no box to store in, nothing threw: the state is the panel's.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter and Space toggle it when the title row has the focus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));

      // Not focused: the keys are not the panel's.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);

      // The row is still there to be pressed, and still has the focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets('the title row is a button for the pointer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 400));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );

      await mouse.moveTo(tester.getCenter(find.text('Activity')));
      await tester.pumpAndSettle();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    });

    testWidgets("a trailing action's tap is its own and toggles nothing", (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        _host(
          _stacked(
            _short(
              actions: <Widget>[
                IconButton(
                  key: _action,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => pressed++,
                ),
              ],
            ),
          ),
        ),
      );

      // The action sits before the chevron, which keeps the end.
      expect(
        tester.getRect(find.byKey(_action)).right,
        lessThanOrEqualTo(tester.getRect(_chevron()).left),
      );

      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(find.byKey(_body), findsOneWidget);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);

      // Closed, the action is still there and still its own.
      await tester.tap(find.byKey(_action));
      await tester.pumpAndSettle();
      expect(pressed, 2);
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets(
      'closed in a column, as tall as its body, it gives its height back',
      (WidgetTester tester) async {
        await tester.pumpWidget(_host(_stacked(_short())));
        expect(_height(tester, _panel), 79);
        expect(_height(tester, _rest), 600 - 79);

        await tester.tap(find.text('Activity'));
        await tester.pump();
        // On the way: between the two heights, the body still there and
        // at its full height under the clip, so nothing overflows.
        await tester.pump(const Duration(milliseconds: 100));
        final double mid = _height(tester, _panel);
        expect(mid, greaterThan(_header));
        expect(mid, lessThan(79));
        expect(_height(tester, _rest), 600 - mid);
        expect(_height(tester, _body), 30);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(milliseconds: 90));
        expect(_height(tester, _panel), greaterThan(_header));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump();

        // No divider and no padding left under the title row.
        expect(_height(tester, _panel), _header);
        expect(tester.getSize(_card()).height, _header);
        expect(find.byType(Divider), findsNothing);
        expect(find.byKey(_body), findsNothing);
        expect(_height(tester, _rest), 600 - _header);
        // Once the tap's ink has faded too, no ticker is left running.
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(_height(tester, _panel), _header);
      },
    );

    testWidgets(
      'in a slot of fixed height the card shrinks to its title row and the '
      'slot keeps its height',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(
            const Panel(
              key: _panel,
              title: 'Activity',
              collapsible: true,
              collapseKey: 'test.slot',
              // A body that cannot be squeezed: laid out any shorter than
              // its slot on the way, it would overflow.
              child: Column(
                key: _body,
                children: <Widget>[
                  SizedBox(height: 400),
                  Spacer(),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );

        // Open, it is the panel it would be if it could not fold.
        expect(tester.getSize(_card()).height, 600);
        expect(_height(tester, _body), 600 - _header - 1);

        await tester.tap(find.text('Activity'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getSize(_card()).height, greaterThan(_header));
        expect(tester.getSize(_card()).height, lessThan(600));
        expect(_height(tester, _body), 600 - _header - 1);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        expect(tester.getRect(_card()), const Rect.fromLTWH(0, 0, 400, 48));
        expect(find.byKey(_body), findsNothing);
        // What the panel alone cannot give away.
        expect(_height(tester, _panel), 600);

        await tester.tap(find.text('Activity'));
        await tester.pumpAndSettle();
        expect(tester.getSize(_card()).height, 600);
        expect(_height(tester, _body), 600 - _header - 1);
      },
    );

    testWidgets('moves at full length when the system asks for less motion', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(_stacked(_short())));

      await tester.tap(find.text('Activity'));
      await tester.pump();
      // A controller left to the system's setting would be done in 10 ms.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester, _panel), greaterThan(_header));
      expect(_height(tester, _panel), lessThan(79));
      await tester.pumpAndSettle();
      expect(_height(tester, _panel), _header);
    });

    testWidgets('a close turned back before it ends leaves the body in place', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));

      await tester.tap(find.text('Activity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.byKey(_body), findsOneWidget);
      expect(_height(tester, _panel), 79);
    });

    testWidgets(
      'right to left, the chevron keeps the end of the row, which is the '
      'left, and turns the other way',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(_stacked(_short()), direction: TextDirection.rtl),
        );

        // 8 of padding from the card's left edge, where left to right has
        // the title 16 in.
        expect(tester.getRect(_chevron()).left, 8);
        expect(tester.getRect(find.text('Activity')).right, 400 - 16);
        expect(
          tester.getRect(_chevron()).right,
          lessThanOrEqualTo(tester.getRect(find.text('Activity')).left),
        );
        expect(_turns(tester), -0.5);

        await tester.tap(find.text('Activity'));
        await tester.pumpAndSettle();
        expect(_turns(tester), 0);
        expect(tester.getRect(_chevron()).left, 8);
        expect(find.byKey(_body), findsNothing);
      },
    );
  });

  group('an empty panel', () {
    Panel empty({required bool isEmpty, bool collapsible = false}) => Panel(
      key: _panel,
      title: 'To collect',
      shrinkWrap: true,
      collapsible: collapsible,
      collapseKey: collapsible ? 'test.collect' : null,
      emptyNote: 'None yet',
      isEmpty: isEmpty,
      actions: const <Widget>[Text('0')],
      child: const SizedBox(key: _body, height: 30),
    );

    testWidgets('is one line: the note beside the title, and no body', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(empty(isEmpty: true))));

      expect(find.byKey(_body), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(_height(tester, _panel), _header);
      expect(_height(tester, _rest), 600 - _header);

      // Beside the title and after it, on the title row.
      final Rect title = tester.getRect(find.text('To collect'));
      final Rect note = tester.getRect(find.text('None yet'));
      expect(note.left, greaterThan(title.right));
      expect(note.bottom, lessThan(_header));
      expect(note.top, greaterThan(0));
      // Muted: the theme's faint, not the title's ink.
      expect(
        tester.widget<Text>(find.text('None yet')).style!.color,
        AppTokens.dark.faint,
      );
      // The owner's actions stay.
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('does not toggle, and shows no chevron that says it could', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_stacked(empty(isEmpty: true, collapsible: true))),
      );

      expect(_chevron(), findsNothing);

      await tester.tap(find.text('To collect'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
      expect(_height(tester, _panel), _header);

      // Nor from the keyboard: the row takes no focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);

      // And the pointer is not told there is something to press.
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('To collect')));
      await tester.pumpAndSettle();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );
    });

    testWidgets('takes its body back when content arrives, and folds again', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(empty(isEmpty: true))));

      await tester.pumpWidget(_host(_stacked(empty(isEmpty: false))));
      // It opens, it does not jump open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester, _panel), greaterThan(_header));
      expect(_height(tester, _panel), lessThan(79));
      await tester.pumpAndSettle();

      expect(find.byKey(_body), findsOneWidget);
      expect(find.text('None yet'), findsNothing);
      expect(_height(tester, _panel), 79);
      // Not collapsible: it has its body and nothing to close it with.
      expect(_chevron(), findsNothing);

      await tester.pumpWidget(_host(_stacked(empty(isEmpty: true))));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
      expect(find.text('None yet'), findsOneWidget);
      expect(_height(tester, _panel), _header);
    });

    testWidgets('a collapsible one gets its chevron with its content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_stacked(empty(isEmpty: true, collapsible: true))),
      );

      await tester.pumpWidget(
        _host(_stacked(empty(isEmpty: false, collapsible: true))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);
      expect(_chevron(), findsOneWidget);

      await tester.tap(find.text('To collect'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
    });
  });

  group('the stored state', () {
    late Directory dir;
    late Box<dynamic> preferences;

    // Kept in memory: a toggle stores as it is pressed, under the test's
    // fake clock, and a write to a file begun there never finishes.
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('syrius_panel_');
      Hive.init(dir.path);
      preferences = await Hive.openBox<dynamic>(
        kSharedPrefsBox,
        bytes: Uint8List(0),
      );
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    testWidgets('is written under the key, not the title, at each toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));
      // Showing a panel stores nothing: it stays "never chosen".
      expect(preferences.get('${_prefix}test.activity'), isNull);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(preferences.get('${_prefix}test.activity'), isTrue);
      expect(preferences.keys, <String>['${_prefix}test.activity']);

      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(preferences.get('${_prefix}test.activity'), isFalse);
    });

    testWidgets('wins over initiallyCollapsed the next time it is built', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_stacked(_short(initiallyCollapsed: true))),
      );
      expect(find.byKey(_body), findsNothing);
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsOneWidget);

      // Another page, then this one again: a new panel, the same key.
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(
        _host(_stacked(_short(initiallyCollapsed: true))),
      );
      expect(find.byKey(_body), findsOneWidget);
      // And it is open at once: it does not open again in front of them.
      expect(_height(tester, _panel), 79);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('closed wins over a panel that would start open', (
      WidgetTester tester,
    ) async {
      await preferences.put('${_prefix}test.activity', true);
      await tester.pumpWidget(_host(_stacked(_short())));

      expect(find.byKey(_body), findsNothing);
      expect(_height(tester, _panel), _header);
    });

    testWidgets('survives a change of language, which changes the title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_stacked(_short())));
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(_host(_stacked(_short(title: 'Aktivität'))));
      expect(find.text('Aktivität'), findsOneWidget);
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets("is one panel's: another key has its own", (
      WidgetTester tester,
    ) async {
      await preferences.put('${_prefix}test.activity', true);
      await tester.pumpWidget(
        _host(_stacked(_short(collapseKey: 'test.other'))),
      );
      expect(find.byKey(_body), findsOneWidget);

      // The same widget given another key reads that key's state.
      await tester.pumpWidget(_host(_stacked(_short())));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets('a damaged entry reads as never chosen', (
      WidgetTester tester,
    ) async {
      await preferences.put('${_prefix}test.activity', 'open');
      await tester.pumpWidget(
        _host(_stacked(_short(initiallyCollapsed: true))),
      );
      expect(find.byKey(_body), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty panel leaves what was chosen alone', (
      WidgetTester tester,
    ) async {
      await preferences.put('${_prefix}test.collect', true);
      Panel collect({required bool isEmpty}) => Panel(
        key: _panel,
        title: 'To collect',
        shrinkWrap: true,
        collapsible: true,
        collapseKey: 'test.collect',
        emptyNote: 'None yet',
        isEmpty: isEmpty,
        child: const SizedBox(key: _body, height: 30),
      );

      await tester.pumpWidget(_host(_stacked(collect(isEmpty: true))));
      await tester.tap(find.text('To collect'));
      await tester.pumpAndSettle();
      expect(preferences.get('${_prefix}test.collect'), isTrue);

      // Content arrives in a panel its reader had closed: it stays closed,
      // and now has the chevron to open it with.
      await tester.pumpWidget(_host(_stacked(collect(isEmpty: false))));
      await tester.pumpAndSettle();
      expect(find.byKey(_body), findsNothing);
      expect(find.text('None yet'), findsNothing);
      expect(_chevron(), findsOneWidget);
    });
  });
}
