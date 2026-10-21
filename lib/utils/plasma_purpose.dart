import 'package:zenon_syrius_wallet_flutter/l10n/app_localizations.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';

/// What a transaction is for, when the wallet has to generate Plasma to send
/// it: the title of the notification that says so.
///
/// One value per whole sentence. The title used to be a fixed English opening
/// with a verb fragment glued on by the caller ('burn token', 'fuse QSR for
/// Plasma'), and a sentence put together like that cannot be translated: the
/// other languages order it differently. A new action takes a new value here
/// and a `plasmaPurpose…` message in `app_en.arb`, never a fragment.
enum PlasmaPurpose {
  /// Receiving a pending transaction.
  receiveTransaction,

  /// A send from the Transfer tab.
  sendTransaction,

  /// A transfer asked for by an app connected over WalletConnect.
  executeTransfer,

  /// Staking ZNN.
  createStake,

  /// Ending a stake whose time is up.
  cancelStake,

  /// Collecting the rewards of staking.
  collectStakingRewards,

  /// Collecting the rewards of a Pillar or of a delegation.
  collectPillarRewards,

  /// Collecting the rewards of a Sentinel.
  collectSentinelRewards,

  /// Delegating to a Pillar.
  delegateToPillar,

  /// Taking a delegation back.
  undelegate,

  /// Fusing QSR for Plasma.
  fuseQsrForPlasma,

  /// Taking fused QSR back.
  cancelPlasma,

  /// Registering a Pillar.
  registerPillar,

  /// Changing a Pillar's settings.
  updatePillar,

  /// Disassembling a Pillar.
  disassemblePillar,

  /// Depositing QSR towards a Pillar Slot.
  depositQsrForPillarSlot,

  /// Taking back the QSR deposited towards a Pillar Slot.
  withdrawQsrFromPillarSlot,

  /// Registering a Sentinel.
  registerSentinel,

  /// Disassembling a Sentinel.
  disassembleSentinel,

  /// Depositing QSR towards a Sentinel Slot.
  depositQsrForSentinelSlot,

  /// Taking back the QSR deposited towards a Sentinel Slot.
  withdrawQsrFromSentinelSlot,

  /// Issuing a new ZTS token.
  issueToken,

  /// Minting more of a token.
  mintToken,

  /// Burning some of a token.
  burnToken,

  /// Handing the ownership of a token to another address.
  transferToken,

  /// Submitting an Accelerator-Z project.
  createProject,

  /// Adding a phase to an Accelerator-Z project.
  createPhase,

  /// Changing a phase of an Accelerator-Z project.
  updatePhase,

  /// Voting on an Accelerator-Z project or phase.
  voteForProject,

  /// Donating to Accelerator-Z.
  donateToAccelerator,

  /// Opening a P2P swap.
  startSwap,

  /// Joining a P2P swap the other side opened.
  joinSwap,

  /// Unlocking the other side's deposit of a P2P swap.
  completeSwap,

  /// Taking back one's own deposit of a P2P swap that ran out.
  reclaimSwapFunds;

  /// The sentence in the language the app is showing, for the blocs, which
  /// have no `BuildContext`.
  ///
  /// A plain string in the language of the moment: read it when the
  /// transaction is made, and do not keep it.
  String get message => messageIn(currentL10n);

  /// The sentence in the language of [l10n].
  String messageIn(AppLocalizations l10n) => switch (this) {
    receiveTransaction => l10n.plasmaPurposeReceiveTransaction,
    sendTransaction => l10n.plasmaPurposeSendTransaction,
    executeTransfer => l10n.plasmaPurposeExecuteTransfer,
    createStake => l10n.plasmaPurposeCreateStake,
    cancelStake => l10n.plasmaPurposeCancelStake,
    collectStakingRewards => l10n.plasmaPurposeCollectStakingRewards,
    collectPillarRewards => l10n.plasmaPurposeCollectPillarRewards,
    collectSentinelRewards => l10n.plasmaPurposeCollectSentinelRewards,
    delegateToPillar => l10n.plasmaPurposeDelegateToPillar,
    undelegate => l10n.plasmaPurposeUndelegate,
    fuseQsrForPlasma => l10n.plasmaPurposeFuseQsrForPlasma(kQsrCoin.symbol),
    cancelPlasma => l10n.plasmaPurposeCancelPlasma,
    registerPillar => l10n.plasmaPurposeRegisterPillar,
    updatePillar => l10n.plasmaPurposeUpdatePillar,
    disassemblePillar => l10n.plasmaPurposeDisassemblePillar,
    depositQsrForPillarSlot => l10n.plasmaPurposeDepositQsrForPillarSlot(
      kQsrCoin.symbol,
    ),
    withdrawQsrFromPillarSlot => l10n.plasmaPurposeWithdrawQsrFromPillarSlot(
      kQsrCoin.symbol,
    ),
    registerSentinel => l10n.plasmaPurposeRegisterSentinel,
    disassembleSentinel => l10n.plasmaPurposeDisassembleSentinel,
    depositQsrForSentinelSlot => l10n.plasmaPurposeDepositQsrForSentinelSlot(
      kQsrCoin.symbol,
    ),
    withdrawQsrFromSentinelSlot =>
      l10n.plasmaPurposeWithdrawQsrFromSentinelSlot(kQsrCoin.symbol),
    issueToken => l10n.plasmaPurposeIssueToken,
    mintToken => l10n.plasmaPurposeMintToken,
    burnToken => l10n.plasmaPurposeBurnToken,
    transferToken => l10n.plasmaPurposeTransferToken,
    createProject => l10n.plasmaPurposeCreateProject,
    createPhase => l10n.plasmaPurposeCreatePhase,
    updatePhase => l10n.plasmaPurposeUpdatePhase,
    voteForProject => l10n.plasmaPurposeVoteForProject,
    donateToAccelerator => l10n.plasmaPurposeDonateToAccelerator,
    startSwap => l10n.plasmaPurposeStartSwap,
    joinSwap => l10n.plasmaPurposeJoinSwap,
    completeSwap => l10n.plasmaPurposeCompleteSwap,
    reclaimSwapFunds => l10n.plasmaPurposeReclaimSwapFunds,
  };
}

/// The sentence for a send asked for by a web page through the dapp bridge.
///
/// Not a [PlasmaPurpose], because it names the page: [shownOrigin] is the
/// page's origin as the wallet shows it. In [l10n], or in the language the
/// app is showing.
String plasmaPurposeSendForDapp(
  String shownOrigin, [
  AppLocalizations? l10n,
]) => (l10n ?? currentL10n).plasmaPurposeSendForDapp(shownOrigin);
