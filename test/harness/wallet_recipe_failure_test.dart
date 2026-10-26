import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/screens/onboarding/welcome_surface.dart';

import '../../harness/app/agent.dart';
import '../../harness/bin/wallet_recipe.dart';
import '../../harness/wallet_recipe_failure.dart';
import '../welcome/support.dart';

Future<Map<String, Object?>> _importControl(HarnessAgent agent) async {
  final Map<String, Object?> view = await agent.commandForTest(
    <String, dynamic>{'cmd': 'wallet-recipe', 'action': 'observe'},
  );
  final List<Map<String, Object?>> controls =
      view['controls']! as List<Map<String, Object?>>;
  return controls.singleWhere(
    (Map<String, Object?> row) => row['key'] == 'welcome_import',
  );
}

void main() {
  for (final bool disableAnimations in <bool>[false, true]) {
    testWidgets('Welcome recipe waits for its entrance $disableAnimations', (
      WidgetTester tester,
    ) async {
      prepareWelcomeViewport(tester);
      final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
      int selected = 0;
      await tester.pumpWidget(welcomeHost(
        welcomeFixture(
          source: Object(), onSelected: (WelcomeDestination _) => selected++,
        ),
        disableAnimations: disableAnimations,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      final Finder importControl = find.byKey(const Key('welcome_import'));
      final Element original = tester.element(importControl);
      final Offset movingCenter = tester.getCenter(importControl);
      expect(importControl.hitTestable(), findsOneWidget);
      expect((await _importControl(agent))['enabled'], isFalse);
      expect(selected, 0);

      await finishWelcomeEntrance(tester);
      expect(tester.element(importControl), same(original));
      expect(tester.getCenter(importControl), isNot(movingCenter));
      expect((await _importControl(agent))['enabled'], isTrue);
      expect(selected, 0);
    });
  }

  testWidgets('ordinary Welcome input remains available during entrance', (
    WidgetTester tester,
  ) async {
    prepareWelcomeViewport(tester);
    final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
    final List<WelcomeDestination> selected = <WelcomeDestination>[];
    await tester.pumpWidget(welcomeHost(welcomeFixture(
      source: Object(), onSelected: selected.add,
    )));
    await tester.pump(const Duration(milliseconds: 150));
    expect((await _importControl(agent))['enabled'], isFalse);
    await tester.tap(find.byKey(const Key('welcome_import')));
    expect(selected, <WelcomeDestination>[WelcomeDestination.importWallet]);
    await finishWelcomeEntrance(tester);
    expect((await _importControl(agent))['enabled'], isTrue);
    expect(selected, <WelcomeDestination>[WelcomeDestination.importWallet]);
  });

  testWidgets('the actual Welcome view exposes its original import control', (
    WidgetTester tester,
  ) async {
    prepareWelcomeViewport(tester);
    final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
    int selected = 0;
    await tester.pumpWidget(welcomeHost(welcomeFixture(
      source: Object(), onSelected: (WelcomeDestination _) => selected++,
    )));
    await finishWelcomeEntrance(tester);
    final Map<String, Object?> view = await agent.commandForTest(
      <String, dynamic>{'cmd': 'wallet-recipe', 'action': 'observe'},
    );
    expect(view['entryPhase'], 'welcome');
    final List<Map<String, Object?>> controls =
        view['controls']! as List<Map<String, Object?>>;
    final List<Map<String, Object?>> imports = controls.where(
      (Map<String, Object?> row) => row['key'] == 'welcome_import',
    ).toList();
    expect(imports, hasLength(1));
    expect(imports.single['enabled'], isTrue);
    expect(selected, 0);
  });

  test('entry labels reject raw text and keep only known view families', () {
    final Map<String, String> value = walletRecipeDiagnostic(
      <String, Object?>{'action': 'observe', 'key': 'welcome_import'},
      'wallet-recipe-control-absent', entryPhase: 'startup-platform-error',
    );
    expect(value['entry'], 'startup-platform-error');
    expect(walletRecipePublicDiagnostic(value), value);
    expect(walletRecipePublicDiagnostic(<String, String>{
      ...value, 'entry': 'synthetic private exception text',
    }), isNull);
    expect(walletRecipeDiagnostic(<String, Object?>{'action': 'observe'},
      'wallet-recipe-control-absent', entryPhase: 'synthetic private data',
    ).containsKey('entry'), isFalse);
    for (final String handoff in walletRecipeStartupHandoffs) {
      final Map<String, String> traced = <String, String>{
        ...value, 'startup': handoff,
      };
      expect(walletRecipePublicDiagnostic(traced), traced);
    }
    expect(walletRecipePublicDiagnostic(<String, String>{
      ...value, 'startup': 'synthetic private input',
    }), isNull);
  });

  for (final bool disabled in <bool>[false, true]) {
    test('wait labels identify the unavailable control $disabled', () async {
      int calls = 0;
      bool acted = false;
      final WalletRecipe recipe = WalletRecipe(
        wait: (Duration _) async {},
        send: (Map<String, Object?> command, Duration timeout) async {
          calls++;
          acted |= command['action'] != 'observe';
          return <String, dynamic>{
            'ok': true, 'harnessMode': 'wallet', 'booted': true,
            'owner': 1, 'revision': 1, 'hasError': false,
            'walletPresent': false, 'transitionPending': false,
            'entryPhase': 'welcome',
            'signingPolicyReady': true,
            'signingChainId': 1, 'savedSigningChainId': 1,
            'controls': <Map<String, dynamic>>[
              if (disabled)
                <String, dynamic>{'key': 'welcome_import', 'enabled': false},
            ],
          };
        },
      );
      Future<void> run() => recipe.importWallet(
        chain: '321', mnemonic: List<String>.filled(12, 'synthetic').join(' '),
        password: 'Synthetic fixture A1!',
      );
      WalletRecipeRefused? failure;
      try {
        await run();
      } on WalletRecipeRefused catch (error) {
        failure = error;
      }
      expect(failure?.code, 'wallet-recipe-stage-unsettled');
      expect(failure?.diagnostic, <String, String>{
        'action': 'observe', 'control': 'welcome_import',
        'entry': 'welcome',
        'startup': 'natural-welcome',
        'reason': disabled
            ? 'wallet-recipe-control-disabled'
            : 'wallet-recipe-control-absent',
      });
      expect(acted, isFalse);
      final int originalCalls = calls;
      await expectLater(run(), throwsA(isA<WalletRecipeRefused>()));
      expect(calls, originalCalls);
    });
  }

  test('a refused field retains fixed labels without its value or reply', () {
    final Map<String, String> value = walletRecipeDiagnostic(
      <String, Object?>{
        'action': 'type', 'key': 'import_seed_field',
        'value': 'synthetic private input',
        'endpoint': 'synthetic private node',
      },
      'wallet-recipe-private-input-refused',
    );
    expect(value, <String, String>{
      'action': 'type', 'control': 'import_seed_field',
      'reason': 'wallet-recipe-private-input-refused',
    });
    expect(jsonEncode(value), isNot(contains('synthetic private')));
    expect(() => value['control'] = 'changed', throwsUnsupportedError);
    expect(walletRecipePublicDiagnostic(value), value);
  });

  test('dynamic controls and unknown errors cannot disclose their text', () {
    final Map<String, String> value = walletRecipeDiagnostic(
      <String, Object?>{
        'action': 'tap',
        'key': 'node_settings_select_wss://synthetic-private.invalid:321',
      },
      'synthetic private transport detail',
    );
    expect(value['control'], 'node_settings_select');
    expect(value['reason'], 'wallet-recipe-refused');
    expect(jsonEncode(value), isNot(contains('synthetic')));
    expect(walletRecipePublicDiagnostic(<String, String>{
      ...value, 'detail': 'synthetic private data',
    }), isNull);
    expect(walletRecipePublicDiagnostic(<String, String>{
      ...value, 'reason': 'synthetic private data',
    }), isNull);
  });

  test('failure labels keep the refusal and retire its driver', () async {
    int calls = 0;
    final WalletRecipe recipe = WalletRecipe(
      send: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        return <String, dynamic>{
          'ok': false, 'error': 'wallet-recipe-original-owner-changed',
          'detail': 'synthetic private reply',
        };
      },
    );
    Future<void> run() => recipe.importWallet(
      chain: '321', mnemonic: List<String>.filled(12, 'synthetic').join(' '),
      password: 'Synthetic fixture A1!',
    );
    WalletRecipeRefused? failure;
    try {
      await run();
    } on WalletRecipeRefused catch (error) {
      failure = error;
    }
    expect(failure?.code, 'wallet-recipe-command-refused');
    expect(failure?.diagnostic, <String, String>{
      'action': 'observe', 'control': 'none',
      'reason': 'wallet-recipe-original-owner-changed',
    });
    expect('$failure', isNot(contains('synthetic private')));
    await expectLater(run(), throwsA(isA<WalletRecipeRefused>()));
    expect(calls, 1);
  });

  testWidgets('the server preserves a fixed owner refusal without acting', (
    WidgetTester tester,
  ) async {
    final HarnessAgent agent = HarnessAgent.forTest()..booted = true;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await expectLater(
      agent.commandForTest(<String, dynamic>{
        'cmd': 'wallet-recipe', 'action': 'tap', 'key': 'welcome_import',
        'owner': 0, 'revision': 0,
      }),
      throwsA(isA<HarnessError>().having(
        (HarnessError value) => value.message,
        'message', 'wallet-recipe-original-owner-changed',
      )),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
