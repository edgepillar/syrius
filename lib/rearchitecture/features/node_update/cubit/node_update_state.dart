part of 'node_update_cubit.dart';

/// Where the read of what is on disk stands.
enum NodeUpdateLoad {
  /// Not read yet.
  loading,

  /// [NodeUpdatePanelState.library] holds it.
  ready,

  /// The override directory could not be read.
  failed,
}

/// The answer to the last press of Check.
sealed class NodeUpdateCheck extends Equatable {
  const NodeUpdateCheck();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Check has not been pressed for this repository.
final class NodeUpdateCheckIdle extends NodeUpdateCheck {
  /// Creates the state.
  const NodeUpdateCheckIdle();
}

/// The release list is being read.
final class NodeUpdateCheckRunning extends NodeUpdateCheck {
  /// Creates the state.
  const NodeUpdateCheckRunning();
}

/// The repository answered.
final class NodeUpdateCheckDone extends NodeUpdateCheck {
  /// Creates the state.
  const NodeUpdateCheckDone({required this.release, required this.comparison});

  /// The newest release, or null when the repository has none.
  final NodeRelease? release;

  /// How [release] stands to what the next start loads.
  final NodeUpdateState comparison;

  /// Whether [release] can be downloaded: it has a library for this
  /// platform, and the next start is not known to load it already.
  bool get downloadable =>
      release?.asset != null &&
      (comparison == NodeUpdateState.updateAvailable ||
          comparison == NodeUpdateState.unknown);

  @override
  List<Object?> get props => <Object?>[release, comparison];
}

/// The repository could not be read.
final class NodeUpdateCheckFailed extends NodeUpdateCheck {
  /// Creates the state.
  const NodeUpdateCheckFailed(this.error);

  /// Why.
  final NodeUpdateException error;

  @override
  List<Object?> get props => <Object?>[error];
}

/// Where an install, or a roll back, stands. Everything but
/// [NodeUpdateStepIdle] and [NodeUpdateStepFailed] is [busy]: one thing at a
/// time.
sealed class NodeUpdateStep extends Equatable {
  const NodeUpdateStep();

  /// Whether another action has to wait for this one.
  bool get busy => true;

  @override
  List<Object?> get props => const <Object?>[];
}

/// Nothing is under way.
final class NodeUpdateStepIdle extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateStepIdle();

  @override
  bool get busy => false;
}

/// A release's archive is arriving.
final class NodeUpdateDownloading extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateDownloading({required this.received, required this.total});

  /// Bytes so far.
  final int received;

  /// Bytes expected; 0 when not known.
  final int total;

  @override
  List<Object?> get props => <Object?>[received, total];
}

/// A file the person picked is being copied and hashed.
final class NodeUpdateReadingFile extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateReadingFile(this.name);

  /// The file's name.
  final String name;

  @override
  List<Object?> get props => <Object?>[name];
}

/// The release publishes no hash for its library, so nothing was
/// downloaded. The person has to say, apart from the install itself, that an
/// unverified download is wanted.
final class NodeUpdateUnverifiedAsk extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateUnverifiedAsk({
    required this.release,
    required this.checksumFile,
  });

  /// The release asked for.
  final NodeRelease release;

  /// Why the checksum file was no help.
  final NodeChecksumFileCheck checksumFile;

  @override
  List<Object?> get props => <Object?>[release, checksumFile];
}

/// A library lies in a temporary file and waits for the person's answer.
/// Nothing is installed yet.
final class NodeUpdateConfirmAsk extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateConfirmAsk(this.library);

  /// What would be installed.
  final DownloadedNodeLibrary library;

  @override
  List<Object?> get props => <Object?>[library];
}

/// The person confirmed and the library is being staged.
final class NodeUpdateStaging extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateStaging(this.library);

  /// What is being staged.
  final DownloadedNodeLibrary library;

  @override
  List<Object?> get props => <Object?>[library];
}

/// The last action failed. Nothing of it is left on disk.
final class NodeUpdateStepFailed extends NodeUpdateStep {
  /// Creates the state.
  const NodeUpdateStepFailed(this.error);

  /// Why.
  final NodeUpdateException error;

  @override
  bool get busy => false;

  @override
  List<Object?> get props => <Object?>[error];
}

/// Everything the Embedded node panel shows.
class NodeUpdatePanelState extends Equatable {
  /// Creates a state.
  const NodeUpdatePanelState({
    required this.repository,
    this.load = NodeUpdateLoad.loading,
    this.library,
    this.check = const NodeUpdateCheckIdle(),
    this.step = const NodeUpdateStepIdle(),
  });

  /// Whether [library] has been read.
  final NodeUpdateLoad load;

  /// What is loaded, installed, staged and marked bad. Null until read.
  final NodeLibraryStatus? library;

  /// The repository Check reads, as `owner/name`.
  final String repository;

  /// The last Check.
  final NodeUpdateCheck check;

  /// The install or roll back under way.
  final NodeUpdateStep step;

  /// Whether Check, an install or a roll back may start now.
  bool get idle => !step.busy && check is! NodeUpdateCheckRunning;

  /// A copy with the given fields replaced.
  NodeUpdatePanelState copyWith({
    NodeUpdateLoad? load,
    NodeLibraryStatus? library,
    String? repository,
    NodeUpdateCheck? check,
    NodeUpdateStep? step,
  }) {
    return NodeUpdatePanelState(
      load: load ?? this.load,
      library: library ?? this.library,
      repository: repository ?? this.repository,
      check: check ?? this.check,
      step: step ?? this.step,
    );
  }

  @override
  List<Object?> get props => <Object?>[load, library, repository, check, step];
}
