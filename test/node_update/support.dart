// Stand-ins for the loader and the updater, so the panel and its cubit can
// be driven without a disk, a library or a network.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_updater.dart';

const String kRepo = NodeUpdateSource.defaultRepository;
const String kTag = 'v0.0.9';
const String kAsset = 'libznn-windows-amd64.zip';

/// Three sha256 values, each 64 hex digits.
const String kBundledSha =
    '1111111111aaaaaaaaaa2222222222bbbbbbbbbb3333333333cccccccccc4444';
const String kNewSha =
    '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
const String kOldSha =
    '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae';

final DateTime _then = DateTime.utc(2026, 10, 12, 9);

NodeLibraryManifest manifestOf({
  String source = kRepo,
  String? tag = kTag,
  String asset = kAsset,
  String sha256 = kNewSha,
}) => NodeLibraryManifest(
  source: source,
  tag: tag,
  asset: asset,
  sha256: sha256,
  installedAt: _then,
);

/// What the loader reports. With nothing passed: the bundled library is
/// loaded and nothing else is on disk.
NodeLibraryStatus statusOf({
  bool running = true,
  NodeLibraryManifest? loadedOverride,
  NodeLibraryManifest? installed,
  NodeLibraryManifest? staged,
  NodeLibraryManifest? previous,
  NodeLibraryBadMarker? bad,
}) {
  const String bundledPath = 'bundled/libznn.dll';
  const String overridePath = 'node/libznn.dll';
  // An override marked bad is passed over for the bundled library.
  final bool usable = installed != null && bad?.sha256 != installed.sha256;
  return NodeLibraryStatus(
    loaded: !running
        ? null
        : LoadedNodeLibrary(
            path: loadedOverride == null ? bundledPath : overridePath,
            kind: loadedOverride == null
                ? NodeLibraryKind.bundled
                : NodeLibraryKind.override,
            pid: 1,
            loadedAt: _then,
            manifest: loadedOverride,
          ),
    next: usable
        ? ResolvedNodeLibrary(
            path: overridePath,
            kind: NodeLibraryKind.override,
            manifest: installed,
          )
        : ResolvedNodeLibrary(path: bundledPath, kind: NodeLibraryKind.bundled),
    installed: installed,
    staged: staged,
    previous: previous,
    bad: bad,
    stagedRejected: null,
    bundledPath: bundledPath,
    bundledSha256: kBundledSha,
  );
}

NodeRelease releaseOf({
  String tag = kTag,
  String repository = kRepo,
  bool withAsset = true,
}) => NodeRelease(
  repository: repository,
  tag: tag,
  name: tag,
  pageUrl: Uri.https('github.com', '/$repository/releases/tag/$tag'),
  publishedAt: _then,
  asset: withAsset
      ? NodeReleaseAsset(
          name: kAsset,
          size: 100,
          downloadUrl: Uri.https(
            'github.com',
            '/$repository/releases/download/$tag/$kAsset',
          ),
        )
      : null,
);

/// A library waiting for its answer. The file is never touched: the fakes
/// stage and discard by name only.
DownloadedNodeLibrary downloadedOf({
  String source = kRepo,
  String? tag = kTag,
  String asset = kAsset,
  String sha256 = kNewSha,
  NodeChecksumFileCheck? checksumFile = NodeChecksumFileCheck.verified,
  NodeApiDigestCheck? apiDigest = NodeApiDigestCheck.absent,
}) => DownloadedNodeLibrary(
  file: File('not-on-disk-$sha256'),
  sha256: sha256,
  size: 4096,
  source: source,
  tag: tag,
  asset: asset,
  checksumFile: checksumFile,
  apiDigest: apiDigest,
);

/// A library picked from disk: no tag, and no release to check it against.
DownloadedNodeLibrary pickedOf({String name = 'libznn.dll'}) => downloadedOf(
  source: NodeUpdateSource.file,
  tag: null,
  asset: name,
  checksumFile: null,
  apiDigest: null,
);

/// The loader, as far as the panel uses it.
class FakeNodeLibrary extends Fake implements NodeLibrary {
  FakeNodeLibrary([NodeLibraryStatus? status]) : current = status ?? statusOf();

  /// What [status] answers.
  NodeLibraryStatus current;

  /// Thrown by [status] when set.
  Exception? statusFailure;

  /// What [restorePrevious] answers.
  bool restores = true;

  /// What [status] answers after a [rollback] or a [restorePrevious].
  NodeLibraryStatus? afterRollback;

  final List<String> calls = <String>[];

  @override
  String get directory => 'node';

  @override
  Future<NodeLibraryStatus> status() async {
    if (statusFailure != null) {
      throw statusFailure!;
    }
    return current;
  }

  @override
  void rollback() {
    calls.add('rollback');
    current = afterRollback ?? statusOf();
  }

  @override
  bool restorePrevious() {
    calls.add('restorePrevious');
    if (restores) {
      current = afterRollback ?? current;
    }
    return restores;
  }
}

/// GitHub and the download folder, as far as the panel uses them. Every
/// call is written to [calls], so a test can say what was never asked.
class FakeNodeUpdater extends Fake implements NodeUpdater {
  FakeNodeUpdater(this.library, [NodeUpdateSource? source])
    : source = source ?? NodeUpdateSource();

  @override
  final FakeNodeLibrary library;

  @override
  final NodeUpdateSource source;

  /// What [latestRelease] answers: a release, null for none, or the
  /// exception to throw.
  Object? latest;

  /// What each [download] answers, in order: the library, or the exception
  /// to throw.
  final List<Object> downloads = <Object>[];

  /// The progress reported before a download answers.
  List<(int, int)> progress = <(int, int)>[(50, 100), (100, 100)];

  /// When set, a download waits for it, or for its cancel token.
  Completer<void>? hold;

  /// What [fromFile] answers: the library, or the exception to throw.
  Object? picked;

  /// Thrown by [stage] when set.
  NodeUpdateException? stageFailure;

  bool closed = false;

  final List<String> calls = <String>[];

  @override
  Future<NodeRelease?> latestRelease({bool includePrereleases = false}) async {
    calls.add('latestRelease ${source.repository}');
    final Object? answer = latest;
    if (answer is Exception) {
      throw answer;
    }
    return answer as NodeRelease?;
  }

  @override
  Future<DownloadedNodeLibrary> download(
    NodeRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
    bool allowUnverified = false,
  }) async {
    calls.add('download ${release.tag} allowUnverified=$allowUnverified');
    for (final (int received, int total) in progress) {
      onProgress?.call(received, total);
    }
    final Completer<void>? waiting = hold;
    if (waiting != null) {
      await Future.any<void>(<Future<void>>[
        waiting.future,
        cancel!.whenCancelled,
      ]);
      if (cancel.isCancelled) {
        throw const NodeUpdateCancelled();
      }
    }
    final Object answer = downloads.removeAt(0);
    if (answer is Exception) {
      throw answer;
    }
    return answer as DownloadedNodeLibrary;
  }

  @override
  Future<DownloadedNodeLibrary> fromFile(File picked) async {
    calls.add('fromFile ${path.basename(picked.path)}');
    final Object? answer = this.picked;
    if (answer is Exception) {
      throw answer;
    }
    return answer! as DownloadedNodeLibrary;
  }

  @override
  Future<void> stage(DownloadedNodeLibrary downloaded) async {
    calls.add('stage ${downloaded.sha256}');
    if (stageFailure != null) {
      throw stageFailure!;
    }
    library.current = statusOf(
      staged: manifestOf(
        source: downloaded.source,
        tag: downloaded.tag,
        asset: downloaded.asset,
        sha256: downloaded.sha256,
      ),
    );
  }

  @override
  void discard(DownloadedNodeLibrary downloaded) {
    calls.add('discard ${downloaded.sha256}');
  }

  @override
  void close() {
    closed = true;
  }
}
