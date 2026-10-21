import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/skeleton.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';

// The sweep's numbers, written out again and not shared with skeleton.dart:
// a change of tuning there has to be made here as well, on purpose.

/// Logical pixels a millisecond: 1,200 px in 1.4 s.
const double _speed = 1200 / 1400;

/// The band, edge to edge.
const double _band = 240;

/// The test surface, in logical pixels.
const int _surfaceWidth = 800;

/// Where the middle of the first band is in the window, [ms] after the
/// clock started, reading left to right. It sets off from just outside the
/// left edge.
double _centreAt(int ms) => _speed * ms - _band / 2;

final GlobalKey _surface = GlobalKey();

/// A page in one of the app's two themes, on the colour of a card, as one
/// layer the test can read back.
Widget _host(
  Widget child, {
  bool light = false,
  TextDirection direction = TextDirection.ltr,
}) {
  final ThemeData theme = light ? AppTheme.lightTheme : AppTheme.darkTheme;
  return Theme(
    data: theme,
    child: Directionality(
      textDirection: direction,
      child: RepaintBoundary(
        key: _surface,
        child: ColoredBox(
          color: theme.colorScheme.primary,
          child: Align(alignment: AlignmentDirectional.topStart, child: child),
        ),
      ),
    ),
  );
}

/// One bar at each of [places], in window coordinates.
Widget _bars(List<Rect> places, {double radius = 4}) => Stack(
  children: <Widget>[
    for (final Rect place in places)
      Positioned.fromRect(
        rect: place,
        child: Skeleton(radius: radius),
      ),
  ],
);

/// The frame on screen, one pixel to the logical pixel, as RGBA bytes.
Future<ByteData> _frame(WidgetTester tester) async {
  final RenderRepaintBoundary surface = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_surface));
  final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await surface.toImage();
    final ByteData? data = await image.toByteData();
    image.dispose();
    return data;
  });
  return bytes!;
}

/// What one bar shows in a frame.
class _Light {
  _Light(this.rest, this.peak, this.centre);

  /// The bar's own colour, as red plus green plus blue.
  final int rest;

  /// The lightest pixel on the bar, the same way.
  final int peak;

  /// The middle of the band from the bar's left edge, or null when no band
  /// is on it.
  final double? centre;
}

/// Reads the pixels along the middle line of the bar at [place].
///
/// The bar's own colour is the commonest value on the line. The band is
/// what stands clear of it, and its middle is the centroid of that: the
/// band is symmetric, so cutting off its faint edges does not move it.
_Light _read(ByteData frame, Rect place) {
  final int y = place.center.dy.floor();
  final List<int> line = <int>[
    for (int x = place.left.round(); x < place.right.round(); x++)
      frame.getUint8((y * _surfaceWidth + x) * 4) +
          frame.getUint8((y * _surfaceWidth + x) * 4 + 1) +
          frame.getUint8((y * _surfaceWidth + x) * 4 + 2),
  ];
  final Map<int, int> seen = <int, int>{};
  for (final int value in line) {
    seen[value] = (seen[value] ?? 0) + 1;
  }
  int rest = line.first;
  int peak = line.first;
  for (final int value in seen.keys) {
    if (seen[value]! > seen[rest]!) rest = value;
    if (value > peak) peak = value;
  }
  double weight = 0;
  double moment = 0;
  for (int i = 0; i < line.length; i++) {
    final int lift = line[i] - rest;
    if (lift > 6) {
      weight += lift;
      moment += lift * (i + 0.5);
    }
  }
  return _Light(rest, peak, weight == 0 ? null : moment / weight);
}

/// Counts how often what is around the bars is painted.
class _PaintCount extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_PaintCount old) => false;
}

void main() {
  group('Skeleton layout', () {
    testWidgets('a bar takes the width and height it is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const Skeleton(width: 72)));
      expect(tester.getSize(find.byType(Skeleton)), const Size(72, 12));

      await tester.pumpWidget(
        _host(const Skeleton(width: 96, height: 40, radius: 8)),
      );
      expect(tester.getSize(find.byType(Skeleton)), const Size(96, 40));
    });

    testWidgets('without a width it fills a bounded one', (
      WidgetTester tester,
    ) async {
      // Loose constraints, as under the Center one caller puts it in.
      await tester.pumpWidget(
        _host(const SizedBox(width: 300, child: Center(child: Skeleton()))),
      );
      expect(tester.getSize(find.byType(Skeleton)), const Size(300, 12));
    });

    testWidgets('without a width it has none in an unbounded one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[Skeleton()],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Skeleton)), const Size(0, 12));
    });

    testWidgets('rows keep their count, size and gap; the last is shorter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 200, child: SkeletonRows(rows: 4, gap: 18)),
        ),
      );
      final Finder bars = find.byType(Skeleton);
      expect(bars, findsNWidgets(4));
      for (int i = 0; i < 4; i++) {
        expect(
          tester.getRect(bars.at(i)),
          Rect.fromLTWH(0, i * 30, i == 3 ? 120 : 200, 12),
        );
      }
      expect(tester.getSize(find.byType(SkeletonRows)), const Size(200, 102));
    });

    testWidgets('the default is three rows, 14 apart', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 200, child: SkeletonRows())),
      );
      expect(find.byType(Skeleton), findsNWidgets(3));
      expect(tester.getSize(find.byType(SkeletonRows)), const Size(200, 64));
    });

    testWidgets('right to left, the short row starts at the right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 200, child: SkeletonRows()),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getRect(find.byType(Skeleton).last),
        const Rect.fromLTWH(_surfaceWidth - 120, 52, 120, 12),
      );
    });
  });

  group('Skeleton clock', () {
    Widget page(int bars) => _host(
      Column(
        children: <Widget>[
          for (int i = 0; i < bars; i++)
            Skeleton(key: ValueKey<int>(i), width: 100),
        ],
      ),
    );

    testWidgets('one ticker for every bar on the page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              SkeletonRows(rows: 5),
              SkeletonRows(rows: 4),
              Skeleton(width: 72),
            ],
          ),
        ),
      );
      expect(find.byType(Skeleton), findsNWidgets(10));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('runs while a bar is mounted and stops with the last one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(page(0));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(page(2));
      expect(tester.binding.transientCallbackCount, 1);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // One bar leaves; the other still needs the clock.
      await tester.pumpWidget(page(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 1);
      expect(tester.binding.hasScheduledFrame, isTrue);

      // The last one leaves. The frame the ticker had already asked for is
      // drawn, and no other follows.
      await tester.pumpWidget(page(0));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a bar that returns starts the sweep from the edge again', (
      WidgetTester tester,
    ) async {
      const Rect wide = Rect.fromLTWH(0, 100, 800, 12);
      await tester.pumpWidget(_host(_bars(<Rect>[wide])));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(_host(_bars(<Rect>[])));
      await tester.pump(const Duration(seconds: 5));

      await tester.pumpWidget(_host(_bars(<Rect>[wide])));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _read(await _frame(tester), wide).centre,
        moreOrLessEquals(_centreAt(400), epsilon: 2),
      );
    });

    testWidgets('a bar the framework has muted does not hold the clock', (
      WidgetTester tester,
    ) async {
      Widget muted({required bool enabled}) => _host(
        TickerMode(enabled: enabled, child: const Skeleton(width: 100)),
      );
      await tester.pumpWidget(muted(enabled: false));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(muted(enabled: true));
      expect(tester.binding.transientCallbackCount, 1);

      await tester.pumpWidget(muted(enabled: false));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a tick rebuilds nothing and repaints only the bars', (
      WidgetTester tester,
    ) async {
      final _PaintCount around = _PaintCount();
      await tester.pumpWidget(
        _host(CustomPaint(painter: around, child: const SkeletonRows())),
      );
      final Finder bar = find.descendant(
        of: find.byType(Skeleton).first,
        matching: find.byType(CustomPaint),
      );
      final Widget built = tester.widget(bar);
      expect(around.paints, 1);

      int builds = 0;
      debugOnRebuildDirtyWidget = (Element element, bool builtOnce) => builds++;
      try {
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      } finally {
        debugOnRebuildDirtyWidget = null;
      }
      expect(builds, 0);
      // A build would have made a new CustomPaint.
      expect(tester.widget(bar), same(built));
      expect(around.paints, 1);
    });
  });

  group('Skeleton sweep', () {
    /// As wide as the window, so the whole band fits on it.
    const Rect wide = Rect.fromLTWH(0, 100, 800, 12);

    testWidgets('crosses 1,200 px in 1.4 s, then rests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_bars(<Rect>[wide])));
      // Just off the left edge at the start: nothing on the bar yet.
      expect(_read(await _frame(tester), wide).centre, isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _read(await _frame(tester), wide).centre,
        moreOrLessEquals(_centreAt(400), epsilon: 2),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _read(await _frame(tester), wide).centre,
        moreOrLessEquals(_centreAt(800), epsilon: 2),
      );

      // Gone past an 800 px window after 1.22 s; the next sets off at 1.8 s.
      await tester.pump(const Duration(milliseconds: 700));
      final _Light resting = _read(await _frame(tester), wide);
      expect(resting.centre, isNull);
      expect(resting.peak - resting.rest, lessThanOrEqualTo(3));

      await tester.pump(const Duration(milliseconds: 700));
      expect(
        _read(await _frame(tester), wide).centre,
        moreOrLessEquals(_centreAt(400), epsilon: 2),
      );
    });

    testWidgets('two bars show the band at one place in the window', (
      WidgetTester tester,
    ) async {
      const Rect first = Rect.fromLTWH(40, 100, 600, 12);
      const Rect second = Rect.fromLTWH(140, 200, 600, 12);
      await tester.pumpWidget(_host(_bars(<Rect>[first, second])));
      await tester.pump(const Duration(milliseconds: 500));

      final ByteData frame = await _frame(tester);
      final double onFirst = _read(frame, first).centre!;
      final double onSecond = _read(frame, second).centre!;
      // A different place on each bar, by as much as the bars are apart.
      expect(onFirst - onSecond, moreOrLessEquals(100, epsilon: 2));
      // The same place in the window.
      expect(
        first.left + onFirst,
        moreOrLessEquals(second.left + onSecond, epsilon: 2),
      );
      expect(
        first.left + onFirst,
        moreOrLessEquals(_centreAt(500), epsilon: 2),
      );
    });

    testWidgets('a bar further along is lit later', (
      WidgetTester tester,
    ) async {
      const Rect near = Rect.fromLTWH(40, 100, 72, 12);
      const Rect far = Rect.fromLTWH(640, 100, 72, 12);
      await tester.pumpWidget(_host(_bars(<Rect>[near, far])));

      // The band's middle is at 76, the middle of the near bar.
      await tester.pump(const Duration(milliseconds: 229));
      ByteData frame = await _frame(tester);
      expect(_read(frame, near).peak, greaterThan(_read(frame, far).peak));

      // 700 ms on it has moved 600 px, to the middle of the far one.
      await tester.pump(const Duration(milliseconds: 700));
      frame = await _frame(tester);
      expect(_read(frame, far).peak, greaterThan(_read(frame, near).peak));
    });

    testWidgets('moves left to right', (WidgetTester tester) async {
      await tester.pumpWidget(_host(_bars(<Rect>[wide])));
      await tester.pump(const Duration(milliseconds: 870));
      final double before = _read(await _frame(tester), wide).centre!;
      await tester.pump(const Duration(milliseconds: 60));
      final double after = _read(await _frame(tester), wide).centre!;
      expect(after - before, moreOrLessEquals(_speed * 60, epsilon: 2));
    });

    testWidgets('moves right to left when the text does', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(_bars(<Rect>[wide]), direction: TextDirection.rtl),
      );
      // The instants of the test above. The wave is the same one mirrored,
      // so the band is on the bar at both of them here as well.
      await tester.pump(const Duration(milliseconds: 870));
      final double before = _read(await _frame(tester), wide).centre!;
      await tester.pump(const Duration(milliseconds: 60));
      final double after = _read(await _frame(tester), wide).centre!;
      expect(after - before, moreOrLessEquals(-_speed * 60, epsilon: 2));
    });

    testWidgets('a rebuild of the only bar does not send the band back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(_bars(<Rect>[wide])));
      await tester.pump(const Duration(milliseconds: 400));
      // A new radius: the bar is built again and gets a new painter.
      await tester.pumpWidget(
        _host(_bars(<Rect>[wide], radius: 6)),
        duration: const Duration(milliseconds: 400),
      );
      expect(
        _read(await _frame(tester), wide).centre,
        moreOrLessEquals(_centreAt(800), epsilon: 2),
      );
    });

    for (final bool light in <bool>[false, true]) {
      testWidgets(
        'the ${light ? 'light' : 'dark'} theme shows a band a little '
        'lighter than the bar',
        (WidgetTester tester) async {
          await tester.pumpWidget(_host(_bars(<Rect>[wide]), light: light));
          await tester.pump(const Duration(milliseconds: 500));
          final _Light read = _read(await _frame(tester), wide);
          expect(read.centre, isNotNull);
          // Per channel: more than 6 of 255, so it can be seen, and less
          // than 25, so it is not a flash.
          expect(read.peak - read.rest, greaterThan(3 * 6));
          expect(read.peak - read.rest, lessThan(3 * 25));
        },
      );
    }
  });
}
