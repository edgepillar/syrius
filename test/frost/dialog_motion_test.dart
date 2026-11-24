import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/dialogs.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/frosted_route.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/window_frame.dart';

double _rise(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(of: find.byType(RiseIn), matching: find.byType(Transform))
          .first,
    )
    .transform
    .storage[13];

void main() {
  testWidgets('caption frost centres custom dialogs in the full client area', (
    WidgetTester tester,
  ) async {
    const MethodChannel channel = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(channel, (MethodCall call) async {
            return switch (call.method) {
              'isFullScreen' || 'isMaximized' => false,
              _ => null,
            };
          });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    tester.view
      ..physicalSize = const Size(1280, 780)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const Key probe = Key('client_centred_dialog');
    final foundation.TargetPlatform? platform =
        foundation.debugDefaultTargetPlatformOverride;
    foundation.debugDefaultTargetPlatformOverride =
        foundation.TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, Widget? child) => AppWindowFrame(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showCustomDialog(
                  context: context,
                  clipContent: false,
                  frostWindowCaption: true,
                  content: const SizedBox(key: probe, width: 480, height: 540),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    } finally {
      foundation.debugDefaultTargetPlatformOverride = platform;
    }
    expect(
      find.byKey(const ValueKey<String>('window-caption')),
      findsOneWidget,
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final Finder frost = find.byKey(
      const ValueKey<String>('window-caption-frost'),
    );
    final Color tint = tester.widget<ColoredBox>(frost).color;
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.widget<ColoredBox>(frost).color.a, greaterThan(tint.a));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(probe)), const Offset(640, 390));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(FrostHold.count.value, 0);
  });

  for (final bool platform in <bool>[false, true]) {
    for (final bool mediaQuery in <bool>[false, true]) {
      if (!platform && !mediaQuery) continue;
      testWidgets(
        'frost and rise retain their clocks, platform $platform, '
        'MediaQuery $mediaQuery',
        (WidgetTester tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: platform);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (BuildContext context, Widget? child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: mediaQuery,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) => TextButton(
                    onPressed: () => showFrostedDialog<void>(
                      context: context,
                      builder: (BuildContext context) => const DialogCard(
                        title: 'Send',
                        body: Text('Send 1 ZNN?'),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pump();
          final ModalRoute<dynamic> route = ModalRoute.of(
            tester.element(find.text('Send 1 ZNN?')),
          )!;
          expect(route.animation!.value, 0);
          expect(_rise(tester), 6);

          await tester.pump(const Duration(milliseconds: 75));
          expect(route.animation!.value, closeTo(0.5, 1e-9));
          expect(
            _rise(tester),
            closeTo(6 * (1 - AppTokens.dark.spring.transform(75 / 240)), 1e-6),
          );
          await tester.pump(const Duration(milliseconds: 75));
          expect(route.animation!.value, 1);
          expect(_rise(tester), greaterThan(0));
          await tester.pump(const Duration(milliseconds: 89));
          expect(_rise(tester), greaterThan(0));
          await tester.pump(const Duration(milliseconds: 1));
          expect(_rise(tester), 0);

          Navigator.of(tester.element(find.text('Send 1 ZNN?'))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 75));
          expect(route.animation!.value, closeTo(0.5, 1e-9));
          expect(find.byType(FrostedBarrier), findsOneWidget);
          await tester.pumpAndSettle();
          expect(find.byType(FrostedBarrier), findsNothing);
          expect(FrostHold.count.value, 0);
        },
      );
    }
  }
}
