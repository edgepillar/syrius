import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show InputDecorator, TextButton;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/rise_switcher.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:zenon_syrius_wallet_flutter/utils/original_publications.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/about_information.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/licences.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/help_widgets/originals_card.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/node_settings_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/node_settings_view.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/settings_switch.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/wallet_settings_presenter.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/settings_widgets/wallet_settings_view.dart';

import '../../harness/app/agent.dart';
import '../../harness/app/presentation_host.dart';
import '../../harness/app/readonly_native_commands.dart';
import '../../harness/app/readonly_sdk_admission.dart';
import '../../harness/bin/harness.dart' as cli;
import '../../harness/bin/readonly_inspection_session.dart';
import '../../harness/bin/screen_capture.dart';

import '../settings_about_redesign/support.dart' as about_fixture;
import '../settings_node_redesign/support.dart' as node_fixture;
import '../settings_wallet_redesign/support.dart' as wallet_fixture;

class _Scope {
  final Object sdk = Object();
  final HarnessAgent agent = HarnessAgent.forTest();
  bool current = true;
  bool disabled = false;

  Future<ReadonlySdkAdmission> seal() => ReadonlySdkAdmission.seal(
    sdkOwner: sdk,
    ownersCurrent: () => current,
    automaticDisabled: () => disabled,
    disableAutomatic: () async {
      disabled = true;
    },
  );

  Future<void> open() async {
    agent.reserveReadonlyNative();
    agent.attachReadonlyNative(await seal());
    agent.booted = true;
  }

  Future<Map<String, Object?>> ping() =>
      agent.commandForTest(<String, dynamic>{'cmd': 'ping'});
}

class _Headers extends Fake implements HttpHeaders {
  _Headers([this._token]);

  final String? _token;

  @override
  ContentType? contentType;

  @override
  String? value(String name) => name == 'x-harness-token' ? _token : null;
}

class _Response extends Fake implements HttpResponse {
  final StringBuffer _output = StringBuffer();
  bool _closed = false;

  @override
  final HttpHeaders headers = _Headers();

  @override
  int statusCode = 200;

  bool get closed => _closed;

  Map<String, dynamic> get body =>
      jsonDecode(_output.toString()) as Map<String, dynamic>;

  @override
  void write(Object? value) => _output.write(value);

  @override
  Future<void> close() async {
    _closed = true;
  }
}

class _Request extends Stream<Uint8List> implements HttpRequest {
  _Request(Map<String, dynamic> command, {String token = 'fixture-token'})
    : headers = _Headers(token),
      _body = Uint8List.fromList(utf8.encode(jsonEncode(command)));

  final Uint8List _body;

  @override
  final HttpHeaders headers;

  @override
  final _Response response = _Response();

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<Uint8List>.value(_body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected synthetic request member');
}

Future<T> _driveCatalogCommand<T>(
  WidgetTester tester,
  Future<T> command,
) async {
  bool done = false;
  T? result;
  Object? failure;
  StackTrace? trace;
  unawaited(command.then((T value) {
    result = value;
    done = true;
  }, onError: (Object error, StackTrace stack) {
    failure = error;
    trace = stack;
    done = true;
  }));
  for (int frame = 0; frame < 80 && !done; frame++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(done, isTrue, reason: 'The original catalog command must finish');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result as T;
}


class _InspectionInstance extends cli.Instance {
  _InspectionInstance(this._session) : super('synthetic-widget-inspection');
  final ReadonlyInspectionSession _session;

  @override
  Map<String, dynamic> read() =>
      throw StateError('The widget actor has no filesystem state');

  @override
  Future<Map<String, dynamic>> send(Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 30),
  }) => _session.send(command, timeout);
}

void main() {
  testWidgets(
    'revealed sibling retains the registry end and earlier complete text',
    (WidgetTester tester) async {
      about_fixture.prepareAboutViewport(tester);
      Future<void> toggle(String key) async {
        final Finder target = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
      }
      Future<AboutInformation> information() async =>
          AboutInformation(version: 'fixture');
      for (final bool light in <bool>[false, true]) {
        final ValueNotifier<bool> revealed = ValueNotifier<bool>(false);
        int reads = 0;
        Stream<LicenseEntry> load() {
          reads++;
          return Stream<LicenseEntry>.fromIterable(<LicenseEntry>[
            for (int index = 0; index < 30; index++)
              about_fixture.FixtureLicence(
                <String>[
                  'fixture-package-${index.toString().padLeft(2, '0')}',
                ],
                <LicenseParagraph>[
                  LicenseParagraph('Fixture terms $index', 0),
                ],
              ),
          ]);
        }
        try {
          await tester.pumpWidget(about_fixture.aboutHost(
            ValueListenableBuilder<bool>(
              valueListenable: revealed,
              builder: (BuildContext context, bool visible, Widget? _) =>
                  AboutCard(
                    loadInformation: information,
                    loadLicences: load,
                    compactLicences: visible,
                    licencesTrailingBuilder: (_) => const SizedBox(
                      height: 82,
                      child: Text('Fixture end', key: Key('fixture_end')),
                    ),
                    afterLicences: visible
                        ? const SizedBox(
                            height: 300,
                            child: Text('Fixture sibling'),
                          )
                        : null,
                  ),
            ),
            light: light, width: 992, height: 674,
          ));
          await toggle('about_licences_toggle');
          final Element listOwner = tester.element(find.byType(Licences));
          final Finder list = find.byKey(const Key('about_licences_list'));
          final Finder scrollable = find.descendant(
            of: list, matching: find.byType(Scrollable),
          ).first;
          await tester.scrollUntilVisible(
            find.byKey(const Key('fixture_end')), 250,
            scrollable: scrollable, maxScrolls: 20,
          );
          // The contract retains an idle, reached end, beyond mere visibility.
          final ScrollPosition position =
              tester.state<ScrollableState>(scrollable).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          expect(position.extentAfter, 0);
          expect(position.isScrollingNotifier.value, isFalse);
          expect(reads, 1);
          expect(find.byKey(const Key('fixture_end')).hitTestable(),
              findsOneWidget);
          revealed.value = true;
          await tester.pump();
          await tester.pump();
          // Observe the bounded layout corrections without advancing clocks.
          for (int frame = 0; frame < 4; frame++) {
            await tester.pump();
          }
          expect(tester.element(find.byType(Licences)), same(listOwner));
          expect(reads, 1);
          expect(position.extentAfter, 0);
          expect(find.byKey(const Key('fixture_end')).hitTestable(),
              findsOneWidget);
          revealed.value = false;
          await tester.pump();
          await tester.pump();
          // Visible end content need not include all its trailing space.
          position.jumpTo(position.maxScrollExtent - 16);
          await tester.pump();
          expect(position.extentAfter, greaterThan(0));
          expect(find.byKey(const Key('fixture_end')).hitTestable(),
              findsOneWidget);
          revealed.value = true;
          await tester.pump();
          for (int frame = 0; frame < 5; frame++) {
            await tester.pump();
          }
          expect(position.extentAfter, 0);
          final Rect retained = tester.getRect(
            find.byKey(const Key('fixture_end')),
          );
          final Rect viewport = tester.getRect(list);
          expect(viewport.contains(retained.topLeft), isTrue);
          expect(viewport.contains(retained.bottomRight - const Offset(1, 1)),
              isTrue);
          final Finder first = find.byKey(
            const Key('about_licence_fixture-package-00_toggle'),
          );
          await tester.scrollUntilVisible(
            first, -250, scrollable: scrollable, maxScrolls: 20,
          );
          await toggle('about_licence_fixture-package-00_toggle');
          expect(find.text('Fixture terms 0'), findsOneWidget);
          expect(reads, 1);
          revealed.value = false;
          await tester.pump();
          await tester.pump();
          final double awayFromEnd = position.pixels;
          expect(position.extentAfter, greaterThan(0));
          revealed.value = true;
          await tester.pump();
          await tester.pump();
          expect(position.pixels, awayFromEnd);
          expect(position.extentAfter, greaterThan(0));
          revealed.value = false;
          await tester.pump();
          await tester.pump();
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          expect(position.extentAfter, 0);
          // A movement after layout must revoke the earlier end request.
          WidgetsBinding.instance.addPostFrameCallback((Duration _) {
            position.jumpTo(0);
          });
          revealed.value = true;
          await tester.pump();
          await tester.pump();
          expect(position.pixels, 0);
          expect(position.extentAfter, greaterThan(0));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          revealed.dispose();
        }
      }
    },
  );

  testWidgets('nested page entrances restore Node focus authority', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    for (final bool light in <bool>[false, true]) {
      final node_fixture.FakeNodeSettingsSession source =
          node_fixture.FakeNodeSettingsSession();
      final NodeSettingsPresenter presenter =
          node_fixture.nodePresenter(source);
      final ValueNotifier<bool> show = ValueNotifier<bool>(false);
      final Widget section = RiseSwitcher(
        child: NodeSettingsView(
          presenter: presenter,
          isCurrent: () => true,
          embeddedNode: const SizedBox(height: 80),
        ),
      );
      TextButton add() => tester.widget<TextButton>(find.descendant(
        of: find.byKey(const Key('node_settings_add')),
        matching: find.byType(TextButton),
      ).first);
      try {
        await tester.pumpWidget(about_fixture.aboutHost(
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (BuildContext context, bool visible, Widget? _) =>
                RiseSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey<bool>(visible),
                    child: visible ? section : const SizedBox.shrink(),
                  ),
                ),
          ),
          light: light, width: 992, height: 674,
        ));
        show.value = true;
        await tester.pump();
        final State<StatefulWidget> owner = tester.state(
          find.byType(NodeSettingsView),
        );
        expect(find.byType(RiseSwitcher), findsNWidgets(2));
        expect(presenter.currentNetwork, isNull);
        expect(source.calls, isEmpty);
        expect(add().onPressed, isNull);
        await tester.pump(const Duration(milliseconds: 400));
        for (int frame = 0;
            frame < 100 &&
                (presenter.currentNetwork == null || add().onPressed == null);
            frame++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(tester.state(find.byType(NodeSettingsView)), same(owner));
        expect(presenter.currentNetwork, isNotNull);
        expect(add().onPressed, isNotNull);
        final VoidCallback retained = add().onPressed!;
        final int epoch = presenter.authorityEpoch;
        final List<String> before = List<String>.of(source.calls);
        show.value = false;
        await tester.pump();
        await tester.pump();
        expect(presenter.currentNetwork, isNull);
        expect(presenter.authorityEpoch, greaterThan(epoch));
        retained();
        await tester.pump();
        expect(find.byKey(const Key('node_settings_endpoint')), findsNothing);
        expect(source.calls, before);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(NodeSettingsView), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await presenter.close();
        show.dispose();
      }
    }
  });

  testWidgets('nested page entrances restore Wallet focus authority', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final _Scope scope = _Scope();
    await scope.open();
    for (final bool light in <bool>[false, true]) {
      final wallet_fixture.WalletSettingsFixture source =
          wallet_fixture.WalletSettingsFixture();
      final WalletSettingsPresenter presenter =
          WalletSettingsPresenter(binding: source.bind());
      final ValueNotifier<bool> show = ValueNotifier<bool>(false);
      final Widget section = RiseSwitcher(
        child: WalletSettingsView(
          presenter: presenter,
          isCurrent: () => true,
          onDeleteCache: (_) => fail('No maintenance action is requested'),
          onResetWallet: (_) => fail('No reset action is requested'),
        ),
      );
      SettingsSwitch auto() => tester.widget<SettingsSwitch>(
        find.byKey(const Key('wallet_settings_autoReceive')),
      );
      try {
        await tester.pumpWidget(about_fixture.aboutHost(
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (BuildContext context, bool visible, Widget? _) =>
                RiseSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey<bool>(visible),
                    child: visible ? section : const SizedBox.shrink(),
                  ),
                ),
          ),
          light: light, width: 992, height: 674,
        ));
        show.value = true;
        await tester.pump();
        final State<StatefulWidget> owner = tester.state(
          find.byType(WalletSettingsView),
        );
        expect(find.byType(RiseSwitcher), findsNWidgets(2));
        expect(presenter.state.available, isTrue);
        expect(auto().onChanged, isNull);
        await tester.pump(const Duration(milliseconds: 400));
        for (int frame = 0;
            frame < 100 && auto().onChanged == null; frame++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(tester.state(find.byType(WalletSettingsView)), same(owner));
        expect(auto().onChanged, isNotNull);
        final Map<String, Object?> observed =
            await scope.agent.commandForTest(<String, dynamic>{
          'cmd': 'assert', 'key': 'wallet_settings_autoReceive',
        });
        expect(observed['asserted'], isTrue);
        final ValueChanged<bool> retained = auto().onChanged!;
        show.value = false;
        await tester.pump();
        await tester.pump();
        retained(false);
        await tester.pump();
        expect(source.store.writes, isEmpty);
        expect(source.effects, isEmpty);
        expect(source.notices, isEmpty);
        expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(WalletSettingsView), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await presenter.close();
        show.dispose();
      }
    }
  });

  testWidgets('callback-only Node owners refresh and revoke retained Add', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final node_fixture.FakeNodeSettingsSession source =
        node_fixture.FakeNodeSettingsSession();
    final NodeSettingsPresenter presenter = node_fixture.nodePresenter(source);
    final ValueNotifier<bool> active = ValueNotifier<bool>(false);
    Widget nodeContent() => ValueListenableBuilder<bool>(
      valueListenable: active,
      builder: (BuildContext context, bool current, Widget? _) =>
          NodeSettingsView(
            presenter: presenter,
            isCurrent: () => current,
            embeddedNode: const SizedBox(height: 80),
          ),
    );
    TextButton add() => tester.widget<TextButton>(find.descendant(
      of: find.byKey(const Key('node_settings_add')),
      matching: find.byType(TextButton),
    ).first);
    Future<void> ready() async {
      for (int frame = 0;
          frame < 100 && presenter.currentNetwork == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(presenter.currentNetwork, isNotNull);
      await tester.pump();
    }
    try {
      await tester.pumpWidget(about_fixture.aboutHost(
        nodeContent(), width: 992, height: 674,
      ));
      await tester.pump();
      final State<StatefulWidget> owner = tester.state(
        find.byType(NodeSettingsView),
      );
      expect(presenter.currentNetwork, isNull);
      expect(add().onPressed, isNull);
      active.value = true;
      await tester.pump();
      await ready();
      expect(tester.state(find.byType(NodeSettingsView)), same(owner));
      final VoidCallback retained = add().onPressed!;
      final int epoch = presenter.authorityEpoch;
      active.value = false;
      await tester.pump();
      expect(presenter.currentNetwork, isNull);
      expect(presenter.authorityEpoch, greaterThan(epoch));
      expect(add().onPressed, isNull);
      active.value = true;
      await tester.pump();
      await ready();
      expect(tester.state(find.byType(NodeSettingsView)), same(owner));
      retained();
      await tester.pump();
      expect(find.byKey(const Key('node_settings_endpoint')), findsNothing);
      expect(source.calls.where((String call) =>
          call.startsWith('connect:')), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await presenter.close();
      active.dispose();
    }
  });

  testWidgets('an inactive replacement Node owner performs no passive reads', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final node_fixture.FakeNodeSettingsSession firstSource =
        node_fixture.FakeNodeSettingsSession();
    final node_fixture.FakeNodeSettingsSession nextSource =
        node_fixture.FakeNodeSettingsSession();
    final NodeSettingsPresenter first = node_fixture.nodePresenter(firstSource);
    final NodeSettingsPresenter next = node_fixture.nodePresenter(nextSource);
    NodeSettingsPresenter presenter = first;
    final ValueNotifier<int> revision = ValueNotifier<int>(0);
    bool active = true;
    Widget nodeContent() => ValueListenableBuilder<int>(
      valueListenable: revision,
      builder: (BuildContext context, int epoch, Widget? _) {
        final bool current = active;
        return NodeSettingsView(
          presenter: presenter,
          isCurrent: () => current,
          embeddedNode: const SizedBox(height: 80),
        );
      },
    );
    Future<void> ready() async {
      for (int frame = 0;
          frame < 100 && presenter.currentNetwork == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(presenter.currentNetwork, isNotNull);
      await tester.pump();
    }
    try {
      await tester.pumpWidget(about_fixture.aboutHost(
        nodeContent(), width: 992, height: 674,
      ));
      await ready();
      final State<StatefulWidget> owner = tester.state(
        find.byType(NodeSettingsView),
      );
      active = false;
      revision.value++;
      await tester.pump();
      expect(first.currentNetwork, isNull);
      final List<String> originalReads = List<String>.of(nextSource.calls);
      presenter = next;
      revision.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(nextSource.calls, originalReads);
      expect(next.currentNetwork, isNull);
      expect(tester.state(find.byType(NodeSettingsView)), same(owner));
      active = true;
      revision.value++;
      await tester.pump();
      await ready();
      expect(tester.state(find.byType(NodeSettingsView)), same(owner));
      expect(nextSource.calls.length, greaterThan(originalReads.length));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await first.close();
      await next.close();
      revision.dispose();
    }
  });

  testWidgets('readonly Add timeouts retain their original refusal category', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final _Scope scope = _Scope();
    await scope.open();
    final node_fixture.FakeNodeSettingsSession source =
        node_fixture.FakeNodeSettingsSession();
    final NodeSettingsPresenter presenter = node_fixture.nodePresenter(source);
    final ValueNotifier<int> phase = ValueNotifier<int>(0);
    final Widget content = ValueListenableBuilder<int>(
      valueListenable: phase,
      builder: (BuildContext context, int value, Widget? _) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (value != 3)
            NodeSettingsView(
              presenter: presenter,
              isCurrent: () => value != 1,
              embeddedNode: const SizedBox(height: 80),
            ),
          if (value == 2)
            const Positioned.fill(child: AbsorbPointer(
              child: SizedBox.expand(),
            )),
        ],
      ),
    );
    try {
      await tester.pumpWidget(about_fixture.aboutHost(
        content, width: 992, height: 674,
      ));
      for (int frame = 0;
          frame < 100 && presenter.currentNetwork == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(presenter.currentNetwork, isNotNull);
      await tester.pump();
      final Map<String, Object?> ready = await scope.agent.commandForTest(
        <String, dynamic>{'cmd': 'wait', 'key': 'node_settings_add',
          'ready': true, 'timeoutMs': 0},
      );
      expect((ready['target']! as Map<String, Object?>)['key'],
        'node_settings_add');
      const List<ScreenCaptureReplyCode> expected = <ScreenCaptureReplyCode>[
        ScreenCaptureReplyCode.targetDisabled,
        ScreenCaptureReplyCode.targetCovered,
        ScreenCaptureReplyCode.targetMissing,
      ];
      for (int value = 1; value <= 3; value++) {
        phase.value = value;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final List<String> before = List<String>.of(source.calls);
        final List<Map<String, Object?>> commands = <Map<String, Object?>>[];
        final _InspectionInstance instance = _InspectionInstance(
          ReadonlyInspectionSession(
            processId: pid,
            original: (Map<String, Object?> command, Duration timeout) async {
              commands.add(Map<String, Object?>.of(command));
              try {
                return <String, dynamic>{'ok': true,
                  ...await scope.agent.commandForTest(
                    Map<String, dynamic>.of(command),
                  ),
                };
              } on HarnessError catch (error) {
                expect(error.message, 'not ready after 0 ms');
                return <String, dynamic>{'ok': false, 'error': error.message,
                  'detail': ?error.detail,
                };
              }
            },
          ),
        );
        await expectLater(cli.waitForTarget(instance, cli.Args(<String>[
          '--key', 'node_settings_add', '--ready', '--timeout', '0',
        ])), throwsA(isA<cli.Fail>().having(screenCaptureReplyOf,
          'original closed readiness category', expected[value - 1])));
        expect(commands, <Map<String, Object?>>[
          <String, Object?>{'cmd': 'wait', 'key': 'node_settings_add',
            'ready': true, 'timeoutMs': 0},
        ]);
        await expectLater(instance.send(<String, Object?>{'cmd': 'ping'}),
          throwsA(isA<ReadonlyInspectionRefused>()));
        expect(commands.length, 1);
        expect(source.calls, before);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await presenter.close();
      phase.dispose();
    }
  });

  testWidgets('readonly observes the actual disabled Sporks card', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final _Scope scope = _Scope();
    await scope.open();
    final HarnessAgent agent = scope.agent;
    final node_fixture.FakeNodeSettingsSession source =
        node_fixture.FakeNodeSettingsSession();
    final NodeSettingsPresenter presenter = node_fixture.nodePresenter(source);
    double height = 674;
    final ValueNotifier<bool> active = ValueNotifier<bool>(true);
    Widget nodeContent() => ValueListenableBuilder<bool>(
      valueListenable: active,
      builder: (BuildContext context, bool current, Widget? _) => TickerMode(
        enabled: current,
        child: NodeSettingsView(
          presenter: presenter,
          isCurrent: () => current,
          embeddedNode: const SizedBox(height: 80),
        ),
      ),
    );
    for (final bool light in <bool>[false, true]) {
      await tester.pumpWidget(about_fixture.aboutHost(
        nodeContent(),
        light: light, width: 992, height: height,
      ));
      for (int frame = 0;
          frame < 100 && presenter.currentNetwork == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(presenter.currentNetwork, isNotNull);
      await tester.pump();
      final Finder gate = find.byKey(
        const Key('node_settings_sporks_gate'),
      );
      if (!light) {
        // End the inert viewport just below the actual Peers header.
        // The original scroll must expose Sporks through real clipping.
        height = tester.getRect(find.byKey(
          const Key('node_settings_peers_toggle'),
        )).bottom - tester.getRect(find.byKey(
          const Key('node_settings_page'),
        )).top + 1;
        expect(height, inInclusiveRange(1, 674));
        await tester.pumpWidget(about_fixture.aboutHost(
          nodeContent(),
          light: light, width: 992, height: height,
        ));
        await tester.pump();
      }
      ScrollPosition position() => tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('node_settings_page')),
          matching: find.byType(Scrollable),
        ).first,
      ).position;
      if (light) expect(position().pixels, greaterThan(0));
      // Prepare the original top-of-page Add target before readiness.
      await _driveCatalogCommand(tester, agent.commandForTest(
        <String, dynamic>{'cmd': 'scroll', 'dy': -1000000},
      ));
      expect(position().pixels, 0);
      active.value = false;
      await tester.pump();
      await expectLater(agent.commandForTest(<String, dynamic>{
        'cmd': 'assert', 'key': 'node_settings_add',
      }), throwsA(isA<HarnessError>().having(
        (HarnessError error) =>
            classifyScreenCaptureReply(error.message, error.detail),
        'actual disabled target', ScreenCaptureReplyCode.targetDisabled,
      )));
      bool readinessDone = false;
      final List<Map<String, Object?>> waitCommands =
          <Map<String, Object?>>[];
      final _InspectionInstance readyInstance = _InspectionInstance(
        ReadonlyInspectionSession(
          processId: pid,
          original: (Map<String, Object?> command, Duration timeout) async {
            waitCommands.add(Map<String, Object?>.of(command));
            try {
              return <String, dynamic>{
                'ok': true,
                ...await agent.commandForTest(
                  Map<String, dynamic>.of(command),
                ),
              };
            } on HarnessError catch (error) {
              return <String, dynamic>{
                'ok': false, 'error': error.message, 'detail': ?error.detail,
              };
            }
          },
        ),
      );
      final Future<Map<String, Object?>> readiness = cli.waitForTarget(
        readyInstance, cli.Args(<String>[
          '--key', 'node_settings_add', '--ready', '--timeout', '5',
        ]),
      );
      unawaited(readiness.then<void>((Map<String, Object?> value) {
        readinessDone = true;
      }, onError: (Object error, StackTrace stack) {
        readinessDone = true;
      }));
      await tester.pump(const Duration(milliseconds: 40));
      expect(readinessDone, isFalse);
      active.value = true;
      final Map<String, Object?> resumed =
          await _driveCatalogCommand(tester, readiness);
      expect((resumed['target']! as Map<String, Object?>)['key'],
        'node_settings_add');
      expect(waitCommands, equals(<Map<String, Object?>>[
        <String, Object?>{
          'cmd': 'wait', 'key': 'node_settings_add',
          'ready': true, 'timeoutMs': 5000,
        },
      ]));
      for (int frame = 0;
          frame < 100 && presenter.currentNetwork == null; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(presenter.currentNetwork, isNotNull);
      final List<String> callsBefore = List<String>.of(source.calls);
      await _driveCatalogCommand(tester, agent.commandForTest(
        <String, dynamic>{'cmd': 'scroll', 'dy': -1000000},
      ));
      expect(position().pixels, 0);
      final Map<String, Object?> addReady =
          await agent.commandForTest(<String, dynamic>{
        'cmd': 'assert', 'key': 'node_settings_add',
      });
      expect(addReady['asserted'], isTrue);
      await expectLater(agent.commandForTest(<String, dynamic>{
        'cmd': 'assert', 'key': 'node_settings_sporks_gate',
      }), throwsA(isA<HarnessError>()));
      await _driveCatalogCommand(tester, agent.commandForTest(
        <String, dynamic>{
          'cmd': 'scroll', 'key': 'node_settings_peers_toggle', 'dy': 300,
        },
      ));
      expect(position().pixels, greaterThan(0));
      expect(tester.widget<SeamGate>(gate).seam, Seam.sporks);
      for (final String command in <String>['assert', 'wait']) {
        final Map<String, Object?> result =
            await agent.commandForTest(<String, dynamic>{
          'cmd': command, 'key': 'node_settings_sporks_gate',
          if (command == 'wait') 'timeoutMs': 0,
          if (command == 'wait') 'ready': true,
        });
        final Map<String, Object?> target =
            result['target']! as Map<String, Object?>;
        expect(target['key'], 'node_settings_sporks_gate');
        expect(target['kind'], 'region');
        expect(target['ref'], 0);
      }
      await expectLater(agent.commandForTest(<String, dynamic>{
        'cmd': 'tap', 'key': 'node_settings_sporks_gate',
      }), throwsA(isA<HarnessError>()));
      expect(source.calls, callsBefore);
      expect(scope.disabled, isTrue);
      expect(find.byKey(const Key('node_settings_sporks_body'))
        .hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await presenter.close();
    active.dispose();
  });

  testWidgets(
    'actual licences list becomes visible after header-targeted scrolling',
    (WidgetTester tester) async {
      about_fixture.prepareAboutViewport(tester);
      final _Scope scope = _Scope();
      await scope.open();
      final HarnessAgent agent = scope.agent;
      final List<String> catalogCommands = <String>[];
      final _InspectionInstance inspection = _InspectionInstance(
        ReadonlyInspectionSession(
          processId: pid,
          original: (Map<String, Object?> command, Duration timeout) async {
            catalogCommands.add(command['cmd']! as String);
            try {
              return <String, dynamic>{
                'ok': true,
                ...await agent.commandForTest(
                  Map<String, dynamic>.of(command),
                ),
              };
            } on HarnessError catch (error) {
              return <String, dynamic>{
                'ok': false, 'error': error.message, 'detail': ?error.detail,
              };
            }
          },
        ),
      );
      // One agent owns its mouse device across both theme renders.
      for (final bool light in <bool>[false, true]) {
        final OriginalsController discovery = OriginalsController();
        // Keep fixture source identities stable across gallery insertion.
        int registryReads = 0;
        Future<AboutInformation> readInformation() async =>
            AboutInformation(version: 'fixture');
        Stream<LicenseEntry> readLicences() {
          registryReads++;
          return Stream<LicenseEntry>.value(
            about_fixture.FixtureLicence(<String>[
              'fixture-package',
              for (int index = 0; index < 120; index++)
                'fixture-registry-$index',
            ], const <LicenseParagraph>[
              LicenseParagraph('Complete fixture licence.', 0),
            ]),
          );
        }
        final Future<AboutInformation> Function() loadInformation =
            readInformation;
        final Stream<LicenseEntry> Function() loadLicences = readLicences;
        final ValueNotifier<double> viewportHeight = ValueNotifier<double>(674);
        addTearDown(viewportHeight.dispose);
        await tester.pumpWidget(ValueListenableBuilder<double>(
          valueListenable: viewportHeight,
          builder: (_, double height, Widget? child) =>
              about_fixture.aboutHost(child!, light: light, height: height),
          child: ListenableBuilder(
            listenable: discovery,
            builder: (BuildContext context, Widget? _) => AboutCard(
              loadInformation: loadInformation,
              loadLicences: loadLicences,
              compactLicences: discovery.revealed,
              licencesTrailingBuilder: (BuildContext context) =>
                  OriginalsDiscovery(
                    controller: discovery,
                    isCurrent: () => true,
                  ),
              // Real gallery geometry; artwork stays inert in this fixture.
              afterLicences: discovery.revealed
                  ? OriginalsCard(
                      isCurrent: () => true,
                      artBuilder: (BuildContext context, OriginalsArt art) =>
                          const SizedBox.expand(),
                    )
                  : const SizedBox(height: 56),
            ),
          ),
        ));
        await tester.pump();
        await _driveCatalogCommand(tester, agent.commandForTest(
          <String, dynamic>{'cmd': 'tap', 'key': 'about_licences_toggle'},
        ));
        final Finder list = find.byKey(const Key('about_licences_list'));
        expect(list, findsOneWidget);
        final Rect before = tester.getRect(list);
        expect(before.bottom, greaterThan(780));
        await expectLater(agent.commandForTest(<String, dynamic>{
          'cmd': 'wait', 'key': 'about_licences_list', 'timeoutMs': 0,
        }), throwsA(isA<HarnessError>()));
        await _driveCatalogCommand(tester, agent.commandForTest(
          <String, dynamic>{
            'cmd': 'scroll', 'key': 'about_licences_toggle', 'dy': 300,
          },
        ));
        final Rect section = tester.getRect(
          find.byKey(const Key('about_page')),
        );
        final Rect after = tester.getRect(list);
        expect(section.contains(after.topLeft), isTrue);
        expect(section.contains(after.bottomRight - const Offset(1, 1)),
          isTrue);
        final Map<String, Object?> result =
            await agent.commandForTest(<String, dynamic>{
          'cmd': 'wait', 'key': 'about_licences_list', 'timeoutMs': 0,
        });
        final Map<String, Object?> target =
            result['target']! as Map<String, Object?>;
        expect(target['kind'], 'region');
        expect(target['key'], 'about_licences_list');
        expect(find.text('fixture-package'), findsOneWidget);
        expect(tester.getRect(list).contains(const Offset(640, 390)),
          isTrue);
        await expectLater(agent.commandForTest(<String, dynamic>{
          'cmd': 'assert', 'key': 'about_licences_end',
        }), throwsA(isA<HarnessError>()));
        for (int phase = 0; phase < 3; phase++) {
          await _driveCatalogCommand(tester, cli.call(inspection,
            <String, Object?>{'cmd': 'scroll', 'dy': 1000000},
          ));
        }
        await _driveCatalogCommand(tester, cli.reveal(inspection,
          <String, Object?>{'key': 'about_licences_end'},
        ));
        final Map<String, Object?> endReady =
            await agent.commandForTest(<String, dynamic>{
          'cmd': 'wait', 'key': 'about_licences_end', 'timeoutMs': 0,
        });
        expect((endReady['target']! as Map<String, Object?>)['key'],
          'about_licences_end');
        final Map<String, Object?> end =
            await agent.commandForTest(<String, dynamic>{
          'cmd': 'assert', 'key': 'about_licences_end',
        });
        expect(end['asserted'], isTrue);
        await expectLater(agent.commandForTest(<String, dynamic>{
          'cmd': 'tap', 'key': 'about_licences_end',
        }), throwsA(isA<HarnessError>()));
        expect(discovery.revealed, isFalse);
        await _driveCatalogCommand(tester, cli.reveal(inspection,
          <String, Object?>{'key': 'originals_discovery_field'},
        ));
        final Map<String, Object?> discoveryReady =
            await agent.commandForTest(<String, dynamic>{
          'cmd': 'wait', 'key': 'originals_discovery_field', 'timeoutMs': 0,
        });
        expect((discoveryReady['target']! as Map<String, Object?>)['key'],
          'originals_discovery_field');
        await _driveCatalogCommand(tester, cli.call(inspection,
          <String, Object?>{
            'cmd': 'type', 'key': 'originals_discovery_field', 'value': '321',
          },
        ));
        expect(discovery.revealed, isTrue);
        expect(registryReads, 1);
        await tester.pump();
        expect(find.byKey(const Key('originals_card')), findsOneWidget);
        for (int frame = 0; frame < 4; frame++) {
          await tester.pump();
        }
        final Finder discoveryEditable = find.descendant(
          of: find.byKey(const Key('originals_discovery_field')),
          matching: find.byType(EditableText),
        );
        final RenderBox? container = InputDecorator.containerOf(
          tester.element(discoveryEditable),
        );
        expect(container, isNotNull);
        final Rect painted = container!.localToGlobal(Offset.zero) &
            container.size;
        final Rect compactList = tester.getRect(list);
        expect(compactList.contains(painted.topLeft), isTrue);
        expect(compactList.contains(painted.bottomRight - const Offset(1, 1)),
          isTrue);
        // Prepare a genuinely clipped card at the new compact geometry.
        viewportHeight.value = 500;
        await tester.pump();
        await expectLater(agent.commandForTest(<String, dynamic>{
          'cmd': 'wait', 'key': 'originals_card', 'timeoutMs': 0,
        }), throwsA(isA<HarnessError>()));
        for (int phase = 0; phase < 2; phase++) {
          await _driveCatalogCommand(tester, cli.call(inspection,
            <String, Object?>{'cmd': 'scroll', 'dy': 1000000},
          ));
        }
        final Rect gallery = tester.getRect(
          find.byKey(const Key('originals_card')),
        );
        final Rect currentSection = tester.getRect(
          find.byKey(const Key('about_page')),
        );
        expect(currentSection.contains(gallery.topLeft), isTrue);
        expect(currentSection.contains(
          gallery.bottomRight - const Offset(1, 1)), isTrue);
        expect(section.contains(gallery.topLeft), isTrue);
        expect(section.contains(gallery.bottomRight - const Offset(1, 1)),
          isTrue);
        expect(registryReads, 1);
        final Map<String, Object?> cardReady = await _driveCatalogCommand(
          tester, cli.waitForTarget(inspection, cli.Args(<String>[
            '--key', 'originals_card', '--timeout', '30',
          ])),
        );
        expect((cardReady['target']! as Map<String, Object?>)['key'],
          'originals_card');
        final Map<String, Object?> play = await _driveCatalogCommand(
          tester, cli.call(inspection, <String, Object?>{
            'cmd': 'assert', 'key': 'originals_play_launch', 'exact': true,
          }),
        );
        expect(play['asserted'], isTrue);
        expect(scope.disabled, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        discovery.dispose();
      }
      expect(catalogCommands, equals(<String>[
        for (int theme = 0; theme < 2; theme++)
          ...<String>[
            'scroll', 'scroll', 'scroll', 'wait', 'wait',
            'type', 'scroll', 'scroll', 'wait', 'assert',
          ],
      ]));
    },
  );


  testWidgets('readonly regions retain actual widget keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const ColoredBox(key: Key('home_hero'), color: Color(0xff222222),
            child: SizedBox(width: 200, height: 100,
              child: Text('Synthetic amount', key: Key('home_znn')))),
          GestureDetector(
            onTap: () => fail('Passive observation must not tap'),
            child: const Text('Synthetic rail',
              key: Key('rail_label_dashboard')),
          ),
        ]),
      ),
    ));
    final HarnessAgent ordinary = HarnessAgent.forTest()..booted = true;
    await expectLater(ordinary.commandForTest(<String, dynamic>{
      'cmd': 'assert', 'key': 'home_hero',
    }), throwsA(isA<HarnessError>()));
    final _Scope scope = _Scope();
    await scope.open();
    for (final String key in <String>[
      'home_hero', 'home_znn', 'rail_label_dashboard',
    ]) {
      final Map<String, Object?> result = await scope.agent.commandForTest(
        <String, dynamic>{'cmd': 'assert', 'key': key},
      );
      expect(result['asserted'], isTrue);
      final Map<String, Object?> target =
          result['target']! as Map<String, Object?>;
      final Rect rect = tester.getRect(find.byKey(Key(key)));
      expect(target['key'], key);
      expect(target['kind'], 'region');
      expect(target['rect'], <int>[
        rect.left.round(), rect.top.round(),
        rect.width.round(), rect.height.round(),
      ]);
      final Map<String, Object?> waited = await scope.agent.commandForTest(
        <String, dynamic>{'cmd': 'wait', 'key': key,
          'ready': true, 'timeoutMs': 0},
      );
      expect((waited['target']! as Map<String, Object?>)['key'], key);
    }
    final Map<String, Object?> tree = await scope.agent.commandForTest(
      <String, dynamic>{'cmd': 'tree'},
    );
    final List<Map<String, Object?>> nodes =
        tree['nodes']! as List<Map<String, Object?>>;
    expect(nodes.where((Map<String, Object?> node) =>
        node['kind'] == 'region'), isEmpty);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  testWidgets('hidden or duplicate regions provide no positive state', (
    WidgetTester tester,
  ) async {
    final _Scope scope = _Scope();
    await scope.open();
    const Widget region = ColoredBox(key: Key('home_hero'),
      color: Color(0xff222222), child: SizedBox(width: 200, height: 80));
    for (final String fault in <String>[
      'duplicate', 'offstage', 'hidden', 'zero',
    ]) {
      final Widget content = switch (fault) {
        'duplicate' => const Column(children: <Widget>[
          SizedBox(child: region), SizedBox(child: region),
        ]),
        'offstage' => const Offstage(child: region),
        'hidden' => const Visibility(visible: false, maintainSize: true,
          maintainAnimation: true, maintainState: true, child: region),
        _ => const SizedBox.shrink(child: region),
      };
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: content),
      ));
      await expectLater(scope.agent.commandForTest(<String, dynamic>{
        'cmd': 'assert', 'key': 'home_hero',
      }), throwsA(isA<HarnessError>()));
      await expectLater(scope.agent.commandForTest(<String, dynamic>{
        'cmd': 'wait', 'key': 'home_hero', 'timeoutMs': 0, 'ready': true,
      }), throwsA(isA<HarnessError>()));
      expect(tester.takeException(), isNull);
    }
    expect((await scope.ping())['booted'], isTrue);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  testWidgets('covered regions cannot assert or become controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: <Widget>[
        Positioned(left: 0, top: 0, width: 200, height: 100,
          child: ColoredBox(key: Key('home_hero'), color: Color(0xff222222),
            child: Text('Synthetic amount', key: Key('home_znn')))),
        Positioned.fill(child: ColoredBox(color: Color(0xff444444))),
      ]),
    ));
    final _Scope scope = _Scope();
    await scope.open();
    for (final Map<String, dynamic> command in <Map<String, dynamic>>[
      <String, dynamic>{'cmd': 'assert', 'key': 'home_hero'},
      <String, dynamic>{'cmd': 'wait', 'key': 'home_hero',
        'timeoutMs': 0, 'ready': true},
      <String, dynamic>{'cmd': 'tap', 'key': 'home_hero'},
      <String, dynamic>{'cmd': 'assert', 'key': 'home_hero', 'nth': 1},
      <String, dynamic>{'cmd': 'wait', 'key': 'home_hero', 'gone': true},
    ]) {
      await expectLater(scope.agent.commandForTest(command),
          throwsA(isA<HarnessError>()));
    }
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });


  testWidgets('readonly catalog regions preserve passive ancestor keys', (
    WidgetTester tester,
  ) async {
    about_fixture.prepareAboutViewport(tester);
    final _Scope scope = _Scope();
    await scope.open();
    final HarnessAgent ordinary = HarnessAgent.forTest()..booted = true;
    const List<String> keys = <String>[
      'send_form_ready', 'receive_form_ready', 'receive_screen_marker',
      'nodes_pillars_strip', 'pillar_dev1_detail', 'plasma_strip',
      'plasma_fused_list', 'plasma_screen', 'tokens_strip', 'tokens_list',
      'p2p_swaps_strip', 'p2p_swaps_list',
      'accelerator_strip', 'accelerator_list',
      'receive_qr_screen_marker',
      'zap_form_ready',
      'about_page',
      'about_licences_list',
      'about_licences_end',
      'originals_card',
      'node_settings_page',
      'node_settings_nodes',
      'node_settings_count',
      'node_settings_sporks_gate',
      'security_settings_page',
      'security_settings_policies',
      'security_settings_password_gate',
      'security_settings_backup',
      'display_page',
      'wallet_settings_page',
      'wallet_settings_preferences',
      'wallet_settings_modes_gate',
      'wallet_settings_wallets_gate',
      'apps_settings_page',
      'apps_settings_connected',
      'apps_settings_count',
      'addresses_settings_page',
      'about_strip',
      'about_update_gate',
      'about_version',
      'about_embedded_version',
      'about_build',
    ];
    Widget region(String key) => SizedBox(
      key: Key(key), width: 200, height: 80,
      child: const ColoredBox(
        color: Color(0xff222222),
        child: Text('Synthetic child', key: Key('synthetic_child')),
      ),
    );
    Widget overflowRegion(String key, Clip behavior) => SizedBox(
      width: 100, height: 40,
      child: ClipRect(
        clipBehavior: behavior,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 200, maxWidth: 200, minHeight: 80, maxHeight: 80,
          child: region(key),
        ),
      ),
    );
    Future<void> show(Widget content) => tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: content),
    ));
    Future<void> refused(Map<String, dynamic> command, {String? reason}) =>
        expectLater(scope.agent.commandForTest(command), throwsA(
          reason == null ? isA<HarnessError>() : isA<HarnessError>().having(
            (HarnessError error) =>
                (error.detail! as Map<String, Object?>)['readonly_region'],
            'original region refusal', reason,
          ),
        ));
    for (final String key in keys) {
      await show(region(key));
      await expectLater(ordinary.commandForTest(<String, dynamic>{
        'cmd': 'assert', 'key': key,
      }), throwsA(isA<HarnessError>()));
      for (final String command in <String>['assert', 'wait']) {
        final Map<String, Object?> result =
            await scope.agent.commandForTest(<String, dynamic>{
          'cmd': command, 'key': key,
          if (command == 'wait') 'ready': true,
          if (command == 'wait') 'timeoutMs': 0,
        });
        final Map<String, Object?> target =
            result['target']! as Map<String, Object?>;
        final Rect rect = tester.getRect(find.byKey(Key(key)));
        expect(target['key'], key);
        expect(target['kind'], 'region');
        expect(target['ref'], 0);
        expect(target['rect'], <int>[
          rect.left.round(), rect.top.round(),
          rect.width.round(), rect.height.round(),
        ]);
      }
      for (final Map<String, dynamic> command in <Map<String, dynamic>>[
        <String, dynamic>{'cmd': 'tap', 'key': key},
        <String, dynamic>{'cmd': 'assert', 'key': key, 'nth': 1},
        <String, dynamic>{'cmd': 'wait', 'key': key, 'gone': true},
      ]) {
        await refused(command);
      }
      final Map<String, Object?> tree =
          await scope.agent.commandForTest(<String, dynamic>{'cmd': 'tree'});
      final List<Map<String, Object?>> nodes =
          tree['nodes']! as List<Map<String, Object?>>;
      expect(nodes.where((Map<String, Object?> node) =>
          node['kind'] == 'region'), isEmpty);
      await show(overflowRegion(key, Clip.none));
      for (final String command in <String>['assert', 'wait']) {
        final Map<String, Object?> result =
            await scope.agent.commandForTest(<String, dynamic>{
          'cmd': command, 'key': key,
          if (command == 'wait') 'ready': true,
          if (command == 'wait') 'timeoutMs': 0,
        });
        final Map<String, Object?> target =
            result['target']! as Map<String, Object?>;
        expect(target['key'], key);
        expect(target['kind'], 'region');
        expect(target['ref'], 0);
      }
      for (final String fault in <String>[
        'duplicate', 'offstage', 'hidden', 'zero', 'covered', 'clipped',
      ]) {
        final Widget content = switch (fault) {
          'duplicate' => Column(mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(child: region(key)), SizedBox(child: region(key)),
            ]),
          'offstage' => Offstage(child: region(key)),
          'hidden' => Visibility(visible: false, maintainSize: true,
            maintainAnimation: true, maintainState: true, child: region(key)),
          'clipped' => overflowRegion(key, Clip.hardEdge),
          'covered' => Stack(children: <Widget>[
            region(key),
            const Positioned.fill(
              child: ColoredBox(color: Color(0xff444444))),
          ]),
          _ => SizedBox.shrink(child: region(key)),
        };
        await show(content);
        final String? reason = switch (fault) {
          'duplicate' => 'duplicate',
          'offstage' || 'hidden' => 'absent',
          'zero' => 'boundsRefused',
          'clipped' => 'paintClipCheckRefused',
          _ => null,
        };
        await refused(<String, dynamic>{'cmd': 'assert', 'key': key},
          reason: reason,
        );
        await refused(<String, dynamic>{'cmd': 'wait', 'key': key,
          'timeoutMs': 0, 'ready': true}, reason: reason);
        expect(tester.takeException(), isNull);
      }
    }
    for (final String key in <String>[
      'unapproved_passive_region', 'send_amount_field', 'plasma_open_fuse',
    ]) {
      await show(region(key));
      await refused(<String, dynamic>{'cmd': 'assert', 'key': key});
      await refused(<String, dynamic>{'cmd': 'wait', 'key': key,
        'timeoutMs': 0, 'ready': true});
    }
    int activations = 0;
    await tester.pumpWidget(about_fixture.aboutHost(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 320,
          height: 80,
          child: SeamGate(
            key: const Key('about_update_gate'),
            seam: Seam.walletUpdateNotice,
            child: TextButton(
              key: const Key('fixture_update_action'),
              onPressed: () => activations++,
              child: const Text('Synthetic update action'),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    for (final String command in <String>['assert', 'wait']) {
      final Map<String, Object?> result =
          await scope.agent.commandForTest(<String, dynamic>{
        'cmd': command,
        'key': 'about_update_gate',
        if (command == 'wait') 'ready': true,
        if (command == 'wait') 'timeoutMs': 0,
      });
      final Map<String, Object?> target =
          result['target']! as Map<String, Object?>;
      expect(target['key'], 'about_update_gate');
      expect(target['kind'], 'region');
    }
    for (final String key in <String>[
      'about_update_gate', 'fixture_update_action',
    ]) {
      await refused(<String, dynamic>{'cmd': 'tap', 'key': key});
      await refused(<String, dynamic>{
        'cmd': 'type', 'key': key, 'value': 'synthetic',
      });
    }
    await tester.tap(find.byKey(const Key('fixture_update_action')),
      warnIfMissed: false);
    expect(activations, 0);
    expect((await scope.ping())['booted'], isTrue);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });


  testWidgets('readonly unavailable preference stays an original refusal', (
    WidgetTester tester,
  ) async {
    final _Scope scope = _Scope();
    await scope.open();
    final HarnessAgent ordinary = HarnessAgent.forTest()..booted = true;
    for (final bool light in <bool>[false, true]) {
      final WalletSettingsPresenter presenter = WalletSettingsPresenter(
        binding: null,
      );
      for (final String mode in <String>[
        'visible', 'covered', 'hidden', 'duplicate',
      ]) {
        final Widget view = WalletSettingsView(
          presenter: presenter,
          isCurrent: () => true,
          onDeleteCache: (_) => fail('No maintenance may start'),
          onResetWallet: (_) => fail('No reset may start'),
        );
        await tester.pumpWidget(about_fixture.aboutHost(
          Stack(fit: StackFit.expand, children: <Widget>[
            Offstage(offstage: mode == 'hidden', child: view),
            if (mode == 'covered')
              const Positioned.fill(
                child: ColoredBox(color: Color(0xff222222)),
              ),
            if (mode == 'duplicate')
              const Positioned(top: 0, right: 0, child: Text(
                'Synthetic marker',
                key: Key('wallet_settings_autoReceive_unavailable'),
              )),
          ]),
          light: light,
        ));
        await tester.pump();
        for (final HarnessAgent agent in <HarnessAgent>[
          scope.agent, ordinary,
        ]) {
          HarnessError? rejected;
          try {
            await agent.commandForTest(<String, dynamic>{
              'cmd': 'assert', 'key': 'wallet_settings_autoReceive',
            });
          } on HarnessError catch (error) {
            rejected = error;
          }
          expect(rejected, isNotNull);
          expect(rejected!.message, 'nothing matches');
          expect(classifyScreenCaptureReply(
            rejected.message, rejected.detail,
          ), identical(agent, scope.agent) && mode == 'visible'
              ? ScreenCaptureReplyCode.targetUnavailable
              : ScreenCaptureReplyCode.targetMissing);
        }
        for (final String command in <String>['tap', 'type']) {
          await expectLater(scope.agent.commandForTest(<String, dynamic>{
            'cmd': command,
            'key': 'wallet_settings_autoReceive',
            if (command == 'type') 'text': 'Synthetic input',
          }), throwsA(isA<HarnessError>()));
        }
        expect(presenter.state.available, isFalse);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await presenter.close();
    }
    expect(classifyScreenCaptureReply('nothing matches', <String, Object?>{
      'key': 'a_different_selector',
      'readonly_wallet_preference': 'unavailable',
    }), ScreenCaptureReplyCode.targetMissing);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  testWidgets('readonly settings regions keep real seam gates inert', (
    WidgetTester tester,
  ) async {
    final _Scope scope = _Scope();
    await scope.open();
    int activated = 0;
    const Map<String, Seam> gates = <String, Seam>{
      'security_settings_password_gate': Seam.passwordChangeMigration,
      'wallet_settings_modes_gate': Seam.operatorModes,
      'wallet_settings_wallets_gate': Seam.walletPicker,
    };
    for (final bool light in <bool>[false, true]) {
      for (final MapEntry<String, Seam> entry in gates.entries) {
        await tester.pumpWidget(about_fixture.aboutHost(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 200, height: 80,
              child: SeamGate(key: Key(entry.key), seam: entry.value,
                child: TextButton(
                  key: const Key('synthetic_gated_action'),
                  onPressed: () => activated++,
                  child: const Text('Synthetic gated action'),
                ),
              ),
            ),
          ),
          light: light,
        ));
        await tester.pump();
        for (final String command in <String>['assert', 'wait']) {
          final Map<String, Object?> result =
              await scope.agent.commandForTest(<String, dynamic>{
            'cmd': command, 'key': entry.key,
            if (command == 'wait') 'ready': true,
            if (command == 'wait') 'timeoutMs': 0,
          });
          final Map<String, Object?> target =
              result['target']! as Map<String, Object?>;
          expect(target['key'], entry.key);
          expect(target['kind'], 'region');
          expect(target['ref'], 0);
        }
        await expectLater(scope.agent.commandForTest(<String, dynamic>{
          'cmd': 'tap', 'key': entry.key,
        }), throwsA(isA<HarnessError>()));
        await expectLater(scope.agent.commandForTest(<String, dynamic>{
          'cmd': 'type', 'key': entry.key, 'text': 'Synthetic input',
        }), throwsA(isA<HarnessError>()));
        await tester.tap(find.byKey(const Key('synthetic_gated_action')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(activated, 0);
        final Map<String, Object?> tree = await scope.agent.commandForTest(
          <String, dynamic>{'cmd': 'tree'},
        );
        expect((tree['nodes']! as List<Map<String, Object?>>).where(
          (Map<String, Object?> node) => node['kind'] == 'region',
        ), isEmpty);
        expect(tester.takeException(), isNull);
      }
    }
    expect(scope.disabled, isTrue);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });


  testWidgets('readonly passive centers distinguish gaps from overlays', (
    WidgetTester tester,
  ) async {
    final _Scope scope = _Scope();
    await scope.open();
    final HarnessAgent ordinary = HarnessAgent.forTest()..booted = true;
    for (final String key in <String>['home_hero', 'send_form_ready']) {
      for (final bool covered in <bool>[false, true]) {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft,
            child: ColoredBox(color: const Color(0xff222222),
              child: SizedBox(width: 200, height: 100,
                child: Stack(children: <Widget>[
                  Builder(key: Key(key), builder: (_) => const Column(
                    children: <Widget>[
                      SizedBox(height: 20, child: Text('Synthetic top',
                        key: Key('passive_top'))),
                      Spacer(),
                      SizedBox(height: 20, child: Text('Synthetic bottom',
                        key: Key('passive_bottom'))),
                    ],
                  )),
                  if (covered)
                    const Positioned(left: 70, top: 30, width: 60, height: 40,
                      child: ColoredBox(color: Color(0xff444444))),
                ]),
              ),
            ),
          ),
        ));
        for (final String child in <String>['passive_top', 'passive_bottom']) {
          final Map<String, Object?> result =
              await scope.agent.commandForTest(<String, dynamic>{
            'cmd': 'assert', 'key': child,
          });
          expect(result['asserted'], isTrue);
        }
        await expectLater(ordinary.commandForTest(<String, dynamic>{
          'cmd': 'assert', 'key': key,
        }), throwsA(isA<HarnessError>()));
        for (final String command in <String>['assert', 'wait']) {
          final Map<String, dynamic> fields = <String, dynamic>{
            'cmd': command, 'key': key,
            if (command == 'wait') 'ready': true,
            if (command == 'wait') 'timeoutMs': 0,
          };
          if (covered) {
            await expectLater(scope.agent.commandForTest(fields),
              throwsA(isA<HarnessError>()));
          } else {
            final Map<String, Object?> result =
                await scope.agent.commandForTest(fields);
            final Map<String, Object?> target =
                result['target']! as Map<String, Object?>;
            expect(target['key'], key);
            expect(target['kind'], 'region');
            expect(target['ref'], 0);
            final Rect rect = tester.getRect(find.byKey(Key(key)));
            expect(target['rect'], <int>[
              rect.left.round(), rect.top.round(),
              rect.width.round(), rect.height.round(),
            ]);
          }
        }
        await expectLater(scope.agent.commandForTest(<String, dynamic>{
          'cmd': 'tap', 'key': key,
        }), throwsA(isA<HarnessError>()));
        expect(tester.takeException(), isNull);
      }
    }
    final Map<String, Object?> tree =
        await scope.agent.commandForTest(<String, dynamic>{'cmd': 'tree'});
    final List<Map<String, Object?>> nodes =
        tree['nodes']! as List<Map<String, Object?>>;
    expect(nodes.where((Map<String, Object?> node) =>
        node['kind'] == 'region'), isEmpty);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  test('inspection entry refuses foreign nodes and chains before UI access',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    for (final Map<String, dynamic> fields in <Map<String, dynamic>>[
      <String, dynamic>{'expectedNode': 'wss://example.invalid:443'},
      <String, dynamic>{'expectedNodeChain': 1},
      <String, dynamic>{
        'key': 'node_settings_endpoint', 'value': 'ws://127.0.0.1:45999',
      },
      <String, dynamic>{
        'key': 'node_settings_client_chain', 'value': '1',
      },
      <String, dynamic>{
        'key': 'node_settings_select_ws://127.0.0.1:45999',
      },
    ]) {
      await expectLater(scope.agent.commandForTest(<String, dynamic>{
        'cmd': 'readonly-entry', 'action': 'observe', ...fields,
      }), throwsA(isA<ReadonlyNativeCommandRefused>()));
    }
    expect((await scope.ping())['pid'], pid);
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  test('binding without the original native window holds the actual agent',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    await expectLater(scope.agent.commandForTest(<String, dynamic>{
      'cmd': 'readonly-wallet-bind',
    }), throwsA(isA<HarnessError>()));
    await expectLater(scope.ping(),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  test('ordinary original ping keeps the wallet mode without SDK sealing',
      () async {
    final HarnessAgent agent = HarnessAgent.forTest();
    final Map<String, Object?> result =
        await agent.commandForTest(<String, dynamic>{'cmd': 'ping'});
    expect(result['harnessMode'], 'wallet');
    expect(result['booted'], isFalse);
    expect(result.containsKey('readonlyAdmission'), isFalse);
  });

  test('reserved startup exposes only pending ping before SDK admission',
      () async {
    final _Scope scope = _Scope();
    scope.agent.reserveReadonlyNative();
    final Map<String, Object?> pending = await scope.ping();
    expect(pending['booted'], isFalse);
    expect(pending['harnessMode'], 'readonly-native');
    expect(pending.containsKey('pid'), isFalse);
    for (final String command in <String>['state', 'type', 'readonly-state']) {
      await expectLater(
        scope.agent.commandForTest(<String, dynamic>{'cmd': command}),
        throwsA(isA<ReadonlyNativeCommandRefused>()),
      );
    }
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
  });

  test('sealed readiness uses the original agent ping and fixed SDK scope',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    final Map<String, Object?> result = await scope.ping();
    expect(result['pid'], pid);
    expect(result['booted'], isTrue);
    expect(result['harnessMode'], 'readonly-native');
    expect(result['readonlyAdmission'], <String, Object>{
      'schema': 1,
      'scope': 'readonly_native_sdk_admission',
      'status': 'CURRENT',
      'publicationAdmissionPaused': true,
      'automaticReceiveDisabled': true,
    });
    expect(scope.disabled, isTrue);
  });

  test('financial routes cannot bypass the original agent admission',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    for (final String command in <String>[
      'seed', 'lab-send', 'lab-quiesce', 'lab-reopen-observe',
      'wallet-recipe', 'clipboard',
    ]) {
      await expectLater(
        scope.agent.commandForTest(<String, dynamic>{'cmd': command}),
        throwsA(isA<ReadonlyNativeCommandRefused>()),
      );
    }
    expect(OriginalPublications.snapshot(scope.sdk), isEmpty);
    expect(OriginalPublications.hasRefusedAdmission(scope.sdk), isFalse);
    expect((await scope.ping())['booted'], isTrue);
  });

  test('early readiness cannot attach an SDK after its failed observation',
      () async {
    final _Scope scope = _Scope();
    scope.agent
      ..reserveReadonlyNative()
      ..booted = true;
    await expectLater(scope.ping(),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
    scope.agent.booted = false;
    final ReadonlySdkAdmission sdk = await scope.seal();
    expect(() => scope.agent.attachReadonlyNative(sdk),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
  });

  test('a used or booted ordinary agent cannot reserve inspection later',
      () async {
    final HarnessAgent used = HarnessAgent.forTest();
    await used.commandForTest(<String, dynamic>{'cmd': 'ping'});
    expect(used.reserveReadonlyNative, throwsA(isA<HarnessError>()));
    final HarnessAgent booted = HarnessAgent.forTest()..booted = true;
    expect(booted.reserveReadonlyNative, throwsA(isA<HarnessError>()));
  });

  test('presentation and original native inspection are mutually exclusive',
      () {
    final HarnessPresentationController controller =
        HarnessPresentationController();
    addTearDown(controller.dispose);
    final HarnessAgent preview = HarnessAgent.forTest()
      ..usePresentation(
        controller: controller,
        isCurrent: () => true,
        context: () => null,
      );
    expect(preview.reserveReadonlyNative, throwsA(isA<HarnessError>()));
    final HarnessAgent native = HarnessAgent.forTest()
      ..reserveReadonlyNative();
    expect(
      () => native.usePresentation(
        controller: controller,
        isCurrent: () => true,
        context: () => null,
      ),
      throwsA(isA<HarnessError>()),
    );
  });

  test('a changed SDK observation stays held after restoration', () async {
    final _Scope scope = _Scope();
    await scope.open();
    scope.current = false;
    await expectLater(scope.ping(),
        throwsA(isA<ReadonlySdkAdmissionRefused>()));
    scope.current = true;
    await expectLater(scope.ping(),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
  });

  test('the actual original ping await cannot borrow changed SDK ownership',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    final Future<void> refused = expectLater(
      scope.ping(),
      throwsA(isA<ReadonlySdkAdmissionRefused>()),
    );
    scope.current = false;
    await refused;
  });

  test('an original UI refusal stays exact while its SDK remains current',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    await expectLater(
      scope.agent.commandForTest(<String, dynamic>{'cmd': 'entry-check'}),
      throwsA(isA<HarnessError>().having(
        (HarnessError error) => error.message,
        'original error',
        'native entry capture is unavailable',
      )),
    );
    expect((await scope.ping())['booted'], isTrue);
  });

  test('duplicate attachment cannot supply a second positive SDK scope',
      () async {
    final _Scope scope = _Scope();
    scope.agent.reserveReadonlyNative();
    final ReadonlySdkAdmission sdk = await scope.seal();
    scope.agent.attachReadonlyNative(sdk);
    expect(() => scope.agent.attachReadonlyNative(sdk),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
    scope.agent.booted = true;
    await expectLater(scope.ping(),
        throwsA(isA<ReadonlyNativeCommandRefused>()));
  });

  test('an unreserved agent cannot attach an inspection SDK', () async {
    final _Scope scope = _Scope();
    final ReadonlySdkAdmission sdk = await scope.seal();
    expect(() => scope.agent.attachReadonlyNative(sdk),
        throwsA(isA<HarnessError>()));
  });

  test('actual transport keeps pending refusals finite without raw errors',
      () async {
    final HarnessAgent agent = HarnessAgent.forTest()
      ..reserveReadonlyNative();
    final _Request request = _Request(<String, dynamic>{'cmd': 'type'});
    await agent.serveForTest(request, 'fixture-token');
    expect(request.response.statusCode, 400);
    expect(request.response.closed, isTrue);
    expect(request.response.body, <String, Object>{
      'ok': false,
      'error': 'READONLY_NATIVE_COMMAND_REFUSED',
    });
    expect(request.response.headers.contentType, ContentType.json);
  });

  test('actual transport projects a replaced SDK without private details',
      () async {
    final _Scope scope = _Scope();
    await scope.open();
    scope.current = false;
    final _Request request = _Request(<String, dynamic>{'cmd': 'ping'});
    await scope.agent.serveForTest(request, 'fixture-token');
    expect(request.response.statusCode, 400);
    expect(request.response.closed, isTrue);
    expect(request.response.body, <String, Object>{
      'ok': false,
      'error': 'READONLY_NATIVE_SDK_REFUSED',
    });
  });

  test('original authentication and ordinary transport errors stay intact',
      () async {
    final HarnessAgent agent = HarnessAgent.forTest();
    final _Request wrong = _Request(
      <String, dynamic>{'cmd': 'ping'},
      token: 'another-fixture-token',
    );
    await agent.serveForTest(wrong, 'fixture-token');
    expect(wrong.response.body, <String, Object>{
      'ok': false,
      'error': 'bad token',
    });
    final _Request unknown = _Request(<String, dynamic>{'cmd': 'unknown'});
    await agent.serveForTest(unknown, 'fixture-token');
    expect(unknown.response.statusCode, 400);
    expect(unknown.response.closed, isTrue);
    expect(unknown.response.body, <String, Object>{
      'ok': false,
      'error': 'unknown command unknown',
    });
  });
}
