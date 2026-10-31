import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../harness/bin/readonly_inspection_session.dart';

Map<String, dynamic> _reply({bool wallet = false}) => <String, dynamic>{
  'ok': true, 'pid': 44, 'booted': true,
  'harnessMode': 'readonly-native', 'readOnly': true,
  'readonlyAdmission': <String, dynamic>{
    'schema': 1, 'scope': 'readonly_native_sdk_admission', 'status': 'CURRENT',
    'publicationAdmissionPaused': true, 'automaticReceiveDisabled': true,
  },
  if (wallet) 'readonlyWallet': <String, dynamic>{
    'schema': 1, 'scope': 'readonly_native_wallet_admission',
    'status': 'CURRENT',
    'chain': 321, 'selectedIndex': 1, 'nativeFrameObserved': true,
  },
};

class _JsonReentry {
  _JsonReentry(this.invoke);

  final void Function() invoke;

  String toJson() {
    invoke();
    return 'synthetic';
  }
}

void main() {
  test('an admitted original reply keeps identity and its actual mode',
      () async {
    final Map<String, dynamic> original = _reply();
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        expect(command['cmd'], 'ping');
        return original;
      },
    );
    expect(await session.send(<String, Object?>{'cmd': 'ping'},
        const Duration(seconds: 1)), same(original));
    expect(original['harnessMode'], 'readonly-native');
    expect(calls, 1);
    expect(session.walletBound, isFalse);
  });

  test('a foreign process mode or SDK receipt permanently refuses replies',
      () async {
    for (final String fault in <String>['pid', 'mode', 'pending', 'expanded']) {
      final Map<String, dynamic> value = _reply();
      switch (fault) {
        case 'pid': value['pid'] = 45;
        case 'mode': value['harnessMode'] = 'wallet';
        case 'pending':
          (value['readonlyAdmission'] as Map<String, dynamic>)['status'] =
              'PENDING';
        case 'expanded':
          (value['readonlyAdmission'] as Map<String, dynamic>)['extra'] = true;
      }
      int calls = 0;
      final ReadonlyInspectionSession session = ReadonlyInspectionSession(
        processId: 44,
        original: (Map<String, Object?> command, Duration timeout) async {
          calls++;
          return value;
        },
      );
      await expectLater(session.send(<String, Object?>{'cmd': 'ping'},
          const Duration(seconds: 1)),
          throwsA(isA<ReadonlyInspectionRefused>()));
      value['pid'] = 44;
      await expectLater(session.send(<String, Object?>{'cmd': 'ping'},
          const Duration(seconds: 1)),
          throwsA(isA<ReadonlyInspectionRefused>()));
      expect(calls, 1);
    }
  });

  test('wallet binding reserves its only original request and scope',
      () async {
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        expect(command, <String, Object?>{'cmd': 'readonly-wallet-bind'});
        return _reply(wallet: true);
      },
    );
    await session.bindWallet();
    expect(session.walletBound, isTrue);
    await expectLater(session.bindWallet(),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 1);
  });

  test('an SDK-only bind cannot establish an opened wallet', () async {
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        return _reply();
      },
    );
    await expectLater(session.bindWallet(),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(session.walletBound, isFalse);
    await expectLater(session.bindWallet(),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 1);
  });

  test('every later reply retains the original opened-wallet scope',
      () async {
    bool current = true;
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        return _reply(wallet: current);
      },
    );
    await session.bindWallet();
    current = false;
    await expectLater(session.send(<String, Object?>{'cmd': 'shot'},
        const Duration(seconds: 1)),
        throwsA(isA<ReadonlyInspectionRefused>()));
    current = true;
    await expectLater(session.send(<String, Object?>{'cmd': 'shot'},
        const Duration(seconds: 1)),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 2);
  });

  test('an original exception and stack remain exact without replay',
      () async {
    final StateError error = StateError('Synthetic private transport failure');
    final StackTrace trace = StackTrace.current;
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) {
        calls++;
        return Future<Map<String, dynamic>>.error(error, trace);
      },
    );
    Object? seen;
    StackTrace? seenTrace;
    await session.send(<String, Object?>{'cmd': 'ping'},
        const Duration(seconds: 1)).then<void>(
      (_) => fail('An original failure cannot supply readiness'),
      onError: (Object original, StackTrace originalTrace) {
        seen = original;
        seenTrace = originalTrace;
      },
    );
    expect(seen, same(error));
    expect(seenTrace, same(trace));
    await expectLater(session.bindWallet(),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 1);
  });

  test('an original negative reply is returned unchanged and retires the lane',
      () async {
    final Map<String, dynamic> refused = <String, dynamic>{
      'ok': false, 'error': 'synthetic private diagnostic',
    };
    int calls = 0;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        return refused;
      },
    );
    expect(await session.send(<String, Object?>{'cmd': 'readonly-entry'},
        const Duration(seconds: 1)), same(refused));
    await expectLater(session.bindWallet(),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 1);
  });

  test('caught transport reentry also refuses the outer positive reply',
      () async {
    late ReadonlyInspectionSession session;
    int calls = 0;
    session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        await expectLater(session.send(<String, Object?>{'cmd': 'ping'},
            timeout), throwsA(isA<ReadonlyInspectionRefused>()));
        return _reply();
      },
    );
    await expectLater(session.send(<String, Object?>{'cmd': 'ping'},
        const Duration(seconds: 1)),
        throwsA(isA<ReadonlyInspectionRefused>()));
    expect(calls, 1);
  });

  test('nested command values are retained before an original await',
      () async {
    final Completer<void> pending = Completer<void>();
    final List<String> values = <String>['initial'];
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        expect(() => command['cmd'] = 'seed', throwsUnsupportedError);
        await pending.future;
        expect(command['values'], <String>['initial']);
        return _reply();
      },
    );
    final Future<Map<String, dynamic>> original = session.send(
      <String, Object?>{'cmd': 'type', 'values': values},
      const Duration(seconds: 1),
    );
    values[0] = 'changed';
    pending.complete();
    await original;
  });

  test('caught serialization reentry refuses before transport dispatch',
      () async {
    int calls = 0;
    late Future<void> inner;
    final ReadonlyInspectionSession session = ReadonlyInspectionSession(
      processId: 44,
      original: (Map<String, Object?> command, Duration timeout) async {
        calls++;
        return _reply();
      },
    );
    final _JsonReentry value = _JsonReentry(() {
      inner = expectLater(session.send(<String, Object?>{'cmd': 'ping'},
          const Duration(seconds: 1)),
          throwsA(isA<ReadonlyInspectionRefused>()));
    });
    await expectLater(session.send(
        <String, Object?>{'cmd': 'type', 'value': value},
        const Duration(seconds: 1)),
        throwsA(isA<ReadonlyInspectionRefused>()));
    await inner;
    expect(calls, 0);
  });

  test('financial commands and an unreserved bind never reach the transport',
      () async {
    for (final String name in <String>[
      'seed', 'lab-send', 'lab-quiesce', 'lab-reopen-observe',
      'wallet-recipe', 'clipboard', 'readonly-wallet-bind', 'unknown',
    ]) {
      int calls = 0;
      final ReadonlyInspectionSession session = ReadonlyInspectionSession(
        processId: 44,
        original: (Map<String, Object?> command, Duration timeout) async {
          calls++;
          return _reply(wallet: true);
        },
      );
      await expectLater(session.send(<String, Object?>{'cmd': name},
          const Duration(seconds: 1)),
          throwsA(isA<ReadonlyInspectionRefused>()));
      expect(calls, 0);
    }
  });

  test('invalid process IDs refuse before a transport can be used', () {
    for (final int pid in <int>[-1, 0]) {
      expect(() => ReadonlyInspectionSession(processId: pid,
        original: (Map<String, Object?> command, Duration timeout) async =>
            throw StateError('No original call is admitted'),
      ), throwsA(isA<ReadonlyInspectionRefused>()));
    }
  });
}
