import 'dart:convert';
import 'dart:io';

import '../wallet_recipe_failure.dart'
    show walletRecipeDiagnostic, walletRecipePublicDiagnostic;
import 'harness.dart' as cli;
import 'wallet_recipe.dart' show WalletRecipeRefused, WalletRecipeSend;

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

enum _PreparationPhase {
  environment, input, ownerBefore, emptyProfile, importWallet, ownerAfter,
  walletReady,
}

class _Refused implements Exception {
  const _Refused(this.code);

  final String code;
}

class _OwnedInstance extends cli.Instance {
  _OwnedInstance(this._receipt, [this._transport])
      : super('ci-paired-interactive');

  final Map<String, dynamic> _receipt;
  final WalletRecipeSend? _transport;

  @override
  Map<String, dynamic> read() => _receipt;

  @override
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 120),
  }) => _transport == null
      ? super.send(command, timeout: timeout)
      : _transport(command, timeout);
}

/// The marker retains only the recipe's existing allowlisted labels.
Map<String, String>? pairedFrameRecipeDiagnostic(Object? failure) =>
    failure is WalletRecipeRefused
    ? walletRecipePublicDiagnostic(failure.diagnostic)
    : null;

/// Observe empty entry readiness without sending its original action.
///
/// The initial gate may also admit the original startup handoff control.
/// The tap boundary retains the default Welcome-only requirement.
Future<void> pairedFrameWaitForWelcome(
  WalletRecipeSend send, {
  Future<void> Function(Duration)? wait,
  Duration Function()? elapsed,
  Duration budget = const Duration(seconds: 90),
  bool allowOriginalStartup = false,
}) async {
  if (budget <= Duration.zero || budget > const Duration(seconds: 90)) {
    throw const WalletRecipeRefused('wallet-recipe-deadline');
  }
  const Duration quiet = Duration(seconds: 1);
  final Stopwatch clock = Stopwatch()..start();
  final Future<void> Function(Duration) pause = wait ?? Future<void>.delayed;
  Duration previous = Duration.zero;
  Duration? readySince;
  (int, int, int, String)? readyContext;
  Object? phase;
  String control = 'welcome_import';
  String reason = 'wallet-recipe-control-absent';

  Never refuse(String code) => throw WalletRecipeRefused(
    code,
    diagnostic: walletRecipeDiagnostic(
      <String, Object?>{'action': 'observe', 'key': control},
      reason,
      entryPhase: phase,
    ),
  );

  Duration now() {
    final Duration value = elapsed?.call() ?? clock.elapsed;
    if (value < previous || value >= budget) {
      refuse('wallet-recipe-deadline');
    }
    previous = value;
    return value;
  }

  // P06's original row enters over 320 ms with a 40 ms stagger. Keep its
  // identity and exact-center admission intact; wait before the first tap.
  for (int turn = 0; turn < 600; turn++) {
    final Duration remaining = budget - now();
    final Duration limit = remaining < const Duration(seconds: 10)
        ? remaining
        : const Duration(seconds: 10);
    final Map<String, dynamic> view;
    try {
      view = await send(<String, Object?>{
        'cmd': 'wallet-recipe', 'action': 'observe',
      }, limit).timeout(limit);
    } on Object {
      refuse('wallet-recipe-command-uncertain');
    }
    final Duration observedAt = now();
    phase = view['entryPhase'];
    final Object? controls = view['controls'];
    if (view['ok'] != true || view['harnessMode'] != 'wallet' ||
        view['booted'] != true || view['hasError'] != false ||
        view['owner'] is! int || view['revision'] is! int ||
        controls is! List ||
        controls.any((dynamic value) => value is! Map<String, dynamic>)) {
      reason = 'wallet-recipe-refused';
      refuse('wallet-recipe-observation-refused');
    }
    if (view['walletPresent'] != false || view['transitionPending'] != false) {
      reason = 'wallet-recipe-refused';
      refuse('wallet-recipe-empty-profile-required');
    }
    if (view['signingPolicyReady'] != true || view['signingChainId'] is! int ||
        (view['signingChainId'] as int) <= 0 ||
        view['signingChainId'] != view['savedSigningChainId']) {
      reason = 'wallet-recipe-refused';
      refuse('wallet-recipe-signing-policy-unavailable');
    }
    final bool originalStartup = allowOriginalStartup &&
        phase == 'startup-before-initialization';
    control = originalStartup ? 'launch_skip_hint' : 'welcome_import';
    final List<Map<String, dynamic>> matches = controls
        .cast<Map<String, dynamic>>()
        .where((Map<String, dynamic> value) => value['key'] == control)
        .toList();
    if (matches.length > 1) {
      reason = 'wallet-recipe-control-ambiguous';
      refuse('wallet-recipe-control-ambiguous');
    }
    reason = matches.isEmpty
        ? 'wallet-recipe-control-absent'
        : matches.single['enabled'] != true
        ? 'wallet-recipe-control-disabled'
        : 'wallet-recipe-stage-unsettled';
    if (phase is String &&
        (phase == 'welcome' || originalStartup) && matches.isNotEmpty &&
        matches.single['enabled'] == true) {
      final (int, int, int, String) context = (
        view['owner'] as int, view['revision'] as int,
        view['signingChainId'] as int, phase,
      );
      if (context != readyContext) {
        readyContext = context;
        readySince = observedAt;
      }
      if (observedAt - readySince! >= quiet) return;
      reason = 'wallet-recipe-stage-unsettled';
    } else {
      readyContext = null;
      readySince = null;
    }
    final Duration left = budget - now();
    final Duration tick = left < const Duration(milliseconds: 150)
        ? left
        : const Duration(milliseconds: 150);
    try {
      await pause(tick).timeout(left);
    } on Object {
      refuse('wallet-recipe-deadline');
    }
  }
  refuse('wallet-recipe-deadline');
}

/// Preserve the original Welcome and signing taps within one finite budget.
WalletRecipeSend pairedFrameWelcomeSend(
  WalletRecipeSend send, {
  Future<void> Function(void Function() requireCurrent)? beforeTap,
  Future<void> Function(Duration)? wait,
  Duration Function()? elapsed,
}) {
  final Set<String> reserved = <String>{};
  bool retired = false;
  return (Map<String, Object?> command, Duration timeout) async {
    if (retired) {
      throw const WalletRecipeRefused('wallet-recipe-retired');
    }
    try {
      if (timeout <= Duration.zero) {
        throw const WalletRecipeRefused('wallet-recipe-deadline');
      }
      final bool signing = command['key'] == 'node_settings_chain_toggle';
      if (command['cmd'] != 'wallet-recipe' ||
          command['action'] != 'tap' ||
          command['key'] != 'welcome_import' && !signing) {
        return await send(command, timeout).timeout(timeout);
      }
      if (!reserved.add(command['key'] as String)) {
        throw const WalletRecipeRefused('wallet-recipe-retired');
      }
      final Stopwatch clock = Stopwatch()..start();
      final Duration origin = elapsed?.call() ?? Duration.zero;
      Duration previous = Duration.zero;
      Duration spent() {
        if (retired) {
          throw const WalletRecipeRefused('wallet-recipe-retired');
        }
        final Duration value = (elapsed?.call() ?? clock.elapsed) - origin;
        if (value < previous || value >= timeout) {
          throw const WalletRecipeRefused('wallet-recipe-deadline');
        }
        previous = value;
        return value;
      }
      Duration remaining() => timeout - spent();
      if (signing) {
        // Let the Settings entrance finish before its original first tap.
        // Keep the exact center guard and the original command deadline.
        const Duration settle = Duration(seconds: 1);
        if (remaining() <= settle) {
          throw const WalletRecipeRefused('wallet-recipe-deadline');
        }
        final Future<void> Function(Duration) pause =
            wait ?? Future<void>.delayed;
        await pause(settle).timeout(remaining());
      } else {
        await pairedFrameWaitForWelcome(
          send,
          wait: wait,
          elapsed: spent,
          budget: timeout < const Duration(seconds: 90)
              ? timeout
              : const Duration(seconds: 90),
        );
        if (beforeTap != null) {
          await beforeTap(remaining).timeout(remaining());
        }
      }
      final Duration left = remaining();
      return await send(command, left).timeout(left);
    } on Object catch (error) {
      retired = true;
      if (error is WalletRecipeRefused || error is _Refused) rethrow;
      throw const WalletRecipeRefused('wallet-recipe-command-uncertain');
    }
  };
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

Future<void> _emptyProfile(_OwnedInstance instance) async {
  final Map<String, dynamic> state =
      await cli.call(instance, <String, Object?>{'cmd': 'state'});
  if (state['walletUnlocked'] != false ||
      state['walletInitCompleted'] != false || state['walletPath'] != null) {
    throw const _Refused('PROFILE_REFUSED');
  }
}

Future<void> main(List<String> args) async {
  String? error;
  _PreparationPhase phase = _PreparationPhase.environment;
  Map<String, String>? recipeFailure;
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
    phase = _PreparationPhase.input;
    final Map<String, dynamic> offered = await _input();
    final int pid = offered['pid'] as int;
    final _OwnedInstance instance = _OwnedInstance(<String, dynamic>{
      'port': offered['port'],
      'token': offered['token'],
    });
    phase = _PreparationPhase.ownerBefore;
    await _owner(instance, pid);
    phase = _PreparationPhase.emptyProfile;
    await _emptyProfile(instance);
    phase = _PreparationPhase.importWallet;
    await pairedFrameWaitForWelcome(
      (Map<String, Object?> command, Duration timeout) =>
          instance.send(command, timeout: timeout),
      allowOriginalStartup: true,
    );
    phase = _PreparationPhase.ownerBefore;
    await _owner(instance, pid);
    phase = _PreparationPhase.emptyProfile;
    await _emptyProfile(instance);
    phase = _PreparationPhase.importWallet;
    final _OwnedInstance importer = _OwnedInstance(
      instance.read(),
      pairedFrameWelcomeSend(
        (Map<String, Object?> command, Duration timeout) =>
            instance.send(command, timeout: timeout),
        beforeTap: (void Function() requireCurrent) async {
          requireCurrent();
          phase = _PreparationPhase.ownerBefore;
          await _owner(instance, pid);
          requireCurrent();
          phase = _PreparationPhase.emptyProfile;
          await _emptyProfile(instance);
          requireCurrent();
          phase = _PreparationPhase.importWallet;
        },
      ),
    );
    await cli.walletRecipe(importer).importWallet(
      chain: '321',
      mnemonic: offered['mnemonic'] as String,
      password: offered['password'] as String,
      node: _node,
      beforeWelcome: (Duration remaining) => pairedFrameWaitForWelcome(
        (Map<String, Object?> command, Duration timeout) =>
            instance.send(command, timeout: timeout),
        budget: remaining < const Duration(seconds: 90)
            ? remaining
            : const Duration(seconds: 90),
      ),
    );
    phase = _PreparationPhase.ownerAfter;
    await _owner(instance, pid);
    phase = _PreparationPhase.walletReady;
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
  } on WalletRecipeRefused catch (failure) {
    error = 'PREPARATION_REFUSED';
    recipeFailure = pairedFrameRecipeDiagnostic(failure);
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
    if (error != null)
      'failure': <String, Object?>{
        'phase': phase.name,
        'recipe': ?recipeFailure,
      },
  }));
  exitCode = error == null ? 0 : 1;
}
