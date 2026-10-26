import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../harness/app/agent.dart';
import '../../harness/bin/wallet_recipe.dart';
import '../../harness/wallet_recipe_failure.dart';

void main() {
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
