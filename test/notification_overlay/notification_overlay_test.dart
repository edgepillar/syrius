import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

const Key _pageKey = Key('page');
const Key _areaKey = Key('page_area');

/// The bar on a floating banner that fills as its time runs.
const Key _barKey = ValueKey<String>('notification_dismiss_bar');

/// The shell's layout in small: a 200 px rail, then the page area with the
/// floating banner over it.
Widget _host({
  Widget page = const SizedBox.expand(key: _pageKey),
  TextDirection textDirection = TextDirection.ltr,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: ThemeData.dark(),
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations:
          reduceMotion || MediaQuery.of(context).disableAnimations,
    ),
    child: Directionality(textDirection: textDirection, child: child!),
  ),
  home: Scaffold(
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(width: 200),
        Expanded(
          key: _areaKey,
          child: NotificationOverlay(
            banner: NotificationWidget(
              onSeeMorePressed: () {},
              popBeforeSeeMoreIsPressed: false,
              floating: true,
            ),
            child: page,
          ),
        ),
      ],
    ),
  ),
);

/// The banner inline, above the content, as the stepper and the other
/// screens that pass `floating: false` use it.
Widget _inlineHost() => MaterialApp(
  theme: ThemeData.dark(),
  home: const Scaffold(
    body: Column(
      children: <Widget>[
        NotificationWidget(),
        Expanded(child: SizedBox.expand(key: _pageKey)),
      ],
    ),
  ),
);

WalletNotification _notification(
  int timestamp, {
  NotificationType type = NotificationType.paymentSent,
  String title = 'Account-block published',
}) => WalletNotification(
  title: title,
  timestamp: timestamp,
  details: 'details',
  type: type,
);

/// How long a floating banner of [type] stays. Written out here and not
/// read from the widget: these are the owner's numbers.
Duration _timeFor(NotificationType type) => switch (type) {
  NotificationType.error ||
  NotificationType.stakingDeactivated ||
  NotificationType.confirm => const Duration(seconds: 6),
  _ => const Duration(seconds: 3),
};

/// Short of a banner's time by this much it is still up; this much past it,
/// it is not. Never the frame on the time itself: a controller ends on the
/// first frame past its duration, so that frame draws the bar full with the
/// banner still up, and the app never draws one exactly there.
const Duration _aMoment = Duration(milliseconds: 100);

/// Long enough for a banner to have come in, short of any banner's time.
const Duration _entered = Duration(milliseconds: 400);

Finder _banner() => find
    .ancestor(of: find.text('Dismiss'), matching: find.byType(Material))
    .first;

/// What [bar] draws now, in its own coordinates.
///
/// The colour as 8 bits a channel, which is how the theme gives it. A Paint
/// keeps its colour in 32-bit floats, so the Color read back from one is a
/// hair off the Color that went in: the two print alike and are not equal.
({Rect rect, int argb}) _barFill(WidgetTester tester, [Finder? bar]) {
  final List<({Rect rect, int argb})> fills = <({Rect rect, int argb})>[];
  expect(
    bar ?? find.byKey(_barKey),
    paints..something((Symbol method, List<dynamic> arguments) {
      if (method != #drawRect) {
        return false;
      }
      fills.add((
        rect: arguments[0] as Rect,
        argb: (arguments[1] as Paint).color.toARGB32(),
      ));
      return true;
    }),
  );
  return fills.single;
}

/// How far [bar] has filled, from 0 to 1.
double _barValue(WidgetTester tester, [Finder? bar]) {
  final Finder found = bar ?? find.byKey(_barKey);
  return _barFill(tester, found).rect.width / tester.getSize(found).width;
}

class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => false;
}

void main() {
  setUp(() async {
    // A fresh bloc each time: it replays its last notification to a new
    // listener, which would carry one test's banner into the next.
    if (sl.isRegistered<NotificationsBloc>()) {
      await sl.unregister<NotificationsBloc>();
    }
    sl.registerSingleton<NotificationsBloc>(NotificationsBloc());
    kLastNotification = null;
    kLastDismissedNotification = null;
  });

  Future<void> setWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 704);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Sends [notification] and draws the banner's first frame, the one its
  /// count starts on. The bloc delivers on a microtask, so the first pump
  /// only hears of it and the second draws it.
  Future<void> show(
    WidgetTester tester,
    WalletNotification notification,
  ) async {
    sl<NotificationsBloc>().addEvent(notification);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the banner does not move or resize the page', (
    WidgetTester tester,
  ) async {
    await setWindow(tester);
    await tester.pumpWidget(_host());
    final Rect without = tester.getRect(find.byKey(_pageKey));
    expect(find.text('Dismiss'), findsNothing);

    // A notification arrives: the page keeps its place through the
    // animation and after it.
    sl<NotificationsBloc>().addEvent(_notification(1));
    await tester.pump();
    expect(tester.getRect(find.byKey(_pageKey)), without);
    await tester.pump(Durations.short2);
    expect(tester.getRect(find.byKey(_pageKey)), without);
    // Not until it settles: the count runs, and settled is dismissed.
    await tester.pump(_entered);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('See more'), findsOneWidget);
    expect(tester.getRect(find.byKey(_pageKey)), without);

    // Inside the page area, so it never reaches the rail.
    final Rect area = tester.getRect(find.byKey(_areaKey));
    final Rect banner = tester.getRect(_banner());
    expect(banner.left, greaterThan(area.left));
    expect(banner.right, lessThan(area.right));
    expect(banner.top, greaterThan(area.top));

    // Dismissed, it goes and the page still does not move.
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(tester.getRect(find.byKey(_pageKey)), without);
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsNothing);
    expect(kLastDismissedNotification?.timestamp, 1);
    expect(tester.getRect(find.byKey(_pageKey)), without);
  });

  testWidgets('Escape dismisses the banner when focus is in it', (
    WidgetTester tester,
  ) async {
    await setWindow(tester);
    kLastNotification = _notification(2);
    await tester.pumpWidget(_host());
    await tester.pump(_entered);
    expect(find.text('Dismiss'), findsOneWidget);

    // The first Tab puts focus on "See more".
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsNothing);
    expect(kLastDismissedNotification?.timestamp, 2);
  });

  group('floating, the countdown', () {
    testWidgets('dismisses a success banner after 3 s, freeing what it '
        'covered', (WidgetTester tester) async {
      await setWindow(tester);
      int refreshes = 0;
      const Key refresh = Key('refresh');
      // A card's Refresh button, under the banner's title. Under Dismiss,
      // the tap below would press it, and the banner would go by that and
      // not by its count.
      await tester.pumpWidget(
        _host(
          page: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TextButton(
                key: refresh,
                onPressed: () => refreshes++,
                child: const Text('Refresh'),
              ),
            ),
          ),
        ),
      );
      await show(tester, _notification(10));
      await tester.pump(const Duration(seconds: 3) - _aMoment);
      expect(find.text('Dismiss'), findsOneWidget);
      // Covered: the banner takes the click.
      await tester.tap(find.byKey(refresh), warnIfMissed: false);
      expect(refreshes, 0);
      // And does nothing with it.
      final Offset tapped = tester.getCenter(find.byKey(refresh));
      expect(tester.getRect(_banner()).contains(tapped), isTrue);
      expect(kLastDismissedNotification, isNull);

      await tester.pump(_aMoment * 2);
      // The same path as Dismiss, and the exit animation plays.
      expect(kLastDismissedNotification?.timestamp, 10);
      await tester.pump();
      expect(find.text('Dismiss'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);

      await tester.tap(find.byKey(refresh));
      expect(refreshes, 1);
    });

    // Every kind goes, the error and the act-on kinds included: they used
    // to stay until dismissed, and the Notifications list keeps them now.
    for (final NotificationType type in NotificationType.values) {
      final Duration time = _timeFor(type);
      testWidgets('dismisses a ${type.name} banner after '
          '${time.inSeconds} s and not before', (WidgetTester tester) async {
        await setWindow(tester);
        await tester.pumpWidget(_host());
        await show(tester, _notification(20, type: type));

        await tester.pump(time - _aMoment);
        expect(find.text('Dismiss'), findsOneWidget);
        expect(kLastDismissedNotification, isNull);

        await tester.pump(_aMoment * 2);
        expect(kLastDismissedNotification?.timestamp, 20);
        await tester.pumpAndSettle();
        expect(find.text('Dismiss'), findsNothing);
      });
    }

    testWidgets('fills a bar along the top edge as the time runs', (
      WidgetTester tester,
    ) async {
      await setWindow(tester);
      await tester.pumpWidget(_host());
      final WalletNotification shown = _notification(30);
      await show(tester, shown);
      expect(find.byKey(_barKey), findsOneWidget);
      expect(_barValue(tester), 0);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_barValue(tester), 0.5);

      // 2 px along the top edge, inside the banner's 1 px outline.
      final Rect banner = tester.getRect(_banner());
      final Rect bar = tester.getRect(find.byKey(_barKey));
      expect(bar.top, banner.top + 1);
      expect(bar.left, banner.left + 1);
      expect(bar.right, banner.right - 1);
      expect(bar.height, 2);

      // From the left, in the banner's kind colour, with no track.
      final ({Rect rect, int argb}) fill = _barFill(tester);
      expect(fill.rect.left, 0);
      expect(fill.rect.top, 0);
      expect(fill.rect.height, 2);
      expect(fill.argb, shown.getColor().toARGB32());
      expect(find.byKey(_barKey), paintsExactlyCountTimes(#drawRect, 1));
      expect(find.byKey(_barKey), paintsExactlyCountTimes(#drawRRect, 0));

      await tester.pump(const Duration(milliseconds: 1400));
      expect(_barValue(tester), closeTo(2.9 / 3, 1e-9));
      expect(kLastDismissedNotification, isNull);

      // Full on its time, on the frame the banner starts to leave, and
      // while it does.
      await tester.pump(_aMoment);
      expect(_barValue(tester), 1);
      await tester.pump(_aMoment);
      expect(kLastDismissedNotification?.timestamp, 30);
      expect(_barValue(tester), 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_barValue(tester), 1);
    });

    testWidgets('fills from the right when the text runs right to left', (
      WidgetTester tester,
    ) async {
      await setWindow(tester);
      await tester.pumpWidget(_host(textDirection: TextDirection.rtl));
      await show(tester, _notification(31));
      await tester.pump(const Duration(milliseconds: 1500));

      final Rect banner = tester.getRect(_banner());
      final Rect bar = tester.getRect(find.byKey(_barKey));
      expect(bar.left, banner.left + 1);
      expect(bar.right, banner.right - 1);

      final Rect fill = _barFill(tester).rect;
      expect(fill.right, bar.width);
      expect(fill.left, bar.width / 2);
    });

    testWidgets('holds the count and the bar under the pointer, and goes on '
        'from there when it leaves', (WidgetTester tester) async {
      await setWindow(tester);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      // On the page, below the banner.
      const Offset away = Offset(600, 600);
      await mouse.addPointer(location: away);
      addTearDown(mouse.removePointer);
      await tester.pumpWidget(_host());
      await show(tester, _notification(12));

      await tester.pump(const Duration(seconds: 1));
      await mouse.moveTo(tester.getCenter(find.text('Dismiss')));
      await tester.pump();
      final double held = _barValue(tester);
      expect(held, closeTo(1 / 3, 1e-9));
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      expect(_barValue(tester), held);

      await mouse.moveTo(away);
      await tester.pump();
      expect(_barValue(tester), held);
      // Two of the three seconds were left, not three again.
      await tester.pump(const Duration(seconds: 1));
      expect(_barValue(tester), closeTo(2 / 3, 1e-9));
      await tester.pump(const Duration(seconds: 1) - _aMoment);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      await tester.pump(_aMoment * 2);
      expect(kLastDismissedNotification?.timestamp, 12);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('holds while focus is in the banner, and goes on from '
        'there when it leaves', (WidgetTester tester) async {
      await setWindow(tester);
      await tester.pumpWidget(_host());
      await show(tester, _notification(13));

      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final double held = _barValue(tester);
      expect(held, closeTo(1 / 3, 1e-9));
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      expect(_barValue(tester), held);

      // The focus moves on a microtask: one pump to hear of it, one to
      // draw the frame the count goes on from.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_barValue(tester), held);
      await tester.pump(const Duration(seconds: 2) - _aMoment);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      await tester.pump(_aMoment * 2);
      expect(kLastDismissedNotification?.timestamp, 13);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('starts again from zero, with the new kind\'s time, for a '
        'newer banner', (WidgetTester tester) async {
      await setWindow(tester);
      await tester.pumpWidget(_host());
      await show(tester, _notification(14));
      await tester.pump(const Duration(seconds: 2));
      expect(_barValue(tester), closeTo(2 / 3, 1e-9));

      final WalletNotification error = _notification(
        15,
        type: NotificationType.error,
        title: 'Could not send',
      );
      await show(tester, error);
      // Two for a moment: the one going out keeps the bar it had, the one
      // coming in starts empty, in its own colour.
      expect(find.byKey(_barKey), findsNWidgets(2));
      expect(
        _barValue(tester, find.byKey(_barKey).first),
        closeTo(2 / 3, 1e-9),
      );
      expect(_barValue(tester, find.byKey(_barKey).last), 0);
      expect(
        _barFill(tester, find.byKey(_barKey).last).argb,
        error.getColor().toARGB32(),
      );
      expect(error.getColor(), isNot(_notification(14).getColor()));

      // In two steps, so the old banner's exit runs to its end. The second
      // left on the first banner's count has passed, and so have its 3 s:
      // the error has half of its own 6 s.
      await tester.pump(_entered);
      await tester.pump(const Duration(seconds: 3) - _entered);
      expect(find.text('Could not send'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      expect(_barValue(tester), 0.5);

      await tester.pump(const Duration(seconds: 3) - _aMoment);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      await tester.pump(_aMoment * 2);
      expect(kLastDismissedNotification?.timestamp, 15);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('takes its full time when the OS asks for less motion', (
      WidgetTester tester,
    ) async {
      await setWindow(tester);
      // What a controller reads, and what a widget would.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(reduceMotion: true));
      expect(tester.binding.disableAnimations, isTrue);
      expect(
        MediaQuery.of(tester.element(find.byKey(_pageKey))).disableAnimations,
        isTrue,
      );
      await show(tester, _notification(17));

      await tester.pump(const Duration(milliseconds: 1500));
      expect(_barValue(tester), 0.5);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('Dismiss'), findsOneWidget);
      expect(kLastDismissedNotification, isNull);
      await tester.pump(_aMoment * 2);
      expect(kLastDismissedNotification?.timestamp, 17);
    });

    testWidgets('leaves at its time when it was dismissed from elsewhere', (
      WidgetTester tester,
    ) async {
      await setWindow(tester);
      int dismissals = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: NotificationOverlay(
              banner: NotificationWidget(
                onDismissPressed: () => dismissals++,
                floating: true,
              ),
              child: const SizedBox.expand(key: _pageKey),
            ),
          ),
        ),
      );
      await show(tester, _notification(19));
      await tester.pump(const Duration(seconds: 1));

      // As Dismiss does on the inline banner of a screen over this one,
      // and as resetting the wallet does: this banner is not told.
      kLastDismissedNotification = kLastNotification;
      await tester.pump(const Duration(seconds: 2) - _aMoment);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.pump(_aMoment * 2);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);
      // Not this banner's dismissal to announce.
      expect(dismissals, 0);
    });

    testWidgets('repaints the bar alone, not the banner or the page under '
        'it', (WidgetTester tester) async {
      await setWindow(tester);
      int pagePaints = 0;
      await tester.pumpWidget(
        _host(
          page: CustomPaint(
            key: _pageKey,
            painter: _CountingPainter(() => pagePaints++),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await show(tester, _notification(18));
      await tester.pump(_entered);

      // The bar's own layer, and nothing else in it.
      final RenderRepaintBoundary layer = tester.renderObject(
        find
            .ancestor(
              of: find.byKey(_barKey),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      expect(layer.size, tester.getSize(find.byKey(_barKey)));

      layer.debugResetMetrics();
      final int before = pagePaints;
      final double from = _barValue(tester);
      for (int frame = 0; frame < 10; frame++) {
        await tester.pump(_aMoment);
      }
      expect(_barValue(tester), greaterThan(from));
      // Painted on each frame without what holds it, never with it.
      expect(layer.debugAsymmetricPaintCount, 10);
      expect(layer.debugSymmetricPaintCount, 0);
      expect(pagePaints, before);
    });
  });

  testWidgets('inline, a banner stays and has no bar', (
    WidgetTester tester,
  ) async {
    await setWindow(tester);
    kLastNotification = _notification(16);
    await tester.pumpWidget(_inlineHost());
    expect(find.byKey(_barKey), findsNothing);
    await tester.pump(const Duration(seconds: 60));
    // Nothing counts, so it settles with the banner up.
    await tester.pumpAndSettle();
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.byKey(_barKey), findsNothing);
    expect(kLastDismissedNotification, isNull);
  });
}
