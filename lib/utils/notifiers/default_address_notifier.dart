import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/pow_generating_status_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/dapp_bridge.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/latest_transactions/bloc/latest_transactions_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/wallet_context_revision.dart';

/// Announces the selected address after invalidating old display ownership.
class SelectedAddressNotifier extends ChangeNotifier {
  /// A real address change revokes old PoW before announcing the new context.
  void changeSelectedAddress(String? newSelectedAddress) {
    if (newSelectedAddress != kSelectedAddress) {
      WalletContextRevision.invalidate();
    }
    if (newSelectedAddress != kSelectedAddress &&
        sl.isRegistered<LatestTransactionsBloc>()) {
      sl.get<LatestTransactionsBloc>().invalidateReadContext();
    }
    if (newSelectedAddress != kSelectedAddress &&
        sl.isRegistered<PowGeneratingStatusBloc>()) {
      sl.get<PowGeneratingStatusBloc>().invalidate();
    }
    kSelectedAddress = newSelectedAddress;
    unawaited(
      sl<IWeb3WalletService>().emitAddressChangeEvent(newSelectedAddress!),
    );
    DappBridge.instance.selectionChanged();
    notifyListeners();
  }
}
