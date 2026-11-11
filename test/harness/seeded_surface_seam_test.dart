import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';

import '../../harness/app/fixtures/seed_policy.dart';
import '../../harness/app/fixtures/seeded_surface_seam.dart';
import '../../harness/wallet_address_context.dart';

WalletAddressContext _holderContext({
  List<String> members = const <String>['first', 'issuer', 'holder'],
  String selected = 'issuer',
  String saved = 'issuer',
  int revision = 20,
  int owner = 1,
}) => WalletAddressContext.parse(<String, dynamic>{
  'members': members, 'selected': selected, 'saved': saved,
  'revision': revision, 'owner': owner,
});

void main() {
  final String hash = List<String>.filled(64, '1').join();

  test('retired Token handoff retains one committed existing member', () {
    final WalletAddressContext original = _holderContext();
    WalletAddressContext current = original;
    final SeededTokenHolder holder = SeededTokenHolder(
      confirmedHash: hash, original: original,
      requireRetired: () {}, requireResources: () {},
      readContext: () => current,
    );
    expect(holder.standard, seedIssuedTokenStandard(hash).toString());
    holder.requireTransition();
    current = _holderContext(saved: 'holder');
    holder.requireTransition();
    current = _holderContext(
      selected: 'holder', saved: 'holder', revision: 21,
    );
    final WalletAddressContext selected = holder.requireSelected();
    expect(selected, same(current));
    expect(holder.requireSelected(), same(selected));
    final Map<String, Object> receipt = holder.selectionReceipt;
    expect(receipt, <String, Object>{
      'schema': 1, 'scope': 'owned_seeded_token_holder_selection',
      'members': 3, 'originalIndex': 1, 'selectedIndex': 2,
      'singleTransition': true, 'persisted': true,
      'originalResourcesCurrent': true, 'publicationRetired': true,
    });
    expect(() => receipt['members'] = 4, throwsUnsupportedError);
    expect(jsonEncode(receipt), isNot(contains(hash)));
    expect(jsonEncode(receipt), isNot(contains('zts1')));
    current = original;
    expect(holder.requireTransition, throwsA(isA<SeedRefused>()));
    current = selected;
    expect(holder.requireSelected, throwsA(isA<SeedRefused>()));
  });

  test('pending selection cannot become a positive holder receipt later', () {
    WalletAddressContext current = _holderContext(saved: 'holder');
    final SeededTokenHolder holder = SeededTokenHolder(
      confirmedHash: hash, original: _holderContext(),
      requireRetired: () {}, requireResources: () {},
      readContext: () => current,
    )..requireTransition();
    expect(holder.requireSelected, throwsA(isA<SeedRefused>()));
    current = _holderContext(
      selected: 'holder', saved: 'holder', revision: 21,
    );
    expect(holder.requireSelected, throwsA(isA<SeedRefused>()));
  });

  test('lost retirement, resources or exact selection stay held', () {
    for (final String loss in <String>[
      'retirement', 'resources', 'afterRead', 'owner', 'order', 'revision',
    ]) {
      bool retired = true;
      bool resources = true;
      bool failAfterRead = false;
      WalletAddressContext current = _holderContext();
      final SeededTokenHolder holder = SeededTokenHolder(
        confirmedHash: hash, original: current,
        requireRetired: () {
          if (!retired) throw StateError('Synthetic retired scope lost');
        },
        requireResources: () {
          if (!resources) throw StateError('Synthetic resources changed');
        },
        readContext: () {
          if (failAfterRead) resources = false;
          return current;
        },
      )..requireTransition();
      switch (loss) {
        case 'retirement': retired = false;
        case 'resources': resources = false;
        case 'afterRead': failAfterRead = true;
        case 'owner': current = _holderContext(owner: 2);
        case 'order': current = _holderContext(
          members: <String>['holder', 'issuer', 'first'],
        );
        case 'revision': current = _holderContext(revision: 22);
      }
      expect(holder.requireTransition, throwsA(isA<SeedRefused>()));
      retired = true;
      resources = true;
      failAfterRead = false;
      current = _holderContext();
      expect(holder.requireTransition, throwsA(isA<SeedRefused>()));
    }
  });

  test('holder handoff refuses missing confirmation or original selection', () {
    for (final WalletAddressContext original in <WalletAddressContext>[
      _holderContext(members: <String>['first', 'issuer']),
      _holderContext(members: <String>['first', 'issuer', 'holder', 'extra']),
      _holderContext(selected: 'first', saved: 'first'),
      _holderContext(saved: 'holder'),
    ]) {
      expect(() => SeededTokenHolder(
        confirmedHash: hash, original: original,
        requireRetired: () => fail('No retirement proof was admitted'),
        requireResources: () => fail('No resource capture was admitted'),
        readContext: () => fail('No selection was admitted'),
      ), throwsA(isA<SeedRefused>()));
    }
    expect(() => SeededTokenHolder(
      confirmedHash: '', original: _holderContext(),
      requireRetired: () {}, requireResources: () {},
      readContext: _holderContext,
    ), throwsA(isA<SeedRefused>()));
  });

  test('four gates in both original themes retain only fixed pointer facts',
      () async {
    int ownerChecks = 0;
    final List<String> themes = <String>[];
    for (final Seam kind in seededSurfaceControls.keys) {
      final SeededSurfaceSeam seam = SeededSurfaceSeam(
        confirmedHash: hash, seam: kind,
        requireCurrent: () { ownerChecks++; },
        observe: (String standard, Seam observed, String theme,
            void Function() current) async {
          expect(standard, seedIssuedTokenStandard(hash).toString());
          expect(observed, kind);
          current();
          await Future<void>.value();
          current();
          themes.add('${kind.name}:$theme');
        },
      );
      for (final String theme in <String>['dark', 'light']) {
        final Map<String, Object> receipt = await seam.observe(theme);
        expect(receipt, <String, Object>{
          'schema': 1,
          'scope': 'owned_seeded_surface_seam_pointer_observation',
          'seam': kind.name,
          'theme': theme,
          'pointerDispatched': true,
          'absorptionObserved': true,
          'originalReceiptCurrent': true,
          'nativeFrameObserved': true,
        });
        expect(jsonEncode(receipt), isNot(contains(hash)));
        expect(jsonEncode(receipt), isNot(contains('zts1')));
      }
    }
    expect(themes, <String>[
      for (final Seam kind in seededSurfaceControls.keys)
        for (final String theme in <String>['dark', 'light'])
          '${kind.name}:$theme',
    ]);
    expect(ownerChecks, 32);
  });

  test('missing or malformed confirmation refuses before observation', () {
    for (final String invalid in <String>[
      '', 'private detail', List<String>.filled(64, '0').join(),
    ]) {
      expect(
        () => SeededSurfaceSeam(
          confirmedHash: invalid, seam: Seam.tokenExplorer,
          requireCurrent: () => fail('No owner capture was admitted'),
          observe: (String _, Seam _, String _, void Function() _) async {
            fail('No pointer was admitted');
          },
        ),
        throwsA(isA<SeedRefused>()),
      );
    }
    expect(() => SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.sporks,
      requireCurrent: () => fail('No owner capture was admitted'),
      observe: (String _, Seam _, String _, void Function() _) async {
        fail('No pointer was admitted');
      },
    ), throwsA(isA<SeedRefused>()));
  });

  test('unknown theme holds the original before any pointer', () async {
    int probes = 0;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {},
      observe: (String _, Seam _, String _, void Function() _) async {
        probes++;
      },
    );
    await expectLater(
      seam.observe('private detail'), throwsA(isA<SeedRefused>()),
    );
    await expectLater(seam.observe('dark'), throwsA(isA<SeedRefused>()));
    expect(probes, 0);
  });

  test('repeated theme cannot replay or replace a successful pointer',
      () async {
    int probes = 0;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {},
      observe: (String _, Seam _, String _, void Function() _) async {
        probes++;
      },
    );
    await seam.observe('dark');
    await expectLater(seam.observe('dark'), throwsA(isA<SeedRefused>()));
    await expectLater(seam.observe('light'), throwsA(isA<SeedRefused>()));
    expect(probes, 1);
  });

  test('lost original owner stays held after it is restored', () async {
    bool current = false;
    int probes = 0;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {
        if (!current) throw StateError('private owner detail');
      },
      observe: (String _, Seam _, String _, void Function() _) async {
        probes++;
      },
    );
    await expectLater(seam.observe('dark'), throwsA(isA<SeedRefused>()));
    current = true;
    await expectLater(seam.observe('light'), throwsA(isA<SeedRefused>()));
    expect(probes, 0);
  });

  test('owner loss at a pointer boundary never emits a receipt', () async {
    bool current = true;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {
        if (!current) throw StateError('private owner detail');
      },
      observe: (String _, Seam _, String _, void Function() owner) async {
        current = false;
        owner();
      },
    );
    await expectLater(seam.observe('dark'), throwsA(isA<SeedRefused>()));
    current = true;
    await expectLater(seam.observe('light'), throwsA(isA<SeedRefused>()));
  });

  test('owner loss after observation never becomes a successful receipt',
      () async {
    bool current = true;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {
        if (!current) throw StateError('private owner detail');
      },
      observe: (String _, Seam _, String _, void Function() _) async {
        current = false;
      },
    );
    await expectLater(seam.observe('dark'), throwsA(isA<SeedRefused>()));
  });

  test('an observer error exports only a fixed refusal and stays held',
      () async {
    int probes = 0;
    final SeededSurfaceSeam seam = SeededSurfaceSeam(
      confirmedHash: hash, seam: Seam.tokenExplorer,
      requireCurrent: () {},
      observe: (String _, Seam _, String _, void Function() _) async {
        probes++;
        throw StateError('private response body');
      },
    );
    await expectLater(
      seam.observe('dark'),
      throwsA(isA<SeedRefused>().having(
        (SeedRefused error) => error.code,
        'code', 'seeded-surface-seam-refused',
      )),
    );
    await expectLater(seam.observe('light'), throwsA(isA<SeedRefused>()));
    expect(probes, 1);
  });
}
