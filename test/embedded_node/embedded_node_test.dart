import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/embedded_node/embedded_node.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';

// The two names `embedded_node.dart` keeps in the isolate name server. The
// first is private there and written out here, so the test also holds the
// file to the name the documentation gives.
const String _heldName = 'embeddedNodeLibraryHeld';
const String _isolateName = 'embeddedIsolate';

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

/// What the node's isolate does with the name, in an isolate of its own.
void _registerAndLeave(String name) {
  final RawReceivePort port = RawReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, name);
  port.close();
}

bool _isRegistered(String name) =>
    IsolateNameServer.lookupPortByName(name) != null;

// Nothing here opens a library or starts a node. `initializeNodeLib` and
// `runNode` are never called: they read the user's own profile and map the
// real libznn. The tests go through `loadThrough` and `runNodeThrough`, the
// same code with a loader over a temporary directory and stand-ins for
// `RunNode` and `StopNode`.
void main() {
  final DateTime clock = DateTime.utc(2026, 10, 13, 12);
  final Uint8List a = _bytes(2);
  final Uint8List b = _bytes(3, 5000);

  late Directory temp;
  late String bundledPath;

  NodeLibrary library({int processId = 100}) => NodeLibrary(
        directory: path.join(temp.path, 'profile', 'node'),
        bundledSearchPaths: <String>[path.join(temp.path, 'install')],
        processId: processId,
        now: () => clock,
        // Every earlier wallet is gone, and the system is not asked.
        isProcessRunning: (int pid) => false,
      );

  void put(File libraryFile, File manifestFile, List<int> bytes, String tag) {
    libraryFile.parent.createSync(recursive: true);
    libraryFile.writeAsBytesSync(bytes);
    manifestFile.writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'source': 'zenon-network/go-zenon',
        'tag': tag,
        'asset': NodeLibrary.libraryFileName,
        'sha256': _sha(bytes),
        'installedAt': '2026-10-01T00:00:00.000Z',
      }),
    );
  }

  void install(NodeLibrary lib, List<int> bytes, String tag) =>
      put(lib.overrideLibrary, lib.overrideManifest, bytes, tag);

  void stageByHand(NodeLibrary lib, List<int> bytes, String tag) =>
      put(lib.stagedLibrary, lib.stagedManifest, bytes, tag);

  Map<String, dynamic> readJson(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  void forgetNames() {
    IsolateNameServer.removePortNameMapping(_heldName);
    IsolateNameServer.removePortNameMapping(_isolateName);
  }

  setUp(() {
    // The name server is the process's, so one test's names would be the
    // next one's: each starts as a new process does, with none.
    forgetNames();
    temp = Directory.systemTemp.createTempSync('embedded_node_test');
    final Directory bundle = Directory(path.join(temp.path, 'install'))
      ..createSync();
    bundledPath = path.join(bundle.path, NodeLibrary.libraryFileName);
    File(bundledPath).writeAsBytesSync(_bytes(1));
  });

  tearDown(() {
    forgetNames();
    temp.deleteSync(recursive: true);
  });

  // What the loader's `heldByProcess` rests on.
  group('the isolate name server', () {
    const String name = 'embeddedNodeTestName';

    tearDown(() => IsolateNameServer.removePortNameMapping(name));

    test('keeps a name after its port and its isolate are gone', () async {
      IsolateNameServer.removePortNameMapping(name);
      expect(_isRegistered(name), isFalse);

      await Isolate.run(() => _registerAndLeave(name));

      expect(_isRegistered(name), isTrue);
      // And a later isolate of the process sees it.
      expect(await Isolate.run(() => _isRegistered(name)), isTrue);
    });

    test('refuses a name that is taken', () {
      final RawReceivePort first = RawReceivePort();
      final RawReceivePort second = RawReceivePort();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(
        IsolateNameServer.registerPortWithName(first.sendPort, name),
        isTrue,
      );
      first.close();
      expect(
        IsolateNameServer.registerPortWithName(second.sendPort, name),
        isFalse,
      );
    });
  });

  group('loadThrough', () {
    test('at the first load of a process passes over the record of an '
        'earlier run with its pid, and registers the name', () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      // An earlier run of the wallet with this pid, ended in good order.
      lib
        ..load(_Opener().call)
        ..confirmStarted();
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();
      expect(_isRegistered(_heldName), isFalse);

      EmbeddedNode.loadThrough(library(), opener.call);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(lib.overrideLibrary.readAsBytesSync(), b);
      expect(lib.loadedInThisProcess()!.manifest!.tag, 'v2');
      expect(_isRegistered(_heldName), isTrue);
    });

    test('in a later isolate opens the same library and promotes nothing',
        () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      EmbeddedNode.loadThrough(lib, _Opener().call);
      // Staged while the node runs; the node's isolate is then restarted.
      stageByHand(lib, b, 'v2');
      final _Opener opener = _Opener();

      EmbeddedNode.loadThrough(library(), opener.call);

      expect(opener.opened, <String>[lib.overrideLibrary.path]);
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.stagedLibrary.existsSync(), isTrue);
      expect(lib.loadedInThisProcess()!.manifest!.tag, 'v1');
    });

    test('in a later isolate throws when the library it holds cannot be had',
        () {
      final NodeLibrary lib = library();
      install(lib, a, 'v1');
      EmbeddedNode.loadThrough(lib, _Opener().call);
      stageByHand(lib, b, 'v2');
      lib.loadedRecord.deleteSync();
      final _Opener opener = _Opener();

      expect(
        () => EmbeddedNode.loadThrough(library(), opener.call),
        throwsA(isA<NodeLibraryHeldException>()),
      );

      // Where a new process would have promoted v2 and opened it.
      expect(opener.opened, isEmpty);
      expect(lib.overrideLibrary.readAsBytesSync(), a);
      expect(lib.stagedLibrary.existsSync(), isTrue);
    });

    test('registers no name when there is nothing to load', () {
      File(bundledPath).deleteSync();

      expect(
        () => EmbeddedNode.loadThrough(library(), _Opener().call),
        throwsA(same(invalidZnnLibPathException)),
      );

      expect(_isRegistered(_heldName), isFalse);
    });

    test('registers no name when the bundled library does not open', () {
      final _Opener opener = _Opener()..failing.add(bundledPath);

      expect(
        () => EmbeddedNode.loadThrough(library(), opener.call),
        throwsArgumentError,
      );

      expect(_isRegistered(_heldName), isFalse);
    });
  });

  group('runNodeThrough', () {
    late NodeLibrary lib;
    late List<String> events;

    /// The node's isolate, with an override that one earlier wallet did not
    /// survive: the marker carries one failed start while this one runs.
    Future<void> runNode({Duration? startSurvivedAfter}) {
      lib = library();
      events = <String>[];
      install(lib, a, 'v1');
      library(processId: 99).load(_Opener().call);

      void load() => EmbeddedNode.loadThrough(lib, _Opener().call);
      void run() => events.add('run');
      void stop() => events.add(
            lib.startingMarker.existsSync()
                ? 'stop, the marker still there'
                : 'stop, the marker gone',
          );
      return startSurvivedAfter == null
          ? EmbeddedNode.runNodeThrough(load: load, run: run, stop: stop)
          : EmbeddedNode.runNodeThrough(
              load: load,
              run: run,
              stop: stop,
              startSurvivedAfter: startSurvivedAfter,
            );
    }

    test('an orderly stop clears the count, after StopNode has come back',
        () async {
      // The minute it would otherwise take is the real one: this test is
      // over long before, so what clears the marker is the stop.
      final Future<void> node = runNode();
      expect(events, <String>['run']);
      expect(readJson(lib.startingMarker)['failures'], 1);
      expect(readJson(lib.startingMarker)['pid'], 100);

      expect(EmbeddedNode.stopNode(), isTrue);
      await node;

      expect(events, <String>['run', 'stop, the marker still there']);
      expect(lib.startingMarker.existsSync(), isFalse);
      expect(_isRegistered(_isolateName), isFalse);
      // The next wallet starts the override with nothing counted.
      library(processId: 101).load(_Opener().call);
      expect(readJson(lib.startingMarker)['failures'], 0);
    });

    test('a node that has run for the time clears the count unasked',
        () async {
      final Future<void> node =
          runNode(startSurvivedAfter: const Duration(milliseconds: 50));
      expect(readJson(lib.startingMarker)['failures'], 1);

      // The time is real, so the test waits for the marker to go, not for
      // a fixed while that a busy machine would overrun.
      for (int i = 0; i < 200 && lib.startingMarker.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(lib.startingMarker.existsSync(), isFalse);
      // Nobody stopped it.
      expect(events, <String>['run']);

      expect(EmbeddedNode.stopNode(), isTrue);
      await node;
      expect(events, <String>['run', 'stop, the marker gone']);
    });

    test('leaves no name behind when the library cannot be loaded', () async {
      lib = library();
      events = <String>[];
      install(lib, a, 'v1');
      // A later isolate of a process whose record is gone.
      EmbeddedNode.loadThrough(lib, _Opener().call);
      lib.loadedRecord.deleteSync();

      await expectLater(
        EmbeddedNode.runNodeThrough(
          load: () => EmbeddedNode.loadThrough(library(), _Opener().call),
          run: () => events.add('run'),
          stop: () => events.add('stop'),
        ),
        throwsA(isA<NodeLibraryHeldException>()),
      );

      expect(events, isEmpty);
      // No node, so nothing to ask to stop. With the name left behind the
      // wallet would wait at its close for an isolate that has gone.
      expect(EmbeddedNode.stopNode(), isFalse);
    });

    test('leaves the name of a node in another isolate alone', () async {
      events = <String>[];
      // Stands in for the port of a node's isolate that is running.
      final ReceivePort other = ReceivePort();
      addTearDown(other.close);
      IsolateNameServer.registerPortWithName(other.sendPort, _isolateName);
      File(bundledPath).deleteSync();

      await expectLater(
        EmbeddedNode.runNodeThrough(
          load: () => EmbeddedNode.loadThrough(library(), _Opener().call),
          run: () => events.add('run'),
          stop: () => events.add('stop'),
        ),
        throwsA(same(invalidZnnLibPathException)),
      );

      expect(events, isEmpty);
      // The stop still reaches the node that runs.
      expect(EmbeddedNode.stopNode(), isTrue);
      expect(await other.first, 'stop');
    });
  });
}
