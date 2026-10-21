import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/services/accelerator_project_cache.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A node with an Accelerator contract that behaves as go-zenon's does, as
/// far as the cache can tell: every change to a project comes with a block
/// on the contract's account chain, an id is the hash of the block that
/// made it, and `Update` moves projects without naming them.
///
/// It counts the requests made of it, by method.
class FakeNode {
  FakeNode({this.chainId = 321, String genesis = 'genesis'})
    : genesis = hashOf(genesis) {
    zenon = _FakeZenon(this);
  }

  final int chainId;
  final String genesis;
  late final Zenon zenon;

  /// Requests made, by method name.
  final Map<String, int> calls = <String, int>{};

  /// The ids `getProjectById` was asked for, in order.
  final List<String> fetched = <String>[];

  /// The projects, in the node's JSON, by id.
  final Map<String, Map<String, dynamic>> projects =
      <String, Map<String, dynamic>>{};

  /// The contract's account chain, in the node's JSON; height is index + 1.
  final List<Map<String, dynamic>> blocks = <Map<String, dynamic>>[];

  /// The height of the momentum chain.
  int momentums = 100;

  /// The heights `getMomentumsByHeight` was asked for, in order.
  final List<int> momentumsAsked = <int>[];

  /// When set, `getProjectById` fails.
  Object? failProjectById;

  /// When set, `getAll` fails.
  Object? failGetAll;

  int _clock = 1000;
  int _nonce = 0;

  int get total => calls.values.fold(0, (int a, int b) => a + b);

  void resetCounts() {
    calls.clear();
    momentumsAsked.clear();
    fetched.clear();
  }

  static String hashOf(String text) =>
      Hash.digest(utf8.encode(text)).toString();

  String _newHash() => hashOf('h${_nonce += 1}/$genesis');

  // The contract's calls.

  /// A project in voting; returns its id.
  String createProject(String name) {
    final String id = _receive(
      Definitions.accelerator.encodeFunction('CreateProject', <dynamic>[
        name,
        'about $name',
        'zenon.network',
        BigInt.from(5000),
        BigInt.from(50000),
      ]),
    );
    projects[id] = <String, dynamic>{
      'id': id,
      'owner': pillarAddress.toString(),
      'name': name,
      'description': 'about $name',
      'url': 'zenon.network',
      'znnFundsNeeded': '5000',
      'qsrFundsNeeded': '50000',
      'creationTimestamp': _clock,
      'lastUpdateTimestamp': _clock,
      'status': AcceleratorProjectStatus.voting.index,
      'phaseIds': <String>[],
      'votes': _noVotes(id),
      'phases': <Map<String, dynamic>>[],
    };
    return id;
  }

  /// A phase in voting on [projectId]; returns the phase's id.
  String addPhase(String projectId, String name) {
    final String id = _receive(_phaseData('AddPhase', projectId, name));
    final Map<String, dynamic> project = projects[projectId]!;
    (project['phaseIds'] as List<String>).add(id);
    (project['phases'] as List<Map<String, dynamic>>).add(
      _phase(id, projectId, name),
    );
    project['lastUpdateTimestamp'] = _clock;
    return id;
  }

  /// Replaces the last phase of [projectId]; returns the new phase's id.
  String updatePhase(String projectId, String name) {
    final String id = _receive(_phaseData('UpdatePhase', projectId, name));
    final Map<String, dynamic> project = projects[projectId]!;
    (project['phaseIds'] as List<String>)
      ..removeLast()
      ..add(id);
    (project['phases'] as List<Map<String, dynamic>>)
      ..removeLast()
      ..add(_phase(id, projectId, name));
    return id;
  }

  /// A Pillar's yes on a project or a phase.
  void vote(String id, {bool byName = true}) {
    _receive(
      byName
          ? Definitions.common.encodeFunction('VoteByName', <dynamic>[
              Hash.parse(id).getBytes(),
              'pillar',
              0,
            ])
          : Definitions.common.encodeFunction('VoteByProdAddress', <dynamic>[
              Hash.parse(id).getBytes(),
              0,
            ]),
    );
    for (final Map<String, dynamic> project in projects.values) {
      final List<Map<String, dynamic>> tallies = <Map<String, dynamic>>[
        project['votes'] as Map<String, dynamic>,
        for (final Map<String, dynamic> phase
            in project['phases'] as List<Map<String, dynamic>>)
          phase['votes'] as Map<String, dynamic>,
      ];
      for (final Map<String, dynamic> tally in tallies) {
        if (tally['id'] == id) {
          tally['yes'] = (tally['yes'] as int) + 1;
          tally['total'] = (tally['total'] as int) + 1;
        }
      }
    }
  }

  /// The Pillars' `Update`: one block that names nothing. [accept] and
  /// [close] are projects in voting it settles; [pay] are projects whose
  /// last phase it pays.
  void update({
    List<String> accept = const <String>[],
    List<String> close = const <String>[],
    List<String> pay = const <String>[],
  }) {
    _receive(Definitions.common.encodeFunction('Update', <dynamic>[]));
    for (final String id in accept) {
      projects[id]!['status'] = AcceleratorProjectStatus.active.index;
      projects[id]!['lastUpdateTimestamp'] = _clock;
    }
    for (final String id in close) {
      projects[id]!['status'] = AcceleratorProjectStatus.closed.index;
    }
    for (final String id in pay) {
      final Map<String, dynamic> last =
          (projects[id]!['phases'] as List<Map<String, dynamic>>).last['phase']
              as Map<String, dynamic>;
      last['status'] = AcceleratorProjectStatus.paid.index;
      last['acceptedTimestamp'] = _clock;
      projects[id]!['lastUpdateTimestamp'] = _clock;
    }
  }

  /// A donation: a block that changes no project.
  void donate() =>
      _receive(Definitions.common.encodeFunction('Donate', <dynamic>[]));

  /// A block calling something the SDK's definitions do not hold.
  void unknownCall() => _receive(<int>[0xde, 0xad, 0xbe, 0xef, 1, 2, 3]);

  /// The same chain with its history replaced from [height] on, as after a
  /// rollback or a devnet rebuilt from the same genesis.
  void rewriteFrom(int height) {
    final int count = blocks.length - height + 1;
    blocks.removeRange(height - 1, blocks.length);
    for (int i = 0; i < count; i += 1) {
      donate();
    }
  }

  String _receive(List<int> data) {
    _clock += 10;
    final String sendHash = _newHash();
    final Map<String, dynamic> send = _block(
      hash: sendHash,
      height: 1,
      type: BlockTypeEnum.userSend,
      data: data,
    );
    blocks.add(
      _block(
        hash: _newHash(),
        height: blocks.length + 1,
        type: BlockTypeEnum.contractReceive,
        data: const <int>[],
        paired: send,
      ),
    );
    return sendHash;
  }

  Map<String, dynamic> _block({
    required String hash,
    required int height,
    required BlockTypeEnum type,
    required List<int> data,
    Map<String, dynamic>? paired,
  }) => <String, dynamic>{
    'version': 1,
    'chainIdentifier': chainId,
    'blockType': type.index,
    'hash': hash,
    'previousHash': emptyHash.toString(),
    'height': height,
    'momentumAcknowledged': <String, dynamic>{
      'hash': emptyHash.toString(),
      'height': 1,
    },
    'address': pillarAddress.toString(),
    'toAddress': acceleratorAddress.toString(),
    'amount': '0',
    'tokenStandard': znnZts.toString(),
    'fromBlockHash': emptyHash.toString(),
    'data': base64.encode(data),
    'fusedPlasma': 0,
    'difficulty': 0,
    'nonce': '',
    'publicKey': null,
    'signature': null,
    'descendantBlocks': <dynamic>[],
    'basePlasma': 0,
    'usedPlasma': 0,
    'changesHash': emptyHash.toString(),
    'token': null,
    'confirmationDetail': null,
    'pairedAccountBlock': paired,
  };

  List<int> _phaseData(String method, String projectId, String name) =>
      Definitions.accelerator.encodeFunction(method, <dynamic>[
        Hash.parse(projectId).getBytes(),
        name,
        'about $name',
        'zenon.network',
        BigInt.from(100),
        BigInt.from(1000),
      ]);

  Map<String, dynamic> _phase(String id, String projectId, String name) =>
      <String, dynamic>{
        'phase': <String, dynamic>{
          'id': id,
          'projectID': projectId,
          'name': name,
          'description': 'about $name',
          'url': 'zenon.network',
          'znnFundsNeeded': '100',
          'qsrFundsNeeded': '1000',
          'creationTimestamp': _clock,
          'acceptedTimestamp': 0,
          'status': AcceleratorProjectStatus.voting.index,
        },
        'votes': _noVotes(id),
      };

  static Map<String, dynamic> _noVotes(String id) => <String, dynamic>{
    'id': id,
    'yes': 0,
    'no': 0,
    'total': 0,
  };

  /// The ids in the order `getAll` lists them: last update first, over the
  /// storage's id order.
  List<String> get order {
    final List<String> ids = projects.keys.toList()..sort();
    final List<String> sorted = <String>[];
    final List<int> stamps =
        ids
            .map((String id) => projects[id]!['lastUpdateTimestamp'] as int)
            .toSet()
            .toList()
          ..sort((int a, int b) => b.compareTo(a));
    for (final int stamp in stamps) {
      sorted.addAll(
        ids.where(
          (String id) => projects[id]!['lastUpdateTimestamp'] == stamp,
        ),
      );
    }
    return sorted;
  }

  void _count(String method) => calls[method] = (calls[method] ?? 0) + 1;
}

class _FakeZenon extends Fake implements Zenon {
  _FakeZenon(FakeNode node)
    : ledger = _FakeLedger(node),
      embedded = _FakeEmbedded(node);

  @override
  LedgerApi ledger;

  @override
  EmbeddedApi embedded;
}

class _FakeEmbedded extends Fake implements EmbeddedApi {
  _FakeEmbedded(FakeNode node) : accelerator = _FakeAccelerator(node);

  @override
  AcceleratorApi accelerator;
}

class _FakeLedger extends Fake implements LedgerApi {
  _FakeLedger(this.node);

  final FakeNode node;

  @override
  Future<MomentumList> getMomentumsByHeight(int height, int count) async {
    node._count('getMomentumsByHeight');
    node.momentumsAsked.add(height);
    if (height > node.momentums) {
      return MomentumList.fromJson(<String, dynamic>{
        'count': 0,
        'list': <dynamic>[],
      });
    }
    return MomentumList.fromJson(<String, dynamic>{
      'count': 1,
      'list': <dynamic>[
        <String, dynamic>{
          'version': 1,
          'chainIdentifier': node.chainId,
          'hash': height == 1 ? node.genesis : FakeNode.hashOf('m$height'),
          'previousHash': height == 2
              ? node.genesis
              : emptyHash.toString(),
          'height': height,
          'timestamp': 1,
          'data': '',
          'content': <dynamic>[],
          'changesHash': emptyHash.toString(),
          'publicKey': '',
          'signature': '',
          'producer': pillarAddress.toString(),
        },
      ],
    });
  }

  @override
  Future<AccountBlockList> getAccountBlocksByPage(
    Address address, {
    int pageIndex = 0,
    int pageSize = rpcMaxPageSize,
  }) async {
    node._count('getAccountBlocksByPage');
    final List<Map<String, dynamic>> newestFirst = node.blocks.reversed
        .skip(pageIndex * pageSize)
        .take(pageSize)
        .toList();
    return _list(newestFirst);
  }

  @override
  Future<AccountBlockList> getAccountBlocksByHeight(
    Address address, [
    int height = 1,
    int count = rpcMaxPageSize,
  ]) async {
    node._count('getAccountBlocksByHeight');
    if (height < 1) throw Exception('height must be greater than zero');
    return _list(node.blocks.skip(height - 1).take(count).toList());
  }

  AccountBlockList _list(List<Map<String, dynamic>> blocks) =>
      AccountBlockList.fromJson(<String, dynamic>{
        'count': node.blocks.length,
        'list': blocks,
        'more': false,
      });
}

class _FakeAccelerator extends Fake implements AcceleratorApi {
  _FakeAccelerator(this.node);

  final FakeNode node;

  @override
  Future<ProjectList> getAll({
    int pageIndex = 0,
    int pageSize = rpcMaxPageSize,
  }) async {
    node._count('getAll');
    if (node.failGetAll != null) throw node.failGetAll!;
    return ProjectList.fromJson(<String, dynamic>{
      'count': node.projects.length,
      'list': node.order
          .skip(pageIndex * pageSize)
          .take(pageSize)
          .map((String id) => node.projects[id]!)
          .toList(),
    });
  }

  @override
  Future<Project> getProjectById(String id) async {
    node._count('getProjectById');
    node.fetched.add(id);
    if (node.failProjectById != null) throw node.failProjectById!;
    final Map<String, dynamic>? project = node.projects[id];
    if (project == null) throw Exception('data non existent');
    return Project.fromJson(project);
  }

  @override
  Future<List<PillarVote?>> getPillarVotes(
    String name,
    List<String> hashes,
  ) async {
    node._count('getPillarVotes');
    node.fetched.addAll(hashes);
    return hashes.map((String _) => null).toList();
  }
}

/// A store in memory, counting what is asked of it.
class MemoryStore implements AcceleratorProjectStore {
  final Map<String, String> entries = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    entries[key] = value;
  }

  @override
  Future<void> delete(String key) async => entries.remove(key);
}
