import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../harness/bin/harness.dart' as cli;

class _TourInstance extends cli.Instance {
  _TourInstance() : super('synthetic-tour');

  String tab = 'dashboard';
  bool bellOpen = false;
  String? unavailable;
  bool widgetError = false;
  bool severe = false;
  int chain = 321;
  List<String> tabs = <String>[
    ...cli.walletTourPages, 'generation', 'sync', 'lock',
  ];
  final List<String> sections = <String>[];
  final List<String> captured = <String>[];
  Map<String, Object?>? outcome;

  @override
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    switch (command['cmd']) {
      case 'state':
        return <String, dynamic>{
          'ok': true, 'harnessMode': 'wallet', 'booted': true,
          'walletUnlocked': true,
          'walletInitCompleted': true, 'tab': tab, 'tabs': tabs,
          'address': 'synthetic-address', 'walletPath': 'synthetic-profile',
          'node': 'ws://127.0.0.1:45998', 'chainId': chain,
          'signingChainId': 321, 'savedSigningChainId': 321,
        };
      case 'tap':
        if (unavailable != null &&
            (command['tab'] == unavailable || command['key'] == unavailable)) {
          return <String, dynamic>{
            'ok': false, 'error': 'synthetic-unavailable',
          };
        }
        if (command['tab'] case final String value) {
          if (bellOpen) {
            return <String, dynamic>{
              'ok': false, 'error': 'synthetic-covered-navigation',
            };
          }
          if (value == 'notifications') {
            bellOpen = true;
          } else {
            tab = value;
          }
        }
        if (command['key'] case final String key) {
          if (key == 'bell_close') {
            if (!bellOpen) {
              return <String, dynamic>{
                'ok': false, 'error': 'synthetic-bell-not-open',
              };
            }
            bellOpen = false;
          }
          sections.add(key);
        }
        return <String, dynamic>{'ok': true};
      case 'wait':
        if (command['key'] == 'bell_panel' &&
            bellOpen == (command['gone'] == true)) {
          return <String, dynamic>{
            'ok': false, 'error': 'synthetic-bell-state-unavailable',
          };
        }
        return <String, dynamic>{'ok': true};
      case 'logs':
        return <String, dynamic>{
          'ok': true, 'seq': 1,
          'logs': <Object?>[
            if (severe && command.containsKey('since'))
              <String, Object?>{'message': 'synthetic private diagnostic'},
          ],
        };
      case 'tree':
        return <String, dynamic>{
          'ok': true,
          'nodes': <Object?>[
            <String, Object?>{
              'kind': widgetError ? 'error' : 'text',
              'label': 'synthetic private widget detail',
            },
          ],
        };
      case 'shot':
        return <String, dynamic>{'ok': true, 'png': 'synthetic-frame'};
      default:
        throw StateError('unexpected synthetic command');
    }
  }

  Future<void> run({bool changeContext = false}) => cli.tour(
    this,
    cli.Args(<String>[]),
    settle: (_) async {},
    capture: (String page, _) async {
      captured.add(page);
      if (changeContext) chain = 322;
    },
    publish: (Map<String, Object?> value) => outcome = value,
  );
}

class _UnlockStdout extends Fake implements Stdout {
  final List<Object?> lines = <Object?>[];

  @override
  void writeln([Object? object = '']) => lines.add(object);
}

class _UnlockInstance extends cli.Instance {
  _UnlockInstance(this.states) : super('synthetic-unlock');

  final List<Map<String, dynamic>> states;
  final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
  final _UnlockStdout output = _UnlockStdout();

  Future<void> runUnlock() => IOOverrides.runZoned<Future<void>>(
    () => cli.unlock(this, 'synthetic-password'),
    stdout: () => output,
  );

  @override
  Future<Map<String, dynamic>> send(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    commands.add(Map<String, Object?>.of(command));
    if (command['cmd'] == 'state') {
      if (states.isEmpty) throw StateError('synthetic state exhausted');
      return <String, dynamic>{'ok': true, ...states.removeAt(0)};
    }
    if (command['cmd'] == 'type' || command['cmd'] == 'tap') {
      return <String, dynamic>{'ok': true};
    }
    throw StateError('unexpected synthetic unlock command');
  }
}

void main() {
  test('unlock refuses unconfirmed non-lock states before password input',
      () async {
    for (final Object? tab in <Object?>[
      'startup', 'welcome', 'dashboard', null,
    ]) {
      for (final Object? unlocked in <Object?>[false, null, 'true', 1]) {
        final _UnlockInstance instance = _UnlockInstance(<Map<String, dynamic>>[
          <String, dynamic>{'tab': tab, 'walletUnlocked': unlocked},
        ]);
        await expectLater(instance.runUnlock(),
          throwsA(isA<cli.Fail>()));
        expect(instance.commands, <Map<String, Object?>>[
          <String, Object?>{'cmd': 'state'},
        ]);
        expect(instance.output.lines, isEmpty);
      }
    }
  });

  test('unlock accepts an already observed unlocked state without input',
      () async {
    final _UnlockInstance instance = _UnlockInstance(<Map<String, dynamic>>[
      <String, dynamic>{'tab': 'dashboard', 'walletUnlocked': true},
    ]);
    await instance.runUnlock();
    expect(instance.commands, <Map<String, Object?>>[
      <String, Object?>{'cmd': 'state'},
    ]);
    expect(instance.output.lines, <Object?>['already unlocked']);
  });

  test('unlock retains the ordinary password field, button and state check',
      () async {
    final _UnlockInstance instance = _UnlockInstance(<Map<String, dynamic>>[
      <String, dynamic>{'tab': 'lock', 'walletUnlocked': false},
      <String, dynamic>{'tab': 'dashboard', 'walletUnlocked': true},
    ]);
    await instance.runUnlock();
    expect(instance.commands, <Map<String, Object?>>[
      <String, Object?>{'cmd': 'state'},
      <String, Object?>{'cmd': 'type', 'key': 'wallet_password_field',
        'value': 'synthetic-password'},
      <String, Object?>{'cmd': 'tap', 'key': 'wallet_unlock_button'},
      <String, Object?>{'cmd': 'state'},
    ]);
    expect(instance.states, isEmpty);
    expect(instance.output.lines, isEmpty);
  });

  test('tour covers every page and reaches merged subpages', () async {
    final _TourInstance instance = _TourInstance();
    await instance.run();
    expect(instance.captured, <String>[
      ...cli.walletTourPages, 'walletConnect',
    ]);
    expect(instance.sections, <String>[
      'nodes_tab_pillars', 'nodes_tab_sentinels', 'bell_close', 'settings_apps',
    ]);
    expect(instance.tab, 'dashboard');
    expect(instance.bellOpen, isFalse);
    expect(instance.outcome?['complete'], isTrue);
    final List<Map<String, Object?>> visited =
        instance.outcome!['visited']! as List<Map<String, Object?>>;
    expect(
      visited.every((Map<String, Object?> page) => page['captured'] == true),
      isTrue,
    );
  });

  test('notifications opens the bell while retaining its original page',
      () async {
    final _TourInstance instance = _TourInstance()..tab = 'accelerator';
    await cli.goto(instance, 'notifications');
    expect(instance.tab, 'accelerator');
    expect(instance.bellOpen, isTrue);
    expect(instance.outcome, isNull);
  });

  test('an unavailable page cannot silently become complete', () async {
    final _TourInstance instance = _TourInstance()..unavailable = 'transfer';
    await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
    expect(instance.captured, <String>['dashboard']);
    expect(instance.outcome?['complete'], isFalse);
  });

  test('a missing merged section fails after its rail page opens', () async {
    final _TourInstance instance = _TourInstance()
      ..unavailable = 'nodes_tab_sentinels';
    await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
    expect(instance.captured, <String>['dashboard', 'transfer', 'pillars']);
    expect(instance.outcome?['complete'], isFalse);
  });

  test('invalid catalogs are rejected before navigation', () async {
    for (final List<String> tabs in <List<String>>[
      <String>[],
      <String>[...cli.walletTourPages, 'dashboard'],
      <String>[...cli.walletTourPages, 'unknown'],
      cli.walletTourPages.where((String page) => page != 'sentinels').toList(),
    ]) {
      final _TourInstance instance = _TourInstance()..tabs = tabs;
      await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
      expect(instance.captured, isEmpty);
      expect(instance.sections, isEmpty);
    }
  });

  test('widget and severe errors fail without raw diagnostics', () async {
    for (final bool widgetError in <bool>[true, false]) {
      final _TourInstance instance = _TourInstance()
        ..widgetError = widgetError
        ..severe = !widgetError;
      await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
      expect(instance.outcome?['complete'], isFalse);
      expect(instance.outcome.toString(), isNot(contains('private')));
      expect(instance.captured, isEmpty);
    }
  });

  test('wallet context changes stop the tour before the next page', () async {
    final _TourInstance instance = _TourInstance();
    await expectLater(
      instance.run(changeContext: true), throwsA(isA<cli.Fail>()),
    );
    expect(instance.captured, <String>['dashboard']);
    expect(instance.outcome?['complete'], isFalse);
  });
}
