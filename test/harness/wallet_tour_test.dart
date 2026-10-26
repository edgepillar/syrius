import 'package:flutter_test/flutter_test.dart';

import '../../harness/bin/harness.dart' as cli;

class _TourInstance extends cli.Instance {
  _TourInstance() : super('synthetic-tour');

  String tab = 'dashboard';
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
          'ok': true, 'harnessMode': 'wallet', 'booted': true, 'walletUnlocked': true,
          'walletInitCompleted': true, 'tab': tab, 'tabs': tabs,
          'address': 'synthetic-address', 'walletPath': 'synthetic-profile',
          'node': 'ws://127.0.0.1:45998', 'chainId': chain,
          'signingChainId': 321, 'savedSigningChainId': 321,
        };
      case 'tap':
        if (unavailable != null &&
            (command['tab'] == unavailable || command['key'] == unavailable)) {
          return <String, dynamic>{'ok': false, 'error': 'synthetic-unavailable'};
        }
        if (command['tab'] case final String value) tab = value;
        if (command['key'] case final String key) sections.add(key);
        return <String, dynamic>{'ok': true};
      case 'wait':
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

void main() {
  test('tour covers every page and reaches merged subpages through their UI', () async {
    final _TourInstance instance = _TourInstance();
    await instance.run();
    expect(instance.captured, <String>[...cli.walletTourPages, 'walletConnect']);
    expect(instance.sections, <String>[
      'nodes_tab_pillars', 'nodes_tab_sentinels', 'settings_apps',
    ]);
    expect(instance.tab, 'dashboard');
    expect(instance.outcome?['complete'], isTrue);
    final List<Map<String, Object?>> visited =
        instance.outcome!['visited']! as List<Map<String, Object?>>;
    expect(visited.every((Map<String, Object?> page) => page['captured'] == true), isTrue);
  });

  test('an unavailable page fails and cannot silently become complete', () async {
    final _TourInstance instance = _TourInstance()..unavailable = 'transfer';
    await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
    expect(instance.captured, <String>['dashboard']);
    expect(instance.outcome?['complete'], isFalse);
  });

  test('a missing merged section fails even when the main rail page opens', () async {
    final _TourInstance instance = _TourInstance()
      ..unavailable = 'nodes_tab_sentinels';
    await expectLater(instance.run(), throwsA(isA<cli.Fail>()));
    expect(instance.captured, <String>['dashboard', 'transfer', 'pillars']);
    expect(instance.outcome?['complete'], isFalse);
  });

  test('missing duplicate and unknown catalogs are rejected before navigation', () async {
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

  test('widget and severe errors fail with finite counts and no raw diagnostics', () async {
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
    await expectLater(instance.run(changeContext: true), throwsA(isA<cli.Fail>()));
    expect(instance.captured, <String>['dashboard']);
    expect(instance.outcome?['complete'], isFalse);
  });
}
