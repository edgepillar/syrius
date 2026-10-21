// Harness entrypoint: the real app (lib/main.dart, unchanged) with the agent
// beside it. Build it with `harness/h build`, never ship it.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/utils/motion_binding.dart';

import 'agent.dart';

const String _protocolKey = r'HKCU\Software\Classes\syrius';

Future<void> main() async {
  final Map<String, String> env = Platform.environment;
  final String? home = env['SYRIUS_HARNESS_HOME'];
  final String? appData = env['AppData'];
  final int? port = int.tryParse(env['SYRIUS_HARNESS_PORT'] ?? '');
  final String? token = env['SYRIUS_HARNESS_TOKEN'];

  // The SDK keeps wallets under %AppData%\znn. Started by hand, this binary
  // would open the machine's real wallets with a remote control attached, so
  // it runs only when the launcher has pointed AppData into a harness home.
  if (home == null ||
      appData == null ||
      port == null ||
      token == null ||
      !path.isWithin(path.canonicalize(home), path.canonicalize(appData))) {
    stderr.writeln(
      'syrius harness: refusing to start outside a harness home. '
      'Use `harness/h start`.',
    );
    exit(64);
  }

  // The agent needs a binding before app.main() runs, and the first binding
  // created is the one the process keeps. A plain one here would switch the
  // app's own off, and the harness would then drive a wallet whose animations
  // shorten under reduced motion while the shipped one's do not.
  MotionBinding.ensureInitialized();
  await HarnessAgent.start(port: port, token: token);

  // app.main() registers this executable as the handler of syrius:// links.
  // Put back whatever was there, so the installed wallet keeps its links.
  final String? previous = _readProtocolCommand();
  try {
    await app.main();
  } finally {
    _restoreProtocolCommand(previous);
  }
  HarnessAgent.instance.booted = true;
}

String? _readProtocolCommand() {
  if (!Platform.isWindows) return null;
  final ProcessResult r = Process.runSync('reg', <String>[
    'query',
    '$_protocolKey\\shell\\open\\command',
    '/ve',
  ]);
  if (r.exitCode != 0) return null;
  final RegExpMatch? m = RegExp(
    r'REG_SZ\s+(.*)$',
    multiLine: true,
  ).firstMatch(r.stdout as String);
  return m?.group(1)?.trim();
}

void _restoreProtocolCommand(String? previous) {
  if (!Platform.isWindows) return;
  if (previous == null) {
    Process.runSync('reg', <String>['delete', _protocolKey, '/f']);
  } else {
    Process.runSync('reg', <String>[
      'add',
      '$_protocolKey\\shell\\open\\command',
      '/ve',
      '/d',
      previous,
      '/f',
    ]);
  }
}
