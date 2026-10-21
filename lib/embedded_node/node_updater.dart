/// Finds, downloads and verifies a libznn, and hands it to
/// [NodeLibrary.stage].
///
/// The library runs inside the process that holds the wallet's keys, so a
/// malicious one is a total compromise. Nothing here installs by itself.
/// There are three calls and the user stands between each:
///
/// 1. [NodeUpdater.latestRelease] or [NodeUpdater.releases] reads what the
///    repository has published. Nothing is downloaded.
/// 2. [NodeUpdater.download], started by the user, fetches one release's
///    archive, checks it and unpacks the library to a temporary file.
///    [NodeUpdater.fromFile] does the same for a file the user picked.
/// 3. [NodeUpdater.stage], after the user has seen the repository, tag,
///    asset name, sha256 and what was verified, stages it for the next
///    start. [NodeUpdater.discard] is the other answer.
///
/// Requests are HTTPS to GitHub's own hosts and nowhere else, redirects
/// included; see [NodeUpdater.apiHosts] and [NodeUpdater.downloadHosts].
///
/// Plain Dart with no Flutter import, like the loader: usable from any
/// isolate and from a test.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_archive.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';

final Logger _log = Logger('NodeUpdater');

// ------------------------------------------------------------------ errors --

/// Every failure of the updater. The subtype says what to tell the user;
/// [detail] is for the log and is never shown.
sealed class NodeUpdateException implements Exception {
  const NodeUpdateException(this.detail);

  final String detail;

  @override
  String toString() => 'NodeUpdateException: $detail';
}

/// GitHub refused the request until [resetAt]: 403 or 429 with
/// `x-ratelimit-remaining: 0` or a `retry-after`. Unauthenticated callers
/// get 60 API requests an hour for each address.
final class NodeUpdateRateLimited extends NodeUpdateException {
  const NodeUpdateRateLimited({this.resetAt}) : super('rate limited');

  /// UTC. Null when the response did not say.
  final DateTime? resetAt;
}

/// No connection, a broken one, a TLS failure or a timeout.
final class NodeUpdateNetworkError extends NodeUpdateException {
  const NodeUpdateNetworkError(super.detail);
}

/// A status other than 200 that is not a rate limit. 404 is a repository or
/// a file that does not exist.
final class NodeUpdateHttpError extends NodeUpdateException {
  const NodeUpdateHttpError(this.statusCode) : super('HTTP $statusCode');

  final int statusCode;
}

/// The release list was not the JSON GitHub documents, or a redirect could
/// not be followed.
final class NodeUpdateMalformedResponse extends NodeUpdateException {
  const NodeUpdateMalformedResponse(super.detail);
}

/// A URL, first or after a redirect, that is not HTTPS to one of the
/// allowed hosts. No request was sent to it.
final class NodeUpdateForbiddenUrl extends NodeUpdateException {
  NodeUpdateForbiddenUrl(this.url) : super('refused $url');

  final Uri url;
}

/// The download, the picked file or the unpacked library is over
/// [limit] bytes.
final class NodeUpdateTooLarge extends NodeUpdateException {
  const NodeUpdateTooLarge(this.limit) : super('over $limit bytes');

  final int limit;
}

/// The download ended with another number of bytes than the release lists.
final class NodeUpdateSizeMismatch extends NodeUpdateException {
  const NodeUpdateSizeMismatch({required this.expected, required this.actual})
      : super('$actual bytes, not the $expected listed');

  final int expected;
  final int actual;
}

/// Which published hash a comparison was made against.
enum NodeDigestSource {
  /// The release's checksum file.
  checksumFile,

  /// The `digest` field of the asset in GitHub's API.
  apiDigest,
}

/// The archive's sha256 is [actual] and the release publishes [expected]
/// in [check]. The download has been deleted.
final class NodeUpdateDigestMismatch extends NodeUpdateException {
  const NodeUpdateDigestMismatch({
    required this.check,
    required this.expected,
    required this.actual,
  }) : super('sha256 $actual, not $expected');

  final NodeDigestSource check;
  final String expected;
  final String actual;
}

/// The release contradicts itself: its checksum file and GitHub's digest
/// name different hashes for the same asset. Nothing was downloaded.
final class NodeUpdateChecksumConflict extends NodeUpdateException {
  const NodeUpdateChecksumConflict({
    required this.checksumFile,
    required this.apiDigest,
  }) : super('the checksum file names $checksumFile, the API $apiDigest');

  final String checksumFile;
  final String apiDigest;
}

/// The release's checksum file is not `sha256sum` output, or is over
/// 64 KB.
final class NodeUpdateMalformedChecksums extends NodeUpdateException {
  const NodeUpdateMalformedChecksums(super.detail);
}

/// The release publishes no hash for the asset, in a checksum file or in
/// the API, and the caller did not pass `allowUnverified`. Nothing was
/// downloaded.
final class NodeUpdateUnverified extends NodeUpdateException {
  const NodeUpdateUnverified({required this.checksumFile})
      : super('no published sha256 to check against');

  /// Why the checksum file was no help: there is none, or it does not list
  /// the asset.
  final NodeChecksumFileCheck checksumFile;
}

/// The archive was refused; see [problem]. Never
/// [NodeArchiveProblem.tooLarge], which is a [NodeUpdateTooLarge].
final class NodeUpdateArchiveError extends NodeUpdateException {
  NodeUpdateArchiveError(this.problem, String detail)
      : super('${problem.name}, $detail');

  final NodeArchiveProblem problem;
}

/// The caller cancelled. Nothing is left on disk.
final class NodeUpdateCancelled extends NodeUpdateException {
  const NodeUpdateCancelled() : super('cancelled');
}

/// The release has no library for this platform.
final class NodeUpdateNoAsset extends NodeUpdateException {
  const NodeUpdateNoAsset(this.tag) : super('no asset for this platform');

  final String tag;
}

/// The picked file is not this platform's library or one of the archives,
/// or is empty.
final class NodeUpdateUnsupportedFile extends NodeUpdateException {
  const NodeUpdateUnsupportedFile(this.name) : super('cannot use $name');

  final String name;
}

/// The disk refused: no space, no permission, a file that went away, or a
/// temporary library that changed before it was staged.
final class NodeUpdateFileError extends NodeUpdateException {
  const NodeUpdateFileError(super.detail);
}

// -------------------------------------------------------------------- http --

/// One answer of [NodeHttpClient.get].
class NodeHttpResponse {
  NodeHttpResponse({
    required this.statusCode,
    required this.body,
    Map<String, String> headers = const <String, String>{},
    this.contentLength,
  }) : headers = <String, String>{
          for (final MapEntry<String, String> header in headers.entries)
            header.key.toLowerCase(): header.value,
        };

  final int statusCode;

  /// By lower-case name.
  final Map<String, String> headers;

  /// Null when the server did not declare one.
  final int? contentLength;

  /// Single subscription. Cancelling it must drop the connection.
  final Stream<List<int>> body;
}

/// The one thing the updater needs from HTTP, so a test can stand in for
/// GitHub.
///
/// An implementation must not follow redirects: the updater checks every
/// hop's host before it asks for it.
abstract interface class NodeHttpClient {
  Future<NodeHttpResponse> get(Uri url, {required Map<String, String> headers});

  void close();
}

/// [NodeHttpClient] over `dart:io`. `package:http` is only a transitive
/// dependency here, which this package may not import.
class IoNodeHttpClient implements NodeHttpClient {
  IoNodeHttpClient({Duration connectionTimeout = const Duration(seconds: 20)})
      : _client = HttpClient()..connectionTimeout = connectionTimeout;

  final HttpClient _client;

  @override
  Future<NodeHttpResponse> get(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    final HttpClientRequest request = await _client.getUrl(url);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    final HttpClientResponse response = await request.close();
    final Map<String, String> received = <String, String>{};
    response.headers.forEach((String name, List<String> values) {
      received[name] = values.join(', ');
    });
    return NodeHttpResponse(
      statusCode: response.statusCode,
      headers: received,
      contentLength: response.contentLength < 0 ? null : response.contentLength,
      body: response,
    );
  }

  @override
  void close() => _client.close(force: true);
}

/// Stops a [NodeUpdater.download] from outside.
class CancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }
}

// ------------------------------------------------------------------ models --

/// The repository releases are read from, as `owner/name`.
class NodeUpdateSource {
  /// Throws [FormatException] when [repository] is not `owner/name`.
  NodeUpdateSource([this.repository = defaultRepository]) {
    if (!isValid(repository)) {
      throw FormatException('Not an owner/name repository', repository);
    }
  }

  static const String defaultRepository = 'zenon-network/go-zenon';

  /// What a manifest's `source` is for a library that came from a file.
  static const String file = 'file';

  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

  /// `owner/name` in the characters GitHub allows. Neither part may be `.`
  /// or `..`, which the pattern alone would let through into a URL path.
  static bool isValid(String repository) =>
      _pattern.hasMatch(repository) &&
      !repository.split('/').any((String part) => part == '.' || part == '..');

  /// Null where the constructor would throw.
  static NodeUpdateSource? tryParse(String repository) =>
      isValid(repository.trim()) ? NodeUpdateSource(repository.trim()) : null;

  final String repository;

  @override
  String toString() => repository;
}

/// The builds go-zenon publishes a libznn for, and what each is called.
///
/// macOS takes the archive of its own architecture before the universal
/// one: the release's checksum file lists the first and not the second.
enum NodePlatform {
  windowsAmd64('.dll', <String>['libznn-windows-amd64.zip']),
  linuxAmd64('.so', <String>['libznn-linux-amd64.tar.gz']),
  linuxArm64('.so', <String>['libznn-linux-arm64.tar.gz']),
  macosAmd64('.dylib', <String>[
    'libznn-darwin-amd64.tar.gz',
    'libznn-darwin-universal.tar.gz',
  ]),
  macosArm64('.dylib', <String>[
    'libznn-darwin-arm64.tar.gz',
    'libznn-darwin-universal.tar.gz',
  ]);

  const NodePlatform(this.libraryExtension, this.assetNames);

  /// `.dll`, `.so` or `.dylib`.
  final String libraryExtension;

  /// The release assets that hold a library this platform can load, the
  /// preferred one first.
  final List<String> assetNames;

  /// By the ABI of the running process, which is what decides whether a
  /// library loads: an x64 wallet under Rosetta needs the amd64 build.
  static NodePlatform get current {
    final Abi abi = Abi.current();
    if (Platform.isWindows) {
      return NodePlatform.windowsAmd64;
    }
    if (Platform.isMacOS) {
      return abi == Abi.macosArm64
          ? NodePlatform.macosArm64
          : NodePlatform.macosAmd64;
    }
    return abi == Abi.linuxArm64
        ? NodePlatform.linuxArm64
        : NodePlatform.linuxAmd64;
  }

  /// The one file inside [assetName]: go-zenon's builder archives
  /// `libznn-<os>-<arch><ext>` alone as `libznn-<os>-<arch>.zip` or
  /// `.tar.gz` (`.github/workflows/znn_builder.yml` there).
  String memberNameOf(String assetName) {
    final String lower = assetName.toLowerCase();
    for (final String suffix in <String>['.tar.gz', '.tgz', '.zip']) {
      if (lower.endsWith(suffix)) {
        final int end = assetName.length - suffix.length;
        return '${assetName.substring(0, end)}$libraryExtension';
      }
    }
    return '$assetName$libraryExtension';
  }

  /// The members of every archive in [assetNames].
  List<String> get memberNames => assetNames.map(memberNameOf).toList();
}

/// The archive of a release that holds this platform's library.
class NodeReleaseAsset {
  NodeReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
    String? sha256,
  }) : sha256 = sha256?.toLowerCase();

  final String name;

  /// Of the archive, in bytes.
  final int size;
  final Uri downloadUrl;

  /// The archive's sha256 from the API's `digest` field, lower-case hex.
  /// Null when the API gives none, as for releases uploaded before GitHub
  /// began computing it, or gives another algorithm.
  final String? sha256;

  /// `sha256:<hex>`, as the API writes it.
  String? get digest => sha256 == null ? null : 'sha256:$sha256';
}

/// The checksum file of a release.
class NodeChecksumAsset {
  NodeChecksumAsset({required this.name, required this.downloadUrl});

  /// The names a checksum file is recognised by, compared without case.
  static const List<String> names = <String>[
    'sha256checksums.txt',
    'sha256sums',
    'sha256sums.txt',
    'checksums.txt',
  ];

  final String name;
  final Uri downloadUrl;
}

/// One published release, as far as the updater cares.
class NodeRelease {
  NodeRelease({
    required this.repository,
    required this.tag,
    required this.name,
    required this.pageUrl,
    this.publishedAt,
    this.prerelease = false,
    this.asset,
    this.checksums,
  });

  /// `owner/name`.
  final String repository;
  final String tag;

  /// The release's title; the tag when it has none.
  final String name;

  /// UTC.
  final DateTime? publishedAt;
  final bool prerelease;

  /// The release's page on github.com, for the user to read.
  final Uri pageUrl;

  /// Null when the release has no library for this platform.
  final NodeReleaseAsset? asset;

  /// Null when the release has no checksum file.
  final NodeChecksumAsset? checksums;

  @override
  String toString() => '$repository $tag';
}

/// What the release's checksum file said about the downloaded archive.
enum NodeChecksumFileCheck {
  /// The file lists the asset and the archive's sha256 equals the entry.
  verified,

  /// The release has no checksum file.
  absentFromRelease,

  /// The release has one and it does not list the asset.
  assetNotListed,
}

/// What the API's `digest` said about the downloaded archive.
enum NodeApiDigestCheck {
  /// The API gives a sha256 and the archive's equals it.
  verified,

  /// The API gives none for the asset.
  absent,
}

/// A library unpacked to a temporary file, waiting for the user's answer:
/// [NodeUpdater.stage] or [NodeUpdater.discard].
class DownloadedNodeLibrary {
  DownloadedNodeLibrary({
    required this.file,
    required this.sha256,
    required this.size,
    required this.source,
    required this.asset,
    this.tag,
    this.archiveSha256,
    this.checksumFile,
    this.apiDigest,
  });

  /// The temporary library, in the override directory's `download` folder.
  final File file;

  /// Of the library itself, lower-case hex. What the manifest will name
  /// and what the user should be shown.
  final String sha256;

  /// Of the library, in bytes.
  final int size;

  /// The repository, or [NodeUpdateSource.file].
  final String source;

  /// The release's tag. Null for a file.
  final String? tag;

  /// The release asset's name, or the picked file's.
  final String asset;

  /// Of the archive the library came out of. Null for a bare library.
  final String? archiveSha256;

  /// Null for a file: there is no release to ask.
  final NodeChecksumFileCheck? checksumFile;

  /// Null for a file.
  final NodeApiDigestCheck? apiDigest;

  bool get isFromFile => source == NodeUpdateSource.file;

  /// At least one published hash matched the archive. False for a file,
  /// and for a download made with `allowUnverified` that found neither.
  bool get verified =>
      checksumFile == NodeChecksumFileCheck.verified ||
      apiDigest == NodeApiDigestCheck.verified;
}

/// The answer of [NodeUpdater.compare].
enum NodeUpdateState {
  /// The next start loads this release already.
  upToDate,

  /// The next start loads something else.
  updateAvailable,

  /// This release is staged and waits for a restart.
  staged,

  /// The installed library has no tag to compare, and the release's
  /// library has not been downloaded to compare hashes.
  unknown,
}

// ----------------------------------------------------------------- updater --

class NodeUpdater {
  NodeUpdater({
    required this.library,
    NodeUpdateSource? source,
    NodeHttpClient? http,
    NodePlatform? platform,
    this.maxBytes = defaultMaxBytes,
    this.idleTimeout = const Duration(seconds: 30),
    DateTime Function()? now,
  })  : source = source ?? NodeUpdateSource(),
        platform = platform ?? NodePlatform.current,
        _http = http ?? IoNodeHttpClient(),
        _now = now ?? _utcNow;

  /// 200 MB, on the download, on a picked file and on the unpacked library.
  /// The largest archive go-zenon publishes is 13 MB.
  static const int defaultMaxBytes = 200 * 1024 * 1024;

  /// The only host release lists are read from.
  static const Set<String> apiHosts = <String>{'api.github.com'};

  /// The hosts an asset may come from: github.com, and the two it
  /// redirects a release download to.
  static const Set<String> downloadHosts = <String>{
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  static const Set<String> _pageHosts = <String>{'github.com'};
  static const int _maxRedirects = 5;
  static const int _maxApiBytes = 8 << 20;
  static const int _maxChecksumBytes = 64 << 10;
  static const String _userAgent = 'syrius-node-updater';

  // A leftover younger than this may be another updater's, still waiting
  // for its user.
  static const Duration _staleAfter = Duration(hours: 1);

  static final RegExp _digestPattern = RegExp(r'^sha256:([0-9a-fA-F]{64})$');

  // 64 hex digits, blanks, an optional '*' for binary mode, and a bare file
  // name: what `sha256sum` and `shasum -a 256` write.
  static final RegExp _checksumLine =
      RegExp(r'^([0-9a-fA-F]{64})[ \t]+\*?([^\s/\\*]+)$');

  /// The loader whose override directory this updater stages into.
  final NodeLibrary library;
  final NodeUpdateSource source;
  final NodePlatform platform;
  final int maxBytes;

  /// How long a response may send nothing before it is given up.
  final Duration idleTimeout;

  final NodeHttpClient _http;
  final DateTime Function() _now;

  /// The names of the temporary files this updater still answers for.
  final Set<String> _live = <String>{};
  int _counter = 0;

  /// `<override directory>/download`: on the volume the staged library is
  /// renamed on, and out of the way of the names the loader reads.
  String get downloadDirectory => path.join(library.directory, 'download');

  // ------------------------------------------------------------ releases --

  /// The newest release of [source], or null when it has none.
  ///
  /// A prerelease is passed over unless [includePrereleases]. The release
  /// is returned even when it has no library for this platform; its
  /// [NodeRelease.asset] is null then.
  Future<NodeRelease?> latestRelease({bool includePrereleases = false}) async {
    for (final NodeRelease release in await releases(limit: 30)) {
      if (includePrereleases || !release.prerelease) {
        return release;
      }
    }
    return null;
  }

  /// Up to [limit] releases, newest first, prereleases among them.
  ///
  /// One API request. Throws a [NodeUpdateException]:
  /// [NodeUpdateRateLimited], [NodeUpdateNetworkError],
  /// [NodeUpdateHttpError] (404: no such repository),
  /// [NodeUpdateMalformedResponse] or [NodeUpdateForbiddenUrl].
  Future<List<NodeRelease>> releases({int limit = 10}) => _typed(() async {
        final int count = limit.clamp(1, 100);
        final Uri url = Uri.https(
          'api.github.com',
          '/repos/${source.repository}/releases',
          <String, String>{'per_page': '$count'},
        );
        final NodeHttpResponse response = await _get(
          url,
          apiHosts,
          <String, String>{
            'accept': 'application/vnd.github+json',
            'x-github-api-version': '2022-11-28',
          },
          null,
        );
        final Uint8List body = await _readAll(
          response,
          _maxApiBytes,
          null,
          () => const NodeUpdateMalformedResponse('the release list is huge'),
        );
        final Object? decoded;
        try {
          decoded = jsonDecode(utf8.decode(body));
        } on FormatException catch (e) {
          throw NodeUpdateMalformedResponse('not JSON: ${e.message}');
        }
        if (decoded is! List<dynamic>) {
          throw const NodeUpdateMalformedResponse('not a list of releases');
        }
        final List<NodeRelease> found = <NodeRelease>[];
        for (final Object? item in decoded) {
          if (item is! Map<String, dynamic>) {
            throw const NodeUpdateMalformedResponse('a release is no object');
          }
          if (item['draft'] == true) {
            continue;
          }
          found.add(_parseRelease(item));
        }
        return found.length > count ? found.sublist(0, count) : found;
      });

  NodeRelease _parseRelease(Map<String, dynamic> json) {
    final Object? tag = json['tag_name'];
    if (tag is! String || tag.isEmpty) {
      throw const NodeUpdateMalformedResponse('a release has no tag');
    }
    final Object? name = json['name'];
    final Object? published = json['published_at'];
    final Object? page = json['html_url'];

    final Map<String, Map<String, dynamic>> byName =
        <String, Map<String, dynamic>>{};
    final Object? assets = json['assets'];
    if (assets is List<dynamic>) {
      for (final Object? asset in assets) {
        if (asset is! Map<String, dynamic>) {
          continue;
        }
        final Object? assetName = asset['name'];
        final Object? state = asset['state'];
        if (assetName is String && (state == null || state == 'uploaded')) {
          byName[assetName] = asset;
        }
      }
    }

    NodeReleaseAsset? library;
    for (final String candidate in platform.assetNames) {
      final Map<String, dynamic>? asset = byName[candidate];
      final Uri? url = asset == null ? null : _assetUrl(asset);
      final Object? size = asset?['size'];
      if (asset != null && url != null && size is int && size >= 0) {
        final Object? digest = asset['digest'];
        library = NodeReleaseAsset(
          name: candidate,
          size: size,
          downloadUrl: url,
          sha256: digest is String
              ? _digestPattern.firstMatch(digest)?.group(1)
              : null,
        );
        break;
      }
    }

    NodeChecksumAsset? checksums;
    for (final String candidate in NodeChecksumAsset.names) {
      for (final MapEntry<String, Map<String, dynamic>> asset
          in byName.entries) {
        final Uri? url = _assetUrl(asset.value);
        if (checksums == null &&
            url != null &&
            asset.key.toLowerCase() == candidate) {
          checksums = NodeChecksumAsset(name: asset.key, downloadUrl: url);
        }
      }
    }

    // The page is opened in the user's browser: only ever github.com.
    final Uri? pageUrl = page is String ? Uri.tryParse(page) : null;
    return NodeRelease(
      repository: source.repository,
      tag: tag,
      name: name is String && name.isNotEmpty ? name : tag,
      publishedAt:
          published is String ? DateTime.tryParse(published)?.toUtc() : null,
      prerelease: json['prerelease'] == true,
      pageUrl: pageUrl != null && _isAllowed(pageUrl, _pageHosts)
          ? pageUrl
          : Uri.https(
              'github.com',
              '/${source.repository}/releases/tag/${Uri.encodeComponent(tag)}',
            ),
      asset: library,
      checksums: checksums,
    );
  }

  static Uri? _assetUrl(Map<String, dynamic> asset) {
    final Object? url = asset['browser_download_url'];
    final Uri? parsed = url is String ? Uri.tryParse(url) : null;
    return parsed != null && parsed.hasScheme && parsed.host.isNotEmpty
        ? parsed
        : null;
  }

  // ------------------------------------------------------------ download --

  /// Downloads [release]'s archive, checks it and unpacks the library to a
  /// temporary file. Nothing is installed.
  ///
  /// The archive's sha256, computed as it streams in, is compared with two
  /// published hashes, and both answers are in the result:
  ///
  /// - the entry for the asset in the release's checksum file
  ///   ([DownloadedNodeLibrary.checksumFile]), fetched first;
  /// - the `digest` of the asset in the API
  ///   ([DownloadedNodeLibrary.apiDigest]).
  ///
  /// Where both exist they must name the same hash, or nothing is
  /// downloaded ([NodeUpdateChecksumConflict]); a hash that exists must
  /// match, or the download is deleted ([NodeUpdateDigestMismatch]). Where
  /// neither exists the call refuses ([NodeUpdateUnverified]) unless
  /// [allowUnverified], which is for the caller to pass only after the user
  /// has said so in as many words. One of the two is enough to go on.
  ///
  /// The checksum file and the archive come from the same release on the
  /// same host, so these checks catch a corrupted download and a single
  /// swapped asset, not a compromised release: whoever can replace the
  /// archive there can replace both hashes with it.
  ///
  /// [onProgress] gets the bytes received and the total expected, on the
  /// calling isolate. [cancel] stops it; the future then fails with
  /// [NodeUpdateCancelled]. On every failure the temporary files are gone.
  ///
  /// Throws a [NodeUpdateException]; besides those named above
  /// [NodeUpdateNoAsset], [NodeUpdateTooLarge], [NodeUpdateSizeMismatch],
  /// [NodeUpdateMalformedChecksums], [NodeUpdateArchiveError],
  /// [NodeUpdateForbiddenUrl], [NodeUpdateRateLimited],
  /// [NodeUpdateHttpError], [NodeUpdateNetworkError] and
  /// [NodeUpdateFileError].
  Future<DownloadedNodeLibrary> download(
    NodeRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
    bool allowUnverified = false,
  }) =>
      _typed(() async {
        final NodeReleaseAsset? asset = release.asset;
        if (asset == null) {
          throw NodeUpdateNoAsset(release.tag);
        }
        if (asset.size > maxBytes) {
          throw NodeUpdateTooLarge(maxBytes);
        }
        _throwIfCancelled(cancel);

        NodeChecksumFileCheck checksumFile =
            NodeChecksumFileCheck.absentFromRelease;
        String? listed;
        final NodeChecksumAsset? checksums = release.checksums;
        if (checksums != null) {
          // A checksum file the release has but that cannot be fetched is a
          // failure, not an absence: otherwise blocking one request would
          // switch the check off.
          final Map<String, String> entries =
              parseChecksums(await _fetchChecksums(checksums, cancel));
          listed = entries[asset.name];
          checksumFile = listed == null
              ? NodeChecksumFileCheck.assetNotListed
              : NodeChecksumFileCheck.verified;
        }
        final String? digest = asset.sha256;
        if (listed != null && digest != null && listed != digest) {
          throw NodeUpdateChecksumConflict(
            checksumFile: listed,
            apiDigest: digest,
          );
        }
        if (listed == null && digest == null && !allowUnverified) {
          throw NodeUpdateUnverified(checksumFile: checksumFile);
        }

        final _Temp temp = _newTemp();
        try {
          final String archiveSha256 =
              await _downloadArchive(asset, temp.archive, onProgress, cancel);
          if (listed != null && archiveSha256 != listed) {
            throw NodeUpdateDigestMismatch(
              check: NodeDigestSource.checksumFile,
              expected: listed,
              actual: archiveSha256,
            );
          }
          if (digest != null && archiveSha256 != digest) {
            throw NodeUpdateDigestMismatch(
              check: NodeDigestSource.apiDigest,
              expected: digest,
              actual: archiveSha256,
            );
          }
          _throwIfCancelled(cancel);
          final NodeArchiveMember member = await _extractOffIsolate(
            temp.archive.path,
            NodeArchiveFormat.ofFileName(asset.name) ?? NodeArchiveFormat.zip,
            <String>[platform.memberNameOf(asset.name)],
            temp.library.path,
            maxBytes,
          );
          _throwIfCancelled(cancel);
          _forget(temp.archive);
          _log.log(
            Level.INFO,
            'Downloaded libznn $release ${asset.name}: library '
            '${member.sha256}, archive $archiveSha256, checksum file '
            '${checksumFile.name}, API digest '
            '${digest == null ? 'absent' : 'verified'}',
          );
          return DownloadedNodeLibrary(
            file: temp.library,
            sha256: member.sha256,
            size: member.size,
            source: release.repository,
            tag: release.tag,
            asset: asset.name,
            archiveSha256: archiveSha256,
            checksumFile: checksumFile,
            apiDigest: digest == null
                ? NodeApiDigestCheck.absent
                : NodeApiDigestCheck.verified,
          );
        } on Object {
          _forget(temp.archive);
          _forget(temp.library);
          rethrow;
        }
      });

  /// Takes a library the user has on disk: this platform's bare library
  /// (`.dll`, `.so` or `.dylib`), or a `.zip`, `.tar.gz` or `.tgz` holding
  /// exactly one of the members a release archive for this platform holds.
  ///
  /// The file is copied into the download folder under the same size cap
  /// and hashed as it is copied, so what is staged later is what was hashed
  /// here whatever happens to the original. There is nothing to verify it
  /// against: [DownloadedNodeLibrary.checksumFile] and
  /// [DownloadedNodeLibrary.apiDigest] are null, and the sha256 is all the
  /// user has to go on.
  ///
  /// Throws [NodeUpdateUnsupportedFile], [NodeUpdateTooLarge],
  /// [NodeUpdateArchiveError] or [NodeUpdateFileError].
  Future<DownloadedNodeLibrary> fromFile(File picked) => _typed(() async {
        final String name = path.basename(picked.path);
        final FileStat stat = picked.statSync();
        if (stat.type != FileSystemEntityType.file) {
          throw NodeUpdateFileError('${picked.path} is not a file');
        }
        if (stat.size > maxBytes) {
          throw NodeUpdateTooLarge(maxBytes);
        }
        final bool bare =
            name.toLowerCase().endsWith(platform.libraryExtension);
        final NodeArchiveFormat? format =
            bare ? null : NodeArchiveFormat.ofFileName(name);
        if (stat.size == 0 || (!bare && format == null)) {
          throw NodeUpdateUnsupportedFile(name);
        }

        final _Temp temp = _newTemp();
        try {
          final String sha256;
          final int size;
          String? archiveSha256;
          if (format == null) {
            (sha256, size) = await _copyOffIsolate(
              picked.path,
              temp.library.path,
              maxBytes,
            );
          } else {
            final NodeArchiveMember member;
            (archiveSha256, member) = await _importOffIsolate(
              picked.path,
              temp.archive.path,
              format,
              platform.memberNames,
              temp.library.path,
              maxBytes,
            );
            sha256 = member.sha256;
            size = member.size;
            _forget(temp.archive);
          }
          return DownloadedNodeLibrary(
            file: temp.library,
            sha256: sha256,
            size: size,
            source: NodeUpdateSource.file,
            asset: name,
            archiveSha256: archiveSha256,
          );
        } on Object {
          _forget(temp.archive);
          _forget(temp.library);
          rethrow;
        }
      });

  /// Stages [downloaded] for the next start: writes the manifest (source,
  /// tag, asset, sha256, now) and calls [NodeLibrary.stage], which copies
  /// the library, hashes the copy and refuses one that is not the sha256
  /// the user was shown.
  ///
  /// Call it only on the user's confirmation. The temporary file is
  /// deleted whether this succeeds or not; after a failure the library has
  /// to be downloaded again. Throws [NodeUpdateFileError].
  Future<void> stage(DownloadedNodeLibrary downloaded) => _typed(() async {
        try {
          if (!downloaded.file.existsSync()) {
            throw NodeUpdateFileError(
              '${downloaded.file.path} is gone; download it again',
            );
          }
          await library.stage(
            downloaded.file,
            NodeLibraryManifest(
              source: downloaded.source,
              tag: downloaded.tag,
              asset: downloaded.asset,
              sha256: downloaded.sha256,
              installedAt: _now(),
            ),
          );
        } finally {
          discard(downloaded);
        }
      });

  /// Deletes [downloaded]'s temporary file: the user said no. Harmless to
  /// call twice, or after [stage].
  void discard(DownloadedNodeLibrary downloaded) {
    _forget(downloaded.file);
  }

  /// Closes the HTTP client. Temporary files already handed out stay until
  /// they are staged or discarded.
  void close() => _http.close();

  // ------------------------------------------------------------- compare --

  /// How [release] stands to what the next start will load.
  ///
  /// [NodeUpdateState.staged] when the staged pair is this release. Then
  /// by tag, when the installed override came from the same repository:
  /// equal is [NodeUpdateState.upToDate], anything else
  /// [NodeUpdateState.updateAvailable]. Tags are compared for equality
  /// only, so an override newer than [release] also reads as an update
  /// available.
  ///
  /// The bundled library, and an override from a file or from another
  /// repository, have no tag to compare. They can only be compared by
  /// hash, and the release publishes the archive's hash, not the
  /// library's: pass [librarySha256] from a [DownloadedNodeLibrary] of
  /// this release when there is one. Without it the answer is
  /// [NodeUpdateState.unknown].
  static NodeUpdateState compare(
    NodeLibraryStatus status,
    NodeRelease release, {
    String? librarySha256,
  }) {
    final String? known = librarySha256?.toLowerCase();
    final NodeLibraryManifest? staged = status.staged;
    if (staged != null) {
      final bool sameRelease =
          staged.source == release.repository && staged.tag == release.tag;
      if (sameRelease || (known != null && staged.sha256 == known)) {
        return NodeUpdateState.staged;
      }
    }

    final ResolvedNodeLibrary? next = status.next;
    final NodeLibraryManifest? installed =
        next?.kind == NodeLibraryKind.override ? next?.manifest : null;
    final String? installedSha256 = next == null
        ? null
        : next.kind == NodeLibraryKind.override
            ? installed?.sha256
            : status.bundledSha256;
    if (known != null && installedSha256 == known) {
      return NodeUpdateState.upToDate;
    }
    final String? installedTag =
        installed != null && installed.source == release.repository
            ? installed.tag
            : null;
    if (installedTag != null) {
      return installedTag == release.tag
          ? NodeUpdateState.upToDate
          : NodeUpdateState.updateAvailable;
    }
    return known != null && installedSha256 != null
        ? NodeUpdateState.updateAvailable
        : NodeUpdateState.unknown;
  }

  // ----------------------------------------------------------- checksums --

  /// The entries of a `sha256sum` file, hash by file name, hashes in
  /// lower case.
  ///
  /// Strict: every line must be 64 hex digits, blanks, an optional `*` and
  /// a file name with no path separator and no blank. Empty lines are
  /// passed over. A name listed twice with two hashes, a file with no entry
  /// at all, and anything else throw [NodeUpdateMalformedChecksums].
  static Map<String, String> parseChecksums(String text) {
    final Map<String, String> entries = <String, String>{};
    for (final String raw in text.split('\n')) {
      final String line =
          raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      if (line.isEmpty) {
        continue;
      }
      final RegExpMatch? match = _checksumLine.firstMatch(line);
      if (match == null) {
        throw const NodeUpdateMalformedChecksums('a line is not a checksum');
      }
      final String hash = match.group(1)!.toLowerCase();
      final String name = match.group(2)!;
      final String? earlier = entries[name];
      if (earlier != null && earlier != hash) {
        throw NodeUpdateMalformedChecksums('$name is listed with two hashes');
      }
      entries[name] = hash;
    }
    if (entries.isEmpty) {
      throw const NodeUpdateMalformedChecksums('the file lists nothing');
    }
    return entries;
  }

  Future<String> _fetchChecksums(
    NodeChecksumAsset checksums,
    CancelToken? cancel,
  ) async {
    final NodeHttpResponse response = await _get(
      checksums.downloadUrl,
      downloadHosts,
      const <String, String>{'accept': 'application/octet-stream'},
      cancel,
    );
    final Uint8List bytes = await _readAll(
      response,
      _maxChecksumBytes,
      cancel,
      () => const NodeUpdateMalformedChecksums('over 64 KB'),
    );
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const NodeUpdateMalformedChecksums('not text');
    }
  }

  // ---------------------------------------------------------------- http --

  Future<String> _downloadArchive(
    NodeReleaseAsset asset,
    File target,
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    final NodeHttpResponse response = await _get(
      asset.downloadUrl,
      downloadHosts,
      const <String, String>{'accept': 'application/octet-stream'},
      cancel,
    );
    final int? declared = response.contentLength;
    if (declared != null && declared > maxBytes) {
      _drop(response);
      throw NodeUpdateTooLarge(maxBytes);
    }
    final int total = declared ?? asset.size;
    final Sha256 hash = Sha256();
    int received = 0;
    final RandomAccessFile file = target.openSync(mode: FileMode.write);
    try {
      await _pump(response.body, cancel, (List<int> chunk) {
        received += chunk.length;
        if (received > maxBytes) {
          throw NodeUpdateTooLarge(maxBytes);
        }
        final Uint8List bytes =
            chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        hash.add(bytes);
        file.writeFromSync(bytes);
        onProgress?.call(received, total);
      });
      file.flushSync();
    } finally {
      file.closeSync();
    }
    if (received != asset.size) {
      throw NodeUpdateSizeMismatch(expected: asset.size, actual: received);
    }
    return hash.close();
  }

  /// A 200 from [url], after following redirects by hand: every hop must
  /// pass [_isAllowed] for [hosts] before a request goes to it.
  Future<NodeHttpResponse> _get(
    Uri url,
    Set<String> hosts,
    Map<String, String> headers,
    CancelToken? cancel,
  ) async {
    Uri current = url;
    for (int hop = 0; hop <= _maxRedirects; hop++) {
      if (!_isAllowed(current, hosts)) {
        throw NodeUpdateForbiddenUrl(current);
      }
      final NodeHttpResponse response = await _send(current, headers, cancel);
      final int status = response.statusCode;
      if (status == 200) {
        return response;
      }
      _drop(response);
      if (!const <int>{301, 302, 303, 307, 308}.contains(status)) {
        throw _statusError(response);
      }
      final String? location = response.headers['location'];
      if (location == null || location.isEmpty) {
        throw const NodeUpdateMalformedResponse('a redirect to nowhere');
      }
      try {
        current = current.resolve(location);
      } on FormatException {
        throw const NodeUpdateMalformedResponse('an unreadable redirect');
      }
    }
    throw const NodeUpdateMalformedResponse('too many redirects');
  }

  /// HTTPS, one of [hosts], the default port, no credentials.
  static bool _isAllowed(Uri url, Set<String> hosts) =>
      url.scheme == 'https' &&
      hosts.contains(url.host.toLowerCase()) &&
      url.userInfo.isEmpty &&
      (!url.hasPort || url.port == 443);

  Future<NodeHttpResponse> _send(
    Uri url,
    Map<String, String> headers,
    CancelToken? cancel,
  ) async {
    _throwIfCancelled(cancel);
    try {
      final Future<NodeHttpResponse> request = _http.get(
        url,
        headers: <String, String>{...headers, 'user-agent': _userAgent},
      );
      if (cancel == null) {
        return await request;
      }
      final NodeHttpResponse? response = await Future.any<NodeHttpResponse?>(
        <Future<NodeHttpResponse?>>[
          request,
          cancel.whenCancelled.then((_) => null),
        ],
      );
      if (response == null) {
        // The answer may still arrive; nobody will read it.
        request.then(_drop).ignore();
        throw const NodeUpdateCancelled();
      }
      return response;
    } on NodeUpdateException {
      rethrow;
    } on Exception catch (e) {
      // Whatever the client throws for a dead network: SocketException,
      // HandshakeException, HttpException, TimeoutException.
      throw NodeUpdateNetworkError(e.toString());
    }
  }

  NodeUpdateException _statusError(NodeHttpResponse response) {
    final int status = response.statusCode;
    if (status == 403 || status == 429) {
      final String? remaining = response.headers['x-ratelimit-remaining'];
      final int? reset =
          int.tryParse(response.headers['x-ratelimit-reset']?.trim() ?? '');
      final int? retryAfter =
          int.tryParse(response.headers['retry-after']?.trim() ?? '');
      if (status == 429 || remaining?.trim() == '0' || retryAfter != null) {
        return NodeUpdateRateLimited(
          resetAt: retryAfter != null
              ? _now().toUtc().add(Duration(seconds: retryAfter))
              : reset != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      reset * 1000,
                      isUtc: true,
                    )
                  : null,
        );
      }
    }
    return NodeUpdateHttpError(status);
  }

  /// Lets go of a response nobody will read, connection and all.
  static void _drop(NodeHttpResponse response) {
    response.body.listen((_) {}, onError: (Object _) {}).cancel().ignore();
  }

  /// A small body, whole. [tooLarge] makes the error for one over [cap].
  Future<Uint8List> _readAll(
    NodeHttpResponse response,
    int cap,
    CancelToken? cancel,
    NodeUpdateException Function() tooLarge,
  ) async {
    final int? declared = response.contentLength;
    if (declared != null && declared > cap) {
      _drop(response);
      throw tooLarge();
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await _pump(response.body, cancel, (List<int> chunk) {
      if (bytes.length + chunk.length > cap) {
        throw tooLarge();
      }
      bytes.add(Uint8List.fromList(chunk));
    });
    return bytes.takeBytes();
  }

  /// Feeds [body] to [onChunk] until it ends, [onChunk] throws, nothing
  /// arrives for [idleTimeout], or [cancel] fires. The subscription is
  /// cancelled on every way out but the first.
  Future<void> _pump(
    Stream<List<int>> body,
    CancelToken? cancel,
    void Function(List<int> chunk) onChunk,
  ) {
    final Completer<void> done = Completer<void>();
    StreamSubscription<List<int>>? subscription;
    void fail(Object error, StackTrace stack) {
      if (done.isCompleted) {
        return;
      }
      done.completeError(error, stack);
      subscription?.cancel().ignore();
    }

    subscription = body.timeout(idleTimeout).listen(
      (List<int> chunk) {
        if (done.isCompleted) {
          return;
        }
        try {
          onChunk(chunk);
        } on Exception catch (e, s) {
          fail(e, s);
        }
      },
      onError: (Object error, StackTrace stack) => fail(
        error is NodeUpdateException
            ? error
            : NodeUpdateNetworkError(error.toString()),
        stack,
      ),
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: true,
    );
    if (cancel != null) {
      cancel.whenCancelled
          .then((_) => fail(const NodeUpdateCancelled(), StackTrace.current))
          .ignore();
    }
    return done.future;
  }

  static void _throwIfCancelled(CancelToken? cancel) {
    if (cancel != null && cancel.isCancelled) {
      throw const NodeUpdateCancelled();
    }
  }

  /// Runs [body] and turns what the disk, the archive reader and the
  /// loader throw into a [NodeUpdateException], so a caller has one family
  /// to catch.
  Future<T> _typed<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on NodeUpdateCancelled {
      rethrow;
    } on NodeUpdateException catch (e, s) {
      _log.log(Level.WARNING, 'Node update failed', e, s);
      rethrow;
    } on NodeArchiveException catch (e, s) {
      _log.log(Level.WARNING, 'Node update failed', e, s);
      Error.throwWithStackTrace(
        e.problem == NodeArchiveProblem.tooLarge
            ? NodeUpdateTooLarge(maxBytes)
            : NodeUpdateArchiveError(e.problem, e.detail),
        s,
      );
    } on NodeLibraryException catch (e, s) {
      _log.log(Level.WARNING, 'Node update failed', e, s);
      Error.throwWithStackTrace(NodeUpdateFileError(e.message), s);
    } on FileSystemException catch (e, s) {
      _log.log(Level.WARNING, 'Node update failed', e, s);
      Error.throwWithStackTrace(NodeUpdateFileError(e.toString()), s);
    }
  }

  // ---------------------------------------------------------- temp files --

  /// Two fresh names in [downloadDirectory], after clearing out what a
  /// crashed run left there.
  _Temp _newTemp() {
    final Directory directory = Directory(downloadDirectory)
      ..createSync(recursive: true);
    for (final FileSystemEntity entity in directory.listSync()) {
      if (entity is File &&
          !_live.contains(path.basename(entity.path)) &&
          _now().difference(entity.statSync().modified) > _staleAfter) {
        _delete(entity);
      }
    }
    final String stamp = _now().microsecondsSinceEpoch.toRadixString(36);
    final String name = 'libznn-$stamp-$pid-${_counter++}';
    final _Temp temp = _Temp(
      File(path.join(directory.path, '$name.archive')),
      File(path.join(directory.path, '$name${platform.libraryExtension}')),
    );
    _live
      ..add(path.basename(temp.archive.path))
      ..add(path.basename(temp.library.path));
    return temp;
  }

  /// Deletes a temporary file, and the download folder with the last one.
  void _forget(File file) {
    _live.remove(path.basename(file.path));
    _delete(file);
    try {
      final Directory directory = Directory(downloadDirectory);
      if (directory.existsSync() && directory.listSync().isEmpty) {
        directory.deleteSync();
      }
    } on FileSystemException {
      // Another download put a file there in between.
    }
  }

  static void _delete(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } on FileSystemException catch (e) {
      _log.log(Level.WARNING, 'Could not delete ${file.path}', e);
    }
  }

  // ------------------------------------------------------------- workers --

  // Static, each closure made where only strings, numbers and enums are in
  // scope: a closure made in an instance method would drag the HTTP client
  // along to the worker.

  static Future<NodeArchiveMember> _extractOffIsolate(
    String archivePath,
    NodeArchiveFormat format,
    List<String> memberNames,
    String outputPath,
    int maxBytes,
  ) =>
      Isolate.run<NodeArchiveMember>(
        () => NodeArchive.extractMember(
          archivePath: archivePath,
          format: format,
          memberNames: memberNames,
          outputPath: outputPath,
          maxBytes: maxBytes,
        ),
      );

  static Future<(String, int)> _copyOffIsolate(
    String from,
    String to,
    int maxBytes,
  ) =>
      Isolate.run<(String, int)>(() => _copyCapped(from, to, maxBytes));

  static Future<(String, NodeArchiveMember)> _importOffIsolate(
    String from,
    String archivePath,
    NodeArchiveFormat format,
    List<String> memberNames,
    String outputPath,
    int maxBytes,
  ) =>
      Isolate.run<(String, NodeArchiveMember)>(() {
        final (String archiveSha256, _) =
            _copyCapped(from, archivePath, maxBytes);
        return (
          archiveSha256,
          NodeArchive.extractMember(
            archivePath: archivePath,
            format: format,
            memberNames: memberNames,
            outputPath: outputPath,
            maxBytes: maxBytes,
          ),
        );
      });

  /// Copies [from] to [to], hashing as it goes and stopping at [maxBytes]:
  /// the file may have grown since it was measured.
  static (String, int) _copyCapped(String from, String to, int maxBytes) {
    final Sha256 hash = Sha256();
    int size = 0;
    final RandomAccessFile source = File(from).openSync();
    try {
      final RandomAccessFile target = File(to).openSync(mode: FileMode.write);
      try {
        while (true) {
          final Uint8List chunk = source.readSync(1 << 20);
          if (chunk.isEmpty) {
            break;
          }
          size += chunk.length;
          if (size > maxBytes) {
            throw NodeUpdateTooLarge(maxBytes);
          }
          hash.add(chunk);
          target.writeFromSync(chunk);
        }
        target.flushSync();
      } finally {
        target.closeSync();
      }
    } finally {
      source.closeSync();
    }
    return (hash.close(), size);
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

class _Temp {
  _Temp(this.archive, this.library);

  final File archive;
  final File library;
}
