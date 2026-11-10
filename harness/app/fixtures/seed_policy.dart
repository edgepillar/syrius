import 'dart:async';

import 'package:znn_sdk_dart/znn_sdk_dart.dart'
    show Crypto, Hash, TokenStandard;

import 'seed_stake_effect.dart';

/// Harness-only policy. This file has no wallet, signer, filesystem or client.
const String seedWsOrigin = 'ws://127.0.0.1:45998';
const String seedHttpOrigin = 'http://127.0.0.1:45997';
/// The single P09 send is separate from the six checkpointed F06 recipes.
const String labSendRecipeId = 'lab-send';
const String pillarDepositRecipeId = 'pillar-qsr';
const Set<String> seedRecipeIds = <String>{
  'stake',
  'fuse',
  'token',
  'deposit',
  'project',
  'fund-address',
};

/// The two closed non-self Fuse targets in an owned restored profile.
enum SeedFuseTarget {
  restoredSecondary(2, 100),
  pillarActor(3, 1000);

  const SeedFuseTarget(this.index, this.qsr);

  final int index;
  final int qsr;
  BigInt get units => BigInt.from(qsr) * BigInt.from(100000000);
  String get optionKey => 'fuse_plasma_beneficiary_option_$index';
}

/// The issued token standard is derived from the confirmed Issue block.
TokenStandard seedIssuedTokenStandard(String hash) => TokenStandard.fromBytes(
  Crypto.digest(Hash.parse(hash).getBytes()!)
      .sublist(0, TokenStandard.coreSize),
);

final class SeedRefused implements Exception {
  const SeedRefused(this.code, {
    this.frontier, this.confirmation, this.originals, this.stakeEffect,
  });
  final String code;
  final SeedAdvanceObservation? frontier;
  final SeedConfirmationObservation? confirmation;
  final SeedOriginalObservation? originals;
  final SeedStakeEffectObservation? stakeEffect;
  @override
  String toString() => 'Seed refused: $code';
}

/// The same admission snapshot, without identities, errors or accepted hashes.
final class SeedOriginalObservation {
  const SeedOriginalObservation._({
    required this.pending, required this.failed, required this.releaseFailed,
  });

  factory SeedOriginalObservation.capture(Iterable<SeedOriginal> originals) {
    bool pending = false;
    bool failed = false;
    bool releaseFailed = false;
    for (final SeedOriginal original in originals) {
      pending = !original.settled || pending;
      failed = original.failed || failed;
      releaseFailed = original.releaseFailed || releaseFailed;
    }
    return SeedOriginalObservation._(
      pending: pending, failed: failed, releaseFailed: releaseFailed,
    );
  }

  final bool pending;
  final bool failed;
  final bool releaseFailed;
  bool get unresolved => pending || failed || releaseFailed;

  Map<String, Object> get public =>
      Map<String, Object>.unmodifiable(<String, Object>{
        'pending': pending, 'failed': failed, 'release_failed': releaseFailed,
      });
}

/// Three exact negative flags from one original snapshot, without authority.
Map<String, Object>? seedOriginalProjection(Object? value) {
  const Set<String> fields = <String>{'pending', 'failed', 'release_failed'};
  if (value is! Map<String, Object?> || value.length != fields.length ||
      !value.keys.toSet().containsAll(fields) ||
      fields.any((String key) => value[key] is! bool) ||
      !fields.any((String key) => value[key] == true)) {
    return null;
  }
  return Map<String, Object>.unmodifiable(<String, Object>{
    for (final String key in fields) key: value[key]! as bool,
  });
}

/// Completed nonpositive rounds from the original eighteen seed reads only.
/// These counts contain no receipt, wallet identity or operation authority.
final class SeedConfirmationObservation {
  const SeedConfirmationObservation._({
    required this.absent,
    required this.unconfirmed,
    required this.effectPending,
    required this.last,
    this.funding,
  });

  final int absent;
  final int unconfirmed;
  final int effectPending;
  final SeedPendingResult last;
  final SeedFundingObservation? funding;

  Map<String, Object> get public =>
      Map<String, Object>.unmodifiable(<String, Object>{
        'polls': absent + unconfirmed + effectPending,
        'absent': absent, 'unconfirmed': unconfirmed,
        'effect_pending': effectPending,
        'last': switch (last) {
          SeedPendingResult.absent => 'absent',
          SeedPendingResult.unconfirmed => 'unconfirmed',
          SeedPendingResult.effectPending => 'effect_pending',
        },
        'funding': ?funding?.public,
      });
}

enum SeedPendingResult { absent, unconfirmed, effectPending }

enum SeedFundingLedger {
  confirmed('confirmed'),
  balancePending('balance_pending'),
  receivePending('receive_pending');

  const SeedFundingLedger(this.wire);
  final String wire;
}

enum SeedFundingReceive { unavailable, unseen, pending, accepted, held }

/// One completed negative ledger check and its same-hash wallet observation.
final class SeedFundingObservation {
  const SeedFundingObservation({
    required this.ledger,
    required this.walletReceive,
    required this.pairedReceive,
    this._receiveResult,
  });

  final SeedFundingLedger ledger;
  final SeedFundingReceive walletReceive;
  final bool pairedReceive;
  final Future<Object?>? _receiveResult;

  /// The existing wallet result only schedules the next exact ledger read.
  Future<Object?>? get pendingReceiveResult =>
      !pairedReceive && walletReceive == SeedFundingReceive.pending
          ? _receiveResult
          : null;

  bool get waitingForReceive =>
      !pairedReceive &&
      (walletReceive == SeedFundingReceive.pending ||
          walletReceive == SeedFundingReceive.accepted);

  Map<String, Object> get public =>
      Map<String, Object>.unmodifiable(<String, Object>{
        'ledger': ledger.wire,
        'wallet_receive': walletReceive.name,
        'paired_receive': pairedReceive,
      });
}

// The optional observer stays bound to the original source.
// ignore: one_member_abstracts
abstract interface class SeedFundingEffectSource {
  SeedFundingObservation? observeFundingEffect(String hash);
}

Map<String, Object>? _seedFundingProjection(Object? value) {
  if (value is! Map<String, Object?> || value.length != 3) return null;
  final Object? ledger = value['ledger'];
  final Object? receive = value['wallet_receive'];
  final Object? paired = value['paired_receive'];
  if (ledger is! String ||
      !const <String>{'balance_pending', 'receive_pending'}.contains(ledger) ||
      receive is! String ||
      !SeedFundingReceive.values.any(
        (SeedFundingReceive state) => state.name == receive,
      ) ||
      paired is! bool ||
      (paired && ledger == 'receive_pending')) {
    return null;
  }
  return Map<String, Object>.unmodifiable(<String, Object>{
    'ledger': ledger, 'wallet_receive': receive, 'paired_receive': paired,
  });
}

/// A bounded copy of completed original negative reads, without authority.
Map<String, Object>? seedConfirmationProjection(
  Object? value, {
  bool allowFunding = false,
}) {
  const Set<String> fields = <String>{
    'polls', 'absent', 'unconfirmed', 'effect_pending', 'last',
  };
  if (value is! Map<String, Object?>) return null;
  final bool hasFunding = value.containsKey('funding');
  if (value.length != fields.length + (hasFunding ? 1 : 0) ||
      !value.keys.toSet().containsAll(fields) ||
      (hasFunding && !allowFunding)) {
    return null;
  }
  final Object? polls = value['polls'];
  final Object? absent = value['absent'];
  final Object? unconfirmed = value['unconfirmed'];
  final Object? pending = value['effect_pending'];
  final Object? last = value['last'];
  if (polls is! int || polls != 18 || absent is! int ||
      unconfirmed is! int || pending is! int || last is! String ||
      absent < 0 || absent > 18 || unconfirmed < 0 || unconfirmed > 18 ||
      pending < 0 || pending > 18 || absent + unconfirmed + pending != 18 ||
      !<String>{'absent', 'unconfirmed', 'effect_pending'}.contains(last)) {
    return null;
  }
  if (last == 'absent' && absent == 0 ||
      last == 'unconfirmed' && unconfirmed == 0 ||
      last == 'effect_pending' && pending == 0) {
    return null;
  }
  final Map<String, Object>? funding = _seedFundingProjection(value['funding']);
  if (hasFunding && (last != 'effect_pending' || funding == null)) return null;
  return Map<String, Object>.unmodifiable(<String, Object>{
    'polls': 18, 'absent': absent, 'unconfirmed': unconfirmed,
    'effect_pending': pending, 'last': last,
    'funding': ?funding,
  });
}

final class SeedEnvironment {
  SeedEnvironment({
    required this.profile,
    required this.isolated,
    required this.unlocked,
    required this.initialized,
    required this.booted,
    required this.ws,
    required this.http,
    required this.nodeChain,
    required this.signingChain,
    required this.selectedIndex,
    required this.owner,
    required Iterable<String> members,
  }) : members = List<String>.unmodifiable(members);
  final String profile;
  final bool isolated;
  final bool unlocked;
  final bool initialized;
  final bool booted;
  final String ws;
  final String http;
  final int? nodeChain;
  final int signingChain;
  final int selectedIndex;
  final String owner;
  final List<String> members;

  void requireLab({bool pillarActor = false}) {
    if (profile == 'default' ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(profile) ||
        !isolated ||
        !booted ||
        !unlocked ||
        !initialized) {
      throw const SeedRefused('isolated-unlocked-profile-required');
    }
    // Exact strings deliberately refuse DNS aliases, credentials, paths,
    // alternate ports, query strings and public endpoints.
    if (ws != seedWsOrigin ||
        http != seedHttpOrigin ||
        nodeChain != 321 ||
        signingChain != 321) {
      throw const SeedRefused('exact-chain-321-lab-required');
    }
    final int requiredIndex =
        pillarActor ? SeedFuseTarget.pillarActor.index : 1;
    if (selectedIndex != requiredIndex ||
        members.length <= requiredIndex ||
        pillarActor && members.length != requiredIndex + 1 ||
        members.toSet().length != members.length ||
        owner.isEmpty ||
        members[requiredIndex] != owner) {
      throw SeedRefused(pillarActor
          ? 'restored-seed-derivation-refused' : 'funded-index-one-required');
    }
  }
}

final class SeedFrontier {
  const SeedFrontier({
    required this.chain,
    required this.height,
    required this.timestamp,
    required this.hash,
  });
  final int chain;
  final int height;
  final int timestamp;
  final String hash;
  bool get valid =>
      chain == 321 && height > 0 && timestamp > 0 && seedHash(hash);
  bool advances(SeedFrontier original) =>
      valid &&
      original.valid &&
      height > original.height &&
      timestamp > original.timestamp &&
      hash != original.hash;
}

/// Facts from the same completed admission reads; this starts no extra read.
final class SeedAdvanceObservation {
  const SeedAdvanceObservation({
    required this.firstWs,
    required this.firstHttp,
    required this.lastWs,
    required this.lastHttp,
  });

  final SeedFrontier firstWs;
  final SeedFrontier firstHttp;
  final SeedFrontier lastWs;
  final SeedFrontier lastHttp;

  /// Only isolated lab heights, timestamps and hash comparisons are public.
  /// Hash bytes, transport replies and wallet identities never leave here.
  Map<String, Object> get public => Map<String, Object>.unmodifiable(
    <String, Object>{
      'polls': 6,
      'ws_first_height': firstWs.height,
      'ws_last_height': lastWs.height,
      'ws_first_timestamp': firstWs.timestamp,
      'ws_last_timestamp': lastWs.timestamp,
      'ws_hash_changed': firstWs.hash != lastWs.hash,
      'http_first_height': firstHttp.height,
      'http_last_height': lastHttp.height,
      'http_first_timestamp': firstHttp.timestamp,
      'http_last_timestamp': lastHttp.timestamp,
      'http_hash_changed': firstHttp.hash != lastHttp.hash,
    },
  );
}

/// Copies the six completed original rounds, without hash bytes or authority.
Map<String, Object>? seedAdvanceProjection(Object? value) {
  const Set<String> fields = <String>{
    'polls', 'ws_first_height', 'ws_last_height', 'ws_first_timestamp',
    'ws_last_timestamp', 'ws_hash_changed', 'http_first_height',
    'http_last_height', 'http_first_timestamp', 'http_last_timestamp',
    'http_hash_changed',
  };
  if (value is! Map<String, Object?> || value.length != fields.length ||
      !value.keys.toSet().containsAll(fields) || value['polls'] is! int ||
      value['polls'] != 6) {
    return null;
  }
  const int maximum = 9007199254740991;
  final Map<String, Object> result = <String, Object>{'polls': 6};
  bool bothAdvance = true;
  for (final String endpoint in <String>['ws', 'http']) {
    final Object? firstHeight = value['${endpoint}_first_height'];
    final Object? lastHeight = value['${endpoint}_last_height'];
    final Object? firstTime = value['${endpoint}_first_timestamp'];
    final Object? lastTime = value['${endpoint}_last_timestamp'];
    final Object? changed = value['${endpoint}_hash_changed'];
    if (firstHeight is! int || lastHeight is! int || firstTime is! int ||
        lastTime is! int || changed is! bool || firstHeight < 1 ||
        firstHeight > maximum || lastHeight < firstHeight ||
        lastHeight > maximum || firstTime < 1 || firstTime > maximum ||
        lastTime < 1 || lastTime > maximum ||
        lastHeight == firstHeight && (lastTime != firstTime || changed)) {
      return null;
    }
    bothAdvance = bothAdvance && lastHeight > firstHeight &&
        lastTime > firstTime && changed;
    result.addAll(<String, Object>{
      '${endpoint}_first_height': firstHeight,
      '${endpoint}_last_height': lastHeight,
      '${endpoint}_first_timestamp': firstTime,
      '${endpoint}_last_timestamp': lastTime,
      '${endpoint}_hash_changed': changed,
    });
  }
  return bothAdvance ? null : Map<String, Object>.unmodifiable(result);
}

/// Only an original publish refusal can carry these fixed passive details.
Map<String, Object>? seedRefusalDetail(
  SeedRefused error, {
  required Object? action,
}) {
  if (action != 'publish') return null;
  final Map<String, Object>? originals =
      error.code == 'earlier-original-unresolved'
      ? seedOriginalProjection(error.originals?.public) : null;
  if (originals != null) {
    return Map<String, Object>.unmodifiable(<String, Object>{
      'seedOriginals': originals,
    });
  }
  final Map<String, Object>? confirmation =
      error.code == 'exact-confirmation-or-effect-pending'
      ? seedConfirmationProjection(error.confirmation?.public,
          allowFunding: true) : null;
  if (confirmation != null) {
    final Map<String, Object>? stake =
        confirmation['last'] == 'effect_pending'
        ? seedStakeEffectProjection(error.stakeEffect?.public) : null;
    return Map<String, Object>.unmodifiable(<String, Object>{
      'seedConfirmation': confirmation,
      'seedStakeEffect': ?stake,
    });
  }
  final Map<String, Object>? frontier =
      error.code == 'advancing-momentum-required'
      ? seedAdvanceProjection(error.frontier?.public) : null;
  return frontier == null ? null :
      Map<String, Object>.unmodifiable(<String, Object>{
        'seedAdvance': frontier,
      });
}

bool seedHash(String value) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(value) &&
    value.contains(RegExp('[1-9a-f]'));

final class SeedFunding {
  const SeedFunding(this.znn, this.qsr);
  final BigInt znn;
  final BigInt qsr;
}

/// Each wrapper's identity names the identical actual original operation.
abstract interface class SeedOriginal {
  Object get identity;
  bool get settled;
  bool get failed;
  bool get releaseFailed;
  String? get acceptedHash;
}

/// Observes the original result and release without stopping its lane.
abstract interface class SeedOriginalSettlement implements SeedOriginal {
  Future<void> get settlement;
}

final class SeedConfirmed {
  const SeedConfirmed({
    required this.hash,
    required this.owner,
    required this.chain,
    required this.positiveConfirmation,
    required this.matchesRecipe,
    this.fundAddressReceiveConfirmed = false,
    this.pendingTokenHoldingReceive,
  });
  final String hash;
  final String owner;
  final int chain;
  final bool positiveConfirmation;
  final bool matchesRecipe;
  final bool fundAddressReceiveConfirmed;

  /// The existing wallet result can only schedule another exact ledger read.
  final Future<Object?>? pendingTokenHoldingReceive;
}

abstract interface class SeedSource {
  SeedEnvironment get environment;
  bool get isCurrent;
  Future<SeedFrontier> wsFrontier();
  Future<SeedFrontier> httpFrontier();
  Future<bool> sameMomentum(SeedFrontier http);
  Future<SeedFunding> funding();
  List<SeedOriginal> originals();
  Future<SeedConfirmed?> confirmed(String recipe, String hash);
  Future<bool> effect(String recipe, SeedConfirmed original);
  SeedFunding minimum(String recipe);
}

/// The production implementation creates exclusive, small profile records.
/// No operation clears an uncertain attempt or overwrites an earlier receipt.
abstract interface class SeedJournal {
  void requireAvailable(String recipe);
  void claim(String recipe);
  void accepted(String recipe, String hash);
  void confirmed(String recipe, String hash);
}

/// One captured source; returning to a revoked source cannot revive it.
final class SeedGuard {
  SeedGuard({
    required this.source,
    required this.journal,
    Future<void> Function(Duration)? delay,
    this.readTimeout = const Duration(seconds: 3),
  }) : _delay = delay ?? Future<void>.delayed,
       _labSend = false,
       _pillarDeposit = false;

  /// Read admission for one original P09 request; never a generic seed publish.
  SeedGuard.forLabSend({
    required this.source,
    required this.journal,
    Future<void> Function(Duration)? delay,
    this.readTimeout = const Duration(seconds: 3),
  }) : _delay = delay ?? Future<void>.delayed,
       _labSend = true,
       _pillarDeposit = false;

  /// Admits the original QSR deposit of the sponsored fourth lab member.
  SeedGuard.forPillarDeposit({
    required this.source,
    required this.journal,
    Future<void> Function(Duration)? delay,
    this.readTimeout = const Duration(seconds: 3),
  }) : _delay = delay ?? Future<void>.delayed,
       _labSend = false,
       _pillarDeposit = true;
  final SeedSource source;
  final SeedJournal journal;
  final Future<void> Function(Duration) _delay;
  final Duration readTimeout;
  final bool _labSend;
  final bool _pillarDeposit;
  bool _revoked = false;
  bool _attempted = false;
  SeedOriginal? _original;
  String? _hash;
  String? get acceptedHash => _hash;

  void requireCurrent() {
    if (_revoked || !source.isCurrent) {
      _revoked = true;
      throw const SeedRefused('original-context-changed');
    }
    source.environment.requireLab(pillarActor: _pillarDeposit);
  }

  void requirePreparation() {
    requireCurrent();
    if (_attempted) throw const SeedRefused('original-attempt-held');
  }

  Future<T> _read<T>(Future<T> Function() action) async {
    requireCurrent();
    final T value = await action().timeout(readTimeout);
    requireCurrent();
    return value;
  }

  Future<(SeedFrontier, SeedFrontier)> _frontiers() async {
    final List<SeedFrontier> values = await Future.wait<SeedFrontier>(
      <Future<SeedFrontier>>[
        _read(source.wsFrontier),
        _read(source.httpFrontier),
      ],
    );
    if (values.any((SeedFrontier value) => !value.valid)) {
      throw const SeedRefused('invalid-lab-frontier');
    }
    if (!await _read(() => source.sameMomentum(values.last))) {
      throw const SeedRefused('lab-endpoints-disagree');
    }
    return (values.first, values.last);
  }

  /// Both original endpoints must positively advance during this admission.
  Future<void> admit(String recipe, {bool waitForEarlier = false}) async {
    final bool allowed = _labSend
        ? recipe == labSendRecipeId
        : _pillarDeposit
        ? recipe == pillarDepositRecipeId
        : seedRecipeIds.contains(recipe);
    if (!allowed) {
      throw const SeedRefused('unknown-recipe');
    }
    requireCurrent();
    journal.requireAvailable(recipe);
    final (SeedFrontier firstWs, SeedFrontier firstHttp) = await _frontiers();
    SeedFrontier previousWs = firstWs;
    SeedFrontier previousHttp = firstHttp;
    bool advancing = false;
    final bool fullLateSlots = _labSend || recipe == 'project';
    for (int poll = 0; poll < 6; poll++) {
      // Leave a full nominal slot between the final Project and Send reads.
      final Duration interval = fullLateSlots && poll >= 4
          ? const Duration(seconds: 10)
          : const Duration(seconds: 5);
      await _delay(interval);
      requireCurrent();
      final (SeedFrontier ws, SeedFrontier http) = await _frontiers();
      if (ws.height < previousWs.height ||
          http.height < previousHttp.height ||
          ws.height == previousWs.height &&
              (ws.hash != previousWs.hash ||
                  ws.timestamp != previousWs.timestamp) ||
          http.height == previousHttp.height &&
              (http.hash != previousHttp.hash ||
                  http.timestamp != previousHttp.timestamp)) {
        throw const SeedRefused('lab-frontier-regressed');
      }
      if (ws.advances(firstWs) && http.advances(firstHttp)) {
        advancing = true;
        break;
      }
      previousWs = ws;
      previousHttp = http;
    }
    if (!advancing) {
      throw SeedRefused('advancing-momentum-required',
        frontier: SeedAdvanceObservation(
          firstWs: firstWs, firstHttp: firstHttp,
          lastWs: previousWs, lastHttp: previousHttp,
        ),
      );
    }
    if (waitForEarlier) await _waitForEarlierOriginals();
    final SeedFunding funds = await _read(source.funding);
    final SeedFunding minimum = source.minimum(recipe);
    if (funds.znn <= BigInt.zero ||
        funds.qsr.isNegative ||
        funds.znn < minimum.znn ||
        funds.qsr < minimum.qsr) {
      throw const SeedRefused('funded-selected-index-required');
    }
    _requireSettledOriginals(source.originals());
  }

  void _requireSettledOriginals(List<SeedOriginal> originals) {
    final SeedOriginalObservation observed =
        SeedOriginalObservation.capture(originals);
    if (observed.unresolved) {
      throw SeedRefused('earlier-original-unresolved', originals: observed);
    }
  }

  Future<void> _waitForEarlierOriginals() async {
    requireCurrent();
    final List<SeedOriginal> originals = source.originals();
    final SeedOriginalObservation observed =
        SeedOriginalObservation.capture(originals);
    if (!observed.pending || observed.failed || observed.releaseFailed) return;
    final List<SeedOriginal> pending = originals
        .where((SeedOriginal original) => !original.settled).toList();
    if (pending.any((SeedOriginal value) => value is! SeedOriginalSettlement)) {
      return;
    }
    try {
      await Future.wait<void>(pending.cast<SeedOriginalSettlement>().map(
        (SeedOriginalSettlement original) => original.settlement,
      )).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // The original is still owned by its existing sender.
    }
    requireCurrent();
    final Set<Object> current = Set<Object>.identity()
      ..addAll(source.originals().map((SeedOriginal value) => value.identity));
    if (originals.any(
      (SeedOriginal value) => !current.contains(value.identity),
    )) {
      throw const SeedRefused('original-publication-replaced');
    }
  }

  /// [tapOnce] is the real pointer path. No API here signs or sends a block.
  Future<String> publish(
    String recipe,
    Future<void> Function() tapOnce, {
    Future<void> Function()? requireReady,
  }) async {
    if (_labSend) {
      throw const SeedRefused('original-transfer-witness-required');
    }
    if (_attempted) throw const SeedRefused('original-attempt-held');
    await admit(recipe, waitForEarlier: true);
    if (requireReady != null) await _read<void>(requireReady);
    final List<SeedOriginal> originals = source.originals();
    _requireSettledOriginals(originals);
    final Set<Object> before =
        originals.map((SeedOriginal value) => value.identity).toSet();
    requireCurrent();
    journal.claim(recipe);
    _attempted = true;
    // Any exception after the claim leaves the attempt held. A timeout never
    // cancels, replaces, re-signs or retries the original wallet operation.
    await tapOnce();
    for (int poll = 0; poll < 60; poll++) {
      final List<SeedOriginal> added = source
          .originals()
          .where((SeedOriginal value) => !before.contains(value.identity))
          .toList();
      if (added.length > 1) {
        throw const SeedRefused('ambiguous-original-publication');
      }
      if (added.length == 1) {
        final SeedOriginal value = added.single;
        if (_original != null &&
            !identical(value.identity, _original!.identity)) {
          throw const SeedRefused('original-publication-replaced');
        }
        _original = value;
        final String? accepted = value.acceptedHash;
        if (accepted != null) {
          if (!seedHash(accepted) || _hash != null && _hash != accepted) {
            throw const SeedRefused('invalid-original-hash');
          }
          _hash = accepted;
          journal.accepted(recipe, accepted);
        }
        if (value.failed || value.releaseFailed) {
          throw const SeedRefused('original-outcome-unknown');
        }
        if (value.settled && _hash != null) break;
      }
      requireCurrent();
      await _delay(const Duration(milliseconds: 500));
    }
    if (_original == null || !_original!.settled || _hash == null) {
      throw const SeedRefused('original-outcome-unknown');
    }
    final String hash = _hash!;
    int absent = 0;
    int unconfirmed = 0;
    int effectPending = 0;
    SeedPendingResult last = SeedPendingResult.absent;
    SeedStakeEffectObservation? stakeEffect;
    SeedFundingObservation? fundingEffect;
    bool waitedForStakeEntry = false;
    bool waitedForReceive = false;
    const int rounds = 18;
    for (int poll = 0; poll < rounds; poll++) {
      stakeEffect = null;
      fundingEffect = null;
      final SeedConfirmed? block = await _read(
        () => source.confirmed(recipe, hash),
      );
      if (block != null &&
          (block.hash != hash ||
              block.owner != source.environment.owner ||
              block.chain != 321 ||
              !block.matchesRecipe)) {
        throw const SeedRefused('exact-original-receipt-mismatch');
      }
      if (block != null && block.positiveConfirmation) {
        if (await _read(() => source.effect(recipe, block))) {
          requireCurrent();
          journal.confirmed(recipe, hash);
          return hash;
        }
        effectPending++;
        last = SeedPendingResult.effectPending;
        if (recipe == 'stake' && source is SeedStakeEffectSource) {
          try {
            stakeEffect = (source as SeedStakeEffectSource)
                .observeStakeEffect(hash);
          } on Object {
            // Passive data cannot replace the original negative outcome.
          }
        }
        if (recipe == 'fund-address' && source is SeedFundingEffectSource) {
          try {
            fundingEffect = (source as SeedFundingEffectSource)
                .observeFundingEffect(hash);
          } on Object {
            // The observed receive cannot replace the ledger result.
          }
        }
      } else if (block == null) {
        absent++;
        last = SeedPendingResult.absent;
      } else {
        unconfirmed++;
        last = SeedPendingResult.unconfirmed;
      }
      final bool hasNextRound = poll + 1 < rounds;
      // Give an admitted receive time to settle within the same read budget.
      Duration delay = hasNextRound && fundingEffect?.waitingForReceive == true
          ? const Duration(seconds: 4)
          : const Duration(seconds: 2);
      if (hasNextRound &&
          !waitedForStakeEntry &&
          stakeEffect?.isEmpty == true) {
        // The lab's ten-second momentum cadence can delay the contract receive.
        waitedForStakeEntry = true;
        delay = const Duration(seconds: 12);
      }
      final Future<Object?>? tokenReceive =
          recipe == 'token' && last == SeedPendingResult.effectPending
              ? block?.pendingTokenHoldingReceive : null;
      final Future<Object?>? receive =
          fundingEffect?.pendingReceiveResult ?? tokenReceive;
      if (hasNextRound && !waitedForReceive && receive != null) {
        waitedForReceive = true;
        requireCurrent();
        // The original handle may have a non-nullable result type.
        await receive.then<void>((_) {}).timeout(
          const Duration(seconds: 45),
          onTimeout: () {},
        );
        requireCurrent();
      }
      await _delay(delay);
    }
    throw SeedRefused('exact-confirmation-or-effect-pending',
      stakeEffect: stakeEffect,
      confirmation: SeedConfirmationObservation._(
        absent: absent, unconfirmed: unconfirmed,
        effectPending: effectPending, last: last,
        funding: fundingEffect,
      ),
    );
  }
}
