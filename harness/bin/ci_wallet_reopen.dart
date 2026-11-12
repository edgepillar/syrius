// Ordinary opening of one owned copied profile, without build or import.
import 'dart:convert';
import 'dart:io';

import '../app/fixtures/seed_policy.dart'
    show pillarDepositRecipeId, pillarRegistrationRecipeId,
        seedHash, seedIssuedTokenStandard;
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
  'seed_project', 'seed_fund-address', 'seed_pillar-qsr',
  'seed_pillar-register', 'seeded_capture', 'aged_fuse_fixture',
  'finish',
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

const Map<String, Set<String?>> _preparedSurfaceTargets =
    <String, Set<String?>>{
  'themeRead': <String?>{null},
  'themeSelect': <String?>{'dark', 'light'},
  'themeRestore': <String?>{null},
  'windowRead': <String?>{null},
  'windowShow': <String?>{null},
  'windowRestore': <String?>{null},
  'navigate': <String?>{'dashboard', 'pillars', 'p2pSwap', 'tokens'},
  'wait': <String?>{
    'home_hero', 'strip_update_button', 'nodes_tab_pillars',
    'nodes_pillars_strip', 'p2p_swaps_strip', 'swap_counterparty_input',
    'swap_start_terms_gate', 'p2p_warning_continue',
    'tokens_filter_all', 'issuedTokenRow', 'token_send',
    'token_explorer_control',
  },
  'waitGone': <String?>{'swap_counterparty_input', 'token_explorer_control'},
  'tap': <String?>{
    'nodes_tab_pillars', 'pillars_sort', 'p2p_start_swap', 'swap_action_close',
    'p2p_warning_continue',
    'tokens_filter_all', 'issuedTokenRow',
  },
  'state': <String?>{null},
  'escape': <String?>{null},
  'seam': <String?>{
    'walletUpdateNotice', 'pillarAprEstimate', 'swapTerms', 'tokenExplorer',
  },
};

/// Describes the last entered fixed UI request without granting authority.
final class PreparedSurfaceOperation {
  const PreparedSurfaceOperation._(
    this.action, this.target, this.theme, this.boundary,
  );

  /// Copies fixed labels only; request payloads and replies stay private.
  factory PreparedSurfaceOperation.fromCommand(
    Map<String, Object?> command, {
    String? theme,
    String boundary = 'request',
    String? issuedTokenRowKey,
  }) {
    String? action;
    Object? target;
    switch (command['cmd']) {
      case 'theme':
        action = command.containsKey('restore') ? 'themeRestore'
            : command.containsKey('mode') ? 'themeSelect' : 'themeRead';
        if (action == 'themeSelect') target = command['mode'];
      case 'window':
        action = command.containsKey('restoreState') ? 'windowRestore'
            : command['do'] == 'show' ? 'windowShow'
            : command['do'] == null && !command.containsKey('width') &&
                !command.containsKey('height') ? 'windowRead' : null;
      case 'tap':
        action = command.containsKey('tab') ? 'navigate' : 'tap';
        target = command[command.containsKey('tab') ? 'tab' : 'key'];
      case 'wait':
        action = command['gone'] == true ? 'waitGone' : 'wait';
        target = command['key'];
      case 'state':
        action = 'state';
      case 'key':
        if (command['key'] == 'escape') action = 'escape';
      case 'seed':
        if (command['action'] == 'surface-seam') {
          action = 'seam';
          target = command['seam'];
        }
    }
    if ((action == 'wait' || action == 'tap') &&
        issuedTokenRowKey != null && target == issuedTokenRowKey) {
      target = 'issuedTokenRow';
    }
    final Set<String?>? targets = _preparedSurfaceTargets[action];
    if (action == null || targets == null ||
        target != null && target is! String || !targets.contains(target) ||
        theme != null && !const <String>{'dark', 'light'}.contains(theme) ||
        action == 'themeSelect' && target != theme ||
        !const <String>{'ownerBefore', 'request', 'ownerAfter', 'reply'}
            .contains(boundary)) {
      throw const FormatException('prepared surface metadata refused');
    }
    return PreparedSurfaceOperation._(
      action, target is String ? target : null, theme, boundary,
    );
  }

  final String action;
  final String? target;
  final String? theme;
  final String boundary;

  /// This label is not a successful request, pointer or lifecycle receipt.
  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable(
    <String, Object?>{
      'schema': 1, 'scope': 'prepared_owner_surface_operation',
      'action': action, 'target': target, 'theme': theme, 'boundary': boundary,
    },
  );
}

/// Retains each original ownership check and request without retrying failures.
Future<Map<String, dynamic>> preparedSurfaceRequest(
  Map<String, Object?> command, {
  required Future<Map<String, dynamic>> Function(Map<String, Object?>) request,
  required Future<void> Function() requireCurrent,
  required void Function(PreparedSurfaceOperation) onOperation,
  String? theme,
  String? issuedTokenRowKey,
}) async {
  void enter(String boundary) => onOperation(
    PreparedSurfaceOperation.fromCommand(
      command, theme: theme, boundary: boundary,
      issuedTokenRowKey: issuedTokenRowKey,
    ),
  );
  enter('ownerBefore');
  await requireCurrent();
  enter('request');
  final Map<String, dynamic> reply = await request(command);
  enter('ownerAfter');
  await requireCurrent();
  enter('reply');
  return reply;
}

/// The expected closed wire shape alone is not a selection receipt.
const Map<String, Object> preparedTokenHolderSelection = <String, Object>{
  'schema': 1, 'scope': 'owned_seeded_token_holder_selection',
  'members': 3, 'originalIndex': 1, 'selectedIndex': 2,
  'singleTransition': true, 'persisted': true,
  'originalResourcesCurrent': true, 'publicationRetired': true,
};

/// Retains the committed context separately from the old seed publication.
typedef PreparedTokenHolder = ({
  WalletAddressContext selected,
  Map<String, Object> selection,
  Future<void> Function() requireCurrent,
});

/// Retire once, select one existing member and retain the exact committed view.
/// No unknown reply or late result can rearm a retained observation.
Future<PreparedTokenHolder> prepareSeededTokenHolder({
  required String hash,
  required WalletAddressContext original,
  required bool Function() parentAlive,
  required Future<WalletAddressContext> Function() readContext,
  required Future<Map<String, dynamic>> Function(Map<String, Object?>) request,
  required Future<WalletAddressContext> Function(
    WalletAddressContext, Future<void> Function(),
  ) select,
}) async {
  bool held = false;
  void parent() {
    if (held || !parentAlive()) {
      held = true;
      throw const FormatException('prepared holder parent unavailable');
    }
  }
  Future<void> lease({required bool selected}) async {
    try {
      parent();
      final Map<String, dynamic> reply = await request(<String, Object?>{
        'cmd': 'seed', 'action': 'holder-current', 'hash': hash,
        'selected': selected,
      });
      parent();
      if (reply['ok'] != true || reply['current'] != true ||
          reply['publicationRetired'] != true) {
        throw const FormatException('prepared holder scope unavailable');
      }
      final Object? offered = reply['selection'];
      if (!selected) {
        if (reply.containsKey('selection')) {
          throw const FormatException('prepared holder receipt unavailable');
        }
      } else if (offered is! Map ||
          offered.length != preparedTokenHolderSelection.length ||
          preparedTokenHolderSelection.entries.any(
            (MapEntry<String, Object> entry) =>
                offered[entry.key].runtimeType != entry.value.runtimeType ||
                offered[entry.key] != entry.value,
          )) {
        throw const FormatException('prepared holder receipt unavailable');
      }
    } on Object {
      held = true;
      rethrow;
    }
  }
  try {
    parent();
    if (!seedHash(hash) || !original.consistent ||
        original.members.length != 3 ||
        original.selected != original.members[1] ||
        !original.same(await readContext())) {
      throw const FormatException('prepared holder original unavailable');
    }
    parent();
    final Map<String, dynamic> retired = await request(<String, Object?>{
      'cmd': 'seed', 'action': 'retire-token', 'hash': hash,
    });
    parent();
    if (retired['ok'] != true || retired['retired'] != true ||
        !original.same(await readContext())) {
      throw const FormatException('prepared holder retirement unavailable');
    }
    Future<void> transition() => lease(selected: false);
    await transition();
    final WalletAddressContext selected = await select(original, transition);
    await transition();
    if (!selected.selectedFrom(original, 2) ||
        !selected.same(await readContext())) {
      throw const FormatException('prepared holder selection unavailable');
    }
    await lease(selected: true);
    Future<void> current() async {
      try {
        await lease(selected: true);
        if (!selected.same(await readContext())) {
          throw const FormatException('prepared holder context changed');
        }
        parent();
      } on Object {
        held = true;
        rethrow;
      }
    }
    await current();
    return (selected: selected, requireCurrent: current,
      selection: Map<String, Object>.unmodifiable(
        preparedTokenHolderSelection,
      ));
  } on Object {
    held = true;
    rethrow;
  }
}

/// The two original views that can follow the one Start activation.
enum PreparedSwapOpening { warning, draft }

/// Waits for the original warning or draft without repeating Start.
Future<PreparedSwapOpening> preparedSwapOpening({
  required Future<Map<String, dynamic>> Function(Map<String, Object?>) request,
  required Future<void> Function() requireCurrent,
  required void Function(PreparedSurfaceOperation) onOperation,
  required String theme,
  Future<void> Function(Duration)? pause,
  int Function()? readElapsedMilliseconds,
}) async {
  final Stopwatch clock = Stopwatch()..start();
  final int Function() elapsed =
      readElapsedMilliseconds ?? () => clock.elapsedMilliseconds;
  final Future<void> Function(Duration) delay = pause ?? Future<void>.delayed;
  Future<bool> visible(String key, String kind) async {
    final Map<String, dynamic> reply = await preparedSurfaceRequest(
      <String, Object?>{
        'cmd': 'wait', 'key': key, 'kind': kind, 'exact': true, 'timeoutMs': 0,
      },
      request: request, requireCurrent: requireCurrent,
      onOperation: onOperation, theme: theme,
    );
    final Object? target = reply['target'];
    if (reply['ok'] == true && target is Map<Object?, Object?> &&
        target['key'] == key && target['kind'] == kind) {
      return true;
    }
    final Object? detail = reply['detail'];
    if (reply['ok'] == false && reply['error'] == 'not there after 0 ms' &&
        detail is Map<Object?, Object?> && detail.length == 2 &&
        detail['key'] == key && detail['kind'] == kind) {
      return false;
    }
    throw const FormatException('prepared swap opening response refused');
  }

  while (elapsed() < 5000) {
    final bool warning = await visible('p2p_warning_continue', 'button');
    final bool draft = await visible('swap_counterparty_input', 'field');
    if (warning && draft) {
      throw const FormatException('prepared swap opening ambiguous');
    }
    if (warning) return PreparedSwapOpening.warning;
    if (draft) return PreparedSwapOpening.draft;
    if (elapsed() >= 5000) break;
    await delay(const Duration(milliseconds: 150));
  }
  throw const FormatException('prepared swap opening timed out');
}

/// Only typed families and validated fixed labels enter the failure marker.
Map<String, Object?>? restoredChildFailure(
  String phase, Object error, {
  ScreenCaptureObservation? captureStep,
  PreparedSurfaceOperation? surfaceOperation,
  RestoredSeedSelection selection = RestoredSeedSelection.all,
  bool pillarSpawn = false,
  bool pillarDone = false,
  bool swapList = false,
}) {
  if (!restoredChildPhases.contains(phase)) return null;
  if (surfaceOperation != null &&
      (phase != 'seeded_capture' ||
       captureStep?.step != ScreenCaptureStep.complete ||
       captureStep?.screen != null || captureStep?.theme != null ||
       captureStep?.line != null ||
       selection != RestoredSeedSelection.seededCatalog ||
       pillarSpawn || pillarDone || swapList)) {
    return null;
  }
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
      'kind': swapList ? 'restored_swap_seeded_capture_failure'
          : pillarDone ? 'restored_pillar_done_capture_failure'
          : pillarSpawn ? 'restored_pillar_spawn_capture_failure'
          : switch (selection) {
        RestoredSeedSelection.stakeDraft =>
          'restored_stake_draft_capture_failure',
        RestoredSeedSelection.projectDetail =>
          'restored_project_detail_capture_failure',
        _ => 'restored_seeded_capture_failure',
      },
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
    'prepared_surface_operation': ?surfaceOperation?.toJson(),
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

/// Observe the existing harness-only aged rows without a publication command.
Future<Map<String, Object>> observeAgedFuseFixture({
  required String profile,
  required WalletRecipeSend request,
  required Future<void> Function() requireCurrent,
  Future<void> Function(Duration)? pause,
  int Function()? readElapsedMilliseconds,
}) async {
  final Stopwatch watch = Stopwatch()..start();
  final int Function() elapsed =
      readElapsedMilliseconds ?? () => watch.elapsedMilliseconds;
  final Future<void> Function(Duration) delay = pause ?? Future<void>.delayed;
  int last = 0;
  void need(bool value) {
    if (!value) {
      throw const FormatException('aged-fuse fixture observation refused');
    }
  }
  int remaining() {
    final int now = elapsed();
    need(now >= last && now < 90000);
    last = now;
    return 90000 - now;
  }
  Future<Map<String, dynamic>> original(Map<String, Object?> command) async {
    final int budget = remaining();
    // The original fixture admission observes actual advancing lab momentums.
    final int cap = command['cmd'] == 'seed' ? 60000 : 5000;
    final Map<String, dynamic> reply = await request(
      Map<String, Object?>.unmodifiable(command),
      Duration(milliseconds: budget < cap ? budget : cap),
    );
    remaining();
    need(reply['ok'] == true);
    return reply;
  }
  Future<void> wait() =>
      delay(Duration(milliseconds: remaining() < 50 ? remaining() : 50));
  bool visible(Map<Object?, Object?> node) {
    final Object? rect = node['rect'];
    return rect is List<Object?> && rect.length == 4 &&
        rect.every((Object? part) => part is int) &&
        (rect[0]! as int) >= 0 && (rect[1]! as int) >= 0 &&
        (rect[2]! as int) > 0 && (rect[3]! as int) > 0 &&
        (rect[0]! as int) + (rect[2]! as int) <= 1280 &&
        (rect[1]! as int) + (rect[3]! as int) <= 780;
  }
  need(RegExp(r'^ci-wallet-[a-f0-9]{24}$').hasMatch(profile));
  await requireCurrent();
  final Map<String, dynamic> opened = await original(<String, Object?>{
    'cmd': 'seed', 'action': 'fixture', 'kind': 'aged-fuse', 'profile': profile,
    'ws': 'ws://127.0.0.1:45998', 'http': 'http://127.0.0.1:45997',
  });
  need(opened.length == 4 && opened['fixture'] == 'aged-fuse' &&
      opened['readOnly'] == true && opened['chain'] is int && opened['chain'] == 321);
  final Set<String> buttons = <String>{
    for (int index = 1; index <= 2; index++)
      'plasma_cancel_${index.toRadixString(16).padLeft(64, '0')}',
  };
  while (true) {
    final Map<String, dynamic> tree = await original(<String, Object?>{'cmd': 'tree'});
    final Object? raw = tree['nodes'];
    final Object? size = tree['size'];
    need(raw is List<Object?> && raw.length <= 4096 &&
        size is List<Object?> && size.length == 2 && size[0] == 1280 && size[1] == 780);
    final List<Map<Object?, Object?>> nodes = <Map<Object?, Object?>>[];
    for (final Object? value in raw! as List<Object?>) {
      need(value is Map<Object?, Object?>);
      final Map<Object?, Object?> node = value! as Map<Object?, Object?>;
      if (visible(node)) nodes.add(node);
    }
    bool label(String text, String kind) => nodes.any(
      (Map<Object?, Object?> node) => node['kind'] == kind && node['label'] == text,
    );
    need(!label('Fixture expired', 'text'));
    final List<Map<Object?, Object?>> cancel = nodes.where(
      (Map<Object?, Object?> node) => node['kind'] == 'button' && buttons.contains(node['key']),
    ).toList();
    final bool count = nodes.any((Map<Object?, Object?> node) =>
        node['kind'] == 'text' && node['key'] == 'plasma_fused_count' && node['label'] == '2');
    final int expired = nodes.where((Map<Object?, Object?> node) =>
        node['kind'] == 'text' && node['label'] == 'Cancelable').length;
    if (count && expired == 2 && cancel.length == 2 &&
        cancel.every((Map<Object?, Object?> node) => node['enabled'] == false) &&
        cancel.map((Map<Object?, Object?> node) => node['key']).toSet().containsAll(buttons) &&
        label('Harness fixture · aged-fuse · read only', 'text')) {
      break;
    }
    await wait();
  }
  await original(<String, Object?>{
    'cmd': 'tap', 'key': 'seed_fixture_close', 'kind': 'button', 'exact': true,
  });
  while (true) {
    final Map<String, dynamic> state = await original(<String, Object?>{'cmd': 'state'});
    need(state['booted'] == true && state['walletUnlocked'] == true);
    if (!state.containsKey('harnessFixture')) break;
    need(state['harnessFixture'] == 'aged-fuse');
    await wait();
  }
  await requireCurrent();
  remaining();
  return const <String, Object>{
    'schema': 1, 'scope': 'owned_native_aged_fuse_fixture', 'fixture': 'aged-fuse',
    'rows': 2, 'expired_rows': 2, 'disabled_cancel_controls': 2,
    'banner_observed': true, 'route_closed': true, 'cleanup_cleared': true,
    'owner_current': true, 'publication_commands': 0,
  };
}

const String _seededDirectory = '.harness/ci-seeded-catalog';
const List<String> _seededScreens = <String>['staking', 'token-mine'];
const List<String> _seededFiles = <String>[
  '13-staking-dark.png', '13-staking-light.png',
  '24-token-mine-dark.png', '24-token-mine-light.png',
];
const List<String> _stakeDraftScreens = <String>['staking-new'];
const List<String> _stakeDraftFiles = <String>[
  '14-staking-new-dark.png', '14-staking-new-light.png',
];
const List<String> _projectScreens = <String>['az-project'];
const List<String> _projectFiles = <String>[
  '29-az-project-dark.png', '29-az-project-light.png',
];

// The ordinary script's final assertion is bound to the confirmed Deposit's
// disclosure below, including the original frame readback checks.
const Set<String> _swapListLines = <String>{
  'goto p2pSwap',
  'wait --key p2p_swaps_strip --timeout 30',
  'wait --key p2p_swaps_list --timeout 30',
  'assert --key swap_filter',
  'assert --key p2p_start_swap',
  'assert --key p2p_join_swap',
  'goto dashboard',
  'wait --key home_hero --timeout 5',
};

/// Only these local UI steps may run after the parent validates the journals.
const Set<String> _seededLines = <String>{
  'goto staking',
  'wait --key staking_strip --timeout 30',
  'wait --key staking_stakes_count --timeout 30',
  'assert --key staking_stakes_count',
  'goto tokens',
  'wait --key tokens_filter_held --timeout 30',
  'tap --key tokens_filter_held',
  'key ctrl+r',
  'wait --key @issued-token-row --timeout 30',
  'tap --key @issued-token-row',
  'wait --key token_action_mode_mint --timeout 30',
  'tap --key token_action_mode_mint',
  'wait --key mint_amount_field --kind field --timeout 30',
  'type --key mint_amount_field 5000',
  'assert --key @issued-token-row',
  'assert --key mint_beneficiary_field --kind field',
  'assert --key mint_amount_field --kind field',
  'wait --key mint_amount_field --kind field --gone --timeout 10',
};

const Set<String> _stakeDraftLines = <String>{
  'goto staking',
  'wait --key staking_stakes_count --timeout 30',
  'tap --key staking_stake_button',
  'wait --key create_stake_amount_field --kind field --ready --timeout 30',
  'tap --key create_stake_months_6',
  'type --key create_stake_amount_field --kind field 300',
  'wait --key create_stake_submit_button --ready --timeout 30',
  'assert --key create_stake_submit_button',
  'wait --key create_stake_amount_field --kind field --gone --timeout 10',
  'goto dashboard',
  'wait --key home_hero --timeout 5',
};

const Set<String> _projectLines = <String>{
  'goto accelerator',
  'wait --key accelerator_list --timeout 30',
  'tap --key accelerator_filter_all',
  'wait --key @confirmed-project-row --timeout 30',
  'tap --key @confirmed-project-row',
  'wait --key accelerator_project_loaded --timeout 30',
  'assert --key accelerator_project_loaded',
  'tap --key project_details_back',
  'wait --key accelerator_project_loaded --gone --timeout 10',
  'wait --key accelerator_list --timeout 10',
  'goto dashboard',
  'wait --key home_hero --timeout 5',
};

const Set<String> _spawnLines = <String>{
  'goto pillars',
  'wait --key nodes_tab_pillars --timeout 30',
  'tap --key nodes_tab_pillars',
  'wait --key nodes_pillar_more --ready --timeout 30',
  'tap --key nodes_pillar_more',
  'wait --key nodes_pillar_owner --ready --timeout 30',
  'tap --key nodes_pillar_owner',
  'wait --key nodes_spawn_pillar --ready --timeout 30',
  'tap --key nodes_spawn_pillar',
  'wait --key pillar_plasma_next_button --ready --timeout 30',
  'tap --key pillar_plasma_next_button',
  'wait --key pillar_qsr_next_button --ready --timeout 30',
  'tap --key pillar_qsr_next_button',
  'wait --key pillar_znn_next_button --ready --timeout 30',
  'tap --key pillar_znn_next_button',
  'wait --key pillar_name_field --timeout 30',
  'assert --key pillar_name_field',
  'tap Close --kind button --exact',
  'wait --key pillar_name_field --gone --timeout 10',
  'wait --key nodes_pillar_owner_close --ready --timeout 10',
  'tap --key nodes_pillar_owner_close',
  'wait --key nodes_pillar_owner_close --gone --timeout 10',
  'goto dashboard',
  'wait --key home_hero --timeout 5',
};

const Set<String> _pillarDoneLines = <String>{
  'wait --key pillar_registration_confirmed --ready --timeout 60',
  'assert --key pillar_registration_confirmed',
};

// Uses the same prepared native wallet after all four PNGs are retained.
// Only existing unavailable controls are tried; no form input is submitted.
Future<void> _observePreparedPageSeams(
  cli.Instance instance,
  Future<void> Function() requireCurrent,
  Future<void> Function(String seam, String theme) observe,
  void Function(PreparedSurfaceOperation) onOperation, {
  required String tokenRowKey,
}) async {
  String? currentTheme;
  Future<Map<String, dynamic>> send(Map<String, Object?> command) =>
      preparedSurfaceRequest(
        command, request: (Map<String, Object?> value) =>
            cli.call(instance, value),
        requireCurrent: requireCurrent, onOperation: onOperation,
        theme: currentTheme, issuedTokenRowKey: tokenRowKey,
      );
  Future<void> wait(String key, {
    String? kind, bool gone = false, bool ready = false,
  }) async {
    final Map<String, dynamic> reply = await send(<String, Object?>{
      'cmd': 'wait', 'key': key, 'exact': true, 'timeoutMs': 5000,
      'kind': ?kind,
      if (gone) 'gone': true,
      if (ready) 'ready': true,
    });
    final Object? target = reply['target'];
    if (gone ? reply.containsKey('target') :
        target is! Map || target['key'] != key) {
      throw const FormatException('prepared surface target refused');
    }
  }
  Future<void> tap(String key) async {
    final Map<String, dynamic> reply = await send(<String, Object?>{
      'cmd': 'tap', 'key': key, 'kind': 'button', 'exact': true,
    });
    final Object? target = reply['target'];
    if (target is! Map || target['key'] != key) {
      throw const FormatException('prepared surface target refused');
    }
  }
  Future<String> route(String tab) async {
    final Map<String, dynamic> state = await send(
      <String, Object?>{'cmd': 'state'},
    );
    final Object? name = state['route'];
    if (state['tab'] != tab || name is! String || name.isEmpty ||
        state['node'] != 'ws://127.0.0.1:45998' || state['chainId'] != 321 ||
        state['signingChainId'] != 321 || state['savedSigningChainId'] != 321 ||
        state['walletUnlocked'] != true ||
        state['walletInitCompleted'] != true ||
        state['embeddedNode'] != false || state['harnessFixture'] != null) {
      throw const FormatException('prepared surface route refused');
    }
    return name;
  }
  Future<void> sameRoute(String tab, String expected) async {
    if (await route(tab) != expected) {
      throw const FormatException('prepared surface route changed');
    }
  }
  final Map<String, dynamic> originalTheme = await send(
    <String, Object?>{'cmd': 'theme'},
  );
  final Map<String, dynamic> originalWindow = await send(
    <String, Object?>{'cmd': 'window'},
  );
  final Map<String, dynamic> shown = await send(<String, Object?>{
    'cmd': 'window', 'do': 'show', 'width': 1280, 'height': 780,
  });
  if (shown['clientMatched'] != true) {
    throw const FormatException('prepared surface window refused');
  }
  for (final String theme in <String>['dark', 'light']) {
    currentTheme = theme;
    await send(<String, Object?>{'cmd': 'theme', 'mode': theme});
    await send(<String, Object?>{'cmd': 'tap', 'tab': 'tokens'});
    await wait('tokens_filter_all', kind: 'button', ready: true);
    await tap('tokens_filter_all');
    await wait(tokenRowKey);
    final String tokens = await route('tokens');
    await tap(tokenRowKey);
    await wait('token_send', kind: 'button', ready: true);
    await wait('token_explorer_control', kind: 'button');
    await sameRoute('tokens', tokens);
    await observe('tokenExplorer', theme);
    await sameRoute('tokens', tokens);
    await tap(tokenRowKey);
    await wait('token_explorer_control', kind: 'button', gone: true);
    await sameRoute('tokens', tokens);
  }
  for (final String theme in <String>['dark', 'light']) {
    currentTheme = theme;
    await send(<String, Object?>{'cmd': 'theme', 'mode': theme});
    await send(<String, Object?>{'cmd': 'tap', 'tab': 'dashboard'});
    await wait('home_hero');
    final String home = await route('dashboard');
    await wait('strip_update_button', kind: 'button');
    await sameRoute('dashboard', home);
    await observe('walletUpdateNotice', theme);
    await sameRoute('dashboard', home);

    await send(<String, Object?>{'cmd': 'tap', 'tab': 'pillars'});
    await wait('nodes_tab_pillars');
    await tap('nodes_tab_pillars');
    await wait('nodes_pillars_strip');
    final String pillars = await route('pillars');
    await tap('pillars_sort');
    final String menu = await route('pillars');
    if (menu == pillars) {
      throw const FormatException('prepared surface menu required');
    }
    await observe('pillarAprEstimate', theme);
    await sameRoute('pillars', menu);
    await send(<String, Object?>{'cmd': 'key', 'key': 'escape'});
    await sameRoute('pillars', pillars);

    await send(<String, Object?>{'cmd': 'tap', 'tab': 'p2pSwap'});
    await wait('p2p_swaps_strip');
    final String swaps = await route('p2pSwap');
    await tap('p2p_start_swap');
    final PreparedSwapOpening opening = await preparedSwapOpening(
      request: (Map<String, Object?> command) => instance.send(command),
      requireCurrent: requireCurrent, onOperation: onOperation, theme: theme,
    );
    if (opening == PreparedSwapOpening.warning) {
      await tap('p2p_warning_continue');
    }
    await wait('swap_counterparty_input', kind: 'field');
    final String draft = await route('p2pSwap');
    await wait('swap_start_terms_gate', kind: 'button');
    await observe('swapTerms', theme);
    await sameRoute('p2pSwap', draft);
    await wait('swap_counterparty_input', kind: 'field');
    await tap('swap_action_close');
    await wait('swap_counterparty_input', kind: 'field', gone: true);
    await sameRoute('p2pSwap', swaps);
  }
  await send(<String, Object?>{'cmd': 'tap', 'tab': 'dashboard'});
  await wait('home_hero');
  await route('dashboard');
  await send(<String, Object?>{'cmd': 'theme', 'restore': originalTheme});
  await send(<String, Object?>{
    'cmd': 'window', 'restoreState': originalWindow,
  });
  await requireCurrent();
}

/// Opens only the row persisted by the already confirmed original Deposit.
/// An existing disclosure stays open; no publication or clipboard is invoked.
Future<void> revealSeededSwapRow(
  String hash, {
  required Future<void> Function() requireCurrent,
  required Future<Map<String, dynamic>> Function(Map<String, Object?>) request,
}) async {
  if (!seedHash(hash)) {
    throw const FormatException('confirmed swap seed required');
  }
  Future<Map<String, dynamic>> send(Map<String, Object?> command) async {
    await requireCurrent();
    final Map<String, dynamic> reply = await request(command);
    await requireCurrent();
    if (reply['ok'] is! bool) {
      throw const FormatException('seeded swap reply refused');
    }
    return reply;
  }
  Future<void> require(Map<String, Object?> command) async {
    if ((await send(command))['ok'] != true) {
      throw const FormatException('seeded swap row unavailable');
    }
  }
  final String row = 'swap_${hash}_row';
  final String copy = 'swap_copy_$hash';
  await require(<String, Object?>{
    'cmd': 'wait', 'key': row, 'exact': true, 'timeoutMs': 30000,
  });
  final Map<String, dynamic> shown = await send(<String, Object?>{
    'cmd': 'wait', 'key': copy, 'exact': true, 'timeoutMs': 0,
  });
  if (shown['ok'] != true) {
    if (classifyScreenCaptureReply(shown['error'], shown['detail']) !=
        ScreenCaptureReplyCode.targetMissing) {
      throw const FormatException('seeded swap disclosure refused');
    }
    await require(<String, Object?>{'cmd': 'tap', 'key': row, 'exact': true});
    await require(<String, Object?>{
      'cmd': 'wait', 'key': copy, 'exact': true, 'timeoutMs': 30000,
    });
  }
  await require(<String, Object?>{'cmd': 'assert', 'key': copy, 'exact': true});
}

Future<Map<String, Object>> _captureSeededCatalog(
  cli.Instance instance,
  List<Map<String, String>> receipts,
  String beneficiary,
  Future<void> Function() requireCurrent,
  void Function(ScreenCaptureObservation) onStep, {
  required RestoredSeedSelection selection,
  required Future<void> Function(String) emitMarker,
  required void Function(PreparedSurfaceOperation) onPreparedOperation,
  Future<PreparedTokenHolder> Function()? prepareTokenHolder,
  bool pillarSpawn = false,
  bool pillarDone = false,
  bool swapList = false,
}) async {
  final ({
    int schema,
    List<String> screens,
    List<String> files,
    Set<String> lines,
  }) catalog = swapList
      ? (schema: 15, screens: const <String>['swap-list'],
          files: const <String>['26-swap-list-dark.png',
                               '26-swap-list-light.png'],
          lines: _swapListLines)
      : pillarDone
      ? (schema: 14, screens: const <String>['pillar-done'],
          files: const <String>['20-pillar-done-dark.png',
                               '20-pillar-done-light.png'],
          lines: _pillarDoneLines)
      : pillarSpawn
      ? (schema: 13, screens: const <String>['spawn'],
          files: const <String>['19-spawn-dark.png', '19-spawn-light.png'],
          lines: _spawnLines)
      : switch (selection) {
    RestoredSeedSelection.seededCatalog =>
      (schema: 4, screens: _seededScreens, files: _seededFiles,
       lines: _seededLines),
    RestoredSeedSelection.stakeDraft =>
      (schema: 6, screens: _stakeDraftScreens, files: _stakeDraftFiles,
       lines: _stakeDraftLines),
    RestoredSeedSelection.projectDetail =>
      (schema: 7, screens: _projectScreens, files: _projectFiles,
       lines: _projectLines),
    RestoredSeedSelection.all =>
      throw const FormatException('seeded catalog selection required'),
  };
  String confirmed(String id) =>
      receipts.singleWhere((Map<String, String> row) => row['recipe'] == id)
          ['hash']!;
  final bool stakeDraft = selection == RestoredSeedSelection.stakeDraft;
  final bool projectDetail = selection == RestoredSeedSelection.projectDetail;
  final String? stake =
      projectDetail || pillarSpawn || pillarDone || swapList
          ? null : confirmed('stake');
  final String? rowKey = switch (selection) {
    RestoredSeedSelection.seededCatalog =>
      'token_${seedIssuedTokenStandard(confirmed('token'))}_row',
    RestoredSeedSelection.projectDetail =>
      'accelerator_project_${confirmed('project')}',
    _ => null,
  };
  Map<String, Object?> assertion(List<String> args) {
    final Map<String, Object?> selector = cli.assertionArgs(cli.Args(args));
    if (stake != null && selector['key'] == 'staking_stakes_count') {
      selector['key'] = stake;
    }
    if (swapList && selector['key'] == 'p2p_join_swap') {
      selector['key'] = 'swap_copy_${confirmed('deposit')}';
    }
    return selector;
  }

  Future<void> Function() surfaceOwner = requireCurrent;
  Future<void> observeSurface(String name, String theme) async {
    if (!const <String>{'walletUpdateNotice',
        'pillarAprEstimate', 'swapTerms', 'tokenExplorer'}.contains(name) ||
        !const <String>{'dark', 'light'}.contains(theme)) {
      throw const FormatException('prepared surface selection refused');
    }
    final Map<String, dynamic> seam = await preparedSurfaceRequest(
      <String, Object?>{
        'cmd': 'seed', 'action': 'surface-seam',
        'hash': confirmed('token'), 'seam': name, 'theme': theme,
      },
      request: (Map<String, Object?> value) => cli.call(instance, value),
      requireCurrent: surfaceOwner, onOperation: onPreparedOperation,
      theme: theme,
    );
    final Map<String, Object> expected = <String, Object>{
      'schema': 1,
      'scope': 'owned_seeded_surface_seam_pointer_observation',
      'seam': name, 'theme': theme,
      'pointerDispatched': true, 'absorptionObserved': true,
      'originalReceiptCurrent': true, 'nativeFrameObserved': true,
    };
    if (expected.entries.any((MapEntry<String, Object> entry) =>
        seam[entry.key].runtimeType != entry.value.runtimeType ||
        seam[entry.key] != entry.value)) {
      throw const FormatException('prepared surface receipt refused');
    }
    await emitMarker('CI_PREPARED_SURFACE_SEAM:${jsonEncode(expected)}');
  }

  final ScreenCapture capture = ScreenCapture(
    repository: Directory(cli.repo),
    restoredSeeded: true,
    restoredProject: projectDetail,
    restoredPillarSpawn: pillarSpawn,
    restoredPillarDone: pillarDone,
    onStep: onStep,
    call: (Map<String, Object?> command) async {
      await requireCurrent();
      final Map<String, dynamic> result = await cli.call(instance, command);
      await requireCurrent();
      return result;
    },
    prepareHome: pillarDone
        ? requireCurrent : () => cli.prepareScreenHome(instance),
    readRailState: pillarDone ? null : () => cli.screenRailExpanded(instance),
    restoreRailState: pillarDone ? null : ({required bool expanded}) =>
        cli.restoreScreenRail(instance, expanded: expanded),
    assertionFor: (List<String> words) => assertion(words.sublist(1)),
    runLine: (List<String> words) async {
      final String authored = words.join(' ');
      if (!catalog.lines.contains(authored)) {
        throw const FormatException('seeded capture command refused');
      }
      final List<String> args = <String>[
        for (final String word in words.skip(1))
          if (word == '@issued-token-row' || word == '@confirmed-project-row')
            rowKey!
          else if (stakeDraft && word == 'staking_stakes_count')
            stake!
          else
            word,
      ];
      await requireCurrent();
      if (swapList && authored == 'assert --key p2p_join_swap') {
        await revealSeededSwapRow(
          confirmed('deposit'), requireCurrent: requireCurrent,
          request: instance.send,
        );
      }
      switch (words.first) {
        case 'goto':
          await cli.goto(instance, args.single);
        case 'wait':
          await cli.waitForTarget(instance, cli.Args(<String>[
            ...args,
            if (stakeDraft || projectDetail || pillarSpawn || pillarDone)
              '--exact',
          ]));
        case 'tap':
          await cli.call(instance, <String, Object?>{
            'cmd': 'tap',
            if (pillarSpawn) ...assertion(args) else ...<String, Object?>{
              'key': args.last, 'exact': true,
            },
          });
        case 'key':
          final Map<String, dynamic> refreshed = await cli.call(
            instance, <String, Object?>{'cmd': 'key', 'key': args.single},
          );
          if (refreshed['handled'] != true) {
            throw const FormatException('token page refresh refused');
          }
        case 'type':
          final String amount = stakeDraft ? '300' : '5000';
          final Map<String, dynamic> typed = await cli.call(
            instance, <String, Object?>{
              'cmd': 'type', 'exact': true, 'value': amount,
              'key': stakeDraft
                  ? 'create_stake_amount_field' : 'mint_amount_field',
              if (stakeDraft) 'kind': 'field',
            },
          );
          if (typed['value'] != amount) {
            throw const FormatException('seeded draft amount refused');
          }
        case 'assert':
          final Map<String, Object?> selector = assertion(args);
          final Object? key = selector['key'];
          if (stake != null && key == stake) {
            await cli.waitForTarget(instance, cli.Args(<String>[
              '--key', stake, '--exact', '--timeout', '30',
            ]));
          }
          final Map<String, dynamic> asserted = await cli.call(
            instance, <String, Object?>{
              'cmd': 'assert',
              ...selector,
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
    catalog.screens, directory: _seededDirectory,
  );
  if (paths.length != catalog.files.length ||
      Iterable<int>.generate(paths.length).any(
        (int i) => paths[i] != '$_seededDirectory/${catalog.files[i]}',
      )) {
    throw const FormatException('seeded capture paths refused');
  }
  if (selection == RestoredSeedSelection.seededCatalog) {
    if (prepareTokenHolder == null || rowKey == null) {
      throw const FormatException('prepared holder admission required');
    }
    final PreparedTokenHolder holder = await prepareTokenHolder();
    surfaceOwner = holder.requireCurrent;
    await emitMarker(
      'CI_PREPARED_HOLDER_SELECTION:${jsonEncode(holder.selection)}',
    );
    await _observePreparedPageSeams(
      instance, surfaceOwner, observeSurface, onPreparedOperation,
      tokenRowKey: rowKey,
    );
    await surfaceOwner();
  }
  return <String, Object>{
    'schema': catalog.schema,
    'scope': 'restored_native_seeded_catalog_capture',
    'screens': catalog.screens, 'themes': const <String>['dark', 'light'],
    'files': catalog.files, 'width': 1280, 'height': 780, 'scale': 1,
    'capture_returned': true,
  };
}

Future<void> main() async {
  CopiedPointerInput? input;
  ScreenCaptureObservation? captureStep;
  PreparedSurfaceOperation? surfaceOperation;
  String phase = 'gate';
  RestoredSeedSelection selection = RestoredSeedSelection.all;
  bool pillarSpawn = false;
  bool pillarDone = false;
  bool swapList = false;
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
    selection = switch (env['SYRIUS_CI_REOPEN_SEEDED_CAPTURE']) {
      null || 'false' || 'pillar-spawn' || 'pillar-done' || 'swap-seeded' =>
        RestoredSeedSelection.all,
      'true' => RestoredSeedSelection.seededCatalog,
      'stake-draft' => RestoredSeedSelection.stakeDraft,
      'project-detail' => RestoredSeedSelection.projectDetail,
      _ => throw const FormatException('seeded capture selection refused'),
    };
    pillarSpawn = env['SYRIUS_CI_REOPEN_SEEDED_CAPTURE'] == 'pillar-spawn';
    pillarDone = env['SYRIUS_CI_REOPEN_SEEDED_CAPTURE'] == 'pillar-done';
    swapList = env['SYRIUS_CI_REOPEN_SEEDED_CAPTURE'] == 'swap-seeded';
    final bool seededCapture =
        pillarSpawn || pillarDone || swapList ||
        selection != RestoredSeedSelection.all;
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
    if (pillarSpawn || pillarDone) {
      final RegExp address =
          RegExp(r'^z1[023456789acdefghjklmnpqrstuvwxyz]{38}$');
      final List<String> roles = <String>[
        'actor', if (pillarDone) ...<String>['producer', 'reward'],
      ];
      final String action =
          pillarDone ? 'SEED_PILLAR_DONE' : 'SEED_PILLAR_SPAWN';
      if (seedInput is! Map<String, dynamic> ||
          seedInput.length != roles.length + 1 ||
          seedInput['action'] != action ||
          roles.any((String key) {
            final Object? value = seedInput[key];
            return value is! String || !address.hasMatch(value);
          }) ||
          roles.map((String key) => seedInput[key]).toSet().length !=
              roles.length) {
        throw const FormatException('Pillar fixture admission refused');
      }
      final String scope = pillarDone ? 'pillar_done' : 'pillar_spawn';
      final List<Map<String, String>> receipts = <Map<String, String>>[];
      Map<String, Object> receipt(String suffix) => <String, Object>{
        'schema': 1, 'scope': 'private_restored_${scope}_$suffix',
        'chain': 321, 'members': 4, 'selected_index': 3,
        'derived_count': 2, 'owner_stable': true, 'receipts': receipts,
      };
      Future<void> prefix() =>
          marker('CI_SEED_PROGRESS:${jsonEncode(receipt('prefix'))}');
      phase = 'seed_fuse';
      final ({WalletAddressContext selected, String fusionHash}) sponsored =
          await cli.preparePillarCatalogActor(
        instance, originalContext, expectedActor: seedInput['actor'] as String,
        parentAlive: () => originalInput.alive,
        onSponsored: (String hash) async {
          receipts.add(<String, String>{'recipe': 'fuse', 'hash': hash});
          await prefix();
        },
      );
      final bool? originalRail = pillarDone
          ? await cli.screenRailExpanded(instance) : null;
      if (pillarDone) await cli.prepareScreenHome(instance);
      phase = 'seed_pillar-qsr';
      final String deposited = await cli.depositPillarCatalogQsr(
        instance, sponsored, parentAlive: () => originalInput.alive,
      );
      receipts.add(<String, String>{
        'recipe': pillarDepositRecipeId, 'hash': deposited,
      });
      await prefix();
      if (pillarDone) {
        phase = 'seed_pillar-register';
        final String registered = await cli.registerPillarCatalog(
          instance, sponsored, deposited: deposited,
          producer: seedInput['producer'] as String,
          reward: seedInput['reward'] as String,
          parentAlive: () => originalInput.alive,
        );
        receipts.add(<String, String>{
          'recipe': pillarRegistrationRecipeId, 'hash': registered,
        });
        await prefix();
      }
      await marker('CI_SEED_DONE:${jsonEncode(receipt('receipts'))}');
      phase = 'seeded_capture';
      if (await originalInput.read() != 'CAPTURE_SEEDED') {
        throw const FormatException('Pillar capture gate refused');
      }
      Future<void> requireCurrent() async {
        if (!originalInput.alive ||
            !sponsored.selected.same(await context()) || !originalInput.alive) {
          throw const FormatException('Pillar capture owner changed');
        }
      }

      Future<void> closePillarOwnerPanel() async {
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'nodes_pillar_owner_close', '--exact',
          '--ready', '--timeout', '10',
        ]));
        await requireCurrent();
        await cli.call(instance, <String, Object?>{
          'cmd': 'tap', 'key': 'nodes_pillar_owner_close', 'exact': true,
        });
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'nodes_pillar_owner_close', '--exact',
          '--gone', '--timeout', '10',
        ]));
        await requireCurrent();
      }

      if (pillarSpawn) {
        await requireCurrent();
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'pillar_qsr_next_button', '--kind', 'button',
          '--ready', '--timeout', '30',
        ]));
        await requireCurrent();
        await cli.call(instance, <String, Object?>{
          'cmd': 'tap', 'text': 'Close', 'kind': 'button', 'exact': true,
        });
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'pillar_qsr_next_button', '--gone', '--timeout', '10',
        ]));
        await closePillarOwnerPanel();
      }
      final Map<String, Object> captured = await _captureSeededCatalog(
        instance, receipts, sponsored.selected.selected, requireCurrent,
        (ScreenCaptureObservation step) => captureStep = step,
        selection: RestoredSeedSelection.all,
        emitMarker: marker,
        onPreparedOperation: (PreparedSurfaceOperation operation) =>
            surfaceOperation = operation,
        pillarSpawn: pillarSpawn, pillarDone: pillarDone,
      );
      if (pillarDone) {
        const Map<String, Object?> view = <String, Object?>{
          'text': 'View pillar', 'kind': 'button', 'exact': true,
        };
        await cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'pillar_registration_confirmed', '--exact',
          '--ready', '--timeout', '10',
        ]));
        await cli.reveal(instance, view);
        await requireCurrent();
        await cli.call(instance, <String, Object?>{'cmd': 'tap', ...view});
        await cli.call(instance, <String, Object?>{
          'cmd': 'wait', ...view, 'gone': true, 'timeoutMs': 10000,
        });
        await closePillarOwnerPanel();
        await cli.restoreScreenRail(instance, expanded: originalRail!);
        await requireCurrent();
      }
      await marker('CI_SEEDED_CAPTURE_DONE:${jsonEncode(captured)}');
      phase = 'finish';
      if (await originalInput.read() != 'FINISH') {
        throw const FormatException('closure unconfirmed');
      }
      return;
    }
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
          catalogTokenHolding: seededCapture && id == 'token',
        );
      },
    );
    final Map<String, Object> seeds = await workflow.run(
      counterparty, selection: selection,
    );
    await marker('CI_SEED_DONE:${jsonEncode(seeds)}');
    if (selection == RestoredSeedSelection.all) {
      phase = 'aged_fuse_fixture';
      final WalletAddressContext fixtureOwner = await context();
      if (!fixtureOwner.derivedFrom(originalContext)) {
        throw const FormatException('aged-fuse fixture owner refused');
      }
      final Map<String, Object> witness = await observeAgedFuseFixture(
        profile: name,
        request: (Map<String, Object?> command, Duration timeout) =>
            instance.send(command, timeout: timeout),
        requireCurrent: () async {
          if (!originalInput.alive || !fixtureOwner.same(await context()) ||
              !originalInput.alive) {
            throw const FormatException('aged-fuse fixture owner changed');
          }
        },
      );
      await marker('CI_AGED_FUSE_DONE:${jsonEncode(witness)}');
    }
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
      final Object? receipts = seeds['receipts'];
      if (receipts is! List<Map<String, String>>) {
        throw const FormatException('seeded capture receipts refused');
      }
      // Project seed completion already waits for its original route exit.
      final Map<String, Object> captured = await _captureSeededCatalog(
        instance, receipts, owned.selected, requireCurrent,
        (ScreenCaptureObservation step) => captureStep = step,
        selection: selection,
        emitMarker: marker,
        swapList: swapList,
        onPreparedOperation: (PreparedSurfaceOperation operation) =>
            surfaceOperation = operation,
        prepareTokenHolder: selection != RestoredSeedSelection.seededCatalog
            ? null : () => prepareSeededTokenHolder(
                hash: receipts.singleWhere((Map<String, String> row) =>
                    row['recipe'] == 'token')['hash']!,
                original: owned, parentAlive: () => originalInput.alive,
                readContext: context,
                request: (Map<String, Object?> command) =>
                    cli.call(instance, command),
                select: (WalletAddressContext original,
                    Future<void> Function() transition) =>
                    cli.walletRecipe(instance, requireCurrent: transition)
                        .selectSeededTokenHolder(original, requireParent: () {
                          if (!originalInput.alive) {
                            throw const FormatException(
                              'prepared holder parent unavailable',
                            );
                          }
                        }),
              ),
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
      surfaceOperation: surfaceOperation,
      selection: selection, pillarSpawn: pillarSpawn, pillarDone: pillarDone,
      swapList: swapList,
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
