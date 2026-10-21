/// The Accelerator's projects, kept between sessions with the height they
/// were complete at.
///
/// `embedded.accelerator.getAll` has the node read every project, every
/// phase and every vote out of the contract's storage: about ten seconds on
/// a public mainnet node for 201 projects, on each opening of the page.
/// Projects are never deleted, so the list a wallet saw yesterday is still
/// the list, less what happened since.
///
/// What happened since is on the contract's own account chain and nowhere
/// else. An embedded contract's storage changes only when the contract
/// receives a block: a project created, a phase added or replaced, a vote,
/// and the `Update` the Pillars send that closes votings and pays phases.
/// So the cache holds the list and a snapshot, the height and hash of the
/// contract's frontier block when the list was read, and a refresh asks
/// only for the blocks after it:
///
/// * none: the list is exact, and nothing else is asked;
/// * some: the projects those blocks name are read again, with every project
///   an `Update` can move (see `AcceleratorProjectCache.isSettled`), and the
///   snapshot advances.
///
/// A new project's id is the hash of the send block that created it
/// (go-zenon, `CreateProjectMethod.ReceiveBlock`: `project.Id =
/// sendBlock.Hash`), a phase's likewise, which is how a block is tied to
/// the project it made.
///
/// The cache is never the only path. Anything unexpected on the way, a
/// block it cannot read, a project that will not load, too long a gap,
/// ends in the full read the page made before.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:hive_ce/hive_ce.dart';
import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/utils/constants.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// What [AcceleratorProjectCache.load] hands to the page, in order.
sealed class AcceleratorCacheEvent {
  const AcceleratorCacheEvent();
}

/// The list of projects, newest update first as the node sorts it.
class AcceleratorProjectsLoaded extends AcceleratorCacheEvent {
  /// Creates the event.
  const AcceleratorProjectsLoaded(
    this.projects, {
    required this.height,
    required this.fromCache,
  });

  /// Every project, with its phases.
  final List<Project> projects;

  /// The contract's account chain height the list is complete at.
  final int height;

  /// True for the stored list shown before the node has answered; false
  /// once it has been brought up to the node's frontier.
  final bool fromCache;
}

/// The stored list just shown belongs to a chain the node is not on. The
/// page must take it down; the full read follows.
class AcceleratorCacheDropped extends AcceleratorCacheEvent {
  /// Creates the event.
  const AcceleratorCacheDropped();
}

/// Where the cache is kept: one string per chain.
abstract class AcceleratorProjectStore {
  /// The entry of [key], or null.
  Future<String?> read(String key);

  /// Replaces the entry of [key].
  Future<void> write(String key, String value);

  /// Removes the entry of [key].
  Future<void> delete(String key);
}

/// The store in Hive. A lazy box: the entry is a few hundred kilobytes and
/// is read when the Accelerator page opens, not held in memory from the
/// start of the app as a plain box's values are.
class HiveAcceleratorProjectStore implements AcceleratorProjectStore {
  LazyBox<String>? _box;

  /// Wiping the wallet's cache closes every box, so an open one is not
  /// taken for granted.
  Future<LazyBox<String>> _open() async {
    final LazyBox<String>? box = _box;
    if (box != null && box.isOpen) return box;
    return _box = await Hive.openLazyBox<String>(kAcceleratorProjectsBox);
  }

  @override
  Future<String?> read(String key) async => (await _open()).get(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _open()).put(key, value);

  @override
  Future<void> delete(String key) async => (await _open()).delete(key);
}

/// The list of one chain and its snapshot.
class _Entry {
  const _Entry(this.height, this.hash, this.projects);

  /// The contract's frontier height when [projects] was read; 0 when the
  /// contract had no block yet.
  final int height;

  /// The hash of the block at [height]. It commits to everything before
  /// it, so a node that still has this block at this height has the same
  /// history the list was read from.
  final String hash;

  final List<Project> projects;
}

/// The stored list no longer matches the node's chain.
class _SnapshotGone implements Exception {
  const _SnapshotGone(this.why);
  final String why;
  @override
  String toString() => 'snapshot gone: $why';
}

/// The step from the snapshot cannot be trusted or is not worth making.
class _NotIncremental implements Exception {
  const _NotIncremental(this.why);
  final String why;
  @override
  String toString() => 'not incremental: $why';
}

/// Loads the Accelerator's projects through the cache.
class AcceleratorProjectCache {
  /// Creates a cache over [store], asking [node].
  AcceleratorProjectCache({
    AcceleratorProjectStore? store,
    Zenon Function()? node,
  }) : _store = store ?? HiveAcceleratorProjectStore(),
       _node = node ?? (() => zenon!);

  static AcceleratorProjectCache? _instance;

  /// The wallet's one cache.
  static AcceleratorProjectCache getInstance() =>
      _instance ??= AcceleratorProjectCache();

  static final Logger _log = Logger('AcceleratorProjectCache');

  /// Bumped when the stored shape changes; an entry of another version is
  /// dropped, not migrated.
  static const int _version = 1;

  /// Blocks asked for at a time. Not the node's maximum of 1024: the SDK
  /// decodes an answer on the calling isolate, and a full page of these
  /// blocks, 2.5 MB, holds it for over 100 ms. A page of this size is
  /// 300 kB and under 10 ms, and two days of the contract's blocks on
  /// mainnet, where it receives about 55 a day.
  static const int blockPageSize = 128;

  /// The longest gap followed block by block: some five weeks away from
  /// the wallet on mainnet. The pages are asked for one after another, at
  /// about 0.3 s each from a public node, so beyond this the full read,
  /// ten seconds there, is no longer the slower way.
  static const int maxBlockPages = 16;

  /// The most projects read again one by one before the full read is
  /// cheaper. Mainnet has 12 an `Update` can move.
  static const int maxRefetch = 64;

  /// Projects asked for at once.
  static const int _concurrency = 8;

  final AcceleratorProjectStore _store;
  final Zenon Function() _node;

  /// Entries already decoded this session, by chain, so that coming back to
  /// the page reads no disk.
  final Map<String, _Entry> _memory = <String, _Entry>{};

  /// The stored list at once, if this chain has one, then the list brought
  /// up to the node's frontier.
  ///
  /// An error after a [AcceleratorProjectsLoaded] means the node could not
  /// be asked; the list already handed over stands.
  Stream<AcceleratorCacheEvent> load() async* {
    final Zenon node = _node();
    final String key = await _chainKey(node);
    final _Entry? stored = await _read(key);
    if (stored != null) {
      yield AcceleratorProjectsLoaded(
        stored.projects,
        height: stored.height,
        fromCache: true,
      );
    }

    _Entry? current;
    if (stored != null) {
      try {
        current = await _advance(node, stored);
      } on _SnapshotGone catch (e) {
        // Shown a moment ago, and wrong: taken down before anything else,
        // so that a failed full read leaves an error and not another
        // chain's projects.
        _log.info('$key: $e');
        await _drop(key);
        yield const AcceleratorCacheDropped();
      } on Object catch (e, stackTrace) {
        _log.log(Level.INFO, '$key: full read instead', e, stackTrace);
      }
    }
    current ??= await _full(node);

    if (!identical(current, stored)) {
      _memory[key] = current;
      await _write(key, current);
    }
    yield AcceleratorProjectsLoaded(
      current.projects,
      height: current.height,
      fromCache: false,
    );
  }

  /// Whether nothing but a block naming [project] can change it, so that
  /// the stored copy stands until such a block is seen.
  ///
  /// Read off go-zenon's `UpdateEmbeddedAcceleratorMethod`, the one thing
  /// that changes projects no block names. It acts on a project in voting
  /// (accepts it, or closes it when its time is up) and on an accepted
  /// project whose last phase is in voting (pays the phase and may complete
  /// the project). It passes over everything else:
  ///
  /// * closed and completed projects, which nothing brings back;
  /// * an accepted project with no phase or with its last phase paid, which
  ///   waits for its owner to add a phase, in a block that names it.
  ///
  /// A vote can still land on any of these and move the tally shown, and a
  /// vote names what it votes on, so it is read again then.
  static bool isSettled(Project project) {
    switch (project.status) {
      case AcceleratorProjectStatus.closed:
      case AcceleratorProjectStatus.completed:
        return true;
      case AcceleratorProjectStatus.active:
        return project.phases.isEmpty ||
            project.phases.last.status == AcceleratorProjectStatus.paid;
      case AcceleratorProjectStatus.voting:
      case AcceleratorProjectStatus.paid:
        return false;
    }
  }

  /// The chain the node is on: its identifier and its first momentum.
  ///
  /// Asked of the node on every load and never remembered, since the same
  /// address can serve another chain after a node is switched or a devnet
  /// rebuilt. Two devnets share identifier 321; their genesis tells them
  /// apart.
  ///
  /// The genesis hash is read off the second momentum, as the hash before
  /// it. The first momentum itself lists every genesis account: 2 MB and
  /// most of a second on mainnet, where the second is 2 kB.
  static Future<String> _chainKey(Zenon node) async {
    final List<Momentum> second =
        (await node.ledger.getMomentumsByHeight(2, 1)).list;
    if (second.isNotEmpty) {
      return '${second.first.chainIdentifier}:${second.first.previousHash}';
    }
    // A chain one momentum long.
    final Momentum genesis =
        (await node.ledger.getMomentumsByHeight(1, 1)).list.first;
    return '${genesis.chainIdentifier}:${genesis.hash}';
  }

  /// The contract's frontier block as a snapshot, with no list yet.
  static Future<(int, String)> _frontier(Zenon node) async {
    final List<AccountBlock> list =
        (await node.ledger.getAccountBlocksByPage(
          acceleratorAddress,
          pageSize: 1,
        )).list ??
        <AccountBlock>[];
    if (list.isEmpty) return (0, '');
    return (list.first.height, list.first.hash.toString());
  }

  /// Every project, as the page read them before the cache.
  ///
  /// The snapshot is taken before the list: a block arriving between the
  /// two is then looked at again on the next refresh, which costs a
  /// request. Taken after, it would be skipped, and its project stale for
  /// good.
  static Future<_Entry> _full(Zenon node) async {
    final (int height, String hash) = await _frontier(node);
    final List<Project> projects = <Project>[];
    for (int page = 0; ; page += 1) {
      final ProjectList got = await node.embedded.accelerator.getAll(
        pageIndex: page,
      );
      projects.addAll(got.list);
      if (got.list.isEmpty || projects.length >= got.count) break;
    }
    return _Entry(height, hash, _sorted(projects));
  }

  /// [entry] brought up to the node's frontier, or [entry] itself when no
  /// block followed its snapshot.
  static Future<_Entry> _advance(Zenon node, _Entry entry) async {
    // The first block asked for is the snapshot's own: finding it where it
    // was is the proof that this is still the chain the list came from. A
    // node that was switched, rolled back or resynced does not have it.
    final List<AccountBlock> blocks = <AccountBlock>[];
    final bool anchored = entry.height > 0;
    int from = anchored ? entry.height : 1;
    bool complete = false;
    for (int page = 0; page < maxBlockPages; page += 1) {
      final List<AccountBlock> got =
          (await node.ledger.getAccountBlocksByHeight(
            acceleratorAddress,
            from,
            blockPageSize,
          )).list ??
          <AccountBlock>[];
      if (page == 0 && anchored) {
        if (got.isEmpty) {
          throw const _SnapshotGone('the node is behind the snapshot');
        }
        if (got.first.height != entry.height ||
            got.first.hash.toString() != entry.hash) {
          throw const _SnapshotGone('another block at the snapshot height');
        }
        blocks.addAll(got.skip(1));
      } else {
        blocks.addAll(got);
      }
      if (got.length < blockPageSize) {
        complete = true;
        break;
      }
      from += blockPageSize;
    }
    if (!complete) throw const _NotIncremental('too many blocks since');
    if (blocks.isEmpty) return entry;

    final Map<String, Project> byId = <String, Project>{
      for (final Project project in entry.projects)
        project.id.toString(): project,
    };
    final Set<String> again = _touched(blocks, entry.projects)
      ..addAll(
        entry.projects
            .where((Project project) => !isSettled(project))
            .map((Project project) => project.id.toString()),
      );
    if (again.length > maxRefetch) {
      throw const _NotIncremental('too many projects to read again');
    }

    final List<String> ids = again.toList();
    for (int i = 0; i < ids.length; i += _concurrency) {
      final Iterable<String> batch = ids.skip(i).take(_concurrency);
      final List<Project> got = await Future.wait(
        batch.map(node.embedded.accelerator.getProjectById),
      );
      for (final Project project in got) {
        byId[project.id.toString()] = project;
      }
    }
    return _Entry(
      blocks.last.height,
      blocks.last.hash.toString(),
      _sorted(byId.values.toList()),
    );
  }

  /// The ids of the projects [blocks] created or changed, among [known]
  /// and those the blocks themselves created.
  ///
  /// Throws for a block it cannot place: an unknown call may be one a later
  /// protocol version added, and guessing that it changed nothing is how a
  /// cache goes quietly wrong.
  static Set<String> _touched(List<AccountBlock> blocks, List<Project> known) {
    final Set<String> projects = <String>{
      for (final Project project in known) project.id.toString(),
    };
    final Map<String, String> projectOfPhase = <String, String>{
      for (final Project project in known)
        for (final Hash phase in project.phaseIds)
          phase.toString(): project.id.toString(),
    };
    final Set<String> touched = <String>{};
    for (final AccountBlock block in blocks) {
      // The contract's own sends are the payments an Update made; they
      // carry no call. Its genesis block is its opening balance on a
      // devnet.
      if (block.blockType != BlockTypeEnum.contractReceive.index) continue;
      final AccountBlock? send = block.pairedAccountBlock;
      if (send == null) throw const _NotIncremental('a receive with no send');
      final AcceleratorCall call = AcceleratorCall.of(send.data);
      final String sendHash = send.hash.toString();
      switch (call.kind) {
        case AcceleratorCallKind.createProject:
          projects.add(sendHash);
          touched.add(sendHash);
        case AcceleratorCallKind.phase:
          // Refused by the contract when the project does not exist, so an
          // id that is not known named nothing.
          if (projects.contains(call.id)) {
            touched.add(call.id!);
            projectOfPhase[sendHash] = call.id!;
          }
        case AcceleratorCallKind.vote:
          // On a project or on a phase. Every project and phase that
          // exists is either in the stored list or was made by a block
          // above, so an id found in neither is a vote the contract
          // refused.
          final String? project = projects.contains(call.id)
              ? call.id
              : projectOfPhase[call.id];
          if (project != null) touched.add(project);
        case AcceleratorCallKind.none:
          break;
        case AcceleratorCallKind.unknown:
          throw const _NotIncremental('a call the cache does not know');
      }
    }
    return touched;
  }

  /// The node's order: last update first. The node sorts stably over its
  /// storage, which is in id order, so ties fall the same way here.
  static List<Project> _sorted(List<Project> projects) => projects
    ..sort((Project a, Project b) {
      final int byUpdate = b.lastUpdateTimestamp.compareTo(
        a.lastUpdateTimestamp,
      );
      return byUpdate != 0
          ? byUpdate
          : a.id.toString().compareTo(b.id.toString());
    });

  Future<_Entry?> _read(String key) async {
    final _Entry? held = _memory[key];
    if (held != null) return held;
    try {
      final String? raw = await _store.read(key);
      if (raw == null) return null;
      final _Entry? entry = await Isolate.run<_Entry?>(
        _decoder(raw),
        debugName: 'accelerator-cache-decode',
      );
      if (entry == null) {
        await _drop(key);
        return null;
      }
      return _memory[key] = entry;
    } on Object catch (e, stackTrace) {
      // An entry that cannot be read is no entry.
      _log.log(Level.WARNING, '$key: unreadable, dropped', e, stackTrace);
      await _drop(key);
      return null;
    }
  }

  Future<void> _write(String key, _Entry entry) async {
    try {
      final String raw = await Isolate.run<String>(
        _encoder(entry.height, entry.hash, entry.projects),
        debugName: 'accelerator-cache-encode',
      );
      await _store.write(key, raw);
    } on Object catch (e, stackTrace) {
      // The list is on the page either way; the next opening reads it in
      // full again.
      _log.log(Level.WARNING, '$key: not stored', e, stackTrace);
    }
  }

  Future<void> _drop(String key) async {
    _memory.remove(key);
    try {
      await _store.delete(key);
    } on Object catch (e, stackTrace) {
      _log.log(Level.WARNING, '$key: not deleted', e, stackTrace);
    }
  }

  // The closures run in another isolate: decoding 200 projects takes some
  // 15 ms, which is a dropped frame on the UI isolate. Each is built in a
  // static function that holds only what it sends; written inline they
  // would take the cache, its store and the node with them.

  static _Entry? Function() _decoder(String raw) =>
      () => _decode(raw);

  static String Function() _encoder(
    int height,
    String hash,
    List<Project> projects,
  ) =>
      () => jsonEncode(<String, dynamic>{
        'version': _version,
        'height': height,
        'hash': hash,
        'projects': projects.map(projectToJson).toList(),
      });

  static _Entry? _decode(String raw) {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != _version) return null;
    return _Entry(
      json['height'] as int,
      json['hash'] as String,
      (json['projects'] as List<dynamic>)
          .map((dynamic e) => Project.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// [project] in the shape the node sends and `Project.fromJson` reads.
  /// The SDK's own `toJson` leaves out the phases and writes the votes as
  /// text, so it does not read back.
  static Map<String, dynamic> projectToJson(Project project) =>
      <String, dynamic>{
        'id': project.id.toString(),
        'owner': project.owner.toString(),
        'name': project.name,
        'description': project.description,
        'url': project.url,
        'znnFundsNeeded': project.znnFundsNeeded.toString(),
        'qsrFundsNeeded': project.qsrFundsNeeded.toString(),
        'creationTimestamp': project.creationTimestamp,
        'lastUpdateTimestamp': project.lastUpdateTimestamp,
        'status': project.statusInt,
        'phaseIds': project.phaseIds.map((Hash id) => id.toString()).toList(),
        'votes': project.voteBreakdown.toJson(),
        'phases': project.phases
            .map(
              (Phase phase) => <String, dynamic>{
                'phase': <String, dynamic>{
                  'id': phase.id.toString(),
                  'projectID': phase.projectId.toString(),
                  'name': phase.name,
                  'description': phase.description,
                  'url': phase.url,
                  'znnFundsNeeded': phase.znnFundsNeeded.toString(),
                  'qsrFundsNeeded': phase.qsrFundsNeeded.toString(),
                  'creationTimestamp': phase.creationTimestamp,
                  'acceptedTimestamp': phase.acceptedTimestamp,
                  'status': phase.statusInt,
                },
                'votes': phase.voteBreakdown.toJson(),
              },
            )
            .toList(),
      };
}

/// What a call to the Accelerator contract does to the list.
enum AcceleratorCallKind {
  /// Creates a project, whose id is the hash of the calling block.
  createProject,

  /// Adds a phase to a project or replaces its last; names the project,
  /// and the phase's id is the hash of the calling block.
  phase,

  /// A Pillar's vote on a project or a phase, named by id.
  vote,

  /// Names no project: `Update`, whose effects are found by reading every
  /// project that is not settled, and `Donate`.
  none,

  /// Not a call of this contract's known interface.
  unknown,
}

/// The data of a block sent to the Accelerator, read as far as the cache
/// needs: which call, and the id it names.
class AcceleratorCall {
  const AcceleratorCall._(this.kind, [this.id]);

  /// Reads [data], the data of the send block.
  ///
  /// Only the four signature bytes and, for the calls that take one, the
  /// 32 bytes of the id that follow them: the id is the first argument and
  /// of fixed size, so it sits there whatever strings come after, and none
  /// of them needs decoding.
  factory AcceleratorCall.of(List<int> data) {
    if (data.length < AbiFunction.encodedSignLength) {
      return const AcceleratorCall._(AcceleratorCallKind.unknown);
    }
    final String signature = _hex(data, 0, AbiFunction.encodedSignLength);
    final AcceleratorCallKind? kind = _kinds[signature];
    if (kind == null) {
      return const AcceleratorCall._(AcceleratorCallKind.unknown);
    }
    if (kind != AcceleratorCallKind.phase && kind != AcceleratorCallKind.vote) {
      return AcceleratorCall._(kind);
    }
    final int end = AbiFunction.encodedSignLength + Hash.length;
    if (data.length < end) {
      return const AcceleratorCall._(AcceleratorCallKind.unknown);
    }
    return AcceleratorCall._(
      kind,
      _hex(data, AbiFunction.encodedSignLength, end),
    );
  }

  /// The call.
  final AcceleratorCallKind kind;

  /// The id named, as a hash in hex: the project's for
  /// [AcceleratorCallKind.phase], a project's or a phase's for
  /// [AcceleratorCallKind.vote].
  final String? id;

  /// Signature to kind, from the SDK's own definitions of the contract.
  /// `Update` is in the interface every embedded contract shares.
  static final Map<String, AcceleratorCallKind> _kinds = () {
    const Map<String, AcceleratorCallKind> byName =
        <String, AcceleratorCallKind>{
          'CreateProject': AcceleratorCallKind.createProject,
          'AddPhase': AcceleratorCallKind.phase,
          'UpdatePhase': AcceleratorCallKind.phase,
          'VoteByName': AcceleratorCallKind.vote,
          'VoteByProdAddress': AcceleratorCallKind.vote,
          'Donate': AcceleratorCallKind.none,
          'Update': AcceleratorCallKind.none,
        };
    final Map<String, AcceleratorCallKind> kinds =
        <String, AcceleratorCallKind>{};
    for (final Abi abi in <Abi>[Definitions.accelerator, Definitions.common]) {
      for (final Entry entry in abi.entries) {
        final AcceleratorCallKind? kind = byName[entry.name];
        if (kind == null) continue;
        final List<int> signature = AbiFunction.extractSignature(
          entry.encodeSignature(),
        );
        kinds[_hex(signature, 0, signature.length)] = kind;
      }
    }
    return kinds;
  }();

  static String _hex(List<int> bytes, int start, int end) {
    final StringBuffer out = StringBuffer();
    for (int i = start; i < end; i += 1) {
      out.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
