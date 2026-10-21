import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/cubits/timer_cubit.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/plasma_glow.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/pair.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/app_lottie.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/status_strip.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

const Key _sync = Key('strip_sync');
const Key _height = Key('strip_height');
const Key _node = Key('strip_node');
const Key _chain = Key('strip_chain');
const Key _peers = Key('strip_peers');
const Key _behind = Key('strip_behind');
const Key _flight = Key('strip_flight');
const Key _plasma = Key('strip_plasma');
const Key _elapsed = Key('strip_plasma_elapsed');
const Key _typical = Key('strip_plasma_typical');
const Key _notice = Key('notice');

/// The strip's width in the smallest window (1200) with the rail open (200):
/// less the shell's padding (10 and 18) and the gap beside the rail (8).
const double _narrowest = 964;

/// The sync cubit without its node and without its storage: the strip only
/// listens to it.
class _Sync extends Cubit<NodeSyncStatusState> implements NodeSyncStatusCubit {
  _Sync() : super(const NodeSyncStatusState());

  /// The node answers with these heights.
  void answer({required int current, required int target, bool done = true}) =>
      emit(
        NodeSyncStatusState(
          status: TimerStatus.success,
          data: Pair<SyncState, SyncInfo>(
            done ? SyncState.syncDone : SyncState.syncing,
            SyncInfo.fromJson(<String, dynamic>{
              'state': (done ? SyncState.syncDone : SyncState.syncing).index,
              'currentHeight': current,
              'targetHeight': target,
            }),
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What one test holds of the strip's sources.
class _Rig {
  _Rig(this.tester) : _start = tester.binding.clock.now();

  final WidgetTester tester;
  final DateTime _start;
  final _Sync sync = _Sync();
  final StreamController<PowStatus> pow = StreamController<PowStatus>.broadcast(
    sync: true,
  );
  final PlasmaTimes times = PlasmaTimes();
  final Set<Hash> confirmed = <Hash>{};
  late final InFlightBlocks flight = InFlightBlocks(
    lookup: (Hash hash) async => confirmed.contains(hash),
  );
  final ValueNotifier<int?> peers = ValueNotifier<int?>(23);

  /// The test's clock, which `pump` moves.
  Duration uptime() => tester.binding.clock.now().difference(_start);

  Future<void> show({
    double width = 1400,
    Widget? trailing,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: SizedBox(
              width: width,
              child: StatusStrip(
                syncCubit: sync,
                page: ValueNotifier<int>(0),
                flight: flight,
                peers: peers,
                plasma: GenerationStatus(
                  status: pow.stream,
                  uptime: uptime,
                  times: times,
                ),
                trailing: trailing,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> dispose() async {
    await pow.close();
    await sync.close();
  }
}

final Hash _hash = Hash.parse('ab' * 32);
final Hash _otherHash = Hash.parse('cd' * 32);

Color _dot(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byKey(_sync)).decoration!
            as BoxDecoration)
        .color!;

/// Whether the part is drawn. One the row has left out is still in the
/// widget tree, so finding it says nothing.
bool _drawn(Key key) => find.byKey(key).hitTestable().evaluate().isNotEmpty;

void main() {
  setUp(() => kCurrentNode = 'ws://127.0.0.1:35998');
  tearDown(() => kCurrentNode = null);

  /// A window wide enough for every part at the test font's width, which
  /// is about twice the wallet's.
  void wideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('at rest: height, node, chain, peers, a green dot, the glow', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 3281904, target: 3281904);
    await rig.show(width: 2000);

    expect(find.text('#3,281,904'), findsOneWidget);
    expect(_drawn(_height), isTrue);
    expect(tester.widget<Text>(find.byKey(_node)).data, 'ws://127.0.0.1:35998');
    expect(_drawn(_chain), isTrue);
    expect(tester.widget<Text>(find.byKey(_peers)).data, '23');
    expect(_dot(tester), AppTokens.dark.znnInk);
    expect(tester.widget(find.byKey(_plasma)), isA<PlasmaGlow>());
    expect(tester.widget<PlasmaGlow>(find.byKey(_plasma)).active, isFalse);
    expect(find.byKey(_behind), findsNothing);
    expect(find.byKey(_flight), findsNothing);
    expect(find.byKey(_elapsed), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generating plasma: the bolt, seconds counting, then typical', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 100, target: 100);
    await rig.show(width: 2000);

    rig.pow.add(PowStatus.generating);
    await tester.pump();
    expect(tester.widget(find.byKey(_plasma)), isA<AppLottie>());
    expect(
      tester.widget<AppLottie>(find.byKey(_plasma)).asset,
      AppLottieAsset.plasmaGeneration,
    );
    expect(tester.widget<AppLottie>(find.byKey(_plasma)).repeat, isTrue);
    expect(find.text('Generating plasma'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(_elapsed)).data, '0 s');
    // Nothing has been measured yet.
    expect(find.byKey(_typical), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Text>(find.byKey(_elapsed)).data, '1 s');
    await tester.pump(const Duration(seconds: 13));
    expect(tester.widget<Text>(find.byKey(_elapsed)).data, '14 s');

    rig.pow.add(PowStatus.done);
    await tester.pump();
    expect(tester.widget(find.byKey(_plasma)), isA<PlasmaGlow>());
    expect(find.byKey(_elapsed), findsNothing);
    expect(rig.times.typical, const Duration(seconds: 14));

    // The second generation starts from zero and knows the first.
    rig.pow.add(PowStatus.generating);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(_elapsed)).data, '0 s');
    expect(
      tester.widget<Text>(find.byKey(_typical)).data,
      contains('usually about 14 s'),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Text>(find.byKey(_elapsed)).data, '3 s');
    expect(tester.takeException(), isNull);
  });

  test('the typical time is the median of the last eight', () {
    final PlasmaTimes times = PlasmaTimes();
    expect(times.typical, isNull);
    for (final int seconds in <int>[20, 30, 400]) {
      times.add(Duration(seconds: seconds));
    }
    expect(times.typical, const Duration(seconds: 30));
    times.add(const Duration(seconds: 40));
    expect(times.typical, const Duration(seconds: 35));
    for (int i = 0; i < PlasmaTimes.kept; i++) {
      times.add(const Duration(seconds: 5));
    }
    expect(times.typical, const Duration(seconds: 5));
  });

  testWidgets('a block in flight is named until a momentum has it', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 100, target: 100);
    await rig.show(width: 2000);
    expect(find.byKey(_flight), findsNothing);

    rig.flight.sent(
      hash: _hash,
      amount: BigInt.from(1250000000),
      decimals: 8,
      symbol: 'ZNN',
    );
    await tester.pump();
    expect(_drawn(_flight), isTrue);
    // No trailing zeros, and the amount is its own left-to-right run.
    expect(find.text('12.5 ZNN'), findsOneWidget);
    expect(
      find.textContaining('waiting for a momentum', findRichText: true),
      findsOneWidget,
    );

    // A momentum without the block: still waiting.
    rig.sync.answer(current: 101, target: 101);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_flight), findsOneWidget);

    rig.flight.sent(
      hash: _otherHash,
      amount: BigInt.one,
      decimals: 0,
      symbol: 'PP',
    );
    await tester.pump();
    expect(
      find.textContaining('Sending 2 blocks', findRichText: true),
      findsOneWidget,
    );

    rig.confirmed.addAll(<Hash>[_hash, _otherHash]);
    rig.sync.answer(current: 102, target: 102);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_flight), findsNothing);
    expect(rig.flight.value, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a node behind: amber dot and how many momentums', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 3281862, target: 3281904, done: false);
    await rig.show(width: 2000);

    expect(_dot(tester), AppTokens.dark.warn);
    expect(
      tester.widget<Text>(find.byKey(_behind)).data,
      '42 momentums behind',
    );
    expect(_drawn(_behind), isTrue);

    // Caught up to within the node's usual slack.
    rig.sync.answer(current: 3281903, target: 3281904, done: false);
    await tester.pump();
    expect(_dot(tester), AppTokens.dark.znnInk);
    expect(find.byKey(_behind), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the trailing notice is shown when given, at the far end', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 100, target: 100);
    await rig.show(width: 2000);
    expect(find.byKey(_notice), findsNothing);

    await rig.show(
      width: 2000,
      trailing: const Text('Syrius 0.3.0 is out', key: _notice),
    );
    expect(_drawn(_notice), isTrue);
    expect(
      tester.getRect(find.byKey(_notice)).left,
      greaterThan(tester.getRect(find.byKey(_plasma)).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing overflows; peers go first, then chain, then node', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.sync.answer(current: 3281904, target: 3281904);
    rig.flight.sent(
      hash: _hash,
      amount: BigInt.from(1250000000),
      decimals: 8,
      symbol: 'ZNN',
    );

    final Set<String> seen = <String>{};
    for (double width = 2200; width >= 100; width -= 20) {
      await rig.show(
        width: width,
        trailing: const Text('Syrius 0.3.0 is out', key: _notice),
      );
      expect(tester.takeException(), isNull, reason: 'at $width');
      final bool node = _drawn(_node);
      final bool chain = _drawn(_chain);
      final bool peers = _drawn(_peers);
      expect(!peers || chain, isTrue, reason: 'peers without chain at $width');
      expect(!chain || node, isTrue, reason: 'chain without node at $width');
      expect(!node || _drawn(_flight), isTrue, reason: 'node first at $width');
      seen.add('${node ? 'n' : ''}${chain ? 'c' : ''}${peers ? 'p' : ''}');
      // The dot is never given up.
      expect(_drawn(_sync), isTrue, reason: 'at $width');
    }
    // Each step of giving way was passed through on the way down.
    expect(seen, <String>{'ncp', 'nc', 'n', ''});
  });

  testWidgets('every state at once in the smallest window, both themes', (
    WidgetTester tester,
  ) async {
    wideWindow(tester);
    final _Rig rig = _Rig(tester);
    addTearDown(rig.dispose);
    rig.times.add(const Duration(seconds: 25));
    rig.sync.answer(current: 3281862, target: 3281904, done: false);
    rig.flight.sent(
      hash: _hash,
      amount: BigInt.from(1250000000),
      decimals: 8,
      symbol: 'ZNN',
    );
    for (final ThemeData theme in <ThemeData>[
      AppTheme.darkTheme,
      AppTheme.lightTheme,
    ]) {
      await rig.show(
        width: _narrowest,
        theme: theme,
        trailing: const Text('Syrius 0.3.0 is out', key: _notice),
      );
      rig.pow.add(PowStatus.generating);
      await tester.pump();
      await tester.pump(const Duration(seconds: 14));
      expect(tester.takeException(), isNull);
      expect(_drawn(_sync), isTrue);
      expect(_drawn(_height), isTrue);
      expect(_drawn(_behind), isTrue);
      expect(_drawn(_plasma), isTrue);
      expect(_drawn(_elapsed), isTrue);
      expect(
        tester.getRect(find.byType(StatusStrip)).width,
        _narrowest,
      );
      rig.pow.add(PowStatus.done);
      await tester.pump();
    }
  });
}
