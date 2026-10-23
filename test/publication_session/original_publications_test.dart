import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/original_publications.dart';

void main() {
  test(
    'the SDK lane retains an original after its wallet file is replaced',
    () async {
      final Object file = Object();
      final Object replacementFile = Object();
      final Object sdk = Object();
      final Object accepted = Object();
      final Completer<Object> reply = Completer<Object>();
      addTearDown(() {
        if (!reply.isCompleted) reply.complete(accepted);
      });
      late Future<OriginalPublicationDrain> sdkDrain;
      final Future<Object> original = OriginalPublications.runForOwners<Object>(
        <Object>[file, sdk, file],
        (OriginalPublication<Object> operation) {
          operation.retainPublicationHash('original-hash');
          sdkDrain = OriginalPublications.pauseAndDrain(sdk);
          return reply.future;
        },
      );
      expect(original, same(reply.future));
      expect(OriginalPublications.snapshot(file), hasLength(1));
      expect(
        OriginalPublications.snapshot(sdk).single,
        same(OriginalPublications.snapshot(file).single),
      );
      expect(OriginalPublications.canChangeTransport(replacementFile), isTrue);
      expect(OriginalPublications.canChangeTransport(sdk), isFalse);
      bool drained = false;
      unawaited(sdkDrain.then<void>((_) => drained = true));
      await Future<void>.value();
      expect(drained, isFalse);
      reply.complete(accepted);
      expect(await original, same(accepted));
      final OriginalPublicationDrain receipt = await sdkDrain;
      expect(receipt.completed, isTrue);
      expect(receipt.operations.single.result, same(accepted));
      expect(receipt.operations.single.acceptedHash, 'original-hash');
      expect(OriginalPublications.canChangeTransport(sdk), isTrue);
    },
  );

  test(
    'a paused secondary owner refuses before reserving any new original',
    () async {
      final Object file = Object();
      final Object sdk = Object();
      await OriginalPublications.pauseAndDrain(sdk);
      int calls = 0;
      expect(
        () => OriginalPublications.runForOwners<void>(
          <Object>[file, sdk],
          (_) async {
            calls++;
          },
        ),
        throwsA(isA<OriginalPublicationRefused>()),
      );
      expect(calls, 0);
      expect(OriginalPublications.snapshot(file), isEmpty);
      expect(OriginalPublications.snapshot(sdk), isEmpty);
    },
  );

  test(
    'snapshot observes the same original and keeps its first accepted hash',
    () async {
      final Object owner = Object();
      final Object value = Object();
      final Completer<Object> reply = Completer<Object>();
      addTearDown(() {
        if (!reply.isCompleted) reply.complete(value);
      });
      final List<OriginalPublication<dynamic>> before =
          OriginalPublications.snapshot(owner);
      late OriginalPublication<Object> retained;
      final Future<Object> original = OriginalPublications.run<Object>(owner, (
        OriginalPublication<Object> operation,
      ) {
        retained = operation;
        operation
          ..retainPublicationHash('original-hash')
          ..retainPublicationHash('replacement-hash');
        return reply.future;
      });
      final List<OriginalPublication<dynamic>> after =
          OriginalPublications.snapshot(owner);
      expect(before, isEmpty);
      expect(after.single, same(retained));
      expect(after.single.future, same(original));
      expect(after.single.acceptedHash, 'original-hash');
      expect(after.clear, throwsUnsupportedError);
      expect(retained.settled, isFalse);
      expect(OriginalPublications.canChangeTransport(owner), isFalse);
      reply.complete(value);
      expect(await original, same(value));
      expect(
        (await OriginalPublications.pauseAndDrain(owner)).completed,
        isTrue,
      );
      expect(OriginalPublications.canChangeTransport(owner), isTrue);
    },
  );

  test('admission is reserved before a reentrant pause observes it', () async {
    final Object owner = Object();
    final Object result = Object();
    final Completer<Object> original = Completer<Object>();
    late Future<OriginalPublicationDrain> drain;
    final Future<Object> operation = OriginalPublications.run<Object>(owner, (
      _,
    ) {
      drain = OriginalPublications.pauseAndDrain(owner);
      return original.future;
    });
    expect(operation, same(original.future));
    bool drained = false;
    unawaited(drain.then<void>((_) => drained = true));
    await Future<void>.value();
    expect(drained, isFalse);
    original.complete(result);
    expect(await operation, same(result));
    final OriginalPublicationDrain receipt = await drain;
    expect(receipt.owner, same(owner));
    expect(receipt.completed, isTrue);
    expect(receipt.operations.single.future, same(operation));
    expect(receipt.operations.single.result, same(result));
  });

  test(
    'pause refuses new work and is terminal for only the original owner',
    () async {
      final Object owner = Object();
      final Object other = Object();
      final Future<OriginalPublicationDrain> first =
          OriginalPublications.pauseAndDrain(owner);
      final Future<OriginalPublicationDrain> repeated =
          OriginalPublications.pauseAndDrain(owner);
      expect(repeated, same(first));
      int calls = 0;
      expect(
        () => OriginalPublications.run<void>(owner, (_) async {
          calls++;
        }),
        throwsA(isA<OriginalPublicationRefused>()),
      );
      await OriginalPublications.run<void>(other, (_) async {
        calls++;
      });
      expect(calls, 1);
      expect((await first).completed, isTrue);
    },
  );

  test(
    'an original failed operation keeps its exact error and trace',
    () async {
      final Object owner = Object();
      final StateError error = StateError('Synthetic publication failure');
      final StackTrace trace = StackTrace.current;
      final Completer<Object> original = Completer<Object>();
      final Future<Object> operation = OriginalPublications.run<Object>(
        owner,
        (_) => original.future,
      );
      final Future<void> observed = expectLater(
        operation,
        throwsA(same(error)),
      );
      original.completeError(error, trace);
      await observed;
      final OriginalPublicationDrain drain =
          await OriginalPublications.pauseAndDrain(owner);
      expect(drain.completed, isTrue);
      expect(drain.operations.single.error, same(error));
      expect(drain.operations.single.stackTrace, same(trace));
    },
  );

  test(
    'failed original release cannot change acceptance or prove quiescence',
    () async {
      final Object owner = Object();
      final Object accepted = Object();
      final StateError release = StateError('Synthetic release failure');
      final StackTrace trace = StackTrace.current;
      final Object value = await OriginalPublications.run<Object>(owner, (
        OriginalPublication<Object> operation,
      ) async {
        operation.recordReleaseFailure(release, trace);
        return accepted;
      });
      final OriginalPublicationDrain drain =
          await OriginalPublications.pauseAndDrain(owner);
      expect(value, same(accepted));
      expect(drain.completed, isFalse);
      expect(drain.operations.single.result, same(accepted));
      expect(drain.operations.single.releaseError, same(release));
      expect(drain.operations.single.releaseTrace, same(trace));
      expect(OriginalPublications.canChangeTransport(owner), isFalse);
    },
  );

  test(
    'a never-settled original cannot become a successful empty drain',
    () async {
      final Object owner = Object();
      final Completer<void> original = Completer<void>();
      unawaited(
        OriginalPublications.run<void>(owner, (_) => original.future),
      );
      bool settled = false;
      final Future<OriginalPublicationDrain> drain =
          OriginalPublications.pauseAndDrain(owner);
      unawaited(drain.then<void>((_) => settled = true));
      await Future<void>.value();
      await Future<void>.value();
      expect(settled, isFalse);
      original.complete();
      expect((await drain).completed, isTrue);
    },
  );
}
