import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/dapp_bridge/dapp_bridge.dart';
import 'package:zenon_syrius_wallet_flutter/services/i_web3wallet_service.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';

class SelectedAddressNotifier extends ChangeNotifier {
  void changeSelectedAddress(String? newSelectedAddress) {
    kSelectedAddress = newSelectedAddress;
    sl<IWeb3WalletService>().emitAddressChangeEvent(newSelectedAddress!);
    DappBridge.instance.selectionChanged();
    notifyListeners();
  }
}
