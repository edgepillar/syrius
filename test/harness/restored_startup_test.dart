import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../harness/bin/ci_wallet_reopen.dart' as entry;
import '../../harness/bin/harness.dart' as cli;
import '../../harness/bin/screen_capture.dart';
import '../../harness/bin/wallet_recipe.dart';
import '../../harness/lock_view_observation.dart';
import '../../harness/seed/restored_seed_workflow.dart';
import '../../harness/wallet_address_context.dart';

WalletAddressContext _preparedHolderContext({
  List<String> members = const <String>['first', 'issuer', 'holder'],
  String selected = 'issuer',
  String saved = 'issuer',
  int revision = 20,
  int owner = 1,
}) => WalletAddressContext.parse(<String, dynamic>{
  'members': members, 'selected': selected, 'saved': saved,
  'revision': revision, 'owner': owner,
});

class _HolderPreparation {
  final WalletAddressContext original = _preparedHolderContext();
  late WalletAddressContext current = original;
  bool alive = true;
  bool earlyReceipt = false;
  int selections = 0;
  final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
  Map<String, dynamic> retirementReply = <String, dynamic>{
    'ok': true, 'retired': true,
  };
  Object? selectionReply = Map<String, Object>.from(
    entry.preparedTokenHolderSelection,
  );
  Future<WalletAddressContext> Function(
    WalletAddressContext, Future<void> Function(),
  )? selectOriginal;

  Future<entry.PreparedTokenHolder> prepare() => entry.prepareSeededTokenHolder(
    hash: List<String>.filled(64, 'a').join(), original: original,
    parentAlive: () => alive, readContext: () async => current,
    request: (Map<String, Object?> command) async {
      commands.add(Map<String, Object?>.from(command));
      if (command['action'] == 'retire-token') return retirementReply;
      expect(command['action'], 'holder-current');
      return <String, dynamic>{
        'ok': true, 'current': true, 'publicationRetired': true,
        if (command['selected'] == true || earlyReceipt)
          'selection': selectionReply,
      };
    },
    select: (WalletAddressContext owner, Future<void> Function() transition)
        async {
      selections++;
      final Future<WalletAddressContext> Function(
        WalletAddressContext, Future<void> Function(),
      )? action = selectOriginal;
      if (action != null) return action(owner, transition);
      expect(owner, same(original));
      await transition();
      current = _preparedHolderContext(saved: 'holder');
      await transition();
      current = _preparedHolderContext(
        selected: 'holder', saved: 'holder', revision: 21,
      );
      await transition();
      return current;
    },
  );
}

class _Unformattable implements Exception {
  @override
  String toString() => throw StateError('The error must not be formatted');
}

class _UnlockInstance extends cli.Instance {
  _UnlockInstance(this.refusal, {this.lockView})
      : super('synthetic-restored-unlock');

  final Object? lockView;

  final String? refusal;
  final List<String> commands = <String>[];
  int observations = 0;

  @override
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final String name = command['cmd']! as String;
    commands.add(name);
    bool refused = false;
    if (name == 'lock-view') {
      final Object? original = lockView;
      if (original is! Map<String, dynamic>) throw _Unformattable();
      expect(command['action'], anyOf('bind', 'observe'));
      expect(command.containsKey('value'), isFalse);
      return Map<String, dynamic>.from(original);
    }
    if (name == 'state') {
      observations++;
      refused = observations == 1
          ? refusal == 'UNLOCK_STATE_REFUSED'
          : refusal == 'UNLOCK_WAIT_REFUSED' ||
              refusal == 'UNLOCK_FAILURE_TREE_REFUSED';
      if (!refused) {
        return <String, dynamic>{
          'ok': true,
          'tab': refusal == 'UNLOCK_LOCK_REQUIRED'
              ? 'startup' : observations == 1 ? 'lock' : 'dashboard',
          'walletUnlocked': observations > 1,
        };
      }
    } else if (name == 'wait') {
      expect(command['key'], 'wallet_password_field');
      expect(command['kind'], 'field');
      expect(command['ready'], isTrue);
      expect(command['timeoutMs'], 5000);
      expect(command.containsKey('value'), isFalse);
      refused = refusal == 'UNLOCK_FIELD_READY_REFUSED';
    } else if (name == 'type') {
      expect(command['key'], 'wallet_password_field');
      expect(command['value'], 'synthetic-private-password');
      refused = refusal == 'UNLOCK_TYPE_REFUSED';
    } else if (name == 'tap') {
      expect(command['key'], 'wallet_unlock_button');
      refused = refusal == 'UNLOCK_TAP_REFUSED';
    } else if (name == 'tree') {
      expect(command['kind'], 'text');
      refused = refusal == 'UNLOCK_FAILURE_TREE_REFUSED';
      if (!refused) return <String, dynamic>{'ok': true, 'nodes': <Object>[]};
    } else {
      throw StateError('Unexpected original unlock operation');
    }
    return <String, dynamic>{
      'ok': !refused,
      if (refused) 'error': 'synthetic-private-error',
      if (refused) 'detail': <String, String>{'path': 'synthetic-private-path'},
      if (refused) 'stack': 'synthetic-private-stack',
    };
  }
}

Object _typeError() {
  final Object value = Object();
  try {
    return value as int;
  } on Object catch (error) {
    return error;
  }
}

Future<Map<String, Object?>> _failure(
  Future<void> Function() action,
  String phase,
) async {
  try {
    await action();
  } on Object catch (error) {
    final Map<String, Object?>? result = entry.restoredChildFailure(
      phase,
      error,
    );
    expect(result, isNotNull);
    return result!;
  }
  throw StateError('The original operation did not refuse');
}

Map<String, dynamic> _view({
  String tab = 'lock', String phase = 'unknown', String? film,
  bool hint = false,
}) => <String, dynamic>{
  'ok': true, 'harnessMode': 'wallet', 'booted': true,
  'owner': 1, 'revision': 1, 'hasError': false,
  'tab': tab, 'entryPhase': phase,
  'startupFilmState': ?film,
  'controls': <Map<String, Object>>[
    if (hint) <String, Object>{'key': 'launch_skip_hint', 'enabled': true},
  ],
};

void main() {
  test('prepared holder retires once and selects only one existing member',
      () async {
    final _HolderPreparation driver = _HolderPreparation();
    final entry.PreparedTokenHolder holder = await driver.prepare();
    expect(holder.selected, same(driver.current));
    expect(holder.selected.selectedFrom(driver.original, 2), isTrue);
    await holder.requireCurrent();
    expect(driver.selections, 1);
    expect(driver.commands.where((Map<String, Object?> command) =>
      command['action'] == 'retire-token'), hasLength(1));
    expect(driver.commands.every((Map<String, Object?> command) =>
      command['cmd'] == 'seed' &&
      <String>{'retire-token', 'holder-current'}.contains(command['action'])),
      isTrue);
    expect(holder.selection, entry.preparedTokenHolderSelection);
    expect(() => holder.selection['members'] = 4, throwsUnsupportedError);
    expect(jsonEncode(holder.selection), isNot(contains('issuer')));
    expect(jsonEncode(holder.selection), isNot(contains('aaaa')));
  });

  test('prepared holder cannot recover after context or parent replacement',
      () async {
    for (final String lost in <String>[
      'parent', 'owner', 'revision', 'members', 'original',
    ]) {
      final _HolderPreparation driver = _HolderPreparation();
      final entry.PreparedTokenHolder holder = await driver.prepare();
      switch (lost) {
        case 'parent': driver.alive = false;
        case 'owner': driver.current = _preparedHolderContext(
          selected: 'holder', saved: 'holder', revision: 21, owner: 2,
        );
        case 'revision': driver.current = _preparedHolderContext(
          selected: 'holder', saved: 'holder', revision: 22,
        );
        case 'members': driver.current = _preparedHolderContext(
          members: <String>['issuer', 'first', 'holder'],
          selected: 'holder', saved: 'holder', revision: 21,
        );
        case 'original': driver.current = driver.original;
      }
      await expectLater(holder.requireCurrent(), throwsFormatException);
      driver
        ..alive = true
        ..current = holder.selected;
      await expectLater(holder.requireCurrent(), throwsFormatException);
      expect(driver.selections, 1);
    }
  });

  test('prepared holder refuses unknown retirement and coerced selection facts',
      () async {
    for (final Object? receipt in <Object?>[
      null, true, <String, Object>{},
      <String, Object>{...entry.preparedTokenHolderSelection, 'members': true},
      <String, Object>{...entry.preparedTokenHolderSelection, 'persisted': 1},
      <String, Object>{...entry.preparedTokenHolderSelection, 'private': true},
    ]) {
      final _HolderPreparation driver = _HolderPreparation()
        ..selectionReply = receipt;
      await expectLater(driver.prepare(), throwsFormatException);
      expect(driver.selections, 1);
    }
    for (final Map<String, dynamic> reply in <Map<String, dynamic>>[
      <String, dynamic>{'ok': true},
      <String, dynamic>{'ok': true, 'retired': 1},
      <String, dynamic>{'ok': false, 'retired': true},
    ]) {
      final _HolderPreparation driver = _HolderPreparation()
        ..retirementReply = reply;
      await expectLater(driver.prepare(), throwsFormatException);
      expect(driver.selections, 0);
      expect(driver.commands, hasLength(1));
    }
    final _HolderPreparation early = _HolderPreparation()..earlyReceipt = true;
    await expectLater(early.prepare(), throwsFormatException);
    expect(early.selections, 0);
  });

  test('late selected context cannot rearm a held preparation', () async {
    final _HolderPreparation driver = _HolderPreparation();
    final Completer<void> selecting = Completer<void>();
    final Completer<WalletAddressContext> selected =
        Completer<WalletAddressContext>();
    late Future<void> Function() retainedTransition;
    driver.selectOriginal = (WalletAddressContext original,
        Future<void> Function() transition) async {
      expect(original, same(driver.original));
      retainedTransition = transition;
      await transition();
      selecting.complete();
      final WalletAddressContext context = await selected.future;
      await transition();
      return context;
    };
    final Future<entry.PreparedTokenHolder> preparation = driver.prepare();
    await selecting.future;
    driver.alive = false;
    await expectLater(retainedTransition(), throwsFormatException);
    driver
      ..alive = true
      ..current = _preparedHolderContext(
        selected: 'holder', saved: 'holder', revision: 21,
      );
    final Future<void> refused =
        expectLater(preparation, throwsFormatException);
    selected.complete(driver.current);
    await refused;
    await expectLater(retainedTransition(), throwsFormatException);
    expect(driver.selections, 1);
  });

  Map<String, dynamic> openingReply(Map<String, Object?> command, {
    required bool warning,
    required bool draft,
  }) {
    final bool present = command['key'] == 'p2p_warning_continue'
        ? warning : draft;
    return present ? <String, dynamic>{
      'ok': true,
      'target': <String, Object?>{
        'key': command['key'], 'kind': command['kind'],
      },
    } : <String, dynamic>{
      'ok': false, 'error': 'not there after 0 ms',
      'detail': <String, Object?>{
        'key': command['key'], 'kind': command['kind'],
      },
    };
  }

  test('prepared Swap opening observes the original warning or direct draft',
      () async {
    for (final entry.PreparedSwapOpening expected
        in entry.PreparedSwapOpening.values) {
      final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
      int owners = 0;
      final entry.PreparedSwapOpening actual = await entry.preparedSwapOpening(
        request: (Map<String, Object?> command) async {
          commands.add(Map<String, Object?>.of(command));
          return openingReply(command,
            warning: expected == entry.PreparedSwapOpening.warning,
            draft: expected == entry.PreparedSwapOpening.draft,
          );
        },
        requireCurrent: () async { owners++; },
        onOperation: (entry.PreparedSurfaceOperation _) {},
        theme: 'dark',
      );
      expect(actual, expected);
      expect(owners, 4);
      expect(commands.map((Map<String, Object?> value) => value['key']),
          <String>['p2p_warning_continue', 'swap_counterparty_input']);
      for (final Map<String, Object?> command in commands) {
        expect(command['cmd'], 'wait');
        expect(command['timeoutMs'], 0);
        expect(command['exact'], isTrue);
      }
    }
  });

  test('prepared Swap opening waits for a real view without another Start',
      () async {
    int elapsed = 0;
    int requests = 0;
    int pauses = 0;
    final entry.PreparedSwapOpening actual = await entry.preparedSwapOpening(
      request: (Map<String, Object?> command) async {
        requests++;
        expect(command['cmd'], 'wait');
        return openingReply(command, warning: false, draft: elapsed >= 150);
      },
      requireCurrent: () async {},
      onOperation: (entry.PreparedSurfaceOperation _) {},
      theme: 'light',
      pause: (Duration duration) async {
        pauses++;
        elapsed += duration.inMilliseconds;
      },
      readElapsedMilliseconds: () => elapsed,
    );
    expect(actual, entry.PreparedSwapOpening.draft);
    expect(requests, 4);
    expect(pauses, 1);
  });

  test('prepared Swap opening refuses unknown and ambiguous replies', () async {
    for (final Map<String, dynamic> reply in <Map<String, dynamic>>[
      <String, dynamic>{'ok': false, 'error': _Unformattable()},
      <String, dynamic>{'ok': false, 'error': 'not ready after 0 ms'},
      <String, dynamic>{
        'ok': true, 'target': <String, String>{'key': 'private'},
      },
      <String, dynamic>{
        'ok': false, 'error': 'not there after 0 ms',
        'detail': <String, String>{'key': 'private', 'kind': 'button'},
      },
    ]) {
      await expectLater(entry.preparedSwapOpening(
        request: (Map<String, Object?> _) async => reply,
        requireCurrent: () async {},
        onOperation: (entry.PreparedSurfaceOperation _) {},
        theme: 'dark',
      ), throwsFormatException);
    }
    await expectLater(entry.preparedSwapOpening(
      request: (Map<String, Object?> command) async =>
          openingReply(command, warning: true, draft: true),
      requireCurrent: () async {},
      onOperation: (entry.PreparedSurfaceOperation _) {},
      theme: 'dark',
    ), throwsFormatException);
  });

  test('prepared Swap opening holds absent views and lost original owners',
      () async {
    int elapsed = 0;
    int requests = 0;
    await expectLater(entry.preparedSwapOpening(
      request: (Map<String, Object?> command) async {
        requests++;
        return openingReply(command, warning: false, draft: false);
      },
      requireCurrent: () async {},
      onOperation: (entry.PreparedSurfaceOperation _) {},
      theme: 'dark',
      pause: (Duration duration) async {
        expect(duration, const Duration(milliseconds: 150));
        elapsed = 5000;
      },
      readElapsedMilliseconds: () => elapsed,
    ), throwsFormatException);
    expect(requests, 2);

    int owners = 0;
    requests = 0;
    final _Unformattable original = _Unformattable();
    await expectLater(entry.preparedSwapOpening(
      request: (Map<String, Object?> command) async {
        requests++;
        return openingReply(command, warning: true, draft: false);
      },
      requireCurrent: () async {
        owners++;
        if (owners == 3) throw original;
      },
      onOperation: (entry.PreparedSurfaceOperation _) {},
      theme: 'dark',
    ), throwsA(same(original)));
    expect(requests, 1);
    expect(owners, 3);
  });

  test('prepared operation labels exclude payloads and remain immutable', () {
    final List<Map<String, Object?>> commands = <Map<String, Object?>>[
      <String, Object?>{'cmd': 'theme'},
      <String, Object?>{'cmd': 'theme', 'mode': 'dark'},
      <String, Object?>{'cmd': 'theme', 'restore': _Unformattable()},
      <String, Object?>{'cmd': 'window'},
      <String, Object?>{'cmd': 'window', 'do': 'show', 'width': 1280},
      <String, Object?>{'cmd': 'window', 'restoreState': _Unformattable()},
      <String, Object?>{'cmd': 'tap', 'tab': 'dashboard'},
      <String, Object?>{'cmd': 'tap', 'key': 'pillars_sort'},
      <String, Object?>{'cmd': 'wait', 'key': 'home_hero'},
      <String, Object?>{
        'cmd': 'wait', 'key': 'swap_counterparty_input', 'gone': true,
      },
      <String, Object?>{'cmd': 'state'},
      <String, Object?>{'cmd': 'key', 'key': 'escape'},
      <String, Object?>{
        'cmd': 'seed', 'action': 'surface-seam',
        'seam': 'walletUpdateNotice', 'hash': _Unformattable(),
      },
      <String, Object?>{
        'cmd': 'seed', 'action': 'surface-seam', 'seam': 'tokenExplorer',
      },
    ];
    for (final Map<String, Object?> command in commands) {
      final entry.PreparedSurfaceOperation operation =
          entry.PreparedSurfaceOperation.fromCommand(command, theme: 'dark');
      final Map<String, Object?> snapshot = operation.toJson();
      command.clear();
      expect(jsonEncode(snapshot), isNot(contains('private')));
      expect(snapshot.keys, unorderedEquals(<String>[
        'schema', 'scope', 'action', 'target', 'theme', 'boundary',
      ]));
      expect(() => snapshot['target'] = 'private', throwsUnsupportedError);
      expect(operation.toJson(), snapshot);
    }
    for (final String action in <String>['wait', 'tap']) {
      final Map<String, Object?> row = <String, Object?>{
        'cmd': action, 'key': 'token_private_row',
      };
      final Map<String, Object?> label =
          entry.PreparedSurfaceOperation.fromCommand(
            row, theme: 'dark', issuedTokenRowKey: 'token_private_row',
          ).toJson();
      expect(label['target'], 'issuedTokenRow');
      expect(jsonEncode(label), isNot(contains('token_private_row')));
      expect(() => entry.PreparedSurfaceOperation.fromCommand(
        row, issuedTokenRowKey: 'another_private_row',
      ), throwsFormatException);
    }
  });

  test('prepared operation labels reject foreign commands and targets', () {
    for (final Map<String, Object?> command in <Map<String, Object?>>[
      <String, Object?>{'cmd': 'private'},
      <String, Object?>{'cmd': 'tap', 'tab': 'settings'},
      <String, Object?>{'cmd': 'wait', 'key': 'private'},
      <String, Object?>{'cmd': 'key', 'key': 'enter'},
      <String, Object?>{'cmd': 'theme', 'mode': 'light'},
    ]) {
      expect(
        () => entry.PreparedSurfaceOperation.fromCommand(
          command, theme: 'dark',
        ),
        throwsFormatException,
      );
    }
    for (final String boundary in <String>['private', '', 'accepted']) {
      expect(
        () => entry.PreparedSurfaceOperation.fromCommand(
          <String, Object?>{'cmd': 'state'}, boundary: boundary,
        ),
        throwsFormatException,
      );
    }
  });

  test('prepared requests preserve failures and both ownership boundaries',
      () async {
    for (final int failedBoundary in <int>[0, 1, 2, -1]) {
      final _Unformattable originalFailure = _Unformattable();
      final List<entry.PreparedSurfaceOperation> operations =
          <entry.PreparedSurfaceOperation>[];
      int owners = 0;
      int requests = 0;
      final Map<String, dynamic> reply = <String, dynamic>{'private': true};
      final Future<Map<String, dynamic>> result = entry.preparedSurfaceRequest(
        <String, Object?>{'cmd': 'wait', 'key': 'home_hero'},
        request: (Map<String, Object?> command) async {
          requests++;
          if (failedBoundary == 1) throw originalFailure;
          return reply;
        },
        requireCurrent: () async {
          owners++;
          if (failedBoundary == 0 && owners == 1 ||
              failedBoundary == 2 && owners == 2) {
            throw originalFailure;
          }
        },
        onOperation: operations.add,
        theme: 'dark',
      );
      if (failedBoundary == -1) {
        expect(await result, same(reply));
      } else {
        await expectLater(result, throwsA(same(originalFailure)));
      }
      expect(requests, failedBoundary == 0 ? 0 : 1);
      expect(owners, failedBoundary == 0 || failedBoundary == 1 ? 1 : 2);
      expect(operations.last.boundary, switch (failedBoundary) {
        0 => 'ownerBefore', 1 => 'request', 2 => 'ownerAfter', _ => 'reply',
      });
      expect(jsonEncode(operations.last.toJson()), isNot(contains('private')));
    }
  });

  test('prepared failure labels belong only to the completed issuer catalog',
      () {
    final entry.PreparedSurfaceOperation operation =
        entry.PreparedSurfaceOperation.fromCommand(
          <String, Object?>{'cmd': 'state'}, theme: 'light',
        );
    const ScreenCaptureObservation complete =
        ScreenCaptureObservation(ScreenCaptureStep.complete);
    final Map<String, Object?> result = entry.restoredChildFailure(
      'seeded_capture', _Unformattable(), captureStep: complete,
      selection: RestoredSeedSelection.seededCatalog,
      surfaceOperation: operation,
    )!;
    expect(result['prepared_surface_operation'], operation.toJson());
    expect(result['kind'], 'OTHER_ERROR');
    for (final String phase in <String>['startup', 'seed_token', 'finish']) {
      expect(entry.restoredChildFailure(
        phase, _Unformattable(), captureStep: complete,
        selection: RestoredSeedSelection.seededCatalog,
        surfaceOperation: operation,
      ), isNull);
    }
    expect(entry.restoredChildFailure(
      'seeded_capture', _Unformattable(), captureStep: complete,
      selection: RestoredSeedSelection.stakeDraft,
      surfaceOperation: operation,
    ), isNull);
    expect(entry.restoredChildFailure(
      'seeded_capture', _Unformattable(),
      captureStep: const ScreenCaptureObservation(ScreenCaptureStep.scriptLine),
      selection: RestoredSeedSelection.seededCatalog,
      surfaceOperation: operation,
    ), isNull);
    expect(entry.restoredChildFailure(
      'seeded_capture', _Unformattable(),
      captureStep: const ScreenCaptureObservation(
        ScreenCaptureStep.complete, screen: 'private',
      ),
      selection: RestoredSeedSelection.seededCatalog,
      surfaceOperation: operation,
    ), isNull);
  });

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
          return skipped ? _view() : _view(
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
        return observations++ < 2 ? _view(
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
        return observations++ == 0 ? _view(
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

  test('restored startup requires one acknowledged visible target client',
      () async {
    Map<String, dynamic> window() => <String, dynamic>{
      'ok': true, 'clientMatched': true, 'client': <num>[1280, 780.0],
      'minimized': false, 'maximized': false,
    };
    final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
    await entry.showRestoredStartupWindow((Map<String, Object?> command) async {
      commands.add(command);
      return window();
    });
    expect(commands, <Map<String, Object?>>[
      <String, Object?>{
        'cmd': 'window', 'do': 'show', 'width': 1280, 'height': 780,
      },
    ]);
    final Map<String, List<Map<String, dynamic>>> invalid =
        <String, List<Map<String, dynamic>>>{
      'WINDOW_RESPONSE_REFUSED': <Map<String, dynamic>>[
        <String, dynamic>{'ok': false}, <String, dynamic>{'ok': 'true'},
      ],
      'WINDOW_CLIENT_REFUSED': <Map<String, dynamic>>[
        <String, dynamic>{'clientMatched': false},
        <String, dynamic>{'client': null},
        <String, dynamic>{'client': <num>[1280]},
        <String, dynamic>{'client': <Object>[true, 780]},
        <String, dynamic>{'client': <num>[double.nan, 780]},
        <String, dynamic>{'client': <num>[1279, 780]},
      ],
      'WINDOW_STATE_REFUSED': <Map<String, dynamic>>[
        <String, dynamic>{'minimized': true},
        <String, dynamic>{'maximized': true},
        <String, dynamic>{'minimized': null},
      ],
    };
    for (final MapEntry<String, List<Map<String, dynamic>>> group
        in invalid.entries) {
      for (final Map<String, dynamic> change in group.value) {
        int requests = 0;
        final Map<String, Object?> failed = await _failure(
          () => entry.showRestoredStartupWindow((_) async {
            requests++;
            return window()..addAll(change);
          }),
          'startup_window',
        );
        expect(requests, 1);
        expect(failed['kind'], 'WINDOW_REFUSED');
        expect(failed['code'], group.key);
        expect(failed['recipe'], isNull);
      }
    }
  });

  test('observe reads classify one original failure without exposing its text',
      () async {
    expect(entry.RestoredObserveOperation.values.map(
      (entry.RestoredObserveOperation value) => value.code).toSet(),
      entry.restoredObserveFailureCodes);
    for (final entry.RestoredObserveOperation operation
        in entry.RestoredObserveOperation.values) {
      int reads = 0;
      Object? failure;
      try {
        await entry.restoredObserveRead<void>(operation, () async {
          reads++;
          throw const FormatException('fixture-sensitive-text');
        });
      } on Object catch (error) {
        failure = error;
      }
      expect(reads, 1);
      expect(failure, isA<FormatException>());
      final Map<String, Object?> marker =
          entry.restoredChildFailure('observe', failure!)!;
      expect(marker['kind'], 'FORMAT_ERROR');
      expect(marker['code'], operation.code);
      expect(jsonEncode(marker), isNot(contains('fixture-sensitive-text')));
      expect(entry.restoredChildFailure('seed_stake', failure)?['code'],
        isNull);
      Object? nested;
      try {
        await entry.restoredObserveRead<void>(
          entry.RestoredObserveOperation.state,
          () => Future<void>.error(failure!));
      } on Object catch (error) {
        nested = error;
      }
      expect(nested, same(failure));
    }
    int reads = 0;
    expect(await entry.restoredObserveRead<int>(
      entry.RestoredObserveOperation.state, () async {
        reads++;
        return 7;
      }), 7);
    expect(reads, 1);
    final Object original = _Unformattable();
    Object? observed;
    try {
      await entry.restoredObserveRead<void>(
        entry.RestoredObserveOperation.state,
        () => Future<void>.error(original));
    } on Object catch (error) {
      observed = error;
    }
    expect(observed, same(original));
  });

  test('observe conditions and parsing keep their original refusal scope', () {
    for (final entry.RestoredObserveOperation operation
        in entry.RestoredObserveOperation.values) {
      entry.requireRestoredObserve(condition: true, operation: operation);
      Object? failure;
      try {
        entry.requireRestoredObserve(condition: false, operation: operation);
      } on Object catch (error) {
        failure = error;
      }
      expect(entry.restoredChildFailure('observe', failure!)?['code'],
        operation.code);
    }
    int parses = 0;
    Object? failure;
    try {
      entry.restoredObserveValue<void>(
        entry.RestoredObserveOperation.addressContext, () {
          parses++;
          throw const FormatException('fixture-sensitive-value');
        });
    } on Object catch (error) {
      failure = error;
    }
    expect(parses, 1);
    expect(entry.restoredChildFailure('observe', failure!)?['code'],
      'OBSERVE_ADDRESS_CONTEXT_FORMAT');
    expect(entry.restoredObserveValue<int>(
      entry.RestoredObserveOperation.addressContext, () => 8), 8);
    expect(entry.restoredChildFailure('observe',
      const FormatException('fixture-sensitive-value'))?['code'], isNull);
  });

  test('child failures export fixed types and validated recipe labels only',
      () async {
    final Map<String, String> diagnostic = <String, String>{
      'action': 'observe', 'control': 'none',
      'reason': 'wallet-recipe-refused',
      'entry': 'startup-before-initialization',
      'startup': 'key-confirmed', 'film': 'skip-middle-frame-pending',
    };
    final Map<String, Object?> original = entry.restoredChildFailure(
      'startup',
      WalletRecipeRefused('wallet-recipe-restored-lock-required',
        diagnostic: diagnostic),
    )!;
    expect(original['code'], 'wallet-recipe-restored-lock-required');
    expect(original['recipe'], diagnostic);
    final Map<String, Object?> unknown = entry.restoredChildFailure(
      'startup', WalletRecipeRefused('private',
        diagnostic: <String, String>{...diagnostic, 'private': 'private'}),
    )!;
    expect(unknown['code'], isNull);
    expect(unknown['recipe'], isNull);
    final Map<String, Object> errors = <String, Object>{
      'HARNESS_REFUSED': cli.Fail('private'),
      'FORMAT_ERROR': const FormatException('private'),
      'STATE_ERROR': StateError('private'),
      'OS_ERROR': const FileSystemException('private', 'private'),
      'TYPE_ERROR': _typeError(),
      'OTHER_ERROR': _Unformattable(),
    };
    for (final MapEntry<String, Object> value in errors.entries) {
      final Map<String, Object?> failure =
          entry.restoredChildFailure('startup', value.value)!;
      expect(failure['kind'], value.key);
      expect(failure['code'], isNull);
      expect(failure['recipe'], isNull);
      expect(jsonEncode(failure), isNot(contains('private')));
    }
    expect(entry.restoredChildFailure('private', _Unformattable()), isNull);
    final Map<String, List<String>> expected = <String, List<String>>{
      'UNLOCK_STATE_REFUSED': <String>['state'],
      'UNLOCK_LOCK_REQUIRED': <String>['state'],
      'UNLOCK_FIELD_READY_REFUSED': <String>['state', 'wait'],
      'UNLOCK_TYPE_REFUSED': <String>['state', 'wait', 'type'],
      'UNLOCK_TAP_REFUSED': <String>['state', 'wait', 'type', 'tap'],
      'UNLOCK_WAIT_REFUSED': <String>[
        'state', 'wait', 'type', 'tap', 'state', 'tree',
      ],
      'UNLOCK_FAILURE_TREE_REFUSED': <String>[
        'state', 'wait', 'type', 'tap', 'state', 'tree',
      ],
    };
    expect(expected.keys.toSet(), entry.restoredUnlockFailureCodes);
    for (final MapEntry<String, List<String>> item in expected.entries) {
      final _UnlockInstance instance = _UnlockInstance(item.key);
      final Map<String, Object?> failure = await _failure(
        () => entry.unlockRestoredWallet(
          instance,
          'synthetic-private-password',
        ),
        'unlock',
      );
      expect(instance.commands, item.value);
      expect(failure['kind'], 'HARNESS_REFUSED');
      expect(failure['code'], item.key);
      expect(failure['recipe'], isNull);
      expect(jsonEncode(failure), isNot(contains('private')));
    }
    final _UnlockInstance positive = _UnlockInstance(null);
    await entry.unlockRestoredWallet(positive, 'synthetic-private-password');
    expect(positive.commands, <String>[
      'state', 'wait', 'type', 'tap', 'state',
    ]);
  });

  test('closed lock observations reject private fields and invalid values', () {
    final Map<String, Object?> view = <String, Object?>{
      for (final String key in lockViewBooleanFields) key: false,
      'password_failures': 0, 'lifecycle': 'unknown',
    };
    final Map<String, Object?> value = <String, Object?>{
      'schema': 1, 'status': 'observed', 'owner_same': true, 'view': view,
    };
    expect(projectLockView(value), value);
    expect(projectLockView(<String, Object?>{...value, 'ok': true}), value);
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'private': 'private'},
      <String, Object?>{'schema': true},
      <String, Object?>{'status': 'private'},
      <String, Object?>{'owner_same': false},
      <String, Object?>{'ok': false},
      <String, Object?>{'view': null},
      for (final Map<String, Object?> invalid in <Map<String, Object?>>[
        <String, Object?>{'private': 'private'},
        <String, Object?>{'busy': 1},
        <String, Object?>{'password_failures': true},
        <String, Object?>{'password_failures': -1},
        <String, Object?>{'password_failures': 256},
        <String, Object?>{'lifecycle': 'private'},
      ]) <String, Object?>{'view': <String, Object?>{...view, ...invalid}},
    ]) {
      expect(projectLockView(<String, Object?>{...value, ...change}), isNull);
    }
    for (final String status in lockViewStatuses.difference(
      <String>{'observed'},
    )) {
      expect(projectLockView(<String, Object?>{
        'schema': 1, 'status': status, 'owner_same': false, 'view': null,
      }), isNotNull);
    }
  });

  test('passive lock diagnostics cannot retry or replace an unlock refusal',
      () async {
    for (final Object? view in <Object?>[
      null,
      <String, Object?>{'ok': true, 'private': 'private'},
      <String, Object?>{
        'ok': true, 'schema': 1, 'status': 'observed', 'owner_same': true,
        'view': <String, Object?>{
          for (final String key in lockViewBooleanFields) key: false,
          'password_failures': 0, 'lifecycle': 'inactive',
        },
      },
    ]) {
      final _UnlockInstance instance = _UnlockInstance(
        'UNLOCK_WAIT_REFUSED', lockView: view,
      );
      final Map<String, Object?> failure = await _failure(
        () => entry.unlockRestoredWallet(
          instance, 'synthetic-private-password', observeView: true,
        ), 'unlock',
      );
      expect(instance.commands, <String>[
        'lock-view', 'state', 'wait', 'type', 'tap', 'state', 'tree',
        'lock-view',
      ]);
      expect(failure['code'], 'UNLOCK_WAIT_REFUSED');
      expect(failure['kind'], 'HARNESS_REFUSED');
      expect(jsonEncode(failure), isNot(contains('private')));
      final Map<String, Object?>? projected = projectLockView(view);
      expect(failure['lock_view'], projected);
    }
  });

  test('failed restored wait retains its last labels and cannot adopt lock',
      () async {
    final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
    bool laterLock = false;
    final WalletRecipe driver = WalletRecipe(
      send: (Map<String, Object?> command, Duration _) async {
        commands.add(command);
        if (command['action'] != 'observe') {
          return <String, dynamic>{'ok': true, 'acted': true};
        }
        return laterLock ? _view() : _view(
          phase: 'startup-before-initialization',
          film: 'skip-middle-frame-pending', hint: true);
      },
      wait: (Duration _) async {},
    );
    final Map<String, Object?> failed = await _failure(
      driver.settleRestoredStartup, 'startup');
    expect(failed['code'], 'wallet-recipe-restored-lock-required');
    final Map<String, String> labels = failed['recipe']! as Map<String, String>;
    expect(labels['entry'], 'startup-before-initialization');
    expect(labels['film'], 'skip-middle-frame-pending');
    expect(labels['startup'], 'key-confirmed');
    expect(commands.where((Map<String, Object?> c) =>
      c['action'] != 'observe').map((Map<String, Object?> c) => c['key']),
      <String>['launch_skip_hint']);
    final int originalRequests = commands.length;
    laterLock = true;
    expect((await _failure(driver.settleRestoredStartup, 'startup'))['code'],
      'wallet-recipe-retired');
    expect(commands.length, originalRequests);
  });
}
