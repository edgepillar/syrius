import 'package:zenon_syrius_wallet_flutter/seams/seam.dart';

import '../../wallet_address_context.dart';
import 'seed_policy.dart';

/// The exact page controls admitted after the original Token recipe.
const Map<Seam, String> seededSurfaceControls = <Seam, String>{
  Seam.walletUpdateNotice: 'strip_update_button',
  Seam.pillarAprEstimate: 'pillars_sort_apr_gate',
  Seam.swapTerms: 'swap_start_terms_gate',
  Seam.tokenExplorer: 'token_explorer_control',
};

/// Read-only handoff after retiring the confirmed original Token publication.
/// It admits one existing member selection, never a derivation or publication.
final class SeededTokenHolder {
  /// Resource and retirement checks are captured before the original retires.
  SeededTokenHolder({
    required String confirmedHash,
    required this._original,
    required this._requireRetired,
    required this._requireResources,
    required this._readContext,
  }) : standard = seedHash(confirmedHash)
           ? seedIssuedTokenStandard(confirmedHash).toString() : '' {
    if (standard.isEmpty || !_original.consistent ||
        _original.members.length != 3 ||
        _original.selected != _original.members[1]) {
      throw const SeedRefused('seeded-token-holder-original-required');
    }
  }

  /// The real issued standard, derived from the retained original receipt.
  final String standard;
  final WalletAddressContext _original;
  final void Function() _requireRetired;
  final void Function() _requireResources;
  final WalletAddressContext Function() _readContext;
  WalletAddressContext? _selected;
  bool _held = false;

  WalletAddressContext _observe() {
    try {
      if (_held) throw const SeedRefused('seeded-token-holder-held');
      _requireRetired();
      _requireResources();
      final WalletAddressContext current = _readContext();
      _requireResources();
      _requireRetired();
      final WalletAddressContext? selected = _selected;
      if (selected == null
          ? !current.selectionPending(_original, 2)
          : !current.same(selected)) {
        throw const SeedRefused('seeded-token-holder-held');
      }
      return current;
    } on Object {
      _held = true;
      throw const SeedRefused('seeded-token-holder-held');
    }
  }

  /// Pending preference writes allow observation, never another selection tap.
  void requireTransition() { _observe(); }

  /// Retains the first exact committed transition; replacement stays held.
  WalletAddressContext requireSelected() {
    final WalletAddressContext current = _observe();
    if (!current.selectedFrom(_original, 2)) {
      _held = true;
      throw const SeedRefused('seeded-token-holder-held');
    }
    return _selected ??= current;
  }

  /// Finite selection facts grant neither a pointer nor token-action authority.
  Map<String, Object> get selectionReceipt {
    requireSelected();
    return Map<String, Object>.unmodifiable(<String, Object>{
      'schema': 1, 'scope': 'owned_seeded_token_holder_selection',
      'members': 3, 'originalIndex': 1, 'selectedIndex': 2,
      'singleTransition': true, 'persisted': true,
      'originalResourcesCurrent': true, 'publicationRetired': true,
    });
  }
}

/// Observes one original page gate after a confirmed owned Token recipe.
/// The supplied owner check must retain that receipt and its completed exit.
final class SeededSurfaceSeam {
  /// Captures the confirmed original and the native pointer observer once.
  SeededSurfaceSeam({
    required String confirmedHash,
    required Seam seam,
    required this._requireCurrent,
    required this._observe,
  }) : _confirmedHash = confirmedHash,
       _seam = seam {
    if (!seedHash(confirmedHash) || !seededSurfaceControls.containsKey(seam)) {
      throw const SeedRefused('confirmed-token-seam-required');
    }
  }

  final String _confirmedHash;
  final Seam _seam;
  final void Function() _requireCurrent;
  final Future<void> Function(
    String standard,
    Seam seam,
    String theme,
    void Function() requireOwner,
  ) _observe;
  final Set<String> _attemptedThemes = <String>{};
  bool _held = false;

  void _current() {
    try {
      if (_held) throw const SeedRefused('seeded-surface-seam-held');
      _requireCurrent();
    } on Object {
      _held = true;
      throw const SeedRefused('seeded-surface-seam-owner-changed');
    }
  }

  /// A failed or repeated observation holds this original permanently.
  /// Token, wallet and hash values stay local; receipts hold fixed facts.
  Future<Map<String, Object>> observe(String theme) async {
    if (_held ||
        !const <String>{'dark', 'light'}.contains(theme) ||
        _attemptedThemes.contains(theme)) {
      _held = true;
      throw const SeedRefused('seeded-surface-seam-held');
    }
    _current();
    _attemptedThemes.add(theme);
    try {
      await _observe(
        seedIssuedTokenStandard(_confirmedHash).toString(),
        _seam,
        theme,
        _current,
      );
      _current();
    } on Object {
      _held = true;
      throw const SeedRefused('seeded-surface-seam-refused');
    }
    return Map<String, Object>.unmodifiable(<String, Object>{
      'schema': 1,
      'scope': 'owned_seeded_surface_seam_pointer_observation',
      'seam': _seam.name,
      'theme': theme,
      'pointerDispatched': true,
      'absorptionObserved': true,
      'originalReceiptCurrent': true,
      'nativeFrameObserved': true,
    });
  }
}
