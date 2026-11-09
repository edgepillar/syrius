import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:mocktail/mocktail.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart' as sdk;

import '../../harness/app/fixtures/fixture_cleanup.dart';
import '../../harness/app/fixtures/lab_seed_binding.dart';
import '../../harness/app/fixtures/seed_commands.dart';
import '../../harness/app/fixtures/seed_policy.dart';
import '../../harness/app/fixtures/seed_project_presentation.dart';
import '../../harness/app/fixtures/seed_stake_effect.dart';
import '../../harness/app/fixtures/seed_token_presentation.dart';

String _hash(int id) => id.toRadixString(16).padLeft(64, '0');

class _FundingLedger extends Mock implements sdk.LedgerApi {}

class _SeedProject extends Mock implements sdk.Project {}

sdk.HtlcInfo _depositEntry() => sdk.HtlcInfo(
  id: sdk.Hash.parse(_hash(9)),
  timeLocked: sdk.htlcAddress,
  hashLocked: sdk.acceleratorAddress,
  tokenStandard: sdk.znnZts,
  amount: BigInt.from(100000000),
  expirationTime: 100,
  hashType: 0,
  keyMaxSize: 32,
  hashLock: List<int>.filled(32, 0),
);

SeedEnvironment _environment({
  String profile = 'lab-fixture',
  bool isolated = true,
  bool unlocked = true,
  String ws = seedWsOrigin,
  String http = seedHttpOrigin,
  int nodeChain = 321,
  int signingChain = 321,
  int index = 1,
  List<String> members = const <String>['producer', 'owner', 'recipient'],
}) => SeedEnvironment(
  profile: profile,
  isolated: isolated,
  unlocked: unlocked,
  initialized: true,
  booted: true,
  ws: ws,
  http: http,
  nodeChain: nodeChain,
  signingChain: signingChain,
  selectedIndex: index,
  owner: 'owner',
  members: members,
);

class _Original implements SeedOriginal {
  @override
  final Object identity = Object();
  @override
  bool settled = true;
  @override
  bool failed = false;
  @override
  bool releaseFailed = false;
  @override
  String? acceptedHash = _hash(9);
}

class _SettlingOriginal extends _Original implements SeedOriginalSettlement {
  final Completer<void> observed = Completer<void>();
  final Completer<void> finished = Completer<void>();

  @override
  Future<void> get settlement {
    if (!observed.isCompleted) observed.complete();
    return finished.future;
  }
}

class _Journal implements SeedJournal {
  final Set<String> attempts = <String>{};
  final Map<String, String> acceptedHashes = <String, String>{};
  final Map<String, String> confirmedHashes = <String, String>{};
  @override
  void requireAvailable(String recipe) {
    if (attempts.contains(recipe) ||
        attempts.any((String id) => !confirmedHashes.containsKey(id))) {
      throw const SeedRefused('earlier-seed-attempt-held');
    }
  }

  @override
  void claim(String recipe) {
    requireAvailable(recipe);
    attempts.add(recipe);
  }

  @override
  void accepted(String recipe, String hash) {
    final String? original = acceptedHashes[recipe];
    if (original != null && original != hash) {
      throw const SeedRefused('original-hash-changed');
    }
    acceptedHashes[recipe] = hash;
  }

  @override
  void confirmed(String recipe, String hash) => confirmedHashes[recipe] = hash;
}

class _Source implements SeedSource {
  _Source({SeedEnvironment? environment})
    : environment = environment ?? _environment();
  @override
  final SeedEnvironment environment;
  @override
  bool isCurrent = true;
  bool advancingWs = true;
  bool advancingHttp = true;
  bool agreement = true;
  bool effectPresent = true;
  bool positiveConfirmation = true;
  Future<SeedConfirmed?> Function()? onConfirmation;
  Future<bool> Function()? onEffect;
  bool targetMatches = true;
  int wsReads = 0;
  int httpReads = 0;
  int confirmationReads = 0;
  int effectReads = 0;
  int delays = 0;
  String? receiptHash;
  String receiptOwner = 'owner';
  int receiptChain = 321;
  SeedFunding balance = SeedFunding(BigInt.from(100), BigInt.from(100));
  final List<SeedOriginal> operations = <SeedOriginal>[];
  Future<void> Function()? onWs;
  Future<void> delay(Duration duration) async {
    delays++;
  }

  @override
  Future<SeedFrontier> wsFrontier() async {
    wsReads++;
    await onWs?.call();
    return SeedFrontier(
      chain: 321,
      height: advancingWs ? wsReads + 10 : 10,
      timestamp: advancingWs ? wsReads + 100 : 100,
      hash: _hash(advancingWs ? wsReads + 10 : 10),
    );
  }

  @override
  Future<SeedFrontier> httpFrontier() async {
    httpReads++;
    return SeedFrontier(
      chain: 321,
      height: advancingHttp ? httpReads + 10 : 10,
      timestamp: advancingHttp ? httpReads + 100 : 100,
      hash: _hash(advancingHttp ? httpReads + 10 : 10),
    );
  }

  @override
  Future<bool> sameMomentum(SeedFrontier http) async => agreement;
  @override
  Future<SeedFunding> funding() async => balance;
  @override
  SeedFunding minimum(String recipe) => SeedFunding(BigInt.one, BigInt.one);
  @override
  List<SeedOriginal> originals() => List<SeedOriginal>.unmodifiable(operations);
  @override
  Future<SeedConfirmed?> confirmed(String recipe, String hash) async {
    confirmationReads++;
    if (onConfirmation != null) return onConfirmation!();
    return SeedConfirmed(
      hash: receiptHash ?? hash,
      owner: receiptOwner,
      chain: receiptChain,
      positiveConfirmation: positiveConfirmation,
      matchesRecipe: targetMatches,
    );
  }

  @override
  Future<bool> effect(String recipe, SeedConfirmed original) async {
    effectReads++;
    if (onEffect != null) return onEffect!();
    return effectPresent;
  }
}

class _ObservedStakeSource extends _Source implements SeedStakeEffectSource {
  SeedStakeEffectObservation? observation = SeedStakeEffectObservation.capture(
    reported: 0, returned: 0, entries: const <SeedStakeEffectPredicates>[],
  );
  bool diagnosticThrows = false;
  int observationReads = 0;

  @override
  SeedStakeEffectObservation? observeStakeEffect(String hash) {
    observationReads++;
    if (diagnosticThrows) throw StateError('Synthetic private diagnostic');
    return hash == _hash(9) ? observation : null;
  }
}

class _ObservedFundingSource extends _Source
    implements SeedFundingEffectSource {
  int observations = 0;
  Future<Object?>? receiveResult;
  final Completer<void> pendingObserved = Completer<void>();

  @override
  SeedFundingObservation? observeFundingEffect(String hash) {
    observations++;
    if (hash != _hash(9)) return null;
    final SeedFundingReceive receive = receiveResult != null
        ? SeedFundingReceive.pending
        : switch (effectReads) {
            1 => SeedFundingReceive.unseen,
            2 => SeedFundingReceive.pending,
            _ => SeedFundingReceive.accepted,
          };
    if (receive == SeedFundingReceive.pending && !pendingObserved.isCompleted) {
      pendingObserved.complete();
    }
    return SeedFundingObservation(
      ledger: SeedFundingLedger.balancePending,
      walletReceive: receive,
      pairedReceive: false,
      receiveResult: receiveResult,
    );
  }
}

void main() {
  late _Source source;
  late _Journal journal;
  late SeedGuard guard;
  setUp(() {
    source = _Source();
    journal = _Journal();
    guard = SeedGuard(source: source, journal: journal, delay: source.delay);
  });

  test('negative Stake counts distinguish each successive match', () {
    final SeedStakeEffectObservation observed =
        SeedStakeEffectObservation.capture(reported: 4, returned: 4,
      entries: const <SeedStakeEffectPredicates>[
        (identity: false, owner: true, amount: true, duration: true),
        (identity: true, owner: false, amount: true, duration: true),
        (identity: true, owner: true, amount: false, duration: true),
        (identity: true, owner: true, amount: true, duration: false),
      ],
    )!;
    expect(observed.public, <String, Object>{
      'schema': 1, 'scope': 'original_seed_stake_effect',
      'reported_rows': 4, 'returned_rows': 4, 'scan': 'COMPLETE',
      'id_matches': 3, 'owner_matches': 2, 'amount_matches': 1,
      'duration_matches': 0,
    });
    expect(observed.public.clear, throwsUnsupportedError);
    final String encoded = jsonEncode(observed.public);
    for (final String private in <String>[
      _hash(9), 'address', 'timestamp', 'receipt', 'retry', 'confirmed',
    ]) {
      expect(encoded.contains(private), isFalse);
    }
    final SeedStakeEffectObservation duplicate =
        SeedStakeEffectObservation.capture(reported: 2, returned: 2,
      entries: List<SeedStakeEffectPredicates>.filled(2,
        (identity: true, owner: true, amount: true, duration: true)),
    )!;
    expect(duplicate.public['duration_matches'], 2);
  });

  test('incomplete Stake list exposes no invented predicate counts', () {
    int scans = 0;
    final SeedStakeEffectObservation observed =
        SeedStakeEffectObservation.capture(reported: 65, returned: 64,
      entries: Iterable<SeedStakeEffectPredicates>.generate(64, (_) {
        scans++;
        return (identity: true, owner: true, amount: true, duration: true);
      }),
    )!;
    expect(scans, 0);
    expect(observed.public, <String, Object>{
      'schema': 1, 'scope': 'original_seed_stake_effect',
      'reported_rows': 65, 'returned_rows': 64, 'scan': 'NOT_RUN',
    });
  });

  test('Stake snapshots reject positive malformed and private data', () {
    const Map<String, Object> valid = <String, Object>{
      'schema': 1, 'scope': 'original_seed_stake_effect',
      'reported_rows': 0, 'returned_rows': 0, 'scan': 'COMPLETE',
      'id_matches': 0, 'owner_matches': 0, 'amount_matches': 0,
      'duration_matches': 0,
    };
    final List<Map<String, Object>> invalid = <Map<String, Object>>[
      <String, Object>{...valid, 'schema': true},
      <String, Object>{...valid, 'reported_rows': -1},
      <String, Object>{...valid, 'returned_rows': 65},
      <String, Object>{...valid, 'reported_rows': 1},
      <String, Object>{...valid, 'scan': 'NOT_RUN'},
      <String, Object>{...valid, 'owner_matches': 1},
      <String, Object>{...valid, 'id_matches': 0.0},
      <String, Object>{...valid, 'hash': _hash(9)},
      <String, Object>{...valid, 'address': 'Synthetic private address'},
      <String, Object>{...valid, 'reported_rows': 1, 'returned_rows': 1,
        'id_matches': 1, 'owner_matches': 1, 'amount_matches': 1,
        'duration_matches': 1},
      for (final String key in valid.keys)
        <String, Object>{...valid}..remove(key),
    ];
    for (final Object? value in <Object?>[null, true, <Object>[], ...invalid]) {
      expect(seedStakeEffectProjection(value), isNull);
    }
    expect(SeedStakeEffectObservation.capture(reported: 1, returned: 1,
      entries: const <SeedStakeEffectPredicates>[
        (identity: true, owner: true, amount: true, duration: true),
      ],
    ), isNull);
  });

  test('Stake capture bounds inconsistent and unending entry iterables', () {
    int visited = 0;
    expect(SeedStakeEffectObservation.capture(reported: 64, returned: 64,
      entries: Iterable<SeedStakeEffectPredicates>.generate(1000000, (_) {
        visited++;
        return (identity: false, owner: false, amount: false, duration: false);
      }),
    ), isNull);
    expect(visited, 65);
    expect(SeedStakeEffectObservation.capture(reported: 1, returned: 1,
      entries: const <SeedStakeEffectPredicates>[],
    ), isNull);
    expect(SeedStakeEffectObservation.capture(reported: -1, returned: 0,
      entries: const <SeedStakeEffectPredicates>[],
    ), isNull);
  });

  test('Stake failure attaches the same last negative read without retry',
      () async {
    final _ObservedStakeSource observed = _ObservedStakeSource()
      ..effectPresent = false;
    final List<Duration> waits = <Duration>[];
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: (Duration delay) async {
        if (observed.confirmationReads > 0) waits.add(delay);
      },
    );
    SeedRefused? refusal;
    int taps = 0;
    try {
      await current.publish('stake', () async {
        taps++;
        observed.operations.add(_Original());
      });
    } on SeedRefused catch (error) {
      refusal = error;
    }
    expect(refusal?.code, 'exact-confirmation-or-effect-pending');
    expect(refusal?.stakeEffect, same(observed.observation));
    expect(observed.confirmationReads, 18);
    expect(observed.effectReads, 18);
    expect(observed.observationReads, 18);
    expect(waits, <Duration>[
      const Duration(seconds: 12),
      ...List<Duration>.filled(17, const Duration(seconds: 2)),
    ]);
    expect(taps, 1);
    expect(journal.attempts, <String>{'stake'});
    expect(journal.confirmedHashes, isEmpty);
    expect(seedRefusalDetail(refusal!, action: 'publish')!['seedStakeEffect'],
        observed.observation!.public);
    await expectLater(current.publish('stake', () async { taps++; }),
        throwsA(isA<SeedRefused>()));
    expect(taps, 1);
  });

  test('late Stake confirmation leaves time for the original entry', () async {
    final _ObservedStakeSource observed = _ObservedStakeSource();
    observed.onConfirmation = () async => observed.confirmationReads <= 13
        ? null
        : SeedConfirmed(hash: _hash(9), owner: 'owner', chain: 321,
            positiveConfirmation: true, matchesRecipe: true);
    Duration effectTime = Duration.zero;
    observed.onEffect = () async => effectTime >= const Duration(seconds: 14);
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: (Duration delay) async {
        if (observed.effectReads > 0) effectTime += delay;
      },
    );
    int taps = 0;
    expect(await current.publish('stake', () async {
      taps++;
      observed.operations.add(_Original());
    }), _hash(9));
    expect(taps, 1);
    expect(observed.confirmationReads, 16);
    expect(observed.effectReads, 3);
    expect(observed.observationReads, 2);
    expect(effectTime, const Duration(seconds: 14));
    expect(journal.attempts, <String>{'stake'});
    expect(journal.confirmedHashes, <String, String>{'stake': _hash(9)});
  });

  test('a final absent round clears an earlier Stake observation', () async {
    final _ObservedStakeSource observed = _ObservedStakeSource()
      ..effectPresent = false;
    observed.onConfirmation = () async => observed.confirmationReads == 18
        ? null : SeedConfirmed(hash: _hash(9), owner: 'owner', chain: 321,
            positiveConfirmation: true, matchesRecipe: true);
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: observed.delay,
    );
    SeedRefused? refusal;
    try {
      await current.publish('stake', () async {
        observed.operations.add(_Original());
      });
    } on SeedRefused catch (error) {
      refusal = error;
    }
    expect(refusal?.code, 'exact-confirmation-or-effect-pending');
    expect(refusal?.confirmation?.public['last'], 'absent');
    expect(refusal?.stakeEffect, isNull);
    expect(observed.observationReads, 17);
    expect(observed.effectReads, 17);
    expect(observed.confirmationReads, 18);
    expect(seedRefusalDetail(refusal!, action: 'publish')!
        .containsKey('seedStakeEffect'), isFalse);
  });

  test('diagnostic failure preserves all original Stake refusal counts',
      () async {
    final _ObservedStakeSource observed = _ObservedStakeSource()
      ..effectPresent = false
      ..diagnosticThrows = true;
    final List<Duration> waits = <Duration>[];
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: (Duration delay) async {
        if (observed.confirmationReads > 0) waits.add(delay);
      },
    );
    SeedRefused? refusal;
    try {
      await current.publish('stake', () async {
        observed.operations.add(_Original());
      });
    } on SeedRefused catch (error) {
      refusal = error;
    }
    expect(refusal?.code, 'exact-confirmation-or-effect-pending');
    expect(refusal?.stakeEffect, isNull);
    expect(observed.confirmationReads, 18);
    expect(observed.effectReads, 18);
    expect(observed.observationReads, 18);
    expect(waits, List<Duration>.filled(18, const Duration(seconds: 2)));
    expect(journal.confirmedHashes, isEmpty);
  });

  test('positive effects and other recipes never request Stake diagnostics',
      () async {
    for (final String recipe in <String>['stake', 'fuse']) {
      final _ObservedStakeSource observed = _ObservedStakeSource()
        ..effectPresent = recipe == 'stake';
      final _Journal ledger = _Journal();
      final SeedGuard current = SeedGuard(
        source: observed, journal: ledger, delay: observed.delay,
      );
      Future<String> publish() => current.publish(recipe, () async {
        observed.operations.add(_Original());
      });
      if (recipe == 'stake') {
        expect(await publish(), _hash(9));
        expect(ledger.confirmedHashes[recipe], _hash(9));
      } else {
        await expectLater(publish(), throwsA(isA<SeedRefused>()));
        expect(ledger.confirmedHashes, isEmpty);
      }
      expect(observed.observationReads, 0);
    }
  });

  test('Fund Address paces only the admitted receive without extra reads',
      () async {
    for (final bool finalAbsent in <bool>[false, true]) {
      final _ObservedFundingSource observed = _ObservedFundingSource()
        ..effectPresent = false;
      observed.onConfirmation = () async => observed.confirmationReads == 1 ||
              (finalAbsent && observed.confirmationReads == 18)
          ? null : SeedConfirmed(hash: _hash(9), owner: 'owner', chain: 321,
              positiveConfirmation: true, matchesRecipe: true);
      final _Journal ledger = _Journal();
      final List<Duration> waits = <Duration>[];
      final SeedGuard current = SeedGuard(source: observed, journal: ledger,
        delay: (Duration duration) async { waits.add(duration); });
      SeedRefused? refusal;
      int taps = 0;
      try {
        await current.publish('fund-address', () async {
          taps++;
          observed.operations.add(_Original());
        });
      } on SeedRefused catch (error) {
        refusal = error;
      }
      expect(refusal?.code, 'exact-confirmation-or-effect-pending');
      expect(observed.confirmationReads, 18);
      expect(observed.effectReads, finalAbsent ? 16 : 17);
      expect(observed.observations, observed.effectReads);
      expect(waits.sublist(waits.length - 18), <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 2),
        ...List<Duration>.filled(15, const Duration(seconds: 4)),
        const Duration(seconds: 2),
      ]);
      final Object? funding = refusal?.confirmation?.public['funding'];
      expect(funding, finalAbsent ? null : <String, Object>{
        'ledger': 'balance_pending', 'wallet_receive': 'accepted',
        'paired_receive': false,
      });
      expect(ledger.attempts, <String>{'fund-address'});
      expect(ledger.confirmedHashes, isEmpty);
      await expectLater(current.publish('fund-address', () async { taps++; }),
          throwsA(isA<SeedRefused>()));
      expect(taps, 1);
    }
  });

  test('Fund Address waits for its original receive before reading again',
      () async {
    final Completer<Object> receive = Completer<Object>();
    final _ObservedFundingSource observed = _ObservedFundingSource()
      ..receiveResult = receive.future;
    observed.onEffect = () async => observed.effectReads == 3;
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: observed.delay,
    );
    int taps = 0;
    final Future<String> publication = current.publish(
      'fund-address',
      () async {
        taps++;
        observed.operations.add(_Original());
      },
    );
    await observed.pendingObserved.future;
    await Future<void>.delayed(Duration.zero);
    final int readsBeforeReceive = observed.confirmationReads;
    final bool confirmedBeforeReceive = journal.confirmedHashes.isNotEmpty;
    receive.complete(Object());
    expect(await publication, _hash(9));
    expect(readsBeforeReceive, 1);
    expect(confirmedBeforeReceive, isFalse);
    expect(observed.confirmationReads, 3);
    expect(observed.effectReads, 3);
    expect(taps, 1);
    expect(journal.confirmedHashes, <String, String>{'fund-address': _hash(9)});
  });

  testWidgets('Fund Address waits once for a still pending original receive',
      (WidgetTester tester) async {
    final _ObservedFundingSource observed = _ObservedFundingSource()
      ..receiveResult = Completer<Object>().future
      ..effectPresent = false;
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: observed.delay,
    );
    int taps = 0;
    final Future<void> refusal = expectLater(
      current.publish('fund-address', () async {
        taps++;
        observed.operations.add(_Original());
      }),
      throwsA(isA<SeedRefused>().having(
        (SeedRefused error) => error.confirmation?.public['funding'],
        'public funding',
        <String, Object>{
          'ledger': 'balance_pending', 'wallet_receive': 'pending',
          'paired_receive': false,
        },
      )),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 44));
    expect(observed.confirmationReads, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(observed.confirmationReads, 18);
    await refusal;
    expect(observed.effectReads, 18);
    expect(journal.attempts, <String>{'fund-address'});
    expect(journal.confirmedHashes, isEmpty);
    expect(taps, 1);
  });

  test('Fund Address rechecks its original context after waiting', () async {
    final Completer<Object> receive = Completer<Object>();
    final _ObservedFundingSource observed = _ObservedFundingSource()
      ..receiveResult = receive.future
      ..effectPresent = false;
    final SeedGuard current = SeedGuard(
      source: observed, journal: journal, delay: observed.delay,
    );
    final Future<void> refusal = expectLater(
      current.publish('fund-address', () async {
        observed.operations.add(_Original());
      }),
      throwsA(isA<SeedRefused>().having(
        (SeedRefused error) => error.code, 'code', 'original-context-changed',
      )),
    );
    await observed.pendingObserved.future;
    observed.isCurrent = false;
    receive.complete(Object());
    await refusal;
    expect(observed.confirmationReads, 1);
    expect(observed.effectReads, 1);
    expect(journal.attempts, <String>{'fund-address'});
    expect(journal.confirmedHashes, isEmpty);
  });

  test('Fund Address keeps exact receive and balance checks', () async {
    final sdk.Hash sendHash = sdk.Hash.parse(_hash(9));
    final sdk.Address recipient = sdk.Address.fromPublicKey(
      List<int>.filled(32, 1),
    );
    final Map<String, dynamic> confirmation = <String, dynamic>{
      'numConfirmations': 1,
      'momentumHeight': 11,
      'momentumHash': _hash(11),
      'momentumTimestamp': 100,
    };
    final Map<String, dynamic> wire = <String, dynamic>{
      ...sdk.AccountBlockTemplate.receive(sendHash).toJson(),
      'hash': _hash(10),
      'address': recipient.toString(),
      'chainIdentifier': 321,
      'descendantBlocks': const <dynamic>[],
      'basePlasma': 0,
      'usedPlasma': 0,
      'changesHash': sdk.emptyHash.toString(),
      'confirmationDetail': confirmation,
    };
    bool matches(Map<String, dynamic> value) => seedFundingReceiveMatches(
      sdk.AccountBlock.fromJson(value),
      recipient,
      sendHash,
    );

    expect(matches(wire), isTrue);
    expect(seedFundingReceiveMatches(null, recipient, sendHash), isFalse);
    for (final Map<String, dynamic> change in <Map<String, dynamic>>[
      <String, dynamic>{'hash': sdk.emptyHash.toString()},
      <String, dynamic>{'address': sdk.stakeAddress.toString()},
      <String, dynamic>{'chainIdentifier': 1},
      <String, dynamic>{'blockType': sdk.BlockTypeEnum.userSend.index},
      <String, dynamic>{'fromBlockHash': _hash(8)},
      <String, dynamic>{'confirmationDetail': null},
      <String, dynamic>{
        'confirmationDetail': <String, dynamic>{
          ...confirmation,
          'numConfirmations': 0,
        },
      },
    ]) {
      expect(matches(<String, dynamic>{...wire, ...change}), isFalse);
    }

    final _FundingLedger ledger = _FundingLedger();
    final List<sdk.AccountBlock> history = <sdk.AccountBlock>[];
    final BigInt requiredUnits = BigInt.from(1000000000);
    BigInt units = requiredUnits;
    when(() => ledger.getAccountInfoByAddress(recipient)).thenAnswer(
      (_) async => sdk.AccountInfo(
        address: recipient.toString(),
        blockCount: 1,
        balanceInfoList: <sdk.BalanceInfoListItem>[
          sdk.BalanceInfoListItem(token: kZnnCoin, balance: units),
        ],
      ),
    );
    when(() => ledger.getAccountBlocksByPage(recipient, pageSize: 64))
        .thenAnswer((_) async => sdk.AccountBlockList(list: history));
    Future<SeedFundingLedger> effect({required bool paired}) =>
        readSeedFundingEffect(
      ledger: ledger,
      recipient: recipient,
      original: SeedConfirmed(
        hash: sendHash.toString(),
        owner: 'owner',
        chain: 321,
        positiveConfirmation: true,
        matchesRecipe: true,
        fundAddressReceiveConfirmed: paired && matches(wire),
      ),
      requireCurrent: () {},
    );

    expect(await effect(paired: true), SeedFundingLedger.confirmed);
    units -= BigInt.one;
    expect(await effect(paired: true), SeedFundingLedger.balancePending);
    verify(() => ledger.getAccountInfoByAddress(recipient)).called(2);
    verifyNever(() => ledger.getAccountBlocksByPage(recipient, pageSize: 64));

    units = requiredUnits;
    expect(await effect(paired: false), SeedFundingLedger.receivePending);
    final sdk.AccountBlock receive = sdk.AccountBlock.fromJson(wire);
    history.add(receive);
    expect(await effect(paired: false), SeedFundingLedger.confirmed);
    history.add(receive);
    expect(await effect(paired: false), SeedFundingLedger.receivePending);
    verify(() => ledger.getAccountBlocksByPage(recipient, pageSize: 64))
        .called(3);
  });

  test('a current deposit entry retains its original result identity',
      () async {
    final sdk.HtlcInfo original = _depositEntry();
    int reads = 0;
    int owners = 0;
    final sdk.HtlcInfo? result = await readSeedContractEntry<sdk.HtlcInfo>(
      read: () async { reads++; return original; },
      requireCurrent: () { owners++; },
    );
    expect(identical(result, original), isTrue);
    expect(reads, 1);
    expect(owners, 2);
  });

  test('the exact typed missing deposit reply remains pending', () async {
    int reads = 0;
    int owners = 0;
    final sdk.HtlcInfo? result = await readSeedContractEntry<sdk.HtlcInfo>(
      read: () async {
        reads++;
        throw rpc.RpcException(-32000, 'data non existent');
      },
      requireCurrent: () { owners++; },
    );
    expect(result, isNull);
    expect(reads, 1);
    expect(owners, 2);
  });

  test('other RPC codes messages and data retain the original error', () async {
    for (final rpc.RpcException error in <rpc.RpcException>[
      rpc.RpcException(-32601, 'data non existent'),
      rpc.RpcException(-32000, 'contract does not exist'),
      rpc.RpcException(-32000, 'data non existent', data: <String, Object>{
        'unexpected': true,
      }),
    ]) {
      int reads = 0;
      int owners = 0;
      await expectLater(readSeedContractEntry<sdk.HtlcInfo>(
        read: () async { reads++; throw error; },
        requireCurrent: () { owners++; },
      ), throwsA(same(error)));
      expect(reads, 1);
      expect(owners, 2);
    }
  });

  test('lookalike deposit errors and malformed replies are never pending',
      () async {
    for (final Object error in <Object>[
      Exception('data non existent'),
      const FormatException('Synthetic malformed entry'),
      StateError('Synthetic missing transport'),
    ]) {
      int owners = 0;
      await expectLater(readSeedContractEntry<sdk.HtlcInfo>(
        read: () async {
          if (error is Exception) throw error;
          if (error is Error) throw error;
          fail('Synthetic failures must be errors or exceptions');
        },
        requireCurrent: () { owners++; },
      ), throwsA(same(error)));
      expect(owners, 2);
    }
  });

  test('a refused deposit owner prevents the original read', () async {
    final StateError error = StateError('Synthetic owner changed');
    int reads = 0;
    await expectLater(readSeedContractEntry<sdk.HtlcInfo>(
      read: () async { reads++; return _depositEntry(); },
      requireCurrent: () { throw error; },
    ), throwsA(same(error)));
    expect(reads, 0);
  });

  test('owner replacement after a deposit result refuses that result',
      () async {
    final StateError error = StateError('Synthetic owner changed');
    bool current = true;
    await expectLater(readSeedContractEntry<sdk.HtlcInfo>(
      read: () async { current = false; return _depositEntry(); },
      requireCurrent: () { if (!current) throw error; },
    ), throwsA(same(error)));
  });

  test('owner replacement after a missing reply refuses pending admission',
      () async {
    final StateError error = StateError('Synthetic owner changed');
    bool current = true;
    await expectLater(readSeedContractEntry<sdk.HtlcInfo>(
      read: () async {
        current = false;
        throw rpc.RpcException(-32000, 'data non existent');
      },
      requireCurrent: () { if (!current) throw error; },
    ), throwsA(same(error)));
  });

  test('a pending deposit uses one publication before its later effect',
      () async {
    int reads = 0;
    int publications = 0;
    source.onEffect = () async {
      final sdk.HtlcInfo? entry = await readSeedContractEntry<sdk.HtlcInfo>(
        read: () async {
          if (++reads == 1) {
            throw rpc.RpcException(-32000, 'data non existent');
          }
          return _depositEntry();
        },
        requireCurrent: () {
          if (!source.isCurrent) throw StateError('Synthetic owner changed');
        },
      );
      return entry?.id.toString() == _hash(9);
    };
    final String result = await guard.publish('deposit', () async {
      publications++;
      source.operations.add(_Original());
    });
    expect(result, _hash(9));
    expect(reads, 2);
    expect(source.effectReads, 2);
    expect(publications, 1);
    expect(journal.attempts, <String>{'deposit'});
    expect(journal.confirmedHashes, <String, String>{'deposit': _hash(9)});
  });

  test('a pending project keeps its original publication while it appears',
      () async {
    final sdk.Project original = _SeedProject();
    int reads = 0;
    int publications = 0;
    source.onEffect = () async {
      final sdk.Project? entry = await readSeedContractEntry<sdk.Project>(
        read: () async {
          if (++reads == 1) {
            throw rpc.RpcException(-32000, 'data non existent');
          }
          return original;
        },
        requireCurrent: guard.requireCurrent,
      );
      return identical(entry, original);
    };
    final String result = await guard.publish('project', () async {
      publications++;
      source.operations.add(_Original());
    });
    expect(result, _hash(9));
    expect(reads, 2);
    expect(publications, 1);
    expect(journal.confirmedHashes, <String, String>{'project': _hash(9)});
  });

  test('a permanently missing deposit retains the original eighteen-read hold',
      () async {
    int publications = 0;
    source.onEffect = () async {
      final sdk.HtlcInfo? entry = await readSeedContractEntry<sdk.HtlcInfo>(
        read: () async {
          throw rpc.RpcException(-32000, 'data non existent');
        },
        requireCurrent: () {
          if (!source.isCurrent) throw StateError('Synthetic owner changed');
        },
      );
      return entry != null;
    };
    await expectLater(guard.publish('deposit', () async {
      publications++;
      source.operations.add(_Original());
    }), throwsA(isA<SeedRefused>().having(
      (SeedRefused error) => error.code,
      'code', 'exact-confirmation-or-effect-pending',
    )));
    expect(source.confirmationReads, 18);
    expect(source.effectReads, 18);
    expect(publications, 1);
    expect(journal.attempts, <String>{'deposit'});
    expect(journal.confirmedHashes, isEmpty);
  });

  test('only an explicit isolated unlocked profile can admit', () async {
    for (final SeedEnvironment environment in <SeedEnvironment>[
      _environment(profile: 'default'),
      _environment(isolated: false),
      _environment(unlocked: false),
    ]) {
      final _Source other = _Source(environment: environment);
      final SeedGuard scoped = SeedGuard(
        source: other,
        journal: _Journal(),
        delay: other.delay,
      );
      await expectLater(scoped.admit('stake'), throwsA(isA<SeedRefused>()));
      expect(other.wsReads, 0);
    }
  });

  test(
    'exact loopback origins and both chain identifiers are required',
    () async {
      for (final SeedEnvironment environment in <SeedEnvironment>[
        _environment(ws: 'ws://localhost:45998'),
        _environment(ws: '$seedWsOrigin/'),
        _environment(http: 'http://127.0.0.1:35997'),
        _environment(http: 'https://example.test'),
        _environment(nodeChain: 1),
        _environment(signingChain: 69),
      ]) {
        final _Source other = _Source(environment: environment);
        await expectLater(
          SeedGuard(
            source: other,
            journal: _Journal(),
            delay: other.delay,
          ).admit('stake'),
          throwsA(isA<SeedRefused>()),
        );
        expect(other.wsReads, 0);
      }
    },
  );

  test(
    'selected index and immutable exact membership are independent '
    'requirements',
    () {
      final List<String> members = <String>['producer', 'owner', 'recipient'];
      final SeedEnvironment captured = _environment(members: members);
      members[1] = 'replacement';
      expect(captured.members[1], 'owner');
      expect(captured.requireLab, returnsNormally);
      expect(_environment(index: 0).requireLab, throwsA(isA<SeedRefused>()));
      expect(
        _environment(members: <String>['owner', 'owner']).requireLab,
        throwsA(isA<SeedRefused>()),
      );
    },
  );

  test(
    'both frontiers must positively advance within six bounded polls',
    () async {
      for (final (bool, bool) endpoints in <(bool, bool)>[
        (true, false), (false, true), (false, false),
      ]) {
        source
          ..advancingWs = endpoints.$1
          ..advancingHttp = endpoints.$2
          ..wsReads = 0
          ..httpReads = 0
          ..delays = 0;
        SeedRefused? refusal;
        try {
          await guard.admit('stake');
        } on SeedRefused catch (error) {
          refusal = error;
        }
        expect(refusal?.code, 'advancing-momentum-required');
        final SeedRefused original = refusal!;
        final Map<String, Object> facts = original.frontier!.public;
        expect(facts, <String, Object>{
          'polls': 6,
          'ws_first_height': endpoints.$1 ? 11 : 10,
          'ws_last_height': endpoints.$1 ? 17 : 10,
          'ws_first_timestamp': endpoints.$1 ? 101 : 100,
          'ws_last_timestamp': endpoints.$1 ? 107 : 100,
          'ws_hash_changed': endpoints.$1,
          'http_first_height': endpoints.$2 ? 11 : 10,
          'http_last_height': endpoints.$2 ? 17 : 10,
          'http_first_timestamp': endpoints.$2 ? 101 : 100,
          'http_last_timestamp': endpoints.$2 ? 107 : 100,
          'http_hash_changed': endpoints.$2,
        });
        expect(() => facts['polls'] = 0, throwsUnsupportedError);
        final Map<String, Object> offered = Map<String, Object>.of(facts);
        final Map<String, Object> copied = seedAdvanceProjection(offered)!;
        offered['ws_first_height'] = 0;
        expect(copied, facts);
        expect(() => copied['polls'] = 0, throwsUnsupportedError);
        final Map<String, Object> detail =
            seedRefusalDetail(original, action: 'publish')!;
        expect(detail, <String, Object>{'seedAdvance': facts});
        expect(detail.clear, throwsUnsupportedError);
        for (final Object? action in <Object?>[
          'begin', 'check', 'prepare', 'finish', null, true,
        ]) {
          expect(seedRefusalDetail(original, action: action), isNull);
        }
        expect(seedRefusalDetail(SeedRefused('unknown',
          frontier: original.frontier), action: 'publish'), isNull);
        for (final Map<String, Object?> change in <Map<String, Object?>>[
          <String, Object?>{'polls': 5}, <String, Object?>{'polls': true},
          <String, Object?>{'ws_first_height': 0},
          <String, Object?>{'ws_last_height': 9},
          <String, Object?>{'http_last_height': 9007199254740992},
          <String, Object?>{'ws_last_timestamp': 100.0},
          <String, Object?>{'http_first_timestamp': null},
          <String, Object?>{'ws_hash_changed': 1},
          <String, Object?>{'hash': 'synthetic-private-value'},
        ]) {
          expect(seedAdvanceProjection(<String, Object?>{
            ...facts, ...change,
          }), isNull);
        }
        for (final String missing in facts.keys) {
          expect(seedAdvanceProjection(<String, Object>{
            for (final String key in facts.keys)
              if (key != missing) key: facts[key]!,
          }), isNull);
        }
        final String stationary = endpoints.$1 ? 'http' : 'ws';
        expect(seedAdvanceProjection(<String, Object>{
          ...facts, '${stationary}_hash_changed': true,
        }), isNull);
        expect(seedAdvanceProjection(<String, Object>{
          'polls': 6,
          for (final String endpoint in <String>['ws', 'http']) ...
            <String, Object>{
              '${endpoint}_first_height': 10,
              '${endpoint}_last_height': 11,
              '${endpoint}_first_timestamp': 100,
              '${endpoint}_last_timestamp': 101,
              '${endpoint}_hash_changed': true,
            },
        }), isNull);
        expect(source.wsReads, 7);
        expect(source.httpReads, 7);
        expect(source.delays, 6);
        expect(source.confirmationReads, 0);
        expect(source.effectReads, 0);
        expect(journal.attempts, isEmpty);
      }
    },
  );

  test(
    'same chain labels cannot replace exact cross-endpoint momentum agreement',
    () async {
      source.agreement = false;
      await expectLater(guard.admit('stake'), throwsA(isA<SeedRefused>()));
      expect(source.wsReads, 1);
      expect(journal.attempts, isEmpty);
    },
  );

  test('funding zero refuses before the UI publication control', () async {
    source.balance = SeedFunding(BigInt.zero, BigInt.from(100));
    int taps = 0;
    await expectLater(
      guard.publish('stake', () async {
        taps++;
      }),
      throwsA(isA<SeedRefused>()),
    );
    expect(taps, 0);
    expect(journal.attempts, isEmpty);
  });

  test(
    'revocation during a frontier read never recaptures a replacement source',
    () async {
      source.onWs = () async {
        source.isCurrent = false;
      };
      await expectLater(guard.admit('stake'), throwsA(isA<SeedRefused>()));
      source.isCurrent = true;
      expect(guard.requireCurrent, throwsA(isA<SeedRefused>()));
      expect(journal.attempts, isEmpty);
    },
  );

  test(
    'an earlier pending, failed or unreleased original prevents another tap',
    () async {
      int taps = 0;
      for (int flags = 1; flags < 8; flags++) {
        final _Original operation = _Original()
          ..settled = (flags & 1) == 0
          ..failed = (flags & 2) != 0
          ..releaseFailed = (flags & 4) != 0;
        source.operations
          ..clear()
          ..add(_Original())
          ..add(operation);
        SeedRefused? refusal;
        try {
          await guard.publish('stake', () async { taps++; });
        } on SeedRefused catch (error) {
          refusal = error;
        }
        expect(refusal?.code, 'earlier-original-unresolved');
        final SeedRefused original = refusal!;
        final Map<String, Object> facts = <String, Object>{
          'pending': (flags & 1) != 0, 'failed': (flags & 2) != 0,
          'release_failed': (flags & 4) != 0,
        };
        final Map<String, Object> detail = seedRefusalDetail(
          original, action: 'publish',
        )!;
        expect(detail, <String, Object>{'seedOriginals': facts});
        expect(detail.clear, throwsUnsupportedError);
        final Map<String, Object> observed =
            detail['seedOriginals']! as Map<String, Object>;
        expect(observed.clear, throwsUnsupportedError);
        operation
          ..settled = true
          ..failed = false
          ..releaseFailed = false;
        expect(observed, facts);
        final Map<String, Object> offered = Map<String, Object>.of(facts);
        final Map<String, Object> copied = seedOriginalProjection(offered)!;
        offered.clear();
        expect(copied, facts);
        expect(copied.clear, throwsUnsupportedError);
        for (final Object? action in <Object?>[
          'begin', 'check', 'prepare', 'finish', null, true,
        ]) {
          expect(seedRefusalDetail(original, action: action), isNull);
        }
        expect(seedRefusalDetail(SeedRefused('unknown',
          originals: original.originals), action: 'publish'), isNull);
        for (final Object? value in <Object?>[
          null, true, <Object>[], 'Synthetic',
          <String, Object>{...facts, 'path': 'Synthetic'},
          <String, Object>{...facts, 'hash': 'Synthetic'},
          <String, Object>{
            'pending': false, 'failed': false, 'release_failed': false,
          },
          for (final String key in facts.keys) ...<Object?>[
            <String, Object>{
              for (final String field in facts.keys)
                if (field != key) field: facts[field]!,
            },
            <String, Object>{...facts, key: 1},
            <String, Object?>{...facts, key: null},
          ],
        ]) {
          expect(seedOriginalProjection(value), isNull);
        }
        expect(journal.attempts, isEmpty);
        expect(journal.acceptedHashes, isEmpty);
        expect(journal.confirmedHashes, isEmpty);
      }
      expect(taps, 0);
      expect(source.wsReads, 14);
      expect(source.httpReads, 14);
      expect(source.delays, 7);
      expect(source.confirmationReads, 0);
      expect(source.effectReads, 0);
      expect(journal.attempts, isEmpty);
    },
  );

  test('a pending original must settle with the same identity and release',
      () async {
    for (final String outcome in <String>['success', 'release', 'replaced']) {
      final _Source earlier = _Source();
      final _SettlingOriginal original = _SettlingOriginal()..settled = false;
      earlier.operations.add(original);
      final _Journal ledger = _Journal();
      final SeedGuard current = SeedGuard(
        source: earlier, journal: ledger, delay: earlier.delay,
      );
      int taps = 0;
      final Future<String> result = current.publish('deposit', () async {
        taps++;
        earlier.operations.add(_Original());
      });
      await original.observed.future;
      expect(taps, 0);
      expect(ledger.attempts, isEmpty);
      if (outcome == 'replaced') {
        earlier.operations
          ..clear()
          ..add(_Original());
      }
      original
        ..settled = true
        ..releaseFailed = outcome == 'release'
        ..finished.complete();
      if (outcome == 'success') {
        expect(await result, _hash(9));
        expect(taps, 1);
        expect(ledger.confirmedHashes['deposit'], _hash(9));
      } else {
        final String code = outcome == 'release'
            ? 'earlier-original-unresolved' : 'original-publication-replaced';
        await expectLater(result, throwsA(isA<SeedRefused>().having(
          (SeedRefused error) => error.code, 'code', code,
        )));
        expect(taps, 0);
        expect(ledger.attempts, isEmpty);
      }
    }
  });

  test(
    'one tap retains the original accepted hash and requires exact '
    'effect proof',
    () async {
      int taps = 0;
      final String hash = await guard.publish('stake', () async {
        taps++;
        source.operations.add(_Original());
      });
      expect(hash, _hash(9));
      expect(taps, 1);
      expect(journal.confirmedHashes['stake'], hash);
      expect(source.confirmationReads, 1);
      expect(source.effectReads, 1);
    },
  );

  test(
    'multiple new originals are ambiguous and are never selected '
    'by resemblance',
    () async {
      await expectLater(
        guard.publish('stake', () async {
          source.operations.addAll(<SeedOriginal>[_Original(), _Original()]);
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(source.confirmationReads, 0);
      expect(journal.attempts, contains('stake'));
      expect(journal.confirmedHashes, isEmpty);
    },
  );

  test(
    'a tap exception holds its original attempt without a second tap',
    () async {
      int taps = 0;
      Future<void> tap() async {
        taps++;
        throw StateError('synthetic pointer failure');
      }

      await expectLater(
        guard.publish('stake', tap),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        guard.publish('stake', tap),
        throwsA(isA<SeedRefused>()),
      );
      expect(taps, 1);
      expect(journal.attempts, contains('stake'));
    },
  );
  test('preparation cannot continue after a claimed pointer failure', () async {
    expect(guard.requirePreparation, returnsNormally);
    await expectLater(
      guard.publish('stake', () async {
        expect(journal.attempts, <String>{'stake'});
        expect(
          guard.requirePreparation,
          throwsA(
            isA<SeedRefused>().having(
              (SeedRefused error) => error.code,
              'code',
              'original-attempt-held',
            ),
          ),
        );
        throw StateError('synthetic pointer failure');
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      guard.requirePreparation,
      throwsA(
        isA<SeedRefused>().having(
          (SeedRefused error) => error.code,
          'code',
          'original-attempt-held',
        ),
      ),
    );
    expect(journal.attempts, <String>{'stake'});
    expect(journal.acceptedHashes, isEmpty);
    expect(journal.confirmedHashes, isEmpty);
    expect(source.operations, isEmpty);
    expect(source.confirmationReads, 0);
    expect(source.effectReads, 0);
  });
  test('preparation latches original context revocation before any input', () {
    source.isCurrent = false;
    expect(
      guard.requirePreparation,
      throwsA(
        isA<SeedRefused>().having(
          (SeedRefused error) => error.code,
          'code',
          'original-context-changed',
        ),
      ),
    );
    source.isCurrent = true;
    expect(guard.requirePreparation, throwsA(isA<SeedRefused>()));
    expect(journal.attempts, isEmpty);
    expect(source.wsReads, 0);
    expect(source.httpReads, 0);
  });

  test(
    'an accepted hash stays retained when the original release fails',
    () async {
      final _Original operation = _Original()..releaseFailed = true;
      await expectLater(
        guard.publish('stake', () async {
          source.operations.add(operation);
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(guard.acceptedHash, _hash(9));
      expect(journal.acceptedHashes['stake'], _hash(9));
      expect(journal.confirmedHashes, isEmpty);
    },
  );

  test(
    'a toast or elapsed polls cannot establish chain confirmation',
    () async {
      source.positiveConfirmation = false;
      await expectLater(
        guard.publish('stake', () async {
          source.operations.add(_Original());
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(source.confirmationReads, 18);
      expect(source.effectReads, 0);
      expect(journal.confirmedHashes, isEmpty);
    },
  );

  test(
    'confirmed account send alone cannot establish a contract effect',
    () async {
      source.effectPresent = false;
      await expectLater(
        guard.publish('stake', () async {
          source.operations.add(_Original());
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(source.effectReads, 18);
      expect(journal.confirmedHashes, isEmpty);
    },
  );

  test(
    'changed hash, owner, chain or recipe receipt refuses the exact original',
    () async {
      for (int mismatch = 0; mismatch < 4; mismatch++) {
        final _Source other = _Source();
        if (mismatch == 0) other.receiptHash = _hash(10);
        if (mismatch == 1) other.receiptOwner = 'replacement';
        if (mismatch == 2) other.receiptChain = 1;
        if (mismatch == 3) other.targetMatches = false;
        final _Journal records = _Journal();
        final SeedGuard scoped = SeedGuard(
          source: other,
          journal: records,
          delay: other.delay,
        );
        await expectLater(
          scoped.publish('stake', () async {
            other.operations.add(_Original());
          }),
          throwsA(isA<SeedRefused>()),
        );
        expect(records.confirmedHashes, isEmpty);
      }
    },
  );

  test(
    'a context change after acceptance keeps the hash without stale '
    'confirmation',
    () async {
      await expectLater(
        guard.publish('stake', () async {
          source.operations.add(_Original());
          source.isCurrent = false;
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(guard.acceptedHash, _hash(9));
      expect(source.confirmationReads, 0);
      expect(journal.confirmedHashes, isEmpty);
    },
  );

  test(
    'an unsettled original remains held after a finite outcome window',
    () async {
      final _Original operation = _Original()
        ..settled = false
        ..acceptedHash = null;
      int taps = 0;
      await expectLater(
        guard.publish('stake', () async {
          taps++;
          source.operations.add(operation);
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(source.delays, 61);
      await expectLater(
        SeedGuard(
          source: source,
          journal: journal,
          delay: source.delay,
        ).publish('fuse', () async {
          taps++;
        }),
        throwsA(isA<SeedRefused>()),
      );
      expect(taps, 1);
    },
  );

  test('eighteen absent seed reads retain one held original attempt', () async {
    source.onConfirmation = () async => null;
    int taps = 0;
    Future<void> tap() async {
      taps++;
      source.operations.add(_Original());
    }
    SeedRefused? refusal;
    try {
      await guard.publish('fuse', tap);
    } on SeedRefused catch (error) {
      refusal = error;
    }
    expect(refusal?.code, 'exact-confirmation-or-effect-pending');
    expect(refusal?.confirmation?.public, <String, Object>{
      'polls': 18, 'absent': 18, 'unconfirmed': 0,
      'effect_pending': 0, 'last': 'absent',
    });
    expect(source.confirmationReads, 18);
    expect(source.effectReads, 0);
    expect(source.delays, 19);
    expect(taps, 1);
    expect(journal.acceptedHashes, <String, String>{'fuse': _hash(9)});
    expect(journal.confirmedHashes, isEmpty);
    await expectLater(guard.publish('fuse', tap),
        throwsA(isA<SeedRefused>()));
    expect(taps, 1);
    expect(source.confirmationReads, 18);
  });

  test('completed seed rounds distinguish absence confirmation and effect',
      () async {
    source
      ..effectPresent = false
      ..onConfirmation = () async {
        if (source.confirmationReads <= 6) return null;
        return SeedConfirmed(
          hash: _hash(9), owner: 'owner', chain: 321, matchesRecipe: true,
          positiveConfirmation: source.confirmationReads > 12,
        );
      };
    SeedRefused? refusal;
    try {
      await guard.publish('fuse', () async {
        source.operations.add(_Original());
      });
    } on SeedRefused catch (error) {
      refusal = error;
    }
    final Map<String, Object> observed = refusal!.confirmation!.public;
    expect(observed, <String, Object>{
      'polls': 18, 'absent': 6, 'unconfirmed': 6,
      'effect_pending': 6, 'last': 'effect_pending',
    });
    expect(() => observed['polls'] = 0, throwsUnsupportedError);
    expect(source.confirmationReads, 18);
    expect(source.effectReads, 6);
    expect(source.delays, 19);
    expect(journal.confirmedHashes, isEmpty);
  });

  test('a positive last seed round keeps its exact original success', () async {
    source.onConfirmation = () async => source.confirmationReads == 18
        ? SeedConfirmed(hash: _hash(9), owner: 'owner', chain: 321,
            positiveConfirmation: true, matchesRecipe: true)
        : null;
    expect(await guard.publish('fuse', () async {
      source.operations.add(_Original());
    }), _hash(9));
    expect(source.confirmationReads, 18);
    expect(source.effectReads, 1);
    expect(source.delays, 18);
    expect(journal.confirmedHashes, <String, String>{'fuse': _hash(9)});
  });

  test('an incomplete last effect never produces exhausted seed counts',
      () async {
    final Completer<bool> late = Completer<bool>();
    source.onEffect = () => source.effectReads == 18
        ? late.future : Future<bool>.value(false);
    final SeedGuard bounded = SeedGuard(source: source, journal: journal,
      delay: source.delay, readTimeout: const Duration(milliseconds: 1));
    await expectLater(bounded.publish('fuse', () async {
      source.operations.add(_Original());
    }), throwsA(isA<TimeoutException>()));
    expect(source.confirmationReads, 18);
    expect(source.effectReads, 18);
    expect(source.delays, 18);
    expect(journal.confirmedHashes, isEmpty);
    late.complete(false);
    await Future<void>.delayed(Duration.zero);
    expect(journal.confirmedHashes, isEmpty);
    expect(source.effectReads, 18);
    await expectLater(bounded.publish('fuse', () async {
      fail('An incomplete original must not be retried');
    }), throwsA(isA<SeedRefused>()));
    expect(source.effectReads, 18);
  });

  test('seed count projections retain bounded immutable completed rounds', () {
    for (final String last in <String>[
      'absent', 'unconfirmed', 'effect_pending',
    ]) {
      final Map<String, Object> offered = <String, Object>{
        'polls': 18, 'absent': 6, 'unconfirmed': 6,
        'effect_pending': 6, 'last': last,
      };
      final Map<String, Object> observed =
          seedConfirmationProjection(offered)!;
      expect(observed, offered);
      offered['absent'] = 0;
      expect(observed['absent'], 6);
      expect(() => observed['polls'] = 0, throwsUnsupportedError);
    }
  });

  test('seed count projections refuse coerced private and impossible data', () {
    const Map<String, Object> valid = <String, Object>{
      'polls': 18, 'absent': 6, 'unconfirmed': 6,
      'effect_pending': 6, 'last': 'effect_pending',
    };
    for (final Map<String, Object?> change in <Map<String, Object?>>[
      <String, Object?>{'polls': true}, <String, Object?>{'polls': 17},
      <String, Object?>{'absent': -1}, <String, Object?>{'absent': 19},
      <String, Object?>{'unconfirmed': 6.0},
      <String, Object?>{'effect_pending': null},
      <String, Object?>{'effect_pending': 5},
      <String, Object?>{'last': 'synthetic-private-value'},
      <String, Object?>{'hash': 'synthetic-private-value'},
    ]) {
      expect(seedConfirmationProjection(<String, Object?>{
        ...valid, ...change,
      }), isNull);
    }
    for (final String missing in valid.keys) {
      expect(seedConfirmationProjection(<String, Object>{
        for (final String key in valid.keys)
          if (key != missing) key: valid[key]!,
      }), isNull);
    }
    for (final Object? value in <Object?>[null, true, <Object>[], 'private']) {
      expect(seedConfirmationProjection(value), isNull);
    }
  });

  test('seed projections require a possible last result without authority', () {
    expect(seedConfirmationProjection(<String, Object>{
      'polls': 18, 'absent': 18, 'unconfirmed': 0,
      'effect_pending': 0, 'last': 'effect_pending',
    }), isNull);
    final Map<String, Object> observed = seedConfirmationProjection(
      <String, Object>{
        'polls': 18, 'absent': 0, 'unconfirmed': 0,
        'effect_pending': 18, 'last': 'effect_pending',
      },
    )!;
    for (final String key in <String>[
      'confirmed', 'complete', 'hash', 'retry', 'success', 'address',
    ]) {
      expect(observed.containsKey(key), isFalse);
    }
    expect(seedConfirmationProjection(null), isNull);
  });

  test('confirmed Project finish closes once and retains fixture admission',
      () async {
    expect(await guard.publish('project', () async {
      source.operations.add(_Original());
    }), _hash(9));
    expect(journal.confirmedHashes, <String, String>{'project': _hash(9)});
    final List<int> reads = <int>[
      source.wsReads, source.httpReads,
      source.confirmationReads, source.effectReads,
    ];
    final FixtureCleanup fixture = FixtureCleanup(name: 'sentinel');
    final Completer<Object?> route = Completer<Object?>();
    bool visible = true;
    int exits = 0;
    final SeedProjectPresentation presentation = SeedProjectPresentation(
      originalCurrent: () => visible,
      submittedCurrent: (String hash) => visible && hash == _hash(9),
      originalRouteCompleted: route.future,
      tapOriginalExit: (void Function() admission) async {
        admission();
        exits++;
        admission();
        visible = false;
        route.complete(null);
      },
    );
    SeedCommands commands({required bool confirmed}) =>
        SeedCommands.withFixtureAdmission(
      fixture: fixture, guard: guard, recipe: 'project',
      confirmed: confirmed, projectPresentation: presentation,
    );
    Future<Map<String, Object?>> finish(SeedCommands original) => original.run(
      <String, dynamic>{'action': 'finish'}, booted: false,
      ui: (_) async => throw StateError('Unexpected generic UI query'),
      captureTap: (_) => throw StateError('Unexpected generic pointer'),
    );
    await expectLater(finish(commands(confirmed: false)),
      throwsA(isA<SeedRefused>()
        .having((SeedRefused error) => error.code,
            'code', 'exact-confirmation-required')));
    final SeedCommands original = commands(confirmed: true);
    await expectLater(finish(original), throwsA(isA<SeedRefused>()
        .having((SeedRefused error) => error.code,
            'code', 'close-current-fixture-first')));
    expect(exits, 0);
    expect(presentation.closed, isFalse);
    final Object fixtureOwner = Object();
    fixture
      ..open(routeCompleted: Future<void>.value(),
          push: Future<void>.value)
      ..attach(fixtureOwner)
      ..dispose(owner: fixtureOwner, dispose: <void Function()>[],
          close: <Future<void> Function()>[], stateDisposed: () {});
    await Future<void>.delayed(Duration.zero);
    expect(fixture.heldName, isNull);
    final Map<String, Object?> receipt = await finish(original);
    expect(receipt, <String, Object?>{
      'confirmed': true, 'recipe': 'project', 'hash': _hash(9),
    });
    expect(presentation.closed, isTrue);
    expect(exits, 1);
    expect(() => fixture.attach(Object()), throwsStateError);
    expect(fixture.heldName, 'sentinel');
    expect(await finish(original), receipt);
    expect(exits, 1);
    expect(source.operations, hasLength(1));
    expect(<int>[source.wsReads, source.httpReads,
      source.confirmationReads, source.effectReads], reads);
    expect(journal.acceptedHashes, <String, String>{'project': _hash(9)});
    expect(journal.confirmedHashes, <String, String>{'project': _hash(9)});
  });

  test('Project capture precedes only its original exclusive publication',
      () async {
    for (final String phase in <String>['missing', 'replaced', 'captured']) {
      final _Source original = _Source();
      final _Journal ledger = _Journal();
      final SeedGuard scoped = SeedGuard(
        source: original, journal: ledger, delay: original.delay,
      );
      final FixtureCleanup fixture = FixtureCleanup(name: 'sentinel');
      final Object fixtureOwner = Object();
      fixture
        ..open(routeCompleted: Future<void>.value(),
            push: Future<void>.value)
        ..attach(fixtureOwner)
        ..dispose(owner: fixtureOwner, dispose: <void Function()>[],
            close: <Future<void> Function()>[], stateDisposed: () {});
      await Future<void>.delayed(Duration.zero);
      expect(fixture.heldName, isNull);
      bool live = phase != 'replaced';
      int captures = 0;
      int publications = 0;
      int exits = 0;
      final Completer<Object?> route = Completer<Object?>();
      final SeedProjectPresentation presentation = SeedProjectPresentation(
        originalCurrent: () => live,
        submittedCurrent: (String hash) => live && hash == _hash(9),
        originalRouteCompleted: route.future,
        tapOriginalExit: (void Function() admission) async {
          admission();
          exits++;
          admission();
          route.complete(null);
        },
      );
      final SeedCommands commands = SeedCommands.withFixtureAdmission(
        fixture: fixture, guard: scoped, recipe: 'project',
      );
      Future<Map<String, Object?>> publish() => commands.run(
        <String, dynamic>{'action': 'publish'}, booted: false,
        ui: (Map<String, dynamic> request) async {
          expect(request, <String, dynamic>{
            'cmd': 'assert', 'text': 'Submit',
            'kind': 'button', 'exact': true,
          });
          return <String, Object?>{
            'target': <String, Object?>{'ref': 7},
          };
        },
        captureTap: (Map<String, dynamic> request) =>
            (void Function() admission) async {
              admission();
              admission();
              expect(request, <String, dynamic>{'cmd': 'tap', 'ref': 7});
              publications++;
              original.operations.add(_Original());
            },
        captureProjectPresentation: phase == 'missing' ? null : (int ref) {
          captures++;
          expect(ref, 7);
          expect(original.operations, isEmpty);
          expect(original.wsReads, 0);
          expect(original.httpReads, 0);
          expect(ledger.attempts, isEmpty);
          return presentation;
        },
      );
      if (phase != 'captured') {
        await expectLater(publish(), throwsA(isA<SeedRefused>()));
        expect(captures, phase == 'missing' ? 0 : 1);
        expect(publications, 0);
        expect(exits, 0);
        expect(original.operations, isEmpty);
        expect(ledger.attempts, isEmpty);
        expect(original.wsReads, 0);
        if (phase == 'replaced') {
          live = true;
          await expectLater(publish(), throwsA(isA<SeedRefused>()));
          expect(captures, 1);
          expect(publications, 0);
        }
        route.complete(null);
        continue;
      }
      final Map<String, Object?> receipt = await publish();
      expect(receipt, <String, Object?>{
        'confirmed': true, 'recipe': 'project', 'hash': _hash(9),
      });
      expect(captures, 1);
      expect(publications, 1);
      expect(exits, 0);
      final Map<String, Object?> finished = await commands.run(
        <String, dynamic>{'action': 'finish'}, booted: false,
        ui: (_) async => throw StateError('Unexpected generic UI query'),
        captureTap: (_) => throw StateError('Unexpected generic pointer'),
      );
      expect(finished, receipt);
      expect(presentation.closed, isTrue);
      expect(exits, 1);
      await expectLater(publish(), throwsA(isA<SeedRefused>()));
      expect(captures, 1);
      expect(publications, 1);
      expect(original.operations, hasLength(1));
      expect(ledger.confirmedHashes,
          <String, String>{'project': _hash(9)});
    }
  });
  test('confirmed Token finish closes once and retains fixture admission',
      () async {
    expect(await guard.publish('token', () async {
      source.operations.add(_Original());
    }), _hash(9));
    expect(journal.confirmedHashes, <String, String>{'token': _hash(9)});
    final List<int> reads = <int>[
      source.wsReads, source.httpReads,
      source.confirmationReads, source.effectReads,
    ];
    final FixtureCleanup fixture = FixtureCleanup(name: 'sentinel');
    final Completer<Object?> route = Completer<Object?>();
    bool visible = true;
    int exits = 0;
    final SeedTokenPresentation presentation = SeedTokenPresentation(
      originalCurrent: () => visible,
      submittedCurrent: (String hash) => visible && hash == _hash(9),
      originalRouteCompleted: route.future,
      tapOriginalExit: (void Function() admission) async {
        admission();
        exits++;
        admission();
        visible = false;
        route.complete(null);
      },
    );
    SeedCommands commands({required bool confirmed}) =>
        SeedCommands.withFixtureAdmission(
      fixture: fixture, guard: guard, recipe: 'token',
      confirmed: confirmed, tokenPresentation: presentation,
    );
    Future<Map<String, Object?>> finish(SeedCommands original) => original.run(
      <String, dynamic>{'action': 'finish'}, booted: false,
      ui: (_) async => throw StateError('Unexpected generic UI query'),
      captureTap: (_) => throw StateError('Unexpected generic pointer'),
    );
    await expectLater(finish(commands(confirmed: false)),
      throwsA(isA<SeedRefused>()
        .having((SeedRefused error) => error.code,
            'code', 'exact-confirmation-required')));
    final SeedCommands original = commands(confirmed: true);
    await expectLater(finish(original), throwsA(isA<SeedRefused>()
        .having((SeedRefused error) => error.code,
            'code', 'close-current-fixture-first')));
    expect(exits, 0);
    expect(presentation.closed, isFalse);
    final Object fixtureOwner = Object();
    fixture
      ..open(routeCompleted: Future<void>.value(),
          push: Future<void>.value)
      ..attach(fixtureOwner)
      ..dispose(owner: fixtureOwner, dispose: <void Function()>[],
          close: <Future<void> Function()>[], stateDisposed: () {});
    await Future<void>.delayed(Duration.zero);
    expect(fixture.heldName, isNull);
    final Map<String, Object?> receipt = await finish(original);
    expect(receipt, <String, Object?>{
      'confirmed': true, 'recipe': 'token', 'hash': _hash(9),
    });
    expect(presentation.closed, isTrue);
    expect(exits, 1);
    expect(() => fixture.attach(Object()), throwsStateError);
    expect(fixture.heldName, 'sentinel');
    expect(await finish(original), receipt);
    expect(exits, 1);
    expect(source.operations, hasLength(1));
    expect(<int>[source.wsReads, source.httpReads,
      source.confirmationReads, source.effectReads], reads);
    expect(journal.acceptedHashes, <String, String>{'token': _hash(9)});
    expect(journal.confirmedHashes, <String, String>{'token': _hash(9)});
  });

  test('Token capture precedes only its original exclusive publication',
      () async {
    for (final String phase in <String>['missing', 'replaced', 'captured']) {
      final _Source original = _Source();
      final _Journal ledger = _Journal();
      final SeedGuard scoped = SeedGuard(
        source: original, journal: ledger, delay: original.delay,
      );
      final FixtureCleanup fixture = FixtureCleanup(name: 'sentinel');
      final Object fixtureOwner = Object();
      fixture
        ..open(routeCompleted: Future<void>.value(),
            push: Future<void>.value)
        ..attach(fixtureOwner)
        ..dispose(owner: fixtureOwner, dispose: <void Function()>[],
            close: <Future<void> Function()>[], stateDisposed: () {});
      await Future<void>.delayed(Duration.zero);
      expect(fixture.heldName, isNull);
      bool live = phase != 'replaced';
      int captures = 0;
      int publications = 0;
      int exits = 0;
      final Completer<Object?> route = Completer<Object?>();
      final SeedTokenPresentation presentation = SeedTokenPresentation(
        originalCurrent: () => live,
        submittedCurrent: (String hash) => live && hash == _hash(9),
        originalRouteCompleted: route.future,
        tapOriginalExit: (void Function() admission) async {
          admission();
          exits++;
          admission();
          route.complete(null);
        },
      );
      final SeedCommands commands = SeedCommands.withFixtureAdmission(
        fixture: fixture, guard: scoped, recipe: 'token',
      );
      Future<Map<String, Object?>> publish() => commands.run(
        <String, dynamic>{'action': 'publish'}, booted: false,
        ui: (Map<String, dynamic> request) async {
          expect(request, <String, dynamic>{
            'cmd': 'assert', 'key': 'token_create_continue',
            'kind': 'button', 'exact': true,
          });
          return <String, Object?>{
            'target': <String, Object?>{'ref': 7},
          };
        },
        captureTap: (Map<String, dynamic> request) =>
            (void Function() admission) async {
              admission();
              admission();
              expect(request, <String, dynamic>{'cmd': 'tap', 'ref': 7});
              publications++;
              original.operations.add(_Original());
            },
        captureTokenPresentation: phase == 'missing'
            ? null : (int ref, String owner) {
          expect(owner, 'owner');
          captures++;
          expect(ref, 7);
          expect(original.operations, isEmpty);
          expect(original.wsReads, 0);
          expect(original.httpReads, 0);
          expect(ledger.attempts, isEmpty);
          return presentation;
        },
      );
      if (phase != 'captured') {
        await expectLater(publish(), throwsA(isA<SeedRefused>()));
        expect(captures, phase == 'missing' ? 0 : 1);
        expect(publications, 0);
        expect(exits, 0);
        expect(original.operations, isEmpty);
        expect(ledger.attempts, isEmpty);
        expect(original.wsReads, 0);
        if (phase == 'replaced') {
          live = true;
          await expectLater(publish(), throwsA(isA<SeedRefused>()));
          expect(captures, 1);
          expect(publications, 0);
        }
        route.complete(null);
        continue;
      }
      final Map<String, Object?> receipt = await publish();
      expect(receipt, <String, Object?>{
        'confirmed': true, 'recipe': 'token', 'hash': _hash(9),
      });
      expect(captures, 1);
      expect(publications, 1);
      expect(exits, 0);
      final Map<String, Object?> finished = await commands.run(
        <String, dynamic>{'action': 'finish'}, booted: false,
        ui: (_) async => throw StateError('Unexpected generic UI query'),
        captureTap: (_) => throw StateError('Unexpected generic pointer'),
      );
      expect(finished, receipt);
      expect(presentation.closed, isTrue);
      expect(exits, 1);
      await expectLater(publish(), throwsA(isA<SeedRefused>()));
      expect(captures, 1);
      expect(publications, 1);
      expect(original.operations, hasLength(1));
      expect(ledger.confirmedHashes,
          <String, String>{'token': _hash(9)});
    }
  });
}
