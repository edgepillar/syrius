import 'package:flutter_test/flutter_test.dart';

import '../../harness/bin/ci_wallet_reopen.dart' as entry;
import '../../harness/bin/wallet_recipe.dart';

Map<String, dynamic> _view({
  String tab = 'lock', String phase = 'unknown', String? film,
  bool hint = false,
}) => <String, dynamic>{
  'ok': true, 'harnessMode': 'wallet', 'booted': true,
  'owner': 1, 'revision': 1, 'hasError': false,
  'tab': tab, 'entryPhase': phase,
  if (film != null) 'startupFilmState': film,
  'controls': <Map<String, Object>>[
    if (hint) <String, Object>{'key': 'launch_skip_hint', 'enabled': true},
  ],
};

void main() {
  Map<String, dynamic> ready() => <String, dynamic>{
    'walletUnlocked': true, 'walletInitCompleted': true,
    'embeddedNode': false, 'ws': 'running',
    'node': 'ws://127.0.0.1:45998', 'nodeSelectionSaved': true,
    'nodeTransitionPending': false, 'chainId': 321,
    'signingChainId': 321, 'savedSigningChainId': 321,
  };

  test('restored readiness needs initialized transport and saved lab policy',
      () {
    expect(entry.restoredWalletReady(ready()), isTrue);
    for (final String key in ready().keys) {
      final Map<String, dynamic> value = ready()..remove(key);
      expect(entry.restoredWalletReady(value), isFalse, reason: key);
    }
  });

  test('unlocked state cannot hide pending or foreign restored policy', () {
    for (final Map<String, Object> change in <Map<String, Object>>[
      <String, Object>{'chainId': 321.0},
      <String, Object>{'signingChainId': 1},
      <String, Object>{'savedSigningChainId': 321.0},
      <String, Object>{'ws': 'uninitialized'},
      <String, Object>{'nodeSelectionSaved': false},
      <String, Object>{'nodeTransitionPending': true},
    ]) {
      expect(entry.restoredWalletReady(ready()..addAll(change)), isFalse);
    }
  });

  test('a settled restored lock uses no input', () async {
    final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
    final WalletRecipe driver = WalletRecipe(
      send: (Map<String, Object?> command, Duration _) async {
        commands.add(command);
        return _view();
      },
    );
    await driver.settleRestoredStartup();
    expect(commands, hasLength(1));
    expect(commands.single['action'], 'observe');
  });

  test('the original startup hint gets one ordinary key before lock', () async {
    bool skipped = false;
    final List<Map<String, Object?>> inputs = <Map<String, Object?>>[];
    final WalletRecipe driver = WalletRecipe(
      send: (Map<String, Object?> command, Duration _) async {
        if (command['action'] == 'observe') {
          return skipped ? _view() : _view(tab: 'lock',
            phase: 'startup-before-initialization', film: 'opening',
            hint: true);
        }
        inputs.add(command);
        skipped = true;
        return <String, dynamic>{'ok': true, 'acted': true};
      },
      wait: (Duration _) async {},
    );
    await driver.settleRestoredStartup();
    expect(inputs, hasLength(1));
    expect(inputs.single['action'], 'key');
    expect(inputs.single['key'], 'launch_skip_hint');
    expect(inputs.single.containsKey('value'), isFalse);
  });

  test('natural initialization reaches lock without any key', () async {
    int observations = 0;
    final List<Map<String, Object?>> inputs = <Map<String, Object?>>[];
    final WalletRecipe driver = WalletRecipe(
      send: (Map<String, Object?> command, Duration _) async {
        if (command['action'] != 'observe') inputs.add(command);
        return observations++ < 2 ? _view(tab: 'lock',
          phase: 'startup-initialization-started', film: 'ended') : _view();
      },
      wait: (Duration _) async {},
    );
    await driver.settleRestoredStartup();
    expect(inputs, isEmpty);
    expect(observations, 3);
  });

  test('a natural lock racing the hint observation does not receive a key',
      () async {
    int observations = 0;
    final List<Map<String, Object?>> inputs = <Map<String, Object?>>[];
    final WalletRecipe driver = WalletRecipe(
      send: (Map<String, Object?> command, Duration _) async {
        if (command['action'] != 'observe') inputs.add(command);
        return observations++ == 0 ? _view(tab: 'lock',
          phase: 'startup-before-initialization', film: 'opening', hint: true)
          : _view();
      },
      wait: (Duration _) async {},
    );
    await driver.settleRestoredStartup();
    expect(inputs, isEmpty);
  });

  test('Welcome or a failed initialization refuses before private input',
      () async {
    for (final String phase in <String>[
      'welcome', 'import', 'ready', 'startup-hive-error',
    ]) {
      final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
      final WalletRecipe driver = WalletRecipe(
        send: (Map<String, Object?> command, Duration _) async {
          commands.add(command);
          return _view(tab: 'entry', phase: phase);
        },
      );
      await expectLater(driver.settleRestoredStartup(),
        throwsA(isA<WalletRecipeRefused>()));
      expect(commands.every((Map<String, Object?> command) =>
        command['action'] == 'observe'), isTrue);
    }
  });
}
