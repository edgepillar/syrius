import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/p2p_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/plasma_purpose.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class CompleteHtlcSwapBloc extends BaseBloc<HtlcSwap?> {
  Future<void> completeHtlcSwap({
    required HtlcSwap swap,
  }) async {
    try {
      addEvent(null);
      final String htlcId = swap.direction == P2pSwapDirection.outgoing
          ? swap.counterHtlcId!
          : swap.initialHtlcId;

      // Make sure that the HTLC exists and has a safe amount of time left
      // until expiration.
      final HtlcInfo htlc = await zenon!.embedded.htlc.getById(Hash.parse(htlcId));
      if (htlc.expirationTime <=
          DateTimeUtils.unixTimeNow + kMinSafeTimeToCompleteSwap.inSeconds) {
        throw currentL10n.completeSwapExpiresTooSoonError;
      }

      if (htlc.keyMaxSize <
          FormatUtils.decodeHexString(swap.preimage!).length) {
        throw currentL10n.completeSwapSecretTooLargeError;
      }

      final AccountBlockTemplate transactionParams = zenon!.embedded.htlc.unlock(
          Hash.parse(htlcId), FormatUtils.decodeHexString(swap.preimage!),);
      AccountBlockUtils().createAccountBlock(
              transactionParams, PlasmaPurpose.completeSwap.message,
              address: Address.parse(swap.selfAddress), waitForRequiredPlasma: true,)
          .then(
        (AccountBlockTemplate response) async {
          swap.state = P2pSwapState.completed;
          await htlcSwapsService!.storeSwap(swap);
          ZenonAddressUtils().refreshBalance();
          addEvent(swap);
        },
      ).onError(
        (Object? error, StackTrace stackTrace) {
          addError(error.toString(), stackTrace);
        },
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }
}
