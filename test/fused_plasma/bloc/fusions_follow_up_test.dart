import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

typedef _Fusions = InfiniteListState<FusionEntryWrapper>;
typedef _Levels = InfiniteListState<PlasmaInfoWrapper>;

class _MockFusedPlasmaBloc extends MockBloc<InfiniteListEvent, _Fusions>
    implements FusedPlasmaBloc {}

class _MockPlasmaStatsBloc extends MockBloc<InfiniteListEvent, _Levels>
    implements PlasmaStatsBloc {}

/// A fusion for the selected address ([emptyAddress] here), or for
/// [beneficiary].
FusionEntryWrapper _entry(int n, {Address? beneficiary}) => FusionEntryWrapper(
  fusionEntry: FusionEntry(
    beneficiary: beneficiary ?? emptyAddress,
    expirationHeight: 10,
    id: Hash.fromBytes(List<int>.filled(Hash.length, n)),
    qsrAmount: BigInt.from(10),
  ),
  isRevocable: false,
);

_Fusions _loaded(List<int> ids, {Address? beneficiary}) => _Fusions(
  status: InfiniteListStatus.success,
  data: ids.map((int n) => _entry(n, beneficiary: beneficiary)).toList(),
  hasReachedMax: true,
);

/// The levels with [qsr] fused for the selected address.
_Levels _stats(int qsr) => _Levels(
  status: InfiniteListStatus.success,
  data: <PlasmaInfoWrapper>[
    PlasmaInfoWrapper(
      address: emptyAddress.toString(),
      plasmaInfo: PlasmaInfo(
        currentPlasma: qsr * 2100,
        maxPlasma: qsr * 2100,
        qsrAmount: BigInt.from(qsr),
      ),
    ),
  ],
  hasReachedMax: true,
);

// testWidgets runs in a fake clock: pump(d) moves it on by d and fires the
// timers due in between, so a minute of reloads takes no real time.
void main() {
  setUpAll(() {
    registerFallbackValue(const InfiniteListRequested());
  });

  late _MockFusedPlasmaBloc fusions;
  late _MockPlasmaStatsBloc levels;
  late StreamController<_Fusions> fusionStates;
  late StreamController<_Levels> levelStates;
  late List<InfiniteListEvent> fusionEvents;
  late List<InfiniteListEvent> levelEvents;
  late FusionsFollowUp followUp;

  void setUpBlocs(_Fusions initial, {_Levels? initialLevels}) {
    fusions = _MockFusedPlasmaBloc();
    levels = _MockPlasmaStatsBloc();
    fusionStates = StreamController<_Fusions>.broadcast();
    levelStates = StreamController<_Levels>.broadcast();
    fusionEvents = <InfiniteListEvent>[];
    levelEvents = <InfiniteListEvent>[];
    whenListen(fusions, fusionStates.stream, initialState: initial);
    whenListen(
      levels,
      levelStates.stream,
      initialState: initialLevels ?? _stats(10),
    );
    when(() => fusions.add(any())).thenAnswer(
      (Invocation i) => fusionEvents.add(i.positionalArguments.single),
    );
    when(() => levels.add(any())).thenAnswer(
      (Invocation i) => levelEvents.add(i.positionalArguments.single),
    );
    followUp = FusionsFollowUp(
      fusions: fusions,
      levels: levels,
      address: () => emptyAddress,
    );
    addTearDown(() async {
      followUp.dispose();
      await fusionStates.close();
      await levelStates.close();
    });
  }

  /// The list as a reload would bring it back.
  Future<void> emit(WidgetTester tester, _Fusions state) async {
    fusionStates.add(state);
    await tester.pump();
  }

  /// The levels as a reload would bring them back.
  Future<void> emitLevels(WidgetTester tester, _Levels state) async {
    levelStates.add(state);
    await tester.pump();
  }

  testWidgets('a fuse reloads both at once and at 10, 20, 40 and 60 s', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    expect(fusionEvents, hasLength(1));
    expect(levelEvents, hasLength(1));

    for (final (int seconds, int reloads) in <(int, int)>[
      (10, 2),
      (10, 3),
      (20, 4),
      (20, 5),
    ]) {
      await tester.pump(Duration(seconds: seconds));
      // The same list comes back: the contract has not received it yet.
      await emit(tester, _loaded(<int>[1]));
      await emitLevels(tester, _stats(10));
      expect(fusionEvents, hasLength(reloads));
      expect(levelEvents, hasLength(reloads));
    }
    expect(followUp.isRunning, isFalse);

    await tester.pump(const Duration(minutes: 5));
    expect(fusionEvents, hasLength(5));
    expect(levelEvents, hasLength(5));
  });

  testWidgets('reloads keep the rows and the figures: never a refresh', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 60));

    // InfiniteListRefreshRequested empties the state first, which shows the
    // loading bars; every reload here must leave the rows standing.
    expect(fusionEvents, everyElement(isA<InfiniteListRequested>()));
    expect(levelEvents, everyElement(isA<InfiniteListRequested>()));
    expect(
      fusionEvents.map((InfiniteListEvent e) => e.address),
      everyElement(emptyAddress),
    );
  });

  testWidgets('the list changes at 20 s and the levels at 40 s: the levels '
      'reload until 40 s', (WidgetTester tester) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[1]));
    await emitLevels(tester, _stats(10));
    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[2, 1]));
    // The levels a momentum behind the list.
    await emitLevels(tester, _stats(10));

    expect(followUp.isRunning, isTrue);
    expect(fusionEvents, hasLength(3));
    // Now, 10 s and 20 s, and one more after the list changed.
    expect(levelEvents, hasLength(4));

    await tester.pump(const Duration(seconds: 20));
    // At 40 s the levels alone are reloaded, and now show the fusion.
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(5));
    await emitLevels(tester, _stats(20));
    expect(followUp.isRunning, isFalse);

    await tester.pump(const Duration(seconds: 60));
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(5));
  });

  testWidgets('levels that never change are reloaded until 60 s', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 20));
    await emit(tester, _loaded(<int>[2, 1]));
    expect(levelEvents, hasLength(4));

    await tester.pump(const Duration(seconds: 20));
    await emitLevels(tester, _stats(10));
    expect(levelEvents, hasLength(5));
    await tester.pump(const Duration(seconds: 20));
    await emitLevels(tester, _stats(10));
    expect(levelEvents, hasLength(6));
    expect(followUp.isRunning, isFalse);

    await tester.pump(const Duration(minutes: 5));
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(6));
  });

  testWidgets('a fuse for another address ends the levels with the list', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1], beneficiary: pillarAddress));
    followUp.start();
    await tester.pump(const Duration(seconds: 20));
    await emit(tester, _loaded(<int>[2, 1], beneficiary: pillarAddress));

    // The selected address's levels cannot move; they are read once more
    // for the beneficiary's own row, and the reloads end.
    expect(followUp.isRunning, isFalse);
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(4));
    await tester.pump(const Duration(seconds: 60));
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(4));
  });

  testWidgets('a cancel stops once its fusion is gone and the fused QSR '
      'dropped', (WidgetTester tester) async {
    setUpBlocs(_loaded(<int>[1, 2]), initialLevels: _stats(20));
    followUp.start();
    await tester.pump(const Duration(seconds: 20));
    await emit(tester, _loaded(<int>[2]));
    expect(followUp.isRunning, isTrue);
    await emitLevels(tester, _stats(10));

    expect(followUp.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 60));
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(4));
  });

  testWidgets('levels that change first wait for the list', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 10));
    await emitLevels(tester, _stats(20));
    await emit(tester, _loaded(<int>[1]));
    expect(followUp.isRunning, isTrue);

    await tester.pump(const Duration(seconds: 10));
    // The levels are done: only the list is reloaded.
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(2));
    await emit(tester, _loaded(<int>[2, 1]));
    expect(followUp.isRunning, isFalse);
  });

  testWidgets('the first loaded list is not a change', (
    WidgetTester tester,
  ) async {
    // Fused before the list had loaded: its first rows are the baseline.
    setUpBlocs(const _Fusions.initial());
    followUp.start();
    await emit(tester, _loaded(<int>[1]));
    expect(followUp.isRunning, isTrue);

    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[2, 1]));
    await emitLevels(tester, _stats(20));
    expect(followUp.isRunning, isFalse);
    expect(fusionEvents, hasLength(2));
  });

  testWidgets('the first loaded levels are not a change', (
    WidgetTester tester,
  ) async {
    setUpBlocs(_loaded(<int>[1]), initialLevels: const _Levels.initial());
    followUp.start();
    await emitLevels(tester, _stats(10));
    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[2, 1]));
    expect(followUp.isRunning, isTrue);

    await emitLevels(tester, _stats(20));
    expect(followUp.isRunning, isFalse);
  });

  testWidgets('two fuses wait for both fusions', (WidgetTester tester) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 5));
    followUp.start();
    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[2, 1]));
    await emitLevels(tester, _stats(20));
    expect(followUp.isRunning, isTrue);

    await tester.pump(const Duration(seconds: 10));
    await emit(tester, _loaded(<int>[3, 2, 1]));
    expect(followUp.isRunning, isTrue);
    await emitLevels(tester, _stats(30));
    expect(followUp.isRunning, isFalse);
  });

  testWidgets('dispose stops the reloads', (WidgetTester tester) async {
    setUpBlocs(_loaded(<int>[1]));
    followUp.start();
    await tester.pump(const Duration(seconds: 20));
    await emit(tester, _loaded(<int>[2, 1]));
    // The list has its change; the levels are still being waited for.
    expect(followUp.isRunning, isTrue);
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(4));

    await tester.pump(const Duration(seconds: 10));
    followUp.dispose();
    expect(followUp.isRunning, isFalse);
    await tester.pump(const Duration(minutes: 2));
    await emitLevels(tester, _stats(20));
    expect(fusionEvents, hasLength(3));
    expect(levelEvents, hasLength(4));
  });
}
