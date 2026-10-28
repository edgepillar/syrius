import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/lock_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/tab_children_widgets/lock_tab_child.dart';

import '../../harness/app/agent.dart';
import '../../harness/lock_view_observation.dart';

class _PendingFilmBundle extends CachingAssetBundle {
  final Completer<ByteData> bytes = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) => bytes.future;
}

Widget _host(ValueNotifier<int> mode) => MaterialApp(
  locale: const Locale('en'),
  theme: AppTheme.darkTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: Scaffold(
    body: DefaultAssetBundle(
      bundle: _PendingFilmBundle(),
      child: ValueListenableBuilder<int>(
        valueListenable: mode,
        builder: (_, int value, _) => Focus(
          descendantsAreFocusable: value != 1,
          child: TickerMode(
            enabled: value != 2,
            child: LockTabChild(
              (_) async => throw StateError('Unlock must not run'),
              () => throw StateError('Initialization must not run'),
              key: ValueKey<int>(value >= 3 ? value : 0),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<Map<String, Object?>> _read(HarnessAgent agent, String action) async {
  final Map<String, Object?> value = await agent.commandForTest(
    <String, dynamic>{'cmd': 'lock-view', 'action': action},
  );
  expect(projectLockView(value), value);
  return value;
}

void main() {
  const MethodChannel window = MethodChannel('window_manager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, (MethodCall _) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, null);
  });

  testWidgets('passive lock reads keep input and observe original view guards',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final String? originalPath = kWalletPath;
    kWalletPath = 'synthetic-private-directory/qualification.wallet';
    final ValueNotifier<int> mode = ValueNotifier<int>(0);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      kWalletPath = originalPath;
      mode.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(_host(mode));
    await tester.pump();
    final State<StatefulWidget> original = tester.state(
      find.byType(LockTabChild),
    );
    final TextEditingController password =
        tester.widget<LockCard>(find.byType(LockCard)).passwordController;
    password.text = 'synthetic-private-password';
    final HarnessAgent agent = HarnessAgent.forTest();
    final Map<String, Object?> bound = await _read(agent, 'bind');
    expect(bound['owner_same'], isTrue);
    Map<String, Object?> view =
        Map<String, Object?>.from(bound['view']! as Map);
    expect(view['current'], isTrue);
    expect(view['busy'], isFalse);
    expect(view['password_failures'], 0);
    final bool frameBefore = tester.binding.hasScheduledFrame;
    for (int i = 0; i < 3; i++) {
      final Map<String, Object?> read = await _read(agent, 'observe');
      expect(read, bound);
      expect(jsonEncode(read), isNot(contains('synthetic-private')));
      expect(password.text, 'synthetic-private-password');
      expect(tester.binding.hasScheduledFrame, frameBefore);
    }
    for (final int value in <int>[1, 2, 0]) {
      mode.value = value;
      await tester.pump();
      view = Map<String, Object?>.from(
        (await _read(agent, 'observe'))['view']! as Map,
      );
      expect(view['focus_allows_input'], value != 1);
      expect(view['visible'], value != 2);
      expect(view['current'], value == 0);
      expect(tester.state(find.byType(LockTabChild)), same(original));
      expect(password.text, 'synthetic-private-password');
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    view = Map<String, Object?>.from(
      (await _read(agent, 'observe'))['view']! as Map,
    );
    expect(view['window_active'], isFalse);
    expect(view['current'], isFalse);
    expect(view['lifecycle'], 'inactive');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    view = Map<String, Object?>.from(
      (await _read(agent, 'observe'))['view']! as Map,
    );
    expect(view['current'], isTrue);
    expect(password.text, 'synthetic-private-password');
  });

  testWidgets('lock observation never adopts a replacement owner',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ValueNotifier<int> mode = ValueNotifier<int>(0);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      mode.dispose();
    });
    await tester.pumpWidget(_host(mode));
    await tester.pump();
    final HarnessAgent agent = HarnessAgent.forTest();
    expect((await _read(agent, 'bind'))['status'], 'observed');
    mode.value = 3;
    await tester.pump();
    expect(await _read(agent, 'observe'), <String, Object?>{
      'schema': 1, 'status': 'replaced', 'owner_same': false, 'view': null,
    });
    mode.value = 0;
    await tester.pump();
    expect((await _read(agent, 'observe'))['status'], 'retired');
    expect((await _read(agent, 'bind'))['status'], 'retired');
  });
}
