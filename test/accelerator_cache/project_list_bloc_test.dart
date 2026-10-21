import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/services/accelerator_project_cache.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'fake_node.dart';

class MockPillarInfo extends Mock implements PillarInfo {}

void main() {
  late FakeNode node;
  late MemoryStore store;
  late PillarInfo pillar;
  late String voting;
  late String accepted;
  late String closed;
  late String phase;

  ProjectListBloc open({PillarInfo? as}) => ProjectListBloc(
    pillarInfo: as,
    cache: AcceleratorProjectCache(store: store, node: () => node.zenon),
    node: () => node.zenon,
  );

  /// The first state with the node's answer in it.
  Future<ProjectListState> settled(ProjectListBloc bloc) => bloc.stream
      .firstWhere((ProjectListState s) => s.projects != null && !s.refreshing);

  List<String> names(ProjectListState state) =>
      state.projects!.map((Project project) => project.name).toList();

  setUp(() {
    node = FakeNode();
    store = MemoryStore();
    pillar = MockPillarInfo();
    when(() => pillar.name).thenReturn('pillar');
    voting = node.createProject('alpha voting');
    accepted = node.createProject('beta accepted');
    closed = node.createProject('gamma closed');
    node.update(accept: <String>[accepted], close: <String>[closed]);
    phase = node.addPhase(accepted, 'one');
    kDefaultAddressList = <String?>[];
  });

  test('shows the stored list while the node is asked', () async {
    await settled(open(as: pillar));
    node.createProject('delta new');

    final List<ProjectListState> states = await open(as: pillar).stream
        .takeWhile((ProjectListState s) => s.projects == null || s.refreshing)
        .toList();

    final ProjectListState stored = states.last;
    expect(stored.refreshing, isTrue);
    expect(names(stored), hasLength(3));
  });

  test('search, filters and sort ask the node nothing', () async {
    final ProjectListBloc bloc = open(as: pillar);
    await settled(bloc);
    node.resetCounts();

    bloc.search('BETA');
    expect(names(bloc.state), <String>['beta accepted']);
    bloc.search(voting.substring(0, 12));
    expect(names(bloc.state), <String>['alpha voting']);
    bloc
      ..search('')
      ..toggleFilter(AccProjectsFilterTag.onlyAccepted);
    expect(names(bloc.state), <String>['beta accepted']);
    bloc
      ..toggleFilter(AccProjectsFilterTag.onlyAccepted)
      ..sortByLastUpdate();
    expect(names(bloc.state).first, 'alpha voting');
    bloc.sortByLastUpdate();
    expect(names(bloc.state).first, 'beta accepted');

    expect(node.total, 0);
    bloc.dispose();
  });

  test('a voting filter asks once, for what is in voting only', () async {
    final ProjectListBloc bloc = open(as: pillar);
    await settled(bloc);
    node.resetCounts();

    bloc.toggleFilter(AccProjectsFilterTag.needsVoting);
    final ProjectListState state = await bloc.stream.firstWhere(
      (ProjectListState s) => s.projects?.length == 2,
    );

    expect(names(state), <String>['beta accepted', 'alpha voting']);
    expect(node.calls, <String, int>{'getPillarVotes': 1});
    expect(node.fetched.toSet(), <String>{voting, phase});

    // Typing under the filter does not ask again.
    bloc.search('alpha');
    await bloc.stream.firstWhere(
      (ProjectListState s) => s.projects?.length == 1,
    );
    expect(node.calls, <String, int>{'getPillarVotes': 1});
    bloc.dispose();
  });

  test('an address with no Pillar sees what was accepted and what it '
      'owns', () async {
    ProjectListBloc bloc = open();
    expect(names(await settled(bloc)), <String>['beta accepted']);
    bloc.dispose();

    kDefaultAddressList = <String?>[pillarAddress.toString()];
    bloc = open();
    expect(names(await settled(bloc)), hasLength(3));
    bloc.dispose();
  });

  test('refresh keeps the list on screen and brings what is new', () async {
    final ProjectListBloc bloc = open(as: pillar);
    await settled(bloc);
    node
      ..createProject('delta new')
      ..resetCounts();
    final List<ProjectListState> seen = <ProjectListState>[];
    bloc.stream.skip(1).listen(seen.add);

    bloc.refreshResults();
    await bloc.stream.firstWhere(
      (ProjectListState s) => s.projects?.length == 4 && !s.refreshing,
    );

    expect(seen.every((ProjectListState s) => s.projects != null), isTrue);
    expect(node.calls['getAll'], isNull);
    bloc.dispose();
  });

  test('a node that cannot be asked is an error, not an empty list', () async {
    node.failGetAll = Exception('down');

    final ProjectListState state = await open(
      as: pillar,
    ).stream.firstWhere((ProjectListState s) => s.error != null);

    expect(state.projects, isNull);
  });
}
