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
}
