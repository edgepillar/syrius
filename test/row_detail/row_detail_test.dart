import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/row_detail.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

const double _rowHeight = 32;
const double _detailHeight = 60;

/// The mockup's spring, written out and not read from the widget's file: a
/// change to the curve there should fail the mid-height test.
const Cubic _spring = Cubic(0.2, 0.8, 0.2, 1);

Key _rowKey(String name) => ValueKey<String>('${name}_row');
Key _detailKey(String name) => ValueKey<String>('${name}_detail');
Key _boxKey(String name) => ValueKey<String>('${name}_box');
Key _buttonKey(String name) => ValueKey<String>('${name}_button');

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

/// A row as a table would hold one: a chevron, a name, and at the end a
/// button when [button] is given.
RowDetail _row(
  String name, {
  bool? open,
  ValueChanged<bool>? onToggle,
  Object? id,
  bool initiallyOpen = false,
  Widget? button,
  VoidCallback? onDetailBuilt,
}) => RowDetail(
  key: _boxKey(name),
  keyPrefix: name,
  open: open,
  onToggle: onToggle,
  id: id,
  initiallyOpen: initiallyOpen,
  row: Row(
    children: <Widget>[
      const RowDetailChevron(),
      Expanded(child: Text(name)),
      ?button,
    ],
  ),
  detail: (BuildContext context) {
    onDetailBuilt?.call();
    return SizedBox(key: _detailKey(name), height: _detailHeight);
  },
);

Widget _column(List<Widget> rows) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: rows,
);

double _height(WidgetTester tester, Key key) =>
    tester.getSize(find.byKey(key)).height;

/// How far the chevron of the row called [name] is turned, in turns.
double _turns(WidgetTester tester, String name) => tester
    .widget<RotationTransition>(
      find.descendant(
        of: find.byKey(_rowKey(name)),
        matching: find.byType(RotationTransition),
      ),
    )
    .turns
    .value;

/// The clip round the detail, which is on only while it moves.
Clip _clip(WidgetTester tester, String name) => tester
    .widget<ClipRect>(
      find
          .ancestor(
            of: find.byKey(_detailKey(name)),
            matching: find.byType(ClipRect),
          )
          .first,
    )
    .clipBehavior;

void main() {
  group('RowDetail', () {
    testWidgets('is closed by default, and its detail is not built', (
      WidgetTester tester,
    ) async {
      int built = 0;
      await tester.pumpWidget(
        _host(_column(<Widget>[_row('a', onDetailBuilt: () => built++)])),
      );

      expect(built, 0);
      expect(find.byKey(_detailKey('a')), findsNothing);
      expect(_height(tester, _boxKey('a')), _rowHeight);
      expect(_turns(tester, 'a'), -0.25);
    });

    testWidgets('a tap opens it, mid-height on the way, and another closes', (
      WidgetTester tester,
    ) async {
      int built = 0;
      final List<bool> asked = <bool>[];
      await tester.pumpWidget(
        _host(
          _column(<Widget>[
            _row('a', onToggle: asked.add, onDetailBuilt: () => built++),
          ]),
        ),
      );

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pump();
      expect(asked, <bool>[true]);
      expect(built, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 120));

      // Half of 240 ms along the spring, the detail at its full height
      // under the clip and still above its place.
      final double t = _spring.transform(0.5);
      expect(
        _height(tester, _boxKey('a')),
        moreOrLessEquals(_rowHeight + _detailHeight * t, epsilon: 0.01),
      );
      expect(_height(tester, _detailKey('a')), _detailHeight);
      expect(_clip(tester, 'a'), Clip.hardEdge);
      final double top = tester.getRect(find.byKey(_detailKey('a'))).top;
      expect(top, moreOrLessEquals(_rowHeight - 8 * (1 - t), epsilon: 0.01));
      final double opacity = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byKey(_detailKey('a')),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacity, moreOrLessEquals(t, epsilon: 0.001));

      await tester.pumpAndSettle();
      expect(_height(tester, _boxKey('a')), _rowHeight + _detailHeight);
      expect(tester.getRect(find.byKey(_detailKey('a'))).top, _rowHeight);
      expect(_clip(tester, 'a'), Clip.none);
      expect(_turns(tester, 'a'), 0);

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(_height(tester, _boxKey('a')), greaterThan(_rowHeight));
      expect(
        _height(tester, _boxKey('a')),
        lessThan(_rowHeight + _detailHeight),
      );
      expect(_clip(tester, 'a'), Clip.hardEdge);
      await tester.pumpAndSettle();
      expect(asked, <bool>[true, false]);
      expect(find.byKey(_detailKey('a')), findsNothing);
      expect(_height(tester, _boxKey('a')), _rowHeight);
    });

    testWidgets('moves at full length when the system asks for less motion', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(_column(<Widget>[_row('a')])));

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pump();
      // A controller left to the system's setting would be done in 12 ms.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester, _boxKey('a')), greaterThan(_rowHeight));
      expect(
        _height(tester, _boxKey('a')),
        lessThan(_rowHeight + _detailHeight),
      );
      expect(_turns(tester, 'a'), lessThan(0));
      await tester.pumpAndSettle();
      expect(_height(tester, _boxKey('a')), _rowHeight + _detailHeight);
    });

    testWidgets('rows without a group are independent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_column(<Widget>[_row('a', initiallyOpen: true), _row('b')])),
      );
      expect(find.byKey(_detailKey('a')), findsOneWidget);

      await tester.tap(find.byKey(_rowKey('b')));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsOneWidget);
      expect(find.byKey(_detailKey('b')), findsOneWidget);
    });

    testWidgets('controlled, a press only asks and the caller decides', (
      WidgetTester tester,
    ) async {
      final List<bool> asked = <bool>[];
      Widget build({required bool open}) => _host(
        _column(<Widget>[_row('a', open: open, onToggle: asked.add)]),
      );
      await tester.pumpWidget(build(open: false));

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pumpAndSettle();
      expect(asked, <bool>[true]);
      expect(find.byKey(_detailKey('a')), findsNothing);

      await tester.pumpWidget(build(open: true));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_height(tester, _boxKey('a')), greaterThan(_rowHeight));
      expect(
        _height(tester, _boxKey('a')),
        lessThan(_rowHeight + _detailHeight),
      );
      await tester.pumpAndSettle();
      expect(_height(tester, _boxKey('a')), _rowHeight + _detailHeight);

      await tester.pumpWidget(build(open: false));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsNothing);
    });

    testWidgets('Enter and Space toggle it when the row has the focus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_column(<Widget>[_row('a')])));

      // Not focused: the keys are not the row's.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsNothing);
    });

    testWidgets('the row is a button, for the pointer and a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(_column(<Widget>[_row('a')])));

      expect(
        tester.getSemantics(find.byKey(_rowKey('a'))),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );

      final RenderObject box = tester.renderObject(
        find
            .descendant(
              of: find.byKey(_boxKey('a')),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final Color tint = AppTokens.dark.hover;
      expect(box, isNot(paints..rect(color: tint)));

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(200, 400));
      addTearDown(mouse.removePointer);
      await tester.pump();
      // Anywhere on the row, the empty middle included.
      await mouse.moveTo(const Offset(250, _rowHeight / 2));
      await tester.pumpAndSettle();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      expect(
        box,
        paints..rect(
          rect: const Rect.fromLTWH(0, 0, 400, _rowHeight),
          color: tint,
        ),
      );

      // Open, the one tint runs on under the detail, and stays when the
      // pointer has gone.
      await tester.tap(find.byKey(_rowKey('a')));
      await mouse.moveTo(const Offset(200, 400));
      await tester.pumpAndSettle();
      expect(
        box,
        paints..rect(
          rect: const Rect.fromLTWH(0, 0, 400, _rowHeight + _detailHeight),
          color: tint,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_rowKey('a'))),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
      );
      semantics.dispose();
    });

    testWidgets('right to left the row is mirrored and the chevron starts '
        'from the other side', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(_column(<Widget>[_row('a')]), direction: TextDirection.rtl),
      );

      final Rect chevron = tester.getRect(
        find.descendant(
          of: find.byKey(_rowKey('a')),
          matching: find.byType(RowDetailChevron),
        ),
      );
      expect(chevron.right, 400);
      expect(_turns(tester, 'a'), 0.25);

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pumpAndSettle();
      expect(_turns(tester, 'a'), 0);
      expect(
        tester.getRect(find.byKey(_detailKey('a'))),
        const Rect.fromLTWH(0, _rowHeight, 400, _detailHeight),
      );
    });
  });

  group('an inner button', () {
    for (final bool enabled in <bool>[true, false]) {
      final String state = enabled ? 'enabled' : 'disabled';
      testWidgets('$state, keeps the press from the row', (
        WidgetTester tester,
      ) async {
        int pressed = 0;
        final List<bool> asked = <bool>[];
        await tester.pumpWidget(
          _host(
            _column(<Widget>[
              _row(
                'a',
                onToggle: asked.add,
                button: RowDetailIgnore(
                  child: TextButton(
                    key: _buttonKey('a'),
                    onPressed: enabled ? () => pressed++ : null,
                    child: const Text('Go'),
                  ),
                ),
              ),
            ]),
          ),
        );

        await tester.tap(find.byKey(_buttonKey('a')));
        await tester.pumpAndSettle();
        expect(pressed, enabled ? 1 : 0);
        expect(asked, isEmpty);
        expect(find.byKey(_detailKey('a')), findsNothing);

        // A press held past the tap deadline is no different.
        await tester.longPress(find.byKey(_buttonKey('a')));
        await tester.pumpAndSettle();
        expect(asked, isEmpty);

        // The rest of the row is still the row's.
        await tester.tap(find.text('a'));
        await tester.pumpAndSettle();
        expect(asked, <bool>[true]);
        expect(find.byKey(_detailKey('a')), findsOneWidget);
      });
    }

    testWidgets('enabled and unwrapped, still wins the press', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await tester.pumpWidget(
        _host(
          _column(<Widget>[
            _row(
              'a',
              button: TextButton(
                key: _buttonKey('a'),
                onPressed: () => pressed++,
                child: const Text('Go'),
              ),
            ),
          ]),
        ),
      );

      await tester.tap(find.byKey(_buttonKey('a')));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(find.byKey(_detailKey('a')), findsNothing);
    });
  });

  group('RowDetailGroup', () {
    testWidgets('opening one row closes the other', (
      WidgetTester tester,
    ) async {
      final List<Object?> changes = <Object?>[];
      await tester.pumpWidget(
        _host(
          RowDetailGroup(
            onChanged: changes.add,
            child: _column(<Widget>[
              _row('a', id: 'a'),
              _row('b', id: 'b'),
              _row('c'),
            ]),
          ),
        ),
      );

      await tester.tap(find.byKey(_rowKey('a')));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsOneWidget);

      await tester.tap(find.byKey(_rowKey('b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // One on its way out as the other comes in.
      expect(_height(tester, _boxKey('a')), greaterThan(_rowHeight));
      expect(
        _height(tester, _boxKey('a')),
        lessThan(_rowHeight + _detailHeight),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('a')), findsNothing);
      expect(find.byKey(_detailKey('b')), findsOneWidget);

      // A row with no id is not the group's.
      await tester.tap(find.byKey(_rowKey('c')));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('b')), findsOneWidget);
      expect(find.byKey(_detailKey('c')), findsOneWidget);

      await tester.tap(find.byKey(_rowKey('b')));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('b')), findsNothing);
      expect(changes, <Object?>['a', 'b', null]);
    });

    testWidgets('keeps a row open while it is scrolled out of a lazy list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          RowDetailGroup(
            child: ListView.builder(
              itemCount: 100,
              itemBuilder: (BuildContext context, int index) =>
                  _row('r$index', id: index),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(_rowKey('r1')));
      await tester.pumpAndSettle();
      expect(find.byKey(_detailKey('r1')), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byKey(_boxKey('r1')), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      // One frame, no settling: it comes back open, not opening.
      await tester.pump();
      expect(find.byKey(_detailKey('r1')), findsOneWidget);
      expect(_height(tester, _boxKey('r1')), _rowHeight + _detailHeight);
      expect(_clip(tester, 'r1'), Clip.none);
      expect(_turns(tester, 'r1'), 0);
    });
  });
}
