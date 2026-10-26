import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/tabs.dart';

import '../../harness/app/agent.dart';
import '../welcome/support.dart';

Future<void> _mount(
  WidgetTester tester, {
  required bool collapsed,
  required bool locked,
  required ValueChanged<Tabs> onSelected,
}) async {
  prepareWelcomeViewport(tester);
  final RailCollapse collapse = RailCollapse()
    ..setCollapsed(collapsed: collapsed);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    collapse.dispose();
  });
  await tester.pumpWidget(
    welcomeHost(
      Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ShellRail(
              collapse: collapse,
              selected: Tabs.dashboard,
              locked: locked,
              onSelected: onSelected,
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<List<Map<String, Object?>>> _controls(HarnessAgent agent) async {
  final Map<String, Object?> view = await agent.commandForTest(
    <String, dynamic>{'cmd': 'wallet-recipe', 'action': 'observe'},
  );
  return view['controls']! as List<Map<String, Object?>>;
}

void main() {
  for (final bool collapsed in <bool>[true, false]) {
    testWidgets('the real rail exposes reachable navigation $collapsed', (
      WidgetTester tester,
    ) async {
      final List<Tabs> opened = <Tabs>[];
      await _mount(
        tester,
        collapsed: collapsed,
        locked: false,
        onSelected: opened.add,
      );
      final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
      final List<Map<String, Object?>> controls = await _controls(agent);
      for (final String key in <String>['nav_dashboard', 'nav_settings']) {
        expect(
          tester.widget<Widget>(find.byKey(ValueKey<String>(key))),
          isA<InkWell>(),
        );
        final List<Map<String, Object?>> matches = controls.where(
          (Map<String, Object?> row) => row['key'] == key,
        ).toList();
        expect(matches, hasLength(1));
        expect(matches.single['enabled'], isTrue);
      }
      Map<String, Object?>? reply;
      Object? error;
      final Future<void> tapped = agent.commandForTest(<String, dynamic>{
        'cmd': 'tap', 'key': 'nav_settings', 'settleMs': 0,
      }).then<void>(
        (Map<String, Object?> value) {
          reply = value;
        },
        onError: (Object value) {
          error = value;
        },
      );
      for (int frame = 0; frame < 8 && reply == null && error == null; frame++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(error, isNull);
      expect(reply, isNotNull);
      await tapped;
      final Map<String, Object?> target =
          reply!['target']! as Map<String, Object?>;
      expect(target['key'], 'nav_settings');
      expect(target['kind'], 'button');
      expect(target['tab'], 'settings');
      expect(opened, <Tabs>[Tabs.settings]);
    });
  }

  testWidgets('a locked real rail refuses navigation without a callback', (
    WidgetTester tester,
  ) async {
    final List<Tabs> opened = <Tabs>[];
    await _mount(
      tester,
      collapsed: true,
      locked: true,
      onSelected: opened.add,
    );
    final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
    final List<Map<String, Object?>> controls = await _controls(agent);
    expect(
      controls.where((Map<String, Object?> row) =>
          row['key'] == 'nav_settings' && row['enabled'] == true),
      isEmpty,
    );
    await expectLater(
      agent.commandForTest(<String, dynamic>{
        'cmd': 'tap', 'key': 'nav_settings', 'settleMs': 0,
      }),
      throwsA(isA<HarnessError>()),
    );
    expect(opened, isEmpty);
  });
}
