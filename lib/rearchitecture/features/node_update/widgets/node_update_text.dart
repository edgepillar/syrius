part of '../view/node_update_card.dart';

/// A library as the panel names it: the bundled one, or an override by its
/// release tag (its file name when it has none) and where it came from.
class _Named {
  const _Named.bundled(this.sha256)
    : name = null,
      repository = null,
      asset = null;

  _Named.manifest(NodeLibraryManifest manifest)
    : name = manifest.tag ?? manifest.asset,
      repository = manifest.source == NodeUpdateSource.file
          ? null
          : manifest.source,
      asset = manifest.asset,
      sha256 = manifest.sha256;

  /// What a start would load from what is installed now; a staged library
  /// is not counted in.
  static _Named? resolved(NodeLibraryStatus status) {
    final ResolvedNodeLibrary? next = status.next;
    if (next == null) {
      return null;
    }
    final NodeLibraryManifest? manifest = next.manifest;
    return next.kind == NodeLibraryKind.override && manifest != null
        ? _Named.manifest(manifest)
        : _Named.bundled(status.bundledSha256);
  }

  /// What this process has loaded, or null while the embedded node has not
  /// been started in it.
  static _Named? loaded(NodeLibraryStatus status) {
    final LoadedNodeLibrary? loaded = status.loaded;
    if (loaded == null) {
      return null;
    }
    final NodeLibraryManifest? manifest = loaded.manifest;
    return loaded.kind == NodeLibraryKind.override && manifest != null
        ? _Named.manifest(manifest)
        : _Named.bundled(
            loaded.path == status.bundledPath ? status.bundledSha256 : null,
          );
  }

  /// The tag, or the file name. Null for the bundled library.
  final String? name;

  /// `owner/name`. Null for the bundled library and for one from a file.
  final String? repository;

  /// The release asset's name, or the file's. Null for the bundled library.
  final String? asset;

  /// Null when it could not be read.
  final String? sha256;

  bool get bundled => name == null;

  /// An override on one line: its name, then its repository if it has one.
  /// Empty for the bundled library, whose name is a translated word.
  String get text =>
      repository == null ? name ?? '' : '${name ?? ''}  $repository';

  /// Whether [other] is another library than this one, as far as can be
  /// told.
  bool differsFrom(_Named other) =>
      bundled != other.bundled ||
      (sha256 != null && other.sha256 != null && sha256 != other.sha256);
}

/// What went wrong, in the person's words, and the values that go with it.
class _Problem {
  const _Problem(this.message, [this.values = const <String, String>{}]);

  final String message;

  /// Checksums to show under the message, by their label.
  final Map<String, String> values;
}

/// The message for [error]. Never the exception's own text: that is for
/// the log.
_Problem _problemOf(AppLocalizations l10n, NodeUpdateException error) {
  return switch (error) {
    NodeUpdateRateLimited(:final DateTime? resetAt) => _Problem(
      resetAt == null
          ? l10n.nodeUpdateRateLimitedError
          : l10n.nodeUpdateRateLimitedUntilError(resetAt.toLocal()),
    ),
    NodeUpdateNetworkError() => _Problem(l10n.nodeUpdateNetworkError),
    NodeUpdateHttpError(:final int statusCode) => _Problem(
      statusCode == 404
          ? l10n.nodeUpdateNotFoundError
          : l10n.nodeUpdateHttpError(statusCode),
    ),
    NodeUpdateMalformedResponse() => _Problem(l10n.nodeUpdateMalformedError),
    NodeUpdateForbiddenUrl() => _Problem(l10n.nodeUpdateForbiddenUrlError),
    NodeUpdateTooLarge(:final int limit) => _Problem(
      l10n.nodeUpdateTooLargeError(limit ~/ (1024 * 1024)),
    ),
    NodeUpdateSizeMismatch() => _Problem(l10n.nodeUpdateSizeMismatchError),
    NodeUpdateDigestMismatch(
      :final String expected,
      :final String actual,
    ) =>
      _Problem(l10n.nodeUpdateDigestMismatchError, <String, String>{
        l10n.nodeUpdateExpectedLabel: expected,
        l10n.nodeUpdateActualLabel: actual,
      }),
    NodeUpdateChecksumConflict(
      :final String checksumFile,
      :final String apiDigest,
    ) =>
      _Problem(l10n.nodeUpdateChecksumConflictError, <String, String>{
        l10n.nodeUpdateChecksumFileLabel: checksumFile,
        l10n.nodeUpdateDigestLabel: apiDigest,
      }),
    NodeUpdateMalformedChecksums() => _Problem(
      l10n.nodeUpdateMalformedChecksumsError,
    ),
    NodeUpdateUnverified() => _Problem(l10n.nodeUpdateUnverifiedError),
    NodeUpdateArchiveError() ||
    NodeUpdateUnsupportedFile() => _Problem(l10n.nodeUpdateNotLibraryError),
    NodeUpdateCancelled() => _Problem(l10n.nodeUpdateCancelledError),
    NodeUpdateNoAsset(:final String tag) => _Problem(
      l10n.nodeUpdateNoAssetError(tag),
    ),
    NodeUpdateFileError() => _Problem(l10n.nodeUpdateFileError),
  };
}

/// What the release's checksum file said, in words. Null is a library from
/// a file, which no release vouches for.
String _checksumFileText(AppLocalizations l10n, NodeChecksumFileCheck? check) {
  return switch (check) {
    NodeChecksumFileCheck.verified => l10n.nodeUpdateChecksumVerifiedLabel,
    NodeChecksumFileCheck.assetNotListed =>
      l10n.nodeUpdateChecksumNotListedLabel,
    NodeChecksumFileCheck.absentFromRelease =>
      l10n.nodeUpdateChecksumAbsentLabel,
    null => l10n.nodeUpdateFileUncheckedLabel,
  };
}

/// What GitHub's own digest said, in words. Null as in [_checksumFileText].
String _apiDigestText(AppLocalizations l10n, NodeApiDigestCheck? check) {
  return switch (check) {
    NodeApiDigestCheck.verified => l10n.nodeUpdateDigestVerifiedLabel,
    NodeApiDigestCheck.absent => l10n.nodeUpdateDigestAbsentLabel,
    null => l10n.nodeUpdateFileUncheckedLabel,
  };
}

String _comparisonText(AppLocalizations l10n, NodeUpdateState comparison) {
  return switch (comparison) {
    NodeUpdateState.upToDate => l10n.nodeUpdateCompareUpToDateLabel,
    NodeUpdateState.updateAvailable => l10n.nodeUpdateCompareAvailableLabel,
    NodeUpdateState.staged => l10n.nodeUpdateCompareStagedLabel,
    NodeUpdateState.unknown => l10n.nodeUpdateCompareUnknownLabel,
  };
}

/// [bytes] in megabytes with one decimal, in Latin digits.
String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// A hash cut in the middle. The whole of it is in the tooltip and on the
/// copy button beside it.
String _middle(String hash) => hash.length <= 24
    ? hash
    : '${hash.substring(0, 10)}…${hash.substring(hash.length - 10)}';

/// A ledger label: capitals where the language has them.
String _label(BuildContext context, String label) =>
    usesLatinScript(context) ? label.toUpperCase() : label;
