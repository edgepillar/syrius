import 'package:flutter_test/flutter_test.dart';

import '../../harness/lab_send_failure.dart';

class _PrivateValue {
  @override
  String toString() => throw StateError('Private values must not be formatted');
}

Map<String, Object> _labels() => <String, Object>{
  'phase': 'profile', 'reason': 'owned-isolated-profile-required',
};

void main() {
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
    final Map<String, String> result = labSendPublicDiagnostic(input)!;
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
      final Map<String, String> result = labSendPublicDiagnostic(input)!;
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
