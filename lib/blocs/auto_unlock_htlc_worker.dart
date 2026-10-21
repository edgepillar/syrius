import 'dart:async';
import 'dart:collection';

import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/base_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/notification_type.dart';
import 'package:zenon_syrius_wallet_flutter/model/database/wallet_notification.dart';
import 'package:zenon_syrius_wallet_flutter/model/p2p_swap/htlc_swap.dart';
import 'package:zenon_syrius_wallet_flutter/utils/account_block_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/address_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/format_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/utils/plasma_purpose.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class AutoUnlockHtlcWorker extends BaseBloc<WalletNotification> {
  static AutoUnlockHtlcWorker? _instance;
  Queue<Hash> pool = Queue<Hash>();
  HashSet<Hash> processedHashes = HashSet<Hash>();
  bool running = false;

  static AutoUnlockHtlcWorker getInstance() {
    _instance ??= AutoUnlockHtlcWorker();
    return _instance!;
  }

  Future<void> autoUnlock() async {
    if (pool.isNotEmpty && !running && kWalletFile != null) {
      running = true;
      final Hash currentHash = pool.first;
      try {
        final HtlcInfo htlc = await zenon!.embedded.htlc.getById(currentHash);
        final HtlcSwap? swap = htlcSwapsService!
            .getSwapByHashLock(FormatUtils.encodeHexString(htlc.hashLock));
        if (swap == null || swap.preimage == null) {
          throw currentL10n.autoUnlockInvalidSwapError;
        }
        if (!kDefaultAddressList.contains(htlc.hashLocked.toString())) {
          throw currentL10n.autoUnlockAddressNotInWalletError;
        }
        final AccountBlockTemplate transactionParams = zenon!.embedded.htlc
            .unlock(htlc.id, FormatUtils.decodeHexString(swap.preimage!));
        final AccountBlockTemplate response =
            await AccountBlockUtils().createAccountBlock(
          transactionParams,
          PlasmaPurpose.completeSwap.message,
          address: htlc.hashLocked,
          waitForRequiredPlasma: true,
        );
        _sendSuccessNotification(response, htlc.hashLocked.toString());
      } on RpcException catch (e, stackTrace) {
        Logger('AutoUnlockHtlcWorker')
            .log(Level.WARNING, 'autoUnlock', e, stackTrace);
        if (!e.message.contains('data non existent')) {
          _sendErrorNotification(e.toString());
        }
      } catch (e, stackTrace) {
        Logger('AutoUnlockHtlcWorker')
            .log(Level.WARNING, 'autoUnlock', e, stackTrace);
        _sendErrorNotification(e.toString());
      } finally {
        pool.removeFirst();
        _removeHashFromHashSetAfterDelay(currentHash);
        running = false;
      }
    }
  }

  void _sendErrorNotification(String errorText) {
    addEvent(
      WalletNotification(
        title: currentL10n.autoUnlockFailedNotificationTitle,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: currentL10n.autoUnlockFailedNotificationDetails(errorText),
        type: NotificationType.error,
      ),
    );
  }

  void _sendSuccessNotification(AccountBlockTemplate block, String toAddress) {
    addEvent(
      WalletNotification(
        title: currentL10n.transactionReceivedNotificationTitle(
          ZenonAddressUtils.getLabel(toAddress),
        ),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: currentL10n.transactionReceivedNotificationDetails(
          '${block.hash}',
        ),
        type: NotificationType.paymentReceived,
      ),
    );
  }

  void addHash(Hash hash) {
    if (!processedHashes.contains(hash)) {
      zenon!.stats.syncInfo().then((SyncInfo syncInfo) {
        if (!processedHashes.contains(hash) &&
            (syncInfo.state == SyncState.syncDone ||
                (syncInfo.targetHeight > 0 &&
                    syncInfo.currentHeight > 0 &&
                    (syncInfo.targetHeight - syncInfo.currentHeight) < 3))) {
          pool.add(hash);
          processedHashes.add(hash);
        }
      }).onError(
        (Object? e, StackTrace stackTrace) {
          Logger('AutoUnlockHtlcWorker')
              .log(Level.WARNING, 'addHash', e, stackTrace);
        },
      );
    }
  }

  // Remove the hash from the processedHashes hash set after a delay, because
  // if the node shuts down immediately after the unlock transactions has been
  // sent, the transaction may not actually be published. By removing the hash
  // from processedHashes, it can be re-added to the pool and retried.
  // The delay gives the network time to process the transaction, before
  // allowing for it to be retried.
  void _removeHashFromHashSetAfterDelay(Hash hash) {
    Future.delayed(
        const Duration(minutes: 2), () => processedHashes.remove(hash),);
  }
}
