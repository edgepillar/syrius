import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/model/model.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/card_parts/card_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/global.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as syrius_stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

enum _Step {
  checkPlasma,
  tokenCreation,
  tokenDetails,
  tokenMintableBurnable,
  tokenMetrics,
  issueToken,
}

/// A stepper that guides the user through creating a ZTS token.
class CreateTokenStepperView extends StatefulWidget {
  /// Creates a [CreateTokenStepperView].
  const CreateTokenStepperView({super.key});

  @override
  State createState() {
    return _CreateTokenStepperViewState();
  }
}

class _CreateTokenStepperViewState extends State<CreateTokenStepperView> {
  // When value is null, it means the stepper has completed.
  final ValueNotifier<_Step?> _currentStep = ValueNotifier<_Step?>(
    _Step.checkPlasma,
  );

  final TextEditingController _addressController = TextEditingController(
    text: kSelectedAddress,
  );
  final TextEditingController _tokenNameController = TextEditingController();
  final TextEditingController _totalSupplyController = TextEditingController();
  final TextEditingController _maxSupplyController = TextEditingController();
  final TextEditingController _tokenDomainController = TextEditingController();
  final TextEditingController _tokenSymbolController = TextEditingController();

  final ValueNotifier<NewTokenData> _tokenData = .new(
    NewTokenData.initial(address: kSelectedAddress!),
  );

  // Counts the tokens started. The decimals slider keeps its own position,
  // so it is built anew for each token or it would show the last one's.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    sl.get<MultipleBalanceBloc>().add(
      MultipleBalanceFetch(
        addresses: kDefaultAddressList.map((String? e) => e!).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MultipleBalanceBloc, MultipleBalanceState>(
      // Loading, the steps and an error fade into one another. The steps
      // themselves change with the stepper's own transition.
      builder: (_, MultipleBalanceState state) => StateSwitcher(
        alignment: Alignment.center,
        child: switch (state.status) {
          MultipleBalanceStatus.failure => SyriusErrorWidget(
            state.error!,
            key: const ValueKey<String>('error'),
          ),
          MultipleBalanceStatus.initial ||
          MultipleBalanceStatus.loading => const SyriusLoadingWidget(
            key: ValueKey<String>('loading'),
          ),
          MultipleBalanceStatus.success => KeyedSubtree(
            key: const ValueKey<String>('steps'),
            child: _buildBody(
              context,
              state.data![_addressController.text]!,
            ),
          ),
        },
      ),
    );
  }

  Widget _buildMaterialStepper({
    required AccountInfo accountInfo,
    required _Step? currentStep,
  }) {
    final int lastStepIndex = _Step.values.last.index;

    syrius_stepper.StepState getStepState(
      _Step step,
      _Step? currentStep,
    ) {
      return step.index < (currentStep?.index ?? lastStepIndex + 1)
          ? syrius_stepper.StepState.complete
          : syrius_stepper.StepState.indexed;
    }

    return ValueListenableBuilder<NewTokenData>(
      valueListenable: _tokenData,
      builder: (_, NewTokenData value, _) {
        final bool isBurnable = value.isBurnable;
        final bool isMintable = value.isMintable;
        final bool isUtility = value.isUtility;
        // The one accent of the stepper: its marks, the lines between them
        // and what a finished step says under its title.
        final Color accent = AppTokens.of(context).znnInk;

        return syrius_stepper.Stepper(
          activeColor: accent,
          currentStep: currentStep?.index ?? lastStepIndex,
          onStepTapped: (int index) {},
          steps: <syrius_stepper.Step>[
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.plasmaCheck,
              stepContent: TokenPlasmaCheckStep(
                active: currentStep == _Step.checkPlasma,
                addressController: _addressController,
                onNextPressed: _navigateToNextStep,
              ),
              stepSubtitle: context.l10n.sufficientPlasma,
              stepState: getStepState(
                _Step.checkPlasma,
                currentStep,
              ),
              context: context,
              stepSubtitleColor: accent,
            ),
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.tokenCreation,
              stepContent: TokenZnnCheckStep(
                active: currentStep == _Step.tokenCreation,
                accountInfo: accountInfo,
                addressController: _addressController,
                onContinuePressed: _navigateToNextStep,
                tokenData: _tokenData,
              ),
              stepSubtitle: _addressController.text,
              stepState: getStepState(
                _Step.tokenCreation,
                currentStep,
              ),
              context: context,
              stepSubtitleColor: accent,
            ),
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.tokenDetails,
              stepContent: TokenDetailsStep(
                active: currentStep == _Step.tokenDetails,
                onBackPressed: _onBackButtonPressed,
                onContinuePressed: _navigateToNextStep,
                tokenData: _tokenData,
                tokenDomainController: _tokenDomainController,
                tokenNameController: _tokenNameController,
                tokenSymbolController: _tokenSymbolController,
              ),
              stepSubtitle:
                  '${_tokenNameController.text} ${_tokenSymbolController.text}',
              stepState: getStepState(
                _Step.tokenDetails,
                currentStep,
              ),
              context: context,
              stepSubtitleColor: accent,
            ),
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.tokenMintableBurnableOptions,
              stepContent: TokenMintableBurnableStep(
                active: currentStep == _Step.tokenMintableBurnable,
                onBackPressed: _onBackButtonPressed,
                onContinuePressed: _onTokenMintableBurnableContinuePressed,
                tokenData: _tokenData,
              ),
              stepSubtitle: context.l10n.tokenMintableBurnableSubtitle(
                isBurnable ? context.l10n.yes : context.l10n.no,
                isMintable ? context.l10n.yes : context.l10n.no,
              ),
              stepState: getStepState(
                _Step.tokenMintableBurnable,
                currentStep,
              ),
              stepSubtitleColor: accent,
              context: context,
            ),
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.tokenMetrics,
              stepContent: TokenMetricsStep(
                key: ValueKey<int>(_run),
                active: currentStep == _Step.tokenMetrics,
                maxSupplyController: _maxSupplyController,
                onBackPressed: _onBackButtonPressed,
                onContinuePressed: _navigateToNextStep,
                tokenData: _tokenData,
                totalSupplyController: _totalSupplyController,
              ),
              // From the draft and not from the field: the step has stored
              // the amounts by the time this shows, and "1.50" reads 1.5.
              stepSubtitle: cardAmount(
                value.totalSupply,
                value.decimals,
                value.tokenSymbol,
              ),
              stepState: getStepState(
                _Step.tokenMetrics,
                currentStep,
              ),
              context: context,
              stepSubtitleColor: accent,
              stepSubtitleIconData: Icons.whatshot,
            ),
            StepperUtils.getMaterialStep(
              stepTitle: context.l10n.issueToken,
              stepContent: IssueTokenStep(
                active: currentStep == _Step.issueToken,
                onBackPressed: _onBackButtonPressed,
                onIssueDone: _onIssueDone,
                onIssuePressed: _onCreatePressed,
                tokenData: _tokenData,
              ),
              stepSubtitle: isMintable
                  ? context.l10n.tokenSupplyOutOfMax(
                      cardAmount(value.maxSupply, value.decimals, ''),
                      value.tokenSymbol,
                      cardAmount(value.totalSupply, value.decimals, ''),
                    )
                  : isUtility
                  ? context.l10n.utilityToken
                  : '',
              stepState: getStepState(
                _Step.issueToken,
                currentStep,
              ),
              context: context,
              stepSubtitleColor: accent,
            ),
          ],
        );
      },
    );
  }

  void _onBackButtonPressed() {
    final _Step? currentStep = _currentStep.value;

    if (currentStep == null || currentStep.index == 0) {
      return;
    }

    _currentStep.value = _Step.values[currentStep.index - 1];
  }

  Widget _buildBody(BuildContext context, AccountInfo accountInfo) {
    // The steps are told how tall the card is: the list they sit in would
    // give a step any height, and its actions would end below the window.
    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) => TokenStepViewport(
        height: constraints.maxHeight,
        child: ValueListenableBuilder<_Step?>(
          valueListenable: _currentStep,
          builder: (_, _Step? currentStep, _) {
            final bool hasTokenBeenCreated = currentStep == null;

            return Stack(
              children: <Widget>[
                ListView(
                  children: <Widget>[
                    _buildMaterialStepper(
                      accountInfo: accountInfo,
                      currentStep: currentStep,
                    ),
                    if (hasTokenBeenCreated)
                      TokenCreatedSuccess(
                        onCreateAnotherTokenPressed:
                            _onCreateAnotherTokenPressed,
                        onViewTokensPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                if (hasTokenBeenCreated) const TokenCreatedSuccessAnimation(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onCreateAnotherTokenPressed() {
    _run++;
    _tokenNameController.clear();
    _tokenSymbolController.clear();
    _totalSupplyController.clear();
    _maxSupplyController.clear();
    _tokenDomainController.clear();
    _tokenData.value = NewTokenData.initial(
      address: _addressController.text,
    );
    _currentStep.value = _Step.checkPlasma;
  }

  void _navigateToNextStep() {
    final int currentStepIndex = _currentStep.value!.index;
    _currentStep.value = _Step.values[currentStepIndex + 1];
  }

  void _onCreatePressed() {
    context.read<IssueTokenBloc>().add(
      IssueTokenRequested(tokenData: _tokenData.value),
    );
  }

  void _onIssueDone() {
    _currentStep.value = null;
    context.read<AllTokensBloc>().add(const AllTokensRequested());
  }

  void _onTokenMintableBurnableContinuePressed() {
    if (_tokenData.value.isMintable && _totalSupplyController.text.isNotEmpty) {
      _maxSupplyController.text = _totalSupplyController.text;
    }
    _navigateToNextStep();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _tokenNameController.dispose();
    _totalSupplyController.dispose();
    _maxSupplyController.dispose();
    _tokenDomainController.dispose();
    _tokenSymbolController.dispose();
    _currentStep.dispose();
    _tokenData.dispose();
    super.dispose();
  }
}
