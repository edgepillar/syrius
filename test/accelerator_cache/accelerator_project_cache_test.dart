import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zenon_syrius_wallet_flutter/services/accelerator_project_cache.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'fake_node.dart';

/// One opening of the page: a cache with nothing in memory, as after a
/// restart of the wallet, over what [store] kept.
Future<List<AcceleratorCacheEvent>> open(
  FakeNode node,
  AcceleratorProjectStore store,
) {
  node.resetCounts();
  return AcceleratorProjectCache(
    store: store,
    node: () => node.zenon,
  ).load().toList();
}

List<Project> shown(List<AcceleratorCacheEvent> events) =>
    (events.last as AcceleratorProjectsLoaded).projects;

Project byId(List<Project> projects, String id) =>
    projects.firstWhere((Project project) => project.id.toString() == id);

List<String> idsOf(List<Project> projects) =>
    projects.map((Project project) => project.id.toString()).toList();

void main() {
  late FakeNode node;
  late MemoryStore store;

  // Four projects, one of each kind the cache tells apart.
  late String voting;
  late String inPhase;
  late String waiting;
  late String closed;

  setUp(() {
    node = FakeNode();
    store = MemoryStore();
    voting = node.createProject('voting');
    inPhase = node.createProject('in phase');
    waiting = node.createProject('waiting');
    closed = node.createProject('closed');
    node
      ..update(accept: <String>[inPhase, waiting], close: <String>[closed])
      ..addPhase(inPhase, 'one');
  });

  group('cold start', () {
    test('reads everything once and stores it with a snapshot', () async {
      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(events, hasLength(1));
      final AcceleratorProjectsLoaded loaded =
          events.single as AcceleratorProjectsLoaded;
      expect(loaded.fromCache, isFalse);
      expect(loaded.height, node.blocks.length);
      expect(idsOf(loaded.projects), node.order);
      expect(node.calls, <String, int>{
        'getMomentumsByHeight': 1,
        'getAccountBlocksByPage': 1,
        'getAll': 1,
      });

      final Map<String, dynamic> entry =
          jsonDecode(store.entries['321:${node.genesis}']!)
              as Map<String, dynamic>;
      expect(entry['height'], node.blocks.length);
      expect(entry['hash'], node.blocks.last['hash']);
      expect(entry['projects'], hasLength(4));
    });

    test('a contract with no block yet has snapshot 0', () async {
      final FakeNode empty = FakeNode(genesis: 'empty');
      expect(shown(await open(empty, store)), isEmpty);

      final String first = empty.createProject('first');
      final List<AcceleratorCacheEvent> events = await open(empty, store);

      expect(idsOf(shown(events)), <String>[first]);
      expect(empty.calls['getAll'], isNull);
    });
  });

  group('warm start', () {
    setUp(() => open(node, store));

    test('paints the stored list first and asks for no list', () async {
      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(events, hasLength(2));
      final AcceleratorProjectsLoaded first =
          events.first as AcceleratorProjectsLoaded;
      expect(first.fromCache, isTrue);
      expect(idsOf(first.projects), node.order);
      expect((events.last as AcceleratorProjectsLoaded).fromCache, isFalse);
      // The chain, then the blocks since the snapshot: none.
      expect(node.calls, <String, int>{
        'getMomentumsByHeight': 1,
        'getAccountBlocksByHeight': 1,
      });
      expect(store.writes, 1, reason: 'nothing changed, nothing rewritten');
    });

    test('a project created since appears', () async {
      final String created = node.createProject('new');

      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(
        idsOf((events.first as AcceleratorProjectsLoaded).projects),
        isNot(contains(created)),
      );
      expect(byId(shown(events), created).name, 'new');
      expect(idsOf(shown(events)), node.order);
      expect(node.calls['getAll'], isNull);
      expect(node.fetched, contains(created));
    });

    test('a phase added to a waiting project is read', () async {
      node.update(pay: <String>[inPhase]);
      await open(node, store);
      final String phase = node.addPhase(waiting, 'first');

      final List<AcceleratorCacheEvent> events = await open(node, store);

      final Project project = byId(shown(events), waiting);
      expect(project.phases.single.id.toString(), phase);
      expect(node.fetched.toSet(), <String>{voting, waiting});
      expect(node.calls['getAll'], isNull);
    });

    test('a replaced phase is read, and a vote on the new one', () async {
      final String phase = node.updatePhase(inPhase, 'one again');
      node.vote(phase);

      final List<AcceleratorCacheEvent> events = await open(node, store);

      final Phase got = byId(shown(events), inPhase).phases.single;
      expect(got.id.toString(), phase);
      expect(got.name, 'one again');
      expect(got.voteBreakdown.yes, 1);
    });

    test('a vote on a closed project moves its tally', () async {
      node
        ..vote(closed)
        ..vote(closed, byName: false);

      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(byId(shown(events), closed).voteBreakdown.yes, 2);
      expect(node.fetched.toSet(), <String>{voting, inPhase, closed});
    });

    test('what an Update can move is read after any block; '
        'what it cannot is not', () async {
      // No block names these two, and both moved.
      node.update(accept: <String>[voting], pay: <String>[inPhase]);
      // Changed behind the cache's back, which the contract never does:
      // had the cache read them again, it would show.
      node.projects[waiting]!['name'] = 'never read';
      node.projects[closed]!['name'] = 'never read';

      final List<AcceleratorCacheEvent> events = await open(node, store);

      final List<Project> projects = shown(events);
      expect(byId(projects, voting).status, AcceleratorProjectStatus.active);
      expect(
        byId(projects, inPhase).phases.single.status,
        AcceleratorProjectStatus.paid,
      );
      expect(byId(projects, waiting).name, 'waiting');
      expect(byId(projects, closed).name, 'closed');
      expect(node.fetched.toSet(), <String>{voting, inPhase});
      expect(node.calls, <String, int>{
        'getMomentumsByHeight': 1,
        'getAccountBlocksByHeight': 1,
        'getProjectById': 2,
      });
    });

    test('a donation alone still has the unsettled read', () async {
      node.donate();

      await open(node, store);

      expect(node.fetched.toSet(), <String>{voting, inPhase});
    });

    test('the snapshot advances, so blocks are looked at once', () async {
      node.createProject('new');
      await open(node, store);

      await open(node, store);

      expect(node.calls, <String, int>{
        'getMomentumsByHeight': 1,
        'getAccountBlocksByHeight': 1,
      });
    });

    test('a long gap is followed page by page', () async {
      for (int i = 0; i < AcceleratorProjectCache.blockPageSize + 10; i += 1) {
        node.donate();
      }
      final String created = node.createProject('late');

      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(idsOf(shown(events)), contains(created));
      expect(node.calls['getAccountBlocksByHeight'], 2);
      expect(node.calls['getAll'], isNull);
    });

    test('coming back in one session reads no disk', () async {
      final AcceleratorProjectCache cache = AcceleratorProjectCache(
        store: store,
        node: () => node.zenon,
      );
      await cache.load().drain<void>();
      store.entries.clear();

      final List<AcceleratorCacheEvent> events = await cache.load().toList();

      expect((events.first as AcceleratorProjectsLoaded).fromCache, isTrue);
    });
  });

  group('another chain', () {
    setUp(() => open(node, store));

    test('another chain id has its own cache', () async {
      final FakeNode mainnet = FakeNode(chainId: 1);
      final String other = mainnet.createProject('mainnet');

      final List<AcceleratorCacheEvent> events = await open(mainnet, store);

      expect(events, hasLength(1), reason: 'nothing of chain 321 is shown');
      expect(idsOf(shown(events)), <String>[other]);
      expect(mainnet.calls['getAll'], 1);
      expect(store.entries.keys, hasLength(2));

      final List<AcceleratorCacheEvent> back = await open(node, store);
      expect((back.first as AcceleratorProjectsLoaded).fromCache, isTrue);
      expect(idsOf(shown(back)), node.order);
      expect(node.calls['getAll'], isNull);
    });

    test('the first momentum is never asked for on a longer chain', () async {
      // It lists every genesis account: 2 MB on mainnet, a quarter of a
      // second to decode, which the SDK does on the calling isolate. Asked
      // for on each opening of the page, it froze the window that long.
      await open(node, store);
      expect(node.momentumsAsked, <int>[2]);
    });

    test('a chain one momentum long is still told by its genesis', () async {
      final FakeNode young = FakeNode(genesis: 'young')..momentums = 1;

      await open(young, store);

      expect(store.entries.keys, contains('321:${young.genesis}'));
      expect(young.calls['getMomentumsByHeight'], 2);
    });

    test('another genesis under the same id has its own cache', () async {
      final FakeNode devnet = FakeNode(genesis: 'another devnet');
      final String other = devnet.createProject('devnet');

      final List<AcceleratorCacheEvent> events = await open(devnet, store);

      expect(events, hasLength(1));
      expect(idsOf(shown(events)), <String>[other]);
      expect(store.entries.keys, hasLength(2));
    });

    test('a snapshot ahead of the node drops the cache', () async {
      // The node lost its last block: resynced, or rolled back.
      node.blocks.removeLast();
      node.projects[inPhase]!['phases'] = <Map<String, dynamic>>[];
      node.projects[inPhase]!['phaseIds'] = <String>[];

      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(events, hasLength(3));
      expect(events[1], isA<AcceleratorCacheDropped>());
      expect(byId(shown(events), inPhase).phases, isEmpty);
      expect(node.calls['getAll'], 1);
      final Map<String, dynamic> entry =
          jsonDecode(store.entries.values.single) as Map<String, dynamic>;
      expect(entry['height'], node.blocks.length);
    });

    test('another block at the snapshot height drops the cache', () async {
      node.rewriteFrom(node.blocks.length);

      final List<AcceleratorCacheEvent> events = await open(node, store);

      expect(events[1], isA<AcceleratorCacheDropped>());
      expect(node.calls['getAll'], 1);
    });

    test('a dropped cache is gone even if the full read fails', () async {
      node
        ..blocks.removeLast()
        ..failGetAll = Exception('down');

      final List<AcceleratorCacheEvent> events = <AcceleratorCacheEvent>[];
      await expectLater(
        AcceleratorProjectCache(
          store: store,
          node: () => node.zenon,
        ).load().forEach(events.add),
        throwsException,
      );

      expect(events.last, isA<AcceleratorCacheDropped>());
      expect(store.entries, isEmpty);
    });
  });

  group('falls back to the full read', () {
    setUp(() => open(node, store));

    Future<void> expectFullRead() async {
      final List<AcceleratorCacheEvent> events = await open(node, store);
      expect(events, hasLength(2));
      expect(events.every((AcceleratorCacheEvent e) =>
          e is AcceleratorProjectsLoaded), isTrue);
      expect(idsOf(shown(events)), node.order);
      expect(node.calls['getAll'], 1);
      // And the next opening is incremental again.
      await open(node, store);
      expect(node.calls['getAll'], isNull);
    }

    test('when a project will not load', () async {
      node
        ..createProject('new')
        ..failProjectById = Exception('data non existent');
      await expectFullRead();
    });

    test('on a call it does not know', () async {
      node.unknownCall();
      await expectFullRead();
    });

    test('on a receive block with no send', () async {
      node
        ..donate()
        ..blocks.last['pairedAccountBlock'] = null;
      await expectFullRead();
    });

    test('when the gap is too long', () async {
      final int blocks =
          AcceleratorProjectCache.blockPageSize *
          AcceleratorProjectCache.maxBlockPages;
      for (int i = 0; i < blocks; i += 1) {
        node.donate();
      }
      await expectFullRead();
    });

    test('when too many projects would be read one by one', () async {
      for (int i = 0; i <= AcceleratorProjectCache.maxRefetch; i += 1) {
        node.createProject('p$i');
      }
      await expectFullRead();
      expect(node.calls['getProjectById'], isNull);
    });

    test('on a stored entry it cannot read', () async {
      store.entries[store.entries.keys.single] = '{not json';
      final List<AcceleratorCacheEvent> events = await open(node, store);
      expect(events, hasLength(1));
      expect(idsOf(shown(events)), node.order);
      expect(node.calls['getAll'], 1);
    });

    test('on an entry of another version', () async {
      final String key = store.entries.keys.single;
      final Map<String, dynamic> entry =
          jsonDecode(store.entries[key]!) as Map<String, dynamic>;
      entry['version'] = 0;
      store.entries[key] = jsonEncode(entry);
      final List<AcceleratorCacheEvent> events = await open(node, store);
      expect(events, hasLength(1));
      expect(node.calls['getAll'], 1);
    });

    test('a store that fails is not the reason the page is empty', () async {
      final List<AcceleratorCacheEvent> events =
          await AcceleratorProjectCache(
            store: _BrokenStore(),
            node: () => node.zenon,
          ).load().toList();
      expect(idsOf(shown(events)), node.order);
    });

    test('with the list shown, a node that stops answering leaves an '
        'error after it', () async {
      node
        ..createProject('new')
        ..failProjectById = Exception('down')
        ..failGetAll = Exception('down');

      final List<AcceleratorCacheEvent> events = <AcceleratorCacheEvent>[];
      await expectLater(
        AcceleratorProjectCache(
          store: store,
          node: () => node.zenon,
        ).load().forEach(events.add),
        throwsException,
      );

      expect((events.single as AcceleratorProjectsLoaded).fromCache, isTrue);
      expect(store.entries, hasLength(1), reason: 'the entry is still good');
    });
  });

  group('settled', () {
    test('is what an Update passes over', () async {
      node
        ..update(pay: <String>[inPhase])
        ..addPhase(inPhase, 'two');
      final String paid = node.createProject('paid');
      node
        ..update(accept: <String>[paid])
        ..addPhase(paid, 'only')
        ..update(pay: <String>[paid]);
      final List<Project> projects = shown(await open(node, store));
      bool settled(String id) =>
          AcceleratorProjectCache.isSettled(byId(projects, id));

      expect(settled(voting), isFalse);
      expect(settled(inPhase), isFalse, reason: 'last phase in voting');
      expect(settled(waiting), isTrue, reason: 'accepted, no phase');
      expect(settled(paid), isTrue, reason: 'accepted, last phase paid');
      expect(settled(closed), isTrue);
    });
  });

  group('AcceleratorCall', () {
    final Hash id = Hash.parse(FakeNode.hashOf('id'));

    test('reads the id out of the calls that name one', () {
      for (final String method in <String>['AddPhase', 'UpdatePhase']) {
        final AcceleratorCall call = AcceleratorCall.of(
          Definitions.accelerator.encodeFunction(method, <dynamic>[
            id.getBytes(),
            'a name long enough to spill past one word of the encoding',
            'd',
            'u.io',
            BigInt.one,
            BigInt.two,
          ]),
        );
        expect(call.kind, AcceleratorCallKind.phase);
        expect(call.id, id.toString());
      }
      final AcceleratorCall byName = AcceleratorCall.of(
        Definitions.accelerator.encodeFunction('VoteByName', <dynamic>[
          id.getBytes(),
          'pillar',
          1,
        ]),
      );
      expect(byName.kind, AcceleratorCallKind.vote);
      expect(byName.id, id.toString());
      final AcceleratorCall byAddress = AcceleratorCall.of(
        Definitions.accelerator.encodeFunction('VoteByProdAddress', <dynamic>[
          id.getBytes(),
          2,
        ]),
      );
      expect(byAddress.kind, AcceleratorCallKind.vote);
      expect(byAddress.id, id.toString());
    });

    test('tells the calls that name nothing from those it does not '
        'know', () {
      expect(
        AcceleratorCall.of(
          Definitions.accelerator.encodeFunction('CreateProject', <dynamic>[
            'n',
            'd',
            'u.io',
            BigInt.one,
            BigInt.two,
          ]),
        ).kind,
        AcceleratorCallKind.createProject,
      );
      for (final String method in <String>['Update', 'Donate']) {
        expect(
          AcceleratorCall.of(
            Definitions.common.encodeFunction(method, <dynamic>[]),
          ).kind,
          AcceleratorCallKind.none,
        );
      }
      expect(
        AcceleratorCall.of(
          Definitions.common.encodeFunction('CollectReward', <dynamic>[]),
        ).kind,
        AcceleratorCallKind.unknown,
      );
      expect(
        AcceleratorCall.of(const <int>[]).kind,
        AcceleratorCallKind.unknown,
      );
      expect(
        AcceleratorCall.of(
          Definitions.common
              .encodeFunction('VoteByName', <dynamic>[id.getBytes(), 'p', 0])
              .sublist(0, 20),
        ).kind,
        AcceleratorCallKind.unknown,
      );
    });
  });

  group('stored shape', () {
    test('a project reads back as the node sent it', () async {
      node
        ..vote(inPhase)
        ..vote((node.projects[inPhase]!['phaseIds'] as List<String>).single);
      for (final Map<String, dynamic> sent in node.projects.values) {
        final Map<String, dynamic> wire =
            jsonDecode(jsonEncode(sent)) as Map<String, dynamic>;
        expect(
          AcceleratorProjectCache.projectToJson(Project.fromJson(wire)),
          wire,
        );
      }
    });
  });

  group('in Hive', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('syrius_az_cache_');
      Hive.init(directory.path);
    });

    tearDown(() async {
      await Hive.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('survives every box being closed under it', () async {
      final HiveAcceleratorProjectStore hive = HiveAcceleratorProjectStore();
      await open(node, hive);
      // What wiping the wallet's cache does before it reopens boxes.
      await Hive.close();
      node.createProject('new');

      final List<AcceleratorCacheEvent> events = await open(node, hive);

      expect((events.first as AcceleratorProjectsLoaded).fromCache, isTrue);
      expect(idsOf(shown(events)), node.order);
      expect(node.calls['getAll'], isNull);
    });
  });
}

class _BrokenStore implements AcceleratorProjectStore {
  @override
  Future<String?> read(String key) => throw const FileSystemException('read');

  @override
  Future<void> write(String key, String value) =>
      throw const FileSystemException('write');

  @override
  Future<void> delete(String key) =>
      throw const FileSystemException('delete');
}
