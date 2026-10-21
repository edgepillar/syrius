// The wallet's own screens for the channel: the approval, the Settings
// switch and Connected sites, with their cubits.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/cubit/connected_sites_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/cubit/dapp_bridge_switch_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_channel.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_consent.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_error.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/view/connected_sites.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/view/dapp_bridge_approval.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/view/dapp_bridge_switch.dart';

import 'support.dart';

/// The channel as the screens see it, without a socket.
class _FakeControl implements DappBridgeControl {
  @override
  bool enabled = true;
  @override
  int? port = 35996;
  @override
  List<DappBridgeSite> sites = <DappBridgeSite>[
    const DappBridgeSite(requester: kSite, addresses: <String>[kA, kB]),
    const DappBridgeSite(
      requester: 'link:$kOther',
      addresses: <String>[kA],
    ),
  ];
  Object? failure;
  final List<String> calls = <String>[];
  final StreamController<void> changed = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => changed.stream;

  @override
  Future<void> setEnabled({required bool enabled}) async {
    calls.add('setEnabled $enabled');
    if (failure != null) {
      throw failure!;
    }
    this.enabled = enabled;
    port = enabled ? 35996 : null;
  }

  @override
  Future<void> disconnect(String requester) async {
    calls.add('disconnect $requester');
    if (failure != null) {
      throw failure!;
    }
    sites = <DappBridgeSite>[
      for (final DappBridgeSite s in sites)
        if (s.requester != requester) s,
    ];
  }
}

Widget _app(Widget child, {double? height = 400}) => MaterialApp(
  home: Scaffold(
    body: height == null
        ? SingleChildScrollView(child: child)
        : SizedBox(width: 600, height: height, child: child),
  ),
);

void main() {
  group('DappBridgeSwitchCubit', () {
    late _FakeControl control;

    setUp(() => control = _FakeControl());

    blocTest<DappBridgeSwitchCubit, DappBridgeSwitchState>(
      'starts from the channel',
      build: () => DappBridgeSwitchCubit(control),
      verify: (DappBridgeSwitchCubit cubit) => expect(
        cubit.state,
        const DappBridgeSwitchState(enabled: true, port: 35996),
      ),
    );

    blocTest<DappBridgeSwitchCubit, DappBridgeSwitchState>(
      'turns the channel off, then shows it off',
      build: () => DappBridgeSwitchCubit(control),
      act: (DappBridgeSwitchCubit cubit) => cubit.setEnabled(enabled: false),
      expect: () => const <DappBridgeSwitchState>[
        DappBridgeSwitchState(enabled: false, port: 35996, saving: true),
        DappBridgeSwitchState(enabled: false),
      ],
      verify: (_) => expect(control.calls, <String>['setEnabled false']),
    );

    blocTest<DappBridgeSwitchCubit, DappBridgeSwitchState>(
      'a change that fails shows what is really in force',
      build: () => DappBridgeSwitchCubit(control..failure = StateError('x')),
      act: (DappBridgeSwitchCubit cubit) => cubit.setEnabled(enabled: false),
      expect: () => const <DappBridgeSwitchState>[
        DappBridgeSwitchState(enabled: false, port: 35996, saving: true),
        DappBridgeSwitchState(enabled: true, port: 35996, failed: true),
      ],
    );

    blocTest<DappBridgeSwitchCubit, DappBridgeSwitchState>(
      'follows the channel when it changes elsewhere',
      build: () => DappBridgeSwitchCubit(control),
      act: (DappBridgeSwitchCubit cubit) async {
        control.port = null;
        control.changed.add(null);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <DappBridgeSwitchState>[
        DappBridgeSwitchState(enabled: true),
      ],
    );
  });

  group('ConnectedSitesCubit', () {
    late _FakeControl control;

    setUp(() => control = _FakeControl());

    blocTest<ConnectedSitesCubit, ConnectedSitesState>(
      'starts with the connected sites',
      build: () => ConnectedSitesCubit(control),
      verify: (ConnectedSitesCubit cubit) =>
          expect(cubit.state.sites, hasLength(2)),
    );

    blocTest<ConnectedSitesCubit, ConnectedSitesState>(
      'disconnects one',
      build: () => ConnectedSitesCubit(control),
      act: (ConnectedSitesCubit cubit) => cubit.disconnect(kSite),
      expect: () => <ConnectedSitesState>[
        ConnectedSitesState(sites: <DappBridgeSite>[control.sites.single]),
      ],
      verify: (_) => expect(control.calls, <String>['disconnect $kSite']),
    );

    blocTest<ConnectedSitesCubit, ConnectedSitesState>(
      'says when a disconnect fails, and keeps the site',
      build: () => ConnectedSitesCubit(control..failure = StateError('x')),
      act: (ConnectedSitesCubit cubit) => cubit.disconnect(kSite),
      expect: () => <ConnectedSitesState>[
        ConnectedSitesState(sites: control.sites, failed: true),
      ],
    );

    blocTest<ConnectedSitesCubit, ConnectedSitesState>(
      'follows a page that connects or disconnects itself',
      build: () => ConnectedSitesCubit(control),
      act: (ConnectedSitesCubit cubit) async {
        control.sites = <DappBridgeSite>[];
        control.changed.add(null);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const <ConnectedSitesState>[ConnectedSitesState()],
    );
  });

  group('DappBridgeSwitch', () {
    testWidgets('shows the port and turns the channel off', (
      WidgetTester tester,
    ) async {
      final _FakeControl control = _FakeControl();
      await tester.pumpWidget(_app(DappBridgeSwitch(control: control)));
      expect(find.text('Web apps'), findsOneWidget);
      expect(find.text('127.0.0.1:35996'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dapp_bridge_switch')));
      await tester.pumpAndSettle();
      expect(control.calls, <String>['setEnabled false']);
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('says when no port was free', (WidgetTester tester) async {
      final _FakeControl control = _FakeControl()..port = null;
      await tester.pumpWidget(_app(DappBridgeSwitch(control: control)));
      expect(find.text('No free port'), findsOneWidget);
    });

    testWidgets('sits in a scrolling column', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(DappBridgeSwitch(control: _FakeControl()), height: null),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dapp_bridge_switch')), findsOneWidget);
    });
  });

  group('ConnectedSites', () {
    for (final double? height in <double?>[400, null]) {
      testWidgets(
        'lists origins, addresses and grants, and disconnects '
        '(${height == null ? 'in a scrolling column' : 'in a grid cell'})',
        (WidgetTester tester) async {
          final _FakeControl control = _FakeControl();
          await tester.pumpWidget(
            _app(ConnectedSites(control: control), height: height),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Connected sites'), findsOneWidget);
          expect(find.text(kSite), findsOneWidget);
          expect(find.text(kOther), findsOneWidget);
          expect(find.text('LINK'), findsOneWidget);
          expect(find.text('z1qq9n7f…wyg0mq'), findsNWidgets(2));
          expect(
            find.text('See address · Ask to sign · Ask to send'),
            findsNWidgets(2),
          );
          await tester.tap(
            find.byKey(const Key('dapp_bridge_disconnect_$kSite')),
          );
          await tester.pumpAndSettle();
          expect(control.calls, <String>['disconnect $kSite']);
          expect(find.text(kSite), findsNothing);
          expect(find.text(kOther), findsOneWidget);
        },
      );
    }

    testWidgets('none yet', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          ConnectedSites(control: _FakeControl()..sites = <DappBridgeSite>[]),
        ),
      );
      expect(find.byKey(const Key('connected_sites_empty')), findsOneWidget);
    });
  });

  group('showDappBridgeApproval', () {
    late GlobalKey<NavigatorState> navigator;

    setUp(() => navigator = GlobalKey<NavigatorState>());

    Future<Future<DappBridgeAnswer>> ask(
      WidgetTester tester, {
      String requester = kSite,
      Duration ttl = kDappBridgeApprovalTtl,
    }) async {
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      final Future<DappBridgeAnswer> answer = showDappBridgeApproval(
        navigator.currentState!,
        title: 'Sign this message?',
        requester: requester,
        action: 'Sign',
        rows: const <(String, String)>[('Message', 'hello')],
        ttl: ttl,
      );
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('approve', (WidgetTester tester) async {
      final Future<DappBridgeAnswer> answer = await ask(tester);
      expect(find.byKey(const Key('dapp_bridge_origin')), findsOneWidget);
      expect(find.text(kSite), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(find.byKey(const Key('dapp_bridge_unverified')), findsNothing);
      await tester.pump(kDappBridgeApprovalArm);
      await tester.tap(find.byKey(const Key('dapp_bridge_approve')));
      await tester.pumpAndSettle();
      expect(await answer, DappBridgeAnswer.approved);
    });

    testWidgets('a click in the first second approves nothing', (
      WidgetTester tester,
    ) async {
      DappBridgeAnswer? answered;
      final Future<DappBridgeAnswer> answer = await ask(tester);
      unawaited(answer.then((DappBridgeAnswer a) => answered = a));
      // As soon as the dialog has finished appearing, well inside the second.
      await tester.tap(find.byKey(const Key('dapp_bridge_approve')));
      await tester.pumpAndSettle();
      expect(answered, isNull);
      expect(find.byKey(const Key('dapp_bridge_approve')), findsOneWidget);
      // Declining is never held back.
      await tester.tap(find.byKey(const Key('dapp_bridge_decline')));
      await tester.pumpAndSettle();
      expect(await answer, DappBridgeAnswer.declined);
    });

    testWidgets('one at a time: the second is built when the first is '
        'answered, so a double click cannot approve both', (
      WidgetTester tester,
    ) async {
      final Future<DappBridgeAnswer> first = await ask(tester);
      final Future<DappBridgeAnswer> second = showDappBridgeApproval(
        navigator.currentState!,
        title: 'Send this?',
        requester: kOther,
        action: 'Send',
        rows: const <(String, String)>[('To', kTo)],
      );
      await tester.pumpAndSettle();
      expect(find.text(kSite), findsOneWidget);
      expect(find.text(kOther), findsNothing);

      await tester.pump(kDappBridgeApprovalArm);
      await tester.tap(find.byKey(const Key('dapp_bridge_approve')));
      await tester.pumpAndSettle();
      expect(await first, DappBridgeAnswer.approved);
      expect(find.text(kSite), findsNothing);
      expect(find.text(kOther), findsOneWidget);

      // The second click of a double click: its button is not armed yet.
      DappBridgeAnswer? answered;
      unawaited(second.then((DappBridgeAnswer a) => answered = a));
      await tester.tap(find.byKey(const Key('dapp_bridge_approve')));
      await tester.pumpAndSettle();
      expect(answered, isNull);
      await tester.pump(kDappBridgeApprovalArm);
      await tester.tap(find.byKey(const Key('dapp_bridge_approve')));
      await tester.pumpAndSettle();
      expect(await second, DappBridgeAnswer.approved);
    });

    testWidgets('one that waited its turn is not shown once the wallet '
        'has locked', (WidgetTester tester) async {
      bool unlocked = true;
      final Future<DappBridgeAnswer> first = await ask(tester);
      final Future<DappBridgeAnswer> second = showDappBridgeApproval(
        navigator.currentState!,
        title: 'Send this?',
        requester: kOther,
        action: 'Send',
        rows: const <(String, String)>[('To', kTo)],
        stillWanted: () => unlocked,
      );
      unlocked = false;
      // What a lock does to the dialog on screen.
      navigator.currentState!.popUntil((Route<dynamic> r) => r.isFirst);
      await tester.pumpAndSettle();
      // Neither was declined by anyone.
      expect(await first, DappBridgeAnswer.dismissed);
      expect(await second, DappBridgeAnswer.dismissed);
      expect(find.byKey(const Key('dapp_bridge_approve')), findsNothing);
    });

    testWidgets('one that expires while it waits is never shown', (
      WidgetTester tester,
    ) async {
      final Future<DappBridgeAnswer> first = await ask(tester);
      final Future<DappBridgeAnswer> second = showDappBridgeApproval(
        navigator.currentState!,
        title: 'Send this?',
        requester: kOther,
        action: 'Send',
        rows: const <(String, String)>[('To', kTo)],
        ttl: const Duration(minutes: 1),
      );
      final Future<void> refused = expectLater(
        second,
        throwsA(
          isA<DappBridgeError>().having(
            (DappBridgeError e) => e.code,
            'code',
            -32006,
          ),
        ),
      );
      await tester.pump(const Duration(minutes: 1));
      await refused;
      await tester.tap(find.byKey(const Key('dapp_bridge_decline')));
      await tester.pumpAndSettle();
      expect(await first, DappBridgeAnswer.declined);
      expect(find.text(kOther), findsNothing);
    });

    testWidgets('decline', (WidgetTester tester) async {
      final Future<DappBridgeAnswer> answer = await ask(tester);
      await tester.tap(find.byKey(const Key('dapp_bridge_decline')));
      await tester.pumpAndSettle();
      expect(await answer, DappBridgeAnswer.declined);
    });

    testWidgets('popped by a lock: dismissed, not declined', (
      WidgetTester tester,
    ) async {
      final Future<DappBridgeAnswer> answer = await ask(tester);
      navigator.currentState!.popUntil((Route<dynamic> r) => r.isFirst);
      await tester.pumpAndSettle();
      expect(await answer, DappBridgeAnswer.dismissed);
    });

    testWidgets('expires: -32006, and the dialog is gone', (
      WidgetTester tester,
    ) async {
      final Future<DappBridgeAnswer> answer = await ask(
        tester,
        ttl: const Duration(minutes: 1),
      );
      final Future<void> refused = expectLater(
        answer,
        throwsA(
          isA<DappBridgeError>().having(
            (DappBridgeError e) => e.code,
            'code',
            -32006,
          ),
        ),
      );
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      await refused;
      expect(find.byKey(const Key('dapp_bridge_approve')), findsNothing);
    });

    testWidgets('a link request says its sender is not verified', (
      WidgetTester tester,
    ) async {
      final Future<DappBridgeAnswer> answer = await ask(
        tester,
        requester: 'link:$kSite',
      );
      expect(find.text(kSite), findsOneWidget);
      expect(find.byKey(const Key('dapp_bridge_unverified')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dapp_bridge_decline')));
      await tester.pumpAndSettle();
      expect(await answer, DappBridgeAnswer.declined);
    });
  });
}
