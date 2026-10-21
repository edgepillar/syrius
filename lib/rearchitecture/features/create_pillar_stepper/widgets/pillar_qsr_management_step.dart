import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/math_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// A note on how the max QSR that can be deposited is calculated.
///
/// The minimum value between available and needed QSR to cover the cost
///
/// For example: if 100 is available to be deposited, and only 25 needed,
/// then this variable is equal to 25
///
/// If 100 more QSR is needed, and 100 is available, then variable is equal
/// to 100
///
class PillarQsrManagementStep extends StatefulWidget {
  /// Creates a [PillarQsrManagementStep].
  const PillarQsrManagementStep({
    required this.accountInfo,
    required this.addressController,
    required this.onNextPressed,
    required this.qsrAmountController,
    this.onBackPressed,
    this.active = true,
    super.key,
  });

  /// Account balances for the selected address.
  final AccountInfo accountInfo;

  /// Selected address controller displayed by the disabled address field.
  final TextEditingController addressController;

  /// Controller containing the QSR amount to deposit.
  final TextEditingController qsrAmountController;

  /// Called when the user can continue to the next step.
  final VoidCallback onNextPressed;

  /// Called when the user wants to go back. No Back button when null.
  final VoidCallback? onBackPressed;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<PillarQsrManagementStep> createState() =>
      _PillarQsrManagementStepState();
}

class _PillarQsrManagementStepState extends State<PillarQsrManagementStep> {
  final GlobalKey<LoadingButtonState> _depositQsrButtonKey = GlobalKey();
  final GlobalKey<LoadingButtonState> _withdrawButtonKey = GlobalKey();

  // From the press until the bloc is done or has failed.
  bool _isDepositing = false;
  bool _isWithdrawing = false;

  // The most that could be deposited when the field was last filled in.
  BigInt? _filledInFor;

  bool get _isSending => _isDepositing || _isWithdrawing;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<PillarDepositQsrBloc, PillarDepositQsrState>(
          listener: (_, PillarDepositQsrState state) =>
              _onDepositStateChanged(state),
        ),
        BlocListener<PillarWithdrawQsrBloc, PillarWithdrawQsrState>(
          listener: (_, PillarWithdrawQsrState state) =>
              _onWithdrawStateChanged(state),
        ),
      ],
      child:
          BlocBuilder<
            CreatePillarQsrInfoBloc,
            FetchState<CreatePillarQsrInfoData>
          >(
            builder: (_, FetchState<CreatePillarQsrInfoData> state) =>
                switch (state) {
                  FetchFailure<CreatePillarQsrInfoData>() => SyriusErrorWidget(
                    state.exception,
                  ),
                  FetchInitial<CreatePillarQsrInfoData>() =>
                    const SyriusLoadingWidget(),
                  FetchPopulated<CreatePillarQsrInfoData>() => _buildPopulated(
                    context,
                    state.data,
                  ),
                },
          ),
    );
  }

  Widget _buildPopulated(
    BuildContext context,
    CreatePillarQsrInfoData qsrInfo,
  ) {
    final BigInt maxQsrAmount = MathUtils.bigMin(
      widget.accountInfo.getBalance(
        kQsrCoin.tokenStandard,
      ),
      MathUtils.bigMax(BigInt.zero, qsrInfo.cost - qsrInfo.deposit),
    );

    // The field starts at the most that can be deposited, and is filled in
    // again when that changes: after a deposit, a withdrawal, a new balance.
    // Not on every build, which would undo what is being typed.
    if (_filledInFor != maxQsrAmount) {
      _filledInFor = maxQsrAmount;
      widget.qsrAmountController.text = maxQsrAmount.addDecimals(
        coinDecimals,
      );
    }

    final bool qsrCostCovered = qsrInfo.deposit >= qsrInfo.cost;

    return ListenableBuilder(
      listenable: widget.qsrAmountController,
      builder: (BuildContext context, _) {
        final AppTokens tokens = AppTokens.of(context);
        final bool canDeposit =
            !_isSending &&
            _canDeposit(
              maxQsrAmount: maxQsrAmount,
              qsrAmountText: widget.qsrAmountController.text,
            );
        final VoidCallback? onNext = _isSending ? null : widget.onNextPressed;
        // The frame holds the fields and the step's actions. What has been
        // deposited stands beside it, not in it: the frame gives the focus
        // to the first control it holds when the step opens, and that must
        // be the amount or Next, never Withdraw. Tab still reaches Withdraw,
        // after the step's own actions.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TokenStepFrame(
                active: widget.active,
                busy: _isSending,
                onBack: widget.onBackPressed,
                onSubmit: qsrCostCovered
                    ? onNext
                    : canDeposit
                    ? _onDepositButtonPressed
                    : null,
                body: _buildFields(
                  context,
                  qsrInfo,
                  maxQsrAmount,
                  qsrCostCovered: qsrCostCovered,
                ),
                // The keys stay on wrappers: the buttons are looked up
                // under them.
                primary: qsrCostCovered
                    ? KeyedSubtree(
                        key: const Key('pillar_qsr_next_button'),
                        child: OutlinedButton(
                          onPressed: onNext,
                          child: Text(context.l10n.next),
                        ),
                      )
                    : KeyedSubtree(
                        key: const Key('pillar_qsr_deposit_button'),
                        child: LoadingButton(
                          key: _depositQsrButtonKey,
                          text: context.l10n.deposit,
                          onPressed: canDeposit
                              ? _onDepositButtonPressed
                              : null,
                          circularBorderRadius:
                              kLoadingButtonMinSize.height / 2,
                        ),
                      ),
              ),
            ),
            SizedBox(width: tokens.panelGap * 2),
            Expanded(
              child: Visibility(
                visible: qsrInfo.deposit > BigInt.zero,
                child: _DepositedQsr(
                  qsrInfo: qsrInfo,
                  withdrawKey: _withdrawButtonKey,
                  onWithdrawPressed: _isSending
                      ? null
                      : _onWithdrawButtonPressed,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFields(
    BuildContext context,
    CreatePillarQsrInfoData qsrInfo,
    BigInt maxQsrAmount, {
    required bool qsrCostCovered,
  }) {
    final AppTokens tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AccField(
          label: context.l10n.address,
          child: DisabledAddressField(widget.addressController),
        ),
        // Under the field: what the address holds, and what a slot takes.
        AccBalanceLine(kQsrCoin, widget.accountInfo),
        AccHintLine(
          context.l10n.requiredForPillarSlot(
            cardAmount(qsrInfo.cost, coinDecimals, ''),
            kQsrCoin.symbol,
          ),
        ),
        if (!qsrCostCovered) ...<Widget>[
          SizedBox(height: tokens.cardGap),
          AccField(
            label: context.l10n.amount,
            child: AmountRefusalScope(
              controller: widget.qsrAmountController,
              builder: (BuildContext context, String? refusal) =>
                  TextFormField(
                    key: const Key('pillar_qsr_amount_field'),
                    autovalidateMode: AutovalidateMode.always,
                    controller: widget.qsrAmountController,
                    readOnly: _isSending,
                    inputFormatters: FormatUtils.getAmountTextInputFormatters(
                      widget.qsrAmountController.text,
                    ),
                    style: accFieldTextStyle(context, mono: true),
                    // An amount reads left to right in every language.
                    textDirection: TextDirection.ltr,
                    textAlign: ltrTextAlign(context),
                    // Why the last key did nothing comes before what the
                    // amount itself has wrong.
                    forceErrorText: refusal,
                    validator: (String? value) => _qsrAmountValidator(
                      maxQsrAmount: maxQsrAmount,
                      value: value,
                    ),
                  ),
            ),
          ),
        ],
        SizedBox(height: tokens.cardGap),
        DottedBorderInfoWidget(
          borderColor: tokens.qsrInk,
          text: context.l10n.depositedCoinWillBurn(kQsrCoin.symbol),
        ),
      ],
    );
  }

  String? _qsrAmountValidator({
    required BigInt maxQsrAmount,
    required String? value,
  }) => InputValidators.correctValue(
    value,
    maxQsrAmount,
    kQsrCoin.decimals,
    BigInt.one,
    canBeEqualToMin: true,
  );

  void _refreshPillarQsrInfo() {
    sl.get<MultipleBalanceBloc>().add(
      MultipleBalanceFetch(
        addresses: kDefaultAddressList.map((String? e) => e!).toList(),
      ),
    );
    context.read<CreatePillarQsrInfoBloc>().add(
      FetchRequestData(
        address: Address.parse(widget.addressController.text),
      ),
    );
  }

  bool _canDeposit({
    required BigInt maxQsrAmount,
    required String qsrAmountText,
  }) =>
      _hasQsrBalance(widget.accountInfo) &&
      _qsrAmountValidator(
            value: qsrAmountText,
            maxQsrAmount: maxQsrAmount,
          ) ==
          null;

  bool _hasQsrBalance(AccountInfo accountInfo) =>
      accountInfo.qsr()! > BigInt.zero;

  void _onDepositButtonPressed() {
    if (_isSending) {
      return;
    }
    setState(() {
      _isDepositing = true;
    });
    final BigInt qsrAmount = widget.qsrAmountController.text.extractDecimals(
      coinDecimals,
    );

    context.read<PillarDepositQsrBloc>().add(
      PillarDepositQsrRequested(
        address: Address.parse(widget.addressController.text),
        amount: qsrAmount,
      ),
    );
  }

  void _onWithdrawButtonPressed() {
    if (_isSending) {
      return;
    }
    setState(() {
      _isWithdrawing = true;
    });
    context.read<PillarWithdrawQsrBloc>().add(
      PillarWithdrawQsrRequested(
        address: Address.parse(widget.addressController.text),
      ),
    );
  }

  void _onDepositStateChanged(PillarDepositQsrState state) {
    if (state is PillarDepositQsrDone) {
      _depositQsrButtonKey.currentState?.animateReverse();
      setState(() {
        _isDepositing = false;
      });
      _refreshPillarQsrInfo();
    } else if (state is PillarDepositQsrLoading) {
      _depositQsrButtonKey.currentState?.animateForward();
      setState(() {
        _isDepositing = true;
      });
    } else if (state is PillarDepositQsrFailure) {
      _depositQsrButtonKey.currentState?.animateReverse();
      setState(() {
        _isDepositing = false;
      });
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorWhileDepositing(kQsrCoin.symbol),
        ),
      );
    }
  }

  void _onWithdrawStateChanged(PillarWithdrawQsrState state) {
    if (state is PillarWithdrawQsrLoading) {
      _withdrawButtonKey.currentState?.animateForward();
      setState(() {
        _isWithdrawing = true;
      });
    } else if (state is PillarWithdrawQsrFailure) {
      _withdrawButtonKey.currentState?.animateReverse();
      setState(() {
        _isWithdrawing = false;
      });
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorWhileWithdrawing(kQsrCoin.symbol),
        ),
      );
    } else if (state is PillarWithdrawQsrPopulated) {
      _withdrawButtonKey.currentState?.animateReverse();
      setState(() {
        _isWithdrawing = false;
      });
      _refreshPillarQsrInfo();
    }
  }
}

/// What has been deposited for the slot so far, against what the slot takes,
/// and the way to take it back.
class _DepositedQsr extends StatelessWidget {
  const _DepositedQsr({
    required this.qsrInfo,
    required this.withdrawKey,
    required this.onWithdrawPressed,
  });

  final CreatePillarQsrInfoData qsrInfo;
  final GlobalKey<LoadingButtonState> withdrawKey;

  /// Null while a deposit or a withdrawal is being sent.
  final VoidCallback? onWithdrawPressed;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final double toBeDepositedValue =
        (qsrInfo.cost - qsrInfo.deposit) / qsrInfo.cost;
    final double depositedValue = qsrInfo.deposit / qsrInfo.cost;

    return Card.filled(
      margin: EdgeInsets.zero,
      color: context.themeData.inputDecorationTheme.fillColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.panelGap),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1,
                    child: StandardPieChart(
                      sections: <PieChartSectionData>[
                        PieChartSectionData(
                          showTitle: false,
                          radius: 7,
                          value: toBeDepositedValue,
                          color: tokens.qsrInk.withValues(alpha: 0.3),
                        ),
                        PieChartSectionData(
                          showTitle: false,
                          radius: 7,
                          value: depositedValue,
                          color: tokens.qsrInk,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      context.l10n.currentPillarSlotFee(
                        cardAmount(qsrInfo.cost, coinDecimals, ''),
                        kQsrCoin.symbol,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.cardGap),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.l10n.youHaveDeposited(
                      cardAmount(qsrInfo.deposit, coinDecimals, ''),
                      kQsrCoin.symbol,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: tokens.cardGap),
                  // The step's one filled button is Deposit or Next; taking
                  // the deposit back is the quiet action beside it.
                  OutlinedButtonTheme(
                    data: OutlinedButtonThemeData(
                      style: secondaryButtonStyle(context),
                    ),
                    child: LoadingButton(
                      key: withdrawKey,
                      text: context.l10n.withdraw,
                      onPressed: onWithdrawPressed,
                      circularBorderRadius: kLoadingButtonMinSize.height / 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
