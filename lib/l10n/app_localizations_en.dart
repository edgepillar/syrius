// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activePillars => 'Active Pillars';

  @override
  String get activeSentinels => 'Active Sentinels';

  @override
  String get address => 'Address';

  @override
  String get addressSearchDescription =>
      'Addresses can be searched by label - \"Address 1\" - and by hex value - \"z1qxemdeddedxt0kenxxxxxxxxxxxxxxxxh9amk0\"';

  @override
  String get addressToCollectRewards =>
      'The address that will be able to collect the Pillar rewards';

  @override
  String get addressToProduceMomentums =>
      'The address that will produce momentums, get it from znn-controller';

  @override
  String get amount => 'Amount';

  @override
  String areYouSureTranfer(Object amount, Object recipient, Object symbol) {
    return 'Are you sure you want to transfer $amount $symbol to $recipient ?';
  }

  @override
  String get asset => 'Asset';

  @override
  String get balance => 'Balance';

  @override
  String get beneficiaryAddress => 'Beneficiary address';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelPlasmaConfirmation =>
      'Are you sure you want to cancel the Plasma fusion?';

  @override
  String get checkPillarStatus => ' to check the Pillar status';

  @override
  String get checkSentinelStatus => ' to check the Sentinel status';

  @override
  String get clickToAddToFavorites => 'Click to add to favorites';

  @override
  String get clickToRemoveFromFavorites => 'Click to remove from favorites';

  @override
  String get coin => 'Coin';

  @override
  String get collect => 'Collect';

  @override
  String get collectPillarRewards => 'Collect Pillar rewards';

  @override
  String get collectSentinelRewards => 'Collect Sentinel rewards';

  @override
  String get collectStakingRewards => 'Collect staking rewards';

  @override
  String get cannotReuseAddressForSentinel =>
      'If this address previously revoked a Sentinel, it cannot create a new Sentinel again. Use a different address before depositing QSR.';

  @override
  String couldNotSend(Object amount, Object recipient, Object symbol) {
    return 'Couldn\'t send $amount $symbol to $recipient';
  }

  @override
  String get burn => 'Burn';

  @override
  String get burnableToken => 'Burnable by any holder';

  @override
  String burnTokenIssueFee(Object amount, Object symbol) {
    return 'You will need to burn $amount $symbol to issue a token';
  }

  @override
  String get continueText => 'Continue';

  @override
  String get create => 'Create';

  @override
  String get createAnotherToken => 'Create another Token';

  @override
  String get createPillarDescription =>
      'Start the process of deploying a Pillar Node in the network';

  @override
  String get createPillarTitle => 'Create Pillar';

  @override
  String get createSentinelDescription =>
      'Start the process of deploying a Sentinel Node in the network';

  @override
  String get createStake => 'create stake';

  @override
  String createStakeDescription(Object kQsrCoinSymbol, Object kZnnCoinSymbol) {
    return 'This card displays information about staking per wallet address. Choose the duration and the amount in $kZnnCoinSymbol for staking in order to receive $kQsrCoinSymbol';
  }

  @override
  String get createStakeTitle => 'Create Stake';

  @override
  String get createToken => 'Create Token';

  @override
  String get createTokenDescription =>
      'Create a token following the ZTS specification';

  @override
  String get createTokenTitle => 'Create Token';

  @override
  String currentAmounts(Object kQsrCoinSymbol, Object kZnnCoinSymbol) {
    return 'This card displays the current $kZnnCoinSymbol and $kQsrCoinSymbol amounts for the selected address';
  }

  @override
  String currentPillarSlotFee(Object coins, Object kQsrCoinSymbol) {
    return 'Current Pillar Slot fee\n$coins $kQsrCoinSymbol';
  }

  @override
  String currentSentinelSlotFee(Object coins, Object kQsrCoinSymbol) {
    return 'Current Sentinel Slot fee\n$coins $kQsrCoinSymbol';
  }

  @override
  String get date => 'Date';

  @override
  String decimals(Object number) {
    return '$number decimals';
  }

  @override
  String get delegateKey => 'DELEGATE';

  @override
  String get delegation => 'Delegation';

  @override
  String delegationPercentageGiven(Object percentage) {
    return 'Delegation percentage given: $percentage';
  }

  @override
  String get delegationReward => 'Delegation reward';

  @override
  String get delegationStats => 'Delegation Stats';

  @override
  String delegationStatsDescription(Object kZnnCoinSymbol) {
    return 'This card displays the amount of $kZnnCoinSymbol and the name of the Pillar that you delegated to';
  }

  @override
  String delegators(Object number) {
    return 'Delegators: $number';
  }

  @override
  String get deposit => 'Deposit';

  @override
  String deposited(Object kQsrCoinSymbol) {
    return '$kQsrCoinSymbol deposited';
  }

  @override
  String depositedCoinWillBurn(Object kQsrCoinSymbol) {
    return 'All the deposited $kQsrCoinSymbol will be burned in order to create the Pillar Slot';
  }

  @override
  String get disassemble => 'DISASSEMBLE';

  @override
  String disassemblePillarToUnlockCoin(Object kZnnCoinSymbol) {
    return 'You will be able to unlock the $kZnnCoinSymbol if you choose to disassemble the Pillar';
  }

  @override
  String disassembleSentinelToUnlockCoin(Object kZnnCoinSymbol) {
    return 'You will be able to unlock the $kZnnCoinSymbol if you choose to disassemble the Sentinel';
  }

  @override
  String get dualCoinStats => 'Dual Coin Stats';

  @override
  String dualCoinStatsDescription(
    Object kQsrCoinSymbol,
    Object kZnnCoinSymbol,
  ) {
    return 'This card displays the circulating $kZnnCoinSymbol and $kQsrCoinSymbol supply from the network';
  }

  @override
  String get duration => 'Duration';

  @override
  String get errorCreatingToken => 'Error while creating a new ZTS token';

  @override
  String errorAddingTokenToFavorites(Object name) {
    return 'Error adding $name token to favorites';
  }

  @override
  String get errorBurningZts => 'Error while trying to burn ZTS';

  @override
  String get errorCollectingPillarRewards =>
      'Error while collecting Pillar rewards';

  @override
  String get errorCollectingSentinelRewards =>
      'Error while collecting Sentinel rewards';

  @override
  String get errorDeployingPillar => 'Error while deploying a Pillar';

  @override
  String get errorDeployingSentinel =>
      'Error while deploying the Sentinel Node';

  @override
  String get errorDisassemblingPillar => 'Error while disassembling Pillar';

  @override
  String get errorDisassemblingSentinel => 'Error while disassembling Sentinel';

  @override
  String get errorCollectingStakingRewards =>
      'Error while collecting staking rewards';

  @override
  String get errorUndelegating => 'Error while undelegating';

  @override
  String get errorUpdatingPillar => 'Error while updating Pillar';

  @override
  String get errorWhileCancellingPlasma => 'Error while cancelling Plasma';

  @override
  String get errorWhileCancellingStake => 'Error while cancelling stake';

  @override
  String get errorGeneratingPlasma => 'Error while generating Plasma';

  @override
  String errorMintingToken(Object symbol) {
    return 'Error while trying to mint $symbol';
  }

  @override
  String errorRemovingTokenFromFavorites(Object name) {
    return 'Error removing $name token from favorites';
  }

  @override
  String get errorTransferringTokenOwnership =>
      'Error while trying to transfer token ownership';

  @override
  String errorWhileDepositing(Object kQsrCoinSymbol) {
    return 'Error while depositing $kQsrCoinSymbol';
  }

  @override
  String get errorWhileGeneratingStake => 'Error while generating stake';

  @override
  String errorWhileWithdrawing(Object kQsrCoinSymbol) {
    return 'Error while withdrawing $kQsrCoinSymbol';
  }

  @override
  String get expiration => 'Expiration';

  @override
  String get expectedProducedMomentums => 'Expected/produced momentums';

  @override
  String get from => 'from';

  @override
  String get fuse => 'Fuse';

  @override
  String fusePlasmaDescription(Object kQsrCoinSymbol) {
    return 'This card displays information about Plasma available per wallet address. A minimum of 10 $kQsrCoinSymbol are needed to be fused in order to generate Plasma. The more $kQsrCoinSymbol fused, the more Plasma is produced for the beneficiary address\n\nInsufficient Plasma: Proof-of-work for Plasma generation; limited to 1 transaction per momentum\nLow Plasma: between 10 and 89 $kQsrCoinSymbol\nAverage Plasma: between 90 and 119 $kQsrCoinSymbol\nHigh Plasma: over 120 $kQsrCoinSymbol; recommended for complex transactions (register Pillars, Sentinels, staking and issuing ZTS tokens)';
  }

  @override
  String get fusePlasmaTitle => 'Fuse Plasma';

  @override
  String fusedPlasmaDescription(Object kQsrCoinSymbol) {
    return 'This card displays all your addresses that have Plasma generated by fusing $kQsrCoinSymbol';
  }

  @override
  String get fusedPlasmaTitle => 'Fused Plasma';

  @override
  String get goBack => 'Go back';

  @override
  String get hAgo => 'h ago';

  @override
  String get hash => 'Hash';

  @override
  String hashValue(Object value) {
    return 'Hash: $value';
  }

  @override
  String get issueToken => 'Issue Token';

  @override
  String get latestTransactionsDescription =>
      'This card displays the latest transactions (including ZTS tokens) of your selected address';

  @override
  String get latestTransactionsTitle => 'Latest Transactions';

  @override
  String get latestTransactionsTransferDescription =>
      'This card displays the latest transactions (including ZTS tokens) involving your wallet addresses';

  @override
  String get level => 'Level';

  @override
  String locked(Object kQsrCoinSymbol) {
    return '$kQsrCoinSymbol locked';
  }

  @override
  String get manageReceivingFunds => 'Manage receiving funds';

  @override
  String get manageSendingFunds => 'Manage sending funds';

  @override
  String management(Object kQsrCoinSymbol) {
    return '$kQsrCoinSymbol management';
  }

  @override
  String get max => 'Max';

  @override
  String get maxSupply => 'Max supply';

  @override
  String get minAgo => 'min ago';

  @override
  String get mint => 'Mint';

  @override
  String get mintable => 'Mintable';

  @override
  String get mintableToken => 'Mintable token';

  @override
  String momentumPercentageGiven(Object percentage) {
    return 'Momentum percentage given: $percentage';
  }

  @override
  String get momentumReward => 'Momentum reward';

  @override
  String get morePlasmaRequired =>
      'More Plasma is required to perform complex transactions. Please fuse enough QSR before proceeding.';

  @override
  String get name => 'Name';

  @override
  String get newOwnerAddress => 'New owner address';

  @override
  String get next => 'Next';

  @override
  String get no => 'no';

  @override
  String get noItemsFound => 'None yet';

  @override
  String get noMoreItems => 'No more items';

  @override
  String get noRewardsCollect => 'No rewards to collect';

  @override
  String get noZtsTokensAvailable => 'No ZTS tokens available';

  @override
  String numberOfDecimals(Object number) {
    return 'Number of decimals: $number';
  }

  @override
  String get ownZtsToken => 'You own this ZTS token';

  @override
  String get password => 'Password';

  @override
  String get pending => 'Pending';

  @override
  String get pendingTransactionsDescription =>
      'This card displays the pending transactions (including ZTS tokens) for the selected address';

  @override
  String get pendingTransactionsTitle => 'Pending Transactions';

  @override
  String get percentageDelegationRewardsGiven =>
      'Percentage of delegation rewards given to the delegators';

  @override
  String get percentageOfMomentumRewards =>
      'Percentage of momentum rewards given to the delegators';

  @override
  String get pillar => 'Pillar';

  @override
  String get pillarCollectDescription =>
      'This card displays your current Pillar rewards (either from your Pillar Node or from your delegation) that are ready to be collected. If there are any rewards available, you will be able to collect them. In order to receive rewards, the Pillar Node needs to be not only registered in the network, but also deployed (use znn-controller for this operation) and it must produce momentums';

  @override
  String get pillarCollectTitle => 'Pillar Collect';

  @override
  String get pillarDelegationError => 'Pillar delegation error';

  @override
  String get pillarDetails => 'Pillar details';

  @override
  String get pillarMomentumAddress => 'Pillar momentum address';

  @override
  String get pillarMomentumRewards => 'Pillar momentum rewards';

  @override
  String get pillarName => 'Pillar name';

  @override
  String get pillarProducerAddress => 'Pillar producer address';

  @override
  String get pillarRegistered => 'Pillar registered';

  @override
  String get pillarRewardAddress => 'Pillar reward address';

  @override
  String get pillarRewardsBlockCreated =>
      'Successfully created block for collecting the pillar rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.';

  @override
  String get pillarRewardsDescription =>
      'This card displays a chart with your Pillar rewards. Pillar rewards are generated either by operating a Pillar Node or from delegations to a Pillar Node';

  @override
  String get pillarRewardsTitle => 'Pillar Rewards';

  @override
  String plasmaStatsDescription(Object kQsrCoinSymbol) {
    return 'This card displays information about current Plasma level for each wallet address. Plasma is used as an anti-spam mechanism. More Plasma you have per address, more transactions you will be able to send or receive on that address. Low or insufficient Plasma will require proof-of-work for generation. Fuse 10 $kQsrCoinSymbol or more in order to obtain Plasma for any given address\n\nInsufficient Plasma: Proof-of-work for Plasma generation; limited to 1 transaction per momentum\nLow Plasma: between 10 and 50 $kQsrCoinSymbol\nAverage Plasma: between 50 and 119 $kQsrCoinSymbol\nHigh Plasma: over 120 $kQsrCoinSymbol; recommended to make complex transactions (deploy Pillars, Sentinels, staking and issuing ZTS tokens)';
  }

  @override
  String get plasmaStatsTitle => 'Plasma Stats';

  @override
  String get pillarStats => 'Pillar Stats';

  @override
  String get pillarUpdate => 'Pillar update';

  @override
  String get pillarUpdated => 'Pillar updated';

  @override
  String get pillars => 'Pillars';

  @override
  String pillarsWithNumber(Object number) {
    return 'Pillars: $number';
  }

  @override
  String get pillarsDescription =>
      'This card displays the number of active Pillars in the network';

  @override
  String pillarsListDescription(Object kZnnCoinSymbol) {
    return 'This card displays Pillar Nodes that are currently active in the network. The list contains the name of the Pillar, the associated producer address, the weight (total number of delegations) and your delegation status. You can choose to delegate your $kZnnCoinSymbol balance to any Pillar in order to receive delegation rewards in $kZnnCoinSymbol. You can undelegate the balance at any time, without any penalties. Minimum delegation amount is 1 $kZnnCoinSymbol per address';
  }

  @override
  String get pillarsListTitle => 'Pillars List';

  @override
  String get pillarsTitle => 'Pillars';

  @override
  String get plasma => 'Plasma';

  @override
  String get plasmaCheck => 'Plasma Check';

  @override
  String get pressToReceive => 'Press to receive the transaction';

  @override
  String get producerAddress => 'Producer Address';

  @override
  String quasarTransactions(Object quasar) {
    return '$quasar transactions';
  }

  @override
  String get realtimeStats => 'Realtime Stats';

  @override
  String realtimeStatsDescription(
    Object kQsrCoinSymbol,
    Object kZnnCoinSymbol,
  ) {
    return 'This card displays the number of $kZnnCoinSymbol and $kQsrCoinSymbol transactions. For example, a delegation is considered a $kZnnCoinSymbol transaction from the network\'s perspective. Every interaction with the network embedded contracts is internally considered a transaction';
  }

  @override
  String get receive => 'Receive';

  @override
  String get receiver => 'Receiver';

  @override
  String get recipientAddress => 'Recipient Address';

  @override
  String get register => 'Register';

  @override
  String get registerAnotherPillar => 'Register another Pillar';

  @override
  String get registerPillar => 'Register Pillar';

  @override
  String get registerSentinel => 'Register Sentinel';

  @override
  String get registeredUse => ' registered. Use ';

  @override
  String requiredForPillarSlot(Object coins, Object kQsrCoinSymbol) {
    return '$coins $kQsrCoinSymbol required for a Pillar slot';
  }

  @override
  String requiredForSentinelNode(Object coins, Object kQsrCoinSymbol) {
    return '$coins $kQsrCoinSymbol required for a Sentinel Node';
  }

  @override
  String get revocationWindowOpen => 'Revocation window is open';

  @override
  String get sAgo => 's ago';

  @override
  String get saveQr => 'Save QR';

  @override
  String get searchTokenHint =>
      'Search by name, symbol, owner, or token standard';

  @override
  String get send => 'Send';

  @override
  String get sendTransaction => 'send transaction';

  @override
  String get sentinel => 'Sentinel';

  @override
  String get sender => 'Sender';

  @override
  String get senderAddressDescription =>
      'The address from which the transaction will be sent';

  @override
  String get sent => 'Sent';

  @override
  String sentDetails(
    Object amount,
    Object recipient,
    Object sender,
    Object symbol,
  ) {
    return 'Sent $amount $symbol from $sender to $recipient';
  }

  @override
  String get sentinelAddress => 'Sentinel Address';

  @override
  String get sentinelCollectDescription =>
      'This card displays your current Sentinel rewards that are ready to be collected. If there are any rewards available, you will be able to collect them. In order to receive rewards, the Sentinel Node needs to be not only registered in the network, but also deployed (use znn-controller for this operation) and it must have >90% daily uptime';

  @override
  String get sentinelCollectTitle => 'Sentinel Collect';

  @override
  String get sentinelRewardsDescription =>
      'This card displays a chart with your Sentinel rewards from your Sentinel Node';

  @override
  String get sentinelRewardsBlockCreated =>
      'Successfully created block for collecting the sentinel rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.';

  @override
  String get sentinelRewardsTitle => 'Sentinel Rewards';

  @override
  String get sentinelDetectedOnThisAddress =>
      'Sentinel detected on this address';

  @override
  String get sentinelRegistered => 'Sentinel registered';

  @override
  String get sentinelStats => 'Sentinel Stats';

  @override
  String get sentinels => 'Sentinels';

  @override
  String get sentinelsDescription =>
      'This card displays the number of active Sentinels in the network';

  @override
  String get sentinelsListDescription =>
      'This card displays information about the Sentinels that are currently active in the network';

  @override
  String get sentinelsListTitle => 'Sentinels List';

  @override
  String get shareQr => 'Share QR';

  @override
  String get spawn => 'Spawn';

  @override
  String get stake => 'Stake';

  @override
  String get stakeCollectDescription =>
      'This card displays your current staking rewards that are ready to be collected. If there are any rewards available, you will be able to collect them';

  @override
  String get stakeCollectTitle => 'Stake Collect';

  @override
  String get stakingDuration => 'Staking duration';

  @override
  String get stakingStats => 'Staking Stats';

  @override
  String stakingStatsDescription(Object kZnnCoinSymbol) {
    return 'This card displays the number of staking entries and the total $kZnnCoinSymbol that you are currently staking';
  }

  @override
  String get stakesListDescription =>
      'This card displays information about the stake entries for the selected address';

  @override
  String get stakesListTitle => 'Stakes';

  @override
  String get stakingRewardsDescription =>
      'This card displays a chart with your staking rewards from your staking entries';

  @override
  String get stakingRewardsBlockCreated =>
      'Successfully created block for collecting the staking rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.';

  @override
  String get stakingRewardsTitle => 'Staking Rewards';

  @override
  String get successfully => 'successfully';

  @override
  String successfullyBurned(Object amount, Object symbol) {
    return 'Successfully burned $amount $symbol';
  }

  @override
  String successfullyBurnedRequestedAmount(
    Object amount,
    Object hash,
    Object symbol,
  ) {
    return 'You have successfully burned the requested amount: $amount $symbol $hash';
  }

  @override
  String successfullyMinted(Object amount, Object symbol) {
    return 'Successfully minted $amount $symbol';
  }

  @override
  String successfullyMintedRequestedAmount(
    Object amount,
    Object hash,
    Object symbol,
  ) {
    return 'You have successfully minted the requested amount: $amount $symbol $hash';
  }

  @override
  String get sufficientPlasma => 'Sufficient Plasma';

  @override
  String get to => 'to';

  @override
  String tokenAddedToFavorites(Object name) {
    return '$name token has been added to favorites';
  }

  @override
  String get tokenBalanceDescription =>
      'This card displays information about ZTS tokens that you currently hold in your wallet';

  @override
  String get tokenBalanceTitle => 'Token Balance';

  @override
  String get tokenBurnTooltip =>
      'When enabled, any holder can burn tokens from their own balance. When disabled, only the token owner can burn.';

  @override
  String get tokenCreation => 'ZNN Check';

  @override
  String get tokenDetails => 'Details';

  @override
  String get tokenDomain => 'Token Domain';

  @override
  String get tokenIssuanceAddressDescription =>
      'This will be your issuance address';

  @override
  String get tokenMetrics => 'Metrics';

  @override
  String get tokenMintableBurnableOptions => 'Mintable and Burnable Options';

  @override
  String tokenMintableBurnableSubtitle(Object burnable, Object mintable) {
    return 'Mintable: $mintable\nBurnable: $burnable';
  }

  @override
  String get tokenMintableTooltip =>
      'Whether or not this token is mintable after creation';

  @override
  String get tokenName => 'Token Name';

  @override
  String tokenRemovedFromFavorites(Object name) {
    return '$name token has been removed from favorites';
  }

  @override
  String get tokenStatusUtilityTooltip =>
      'Token status: utility or non-utility (e.g. security token)';

  @override
  String tokenSummary(Object name, Object symbol, Object tokenStandard) {
    return 'Token $name with symbol $symbol and ZTS $tokenStandard';
  }

  @override
  String tokenSupplyOutOfMax(
    Object maxSupply,
    Object symbol,
    Object totalSupply,
  ) {
    return '$totalSupply out of $maxSupply $symbol';
  }

  @override
  String get tokenSymbol => 'Token Symbol';

  @override
  String get tokenTransactions => 'Token Transactions';

  @override
  String get tokens => 'Tokens';

  @override
  String get tokensCardDescription =>
      'This card displays a grid with all the ZTS tokens from the network, including ZTS tokens issued by you';

  @override
  String get totalSupply => 'Total supply';

  @override
  String get transactionError => 'Error while receiving transaction';

  @override
  String visitDomain(Object domain) {
    return 'Visit $domain';
  }

  @override
  String get transactions => 'Transactions';

  @override
  String get transactionsDescription =>
      'This card displays the total number of transactions settled in the last hour across the network';

  @override
  String get transactionsLastHour => 'transactions in the last hour';

  @override
  String get transfer => 'Transfer';

  @override
  String get transferDescription =>
      'Redirects you to the Transfer tab where you can manage sending and receiving funds';

  @override
  String transferredTokenOwnership(Object name) {
    return 'Successfully transferred ownership of $name token';
  }

  @override
  String transferredTokenOwnershipToAddress(Object address, Object name) {
    return 'Successfully transferred ownership of $name token to address $address';
  }

  @override
  String get transferTokenOwnership => 'Transfer token ownership';

  @override
  String get type => 'Type';

  @override
  String get undelegate => 'UNDELEGATE';

  @override
  String get untilRevocationWindowOpens => 'Until revocation window opens';

  @override
  String get update => 'Update';

  @override
  String get updatePillar => 'Update Pillar';

  @override
  String get updatePillarSettings => 'Update Pillar settings';

  @override
  String get uptime => 'Uptime';

  @override
  String get utilityToken => 'Utility token';

  @override
  String get usDateFormat => 'MM/dd/yyyy';

  @override
  String get viewPillars => 'View Pillars';

  @override
  String get viewMyTokens => 'View my Tokens';

  @override
  String get viewSentinels => 'View Sentinels';

  @override
  String get waitingForDataFetching => 'Waiting for data fetching';

  @override
  String get weight => 'Weight';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get yes => 'yes';

  @override
  String youHaveDeposited(Object coins, Object kQsrCoinSymbol) {
    return 'You have deposited $coins $kQsrCoinSymbol';
  }

  @override
  String zenonTransactions(Object zenon) {
    return '$zenon transactions';
  }

  @override
  String get znnController => 'znn-controller ';

  @override
  String get ztsSearchDescription =>
      'Coins and tokens can be searched by name - \"Zenon\" -, by symbol - \"ZNN\" -, and by token standard - \"zts1znnxxxxxxxxxxxxx9z4ulx\"';

  @override
  String burnTokenConfirm(Object amount) {
    return 'Burn $amount?';
  }

  @override
  String get cannotBeUndone => 'This cannot be undone.';

  @override
  String transferTokenConfirm(Object symbol) {
    return 'Transfer $symbol?';
  }

  @override
  String transferTokenConfirmTo(Object address) {
    return '$address becomes the owner. This cannot be undone.';
  }

  @override
  String get sentinelYours => 'Yours';

  @override
  String disassembleSentinelConfirm(Object address) {
    return 'Disassemble the sentinel of $address?';
  }

  @override
  String get validatorInvalidAddress => 'Invalid address';

  @override
  String get validatorInvalidNode => 'Invalid Node';

  @override
  String get validatorAddressNotInWallet =>
      'Must be an address from your wallet';

  @override
  String validatorFieldEmpty(String fieldName) {
    return '$fieldName must not be empty';
  }

  @override
  String get validatorNumberRequired => 'Number required';

  @override
  String get validatorInvalidNumber => 'Input is not a valid number';

  @override
  String get validatorInvalidAmount => 'Invalid amount';

  @override
  String get validatorError => 'Error';

  @override
  String get validatorValueNull => 'Value is null';

  @override
  String get validatorEmptyBalance => 'Empty balance';

  @override
  String get validatorEnterValidAmount => 'Enter a valid amount';

  @override
  String get validatorTooManyDecimals =>
      'Inputted number has too many decimals';

  @override
  String validatorBalanceBelowMin(String min) {
    return 'Your available balance must be at least $min';
  }

  @override
  String validatorValueMustBe(String value) {
    return 'Value must be $value';
  }

  @override
  String validatorValueMustBeMinAllowed(String value) {
    return 'Value must be  $value';
  }

  @override
  String validatorValueOutOfRange(String min, String max) {
    return 'Value must be between $min and $max';
  }

  @override
  String get validatorValueEmpty => 'Value can\'t be empty';

  @override
  String get validatorEnterAddress => 'Enter an address';

  @override
  String get validatorPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get validatorPasswordTooWeak => 'Password not strong enough';

  @override
  String get validatorInvalidPassword => 'Invalid password';

  @override
  String get validatorPillarProducerAddressSameSeed =>
      'Pillar producer address must be generated from a different seed';

  @override
  String get validatorMaxSupplyNotZero =>
      'Max supply must be 0 for non-mintable tokens';

  @override
  String get validatorInvalidUrl => 'Invalid URL';

  @override
  String get validatorInvalidHash => 'Invalid hash';

  @override
  String get validatorInvalidSecret => 'Invalid secret';

  @override
  String get ledgerStatusDeny => 'Deny';

  @override
  String get ledgerStatusWrongP1P2 => 'Invalid P1 or P2';

  @override
  String get ledgerStatusWrongDataLength => 'Invalid data length';

  @override
  String get ledgerStatusInactiveDevice => 'Device is inactive';

  @override
  String get ledgerStatusNotAllowed => 'Request not allowed';

  @override
  String get ledgerStatusInsNotSupported =>
      'Instruction not supported, please make sure the Zenon app is opened';

  @override
  String get ledgerStatusClaNotSupported =>
      'Class not supported, please make sure the Zenon app is opened';

  @override
  String get ledgerStatusAppIsNotOpen =>
      'App not open, please open the Zenon app on your device';

  @override
  String get ledgerStatusWrongResponseLength =>
      'Invalid response, please reconnect the device and try again';

  @override
  String get ledgerStatusDisplayBip32PathFail => 'Failed to display BIP32 path';

  @override
  String get ledgerStatusDisplayAddressFail => 'Failed to display address';

  @override
  String get ledgerStatusDisplayAmountFail => 'Failed to display amount';

  @override
  String get ledgerStatusWrongTxLength => 'Invalid transaction length';

  @override
  String get ledgerStatusTxParsingFail => 'Failed to parse transaction';

  @override
  String get ledgerStatusTxHashFail => 'Failed to hash transaction';

  @override
  String get ledgerStatusBadState =>
      'Bad state, please reconnect the device and try again';

  @override
  String get ledgerStatusSignatureFail => 'Failed to create signature';

  @override
  String get ledgerStatusSuccess => 'Success';

  @override
  String get ledgerStatusUnknownError =>
      'Unknown error, please make sure the device is unlocked';

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '$count h ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '$count min ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count s ago',
      one: '$count s ago',
    );
    return '$_temp0';
  }

  @override
  String durationDaysHours(int days, int hours) {
    return '$days d $hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes m';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes m $seconds s';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get createTokenOpenLabel => 'Create token';

  @override
  String get createTokenHeldLabel => 'Tokens held';

  @override
  String get createTokenFeeLabel => 'Issue fee';

  @override
  String get createTokenDecimalsLabel => 'Decimals';

  @override
  String get createTokenDomainHint => 'example.com';

  @override
  String get plasmaPurposeReceiveTransaction =>
      'Plasma will be generated in order to receive transaction';

  @override
  String get plasmaPurposeSendTransaction =>
      'Plasma will be generated in order to send transaction';

  @override
  String get plasmaPurposeExecuteTransfer =>
      'Plasma will be generated in order to Execute transfer';

  @override
  String plasmaPurposeSendForDapp(String origin) {
    return 'Plasma will be generated in order to Send for $origin';
  }

  @override
  String get plasmaPurposeCreateStake =>
      'Plasma will be generated in order to create stake';

  @override
  String get plasmaPurposeCancelStake =>
      'Plasma will be generated in order to cancel stake';

  @override
  String get plasmaPurposeCollectStakingRewards =>
      'Plasma will be generated in order to Collect staking rewards';

  @override
  String get plasmaPurposeCollectPillarRewards =>
      'Plasma will be generated in order to Collect Pillar rewards';

  @override
  String get plasmaPurposeCollectSentinelRewards =>
      'Plasma will be generated in order to Collect Sentinel rewards';

  @override
  String get plasmaPurposeDelegateToPillar =>
      'Plasma will be generated in order to delegate to Pillar';

  @override
  String get plasmaPurposeUndelegate =>
      'Plasma will be generated in order to undelegate';

  @override
  String plasmaPurposeFuseQsrForPlasma(String qsrSymbol) {
    return 'Plasma will be generated in order to fuse $qsrSymbol for Plasma';
  }

  @override
  String get plasmaPurposeCancelPlasma =>
      'Plasma will be generated in order to cancel Plasma';

  @override
  String get plasmaPurposeRegisterPillar =>
      'Plasma will be generated in order to register Pillar';

  @override
  String get plasmaPurposeUpdatePillar =>
      'Plasma will be generated in order to update pillar';

  @override
  String get plasmaPurposeDisassemblePillar =>
      'Plasma will be generated in order to disassemble Pillar';

  @override
  String plasmaPurposeDepositQsrForPillarSlot(String qsrSymbol) {
    return 'Plasma will be generated in order to deposit $qsrSymbol from Pillar Slot';
  }

  @override
  String plasmaPurposeWithdrawQsrFromPillarSlot(String qsrSymbol) {
    return 'Plasma will be generated in order to withdraw $qsrSymbol from Pillar Slot';
  }

  @override
  String get plasmaPurposeRegisterSentinel =>
      'Plasma will be generated in order to register Sentinel';

  @override
  String get plasmaPurposeDisassembleSentinel =>
      'Plasma will be generated in order to disassemble Sentinel';

  @override
  String plasmaPurposeDepositQsrForSentinelSlot(String qsrSymbol) {
    return 'Plasma will be generated in order to deposit $qsrSymbol for Sentinel Slot';
  }

  @override
  String plasmaPurposeWithdrawQsrFromSentinelSlot(String qsrSymbol) {
    return 'Plasma will be generated in order to withdraw $qsrSymbol from Sentinel Slot';
  }

  @override
  String get plasmaPurposeIssueToken =>
      'Plasma will be generated in order to issue token';

  @override
  String get plasmaPurposeMintToken =>
      'Plasma will be generated in order to mint token';

  @override
  String get plasmaPurposeBurnToken =>
      'Plasma will be generated in order to burn token';

  @override
  String get plasmaPurposeTransferToken =>
      'Plasma will be generated in order to transfer token';

  @override
  String get plasmaPurposeCreateProject =>
      'Plasma will be generated in order to creating project';

  @override
  String get plasmaPurposeCreatePhase =>
      'Plasma will be generated in order to create phase';

  @override
  String get plasmaPurposeUpdatePhase =>
      'Plasma will be generated in order to update phase';

  @override
  String get plasmaPurposeVoteForProject =>
      'Plasma will be generated in order to vote for project';

  @override
  String get plasmaPurposeDonateToAccelerator =>
      'Plasma will be generated in order to donate for accelerator';

  @override
  String get plasmaPurposeStartSwap =>
      'Plasma will be generated in order to start swap';

  @override
  String get plasmaPurposeJoinSwap =>
      'Plasma will be generated in order to join swap';

  @override
  String get plasmaPurposeCompleteSwap =>
      'Plasma will be generated in order to complete swap';

  @override
  String get plasmaPurposeReclaimSwapFunds =>
      'Plasma will be generated in order to reclaim swap funds';

  @override
  String get plasmaNotificationDetails =>
      'Plasma will be generated for this account-block';

  @override
  String notificationErrorWithDetails(String title, Object error) {
    return '$title: $error';
  }

  @override
  String get notificationEmptyTitle => 'Empty title';

  @override
  String get notificationNoDetails => 'No details available';

  @override
  String get nodeUpdatePanelTitle => 'Embedded node';

  @override
  String get nodeUpdateStatusError => 'The node folder could not be read.';

  @override
  String get nodeUpdateLoadedLabel => 'Loaded';

  @override
  String get nodeUpdateNextStartLabel => 'Used at the next start';

  @override
  String get nodeUpdateBundledLabel => 'Bundled';

  @override
  String get nodeUpdateFromFileLabel => 'From a file';

  @override
  String get nodeUpdateMissingLabel => 'No node library found';

  @override
  String get nodeUpdateHashLabel => 'SHA-256';

  @override
  String get nodeUpdateHashCopyTooltip => 'Copy SHA-256';

  @override
  String nodeUpdateReopenStagedLabel(String name) {
    return 'Close and reopen Syrius to use $name.';
  }

  @override
  String get nodeUpdateReopenBundledLabel =>
      'Close and reopen Syrius to use the bundled node.';

  @override
  String get nodeUpdateBadError =>
      'The installed node failed to load. The bundled one is in use.';

  @override
  String get nodeUpdateStagedRejectedError =>
      'The staged node did not match its checksum and was removed.';

  @override
  String get nodeUpdateReleaseLabel => 'Latest release';

  @override
  String get nodeUpdateCheckLabel => 'Check';

  @override
  String get nodeUpdateNotCheckedHint => 'Not checked';

  @override
  String get nodeUpdateNoReleaseLabel => 'This repository has no releases.';

  @override
  String get nodeUpdateCompareUpToDateLabel => 'Up to date';

  @override
  String get nodeUpdateCompareAvailableLabel => 'Update available';

  @override
  String get nodeUpdateCompareStagedLabel => 'Staged for the next start';

  @override
  String get nodeUpdateCompareUnknownLabel => 'Not compared';

  @override
  String get nodeUpdateInstallLabel => 'Install';

  @override
  String get nodeUpdateInstallHint => 'Takes effect at the next start';

  @override
  String get nodeUpdateDownloadLabel => 'Download';

  @override
  String get nodeUpdateFileLabel => 'From file';

  @override
  String nodeUpdateProgressLabel(String received, String total) {
    return '$received of $total MB';
  }

  @override
  String nodeUpdateReadingFileLabel(String name) {
    return 'Reading $name';
  }

  @override
  String get nodeUpdateStagingLabel => 'Installing';

  @override
  String get nodeUpdateInstallTitle => 'Install this node?';

  @override
  String get nodeUpdateRepositoryLabel => 'Repository';

  @override
  String get nodeUpdateTagLabel => 'Release';

  @override
  String get nodeUpdateAssetLabel => 'Asset';

  @override
  String get nodeUpdateFileNameLabel => 'File';

  @override
  String get nodeUpdateNoneLabel => 'None';

  @override
  String get nodeUpdateChecksumFileLabel => 'Checksum file';

  @override
  String get nodeUpdateDigestLabel => 'GitHub digest';

  @override
  String get nodeUpdateChecksumVerifiedLabel =>
      'Matches the release\'s checksum file';

  @override
  String get nodeUpdateChecksumNotListedLabel =>
      'Not listed in the release\'s checksum file';

  @override
  String get nodeUpdateChecksumAbsentLabel =>
      'The release has no checksum file';

  @override
  String get nodeUpdateDigestVerifiedLabel => 'Matches GitHub\'s digest';

  @override
  String get nodeUpdateDigestAbsentLabel =>
      'GitHub gives no digest for this release';

  @override
  String get nodeUpdateFileUncheckedLabel =>
      'Not checked: a file from this computer';

  @override
  String get nodeUpdateInstallConfirm =>
      'This replaces the node that runs inside the wallet. It takes effect at the next start.';

  @override
  String get nodeUpdateUnverifiedTitle => 'Download without verification?';

  @override
  String nodeUpdateUnverifiedConfirm(String tag) {
    return 'Nothing verifies this file. Release $tag publishes no checksum for it.';
  }

  @override
  String get nodeUpdateUnverifiedDownloadLabel => 'Download anyway';

  @override
  String get nodeUpdateRollbackLabel => 'Roll back';

  @override
  String get nodeUpdateRollbackHint => 'Applies at the next start';

  @override
  String get nodeUpdateUseBundledLabel => 'Use bundled node';

  @override
  String get nodeUpdateUsePreviousLabel => 'Use previous';

  @override
  String get nodeUpdateUseBundledTitle => 'Use the bundled node?';

  @override
  String get nodeUpdateUseBundledConfirm =>
      'The nodes listed here are removed. The bundled node runs from the next start.';

  @override
  String get nodeUpdateInstalledLabel => 'Installed';

  @override
  String get nodeUpdateStagedLabel => 'Staged';

  @override
  String get nodeUpdateUsePreviousTitle => 'Use the previous node?';

  @override
  String get nodeUpdateUsePreviousConfirm =>
      'This node replaces the installed one at the next start. Anything staged is removed.';

  @override
  String get nodeUpdateSourceLabel => 'Source repository';

  @override
  String get nodeUpdateSourceHint => 'A GitHub repository, as owner/name';

  @override
  String get nodeUpdateSourceSaveLabel => 'Save';

  @override
  String get nodeUpdateSourceError => 'Enter a repository as owner/name.';

  @override
  String get nodeUpdateSourceForeignHint =>
      'Libraries from another repository are not the Zenon project\'s.';

  @override
  String nodeUpdateRateLimitedUntilError(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'GitHub is limiting requests from this computer. Try again after $timeString.';
  }

  @override
  String get nodeUpdateRateLimitedError =>
      'GitHub is limiting requests from this computer. Try again later.';

  @override
  String get nodeUpdateNetworkError => 'No connection to GitHub.';

  @override
  String get nodeUpdateNotFoundError =>
      'GitHub has no such repository or file.';

  @override
  String nodeUpdateHttpError(int status) {
    return 'GitHub answered with error $status.';
  }

  @override
  String get nodeUpdateMalformedError => 'GitHub\'s answer could not be read.';

  @override
  String get nodeUpdateForbiddenUrlError =>
      'The download led outside GitHub and was refused.';

  @override
  String nodeUpdateTooLargeError(int megabytes) {
    return 'The file is over $megabytes MB.';
  }

  @override
  String get nodeUpdateSizeMismatchError => 'The download was incomplete.';

  @override
  String get nodeUpdateDigestMismatchError =>
      'The download does not match the published checksum and was deleted.';

  @override
  String get nodeUpdateExpectedLabel => 'Published';

  @override
  String get nodeUpdateActualLabel => 'Downloaded';

  @override
  String get nodeUpdateChecksumConflictError =>
      'The release\'s checksum file and GitHub\'s digest disagree. Nothing was downloaded.';

  @override
  String get nodeUpdateMalformedChecksumsError =>
      'The release\'s checksum file could not be read.';

  @override
  String get nodeUpdateUnverifiedError =>
      'The release publishes no checksum for this file.';

  @override
  String get nodeUpdateNotLibraryError => 'This is not a libznn library.';

  @override
  String get nodeUpdateCancelledError => 'Cancelled.';

  @override
  String nodeUpdateNoAssetError(String tag) {
    return 'Release $tag has no library for this platform.';
  }

  @override
  String get nodeUpdateFileError => 'The file could not be read or written.';

  @override
  String get validatorAmountUsePoint => 'Use a point for decimals';

  @override
  String get nodeSyncingNotificationTitle =>
      'The node is still syncing with the network. Please wait until the loading circle turns green before sending any transactions';

  @override
  String get nodeSyncingNotificationDetails =>
      'The information displayed in the wallet does not reflect the most recent network state. Operations should not be performed, as they will likely become invalid by the time the node is fully synced';

  @override
  String get accountBlockPublishedNotificationTitle =>
      'Account-block published';

  @override
  String accountBlockPublishedNotificationDetails(String blockType) {
    return 'Account-block type: $blockType';
  }

  @override
  String get accountBlockReviewSendNotificationTitle =>
      'Sending transaction, please review the transaction on your hardware device';

  @override
  String get accountBlockReviewReceiveNotificationTitle =>
      'Receiving transaction, please review the transaction on your hardware device';

  @override
  String accountBlockReviewNotificationDetails(String blockType) {
    return 'Review account-block type: $blockType';
  }

  @override
  String get addressAddConfirmNotificationTitle =>
      'Adding address, please confirm the address on your hardware device';

  @override
  String addressAddConfirmNotificationDetails(int index) {
    return 'Confirm address for account index: $index';
  }

  @override
  String addressDefaultLabel(int number) {
    return 'Address $number';
  }

  @override
  String get addressGenerateFailedNotificationTitle =>
      'Error while generating new address';

  @override
  String get embeddedNodeStoppingNotificationTitle =>
      'Waiting for Embedded Node to stop';

  @override
  String get embeddedNodeStoppingNotificationDetails =>
      'The app will close after the Embedded Node has been stopped';

  @override
  String get nodeLocalTimeDiscrepancyError =>
      'Local time discrepancy detected.';

  @override
  String openUrlFailedNotificationTitle(String url) {
    return 'Error while trying to open $url';
  }

  @override
  String openUrlFailedNotificationDetails(String url) {
    return 'Something went wrong while trying to open $url';
  }

  @override
  String get copied => 'Copied';

  @override
  String get clipboardPasteError => 'The clipboard data could not be obtained';

  @override
  String get clipboardPasteFailedNotificationTitle =>
      'Something went wrong while getting the clipboard data';

  @override
  String get walletPasswordIncorrectError => 'Incorrect password';

  @override
  String get walletUnlockFailedNotificationTitle => 'Unlock failed';

  @override
  String walletFileTypeNotSupportedError(String walletType) {
    return 'Wallet type ($walletType) is not supported';
  }

  @override
  String walletFilePathNotFoundError(String path) {
    return 'Given wallet path does not exist ($path)';
  }

  @override
  String get walletFileLedgerNotFoundError =>
      'Cannot find the hardware device, please connect/unlock the device on which the wallet is initialized';

  @override
  String fileDeleteNoFileError(String path) {
    return 'There is no file at the following path: $path';
  }

  @override
  String fileDeleteNoDirectoryError(String path) {
    return 'There is no directory at the following path: $path';
  }

  @override
  String get signMessage32BytesError => 'A 32 byte message is refused. Pad it';

  @override
  String get plasmaLevelHighTooltip => 'High Plasma';

  @override
  String get plasmaLevelAverageTooltip => 'Average Plasma';

  @override
  String get plasmaLevelLowTooltip => 'Low Plasma';

  @override
  String get plasmaLevelInsufficientTooltip => 'Insufficient Plasma';

  @override
  String get autoReceiveFailedNotificationTitle => 'Receive transaction failed';

  @override
  String autoReceiveFailedNotificationDetails(String error) {
    return 'Failed to receive the transaction: $error';
  }

  @override
  String transactionReceivedNotificationTitle(String address) {
    return 'Transaction received on $address';
  }

  @override
  String transactionReceivedNotificationDetails(String hash) {
    return 'Transaction hash: $hash';
  }

  @override
  String get autoUnlockInvalidSwapError => 'Invalid swap';

  @override
  String get autoUnlockAddressNotInWalletError =>
      'Swap address not in default addresses. Please add the address in the addresses list.';

  @override
  String get autoUnlockFailedNotificationTitle => 'Failed to complete swap';

  @override
  String autoUnlockFailedNotificationDetails(String error) {
    return 'Failed to complete the swap: $error';
  }

  @override
  String get completeSwapExpiresTooSoonError =>
      'The swap will expire too soon for a safe swap.';

  @override
  String get completeSwapSecretTooLargeError =>
      'The swap secret size exceeds the maximum allowed size.';

  @override
  String createPillarSuccessMessage(String controller) {
    return 'Pillar registered. Use $controller to check its status.';
  }

  @override
  String get createPillarCollateralLabel => 'Collateral';

  @override
  String get createPillarSlotFeeLabel => 'Slot fee';

  @override
  String get createPillarMomentumShareLabel => 'Momentum share';

  @override
  String get createPillarDelegationShareLabel => 'Delegation share';

  @override
  String get updatePillarRewardsTitle => 'Reward sharing';

  @override
  String get validatorAmountDigitsOnly => 'Digits and a point only';

  @override
  String get validatorAmountWholeNumber => 'Whole QSR only';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonSeeMore => 'See more';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonNotConnectedError => 'Not connected to the network';

  @override
  String get cardAvailableLabel => 'AVAILABLE';

  @override
  String availableBalanceLabel(String amount, String symbol) {
    return '$amount $symbol available';
  }

  @override
  String get nodeNotSyncedError => 'Node is not synced';

  @override
  String get rewardsHistoryLastWeekEmpty => 'No rewards in the last week';

  @override
  String get cardScaffoldAboutTooltip => 'About this card';

  @override
  String get cardScaffoldDescriptionLabel => 'Description';

  @override
  String get cardScaffoldDiscreetModeLabel => 'Discreet mode';

  @override
  String get goToPaletteHint => 'Go to';

  @override
  String get goToPaletteEmpty => 'No page by that name';

  @override
  String get assetCellUnknownStandardTooltip => 'Unknown token standard';

  @override
  String get receiveQrFailedError => 'Failed to create QR code';

  @override
  String get selectFileHint => 'Drop a file here, or click to browse';

  @override
  String get selectFileInvalidError => 'This file cannot be used';

  @override
  String get selectFileTypeLabel => 'file';

  @override
  String get settingsAddressRenameTooltip => 'Rename';

  @override
  String get settingsAddressLabelHint => 'Label';

  @override
  String get settingsAddressLabelEmptyError => 'Label can\'t be empty';

  @override
  String settingsAddressLabelTooLongNotificationTitle(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'The label has more than $max characters',
      one: 'The label has more than $max character',
    );
    return '$_temp0';
  }

  @override
  String settingsAddressLabelTooLongNotificationDetails(
    String label,
    int length,
    int max,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      length,
      locale: localeName,
      other:
          'The label $label is $length characters long, which is more than the $max limit.',
      one:
          'The label $label is $length character long, which is more than the $max limit.',
    );
    return '$_temp0';
  }

  @override
  String get settingsAddressLabelExistsNotificationTitle =>
      'Label already exists';

  @override
  String settingsAddressLabelExistsNotificationDetails(String label) {
    return 'Label $label already exists in the database';
  }

  @override
  String get settingsAddressRenameFailedNotificationTitle =>
      'Something went wrong while changing the address label';

  @override
  String settingsNodeChainIdTooltip(int client, int node) {
    return 'Client chain identifier: $client\nNode chain identifier: $node';
  }

  @override
  String settingsNodeChainIdMismatchTooltip(int client, int node) {
    return 'Chain identifier mismatch\nClient chain identifier: $client\nNode chain identifier: $node';
  }

  @override
  String get settingsNodeEncryptedTooltip => 'Encrypted connection';

  @override
  String get settingsNodeUnencryptedTooltip => 'Unencrypted connection';

  @override
  String get settingsNodeEmbeddedTooltip =>
      'Integrated Full Node: enhanced security and privacy';

  @override
  String get settingsNodeEmbeddedSyncTooltip =>
      'The Embedded Node validates all network transactions\nIt may take several hours to fully sync with the network';

  @override
  String get settingsNodeCommunityTooltip => 'Community Node';

  @override
  String get settingsNodeEditTooltip => 'Edit node';

  @override
  String get settingsNodeDeleteLabel => 'Delete node';

  @override
  String settingsNodeDeleteConfirm(String node) {
    return 'Delete $node from the list of nodes? This can\'t be undone.';
  }

  @override
  String get settingsNodeAddressHint => 'Node address with port';

  @override
  String get settingsNodeEmptyError => 'Node address can\'t be empty';

  @override
  String settingsNodeTooLongError(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'The node has more than $max characters',
      one: 'The node has more than $max character',
    );
    return '$_temp0';
  }

  @override
  String get settingsNodeExistsError => 'Node already exists';

  @override
  String settingsNodeDeleteFailedNotificationTitle(String node) {
    return 'Error during deleting node $node from the database';
  }

  @override
  String seedChoiceWordsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '$count word',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int days) {
    return '$days d';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationDaysClock(int days, String clock) {
    return '$days d $clock';
  }

  @override
  String acceleratorClosesIn(String duration) {
    return 'Closes in $duration';
  }

  @override
  String cancelUnlocksIn(String duration) {
    return 'Unlocks in $duration';
  }

  @override
  String p2pSwapExpiresIn(String duration) {
    return 'The swap expires in $duration';
  }

  @override
  String stakeDurationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String createSentinelSuccessMessage(String controller) {
    return 'Sentinel registered. Use $controller to check its status.';
  }

  @override
  String get createSentinelDepositLabel => 'Deposit';

  @override
  String get railExpand => 'Expand';

  @override
  String get railCollapse => 'Collapse';

  @override
  String get stripGeneratingPlasma => 'Generating plasma';

  @override
  String get stripPlasmaIdle => 'Plasma idle';

  @override
  String stripSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String stripPlasmaTypical(int seconds) {
    return 'usually about $seconds s';
  }

  @override
  String stripSending(String amount) {
    return 'Sending $amount';
  }

  @override
  String stripSendingMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sending $count blocks',
      one: 'Sending 1 block',
    );
    return '$_temp0';
  }

  @override
  String get stripWaitingMomentum => 'waiting for a momentum';

  @override
  String stripMomentumsBehind(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString momentums behind',
      one: '1 momentum behind',
    );
    return '$_temp0';
  }

  @override
  String get stripPeers => 'Peers';

  @override
  String get stakingStaked => 'Staked';

  @override
  String get stakingToCollect => 'To collect';

  @override
  String get stakingLast7Days => 'Last 7 days';

  @override
  String get stakingChart => 'Chart';

  @override
  String get plasmaPageFusedByYou => 'Fused by you';

  @override
  String get plasmaPageFused => 'Fused';

  @override
  String get plasmaPageOtherAddresses => 'Other addresses';

  @override
  String plasmaPageLowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count low',
      one: '1 low',
    );
    return '$_temp0';
  }

  @override
  String plasmaPageCancelFuses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cancel $count fuses',
      one: 'Cancel 1 fuse',
    );
    return '$_temp0';
  }

  @override
  String plasmaPageCancelFusesConfirm(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cancel $count fuses, $amount in all?',
      one: 'Cancel 1 fuse of $amount?',
    );
    return '$_temp0';
  }

  @override
  String plasmaPageCancelFusesDone(int done, int total) {
    return '$done of $total cancelled';
  }
}
