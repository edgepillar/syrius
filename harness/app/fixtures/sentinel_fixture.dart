import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart'
    show SentinelsBloc, SentinelsByOwnerBloc;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_action_context.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart'
    show NodesSentinelReaders;
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

import 'seed_policy.dart';

/// Presentation data for the selected isolated account.
SentinelInfo fixtureSentinelInfo(String owner) => SentinelInfo.fromJson(
  <String, dynamic>{
    'owner': owner,
    'registrationTimestamp': 1625132800,
    'isRevocable': true,
    'revokeCooldown': 3600,
    'active': true,
  },
);

/// Supplies the fixture only to the original Nodes readers in this app root.
Widget wrapReadonlySentinelFixture(Widget root) =>
    Provider<NodesSentinelReaders>.value(
      value: const NodesSentinelReaders(
        owner: _ownerReader,
        active: _activeReader,
        count: _activeCount,
      ),
      child: root,
    );

WalletActionContext _requireOriginal(Zenon sdk, String address) {
  final WalletActionContext? original = WalletActionContext.capture(address);
  if (original == null || !identical(original.client, sdk) ||
      kDefaultAddressList.length < 2 || kDefaultAddressList[1] != address ||
      kWalletFile?.isHardwareWallet != false ||
      kCurrentNode != 'ws://127.0.0.1:45998' ||
      kNodeChainId != 321 || getChainIdentifier() != 321) {
    throw const SeedRefused('fixture-expired');
  }
  return original;
}

SentinelsByOwnerBloc _ownerReader(Zenon sdk, String address) =>
    _FixtureOwner(_requireOriginal(sdk, address));

SentinelsBloc _activeReader(Zenon sdk, String address) {
  final WalletActionContext original = _requireOriginal(sdk, address);
  return FixtureSentinelsBloc(
    () => original.isCurrent,
    sdk: original.client,
    rows: <SentinelInfo>[fixtureSentinelInfo(original.ownerAddress)],
  );
}

Future<int> _activeCount(Zenon sdk, String address) async {
  _requireOriginal(sdk, address);
  return 1;
}

class _FixtureOwner extends SentinelsByOwnerBloc {
  _FixtureOwner(this._original) : super(zenon: _original.client);

  final WalletActionContext _original;

  @override
  Future<List<SentinelInfo>> getData({required Address address}) async {
    if (!_original.isCurrent || address.toString() != _original.ownerAddress) {
      throw const SeedRefused('fixture-expired');
    }
    return <SentinelInfo>[fixtureSentinelInfo(_original.ownerAddress)];
  }
}

/// Supplies finite fixture rows and excludes them from hydrated storage.
final class FixtureSentinelsBloc extends SentinelsBloc {
  /// Shares the same read-only fixture list between both harness hosts.
  FixtureSentinelsBloc(this._current, {
    required Zenon sdk,
    required List<SentinelInfo> rows,
  }) : _rows = List<SentinelInfo>.unmodifiable(rows),
       super(zenon: sdk);

  final List<SentinelInfo> _rows;
  final bool Function() _current;

  @override
  Future<List<SentinelInfo>> paginationFetch({
    required int pageIndex,
    required int pageSize,
    Address? address,
  }) async {
    if (!_current()) throw const SeedRefused('fixture-expired');
    return pageIndex == 0 ? _rows : <SentinelInfo>[];
  }

  @override
  Map<String, dynamic>? toJson(InfiniteListState<SentinelInfo> state) => null;

  @override
  InfiniteListState<SentinelInfo>? fromJson(Map<String, dynamic> json) => null;
}
