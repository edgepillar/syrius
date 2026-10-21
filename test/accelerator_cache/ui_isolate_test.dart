import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/services/accelerator_project_cache.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'fake_node.dart';

class MockPillarInfo extends Mock implements PillarInfo {}

/// The longest the calling isolate went without running a timer while
/// [work] was awaited; as in `test/background_crypto`.
Future<Duration> _longestStall(Future<void> Function() work) async {
  final Stopwatch clock = Stopwatch()..start();
  Duration last = Duration.zero;
  Duration longest = Duration.zero;
  final Timer timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final Duration now = clock.elapsed;
    if (now - last > longest) longest = now - last;
    last = now;
  });
  await work();
  final Duration end = clock.elapsed;
  if (end - last > longest) longest = end - last;
  timer.cancel();
  return longest;
}

/// Opening the page with the first cache froze the window for a third of a
/// second on mainnet, on every visit. Nothing here may hold the isolate
/// longer than this.
const Duration _fluid = Duration(milliseconds: 50);

void main() {
  // Mainnet has 201 projects; this is half as many again, with the long
  // descriptions real ones have.
  late FakeNode node;
  late MemoryStore store;
  late AcceleratorProjectCache session;
  late PillarInfo pillar;

  AcceleratorProjectCache restarted() =>
      AcceleratorProjectCache(store: store, node: () => node.zenon);

  /// The page opened and left: the list read through to the node's answer,
  /// and a moment more for what follows it, the write to the store.
  Future<void> visit({PillarInfo? as}) async {
    final ProjectListBloc bloc = ProjectListBloc(
      pillarInfo: as,
      cache: session,
      node: () => node.zenon,
    );
    final ProjectListState state = await bloc.stream.firstWhere(
      (ProjectListState s) => s.projects != null && !s.refreshing,
    );
    expect(state.projects, isNotEmpty);
    bloc
      ..search('lorem')
      ..search('');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    bloc.dispose();
  }

  setUpAll(() async {
    node = FakeNode();
    store = MemoryStore();
    pillar = MockPillarInfo();
    when(() => pillar.name).thenReturn('pillar');
    kDefaultAddressList = <String?>[];
    final List<String> ids = <String>[
      for (int i = 0; i < 300; i += 1)
        node.createProject('project $i ${'lorem ipsum ' * 40}'),
    ];
    node.update(accept: ids.sublist(0, 200), close: ids.sublist(200, 290));
    for (final String id in ids.sublist(0, 150)) {
      node.addPhase(id, 'phase ${'dolor sit amet ' * 30}');
    }
    node.update(pay: ids.sublist(0, 130));
    // The first run of any code is compiled as it goes, here and not in
    // the wallet as shipped; that is not what is measured.
    session = AcceleratorProjectCache(
      store: MemoryStore(),
      node: () => node.zenon,
    );
    await visit(as: pillar);
    await visit(as: pillar);
    session = restarted();
  });

  test('cold: the full read', () async {
    expect(await _longestStall(() => visit(as: pillar)), lessThan(_fluid));
    expect(node.calls['getAll'], greaterThan(0));
    expect(store.entries, hasLength(1));
  });

  test('warm: a second visit in the session', () async {
    node.resetCounts();
    expect(await _longestStall(() => visit(as: pillar)), lessThan(_fluid));
    expect(await _longestStall(visit), lessThan(_fluid));
    expect(node.calls['getAll'], isNull);
  });

  test('warm: after a restart, read from the store', () async {
    session = restarted();
    node.resetCounts();
    expect(await _longestStall(() => visit(as: pillar)), lessThan(_fluid));
    expect(node.calls['getAll'], isNull);
  });

  test('warm: after a restart, with blocks since', () async {
    node
      ..createProject('new')
      ..update();
    session = restarted();
    node.resetCounts();
    expect(await _longestStall(() => visit(as: pillar)), lessThan(_fluid));
    expect(node.calls['getAll'], isNull);
    expect(node.calls['getProjectById'], 31);
    expect(store.writes, 2);
  });
}
