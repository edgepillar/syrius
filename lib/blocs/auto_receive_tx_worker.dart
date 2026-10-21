import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:logging/logging.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/auto_unlock_htlc_worker.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/utils/plasma_purpose.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

class AutoReceiveTxWorker extends BaseBloc<WalletNotification> {
  static AutoReceiveTxWorker? _instance;
  Queue<Hash> pool = Queue<Hash>();
  bool running = false;

  /// The inbound blocks a receive is under way for: from the moment its
  /// block is being made, through plasma and publishing, until the row has
  /// had time to leave the To receive list.
  ///
  /// The Receive button beside such a row is disabled from this. Pressed
  /// again while the first receive was still being made it did nothing, and
  /// pressed after the block was published it sent a second receive the
  /// node refused with "already received".
  final ValueNotifier<Set<Hash>> inFlight = ValueNotifier<Set<Hash>>(
    const <Hash>{},
  );

  /// How long a published receive keeps its row blocked. The list is
  /// refreshed on success and the row goes then; this is for a refresh
  /// that fails, so a row is never blocked for the rest of the session.
  @visibleForTesting
  static Duration publishedHold = const Duration(minutes: 1);

  void _mark(Hash hash) => inFlight.value = <Hash>{...inFlight.value, hash};

  void _unmark(Hash hash) =>
      inFlight.value = <Hash>{...inFlight.value}..remove(hash);

  void _markPublished(Hash hash) =>
      Timer(publishedHold, () => _unmark(hash));

  static AutoReceiveTxWorker getInstance() {
    _instance ??= AutoReceiveTxWorker();
    return _instance!;
  }

  Future<AccountBlockTemplate?> autoReceiveTransactionHash(
    Hash currentHash,
  ) async {
    if (!running) {
      running = true;
      bool published = false;
      _mark(currentHash);
      try {
        final Address toAddress =
            (await zenon!.ledger.getAccountBlockByHash(currentHash))!.toAddress;
        final AccountBlockTemplate transactionParams =
            AccountBlockTemplate.receive(
          currentHash,
        );
        final AccountBlockTemplate response =
            await AccountBlockUtils().createAccountBlock(
          transactionParams,
          PlasmaPurpose.receiveTransaction.message,
          address: toAddress,
          waitForRequiredPlasma: true,
        );
        published = true;
        _onSuccess(response, toAddress.toString());
        return response;
      } on RpcException catch (e, stackTrace) {
        published = _alreadyReceived(e);
        _sendErrorNotification(e.toString());
        Logger('AutoReceiveTxWorker')
            .log(Level.WARNING, 'autoReceive', e, stackTrace);
      } finally {
        running = false;
        published ? _markPublished(currentHash) : _unmark(currentHash);
      }
    }
    return null;
  }

  Future<void> autoReceive() async {
    if (sharedPrefsService!.get(
          kAutoReceiveKey,
          defaultValue: kAutoReceiveDefaultValue,
        ) ==
        false) {
      pool.clear();
      return;
    }
    // Make sure that AutoUnlockHtlcWorker is not running since it should be
    // given priority to send transactions.
    if (pool.isNotEmpty && !running && !sl<AutoUnlockHtlcWorker>().running) {
      running = true;
      final Hash currentHash = pool.first;
      bool published = false;
      _mark(currentHash);
      try {
        final Address toAddress =
            (await zenon!.ledger.getAccountBlockByHash(currentHash))!.toAddress;
        final AccountBlockTemplate transactionParams =
            AccountBlockTemplate.receive(
          currentHash,
        );
        final AccountBlockTemplate response =
            await AccountBlockUtils().createAccountBlock(
          transactionParams,
          PlasmaPurpose.receiveTransaction.message,
          address: toAddress,
          waitForRequiredPlasma: true,
        );
        published = true;
        _onSuccess(response, toAddress.toString());
        if (pool.isNotEmpty) {
          pool.removeFirst();
        }
        running = false;
        autoReceive();
      } on RpcException catch (e, stackTrace) {
        _sendErrorNotification(e.toString());
        Logger('AutoReceiveTxWorker')
            .log(Level.WARNING, 'autoReceive', e, stackTrace);
        if (_alreadyReceived(e)) {
          published = true;
          if (pool.isNotEmpty) {
            pool.removeFirst();
          }
        }
      } catch (e, stackTrace) {
        Logger('AutoReceiveTxWorker')
            .log(Level.WARNING, 'autoReceive', e, stackTrace);
        _sendErrorNotification(e.toString());
      } finally {
        running = false;
        published ? _markPublished(currentHash) : _unmark(currentHash);
      }
    }
  }

  static bool _alreadyReceived(RpcException e) =>
      e.message == 'account-block from-block already received';

  Future<void> addHash(Hash hash) async {
    zenon!.stats.syncInfo().then((SyncInfo syncInfo) {
      if (!pool.contains(hash) &&
          (syncInfo.state == SyncState.syncDone ||
              (syncInfo.targetHeight > 0 &&
                  syncInfo.currentHeight > 0 &&
                  (syncInfo.targetHeight - syncInfo.currentHeight) < 3))) {
        sl.get<PendingTransactionsBloc>().add(
          InfiniteListRefreshRequested(
            address: Address.parse(kSelectedAddress!),
          ),
        );
        pool.add(hash);
      }
    });
  }

  void _sendErrorNotification(String errorText) {
    addEvent(
      WalletNotification(
        title: currentL10n.autoReceiveFailedNotificationTitle,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        details: currentL10n.autoReceiveFailedNotificationDetails(errorText),
        type: NotificationType.error,
      ),
    );
  }

  void _onSuccess(AccountBlockTemplate block, String toAddress) {
    sl.get<MultipleBalanceBloc>().add(
          MultipleBalanceFetch(
            addresses: kDefaultAddressList.map((String? e) => e!).toList(),
          ),
        );

    final Address address = Address.parse(kSelectedAddress!);
    sl.get<LatestTransactionsBloc>().add(
      InfiniteListRefreshRequested(address: address),
    );
    sl.get<PendingTransactionsBloc>().add(
          InfiniteListRefreshRequested(
            address: address,
          ),
        );
    _sendSuccessNotification(block, toAddress);
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
}
