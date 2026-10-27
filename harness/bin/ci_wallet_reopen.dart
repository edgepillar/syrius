// Ordinary opening of one owned copied profile, without build or import.
import 'dart:convert';
import 'dart:io';

import 'ci_copied_wallet_pointer.dart' show CopiedPointerInput;
import 'harness.dart' as cli;

/// Initialization and the persisted lab policy must settle before the read.
bool restoredWalletReady(Map<String, dynamic> state) =>
    state['walletUnlocked'] == true && state['walletInitCompleted'] == true &&
    state['embeddedNode'] == false && state['ws'] == 'running' &&
    state['node'] == 'ws://127.0.0.1:45998' &&
    state['nodeSelectionSaved'] == true &&
    state['nodeTransitionPending'] == false &&
    <String>['chainId', 'signingChainId', 'savedSigningChainId'].every(
      (String key) => state[key] is int && state[key] == 321,
    );

Future<void> main() async {
  CopiedPointerInput? input;
  String phase = 'gate';
  try {
    final Map<String, String> env = Platform.environment;
    final String name = env['SYRIUS_CI_REOPEN_INSTANCE'] ?? '';
    if (!Platform.isWindows || env['GITHUB_ACTIONS'] != 'true' ||
        env['GITHUB_EVENT_NAME'] != 'workflow_dispatch' ||
        env['SYRIUS_HOSTED_RUNNER'] != 'github-hosted' ||
        env['GITHUB_REPOSITORY'] != 'edgepillar/syrius' ||
        env['SYRIUS_CI_WALLET_REOPEN'] != 'true' ||
        !RegExp(r'^ci-wallet-[a-f0-9]{24}$').hasMatch(name)) {
      throw const FormatException('hosted gate refused');
    }
    final CopiedPointerInput originalInput = CopiedPointerInput(stdin);
    input = originalInput;
    Future<void> marker(String value) async {
      stdout.writeln(value);
      await stdout.flush();
    }
    if (await originalInput.read() != 'START') {
      throw const FormatException('ownership gate refused');
    }
    phase = 'start';
    final cli.Instance instance = cli.Instance(name);
    if (FileSystemEntity.typeSync('${instance.home}/instance.json',
        followLinks: false) != FileSystemEntityType.notFound) {
      throw const FormatException('stale instance metadata');
    }
    await cli.start(instance, cli.Args(<String>['--mode', 'release']));
    await marker('CI_REOPEN_READY');
    phase = 'input';
    final Object? decoded = jsonDecode(await originalInput.read());
    const Set<String> keys = <String>{
      'password', 'originalProfile', 'wallet', 'members', 'hash',
    };
    if (decoded is! Map<String, dynamic> || decoded.length != keys.length ||
        !decoded.keys.toSet().containsAll(keys) ||
        decoded['password'] is! String ||
        (decoded['password'] as String).isEmpty ||
        (decoded['password'] as String).length > 512) {
      throw const FormatException('private input refused');
    }
    phase = 'startup';
    await cli.run(instance, 'window', cli.Args(<String>[
      'show', '--width', '1280', '--height', '780',
    ]));
    await cli.walletRecipe(instance).settleRestoredStartup();
    if (!originalInput.alive) {
      throw const FormatException('parent unavailable');
    }
    phase = 'unlock';
    await cli.unlock(instance, decoded['password'] as String);
    phase = 'observe';
    await cli.until(instance, restoredWalletReady, 'restored readiness');
    final Map<String, dynamic> state = await cli.stateOf(instance);
    if (!restoredWalletReady(state) || !originalInput.alive) {
      throw const FormatException('restored policy refused');
    }
    final Map<String, dynamic> result = await instance.send(<String, Object?>{
      'cmd': 'lab-reopen-observe', 'profile': name,
      for (final String key in <String>[
        'originalProfile', 'wallet', 'members', 'hash',
      ]) key: decoded[key],
    });
    if (result['ok'] != true || result['receipt'] is! Map ||
        !originalInput.alive) {
      throw const FormatException('restored observation refused');
    }
    await marker('CI_REOPEN_DONE:${jsonEncode(result['receipt'])}');
    phase = 'finish';
    if (await originalInput.read() != 'FINISH') {
      throw const FormatException('closure unconfirmed');
    }
  } on Object {
    stdout.writeln('CI_REOPEN_ERROR:$phase');
    await stdout.flush();
    exitCode = 1;
  } finally {
    await input?.close();
  }
}
