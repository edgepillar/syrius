import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../seed/seed_recipe.dart';
import 'lab_seed_binding.dart';
import 'presentation_fixtures.dart';
import 'seed_policy.dart';

/// Reached only through the harness's authenticated, serial command queue.
final class SeedCommands {
  SeedGuard? _guard;
  LabSeedBinding? _source;
  String? _recipe;
  bool _confirmed = false;
  Route<void>? _fixture;
  String? _fixtureName;
  String? get fixtureName => _fixture?.isActive == true ? _fixtureName : null;

  Future<Map<String, Object?>> run(
    Map<String, dynamic> command, {
    required bool booted,
    required Future<Map<String, Object?>> Function(Map<String, dynamic>) ui,
    required Future<Map<String, Object?>> Function(
      Map<String, dynamic>,
      void Function(),
    )
    tap,
  }) async {
    try {
      final String? action = command['action'] as String?;
      if (action == 'begin' || action == 'fixture') {
        if (fixtureName != null) {
          throw const SeedRefused('close-current-fixture-first');
        }
        final String profile = command['profile'] as String? ?? '';
        final LabSeedBinding source = LabSeedBinding.capture(
          profile: profile,
          ws: command['ws'] as String? ?? '',
          http: command['http'] as String? ?? '',
          booted: booted,
          counterparty: command['counterparty'] as String?,
        );
        if (action == 'fixture') {
          return await _openFixture(command['kind'] as String? ?? '', source);
        }
        final String recipe = command['recipe'] as String? ?? '';
        if (!seedRecipeIds.contains(recipe) ||
            command['checkpointReady'] != true) {
          throw const SeedRefused('isolated-checkpoint-prerequisite-required');
        }
        if (recipe == 'deposit' && source.counterparty == null ||
            recipe == 'fund-address' && source.environment.members.length < 3) {
          throw const SeedRefused('recipe-prerequisite-missing');
        }
        final ProfileSeedJournal journal = ProfileSeedJournal(source.home)
          ..requireAvailable(recipe);
        _source = source;
        _recipe = recipe;
        _confirmed = false;
        _guard = SeedGuard(source: source, journal: journal);
        return <String, Object?>{
          'ready': true,
          'chain': 321,
          if (source.environment.members.length >= 3)
            'secondaryAddress': source.environment.members[2],
          if (source.counterparty != null) 'counterparty': source.counterparty,
        };
      }
      final SeedGuard? guard = _guard;
      final String? recipe = _recipe;
      final LabSeedBinding? source = _source;
      if (guard == null || recipe == null || source == null) {
        throw const SeedRefused('explicit-seed-begin-required');
      }
      guard.requireCurrent();
      if (action == 'check') return <String, Object?>{'current': true};
      if (action == 'prepare') {
        guard.requirePreparation();
        final Object? raw = command['selector'];
        if (raw is! List || raw.any((Object? value) => value is! String)) {
          throw const SeedRefused('seed-preparation-selector-refused');
        }
        final Map<String, Object> exact = seedPreparationTarget(
          recipe,
          raw.cast<String>(),
        );
        final Map<String, Object?> visible = await ui(<String, dynamic>{
          'cmd': 'assert',
          ...exact,
        });
        final Object? target = visible['target'];
        if (target is! Map ||
            target['enabled'] == false ||
            target['ref'] is! int) {
          throw const SeedRefused('enabled-preparation-control-required');
        }
        guard.requirePreparation();
        await tap(<String, dynamic>{
          'cmd': 'tap',
          'ref': target['ref'],
          if (recipe == 'token' && exact['key'] == 'token_create_continue')
            'seedTokenPreparation': true,
        }, guard.requirePreparation);
        return <String, Object?>{'prepared': true};
      }
      if (action == 'finish') {
        if (!_confirmed) throw const SeedRefused('exact-confirmation-required');
        return <String, Object?>{
          'confirmed': true,
          'recipe': recipe,
          'hash': guard.acceptedHash,
        };
      }
      if (action != 'publish' || _confirmed) {
        throw const SeedRefused('seed-command-refused');
      }
      final String nativeStandard = znnZts.toString();
      final List<String> selector = seedPublishSelector(recipe);
      final Map<String, dynamic> exact = selector.first == '--key'
          ? <String, dynamic>{
              'key': selector[1],
              'kind': 'button',
              'exact': true,
            }
          : <String, dynamic>{
              'text': 'Submit',
              'kind': 'button',
              'exact': true,
            };
      // Validate the actual visible control before consuming this recipe's
      // exclusive attempt marker. The guard is rechecked at pointer down/up.
      final Map<String, Object?> visible = await ui(<String, dynamic>{
        'cmd': 'assert',
        ...exact,
      });
      final Object? target = visible['target'];
      if (target is! Map ||
          target['enabled'] == false ||
          target['ref'] is! int) {
        throw const SeedRefused('enabled-publication-control-required');
      }
      // This internal ref retains the actual asserted element across the
      // advancing-frontier wait. A similarly labelled replacement is refused.
      final int originalRef = target['ref'] as int;
      guard.requireCurrent();
      final String hash = await guard.publish(recipe, () async {
        await tap(<String, dynamic>{
          'cmd': 'tap',
          'ref': originalRef,
          if (recipe == 'fund-address') ...<String, dynamic>{
            'seedOwner': source.environment.owner,
            'seedRecipient': source.environment.members[2],
            'seedToken': nativeStandard,
            'seedAmount': '1000000000',
          },
        }, guard.requireCurrent);
      });
      _confirmed = true;
      return <String, Object?>{
        'confirmed': true,
        'recipe': recipe,
        'hash': hash,
      };
    } on SeedRefused {
      rethrow;
    } on Object {
      // Do not return wallet paths, transport diagnostics or SDK payloads.
      throw const SeedRefused('seed-prerequisite-or-read-failed');
    }
  }

  Future<Map<String, Object?>> _openFixture(
    String kind,
    LabSeedBinding source,
  ) async {
    if (!<String>{'sentinel', 'aged-fuse'}.contains(kind)) {
      throw const SeedRefused('unknown-fixture');
    }
    final NavigatorState? navigator = app.globalNavigatorKey.currentState;
    if (navigator == null) throw const SeedRefused('fixture-route-unavailable');
    final SeedGuard proof = SeedGuard(
      source: source,
      journal: _NoPublicationJournal(),
    );
    await proof.admit('fuse');
    proof.requireCurrent();
    if (!navigator.mounted ||
        !identical(navigator, app.globalNavigatorKey.currentState)) {
      throw const SeedRefused('fixture-route-changed');
    }
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => SeedPresentationFixture(
        kind: kind,
        owner: source.environment.owner,
        originalSdk: source.originalSdk,
        isCurrent: () => source.isCurrent && route.isActive,
      ),
    );
    _fixture = route;
    _fixtureName = kind;
    final Future<void> closed = navigator.push<void>(route);
    unawaited(_watchFixture(route, closed));
    return <String, Object?>{'fixture': kind, 'readOnly': true, 'chain': 321};
  }

  Future<void> _watchFixture(Route<void> route, Future<void> closed) async {
    try {
      await closed;
    } finally {
      if (identical(_fixture, route)) {
        _fixture = null;
        _fixtureName = null;
      }
    }
  }
}

final class _NoPublicationJournal implements SeedJournal {
  @override
  void requireAvailable(String recipe) {}
  @override
  void claim(String recipe) =>
      throw const SeedRefused('fixture-publication-refused');
  @override
  void accepted(String recipe, String hash) =>
      throw const SeedRefused('fixture-publication-refused');
  @override
  void confirmed(String recipe, String hash) =>
      throw const SeedRefused('fixture-publication-refused');
}
