import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_pillar_stepper/widgets/pillar_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/registration_success/registration_confirmation.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/ltr.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/shell/rail.dart'
    show ShellSymbol;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

enum _Stage { details, sharing, review }

/// The retained draft stages after the original Pillar prerequisites.
class DeployPillarStep extends StatefulWidget {
  /// Creates a [DeployPillarStep].
  const DeployPillarStep({
    required this.onDeployDone,
    required this.ownerAddress,
    required this.availableZnn,
    this.onBackPressed,
    this.onPublished,
    this.registrationRun = 0,
    this.active = true,
    super.key,
  });

  /// Called when deployment completes.
  final VoidCallback onDeployDone;

  /// The address captured by the flow before checking plasma and balances.
  final String ownerAddress;

  /// The balance belonging to that address, from the prerequisite view.
  final BigInt availableZnn;

  /// Retains the original result before the legacy completion callback runs.
  final ValueChanged<RegistrationPublication>? onPublished;

  /// Changes only when the user explicitly starts another registration.
  final int registrationRun;

  /// Called when the user wants to go back. No Back button when null.
  final VoidCallback? onBackPressed;

  /// Whether this is the step shown.
  final bool active;

  @override
  State<DeployPillarStep> createState() => _DeployPillarStepState();
}

class _DeployPillarStepState extends State<DeployPillarStep> {
  _Stage _stage = _Stage.details;
  GlobalKey<LoadingButtonState> _registerButtonKey = GlobalKey();

  final TextEditingController _pillarNameController = TextEditingController();
  final TextEditingController _pillarRewardAddressController =
      TextEditingController();
  final TextEditingController _pillarMomentumController =
      TextEditingController();

  String? get _pillarNameError =>
      Validations.pillarName(_pillarNameController.text);

  String? get _pillarRewardAddressError =>
      InputValidators.checkAddress(_pillarRewardAddressController.text);

  String? get _pillarMomentumError =>
      InputValidators.validatePillarMomentumAddress(
        _pillarMomentumController.text,
      );

  final ValueNotifier<double> _momentumRewardPercentage = .new(0);
  final ValueNotifier<double> _delegateRewardPercentage = .new(0);

  // From the press until the bloc is done or has failed.
  bool _isSending = false;
  bool _accepted = false;
  String? _submittedName;
  BigInt? _submittedQsrCost;

  @override
  void didUpdateWidget(DeployPillarStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registrationRun != widget.registrationRun) {
      _stage = _Stage.details;
      _accepted = false;
      _isSending = false;
      _registerButtonKey = GlobalKey<LoadingButtonState>();
      _submittedName = null;
      _submittedQsrCost = null;
      _pillarNameController.clear();
      _pillarMomentumController.clear();
      _pillarRewardAddressController.text = widget.ownerAddress;
      _momentumRewardPercentage.value = 0;
      _delegateRewardPercentage.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _pillarRewardAddressController.text = widget.ownerAddress;
  }

  @override
  void dispose() {
    _pillarNameController.dispose();
    _pillarRewardAddressController.dispose();
    _pillarMomentumController.dispose();
    _momentumRewardPercentage.dispose();
    _delegateRewardPercentage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeployPillarBloc, DeployPillarState>(
      listener: (_, DeployPillarState state) => _onDeployStateChanged(state),
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          _pillarNameController,
          _pillarMomentumController,
          _pillarRewardAddressController,
          _momentumRewardPercentage,
          _delegateRewardPercentage,
        ]),
        builder: (BuildContext context, _) =>
            BlocBuilder<
              CreatePillarQsrInfoBloc,
              FetchState<CreatePillarQsrInfoData>
            >(
              builder:
                  (
                    BuildContext context,
                    FetchState<CreatePillarQsrInfoData> state,
                  ) => _buildBody(
                    context,
                    state is FetchPopulated<CreatePillarQsrInfoData>
                        ? state.data
                        : null,
                  ),
            ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CreatePillarQsrInfoData? qsrInfo) {
    final AppTokens tokens = AppTokens.of(context);
    final bool active = widget.active && StepInteraction.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildRail(context, qsrInfo),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: tokens.tokenCreateBodyMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: tokens.registrationBodyInset,
                  vertical: tokens.tokenCreateVerticalInset,
                ),
                child: StepSwitcher.retained(
                  step: _stage.index,
                  children: <Widget>[
                    _buildDetails(context, active),
                    _buildSharing(context, active),
                    _buildReview(context, active, qsrInfo?.cost),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context, bool active) {
    final VoidCallback? next = active && _isInputValid()
        ? () => _changeStage(_Stage.details, _Stage.sharing)
        : null;
    final AppTokens tokens = AppTokens.of(context);
    final ThemeData theme = Theme.of(context);
    return TokenStepFrame(
      active: active && _stage == _Stage.details,
      busy: _isSending,
      onBack: widget.onBackPressed,
      outlinedBack: true,
      onSubmit: next,
      body: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            isDense: true,
            contentPadding: tokens.sendFieldPadding,
            constraints: BoxConstraints(minHeight: tokens.fieldHeight),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              minimumSize: Size.square(tokens.fieldHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
          ),
        ),
        child: _buildTextFields(context),
      ),
      primary: KeyedSubtree(
        key: const Key('pillar_details_next_button'),
        child: PrimaryPill(
          onPressed: next,
          child: Text(context.l10n.continueText),
        ),
      ),
    );
  }

  Widget _buildSharing(BuildContext context, bool active) {
    final VoidCallback? next = active && _isInputValid()
        ? () => _changeStage(_Stage.sharing, _Stage.review)
        : null;
    return TokenStepFrame(
      active: active && _stage == _Stage.sharing,
      busy: _isSending,
      onBack: () => _changeStage(_Stage.sharing, _Stage.details),
      outlinedBack: true,
      onSubmit: next,
      body: PillarRewardSliders(
        delegateRewardPercentage: _delegateRewardPercentage,
        momentumRewardPercentage: _momentumRewardPercentage,
      ),
      primary: KeyedSubtree(
        key: const Key('pillar_sharing_next_button'),
        child: PrimaryPill(
          onPressed: next,
          child: Text(context.l10n.continueText),
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context, bool active, BigInt? slotFee) {
    return TokenStepFrame(
      active: active && _stage == _Stage.review,
      busy: _isSending,
      onBack: () => _changeStage(_Stage.review, _Stage.sharing),
      outlinedBack: true,
      // Review requires deliberately choosing Register, including by keyboard.
      focusPrimaryOnOpen: false,
      body: PillarReview(
        name: _pillarNameController.text,
        rewardAddress: _pillarRewardAddressController.text,
        producerAddress: _pillarMomentumController.text,
        momentumPercentage: _momentumRewardPercentage.value.toInt(),
        delegatePercentage: _delegateRewardPercentage.value.toInt(),
        costs: <Widget>[
          PillarReviewRow.amount(
            context: context,
            label: context.l10n.createPillarCollateralLabel,
            amount: pillarRegisterZnnAmount,
            token: kZnnCoin,
          ),
          if (slotFee != null)
            PillarReviewRow.amount(
              context: context,
              label: context.l10n.createPillarSlotFeeLabel,
              amount: slotFee,
              token: kQsrCoin,
            ),
        ],
      ),
      primary: KeyedSubtree(
        key: const Key('pillar_register_button'),
        child: LoadingButton(
          text: context.l10n.register,
          onPressed: active && _isInputValid() && !_isSending && !_accepted
              ? _onDeployPressed
              : null,
          circularBorderRadius: kLoadingButtonMinSize.height / 2,
          key: _registerButtonKey,
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, CreatePillarQsrInfoData? qsrInfo) {
    final AppTokens tokens = AppTokens.of(context);
    final bool feeDeposited =
        qsrInfo != null &&
        qsrInfo.observedAddress == widget.ownerAddress &&
        kSelectedAddress == widget.ownerAddress &&
        qsrInfo.cost > BigInt.zero &&
        qsrInfo.deposit >= qsrInfo.cost;
    return Container(
      width: tokens.registrationRailWidth,
      decoration: BoxDecoration(
        border: BorderDirectional(end: BorderSide(color: tokens.line)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.registrationInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tokens.registrationRailGap,
          children: <Widget>[
            _buildRailSteps(context, tokens),
            Divider(height: 1, thickness: 1, color: tokens.line),
            Column(
              spacing: tokens.registrationGap,
              children: <Widget>[
                if (qsrInfo != null)
                  _buildRailAmount(
                    tokens,
                    context.l10n.createPillarSlotFeeLabel,
                    qsrInfo.cost,
                    kQsrCoin,
                    note: feeDeposited
                        ? context.l10n.pillarOwnerDeposited
                        : null,
                  ),
                _buildRailAmount(
                  tokens,
                  context.l10n.createPillarCollateralLabel,
                  pillarRegisterZnnAmount,
                  kZnnCoin,
                ),
                _buildRailAmount(
                  tokens,
                  context.l10n.tokenCreateHave,
                  widget.availableZnn,
                  kZnnCoin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailSteps(BuildContext context, AppTokens tokens) {
    final List<String> labels = pillarRegistrationSteps(context);
    final int current = _stage.index + 1;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.registrationStepListInset),
      child: Column(
        spacing: tokens.registrationActionGap,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Row(
              spacing: tokens.entryStepGap,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: tokens.entryStepSize,
                    height: tokens.entryStepSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < current ? tokens.znn : null,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= current ? tokens.znn : tokens.line,
                      ),
                    ),
                    child: i < current
                        ? ShellSymbol(
                            'check',
                            size: tokens.inlineGlyphSize,
                            color: tokens.onZnn,
                          )
                        : Text(
                            '${i + 1}',
                            style: tokens.ledgerText.copyWith(
                              color: i == current
                                  ? tokens.znnInk
                                  : tokens.faint,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    selected: i == current,
                    child: Text(
                      labels[i],
                      style: i == current
                          ? tokens.compactText
                          : tokens.compactText.copyWith(color: tokens.faint),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRailAmount(
    AppTokens tokens,
    String label,
    BigInt amount,
    Token token, {
    String? note,
  }) => Row(
    spacing: tokens.inlineGap,
    children: <Widget>[
      Expanded(child: Text(label.toUpperCase(), style: tokens.ledgerText)),
      Flexible(
        flex: 2,
        child: FittedBox(
          alignment: AlignmentDirectional.centerStart,
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: tokens.inlineGap,
            children: <Widget>[
              AmountText(
                amount,
                decimals: token.decimals,
                symbol: token.symbol,
                style: tokens.registrationFactText,
              ),
              if (note != null)
                Text(
                  note,
                  style: tokens.registrationFactText.copyWith(
                    color: tokens.znnInk,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  void _changeStage(_Stage from, _Stage to) {
    if (!widget.active || _stage != from || _isSending || _accepted) return;
    if (to.index > from.index && !_isInputValid()) return;
    setState(() => _stage = to);
  }

  Widget _buildTextFields(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final TextStyle text = accFieldTextStyle(context);
    final bool hasName = _pillarNameController.text.isNotEmpty;
    final String? nameError = hasName ? _pillarNameError : null;
    // An address reads left to right in every language.
    final TextStyle address = accFieldTextStyle(context, mono: true);
    final TextAlign addressAlign = ltrTextAlign(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: tokens.registrationActionGap,
      children: <Widget>[
        AccField(
          label: context.l10n.pillarName,
          child: TextField(
            key: const Key('pillar_name_field'),
            controller: _pillarNameController,
            readOnly: _isSending,
            style: text,
            decoration: InputDecoration(
              helperText: context.l10n.createPillarNameHelp,
              helperMaxLines: 3,
              errorText: nameError,
              suffixIconConstraints: BoxConstraints.tightFor(
                width: 36,
                height: tokens.fieldHeight,
              ),
              suffixIcon: hasName && nameError == null
                  ? Center(
                      child: ShellSymbol(
                        'check',
                        size: tokens.smallActionGlyphSize,
                        color: tokens.znnInk,
                        key: const Key('pillar_name_valid'),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        AccField(
          label: context.l10n.pillarProducerAddress,
          child: TextField(
            key: const Key('pillar_producer_address_field'),
            controller: _pillarMomentumController,
            readOnly: _isSending,
            style: address,
            textDirection: TextDirection.ltr,
            textAlign: addressAlign,
            decoration: InputDecoration(
              helperText: context.l10n.createPillarProducerHelp,
              helperMaxLines: 3,
              errorText: _pillarMomentumController.text.isNotEmpty
                  ? _pillarMomentumError
                  : null,
              suffixIconConstraints: BoxConstraints(
                minHeight: tokens.fieldHeight,
              ),
              suffixIcon: FieldSuffixButtons(
                controller: _pillarMomentumController,
              ),
            ),
          ),
        ),
        AccField(
          label: context.l10n.pillarRewardAddress,
          help: context.l10n.addressToCollectRewards,
          child: TextField(
            key: const Key('pillar_reward_address_field'),
            controller: _pillarRewardAddressController,
            readOnly: _isSending,
            style: address,
            textDirection: TextDirection.ltr,
            textAlign: addressAlign,
            decoration: InputDecoration(
              errorText: _pillarRewardAddressController.text.isNotEmpty
                  ? _pillarRewardAddressError
                  : null,
              suffixIconConstraints: BoxConstraints(
                minHeight: tokens.fieldHeight,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton(
                    key: const Key('pillar_use_owner_address'),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, tokens.fieldHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                    ),
                    onPressed: _canUseOwnerAddress ? _useOwnerAddress : null,
                    child: Text(context.l10n.tokensThisAddress),
                  ),
                  FieldSuffixButtons(
                    controller: _pillarRewardAddressController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _canUseOwnerAddress =>
      widget.active &&
      _stage == _Stage.details &&
      !_isSending &&
      !_accepted &&
      kSelectedAddress == widget.ownerAddress;

  void _useOwnerAddress() {
    if (_canUseOwnerAddress) {
      _pillarRewardAddressController.text = widget.ownerAddress;
    }
  }

  void _onDeployStateChanged(DeployPillarState state) {
    if (_accepted) return;
    if (state is DeployPillarDone) {
      _accepted = true;
      try {
        widget.onPublished?.call(
          RegistrationPublication(
            accountBlock: state.accountBlock,
            name: _submittedName,
            qsrCost: _submittedQsrCost,
          ),
        );
      } on Object {
        // Receipt display cannot replace the accepted result in the bloc.
      }
      _registerButtonKey.currentState?.animateReverse();
      setState(() {
        _isSending = false;
      });
      try {
        widget.onDeployDone();
      } on Object {
        // A completion observer never reopens or retries the accepted action.
      }
    } else if (state is DeployPillarFailure) {
      _registerButtonKey.currentState?.animateReverse();
      setState(() {
        _isSending = false;
      });
      unawaited(
        NotificationUtils.sendNotificationError(
          state.exception,
          context.l10n.errorDeployingPillar,
        ),
      );
    } else if (state is DeployPillarLoading) {
      _registerButtonKey.currentState?.animateForward();
      setState(() {
        _isSending = true;
      });
    }
  }

  bool _isInputValid() =>
      _pillarNameError == null &&
      _pillarRewardAddressError == null &&
      _pillarMomentumError == null;

  void _onDeployPressed() {
    if (_isSending ||
        _accepted ||
        !widget.active ||
        _stage != _Stage.review ||
        !_isInputValid()) {
      return;
    }
    _submittedName = _pillarNameController.text;
    if (widget.onPublished != null) {
      final FetchState<CreatePillarQsrInfoData> state = context
          .read<CreatePillarQsrInfoBloc>()
          .state;
      _submittedQsrCost = state is FetchPopulated<CreatePillarQsrInfoData>
          ? state.data.cost
          : null;
    }
    setState(() {
      _isSending = true;
    });
    context.read<DeployPillarBloc>().add(
      DeployPillarRequested(
        pillarName: _pillarNameController.text,
        rewardAddress: Address.parse(_pillarRewardAddressController.text),
        blockProducingAddress: Address.parse(
          _pillarMomentumController.text,
        ),
        giveBlockRewardPercentage: _momentumRewardPercentage.value.toInt(),
        giveDelegateRewardPercentage: _delegateRewardPercentage.value.toInt(),
      ),
    );
  }
}
