import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/embedded_node/node_library.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

ZnnSdkException invalidZnnLibPathException =
    ZnnSdkException('Library libznn could not be found');

typedef _StopNodeFunc = Pointer<Utf8> Function();
_StopNodeFunc? _stopNodeFunction;

typedef _RunNodeFunc = Pointer<Utf8> Function();
_RunNodeFunc? _runNodeFunction;

/// The loader this isolate loaded libznn through.
NodeLibrary? _nodeLibrary;

class EmbeddedNode {
  /// A name in the isolate name server, registered once this process has
  /// loaded a libznn and never removed.
  ///
  /// The node's isolate is started anew each time the user comes back to
  /// the embedded node, and remembers nothing. The name server is what
  /// every isolate of a process shares and a new process starts without,
  /// so it can say what `libznn.loaded.json` cannot: that the pid in that
  /// record is this run of the wallet and not an earlier one that was given
  /// the same number.
  static const String _heldPortName = 'embeddedNodeLibraryHeld';

  /// How long the process has to stay alive with an override loaded and the
  /// node running before the start counts as survived.
  ///
  /// libznn gives the wallet no sign of health. `RunNode` returns nothing
  /// once the node is started, go-zenon answers a node that cannot start
  /// with `os.Exit`, and a Go panic in any goroutine ends the whole process
  /// whenever it happens. So the sign is time: a library that kills the
  /// wallet at start does it well inside a minute.
  static const Duration _startSurvivedAfter = Duration(seconds: 60);

  /// Loads libznn: the override in the user's profile when there is a good
  /// one, the bundled library otherwise. [NodeLibrary] decides which, and
  /// falls back to the bundled one in this same call when the override does
  /// not open, so a bad override never keeps the wallet from starting.
  ///
  /// A process loads one libznn and keeps it. A second isolate of the same
  /// process gets that one again, or a [NodeLibraryHeldException] when it
  /// cannot be had: never another library beside the first.
  static void initializeNodeLib() =>
      loadThrough(NodeLibrary.forThisInstall(), _open);

  /// [initializeNodeLib], with the loader and the opener given. The wallet
  /// comes here from there alone. The tests come with a loader over a
  /// temporary directory and an opener that maps nothing, because the real
  /// pair reads the user's profile and puts a Go runtime into the process.
  @visibleForTesting
  static void loadThrough(NodeLibrary library, NodeLibraryOpener open) {
    final bool held = IsolateNameServer.lookupPortByName(_heldPortName) != null;
    try {
      library.load(open, heldByProcess: held);
    } on NodeLibraryNotFoundException {
      Logger('EmbeddedNode').log(Level.SEVERE, 'Could not load libznn');
      throw invalidZnnLibPathException;
    }
    _nodeLibrary = library;
    if (!held) {
      // Only the name is wanted. The mapping outlives the port, and the
      // isolate.
      final RawReceivePort port = RawReceivePort();
      IsolateNameServer.registerPortWithName(port.sendPort, _heldPortName);
      port.close();
    }
  }

  /// Tells the loader that the wallet survived starting the library, which
  /// clears the start-up guard's marker. See [_startSurvivedAfter].
  static void _confirmStarted() {
    (_nodeLibrary ?? NodeLibrary.forThisInstall()).confirmStarted();
  }

  /// Opens the library and takes both symbols before keeping either, so a
  /// library that lacks one leaves nothing of itself behind in the function
  /// pointers. It does stay mapped: a Go runtime cannot be unloaded, and
  /// closing the handle under its threads would crash the process.
  static void _open(String libraryPath) {
    final DynamicLibrary dylib = DynamicLibrary.open(libraryPath);

    final Pointer<NativeFunction<_StopNodeFunc>> stopNodeFunctionPointer =
        dylib.lookup<NativeFunction<_StopNodeFunc>>('StopNode');
    final Pointer<NativeFunction<_RunNodeFunc>> runNodeFunctionPointer =
        dylib.lookup<NativeFunction<_RunNodeFunc>>('RunNode');

    _stopNodeFunction =
        stopNodeFunctionPointer.asFunction<Pointer<Utf8> Function()>();
    _runNodeFunction =
        runNodeFunctionPointer.asFunction<Pointer<Utf8> Function()>();
  }

  static Future<void> runNode(List<String> args) => runNodeThrough(
        load: () {
          if (_runNodeFunction == null) {
            initializeNodeLib();
          }
        },
        run: () => _runNodeFunction!(),
        stop: () => _stopNodeFunction!(),
      );

  /// [runNode], with the library's part given: [load] sees to it that one
  /// is loaded, [run] and [stop] are its `RunNode` and `StopNode`. The
  /// wallet comes here from [runNode] alone. The tests come with stand-ins
  /// and a shorter [startSurvivedAfter], because the real three start a
  /// node.
  @visibleForTesting
  static Future<void> runNodeThrough({
    required void Function() load,
    required void Function() run,
    required void Function() stop,
    Duration startSurvivedAfter = _startSurvivedAfter,
  }) async {
    final ReceivePort commandsPort = ReceivePort();
    final SendPort sendPort = commandsPort.sendPort;

    final bool named =
        IsolateNameServer.registerPortWithName(sendPort, 'embeddedIsolate');

    try {
      load();
    } on Object {
      // No node runs, so there is none to stop. The name would outlive
      // this isolate, [stopNode] would go on answering that it had asked a
      // node to stop, and the wallet would wait at its close for an isolate
      // that is gone. Only a name this isolate registered is taken away: a
      // refused one is another isolate's.
      if (named) {
        IsolateNameServer.removePortNameMapping('embeddedIsolate');
      }
      commandsPort.close();
      rethrow;
    }
    run();

    // The start-up guard's sign that this start was survived: the process
    // is still here after a minute with the library loaded and the node
    // running, or the node was stopped in good order before that.
    final Timer startSurvived = Timer(startSurvivedAfter, _confirmStarted);

    final Completer embeddedIsolateCompleter = Completer();
    commandsPort.listen((event) {
      startSurvived.cancel();
      stop();
      // After StopNode has come back, not before: a library that takes the
      // process down while stopping has not been survived.
      _confirmStarted();
      IsolateNameServer.removePortNameMapping('embeddedIsolate');
      commandsPort.close();
      embeddedIsolateCompleter.complete();
    });
    await embeddedIsolateCompleter.future;
  }

  static void stopNodeIsolate() {
    if (_stopNodeFunction == null) {
      initializeNodeLib();
    }
    _stopNodeFunction!();
  }

  static bool stopNode() {
    final SendPort? embeddedIsolate =
        IsolateNameServer.lookupPortByName('embeddedIsolate');
    if (embeddedIsolate != null) {
      embeddedIsolate.send('stop');
      return true;
    }
    return false;
  }
}
