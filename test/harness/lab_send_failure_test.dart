import 'package:flutter_test/flutter_test.dart';

import '../../harness/lab_send_failure.dart';

class _PrivateValue {
  @override
  String toString() => throw StateError('Private values must not be formatted');
}

Map<String, Object> _labels() => <String, Object>{
  'phase': 'profile', 'reason': 'owned-isolated-profile-required',
};

Map<String, Object> _frontier() => <String, Object>{
  'polls': 6,
  'ws_first_height': 10, 'ws_last_height': 17,
  'ws_first_timestamp': 100, 'ws_last_timestamp': 107,
  'ws_hash_changed': true,
  'http_first_height': 10, 'http_last_height': 10,
  'http_first_timestamp': 100, 'http_last_timestamp': 100,
  'http_hash_changed': false,
};

Map<String, Object> _stalled(Map<String, Object> frontier) => <String, Object>{
  'phase': 'preflight', 'reason': 'advancing-momentum-required',
  'frontier': frontier,
};

void main() {
  test('stalled frontier facts are independent immutable original read values',
      () {
    final Map<String, Object> input = _frontier();
    final Map<String, Object> value = _stalled(input);
    final Map<String, Object> result = labSendPublicDiagnostic(value)!;
    final Map<String, Object> facts =
        result['frontier']! as Map<String, Object>;
    input['http_last_height'] = 50;
    expect(facts, _frontier());
    expect(() => facts['polls'] = 0, throwsUnsupportedError);
    expect(() => result['phase'] = 'accept', throwsUnsupportedError);
    expect(LabSendDiagnosticFailure(result).diagnostic, result);
  });

  test(
      'frontier facts reject coercion private extras and impossible exhaustion',
      () {
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'polls': true},
      <String, Object?>{'polls': 5},
      <String, Object?>{'ws_last_height': 0},
      <String, Object?>{'ws_last_height': 9007199254740992},
      <String, Object?>{'ws_last_height': 17.0},
      <String, Object?>{'http_hash_changed': 0},
      <String, Object?>{'ws_first_timestamp': _PrivateValue()},
      <String, Object?>{'hash': 'private'},
      <String, Object?>{'http_last_height': 9},
      <String, Object?>{'http_last_timestamp': 101},
      <String, Object?>{'http_hash_changed': true},
      <String, Object?>{'http_last_height': 17,
        'http_last_timestamp': 107, 'http_hash_changed': true},
    ]) {
      expect(labSendPublicDiagnostic(<String, Object?>{
        ..._stalled(_frontier()), 'frontier': <String, Object?>{
          ..._frontier(), ...change,
        },
      }), isNull);
    }
    final Map<String, Object> missing = _frontier()..remove('polls');
    expect(labSendPublicDiagnostic(_stalled(missing)), isNull);
  });

  test('frontier facts belong only to the exhausted original preflight', () {
    for (final Map<String, Object> change in <Map<String, Object>>[
      <String, Object>{'phase': 'confirmation'},
      <String, Object>{'reason': 'original-outcome-unknown'},
      <String, Object>{'original': 'pending'},
      <String, Object>{'confirmed': true},
    ]) {
      expect(labSendPublicDiagnostic(<String, Object>{
        ..._stalled(_frontier()), ...change,
      }), isNull);
    }
    expect(labSendPublicDiagnostic(<String, Object>{
      'phase': 'preflight', 'reason': 'advancing-momentum-required',
    }), isNotNull);
  });
  test('review refusals expose only the fixed failed binding label', () {
    for (final String part in <String>[
      'center', 'button', 'dialog', 'intent', 'draft',
    ]) {
      final Map<String, Object> value = <String, Object>{
        'phase': 'preflight', 'reason': 'original-send-review-$part-changed',
      };
      expect(labSendPublicDiagnostic(value), value);
      expect(labSendPublicDiagnostic(<String, Object>{
        ...value, part: 'private',
      }), isNull);
    }
  });

  test('every fixed phase preserves the exact source-defined reason', () {
    for (final String phase in labSendFailurePhases) {
      final Map<String, Object> value = _labels()..['phase'] = phase;
      expect(labSendPublicDiagnostic(value), value);
    }
  });

  test('unknown labels and nonstring values are never projected', () {
    for (final Map<String, Object> change in <Map<String, Object>>[
      <String, Object>{'phase': 'private-path'},
      <String, Object>{'reason': 'private-server-message'},
      <String, Object>{'phase': 1},
      <String, Object>{'reason': false},
    ]) {
      expect(labSendPublicDiagnostic(<String, Object>{..._labels(), ...change}),
        isNull);
    }
  });

  test('extra identity values or success claims refuse the whole payload', () {
    for (final String key in <String>[
      'hash', 'address', 'walletPath', 'requestId', 'confirmed', 'retry',
    ]) {
      expect(labSendPublicDiagnostic(<String, Object>{
        ..._labels(), key: 'private',
      }), isNull);
    }
    expect(labSendPublicDiagnostic(<String, Object>{'phase': 'profile'}),
      isNull);
  });

  test('the returned diagnostic is independent and immutable', () {
    final Map<String, Object> input = _labels();
    final Map<String, Object> result = labSendPublicDiagnostic(input)!;
    input['phase'] = 'private';
    expect(result, _labels());
    expect(() => result['phase'] = 'confirmation', throwsUnsupportedError);
  });

  test('the controller failure retains only its validated copied labels', () {
    final Map<String, Object> input = _labels();
    final LabSendDiagnosticFailure failure = LabSendDiagnosticFailure(input);
    input['reason'] = 'private';
    expect(failure.diagnostic, _labels());
    expect(failure.toString(), 'Original lab send refused');
    expect(failure.toString(), isNot(contains('private')));
  });

  test('opaque errors are discarded without calling their formatter', () {
    final _PrivateValue private = _PrivateValue();
    expect(labSendPublicDiagnostic(private), isNull);
    expect(labSendPublicDiagnostic(<String, Object>{
      'phase': private, 'reason': private,
    }), isNull);
    final LabSendDiagnosticFailure failure = LabSendDiagnosticFailure(private);
    expect(failure.diagnostic, isNull);
    expect(failure.toString(), 'Original lab send refused');
  });

  test('original state is optional, copied and scoped to unknown confirmation',
      () {
    for (final String state in labSendFailureOriginalStates) {
      final Map<String, Object> input = <String, Object>{
        'phase': 'confirmation', 'reason': 'original-outcome-unknown',
        'original': state,
      };
      final Map<String, Object> result = labSendPublicDiagnostic(input)!;
      input['original'] = 'private';
      expect(result['original'], state);
      expect(() => result['original'] = 'pending', throwsUnsupportedError);
      final LabSendDiagnosticFailure failure = LabSendDiagnosticFailure(result);
      expect(failure.diagnostic, result);
      expect(failure.toString(), 'Original lab send refused');
    }
    expect(labSendPublicDiagnostic(_labels()), _labels());
  });

  test('unknown, private or misplaced original state refuses the whole payload',
      () {
    final Map<String, Object?> value = <String, Object?>{
      'phase': 'confirmation', 'reason': 'original-outcome-unknown',
      'original': 'not_started',
    };
    for (final Object? state in <Object?>[
      null, true, 1, '', 'private-path', 'pending\n', _PrivateValue(),
    ]) {
      expect(labSendPublicDiagnostic(<String, Object?>{
        ...value, 'original': state,
      }), isNull);
    }
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'phase': 'admission'},
      <String, Object?>{'reason': 'exact-confirmation-pending'},
      <String, Object?>{'hash': 'private'},
      <String, Object?>{'confirmed': true},
    ]) {
      expect(labSendPublicDiagnostic(<String, Object?>{
        ...value, ...change,
      }), isNull);
    }
  });
}
