import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart' show Crypto;

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

String _hex(List<int> bytes) => bytes
    .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

/// Stands in for `DynamicLibrary.open` and the two lookups.
class _Opener {
  final List<String> opened = <String>[];
  final Set<String> failing = <String>{};

  void call(String libraryPath) {
    opened.add(libraryPath);
    if (failing.contains(libraryPath)) {
      throw ArgumentError('Failed to load dynamic library $libraryPath');
    }
  }
}

void main() {
  final DateTime clock = DateTime.utc(2026, 10, 13, 12);

  // Three builds of the node, and the one in the box.
  final Uint8List bundledBytes = _bytes(1);
  final Uint8List a = _bytes(2);
  final Uint8List b = _bytes(3, 5000);
  final Uint8List c = _bytes(4, 6000);

  late Directory temp;
  late Directory bundle;
  late String bundledPath;

  // The pids the stand-in for the system calls live. Empty unless a test
  // fills it, so every earlier wallet is gone: the system is never asked,
  // where 100 and 101 may well be somebody's process.
  late Set<int> running;

  NodeLibrary library({int processId = 100}) => NodeLibrary(
        directory: path.join(temp.path, 'profile', 'node'),
        bundledSearchPaths: <String>[
          path.join(temp.path, 'nowhere'),
          bundle.path,
        ],
        processId: processId,
        now: () => clock,
        isProcessRunning: (int pid) => running.contains(pid),
      );

  Map<String, dynamic> manifestJson(List<int> bytes, String tag) =>
      <String, dynamic>{
        'source': 'zenon-network/go-zenon',
        'tag': tag,
        'asset': NodeLibrary.libraryFileName,
        'sha256': _sha(bytes),
        'installedAt': '2026-10-01T00:00:00.000Z',
      };

  /// Writes a library and a manifest that vouches for [vouchedFor], which is
  /// the library itself unless the test wants them to disagree.
  void put(
    File libraryFile,
    File manifestFile,
    List<int> bytes,
    String tag, {
    List<int>? vouchedFor,
  }) {
    libraryFile.parent.createSync(recursive: true);
    libraryFile.writeAsBytesSync(bytes);
    manifestFile
        .writeAsStringSync(jsonEncode(manifestJson(vouchedFor ?? bytes, tag)));
  }

  void install(NodeLibrary lib, List<int> bytes, String tag) =>
      put(lib.overrideLibrary, lib.overrideManifest, bytes, tag);

  void stageByHand(
    NodeLibrary lib,
    List<int> bytes,
    String tag, {
    List<int>? vouchedFor,
  }) =>
      put(
        lib.stagedLibrary,
        lib.stagedManifest,
        bytes,
        tag,
        vouchedFor: vouchedFor,
      );

  Map<String, dynamic> readJson(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  setUp(() {
    running = <int>{};
    temp = Directory.systemTemp.createTempSync('node_library_test');
    bundle = Directory(path.join(temp.path, 'install'))..createSync();
    bundledPath = path.join(bundle.path, NodeLibrary.libraryFileName);
    File(bundledPath).writeAsBytesSync(bundledBytes);
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  group('Sha256', () {
    String ofText(String text) => _sha(ascii.encode(text));

    test('gives the FIPS 180-4 vectors', () {
      expect(
        ofText(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        ofText('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        ofText('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
      expect(
        ofText('a' * 1000000),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
      );
    });

    test('does not care how the bytes are cut', () {
      final Uint8List data = _bytes(9, 1000);
      for (final int piece in <int>[1, 7, 55, 56, 63, 64, 65, 129]) {
        final Sha256 digest = Sha256();
        for (int offset = 0; offset < data.length; offset += piece) {
          final int end =
              offset + piece < data.length ? offset + piece : data.length;
          digest.add(Uint8List.sublistView(data, offset, end));
        }
        expect(digest.close(), _sha(data), reason: 'pieces of $piece');
      }
    });

    test('agrees with the SDK at every padding length', () async {
      for (int length = 0; length <= 130; length++) {
        final Uint8List data = _bytes(length, length);
        expect(
          _sha(data),
          _hex(await Crypto.sha256Bytes(data)),
          reason: '$length bytes',
        );
      }
    });

    test('hashes a file longer than one read', () async {
      final Uint8List data = _bytes(11, (5 << 19) + 3);
      final File file = File(path.join(temp.path, 'big'))
        ..writeAsBytesSync(data);
      expect(
        NodeLibrary.sha256OfFile(file.path),
        _hex(await Crypto.sha256Bytes(data)),
      );
    });
  });

  group('promoteStaged', () {
    test('makes a good staged pair the override and keeps the old one', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');

      final PromotionResult result = lib.promoteStaged();

      expect(result.outcome, PromotionOutcome.promoted);
      expect(result.manifest!.tag, 'v2');
      expect(lib.overrideLibrary.readAsBytesSync(), b);
      expect(readJson(lib.overrideManifest)['tag'], 'v2');
      expect(lib.previousLibrary.readAsBytesSync(), a);
      expect(readJson(lib.previousManifest)['tag'], 'v1');
      expect(lib.stagedLibrary.existsSync(), isFalse);
      expect(lib.stagedManifest.existsSync(), isFalse);
    });

    test('promotes into an empty directory without inventing a prev', () {
      final NodeLibrary lib = library();
      stageByHand(lib, b, 'v2');

      expect(lib.promoteStaged().outcome, PromotionOutcome.promoted);
      expect(lib.overrideLibrary.readAsBytesSync(), b);
      expect(lib.previousLibrary.existsSync(), isFalse);
      expect(lib.previousManifest.existsSync(), isFalse);
    });

    test('discards a staged file with the wrong hash and says why', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      // What a truncated download looks like.
      stageByHand(lib, b.sublist(0, 3000), 'v2', vouchedFor: b);

      final PromotionResult result = lib.promoteStaged();

      expect(result.outcome, PromotionOutcome.discarded);
      expect(lib.stagedLibrary.existsSync(), isFalse);
      expect(lib.stagedManifest.existsSync(), isFalse);
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(readJson(lib.overrideManifest)['tag'], 'v1');
      expect(lib.previousLibrary.existsSync(), isFalse);
      final Map<String, dynamic> rejected = readJson(lib.stagedBadMarker);
      expect(rejected['sha256'], _sha(b.sublist(0, 3000)));
      expect(rejected['reason'], contains(_sha(b)));
      expect(rejected['cause'], 'mismatch');
      expect(rejected['at'], '2026-10-13T12:00:00.000Z');
    });

    test('discards a staged pair whose manifest cannot be read', () {
      final NodeLibrary lib = library();
      stageByHand(lib, b, 'v2');
      lib.stagedManifest.writeAsStringSync('{"sha256": ');

      expect(lib.promoteStaged().outcome, PromotionOutcome.discarded);
      expect(lib.stagedLibrary.existsSync(), isFalse);
      expect(lib.overrideLibrary.existsSync(), isFalse);
    });

    test('leaves a library that has no manifest yet', () {
      final NodeLibrary lib = library();
      stageByHand(lib, b, 'v2');
      lib.stagedManifest.deleteSync();

      expect(lib.promoteStaged().outcome, PromotionOutcome.nothingStaged);
      expect(lib.stagedLibrary.existsSync(), isTrue);
      expect(lib.overrideLibrary.existsSync(), isFalse);
    });

    test('does nothing when the directory does not exist', () {
      final NodeLibrary lib = library();

      expect(lib.promoteStaged().outcome, PromotionOutcome.nothingStaged);
      expect(Directory(lib.directory).existsSync(), isFalse);
    });

    test('finishes a promotion that died before its last rename', () {
      final NodeLibrary lib = library();
      // The library is in place, its manifest is still waiting.
      stageByHand(lib, b, 'v2');
      lib.stagedLibrary.renameSync(lib.overrideLibrary.path);
      expect(lib.resolve()!.kind, NodeLibraryKind.bundled);

      expect(lib.promoteStaged().outcome, PromotionOutcome.promoted);
      expect(lib.stagedManifest.existsSync(), isFalse);
      final ResolvedNodeLibrary resolved = lib.resolve()!;
      expect(resolved.kind, NodeLibraryKind.override);
      expect(resolved.manifest!.tag, 'v2');
    });

    test('drops a staged manifest that vouches for nothing on disk', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.stagedLibrary.deleteSync();

      expect(lib.promoteStaged().outcome, PromotionOutcome.nothingStaged);
      expect(lib.stagedManifest.existsSync(), isFalse);
      expect(readJson(lib.overrideManifest)['tag'], 'v1');
    });
  });

  group('resolve', () {
    test('is the bundled library when nothing is installed', () {
      final ResolvedNodeLibrary resolved = library().resolve()!;

      expect(resolved.kind, NodeLibraryKind.bundled);
      expect(resolved.path, bundledPath);
      expect(resolved.manifest, isNull);
      expect(resolved.refusal, isNull);
    });

    test('prefers a good override', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');

      final ResolvedNodeLibrary resolved = lib.resolve()!;

      expect(resolved.kind, NodeLibraryKind.override);
      expect(resolved.path, lib.overrideLibrary.path);
      expect(resolved.manifest!.tag, 'v1');
      expect(resolved.manifest!.sha256, _sha(a));
      expect(resolved.manifest!.source, 'zenon-network/go-zenon');
      expect(resolved.manifest!.installedAt, DateTime.utc(2026, 10));
    });

    test('refuses an override whose hash differs from its manifest', () {
      final NodeLibrary lib = library();
      put(lib.overrideLibrary, lib.overrideManifest, a, 'v1', vouchedFor: b);

      final ResolvedNodeLibrary resolved = lib.resolve()!;

      expect(resolved.kind, NodeLibraryKind.bundled);
      expect(resolved.path, bundledPath);
      expect(resolved.refusal, contains(_sha(a)));
      expect(resolved.refusal, contains(_sha(b)));
    });

    test('refuses an override that is marked bad', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.badMarker.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'sha256': _sha(a),
          'reason': 'failed to load: no RunNode',
          'at': '2026-10-12T00:00:00.000Z',
        }),
      );

      final ResolvedNodeLibrary resolved = lib.resolve()!;

      expect(resolved.kind, NodeLibraryKind.bundled);
      expect(resolved.refusal, contains('no RunNode'));
    });

    test('takes an override when the bad marker names another build', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.badMarker.writeAsStringSync(
        jsonEncode(<String, dynamic>{'sha256': _sha(b), 'reason': 'x'}),
      );

      expect(lib.resolve()!.kind, NodeLibraryKind.override);
    });

    test('refuses an override without a manifest', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.overrideManifest.deleteSync();

      final ResolvedNodeLibrary resolved = lib.resolve()!;

      expect(resolved.kind, NodeLibraryKind.bundled);
      expect(resolved.refusal, contains('manifest'));
    });

    test('takes the override when no bundled library exists', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      File(bundledPath).deleteSync();

      expect(lib.resolve()!.kind, NodeLibraryKind.override);
    });

    test('is null when there is nothing to load', () {
      File(bundledPath).deleteSync();

      expect(library().resolve(), isNull);
    });
  });

  group('load', () {
    test('opens the bundled library and records it', () {
      final NodeLibrary lib = library();
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded = lib.load(opener.call);

      expect(opener.opened, <String>[bundledPath]);
      expect(loaded.kind, NodeLibraryKind.bundled);
      final Map<String, dynamic> record = readJson(lib.loadedRecord);
      expect(record['kind'], 'bundled');
      expect(record['path'], bundledPath);
      expect(record['pid'], 100);
      expect(record['manifest'], isNull);
    });

    test('promotes what is staged, then opens it', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded = lib.load(opener.call);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(lib.overrideLibrary.readAsBytesSync(), b);
      expect(loaded.kind, NodeLibraryKind.override);
      expect(loaded.manifest!.tag, 'v2');
      expect(readJson(lib.loadedRecord)['kind'], 'override');
    });

    test('falls back to bundled when the override does not open', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      final _Opener opener = _Opener()..failing.add(lib.overrideLibrary.path);

      final LoadedNodeLibrary loaded = lib.load(opener.call);

      expect(
        opener.opened,
        <String>[lib.overrideLibrary.path, bundledPath],
      );
      expect(loaded.kind, NodeLibraryKind.bundled);
      expect(loaded.path, bundledPath);
      final Map<String, dynamic> bad = readJson(lib.badMarker);
      expect(bad['sha256'], _sha(a));
      expect(bad['reason'], contains('Failed to load dynamic library'));
      expect(bad['cause'], 'open');
      expect(bad['at'], '2026-10-13T12:00:00.000Z');
      expect(readJson(lib.loadedRecord)['kind'], 'bundled');
      // The override itself is left for the user to look at or roll back.
      expect(lib.overrideLibrary.existsSync(), isTrue);
      // It never started, so there is no start left to survive.
      expect(lib.startingMarker.existsSync(), isFalse);
    });

    test('does not try a bad override again on the next start', () {
      final NodeLibrary first = library();
      install(first, a, 'v1');
      first.load((_Opener()..failing.add(first.overrideLibrary.path)).call);

      final _Opener opener = _Opener();
      final LoadedNodeLibrary loaded =
          library(processId: 101).load(opener.call);

      expect(opener.opened, <String>[bundledPath]);
      expect(loaded.kind, NodeLibraryKind.bundled);
    });

    test('lets the error through when the bundled library fails', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      final _Opener opener = _Opener()
        ..failing.addAll(<String>[lib.overrideLibrary.path, bundledPath]);

      expect(() => lib.load(opener.call), throwsArgumentError);
      expect(lib.badMarker.existsSync(), isTrue);
      expect(lib.loadedRecord.existsSync(), isFalse);
    });

    test('throws when there is nothing to load', () {
      File(bundledPath).deleteSync();

      expect(
        () => library().load(_Opener().call),
        throwsA(isA<NodeLibraryNotFoundException>()),
      );
    });

    test('opens the same library again within one process', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.load(_Opener().call);
      // Staged while the node runs; the node's isolate is then restarted.
      stageByHand(lib, b, 'v2');

      final _Opener opener = _Opener();
      final LoadedNodeLibrary again = library().load(opener.call);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(again.manifest!.tag, 'v1');
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.stagedLibrary.existsSync(), isTrue);

      // The next run of the wallet is another process, and promotes.
      final LoadedNodeLibrary next =
          library(processId: 101).load(_Opener().call);
      expect(next.manifest!.tag, 'v2');
      expect(lib.overrideLibrary.readAsBytesSync(), b);
    });
  });

  group('load, in a process that already holds a library', () {
    final Matcher throwsHeld = throwsA(isA<NodeLibraryHeldException>());

    test('throws when the recorded library does not open again', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib
        ..load(_Opener().call)
        ..rollback();
      // Waiting for the next start. Resolving afresh would promote it.
      stageByHand(lib, b, 'v2');
      final Map<String, dynamic> record = readJson(lib.loadedRecord);
      final _Opener opener = _Opener()..failing.add(lib.overrideLibrary.path);

      expect(
        () => library().load(opener.call),
        throwsA(
          isA<NodeLibraryHeldException>()
              .having(
                (NodeLibraryHeldException e) => e.message,
                'message',
                contains(lib.overrideLibrary.path),
              )
              .having(
                (NodeLibraryHeldException e) => e.toString(),
                'toString',
                startsWith('NodeLibraryHeldException: '),
              ),
        ),
      );

      // One try at the library it holds and no other: not the bundled one,
      // which would be a second Go runtime, and not the staged one.
      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(lib.overrideLibrary.existsSync(), isFalse);
      expect(lib.stagedLibrary.readAsBytesSync(), b);
      expect(readJson(lib.stagedManifest)['tag'], 'v2');
      expect(readJson(lib.loadedRecord), record);
      // Nothing was learnt about any override.
      expect(lib.badMarker.existsSync(), isFalse);
      expect(readJson(lib.startingMarker)['failures'], 0);
    });

    test('throws when it is told it holds one and there is no record', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      expect(() => lib.load(opener.call, heldByProcess: true), throwsHeld);

      expect(opener.opened, isEmpty);
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.stagedLibrary.existsSync(), isTrue);
      expect(lib.loadedRecord.existsSync(), isFalse);
      expect(lib.startingMarker.existsSync(), isFalse);
    });

    test('does not take the record of another process for its own', () {
      final NodeLibrary lib = library();
      library(processId: 99).load(_Opener().call);
      final _Opener opener = _Opener();

      expect(() => lib.load(opener.call, heldByProcess: true), throwsHeld);

      expect(opener.opened, isEmpty);
      expect(readJson(lib.loadedRecord)['pid'], 99);
    });

    test('opens the library it holds again when told it holds one', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.load(_Opener().call, heldByProcess: false);
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      final LoadedNodeLibrary again =
          library().load(opener.call, heldByProcess: true);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(again.manifest!.tag, 'v1');
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.stagedLibrary.existsSync(), isTrue);
    });

    test('counts no failed start when it opens its library again', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.load(_Opener().call);
      final _Opener opener = _Opener();

      // The node's isolate, started three more times before a minute is up.
      for (int i = 0; i < 3; i++) {
        library().load(opener.call);
      }

      expect(opener.opened, List<String>.filled(3, lib.overrideLibrary.path));
      expect(readJson(lib.startingMarker)['failures'], 0);
      expect(lib.badMarker.existsSync(), isFalse);
    });
  });

  group('load, with a record left by a dead process of the same pid', () {
    test('passes it over when told this process holds nothing', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      // An earlier run of the wallet, ended in good order.
      lib
        ..load(_Opener().call)
        ..confirmStarted();
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded =
          library().load(opener.call, heldByProcess: false);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(loaded.manifest!.tag, 'v2');
      expect(lib.overrideLibrary.readAsBytesSync(), b);
      expect(lib.previousLibrary.readAsBytesSync(), a);
    });
  });

  group('load, the start-up guard', () {
    /// Loads as the process [processId] and never confirms: a wallet that
    /// did not survive the start.
    LoadedNodeLibrary start(int processId, [_Opener? opener]) =>
        library(processId: processId).load((opener ?? _Opener()).call);

    test('writes the marker before it opens an override', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      Map<String, dynamic>? atOpen;

      lib.load((String libraryPath) {
        atOpen = readJson(lib.startingMarker);
      });

      expect(atOpen, <String, dynamic>{
        'sha256': _sha(a),
        'pid': 100,
        'at': '2026-10-13T12:00:00.000Z',
        'failures': 0,
      });
      // Opening is not surviving: only confirmStarted takes it away.
      expect(readJson(lib.startingMarker), atOpen);
    });

    test('writes no marker for the bundled library', () {
      final NodeLibrary lib = library()..load(_Opener().call);

      expect(lib.startingMarker.existsSync(), isFalse);
    });

    test('counts one start not survived and loads the override again', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded = start(101, opener);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(loaded.kind, NodeLibraryKind.override);
      expect(readJson(lib.startingMarker), <String, dynamic>{
        'sha256': _sha(a),
        'pid': 101,
        'at': '2026-10-13T12:00:00.000Z',
        'failures': 1,
      });
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('marks the override bad after two and opens the bundled one', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      start(101);
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded = start(102, opener);

      // The override is not opened a third time.
      expect(opener.opened, <String>[bundledPath]);
      expect(loaded.kind, NodeLibraryKind.bundled);
      expect(loaded.path, bundledPath);
      expect(loaded.manifest, isNull);
      final Map<String, dynamic> bad = readJson(lib.badMarker);
      expect(bad['sha256'], _sha(a));
      expect(bad['cause'], 'start');
      expect(bad['reason'], contains('2 starts in a row'));
      expect(bad['at'], '2026-10-13T12:00:00.000Z');
      // Whatever it counted is in the bad marker now.
      expect(lib.startingMarker.existsSync(), isFalse);
      expect(readJson(lib.loadedRecord)['kind'], 'bundled');
      expect(lib.overrideLibrary.existsSync(), isTrue);

      // And it stays passed over.
      final _Opener next = _Opener();
      expect(start(103, next).kind, NodeLibraryKind.bundled);
      expect(next.opened, <String>[bundledPath]);
      expect(lib.startingMarker.existsSync(), isFalse);
    });

    test('confirmStarted clears the count', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      final NodeLibrary survivor = library(processId: 101)
        ..load(_Opener().call);
      expect(readJson(lib.startingMarker)['failures'], 1);

      survivor.confirmStarted();

      expect(lib.startingMarker.existsSync(), isFalse);
      // It takes two more in a row now, not one.
      start(102);
      expect(readJson(lib.startingMarker)['failures'], 0);
      final _Opener opener = _Opener();
      expect(start(103, opener).kind, NodeLibraryKind.override);
      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(readJson(lib.startingMarker)['failures'], 1);
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('confirmStarted leaves the marker of another process alone', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      final Map<String, dynamic> marker = readJson(lib.startingMarker);

      library(processId: 101).confirmStarted();

      expect(readJson(lib.startingMarker), marker);
    });

    test('confirmStarted is harmless when there is no marker', () {
      final NodeLibrary lib = library()..confirmStarted();

      expect(Directory(lib.directory).existsSync(), isFalse);
    });

    test('counts nothing for a wallet that is still starting', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      start(101);
      // A second wallet opened beside the first, which is alive.
      running.add(101);
      final _Opener opener = _Opener();

      expect(start(102, opener).kind, NodeLibraryKind.override);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      // The count it found, not one more.
      expect(readJson(lib.startingMarker)['failures'], 1);
      expect(readJson(lib.startingMarker)['pid'], 102);
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('takes a marker with its own pid, at a first load, for an earlier '
        'run', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      // The pid was given again, to this process, which is alive.
      running.add(100);
      final _Opener opener = _Opener();

      library().load(opener.call, heldByProcess: false);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(readJson(lib.startingMarker)['failures'], 1);

      expect(
        library().load(opener.call, heldByProcess: false).kind,
        NodeLibraryKind.bundled,
      );
      expect(readJson(lib.badMarker)['cause'], 'start');
    });

    test('counts nothing against another build', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      start(101);
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      final LoadedNodeLibrary loaded = start(102, opener);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(loaded.manifest!.tag, 'v2');
      expect(readJson(lib.startingMarker)['sha256'], _sha(b));
      expect(readJson(lib.startingMarker)['failures'], 0);
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('counts nothing from a marker it cannot read', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      final List<String> unreadable = <String>[
        '{"sha256": ',
        '[]',
        // No pid: nobody to ask about.
        jsonEncode(<String, dynamic>{'sha256': _sha(a), 'failures': 5}),
      ];
      for (int i = 0; i < unreadable.length; i++) {
        lib.startingMarker.writeAsStringSync(unreadable[i]);
        final _Opener opener = _Opener();

        // Another process each time: a second load by the same one would
        // open what it holds and never look at the marker.
        start(101 + i, opener);

        expect(opener.opened, <String>[lib.overrideLibrary.path]);
        expect(readJson(lib.startingMarker)['failures'], 0);
      }
    });

    test('reads a count that is not a positive number as none', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.startingMarker.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'sha256': _sha(a).toUpperCase(),
          'pid': 99,
          'failures': -3,
        }),
      );

      expect(start(101).kind, NodeLibraryKind.override);

      // None before, and the one that marker stands for.
      expect(readJson(lib.startingMarker)['failures'], 1);
    });

    test('goes ahead unguarded when the marker cannot be written', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      // A directory in the marker's place: nothing renames over it.
      Directory(lib.startingMarker.path).createSync();
      final _Opener opener = _Opener();

      for (final int processId in <int>[100, 101, 102]) {
        expect(start(processId, opener).kind, NodeLibraryKind.override);
      }

      expect(opener.opened, List<String>.filled(3, lib.overrideLibrary.path));
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('throws when the override is marked bad and nothing is bundled', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      start(101);
      File(bundledPath).deleteSync();
      final _Opener opener = _Opener();

      expect(
        () => start(102, opener),
        throwsA(isA<NodeLibraryNotFoundException>()),
      );

      expect(opener.opened, isEmpty);
      expect(readJson(lib.badMarker)['cause'], 'start');
    });

    test('keeps the count through a roll back', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      start(100);
      start(101);
      final Map<String, dynamic> marker = readJson(lib.startingMarker);
      expect(marker['failures'], 1);

      // A run on the bundled library in between says nothing about it.
      lib.rollback();
      expect(start(102).kind, NodeLibraryKind.bundled);
      expect(readJson(lib.startingMarker), marker);

      // The same build put back by hand, not staged: the count still
      // stands against it.
      install(lib, a, 'v1');
      final _Opener opener = _Opener();
      expect(start(103, opener).kind, NodeLibraryKind.bundled);
      expect(opener.opened, <String>[bundledPath]);
      expect(readJson(lib.badMarker)['cause'], 'start');
    });
  });

  group('rollback', () {
    test('removes the override and the staged pair, keeps prev', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.promoteStaged();
      stageByHand(lib, c, 'v3');

      lib.rollback();

      expect(lib.overrideLibrary.existsSync(), isFalse);
      expect(lib.overrideManifest.existsSync(), isFalse);
      expect(lib.stagedLibrary.existsSync(), isFalse);
      expect(lib.stagedManifest.existsSync(), isFalse);
      expect(lib.previousLibrary.readAsBytesSync(), a);
      expect(lib.resolve()!.kind, NodeLibraryKind.bundled);
      expect(lib.resolve()!.refusal, isNull);
      expect(lib.promoteStaged().outcome, PromotionOutcome.nothingStaged);
    });

    test('is harmless when nothing is installed', () {
      final NodeLibrary lib = library()..rollback();

      expect(lib.resolve()!.kind, NodeLibraryKind.bundled);
    });
  });

  group('restorePrevious', () {
    test('is false without a prev pair', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');

      expect(lib.restorePrevious(), isFalse);
      expect(lib.resolve()!.manifest!.tag, 'v1');
    });

    test('swaps the override with prev, and back', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.promoteStaged();

      expect(lib.restorePrevious(), isTrue);
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.previousLibrary.readAsBytesSync(), b);
      expect(readJson(lib.previousManifest)['tag'], 'v2');
      ResolvedNodeLibrary resolved = lib.resolve()!;
      expect(resolved.kind, NodeLibraryKind.override);
      expect(resolved.manifest!.tag, 'v1');

      expect(lib.restorePrevious(), isTrue);
      resolved = lib.resolve()!;
      expect(resolved.kind, NodeLibraryKind.override);
      expect(resolved.manifest!.tag, 'v2');
      expect(lib.previousLibrary.readAsBytesSync(), a);
    });

    test('restores after a rollback', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib
        ..promoteStaged()
        ..rollback();

      expect(lib.restorePrevious(), isTrue);
      expect(lib.resolve()!.manifest!.tag, 'v1');
      expect(lib.previousLibrary.existsSync(), isFalse);
      expect(lib.previousManifest.existsSync(), isFalse);
    });

    test('removes a staged pair, which would be promoted over it', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.promoteStaged();
      stageByHand(lib, c, 'v3');

      expect(lib.restorePrevious(), isTrue);
      expect(lib.stagedLibrary.existsSync(), isFalse);
      expect(lib.stagedManifest.existsSync(), isFalse);
      expect(library(processId: 101).load(_Opener().call).manifest!.tag, 'v1');
    });
  });

  group('stage', () {
    NodeLibraryManifest manifestOf(List<int> bytes, String tag) =>
        NodeLibraryManifest(
          source: 'file',
          asset: 'libznn-$tag${NodeLibrary.extension}',
          sha256: _sha(bytes).toUpperCase(),
          installedAt: clock,
        );

    File download(List<int> bytes) =>
        File(path.join(temp.path, 'download'))..writeAsBytesSync(bytes);

    test('copies a verified file into place with its manifest', () async {
      final NodeLibrary lib = library();

      await lib.stage(download(b), manifestOf(b, 'b'));

      expect(lib.stagedLibrary.readAsBytesSync(), b);
      expect(readJson(lib.stagedManifest), <String, dynamic>{
        'source': 'file',
        'tag': null,
        'asset': 'libznn-b${NodeLibrary.extension}',
        'sha256': _sha(b),
        'installedAt': '2026-10-13T12:00:00.000Z',
      });
      expect(
        Directory(lib.directory)
            .listSync()
            .map((FileSystemEntity entity) => path.basename(entity.path))
            .toSet(),
        <String>{'libznn.next${NodeLibrary.extension}', 'libznn.next.json'},
      );
      expect(lib.promoteStaged().outcome, PromotionOutcome.promoted);
      expect(lib.resolve()!.kind, NodeLibraryKind.override);
    });

    test('refuses a file that is not the one the manifest names', () async {
      final NodeLibrary lib = library();
      await lib.stage(download(a), manifestOf(a, 'a'));

      await expectLater(
        lib.stage(download(b.sublist(0, 100)), manifestOf(b, 'b')),
        throwsA(isA<NodeLibraryException>()),
      );

      // What was staged before is still there, whole.
      expect(lib.stagedLibrary.readAsBytesSync(), a);
      expect(readJson(lib.stagedManifest)['asset'], contains('libznn-a'));
      expect(Directory(lib.directory).listSync(), hasLength(2));
    });

    test('replaces what was staged before', () async {
      final NodeLibrary lib = library();
      await lib.stage(download(a), manifestOf(a, 'a'));
      await lib.stage(download(b), manifestOf(b, 'b'));

      expect(lib.stagedLibrary.readAsBytesSync(), b);
      expect(lib.promoteStaged().manifest!.sha256, _sha(b));
    });

    test('gives a build that was marked bad another try', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.load((_Opener()..failing.add(lib.overrideLibrary.path)).call);
      expect(lib.badMarker.existsSync(), isTrue);

      await lib.stage(download(b), manifestOf(b, 'b'));
      expect(lib.badMarker.existsSync(), isTrue);

      await lib.stage(download(a), manifestOf(a, 'a'));
      expect(lib.badMarker.existsSync(), isFalse);
    });

    test('gives a build the wallet did not survive another try', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      library().load(_Opener().call);
      library(processId: 101).load(_Opener().call);
      expect(readJson(lib.startingMarker)['failures'], 1);

      // Another build says nothing about this one's count.
      await lib.stage(download(b), manifestOf(b, 'b'));
      expect(readJson(lib.startingMarker)['failures'], 1);

      await lib.stage(download(a), manifestOf(a, 'a'));
      expect(lib.startingMarker.existsSync(), isFalse);

      // The next start promotes it and counts from nothing.
      final _Opener opener = _Opener();
      final LoadedNodeLibrary loaded =
          library(processId: 102).load(opener.call);
      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(loaded.kind, NodeLibraryKind.override);
      expect(readJson(lib.startingMarker)['failures'], 0);
    });

    test('gives a build the guard marked bad another try', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      for (final int processId in <int>[100, 101, 102]) {
        library(processId: processId).load(_Opener().call);
      }
      expect(readJson(lib.badMarker)['cause'], 'start');

      await lib.stage(download(a), manifestOf(a, 'a'));
      expect(lib.badMarker.existsSync(), isFalse);

      expect(
        library(processId: 103).load(_Opener().call).kind,
        NodeLibraryKind.override,
      );
    });
  });

  group('status', () {
    test('reports the bundled library before anything is installed', () async {
      final NodeLibraryStatus status = await library().status();

      expect(status.loaded, isNull);
      expect(status.next!.kind, NodeLibraryKind.bundled);
      expect(status.installed, isNull);
      expect(status.staged, isNull);
      expect(status.previous, isNull);
      expect(status.bad, isNull);
      expect(status.stagedRejected, isNull);
      expect(status.bundledPath, bundledPath);
      expect(status.bundledSha256, _sha(bundledBytes));
    });

    test('reports what is loaded, staged and kept', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.load(_Opener().call);
      stageByHand(lib, c, 'v3');

      final NodeLibraryStatus status = await lib.status();

      expect(status.loaded!.kind, NodeLibraryKind.override);
      expect(status.loaded!.manifest!.tag, 'v2');
      expect(status.loaded!.loadedAt, clock);
      expect(status.next!.kind, NodeLibraryKind.override);
      expect(status.next!.manifest!.tag, 'v2');
      expect(status.installed!.tag, 'v2');
      expect(status.staged!.tag, 'v3');
      expect(status.previous!.tag, 'v1');
      expect(status.bundledSha256, _sha(bundledBytes));
    });

    test('does not report another process as loaded', () async {
      library().load(_Opener().call);

      expect((await library(processId: 101).status()).loaded, isNull);
    });

    test('reports an override that failed to load', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      lib.load((_Opener()..failing.add(lib.overrideLibrary.path)).call);

      final NodeLibraryStatus status = await lib.status();

      expect(status.loaded!.kind, NodeLibraryKind.bundled);
      expect(status.bad!.sha256, _sha(a));
      expect(status.bad!.reason, contains('failed to load'));
      expect(status.bad!.cause, NodeLibraryBadCause.open);
      expect(status.installed!.tag, 'v1');
      expect(status.next!.kind, NodeLibraryKind.bundled);
      expect(status.next!.refusal, contains('marked bad'));
    });

    test('reports an override the wallet did not survive', () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      for (final int processId in <int>[100, 101, 102]) {
        library(processId: processId).load(_Opener().call);
      }

      final NodeLibraryStatus status =
          await library(processId: 102).status();

      expect(status.loaded!.kind, NodeLibraryKind.bundled);
      expect(status.bad!.sha256, _sha(a));
      expect(status.bad!.cause, NodeLibraryBadCause.start);
      expect(status.bad!.at, clock);
      expect(status.installed!.tag, 'v1');
      expect(status.next!.kind, NodeLibraryKind.bundled);
      expect(status.next!.refusal, contains('marked bad'));
    });

    test('reports a staged library that was thrown away', () async {
      final NodeLibrary lib = library();
      stageByHand(lib, b.sublist(0, 10), 'v2', vouchedFor: b);
      lib.promoteStaged();

      final NodeLibraryStatus status = await lib.status();

      expect(status.staged, isNull);
      expect(status.stagedRejected!.sha256, _sha(b.sublist(0, 10)));
      expect(status.next!.kind, NodeLibraryKind.bundled);
    });

    test('sees a rollback and a restore as what the next start loads',
        () async {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      stageByHand(lib, b, 'v2');
      lib.load(_Opener().call);

      lib.rollback();
      NodeLibraryStatus status = await lib.status();
      expect(status.loaded!.manifest!.tag, 'v2');
      expect(status.next!.kind, NodeLibraryKind.bundled);
      expect(status.installed, isNull);

      lib.restorePrevious();
      status = await lib.status();
      expect(status.loaded!.manifest!.tag, 'v2');
      expect(status.next!.manifest!.tag, 'v1');
    });
  });

  group('NodeLibraryBadMarker', () {
    NodeLibraryBadCause? causeOf(Object? cause) =>
        NodeLibraryBadMarker.fromJson(<String, dynamic>{
          'sha256': _sha(a),
          'reason': 'x',
          'at': '2026-10-12T00:00:00.000Z',
          'cause': ?cause,
        })?.cause;

    test('reads a marker written before there was a cause as a failed open',
        () {
      expect(causeOf(null), NodeLibraryBadCause.open);
    });

    test('reads every cause it writes', () {
      for (final NodeLibraryBadCause cause in NodeLibraryBadCause.values) {
        final NodeLibraryBadMarker marker = NodeLibraryBadMarker(
          sha256: _sha(a),
          reason: 'x',
          at: clock,
          cause: cause,
        );
        expect(marker.toJson()['cause'], cause.name);
        expect(NodeLibraryBadMarker.fromJson(marker.toJson())!.cause, cause);
      }
    });

    test('reads a cause it does not know as a failed open', () {
      expect(causeOf('panic'), NodeLibraryBadCause.open);
      expect(causeOf(7), NodeLibraryBadCause.open);
    });
  });

  // The one place the tests ask the system itself: everywhere else the
  // loader is given a stand-in.
  group('processIsRunning', () {
    test('is true for this process', () {
      expect(processIsRunning(pid), isTrue);
    });

    test('is false for what cannot be a pid', () {
      expect(processIsRunning(0), isFalse);
      expect(processIsRunning(-1), isFalse);
    });

    test('is true for a child that runs and false once it has ended',
        () async {
      // Something that waits a minute and is ours to end sooner.
      final Process child = Platform.isWindows
          ? await Process.start('ping', <String>['-n', '60', '127.0.0.1'])
          : await Process.start('sleep', <String>['60']);
      try {
        expect(processIsRunning(child.pid), isTrue);
      } finally {
        child.kill();
      }
      await child.exitCode;
      await Future.wait(<Future<void>>[
        child.stdout.drain<void>(),
        child.stderr.drain<void>(),
      ]);

      expect(processIsRunning(child.pid), isFalse);
    });
  });
}
