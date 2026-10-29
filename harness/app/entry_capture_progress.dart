const Set<String> _entryEffectPhases = <String>{
  'original-entry-artwork-ready',
  'original-image-release',
  'original-import-controller-end',
  'original-import-navigation-end',
  'original-import-route-end',
  'original-incomplete-import-input',
  'original-native-frame',
  'original-png-encoding',
  'original-renderer-image',
  'original-restored-window-position',
  'original-restored-window-size',
  'original-restored-window-visibility',
  'original-route-frame',
  'original-route-transition',
  'original-theme-flush',
  'original-theme-frame',
  'original-theme-write',
  'original-welcome-import',
  'original-window-position',
  'original-window-size',
  'original-window-visibility',
};

/// Projects existing receipts and elapsed effects without invoking an owner.
/// Invalid or private fields cannot become a partially accepted observation.
Map<String, Object?>? projectEntryCaptureProgress({
  required String screen,
  required String theme,
  required int scopes,
  required int completedCaptures,
  required List<Map<String, Object?>> effects,
  required int artworkCount,
  required bool imageCreated,
  required bool restoring,
  required bool restored,
  required bool held,
}) {
  if (!<String>{'welcome', 'import'}.contains(screen) ||
      !<String>{'dark', 'light'}.contains(theme) ||
      scopes < 1 || scopes > 16 ||
      completedCaptures < 0 || completedCaptures > scopes ||
      effects.length > 192 || artworkCount < 0 || artworkCount > 2) {
    return null;
  }
  const Set<String> fields = <String>{
    'phase', 'future', 'failed', 'milliseconds',
  };
  final List<Map<String, Object?>> fixed = <Map<String, Object?>>[];
  Map<String, Object?>? slowest;
  int largest = -1;
  for (final Map<String, Object?> effect in effects) {
    final Object? phase = effect['phase'];
    final Object? future = effect['future'];
    final Object? failed = effect['failed'];
    final Object? milliseconds = effect['milliseconds'];
    if (effect.length != fields.length ||
        !effect.keys.every(fields.contains) ||
        phase is! String || !_entryEffectPhases.contains(phase) ||
        future is! String || !<String>{
          'not_returned', 'pending', 'succeeded', 'failed',
        }.contains(future) || failed is! bool ||
        milliseconds is! int || milliseconds < 0 ||
        milliseconds > 0x7fffffff) {
      return null;
    }
    final Map<String, Object?> value = Map<String, Object?>.unmodifiable(
      <String, Object?>{
        'phase': phase, 'future': future, 'failed': failed,
        'milliseconds': milliseconds,
      },
    );
    fixed.add(value);
    if (milliseconds > largest) {
      largest = milliseconds;
      slowest = value;
    }
  }
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'schema': 1, 'screen': screen, 'theme': theme,
    'scopes': scopes, 'completedCaptures': completedCaptures,
    'effects': fixed.length, 'last': fixed.isEmpty ? null : fixed.last,
    'slowest': slowest, 'artworkCount': artworkCount,
    'imageCreated': imageCreated, 'restoring': restoring,
    'restored': restored, 'held': held,
  });
}
