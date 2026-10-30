import 'package:zenon_syrius_wallet_flutter/utils/original_publications.dart';

import 'readonly_native_commands.dart';
import 'readonly_sdk_admission.dart';

/// Selects isolated native inspection explicitly, before any app owner starts.
const String harnessReadonlyNativeEnvironment = 'SYRIUS_CI_READONLY_INSPECTION';

/// A requested native inspection cannot retain the required startup scope.
class ReadonlyNativeModeRefused implements Exception {
  /// Refuses before native startup, private input or SDK initialization.
  const ReadonlyNativeModeRefused();
}

/// Absence preserves ordinary startup; every supplied value needs CI admission.
bool harnessReadonlyNativeRequested(
  Map<String, String> environment, {
  required bool windows,
  required String? presentation,
}) {
  final String? value = environment[harnessReadonlyNativeEnvironment];
  if (value == null) return false;
  if (value != 'true' ||
      !windows ||
      environment['GITHUB_ACTIONS'] != 'true' ||
      presentation != null) {
    throw const ReadonlyNativeModeRefused();
  }
  return true;
}

/// Projects only known admission refusals, without formatting original errors.
String? readonlyNativeRefusalCode(Object error) => switch (error) {
  ReadonlyNativeCommandRefused() => 'READONLY_NATIVE_COMMAND_REFUSED',
  ReadonlySdkAdmissionRefused() => 'READONLY_NATIVE_SDK_REFUSED',
  OriginalPublicationRefused() => 'READONLY_NATIVE_PUBLICATION_REFUSED',
  _ => null,
};
