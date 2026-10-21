import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_origin.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/server/dapp_bridge_service.dart';

/// The setting that turns the channel off. Absent means on.
const String kDappBridgeEnabledKey = 'dapp_bridge_enabled';

/// Where the connected sites are kept.
const String kDappBridgeConsentKey = 'dapp_bridge_consent';

/// The key-value store the channel keeps its two settings in.
///
/// In the app it is the wallet's own settings box. That box is among those a
/// wallet reset deletes, which is the point: consent given under one wallet
/// must not be there for the next one, and it goes without the reset having
/// to know this feature exists.
abstract class DappBridgeStore {
  /// The value under [key], or null.
  Object? read(String key);

  /// Saves [value] under [key].
  Future<void> write(String key, Object? value);
}

/// One requester the person has connected, and the addresses it may see.
class DappBridgeSite extends Equatable {
  /// Creates a site.
  const DappBridgeSite({required this.requester, required this.addresses});

  /// What consent is stored under: an origin, or a link requester.
  final String requester;

  /// The addresses it was shown and may ask to sign with.
  final List<String> addresses;

  /// The origin to show.
  String get origin => dappBridgeShownOrigin(requester);

  /// Whether it asks by `syrius://request` rather than over the socket.
  bool get viaLink => dappBridgeIsLink(requester);

  @override
  List<Object?> get props => <Object?>[requester, addresses];
}

/// The connected sites, kept in a [DappBridgeStore] as one JSON text.
///
/// Nothing is cached: every question reads the store, so a revoke, a reset
/// or a cleared settings box is in force for the very next request. What
/// does not parse counts as no consent.
class DappBridgeConsentStore implements DappBridgeConsent {
  /// Creates the consent kept in [store].
  DappBridgeConsentStore(DappBridgeStore store) : _store = store;

  final DappBridgeStore _store;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after a grant or a revoke.
  Stream<void> get changes => _changes.stream;

  /// Every connected requester, sorted by the origin shown.
  List<DappBridgeSite> get sites {
    final List<DappBridgeSite> sites = <DappBridgeSite>[
      for (final MapEntry<String, List<String>> entry in _read().entries)
        DappBridgeSite(requester: entry.key, addresses: entry.value),
    ];
    return sites..sort(
      (DappBridgeSite a, DappBridgeSite b) =>
          '${a.origin} ${a.requester}'.compareTo('${b.origin} ${b.requester}'),
    );
  }

  @override
  bool has(String origin, String address) =>
      _read()[origin]?.contains(address) ?? false;

  @override
  bool hasAny(String origin) => _read().containsKey(origin);

  @override
  Future<void> grant(String origin, String address) async {
    final Map<String, List<String>> all = _read();
    final List<String> addresses = all[origin] ?? <String>[];
    if (addresses.contains(address)) {
      return;
    }
    all[origin] = <String>[...addresses, address];
    await _write(all);
  }

  @override
  Future<void> revoke(String origin) async {
    final Map<String, List<String>> all = _read();
    if (all.remove(origin) != null) {
      await _write(all);
    }
  }

  /// Releases the change stream.
  Future<void> close() => _changes.close();

  Map<String, List<String>> _read() {
    final Object? raw = _store.read(kDappBridgeConsentKey);
    final Map<String, List<String>> all = <String, List<String>>{};
    if (raw is! String) {
      return all;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return all;
      }
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        final Object? value = entry.value;
        final List<String> addresses = value is List
            ? value.whereType<String>().toList()
            : <String>[];
        if (addresses.isNotEmpty) {
          all[entry.key] = addresses;
        }
      }
    } on FormatException {
      return <String, List<String>>{};
    }
    return all;
  }

  Future<void> _write(Map<String, List<String>> all) async {
    await _store.write(kDappBridgeConsentKey, jsonEncode(all));
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}
