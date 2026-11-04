import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/plasma_purpose.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

part 'cancel_stake_event.dart';

part 'cancel_stake_state.dart';

/// A bloc that helps with cancelling expired stakes.
class CancelStakeBloc extends Bloc<CancelStakeEvent, CancelStakeState> {
  /// Creates a new [CancelStakeBloc].
  CancelStakeBloc({
    required this._accountBlockUtils,
    required this._zenon,
    required this._zenonAddressUtils,
  }) : super(const CancelStakeInitial()) {
    on<CancelStakeRequested>(_onCancelStakeRequested);
  }

  final AccountBlockUtils _accountBlockUtils;
  final Zenon _zenon;
  final ZenonAddressUtils _zenonAddressUtils;
  bool _busy = false;

  FutureOr<void> _onCancelStakeRequested(
    CancelStakeRequested event,
    Emitter<CancelStakeState> emit,
  ) async {
    if (_busy || isClosed) return;
    _busy = true;
    bool current() {
      try {
        return !isClosed && (event.canPublish?.call() ?? true);
      } on Object {
        return false;
      }
    }

    void fail(SyriusException error) {
      if (emit.isDone) return;
      emit(
        current()
            ? CancelStakeFailure(exception: error)
            : const CancelStakeInitial(),
      );
    }

    try {
      emit(const CancelStakeLoading());
      if (!current()) {
        if (!emit.isDone) emit(const CancelStakeInitial());
        return;
      }
      final AccountBlockTemplate transactionParams = event.block ??
          _zenon.embedded.stake.cancel(event.stakeHash);
      if (event.canPublish != null) {
        await _accountBlockUtils.createAccountBlock(
          transactionParams,
          PlasmaPurpose.cancelStake.message,
          address: event.fromAddress,
          waitForRequiredPlasma: true,
          canPublish: event.canPublish,
        );
      } else {
        await _accountBlockUtils.createAccountBlock(
          transactionParams,
          PlasmaPurpose.cancelStake.message,
          waitForRequiredPlasma: true,
        );
      }

      if (!current()) {
        if (!emit.isDone) emit(const CancelStakeInitial());
        return;
      }

      _zenonAddressUtils.refreshBalance();

      if (!emit.isDone) {
        emit(current() ? const CancelStakeDone() : const CancelStakeInitial());
      }
    } on SyriusException catch (e, stackTrace) {
      if (!isClosed) addError(e, stackTrace);
      fail(e);
    } on Exception catch (e, stackTrace) {
      if (!isClosed) addError(e, stackTrace);
      fail(FailureException());
    } finally {
      _busy = false;
    }
  }
}
