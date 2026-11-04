part of 'cancel_stake_bloc.dart';

/// Base class for all cancel stake events.
sealed class CancelStakeEvent extends Equatable {
  /// Creates a new [CancelStakeEvent].
  const CancelStakeEvent();

  @override
  List<Object> get props => <Object>[];
}

/// Requests cancellation of an expired stake.
final class CancelStakeRequested extends CancelStakeEvent {
  /// Creates a new [CancelStakeRequested] event.
  const CancelStakeRequested({required this.stakeHash})
    : fromAddress = null,
      block = null,
      canPublish = null;

  /// Keeps the confirmed row, original template and publication authority.
  const CancelStakeRequested.owned({
    required this.stakeHash,
    required Address fromAddress,
    required AccountBlockTemplate block,
    required bool Function() canPublish,
  }) : fromAddress = fromAddress,
       block = block,
       canPublish = canPublish;

  /// Hash of the stake entry that should be cancelled.
  final Hash stakeHash;

  /// The account named before the confirmation opened.
  final Address? fromAddress;

  /// Built by the original client's Stake API after confirmation.
  final AccountBlockTemplate? block;

  /// Rechecked before preparation and by the existing publication path.
  final bool Function()? canPublish;

  @override
  List<Object> get props => <Object>[
    stakeHash,
    ?fromAddress,
    ?block,
    ?canPublish,
  ];
}
