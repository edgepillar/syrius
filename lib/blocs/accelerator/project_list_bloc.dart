import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/services/accelerator_project_cache.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// What the project list shows.
class ProjectListState {
  /// Creates a state.
  const ProjectListState({this.projects, this.error, this.refreshing = false});

  /// The projects that pass the search and the filters, in the order
  /// shown; null while there is no list yet.
  final List<Project>? projects;

  /// Why there is no list.
  final Object? error;

  /// Whether the node is being asked for what happened since the list.
  final bool refreshing;
}

/// The Accelerator's projects, searched and filtered.
///
/// The whole list is held here, read through [AcceleratorProjectCache]: the
/// stored one first, then what the node has since. The search, the filters
/// and the sort run over it in memory. They used to go back through the
/// fetch; and the refresh button did not refresh, since the list, once
/// read, was never asked for again.
class ProjectListBloc with RefreshBlocMixin {
  /// Creates the list as seen by the owner of [pillarInfo], or by an
  /// address with no Pillar.
  ProjectListBloc({
    required this.pillarInfo,
    AcceleratorProjectCache? cache,
    Zenon Function()? node,
  }) : _cache = cache ?? AcceleratorProjectCache.getInstance(),
       _node = node ?? (() => zenon!) {
    // Another node may be on another chain: the list on screen is taken
    // down until that chain's own is known.
    listenToWsRestart(() => unawaited(_load(reset: true)));
    unawaited(_load(reset: true));
  }

  static final Logger _log = Logger('ProjectListBloc');

  final AcceleratorProjectCache _cache;
  final Zenon Function() _node;

  /// The Pillar the selected address owns, if any.
  final PillarInfo? pillarInfo;

  /// The filters switched on. Changed through [toggleFilter].
  final List<AccProjectsFilterTag> selectedProjectsFilterTag =
      <AccProjectsFilterTag>[];

  final BehaviorSubject<ProjectListState> _state =
      BehaviorSubject<ProjectListState>.seeded(const ProjectListState());

  /// The list as it changes.
  Stream<ProjectListState> get stream => _state.stream;

  /// The list now.
  ProjectListState get state => _state.value;

  List<Project>? _all;
  Object? _error;
  bool _refreshing = false;
  String _search = '';

  /// Null for the node's order, last update first.
  bool? _ascending;

  /// The ids, among those in voting, this Pillar has voted on. Per Pillar,
  /// so it is held here and never stored. Dropped whenever the list or the
  /// filters change, since a vote cast from a row changes it.
  Future<Set<String>>? _voted;

  /// Counts the loads, so that a slow one finishing late is ignored.
  int _run = 0;

  /// Counts the views published, for the same reason.
  int _view = 0;

  /// Asks the node for what happened since the list, keeping the list on
  /// screen meanwhile.
  void refreshResults() => unawaited(_load(reset: false));

  /// Narrows the list to the projects whose id, owner, name, description
  /// or link holds [term].
  void search(String term) {
    final String next = term.trim().toLowerCase();
    if (next == _search) return;
    _search = next;
    unawaited(_publish());
  }

  /// Switches [tag] on or off.
  void toggleFilter(AccProjectsFilterTag tag) {
    if (!selectedProjectsFilterTag.remove(tag)) {
      selectedProjectsFilterTag.add(tag);
    }
    _voted = null;
    unawaited(_publish());
  }

  /// Sorts by last update, oldest first, then newest first on the next
  /// call.
  void sortByLastUpdate() {
    _ascending = !(_ascending ?? false);
    unawaited(_publish());
  }

  /// Closes the stream.
  void dispose() {
    cancelStreamSubscription();
    _run += 1;
    unawaited(_state.close());
  }

  Future<void> _load({required bool reset}) async {
    final int run = _run += 1;
    if (reset) _all = null;
    _error = null;
    _refreshing = true;
    await _publish();
    try {
      await for (final AcceleratorCacheEvent event in _cache.load()) {
        if (run != _run) return;
        switch (event) {
          case AcceleratorProjectsLoaded():
            _all = event.projects;
            _refreshing = event.fromCache;
          case AcceleratorCacheDropped():
            _all = null;
        }
        _voted = null;
        await _publish();
      }
    } on Object catch (e, stackTrace) {
      if (run != _run) return;
      _log.log(Level.WARNING, '_load', e, stackTrace);
      // With a list on screen a failed refresh leaves it there: it was
      // true a moment ago, and an error in its place tells less.
      if (_all == null) _error = e;
    }
    if (run != _run) return;
    _refreshing = false;
    await _publish();
  }

  Future<void> _publish() async {
    if (_state.isClosed) return;
    final int view = _view += 1;
    final List<Project>? all = _all;
    if (all == null) {
      _state.add(ProjectListState(error: _error, refreshing: _refreshing));
      return;
    }
    Set<String> voted = const <String>{};
    if (_filtersByVote) {
      // The request is held, not its answer, so that two views published
      // in one turn share it.
      final Future<Set<String>> asked = _voted ??= _votedIds(all);
      try {
        voted = await asked;
        if (view != _view || _state.isClosed) return;
      } on Object catch (e, stackTrace) {
        if (identical(_voted, asked)) _voted = null;
        if (view != _view || _state.isClosed) return;
        _log.log(Level.WARNING, '_votedIds', e, stackTrace);
        _state.add(ProjectListState(error: e));
        return;
      }
    }
    final List<Project> shown = _filter(all, voted);
    if (shown.isEmpty &&
        pillarInfo == null &&
        _search.isEmpty &&
        selectedProjectsFilterTag.isEmpty) {
      _state.add(
        ProjectListState(error: 'No active projects', refreshing: _refreshing),
      );
      return;
    }
    _state.add(ProjectListState(projects: shown, refreshing: _refreshing));
  }

  bool get _filtersByVote =>
      pillarInfo != null &&
      (selectedProjectsFilterTag.contains(AccProjectsFilterTag.needsVoting) ||
          selectedProjectsFilterTag.contains(
            AccProjectsFilterTag.alreadyVoted,
          ));

  /// One request, for the projects and phases in voting only: the two
  /// voting filters look at nothing else. It used to be two requests
  /// naming every project and every phase, for each page of ten.
  Future<Set<String>> _votedIds(List<Project> all) async {
    final List<String> inVoting = <String>[
      for (final Project project in all) ...<String>[
        if (project.status == AcceleratorProjectStatus.voting)
          project.id.toString(),
        for (final Phase phase in project.phases)
          if (phase.status == AcceleratorProjectStatus.voting)
            phase.id.toString(),
      ],
    ];
    if (inVoting.isEmpty) return <String>{};
    final List<PillarVote?> votes = await _node().embedded.accelerator
        .getPillarVotes(pillarInfo!.name, inVoting);
    return <String>{
      for (final PillarVote? vote in votes)
        if (vote != null) vote.id.toString(),
    };
  }

  List<Project> _filter(List<Project> all, Set<String> voted) {
    final List<AccProjectsFilterTag> tags = selectedProjectsFilterTag;
    bool owned(Project project) =>
        kDefaultAddressList.contains(project.owner.toString());
    bool waits(Project project, {required bool votedOn}) =>
        (project.status == AcceleratorProjectStatus.voting &&
            voted.contains(project.id.toString()) == votedOn) ||
        project.phases.any(
          (Phase phase) =>
              phase.status == AcceleratorProjectStatus.voting &&
              voted.contains(phase.id.toString()) == votedOn,
        );
    final List<Project> shown = all.where((Project project) {
      if (_search.isNotEmpty && !_matches(project, _search)) return false;
      if (tags.contains(AccProjectsFilterTag.myProjects) && !owned(project)) {
        return false;
      }
      if (tags.contains(AccProjectsFilterTag.onlyAccepted) &&
          project.status != AcceleratorProjectStatus.active) {
        return false;
      }
      if (tags.contains(AccProjectsFilterTag.needsVoting) &&
          !waits(project, votedOn: false)) {
        return false;
      }
      if (tags.contains(AccProjectsFilterTag.alreadyVoted) &&
          !waits(project, votedOn: true)) {
        return false;
      }
      // An address with no Pillar cannot vote, so it is shown what was
      // accepted and what it owns.
      return pillarInfo != null ||
          project.status == AcceleratorProjectStatus.active ||
          owned(project);
    }).toList();
    final bool? ascending = _ascending;
    if (ascending != null) {
      shown.sort(
        (Project a, Project b) => ascending
            ? a.lastUpdateTimestamp.compareTo(b.lastUpdateTimestamp)
            : b.lastUpdateTimestamp.compareTo(a.lastUpdateTimestamp),
      );
    }
    return shown;
  }

  static bool _matches(Project project, String term) =>
      project.id.toString().toLowerCase().contains(term) ||
      project.owner.toString().toLowerCase().contains(term) ||
      project.name.toLowerCase().contains(term) ||
      project.description.toLowerCase().contains(term) ||
      project.url.toLowerCase().contains(term);
}
