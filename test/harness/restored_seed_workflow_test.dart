import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/fixtures/seed_policy.dart';
import '../../harness/bin/ci_wallet_reopen.dart' as reopen;
import '../../harness/bin/harness.dart' as cli;
import '../../harness/seed/restored_seed_workflow.dart';
import '../../harness/wallet_address_context.dart';

WalletAddressContext _context({
  int count = 2, int revision = 20, int owner = 1,
}) =>
    WalletAddressContext.parse(<String, dynamic>{
      'members': List<String>.generate(count, (int i) => 'synthetic-member-$i'),
      'selected': 'synthetic-member-1', 'saved': 'synthetic-member-1',
      'revision': revision, 'owner': owner,
    });

String _hash(int value) => List<String>.filled(64, '$value').join();

final class _Session {
  final WalletAddressContext original = _context();
  WalletAddressContext current = _context();
  final List<String> started = <String>[];
  bool alive = true;
  int preparations = 0;
  Future<void> Function()? duringRecipe;
  bool wrongDerivation = false;
  bool dieDuringPreparation = false;
  bool duplicateHash = false;
  Map<String, Object?> receiptChange = <String, Object?>{};

  RestoredSeedWorkflow workflow() => RestoredSeedWorkflow(
    original: original, parentAlive: () => alive,
    observe: () async => current,
    prepareAddress: (WalletAddressContext before) async {
      expect(before.same(original), isTrue);
      preparations++;
      current = _context(count: 3,
        revision: wrongDerivation ? 22 : 21);
      if (dieDuringPreparation) alive = false;
      return current;
    },
    recipe: (String id, Future<void> Function() check) async {
      await check();
      started.add(id);
      await duringRecipe?.call();
      return <String, dynamic>{
        'ok': true, 'confirmed': true, 'recipe': id,
        'hash': _hash(duplicateHash ? 1 : started.length), ...receiptChange,
      };
    },
  );
}

class _UnprintableSeedError implements Exception {
  @override
  String toString() => throw StateError('synthetic-private-value');
}

void main() {
  test('one derived member precedes six exact ordered original receipts',
      () async {
    final _Session session = _Session();
    final Map<String, Object> result = await session.workflow().run(
      'synthetic-external-member',
    );
    expect(session.preparations, 1);
    expect(session.started, seedRecipeIds.toList());
    expect(result['members'], 3);
    expect(result['receipts'], hasLength(6));
    expect(result.toString(), isNot(contains('synthetic-member')));
  });

  test('a replaced initial owner receives no Settings or recipe input',
      () async {
    final _Session session = _Session()..current = _context(owner: 2);
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 0);
    expect(session.started, isEmpty);
  });

  test('an unrelated generation cannot admit the first seed recipe', () async {
    final _Session session = _Session()..wrongDerivation = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, isEmpty);
  });

  test('parent EOF during derivation admits no seed publication', () async {
    final _Session session = _Session()..dieDuringPreparation = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, isEmpty);
  });

  test('wrong recipe, unknown outcome and invalid hash hold later recipes',
      () async {
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'recipe': 'fuse'},
      <String, Object?>{'confirmed': false},
      <String, Object?>{'hash': _hash(0)},
    ]) {
      final _Session session = _Session()..receiptChange = change;
      await expectLater(session.workflow().run('synthetic-external-member'),
        throwsA(isA<SeedRefused>()));
      expect(session.started, <String>['stake']);
    }
  });

  test('the same accepted hash cannot qualify two different seed effects',
      () async {
    final _Session session = _Session()..duplicateHash = true;
    await expectLater(session.workflow().run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.started, <String>['stake', 'fuse']);
  });

  test('a failed original is retained without another recipe or retry',
      () async {
    final _Session session = _Session()
      ..duringRecipe = () async { throw const FormatException('unknown'); };
    final RestoredSeedWorkflow workflow = session.workflow();
    await expectLater(workflow.run('synthetic-external-member'),
      throwsFormatException);
    session.duringRecipe = null;
    await expectLater(workflow.run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 1);
    expect(session.started, <String>['stake']);
  });

  test('a late result from a changed owner cannot start the next recipe',
      () async {
    final _Session session = _Session();
    final Completer<void> original = Completer<void>();
    session.duringRecipe = () => original.future;
    final Future<Map<String, Object>> result = session.workflow().run(
      'synthetic-external-member',
    );
    for (int turn = 0; turn < 10 && session.started.isEmpty; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(session.started, <String>['stake']);
    session.current = _context(count: 3, revision: 22);
    original.complete();
    await expectLater(result, throwsA(isA<SeedRefused>()));
    expect(session.started, <String>['stake']);
  });

  test('a successful session cannot derive or publish a second time',
      () async {
    final _Session session = _Session();
    final RestoredSeedWorkflow workflow = session.workflow();
    await workflow.run('synthetic-external-member');
    await expectLater(workflow.run('synthetic-external-member'),
      throwsA(isA<SeedRefused>()));
    expect(session.preparations, 1);
    expect(session.started, hasLength(6));
  });

  test('seed failure snapshots remain immutable after later observations', () {
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake');
    trace.at(cli.SeedOperationAction.check, cli.SeedOperationStep.owner,
        commandIndex: 2);
    final cli.SeedOperationFailure first = trace.failure(
      cli.Fail('synthetic-private-value'),
    );
    trace.at(cli.SeedOperationAction.command, cli.SeedOperationStep.execute,
        commandIndex: 9);
    expect(first.diagnostic['action'], 'check');
    expect(first.diagnostic['command_index'], 2);
    expect(() => first.diagnostic['command_index'] = 99,
        throwsUnsupportedError);
    expect(jsonEncode(first.diagnostic),
        isNot(contains('synthetic-private-value')));
  });

  test('seed failures retain only typed families without formatting errors',
      () {
    final List<(Object, String)> errors = <(Object, String)>[
      (cli.Fail('synthetic-private-value'), 'refused'),
      (const SeedRefused('exact-chain-321-lab-required'), 'refused'),
      (TimeoutException('synthetic-private-value'), 'timeout'),
      (const FormatException('synthetic-private-value'), 'format'),
      (RangeError('synthetic-private-value'), 'type'),
      (const FileSystemException('synthetic-private-value'), 'filesystem'),
      (StateError('synthetic-private-value'), 'state'),
      (_UnprintableSeedError(), 'other'),
    ];
    for (final (Object error, String kind) in errors) {
      final cli.SeedOperationFailure observed =
          cli.SeedOperationTrace('stake').failure(error);
      expect(observed.diagnostic['kind'], kind);
      expect(jsonEncode(observed.diagnostic),
          isNot(contains('synthetic-private-value')));
    }
  });

  test('seed reply codes use exact source labels and reject unknown material',
      () {
    final String code = cli.seedOperationReplyCodes.first;
    for (final String value in <String>[code, 'Seed refused: $code']) {
      final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake');
      trace.at(cli.SeedOperationAction.begin, cli.SeedOperationStep.reply);
      trace.refusedReply(value);
      expect(trace.failure(cli.Fail('synthetic-private-value'))
          .diagnostic['reason'], code);
    }
    for (final Object? value in <Object?>[
      null, true, 321, 'synthetic-private-value', '$code ',
      'Seed refused: synthetic-private-value', _UnprintableSeedError(),
    ]) {
      expect(cli.seedOperationReplyCode(value), 'unknown');
    }
  });

  test('publication entry describes the original call without acceptance', () {
    final cli.SeedOperationTrace trace = cli.SeedOperationTrace('stake');
    trace.at(cli.SeedOperationAction.publish, cli.SeedOperationStep.owner,
        commandIndex: 7);
    final cli.SeedOperationFailure before = trace.failure(cli.Fail('private'));
    trace.publicationCallEntered();
    trace.at(cli.SeedOperationAction.publish, cli.SeedOperationStep.request);
    final cli.SeedOperationFailure after = trace.failure(cli.Fail('private'));
    expect(before.diagnostic['publication_call_entered'], isFalse);
    expect(after.diagnostic['publication_call_entered'], isTrue);
    expect(after.diagnostic['command_index'], 7);
    for (final cli.SeedOperationFailure failure in <cli.SeedOperationFailure>[
      before, after,
    ]) {
      expect(failure.diagnostic.containsKey('confirmed'), isFalse);
      expect(failure.diagnostic.containsKey('hash'), isFalse);
      expect(failure.diagnostic.containsKey('retry'), isFalse);
    }
  });

  test('seed child metadata is phase-bound and never fills an older refusal',
      () {
    final cli.SeedOperationFailure failure =
        cli.SeedOperationTrace('stake').failure(cli.Fail('private'));
    final Map<String, Object?> observed =
        reopen.restoredChildFailure('seed_stake', failure)!;
    expect(observed['kind'], 'HARNESS_REFUSED');
    expect(observed['code'], isNull);
    expect(observed['recipe'], isNull);
    expect(observed['seed'], failure.diagnostic);
    expect(reopen.restoredChildFailure('unlock', failure), isNull);
    final cli.SeedOperationTrace foreign = cli.SeedOperationTrace('private');
    foreign.at(cli.SeedOperationAction.command, cli.SeedOperationStep.execute,
        commandIndex: 100000);
    final cli.SeedOperationFailure held = foreign.failure(cli.Fail('private'));
    expect(held.diagnostic['recipe'], 'unknown');
    expect(held.diagnostic['command_index'], 0);
    expect(reopen.restoredChildFailure('seed_stake', held), isNull);
    final Map<String, Object?> original = reopen.restoredChildFailure(
      'seed_stake', cli.Fail('private'),
    )!;
    expect(original, <String, Object?>{
      'schema': 1, 'scope': 'owned_reopen_child_failure',
      'phase': 'seed_stake', 'kind': 'HARNESS_REFUSED',
      'code': null, 'recipe': null,
    });
  });
}
