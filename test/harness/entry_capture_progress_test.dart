import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/entry_capture_source.dart';

import '../../harness/app/entry_capture_progress.dart';

class _PrivateError implements Exception {
  @override
  String toString() => throw StateError('Private error must not be rendered');
}

Map<String, Object?>? _project(List<Map<String, Object?>> effects, {
  int scopes = 1, int completed = 0,
}) => projectEntryCaptureProgress(
  screen: 'welcome', theme: 'dark', scopes: scopes,
  completedCaptures: completed, effects: effects, artworkCount: 2,
  imageCreated: false, restoring: false, restored: false, held: false,
);

void main() {
  test('progress keeps pending and completed original receipts separate',
      () async {
    final Completer<void> original = Completer<void>();
    final EntryCaptureCompletion receipt = EntryCaptureCompletion(
      original.future,
    );
    final Map<String, Object?> effect = <String, Object?>{
      'phase': 'original-native-frame', 'future': receipt.status.name,
      'failed': false, 'milliseconds': 7,
    };
    final Map<String, Object?> before = _project(<Map<String, Object?>>[
      <String, Object?>{
        'phase': 'original-theme-write', 'future': 'succeeded',
        'failed': false, 'milliseconds': 9,
      }, effect,
    ])!;
    expect(receipt.original, same(original.future));
    expect(receipt.status, EntryCaptureStatus.pending);
    expect((before['last']! as Map<String, Object?>)['future'], 'pending');
    expect((before['slowest']! as Map<String, Object?>)['milliseconds'], 9);
    original.complete();
    await receipt.completion;
    effect['future'] = receipt.status.name;
    effect['milliseconds'] = 12;
    final Map<String, Object?> after = _project(<Map<String, Object?>>[
      effect,
    ], completed: 1)!;
    expect((before['last']! as Map<String, Object?>)['future'], 'pending');
    expect((after['last']! as Map<String, Object?>)['future'], 'succeeded');
    expect(after['completedCaptures'], 1);
    expect(() => before['held'] = true, throwsUnsupportedError);
    expect(() => (before['last']! as Map<String, Object?>)['future'] = 'failed',
      throwsUnsupportedError);
  });

  test('progress never renders or replaces an original failure', () async {
    final Completer<void> original = Completer<void>();
    final EntryCaptureCompletion receipt = EntryCaptureCompletion(
      original.future,
    );
    final _PrivateError error = _PrivateError();
    original.completeError(error, StackTrace.current);
    await receipt.completion;
    final Map<String, Object?> value = _project(<Map<String, Object?>>[
      <String, Object?>{
        'phase': 'original-entry-artwork-ready', 'future': receipt.status.name,
        'failed': true, 'milliseconds': 12,
      },
    ])!;
    expect(receipt.error, same(error));
    await expectLater(original.future, throwsA(same(error)));
    expect((value['last']! as Map<String, Object?>)['future'], 'failed');
    expect(jsonEncode(value), isNot(contains('Private')));
    expect(value.containsKey('error'), isFalse);
  });

  test('progress refuses private fields coerced values and invalid bounds', () {
    final Map<String, Object?> good = <String, Object?>{
      'phase': 'original-native-frame', 'future': 'pending',
      'failed': false, 'milliseconds': 5,
    };
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'phase': _PrivateError()},
      <String, Object?>{'phase': 'private-input'},
      <String, Object?>{'future': 'private-input'},
      <String, Object?>{'failed': 1},
      <String, Object?>{'milliseconds': true},
      <String, Object?>{'milliseconds': -1},
      <String, Object?>{'milliseconds': 0x80000000},
      <String, Object?>{'milliseconds': double.nan},
      <String, Object?>{'error': _PrivateError()},
    ]) {
      expect(_project(<Map<String, Object?>>[<String, Object?>{
        ...good, ...change,
      }]), isNull);
    }
    expect(_project(<Map<String, Object?>>[good], scopes: 0), isNull);
    expect(_project(<Map<String, Object?>>[good], scopes: 17), isNull);
    expect(_project(<Map<String, Object?>>[good], completed: 2), isNull);
    expect(_project(List<Map<String, Object?>>.filled(193, good)), isNull);
    final Map<String, Object?> empty = _project(<Map<String, Object?>>[])!;
    expect(empty['last'], isNull);
    expect(empty['slowest'], isNull);
    expect(empty['effects'], 0);
  });
}
