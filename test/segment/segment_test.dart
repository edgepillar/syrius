import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/segment.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

enum _Tab { send, receive, zap }

// Three lengths on purpose: a thumb that only moved, or that assumed equal
// widths, would pass with three labels of one length.
const List<SegmentItem<_Tab>> _items = <SegmentItem<_Tab>>[
  SegmentItem<_Tab>(value: _Tab.send, label: 'Send'),
  SegmentItem<_Tab>(value: _Tab.receive, label: 'Receive'),
  SegmentItem<_Tab>(value: _Tab.zap, label: 'Zap'),
];

const String _prefix = 'transfer_tab';

Finder _cell(_Tab tab) => find.byKey(Segment.keyOf(_prefix, tab));

final Finder _thumb = find.byType(SegmentThumb);

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

Color _inkOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

Widget _app(
  Widget child, {
  bool light = false,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
  home: Directionality(
    textDirection: direction,
    child: Scaffold(
      body: Align(alignment: AlignmentDirectional.topStart, child: child),
    ),
  ),
);

/// A page that owns the selection, as a call site does, and counts what the
/// control reports.
class _Page extends StatefulWidget {
  const _Page({this.initial = _Tab.send, this.items = _items});

  final _Tab? initial;
  final List<SegmentItem<_Tab>> items;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  late _Tab? selected = widget.initial;
  final List<_Tab> reported = <_Tab>[];

  @override
  Widget build(BuildContext context) => Segment<_Tab>(
    keyPrefix: _prefix,
    items: widget.items,
    selected: selected,
    onChanged: (_Tab value) => setState(() {
      reported.add(value);
      selected = value;
    }),
  );
}

_PageState _page(WidgetTester tester) =>
    tester.state<_PageState>(find.byType(_Page));

void main() {
  group('Segment', () {
    testWidgets('each segment is keyed by the prefix and the value name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      expect(
        find.byKey(const ValueKey<String>('transfer_tab_send')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('transfer_tab_receive')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('transfer_tab_zap')),
        findsOneWidget,
      );
      // A value that is not an enum is named by its toString.
      expect(Segment.keyOf('lock', 15), const ValueKey<String>('lock_15'));
    });

    testWidgets('segments are as wide as their labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      final double send = _rect(tester, _cell(_Tab.send)).width;
      final double receive = _rect(tester, _cell(_Tab.receive)).width;
      final double zap = _rect(tester, _cell(_Tab.zap)).width;
      expect(receive, greaterThan(send));
      expect(send, greaterThan(zap));
      // The same padding round each: the widths differ by the labels alone.
      expect(
        receive - send,
        tester.getSize(find.text('Receive')).width -
            tester.getSize(find.text('Send')).width,
      );
    });

    testWidgets('a tap selects and calls onChanged once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      await tester.tap(_cell(_Tab.receive));
      await tester.pumpAndSettle();
      expect(_page(tester).reported, <_Tab>[_Tab.receive]);
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.receive)));

      // The value already in effect is not reported again.
      await tester.tap(_cell(_Tab.receive));
      await tester.pumpAndSettle();
      expect(_page(tester).reported, <_Tab>[_Tab.receive]);
    });

    testWidgets('the thumb is one widget from start to finish', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      expect(_thumb, findsOneWidget);
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.send)));
      final Element element = tester.element(_thumb);
      final RenderObject box = tester.renderObject(_thumb);

      await tester.tap(_cell(_Tab.zap));
      await tester.pump();
      for (int ms = 0; ms < 360; ms += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_thumb, findsOneWidget);
        expect(tester.element(_thumb), same(element));
        expect(tester.renderObject(_thumb), same(box));
      }
      await tester.pumpAndSettle();
      expect(tester.element(_thumb), same(element));
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.zap)));
    });

    testWidgets('mid-slide the thumb is between the two, in place and size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      final Rect from = _rect(tester, _cell(_Tab.send));
      final Rect to = _rect(tester, _cell(_Tab.receive));

      await tester.tap(_cell(_Tab.receive));
      await tester.pump();
      // The curve is symmetric, so half the time is half the way.
      await tester.pump(const Duration(milliseconds: 180));
      final Rect mid = _rect(tester, _thumb);
      expect(mid.left, moreOrLessEquals((from.left + to.left) / 2));
      expect(mid.width, moreOrLessEquals((from.width + to.width) / 2));
      expect(mid.top, from.top);
      expect(mid.height, from.height);

      // The labels cross with it: neither at rest, both on the way.
      final Color sendMid = _inkOf(tester, 'Send');
      final Color receiveMid = _inkOf(tester, 'Receive');
      expect(sendMid, receiveMid);

      // And it is not done early: 360 ms, not the twentieth of it that the
      // SDK plays under reduced motion.
      await tester.pump(const Duration(milliseconds: 170));
      expect(_rect(tester, _thumb), isNot(to));
      await tester.pump(const Duration(milliseconds: 10));
      expect(_rect(tester, _thumb), to);
      // And it rests there: settling would time out on a ticker left on.
      await tester.pumpAndSettle();
      expect(_rect(tester, _thumb), to);
    });

    testWidgets('the slide keeps its length under reduced motion', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(const _Page()));
      final Rect to = _rect(tester, _cell(_Tab.receive));
      await tester.tap(_cell(_Tab.receive));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(_rect(tester, _thumb), isNot(to));
      expect(_rect(tester, _thumb), isNot(_rect(tester, _cell(_Tab.send))));
      await tester.pumpAndSettle();
      expect(_rect(tester, _thumb), to);
    });

    testWidgets('the label colour follows the thumb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      final Color lit = _inkOf(tester, 'Send');
      final Color dim = _inkOf(tester, 'Zap');
      expect(lit, isNot(dim));
      expect(_inkOf(tester, 'Receive'), dim);

      await tester.tap(_cell(_Tab.zap));
      await tester.pumpAndSettle();
      expect(_inkOf(tester, 'Zap'), lit);
      expect(_inkOf(tester, 'Send'), dim);
    });

    testWidgets('a pick made mid-slide sets off from where the thumb is', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      await tester.tap(_cell(_Tab.zap));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final Rect mid = _rect(tester, _thumb);

      await tester.tap(_cell(_Tab.send));
      await tester.pump();
      expect(_rect(tester, _thumb), mid);
      await tester.pumpAndSettle();
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.send)));
    });

    testWidgets('arrow keys move the selection and stop at the ends', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      // One stop for the whole control.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        Focus.of(tester.element(_cell(_Tab.send))).hasPrimaryFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.receive);
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.receive)));

      // A frame between the two: the control holds no selection, so a second
      // press before the page has rebuilt it asks for the same step again.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.zap);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.receive);
      // Nothing for the press against the end.
      expect(_page(tester).reported, <_Tab>[
        _Tab.receive,
        _Tab.zap,
        _Tab.receive,
      ]);
      // The arrows did not walk the focus away.
      expect(
        Focus.of(tester.element(_cell(_Tab.send))).hasPrimaryFocus,
        isTrue,
      );
    });

    testWidgets('the keyboard focus draws a ring, the pointer does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      final Color ring = AppTokens.dark.focusRing;
      bool ringed() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(Segment<_Tab>),
              matching: find.byType(DecoratedBox),
            ),
          )
          .any((DecoratedBox box) {
            final Decoration decoration = box.decoration;
            return decoration is ShapeDecoration &&
                decoration.shape is StadiumBorder &&
                (decoration.shape as StadiumBorder).side.color == ring &&
                (decoration.shape as StadiumBorder).side.style ==
                    BorderStyle.solid &&
                box.position == DecorationPosition.foreground;
          });

      expect(ringed(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ringed(), isTrue);
      // The ring is drawn over the track: taking the focus moves nothing.
      final Size focused = tester.getSize(find.byType(Segment<_Tab>));
      await tester.tap(_cell(_Tab.zap));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Segment<_Tab>)), focused);
    });

    testWidgets('right to left mirrors the order and the arrows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(const _Page(), direction: TextDirection.rtl),
      );
      final Rect send = _rect(tester, _cell(_Tab.send));
      final Rect receive = _rect(tester, _cell(_Tab.receive));
      final Rect zap = _rect(tester, _cell(_Tab.zap));
      expect(send.left, greaterThan(receive.left));
      expect(receive.left, greaterThan(zap.left));
      expect(send.left, receive.right);
      // At the start, which is the right side.
      final Rect whole = _rect(tester, find.byType(Segment<_Tab>));
      expect(whole.right, tester.getSize(find.byType(Scaffold)).width);
      expect(_rect(tester, _thumb), send);

      // Left is forward here.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.send);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.receive);
      expect(_rect(tester, _thumb), receive);
    });

    testWidgets('a new selected value from outside animates', (
      WidgetTester tester,
    ) async {
      Widget build(_Tab selected) => _app(
        Segment<_Tab>(
          keyPrefix: _prefix,
          items: _items,
          selected: selected,
          onChanged: (_Tab _) => fail('nothing was picked'),
        ),
      );
      await tester.pumpWidget(build(_Tab.send));
      final Rect from = _rect(tester, _cell(_Tab.send));
      final Rect to = _rect(tester, _cell(_Tab.zap));
      final Element element = tester.element(_thumb);

      await tester.pumpWidget(build(_Tab.zap));
      // Not a jump: it sets off from the old segment.
      expect(_rect(tester, _thumb), from);
      await tester.pump(const Duration(milliseconds: 180));
      final Rect mid = _rect(tester, _thumb);
      expect(mid.left, greaterThan(from.left));
      expect(mid.left, lessThan(to.left));
      await tester.pumpAndSettle();
      expect(_rect(tester, _thumb), to);
      expect(tester.element(_thumb), same(element));
    });

    testWidgets('with nothing selected the thumb is closed, then opens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page(initial: null)));
      expect(_thumb, findsOneWidget);
      expect(tester.getSize(_thumb).width, 0);
      expect(_inkOf(tester, 'Send'), _inkOf(tester, 'Zap'));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_page(tester).selected, _Tab.send);
      expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.send)));
    });

    testWidgets('each segment is a button that says whether it is selected', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Page()));
      expect(
        tester.getSemantics(_cell(_Tab.send)),
        isSemantics(
          label: 'Send',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(_cell(_Tab.zap)),
        isSemantics(
          label: 'Zap',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      // A screen reader's tap is a pick like any other.
      tester.semantics.tap(find.semantics.byLabel('Zap'));
      await tester.pumpAndSettle();
      expect(_page(tester).reported, <_Tab>[_Tab.zap]);
      expect(
        tester.getSemantics(_cell(_Tab.zap)),
        isSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('hover tints a segment that is not selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(const _Page()));
      Color? tintOf(_Tab tab) =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: _cell(tab),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as ShapeDecoration)
              .color;

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_cell(_Tab.zap)));
      await tester.pump();
      expect(tintOf(_Tab.zap), AppTokens.dark.hover);
      expect(tintOf(_Tab.receive), isNull);

      await mouse.moveTo(tester.getCenter(_cell(_Tab.send)));
      await tester.pump();
      expect(tintOf(_Tab.zap), isNull);
      expect(tintOf(_Tab.send), isNull);
    });

    testWidgets('a leading icon takes the label colour', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const _Page(
            items: <SegmentItem<_Tab>>[
              SegmentItem<_Tab>(
                value: _Tab.send,
                label: 'Send',
                icon: Icons.north_east,
              ),
              SegmentItem<_Tab>(
                value: _Tab.receive,
                label: 'Receive',
                icon: Icons.south_west,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final Icon lit = tester.widget<Icon>(find.byIcon(Icons.north_east));
      final Icon dim = tester.widget<Icon>(find.byIcon(Icons.south_west));
      expect(lit.color, isNot(dim.color));
      // Before the label: to its left here.
      expect(
        tester.getCenter(find.byIcon(Icons.north_east)).dx,
        lessThan(tester.getCenter(_cell(_Tab.send)).dx),
      );

      await tester.tap(_cell(_Tab.receive));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Icon>(find.byIcon(Icons.south_west)).color,
        lit.color,
      );
    });

    for (final bool light in <bool>[false, true]) {
      for (final TextDirection direction in TextDirection.values) {
        testWidgets(
          'fits a narrow width, ${light ? 'light' : 'dark'}, '
          '${direction.name}',
          (WidgetTester tester) async {
            await tester.pumpWidget(
              _app(
                const SizedBox(width: 120, child: _Page()),
                light: light,
                direction: direction,
              ),
            );
            expect(tester.takeException(), isNull);
            final Rect whole = _rect(tester, find.byType(Segment<_Tab>));
            expect(whole.width, lessThanOrEqualTo(120));
            for (final _Tab tab in _Tab.values) {
              final Rect cell = _rect(tester, _cell(tab));
              expect(cell.left, greaterThanOrEqualTo(whole.left));
              expect(cell.right, lessThanOrEqualTo(whole.right));
            }

            // The thumb still lands on its segment, and a slide at this
            // width overflows no more than rest does.
            await tester.tap(_cell(_Tab.zap));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 180));
            expect(tester.takeException(), isNull);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(_rect(tester, _thumb), _rect(tester, _cell(_Tab.zap)));
          },
        );
      }
    }

    testWidgets('the colours are the theme in use', (
      WidgetTester tester,
    ) async {
      for (final bool light in <bool>[false, true]) {
        final ThemeData theme = light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        await tester.pumpWidget(_app(const _Page(), light: light));
        await tester.pumpAndSettle();
        expect(_inkOf(tester, 'Send'), theme.textTheme.bodyMedium!.color);
        expect(_inkOf(tester, 'Zap'), theme.textTheme.titleMedium!.color);
        expect(
          tester.widget<Text>(find.text('Send')).style!.fontFamily,
          theme.textTheme.bodyMedium!.fontFamily,
          reason: 'the face is the one the theme gives',
        );
        final ShapeDecoration thumb =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: _thumb,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(thumb.color, isNot(theme.colorScheme.primaryContainer));
        expect(
          (thumb.shape as StadiumBorder).side.color,
          theme.dividerTheme.color,
        );
      }
    });
  });
}
