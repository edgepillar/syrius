/// Only fixed recipe labels may leave the private command exchange.
const Set<String> walletRecipeActions = <String>{
  'observe', 'tap', 'type', 'scroll', 'key', 'unknown',
};

/// Dynamic node-selection keys collapse to one label without an endpoint.
const Set<String> walletRecipeControls = <String>{
  'none', 'unknown', 'launch_skip_hint', 'welcome_import',
  'import_words_12', 'import_words_24',
  'import_seed_field', 'import_continue', 'import_new_password',
  'import_confirm_password', 'import_password_continue', 'node_settings_add',
  'node_settings_endpoint', 'node_settings_endpoint_save',
  'node_settings_select', 'node_onboarding_continue',
  'node_settings_question_accept', 'node_settings_chain_toggle',
  'node_settings_client_chain', 'node_settings_chain_save', 'wallet_ready_open',
  'nav_settings', 'nav_dashboard', 'settings_node',
};

/// Fixed server and observation refusals carry no exception text or payload.
const Set<String> walletRecipeFailureCodes = <String>{
  'wallet-recipe-action-refused', 'wallet-recipe-control-refused',
  'wallet-recipe-input-refused', 'wallet-recipe-node-view-ambiguous',
  'wallet-recipe-original-control-changed',
  'wallet-recipe-original-owner-changed',
  'wallet-recipe-original-question-changed',
  'wallet-recipe-original-ready-changed',
  'wallet-recipe-original-ready-unavailable',
  'wallet-recipe-private-input-refused',
  'wallet-recipe-question-already-used', 'wallet-recipe-question-facts-refused',
  'wallet-recipe-question-replaced', 'wallet-recipe-question-unowned',
  'wallet-recipe-refused', 'wallet-recipe-scroll-refused',
  'wallet-recipe-selection-origin-refused', 'wallet-recipe-transition-held',
  'wallet-recipe-visible-error',
  'wallet-recipe-stage-unsettled',
  'wallet-recipe-control-absent',
  'wallet-recipe-control-disabled',
};

/// Entry types and failure families disclose no displayed text or error detail.
const Set<String> walletRecipeEntryPhases = <String>{
  'startup', 'welcome', 'import', 'ready', 'node', 'error', 'unknown',
  'startup-before-initialization', 'startup-initialization-started',
  'startup-initialization-refused', 'startup-filesystem-error',
  'startup-platform-error', 'startup-hive-error', 'startup-other-error',
};

/// This records only the original startup decision, never a key or payload.
const Set<String> walletRecipeStartupHandoffs = <String>{
  'observing', 'key-sent', 'key-confirmed',
  'natural-welcome', 'natural-initialization',
};

/// Values, endpoints, exception text and reply details are never projected.
Map<String, String> walletRecipeDiagnostic(
  Map<String, Object?> command,
  Object? reason, {
  Object? entryPhase,
}) {
  final Object? action = command['action'];
  final Object? key = command['key'];
  String control = 'unknown';
  if (key == null) {
    control = 'none';
  } else if (key is String) {
    if (walletRecipeControls.contains(key)) {
      control = key;
    } else if (key.startsWith('node_settings_select_')) {
      control = 'node_settings_select';
    }
  }
  return Map<String, String>.unmodifiable(<String, String>{
    'action': action is String && walletRecipeActions.contains(action)
        ? action
        : 'unknown',
    'control': control,
    'reason': reason is String && walletRecipeFailureCodes.contains(reason)
        ? reason
        : 'wallet-recipe-refused',
    if (entryPhase is String && walletRecipeEntryPhases.contains(entryPhase))
      'entry': entryPhase,
  });
}

/// Recheck even a typed exception before adding its labels to a CI marker.
Map<String, String>? walletRecipePublicDiagnostic(Object? value) {
  const Set<String> fields = <String>{
    'action', 'control', 'reason', 'entry', 'startup',
  };
  if (value is! Map<Object?, Object?> ||
      value.length < 3 || value.length > 5 ||
      value.keys.any((Object? key) => !fields.contains(key))) {
    return null;
  }
  final Object? action = value['action'];
  final Object? control = value['control'];
  final Object? reason = value['reason'];
  final Object? entry = value['entry'];
  final Object? startup = value['startup'];
  if (action is! String ||
      control is! String ||
      reason is! String ||
      !walletRecipeActions.contains(action) ||
      !walletRecipeControls.contains(control) ||
      !walletRecipeFailureCodes.contains(reason)) {
    return null;
  }
  if (value.containsKey('entry') &&
      (entry is! String || !walletRecipeEntryPhases.contains(entry))) {
    return null;
  }
  if (value.containsKey('startup') &&
      (startup is! String || !walletRecipeStartupHandoffs.contains(startup))) {
    return null;
  }
  final String? phase = entry is String ? entry : null;
  final String? handoff = startup is String ? startup : null;
  return Map<String, String>.unmodifiable(<String, String>{
    'action': action, 'control': control, 'reason': reason,
    'entry': ?phase,
    'startup': ?handoff,
  });
}
