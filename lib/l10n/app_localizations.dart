import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('es'),
    Locale('hi'),
    Locale('zh'),
  ];

  /// No description provided for @activePillars.
  ///
  /// In en, this message translates to:
  /// **'Active Pillars'**
  String get activePillars;

  /// No description provided for @activeSentinels.
  ///
  /// In en, this message translates to:
  /// **'Active Sentinels'**
  String get activeSentinels;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Addresses can be searched by label - \"Address 1\" - and by hex value - \"z1qxemdeddedxt0kenxxxxxxxxxxxxxxxxh9amk0\"'**
  String get addressSearchDescription;

  /// No description provided for @addressToCollectRewards.
  ///
  /// In en, this message translates to:
  /// **'The address that will be able to collect the Pillar rewards'**
  String get addressToCollectRewards;

  /// No description provided for @addressToProduceMomentums.
  ///
  /// In en, this message translates to:
  /// **'The address that will produce momentums, get it from znn-controller'**
  String get addressToProduceMomentums;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @areYouSureTranfer.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to transfer {amount} {symbol} to {recipient} ?'**
  String areYouSureTranfer(Object amount, Object recipient, Object symbol);

  /// No description provided for @asset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get asset;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @beneficiaryAddress.
  ///
  /// In en, this message translates to:
  /// **'Beneficiary address'**
  String get beneficiaryAddress;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelPlasmaConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel the Plasma fusion?'**
  String get cancelPlasmaConfirmation;

  /// No description provided for @checkPillarStatus.
  ///
  /// In en, this message translates to:
  /// **' to check the Pillar status'**
  String get checkPillarStatus;

  /// No description provided for @checkSentinelStatus.
  ///
  /// In en, this message translates to:
  /// **' to check the Sentinel status'**
  String get checkSentinelStatus;

  /// No description provided for @clickToAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Click to add to favorites'**
  String get clickToAddToFavorites;

  /// No description provided for @clickToRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Click to remove from favorites'**
  String get clickToRemoveFromFavorites;

  /// No description provided for @coin.
  ///
  /// In en, this message translates to:
  /// **'Coin'**
  String get coin;

  /// No description provided for @collect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get collect;

  /// No description provided for @collectPillarRewards.
  ///
  /// In en, this message translates to:
  /// **'Collect Pillar rewards'**
  String get collectPillarRewards;

  /// No description provided for @collectSentinelRewards.
  ///
  /// In en, this message translates to:
  /// **'Collect Sentinel rewards'**
  String get collectSentinelRewards;

  /// No description provided for @collectStakingRewards.
  ///
  /// In en, this message translates to:
  /// **'Collect staking rewards'**
  String get collectStakingRewards;

  /// No description provided for @cannotReuseAddressForSentinel.
  ///
  /// In en, this message translates to:
  /// **'If this address previously revoked a Sentinel, it cannot create a new Sentinel again. Use a different address before depositing QSR.'**
  String get cannotReuseAddressForSentinel;

  /// No description provided for @couldNotSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send {amount} {symbol} to {recipient}'**
  String couldNotSend(Object amount, Object recipient, Object symbol);

  /// No description provided for @burn.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get burn;

  /// No description provided for @burnableToken.
  ///
  /// In en, this message translates to:
  /// **'Burnable by any holder'**
  String get burnableToken;

  /// No description provided for @burnTokenIssueFee.
  ///
  /// In en, this message translates to:
  /// **'You will need to burn {amount} {symbol} to issue a token'**
  String burnTokenIssueFee(Object amount, Object symbol);

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createAnotherToken.
  ///
  /// In en, this message translates to:
  /// **'Create another Token'**
  String get createAnotherToken;

  /// No description provided for @createPillarDescription.
  ///
  /// In en, this message translates to:
  /// **'Start the process of deploying a Pillar Node in the network'**
  String get createPillarDescription;

  /// No description provided for @createPillarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Pillar'**
  String get createPillarTitle;

  /// No description provided for @createSentinelDescription.
  ///
  /// In en, this message translates to:
  /// **'Start the process of deploying a Sentinel Node in the network'**
  String get createSentinelDescription;

  /// No description provided for @createStake.
  ///
  /// In en, this message translates to:
  /// **'create stake'**
  String get createStake;

  /// No description provided for @createStakeDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about staking per wallet address. Choose the duration and the amount in {kZnnCoinSymbol} for staking in order to receive {kQsrCoinSymbol}'**
  String createStakeDescription(Object kQsrCoinSymbol, Object kZnnCoinSymbol);

  /// No description provided for @createStakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Stake'**
  String get createStakeTitle;

  /// No description provided for @createToken.
  ///
  /// In en, this message translates to:
  /// **'Create Token'**
  String get createToken;

  /// No description provided for @createTokenDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a token following the ZTS specification'**
  String get createTokenDescription;

  /// No description provided for @createTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Token'**
  String get createTokenTitle;

  /// No description provided for @currentAmounts.
  ///
  /// In en, this message translates to:
  /// **'This card displays the current {kZnnCoinSymbol} and {kQsrCoinSymbol} amounts for the selected address'**
  String currentAmounts(Object kQsrCoinSymbol, Object kZnnCoinSymbol);

  /// No description provided for @currentPillarSlotFee.
  ///
  /// In en, this message translates to:
  /// **'Current Pillar Slot fee\n{coins} {kQsrCoinSymbol}'**
  String currentPillarSlotFee(Object coins, Object kQsrCoinSymbol);

  /// No description provided for @currentSentinelSlotFee.
  ///
  /// In en, this message translates to:
  /// **'Current Sentinel Slot fee\n{coins} {kQsrCoinSymbol}'**
  String currentSentinelSlotFee(Object coins, Object kQsrCoinSymbol);

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @decimals.
  ///
  /// In en, this message translates to:
  /// **'{number} decimals'**
  String decimals(Object number);

  /// No description provided for @delegateKey.
  ///
  /// In en, this message translates to:
  /// **'DELEGATE'**
  String get delegateKey;

  /// No description provided for @delegation.
  ///
  /// In en, this message translates to:
  /// **'Delegation'**
  String get delegation;

  /// No description provided for @delegationPercentageGiven.
  ///
  /// In en, this message translates to:
  /// **'Delegation percentage given: {percentage}'**
  String delegationPercentageGiven(Object percentage);

  /// No description provided for @delegationReward.
  ///
  /// In en, this message translates to:
  /// **'Delegation reward'**
  String get delegationReward;

  /// No description provided for @delegationStats.
  ///
  /// In en, this message translates to:
  /// **'Delegation Stats'**
  String get delegationStats;

  /// No description provided for @delegationStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the amount of {kZnnCoinSymbol} and the name of the Pillar that you delegated to'**
  String delegationStatsDescription(Object kZnnCoinSymbol);

  /// No description provided for @delegators.
  ///
  /// In en, this message translates to:
  /// **'Delegators: {number}'**
  String delegators(Object number);

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @deposited.
  ///
  /// In en, this message translates to:
  /// **'{kQsrCoinSymbol} deposited'**
  String deposited(Object kQsrCoinSymbol);

  /// No description provided for @depositedCoinWillBurn.
  ///
  /// In en, this message translates to:
  /// **'All the deposited {kQsrCoinSymbol} will be burned in order to create the Pillar Slot'**
  String depositedCoinWillBurn(Object kQsrCoinSymbol);

  /// No description provided for @disassemble.
  ///
  /// In en, this message translates to:
  /// **'DISASSEMBLE'**
  String get disassemble;

  /// No description provided for @disassemblePillarToUnlockCoin.
  ///
  /// In en, this message translates to:
  /// **'You will be able to unlock the {kZnnCoinSymbol} if you choose to disassemble the Pillar'**
  String disassemblePillarToUnlockCoin(Object kZnnCoinSymbol);

  /// No description provided for @disassembleSentinelToUnlockCoin.
  ///
  /// In en, this message translates to:
  /// **'You will be able to unlock the {kZnnCoinSymbol} if you choose to disassemble the Sentinel'**
  String disassembleSentinelToUnlockCoin(Object kZnnCoinSymbol);

  /// No description provided for @dualCoinStats.
  ///
  /// In en, this message translates to:
  /// **'Dual Coin Stats'**
  String get dualCoinStats;

  /// No description provided for @dualCoinStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the circulating {kZnnCoinSymbol} and {kQsrCoinSymbol} supply from the network'**
  String dualCoinStatsDescription(Object kQsrCoinSymbol, Object kZnnCoinSymbol);

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @errorCreatingToken.
  ///
  /// In en, this message translates to:
  /// **'Error while creating a new ZTS token'**
  String get errorCreatingToken;

  /// No description provided for @errorAddingTokenToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Error adding {name} token to favorites'**
  String errorAddingTokenToFavorites(Object name);

  /// No description provided for @errorBurningZts.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to burn ZTS'**
  String get errorBurningZts;

  /// No description provided for @errorCollectingPillarRewards.
  ///
  /// In en, this message translates to:
  /// **'Error while collecting Pillar rewards'**
  String get errorCollectingPillarRewards;

  /// No description provided for @errorCollectingSentinelRewards.
  ///
  /// In en, this message translates to:
  /// **'Error while collecting Sentinel rewards'**
  String get errorCollectingSentinelRewards;

  /// No description provided for @errorDeployingPillar.
  ///
  /// In en, this message translates to:
  /// **'Error while deploying a Pillar'**
  String get errorDeployingPillar;

  /// No description provided for @errorDeployingSentinel.
  ///
  /// In en, this message translates to:
  /// **'Error while deploying the Sentinel Node'**
  String get errorDeployingSentinel;

  /// No description provided for @errorDisassemblingPillar.
  ///
  /// In en, this message translates to:
  /// **'Error while disassembling Pillar'**
  String get errorDisassemblingPillar;

  /// No description provided for @errorDisassemblingSentinel.
  ///
  /// In en, this message translates to:
  /// **'Error while disassembling Sentinel'**
  String get errorDisassemblingSentinel;

  /// No description provided for @errorCollectingStakingRewards.
  ///
  /// In en, this message translates to:
  /// **'Error while collecting staking rewards'**
  String get errorCollectingStakingRewards;

  /// No description provided for @errorUndelegating.
  ///
  /// In en, this message translates to:
  /// **'Error while undelegating'**
  String get errorUndelegating;

  /// No description provided for @errorUpdatingPillar.
  ///
  /// In en, this message translates to:
  /// **'Error while updating Pillar'**
  String get errorUpdatingPillar;

  /// No description provided for @errorWhileCancellingPlasma.
  ///
  /// In en, this message translates to:
  /// **'Error while cancelling Plasma'**
  String get errorWhileCancellingPlasma;

  /// No description provided for @errorWhileCancellingStake.
  ///
  /// In en, this message translates to:
  /// **'Error while cancelling stake'**
  String get errorWhileCancellingStake;

  /// No description provided for @errorGeneratingPlasma.
  ///
  /// In en, this message translates to:
  /// **'Error while generating Plasma'**
  String get errorGeneratingPlasma;

  /// No description provided for @errorMintingToken.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to mint {symbol}'**
  String errorMintingToken(Object symbol);

  /// No description provided for @errorRemovingTokenFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Error removing {name} token from favorites'**
  String errorRemovingTokenFromFavorites(Object name);

  /// No description provided for @errorTransferringTokenOwnership.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to transfer token ownership'**
  String get errorTransferringTokenOwnership;

  /// No description provided for @errorWhileDepositing.
  ///
  /// In en, this message translates to:
  /// **'Error while depositing {kQsrCoinSymbol}'**
  String errorWhileDepositing(Object kQsrCoinSymbol);

  /// No description provided for @errorWhileGeneratingStake.
  ///
  /// In en, this message translates to:
  /// **'Error while generating stake'**
  String get errorWhileGeneratingStake;

  /// No description provided for @errorWhileWithdrawing.
  ///
  /// In en, this message translates to:
  /// **'Error while withdrawing {kQsrCoinSymbol}'**
  String errorWhileWithdrawing(Object kQsrCoinSymbol);

  /// No description provided for @expiration.
  ///
  /// In en, this message translates to:
  /// **'Expiration'**
  String get expiration;

  /// No description provided for @expectedProducedMomentums.
  ///
  /// In en, this message translates to:
  /// **'Expected/produced momentums'**
  String get expectedProducedMomentums;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get from;

  /// No description provided for @fuse.
  ///
  /// In en, this message translates to:
  /// **'Fuse'**
  String get fuse;

  /// No description provided for @fusePlasmaDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about Plasma available per wallet address. A minimum of 10 {kQsrCoinSymbol} are needed to be fused in order to generate Plasma. The more {kQsrCoinSymbol} fused, the more Plasma is produced for the beneficiary address\n\nInsufficient Plasma: Proof-of-work for Plasma generation; limited to 1 transaction per momentum\nLow Plasma: between 10 and 89 {kQsrCoinSymbol}\nAverage Plasma: between 90 and 119 {kQsrCoinSymbol}\nHigh Plasma: over 120 {kQsrCoinSymbol}; recommended for complex transactions (register Pillars, Sentinels, staking and issuing ZTS tokens)'**
  String fusePlasmaDescription(Object kQsrCoinSymbol);

  /// No description provided for @fusePlasmaTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuse Plasma'**
  String get fusePlasmaTitle;

  /// No description provided for @fusedPlasmaDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays all your addresses that have Plasma generated by fusing {kQsrCoinSymbol}'**
  String fusedPlasmaDescription(Object kQsrCoinSymbol);

  /// No description provided for @fusedPlasmaTitle.
  ///
  /// In en, this message translates to:
  /// **'Fused Plasma'**
  String get fusedPlasmaTitle;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @hAgo.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hAgo;

  /// No description provided for @hash.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get hash;

  /// No description provided for @hashValue.
  ///
  /// In en, this message translates to:
  /// **'Hash: {value}'**
  String hashValue(Object value);

  /// No description provided for @issueToken.
  ///
  /// In en, this message translates to:
  /// **'Issue Token'**
  String get issueToken;

  /// No description provided for @latestTransactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the latest transactions (including ZTS tokens) of your selected address'**
  String get latestTransactionsDescription;

  /// No description provided for @latestTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest Transactions'**
  String get latestTransactionsTitle;

  /// No description provided for @latestTransactionsTransferDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the latest transactions (including ZTS tokens) involving your wallet addresses'**
  String get latestTransactionsTransferDescription;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'{kQsrCoinSymbol} locked'**
  String locked(Object kQsrCoinSymbol);

  /// No description provided for @manageReceivingFunds.
  ///
  /// In en, this message translates to:
  /// **'Manage receiving funds'**
  String get manageReceivingFunds;

  /// No description provided for @manageSendingFunds.
  ///
  /// In en, this message translates to:
  /// **'Manage sending funds'**
  String get manageSendingFunds;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'{kQsrCoinSymbol} management'**
  String management(Object kQsrCoinSymbol);

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @maxSupply.
  ///
  /// In en, this message translates to:
  /// **'Max supply'**
  String get maxSupply;

  /// No description provided for @minAgo.
  ///
  /// In en, this message translates to:
  /// **'min ago'**
  String get minAgo;

  /// No description provided for @mint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get mint;

  /// No description provided for @mintable.
  ///
  /// In en, this message translates to:
  /// **'Mintable'**
  String get mintable;

  /// No description provided for @mintableToken.
  ///
  /// In en, this message translates to:
  /// **'Mintable token'**
  String get mintableToken;

  /// No description provided for @momentumPercentageGiven.
  ///
  /// In en, this message translates to:
  /// **'Momentum percentage given: {percentage}'**
  String momentumPercentageGiven(Object percentage);

  /// No description provided for @momentumReward.
  ///
  /// In en, this message translates to:
  /// **'Momentum reward'**
  String get momentumReward;

  /// No description provided for @morePlasmaRequired.
  ///
  /// In en, this message translates to:
  /// **'More Plasma is required to perform complex transactions. Please fuse enough QSR before proceeding.'**
  String get morePlasmaRequired;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @newOwnerAddress.
  ///
  /// In en, this message translates to:
  /// **'New owner address'**
  String get newOwnerAddress;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get noItemsFound;

  /// No description provided for @noMoreItems.
  ///
  /// In en, this message translates to:
  /// **'No more items'**
  String get noMoreItems;

  /// No description provided for @noRewardsCollect.
  ///
  /// In en, this message translates to:
  /// **'No rewards to collect'**
  String get noRewardsCollect;

  /// No description provided for @noZtsTokensAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ZTS tokens available'**
  String get noZtsTokensAvailable;

  /// No description provided for @numberOfDecimals.
  ///
  /// In en, this message translates to:
  /// **'Number of decimals: {number}'**
  String numberOfDecimals(Object number);

  /// No description provided for @ownZtsToken.
  ///
  /// In en, this message translates to:
  /// **'You own this ZTS token'**
  String get ownZtsToken;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @pendingTransactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the pending transactions (including ZTS tokens) for the selected address'**
  String get pendingTransactionsDescription;

  /// No description provided for @pendingTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Transactions'**
  String get pendingTransactionsTitle;

  /// No description provided for @percentageDelegationRewardsGiven.
  ///
  /// In en, this message translates to:
  /// **'Percentage of delegation rewards given to the delegators'**
  String get percentageDelegationRewardsGiven;

  /// No description provided for @percentageOfMomentumRewards.
  ///
  /// In en, this message translates to:
  /// **'Percentage of momentum rewards given to the delegators'**
  String get percentageOfMomentumRewards;

  /// No description provided for @pillar.
  ///
  /// In en, this message translates to:
  /// **'Pillar'**
  String get pillar;

  /// No description provided for @pillarCollectDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays your current Pillar rewards (either from your Pillar Node or from your delegation) that are ready to be collected. If there are any rewards available, you will be able to collect them. In order to receive rewards, the Pillar Node needs to be not only registered in the network, but also deployed (use znn-controller for this operation) and it must produce momentums'**
  String get pillarCollectDescription;

  /// No description provided for @pillarCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'Pillar Collect'**
  String get pillarCollectTitle;

  /// No description provided for @pillarDelegationError.
  ///
  /// In en, this message translates to:
  /// **'Pillar delegation error'**
  String get pillarDelegationError;

  /// No description provided for @pillarDetails.
  ///
  /// In en, this message translates to:
  /// **'Pillar details'**
  String get pillarDetails;

  /// No description provided for @pillarMomentumAddress.
  ///
  /// In en, this message translates to:
  /// **'Pillar momentum address'**
  String get pillarMomentumAddress;

  /// No description provided for @pillarMomentumRewards.
  ///
  /// In en, this message translates to:
  /// **'Pillar momentum rewards'**
  String get pillarMomentumRewards;

  /// No description provided for @pillarName.
  ///
  /// In en, this message translates to:
  /// **'Pillar name'**
  String get pillarName;

  /// No description provided for @pillarProducerAddress.
  ///
  /// In en, this message translates to:
  /// **'Pillar producer address'**
  String get pillarProducerAddress;

  /// No description provided for @pillarRegistered.
  ///
  /// In en, this message translates to:
  /// **'Pillar registered'**
  String get pillarRegistered;

  /// No description provided for @pillarRewardAddress.
  ///
  /// In en, this message translates to:
  /// **'Pillar reward address'**
  String get pillarRewardAddress;

  /// No description provided for @pillarRewardsBlockCreated.
  ///
  /// In en, this message translates to:
  /// **'Successfully created block for collecting the pillar rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.'**
  String get pillarRewardsBlockCreated;

  /// No description provided for @pillarRewardsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays a chart with your Pillar rewards. Pillar rewards are generated either by operating a Pillar Node or from delegations to a Pillar Node'**
  String get pillarRewardsDescription;

  /// No description provided for @pillarRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pillar Rewards'**
  String get pillarRewardsTitle;

  /// No description provided for @plasmaStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about current Plasma level for each wallet address. Plasma is used as an anti-spam mechanism. More Plasma you have per address, more transactions you will be able to send or receive on that address. Low or insufficient Plasma will require proof-of-work for generation. Fuse 10 {kQsrCoinSymbol} or more in order to obtain Plasma for any given address\n\nInsufficient Plasma: Proof-of-work for Plasma generation; limited to 1 transaction per momentum\nLow Plasma: between 10 and 50 {kQsrCoinSymbol}\nAverage Plasma: between 50 and 119 {kQsrCoinSymbol}\nHigh Plasma: over 120 {kQsrCoinSymbol}; recommended to make complex transactions (deploy Pillars, Sentinels, staking and issuing ZTS tokens)'**
  String plasmaStatsDescription(Object kQsrCoinSymbol);

  /// No description provided for @plasmaStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Plasma Stats'**
  String get plasmaStatsTitle;

  /// No description provided for @pillarStats.
  ///
  /// In en, this message translates to:
  /// **'Pillar Stats'**
  String get pillarStats;

  /// No description provided for @pillarUpdate.
  ///
  /// In en, this message translates to:
  /// **'Pillar update'**
  String get pillarUpdate;

  /// No description provided for @pillarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Pillar updated'**
  String get pillarUpdated;

  /// No description provided for @pillars.
  ///
  /// In en, this message translates to:
  /// **'Pillars'**
  String get pillars;

  /// No description provided for @pillarsWithNumber.
  ///
  /// In en, this message translates to:
  /// **'Pillars: {number}'**
  String pillarsWithNumber(Object number);

  /// No description provided for @pillarsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the number of active Pillars in the network'**
  String get pillarsDescription;

  /// No description provided for @pillarsListDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays Pillar Nodes that are currently active in the network. The list contains the name of the Pillar, the associated producer address, the weight (total number of delegations) and your delegation status. You can choose to delegate your {kZnnCoinSymbol} balance to any Pillar in order to receive delegation rewards in {kZnnCoinSymbol}. You can undelegate the balance at any time, without any penalties. Minimum delegation amount is 1 {kZnnCoinSymbol} per address'**
  String pillarsListDescription(Object kZnnCoinSymbol);

  /// No description provided for @pillarsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Pillars List'**
  String get pillarsListTitle;

  /// No description provided for @pillarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pillars'**
  String get pillarsTitle;

  /// No description provided for @plasma.
  ///
  /// In en, this message translates to:
  /// **'Plasma'**
  String get plasma;

  /// No description provided for @plasmaCheck.
  ///
  /// In en, this message translates to:
  /// **'Plasma Check'**
  String get plasmaCheck;

  /// No description provided for @pressToReceive.
  ///
  /// In en, this message translates to:
  /// **'Press to receive the transaction'**
  String get pressToReceive;

  /// No description provided for @producerAddress.
  ///
  /// In en, this message translates to:
  /// **'Producer Address'**
  String get producerAddress;

  /// No description provided for @quasarTransactions.
  ///
  /// In en, this message translates to:
  /// **'{quasar} transactions'**
  String quasarTransactions(Object quasar);

  /// No description provided for @realtimeStats.
  ///
  /// In en, this message translates to:
  /// **'Realtime Stats'**
  String get realtimeStats;

  /// No description provided for @realtimeStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the number of {kZnnCoinSymbol} and {kQsrCoinSymbol} transactions. For example, a delegation is considered a {kZnnCoinSymbol} transaction from the network\'s perspective. Every interaction with the network embedded contracts is internally considered a transaction'**
  String realtimeStatsDescription(Object kQsrCoinSymbol, Object kZnnCoinSymbol);

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @receiver.
  ///
  /// In en, this message translates to:
  /// **'Receiver'**
  String get receiver;

  /// No description provided for @recipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient Address'**
  String get recipientAddress;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @registerAnotherPillar.
  ///
  /// In en, this message translates to:
  /// **'Register another Pillar'**
  String get registerAnotherPillar;

  /// No description provided for @registerPillar.
  ///
  /// In en, this message translates to:
  /// **'Register Pillar'**
  String get registerPillar;

  /// No description provided for @registerSentinel.
  ///
  /// In en, this message translates to:
  /// **'Register Sentinel'**
  String get registerSentinel;

  /// No description provided for @registeredUse.
  ///
  /// In en, this message translates to:
  /// **' registered. Use '**
  String get registeredUse;

  /// No description provided for @requiredForPillarSlot.
  ///
  /// In en, this message translates to:
  /// **'{coins} {kQsrCoinSymbol} required for a Pillar slot'**
  String requiredForPillarSlot(Object coins, Object kQsrCoinSymbol);

  /// No description provided for @requiredForSentinelNode.
  ///
  /// In en, this message translates to:
  /// **'{coins} {kQsrCoinSymbol} required for a Sentinel Node'**
  String requiredForSentinelNode(Object coins, Object kQsrCoinSymbol);

  /// No description provided for @revocationWindowOpen.
  ///
  /// In en, this message translates to:
  /// **'Revocation window is open'**
  String get revocationWindowOpen;

  /// No description provided for @sAgo.
  ///
  /// In en, this message translates to:
  /// **'s ago'**
  String get sAgo;

  /// No description provided for @saveQr.
  ///
  /// In en, this message translates to:
  /// **'Save QR'**
  String get saveQr;

  /// No description provided for @searchTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, symbol, owner, or token standard'**
  String get searchTokenHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendTransaction.
  ///
  /// In en, this message translates to:
  /// **'send transaction'**
  String get sendTransaction;

  /// No description provided for @sentinel.
  ///
  /// In en, this message translates to:
  /// **'Sentinel'**
  String get sentinel;

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @senderAddressDescription.
  ///
  /// In en, this message translates to:
  /// **'The address from which the transaction will be sent'**
  String get senderAddressDescription;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @sentDetails.
  ///
  /// In en, this message translates to:
  /// **'Sent {amount} {symbol} from {sender} to {recipient}'**
  String sentDetails(
    Object amount,
    Object recipient,
    Object sender,
    Object symbol,
  );

  /// No description provided for @sentinelAddress.
  ///
  /// In en, this message translates to:
  /// **'Sentinel Address'**
  String get sentinelAddress;

  /// No description provided for @sentinelCollectDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays your current Sentinel rewards that are ready to be collected. If there are any rewards available, you will be able to collect them. In order to receive rewards, the Sentinel Node needs to be not only registered in the network, but also deployed (use znn-controller for this operation) and it must have >90% daily uptime'**
  String get sentinelCollectDescription;

  /// No description provided for @sentinelCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentinel Collect'**
  String get sentinelCollectTitle;

  /// No description provided for @sentinelRewardsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays a chart with your Sentinel rewards from your Sentinel Node'**
  String get sentinelRewardsDescription;

  /// No description provided for @sentinelRewardsBlockCreated.
  ///
  /// In en, this message translates to:
  /// **'Successfully created block for collecting the sentinel rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.'**
  String get sentinelRewardsBlockCreated;

  /// No description provided for @sentinelRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentinel Rewards'**
  String get sentinelRewardsTitle;

  /// No description provided for @sentinelDetectedOnThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Sentinel detected on this address'**
  String get sentinelDetectedOnThisAddress;

  /// No description provided for @sentinelRegistered.
  ///
  /// In en, this message translates to:
  /// **'Sentinel registered'**
  String get sentinelRegistered;

  /// No description provided for @sentinelStats.
  ///
  /// In en, this message translates to:
  /// **'Sentinel Stats'**
  String get sentinelStats;

  /// No description provided for @sentinels.
  ///
  /// In en, this message translates to:
  /// **'Sentinels'**
  String get sentinels;

  /// No description provided for @sentinelsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the number of active Sentinels in the network'**
  String get sentinelsDescription;

  /// No description provided for @sentinelsListDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about the Sentinels that are currently active in the network'**
  String get sentinelsListDescription;

  /// No description provided for @sentinelsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Sentinels List'**
  String get sentinelsListTitle;

  /// No description provided for @shareQr.
  ///
  /// In en, this message translates to:
  /// **'Share QR'**
  String get shareQr;

  /// No description provided for @spawn.
  ///
  /// In en, this message translates to:
  /// **'Spawn'**
  String get spawn;

  /// No description provided for @stake.
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get stake;

  /// No description provided for @stakeCollectDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays your current staking rewards that are ready to be collected. If there are any rewards available, you will be able to collect them'**
  String get stakeCollectDescription;

  /// No description provided for @stakeCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'Stake Collect'**
  String get stakeCollectTitle;

  /// No description provided for @stakingDuration.
  ///
  /// In en, this message translates to:
  /// **'Staking duration'**
  String get stakingDuration;

  /// No description provided for @stakingStats.
  ///
  /// In en, this message translates to:
  /// **'Staking Stats'**
  String get stakingStats;

  /// No description provided for @stakingStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the number of staking entries and the total {kZnnCoinSymbol} that you are currently staking'**
  String stakingStatsDescription(Object kZnnCoinSymbol);

  /// No description provided for @stakesListDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about the stake entries for the selected address'**
  String get stakesListDescription;

  /// No description provided for @stakesListTitle.
  ///
  /// In en, this message translates to:
  /// **'Stakes'**
  String get stakesListTitle;

  /// No description provided for @stakingRewardsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays a chart with your staking rewards from your staking entries'**
  String get stakingRewardsDescription;

  /// No description provided for @stakingRewardsBlockCreated.
  ///
  /// In en, this message translates to:
  /// **'Successfully created block for collecting the staking rewards. It will take at least 30 seconds for the data to update and to be able to receive the rewards.'**
  String get stakingRewardsBlockCreated;

  /// No description provided for @stakingRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Staking Rewards'**
  String get stakingRewardsTitle;

  /// No description provided for @successfully.
  ///
  /// In en, this message translates to:
  /// **'successfully'**
  String get successfully;

  /// No description provided for @successfullyBurned.
  ///
  /// In en, this message translates to:
  /// **'Successfully burned {amount} {symbol}'**
  String successfullyBurned(Object amount, Object symbol);

  /// No description provided for @successfullyBurnedRequestedAmount.
  ///
  /// In en, this message translates to:
  /// **'You have successfully burned the requested amount: {amount} {symbol} {hash}'**
  String successfullyBurnedRequestedAmount(
    Object amount,
    Object hash,
    Object symbol,
  );

  /// No description provided for @successfullyMinted.
  ///
  /// In en, this message translates to:
  /// **'Successfully minted {amount} {symbol}'**
  String successfullyMinted(Object amount, Object symbol);

  /// No description provided for @successfullyMintedRequestedAmount.
  ///
  /// In en, this message translates to:
  /// **'You have successfully minted the requested amount: {amount} {symbol} {hash}'**
  String successfullyMintedRequestedAmount(
    Object amount,
    Object hash,
    Object symbol,
  );

  /// No description provided for @sufficientPlasma.
  ///
  /// In en, this message translates to:
  /// **'Sufficient Plasma'**
  String get sufficientPlasma;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// No description provided for @tokenAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} token has been added to favorites'**
  String tokenAddedToFavorites(Object name);

  /// No description provided for @tokenBalanceDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays information about ZTS tokens that you currently hold in your wallet'**
  String get tokenBalanceDescription;

  /// No description provided for @tokenBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Token Balance'**
  String get tokenBalanceTitle;

  /// No description provided for @tokenBurnTooltip.
  ///
  /// In en, this message translates to:
  /// **'When enabled, any holder can burn tokens from their own balance. When disabled, only the token owner can burn.'**
  String get tokenBurnTooltip;

  /// No description provided for @tokenCreation.
  ///
  /// In en, this message translates to:
  /// **'ZNN Check'**
  String get tokenCreation;

  /// No description provided for @tokenDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get tokenDetails;

  /// No description provided for @tokenDomain.
  ///
  /// In en, this message translates to:
  /// **'Token Domain'**
  String get tokenDomain;

  /// No description provided for @tokenIssuanceAddressDescription.
  ///
  /// In en, this message translates to:
  /// **'This will be your issuance address'**
  String get tokenIssuanceAddressDescription;

  /// No description provided for @tokenMetrics.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get tokenMetrics;

  /// No description provided for @tokenMintableBurnableOptions.
  ///
  /// In en, this message translates to:
  /// **'Mintable and Burnable Options'**
  String get tokenMintableBurnableOptions;

  /// No description provided for @tokenMintableBurnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mintable: {mintable}\nBurnable: {burnable}'**
  String tokenMintableBurnableSubtitle(Object burnable, Object mintable);

  /// No description provided for @tokenMintableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Whether or not this token is mintable after creation'**
  String get tokenMintableTooltip;

  /// No description provided for @tokenName.
  ///
  /// In en, this message translates to:
  /// **'Token Name'**
  String get tokenName;

  /// No description provided for @tokenRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'{name} token has been removed from favorites'**
  String tokenRemovedFromFavorites(Object name);

  /// No description provided for @tokenStatusUtilityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Token status: utility or non-utility (e.g. security token)'**
  String get tokenStatusUtilityTooltip;

  /// No description provided for @tokenSummary.
  ///
  /// In en, this message translates to:
  /// **'Token {name} with symbol {symbol} and ZTS {tokenStandard}'**
  String tokenSummary(Object name, Object symbol, Object tokenStandard);

  /// No description provided for @tokenSupplyOutOfMax.
  ///
  /// In en, this message translates to:
  /// **'{totalSupply} out of {maxSupply} {symbol}'**
  String tokenSupplyOutOfMax(
    Object maxSupply,
    Object symbol,
    Object totalSupply,
  );

  /// No description provided for @tokenSymbol.
  ///
  /// In en, this message translates to:
  /// **'Token Symbol'**
  String get tokenSymbol;

  /// No description provided for @tokenTransactions.
  ///
  /// In en, this message translates to:
  /// **'Token Transactions'**
  String get tokenTransactions;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get tokens;

  /// No description provided for @tokensCardDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays a grid with all the ZTS tokens from the network, including ZTS tokens issued by you'**
  String get tokensCardDescription;

  /// No description provided for @totalSupply.
  ///
  /// In en, this message translates to:
  /// **'Total supply'**
  String get totalSupply;

  /// No description provided for @transactionError.
  ///
  /// In en, this message translates to:
  /// **'Error while receiving transaction'**
  String get transactionError;

  /// No description provided for @visitDomain.
  ///
  /// In en, this message translates to:
  /// **'Visit {domain}'**
  String visitDomain(Object domain);

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @transactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'This card displays the total number of transactions settled in the last hour across the network'**
  String get transactionsDescription;

  /// No description provided for @transactionsLastHour.
  ///
  /// In en, this message translates to:
  /// **'transactions in the last hour'**
  String get transactionsLastHour;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @transferDescription.
  ///
  /// In en, this message translates to:
  /// **'Redirects you to the Transfer tab where you can manage sending and receiving funds'**
  String get transferDescription;

  /// No description provided for @transferredTokenOwnership.
  ///
  /// In en, this message translates to:
  /// **'Successfully transferred ownership of {name} token'**
  String transferredTokenOwnership(Object name);

  /// No description provided for @transferredTokenOwnershipToAddress.
  ///
  /// In en, this message translates to:
  /// **'Successfully transferred ownership of {name} token to address {address}'**
  String transferredTokenOwnershipToAddress(Object address, Object name);

  /// No description provided for @transferTokenOwnership.
  ///
  /// In en, this message translates to:
  /// **'Transfer token ownership'**
  String get transferTokenOwnership;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @undelegate.
  ///
  /// In en, this message translates to:
  /// **'UNDELEGATE'**
  String get undelegate;

  /// No description provided for @untilRevocationWindowOpens.
  ///
  /// In en, this message translates to:
  /// **'Until revocation window opens'**
  String get untilRevocationWindowOpens;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updatePillar.
  ///
  /// In en, this message translates to:
  /// **'Update Pillar'**
  String get updatePillar;

  /// No description provided for @updatePillarSettings.
  ///
  /// In en, this message translates to:
  /// **'Update Pillar settings'**
  String get updatePillarSettings;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @utilityToken.
  ///
  /// In en, this message translates to:
  /// **'Utility token'**
  String get utilityToken;

  /// No description provided for @usDateFormat.
  ///
  /// In en, this message translates to:
  /// **'MM/dd/yyyy'**
  String get usDateFormat;

  /// No description provided for @viewPillars.
  ///
  /// In en, this message translates to:
  /// **'View Pillars'**
  String get viewPillars;

  /// No description provided for @viewMyTokens.
  ///
  /// In en, this message translates to:
  /// **'View my Tokens'**
  String get viewMyTokens;

  /// No description provided for @viewSentinels.
  ///
  /// In en, this message translates to:
  /// **'View Sentinels'**
  String get viewSentinels;

  /// No description provided for @waitingForDataFetching.
  ///
  /// In en, this message translates to:
  /// **'Waiting for data fetching'**
  String get waitingForDataFetching;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @youHaveDeposited.
  ///
  /// In en, this message translates to:
  /// **'You have deposited {coins} {kQsrCoinSymbol}'**
  String youHaveDeposited(Object coins, Object kQsrCoinSymbol);

  /// No description provided for @zenonTransactions.
  ///
  /// In en, this message translates to:
  /// **'{zenon} transactions'**
  String zenonTransactions(Object zenon);

  /// No description provided for @znnController.
  ///
  /// In en, this message translates to:
  /// **'znn-controller '**
  String get znnController;

  /// No description provided for @ztsSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Coins and tokens can be searched by name - \"Zenon\" -, by symbol - \"ZNN\" -, and by token standard - \"zts1znnxxxxxxxxxxxxx9z4ulx\"'**
  String get ztsSearchDescription;

  /// No description provided for @burnTokenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Burn {amount}?'**
  String burnTokenConfirm(Object amount);

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get cannotBeUndone;

  /// No description provided for @transferTokenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Transfer {symbol}?'**
  String transferTokenConfirm(Object symbol);

  /// No description provided for @transferTokenConfirmTo.
  ///
  /// In en, this message translates to:
  /// **'{address} becomes the owner. This cannot be undone.'**
  String transferTokenConfirmTo(Object address);

  /// No description provided for @sentinelYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get sentinelYours;

  /// No description provided for @disassembleSentinelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disassemble the sentinel of {address}?'**
  String disassembleSentinelConfirm(Object address);

  /// No description provided for @validatorInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get validatorInvalidAddress;

  /// No description provided for @validatorInvalidNode.
  ///
  /// In en, this message translates to:
  /// **'Invalid Node'**
  String get validatorInvalidNode;

  /// No description provided for @validatorAddressNotInWallet.
  ///
  /// In en, this message translates to:
  /// **'Must be an address from your wallet'**
  String get validatorAddressNotInWallet;

  /// Under a form field left empty. fieldName is the field's own label, given by the screen that shows it.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must not be empty'**
  String validatorFieldEmpty(String fieldName);

  /// No description provided for @validatorNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Number required'**
  String get validatorNumberRequired;

  /// No description provided for @validatorInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Input is not a valid number'**
  String get validatorInvalidNumber;

  /// No description provided for @validatorInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get validatorInvalidAmount;

  /// No description provided for @validatorError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get validatorError;

  /// No description provided for @validatorValueNull.
  ///
  /// In en, this message translates to:
  /// **'Value is null'**
  String get validatorValueNull;

  /// No description provided for @validatorEmptyBalance.
  ///
  /// In en, this message translates to:
  /// **'Empty balance'**
  String get validatorEmptyBalance;

  /// No description provided for @validatorEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get validatorEnterValidAmount;

  /// No description provided for @validatorTooManyDecimals.
  ///
  /// In en, this message translates to:
  /// **'Inputted number has too many decimals'**
  String get validatorTooManyDecimals;

  /// Under an amount field when the whole balance is less than the least the action takes. min is that least amount, a formatted decimal number.
  ///
  /// In en, this message translates to:
  /// **'Your available balance must be at least {min}'**
  String validatorBalanceBelowMin(String min);

  /// Under an amount field that takes one amount only. value is that amount, a formatted decimal number.
  ///
  /// In en, this message translates to:
  /// **'Value must be {value}'**
  String validatorValueMustBe(String value);

  /// The same sentence as validatorValueMustBe, shown by fields where the least amount is itself allowed. The English has two spaces before the value, as the wallet always showed it; a translation takes one.
  ///
  /// In en, this message translates to:
  /// **'Value must be  {value}'**
  String validatorValueMustBeMinAllowed(String value);

  /// Under an amount field when the amount is outside what the action takes. min and max are formatted decimal numbers.
  ///
  /// In en, this message translates to:
  /// **'Value must be between {min} and {max}'**
  String validatorValueOutOfRange(String min, String max);

  /// No description provided for @validatorValueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Value can\'t be empty'**
  String get validatorValueEmpty;

  /// No description provided for @validatorEnterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter an address'**
  String get validatorEnterAddress;

  /// No description provided for @validatorPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validatorPasswordsDoNotMatch;

  /// No description provided for @validatorPasswordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password not strong enough'**
  String get validatorPasswordTooWeak;

  /// No description provided for @validatorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid password'**
  String get validatorInvalidPassword;

  /// No description provided for @validatorPillarProducerAddressSameSeed.
  ///
  /// In en, this message translates to:
  /// **'Pillar producer address must be generated from a different seed'**
  String get validatorPillarProducerAddressSameSeed;

  /// No description provided for @validatorMaxSupplyNotZero.
  ///
  /// In en, this message translates to:
  /// **'Max supply must be 0 for non-mintable tokens'**
  String get validatorMaxSupplyNotZero;

  /// No description provided for @validatorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get validatorInvalidUrl;

  /// No description provided for @validatorInvalidHash.
  ///
  /// In en, this message translates to:
  /// **'Invalid hash'**
  String get validatorInvalidHash;

  /// No description provided for @validatorInvalidSecret.
  ///
  /// In en, this message translates to:
  /// **'Invalid secret'**
  String get validatorInvalidSecret;

  /// No description provided for @ledgerStatusDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get ledgerStatusDeny;

  /// No description provided for @ledgerStatusWrongP1P2.
  ///
  /// In en, this message translates to:
  /// **'Invalid P1 or P2'**
  String get ledgerStatusWrongP1P2;

  /// No description provided for @ledgerStatusWrongDataLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid data length'**
  String get ledgerStatusWrongDataLength;

  /// No description provided for @ledgerStatusInactiveDevice.
  ///
  /// In en, this message translates to:
  /// **'Device is inactive'**
  String get ledgerStatusInactiveDevice;

  /// No description provided for @ledgerStatusNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Request not allowed'**
  String get ledgerStatusNotAllowed;

  /// No description provided for @ledgerStatusInsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Instruction not supported, please make sure the Zenon app is opened'**
  String get ledgerStatusInsNotSupported;

  /// No description provided for @ledgerStatusClaNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Class not supported, please make sure the Zenon app is opened'**
  String get ledgerStatusClaNotSupported;

  /// No description provided for @ledgerStatusAppIsNotOpen.
  ///
  /// In en, this message translates to:
  /// **'App not open, please open the Zenon app on your device'**
  String get ledgerStatusAppIsNotOpen;

  /// No description provided for @ledgerStatusWrongResponseLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid response, please reconnect the device and try again'**
  String get ledgerStatusWrongResponseLength;

  /// No description provided for @ledgerStatusDisplayBip32PathFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to display BIP32 path'**
  String get ledgerStatusDisplayBip32PathFail;

  /// No description provided for @ledgerStatusDisplayAddressFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to display address'**
  String get ledgerStatusDisplayAddressFail;

  /// No description provided for @ledgerStatusDisplayAmountFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to display amount'**
  String get ledgerStatusDisplayAmountFail;

  /// No description provided for @ledgerStatusWrongTxLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid transaction length'**
  String get ledgerStatusWrongTxLength;

  /// No description provided for @ledgerStatusTxParsingFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse transaction'**
  String get ledgerStatusTxParsingFail;

  /// No description provided for @ledgerStatusTxHashFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to hash transaction'**
  String get ledgerStatusTxHashFail;

  /// No description provided for @ledgerStatusBadState.
  ///
  /// In en, this message translates to:
  /// **'Bad state, please reconnect the device and try again'**
  String get ledgerStatusBadState;

  /// No description provided for @ledgerStatusSignatureFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to create signature'**
  String get ledgerStatusSignatureFail;

  /// No description provided for @ledgerStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get ledgerStatusSuccess;

  /// No description provided for @ledgerStatusUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error, please make sure the device is unlocked'**
  String get ledgerStatusUnknownError;

  /// How long ago a transaction was made, in whole hours, in a narrow table column. h is the short unit for hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} h ago} other{{count} h ago}}'**
  String timeAgoHours(int count);

  /// How long ago a transaction was made, in whole minutes, in a narrow table column. min is the short unit for minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} min ago} other{{count} min ago}}'**
  String timeAgoMinutes(int count);

  /// How long ago a transaction was made, in whole seconds, in a narrow table column. s is the short unit for seconds. The count can be 0.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} s ago} other{{count} s ago}}'**
  String timeAgoSeconds(int count);

  /// A length of time of a day or more, as whole days and the hours left over, in short units: 214 d 3 h.
  ///
  /// In en, this message translates to:
  /// **'{days} d {hours} h'**
  String durationDaysHours(int days, int hours);

  /// A length of time under a day, as whole hours and the minutes left over, in short units: 9 h 52 m.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} m'**
  String durationHoursMinutes(int hours, int minutes);

  /// A length of time under an hour, as whole minutes and the seconds left over, in short units: 14 m 32 s.
  ///
  /// In en, this message translates to:
  /// **'{minutes} m {seconds} s'**
  String durationMinutesSeconds(int minutes, int seconds);

  /// A length of time under a minute, in whole seconds, in a short unit: 32 s. Also what a finished countdown reads, 0 s.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(int seconds);

  /// The button on the Tokens page that opens the steps for issuing a new ZTS token.
  ///
  /// In en, this message translates to:
  /// **'Create token'**
  String get createTokenOpenLabel;

  /// Label over a count on the Tokens page: how many different ZTS tokens the selected address holds.
  ///
  /// In en, this message translates to:
  /// **'Tokens held'**
  String get createTokenHeldLabel;

  /// Label beside the amount of ZNN that issuing a new token costs, on the Tokens page and on the last step before the token is issued.
  ///
  /// In en, this message translates to:
  /// **'Issue fee'**
  String get createTokenFeeLabel;

  /// Label beside a number from 0 to 18 in the summary of a new token: how many decimal places the token has.
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get createTokenDecimalsLabel;

  /// Example shown in the empty domain field of a new token. A domain name without https:// in front.
  ///
  /// In en, this message translates to:
  /// **'example.com'**
  String get createTokenDomainHint;

  /// Title of the notification shown when the wallet starts generating Plasma (proof of work) for a transaction, here one that receives funds. Every plasmaPurpose key is this sentence for another action; translate each as one whole sentence.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to receive transaction'**
  String get plasmaPurposeReceiveTransaction;

  /// No description provided for @plasmaPurposeSendTransaction.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to send transaction'**
  String get plasmaPurposeSendTransaction;

  /// The plasmaPurpose sentence for a transfer asked for by an app connected over WalletConnect.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to Execute transfer'**
  String get plasmaPurposeExecuteTransfer;

  /// The plasmaPurpose sentence for a send asked for by a web page through the dapp bridge. origin is that page's origin, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to Send for {origin}'**
  String plasmaPurposeSendForDapp(String origin);

  /// No description provided for @plasmaPurposeCreateStake.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to create stake'**
  String get plasmaPurposeCreateStake;

  /// No description provided for @plasmaPurposeCancelStake.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to cancel stake'**
  String get plasmaPurposeCancelStake;

  /// No description provided for @plasmaPurposeCollectStakingRewards.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to Collect staking rewards'**
  String get plasmaPurposeCollectStakingRewards;

  /// No description provided for @plasmaPurposeCollectPillarRewards.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to Collect Pillar rewards'**
  String get plasmaPurposeCollectPillarRewards;

  /// No description provided for @plasmaPurposeCollectSentinelRewards.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to Collect Sentinel rewards'**
  String get plasmaPurposeCollectSentinelRewards;

  /// No description provided for @plasmaPurposeDelegateToPillar.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to delegate to Pillar'**
  String get plasmaPurposeDelegateToPillar;

  /// No description provided for @plasmaPurposeUndelegate.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to undelegate'**
  String get plasmaPurposeUndelegate;

  /// The plasmaPurpose sentence for fusing the second coin to get Plasma. qsrSymbol is that coin's symbol.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to fuse {qsrSymbol} for Plasma'**
  String plasmaPurposeFuseQsrForPlasma(String qsrSymbol);

  /// No description provided for @plasmaPurposeCancelPlasma.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to cancel Plasma'**
  String get plasmaPurposeCancelPlasma;

  /// No description provided for @plasmaPurposeRegisterPillar.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to register Pillar'**
  String get plasmaPurposeRegisterPillar;

  /// No description provided for @plasmaPurposeUpdatePillar.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to update pillar'**
  String get plasmaPurposeUpdatePillar;

  /// No description provided for @plasmaPurposeDisassemblePillar.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to disassemble Pillar'**
  String get plasmaPurposeDisassemblePillar;

  /// The plasmaPurpose sentence for depositing the second coin towards a Pillar Slot. qsrSymbol is that coin's symbol. The English says from where for is meant, as the wallet always showed it; a translation says for.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to deposit {qsrSymbol} from Pillar Slot'**
  String plasmaPurposeDepositQsrForPillarSlot(String qsrSymbol);

  /// The plasmaPurpose sentence for taking back the second coin deposited towards a Pillar Slot. qsrSymbol is that coin's symbol.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to withdraw {qsrSymbol} from Pillar Slot'**
  String plasmaPurposeWithdrawQsrFromPillarSlot(String qsrSymbol);

  /// No description provided for @plasmaPurposeRegisterSentinel.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to register Sentinel'**
  String get plasmaPurposeRegisterSentinel;

  /// No description provided for @plasmaPurposeDisassembleSentinel.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to disassemble Sentinel'**
  String get plasmaPurposeDisassembleSentinel;

  /// The plasmaPurpose sentence for depositing the second coin towards a Sentinel Slot. qsrSymbol is that coin's symbol.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to deposit {qsrSymbol} for Sentinel Slot'**
  String plasmaPurposeDepositQsrForSentinelSlot(String qsrSymbol);

  /// The plasmaPurpose sentence for taking back the second coin deposited towards a Sentinel Slot. qsrSymbol is that coin's symbol.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to withdraw {qsrSymbol} from Sentinel Slot'**
  String plasmaPurposeWithdrawQsrFromSentinelSlot(String qsrSymbol);

  /// No description provided for @plasmaPurposeIssueToken.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to issue token'**
  String get plasmaPurposeIssueToken;

  /// No description provided for @plasmaPurposeMintToken.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to mint token'**
  String get plasmaPurposeMintToken;

  /// No description provided for @plasmaPurposeBurnToken.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to burn token'**
  String get plasmaPurposeBurnToken;

  /// The plasmaPurpose sentence for handing the ownership of a token to another address.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to transfer token'**
  String get plasmaPurposeTransferToken;

  /// The plasmaPurpose sentence for creating an Accelerator-Z project. The English says creating where create is meant, as the wallet always showed it; a translation takes the plain verb.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to creating project'**
  String get plasmaPurposeCreateProject;

  /// No description provided for @plasmaPurposeCreatePhase.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to create phase'**
  String get plasmaPurposeCreatePhase;

  /// No description provided for @plasmaPurposeUpdatePhase.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to update phase'**
  String get plasmaPurposeUpdatePhase;

  /// No description provided for @plasmaPurposeVoteForProject.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to vote for project'**
  String get plasmaPurposeVoteForProject;

  /// No description provided for @plasmaPurposeDonateToAccelerator.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to donate for accelerator'**
  String get plasmaPurposeDonateToAccelerator;

  /// No description provided for @plasmaPurposeStartSwap.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to start swap'**
  String get plasmaPurposeStartSwap;

  /// No description provided for @plasmaPurposeJoinSwap.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to join swap'**
  String get plasmaPurposeJoinSwap;

  /// No description provided for @plasmaPurposeCompleteSwap.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to complete swap'**
  String get plasmaPurposeCompleteSwap;

  /// No description provided for @plasmaPurposeReclaimSwapFunds.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated in order to reclaim swap funds'**
  String get plasmaPurposeReclaimSwapFunds;

  /// No description provided for @plasmaNotificationDetails.
  ///
  /// In en, this message translates to:
  /// **'Plasma will be generated for this account-block'**
  String get plasmaNotificationDetails;

  /// The details of an error notification: what failed, then the error itself. title is the notification's own title, already in the wallet's language; error is the error's text as it was raised.
  ///
  /// In en, this message translates to:
  /// **'{title}: {error}'**
  String notificationErrorWithDetails(String title, Object error);

  /// No description provided for @notificationEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty title'**
  String get notificationEmptyTitle;

  /// No description provided for @notificationNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get notificationNoDetails;

  /// Title of the Settings panel about the node software (libznn) that runs inside the wallet: which build is loaded, and installing another one.
  ///
  /// In en, this message translates to:
  /// **'Embedded node'**
  String get nodeUpdatePanelTitle;

  /// Shown in place of the Embedded node panel when the folder holding the installed node library cannot be read.
  ///
  /// In en, this message translates to:
  /// **'The node folder could not be read.'**
  String get nodeUpdateStatusError;

  /// Label over the node library the running wallet has loaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded'**
  String get nodeUpdateLoadedLabel;

  /// Label over the node library the wallet will load when it next starts, shown while the embedded node is not running.
  ///
  /// In en, this message translates to:
  /// **'Used at the next start'**
  String get nodeUpdateNextStartLabel;

  /// Name of the node library that ships with the wallet, as opposed to one installed later.
  ///
  /// In en, this message translates to:
  /// **'Bundled'**
  String get nodeUpdateBundledLabel;

  /// Shown beside a node library's file name where a repository name would be: it was installed from a file on this computer, not downloaded.
  ///
  /// In en, this message translates to:
  /// **'From a file'**
  String get nodeUpdateFromFileLabel;

  /// Shown where the loaded node library would be named, when neither a bundled nor an installed one exists.
  ///
  /// In en, this message translates to:
  /// **'No node library found'**
  String get nodeUpdateMissingLabel;

  /// Label before a file's SHA-256 checksum, a 64-digit hexadecimal number. The name of the algorithm; not translated.
  ///
  /// In en, this message translates to:
  /// **'SHA-256'**
  String get nodeUpdateHashLabel;

  /// Tooltip of the icon button that copies a node library's full SHA-256 checksum.
  ///
  /// In en, this message translates to:
  /// **'Copy SHA-256'**
  String get nodeUpdateHashCopyTooltip;

  /// Line telling the person that a node library is waiting and only takes effect when the wallet starts again. name is its release tag or file name, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Close and reopen Syrius to use {name}.'**
  String nodeUpdateReopenStagedLabel(String name);

  /// Line telling the person that the wallet goes back to the node library it shipped with, and only when it starts again.
  ///
  /// In en, this message translates to:
  /// **'Close and reopen Syrius to use the bundled node.'**
  String get nodeUpdateReopenBundledLabel;

  /// Warning line: the node library the person installed could not be loaded at start, so the wallet fell back to the one it shipped with.
  ///
  /// In en, this message translates to:
  /// **'The installed node failed to load. The bundled one is in use.'**
  String get nodeUpdateBadError;

  /// Warning line: at start, the node library waiting to be installed had changed on disk since it was confirmed, so the wallet deleted it.
  ///
  /// In en, this message translates to:
  /// **'The staged node did not match its checksum and was removed.'**
  String get nodeUpdateStagedRejectedError;

  /// Label of the row showing the newest node release published in the source repository, once the person has pressed Check.
  ///
  /// In en, this message translates to:
  /// **'Latest release'**
  String get nodeUpdateReleaseLabel;

  /// Button that asks GitHub for the newest node release. The wallet never asks by itself.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get nodeUpdateCheckLabel;

  /// Shown where the latest release would be, before the person has pressed Check.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get nodeUpdateNotCheckedHint;

  /// Answer to Check when the source repository exists and has published nothing.
  ///
  /// In en, this message translates to:
  /// **'This repository has no releases.'**
  String get nodeUpdateNoReleaseLabel;

  /// Beside the latest release: the wallet already uses this release.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get nodeUpdateCompareUpToDateLabel;

  /// Beside the latest release: it is not the one the wallet uses.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get nodeUpdateCompareAvailableLabel;

  /// Beside the latest release: it has been installed and takes effect when the wallet starts again.
  ///
  /// In en, this message translates to:
  /// **'Staged for the next start'**
  String get nodeUpdateCompareStagedLabel;

  /// Beside the latest release: the wallet cannot tell whether it is the one in use, because the node in use carries no release tag.
  ///
  /// In en, this message translates to:
  /// **'Not compared'**
  String get nodeUpdateCompareUnknownLabel;

  /// Label of the row with the Download and From file buttons, and the button in the confirmation dialog that installs the node library shown.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get nodeUpdateInstallLabel;

  /// Line under Install: an installed node library is only used once the wallet has been closed and opened again.
  ///
  /// In en, this message translates to:
  /// **'Takes effect at the next start'**
  String get nodeUpdateInstallHint;

  /// Button that downloads the latest release's node library. Nothing is installed until a confirmation that follows.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get nodeUpdateDownloadLabel;

  /// Button that opens a file dialog to pick a node library on this computer, instead of downloading one.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get nodeUpdateFileLabel;

  /// Under the download's progress bar: megabytes received and megabytes expected, each with one decimal.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total} MB'**
  String nodeUpdateProgressLabel(String received, String total);

  /// Shown while a picked file is copied and its checksum computed. name is the file's name.
  ///
  /// In en, this message translates to:
  /// **'Reading {name}'**
  String nodeUpdateReadingFileLabel(String name);

  /// Shown for the moment a confirmed node library is being put in place for the next start.
  ///
  /// In en, this message translates to:
  /// **'Installing'**
  String get nodeUpdateStagingLabel;

  /// Title of the dialog that lists exactly which node library is about to be installed and asks for confirmation.
  ///
  /// In en, this message translates to:
  /// **'Install this node?'**
  String get nodeUpdateInstallTitle;

  /// Label before the GitHub repository (owner/name) a node library was downloaded from.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get nodeUpdateRepositoryLabel;

  /// Label before a release's tag, such as v0.0.8.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get nodeUpdateTagLabel;

  /// Label before the name of the file downloaded from a GitHub release.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get nodeUpdateAssetLabel;

  /// Label before the name of a file picked on this computer.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get nodeUpdateFileNameLabel;

  /// Stands where a repository or a release tag would be, for a node library that came from a file and has neither.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get nodeUpdateNoneLabel;

  /// Label before the result of comparing a download with the checksum file published in the same release, or before the checksum that file names.
  ///
  /// In en, this message translates to:
  /// **'Checksum file'**
  String get nodeUpdateChecksumFileLabel;

  /// Label before the result of comparing a download with the checksum GitHub itself computes for a release file, or before that checksum.
  ///
  /// In en, this message translates to:
  /// **'GitHub digest'**
  String get nodeUpdateDigestLabel;

  /// Result: the download's checksum equals the one in the release's checksum file.
  ///
  /// In en, this message translates to:
  /// **'Matches the release\'s checksum file'**
  String get nodeUpdateChecksumVerifiedLabel;

  /// Result: the release has a checksum file, and it does not mention this download, so nothing was compared.
  ///
  /// In en, this message translates to:
  /// **'Not listed in the release\'s checksum file'**
  String get nodeUpdateChecksumNotListedLabel;

  /// Result: the release publishes no checksum file, so nothing was compared.
  ///
  /// In en, this message translates to:
  /// **'The release has no checksum file'**
  String get nodeUpdateChecksumAbsentLabel;

  /// Result: the download's checksum equals the one GitHub computed for the file.
  ///
  /// In en, this message translates to:
  /// **'Matches GitHub\'s digest'**
  String get nodeUpdateDigestVerifiedLabel;

  /// Result: GitHub has no checksum of its own for this file, so nothing was compared.
  ///
  /// In en, this message translates to:
  /// **'GitHub gives no digest for this release'**
  String get nodeUpdateDigestAbsentLabel;

  /// Result shown for both checks when the node library was picked from disk: there is no release to compare it with.
  ///
  /// In en, this message translates to:
  /// **'Not checked: a file from this computer'**
  String get nodeUpdateFileUncheckedLabel;

  /// Plain statement at the foot of the install confirmation: what installing does and when.
  ///
  /// In en, this message translates to:
  /// **'This replaces the node that runs inside the wallet. It takes effect at the next start.'**
  String get nodeUpdateInstallConfirm;

  /// Title of the warning dialog shown when a release publishes no checksum at all for its node library.
  ///
  /// In en, this message translates to:
  /// **'Download without verification?'**
  String get nodeUpdateUnverifiedTitle;

  /// Body of the warning dialog: the download could be damaged or replaced and the wallet could not tell. tag is the release's tag, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Nothing verifies this file. Release {tag} publishes no checksum for it.'**
  String nodeUpdateUnverifiedConfirm(String tag);

  /// Button of the warning dialog that goes ahead with a download nothing can verify.
  ///
  /// In en, this message translates to:
  /// **'Download anyway'**
  String get nodeUpdateUnverifiedDownloadLabel;

  /// Label of the row with the buttons that go back to the bundled node library or to the one installed before.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get nodeUpdateRollbackLabel;

  /// Line under Roll back: either choice is only used once the wallet has been closed and opened again.
  ///
  /// In en, this message translates to:
  /// **'Applies at the next start'**
  String get nodeUpdateRollbackHint;

  /// Button that removes any installed node library, so the wallet uses the one it shipped with. Also the confirming button of its dialog.
  ///
  /// In en, this message translates to:
  /// **'Use bundled node'**
  String get nodeUpdateUseBundledLabel;

  /// Button that puts back the node library that was installed before the current one. Also the confirming button of its dialog.
  ///
  /// In en, this message translates to:
  /// **'Use previous'**
  String get nodeUpdateUsePreviousLabel;

  /// Title of the dialog confirming a return to the node library the wallet shipped with.
  ///
  /// In en, this message translates to:
  /// **'Use the bundled node?'**
  String get nodeUpdateUseBundledTitle;

  /// Body of that dialog, under a list of the installed and the staged node library.
  ///
  /// In en, this message translates to:
  /// **'The nodes listed here are removed. The bundled node runs from the next start.'**
  String get nodeUpdateUseBundledConfirm;

  /// Label before the node library that is installed in place of the bundled one.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get nodeUpdateInstalledLabel;

  /// Label before the node library that is waiting to be used at the next start.
  ///
  /// In en, this message translates to:
  /// **'Staged'**
  String get nodeUpdateStagedLabel;

  /// Title of the dialog confirming a return to the node library installed before the current one.
  ///
  /// In en, this message translates to:
  /// **'Use the previous node?'**
  String get nodeUpdateUsePreviousTitle;

  /// Body of that dialog, under the details of the earlier node library.
  ///
  /// In en, this message translates to:
  /// **'This node replaces the installed one at the next start. Anything staged is removed.'**
  String get nodeUpdateUsePreviousConfirm;

  /// Label of the setting naming the GitHub repository node releases are read from.
  ///
  /// In en, this message translates to:
  /// **'Source repository'**
  String get nodeUpdateSourceLabel;

  /// Line under Source repository saying what to type. owner/name is the literal form, such as zenon-network/go-zenon.
  ///
  /// In en, this message translates to:
  /// **'A GitHub repository, as owner/name'**
  String get nodeUpdateSourceHint;

  /// Button that keeps the typed source repository; it is used by the next Check.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get nodeUpdateSourceSaveLabel;

  /// Under the source repository field when what is typed is not of the form owner/name.
  ///
  /// In en, this message translates to:
  /// **'Enter a repository as owner/name.'**
  String get nodeUpdateSourceError;

  /// Warning line under the source repository field when it names anything but the Zenon project's own repository.
  ///
  /// In en, this message translates to:
  /// **'Libraries from another repository are not the Zenon project\'s.'**
  String get nodeUpdateSourceForeignHint;

  /// GitHub refused the request because too many were made from this address. time is the local time of day from which it answers again.
  ///
  /// In en, this message translates to:
  /// **'GitHub is limiting requests from this computer. Try again after {time}.'**
  String nodeUpdateRateLimitedUntilError(DateTime time);

  /// GitHub refused the request because too many were made from this address, and did not say until when.
  ///
  /// In en, this message translates to:
  /// **'GitHub is limiting requests from this computer. Try again later.'**
  String get nodeUpdateRateLimitedError;

  /// The request to GitHub could not be made or broke off: no network, a timeout, a failed secure connection.
  ///
  /// In en, this message translates to:
  /// **'No connection to GitHub.'**
  String get nodeUpdateNetworkError;

  /// GitHub answered 404: the source repository does not exist, or a release file is gone.
  ///
  /// In en, this message translates to:
  /// **'GitHub has no such repository or file.'**
  String get nodeUpdateNotFoundError;

  /// GitHub answered with an HTTP status that is not a success. status is that number.
  ///
  /// In en, this message translates to:
  /// **'GitHub answered with error {status}.'**
  String nodeUpdateHttpError(int status);

  /// GitHub answered, but not with a list of releases the wallet understands.
  ///
  /// In en, this message translates to:
  /// **'GitHub\'s answer could not be read.'**
  String get nodeUpdateMalformedError;

  /// A download address or a redirect pointed at a host that is not GitHub's, so the wallet did not follow it.
  ///
  /// In en, this message translates to:
  /// **'The download led outside GitHub and was refused.'**
  String get nodeUpdateForbiddenUrlError;

  /// The download, the picked file or the unpacked library is larger than the wallet accepts. megabytes is that limit.
  ///
  /// In en, this message translates to:
  /// **'The file is over {megabytes} MB.'**
  String nodeUpdateTooLargeError(int megabytes);

  /// The download ended with fewer or more bytes than the release lists.
  ///
  /// In en, this message translates to:
  /// **'The download was incomplete.'**
  String get nodeUpdateSizeMismatchError;

  /// The downloaded file's checksum differs from the one the release publishes. The two checksums follow on their own lines.
  ///
  /// In en, this message translates to:
  /// **'The download does not match the published checksum and was deleted.'**
  String get nodeUpdateDigestMismatchError;

  /// Label before the checksum the release publishes, in a checksum mismatch.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get nodeUpdateExpectedLabel;

  /// Label before the checksum of the file that was actually downloaded, in a checksum mismatch.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get nodeUpdateActualLabel;

  /// The release names two different checksums for the same file. The two checksums follow on their own lines.
  ///
  /// In en, this message translates to:
  /// **'The release\'s checksum file and GitHub\'s digest disagree. Nothing was downloaded.'**
  String get nodeUpdateChecksumConflictError;

  /// The release has a checksum file, and it is not in the usual format.
  ///
  /// In en, this message translates to:
  /// **'The release\'s checksum file could not be read.'**
  String get nodeUpdateMalformedChecksumsError;

  /// Nothing was downloaded because there is nothing to verify the file against.
  ///
  /// In en, this message translates to:
  /// **'The release publishes no checksum for this file.'**
  String get nodeUpdateUnverifiedError;

  /// The picked file, or the downloaded archive, does not hold the node library for this computer. libznn is the library's name; not translated.
  ///
  /// In en, this message translates to:
  /// **'This is not a libznn library.'**
  String get nodeUpdateNotLibraryError;

  /// The person stopped the download.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get nodeUpdateCancelledError;

  /// The release exists and has no node library built for this operating system and processor. tag is the release's tag, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Release {tag} has no library for this platform.'**
  String nodeUpdateNoAssetError(String tag);

  /// The disk refused: no space, no permission, or a file that went away.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read or written.'**
  String get nodeUpdateFileError;

  /// Under an amount field whose last keystroke or paste was refused and left the amount as it was: a comma, a second point, a letter. An amount is Latin digits with a point before the decimals in every language, so the point is not translated into a comma.
  ///
  /// In en, this message translates to:
  /// **'Use a point for decimals'**
  String get validatorAmountUsePoint;

  /// Title of the notification raised half a minute after connecting to a node that is still more than 20 momentums behind the network. The loading circle is the sync indicator in the wallet's top bar.
  ///
  /// In en, this message translates to:
  /// **'The node is still syncing with the network. Please wait until the loading circle turns green before sending any transactions'**
  String get nodeSyncingNotificationTitle;

  /// Details of the node-still-syncing notification.
  ///
  /// In en, this message translates to:
  /// **'The information displayed in the wallet does not reflect the most recent network state. Operations should not be performed, as they will likely become invalid by the time the node is fully synced'**
  String get nodeSyncingNotificationDetails;

  /// Title of the notification raised each time the wallet has published a transaction. An account-block is one transaction in an address's own chain.
  ///
  /// In en, this message translates to:
  /// **'Account-block published'**
  String get accountBlockPublishedNotificationTitle;

  /// Details of the account-block published notification. blockType is the protocol's own name for the kind of block, in English.
  ///
  /// In en, this message translates to:
  /// **'Account-block type: {blockType}'**
  String accountBlockPublishedNotificationDetails(String blockType);

  /// Title of the notification asking the person to check and approve, on their Ledger device, a transaction that sends.
  ///
  /// In en, this message translates to:
  /// **'Sending transaction, please review the transaction on your hardware device'**
  String get accountBlockReviewSendNotificationTitle;

  /// Title of the notification asking the person to check and approve, on their Ledger device, a transaction that receives.
  ///
  /// In en, this message translates to:
  /// **'Receiving transaction, please review the transaction on your hardware device'**
  String get accountBlockReviewReceiveNotificationTitle;

  /// Details of both review-on-your-hardware-device notifications. blockType is the protocol's own name for the kind of block, in English.
  ///
  /// In en, this message translates to:
  /// **'Review account-block type: {blockType}'**
  String accountBlockReviewNotificationDetails(String blockType);

  /// Title of the notification asking the person to confirm, on their Ledger device, a new address being added to the wallet.
  ///
  /// In en, this message translates to:
  /// **'Adding address, please confirm the address on your hardware device'**
  String get addressAddConfirmNotificationTitle;

  /// Details of the confirm-address-on-your-hardware-device notification. index is the address's position in the wallet, counted from 0, as the device shows it.
  ///
  /// In en, this message translates to:
  /// **'Confirm address for account index: {index}'**
  String addressAddConfirmNotificationDetails(int index);

  /// The name a new address of the wallet is given until the person renames it. number is its position in the wallet, counted from 1. Saved with the address when it is made, so it stays in the language of that moment.
  ///
  /// In en, this message translates to:
  /// **'Address {number}'**
  String addressDefaultLabel(int number);

  /// Title of the error notification raised when adding an address to the wallet failed.
  ///
  /// In en, this message translates to:
  /// **'Error while generating new address'**
  String get addressGenerateFailedNotificationTitle;

  /// Title of the notification raised when the wallet is being closed while the node that runs inside it is still running.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Embedded Node to stop'**
  String get embeddedNodeStoppingNotificationTitle;

  /// Details of the waiting-for-Embedded-Node-to-stop notification.
  ///
  /// In en, this message translates to:
  /// **'The app will close after the Embedded Node has been stopped'**
  String get embeddedNodeStoppingNotificationDetails;

  /// The error named in the details of a warning notification: this computer's clock is more than five minutes away from the network's time.
  ///
  /// In en, this message translates to:
  /// **'Local time discrepancy detected.'**
  String get nodeLocalTimeDiscrepancyError;

  /// Title of the error notification raised when a link could not be opened in the browser. url is the link, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Error while trying to open {url}'**
  String openUrlFailedNotificationTitle(String url);

  /// Details of the link-could-not-be-opened notification. url is the link, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while trying to open {url}'**
  String openUrlFailedNotificationDetails(String url);

  /// Short message shown for three seconds at the bottom of the window after something was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// The error named in the details of the notification raised when a paste button found nothing to paste.
  ///
  /// In en, this message translates to:
  /// **'The clipboard data could not be obtained'**
  String get clipboardPasteError;

  /// Title of the error notification raised when a paste button could not read the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while getting the clipboard data'**
  String get clipboardPasteFailedNotificationTitle;

  /// Shown when the wallet password typed is wrong: as the title of an error notification on the lock screen, and under a password field.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get walletPasswordIncorrectError;

  /// Title of the error notification raised when unlocking the wallet failed for a reason other than a wrong password.
  ///
  /// In en, this message translates to:
  /// **'Unlock failed'**
  String get walletUnlockFailedNotificationTitle;

  /// Error raised when a wallet file says it is of a kind this wallet cannot open. walletType is the kind as the file names it, shown as it is.
  ///
  /// In en, this message translates to:
  /// **'Wallet type ({walletType}) is not supported'**
  String walletFileTypeNotSupportedError(String walletType);

  /// Error raised when the wallet file is not where the wallet expects it. path is the file's full path on this computer.
  ///
  /// In en, this message translates to:
  /// **'Given wallet path does not exist ({path})'**
  String walletFilePathNotFoundError(String path);

  /// Error shown when the Ledger device a hardware wallet was set up with is not connected or is locked.
  ///
  /// In en, this message translates to:
  /// **'Cannot find the hardware device, please connect/unlock the device on which the wallet is initialized'**
  String get walletFileLedgerNotFoundError;

  /// Error raised when a file the wallet was about to delete is not there. path is the file's full path on this computer.
  ///
  /// In en, this message translates to:
  /// **'There is no file at the following path: {path}'**
  String fileDeleteNoFileError(String path);

  /// Error raised when a folder the wallet was about to delete is not there. path is the folder's full path on this computer.
  ///
  /// In en, this message translates to:
  /// **'There is no directory at the following path: {path}'**
  String fileDeleteNoDirectoryError(String path);

  /// Under the message field of the Sign and Verify panels when the message is exactly 32 bytes long: a transaction's hash has that size, so the wallet does not sign it as a message. Pad it means make it longer or shorter.
  ///
  /// In en, this message translates to:
  /// **'A 32 byte message is refused. Pad it'**
  String get signMessage32BytesError;

  /// Tooltip of the Plasma icon beside an address that has enough Plasma for any transaction.
  ///
  /// In en, this message translates to:
  /// **'High Plasma'**
  String get plasmaLevelHighTooltip;

  /// Tooltip of the Plasma icon beside an address that has a middling amount of Plasma.
  ///
  /// In en, this message translates to:
  /// **'Average Plasma'**
  String get plasmaLevelAverageTooltip;

  /// Tooltip of the Plasma icon beside an address that has only a little Plasma.
  ///
  /// In en, this message translates to:
  /// **'Low Plasma'**
  String get plasmaLevelLowTooltip;

  /// Tooltip of the Plasma icon beside an address that has too little Plasma to send a transaction without proof of work.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Plasma'**
  String get plasmaLevelInsufficientTooltip;

  /// Title of the error notification raised when the wallet could not receive a pending transaction by itself.
  ///
  /// In en, this message translates to:
  /// **'Receive transaction failed'**
  String get autoReceiveFailedNotificationTitle;

  /// Details of the receive-transaction-failed notification. error is the error's text as it was raised.
  ///
  /// In en, this message translates to:
  /// **'Failed to receive the transaction: {error}'**
  String autoReceiveFailedNotificationDetails(String error);

  /// Title of the notification raised when the wallet has received a transaction. address is the receiving address's label, or the address itself when it has none.
  ///
  /// In en, this message translates to:
  /// **'Transaction received on {address}'**
  String transactionReceivedNotificationTitle(String address);

  /// Details of the transaction-received notification. hash is the transaction's hash, 64 hexadecimal digits.
  ///
  /// In en, this message translates to:
  /// **'Transaction hash: {hash}'**
  String transactionReceivedNotificationDetails(String hash);

  /// The error named in the details of the failed-to-complete-swap notification when the wallet has no record, or no secret, for the P2P swap it was about to complete.
  ///
  /// In en, this message translates to:
  /// **'Invalid swap'**
  String get autoUnlockInvalidSwapError;

  /// The error named in the details of the failed-to-complete-swap notification when the address a P2P swap pays out to is not among the wallet's addresses.
  ///
  /// In en, this message translates to:
  /// **'Swap address not in default addresses. Please add the address in the addresses list.'**
  String get autoUnlockAddressNotInWalletError;

  /// Title of the error notification raised when the wallet could not complete a P2P swap by itself.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete swap'**
  String get autoUnlockFailedNotificationTitle;

  /// Details of the failed-to-complete-swap notification. error is the error's text as it was raised.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete the swap: {error}'**
  String autoUnlockFailedNotificationDetails(String error);

  /// Error shown when the person completes a P2P swap whose deposit runs out in under ten minutes.
  ///
  /// In en, this message translates to:
  /// **'The swap will expire too soon for a safe swap.'**
  String get completeSwapExpiresTooSoonError;

  /// Error shown when the secret that unlocks a P2P swap is longer than the other side's deposit accepts.
  ///
  /// In en, this message translates to:
  /// **'The swap secret size exceeds the maximum allowed size.'**
  String get completeSwapSecretTooLargeError;

  /// Shown once a Pillar has been registered. controller is the name of the program that runs a Pillar node, znn-controller; it is not translated, and it is drawn as a link wherever it stands in the sentence.
  ///
  /// In en, this message translates to:
  /// **'Pillar registered. Use {controller} to check its status.'**
  String createPillarSuccessMessage(String controller);

  /// Label of the ZNN amount that registering a Pillar locks, in the Pillar stepper. The amount follows on the same line or under it.
  ///
  /// In en, this message translates to:
  /// **'Collateral'**
  String get createPillarCollateralLabel;

  /// Label of the QSR amount burned for a Pillar slot, in the review before a Pillar is registered. The amount follows on the same line.
  ///
  /// In en, this message translates to:
  /// **'Slot fee'**
  String get createPillarSlotFeeLabel;

  /// Label in the review before a Pillar is registered or updated: the percentage of its momentum rewards the Pillar gives to its delegators. The percentage follows on the same line.
  ///
  /// In en, this message translates to:
  /// **'Momentum share'**
  String get createPillarMomentumShareLabel;

  /// Label in the review before a Pillar is registered or updated: the percentage of its delegation rewards the Pillar gives to its delegators. The percentage follows on the same line.
  ///
  /// In en, this message translates to:
  /// **'Delegation share'**
  String get createPillarDelegationShareLabel;

  /// Title of the step of the update-Pillar stepper that sets the two percentages of rewards given to delegators.
  ///
  /// In en, this message translates to:
  /// **'Reward sharing'**
  String get updatePillarRewardsTitle;

  /// Under an amount field after a key or a paste that was refused and left the amount as it was, when what was refused was not a comma: a letter, a space, a sign, a second point. The point is the decimal mark in every language and is not translated into a comma.
  ///
  /// In en, this message translates to:
  /// **'Digits and a point only'**
  String get validatorAmountDigitsOnly;

  /// Under the amount field of the Fuse card after a key or a paste that was refused and left the amount as it was: a point, a comma, a letter. QSR is fused in whole coins. QSR is a coin's symbol and is not translated.
  ///
  /// In en, this message translates to:
  /// **'Whole QSR only'**
  String get validatorAmountWholeNumber;

  /// Tooltip of the icon button that copies a value (an address, a hash) to the clipboard. A verb.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Tooltip of the x button in the corner of a modal, which closes it. A verb.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button on the notification banner that removes the banner. A verb.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Button on the notification banner that opens the Notifications page at this notification.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get commonSeeMore;

  /// Button under the last row of a table that loads its next rows.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get commonShowMore;

  /// Button under an error line in a card: asks again for the data that could not be had. A verb.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Button beside a field being edited in Settings (an address label, a node address): keeps the change. A verb.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// The confirming button of a warning dialog when the caller names no action of its own.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// The confirming button of a dialog that asks a question. Capitalised, as a button.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// The declining button of a dialog that asks a question. Capitalised, as a button.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// What a card or an error notification says when an action failed and nothing more specific is known.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// Shown in a card in place of its data when the wallet has no open connection to a node.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the network'**
  String get commonNotConnectedError;

  /// Small label at the left of a line in a form; the balance that can be spent stands at the right of the same line. Upper case in English, as the other small labels are; use the plain form in a script with no capitals.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE'**
  String get cardAvailableLabel;

  /// Under an amount field in a stepper: the balance of the chosen token that can be spent. symbol is the token's ticker and is not translated.
  ///
  /// In en, this message translates to:
  /// **'{amount} {symbol} available'**
  String availableBalanceLabel(String amount, String symbol);

  /// Error shown when a transaction cannot be made because the node the wallet is connected to has not caught up with the network yet.
  ///
  /// In en, this message translates to:
  /// **'Node is not synced'**
  String get nodeNotSyncedError;

  /// Shown in place of the chart of a rewards card (Pillar, Sentinel, staking) when the address earned nothing in the last seven days.
  ///
  /// In en, this message translates to:
  /// **'No rewards in the last week'**
  String get rewardsHistoryLastWeekEmpty;

  /// Tooltip of the info button in a card's header, which turns the card over to its description.
  ///
  /// In en, this message translates to:
  /// **'About this card'**
  String get cardScaffoldAboutTooltip;

  /// On the back of a card: heading of the row that unfolds the text saying what the card shows.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get cardScaffoldDescriptionLabel;

  /// On the back of a card: label of the switch that hides the card's content until the wallet password is entered.
  ///
  /// In en, this message translates to:
  /// **'Discreet mode'**
  String get cardScaffoldDiscreetModeLabel;

  /// Hint in the empty field of the Go to palette, where the name of a page is typed to open it.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get goToPaletteHint;

  /// Shown under the field of the Go to palette when no page's name contains what was typed.
  ///
  /// In en, this message translates to:
  /// **'No page by that name'**
  String get goToPaletteEmpty;

  /// Tooltip on the Asset cell of a transaction row when the transaction's token is not known. A token standard is a token's identifier on the network.
  ///
  /// In en, this message translates to:
  /// **'Unknown token standard'**
  String get assetCellUnknownStandardTooltip;

  /// Shown in place of the QR code of the Receive card when the code could not be drawn.
  ///
  /// In en, this message translates to:
  /// **'Failed to create QR code'**
  String get receiveQrFailedError;

  /// Text inside the dashed zone that takes a file, before one is given: a file can be dragged onto it, and a click opens the system's file dialog.
  ///
  /// In en, this message translates to:
  /// **'Drop a file here, or click to browse'**
  String get selectFileHint;

  /// Text inside the file zone after a file was refused, when the screen has no more specific reason to give.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be used'**
  String get selectFileInvalidError;

  /// Name of the file type in the filter of the system's file dialog, opened from the file zone. Lower case; the system may put the extension after it.
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get selectFileTypeLabel;

  /// Tooltip of the pencil button beside an address in Settings, which lets its label be changed. A verb.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get settingsAddressRenameTooltip;

  /// Hint in the field where an address's label, the name the person gives it, is typed in Settings.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get settingsAddressLabelHint;

  /// Title and details of the error notification raised when an address label is saved empty.
  ///
  /// In en, this message translates to:
  /// **'Label can\'t be empty'**
  String get settingsAddressLabelEmptyError;

  /// Title of the error notification raised when an address label is saved longer than the limit. max is the limit, in characters.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, one{The label has more than {max} character} other{The label has more than {max} characters}}'**
  String settingsAddressLabelTooLongNotificationTitle(int max);

  /// Details of the error notification raised when an address label is saved longer than the limit. label is what was typed, length its number of characters, max the limit in characters.
  ///
  /// In en, this message translates to:
  /// **'{length, plural, one{The label {label} is {length} character long, which is more than the {max} limit.} other{The label {label} is {length} characters long, which is more than the {max} limit.}}'**
  String settingsAddressLabelTooLongNotificationDetails(
    String label,
    int length,
    int max,
  );

  /// Title of the error notification raised when an address is given a label another address already has.
  ///
  /// In en, this message translates to:
  /// **'Label already exists'**
  String get settingsAddressLabelExistsNotificationTitle;

  /// Details of the error notification raised when an address is given a label another address already has. label is what was typed.
  ///
  /// In en, this message translates to:
  /// **'Label {label} already exists in the database'**
  String settingsAddressLabelExistsNotificationDetails(String label);

  /// Title of the error notification raised when saving an address's new label failed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while changing the address label'**
  String get settingsAddressRenameFailedNotificationTitle;

  /// Tooltip of the icon beside the node in use in Settings, when the wallet and the node are on the same chain. Two lines. client is the chain identifier the wallet is set to, node the one the node reports.
  ///
  /// In en, this message translates to:
  /// **'Client chain identifier: {client}\nNode chain identifier: {node}'**
  String settingsNodeChainIdTooltip(int client, int node);

  /// Tooltip of the red icon beside the node in use in Settings, when the wallet and the node are on different chains. Three lines. client is the chain identifier the wallet is set to, node the one the node reports.
  ///
  /// In en, this message translates to:
  /// **'Chain identifier mismatch\nClient chain identifier: {client}\nNode chain identifier: {node}'**
  String settingsNodeChainIdMismatchTooltip(int client, int node);

  /// Tooltip of the closed-lock icon beside a node in Settings whose address begins with wss://.
  ///
  /// In en, this message translates to:
  /// **'Encrypted connection'**
  String get settingsNodeEncryptedTooltip;

  /// Tooltip of the open-lock icon beside a node in Settings whose address begins with ws://.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection'**
  String get settingsNodeUnencryptedTooltip;

  /// Tooltip of the shield icon beside the Embedded Node in the list of nodes in Settings: the node that runs inside the wallet.
  ///
  /// In en, this message translates to:
  /// **'Integrated Full Node: enhanced security and privacy'**
  String get settingsNodeEmbeddedTooltip;

  /// Tooltip of the clock icon beside the Embedded Node in the list of nodes in Settings. Two lines, with no full stop.
  ///
  /// In en, this message translates to:
  /// **'The Embedded Node validates all network transactions\nIt may take several hours to fully sync with the network'**
  String get settingsNodeEmbeddedSyncTooltip;

  /// Tooltip of the link icon beside a node in Settings that is run by a member of the community and ships in the wallet's list.
  ///
  /// In en, this message translates to:
  /// **'Community Node'**
  String get settingsNodeCommunityTooltip;

  /// Tooltip of the pencil button beside a node the person added in Settings, which lets its address be changed.
  ///
  /// In en, this message translates to:
  /// **'Edit node'**
  String get settingsNodeEditTooltip;

  /// Tooltip of the bin button beside a node the person added in Settings, and the title of the dialog that asks before removing it.
  ///
  /// In en, this message translates to:
  /// **'Delete node'**
  String get settingsNodeDeleteLabel;

  /// Question of the dialog that asks before a node is removed from the list in Settings. node is the node's address.
  ///
  /// In en, this message translates to:
  /// **'Delete {node} from the list of nodes? This can\'t be undone.'**
  String settingsNodeDeleteConfirm(String node);

  /// Hint in the field where a node's address is edited in Settings, as in ws://127.0.0.1:35998.
  ///
  /// In en, this message translates to:
  /// **'Node address with port'**
  String get settingsNodeAddressHint;

  /// Under the node address field in Settings when it is saved empty.
  ///
  /// In en, this message translates to:
  /// **'Node address can\'t be empty'**
  String get settingsNodeEmptyError;

  /// Under the node address field in Settings when the address is longer than the limit. max is the limit, in characters.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, one{The node has more than {max} character} other{The node has more than {max} characters}}'**
  String settingsNodeTooLongError(int max);

  /// Under the node address field in Settings when the address is already in the list of nodes.
  ///
  /// In en, this message translates to:
  /// **'Node already exists'**
  String get settingsNodeExistsError;

  /// Title of the error notification raised when removing a node from the list in Settings failed. node is the node's address.
  ///
  /// In en, this message translates to:
  /// **'Error during deleting node {node} from the database'**
  String settingsNodeDeleteFailedNotificationTitle(String node);

  /// Each half of the switch between a 24-word and a 12-word seed phrase, when a wallet is made or imported. count is 24 or 12.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} word} other{{count} words}}'**
  String seedChoiceWordsLabel(int count);

  /// A length of time in whole days alone, in a short unit: 12 d. Used where there is room for one unit only.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String durationDays(int days);

  /// A length of time under a day in whole hours alone, in a short unit: 5 h.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// A length of time under an hour in whole minutes alone, in a short unit: 40 min.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// A countdown of a day or more: whole days, then the rest as a clock of hours, minutes and seconds, 2 d 03:04:05. Only the unit for days is translated; clock is digits and colons.
  ///
  /// In en, this message translates to:
  /// **'{days} d {clock}'**
  String durationDaysClock(int days, String clock);

  /// On the line under an Accelerator-Z project that is being voted on: how long until voting closes. duration is a length of time in one short unit, already translated: 12 d, 5 h, 40 min, 30 s.
  ///
  /// In en, this message translates to:
  /// **'Closes in {duration}'**
  String acceleratorClosesIn(String duration);

  /// Tooltip of a Cancel button that cannot be pressed yet, on a Plasma fusion still locked. duration is a length of time already translated: 9 h 52 m.
  ///
  /// In en, this message translates to:
  /// **'Unlocks in {duration}'**
  String cancelUnlocksIn(String duration);

  /// Warning in a P2P swap's dialog when little time is left to complete it. duration is a length of time already translated: 9 m 58 s.
  ///
  /// In en, this message translates to:
  /// **'The swap expires in {duration}'**
  String p2pSwapExpiresIn(String duration);

  /// The length a stake was made for, in whole months, in the stakes table: 1 month, 12 months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String stakeDurationMonths(int count);

  /// Shown once a Sentinel has been registered. controller is the name of the program that runs a Sentinel node, znn-controller; it is not translated, and it is drawn as a link wherever it stands in the sentence.
  ///
  /// In en, this message translates to:
  /// **'Sentinel registered. Use {controller} to check its status.'**
  String createSentinelSuccessMessage(String controller);

  /// Label, a noun, of the QSR amount deposited for a Sentinel, in the review before a Sentinel is registered. The deposit is locked, not burned: it comes back when the Sentinel is disassembled. The amount follows on the same line.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get createSentinelDepositLabel;

  /// Tooltip, a verb, of the button at the top of the navigation rail while the rail is collapsed to icons. Pressing it opens the rail, so each page's name shows beside its icon.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get railExpand;

  /// Tooltip, a verb, of the button at the top of the navigation rail while the rail is open. Pressing it narrows the rail to icons.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get railCollapse;

  /// Label in the status strip at the bottom of the window while the wallet computes proof of work (plasma) for a block. An animated bolt stands before it and the seconds elapsed follow it, so keep it to two or three words.
  ///
  /// In en, this message translates to:
  /// **'Generating plasma'**
  String get stripGeneratingPlasma;

  /// Tooltip of the plasma mark in the status strip while the wallet is not generating plasma.
  ///
  /// In en, this message translates to:
  /// **'Plasma idle'**
  String get stripPlasmaIdle;

  /// Seconds elapsed since plasma generation started, counting up in the status strip right after the label 'Generating plasma'. The unit is abbreviated.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String stripSeconds(int seconds);

  /// How long plasma generation has lately taken on this computer, in the status strip after the elapsed seconds and a middle dot. Lower case: it continues the line. The unit is abbreviated.
  ///
  /// In en, this message translates to:
  /// **'usually about {seconds} s'**
  String stripPlasmaTypical(int seconds);

  /// Status strip, while a transaction the wallet published waits to be included in a momentum. amount is the amount with its token symbol; it is drawn left to right wherever it stands in the sentence.
  ///
  /// In en, this message translates to:
  /// **'Sending {amount}'**
  String stripSending(String amount);

  /// Status strip, while several transactions the wallet published wait to be included in a momentum. It stands in place of the line that names one amount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sending 1 block} other{Sending {count} blocks}}'**
  String stripSendingMany(int count);

  /// Status strip, in a quieter colour after 'Sending 12.5 ZNN' and a middle dot. Lower case: it continues the line. A momentum is the Network of Momentum's block of blocks; it is not translated differently from elsewhere in the wallet.
  ///
  /// In en, this message translates to:
  /// **'waiting for a momentum'**
  String get stripWaitingMomentum;

  /// Status strip, in the warning colour beside the momentum height, while the node the wallet is connected to has not caught up with the network. count is how many momentums it is short.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 momentum behind} other{{count} momentums behind}}'**
  String stripMomentumsBehind(int count);

  /// Label in the status strip before the number of peers the node is connected to, as in 'Peers 23'.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get stripPeers;

  /// Label of a figure in the strip at the top of the Staking page: the total ZNN the selected address has staked. The amount stands under it.
  ///
  /// In en, this message translates to:
  /// **'Staked'**
  String get stakingStaked;

  /// Label of a figure in the strip at the top of the Staking page: the QSR the selected address has earned from its stakes and not collected yet. The amount stands under it and the Collect button beside it.
  ///
  /// In en, this message translates to:
  /// **'To collect'**
  String get stakingToCollect;

  /// Label of a figure in the strip at the top of the Staking page, and title of the chart under it: the QSR the selected address earned from its stakes over the last seven daily reward periods.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get stakingLast7Days;

  /// Label, a noun, of the small button in the strip at the top of the Staking page that shows or hides the chart of the last seven days of staking rewards.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get stakingChart;

  /// Label of a figure in the strip at the top of the Plasma page: the QSR the selected address has fused, for itself or for other addresses, summed over the list under the strip. The amount stands under it.
  ///
  /// In en, this message translates to:
  /// **'Fused by you'**
  String get plasmaPageFusedByYou;

  /// Title of the list on the Plasma page: the fusions the selected address has made, one row each. A number beside it says how many.
  ///
  /// In en, this message translates to:
  /// **'Fused'**
  String get plasmaPageFused;

  /// Title of a section on the Plasma page that opens to show the plasma level of the wallet's addresses other than the selected one. A number beside it says how many.
  ///
  /// In en, this message translates to:
  /// **'Other addresses'**
  String get plasmaPageOtherAddresses;

  /// Short summary at the end of the 'Other addresses' header on the Plasma page while it is closed: how many of those addresses have the plasma level Low. Lower case, as few words as the language allows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 low} other{{count} low}}'**
  String plasmaPageLowCount(int count);

  /// Button above the list of fusions on the Plasma page, shown once rows are ticked, and the title of the question it asks. It cancels the ticked fusions one after another. count is how many are ticked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cancel 1 fuse} other{Cancel {count} fuses}}'**
  String plasmaPageCancelFuses(int count);

  /// Question asked before the ticked fusions on the Plasma page are cancelled. count is how many; amount is the QSR they hold together, with its symbol.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cancel 1 fuse of {amount}?} other{Cancel {count} fuses, {amount} in all?}}'**
  String plasmaPageCancelFusesConfirm(int count, String amount);

  /// Shown above the list of fusions on the Plasma page when cancelling several stopped at one that failed: how many of the ticked fusions were cancelled before it, out of how many were ticked.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} cancelled'**
  String plasmaPageCancelFusesDone(int done, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'hi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
