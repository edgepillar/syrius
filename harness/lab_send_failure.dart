/// Fixed, public labels for original lab-send refusal; no raw SDK/UI data.
const Set<String> labSendFailurePhases = <String>{
  'admission',
  'profile',
  'profile_owner',
  'profile_apis',
  'profile_transports',
  'profile_paths',
  'profile_members',
  'profile_layout',
  'profile_wallet',
  'profile_terms',
  'journal',
  'transfer',
  'form',
  'transport',
  'sender',
  'token',
  'recipient',
  'amount',
  'review_open',
  'review',
  'preflight',
  'accept',
  'confirmation',
  'receipt',
};

/// Only source-defined original-send reasons can cross the CI boundary.
const Set<String> labSendFailureReasons = <String>{
  'advancing-momentum-required',
  'ambiguous-original-publication',
  'earlier-original-unresolved',
  'earlier-seed-attempt-held',
  'exact-chain-321-lab-required',
  'exact-confirmation-or-effect-pending',
  'exact-confirmation-pending',
  'exact-original-lab-transports-required',
  'exact-original-receipt-mismatch',
  'explicit-lab-origins-required',
  'external-lab-counterparty-required',
  'fixed-original-lab-send-required',
  'funded-index-one-required',
  'funded-selected-index-required',
  'invalid-lab-frontier',
  'invalid-original-hash',
  'isolated-unlocked-profile-required',
  'lab-endpoints-disagree',
  'lab-frontier-regressed',
  'lab-http-frontier-incomplete',
  'lab-http-response-refused',
  'lab-http-response-too-large',
  'lab-http-rpc-refused',
  'original-attempt-held',
  'original-context-changed',
  'original-hash-changed',
  'original-lab-control-changed',
  'original-lab-control-unsettled',
  'original-lab-send-context-changed',
  'original-lab-send-transport-required',
  'original-lab-send-ui-or-read-failed',
  'original-lab-sender-choice-required',
  'original-lab-sender-choice-ambiguous',
  'original-lab-sender-choice-missing',
  'original-lab-sender-choice-unsettled',
  'original-outcome-unknown',
  'original-publication-replaced',
  'original-send-form-changed',
  'original-send-form-required',
  'original-send-review-already-captured',
  'original-send-review-changed',
  'original-send-review-required',
  'original-transfer-attempt-held',
  'original-transfer-review-mismatch',
  'original-transfer-review-required',
  'original-transfer-witness-required',
  'original-ui-control-changed',
  'owned-isolated-profile-required',
  'receipt-shape-refused',
  'recipe-prerequisite-missing',
  'seed-journal-held',
  'unknown-recipe',
  'unlocked-wallet-required',
};

/// Returns an independent immutable projection, or refuses the whole payload.
Map<String, String>? labSendPublicDiagnostic(Object? value) {
  if (value is! Map || value.length != 2 ||
      !value.keys.toSet().containsAll(<String>{'phase', 'reason'}) ||
      !labSendFailurePhases.contains(value['phase']) ||
      !labSendFailureReasons.contains(value['reason'])) {
    return null;
  }
  return Map<String, String>.unmodifiable(<String, String>{
    'phase': value['phase'] as String, 'reason': value['reason'] as String,
  });
}

/// Carries only the finite diagnostic through the private controller boundary.
final class LabSendDiagnosticFailure implements Exception {
  /// Discards any malformed or private response rather than exporting it.
  LabSendDiagnosticFailure(Object? value)
    : diagnostic = labSendPublicDiagnostic(value);

  /// A copied, validated label pair; never the original HTTP response.
  final Map<String, String>? diagnostic;

  @override
  String toString() => 'Original lab send refused';
}
