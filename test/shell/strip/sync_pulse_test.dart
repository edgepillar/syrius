import 'package:flutter/rendering.dart' show PictureLayer, RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/cubits/timer_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/pair.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/strip/status_dot.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/strip/sync.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

Widget _app(Widget child, {bool dark = true, bool disabled = false}) =>
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: Center(child: child),
        ),
      ),
    );

Finder get _haloBoundary => find.descendant(
  of: find.byType(StatusDot),
  matching: find.byType(RepaintBoundary),
);

({double radius, Color color})? _halo(WidgetTester tester) {
  final Finder dot = find.byType(StatusDot);
  final Opacity opacity = tester.widget<Opacity>(
    find.descendant(of: dot, matching: find.byType(Opacity)),
  );
  if (opacity.opacity == 0) return null;
  final Transform scale = tester.widget<Transform>(
    find.descendant(of: dot, matching: find.byType(Transform)),
  );
  expect(scale.alignment, Alignment.center);
  final DecoratedBox circle = tester.widget<DecoratedBox>(
    find.descendant(of: _haloBoundary, matching: find.byType(DecoratedBox)),
  );
  final BoxDecoration decoration = circle.decoration as BoxDecoration;
  expect(decoration.shape, BoxShape.circle);
  return (
    radius: tester.getSize(_haloBoundary).shortestSide / 2 *
        scale.transform.entry(0, 0),
    color: decoration.color!.withValues(alpha: opacity.opacity),
  );
}

NodeSyncStatusState _state({
  int current = 100,
  int target = 100,
  SyncState actual = SyncState.syncDone,
  SyncState remembered = SyncState.syncDone,
}) => NodeSyncStatusState(
  status: TimerStatus.success,
  data: Pair<SyncState, SyncInfo>(
    remembered,
    SyncInfo.fromJson(<String, dynamic>{
      'state': actual.index,
      'currentHeight': current,
      'targetHeight': target,
    }),
  ),
);

void main() {
  for (final bool disabled in <bool>[false, true]) {
    testWidgets(
      'CSS pulse keeps 2.4 seconds with OS animations disabled=$disabled',
      (WidgetTester tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: disabled);
        try {
          await tester.pumpWidget(
            _app(StatusDot(color: AppTokens.dark.znn), disabled: disabled),
          );
          await tester.pump();
          final RenderRepaintBoundary halo =
              tester.renderObject<RenderRepaintBoundary>(_haloBoundary);
          final PictureLayer originalPaint =
              halo.debugLayer!.firstChild! as PictureLayer;
          final Object? originalPicture = originalPaint.picture;
          expect(originalPicture, isNotNull);
          final Element dot = tester.element(find.byType(StatusDot));
          expect(StatusDot.haloPhaseOf(dot), 0);
          expect(tester.getSize(_haloBoundary), const Size.square(22));
          expect(_halo(tester)!.radius, 4);
          expect(_halo(tester)!.color.a, closeTo(0.6, 0.001));
          expect(
            find.descendant(
              of: find.byType(StatusDot),
              matching: find.byType(RepaintBoundary),
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 840));
          const Curve cssEase = Cubic(0.4, 0, 0.2, 1);
          final double halfway = cssEase.transform(0.5);
          expect(StatusDot.haloPhaseOf(dot), closeTo(0.5, 0.001));
          final PictureLayer halfwayPaint =
              halo.debugLayer!.firstChild! as PictureLayer;
          expect(halfwayPaint.picture, same(originalPicture));
          expect(_halo(tester)!.radius, closeTo(4 + 7 * halfway, 0.001));
          expect(_halo(tester)!.color.a, closeTo(0.6 * (1 - halfway), 0.001));
          expect(tester.binding.transientCallbackCount, greaterThan(0));
          await tester.pump(const Duration(milliseconds: 840));
          expect(_halo(tester), isNull);
          expect(StatusDot.haloPhaseOf(dot), 1);
          expect(tester.binding.transientCallbackCount, 0);
          await tester.pump(const Duration(milliseconds: 420));
          expect(_halo(tester), isNull);
          expect(tester.binding.transientCallbackCount, 0);
          await tester.pump(const Duration(milliseconds: 300));
          expect(_halo(tester)!.radius, closeTo(4, 0.001));
          expect(StatusDot.haloPhaseOf(dot), 0);
          expect(_halo(tester)!.color.a, closeTo(0.6, 0.001));
          expect(tester.binding.transientCallbackCount, greaterThan(0));
          // Unmount with the next cycle's wake-up still pending.
          await tester.pump(const Duration(milliseconds: 1680));
          expect(tester.binding.transientCallbackCount, 0);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        }
      },
    );
  }

  testWidgets(
    'changing status color preserves the phase and solid dot geometry',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(StatusDot(color: AppTokens.dark.znn, fillKey: const Key('fill'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 840));
      final ({double radius, Color color}) before = _halo(tester)!;
      await tester.pumpWidget(
        _app(StatusDot(color: AppTokens.dark.qsr, fillKey: const Key('fill'))),
      );
      expect(_halo(tester)!.radius, closeTo(before.radius, 0.001));
      expect(_halo(tester)!.color, before.color);
      expect(tester.getSize(find.byKey(const Key('fill'))), const Size(8, 8));
      expect(
        (tester
                    .widget<AnimatedContainer>(find.byKey(const Key('fill')))
                    .decoration!
                as BoxDecoration)
            .color,
        AppTokens.dark.qsr,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final bool dark in <bool>[true, false]) {
    testWidgets(
      'sync color follows current node state in ${dark ? 'dark' : 'light'}',
      (WidgetTester tester) async {
        final AppTokens tokens = dark ? AppTokens.dark : AppTokens.light;
        Future<Color> show(NodeSyncStatusState state) async {
          await tester.pumpWidget(_app(SyncDot(state: state), dark: dark));
          return (tester
                      .widget<AnimatedContainer>(
                        find.byKey(const Key('strip_sync')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;
        }

        expect(await show(_state()), tokens.znn);
        expect(
          await show(_state(current: 97, actual: SyncState.syncing)),
          tokens.warn,
        );
        expect(
          await show(_state(current: 98, actual: SyncState.syncing)),
          tokens.znn,
        );
        expect(
          await show(_state(current: 0, target: 0, actual: SyncState.unknown)),
          tokens.warn,
        );
        expect(
          await show(
            NodeSyncStatusState(
              status: TimerStatus.failure,
              error: FailureException(message: 'Node unavailable'),
            ),
          ),
          tokens.error,
        );
        expect(await show(const NodeSyncStatusState()), tokens.warn);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the localized sync state is accessible without color alone', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(SyncDot(state: _state(current: 80, actual: SyncState.syncing))),
      );
      expect(
        find.semantics.byLabel('Syncing, momentum 80 of 100'),
        findsOneWidget,
      );
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Syncing, momentum 80 of 100',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    }
  });
}
