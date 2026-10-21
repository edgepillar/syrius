/// Which libznn the wallet loads, and the files that decide it.
///
/// The node is a native library bundled beside the executable. A newer node
/// used to mean a new Syrius release; an override directory in the user's
/// profile lets the installed app load another build instead.
///
/// The directory is `<Syrius data>/node` (see
/// [NodeLibrary.defaultOverrideDirectory]) and holds, with `<ext>` being
/// `.dll`, `.so` or `.dylib`:
///
/// | File | Written by | Meaning |
/// |---|---|---|
/// | `libznn<ext>`, `libznn.json` | `promoteStaged`, `restorePrevious` | the installed override and its manifest |
/// | `libznn.next<ext>`, `libznn.next.json` | `stage` | a library waiting for the next start |
/// | `libznn.next<ext>.part` | `stage` | the copy still being written; renamed to `libznn.next<ext>` once its hash is right |
/// | `libznn.prev<ext>`, `libznn.prev.json` | `promoteStaged`, `restorePrevious` | the override the last promotion replaced |
/// | `libznn.swap<ext>`, `libznn.swap.json` | `restorePrevious` | the override, for the moment the two pairs change places |
/// | `libznn.removed<ext>` | `rollback` | a loaded override that could not be deleted, renamed aside; the next start's `promoteStaged` deletes it |
/// | `libznn.bad.json` | `load` | the sha256 of an override that failed to open, or that the wallet did not survive at two starts in a row, and why |
/// | `libznn.next.bad.json` | `promoteStaged` | the staged library that was thrown away, and why |
/// | `libznn.starting.json` | `load` | the override being started: its sha256, the pid, the time and how many starts in a row it has failed. Removed by `confirmStarted`; one left behind is a start the process did not survive |
/// | `libznn.loaded.json` | `load` | what this process loaded, keyed by its pid |
/// | `download/` | `NodeUpdater`, in `node_updater.dart` | the archive being downloaded and the library unpacked from it, until it is staged or thrown away. The loader never reads it |
///
/// Every JSON file is written as `<name>.tmp` and renamed over its target.
///
/// Everything here is `dart:io`, and `dart:ffi` for the one question the
/// start-up guard asks the system: whether a pid is running. The loader runs
/// inside the node's isolate, where no Flutter binding, shared preference or
/// service locator exists, so nothing in this file may reach for one.
///
/// An override is only ever loaded when its sha256 equals the one in its
/// manifest. That is a check against a truncated download or a half-written
/// file, not against an attacker: whoever can write the library can write
/// the manifest beside it. Deciding what is worth installing is the
/// installer's job.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show znnDefaultPaths;

final Logger _log = Logger('EmbeddedNode');

/// Where a library came from.
enum NodeLibraryKind {
  /// The one shipped beside the executable.
  bundled,

  /// The one installed in the override directory.
  override,
}

/// What [NodeLibrary.promoteStaged] did.
enum PromotionOutcome {
  /// No complete staged pair was waiting.
  nothingStaged,

  /// The staged pair is now the override.
  promoted,

  /// The staged pair did not verify and was deleted.
  discarded,

  /// The file system refused a rename. Whatever is on disk is still whole.
  failed,
}

/// A failure the installer should show to the user.
class NodeLibraryException implements Exception {
  NodeLibraryException(this.message);

  final String message;

  @override
  String toString() => 'NodeLibraryException: $message';
}

/// Neither a usable override nor a bundled library exists.
class NodeLibraryNotFoundException implements Exception {
  @override
  String toString() => 'NodeLibraryNotFoundException';
}

/// `libznn.json` and its `next` and `prev` siblings.
class NodeLibraryManifest {
  NodeLibraryManifest({
    required this.source,
    required this.asset,
    required String sha256,
    this.tag,
    DateTime? installedAt,
  })  : sha256 = sha256.toLowerCase(),
        installedAt = (installedAt ?? DateTime.now()).toUtc();

  /// Null when [json] names no usable sha256: without it the manifest says
  /// nothing the loader can check.
  static NodeLibraryManifest? fromJson(Map<String, dynamic> json) {
    final Object? sha256 = json['sha256'];
    if (sha256 is! String || !_sha256Pattern.hasMatch(sha256)) {
      return null;
    }
    final Object? source = json['source'];
    final Object? tag = json['tag'];
    final Object? asset = json['asset'];
    final Object? installedAt = json['installedAt'];
    return NodeLibraryManifest(
      source: source is String ? source : '',
      tag: tag is String ? tag : null,
      asset: asset is String ? asset : '',
      sha256: sha256,
      installedAt: installedAt is String
          ? DateTime.tryParse(installedAt) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// The repository the library was downloaded from, or `file`.
  final String source;

  /// The release tag, when [source] is a repository.
  final String? tag;

  /// The release asset's name, or the original file's.
  final String asset;

  /// Lower-case hex.
  final String sha256;

  /// UTC. Set when the library was staged; promotion renames the manifest
  /// and does not rewrite it.
  final DateTime installedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'tag': tag,
        'asset': asset,
        'sha256': sha256,
        'installedAt': installedAt.toIso8601String(),
      };

  @override
  String toString() => tag == null ? '$source $asset' : '$source $tag';
}

/// This process already holds a node library, and it is not the one a fresh
/// start would open: the one it holds could not be opened again, or there
/// is no record of which it was. Opening another would put two Go runtimes,
/// and two nodes, into the process that holds the wallet's keys. The
/// embedded node starts again once the wallet has been closed and reopened.
class NodeLibraryHeldException implements Exception {
  NodeLibraryHeldException(this.message);

  final String message;

  @override
  String toString() => 'NodeLibraryHeldException: $message';
}

/// Why a library was marked bad.
enum NodeLibraryBadCause {
  /// It did not open, or lacks a symbol the wallet calls.
  open,

  /// It opened, and the wallet did not survive
  /// [NodeLibrary.maxFailedStarts] starts in a row with it.
  start,

  /// It was staged and did not match its manifest at promotion.
  mismatch,
}

/// `libznn.bad.json` and `libznn.next.bad.json`.
class NodeLibraryBadMarker {
  NodeLibraryBadMarker({
    required this.sha256,
    required this.reason,
    required this.at,
    this.cause = NodeLibraryBadCause.open,
  });

  static NodeLibraryBadMarker? fromJson(Map<String, dynamic> json) {
    final Object? sha256 = json['sha256'];
    final Object? reason = json['reason'];
    final Object? at = json['at'];
    final Object? cause = json['cause'];
    if (sha256 is! String) {
      return null;
    }
    return NodeLibraryBadMarker(
      sha256: sha256.toLowerCase(),
      reason: reason is String ? reason : '',
      at: at is String
          ? DateTime.tryParse(at) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      // A marker written before there was a cause is a failed open: nothing
      // else was marked then.
      cause: NodeLibraryBadCause.values.firstWhere(
        (NodeLibraryBadCause value) => value.name == cause,
        orElse: () => NodeLibraryBadCause.open,
      ),
    );
  }

  /// The sha256 of the file that failed.
  final String sha256;

  /// For whoever reads the file. The panel shows a sentence chosen by
  /// [cause], never this.
  final String reason;
  final DateTime at;
  final NodeLibraryBadCause cause;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sha256': sha256,
        'cause': cause.name,
        'reason': reason,
        'at': at.toUtc().toIso8601String(),
      };
}

/// `libznn.starting.json`: an override the loader was about to open.
///
/// Written before the open and removed by [NodeLibrary.confirmStarted], so
/// one that is still there at the next start, with its process gone, is a
/// start the wallet did not survive.
class NodeLibraryStartMarker {
  NodeLibraryStartMarker({
    required this.sha256,
    required this.pid,
    required this.at,
    required this.failures,
  });

  static NodeLibraryStartMarker? fromJson(Map<String, dynamic> json) {
    final Object? sha256 = json['sha256'];
    final Object? processId = json['pid'];
    final Object? at = json['at'];
    final Object? failures = json['failures'];
    if (sha256 is! String || processId is! int) {
      return null;
    }
    return NodeLibraryStartMarker(
      sha256: sha256.toLowerCase(),
      pid: processId,
      at: at is String
          ? DateTime.tryParse(at) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      failures: failures is int && failures > 0 ? failures : 0,
    );
  }

  /// The sha256 of the override being started.
  final String sha256;

  /// The process that is starting it.
  final int pid;
  final DateTime at;

  /// The starts in a row, before this one, that the wallet did not survive
  /// with this override.
  final int failures;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sha256': sha256,
        'pid': pid,
        'at': at.toUtc().toIso8601String(),
        'failures': failures,
      };
}

/// The answer of [NodeLibrary.resolve].
class ResolvedNodeLibrary {
  ResolvedNodeLibrary({
    required this.path,
    required this.kind,
    this.manifest,
    this.refusal,
  });

  final String path;
  final NodeLibraryKind kind;

  /// The override's manifest. Null for the bundled library.
  final NodeLibraryManifest? manifest;

  /// Why an installed override was passed over. Null when there is none or
  /// when it is the one chosen.
  final String? refusal;
}

/// `libznn.loaded.json`: what a process loaded.
class LoadedNodeLibrary {
  LoadedNodeLibrary({
    required this.path,
    required this.kind,
    required this.pid,
    required this.loadedAt,
    this.manifest,
  });

  static LoadedNodeLibrary? fromJson(Map<String, dynamic> json) {
    final Object? libraryPath = json['path'];
    final Object? kind = json['kind'];
    final Object? processId = json['pid'];
    final Object? loadedAt = json['loadedAt'];
    final Object? manifest = json['manifest'];
    if (libraryPath is! String || processId is! int) {
      return null;
    }
    return LoadedNodeLibrary(
      path: libraryPath,
      kind: kind == NodeLibraryKind.override.name
          ? NodeLibraryKind.override
          : NodeLibraryKind.bundled,
      pid: processId,
      loadedAt: loadedAt is String
          ? DateTime.tryParse(loadedAt) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      manifest: manifest is Map<String, dynamic>
          ? NodeLibraryManifest.fromJson(manifest)
          : null,
    );
  }

  final String path;
  final NodeLibraryKind kind;
  final int pid;
  final DateTime loadedAt;
  final NodeLibraryManifest? manifest;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'kind': kind.name,
        'pid': pid,
        'loadedAt': loadedAt.toUtc().toIso8601String(),
        'manifest': manifest?.toJson(),
      };
}

/// The answer of [NodeLibrary.promoteStaged].
class PromotionResult {
  PromotionResult(this.outcome, {this.manifest, this.reason});

  final PromotionOutcome outcome;

  /// The promoted manifest.
  final NodeLibraryManifest? manifest;

  /// Why the pair was discarded, or what the file system refused.
  final String? reason;
}

/// The answer of [NodeLibrary.status].
class NodeLibraryStatus {
  NodeLibraryStatus({
    required this.loaded,
    required this.next,
    required this.installed,
    required this.staged,
    required this.previous,
    required this.bad,
    required this.stagedRejected,
    required this.bundledPath,
    required this.bundledSha256,
  });

  /// What this process has loaded. Null while the embedded node has not been
  /// started in it.
  final LoadedNodeLibrary? loaded;

  /// What a start would load from what is installed now: differs from
  /// [loaded] after a rollback or a restore. A [staged] pair is not counted
  /// in; the next start promotes it first, if it verifies. Null when there
  /// is nothing to load at all.
  final ResolvedNodeLibrary? next;

  /// The installed override's manifest, whether or not it is usable;
  /// [next] says if it is.
  final NodeLibraryManifest? installed;

  /// The manifest of the pair waiting for the next start.
  final NodeLibraryManifest? staged;

  /// The manifest [NodeLibrary.restorePrevious] would bring back.
  final NodeLibraryManifest? previous;

  /// The override that failed to open, or that the wallet did not survive
  /// at two starts in a row; [NodeLibraryBadMarker.cause] says which.
  final NodeLibraryBadMarker? bad;

  /// The staged library that was thrown away at promotion.
  final NodeLibraryBadMarker? stagedRejected;

  final String? bundledPath;
  final String? bundledSha256;
}

/// Opens the library at a path and looks up the symbols the wallet calls.
/// Throws when the library cannot be opened or a symbol is missing. Tests
/// replace it; the real one is in `embedded_node.dart`.
typedef NodeLibraryOpener = void Function(String libraryPath);

class NodeLibrary {
  /// [isProcessRunning] answers whether a pid is a live process; the
  /// system is asked when it is not given. Tests give their own.
  NodeLibrary({
    required this.directory,
    required this.bundledSearchPaths,
    int? processId,
    DateTime Function()? now,
    bool Function(int pid)? isProcessRunning,
  })  : processId = processId ?? pid,
        _now = now ?? _utcNow,
        _isProcessRunning = isProcessRunning ?? processIsRunning;

  /// The override directory and bundled search paths of the running app.
  ///
  /// Works in any isolate: both come from the environment and the
  /// executable's path. Keep the instance where [status] is polled, so the
  /// bundled library is hashed once and not on every call.
  factory NodeLibrary.forThisInstall() => NodeLibrary(
        directory: defaultOverrideDirectory(),
        bundledSearchPaths: defaultBundledSearchPaths(),
      );

  /// The starts in a row the wallet may fail to survive with one override
  /// before it is marked bad. Two, not one: a single unclean exit is as
  /// likely the user ending the task, or the power going, as the library.
  static const int maxFailedStarts = 2;

  /// `<Syrius data>/node`, the Syrius data directory being the SDK's
  /// `znnDefaultPaths.cache`, where the wallet keeps its Hive boxes and
  /// logs:
  ///
  /// - Windows: `%AppData%\znn\syrius\node`
  /// - Linux: `$HOME/.znn/syrius/node`
  /// - macOS: `$HOME/Library/znn/syrius/node`
  ///
  /// The SDK derives it from the environment alone, which every isolate of
  /// the process shares, so the node's isolate finds the same directory the
  /// main one does without being told.
  static String defaultOverrideDirectory() =>
      path.join(znnDefaultPaths.cache.path, 'node');

  /// Where the bundled library may be, in the order tried: the working
  /// directory, the source tree's blobs under it, beside the executable, the
  /// macOS bundle's `Resources`, and the blobs of a checkout named `syrius`
  /// beside the working directory.
  static List<String> defaultBundledSearchPaths() {
    final String insideSdk =
        path.join('syrius', 'lib', 'embedded_node', 'blobs');
    final List<String> currentPathListParts =
        path.split(Directory.current.path)..removeLast();
    final List<String> executablePathListParts =
        path.split(Platform.resolvedExecutable)..removeLast();
    final String besideExecutable = path.joinAll(executablePathListParts);
    executablePathListParts.removeLast();
    return <String>[
      Directory.current.path,
      path.join(Directory.current.path, 'lib', 'embedded_node', 'blobs'),
      besideExecutable,
      path.join(path.joinAll(executablePathListParts), 'Resources'),
      path.join(path.joinAll(currentPathListParts), insideSdk),
    ];
  }

  /// `.dll`, `.dylib` or `.so`.
  static String get extension {
    if (Platform.isWindows) {
      return '.dll';
    }
    if (Platform.isMacOS) {
      return '.dylib';
    }
    return '.so';
  }

  /// `libznn.dll`, `libznn.dylib` or `libznn.so`.
  static String get libraryFileName => 'libznn$extension';

  final String directory;
  final List<String> bundledSearchPaths;

  /// Identifies this process in `libznn.loaded.json`.
  final int processId;
  final DateTime Function() _now;
  final bool Function(int pid) _isProcessRunning;

  /// Verified hashes, keyed by path, size and modification time. In memory
  /// only: a hash is never trusted across a restart.
  final Map<String, String> _hashes = <String, String>{};

  File get overrideLibrary => _file(libraryFileName);
  File get overrideManifest => _file('libznn.json');
  File get stagedLibrary => _file('libznn.next$extension');
  File get stagedManifest => _file('libznn.next.json');
  File get previousLibrary => _file('libznn.prev$extension');
  File get previousManifest => _file('libznn.prev.json');
  File get badMarker => _file('libznn.bad.json');
  File get stagedBadMarker => _file('libznn.next.bad.json');
  File get startingMarker => _file('libznn.starting.json');
  File get loadedRecord => _file('libznn.loaded.json');

  // A rollback could not delete a loaded library and renamed it here.
  File get _removedLibrary => _file('libznn.removed$extension');
  // The copy [stage] is still writing.
  File get _partialStagedLibrary => _file('libznn.next$extension.part');
  File get _swapLibrary => _file('libznn.swap$extension');
  File get _swapManifest => _file('libznn.swap.json');

  /// Makes a staged pair the override, before anything is loaded.
  ///
  /// When `libznn.next<ext>` and `libznn.next.json` both exist and the
  /// file's sha256 equals the manifest's, the current override is renamed to
  /// `libznn.prev.*` and the staged pair renamed into its place. Otherwise
  /// the staged pair is deleted and the reason written to
  /// `libznn.next.bad.json`.
  ///
  /// Only renames, so a crash at any step leaves whole files. A crash
  /// between two renames can leave a library beside the wrong manifest or
  /// none; [resolve] refuses such a pair and loads the bundled library, and
  /// the next call here finishes the promotion if the staged manifest is
  /// still waiting.
  PromotionResult promoteStaged() {
    try {
      return _promoteStaged();
    } on FileSystemException catch (e) {
      _log.log(Level.SEVERE, 'Could not promote the staged libznn', e);
      return PromotionResult(PromotionOutcome.failed, reason: e.toString());
    }
  }

  PromotionResult _promoteStaged() {
    // Left by a rollback that ran while the library was loaded.
    _deleteIfPossible(_removedLibrary);

    final File library = stagedLibrary;
    final File manifestFile = stagedManifest;
    if (!library.existsSync()) {
      return _finishInterruptedPromotion();
    }
    if (!manifestFile.existsSync()) {
      // [stage] writes the manifest last: the library is still arriving, or
      // its installer died. Either way it is not a pair yet.
      return PromotionResult(PromotionOutcome.nothingStaged);
    }

    final NodeLibraryManifest? manifest = _readManifest(manifestFile);
    final String actual = _hash(library.path);
    if (manifest == null || manifest.sha256 != actual) {
      final String reason = manifest == null
          ? 'the staged manifest is unreadable or names no sha256'
          : 'the staged library does not match its manifest, which names '
              '${manifest.sha256}';
      manifestFile.deleteSync();
      library.deleteSync();
      _writeJson(
        stagedBadMarker,
        NodeLibraryBadMarker(
          sha256: actual,
          reason: reason,
          at: _now(),
          cause: NodeLibraryBadCause.mismatch,
        ).toJson(),
      );
      _log.log(Level.WARNING, 'Discarded the staged libznn $actual: $reason');
      return PromotionResult(PromotionOutcome.discarded, reason: reason);
    }

    if (overrideLibrary.existsSync()) {
      // The manifest goes first: a library whose manifest has already left
      // is refused by resolve, one beside a stranger's manifest fails its
      // hash. Neither order can pair a library with a manifest that
      // vouches for it wrongly.
      if (overrideManifest.existsSync()) {
        overrideManifest.renameSync(previousManifest.path);
      } else {
        _deleteIfPossible(previousManifest);
      }
      overrideLibrary.renameSync(previousLibrary.path);
    }
    final String target = overrideLibrary.path;
    library.renameSync(target);
    manifestFile.renameSync(overrideManifest.path);
    // A rename keeps size and modification time, so the hash just computed
    // is the override's: resolve need not read the file a second time.
    _remember(target, actual);
    _deleteIfPossible(stagedBadMarker);
    _log.log(Level.INFO, 'Promoted the staged libznn $manifest ($actual)');
    return PromotionResult(PromotionOutcome.promoted, manifest: manifest);
  }

  /// A staged manifest without its library is what a promotion leaves when
  /// the process dies between its last two renames: the library is already
  /// in place and only the manifest is still waiting.
  PromotionResult _finishInterruptedPromotion() {
    final File manifestFile = stagedManifest;
    if (!manifestFile.existsSync()) {
      return PromotionResult(PromotionOutcome.nothingStaged);
    }
    final NodeLibraryManifest? manifest = _readManifest(manifestFile);
    if (manifest != null &&
        overrideLibrary.existsSync() &&
        _hash(overrideLibrary.path) == manifest.sha256) {
      manifestFile.renameSync(overrideManifest.path);
      _log.log(Level.INFO, 'Finished promoting the staged libznn $manifest');
      return PromotionResult(PromotionOutcome.promoted, manifest: manifest);
    }
    // It vouches for nothing on disk.
    manifestFile.deleteSync();
    return PromotionResult(PromotionOutcome.nothingStaged);
  }

  /// The library the next load should open.
  ///
  /// The override, when it exists, its sha256 equals its manifest's, and
  /// that sha256 is not the one `libznn.bad.json` names. Otherwise the
  /// bundled library, with [ResolvedNodeLibrary.refusal] saying why an
  /// installed override was passed over. Null when there is neither.
  ResolvedNodeLibrary? resolve() {
    NodeLibraryManifest? manifest;
    String? refusal;
    if (overrideLibrary.existsSync()) {
      manifest = _readManifest(overrideManifest);
      final NodeLibraryBadMarker? bad = _readBad(badMarker);
      if (manifest == null) {
        refusal = 'the override has no readable manifest';
      } else if (bad != null && bad.sha256 == manifest.sha256) {
        // Before the hash: a library known not to load is not worth reading.
        refusal = 'the override ${manifest.sha256} is marked bad: '
            '${bad.reason}';
      } else {
        final String actual = _hash(overrideLibrary.path);
        if (actual != manifest.sha256) {
          refusal = 'the override is $actual but its manifest names '
              '${manifest.sha256}';
        }
      }
      if (refusal == null) {
        return ResolvedNodeLibrary(
          path: overrideLibrary.path,
          kind: NodeLibraryKind.override,
          manifest: manifest,
        );
      }
    }
    final String? bundled = findBundled();
    if (bundled == null) {
      return null;
    }
    return ResolvedNodeLibrary(
      path: bundled,
      kind: NodeLibraryKind.bundled,
      refusal: refusal,
    );
  }

  /// The first bundled library in [bundledSearchPaths].
  String? findBundled() {
    for (final String currentPath in bundledSearchPaths) {
      final String libraryPath = path.join(currentPath, libraryFileName);
      if (File(libraryPath).existsSync()) {
        return libraryPath;
      }
    }
    return null;
  }

  /// Promotes, resolves and opens, falling back to the bundled library when
  /// the override does not open.
  ///
  /// A process loads one libznn and keeps it: Dart never unloads a library,
  /// and a Go runtime cannot be unloaded at all. The node's isolate is
  /// started anew each time the user comes back to the embedded node, and
  /// each new isolate lands here with no memory of the last. So the first
  /// load writes `libznn.loaded.json` with the pid, and a later load in the
  /// same process opens that same path again without promoting anything.
  /// Without it a library staged mid-session would be renamed into place
  /// under a process that still runs the old one, and the record would name
  /// a library that is not the one executing.
  ///
  /// One process never opens two node libraries. When this process holds
  /// one already and it does not open again by its recorded path, or the
  /// record of which it was is gone, the answer is a
  /// [NodeLibraryHeldException] and nothing else is opened: resolving
  /// afresh could promote a staged pair and map a second Go runtime beside
  /// the first. Closing and reopening the wallet is the way on.
  ///
  /// [heldByProcess] says whether this process has loaded a node library
  /// before. The record alone cannot: it carries a pid, and a pid can be
  /// given again to a later run of the wallet, every run in a sandbox with
  /// its own pid numbering. `embedded_node.dart` knows and says. Without it
  /// the pid decides: a record carrying this pid is taken as this
  /// process's. With `false`, such a record is a dead process's and is
  /// passed over.
  ///
  /// The start-up guard: before an override is opened its sha256 goes into
  /// `libznn.starting.json`, and [confirmStarted] removes it once the node
  /// has run. A marker still there at a first load, written by a process
  /// that is gone, is a start the wallet did not survive. After
  /// [maxFailedStarts] of them in a row the override is marked bad, as one
  /// that does not open is, and the bundled library is opened.
  ///
  /// Throws [NodeLibraryNotFoundException] when there is nothing to load,
  /// and whatever [open] throws when the bundled library does not open.
  LoadedNodeLibrary load(NodeLibraryOpener open, {bool? heldByProcess}) {
    final LoadedNodeLibrary? earlier = loadedInThisProcess();
    if (heldByProcess ?? earlier != null) {
      if (earlier == null) {
        throw NodeLibraryHeldException(
          'this process has loaded a libznn and there is no record of which',
        );
      }
      _log.log(
        Level.INFO,
        'Loading libznn from path ${earlier.path} '
        '(${earlier.kind.name}, already loaded by this process)',
      );
      try {
        // By its path even if a rollback has since moved the file: the
        // system's loader answers with the module it already holds.
        open(earlier.path);
      } on Object catch (e) {
        _log.log(Level.SEVERE, 'Could not reopen ${earlier.path}', e);
        throw NodeLibraryHeldException(
          'this process has loaded ${earlier.path}, which did not open '
          'again: $e',
        );
      }
      return earlier;
    }
    if (earlier != null) {
      _log.log(
        Level.INFO,
        'Passing over the record of an earlier process with pid $processId',
      );
    }

    promoteStaged();
    ResolvedNodeLibrary? choice = resolve();
    if (choice == null) {
      throw NodeLibraryNotFoundException();
    }
    if (choice.refusal != null) {
      _log.log(Level.WARNING, 'Not loading the libznn override: '
          '${choice.refusal}');
    }

    final NodeLibraryManifest? manifest = choice.manifest;
    if (choice.kind == NodeLibraryKind.override && manifest != null) {
      final int failures = _failedStarts(manifest.sha256);
      if (failures >= maxFailedStarts) {
        choice = _openBundledInstead(
          open,
          manifest,
          NodeLibraryBadCause.start,
          'the wallet stopped unexpectedly at $failures starts in a row '
          'with it',
        );
      } else {
        _log.log(
          Level.INFO,
          'Loading libznn from path ${choice.path} '
          '(override, $manifest, sha256 ${manifest.sha256})',
        );
        _markStarting(manifest.sha256, failures);
        try {
          open(choice.path);
        } on Object catch (e) {
          // Object, not Exception: a library that does not open or lacks a
          // symbol is an ArgumentError.
          choice = _openBundledInstead(
            open,
            manifest,
            NodeLibraryBadCause.open,
            'failed to load: $e',
          );
        }
      }
    } else {
      _log.log(
        Level.INFO,
        'Loading libznn from path ${choice.path} (bundled)',
      );
      open(choice.path);
    }

    final LoadedNodeLibrary loaded = LoadedNodeLibrary(
      path: choice.path,
      kind: choice.kind,
      pid: processId,
      loadedAt: _now(),
      manifest: choice.manifest,
    );
    try {
      _writeJson(loadedRecord, loaded.toJson());
    } on FileSystemException catch (e) {
      // The node runs either way; only status() loses sight of it.
      _log.log(Level.WARNING, 'Could not record the loaded libznn', e);
    }
    return loaded;
  }

  /// What this process loaded, from `libznn.loaded.json`. Null when the
  /// record is another process's, or there is none.
  LoadedNodeLibrary? loadedInThisProcess() {
    final Map<String, dynamic>? json = _readJson(loadedRecord);
    final LoadedNodeLibrary? record =
        json == null ? null : LoadedNodeLibrary.fromJson(json);
    return record != null && record.pid == processId ? record : null;
  }

  /// Says that the wallet survived starting the override it loaded: removes
  /// this process's `libznn.starting.json`, and with it the count of failed
  /// starts.
  ///
  /// For `embedded_node.dart` to call once the node has run for a while, or
  /// has been stopped in good order. Harmless when there is no marker, and
  /// leaves another process's alone.
  void confirmStarted() {
    final NodeLibraryStartMarker? marker = _readStarting();
    if (marker != null && marker.pid == processId) {
      _deleteIfPossible(startingMarker);
      _log.log(Level.INFO, 'The libznn override ${marker.sha256} started');
    }
  }

  /// The starts in a row the wallet did not survive with the override
  /// [sha256], counting the one `libznn.starting.json` records if its
  /// process is gone.
  ///
  /// Only asked at a process's first load, so a marker carrying this pid is
  /// not this process's: it is an earlier one's, whose pid this one was
  /// given. A marker whose process still runs is another wallet in the
  /// middle of its own start and says nothing yet.
  int _failedStarts(String sha256) {
    final NodeLibraryStartMarker? marker = _readStarting();
    if (marker == null || marker.sha256 != sha256) {
      // A marker for another build says nothing about this one.
      return 0;
    }
    final bool gone =
        marker.pid == processId || !_isProcessRunning(marker.pid);
    if (gone) {
      _log.log(
        Level.WARNING,
        'The last start with the libznn override $sha256, by pid '
        '${marker.pid} at ${marker.at.toIso8601String()}, did not end in '
        'good order',
      );
    }
    return gone ? marker.failures + 1 : marker.failures;
  }

  void _markStarting(String sha256, int failures) {
    try {
      _writeJson(
        startingMarker,
        NodeLibraryStartMarker(
          sha256: sha256,
          pid: processId,
          at: _now(),
          failures: failures,
        ).toJson(),
      );
    } on FileSystemException catch (e) {
      // The start goes ahead unguarded: a directory that cannot be written
      // to must not keep the node from running.
      _log.log(Level.WARNING, 'Could not write the libznn start marker', e);
    }
  }

  /// Marks the override bad and opens the bundled library in its place.
  ResolvedNodeLibrary _openBundledInstead(
    NodeLibraryOpener open,
    NodeLibraryManifest manifest,
    NodeLibraryBadCause cause,
    String reason,
  ) {
    _markBad(manifest.sha256, reason, cause);
    // Whatever it counted is in the bad marker now.
    _deleteIfPossible(startingMarker);
    _log.log(
      Level.SEVERE,
      'The libznn override ${manifest.sha256} ($manifest): $reason. '
      'Marked bad; loading the bundled library instead.',
    );
    final String? bundled = findBundled();
    if (bundled == null) {
      throw NodeLibraryNotFoundException();
    }
    _log.log(
      Level.INFO,
      'Loading libznn from path $bundled (bundled, after the override failed)',
    );
    open(bundled);
    return ResolvedNodeLibrary(
      path: bundled,
      kind: NodeLibraryKind.bundled,
      refusal: reason,
    );
  }

  /// Removes the override pair and any staged pair, so the next start loads
  /// the bundled library.
  ///
  /// Does not touch a loaded library, and cannot: the node that is running
  /// keeps running on the override until the wallet restarts. On Windows the
  /// loaded DLL is locked against deletion, so only its manifest goes, which
  /// is enough for [resolve] to refuse it, and the library is renamed aside
  /// to be deleted by the next start's [promoteStaged].
  ///
  /// `libznn.prev.*` and `libznn.bad.json` are kept.
  void rollback() {
    _deleteIfPossible(overrideManifest);
    _deleteIfPossible(stagedManifest);
    _deleteIfPossible(stagedLibrary);
    _deleteIfPossible(_partialStagedLibrary);
    _deleteIfPossible(stagedBadMarker);
    final File library = overrideLibrary;
    if (library.existsSync() && !_deleteIfPossible(library)) {
      try {
        _deleteIfPossible(_removedLibrary);
        library.renameSync(_removedLibrary.path);
      } on FileSystemException catch (e) {
        // Without its manifest it is never loaded, wherever it lies.
        _log.log(Level.WARNING, 'Could not move the libznn override aside', e);
      }
    }
    _log.log(Level.INFO, 'Rolled back to the bundled libznn');
  }

  /// Swaps the `prev` pair with the override, so the next start loads the
  /// library the last promotion replaced. Calling it again swaps them back.
  /// Any staged pair is removed: it would otherwise be promoted over the
  /// restored library. False when there is no `prev` pair.
  ///
  /// Does not touch a loaded library, and cannot: the node that is running
  /// keeps running on what it loaded until the wallet restarts. On Windows
  /// the loaded DLL is locked against deletion and replacement but not
  /// against renaming, which is why this renames and never overwrites.
  ///
  /// The restored pair is verified like any other, by [resolve] at the next
  /// start.
  bool restorePrevious() {
    if (!previousLibrary.existsSync() || !previousManifest.existsSync()) {
      return false;
    }
    _deleteIfPossible(stagedManifest);
    _deleteIfPossible(stagedLibrary);
    _deleteIfPossible(_partialStagedLibrary);

    final bool hadLibrary = overrideLibrary.existsSync();
    final bool hadManifest = overrideManifest.existsSync();
    if (hadManifest) {
      overrideManifest.renameSync(_swapManifest.path);
    }
    if (hadLibrary) {
      overrideLibrary.renameSync(_swapLibrary.path);
    }
    previousLibrary.renameSync(overrideLibrary.path);
    previousManifest.renameSync(overrideManifest.path);
    if (hadLibrary) {
      _swapLibrary.renameSync(previousLibrary.path);
      if (hadManifest) {
        _swapManifest.renameSync(previousManifest.path);
      }
    } else {
      _deleteIfPossible(_swapManifest);
    }
    _log.log(Level.INFO, 'Restored the previous libznn override');
    return true;
  }

  /// What is loaded, what the next start will load, what is staged, what is
  /// marked bad, and the bundled library's sha256.
  ///
  /// Meant for the main isolate. The two libraries are hashed in a worker
  /// isolate, and only when their size or modification time has changed
  /// since this instance last hashed them; the rest is a few small JSON
  /// files.
  Future<NodeLibraryStatus> status() async {
    final String? bundled = findBundled();
    if (bundled != null) {
      await _hashOffIsolate(bundled);
    }
    if (overrideLibrary.existsSync()) {
      await _hashOffIsolate(overrideLibrary.path);
    }
    return NodeLibraryStatus(
      loaded: loadedInThisProcess(),
      next: resolve(),
      installed: overrideLibrary.existsSync()
          ? _readManifest(overrideManifest)
          : null,
      staged: stagedLibrary.existsSync()
          ? _readManifest(stagedManifest)
          : null,
      previous: previousLibrary.existsSync()
          ? _readManifest(previousManifest)
          : null,
      bad: _readBad(badMarker),
      stagedRejected: _readBad(stagedBadMarker),
      bundledPath: bundled,
      bundledSha256: bundled == null ? null : _hash(bundled),
    );
  }

  /// Copies [library] into the override directory as the staged pair, for
  /// the next start's [promoteStaged].
  ///
  /// The sha256 is computed over the bytes as they are copied, in a worker
  /// isolate, and must equal [manifest]'s: otherwise nothing is staged and a
  /// [NodeLibraryException] is thrown. The copy is written under another
  /// name and renamed, and the manifest goes last, so the loader never sees
  /// a pair that is still being written.
  ///
  /// Replaces whatever was staged before. Staging a library that
  /// `libznn.bad.json` names clears the marker, and one that
  /// `libznn.starting.json` names clears that and its count of failed
  /// starts: asking for it again is asking for another try.
  Future<void> stage(File library, NodeLibraryManifest manifest) async {
    if (!library.existsSync()) {
      throw NodeLibraryException('${library.path} does not exist');
    }
    Directory(directory).createSync(recursive: true);
    final String partial = _partialStagedLibrary.path;
    final String actual = await _copyOffIsolate(library.path, partial);
    if (actual != manifest.sha256) {
      _deleteIfPossible(File(partial));
      throw NodeLibraryException(
        '${library.path} is $actual, not the expected ${manifest.sha256}',
      );
    }
    // The old manifest must not meet the new library.
    _deleteIfPossible(stagedManifest);
    File(partial).renameSync(stagedLibrary.path);
    _remember(stagedLibrary.path, actual);
    _writeJson(stagedManifest, manifest.toJson());
    _deleteIfPossible(stagedBadMarker);
    final NodeLibraryBadMarker? bad = _readBad(badMarker);
    if (bad != null && bad.sha256 == manifest.sha256) {
      _deleteIfPossible(badMarker);
    }
    if (_readStarting()?.sha256 == manifest.sha256) {
      _deleteIfPossible(startingMarker);
    }
    _log.log(Level.INFO, 'Staged libznn $manifest ($actual)');
  }

  /// The lower-case hex sha256 of the file at [filePath], read in 1 MiB
  /// pieces. Synchronous, and measured at 0.2 to 0.4 s for the 19 MB Windows
  /// library: call it from the node's isolate or a worker, never from the UI
  /// isolate. [load] runs in the node's isolate already; [status] and
  /// [stage] send it to a worker.
  static String sha256OfFile(String filePath) {
    final Sha256 digest = Sha256();
    final Uint8List buffer = Uint8List(_chunkSize);
    final RandomAccessFile file = File(filePath).openSync();
    try {
      while (true) {
        final int read = file.readIntoSync(buffer);
        if (read <= 0) {
          break;
        }
        digest.add(buffer, read);
      }
    } finally {
      file.closeSync();
    }
    return digest.close();
  }

  static String _copyAndHash(String from, String to) {
    final Sha256 digest = Sha256();
    final Uint8List buffer = Uint8List(_chunkSize);
    final RandomAccessFile source = File(from).openSync();
    try {
      final RandomAccessFile target = File(to).openSync(mode: FileMode.write);
      try {
        while (true) {
          final int read = source.readIntoSync(buffer);
          if (read <= 0) {
            break;
          }
          digest.add(buffer, read);
          target.writeFromSync(buffer, 0, read);
        }
        target.flushSync();
      } finally {
        target.closeSync();
      }
    } finally {
      source.closeSync();
    }
    return digest.close();
  }

  // Static, so the closure handed to the worker captures two strings and
  // not the instance.
  static Future<String> _copyOffIsolate(String from, String to) =>
      Isolate.run<String>(() => _copyAndHash(from, to));

  static Future<String> _hashInWorker(String filePath) =>
      Isolate.run<String>(() => sha256OfFile(filePath));

  Future<void> _hashOffIsolate(String filePath) async {
    final String? key = _hashKey(filePath);
    if (key == null || _hashes.containsKey(key)) {
      return;
    }
    try {
      _hashes[key] = await _hashInWorker(filePath);
    } on FileSystemException {
      // Gone since it was listed; whoever asks next finds out.
    }
  }

  String _hash(String filePath) {
    final String? key = _hashKey(filePath);
    if (key == null) {
      return sha256OfFile(filePath);
    }
    return _hashes[key] ??= sha256OfFile(filePath);
  }

  void _remember(String filePath, String sha256) {
    final String? key = _hashKey(filePath);
    if (key != null) {
      _hashes[key] = sha256;
    }
  }

  static String? _hashKey(String filePath) {
    final FileStat stat = FileStat.statSync(filePath);
    if (stat.type == FileSystemEntityType.notFound) {
      return null;
    }
    return '$filePath|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
  }

  void _markBad(String sha256, String reason, NodeLibraryBadCause cause) {
    try {
      _writeJson(
        badMarker,
        NodeLibraryBadMarker(
          sha256: sha256,
          reason: reason,
          at: _now(),
          cause: cause,
        ).toJson(),
      );
    } on FileSystemException catch (e) {
      // The fallback must go ahead; the override is tried again next start.
      _log.log(Level.WARNING, 'Could not mark the libznn override bad', e);
    }
  }

  File _file(String name) => File(path.join(directory, name));

  static NodeLibraryManifest? _readManifest(File file) {
    final Map<String, dynamic>? json = _readJson(file);
    return json == null ? null : NodeLibraryManifest.fromJson(json);
  }

  static NodeLibraryBadMarker? _readBad(File file) {
    final Map<String, dynamic>? json = _readJson(file);
    return json == null ? null : NodeLibraryBadMarker.fromJson(json);
  }

  NodeLibraryStartMarker? _readStarting() {
    final Map<String, dynamic>? json = _readJson(startingMarker);
    return json == null ? null : NodeLibraryStartMarker.fromJson(json);
  }

  static Map<String, dynamic>? _readJson(File file) {
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Written beside the target and renamed over it, so a reader never sees
  /// half a document.
  void _writeJson(File file, Map<String, dynamic> json) {
    Directory(directory).createSync(recursive: true);
    final File temporary = File('${file.path}.tmp')
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
        flush: true,
      );
    temporary.renameSync(file.path);
  }

  static bool _deleteIfPossible(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

  static const int _chunkSize = 1 << 20;
}

final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

/// Whether [processId] is a live process, as far as this user may ask.
///
/// A process of another user that cannot be asked about counts as not
/// running, and so does a question the system could not be put. Both suit
/// the one caller: the pid comes out of `libznn.starting.json`, which this
/// user's wallet wrote, and taking a dead start for a live one would leave
/// a library that kills the wallet in place for good.
///
/// Asked through `dart:ffi` and not by running `tasklist` or `ps`: the
/// loader runs in the process that holds the wallet's keys, and starts no
/// other program.
bool processIsRunning(int processId) {
  if (processId <= 0) {
    return false;
  }
  try {
    if (Platform.isWindows) {
      // kernel32 is mapped into every Windows process already.
      final DynamicLibrary kernel32 = DynamicLibrary.open('kernel32.dll');
      final int Function(int, int, int) openProcess = kernel32.lookupFunction<
          IntPtr Function(Uint32, Int32, Uint32),
          int Function(int, int, int)>('OpenProcess');
      final int Function(int, int) waitForSingleObject =
          kernel32.lookupFunction<Uint32 Function(IntPtr, Uint32),
              int Function(int, int)>('WaitForSingleObject');
      final int Function(int) closeHandle = kernel32.lookupFunction<
          Int32 Function(IntPtr), int Function(int)>('CloseHandle');
      const int synchronize = 0x00100000;
      const int waitTimeout = 0x00000102;
      final int handle = openProcess(synchronize, 0, processId);
      if (handle == 0) {
        return false;
      }
      try {
        // A process that has ended is signalled, and its pid stays taken
        // for as long as anyone holds a handle to it.
        return waitForSingleObject(handle, 0) == waitTimeout;
      } finally {
        closeHandle(handle);
      }
    }
    // Signal 0 delivers nothing and only says whether it could have been.
    final int Function(int, int) kill = DynamicLibrary.process()
        .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
            'kill');
    return kill(processId, 0) == 0;
  } on Object {
    return false;
  }
}

/// SHA-256 (FIPS 180-4), fed in pieces.
///
/// Written out here because the only maintained implementation in the
/// dependency tree, `package:crypto`, is a transitive dependency this
/// package may not import, and the SDK's `Crypto.sha256Bytes` wants the
/// whole 20 to 40 MB library in memory and an event loop to wait on. The
/// tests hold it to the standard's vectors and to the SDK's answer.
class Sha256 {
  static final Uint32List _k = Uint32List.fromList(<int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
    0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
    0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
    0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ]);

  static const int _mask = 0xFFFFFFFF;

  final Uint32List _state = Uint32List.fromList(<int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  final Uint32List _w = Uint32List(64);
  final Uint8List _pending = Uint8List(64);
  int _pendingLength = 0;
  int _byteCount = 0;
  bool _closed = false;

  /// Feeds the first [length] bytes of [data], all of it by default.
  void add(Uint8List data, [int? length]) {
    if (_closed) {
      throw StateError('Sha256 is closed');
    }
    final int end = length ?? data.length;
    int offset = 0;
    _byteCount += end;
    if (_pendingLength > 0) {
      final int space = 64 - _pendingLength;
      final int take = end < space ? end : space;
      _pending.setRange(_pendingLength, _pendingLength + take, data);
      _pendingLength += take;
      offset = take;
      if (_pendingLength < 64) {
        return;
      }
      _compress(_pending, 0);
      _pendingLength = 0;
    }
    while (end - offset >= 64) {
      _compress(data, offset);
      offset += 64;
    }
    if (offset < end) {
      _pending.setRange(0, end - offset, data, offset);
      _pendingLength = end - offset;
    }
  }

  /// Pads, finishes and returns the digest as lower-case hex.
  String close() {
    final int bitLength = _byteCount * 8;
    final int padLength = (_pendingLength < 56 ? 56 : 120) - _pendingLength;
    final Uint8List tail = Uint8List(padLength + 8);
    tail[0] = 0x80;
    ByteData.sublistView(tail)
      ..setUint32(padLength, bitLength ~/ 0x100000000)
      ..setUint32(padLength + 4, bitLength & _mask);
    add(tail);
    _closed = true;
    final StringBuffer hex = StringBuffer();
    for (final int word in _state) {
      hex.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return hex.toString();
  }

  @pragma('vm:prefer-inline')
  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

  void _compress(Uint8List block, int offset) {
    final Uint32List w = _w;
    final Uint32List k = _k;
    for (int i = 0; i < 16; i++) {
      final int j = offset + (i << 2);
      w[i] = (block[j] << 24) |
          (block[j + 1] << 16) |
          (block[j + 2] << 8) |
          block[j + 3];
    }
    for (int i = 16; i < 64; i++) {
      final int w15 = w[i - 15];
      final int w2 = w[i - 2];
      final int s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >> 3);
      final int s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >> 10);
      // A Uint32List keeps the low 32 bits of what is stored in it.
      w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }

    int a = _state[0];
    int b = _state[1];
    int c = _state[2];
    int d = _state[3];
    int e = _state[4];
    int f = _state[5];
    int g = _state[6];
    int h = _state[7];
    for (int i = 0; i < 64; i++) {
      final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final int ch = (e & f) ^ ((~e & _mask) & g);
      final int t1 = (h + s1 + ch + k[i] + w[i]) & _mask;
      final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final int maj = (a & b) ^ (a & c) ^ (b & c);
      final int t2 = (s0 + maj) & _mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    _state[0] += a;
    _state[1] += b;
    _state[2] += c;
    _state[3] += d;
    _state[4] += e;
    _state[5] += f;
    _state[6] += g;
    _state[7] += h;
  }
}
