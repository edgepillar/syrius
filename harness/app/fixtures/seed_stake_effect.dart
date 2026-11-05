/// Passive counts from the same completed negative Stake effect read.
/// These values contain no receipt, identity, client or operation authority.
typedef SeedStakeEffectPredicates = ({
  bool identity,
  bool owner,
  bool amount,
  bool duration,
});

final class SeedStakeEffectObservation {
  SeedStakeEffectObservation._(this.public);

  final Map<String, Object> public;

  static SeedStakeEffectObservation? capture({
    required int reported,
    required int returned,
    required Iterable<SeedStakeEffectPredicates> entries,
  }) {
    if (reported < 0 || reported > 9007199254740991 ||
        returned < 0 || returned > 64) return null;
    final Map<String, Object> value = <String, Object>{
      'schema': 1, 'scope': 'original_seed_stake_effect',
      'reported_rows': reported, 'returned_rows': returned,
      'scan': 'NOT_RUN',
    };
    if (reported == returned && reported <= 64) {
      int seen = 0;
      int identities = 0;
      int owners = 0;
      int amounts = 0;
      int durations = 0;
      for (final SeedStakeEffectPredicates entry in entries) {
        if (++seen > returned) return null;
        if (!entry.identity) continue;
        identities++;
        if (!entry.owner) continue;
        owners++;
        if (!entry.amount) continue;
        amounts++;
        if (!entry.duration) continue;
        durations++;
      }
      if (seen != returned) return null;
      value.addAll(<String, Object>{
        'scan': 'COMPLETE', 'id_matches': identities,
        'owner_matches': owners, 'amount_matches': amounts,
        'duration_matches': durations,
      });
    }
    final Map<String, Object>? projected = seedStakeEffectProjection(value);
    return projected == null ? null : SeedStakeEffectObservation._(projected);
  }
}

/// Only a captured source may expose its last same-hash passive observation.
abstract interface class SeedStakeEffectSource {
  SeedStakeEffectObservation? observeStakeEffect(String hash);
}

/// Strict negative data only; a positive matching row never grants success.
Map<String, Object>? seedStakeEffectProjection(Object? value) {
  const Set<String> base = <String>{
    'schema', 'scope', 'reported_rows', 'returned_rows', 'scan',
  };
  const List<String> counts = <String>[
    'id_matches', 'owner_matches', 'amount_matches', 'duration_matches',
  ];
  if (value is! Map<String, Object?> || value['schema'] is! int ||
      value['schema'] != 1 ||
      value['scope'] is! String || value['scan'] is! String ||
      value['scope'] != 'original_seed_stake_effect' ||
      value['reported_rows'] is! int || value['returned_rows'] is! int) {
    return null;
  }
  final int reported = value['reported_rows']! as int;
  final int returned = value['returned_rows']! as int;
  if (reported < 0 || reported > 9007199254740991 ||
      returned < 0 || returned > 64) return null;
  final bool complete = reported == returned && reported <= 64;
  final Set<String> fields = <String>{...base, if (complete) ...counts};
  if (value.length != fields.length ||
      !value.keys.toSet().containsAll(fields) ||
      value['scan'] != (complete ? 'COMPLETE' : 'NOT_RUN')) return null;
  int previous = returned;
  if (complete) {
    for (final String key in counts) {
      final Object? count = value[key];
      if (count is! int || count < 0 || count > previous) return null;
      previous = count;
    }
    if (value['duration_matches'] == 1) return null;
  }
  return Map<String, Object>.unmodifiable(<String, Object>{
    for (final String key in fields) key: value[key]!,
  });
}
