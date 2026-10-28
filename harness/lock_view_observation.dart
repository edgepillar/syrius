/// Fixed boolean fields contain no input, paths or error text.
const Set<String> lockViewBooleanFields = <String>{
  'mounted', 'current', 'window_active', 'visible', 'route_current',
  'focus_allows_input', 'startup_interactive', 'busy', 'opening',
  'incorrect_password', 'attempt_storage_failed', 'has_error_message',
};

/// Only framework lifecycle labels may leave the child.
const Set<String> lockViewLifecycles = <String>{
  'resumed', 'inactive', 'hidden', 'paused', 'detached', 'unknown',
};

/// Unavailable owners remain explicit and never become authentication.
const Set<String> lockViewStatuses = <String>{
  'observed', 'unavailable', 'replaced', 'retired',
};

/// Unknown fields or values cannot enter a public child failure marker.
Map<String, Object?>? projectLockView(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  const Set<String> keys = <String>{
    'schema', 'status', 'owner_same', 'view',
  };
  if (!value.keys.toSet().containsAll(keys) ||
      value.keys.any((String key) => !keys.contains(key) && key != 'ok') ||
      (value.containsKey('ok') && value['ok'] != true) ||
      value['schema'] is! int || value['schema'] != 1 ||
      value['status'] is! String ||
      !lockViewStatuses.contains(value['status']) ||
      value['owner_same'] is! bool) {
    return null;
  }
  final Object? raw = value['view'];
  Map<String, Object?>? view;
  if (value['status'] == 'observed') {
    final Set<String> fields = <String>{
      ...lockViewBooleanFields, 'password_failures', 'lifecycle',
    };
    if (value['owner_same'] != true || raw is! Map<String, dynamic> ||
        raw.length != fields.length || !raw.keys.toSet().containsAll(fields) ||
        lockViewBooleanFields.any((String key) => raw[key] is! bool) ||
        raw['password_failures'] is! int ||
        (raw['password_failures'] as int) < 0 ||
        (raw['password_failures'] as int) > 255 ||
        raw['lifecycle'] is! String ||
        !lockViewLifecycles.contains(raw['lifecycle'])) {
      return null;
    }
    view = Map<String, Object?>.from(raw);
  } else if (value['owner_same'] != false || raw != null) {
    return null;
  }
  return <String, Object?>{
    'schema': 1, 'status': value['status'],
    'owner_same': value['owner_same'], 'view': view,
  };
}
