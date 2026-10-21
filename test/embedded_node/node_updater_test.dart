import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_archive.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_updater.dart';

const String _repo = 'zenon-network/go-zenon';

/// A fake library: bytes nobody will ever open.
Uint8List _bytes(int seed, [int length = 4096]) {
  final Uint8List bytes = Uint8List(length);
  int x = seed * 2654435761 + 1;
  for (int i = 0; i < length; i++) {
    x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
    bytes[i] = x >> 16;
  }
  return bytes;
}

String _sha(List<int> bytes) =>
    (Sha256()..add(Uint8List.fromList(bytes))).close();

int _crc32(List<int> bytes) {
  int crc = 0xFFFFFFFF;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// One entry of a test archive. [type] is the tar type flag: `0` a file,
/// `2` a symbolic link, `5` a directory, `x` a pax header.
class _Entry {
  _Entry(this.name, this.content, {this.type = '0'});

  final String name;
  final List<int> content;
  final String type;
}

Uint8List _zip(List<_Entry> entries, {bool deflate = true}) {
  final BytesBuilder out = BytesBuilder();
  final BytesBuilder directory = BytesBuilder();
  for (final _Entry entry in entries) {
    final List<int> name = utf8.encode(entry.name);
    final List<int> data =
        deflate ? ZLibEncoder(raw: true).convert(entry.content) : entry.content;
    final int offset = out.length;
    final ByteData local = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 0x0800, Endian.little)
      ..setUint16(8, deflate ? 8 : 0, Endian.little)
      ..setUint32(14, _crc32(entry.content), Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, entry.content.length, Endian.little)
      ..setUint16(26, name.length, Endian.little);
    out
      ..add(local.buffer.asUint8List())
      ..add(name)
      ..add(data);
    final ByteData central = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(10, deflate ? 8 : 0, Endian.little)
      ..setUint32(16, _crc32(entry.content), Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, entry.content.length, Endian.little)
      ..setUint16(28, name.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    directory
      ..add(central.buffer.asUint8List())
      ..add(name);
  }
  final Uint8List directoryBytes = directory.takeBytes();
  final ByteData end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, entries.length, Endian.little)
    ..setUint16(10, entries.length, Endian.little)
    ..setUint32(12, directoryBytes.length, Endian.little)
    ..setUint32(16, out.length, Endian.little);
  out
    ..add(directoryBytes)
    ..add(end.buffer.asUint8List());
  return out.takeBytes();
}

Uint8List _tar(List<_Entry> entries) {
  final BytesBuilder out = BytesBuilder();
  for (final _Entry entry in entries) {
    final Uint8List header = Uint8List(512)
      ..setAll(0, utf8.encode(entry.name))
      ..setAll(100, ascii.encode('0000644\x00'))
      ..setAll(108, ascii.encode('0000000\x00'))
      ..setAll(116, ascii.encode('0000000\x00'))
      ..setAll(
        124,
        ascii.encode(
          '${entry.content.length.toRadixString(8).padLeft(11, '0')}\x00',
        ),
      )
      ..setAll(136, ascii.encode('00000000000\x00'))
      ..fillRange(148, 156, 0x20)
      ..[156] = entry.type.codeUnitAt(0)
      ..setAll(257, ascii.encode('ustar\x0000'));
    final int sum = header.fold(0, (int total, int byte) => total + byte);
    header.setAll(
      148,
      ascii.encode('${sum.toRadixString(8).padLeft(6, '0')}\x00 '),
    );
    out
      ..add(header)
      ..add(entry.content)
      ..add(Uint8List((512 - entry.content.length % 512) % 512));
  }
  out.add(Uint8List(1024));
  return out.takeBytes();
}

Uint8List _tarGz(List<_Entry> entries) =>
    Uint8List.fromList(gzip.encode(_tar(entries)));

/// A pax header that renames the entry after it.
_Entry _paxPath(String value) {
  final String body = ' path=$value\n';
  // The length counts its own digits; these records stay under 100 bytes.
  final int length = body.length + 2;
  return _Entry('PaxHeader', utf8.encode('$length$body'), type: 'x');
}

NodeHttpResponse _ok(
  List<int> bytes, {
  int chunk = 1000,
  bool declareLength = true,
}) =>
    NodeHttpResponse(
      statusCode: 200,
      contentLength: declareLength ? bytes.length : null,
      body: Stream<List<int>>.fromIterable(<List<int>>[
        for (int i = 0; i < bytes.length; i += chunk)
          bytes.sublist(i, i + chunk < bytes.length ? i + chunk : bytes.length),
      ]),
    );

NodeHttpResponse _status(
  int code, [
  Map<String, String> headers = const <String, String>{},
]) =>
    NodeHttpResponse(
      statusCode: code,
      headers: headers,
      body: const Stream<List<int>>.empty(),
    );

/// Stands in for api.github.com, github.com and the asset host.
class _FakeGitHub implements NodeHttpClient {
  final Map<String, NodeHttpResponse Function()> routes =
      <String, NodeHttpResponse Function()>{};
  final List<Uri> requested = <Uri>[];
  final List<Map<String, String>> sent = <Map<String, String>>[];

  static String download(String tag, String name) =>
      'https://github.com/$_repo/releases/download/$tag/$name';

  static String stored(String tag, String name) =>
      'https://release-assets.githubusercontent.com/$tag/$name';

  static String api(int perPage) =>
      'https://api.github.com/repos/$_repo/releases?per_page=$perPage';

  /// A release as the API lists it, with its files served the way GitHub
  /// serves them: github.com redirects to the asset host.
  Map<String, dynamic> release(
    String tag,
    Map<String, List<int>> files, {
    bool digests = true,
    bool prerelease = false,
    Map<String, String> digestOf = const <String, String>{},
  }) {
    for (final MapEntry<String, List<int>> file in files.entries) {
      routes[download(tag, file.key)] = () => _status(
            302,
            <String, String>{'Location': stored(tag, file.key)},
          );
      routes[stored(tag, file.key)] = () => _ok(file.value);
    }
    return <String, dynamic>{
      'tag_name': tag,
      'name': tag.split('-').first,
      'draft': false,
      'prerelease': prerelease,
      'published_at': '2026-10-10T23:52:26Z',
      'html_url': 'https://github.com/$_repo/releases/tag/$tag',
      'assets': <Map<String, dynamic>>[
        for (final MapEntry<String, List<int>> file in files.entries)
          <String, dynamic>{
            'name': file.key,
            'size': file.value.length,
            'state': 'uploaded',
            'digest': digestOf[file.key] ??
                (digests ? 'sha256:${_sha(file.value)}' : null),
            'browser_download_url': download(tag, file.key),
          },
      ],
    };
  }

  /// What the API answers, newest first.
  void publish(List<Map<String, dynamic>> releases) {
    for (final int perPage in <int>[10, 30]) {
      routes[api(perPage)] = () => _ok(utf8.encode(jsonEncode(releases)));
    }
  }

  @override
  Future<NodeHttpResponse> get(
    Uri url, {
    required Map<String, String> headers,
  }) async {
    requested.add(url);
    sent.add(headers);
    final NodeHttpResponse Function()? route = routes[url.toString()];
    return route == null ? _status(404) : route();
  }

  @override
  void close() {}

  bool asked(String url) =>
      requested.any((Uri uri) => uri.toString() == url);
}

void main() {
  final DateTime clock = DateTime.utc(2026, 10, 13, 12);

  const String zipName = 'libznn-windows-amd64.zip';
  const String dllName = 'libznn-windows-amd64.dll';
  const String sums = 'SHA256CHECKSUMS.txt';

  final Uint8List bundledBytes = _bytes(1);
  final Uint8List lib9 = _bytes(9, 9000);
  final Uint8List zip9 = _zip(<_Entry>[_Entry(dllName, lib9)]);

  late Directory temp;
  late Directory bundle;
  late _FakeGitHub github;

  NodeLibrary library({int processId = 100}) => NodeLibrary(
        directory: path.join(temp.path, 'profile', 'node'),
        bundledSearchPaths: <String>[bundle.path],
        processId: processId,
        now: () => clock,
      );

  NodeUpdater updater({
    NodePlatform platform = NodePlatform.windowsAmd64,
    int maxBytes = NodeUpdater.defaultMaxBytes,
    NodeLibrary? into,
  }) =>
      NodeUpdater(
        library: into ?? library(),
        http: github,
        platform: platform,
        maxBytes: maxBytes,
        now: () => clock,
      );

  String checksums(Map<String, List<int>> files) => files.entries
      .map((MapEntry<String, List<int>> file) =>
          '${_sha(file.value)}  ${file.key}\n')
      .join();

  /// Everything under the override directory, by name.
  Set<String> left() {
    final Directory directory = Directory(library().directory);
    if (!directory.existsSync()) {
      return <String>{};
    }
    return directory
        .listSync(recursive: true)
        .map((FileSystemEntity entity) =>
            path.relative(entity.path, from: directory.path))
        .toSet();
  }

  /// v0.0.9 as GitHub has it: a digest in the API and a checksum file.
  Future<NodeRelease> published({
    List<int>? archive,
    String? checksumFile,
    bool withChecksumFile = true,
    bool digests = true,
    Map<String, String> digestOf = const <String, String>{},
  }) async {
    final List<int> served = archive ?? zip9;
    github.publish(<Map<String, dynamic>>[
      github.release(
        'v0.0.9-alphanet',
        <String, List<int>>{
          zipName: served,
          if (withChecksumFile)
            sums: utf8.encode(
              checksumFile ?? checksums(<String, List<int>>{zipName: served}),
            ),
        },
        digests: digests,
        digestOf: digestOf,
      ),
    ]);
    return (await updater().latestRelease())!;
  }

  File write(String name, List<int> bytes) =>
      File(path.join(temp.path, name))..writeAsBytesSync(bytes);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('node_updater_test');
    bundle = Directory(path.join(temp.path, 'install'))..createSync();
    File(path.join(bundle.path, NodeLibrary.libraryFileName))
        .writeAsBytesSync(bundledBytes);
    github = _FakeGitHub();
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  group('NodeUpdateSource', () {
    test('defaults to go-zenon and takes owner/name', () {
      expect(NodeUpdateSource().repository, _repo);
      expect(NodeUpdateSource('sol-znn/go-zenon').repository,
          'sol-znn/go-zenon');
      expect(NodeUpdateSource.tryParse(' a.b/c_d-e ')!.repository, 'a.b/c_d-e');
    });

    test('refuses anything else', () {
      for (final String bad in <String>[
        '',
        'go-zenon',
        'a/b/c',
        'a b/c',
        '../..',
        'a/..',
        'https://github.com/a/b',
        'a/b?x=1',
      ]) {
        expect(NodeUpdateSource.tryParse(bad), isNull, reason: bad);
        expect(() => NodeUpdateSource(bad), throwsFormatException);
      }
    });
  });

  group('releases', () {
    Map<String, List<int>> everyAsset() => <String, List<int>>{
          for (final String name in <String>[
            'libznn-darwin-amd64.tar.gz',
            'libznn-darwin-arm64.tar.gz',
            'libznn-darwin-universal.tar.gz',
            'libznn-linux-amd64.tar.gz',
            'libznn-linux-arm64.tar.gz',
            'libznn-windows-amd64.zip',
            'znnd-windows-amd64.zip',
          ])
            name: utf8.encode(name),
          sums: utf8.encode('x'),
        };

    test('picks the asset of each platform', () async {
      github.publish(<Map<String, dynamic>>[
        github.release('v0.0.9-alphanet', everyAsset()),
      ]);

      final Map<NodePlatform, String> expected = <NodePlatform, String>{
        NodePlatform.windowsAmd64: 'libznn-windows-amd64.zip',
        NodePlatform.linuxAmd64: 'libznn-linux-amd64.tar.gz',
        NodePlatform.linuxArm64: 'libznn-linux-arm64.tar.gz',
        // The ones the checksum file lists, not the universal archive.
        NodePlatform.macosAmd64: 'libznn-darwin-amd64.tar.gz',
        NodePlatform.macosArm64: 'libznn-darwin-arm64.tar.gz',
      };
      for (final NodePlatform platform in NodePlatform.values) {
        final NodeRelease release =
            (await updater(platform: platform).latestRelease())!;
        final NodeReleaseAsset asset = release.asset!;
        expect(asset.name, expected[platform], reason: platform.name);
        expect(asset.size, utf8.encode(asset.name).length);
        expect(asset.sha256, _sha(utf8.encode(asset.name)));
        expect(asset.digest, 'sha256:${asset.sha256}');
        expect(
          asset.downloadUrl.toString(),
          _FakeGitHub.download('v0.0.9-alphanet', asset.name),
        );
        expect(release.checksums!.name, sums);
      }
    });

    test('knows the member inside each archive', () {
      expect(
        NodePlatform.macosArm64.memberNames,
        <String>['libznn-darwin-arm64.dylib', 'libznn-darwin-universal.dylib'],
      );
      expect(NodePlatform.windowsAmd64.memberNames, <String>[dllName]);
      expect(
        NodePlatform.linuxArm64.memberNameOf('libznn-linux-arm64.tar.gz'),
        'libznn-linux-arm64.so',
      );
    });

    test('falls back to the universal archive on macOS', () async {
      github.publish(<Map<String, dynamic>>[
        github.release(
          'v0.0.6-alphanet',
          <String, List<int>>{
            'libznn-darwin-universal.tar.gz': <int>[1],
            'libznn-windows-amd64.zip': <int>[2],
          },
        ),
      ]);

      final NodeRelease release =
          (await updater(platform: NodePlatform.macosArm64).latestRelease())!;

      expect(release.asset!.name, 'libznn-darwin-universal.tar.gz');
      expect(release.checksums, isNull);
    });

    test('lists a release without an asset for this platform', () async {
      github.publish(<Map<String, dynamic>>[
        github.release(
          'v0.0.9-alphanet',
          <String, List<int>>{'libznn-windows-amd64.zip': <int>[2]},
          digests: false,
        ),
      ]);

      final List<NodeRelease> found =
          await updater(platform: NodePlatform.linuxArm64).releases();

      expect(found, hasLength(1));
      expect(found.single.asset, isNull);
      expect(found.single.tag, 'v0.0.9-alphanet');
      expect(found.single.name, 'v0.0.9');
      expect(found.single.repository, _repo);
      expect(found.single.publishedAt, DateTime.utc(2026, 10, 10, 23, 52, 26));
      expect(
        found.single.pageUrl.toString(),
        'https://github.com/$_repo/releases/tag/v0.0.9-alphanet',
      );
      // No digest in the API, as for every release before v0.0.9.
      expect(
        (await updater().releases()).single.asset!.sha256,
        isNull,
      );
    });

    test('finds a checksum file by any of its names', () async {
      for (final String name in <String>[
        'SHA256CHECKSUMS.txt',
        'sha256sums',
        'SHA256SUMS.txt',
        'Checksums.txt',
      ]) {
        github.publish(<Map<String, dynamic>>[
          github.release('v1', <String, List<int>>{name: <int>[1]}),
        ]);
        expect(
          (await updater().latestRelease())!.checksums!.name,
          name,
        );
      }
    });

    test('skips a prerelease unless asked', () async {
      github.publish(<Map<String, dynamic>>[
        github.release(
          'v0.1.0-rc1',
          <String, List<int>>{zipName: zip9},
          prerelease: true,
        ),
        github.release('v0.0.9-alphanet', <String, List<int>>{zipName: zip9}),
      ]);

      expect((await updater().latestRelease())!.tag, 'v0.0.9-alphanet');
      final NodeRelease newest =
          (await updater().latestRelease(includePrereleases: true))!;
      expect(newest.tag, 'v0.1.0-rc1');
      expect(newest.prerelease, isTrue);
      expect(
        (await updater().releases())
            .map((NodeRelease release) => release.tag),
        <String>['v0.1.0-rc1', 'v0.0.9-alphanet'],
      );
    });

    test('is null when nothing is published', () async {
      github.publish(<Map<String, dynamic>>[]);

      expect(await updater().latestRelease(), isNull);
    });

    test('asks the API the way GitHub wants', () async {
      github.routes[_FakeGitHub.api(100)] = () => _ok(utf8.encode('[]'));
      await updater().releases(limit: 500);

      expect(
        github.requested.single.toString(),
        'https://api.github.com/repos/$_repo/releases?per_page=100',
      );
      expect(github.sent.single['accept'], 'application/vnd.github+json');
      expect(github.sent.single['user-agent'], isNotEmpty);
    });

    test('maps a rate limit to its own error, with the reset time', () async {
      github.routes[_FakeGitHub.api(10)] = () => _status(
            403,
            <String, String>{
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset': '1791904866',
            },
          );
      await expectLater(
        updater().releases(),
        throwsA(
          isA<NodeUpdateRateLimited>().having(
            (NodeUpdateRateLimited e) => e.resetAt,
            'resetAt',
            DateTime.fromMillisecondsSinceEpoch(1791904866000, isUtc: true),
          ),
        ),
      );

      github.routes[_FakeGitHub.api(10)] =
          () => _status(429, <String, String>{'retry-after': '90'});
      await expectLater(
        updater().releases(),
        throwsA(
          isA<NodeUpdateRateLimited>().having(
            (NodeUpdateRateLimited e) => e.resetAt,
            'resetAt',
            clock.add(const Duration(seconds: 90)),
          ),
        ),
      );

      // A 403 that is not a rate limit stays a plain status.
      github.routes[_FakeGitHub.api(10)] = () =>
          _status(403, <String, String>{'x-ratelimit-remaining': '41'});
      await expectLater(
        updater().releases(),
        throwsA(
          isA<NodeUpdateHttpError>().having(
            (NodeUpdateHttpError e) => e.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('gives a missing repository, a dead network and bad JSON a type',
        () async {
      await expectLater(
        updater().releases(),
        throwsA(
          isA<NodeUpdateHttpError>().having(
            (NodeUpdateHttpError e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );

      github.routes[_FakeGitHub.api(10)] =
          () => throw const SocketException('Failed host lookup');
      await expectLater(
        updater().releases(),
        throwsA(isA<NodeUpdateNetworkError>()),
      );

      for (final String body in <String>[
        '<html>',
        '{"message": "x"}',
        '[1]',
        '[{"name": "no tag"}]',
      ]) {
        github.routes[_FakeGitHub.api(10)] = () => _ok(utf8.encode(body));
        await expectLater(
          updater().releases(),
          throwsA(isA<NodeUpdateMalformedResponse>()),
          reason: body,
        );
      }
    });

    test('refuses a redirect off the API host', () async {
      github.routes[_FakeGitHub.api(10)] = () => _status(
            301,
            <String, String>{'location': 'https://github.com/elsewhere'},
          );

      await expectLater(
        updater().releases(),
        throwsA(isA<NodeUpdateForbiddenUrl>()),
      );
      expect(github.requested, hasLength(1));
    });
  });

  group('IoNodeHttpClient', () {
    test('does not follow a redirect, and streams a body', () async {
      // The one client the fake stands in for, against a loopback server:
      // the updater itself would refuse this host.
      final HttpServer server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final List<String> asked = <String>[];
      server.listen((HttpRequest request) {
        asked.add(request.uri.path);
        final HttpResponse response = request.response;
        if (request.uri.path == '/moved') {
          response
            ..statusCode = HttpStatus.found
            ..headers.set('Location', '/file');
        } else {
          response
            ..headers.set(
              'X-Seen-Agent',
              request.headers.value('user-agent') ?? '',
            )
            ..contentLength = lib9.length
            ..add(lib9);
        }
        unawaited(response.close());
      });
      final IoNodeHttpClient client = IoNodeHttpClient();
      final Uri base = Uri.parse('http://127.0.0.1:${server.port}');
      const Map<String, String> headers = <String, String>{
        'user-agent': 'syrius-test',
      };
      try {
        final NodeHttpResponse moved =
            await client.get(base.resolve('/moved'), headers: headers);
        expect(moved.statusCode, 302);
        expect(moved.headers['location'], '/file');
        await moved.body.drain<void>();
        expect(asked, <String>['/moved']);

        final NodeHttpResponse file =
            await client.get(base.resolve('/file'), headers: headers);
        expect(file.statusCode, 200);
        expect(file.contentLength, lib9.length);
        expect(file.headers['x-seen-agent'], 'syrius-test');
        expect(
          await file.body.expand((List<int> chunk) => chunk).toList(),
          lib9,
        );
      } finally {
        client.close();
        await server.close(force: true);
      }
    });
  });

  group('parseChecksums', () {
    final String a = _sha(<int>[1]);
    final String b = _sha(<int>[2]);

    test('reads sha256sum output', () {
      expect(
        NodeUpdater.parseChecksums(
          '$a  libznn-linux-amd64.tar.gz\n'
          '${b.toUpperCase()} *libznn-windows-amd64.zip\r\n'
          '$a  libznn-linux-amd64.tar.gz\n'
          '\n',
        ),
        <String, String>{
          'libznn-linux-amd64.tar.gz': a,
          'libznn-windows-amd64.zip': b,
        },
      );
    });

    test('refuses everything else', () {
      for (final String bad in <String>[
        '',
        '\n\n',
        'not a checksum file',
        '${a.substring(1)}  short.zip\n',
        '${a}0  long.zip\n',
        '$a\n',
        '${a}name.zip\n',
        '$a  dir/name.zip\n',
        r'$a  dir\name.zip'.replaceFirst(r'$a', a),
        '$a  two words.zip\n',
        ' $a  indented.zip\n',
        '$a  one.zip\n$b  one.zip\n',
        '$a  one.zip\ngarbage\n',
      ]) {
        expect(
          () => NodeUpdater.parseChecksums(bad),
          throwsA(isA<NodeUpdateMalformedChecksums>()),
          reason: jsonEncode(bad),
        );
      }
    });
  });

  group('download', () {
    test('verifies against the checksum file and the API digest', () async {
      final NodeRelease release = await published();
      final List<List<int>> progress = <List<int>>[];

      final DownloadedNodeLibrary got = await updater().download(
        release,
        onProgress: (int received, int total) =>
            progress.add(<int>[received, total]),
      );

      expect(got.checksumFile, NodeChecksumFileCheck.verified);
      expect(got.apiDigest, NodeApiDigestCheck.verified);
      expect(got.verified, isTrue);
      expect(got.sha256, _sha(lib9));
      expect(got.size, lib9.length);
      expect(got.archiveSha256, _sha(zip9));
      expect(got.source, _repo);
      expect(got.tag, 'v0.0.9-alphanet');
      expect(got.asset, zipName);
      expect(got.isFromFile, isFalse);
      expect(got.file.readAsBytesSync(), lib9);
      expect(path.dirname(got.file.path), updater().downloadDirectory);
      // The archive is gone; only the library waits for an answer.
      expect(left(), <String>{
        'download',
        path.join('download', path.basename(got.file.path)),
      });
      expect(progress.last, <int>[zip9.length, zip9.length]);
      expect(progress.length, greaterThan(1));
      // The checksum file first, then the archive, each by its redirect.
      expect(
        github.requested.skip(1).map((Uri url) => url.toString()),
        <String>[
          _FakeGitHub.download('v0.0.9-alphanet', sums),
          _FakeGitHub.stored('v0.0.9-alphanet', sums),
          _FakeGitHub.download('v0.0.9-alphanet', zipName),
          _FakeGitHub.stored('v0.0.9-alphanet', zipName),
        ],
      );
    });

    test('goes on with the checksum file alone', () async {
      // v0.0.8 and older: the API has no digest.
      final NodeRelease release = await published(digests: false);

      final DownloadedNodeLibrary got = await updater().download(release);

      expect(got.checksumFile, NodeChecksumFileCheck.verified);
      expect(got.apiDigest, NodeApiDigestCheck.absent);
      expect(got.verified, isTrue);
      expect(got.sha256, _sha(lib9));
    });

    test('goes on with the API digest when the file does not list the asset',
        () async {
      final NodeRelease release = await published(
        checksumFile: checksums(<String, List<int>>{
          'libznn-linux-amd64.tar.gz': <int>[1],
        }),
      );

      final DownloadedNodeLibrary got = await updater().download(release);

      expect(got.checksumFile, NodeChecksumFileCheck.assetNotListed);
      expect(got.apiDigest, NodeApiDigestCheck.verified);
      expect(got.verified, isTrue);
    });

    test('goes on with the API digest when there is no checksum file',
        () async {
      final NodeRelease release = await published(withChecksumFile: false);

      final DownloadedNodeLibrary got = await updater().download(release);

      expect(got.checksumFile, NodeChecksumFileCheck.absentFromRelease);
      expect(got.apiDigest, NodeApiDigestCheck.verified);
    });

    test('refuses a release with nothing to check against, unless told',
        () async {
      NodeRelease release =
          await published(withChecksumFile: false, digests: false);
      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateUnverified>().having(
            (NodeUpdateUnverified e) => e.checksumFile,
            'checksumFile',
            NodeChecksumFileCheck.absentFromRelease,
          ),
        ),
      );
      // Refused before the archive was asked for.
      expect(
        github.asked(_FakeGitHub.download('v0.0.9-alphanet', zipName)),
        isFalse,
      );
      expect(left(), isEmpty);

      release = await published(
        digests: false,
        checksumFile: checksums(<String, List<int>>{'other.zip': <int>[1]}),
      );
      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateUnverified>().having(
            (NodeUpdateUnverified e) => e.checksumFile,
            'checksumFile',
            NodeChecksumFileCheck.assetNotListed,
          ),
        ),
      );

      final DownloadedNodeLibrary got =
          await updater().download(release, allowUnverified: true);
      expect(got.checksumFile, NodeChecksumFileCheck.assetNotListed);
      expect(got.apiDigest, NodeApiDigestCheck.absent);
      expect(got.verified, isFalse);
      expect(got.sha256, _sha(lib9));
    });

    test('refuses an archive the checksum file does not vouch for', () async {
      final String expected = _sha(<int>[7]);
      final NodeRelease release = await published(
        digests: false,
        checksumFile: '$expected  $zipName\n',
      );

      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateDigestMismatch>()
              .having(
                (NodeUpdateDigestMismatch e) => e.check,
                'check',
                NodeDigestSource.checksumFile,
              )
              .having(
                (NodeUpdateDigestMismatch e) => e.expected,
                'expected',
                expected,
              )
              .having(
                (NodeUpdateDigestMismatch e) => e.actual,
                'actual',
                _sha(zip9),
              ),
        ),
      );
      expect(left(), isEmpty);
    });

    test('refuses an archive the API digest does not vouch for', () async {
      final String expected = _sha(<int>[7]);
      final NodeRelease release = await published(
        withChecksumFile: false,
        digestOf: <String, String>{zipName: 'sha256:$expected'},
      );

      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateDigestMismatch>()
              .having(
                (NodeUpdateDigestMismatch e) => e.check,
                'check',
                NodeDigestSource.apiDigest,
              )
              .having(
                (NodeUpdateDigestMismatch e) => e.expected,
                'expected',
                expected,
              )
              .having(
                (NodeUpdateDigestMismatch e) => e.actual,
                'actual',
                _sha(zip9),
              ),
        ),
      );
      expect(left(), isEmpty);
    });

    test('refuses a release whose two hashes disagree', () async {
      final String other = _sha(<int>[7]);
      final NodeRelease release = await published(
        digestOf: <String, String>{zipName: 'sha256:$other'},
      );

      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateChecksumConflict>()
              .having(
                (NodeUpdateChecksumConflict e) => e.checksumFile,
                'checksumFile',
                _sha(zip9),
              )
              .having(
                (NodeUpdateChecksumConflict e) => e.apiDigest,
                'apiDigest',
                other,
              ),
        ),
      );
      expect(
        github.asked(_FakeGitHub.download('v0.0.9-alphanet', zipName)),
        isFalse,
      );
      expect(left(), isEmpty);
    });

    test('refuses a checksum file it cannot read', () async {
      NodeRelease release = await published(checksumFile: 'see the website\n');
      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateMalformedChecksums>()),
      );

      release = await published(
        checksumFile: '${_sha(zip9)}  $zipName\n' * 2000,
      );
      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateMalformedChecksums>()),
      );
      expect(left(), isEmpty);
    });

    test('does not treat a checksum file it cannot fetch as absent',
        () async {
      final NodeRelease release = await published();
      github.routes.remove(_FakeGitHub.stored('v0.0.9-alphanet', sums));

      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateHttpError>()),
      );
      expect(
        github.asked(_FakeGitHub.download('v0.0.9-alphanet', zipName)),
        isFalse,
      );
    });

    test('refuses a redirect to a host that is not GitHub', () async {
      final NodeRelease release = await published(withChecksumFile: false);
      for (final String target in <String>[
        'https://evil.example/libznn.zip',
        'http://release-assets.githubusercontent.com/libznn.zip',
        'https://user@github.com/libznn.zip',
        'https://github.com:8443/libznn.zip',
        'https://github.com.evil.example/libznn.zip',
      ]) {
        github.requested.clear();
        github.routes[_FakeGitHub.download('v0.0.9-alphanet', zipName)] =
            () => _status(302, <String, String>{'location': target});
        github.routes[target] = () => _ok(zip9);

        await expectLater(
          updater().download(release),
          throwsA(
            isA<NodeUpdateForbiddenUrl>().having(
              (NodeUpdateForbiddenUrl e) => e.url.toString(),
              'url',
              Uri.parse(target).toString(),
            ),
          ),
          reason: target,
        );
        // Refused before a byte was asked of it.
        expect(github.requested, hasLength(1), reason: target);
        expect(left(), isEmpty);
      }
    });

    test('refuses a download URL that is not GitHub to begin with', () async {
      final NodeRelease release = NodeRelease(
        repository: _repo,
        tag: 'v1',
        name: 'v1',
        pageUrl: Uri.parse('https://github.com/$_repo'),
        asset: NodeReleaseAsset(
          name: zipName,
          size: zip9.length,
          downloadUrl: Uri.parse('https://api.github.com/x.zip'),
          sha256: _sha(zip9),
        ),
      );

      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateForbiddenUrl>()),
      );
      expect(github.requested, isEmpty);
    });

    test('gives up on a redirect loop', () async {
      final NodeRelease release = await published(withChecksumFile: false);
      final String url = _FakeGitHub.download('v0.0.9-alphanet', zipName);
      github.routes[url] =
          () => _status(302, <String, String>{'location': url});

      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateMalformedResponse>()),
      );
    });

    test('cuts off a download that runs over the cap', () async {
      final NodeRelease release = await published(withChecksumFile: false);
      final String url = _FakeGitHub.stored('v0.0.9-alphanet', zipName);
      int delivered = 0;
      github.routes[url] = () => NodeHttpResponse(
            statusCode: 200,
            body: Stream<List<int>>.periodic(
              Duration.zero,
              (int i) {
                delivered++;
                return Uint8List(1000);
              },
            ),
          );

      await expectLater(
        updater(maxBytes: 20000).download(release),
        throwsA(
          isA<NodeUpdateTooLarge>().having(
            (NodeUpdateTooLarge e) => e.limit,
            'limit',
            20000,
          ),
        ),
      );
      // The endless body was dropped just past the cap.
      expect(delivered, lessThan(30));
      expect(left(), isEmpty);
    });

    test('does not start a download declared larger than the cap', () async {
      final NodeRelease release = await published(withChecksumFile: false);

      // By the size the API lists: no request at all.
      github.requested.clear();
      await expectLater(
        updater(maxBytes: zip9.length - 1).download(release),
        throwsA(isA<NodeUpdateTooLarge>()),
      );
      expect(github.requested, isEmpty);

      // By the size the server declares.
      github.routes[_FakeGitHub.stored('v0.0.9-alphanet', zipName)] =
          () => NodeHttpResponse(
                statusCode: 200,
                contentLength: NodeUpdater.defaultMaxBytes + 1,
                body: Stream<List<int>>.value(zip9),
              );
      await expectLater(
        updater().download(release),
        throwsA(isA<NodeUpdateTooLarge>()),
      );
      expect(left(), isEmpty);
    });

    test('refuses a download of another length than listed', () async {
      final NodeRelease release = await published(withChecksumFile: false);
      github.routes[_FakeGitHub.stored('v0.0.9-alphanet', zipName)] =
          () => _ok(zip9.sublist(0, 500), declareLength: false);

      await expectLater(
        updater().download(release),
        throwsA(
          isA<NodeUpdateSizeMismatch>()
              .having((NodeUpdateSizeMismatch e) => e.actual, 'actual', 500)
              .having(
                (NodeUpdateSizeMismatch e) => e.expected,
                'expected',
                zip9.length,
              ),
        ),
      );
      expect(left(), isEmpty);
    });

    test('refuses an archive without the library, or with a climbing path',
        () async {
      for (final MapEntry<NodeArchiveProblem, Uint8List> bad
          in <NodeArchiveProblem, Uint8List>{
        NodeArchiveProblem.memberMissing:
            _zip(<_Entry>[_Entry('README.md', lib9)]),
        NodeArchiveProblem.unsafePath: _zip(<_Entry>[
          _Entry(dllName, lib9),
          _Entry('../../Startup/evil.exe', <int>[1]),
        ]),
        NodeArchiveProblem.memberDuplicated: _zip(<_Entry>[
          _Entry(dllName, lib9),
          _Entry('other/$dllName', bundledBytes),
        ]),
        NodeArchiveProblem.corrupt: _bytes(5, 3000),
      }.entries) {
        final NodeRelease release = await published(archive: bad.value);

        await expectLater(
          updater().download(release),
          throwsA(
            isA<NodeUpdateArchiveError>().having(
              (NodeUpdateArchiveError e) => e.problem,
              'problem',
              bad.key,
            ),
          ),
          reason: bad.key.name,
        );
        expect(left(), isEmpty, reason: bad.key.name);
      }
    });

    test('caps the unpacked library as well as the archive', () async {
      final NodeRelease release = await published(
        archive: _zip(<_Entry>[_Entry(dllName, Uint8List(60000))]),
      );

      await expectLater(
        updater(maxBytes: 50000).download(release),
        throwsA(isA<NodeUpdateTooLarge>()),
      );
      expect(left(), isEmpty);
    });

    test('unpacks a tar.gz for Linux and macOS', () async {
      const String tarName = 'libznn-darwin-arm64.tar.gz';
      final Uint8List tar = _tarGz(<_Entry>[
        _Entry('libznn-darwin-arm64.dylib', lib9),
      ]);
      github.publish(<Map<String, dynamic>>[
        github.release('v0.0.9-alphanet', <String, List<int>>{
          tarName: tar,
          'libznn-darwin-universal.tar.gz': <int>[1],
          // As published: the universal archive is not in the file.
          sums: utf8.encode(checksums(<String, List<int>>{tarName: tar})),
        }),
      ]);
      final NodeUpdater mac = updater(platform: NodePlatform.macosArm64);

      final DownloadedNodeLibrary got =
          await mac.download((await mac.latestRelease())!);

      expect(got.asset, tarName);
      expect(got.checksumFile, NodeChecksumFileCheck.verified);
      expect(got.apiDigest, NodeApiDigestCheck.verified);
      expect(got.sha256, _sha(lib9));
      expect(got.file.path, endsWith('.dylib'));
      expect(got.file.readAsBytesSync(), lib9);
    });

    test('leaves nothing behind when cancelled', () async {
      final NodeRelease release = await published();
      bool dropped = false;
      final StreamController<List<int>> body = StreamController<List<int>>(
        onCancel: () => dropped = true,
      );
      github.routes[_FakeGitHub.stored('v0.0.9-alphanet', zipName)] =
          () => NodeHttpResponse(statusCode: 200, body: body.stream);
      final CancelToken cancel = CancelToken();
      int seen = 0;

      final Future<DownloadedNodeLibrary> pending = updater().download(
        release,
        cancel: cancel,
        onProgress: (int received, int total) {
          seen = received;
          // Half an archive is on disk now.
          expect(left(), hasLength(2));
          cancel.cancel();
        },
      );
      body.add(zip9.sublist(0, 1000));

      await expectLater(pending, throwsA(isA<NodeUpdateCancelled>()));
      expect(seen, 1000);
      expect(dropped, isTrue);
      expect(left(), isEmpty);
      await body.close();
    });

    test('does not start when already cancelled', () async {
      final NodeRelease release = await published();
      github.requested.clear();

      await expectLater(
        updater().download(release, cancel: CancelToken()..cancel()),
        throwsA(isA<NodeUpdateCancelled>()),
      );
      expect(github.requested, isEmpty);
    });

    test('says so when the release has nothing for this platform', () async {
      final NodeRelease release = await published();
      final NodeRelease bare = NodeRelease(
        repository: release.repository,
        tag: release.tag,
        name: release.name,
        pageUrl: release.pageUrl,
      );

      await expectLater(
        updater().download(bare),
        throwsA(isA<NodeUpdateNoAsset>()),
      );
    });

    test('clears out what a crashed run left, and nothing younger', () async {
      final NodeRelease release = await published();
      final NodeUpdater node = updater();
      final Directory directory = Directory(node.downloadDirectory)
        ..createSync(recursive: true);
      final File old = File(path.join(directory.path, 'libznn-old.archive'))
        ..writeAsBytesSync(<int>[1])
        ..setLastModifiedSync(clock.subtract(const Duration(hours: 2)));
      final File young = File(path.join(directory.path, 'libznn-young.dll'))
        ..writeAsBytesSync(<int>[1])
        ..setLastModifiedSync(clock.subtract(const Duration(minutes: 5)));

      final DownloadedNodeLibrary got = await node.download(release);

      expect(old.existsSync(), isFalse);
      expect(young.existsSync(), isTrue);
      expect(got.file.existsSync(), isTrue);
    });
  });

  group('fromFile', () {
    test('takes a bare library', () async {
      final File picked = write('my-build.DLL', lib9);

      final DownloadedNodeLibrary got = await updater().fromFile(picked);

      expect(got.source, NodeUpdateSource.file);
      expect(got.isFromFile, isTrue);
      expect(got.tag, isNull);
      expect(got.asset, 'my-build.DLL');
      expect(got.sha256, _sha(lib9));
      expect(got.size, lib9.length);
      expect(got.archiveSha256, isNull);
      expect(got.checksumFile, isNull);
      expect(got.apiDigest, isNull);
      expect(got.verified, isFalse);
      expect(got.file.readAsBytesSync(), lib9);
      // A copy: the original can change without changing what is staged.
      expect(got.file.path, isNot(picked.path));
      expect(github.requested, isEmpty);
    });

    test('takes a release archive', () async {
      final Uint8List stored =
          _zip(<_Entry>[_Entry(dllName, lib9)], deflate: false);
      final File picked = write('libznn-windows-amd64 (1).zip', stored);

      final DownloadedNodeLibrary got = await updater().fromFile(picked);

      expect(got.source, NodeUpdateSource.file);
      expect(got.asset, 'libznn-windows-amd64 (1).zip');
      expect(got.sha256, _sha(lib9));
      expect(got.archiveSha256, _sha(stored));
      expect(got.file.readAsBytesSync(), lib9);
      expect(left(), hasLength(2));
    });

    test('takes either macOS archive, as a tar.gz or a tgz', () async {
      final NodeUpdater mac = updater(platform: NodePlatform.macosAmd64);
      for (final String member in <String>[
        'libznn-darwin-amd64.dylib',
        'libznn-darwin-universal.dylib',
      ]) {
        final DownloadedNodeLibrary got = await mac.fromFile(
          write('built.tgz', _tarGz(<_Entry>[_Entry('./$member', lib9)])),
        );
        expect(got.sha256, _sha(lib9), reason: member);
        mac.discard(got);
      }
      // The other architecture's library is not one this process can load.
      await expectLater(
        mac.fromFile(
          write(
            'built.tar.gz',
            _tarGz(<_Entry>[_Entry('libznn-darwin-arm64.dylib', lib9)]),
          ),
        ),
        throwsA(
          isA<NodeUpdateArchiveError>().having(
            (NodeUpdateArchiveError e) => e.problem,
            'problem',
            NodeArchiveProblem.memberMissing,
          ),
        ),
      );
      expect(left(), isEmpty);
    });

    test('refuses what it cannot use', () async {
      final NodeUpdater node = updater();
      await expectLater(
        node.fromFile(write('libznn.so', lib9)),
        throwsA(isA<NodeUpdateUnsupportedFile>()),
      );
      await expectLater(
        node.fromFile(write('notes.txt', lib9)),
        throwsA(isA<NodeUpdateUnsupportedFile>()),
      );
      await expectLater(
        node.fromFile(write('empty.dll', <int>[])),
        throwsA(isA<NodeUpdateUnsupportedFile>()),
      );
      await expectLater(
        node.fromFile(File(path.join(temp.path, 'missing.dll'))),
        throwsA(isA<NodeUpdateFileError>()),
      );
      await expectLater(
        updater(maxBytes: 100).fromFile(write('big.dll', lib9)),
        throwsA(isA<NodeUpdateTooLarge>()),
      );
      await expectLater(
        node.fromFile(write('broken.zip', _bytes(3, 2000))),
        throwsA(
          isA<NodeUpdateArchiveError>().having(
            (NodeUpdateArchiveError e) => e.problem,
            'problem',
            NodeArchiveProblem.corrupt,
          ),
        ),
      );
      expect(left(), isEmpty);
    });
  });

  group('stage', () {
    test('writes a staged pair the loader then promotes', () async {
      final NodeLibrary lib = library();
      final NodeUpdater node = updater(into: lib);
      final DownloadedNodeLibrary got =
          await node.download(await published());

      await node.stage(got);

      expect(got.file.existsSync(), isFalse);
      expect(left(), <String>{
        'libznn.next${NodeLibrary.extension}',
        'libznn.next.json',
      });
      expect(
        jsonDecode(lib.stagedManifest.readAsStringSync()),
        <String, dynamic>{
          'source': _repo,
          'tag': 'v0.0.9-alphanet',
          'asset': zipName,
          'sha256': _sha(lib9),
          'installedAt': '2026-10-13T12:00:00.000Z',
        },
      );
      expect((await lib.status()).staged!.tag, 'v0.0.9-alphanet');

      final PromotionResult result = library(processId: 101).promoteStaged();
      expect(result.outcome, PromotionOutcome.promoted);
      expect(lib.overrideLibrary.readAsBytesSync(), lib9);
      final ResolvedNodeLibrary resolved = library(processId: 101).resolve()!;
      expect(resolved.kind, NodeLibraryKind.override);
      expect(resolved.manifest!.sha256, _sha(lib9));
    });

    test('stages a picked file as source "file"', () async {
      final NodeLibrary lib = library();
      final NodeUpdater node = updater(into: lib);

      await node.stage(await node.fromFile(write('mine.dll', lib9)));

      final NodeLibraryManifest staged = (await lib.status()).staged!;
      expect(staged.source, 'file');
      expect(staged.tag, isNull);
      expect(staged.asset, 'mine.dll');
      expect(lib.promoteStaged().outcome, PromotionOutcome.promoted);
    });

    test('refuses a temporary library that changed, and cleans up', () async {
      final NodeLibrary lib = library();
      final NodeUpdater node = updater(into: lib);
      final DownloadedNodeLibrary got =
          await node.download(await published());
      got.file.writeAsBytesSync(bundledBytes);

      await expectLater(node.stage(got), throwsA(isA<NodeUpdateFileError>()));
      expect(left(), isEmpty);

      // Used up: staging it again is an error, not a crash.
      await expectLater(node.stage(got), throwsA(isA<NodeUpdateFileError>()));
    });

    test('discard deletes the temporary library', () async {
      final NodeUpdater node = updater();
      final DownloadedNodeLibrary got =
          await node.download(await published());

      node
        ..discard(got)
        ..discard(got);

      expect(left(), isEmpty);
    });
  });

  group('compare', () {
    NodeRelease release(String tag) => NodeRelease(
          repository: _repo,
          tag: tag,
          name: tag,
          pageUrl: Uri.parse('https://github.com/$_repo/releases/tag/$tag'),
        );

    void put(File libraryFile, File manifest, List<int> bytes, String? tag,
        {String source = _repo}) {
      libraryFile.parent.createSync(recursive: true);
      libraryFile.writeAsBytesSync(bytes);
      manifest.writeAsStringSync(
        jsonEncode(
          NodeLibraryManifest(
            source: source,
            tag: tag,
            asset: 'x',
            sha256: _sha(bytes),
            installedAt: clock,
          ).toJson(),
        ),
      );
    }

    test('is unknown for the bundled library, until hashes can be compared',
        () async {
      final NodeLibraryStatus status = await library().status();

      expect(
        NodeUpdater.compare(status, release('v0.0.9')),
        NodeUpdateState.unknown,
      );
      expect(
        NodeUpdater.compare(
          status,
          release('v0.0.9'),
          librarySha256: _sha(bundledBytes).toUpperCase(),
        ),
        NodeUpdateState.upToDate,
      );
      expect(
        NodeUpdater.compare(
          status,
          release('v0.0.9'),
          librarySha256: _sha(lib9),
        ),
        NodeUpdateState.updateAvailable,
      );
    });

    test('compares an installed override by tag', () async {
      final NodeLibrary lib = library();
      put(lib.overrideLibrary, lib.overrideManifest, lib9, 'v0.0.9');
      final NodeLibraryStatus status = await lib.status();

      expect(
        NodeUpdater.compare(status, release('v0.0.9')),
        NodeUpdateState.upToDate,
      );
      expect(
        NodeUpdater.compare(status, release('v0.0.10')),
        NodeUpdateState.updateAvailable,
      );
    });

    test('says staged when this release waits for a restart', () async {
      final NodeLibrary lib = library();
      put(lib.overrideLibrary, lib.overrideManifest, bundledBytes, 'v0.0.8');
      put(lib.stagedLibrary, lib.stagedManifest, lib9, 'v0.0.9');
      final NodeLibraryStatus status = await lib.status();

      expect(
        NodeUpdater.compare(status, release('v0.0.9')),
        NodeUpdateState.staged,
      );
      // Another release than the staged one is still an update.
      expect(
        NodeUpdater.compare(status, release('v0.0.10')),
        NodeUpdateState.updateAvailable,
      );
    });

    test('does not compare tags across sources', () async {
      final NodeLibrary lib = library();
      put(
        lib.overrideLibrary,
        lib.overrideManifest,
        lib9,
        'v0.0.9',
        source: 'someone/fork',
      );
      NodeLibraryStatus status = await lib.status();
      expect(
        NodeUpdater.compare(status, release('v0.0.9')),
        NodeUpdateState.unknown,
      );
      expect(
        NodeUpdater.compare(
          status,
          release('v0.0.9'),
          librarySha256: _sha(lib9),
        ),
        NodeUpdateState.upToDate,
      );

      put(lib.overrideLibrary, lib.overrideManifest, lib9, null,
          source: 'file');
      put(lib.stagedLibrary, lib.stagedManifest, bundledBytes, null,
          source: 'file');
      status = await lib.status();
      expect(
        NodeUpdater.compare(status, release('v0.0.9')),
        NodeUpdateState.unknown,
      );
      expect(
        NodeUpdater.compare(
          status,
          release('v0.0.9'),
          librarySha256: _sha(bundledBytes),
        ),
        NodeUpdateState.staged,
      );
    });
  });

  group('NodeArchive', () {
    NodeArchiveMember extract(
      List<int> archive,
      NodeArchiveFormat format, {
      List<String> names = const <String>['libznn.so'],
      int maxBytes = 1 << 20,
    }) =>
        NodeArchive.extractMember(
          archivePath: write('archive', archive).path,
          format: format,
          memberNames: names,
          outputPath: path.join(temp.path, 'out'),
          maxBytes: maxBytes,
        );

    Matcher refuses(NodeArchiveProblem problem) => throwsA(
          isA<NodeArchiveException>().having(
            (NodeArchiveException e) => e.problem,
            'problem',
            problem,
          ),
        );

    for (final NodeArchiveFormat format in NodeArchiveFormat.values) {
      Uint8List pack(List<_Entry> entries) =>
          format == NodeArchiveFormat.zip ? _zip(entries) : _tarGz(entries);

      group(format.name, () {
        test('takes the one member, wherever it lies', () {
          for (final String name in <String>[
            'libznn.so',
            './libznn.so',
            'build/out/libznn.so',
          ]) {
            final NodeArchiveMember member = extract(
              pack(<_Entry>[
                _Entry('README.md', <int>[1, 2, 3]),
                _Entry(name, lib9),
                _Entry('libznn.so.sig', <int>[4]),
              ]),
              format,
            );

            expect(member.name, 'libznn.so', reason: name);
            expect(member.sha256, _sha(lib9));
            expect(member.size, lib9.length);
            expect(
              File(path.join(temp.path, 'out')).readAsBytesSync(),
              lib9,
            );
          }
        });

        test('refuses an archive without the member', () {
          expect(
            () => extract(pack(<_Entry>[_Entry('libznn.dll', lib9)]), format),
            refuses(NodeArchiveProblem.memberMissing),
          );
          expect(
            () => extract(pack(<_Entry>[]), format),
            refuses(NodeArchiveProblem.memberMissing),
          );
        });

        test('refuses an archive with the member twice', () {
          expect(
            () => extract(
              pack(<_Entry>[
                _Entry('libznn.so', lib9),
                _Entry('libznn.so', bundledBytes),
              ]),
              format,
            ),
            refuses(NodeArchiveProblem.memberDuplicated),
          );
          expect(
            () => extract(
              pack(<_Entry>[
                _Entry('a/libznn.so', lib9),
                _Entry('b/libznn-arm.so', bundledBytes),
              ]),
              format,
              names: <String>['libznn.so', 'libznn-arm.so'],
            ),
            refuses(NodeArchiveProblem.memberDuplicated),
          );
        });

        test('refuses any path that climbs out, member or not', () {
          for (final String name in <String>[
            '../libznn.so',
            'a/../../libznn.so',
            '/etc/libznn.so',
            r'..\libznn.so',
            r'C:\Windows\libznn.so',
            'a/../b/notes.txt',
          ]) {
            expect(
              () => extract(
                pack(<_Entry>[_Entry('libznn.so', lib9), _Entry(name, lib9)]),
                format,
              ),
              refuses(NodeArchiveProblem.unsafePath),
              reason: name,
            );
          }
          // Nothing was ever written where the archive pointed.
          expect(
            temp.parent
                .listSync()
                .where((FileSystemEntity e) => e.path.endsWith('libznn.so')),
            isEmpty,
          );
        });

        test('refuses a member over the cap, and an empty one', () {
          expect(
            () => extract(
              pack(<_Entry>[_Entry('libznn.so', lib9)]),
              format,
              maxBytes: lib9.length - 1,
            ),
            refuses(NodeArchiveProblem.tooLarge),
          );
          expect(
            () => extract(pack(<_Entry>[_Entry('libznn.so', <int>[])]), format),
            refuses(NodeArchiveProblem.corrupt),
          );
        });

        test('refuses a truncated or damaged archive', () {
          final Uint8List good = pack(<_Entry>[_Entry('libznn.so', lib9)]);
          expect(
            () => extract(good.sublist(0, good.length ~/ 2), format),
            refuses(NodeArchiveProblem.corrupt),
          );
          expect(
            () => extract(_bytes(8, 5000), format),
            refuses(NodeArchiveProblem.corrupt),
          );
          expect(
            () => extract(<int>[], format),
            refuses(NodeArchiveProblem.corrupt),
          );
        });
      });
    }

    test('zip: holds a stored member to its CRC-32', () {
      final Uint8List stored =
          _zip(<_Entry>[_Entry('libznn.so', lib9)], deflate: false);
      expect(
        extract(stored, NodeArchiveFormat.zip).sha256,
        _sha(lib9),
      );

      // One byte of the member, which begins after the 30-byte header and
      // the 9-byte name.
      stored[30 + 9 + 100] ^= 0xFF;
      expect(
        () => extract(stored, NodeArchiveFormat.zip),
        refuses(NodeArchiveProblem.corrupt),
      );
    });

    test('zip: refuses a directory entry that names the member', () {
      expect(
        () => extract(
          _zip(<_Entry>[_Entry('libznn.so/', <int>[])]),
          NodeArchiveFormat.zip,
        ),
        refuses(NodeArchiveProblem.memberMissing),
      );
    });

    test('tar: does not take a link or a directory for the member', () {
      for (final String type in <String>['2', '5', '1']) {
        expect(
          () => extract(
            _tarGz(<_Entry>[_Entry('libznn.so', <int>[], type: type)]),
            NodeArchiveFormat.tarGz,
          ),
          refuses(NodeArchiveProblem.memberMissing),
          reason: type,
        );
      }
    });

    test('tar: follows a pax header to the name it gives', () {
      expect(
        extract(
          _tarGz(<_Entry>[
            _paxPath('deep/libznn.so'),
            _Entry('truncated-name', lib9),
          ]),
          NodeArchiveFormat.tarGz,
        ).sha256,
        _sha(lib9),
      );
      expect(
        () => extract(
          _tarGz(<_Entry>[
            _Entry('libznn.so', lib9),
            _paxPath('../../evil'),
            _Entry('harmless', <int>[1]),
          ]),
          NodeArchiveFormat.tarGz,
        ),
        refuses(NodeArchiveProblem.unsafePath),
      );
    });

    test('tar: caps what a gzip bomb unpacks to', () {
      expect(
        () => extract(
          _tarGz(<_Entry>[
            _Entry('padding', Uint8List(300000)),
            _Entry('libznn.so', lib9),
          ]),
          NodeArchiveFormat.tarGz,
          maxBytes: 100000,
        ),
        refuses(NodeArchiveProblem.tooLarge),
      );
    });

    test('knows an archive by its name', () {
      expect(NodeArchiveFormat.ofFileName('A.ZIP'), NodeArchiveFormat.zip);
      expect(NodeArchiveFormat.ofFileName('a.tar.gz'), NodeArchiveFormat.tarGz);
      expect(NodeArchiveFormat.ofFileName('a.tgz'), NodeArchiveFormat.tarGz);
      expect(NodeArchiveFormat.ofFileName('a.dll'), isNull);
    });
  });
}
