import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart' as app;
import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import '../../seed/seed_recipe.dart';
import 'fixture_cleanup.dart';
import 'lab_seed_binding.dart';
import 'presentation_fixtures.dart';
import 'seed_deposit_entry.dart';
import 'seed_deposit_presentation.dart';
import 'seed_policy.dart';
import 'seed_project_presentation.dart';
import 'seed_token_presentation.dart';
import 'seeded_surface_seam.dart';

/// Dispatches a captured control with admission checked at both boundaries.
typedef SeedTap = Future<void> Function(void Function() admission);

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
    bool catalogTokenHolding = false,
    this._projectPresentation,
    this._tokenPresentation,
    this._depositPresentation,
  }) : _source = _guard.source {
    _catalogTokenHolding = catalogTokenHolding;
  }

  SeedGuard? _guard;
  SeedProjectPresentation? _projectPresentation;
  SeedTokenPresentation? _tokenPresentation;
  SeedDepositPresentation? _depositPresentation;
  SeedSource? _source;
  String? _recipe;
  bool _confirmed = false;
  bool _catalogTokenHolding = false;
  final Map<Seam, SeededSurfaceSeam> _surfaceSeams =
      <Seam, SeededSurfaceSeam>{};
  bool _depositEntryAttempted = false;
  FixtureCleanup? _fixture;
  String? get fixtureName => _fixture?.heldName;

  /// The exact sponsorship remains observable across the owned selection.
  String? get confirmedPillarSponsorHash {
    final SeedSource? source = _source;
    return _confirmed && _recipe == 'fuse' && source is LabSeedBinding &&
            source.fuseTarget == SeedFuseTarget.pillarActor
        ? _guard?.acceptedHash : null;
  }

  Future<Map<String, Object?>> run(
    Map<String, dynamic> command, {
    required bool booted,
    required Future<Map<String, Object?>> Function(Map<String, dynamic>) ui,
    required SeedTap Function(Map<String, dynamic>) captureTap,
    bool restoredFunding = false,
    PillarSponsorAdmission? pillarSponsor,
    SeedDepositEntry Function(String)? captureDepositEntry,
    SeedProjectPresentation Function(int)? captureProjectPresentation,
    SeedTokenPresentation Function(int, String)? captureTokenPresentation,
    Future<void> Function(String, Seam, String, void Function())?
        observeSurfaceSeam,
    SeedDepositPresentation Function(int, String)? captureDepositPresentation,
  }) async {
    try {
      final String? action = command['action'] as String?;
      final bool catalogTokenHolding = command['catalogTokenHolding'] == true;
      if (command.containsKey('catalogTokenHolding') &&
          (!catalogTokenHolding ||
              action != 'begin' || command['recipe'] != 'token')) {
        throw const SeedRefused('recipe-prerequisite-missing');
      }
      if (pillarSponsor != null &&
          (restoredFunding || catalogTokenHolding || action != 'begin' ||
              command['recipe'] != 'fuse')) {
        throw const SeedRefused('recipe-prerequisite-missing');
      }
      if (<String>{'begin', 'fixture', 'prepare', 'publish'}.contains(action)) {
        _requireFixtureClear();
      }
      if (action == 'begin' || action == 'fixture') {
        final String recipe = action == 'begin'
            ? command['recipe'] as String? ?? '' : '';
        if (restoredFunding &&
            (action != 'begin' ||
                recipe != 'fuse' && recipe != 'fund-address')) {
          throw const SeedRefused('recipe-prerequisite-missing');
        }
        final String profile = command['profile'] as String? ?? '';
        final LabSeedBinding source = LabSeedBinding.capture(
          profile: profile,
          ws: command['ws'] as String? ?? '',
          http: command['http'] as String? ?? '',
          booted: booted,
          counterparty: command['counterparty'] as String?,
          restoredFunding: restoredFunding,
          catalogTokenHolding: catalogTokenHolding,
          pillarSponsor: pillarSponsor,
        );
        if (action == 'fixture') {
          return await _openFixture(command['kind'] as String? ?? '', source);
        }
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
        _catalogTokenHolding = catalogTokenHolding;
        _surfaceSeams.clear();
        _depositEntryAttempted = false;
        _projectPresentation = null;
        _tokenPresentation = null;
        _depositPresentation = null;
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
      final LabSeedBinding? labSource =
          source is LabSeedBinding ? source : null;
      final LabSeedBinding? restoredSource =
          labSource?.restoredFunding == true ? labSource : null;
      final SeedFuseTarget? fuseTarget = labSource?.fuseTarget;
      guard.requireCurrent();
      if (action == 'check') return <String, Object?>{'current': true};
      if (action == 'surface-seam') {
        final SeedTokenPresentation? presentation = _tokenPresentation;
        final String? hash = guard.acceptedHash;
        final String? theme = command['theme'] as String?;
        final Object? seamName = command['seam'];
        final Seam? seam = seamName is String
            ? Seam.values.asNameMap()[seamName] : null;
        if (command.keys.any((String key) =>
                !const <String>{'cmd', 'action', 'theme', 'hash', 'seam'}
                    .contains(key)) ||
            command.containsKey('cmd') && command['cmd'] != 'seed' ||
            !_catalogTokenHolding || !_confirmed || recipe != 'token' ||
            presentation == null || !presentation.closed || hash == null ||
            command['hash'] != hash ||
            theme == null || seam == null ||
            !seededSurfaceControls.containsKey(seam) ||
            observeSurfaceSeam == null) {
          throw const SeedRefused('confirmed-token-seam-required');
        }
        void current() {
          _requireFixtureClear();
          guard.requireCurrent();
          _requireFixtureClear();
          if (!_confirmed || _recipe != 'token' || !_catalogTokenHolding ||
              !identical(_guard, guard) || guard.acceptedHash != hash ||
              !identical(_tokenPresentation, presentation) ||
              !presentation.closed) {
            throw const SeedRefused('seeded-surface-seam-owner-changed');
          }
        }
        current();
        final SeededSurfaceSeam observation =
            _surfaceSeams[seam] ??= SeededSurfaceSeam(
          confirmedHash: hash,
          seam: seam,
          requireCurrent: current,
          observe: observeSurfaceSeam,
        );
        return await observation.observe(theme);
      }
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
          fuseTarget: fuseTarget,
        );
        if (recipe == 'deposit' && exact['key'] == 'p2p_warning_continue') {
          if (_depositEntryAttempted) {
            throw const SeedRefused('original-deposit-entry-held');
          }
          _depositEntryAttempted = true;
          final SeedDepositEntry Function(String)? capture =
              captureDepositEntry;
          if (capture == null) {
            throw const SeedRefused('original-deposit-entry-required');
          }
          final SeedDepositEntry original = capture(source.environment.owner);
          requirePreparation();
          await original.prepare(requirePreparation);
          return <String, Object?>{'prepared': true};
        }
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
        final SeedTap tap = captureTap(<String, dynamic>{
          'cmd': 'tap',
          'ref': target['ref'],
          if (recipe == 'token' && exact['key'] != 'tokens_create')
            'seedTokenPreparation': true,
        });
        await tap(requirePreparation);
        return <String, Object?>{'prepared': true};
      }
      if (action == 'finish') {
        if (!_confirmed) throw const SeedRefused('exact-confirmation-required');
        if (recipe == 'deposit') {
          final SeedDepositPresentation? original = _depositPresentation;
          final String? hash = guard.acceptedHash;
          if (original == null || hash == null) {
            throw const SeedRefused('original-deposit-presentation-required');
          }
          void requireOriginalDepositCompletion() {
            if (!original.closed) _requireFixtureClear();
            guard.requireCurrent();
            if (!original.closed) _requireFixtureClear();
          }
          requireOriginalDepositCompletion();
          await original.close(hash, requireOriginalDepositCompletion);
        }
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
        if (recipe == 'token') {
          final SeedTokenPresentation? original = _tokenPresentation;
          final String? hash = guard.acceptedHash;
          if (original == null || hash == null) {
            throw const SeedRefused('original-token-presentation-required');
          }
          void requireOriginalTokenCompletion() {
            if (!original.closed) _requireFixtureClear();
            guard.requireCurrent();
            if (!original.closed) _requireFixtureClear();
          }
          requireOriginalTokenCompletion();
          await original.close(hash, requireOriginalTokenCompletion);
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
        if (recipe == 'token') {
          _tokenPresentation?.requireCaptured();
        }
        if (recipe == 'deposit') {
          _depositPresentation?.requireCaptured();
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
      // Bind the asserted element before any other scan or frontier wait
      // can renumber the snapshot references.
      final int originalRef = target['ref'] as int;
      final SeedTap tap = captureTap(<String, dynamic>{
        'cmd': 'tap',
        'ref': originalRef,
        if (recipe == 'fuse' && fuseTarget != null) ...<String, dynamic>{
          'seedFuseTarget': fuseTarget,
          'seedFuseBeneficiary': labSource!.fuseBeneficiary,
        },
        if (recipe == 'fund-address') ...<String, dynamic>{
          'seedOwner': source.environment.owner,
          'seedRecipient': source.environment.members[2],
          'seedToken': nativeStandard,
          'seedAmount': '1000000000',
        },
      });
      if (recipe == 'project' && _projectPresentation == null) {
        final SeedProjectPresentation Function(int)? capture =
            captureProjectPresentation;
        if (capture == null) {
          throw const SeedRefused('original-project-presentation-required');
        }
        _projectPresentation = capture(originalRef);
      }
      if (recipe == 'token' && _tokenPresentation == null) {
        final SeedTokenPresentation Function(int, String)? capture =
            captureTokenPresentation;
        if (capture == null) {
          throw const SeedRefused('original-token-presentation-required');
        }
        _tokenPresentation = capture(originalRef, source.environment.owner);
      }
      if (recipe == 'deposit' && _depositPresentation == null) {
        final SeedDepositPresentation Function(int, String)? capture =
            captureDepositPresentation;
        if (capture == null) {
          throw const SeedRefused('original-deposit-presentation-required');
        }
        _depositPresentation = capture(originalRef, source.environment.owner);
      }
      requirePublication();
      final String hash = await guard.publish(
        recipe,
        () async {
          requirePublication();
          await tap(requirePublication);
        },
        requireReady: recipe == 'fund-address'
            ? restoredSource?.requireFundingReceiveReady
            : null,
      );
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
