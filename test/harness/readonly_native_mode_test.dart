import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/utils/original_publications.dart';

import '../../harness/app/presentation_mode.dart';
import '../../harness/app/readonly_native_commands.dart';
import '../../harness/app/readonly_native_mode.dart';
import '../../harness/app/readonly_sdk_admission.dart';

class _PrivateFailure implements Exception {
  @override
  String toString() => throw StateError('The private formatter must not run');
}

void main() {
  test('absent inspection preserves ordinary and presentation startup', () {
    for (final bool windows in <bool>[false, true]) {
      for (final String? presentation in <String?>[null, 'welcome']) {
        expect(
          harnessReadonlyNativeRequested(
            const <String, String>{},
            windows: windows,
            presentation: presentation,
          ),
          isFalse,
        );
      }
    }
  });

  test('only explicit Windows CI inspection is admitted', () {
    expect(
      harnessReadonlyNativeRequested(
        const <String, String>{
          harnessReadonlyNativeEnvironment: 'true',
          'GITHUB_ACTIONS': 'true',
        },
        windows: true,
        presentation: null,
      ),
      isTrue,
    );
  });

  test('supplied unknown values cannot become ordinary startup', () {
    for (final String value in <String>['', 'false', 'TRUE', '1']) {
      expect(
        () => harnessReadonlyNativeRequested(
          <String, String>{
            harnessReadonlyNativeEnvironment: value,
            'GITHUB_ACTIONS': 'true',
          },
          windows: true,
          presentation: null,
        ),
        throwsA(isA<ReadonlyNativeModeRefused>()),
      );
    }
  });

  test('platform CI and presentation boundaries stay independent', () {
    for (final (bool, String?, String?) scope
        in <(bool, String?, String?)>[
          (false, 'true', null),
          (true, null, null),
          (true, 'false', null),
          (true, 'true', 'welcome'),
          (true, 'true', 'import'),
        ]) {
      expect(
        () => harnessReadonlyNativeRequested(
          <String, String>{
            harnessReadonlyNativeEnvironment: 'true',
            if (scope.$2 != null) 'GITHUB_ACTIONS': scope.$2!,
          },
          windows: scope.$1,
          presentation: scope.$3,
        ),
        throwsA(isA<ReadonlyNativeModeRefused>()),
      );
    }
  });

  test('ordinary launcher removes inherited inspection in either case', () {
    final Map<String, String> parent = <String, String>{
      harnessReadonlyNativeEnvironment: 'true',
      'syrius_ci_readonly_inspection': 'true',
      'GITHUB_ACTIONS': 'true',
    };
    final Map<String, String> launched = harnessLaunchEnvironment(
      parent,
      profileHome: 'fixture-home',
      appData: 'fixture-roaming',
      localAppData: 'fixture-local',
      temporary: 'fixture-temporary',
      port: 12345,
      token: 'fixture-token',
    );
    expect(launched.containsKey(harnessReadonlyNativeEnvironment), isFalse);
    expect(launched.containsKey('syrius_ci_readonly_inspection'), isFalse);
    expect(parent[harnessReadonlyNativeEnvironment], 'true');
    expect(
      harnessLaunchMatches(<String, dynamic>{
        'harnessMode': 'readonly-native',
        'pid': 44,
      }),
      isFalse,
    );
  });

  test('finite transport codes never format unknown private errors', () {
    expect(
      readonlyNativeRefusalCode(const ReadonlyNativeCommandRefused()),
      'READONLY_NATIVE_COMMAND_REFUSED',
    );
    expect(
      readonlyNativeRefusalCode(const ReadonlySdkAdmissionRefused()),
      'READONLY_NATIVE_SDK_REFUSED',
    );
    expect(
      readonlyNativeRefusalCode(const OriginalPublicationRefused()),
      'READONLY_NATIVE_PUBLICATION_REFUSED',
    );
    expect(readonlyNativeRefusalCode(_PrivateFailure()), isNull);
  });
}
