import 'dart:convert';
import 'dart:io';

import 'harness.dart' as cli;

const String _scope = 'owned_chain321_frame_profile_preparation';
const String _node = 'ws://127.0.0.1:45998';
const Set<String> _fields = <String>{
  'schema',
  'pid',
  'port',
  'token',
  'mnemonic',
  'password',
};

class _Refused implements Exception {
  const _Refused(this.code);

  final String code;
}

class _OwnedInstance extends cli.Instance {
  _OwnedInstance(this._receipt) : super('ci-paired-interactive');

  final Map<String, dynamic> _receipt;

  @override
  Map<String, dynamic> read() => _receipt;
}

Future<Map<String, dynamic>> _input() async {
  final List<int> bytes = <int>[];
  await for (final List<int> chunk in stdin.timeout(
    const Duration(seconds: 20),
  )) {
    if (bytes.length + chunk.length > 4096) {
      throw const _Refused('INPUT_REFUSED');
    }
    bytes.addAll(chunk);
  }
  final Object? value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic> ||
      value.length != _fields.length ||
      !_fields.every(value.containsKey) ||
      value['schema'] is! int ||
      value['schema'] != 1 ||
      value['pid'] is! int ||
      (value['pid'] as int) <= 0 ||
      value['port'] is! int ||
      (value['port'] as int) < 1024 ||
      (value['port'] as int) > 65535 ||
      value['token'] is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value['token'] as String) ||
      value['password'] is! String ||
      !RegExp(r'^[a-f0-9]{32}A!1$').hasMatch(value['password'] as String) ||
      value['mnemonic'] is! String ||
      (value['mnemonic'] as String).length > 512 ||
      !RegExp(r'^[a-z]+( [a-z]+){11}( [a-z]+( [a-z]+){11})?$')
          .hasMatch(value['mnemonic'] as String)) {
    throw const _Refused('INPUT_REFUSED');
  }
  return value;
}

Future<void> _owner(_OwnedInstance instance, int pid) async {
  final Map<String, dynamic> reply =
      await cli.call(instance, <String, Object?>{'cmd': 'ping'});
  if (reply['pid'] != pid ||
      reply['booted'] != true ||
      reply['harnessMode'] != 'wallet') {
    throw const _Refused('OWNER_REFUSED');
  }
}

Future<void> main(List<String> args) async {
  String? error;
  try {
    final Map<String, String> env = Platform.environment;
    if (args.isNotEmpty ||
        !Platform.isWindows ||
        env['GITHUB_ACTIONS'] != 'true' ||
        env['GITHUB_EVENT_NAME'] != 'workflow_dispatch' ||
        env['GITHUB_REPOSITORY'] != 'edgepillar/syrius' ||
        env['GITHUB_REF'] != 'refs/heads/redesign' ||
        env['GITHUB_RUN_ATTEMPT'] != '1' ||
        env['RUNNER_ENVIRONMENT'] != 'github-hosted' ||
        env['SYRIUS_PAIRED_INTERACTIVE_PROFILE'] != 'true') {
      throw const _Refused('ENVIRONMENT_REFUSED');
    }
    final Map<String, dynamic> offered = await _input();
    final int pid = offered['pid'] as int;
    final _OwnedInstance instance = _OwnedInstance(<String, dynamic>{
      'port': offered['port'],
      'token': offered['token'],
    });
    await _owner(instance, pid);
    final Map<String, dynamic> before =
        await cli.call(instance, <String, Object?>{'cmd': 'state'});
    if (before['walletUnlocked'] != false ||
        before['walletInitCompleted'] != false ||
        before['walletPath'] != null) {
      throw const _Refused('PROFILE_REFUSED');
    }
    await cli.walletRecipe(instance).importWallet(
      chain: '321',
      mnemonic: offered['mnemonic'] as String,
      password: offered['password'] as String,
      node: _node,
    );
    await _owner(instance, pid);
    final Map<String, dynamic> after =
        await cli.call(instance, <String, Object?>{'cmd': 'state'});
    if (after['walletUnlocked'] != true ||
        after['walletInitCompleted'] != true ||
        after['tab'] != 'dashboard' ||
        after['node'] != _node ||
        after['chainId'] != 321 ||
        after['signingChainId'] != 321 ||
        after['savedSigningChainId'] != 321 ||
        after['nodeTransitionPending'] != false ||
        after['embeddedNode'] != false) {
      throw const _Refused('WALLET_REFUSED');
    }
  } on _Refused catch (failure) {
    error = failure.code;
  } on FormatException {
    error = 'INPUT_REFUSED';
  } on Object {
    error = 'PREPARATION_REFUSED';
  }
  stdout.writeln(jsonEncode(<String, Object?>{
    'schema': 1,
    'scope': _scope,
    'success': error == null,
    'error_code': error,
  }));
  exitCode = error == null ? 0 : 1;
}
