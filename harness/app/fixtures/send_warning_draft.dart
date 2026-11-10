import 'package:znn_sdk_dart/znn_sdk_dart.dart' show Address;

// Synthetic payloads with distinct valid checksums and matching visible ends.
// The fixture stays in an isolated address book and an unsubmitted draft.
final String sendWarningKnownAddress = Address('z', const <int>[
  0, 7, 85, 75, 208, 233, 163, 5, 204, 76,
  115, 233, 254, 231, 93, 120, 90, 191, 23, 65,
]).toString();

final String sendWarningTypedAddress = Address('z', const <int>[
  0, 7, 85, 55, 125, 22, 182, 117, 7, 52,
  153, 150, 155, 2, 69, 31, 251, 228, 193, 28,
]).toString();

const String sendWarningAmount = '12.5';
