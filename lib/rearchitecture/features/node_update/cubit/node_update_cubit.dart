import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_updater.dart';

part 'node_update_state.dart';

/// Makes the updater for a repository. An updater reads one repository for
/// its whole life, so a change of repository asks for a new one.
typedef NodeUpdaterFactory = NodeUpdater Function(NodeUpdateSource source);

/// Drives the Embedded node panel: what is loaded, what the repository has
/// published, and the steps of an install or a roll back.
///
/// The library it installs runs in the process that holds the wallet's keys,
/// so nothing here starts by itself. [load] reads the disk and nothing else.
/// The network is touched by [check], [download] and [downloadUnverified],
/// and a library is only staged by [confirmInstall]: each is a press of a
/// button, and the last one comes after the person has been shown what the
/// library is. [downloadUnverified] does nothing unless the state is the
/// refusal it answers, so no caller can skip that question.
class NodeUpdateCubit extends Cubit<NodeUpdatePanelState> {
  /// Creates the cubit over `library`, the loader whose override directory
  /// is shown and staged into.
  ///
  /// [repository] is the saved one; anything that is not `owner/name` falls
  /// back to the default. `saveRepository` keeps a new one for the next
  /// start.
  NodeUpdateCubit({
    required this._library,
    required this._updaterFor,
    required this._saveRepository,
    String? repository,
  }) : super(
         NodeUpdatePanelState(
           repository:
               (NodeUpdateSource.tryParse(repository ?? '') ??
                       NodeUpdateSource())
                   .repository,
         ),
       );

  final NodeLibrary _library;
  final NodeUpdaterFactory _updaterFor;
  final Future<void> Function(String repository) _saveRepository;

  /// The updater of [NodeUpdatePanelState.repository]; made when first
  /// needed, so opening the panel opens no connection.
  NodeUpdater? _made;

  /// Stops the download under way.
  CancelToken? _cancel;

  /// The release whose library has been downloaded in this session, and that
  /// library's sha256: what lets a release be compared with a library that
  /// has no tag, such as the bundled one.
  NodeRelease? _hashedRelease;
  String? _hashedSha256;

  NodeUpdater get _updater =>
      _made ??= _updaterFor(NodeUpdateSource(state.repository));

  /// Reads what is loaded, installed, staged and marked bad. Disk only.
  Future<void> load() => _reload();

  /// Asks the repository for its newest release. Nothing is downloaded.
  Future<void> check() async {
    if (isClosed || !state.idle) {
      return;
    }
    final NodeUpdater updater = _updater;
    emit(state.copyWith(check: const NodeUpdateCheckRunning()));
    NodeUpdateCheck answer;
    try {
      final NodeRelease? release = await updater.latestRelease();
      _hashedRelease = null;
      _hashedSha256 = null;
      answer = NodeUpdateCheckDone(
        release: release,
        comparison: release == null
            ? NodeUpdateState.unknown
            : _compare(state.library, release),
      );
    } on NodeUpdateException catch (e) {
      answer = NodeUpdateCheckFailed(e);
    } on Exception catch (e) {
      answer = NodeUpdateCheckFailed(NodeUpdateMalformedResponse('$e'));
    }
    _emit(state.copyWith(check: answer));
  }

  /// Downloads the library of the release Check found, to a temporary file.
  /// Ends in [NodeUpdateConfirmAsk], or in [NodeUpdateUnverifiedAsk] when
  /// the release publishes no hash to check it against.
  Future<void> download() async {
    final NodeUpdateCheck check = state.check;
    if (isClosed ||
        !state.idle ||
        check is! NodeUpdateCheckDone ||
        !check.downloadable) {
      return;
    }
    await _download(check.release!, allowUnverified: false);
  }

  /// The person's yes to [NodeUpdateUnverifiedAsk]: downloads that release
  /// with nothing to check it against. Ends in [NodeUpdateConfirmAsk] like
  /// any other download; the install is still to be confirmed.
  Future<void> downloadUnverified() async {
    final NodeUpdateStep step = state.step;
    if (isClosed || step is! NodeUpdateUnverifiedAsk) {
      return;
    }
    await _download(step.release, allowUnverified: true);
  }

  /// Stops the download under way. Nothing of it stays on disk.
  void cancelDownload() => _cancel?.cancel();

  /// Takes a library, or an archive of one, that the person picked. Ends in
  /// [NodeUpdateConfirmAsk].
  Future<void> installFromFile(File file) async {
    if (isClosed || !state.idle) {
      return;
    }
    final NodeUpdater updater = _updater;
    emit(
      state.copyWith(step: NodeUpdateReadingFile(path.basename(file.path))),
    );
    try {
      final DownloadedNodeLibrary downloaded = await updater.fromFile(file);
      if (isClosed) {
        updater.discard(downloaded);
        return;
      }
      emit(state.copyWith(step: NodeUpdateConfirmAsk(downloaded)));
    } on NodeUpdateException catch (e) {
      _emit(state.copyWith(step: NodeUpdateStepFailed(e)));
    }
  }

  /// The person's yes to [NodeUpdateConfirmAsk]: stages the library for the
  /// next start.
  Future<void> confirmInstall() async {
    final NodeUpdateStep step = state.step;
    if (isClosed || step is! NodeUpdateConfirmAsk) {
      return;
    }
    final NodeUpdater updater = _updater;
    emit(state.copyWith(step: NodeUpdateStaging(step.library)));
    NodeUpdateStep next = const NodeUpdateStepIdle();
    try {
      await updater.stage(step.library);
    } on NodeUpdateException catch (e) {
      next = NodeUpdateStepFailed(e);
    }
    await _reload(next);
  }

  /// The person's no to either question. A downloaded library is deleted.
  void cancelInstall() {
    final NodeUpdateStep step = state.step;
    if (isClosed) {
      return;
    }
    if (step is NodeUpdateConfirmAsk) {
      _updater.discard(step.library);
    } else if (step is! NodeUpdateUnverifiedAsk) {
      return;
    }
    emit(state.copyWith(step: const NodeUpdateStepIdle()));
  }

  /// Removes the installed override and anything staged, so the next start
  /// loads the bundled library.
  Future<void> useBundled() async {
    if (isClosed || !state.idle) {
      return;
    }
    NodeUpdateStep next = const NodeUpdateStepIdle();
    try {
      _library.rollback();
    } on FileSystemException catch (e) {
      next = NodeUpdateStepFailed(NodeUpdateFileError('$e'));
    }
    await _reload(next);
  }

  /// Puts back the override the last install replaced, for the next start.
  Future<void> usePrevious() async {
    if (isClosed || !state.idle) {
      return;
    }
    NodeUpdateStep next = const NodeUpdateStepIdle();
    try {
      if (!_library.restorePrevious()) {
        next = const NodeUpdateStepFailed(
          NodeUpdateFileError('no previous library to restore'),
        );
      }
    } on FileSystemException catch (e) {
      next = NodeUpdateStepFailed(NodeUpdateFileError('$e'));
    }
    await _reload(next);
  }

  /// Makes [repository] the one the next Check reads, and saves it. False
  /// when it is not `owner/name`, or while something is under way.
  ///
  /// The last Check is forgotten: its release belongs to the repository
  /// just left.
  Future<bool> setRepository(String repository) async {
    final NodeUpdateSource? source = NodeUpdateSource.tryParse(repository);
    if (isClosed || source == null || !state.idle) {
      return false;
    }
    if (source.repository == state.repository) {
      return true;
    }
    _made?.close();
    _made = null;
    _hashedRelease = null;
    _hashedSha256 = null;
    emit(
      state.copyWith(
        repository: source.repository,
        check: const NodeUpdateCheckIdle(),
        step: const NodeUpdateStepIdle(),
      ),
    );
    try {
      await _saveRepository(source.repository);
    } on Exception catch (e) {
      // In force until the wallet closes, and said not to have been kept.
      _emit(
        state.copyWith(step: NodeUpdateStepFailed(NodeUpdateFileError('$e'))),
      );
    }
    return true;
  }

  Future<void> _download(
    NodeRelease release, {
    required bool allowUnverified,
  }) async {
    final NodeUpdater updater = _updater;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    final int expected = release.asset?.size ?? 0;
    int shown = 0;
    emit(
      state.copyWith(
        step: NodeUpdateDownloading(received: 0, total: expected),
      ),
    );
    try {
      final DownloadedNodeLibrary downloaded = await updater.download(
        release,
        allowUnverified: allowUnverified,
        cancel: cancel,
        onProgress: (int received, int total) {
          // A chunk is a few kilobytes; a state for each would rebuild the
          // bar thousands of times for one download.
          if (isClosed ||
              cancel.isCancelled ||
              (received < total && received - shown < total ~/ 200)) {
            return;
          }
          shown = received;
          emit(
            state.copyWith(
              step: NodeUpdateDownloading(received: received, total: total),
            ),
          );
        },
      );
      if (isClosed) {
        updater.discard(downloaded);
        return;
      }
      _hashedRelease = release;
      _hashedSha256 = downloaded.sha256;
      final NodeUpdateCheck check = state.check;
      emit(
        state.copyWith(
          step: NodeUpdateConfirmAsk(downloaded),
          check: check is NodeUpdateCheckDone && check.release == release
              ? NodeUpdateCheckDone(
                  release: release,
                  comparison: _compare(state.library, release),
                )
              : null,
        ),
      );
    } on NodeUpdateCancelled {
      _emit(state.copyWith(step: const NodeUpdateStepIdle()));
    } on NodeUpdateUnverified catch (e) {
      _emit(
        state.copyWith(
          step: NodeUpdateUnverifiedAsk(
            release: release,
            checksumFile: e.checksumFile,
          ),
        ),
      );
    } on NodeUpdateException catch (e) {
      _emit(state.copyWith(step: NodeUpdateStepFailed(e)));
    } finally {
      if (identical(_cancel, cancel)) {
        _cancel = null;
      }
    }
  }

  /// Reads the disk again and shows it, with [step] as the step when given.
  Future<void> _reload([NodeUpdateStep? step]) async {
    NodeLibraryStatus? status;
    try {
      status = await _library.status();
    } on Exception {
      // Shown as a panel that could not be read, or, after an action, as
      // what was read before it.
    }
    if (isClosed) {
      return;
    }
    if (status == null) {
      emit(
        state.copyWith(
          load: state.library == null ? NodeUpdateLoad.failed : null,
          step: step,
        ),
      );
      return;
    }
    final NodeUpdateCheck check = state.check;
    final NodeRelease? release = check is NodeUpdateCheckDone
        ? check.release
        : null;
    emit(
      state.copyWith(
        load: NodeUpdateLoad.ready,
        library: status,
        step: step,
        check: release == null
            ? null
            : NodeUpdateCheckDone(
                release: release,
                comparison: _compare(status, release),
              ),
      ),
    );
  }

  NodeUpdateState _compare(NodeLibraryStatus? status, NodeRelease release) =>
      status == null
      ? NodeUpdateState.unknown
      : NodeUpdater.compare(
          status,
          release,
          librarySha256: identical(release, _hashedRelease)
              ? _hashedSha256
              : null,
        );

  void _emit(NodeUpdatePanelState next) {
    if (!isClosed) {
      emit(next);
    }
  }

  /// Stops a download, deletes a library still waiting for its answer, and
  /// closes the connection.
  @override
  Future<void> close() {
    _cancel?.cancel();
    final NodeUpdateStep step = state.step;
    if (step is NodeUpdateConfirmAsk) {
      _made?.discard(step.library);
    }
    _made?.close();
    _made = null;
    return super.close();
  }
}
