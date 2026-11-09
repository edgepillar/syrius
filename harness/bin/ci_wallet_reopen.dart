// Ordinary opening of one owned copied profile, without build or import.
import 'dart:convert';
import 'dart:io';

import '../app/fixtures/seed_policy.dart' show seedIssuedTokenStandard;
import '../lock_view_observation.dart';
import '../seed/restored_seed_workflow.dart';
import '../wallet_address_context.dart';
import '../wallet_recipe_failure.dart';
import 'ci_copied_wallet_pointer.dart' show CopiedPointerInput;
import 'harness.dart' as cli;
import 'screen_capture.dart';
import 'wallet_recipe.dart' show WalletRecipeRefused;

/// Fixed child locations, shared with the bounded parent projection.
const Set<String> restoredChildPhases = <String>{
  'gate', 'start', 'input', 'startup_window', 'startup', 'unlock', 'observe',
  'seed_admission', 'seed_stake', 'seed_fuse', 'seed_token', 'seed_deposit',
  'seed_project', 'seed_fund-address', 'seeded_capture', 'finish',
};

/// Exception families disclose no messages, paths, replies or private input.
const Set<String> restoredChildKinds = <String>{
  'WINDOW_REFUSED', 'RECIPE_REFUSED', 'HARNESS_REFUSED', 'FORMAT_ERROR',
  'TYPE_ERROR', 'STATE_ERROR', 'OS_ERROR', 'OTHER_ERROR',
};

/// Only the window acknowledgement's failed condition may leave the child.
const Set<String> restoredWindowFailureCodes = <String>{
  'WINDOW_RESPONSE_REFUSED', 'WINDOW_CLIENT_REFUSED', 'WINDOW_STATE_REFUSED',
};

/// Only the operation of an original unlock refusal is public.
const Set<String> restoredUnlockFailureCodes = <String>{
  'UNLOCK_STATE_REFUSED', 'UNLOCK_LOCK_REQUIRED', 'UNLOCK_TYPE_REFUSED',
  'UNLOCK_FIELD_READY_REFUSED',
  'UNLOCK_TAP_REFUSED', 'UNLOCK_WAIT_REFUSED', 'UNLOCK_FAILURE_TREE_REFUSED',
};

class _RestoredUnlockRefused implements Exception {
  const _RestoredUnlockRefused(this.code, this.lockView);

  final String code;
  final Map<String, Object?>? lockView;
}

/// Run the original unlock once, retaining no reply, password or error text.
Future<void> unlockRestoredWallet(
  cli.Instance instance,
  String password, {
  bool observeView = false,
}) async {
  Future<Map<String, Object?>?> read(String action) async {
    try {
      return projectLockView(await instance.send(<String, Object?>{
        'cmd': 'lock-view', 'action': action,
      }, timeout: const Duration(seconds: 2)));
    } on Object {
      // A failed observation never changes or retries the original unlock.
      return null;
    }
  }
  if (observeView) await read('bind');
  cli.UnlockStep? originalStep;
  try {
    await cli.unlock(
      instance,
      password,
      observe: (cli.UnlockStep step) => originalStep = step,
    );
  } on cli.Fail {
    final String code = switch (originalStep) {
      cli.UnlockStep.state => 'UNLOCK_STATE_REFUSED',
      cli.UnlockStep.lock => 'UNLOCK_LOCK_REQUIRED',
      cli.UnlockStep.fieldReady => 'UNLOCK_FIELD_READY_REFUSED',
      cli.UnlockStep.typePassword => 'UNLOCK_TYPE_REFUSED',
      cli.UnlockStep.submit => 'UNLOCK_TAP_REFUSED',
      cli.UnlockStep.wait => 'UNLOCK_WAIT_REFUSED',
      cli.UnlockStep.failureTree => 'UNLOCK_FAILURE_TREE_REFUSED',
      null => throw StateError('Original unlock step was not observed'),
    };
    final Map<String, Object?>? view =
        observeView ? await read('observe') : null;
    throw _RestoredUnlockRefused(code, view);
  }
}

/// Driver-only refusals extend the existing closed command vocabulary.
const Set<String> restoredRecipeExtraCodes = <String>{
  'wallet-recipe-restored-lock-required', 'wallet-recipe-observation-refused',
  'wallet-recipe-controls-unavailable', 'wallet-recipe-control-ambiguous',
  'wallet-recipe-command-uncertain', 'wallet-recipe-deadline',
  'wallet-recipe-retired',
};

/// A fixed acknowledgement failure, never a retained native reply.
class RestoredWindowRefused implements Exception {
  const RestoredWindowRefused._(this._code);

  final String _code;
}

/// Require the actual client before unlock, without printing its native reply.
Future<void> showRestoredStartupWindow(
  Future<Map<String, dynamic>> Function(Map<String, Object?>) request,
) async {
  final Map<String, dynamic> reply = await request(<String, Object?>{
    'cmd': 'window', 'do': 'show', 'width': 1280, 'height': 780,
  });
  if (reply['ok'] != true) {
    throw const RestoredWindowRefused._('WINDOW_RESPONSE_REFUSED');
  }
  final Object? client = reply['client'];
  bool dimension(Object? value, int expected) =>
      value is num && value.isFinite && (value - expected).abs() < 0.01;
  if (reply['clientMatched'] != true || client is! List || client.length != 2 ||
      !dimension(client[0], 1280) || !dimension(client[1], 780)) {
    throw const RestoredWindowRefused._('WINDOW_CLIENT_REFUSED');
  }
  if (reply['minimized'] != false || reply['maximized'] != false) {
    throw const RestoredWindowRefused._('WINDOW_STATE_REFUSED');
  }
}

/// Only typed families and validated fixed labels enter the failure marker.
Map<String, Object?>? restoredChildFailure(
  String phase, Object error, {
  ScreenCaptureObservation? captureStep,
}) {
  if (!restoredChildPhases.contains(phase)) return null;
  String kind = 'OTHER_ERROR';
  String? code;
  Map<String, String>? recipe;
  Map<String, Object?>? lockView;
  Map<String, Object>? seed;
  Map<String, Object>? capture;
  if (error.runtimeType == RestoredWindowRefused) {
    if (phase != 'startup_window') return null;
    kind = 'WINDOW_REFUSED';
    final String value = (error as RestoredWindowRefused)._code;
    if (restoredWindowFailureCodes.contains(value)) code = value;
  } else if (error.runtimeType == WalletRecipeRefused) {
    kind = 'RECIPE_REFUSED';
    final WalletRecipeRefused original = error as WalletRecipeRefused;
    if (walletRecipeFailureCodes.contains(original.code) ||
        restoredRecipeExtraCodes.contains(original.code)) {
      code = original.code;
    }
    recipe = walletRecipePublicDiagnostic(original.diagnostic);
  } else if (error.runtimeType == _RestoredUnlockRefused) {
    if (phase != 'unlock') return null;
    kind = 'HARNESS_REFUSED';
    final _RestoredUnlockRefused original = error as _RestoredUnlockRefused;
    final String value = original.code;
    if (!restoredUnlockFailureCodes.contains(value)) return null;
    code = value;
    lockView = projectLockView(original.lockView);
  } else if (error is cli.SeedOperationFailure) {
    final Map<String, Object> value = error.diagnostic;
    if (phase != 'seed_${value['recipe']}') return null;
    kind = 'HARNESS_REFUSED';
    seed = value;
  } else if (error is cli.Fail || error is ScreenCaptureError) {
    kind = 'HARNESS_REFUSED';
  } else if (error is FormatException) {
    kind = 'FORMAT_ERROR';
  } else if (error is TypeError) {
    kind = 'TYPE_ERROR';
  } else if (error is StateError) {
    kind = 'STATE_ERROR';
  } else if (error is FileSystemException || error is SocketException) {
    kind = 'OS_ERROR';
  }
  if (phase == 'seeded_capture' && captureStep != null) {
    final String? reply = screenCaptureReplyOf(error)?.name;
    capture = <String, Object>{
      'schema': reply == null ? 1 : 2,
      'kind': 'restored_seeded_capture_failure',
      'last_entered_step': captureStep.step.name,
      'screen': ?captureStep.screen,
      'theme': ?captureStep.theme,
      'line': ?captureStep.line,
      'reply': ?reply,
    };
  }
  return <String, Object?>{
    'schema': 1, 'scope': 'owned_reopen_child_failure', 'phase': phase,
    'kind': kind, 'code': code, 'recipe': recipe,
    'lock_view': ?lockView,
    'seed': ?seed,
    'capture': ?capture,
  };
}

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

const String _seededDirectory = '.harness/ci-seeded-catalog';
const List<String> _seededScreens = <String>['staking', 'token-mine'];
const List<String> _seededFiles = <String>[
  '13-staking-dark.png', '13-staking-light.png',
  '24-token-mine-dark.png', '24-token-mine-light.png',
];

/// Only these local UI steps may run after the parent validates the journals.
const Set<String> _seededLines = <String>{
  'goto staking',
  'wait --key staking_strip --timeout 30',
  'wait --key staking_stakes_count --timeout 30',
  'assert --key staking_stakes_count',
  'goto tokens',
  'wait --key tokens_filter_held --timeout 30',
  'tap --key tokens_filter_held',
  'wait --key @issued-token-row --timeout 30',
  'tap --key @issued-token-row',
  'wait --key token_action_mode_mint --timeout 30',
  'tap --key token_action_mode_mint',
  'wait --key mint_amount_field --timeout 30',
  'type --key mint_amount_field 5000',
  'assert --key @issued-token-row',
  'assert --key mint_beneficiary_field',
  'assert --key mint_amount_field',
  'wait --key mint_amount_field --gone --timeout 10',
};

Future<Map<String, Object>> _captureSeededCatalog(
  cli.Instance instance,
  List<Map<String, String>> receipts,
  String beneficiary,
  Future<void> Function() requireCurrent,
  void Function(ScreenCaptureObservation) onStep,
) async {
  String confirmed(String id) =>
      receipts.singleWhere((Map<String, String> row) => row['recipe'] == id)
          ['hash']!;
  final String stake = confirmed('stake');
  final String standard =
      seedIssuedTokenStandard(confirmed('token')).toString();
  final String rowKey = 'token_${standard}_row';
  final ScreenCapture capture = ScreenCapture(
    repository: Directory(cli.repo),
    restoredSeeded: true,
    onStep: onStep,
    call: (Map<String, Object?> command) async {
      await requireCurrent();
      final Map<String, dynamic> result = await cli.call(instance, command);
      await requireCurrent();
      return result;
    },
    prepareHome: () => cli.prepareScreenHome(instance),
    readRailState: () => cli.screenRailExpanded(instance),
    restoreRailState: ({required bool expanded}) =>
        cli.restoreScreenRail(instance, expanded: expanded),
    assertionFor: (List<String> words) =>
        cli.assertionArgs(cli.Args(<String>[
          '--key', words.last == 'staking_stakes_count' ? stake : words.last,
        ])),
    runLine: (List<String> words) async {
      final String authored = words.join(' ');
      if (!_seededLines.contains(authored)) {
        throw const FormatException('seeded capture command refused');
      }
      final List<String> args = <String>[
        for (final String word in words.skip(1))
          if (word == '@issued-token-row') rowKey else word,
      ];
      await requireCurrent();
      switch (words.first) {
        case 'goto':
          await cli.goto(instance, args.single);
        case 'wait':
          await cli.waitForTarget(instance, cli.Args(args));
        case 'tap':
          await cli.call(instance, <String, Object?>{
            'cmd': 'tap', 'key': args.last, 'exact': true,
          });
        case 'type':
          final Map<String, dynamic> typed = await cli.call(
            instance, <String, Object?>{
              'cmd': 'type', 'key': 'mint_amount_field', 'exact': true,
              'value': '5000',
            },
          );
          if (typed['value'] != '5000') {
            throw const FormatException('seeded draft amount refused');
          }
        case 'assert':
          final String key = args.last;
          if (key == 'staking_stakes_count') {
            await cli.waitForTarget(instance, cli.Args(<String>[
              '--key', stake, '--exact', '--timeout', '30',
            ]));
          }
          final Map<String, dynamic> asserted = await cli.call(
            instance, <String, Object?>{
              'cmd': 'assert',
              'key': key == 'staking_stakes_count' ? stake : key,
              'exact': true,
            },
          );
          final String? expectedValue = switch (key) {
            'mint_beneficiary_field' => beneficiary,
            'mint_amount_field' => '5000',
            _ => null,
          };
          if (expectedValue != null) {
            final Object? target = asserted['target'];
            if (target is! Map || target['value'] != expectedValue) {
              throw const FormatException('seeded draft field refused');
            }
          }
      }
      await requireCurrent();
    },
  );
  final List<String> paths = await capture.captureSelection(
    _seededScreens, directory: _seededDirectory,
  );
  if (paths.length != _seededFiles.length ||
      Iterable<int>.generate(paths.length).any(
        (int i) => paths[i] != '$_seededDirectory/${_seededFiles[i]}',
      )) {
    throw const FormatException('seeded capture paths refused');
  }
  return <String, Object>{
    'schema': 4, 'scope': 'restored_native_seeded_catalog_capture',
    'screens': _seededScreens, 'themes': const <String>['dark', 'light'],
    'files': _seededFiles, 'width': 1280, 'height': 780, 'scale': 1,
    'capture_returned': true,
  };
}

Future<void> main() async {
  CopiedPointerInput? input;
  ScreenCaptureObservation? captureStep;
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
    final bool seededCapture = env['SYRIUS_CI_REOPEN_SEEDED_CAPTURE'] == 'true';
    final CopiedPointerInput originalInput = CopiedPointerInput(
      stdin, allowSeededCapture: seededCapture,
    );
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
    phase = 'startup_window';
    await showRestoredStartupWindow(instance.send);
    phase = 'startup';
    await cli.walletRecipe(instance).settleRestoredStartup();
    if (!originalInput.alive) {
      throw const FormatException('parent unavailable');
    }
    phase = 'unlock';
    await unlockRestoredWallet(
      instance, decoded['password'] as String, observeView: true,
    );
    phase = 'observe';
    await cli.until(instance, restoredWalletReady, 'restored readiness');
    final Map<String, dynamic> state = await cli.stateOf(instance);
    if (!restoredWalletReady(state) || !originalInput.alive) {
      throw const FormatException('restored policy refused');
    }
    Future<WalletAddressContext> context() async {
      final Map<String, dynamic> state = await cli.stateOf(instance);
      if (!restoredWalletReady(state)) {
        throw const FormatException('seed policy changed');
      }
      final Map<String, dynamic> view = await instance.send(
        <String, Object>{'cmd': 'wallet-recipe', 'action': 'observe'},
      );
      if (view['ok'] != true || view['hasError'] != false) {
        throw const FormatException('seed owner unavailable');
      }
      return WalletAddressContext.parse(view['addressContext']);
    }
    final WalletAddressContext originalContext = await context();
    final Map<String, dynamic> result = await instance.send(<String, Object?>{
      'cmd': 'lab-reopen-observe', 'profile': name,
      for (final String key in <String>[
        'originalProfile', 'wallet', 'members', 'hash',
      ]) key: decoded[key],
    });
    if (result['ok'] != true || result['receipt'] is! Map ||
        !originalContext.same(await context()) ||
        !originalInput.alive) {
      throw const FormatException('restored observation refused');
    }
    await marker('CI_REOPEN_DONE:${jsonEncode(result['receipt'])}');
    phase = 'seed_admission';
    final Object? seedInput = jsonDecode(await originalInput.read());
    if (seedInput is! Map<String, dynamic> || seedInput.length != 2 ||
        seedInput['action'] != 'SEED' || seedInput['counterparty'] is! String) {
      throw const FormatException('seed admission refused');
    }
    final String counterparty = seedInput['counterparty'] as String;
    final RestoredSeedWorkflow workflow = RestoredSeedWorkflow(
      original: originalContext,
      parentAlive: () => originalInput.alive,
      observe: context,
      prepareAddress: cli.walletRecipe(instance).prepareSeedAddress,
      onConfirmedPrefix: (Map<String, Object> prefix) =>
          marker('CI_SEED_PROGRESS:${jsonEncode(prefix)}'),
      recipe: (String id, Future<void> Function() current) async {
        phase = 'seed_$id';
        return cli.seed(instance, cli.Args(<String>[
          id, '--instance', name, '--ws', 'ws://127.0.0.1:45998',
          '--http', 'http://127.0.0.1:45997', '--checkpoint-ready',
          if (id == 'deposit') ...<String>['--counterparty', counterparty],
        ]), requireOwner: current,
          restoredFunding: id == 'fuse' || id == 'fund-address',
        );
      },
    );
    final Map<String, Object> seeds = await workflow.run(counterparty);
    await marker('CI_SEED_DONE:${jsonEncode(seeds)}');
    if (seededCapture) {
      phase = 'seeded_capture';
      if (await originalInput.read() != 'CAPTURE_SEEDED') {
        throw const FormatException('seeded capture gate refused');
      }
      final WalletAddressContext owned = await context();
      if (!owned.derivedFrom(originalContext)) {
        throw const FormatException('seeded capture owner refused');
      }
      Future<void> requireCurrent() async {
        if (!originalInput.alive || !owned.same(await context()) ||
            !originalInput.alive) {
          throw const FormatException('seeded capture owner changed');
        }
      }
      final Map<String, Object> captured = await _captureSeededCatalog(
        instance, seeds['receipts'] as List<Map<String, String>>,
        owned.selected, requireCurrent,
        (ScreenCaptureObservation step) => captureStep = step,
      );
      await marker('CI_SEEDED_CAPTURE_DONE:${jsonEncode(captured)}');
    }
    phase = 'finish';
    if (await originalInput.read() != 'FINISH') {
      throw const FormatException('closure unconfirmed');
    }
  } on Object catch (error) {
    final Map<String, Object?>? failure = restoredChildFailure(
      phase, error, captureStep: captureStep,
    );
    if (failure != null) {
      stdout.writeln('CI_REOPEN_FAILURE:${jsonEncode(failure)}');
    }
    stdout.writeln('CI_REOPEN_ERROR:$phase');
    await stdout.flush();
    exitCode = 1;
  } finally {
    await input?.close();
  }
}
