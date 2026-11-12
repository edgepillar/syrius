import 'dart:async';
import 'dart:ui' as ui show AppLifecycleState;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/app/agent.dart';
import '../../harness/app/capture_frame.dart';

Future<void> _turns() async {
  for (int turn = 0; turn < 8; turn++) {
    await Future<void>.value();
  }
}

Matcher _agentRefusal([
  CaptureFrameRefusalReason reason = CaptureFrameRefusalReason.deadline,
]) => throwsA(
  isA<HarnessError>().having(
    (HarnessError error) => error.message,
    'message',
    'the original capture frame is unavailable',
  ).having(
    (HarnessError error) => error.detail,
    'finite capture refusal',
    <String, String>{'capture_frame_refusal': reason.name},
  ),
);

Map<String, dynamic> _shot() => <String, dynamic>{
  'cmd': 'shot',
  'expect': <String, Object?>{'key': 'synthetic_capture_marker'},
  'theme': 'dark',
  'width': 1280,
  'height': 780,
};

void main() {
  testWidgets('passive callback facts distinguish a delivered frame '
      'from the retained pending original', (WidgetTester tester) async {
    final TestWidgetsFlutterBinding binding = tester.binding;
    for (final bool delivered in <bool>[false, true]) {
      final Completer<void> frame = Completer<void>();
      final Completer<void> deadline = Completer<void>();
      int readbacks = 0;
      final bool scheduledBefore = binding.hasScheduledFrame;
      final CaptureFrameGate gate = HarnessAgent.captureFrameGateForBinding(
        binding,
        waitForFrame: () => frame.future,
        waitUntilDeadline: () => deadline.future,
      );
      expect(binding.hasScheduledFrame, scheduledBefore);
      final Future<void> refusal = expectLater(
        gate.capture<void>(() async { readbacks++; }),
        throwsA(isA<CaptureFrameRefused>()),
      );
      final CaptureFrameReceipt original = gate.receipt!;
      expect(original.original, same(frame.future));
      expect(original.refusalState, isNull);
      if (delivered) await tester.pump();
      deadline.complete();
      await refusal;
      final CaptureFrameState state = original.refusalState!;
      expect(state.persistentCallbacksObserved, delivered ? 1 : 0);
      expect(state.beginFrameCallbackRegistered,
        binding.platformDispatcher.onBeginFrame != null);
      expect(state.drawFrameCallbackRegistered,
        binding.platformDispatcher.onDrawFrame != null);
      expect(state.toJson()['schema'], 2);
      expect(readbacks, 0);
      expect(original.outcome, isNull);
      frame.complete();
      await original.completion;
      await tester.pump();
      expect(original.refusalState, same(state));
      expect(state.persistentCallbacksObserved, delivered ? 1 : 0);
      expect(original.status, CaptureFrameStatus.held);
      expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
      expect(readbacks, 0);
    }
  });

  test('callback observations preserve legacy absence and refuse '
      'unbounded or foreign values', () {
    final CaptureFrameCallbackCounter callbacks =
        CaptureFrameCallbackCounter()..begin();
    expect(callbacks.value, 0);
    callbacks.observe();
    expect(callbacks.value, 1);
    for (int i = 1; i < CaptureFrameCallbackCounter.maxCallbacks; i++) {
      callbacks.observe();
    }
    expect(callbacks.value, CaptureFrameCallbackCounter.maxCallbacks);
    callbacks.observe();
    expect(callbacks.value, 'unknown');
    callbacks.observe();
    expect(callbacks.value, 'unknown');
    callbacks.begin();
    expect(callbacks.value, 0);
    final Map<String, Object> legacy = <String, Object>{
      'schema': 1, 'scheduler_phase': 'idle', 'lifecycle_state': 'none',
      'frames_enabled': true, 'has_scheduled_frame': true,
      'binding_current': true,
    };
    final CaptureFrameState retained = CaptureFrameState.fromJson(legacy)!;
    expect(retained.toJson(), legacy);
    expect(retained.persistentCallbacksObserved, isNull);
    final Map<String, Object> progress = <String, Object>{
      ...legacy, 'schema': 2, 'begin_frame_callback_registered': true,
      'draw_frame_callback_registered': true,
      'persistent_callbacks_observed': 0,
    };
    for (final Object count in <Object>[0, 1, 65535, 'unknown']) {
      final Map<String, Object> value = <String, Object>{
        ...progress, 'persistent_callbacks_observed': count,
      };
      expect(CaptureFrameState.fromJson(value)!.toJson(), value);
    }
    for (final Object? count in <Object?>[
      true, false, -1, 65536, 0.0, null, 'Synthetic private frame',
    ]) {
      expect(CaptureFrameState.fromJson(<String, Object?>{
        ...progress, 'persistent_callbacks_observed': count,
      }), isNull);
    }
    for (final String key in progress.keys) {
      final Map<String, Object> missing = Map<String, Object>.from(progress)
        ..remove(key);
      expect(CaptureFrameState.fromJson(missing), isNull);
    }
    expect(CaptureFrameState.fromJson(<String, Object>{
      ...progress, 'begin_frame_callback_registered': 1,
    }), isNull);
    expect(CaptureFrameState.fromJson(<String, Object>{
      ...progress,
      'draw_frame_callback_registered': 'Synthetic private callback',
    }), isNull);
    expect(CaptureFrameState.fromJson(<String, Object>{
      ...progress, 'private_path': 'Synthetic private source',
    }), isNull);
  });

  testWidgets('post-frame admission requests its own next original frame', (
    WidgetTester tester,
  ) async {
    final TestWidgetsFlutterBinding binding = tester.binding;
    final Completer<void> deadline = Completer<void>();
    SchedulerPhase? requestedPhase;
    int readbacks = 0;
    Future<String>? capture;
    final CaptureFrameGate gate = CaptureFrameGate.scheduled(
      requestFrame: () {
        requestedPhase = binding.schedulerPhase;
        binding.scheduleFrame();
      },
      waitForFrame: () => binding.endOfFrame,
      waitUntilDeadline: () => deadline.future,
    );
    binding
      ..addPostFrameCallback((_) {
        capture = gate.capture<String>(() async {
          readbacks++;
          return 'original pixels';
        });
      })
      ..scheduleFrame();
    await tester.pump();
    expect(requestedPhase, SchedulerPhase.postFrameCallbacks);
    expect(binding.hasScheduledFrame, isTrue);
    expect(gate.receipt!.status, CaptureFrameStatus.pending);
    expect(readbacks, 0);
    await tester.pump();
    expect(await capture, 'original pixels');
    expect((await gate.receipt!.completion).completed, isTrue);
    expect(gate.receipt!.timedOut, isFalse);
    expect(readbacks, 1);
    deadline.complete();
    await _turns();

    final Completer<void> pausedDeadline = Completer<void>();
    int stateReads = 0;
    final CaptureFrameGate paused = CaptureFrameGate.scheduled(
      requestFrame: binding.scheduleFrame,
      waitForFrame: () => binding.endOfFrame,
      observeState: () {
        stateReads++;
        return HarnessAgent.captureFrameStateForBinding(binding);
      },
      waitUntilDeadline: () => pausedDeadline.future,
    );
    addTearDown(() => binding.handleAppLifecycleStateChanged(
      ui.AppLifecycleState.resumed,
    ));
    binding.handleAppLifecycleStateChanged(ui.AppLifecycleState.paused);
    final Future<void> pausedRefusal = expectLater(
      paused.capture<void>(() async => fail('Paused readback was admitted')),
      throwsA(isA<CaptureFrameRefused>()),
    );
    final CaptureFrameReceipt pausedOriginal = paused.receipt!;
    expect(pausedOriginal.refusalState, isNull);
    expect(stateReads, 0);
    pausedDeadline.complete();
    await pausedRefusal;
    final CaptureFrameState pausedState = pausedOriginal.refusalState!;
    expect(pausedState.lifecycleState, 'paused');
    expect(pausedState.framesEnabled, isFalse);
    expect(pausedState.bindingCurrent, isTrue);
    expect(pausedOriginal.outcome, isNull);
    expect(stateReads, 1);
    binding.handleAppLifecycleStateChanged(ui.AppLifecycleState.resumed);
    await tester.pump();
    expect((await pausedOriginal.completion).completed, isTrue);
    expect(pausedOriginal.refusalState, same(pausedState));
    expect(pausedOriginal.refusalState!.framesEnabled, isFalse);
    expect(pausedOriginal.status, CaptureFrameStatus.held);
    expect(await pausedOriginal.admission, isFalse);
    expect(stateReads, 1);
  });

  test('scheduled admission retains one original '
      'through pending readback', () async {
    final Completer<void> frame = Completer<void>();
    final Completer<void> deadline = Completer<void>();
    final Completer<String> pixels = Completer<String>();
    int requests = 0;
    int waits = 0;
    int readbacks = 0;
    int stateReads = 0;
    final CaptureFrameGate gate = CaptureFrameGate.scheduled(
      requestFrame: () => requests++,
      waitForFrame: () {
        waits++;
        return frame.future;
      },
      waitUntilDeadline: () => deadline.future,
      observeState: () {
        stateReads++;
        return null;
      },
    );
    final Future<String> capture = gate.capture<String>(() {
      readbacks++;
      return pixels.future;
    });
    final CaptureFrameReceipt original = gate.receipt!;
    expect(original.original, same(frame.future));
    expect(readbacks, 0);
    frame.complete();
    await _turns();
    expect(readbacks, 1);
    expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
    expect(gate.refusalReason, CaptureFrameRefusalReason.busy);
    await expectLater(gate.capture<String>(() async => 'replacement pixels'),
        throwsA(isA<CaptureFrameRefused>()));
    expect(gate.receipt, same(original));
    expect(requests, 1);
    expect(waits, 1);
    pixels.complete('original pixels');
    expect(await capture, 'original pixels');
    expect(gate.requireIdle, returnsNormally);
    expect(gate.refusalReason, isNull);
    expect(gate.receipt!.refusalState, isNull);
    expect(stateReads, 0);
    deadline.complete();
    await _turns();
  });

  test('an original scheduling failure retains its error '
      'before any wait', () async {
    final Object failure = StateError('Synthetic scheduling failure');
    final StackTrace trace = StackTrace.current;
    int requests = 0;
    int waits = 0;
    int deadlines = 0;
    int stateReads = 0;
    final CaptureFrameGate gate = CaptureFrameGate.scheduled(
      requestFrame: () {
        requests++;
        Error.throwWithStackTrace(failure, trace);
      },
      observeState: () {
        stateReads++;
        throw StateError('Synthetic private diagnostic failure');
      },
      waitForFrame: () {
        waits++;
        return Future<void>.value();
      },
      waitUntilDeadline: () {
        deadlines++;
        return Future<void>.value();
      },
    );
    await expectLater(
      gate.capture<void>(() async => fail('Readback was admitted')),
      throwsA(isA<CaptureFrameRefused>()),
    );
    final CaptureFrameReceipt original = gate.receipt!;
    final CaptureFrameOutcome outcome = await original.completion;
    expect(original.original, isNull);
    expect(outcome.error, same(failure));
    expect(outcome.stackTrace.toString(), trace.toString());
    expect(original.timedOut, isFalse);
    expect(gate.heldUnknown, isTrue);
    expect(gate.refusalReason, CaptureFrameRefusalReason.originalFailure);
    await expectLater(
      gate.capture<void>(() async => fail('Readback was retried')),
      throwsA(isA<CaptureFrameRefused>()),
    );
    expect(gate.receipt, same(original));
    expect(requests, 1);
    expect(waits, 0);
    expect(deadlines, 0);
    expect(stateReads, 1);
    expect(gate.receipt!.refusalState, isNull);
  });

  testWidgets('a requested late frame cannot clear the actual 250 ms hold', (
    WidgetTester tester,
  ) async {
    final Completer<void> frame = Completer<void>();
    int requests = 0;
    int readbacks = 0;
    final CaptureFrameGate gate = CaptureFrameGate.scheduled(
      requestFrame: () => requests++,
      waitForFrame: () => frame.future,
    );
    final Future<void> refused = expectLater(gate.capture<void>(() async {
      readbacks++;
    }), throwsA(isA<CaptureFrameRefused>()));
    final CaptureFrameReceipt original = gate.receipt!;
    await tester.pump(const Duration(milliseconds: 250));
    await refused;
    expect(original.timedOut, isTrue);
    expect(original.outcome, isNull);
    expect(gate.refusalReason, CaptureFrameRefusalReason.deadline);
    frame.complete();
    await _turns();
    expect((await original.completion).completed, isTrue);
    expect(original.status, CaptureFrameStatus.held);
    expect(await original.admission, isFalse);
    expect(gate.refusalReason, CaptureFrameRefusalReason.deadline);
    await expectLater(
      gate.capture<void>(() async => fail('Readback was retried')),
      throwsA(isA<CaptureFrameRefused>()),
    );
    expect(gate.receipt, same(original));
    expect(requests, 1);
    expect(readbacks, 0);
  });

  test('pending frame reserves admission before any readback', () async {
    final Completer<void> frame = Completer<void>();
    final Completer<void> deadline = Completer<void>();
    int waits = 0;
    int readbacks = 0;
    final CaptureFrameGate gate = CaptureFrameGate(
      waitForFrame: () {
        waits++;
        return frame.future;
      },
      waitUntilDeadline: () => deadline.future,
    );
    final Future<String> capture = gate.capture<String>(() async {
      readbacks++;
      return 'original pixels';
    });
    final CaptureFrameReceipt receipt = gate.receipt!;
    bool completed = false;
    unawaited(receipt.completion.then<void>((_) => completed = true));
    await _turns();
    expect(receipt.original, same(frame.future));
    expect(receipt.status, CaptureFrameStatus.pending);
    expect(receipt.outcome, isNull);
    expect(completed, isFalse);
    expect(readbacks, 0);
    expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
    await expectLater(
      gate.capture<String>(() async {
        readbacks++;
        return 'replacement pixels';
      }),
      throwsA(isA<CaptureFrameRefused>()),
    );
    expect(gate.receipt, same(receipt));
    expect(waits, 1);
    frame.complete();
    expect(await capture, 'original pixels');
    expect(await receipt.admission, isTrue);
    final CaptureFrameOutcome outcome = await receipt.completion;
    expect(outcome.completed, isTrue);
    expect(outcome.error, isNull);
    expect(outcome.stackTrace, isNull);
    expect(receipt.status, CaptureFrameStatus.ready);
    expect(readbacks, 1);
    expect(gate.requireIdle, returnsNormally);
    deadline.complete();
    await _turns();
    expect(receipt.timedOut, isFalse);
    expect(gate.heldUnknown, isFalse);
  });

  testWidgets('the actual 250 ms deadline never completes the frame', (
    WidgetTester tester,
  ) async {
    final Completer<void> frame = Completer<void>();
    int readbacks = 0;
    final CaptureFrameGate gate = CaptureFrameGate(
      waitForFrame: () => frame.future,
    );
    final Future<void> refusal = expectLater(
      gate.capture<void>(() async {
        readbacks++;
      }),
      throwsA(isA<CaptureFrameRefused>()),
    );
    final CaptureFrameReceipt receipt = gate.receipt!;
    await tester.pump(const Duration(milliseconds: 249));
    expect(receipt.status, CaptureFrameStatus.pending);
    expect(receipt.timedOut, isFalse);
    expect(receipt.outcome, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    await refusal;
    expect(receipt.status, CaptureFrameStatus.held);
    expect(receipt.timedOut, isTrue);
    expect(receipt.outcome, isNull);
    expect(readbacks, 0);
    frame.complete();
    await tester.pump();
    expect((await receipt.completion).completed, isTrue);
    expect(receipt.status, CaptureFrameStatus.held);
    expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
    expect(readbacks, 0);
  });

  for (final bool lateFailure in <bool>[false, true]) {
    test('timeout retains the late original, failure $lateFailure', () async {
      final Completer<void> frame = Completer<void>();
      final Completer<void> deadline = Completer<void>();
      final Object failure = StateError('Synthetic original frame failed');
      final StackTrace trace = StackTrace.current;
      Object? receivedError;
      StackTrace? receivedTrace;
      unawaited(
        frame.future.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            receivedError = error;
            receivedTrace = stack;
          },
        ),
      );
      int readbacks = 0;
      int stateReads = 0;
      final Map<String, Object> state = <String, Object>{
        'schema': 1, 'scheduler_phase': 'idle', 'lifecycle_state': 'paused',
        'frames_enabled': false, 'has_scheduled_frame': false,
        'binding_current': true,
      };
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => frame.future,
        waitUntilDeadline: () => deadline.future,
        observeState: () {
          stateReads++;
          return CaptureFrameState.fromJson(state);
        },
      );
      final Future<void> refusal = expectLater(
        gate.capture<String>(() async {
          readbacks++;
          return 'unadmitted pixels';
        }),
        throwsA(isA<CaptureFrameRefused>()),
      );
      final CaptureFrameReceipt receipt = gate.receipt!;
      final Future<CaptureFrameOutcome> completion = receipt.completion;
      deadline.complete();
      await refusal;
      expect(await receipt.admission, isFalse);
      expect(receipt.original, same(frame.future));
      expect(receipt.status, CaptureFrameStatus.held);
      expect(receipt.timedOut, isTrue);
      expect(gate.refusalReason, CaptureFrameRefusalReason.deadline);
      expect(receipt.outcome, isNull);
      expect(gate.heldUnknown, isTrue);
      expect(readbacks, 0);
      final CaptureFrameState firstState = receipt.refusalState!;
      expect(firstState.toJson(), state);
      expect(stateReads, 1);
      state['lifecycle_state'] = 'resumed';
      state['frames_enabled'] = true;
      expect(() => firstState.toJson()['frames_enabled'] = true,
        throwsUnsupportedError,
      );
      if (lateFailure) {
        frame.completeError(failure, trace);
      } else {
        frame.complete();
      }
      final CaptureFrameOutcome outcome = await completion;
      expect(outcome.completed, !lateFailure);
      if (lateFailure) {
        expect(outcome.error, same(failure));
        expect(outcome.error, same(receivedError));
        expect(outcome.stackTrace, same(receivedTrace));
        expect(outcome.stackTrace.toString(), trace.toString());
      } else {
        expect(outcome.error, isNull);
        expect(outcome.stackTrace, isNull);
      }
      expect(receipt.outcome, same(outcome));
      expect(receipt.completion, same(completion));
      expect(receipt.status, CaptureFrameStatus.held);
      expect(await receipt.admission, isFalse);
      expect(gate.refusalReason, CaptureFrameRefusalReason.deadline);
      await expectLater(
        gate.capture<String>(() async => 'replacement pixels'),
        throwsA(isA<CaptureFrameRefused>()),
      );
      expect(gate.receipt, same(receipt));
      expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
      expect(readbacks, 0);
      expect(receipt.refusalState, same(firstState));
      expect(firstState.lifecycleState, 'paused');
      expect(firstState.framesEnabled, isFalse);
      expect(stateReads, 1);
    });
  }

  test(
    'original failure holds before the deadline with its exact trace',
    () async {
      final Completer<void> frame = Completer<void>();
      final Completer<void> deadline = Completer<void>();
      final Object failure = StateError('Synthetic frame completion failed');
      final StackTrace trace = StackTrace.current;
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => frame.future,
        waitUntilDeadline: () => deadline.future,
      );
      final Future<void> refusal = expectLater(
        gate.capture<void>(() async => fail('Readback was admitted')),
        throwsA(isA<CaptureFrameRefused>()),
      );
      final CaptureFrameReceipt receipt = gate.receipt!;
      frame.completeError(failure, trace);
      await refusal;
      final CaptureFrameOutcome outcome = await receipt.completion;
      expect(outcome.completed, isFalse);
      expect(outcome.error, same(failure));
      expect(outcome.stackTrace.toString(), trace.toString());
      expect(receipt.timedOut, isFalse);
      expect(gate.heldUnknown, isTrue);
      expect(gate.refusalReason, CaptureFrameRefusalReason.originalFailure);
      deadline.complete();
      await _turns();
      expect(receipt.outcome, same(outcome));
      expect(receipt.timedOut, isFalse);
      expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
    },
  );

  test(
    'synchronous frame throw retains no manufactured original Future',
    () async {
      final Object failure = StateError('Synthetic frame callback failed');
      final StackTrace trace = StackTrace.current;
      int deadlines = 0;
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => Error.throwWithStackTrace(failure, trace),
        waitUntilDeadline: () {
          deadlines++;
          return Future<void>.value();
        },
      );
      await expectLater(
        gate.capture<void>(() async => fail('Readback was admitted')),
        throwsA(isA<CaptureFrameRefused>()),
      );
      final CaptureFrameReceipt receipt = gate.receipt!;
      final CaptureFrameOutcome outcome = await receipt.completion;
      expect(receipt.original, isNull);
      expect(outcome.completed, isFalse);
      expect(outcome.error, same(failure));
      expect(outcome.stackTrace.toString(), trace.toString());
      expect(deadlines, 0);
      expect(gate.heldUnknown, isTrue);
    },
  );

  for (final bool synchronous in <bool>[false, true]) {
    test('failed admission clock holds, synchronous $synchronous', () async {
      final Completer<void> frame = Completer<void>();
      final Completer<void> deadline = Completer<void>();
      final Object failure = StateError('Synthetic admission clock failed');
      final StackTrace trace = StackTrace.current;
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => frame.future,
        waitUntilDeadline: () {
          if (synchronous) {
            Error.throwWithStackTrace(failure, trace);
          }
          return deadline.future;
        },
      );
      final Future<void> refusal = expectLater(
        gate.capture<void>(() async => fail('Readback was admitted')),
        throwsA(isA<CaptureFrameRefused>()),
      );
      final CaptureFrameReceipt receipt = gate.receipt!;
      if (!synchronous) {
        deadline.completeError(failure, trace);
      }
      await refusal;
      expect(receipt.original, same(frame.future));
      expect(receipt.outcome, isNull);
      expect(receipt.admissionError, same(failure));
      expect(receipt.admissionStackTrace.toString(), trace.toString());
      expect(receipt.timedOut, isFalse);
      expect(gate.refusalReason, CaptureFrameRefusalReason.admissionFailure);
      frame.complete();
      expect((await receipt.completion).completed, isTrue);
      expect(receipt.status, CaptureFrameStatus.held);
      expect(gate.heldUnknown, isTrue);
      expect(gate.refusalReason, CaptureFrameRefusalReason.admissionFailure);
      expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
    });
  }

  test('reentrant frame callback cannot reserve a second original', () async {
    final Completer<void> frame = Completer<void>();
    final Completer<void> deadline = Completer<void>();
    late final CaptureFrameGate gate;
    Future<void>? nested;
    Object? nestedError;
    int waits = 0;
    int readbacks = 0;
    gate = CaptureFrameGate(
      waitForFrame: () {
        waits++;
        expect(gate.receipt, isNotNull);
        expect(gate.receipt!.original, isNull);
        expect(gate.refusalReason, CaptureFrameRefusalReason.busy);
        nested = gate
            .capture<void>(() async {
              fail('Nested readback was admitted');
            })
            .then<void>(
              (_) => fail('Nested capture was admitted'),
              onError: (Object error, StackTrace _) {
                nestedError = error;
              },
            );
        return frame.future;
      },
      waitUntilDeadline: () => deadline.future,
    );
    final Future<String> capture = gate.capture<String>(() async {
      readbacks++;
      return 'original pixels';
    });
    await nested;
    expect(nestedError, isA<CaptureFrameRefused>());
    expect(waits, 1);
    expect(readbacks, 0);
    frame.complete();
    expect(await capture, 'original pixels');
    expect(readbacks, 1);
    deadline.complete();
    await _turns();
    expect(gate.heldUnknown, isFalse);
  });

  test(
    'positive frame keeps admission busy through original readback',
    () async {
      final Completer<void> frame = Completer<void>();
      final Completer<void> deadline = Completer<void>();
      final Completer<String> pixels = Completer<String>();
      int readbacks = 0;
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => frame.future,
        waitUntilDeadline: () => deadline.future,
      );
      final Future<String> capture = gate.capture<String>(() {
        readbacks++;
        expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
        return pixels.future;
      });
      final CaptureFrameReceipt receipt = gate.receipt!;
      frame.complete();
      await _turns();
      expect((await receipt.completion).completed, isTrue);
      expect(readbacks, 1);
      expect(gate.requireIdle, throwsA(isA<CaptureFrameRefused>()));
      await expectLater(
        gate.capture<String>(() async => 'replacement pixels'),
        throwsA(isA<CaptureFrameRefused>()),
      );
      pixels.complete('original pixels');
      expect(await capture, 'original pixels');
      expect(gate.requireIdle, returnsNormally);
      deadline.complete();
    },
  );

  test(
    'a prior positive receipt cannot hold the next frame admission',
    () async {
      final List<Completer<void>> frames = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
      ];
      final List<Completer<void>> deadlines = <Completer<void>>[
        Completer<void>(),
        Completer<void>(),
      ];
      int calls = 0;
      final CaptureFrameGate gate = CaptureFrameGate(
        waitForFrame: () => frames[calls++].future,
        waitUntilDeadline: () => deadlines[calls - 1].future,
      );
      final Future<String> first = gate.capture<String>(
        () async => 'first original pixels',
      );
      final CaptureFrameReceipt previous = gate.receipt!;
      frames.first.complete();
      expect(await first, 'first original pixels');
      final Future<String> second = gate.capture<String>(
        () async => 'second original pixels',
      );
      final CaptureFrameReceipt current = gate.receipt!;
      expect(current, isNot(same(previous)));
      deadlines.first.complete();
      await _turns();
      expect(current.status, CaptureFrameStatus.pending);
      expect(gate.heldUnknown, isFalse);
      frames.last.complete();
      expect(await second, 'second original pixels');
      expect(previous.original, same(frames.first.future));
      expect(previous.outcome!.completed, isTrue);
      expect(current.original, same(frames.last.future));
      expect(current.outcome!.completed, isTrue);
      expect(gate.requireIdle, returnsNormally);
      deadlines.last.complete();
    },
  );

  for (final bool lateFailure in <bool>[false, true]) {
    test(
      'agent blocks readback and theme after timeout, error $lateFailure',
      () async {
        final Completer<void> frame = Completer<void>();
        final Completer<void> deadline = Completer<void>();
        final Object failure = StateError('Synthetic late frame failure');
        final StackTrace trace = StackTrace.current;
        int waits = 0;
        final HarnessAgent agent = HarnessAgent.forTest(
          waitForCaptureFrame: () {
            waits++;
            return frame.future;
          },
          waitForCaptureFrameDeadline: () => deadline.future,
        );
        final Future<void> refusal = expectLater(
          agent.commandForTest(_shot()),
          _agentRefusal(),
        );
        final CaptureFrameReceipt receipt = agent.captureFrameForTest!;
        for (final Map<String, dynamic> command in <Map<String, dynamic>>[
          _shot(),
          <String, dynamic>{'cmd': 'shot'},
          <String, dynamic>{'cmd': 'theme', 'mode': 'light'},
          <String, dynamic>{
            'cmd': 'theme',
            'restore': <String, Object?>{'mode': 'dark'},
          },
        ]) {
          await expectLater(
            agent.commandForTest(command),
            _agentRefusal(CaptureFrameRefusalReason.busy),
          );
        }
        expect(waits, 1);
        expect(receipt.outcome, isNull);
        deadline.complete();
        await refusal;
        expect(receipt.status, CaptureFrameStatus.held);
        expect(receipt.outcome, isNull);
        if (lateFailure) {
          frame.completeError(failure, trace);
        } else {
          frame.complete();
        }
        final CaptureFrameOutcome outcome = await receipt.completion;
        expect(outcome.completed, !lateFailure);
        if (lateFailure) {
          expect(outcome.error, same(failure));
          expect(outcome.stackTrace.toString(), trace.toString());
        } else {
          expect(outcome.error, isNull);
        }
        await expectLater(agent.commandForTest(_shot()), _agentRefusal());
        await expectLater(
          agent.commandForTest(<String, dynamic>{
            'cmd': 'theme',
            'mode': 'light',
          }),
          _agentRefusal(),
        );
        expect(agent.captureFrameForTest, same(receipt));
        expect(receipt.original, same(frame.future));
        expect(receipt.status, CaptureFrameStatus.held);
        expect(waits, 1);
      },
    );
  }
}
