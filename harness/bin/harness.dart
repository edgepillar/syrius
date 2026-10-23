// The outside half of the harness: builds and launches the harnessed wallet
// in a profile of its own, and sends it commands. Plain Dart, no packages.
//
//   dart harness/bin/harness.dart <command> [arguments] [--flags]
//
// See harness/README.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../app/fixtures/seed_policy.dart';
import '../app/presentation_mode.dart';
import '../seed/seed_recipe.dart';
import 'screen_capture.dart';

final String repo = File.fromUri(Platform.script).parent.parent.parent.path;
final String stateRoot = '$repo${Platform.pathSeparator}.harness';

class Fail implements Exception {
  Fail(this.message);
  final String message;
  @override
  String toString() => message;
}

class Args {
  Args(List<String> raw) {
    for (int i = 0; i < raw.length; i++) {
      final String a = raw[i];
      if (a.startsWith('--') && a.length > 2) {
        final String name = a.substring(2);
        final int eq = name.indexOf('=');
        if (eq > 0) {
          flags[name.substring(0, eq)] = name.substring(eq + 1);
        } else if (_valued.contains(name) && i + 1 < raw.length) {
          flags[name] = raw[++i];
        } else {
          flags[name] = 'true';
        }
      } else {
        rest.add(a);
      }
    }
  }

  static const Set<String> _valued = <String>{
    'instance',
    'mode',
    'port',
    'kind',
    'nth',
    'type',
    'key',
    'timeout',
    'min',
    'out',
    'settle',
    'since',
    'limit',
    'levels',
    'password',
    'mnemonic',
    'node',
    'chain',
    'width',
    'height',
    'dir',
    'tab',
    'max',
    'ws',
    'http',
    'counterparty',
    'presentation',
  };

  final Map<String, String> flags = <String, String>{};
  final List<String> rest = <String>[];

  bool has(String f) => flags.containsKey(f);
  String? operator [](String f) => flags[f];
  int? integer(String f) => flags[f] == null ? null : int.parse(flags[f]!);
}

class Instance {
  Instance(this.name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(name)) {
      throw Fail('instance names contain only letters, digits, _ and -');
    }
  }

  final String name;

  String get home => '$stateRoot${Platform.pathSeparator}$name';
  File get file => File('$home${Platform.pathSeparator}instance.json');

  Map<String, dynamic>? read() => file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : null;

  Future<Map<String, dynamic>> send(
    Map<String, Object?> cmd, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final Map<String, dynamic>? info = read();
    if (info == null) {
      throw Fail('instance "$name" was never started; run `start`');
    }
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final HttpClientRequest req = await client.post(
        '127.0.0.1',
        info['port'] as int,
        '/',
      );
      req.headers
        ..set('x-harness-token', info['token'] as String)
        ..contentType = ContentType.json;
      req.write(jsonEncode(cmd));
      final HttpClientResponse res = await req.close().timeout(timeout);
      final String body = await utf8.decoder.bind(res).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } on SocketException {
      throw Fail('instance "$name" is not running; run `start`');
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> alive() async {
    if (read() == null) return false;
    try {
      return (await send(<String, Object?>{
            'cmd': 'ping',
          }, timeout: const Duration(seconds: 3)))['ok'] ==
          true;
    } on Object catch (_) {
      return false;
    }
  }
}

// ------------------------------------------------------------------ selectors

/// `12` or `#12` is a ref from the last tree, `@x,y` a point, anything else
/// text. `--key`, `--type`, `--kind`, `--nth` and `--exact` narrow it.
Map<String, Object?> selector(String? s, Args a) {
  final Map<String, Object?> sel = <String, Object?>{};
  if (s != null && s.isNotEmpty) {
    final RegExpMatch? ref = RegExp(r'^#?(\d+)$').firstMatch(s);
    final RegExpMatch? at = RegExp(r'^@(-?\d+),(-?\d+)$').firstMatch(s);
    if (ref != null) {
      sel['ref'] = int.parse(ref.group(1)!);
    } else if (at != null) {
      sel['at'] = <int>[int.parse(at.group(1)!), int.parse(at.group(2)!)];
    } else {
      sel['text'] = s;
    }
  }
  if (a.has('key')) sel['key'] = a['key'];
  if (a.has('type')) sel['type'] = a['type'];
  if (a.has('kind')) sel['kind'] = a['kind'];
  if (a.has('tab')) sel['tab'] = a['tab'];
  if (a.has('nth')) sel['nth'] = a.integer('nth');
  if (a.has('exact')) sel['exact'] = true;
  if (a.has('force')) sel['force'] = true;
  if (a.has('settle')) sel['settleMs'] = a.integer('settle');
  return sel;
}

String describe(Map<String, dynamic> n) {
  final StringBuffer b = StringBuffer()
    ..write('[${n['ref']}]'.padRight(6))
    ..write((n['kind'] as String).padRight(9));
  String label = (n['label'] as String? ?? '').replaceAll('\n', ' ');
  if (label.length > 110) label = '${label.substring(0, 107)}...';
  if (label.isNotEmpty) b.write('"$label" ');
  for (final String k in <String>[
    'tab',
    'value',
    'hint',
    'labelText',
    'error',
    'tip',
    'checked',
    'icons',
    'key',
  ]) {
    if (n[k] != null) b.write('$k=${jsonEncode(n[k])} ');
  }
  for (final String k in <String>['obscured', 'focused']) {
    if (n[k] == true) b.write('$k ');
  }
  if (n['enabled'] == false) b.write('DISABLED ');
  final List<num> r = (n['rect'] as List<dynamic>).cast<num>();
  final List<dynamic> path = n['path'] as List<dynamic>? ?? <dynamic>[];
  final String where = path.isEmpty || path.last == n['type']
      ? '${n['type']}'
      : '${path.last}>${n['type']}';
  b.write(' $where @${r[0] + r[2] ~/ 2},${r[1] + r[3] ~/ 2}');
  return b.toString();
}

void printTree(Map<String, dynamic> t) {
  final List<dynamic> size = t['size'] as List<dynamic>;
  stdout.writeln('view ${size[0]}x${size[1]}');
  for (final dynamic n in t['nodes'] as List<dynamic>) {
    stdout.writeln(describe(n as Map<String, dynamic>));
  }
}

// ------------------------------------------------------------------- commands

Future<void> build(Args a) async {
  final String mode = a['mode'] ?? 'release';
  final Process p = await Process.start(
    'flutter',
    <String>['build', 'windows', '--$mode', '-t', 'harness/app/main.dart'],
    workingDirectory: repo,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await p.exitCode != 0) throw Fail('flutter build failed');
  final String cap = mode[0].toUpperCase() + mode.substring(1);
  final Directory from = Directory('$repo/build/windows/x64/runner/$cap');
  final Directory to = Directory('$stateRoot/app/$mode');
  // A copy of its own: the next ordinary `flutter build` overwrites build/.
  // What is in it goes, not the folder: Windows refuses to delete a folder
  // another process still holds open (a shell left standing in it), and
  // that failed a build whose compile had succeeded.
  if (to.existsSync()) {
    for (final FileSystemEntity old in to.listSync()) {
      old.deleteSync(recursive: true);
    }
  }
  int files = 0;
  for (final FileSystemEntity e in from.listSync(recursive: true)) {
    final String rel = e.path.substring(from.path.length);
    if (e is Directory) {
      Directory('${to.path}$rel').createSync(recursive: true);
    } else if (e is File) {
      File('${to.path}$rel').parent.createSync(recursive: true);
      e.copySync('${to.path}$rel');
      files++;
    }
  }
  stdout.writeln('built $mode: ${to.path} ($files files)');
}

Future<int> freePort() async {
  final ServerSocket s = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final int port = s.port;
  await s.close();
  return port;
}

Future<void> start(Instance inst, Args a) async {
  final String? presentation = harnessPresentationSurface(a['presentation']);
  if (presentation != null && (inst.name == 'default' || a.has('fresh'))) {
    throw Fail('presentation needs an explicit unused instance, without fresh');
  }
  if (await inst.alive()) {
    final Map<String, dynamic> observed = await call(
      inst,
      <String, Object?>{'cmd': 'ping'},
    );
    final Object? expectedPid = inst.read()?['pid'];
    if (expectedPid is! int ||
        !harnessLaunchMatches(
          observed,
          presentation: presentation,
          expectedPid: expectedPid,
        )) {
      throw Fail('the instance is already running another harness host');
    }
    stdout.writeln('instance "${inst.name}" is already running');
    return;
  }
  if (presentation != null) {
    final FileSystemEntityType parent = FileSystemEntity.typeSync(
      stateRoot,
      followLinks: false,
    );
    if ((parent != FileSystemEntityType.directory &&
            parent != FileSystemEntityType.notFound) ||
        FileSystemEntity.typeSync(inst.home, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw Fail('presentation needs an unused profile without links');
    }
  }
  final String mode = a['mode'] ?? 'release';
  final File exe = File('$stateRoot/app/$mode/syrius.exe');
  if (!exe.existsSync()) {
    throw Fail('no $mode build of the harness; run `build` first');
  }
  // The Windows runner looks for a window titled "s y r i u s" and, finding
  // one, hands over and exits: one wallet per desktop, harnessed or not.
  final ProcessResult running = Process.runSync('tasklist', <String>[
    '/fi',
    'imagename eq syrius.exe',
    '/fo',
    'csv',
    '/nh',
  ]);
  if ((running.stdout as String).toLowerCase().contains('syrius.exe')) {
    throw Fail(
      'a syrius.exe is already running; Syrius is single-instance, close it '
      'first\n${(running.stdout as String).trim()}',
    );
  }
  final Directory home = Directory(inst.home);
  if (a.has('fresh') && home.existsSync()) home.deleteSync(recursive: true);
  final String sep = Platform.pathSeparator;
  final String roaming = '${home.path}${sep}AppData${sep}Roaming';
  final String local = '${home.path}${sep}AppData${sep}Local';
  final String temp = '${home.path}${sep}Temp';
  for (final String d in <String>[roaming, local, temp]) {
    Directory(d).createSync(recursive: true);
  }
  final int port = a.integer('port') ?? await freePort();
  final Random rnd = Random.secure();
  final String token = List<String>.generate(
    16,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  // Every place the wallet, its SDK and its embedded node look for a profile
  // goes into the instance home; nothing reads the real %AppData%\znn.
  final Map<String, String> env = harnessLaunchEnvironment(
    Platform.environment,
    profileHome: home.path,
    appData: roaming,
    localAppData: local,
    temporary: temp,
    port: port,
    token: token,
    presentation: presentation,
  );
  final Process p = await Process.start(
    exe.path,
    <String>[],
    environment: env,
    includeParentEnvironment: false,
    workingDirectory: exe.parent.path,
    mode: ProcessStartMode.detached,
  );
  inst.file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'pid': p.pid,
      'port': port,
      'token': token,
      'mode': mode,
      'harnessMode': presentation == null ? 'wallet' : 'presentation',
      'presentationScreen': ?presentation,
      'started': DateTime.now().toUtc().toIso8601String(),
    }),
  );
  final Stopwatch sw = Stopwatch()..start();
  while (sw.elapsed < const Duration(seconds: 60)) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final Map<String, dynamic> r;
    try {
      r = await inst.send(<String, Object?>{
        'cmd': 'ping',
      }, timeout: const Duration(seconds: 3));
    } on Fail {
      // Not listening yet.
      continue;
    }
    if (r['booted'] == true) {
      if (!harnessLaunchMatches(
        r,
        presentation: presentation,
        expectedPid: p.pid,
      )) {
        throw Fail('the original process and harness host were not observed');
      }
      stdout.writeln(
        'started "${inst.name}": pid ${p.pid}, port $port, home ${home.path}',
      );
      return;
    }
  }
  throw Fail('the wallet did not come up within 60 s (pid ${p.pid})');
}

bool pidAlive(int pid) =>
    (Process.runSync('tasklist', <String>[
              '/fi',
              'pid eq $pid',
              '/fo',
              'csv',
              '/nh',
            ]).stdout
            as String)
        .contains('"$pid"');

Future<void> stop(Instance inst) async {
  final Map<String, dynamic>? info = inst.read();
  if (info == null) throw Fail('instance "${inst.name}" was never started');
  final int pid = info['pid'] as int;
  if (!pidAlive(pid)) {
    stdout.writeln('not running');
    return;
  }
  try {
    await inst.send(<String, Object?>{'cmd': 'quit'});
  } on Fail {
    // Fall through to the kill.
  }
  final Stopwatch sw = Stopwatch()..start();
  while (sw.elapsed < const Duration(seconds: 12)) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!pidAlive(pid)) {
      stdout.writeln('stopped');
      return;
    }
  }
  Process.runSync('taskkill', <String>['/pid', '$pid', '/f', '/t']);
  stdout.writeln('killed (the wallet did not exit on its own)');
}

/// Sends one command and returns the reply, throwing on `ok: false`.
Future<Map<String, dynamic>> call(
  Instance inst,
  Map<String, Object?> cmd,
) async {
  final Map<String, dynamic> r = await inst.send(cmd);
  if (r['ok'] != true) {
    final Object? detail = r['detail'];
    throw Fail(
      '${cmd['cmd']}: ${r['error']}'
      '${detail == null ? '' : ' ${jsonEncode(detail)}'}'
      '${r['stack'] == null ? '' : '\n${r['stack']}'}',
    );
  }
  return r;
}

void report(Map<String, dynamic> r, Args a, {String? note}) {
  if (a.has('json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(r));
    return;
  }
  final Map<String, dynamic>? t = r['target'] as Map<String, dynamic>?;
  stdout.writeln(
    <String>[
      'ok',
      ?note,
      if (t != null) describe(t),
    ].join('  '),
  );
}

Map<String, Object?> assertionArgs(Args a) {
  const Set<String> allowed = <String>{
    'key',
    'type',
    'kind',
    'tab',
    'nth',
    'exact',
  };
  if (a.rest.length > 1 ||
      a.flags.keys.any((String f) => !allowed.contains(f))) {
    throw Fail(
      'assert <selector> [--key <key>] uses a stable positive selector',
    );
  }
  final Map<String, Object?> sel = selector(
    a.rest.isEmpty ? null : a.rest.first,
    a,
  );
  if (sel.containsKey('at') ||
      sel.containsKey('ref') ||
      !<String>['text', 'key', 'type', 'tab'].any(sel.containsKey) ||
      (a.integer('nth') ?? 0) < 0) {
    throw Fail(
      'assert needs text, key, type or tab; coordinates and refs expire',
    );
  }
  return <String, Object?>{...sel, 'exact': true};
}

Future<void> run(Instance inst, String command, Args a) async {
  final List<String> r = a.rest;
  String? arg(int i) => i < r.length ? r[i] : null;

  switch (command) {
    case 'build':
      await build(a);
    case 'start':
      await start(inst, a);
    case 'stop':
      await stop(inst);
    case 'status':
      final bool up = await inst.alive();
      stdout.writeln(up ? 'running' : 'stopped');
      if (up) {
        stdout.writeln(
          const JsonEncoder.withIndent(
            '  ',
          ).convert(await call(inst, <String, Object?>{'cmd': 'state'})),
        );
      }
    case 'state':
      stdout.writeln(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(await call(inst, <String, Object?>{'cmd': 'state'})),
      );
    case 'tree':
      final Map<String, dynamic> t = await call(inst, <String, Object?>{
        'cmd': 'tree',
        if (a.has('kind')) 'kind': a['kind'],
      });
      if (a.has('json')) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(t));
      } else {
        printTree(t);
      }
    case 'tap':
    case 'hover':
      report(
        await call(inst, <String, Object?>{
          'cmd': command,
          ...selector(arg(0), a),
          for (final String f in <String>['right', 'long', 'double'])
            if (a.has(f)) f: true,
        }),
        a,
      );
    case 'type':
      // `type <selector> <text>`, or `type <text>` into the focused field.
      final bool aimed = r.length >= 2 || a.has('key') || a.has('type');
      final Map<String, dynamic> out = await call(inst, <String, Object?>{
        'cmd': 'type',
        ...selector(aimed && r.length >= 2 ? r[0] : null, a),
        'value': r.isEmpty ? '' : r.last,
        if (a.has('append')) 'append': true,
        if (a.has('submit')) 'submit': true,
      });
      report(out, a, note: 'value=${jsonEncode(out['value'])}');
    case 'key':
      final Map<String, dynamic> out = await call(inst, <String, Object?>{
        'cmd': 'key',
        'key': arg(0) ?? (throw Fail('key <chord>, e.g. enter, shift+tab')),
        if (a.has('settle')) 'settleMs': a.integer('settle'),
      });
      report(out, a, note: out['handled'] == true ? 'handled' : 'unhandled');
    case 'scroll':
      // `scroll <dy>` at the centre, or `scroll <selector> <dy>`.
      report(
        await call(inst, <String, Object?>{
          'cmd': 'scroll',
          ...selector(r.length >= 2 ? r[0] : null, a),
          'dy': num.parse(r.isEmpty ? '300' : r.last),
        }),
        a,
      );
    case 'drag':
      final List<String> by =
          (arg(1) ?? (throw Fail('drag <selector> <dx,dy>'))).split(',');
      report(
        await call(inst, <String, Object?>{
          'cmd': 'drag',
          ...selector(arg(0), a),
          'by': <num>[num.parse(by[0]), num.parse(by[1])],
        }),
        a,
      );
    case 'drop':
      final String file = arg(1) ?? (throw Fail('drop <selector> <file>'));
      report(
        await call(inst, <String, Object?>{
          'cmd': 'drop',
          ...selector(arg(0), a),
          'path': File(file).absolute.path,
        }),
        a,
      );
    case 'wait':
      final Map<String, dynamic> out = await call(inst, <String, Object?>{
        'cmd': 'wait',
        ...selector(arg(0), a),
        if (a.has('gone')) 'gone': true,
        if (a.has('timeout'))
          'timeoutMs': (num.parse(a['timeout']!) * 1000).round(),
      });
      report(out, a, note: '${out['ms']} ms');
    case 'assert':
      report(
        await call(inst, <String, Object?>{
          'cmd': 'assert',
          ...assertionArgs(a),
        }),
        a,
      );
    case 'theme':
      if (r.length != 1 || (r.first != 'dark' && r.first != 'light')) {
        throw Fail('theme dark|light');
      }
      stdout.writeln(
        jsonEncode(
          await call(inst, <String, Object?>{
            'cmd': 'theme',
            'mode': r.first,
          }),
        ),
      );
    case 'presentation':
      if (r.length != 1 ||
          a.flags.keys.any(
            (String flag) => !<String>{'instance', 'json'}.contains(flag),
          )) {
        throw Fail('presentation <surface> [--instance <name>]');
      }
      final String surface = harnessPresentationSurface(r.single)!;
      stdout.writeln(
        jsonEncode(
          await call(inst, <String, Object?>{
            'cmd': 'presentation',
            'surface': surface,
          }),
        ),
      );
    case 'screens':
      if (r.length != 1 ||
          a.flags.keys.any(
            (String f) => !<String>{'instance', 'dir', 'json'}.contains(f),
          )) {
        throw Fail('screens <id>|all [--dir .harness/<fresh-directory>]');
      }
      if ((await stateOf(inst))['harnessMode'] == 'presentation') {
        throw Fail('presentation previews cannot create wallet capture proof');
      }
      final List<String> paths = await ScreenCapture(
        repository: Directory(repo),
        call: (Map<String, Object?> command) => call(inst, command),
        prepareHome: () => prepareScreenHome(inst),
        runLine: (List<String> words) =>
            run(inst, words.first, Args(words.sublist(1))),
        assertionFor: (List<String> words) =>
            assertionArgs(Args(words.sublist(1))),
        readRailState: () => screenRailExpanded(inst),
        restoreRailState: ({required bool expanded}) =>
            restoreScreenRail(inst, expanded: expanded),
      ).capture(r.first, directory: a['dir']);
      if (a.has('json')) {
        stdout.writeln(
          jsonEncode(<String, Object?>{
            'captures': paths,
            'client': <int>[1280, 780],
            'scale': 1,
          }),
        );
      } else {
        for (final String path in paths) {
          stdout.writeln('$path  1280x780 (logical scale 1)');
        }
      }
    case 'shot':
      final Map<String, dynamic> s = await call(inst, <String, Object?>{
        'cmd': 'shot',
      });
      final String out =
          a['out'] ??
          '${inst.home}${Platform.pathSeparator}shots${Platform.pathSeparator}'
              '${DateTime.now().millisecondsSinceEpoch}.png';
      File(out)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(base64Decode(s['png'] as String));
      stdout.writeln(
        '$out  ${s['width']}x${s['height']} (scale ${s['scale']})',
      );
    case 'logs':
      final Map<String, dynamic> out = await call(inst, <String, Object?>{
        'cmd': 'logs',
        if (a.has('since')) 'since': a.integer('since'),
        if (a.has('limit')) 'limit': a.integer('limit'),
        if (a.has('levels')) 'levels': a['levels']!.split(','),
      });
      if (a.has('json')) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
      } else {
        for (final Map<String, dynamic> l
            in (out['logs'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          stdout.writeln(
            '${l['seq']} ${l['time']} ${l['level']} ${l['logger']}: '
            '${l['message']}${l['error'] == null ? '' : ' | ${l['error']}'}',
          );
        }
        stdout.writeln('seq ${out['seq']}');
      }
    case 'stalls':
      final Map<String, dynamic> out = await call(inst, <String, Object?>{
        'cmd': 'stalls',
        if (a.has('reset')) 'reset': true,
        if (a.has('min')) 'min': a.integer('min'),
      });
      if (a.has('brief')) {
        stdout.writeln(
          <String>[
            for (final Map<String, dynamic> s
                in (out['stalls'] as List<dynamic>)
                    .cast<Map<String, dynamic>>())
              '${s['kind']} ${s['ms']}',
          ].join(', '),
        );
      } else {
        for (final Map<String, dynamic> s
            in (out['stalls'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          stdout.writeln('${s['time']} ${s['kind']} ${s['ms']} ms');
        }
      }
      stdout.writeln('longest ${out['longestMs']} ms');
    case 'clipboard':
      stdout.writeln(
        (await call(inst, <String, Object?>{
          'cmd': 'clipboard',
          if (arg(0) != null) 'value': arg(0),
        }))['text'],
      );
    case 'window':
      stdout.writeln(
        jsonEncode(
          await call(inst, <String, Object?>{
            'cmd': 'window',
            if (arg(0) != null) 'do': arg(0),
            if (a.has('width')) 'width': a.integer('width'),
            if (a.has('height')) 'height': a.integer('height'),
          }),
        ),
      );
    case 'run':
      await script(inst, arg(0) ?? (throw Fail('run <file>')), a);
    case 'seed':
      await seed(inst, a);
    default:
      if (!await recipe(inst, command, a)) {
        throw Fail('unknown command "$command"; see harness/README.md');
      }
  }
  if (a.has('tree') && command != 'tree') {
    printTree(await call(inst, <String, Object?>{'cmd': 'tree'}));
  }
}

/// A fixed, preflighted source recipe; no nested script or lifecycle command.
Future<void> seed(Instance inst, Args a) async {
  const Set<String> allowed = <String>{
    'instance',
    'ws',
    'http',
    'counterparty',
    'checkpoint-ready',
    'json',
  };
  if (!a.has('instance') ||
      inst.name == 'default' ||
      a['ws'] != seedWsOrigin ||
      a['http'] != seedHttpOrigin ||
      a.flags.keys.any((String flag) => !allowed.contains(flag)) ||
      a.rest.isEmpty) {
    throw Fail(
      'seed requires an explicit nondefault --instance and exact --ws/--http '
      'lab origins; see harness/seed/README.md',
    );
  }
  Future<Map<String, dynamic>> command(Map<String, Object?> fields) async {
    final Map<String, dynamic> result = await inst
        .send(<String, Object?>{
          'cmd': 'seed',
          ...fields,
        }, timeout: const Duration(seconds: 300))
        .timeout(const Duration(seconds: 305));
    if (result['ok'] != true) throw Fail('seed refused: ${result['error']}');
    return result;
  }

  if (a.rest.first == 'fixture') {
    if (a.rest.length != 2 ||
        !<String>{'sentinel', 'aged-fuse'}.contains(a.rest[1])) {
      throw Fail('seed fixture sentinel|aged-fuse');
    }
    stdout.writeln(
      jsonEncode(
        await command(<String, Object?>{
          'action': 'fixture',
          'kind': a.rest[1],
          'profile': inst.name,
          'ws': a['ws'],
          'http': a['http'],
        }),
      ),
    );
    return;
  }
  if (a.rest.length != 1 ||
      !seedRecipeIds.contains(a.rest.single) ||
      a['checkpoint-ready'] != 'true') {
    throw Fail(
      'seed <recipe> requires a reversible isolated chain/profile checkpoint; '
      'no automatic restore or cleanup',
    );
  }
  final String id = a.rest.single;
  final File file = File('$repo/harness/seed/$id.txt');
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      file.lengthSync() > 8192) {
    throw Fail('seed recipe source is missing or held');
  }
  final SeedRecipe plan = SeedRecipe.parse(id, file.readAsStringSync());
  final Map<String, dynamic> ready = await command(<String, Object?>{
    'action': 'begin',
    'recipe': id,
    'profile': inst.name,
    'ws': a['ws'],
    'http': a['http'],
    'checkpointReady': true,
    if (a['counterparty'] != null) 'counterparty': a['counterparty'],
  });
  final Map<String, String> values = <String, String>{
    if (ready['secondaryAddress'] is String)
      r'${secondaryAddress}': ready['secondaryAddress'] as String,
    if (ready['counterparty'] is String)
      r'${counterparty}': ready['counterparty'] as String,
  };
  final List<List<String>> lines = plan.lines
      .map((List<String> words) => plan.resolve(words, values))
      .toList();
  await prepareScreenHome(inst);
  for (final List<String> words in lines) {
    await command(<String, Object?>{'action': 'check'});
    if (words.first == 'publish') {
      stdout.writeln(
        jsonEncode(await command(<String, Object?>{'action': 'publish'})),
      );
    } else if (words.first == 'tap') {
      await command(<String, Object?>{
        'action': 'prepare',
        'selector': words.sublist(1),
      });
      stdout.writeln('ok');
    } else {
      await run(inst, words.first, Args(words.sublist(1)));
    }
  }
  stdout.writeln(
    jsonEncode(await command(<String, Object?>{'action': 'finish'})),
  );
}

/// Runs a file of harness command lines, stopping at the first that fails.
/// `#` starts a comment; quotes group words.
Future<void> script(Instance inst, String file, Args outer) async {
  final List<String> lines = File(file).readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    stdout.writeln('> $line');
    try {
      final List<String> words = scriptWords(line);
      await run(inst, words.first, Args(words.sublist(1)));
    } on Object catch (e) {
      throw Fail('$file:${i + 1}: $e');
    }
  }
}

// -------------------------------------------------------------------- recipes

//
// Flows a person does often, made of the same taps and keystrokes as above.

Future<Map<String, dynamic>> stateOf(Instance inst) =>
    call(inst, <String, Object?>{'cmd': 'state'});

Future<void> prepareScreenHome(Instance inst) async {
  final Map<String, dynamic> state = await stateOf(inst);
  if (state['booted'] != true ||
      state['walletUnlocked'] != true ||
      state['walletInitCompleted'] != true ||
      state['tab'] == 'lock') {
    throw Fail(
      'screens needs unlocked Home; entry preparation is pending F06/N',
    );
  }
  final List<dynamic> tabs = state['tabs'] as List<dynamic>;
  final String home = tabs.contains('home') ? 'home' : 'dashboard';
  await goto(inst, home);
  await setScreenRail(inst, expanded: false);
  final Map<String, dynamic> observed = await stateOf(inst);
  if (observed['tab'] != home || observed['walletUnlocked'] != true) {
    throw Fail('screens could not establish unlocked Home');
  }
}

Future<bool> screenRailExpanded(Instance inst) async {
  final Map<String, dynamic> state = await stateOf(inst);
  if (state['walletUnlocked'] != true ||
      state['tab'] == 'lock' ||
      state['walletInitCompleted'] != true ||
      !await present(inst, <String, Object?>{'key': 'rail_toggle'})) {
    throw Fail('screens rail is not ready in an unlocked profile');
  }
  return present(inst, <String, Object?>{'key': 'rail_label_dashboard'});
}

Future<void> setScreenRail(Instance inst, {required bool expanded}) async {
  if (await screenRailExpanded(inst) == expanded) return;
  await call(inst, <String, Object?>{'cmd': 'tap', 'key': 'rail_toggle'});
  await call(inst, <String, Object?>{
    'cmd': 'wait',
    'key': 'rail_label_dashboard',
    if (!expanded) 'gone': true,
  });
}

Future<void> restoreScreenRail(Instance inst, {required bool expanded}) async {
  await prepareScreenHome(inst);
  await setScreenRail(inst, expanded: expanded);
}

Future<bool> present(Instance inst, Map<String, Object?> sel) async {
  final Map<String, dynamic> r = await inst.send(<String, Object?>{
    'cmd': 'wait',
    ...sel,
    'timeoutMs': 0,
  });
  return r['ok'] == true;
}

/// Scrolls until the selector is on screen. A list builds only what is
/// visible, so what is below the fold is not in the tree until then.
Future<void> reveal(
  Instance inst,
  Map<String, Object?> sel, {
  int step = 250,
  int max = 20,
}) async {
  for (int i = 0; i <= max; i++) {
    if (await present(inst, sel)) return;
    await call(inst, <String, Object?>{'cmd': 'scroll', 'dy': step});
  }
  throw Fail('reveal: not found after ${max * step} px ${jsonEncode(sel)}');
}

Future<void> until(
  Instance inst,
  bool Function(Map<String, dynamic> state) test,
  String what, {
  int seconds = 30,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  while (true) {
    if (test(await stateOf(inst))) return;
    if (sw.elapsed.inSeconds >= seconds) throw Fail('$what: timed out');
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<void> goto(Instance inst, String tab) async {
  final Map<String, dynamic> s = await stateOf(inst);
  final List<dynamic> tabs = s['tabs'] as List<dynamic>;
  if (!tabs.contains(tab)) {
    throw Fail('no tab "$tab"; tabs are ${tabs.join(', ')}');
  }
  await call(inst, <String, Object?>{'cmd': 'tap', 'tab': tab});
  await until(
    inst,
    (Map<String, dynamic> s) => s['tab'] == tab,
    'goto $tab',
    seconds: 5,
  );
}

Future<void> unlock(Instance inst, String password) async {
  final Map<String, dynamic> s = await stateOf(inst);
  if (s['tab'] != 'lock') {
    stdout.writeln('already unlocked');
    return;
  }
  await call(inst, <String, Object?>{
    'cmd': 'type',
    'key': 'wallet_password_field',
    'value': password,
  });
  await call(inst, <String, Object?>{
    'cmd': 'tap',
    'key': 'wallet_unlock_button',
  });
  try {
    await until(
      inst,
      (Map<String, dynamic> s) =>
          s['tab'] != 'lock' && s['walletUnlocked'] == true,
      'unlock',
      seconds: 20,
    );
  } on Fail {
    // A wrong password costs an attempt; the wallet erases itself at zero.
    final Map<String, dynamic> t = await call(inst, <String, Object?>{
      'cmd': 'tree',
      'kind': 'text',
    });
    final Iterable<String> left = (t['nodes'] as List<dynamic>)
        .map(
          (dynamic n) => (n as Map<String, dynamic>)['label'] as String? ?? '',
        )
        .where((String l) => l.contains('attempt'));
    throw Fail('unlock failed${left.isEmpty ? '' : ': ${left.first}'}');
  }
}

/// From the Welcome screen of an empty profile to the dashboard.
Future<void> importWallet(Instance inst, Args a) async {
  final List<String> words =
      (a['mnemonic'] ?? (throw Fail('--mnemonic "<12 or 24 words>"')))
          .trim()
          .split(RegExp(r'\s+'));
  final String password =
      a['password'] ?? (throw Fail('--password <password>'));
  if (words.length != 12 && words.length != 24) {
    throw Fail('a mnemonic is 12 or 24 words, got ${words.length}');
  }
  Future<Map<String, dynamic>> tap(Map<String, Object?> sel) =>
      call(inst, <String, Object?>{'cmd': 'tap', ...sel});
  Future<Map<String, dynamic>> wait(String text, [int ms = 15000]) => call(
    inst,
    <String, Object?>{'cmd': 'wait', 'text': text, 'timeoutMs': ms},
  );

  await wait('Import wallet');
  await tap(<String, Object?>{'text': 'Import wallet'});
  await wait('Import your wallet');
  if (words.length == 12) {
    await tap(<String, Object?>{'text': 'assets/svg/ic_seed_12.svg'});
  }
  for (int i = 0; i < words.length; i++) {
    await call(inst, <String, Object?>{
      'cmd': 'type',
      'kind': 'field',
      'nth': i,
      'value': words[i],
      'settleMs': 60,
    });
  }
  await tap(<String, Object?>{'text': 'Continue', 'kind': 'button'});
  await wait('Create a wallet password');
  await call(inst, <String, Object?>{
    'cmd': 'type',
    'text': 'Password',
    'exact': true,
    'value': password,
  });
  await call(inst, <String, Object?>{
    'cmd': 'type',
    'text': 'Confirm password',
    'value': password,
  });
  await tap(<String, Object?>{'text': 'Confirm password', 'kind': 'button'});
  await wait('Node Management', 60000);
  if (a.has('node')) await selectNode(inst, a['node']!);
  await tap(<String, Object?>{'text': 'Continue', 'kind': 'button'});
  await wait('Access wallet', 60000);
  await tap(<String, Object?>{'text': 'Access wallet'});
  await until(
    inst,
    (Map<String, dynamic> s) => s['tab'] == 'dashboard',
    'dashboard',
  );
  final Map<String, dynamic> s = await stateOf(inst);
  stdout.writeln(
    'imported: ${s['address']} on ${s['node']} (chain ${s['chainId']})',
  );
}

/// On a screen that shows the node list (onboarding, or Settings): adds the
/// node if it is not listed, and selects it.
Future<void> selectNode(Instance inst, String url) async {
  final Map<String, Object?> row = <String, Object?>{
    'text': url,
    'exact': true,
    'kind': 'button',
  };
  if (!await present(inst, row)) {
    final Map<String, Object?> field = <String, Object?>{
      'text': 'Node address with port',
      'kind': 'field',
    };
    await reveal(inst, field);
    await call(inst, <String, Object?>{'cmd': 'type', ...field, 'value': url});
    final Map<String, Object?> add = <String, Object?>{
      'text': 'Add node',
      'kind': 'button',
    };
    await reveal(inst, add);
    await call(inst, <String, Object?>{'cmd': 'tap', ...add});
    await call(inst, <String, Object?>{'cmd': 'wait', ...row});
  }
  await call(inst, <String, Object?>{'cmd': 'tap', ...row});
}

/// Sets the chain identifier the wallet signs with, in Settings. A devnet
/// refuses blocks signed for chain 1, and the wallet does not follow the node.
Future<void> clientChain(Instance inst, int id) async {
  await goto(inst, 'settings');
  final Map<String, Object?> done = <String, Object?>{
    'text': 'Current client chain identifier is $id',
    'kind': 'field',
  };
  final Map<String, Object?> field = <String, Object?>{
    'text': 'Current client chain identifier',
    'kind': 'field',
  };
  if (!await present(inst, field)) {
    final Map<String, Object?> expander = <String, Object?>{
      'text': 'Client chain identifier selection',
    };
    await reveal(inst, expander);
    await call(inst, <String, Object?>{'cmd': 'tap', ...expander});
    await reveal(inst, field);
  }
  if (await present(inst, done)) return;
  await call(inst, <String, Object?>{'cmd': 'type', ...field, 'value': '$id'});
  // The Confirm button of this section is the first one below the field.
  await call(inst, <String, Object?>{
    'cmd': 'tap',
    'text': 'Confirm',
    'exact': true,
    'kind': 'button',
  });
  await call(inst, <String, Object?>{'cmd': 'wait', ...done});
}

/// Opens every tab in turn, takes a screenshot of each and lists what looks
/// wrong: error widgets, and SEVERE or Flutter errors logged while there.
Future<void> tour(Instance inst, Args a) async {
  final Map<String, dynamic> s = await stateOf(inst);
  if (s['tab'] == 'lock') {
    throw Fail('tour: the wallet is locked; `unlock` first');
  }
  final String dir = a['dir'] ?? '${inst.home}${Platform.pathSeparator}tour';
  // generation and sync are status icons, not pages; lock would end the tour.
  const Set<String> skipped = <String>{'generation', 'sync', 'lock'};
  int problems = 0;
  int seq =
      (await call(inst, <String, Object?>{'cmd': 'logs', 'limit': 0}))['seq']
          as int;
  for (final String tab in (s['tabs'] as List<dynamic>).cast<String>()) {
    if (skipped.contains(tab)) continue;
    // A tab can outlive its rail entry (Help, merged into Settings); say so
    // and go on, so one missing entry does not hide the pages after it.
    try {
      await goto(inst, tab);
    } on Fail catch (e) {
      stdout.writeln('${tab.padRight(14)} not reachable from the rail ($e)');
      continue;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    final Map<String, dynamic> shot = await call(inst, <String, Object?>{
      'cmd': 'shot',
    });
    File('$dir${Platform.pathSeparator}$tab.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(base64Decode(shot['png'] as String));
    final List<dynamic> nodes =
        (await call(inst, <String, Object?>{'cmd': 'tree'}))['nodes']
            as List<dynamic>;
    final List<dynamic> errors = nodes
        .where((dynamic n) => (n as Map<String, dynamic>)['kind'] == 'error')
        .toList();
    final Map<String, dynamic> logs = await call(inst, <String, Object?>{
      'cmd': 'logs',
      'since': seq,
      'levels': <String>['SEVERE', 'SHOUT', 'FLUTTER'],
    });
    seq = logs['seq'] as int;
    final List<dynamic> bad = logs['logs'] as List<dynamic>;
    problems += errors.length + bad.length;
    stdout.writeln(
      '${tab.padRight(14)} ${nodes.length.toString().padLeft(4)} nodes  '
      '${errors.length} error widgets  ${bad.length} errors logged',
    );
    for (final Map<String, dynamic> e in errors.cast<Map<String, dynamic>>()) {
      stdout.writeln('    widget: ${e['label']}');
    }
    for (final Map<String, dynamic> l in bad.cast<Map<String, dynamic>>()) {
      stdout.writeln(
        '    ${l['level']} ${l['logger']}: ${l['message']}'
        '${l['error'] == null ? '' : ' | ${l['error']}'}',
      );
    }
  }
  await goto(inst, 'dashboard');
  stdout.writeln('screenshots in $dir');
  if (problems > 0) throw Fail('tour: $problems problems');
}

Future<bool> recipe(Instance inst, String command, Args a) async {
  switch (command) {
    case 'goto':
      await goto(
        inst,
        a.rest.isEmpty ? (throw Fail('goto <tab>')) : a.rest.first,
      );
      stdout.writeln('ok');
    case 'unlock':
      await unlock(
        inst,
        a.rest.isNotEmpty
            ? a.rest.first
            : (a['password'] ?? (throw Fail('unlock <password>'))),
      );
      stdout.writeln('unlocked');
    case 'lock':
      await goto(inst, 'lock');
      stdout.writeln('locked');
    case 'import':
      await importWallet(inst, a);
    case 'node':
      await selectNode(
        inst,
        a.rest.isEmpty ? (throw Fail('node <ws url>')) : a.rest.first,
      );
      stdout.writeln('ok');
    case 'chain':
      await clientChain(
        inst,
        a.rest.isEmpty ? (throw Fail('chain <id>')) : int.parse(a.rest.first),
      );
      stdout.writeln('ok');
    case 'reveal':
      await reveal(
        inst,
        selector(a.rest.isEmpty ? null : a.rest.first, a)..remove('force'),
        max: a.integer('max') ?? 20,
      );
      stdout.writeln('ok');
    case 'tour':
      await tour(inst, a);
    default:
      return false;
  }
  return true;
}

Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.first == 'help' || argv.first == '--help') {
    stdout.writeln(
      'usage: harness <command> [arguments] [--instance <name>] [--json]\n'
      'see harness/README.md',
    );
    return;
  }
  try {
    final Args a = Args(argv.sublist(1));
    final Instance inst = Instance(a['instance'] ?? 'default');
    await run(inst, argv.first, a);
  } on Object catch (e) {
    stderr.writeln('error: $e');
    exitCode = 1;
  }
}
