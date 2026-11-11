import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';

import '../../harness/app/fixtures/seed_policy.dart';
import '../../harness/app/fixtures/seeded_surface_seam.dart';

void main() {
  final String hash = List<String>.filled(64, '1').join();

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
