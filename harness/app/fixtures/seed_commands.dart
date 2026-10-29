import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../seed/seed_recipe.dart';
import 'fixture_cleanup.dart';
import 'lab_seed_binding.dart';
import 'presentation_fixtures.dart';
import 'seed_policy.dart';
import 'seed_project_presentation.dart';

/// Reached only through the harness's authenticated, serial command queue.
final class SeedCommands {
  /// Captures real bindings only when an explicit begin command is admitted.
  SeedCommands();

  /// Injects inert lifecycle and policy owners without capturing a wallet.
  @visibleForTesting
  SeedCommands.withFixtureAdmission({
    required FixtureCleanup this._fixture,
    required SeedGuard this._guard,
    required String this._recipe,
    this._confirmed = false,
    this._projectPresentation,
  }) : _source = _guard.source;

  SeedGuard? _guard;
  SeedProjectPresentation? _projectPresentation;
  SeedSource? _source;
  String? _recipe;
  bool _confirmed = false;
  FixtureCleanup? _fixture;
  String? get fixtureName => _fixture?.heldName;

  Future<Map<String, Object?>> run(
    Map<String, dynamic> command, {
    required bool booted,
    required Future<Map<String, Object?>> Function(Map<String, dynamic>) ui,
    required Future<Map<String, Object?>> Function(
      Map<String, dynamic>,
      void Function(),
    )
    tap,
    SeedProjectPresentation Function(int)? captureProjectPresentation,
  }) async {
    try {
      final String? action = command['action'] as String?;
      if (<String>{'begin', 'fixture', 'prepare', 'publish'}.contains(action)) {
        _requireFixtureClear();
      }
      if (action == 'begin' || action == 'fixture') {
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
        _projectPresentation = null;
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
      final SeedSource? source = _source;
      if (guard == null || recipe == null || source == null) {
        throw const SeedRefused('explicit-seed-begin-required');
      }
      guard.requireCurrent();
      if (action == 'check') return <String, Object?>{'current': true};
      if (action == 'prepare') {
        void requirePreparation() {
          _requireFixtureClear();
          guard.requirePreparation();
          _requireFixtureClear();
        }

        requirePreparation();
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
        requirePreparation();
        await tap(<String, dynamic>{
          'cmd': 'tap',
          'ref': target['ref'],
          if (recipe == 'token' && exact['key'] == 'token_create_continue')
            'seedTokenPreparation': true,
        }, requirePreparation);
        return <String, Object?>{'prepared': true};
      }
      if (action == 'finish') {
        if (!_confirmed) throw const SeedRefused('exact-confirmation-required');
        if (recipe == 'project') {
          final SeedProjectPresentation? original = _projectPresentation;
          final String? hash = guard.acceptedHash;
          if (original == null || hash == null) {
            throw const SeedRefused('original-project-presentation-required');
          }
          void requireOriginalCompletion() {
            // A known completed exit is only a receipt read. An actual exit
            // retains fixture admission before and after the original guard.
            if (!original.closed) _requireFixtureClear();
            guard.requireCurrent();
            if (!original.closed) _requireFixtureClear();
          }
          requireOriginalCompletion();
          await original.close(hash, requireOriginalCompletion);
        }
        return <String, Object?>{
          'confirmed': true,
          'recipe': recipe,
          'hash': guard.acceptedHash,
        };
      }
      if (action != 'publish' || _confirmed) {
        throw const SeedRefused('seed-command-refused');
      }
      void requirePublication() {
        _requireFixtureClear();
        guard.requireCurrent();
        if (recipe == 'project') {
          _projectPresentation?.requireCaptured();
        }
        _requireFixtureClear();
      }

      requirePublication();
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
      if (recipe == 'project' && _projectPresentation == null) {
        final SeedProjectPresentation Function(int)? capture =
            captureProjectPresentation;
        if (capture == null) {
          throw const SeedRefused('original-project-presentation-required');
        }
        _projectPresentation = capture(originalRef);
      }
      requirePublication();
      final String hash = await guard.publish(recipe, () async {
        requirePublication();
        await tap(<String, dynamic>{
          'cmd': 'tap',
          'ref': originalRef,
          if (recipe == 'fund-address') ...<String, dynamic>{
            'seedOwner': source.environment.owner,
            'seedRecipient': source.environment.members[2],
            'seedToken': nativeStandard,
            'seedAmount': '1000000000',
          },
        }, requirePublication);
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

  void _requireFixtureClear() {
    if (fixtureName != null) {
      throw const SeedRefused('close-current-fixture-first');
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
    final FixtureCleanup cleanup = FixtureCleanup(name: kind);
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => SeedPresentationFixture(
        kind: kind,
        owner: source.environment.owner,
        originalSdk: source.originalSdk,
        isCurrent: () => source.isCurrent && route.isActive,
        cleanup: cleanup,
      ),
    );
    _fixture = cleanup;
    cleanup.open(
      routeCompleted: route.completed,
      push: () => navigator.push<void>(route),
    );
    return <String, Object?>{'fixture': kind, 'readOnly': true, 'chain': 321};
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
