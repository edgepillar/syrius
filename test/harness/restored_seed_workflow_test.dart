import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/fixtures/seed_policy.dart';
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
}
